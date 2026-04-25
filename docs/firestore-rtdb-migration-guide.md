# Firestore to Realtime Database Migration

This repo now includes a deterministic migration flow that:

- recursively walks Firestore collections and subcollections
- writes a raw Firestore export with typed field payloads
- infers a full schema plus a January 26 baseline schema
- normalizes all documents to the January 26 baseline when baseline documents exist for that collection
- transforms the normalized data into a Realtime Database JSON tree
- optionally imports the transformed tree into Realtime Database
- includes an optional live-sync script for ongoing mirroring

## Files

- `scripts/firestore_to_rtdb_migration.mjs`
- `scripts/firestore_to_rtdb_sync.mjs`
- `migration_output/firestore_full_export.json`
- `migration_output/firestore_schema.json`
- `migration_output/normalized_firestore.json`
- `migration_output/realtime_db_ready.json`
- `migration_output/firebase_cli_commands.txt`

## Authentication Modes

The migration script supports two runtime auth paths:

1. Service account JSON
2. Existing `firebase login` session token

Service account auth is the more reliable option for large exports and automated runs.

## Recommended Execution

1. Install Node dependencies so the local Firebase CLI is available if you want CLI-assisted project switching or import.

```powershell
npm install
```

2. Authenticate.

Service account option:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\firebase-service-account.json"
```

Firebase CLI option:

```powershell
firebase login
firebase projects:list
```

3. Run the export + schema inference + transform step.

```powershell
node scripts/firestore_to_rtdb_migration.mjs `
  --source-project-id scadadaralert `
  --source-candidates scadadataserver,alert-systems-db `
  --baseline-month-day 01-26 `
  --target-project-id scadadataserver `
  --target-database-url https://scadadataserver-default-rtdb.firebaseio.com `
  --service-account C:\path\to\firebase-service-account.json `
  --out-dir migration_output
```

If `scadadaralert` is inaccessible, the script automatically tries the next accessible candidate in `--source-candidates` and then any Firebase CLI-visible projects.

4. Import the transformed payload.

Manual CLI import:

```powershell
firebase database:set / migration_output/realtime_db_ready.json --project scadadataserver
```

Depending on your Firebase CLI build, `database:set` may prompt interactively.
If you want a noninteractive path, use the migration tool itself to perform the REST import:

```powershell
node scripts/firestore_to_rtdb_migration.mjs `
  --source-project-id scadadaralert `
  --source-candidates scadadataserver,alert-systems-db `
  --baseline-month-day 01-26 `
  --target-project-id scadadataserver `
  --target-database-url https://scadadataserver-default-rtdb.firebaseio.com `
  --service-account C:\path\to\firebase-service-account.json `
  --import-method rest `
  --execute-import
```

Or let the migration script do it:

```powershell
node scripts/firestore_to_rtdb_migration.mjs `
  --source-project-id scadadaralert `
  --source-candidates scadadataserver,alert-systems-db `
  --baseline-month-day 01-26 `
  --target-project-id scadadataserver `
  --target-database-url https://scadadataserver-default-rtdb.firebaseio.com `
  --service-account C:\path\to\firebase-service-account.json `
  --import-method cli `
  --execute-import
```

Use `--import-method rest` if you want to bypass the CLI and write through the Realtime Database REST API.

## Output Format Notes

### `firestore_full_export.json`

- preserves Firestore field names exactly
- stores raw typed Firestore field objects in `fields`
- preserves subcollections recursively in `subcollections`

### `firestore_schema.json`

- groups collections by path pattern
- reports document counts
- includes both full-database and January 26 baseline field statistics
- marks fields as required when present in every document in the relevant sample set
- records repeated structure signatures
- records which timestamp fields were used to detect the baseline set

### `normalized_firestore.json`

- stores decoded JSON values, not Firestore typed wrappers
- ensures all fields observed in January 26 baseline documents exist in every document of that collection pattern
- fills missing scalar fields with `null`
- fills missing arrays with `[]`
- fills missing maps recursively using baseline keys

### `realtime_db_ready.json`

- converts top-level collections to top-level Realtime Database nodes
- uses document IDs as child keys
- keeps document fields as normal JSON values
- stores nested Firestore subcollections under `__subcollections` to avoid field-name collisions
- contains only the import payload, so it can be passed directly to `firebase database:set`

## Continuous Sync

The live sync script requires installed dependencies and a service account:

```powershell
node scripts/firestore_to_rtdb_sync.mjs `
  --source-project-id scadadataserver `
  --target-database-url https://scadadataserver-default-rtdb.firebaseio.com `
  --service-account C:\path\to\firebase-service-account.json `
  --verbose
```

This script attaches snapshot listeners to discovered collections and mirrors creates, updates, and deletes into Realtime Database.

## Notes and Constraints

- Firestore integers larger than JavaScript safe integers are preserved as strings by default in the transformed Realtime DB payload. Use `--integer-overflow-mode number` only if you accept precision loss.
- The migration script paginates Firestore document reads with `--batch-size`.
- The raw export is the zero-loss artifact. Use it as the audit record if any downstream transformation needs to be replayed.
- The baseline selector uses `MM-DD` matching in UTC. `01-26` means January 26 UTC across all years present in the source data.
- Collections without any January 26 baseline documents are exported unchanged; they are not padded with invented fields.
- Realtime Database does not persist keys whose value is `null`. After import, those normalized placeholder fields disappear from the live RTDB tree even though the logical document structure remains equivalent.
