#!/usr/bin/env python3
"""Windows service wrapper for periodic Firestore analysis."""

from __future__ import annotations

import datetime as dt
import json
import logging
import logging.handlers
from pathlib import Path
from typing import Any

import servicemanager
import win32event
import win32service
import win32serviceutil

from firestore_analyzer import AnalyzerConfig, FirestoreAnalyzerError, analyze_firestore


DEFAULT_CONFIG_PATH = Path(r"C:\SCADA\config\firestore_analyzer.json")
DEFAULT_LOG_PATH = Path(r"C:\SCADA\Logs\firestore_analysis_service.log")
DEFAULT_OUTPUT_PATH = Path(r"C:\SCADA\reports\firestore_analysis_latest.json")
DEFAULT_COLLECTIONS = (
    "alerts_active",
    "alerts_history",
    "client_heartbeats",
    "config",
    "device_tokens",
    "statistics",
    "system_status",
)


class ScadaFirestoreAnalysisService(win32serviceutil.ServiceFramework):
    _svc_name_ = "ScadaFirestoreAnalysisService"
    _svc_display_name_ = "SCADA Firestore Analysis Service"
    _svc_description_ = (
        "Analyzes Firestore collections for SCADA telemetry and writes periodic JSON reports."
    )

    def __init__(self, args: list[str]) -> None:
        super().__init__(args)
        self.stop_event = win32event.CreateEvent(None, 0, 0, None)
        self.logger = _build_logger(DEFAULT_LOG_PATH)
        self.interval_seconds = 60
        self.output_path = DEFAULT_OUTPUT_PATH
        self.analyzer_config = AnalyzerConfig(
            project_id="scadadataserver",
            database_id="(default)",
            service_account_path=None,
            collections=DEFAULT_COLLECTIONS,
            sample_size=5,
            max_depth=6,
            include_all_documents=False,
            all_collections=False,
        )

    def SvcStop(self) -> None:
        self.logger.info("Stop requested.")
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.stop_event)

    def SvcDoRun(self) -> None:
        servicemanager.LogInfoMsg(f"{self._svc_name_} starting")
        self.logger.info("Service starting")
        try:
            self._load_config()
            self._run_loop()
        except Exception as exc:
            self.logger.exception("Service failed: %s", exc)
            raise
        finally:
            self.logger.info("Service stopped")
            servicemanager.LogInfoMsg(f"{self._svc_name_} stopped")

    def _run_loop(self) -> None:
        self._execute_analysis_cycle()
        while True:
            wait_result = win32event.WaitForSingleObject(
                self.stop_event, self.interval_seconds * 1000
            )
            if wait_result == win32event.WAIT_OBJECT_0:
                break

            self._execute_analysis_cycle()

    def _execute_analysis_cycle(self) -> None:
        started_at = dt.datetime.now(dt.timezone.utc)
        self.logger.info("Starting Firestore analysis cycle")
        try:
            report = analyze_firestore(self.analyzer_config)
            self.output_path.parent.mkdir(parents=True, exist_ok=True)
            self.output_path.write_text(
                json.dumps(report, indent=2, ensure_ascii=True) + "\n",
                encoding="utf-8",
            )
            elapsed = dt.datetime.now(dt.timezone.utc) - started_at
            self.logger.info(
                "Analysis completed: %s collections, %s docs, %.3fs",
                report.get("collections_analyzed"),
                report.get("total_documents_seen"),
                elapsed.total_seconds(),
            )
        except Exception as exc:
            self.logger.exception("Analysis cycle failed: %s", exc)

    def _load_config(self) -> None:
        if not DEFAULT_CONFIG_PATH.is_file():
            raise FirestoreAnalyzerError(
                f"Config not found at {DEFAULT_CONFIG_PATH}. "
                "Copy firestore_analyzer.config.example.json to this path and update it."
            )

        raw = json.loads(DEFAULT_CONFIG_PATH.read_text(encoding="utf-8"))
        collections = tuple(raw.get("collections", DEFAULT_COLLECTIONS))
        all_collections = bool(raw.get("all_collections", False))
        if not collections and not all_collections:
            raise FirestoreAnalyzerError("Config 'collections' cannot be empty.")

        self.interval_seconds = int(raw.get("interval_seconds", 60))
        if self.interval_seconds < 5:
            raise FirestoreAnalyzerError("Config 'interval_seconds' must be >= 5.")

        configured_log_path = Path(raw.get("log_path", str(DEFAULT_LOG_PATH)))
        self.logger = _build_logger(configured_log_path)
        self.output_path = Path(raw.get("output_path", str(DEFAULT_OUTPUT_PATH)))
        self.analyzer_config = AnalyzerConfig(
            project_id=raw.get("project_id", "scadadataserver"),
            database_id=raw.get("database_id", "(default)"),
            service_account_path=raw.get("service_account_path"),
            collections=collections,
            sample_size=int(raw.get("sample_size", 5)),
            max_depth=int(raw.get("max_depth", 6)),
            include_all_documents=bool(raw.get("include_all_documents", False)),
            all_collections=all_collections,
        )
        self.logger.info(
            "Loaded config: project=%s database=%s interval=%ss output=%s depth=%s all_collections=%s include_all_documents=%s",
            self.analyzer_config.project_id,
            self.analyzer_config.database_id,
            self.interval_seconds,
            self.output_path,
            self.analyzer_config.max_depth,
            self.analyzer_config.all_collections,
            self.analyzer_config.include_all_documents,
        )


def _build_logger(log_path: Path) -> logging.Logger:
    logger = logging.getLogger("scada_firestore_analysis_service")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()

    log_path.parent.mkdir(parents=True, exist_ok=True)
    handler = logging.handlers.RotatingFileHandler(
        log_path, maxBytes=2_000_000, backupCount=5, encoding="utf-8"
    )
    formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    return logger


if __name__ == "__main__":
    win32serviceutil.HandleCommandLine(ScadaFirestoreAnalysisService)
