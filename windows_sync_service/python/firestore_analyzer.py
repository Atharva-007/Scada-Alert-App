#!/usr/bin/env python3
"""CLI analyzer for SCADA Firestore datasets."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

import firebase_admin
from firebase_admin import credentials, firestore


DEFAULT_COLLECTIONS = (
    "alerts_active",
    "alerts_history",
    "client_heartbeats",
    "config",
    "device_tokens",
    "statistics",
    "system_status",
)


class FirestoreAnalyzerError(RuntimeError):
    """Raised when analyzer configuration or runtime fails."""


@dataclass(frozen=True)
class AnalyzerConfig:
    project_id: str
    database_id: str
    service_account_path: str | None
    collections: tuple[str, ...]
    sample_size: int
    max_depth: int
    include_all_documents: bool
    all_collections: bool


@dataclass
class PathProfile:
    present_in_docs: int = 0
    types: Counter[str] = field(default_factory=Counter)
    null_count: int = 0
    scalar_count: int = 0
    unique_values: set[str] = field(default_factory=set)
    numeric_min: float | None = None
    numeric_max: float | None = None
    string_min_length: int | None = None
    string_max_length: int | None = None
    deepest_level_seen: int = 0


def _json_safe(value: Any) -> Any:
    if isinstance(value, dt.datetime):
        return value.isoformat()
    if isinstance(value, dt.date):
        return value.isoformat()
    if isinstance(value, bytes):
        return f"<bytes:{len(value)}>"
    if isinstance(value, dict):
        return {str(k): _json_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_json_safe(v) for v in value]
    return value


def _type_name(value: Any) -> str:
    if value is None:
        return "null"
    return type(value).__name__


def _stringify_scalar(value: Any) -> str:
    if isinstance(value, (str, int, float, bool)):
        return str(value)
    return _type_name(value)


def _initialize_firestore(project_id: str, service_account_path: str | None) -> None:
    if firebase_admin._apps:
        return

    options = {"projectId": project_id}
    if service_account_path:
        path = Path(service_account_path)
        if not path.is_file():
            raise FirestoreAnalyzerError(f"Service account JSON not found: {path}")
        cred = credentials.Certificate(str(path))
        firebase_admin.initialize_app(cred, options=options)
        return

    firebase_admin.initialize_app(options=options)


def _walk_path(
    value: Any,
    path: str,
    level: int,
    max_depth: int,
    per_doc_seen: set[str],
    path_profiles: dict[str, PathProfile],
) -> None:
    if not path:
        if isinstance(value, dict):
            for key, nested in value.items():
                _walk_path(nested, str(key), level + 1, max_depth, per_doc_seen, path_profiles)
        return

    profile = path_profiles.setdefault(path, PathProfile())
    if path not in per_doc_seen:
        profile.present_in_docs += 1
        per_doc_seen.add(path)

    value_type = _type_name(value)
    profile.types[value_type] += 1
    profile.deepest_level_seen = max(profile.deepest_level_seen, level)

    if value is None:
        profile.null_count += 1
        return

    if isinstance(value, bool):
        profile.scalar_count += 1
        if len(profile.unique_values) < 50:
            profile.unique_values.add(_stringify_scalar(value))
        return

    if isinstance(value, (int, float)):
        numeric = float(value)
        profile.scalar_count += 1
        profile.numeric_min = numeric if profile.numeric_min is None else min(profile.numeric_min, numeric)
        profile.numeric_max = numeric if profile.numeric_max is None else max(profile.numeric_max, numeric)
        if len(profile.unique_values) < 50:
            profile.unique_values.add(_stringify_scalar(value))
        return

    if isinstance(value, str):
        profile.scalar_count += 1
        length = len(value)
        profile.string_min_length = (
            length if profile.string_min_length is None else min(profile.string_min_length, length)
        )
        profile.string_max_length = (
            length if profile.string_max_length is None else max(profile.string_max_length, length)
        )
        if len(profile.unique_values) < 50:
            profile.unique_values.add(value)
        return

    if level >= max_depth:
        return

    if isinstance(value, dict):
        for key, nested in value.items():
            child_path = f"{path}.{key}"
            _walk_path(nested, child_path, level + 1, max_depth, per_doc_seen, path_profiles)
        return

    if isinstance(value, list):
        list_path = f"{path}[]"
        list_profile = path_profiles.setdefault(list_path, PathProfile())
        if list_path not in per_doc_seen:
            list_profile.present_in_docs += 1
            per_doc_seen.add(list_path)
        list_profile.types["array_item"] += len(value)
        list_profile.deepest_level_seen = max(list_profile.deepest_level_seen, level + 1)
        for item in value:
            _walk_path(item, list_path, level + 1, max_depth, per_doc_seen, path_profiles)


def _constraint_profile(path_profile: PathProfile, total_docs: int) -> dict[str, Any]:
    constraints: dict[str, Any] = {
        "required_in_all_documents": path_profile.present_in_docs == total_docs and total_docs > 0,
        "nullable": path_profile.null_count > 0,
    }

    if path_profile.unique_values and len(path_profile.unique_values) <= 12:
        constraints["enum_candidate_values"] = sorted(path_profile.unique_values)

    if path_profile.numeric_min is not None and path_profile.numeric_max is not None:
        constraints["numeric_range"] = {
            "min": path_profile.numeric_min,
            "max": path_profile.numeric_max,
        }

    if (
        path_profile.string_min_length is not None
        and path_profile.string_max_length is not None
    ):
        constraints["string_length_range"] = {
            "min": path_profile.string_min_length,
            "max": path_profile.string_max_length,
        }

    return constraints


def _flattened_profile(path_profiles: dict[str, PathProfile], total_docs: int) -> dict[str, Any]:
    return {
        path: {
            "present_in_docs": profile.present_in_docs,
            "presence_ratio": round(profile.present_in_docs / total_docs, 4) if total_docs else 0.0,
            "types": dict(profile.types),
            "deepest_level_seen": profile.deepest_level_seen,
            "constraints": _constraint_profile(profile, total_docs),
        }
        for path, profile in sorted(path_profiles.items())
    }


def _top_level_profile(path_profiles: dict[str, PathProfile], total_docs: int) -> dict[str, Any]:
    top_level = {
        path: profile
        for path, profile in path_profiles.items()
        if "." not in path and "[]" not in path
    }
    return _flattened_profile(top_level, total_docs)


def _deep_paths(path_profiles: dict[str, PathProfile], top_n: int = 3) -> list[dict[str, Any]]:
    ordered = sorted(
        path_profiles.items(),
        key=lambda item: (item[1].deepest_level_seen, item[1].present_in_docs),
        reverse=True,
    )
    return [
        {
            "path": path,
            "deepest_level_seen": profile.deepest_level_seen,
            "present_in_docs": profile.present_in_docs,
        }
        for path, profile in ordered[:top_n]
    ]


def _analyze_collection(
    db: firestore.Client,
    collection_name: str,
    sample_size: int,
    max_depth: int,
    include_all_documents: bool,
) -> dict[str, Any]:
    docs_stream = db.collection(collection_name).stream()
    total_docs = 0
    sample_documents: list[dict[str, Any]] = []
    full_documents: list[dict[str, Any]] | None = [] if include_all_documents else None
    path_profiles: dict[str, PathProfile] = {}
    severity_counter: Counter[str] = Counter()
    status_counter: Counter[str] = Counter()
    acknowledged_counter: Counter[str] = Counter()

    for doc in docs_stream:
        total_docs += 1
        data = doc.to_dict() or {}
        per_doc_seen: set[str] = set()
        _walk_path(data, "", 0, max_depth, per_doc_seen, path_profiles)

        severity = data.get("severity")
        if isinstance(severity, str):
            severity_counter[severity] += 1

        status = data.get("status")
        if isinstance(status, str):
            status_counter[status] += 1

        ack_value = data.get("isAcknowledged", data.get("acknowledged"))
        if isinstance(ack_value, bool):
            acknowledged_counter[str(ack_value).lower()] += 1

        row = {
            "id": doc.id,
            "fields": _json_safe(data),
        }
        if len(sample_documents) < sample_size:
            sample_documents.append(row)
        if include_all_documents and full_documents is not None:
            full_documents.append(row)

    result: dict[str, Any] = {
        "collection": collection_name,
        "document_count": total_docs,
        "deep_structure_max_depth": max_depth,
        "field_profiles": _top_level_profile(path_profiles, total_docs),
        "deep_field_profiles": _flattened_profile(path_profiles, total_docs),
        "deepest_paths_top_3": _deep_paths(path_profiles, top_n=3),
        "sample_documents": sample_documents,
    }

    if full_documents is not None:
        result["all_documents"] = full_documents

    if severity_counter:
        result["severity_distribution"] = dict(severity_counter)
    if status_counter:
        result["status_distribution"] = dict(status_counter)
    if acknowledged_counter:
        result["acknowledgement_distribution"] = dict(acknowledged_counter)

    return result


def _resolve_collections(db: firestore.Client, config: AnalyzerConfig) -> tuple[str, ...]:
    if not config.all_collections:
        return config.collections
    names = tuple(sorted(collection.id for collection in db.collections()))
    if not names:
        raise FirestoreAnalyzerError("No top-level collections found in Firestore.")
    return names


def analyze_firestore(config: AnalyzerConfig) -> dict[str, Any]:
    _initialize_firestore(config.project_id, config.service_account_path)
    db = firestore.client()
    resolved_collections = _resolve_collections(db, config)

    started_at = dt.datetime.now(dt.timezone.utc)
    collections_output = []
    total_documents = 0

    for collection_name in resolved_collections:
        collection_report = _analyze_collection(
            db=db,
            collection_name=collection_name,
            sample_size=config.sample_size,
            max_depth=config.max_depth,
            include_all_documents=config.include_all_documents,
        )
        collections_output.append(collection_report)
        total_documents += collection_report["document_count"]

    ended_at = dt.datetime.now(dt.timezone.utc)

    return {
        "project_id": config.project_id,
        "database_id": config.database_id,
        "all_collections_mode": config.all_collections,
        "include_all_documents": config.include_all_documents,
        "max_depth": config.max_depth,
        "started_at": started_at.isoformat(),
        "finished_at": ended_at.isoformat(),
        "duration_seconds": round((ended_at - started_at).total_seconds(), 3),
        "collections_analyzed": len(resolved_collections),
        "total_documents_seen": total_documents,
        "collections": collections_output,
    }


def _comma_split(values: str) -> tuple[str, ...]:
    return tuple(v.strip() for v in values.split(",") if v.strip())


def _build_config(args: argparse.Namespace) -> AnalyzerConfig:
    service_account_path = (
        args.service_account
        or os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
        or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    )
    collections = _comma_split(args.collections)
    if not collections and not args.all_collections:
        raise FirestoreAnalyzerError(
            "At least one collection must be provided unless --all-collections is used."
        )
    if args.sample_size < 0:
        raise FirestoreAnalyzerError("--sample-size must be >= 0.")
    if args.max_depth < 1:
        raise FirestoreAnalyzerError("--max-depth must be >= 1.")

    return AnalyzerConfig(
        project_id=args.project_id,
        database_id=args.database_id,
        service_account_path=service_account_path,
        collections=collections,
        sample_size=args.sample_size,
        max_depth=args.max_depth,
        include_all_documents=args.include_all_documents,
        all_collections=args.all_collections,
    )


def _write_output(result: dict[str, Any], output_path: str | None, pretty: bool) -> None:
    indent = 2 if pretty else None
    payload = json.dumps(result, indent=indent, ensure_ascii=True)
    if output_path:
        path = Path(output_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload + "\n", encoding="utf-8")
        return
    print(payload)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Analyze Firestore SCADA collections.")
    parser.add_argument("--project-id", default="scadadataserver", help="Firebase project ID.")
    parser.add_argument("--database-id", default="(default)", help="Firestore database ID.")
    parser.add_argument(
        "--service-account",
        default=None,
        help="Path to service account JSON. Falls back to FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS.",
    )
    parser.add_argument(
        "--collections",
        default=",".join(DEFAULT_COLLECTIONS),
        help="Comma-separated collection list. Ignored when --all-collections is used.",
    )
    parser.add_argument("--all-collections", action="store_true", help="Analyze all top-level collections.")
    parser.add_argument("--sample-size", type=int, default=5, help="Sample docs per collection.")
    parser.add_argument("--max-depth", type=int, default=6, help="Maximum nested path depth to profile.")
    parser.add_argument(
        "--include-all-documents",
        action="store_true",
        help="Include every fetched document in output JSON.",
    )
    parser.add_argument("--output", default=None, help="Write output JSON file.")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output.")
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    try:
        config = _build_config(args)
        result = analyze_firestore(config)
        _write_output(result, args.output, args.pretty)
    except Exception as exc:
        print(f"ERROR: {exc}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
