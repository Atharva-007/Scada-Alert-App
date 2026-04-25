# SCADA Alarm Client

A modern, high-performance Flutter application designed for industrial operators to monitor SCADA (Supervisory Control and Data Acquisition) alarms in real-time. This client connects to a Firebase backend to synchronize active and historical alarms with seamless offline support.

## Features

- **Real-Time Monitoring:** Live updates of active critical, warning, and informational alarms.
- **High-Performance UI:** Built with CustomScrollViews and Slivers for buttery-smooth 60/120fps scrolling.
- **Offline Resilience:** Complete offline caching and synchronization when connectivity is restored.
- **Advanced Filtering:** Instantly filter alerts by severity, acknowledgment status, and date ranges.
- **Deep Diagnostics:** Detailed metrics including trigger values, thresholds, condition states, and equipment sources.
- **Dark Industrial Theme:** A high-contrast, modern UI optimized for readability in varied industrial environments.
- **Haptic & Audio Feedback:** Integrated feedback for critical alerts and interactions.

## Architecture

The project follows a clean, feature-first architecture using Riverpod for state management:

- `lib/core/`: Application-wide services, themes, widgets, and utilities.
- `lib/data/`: Data models (Freezed), Firestore integration, and repositories.
- `lib/features/`: Isolated feature modules (`alerts`, `dashboard`, `history`, `settings`).

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.8.1+)
- Android Studio / Xcode (for mobile deployment)
- Firebase Project configured for Flutter

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd scada_alarm_client
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Code Generation** (If modifying Freezed models)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Firebase Configuration**
   Ensure your `firebase_options.dart` and `google-services.json` are properly configured for your specific Firebase instance.

5. **Run the application**
   ```bash
   flutter run
   ```

## Design System

The application utilizes a dark "Glassmorphism" aesthetic with specific semantic colors:
- **Critical:** `#EF5350` (Red)
- **Warning:** `#FFA726` (Orange)
- **Info:** `#42A5F5` (Blue)
- **Normal/Resolved:** `#66BB6A` (Green)
- **Surfaces:** Deep grays and true blacks (`#0F0F0F`, `#1A1A1A`)

## Firestore CLI Analysis + Windows Service (Python)

Python tooling is available in `windows_sync_service\python` for analyzing Firestore data in `scadadataserver` and running periodic analysis as a Windows service.

### One-time CLI analysis

```powershell
python windows_sync_service\python\firestore_analyzer.py `
  --project-id scadadataserver `
  --database-id "(default)" `
  --service-account C:\SCADA\firebase-service-account.json `
  --all-collections `
  --max-depth 8 `
  --include-all-documents `
  --output C:\SCADA\reports\firestore_full_analysis.json `
  --pretty
```

This deep report includes:
- top-level and deep nested field paths (`deep_field_profiles`)
- inferred constraints per path (required/nullability/enum candidates/ranges)
- top 3 deepest structural paths per collection
- full document export when `--include-all-documents` is used

### Install Windows service

```powershell
powershell -ExecutionPolicy Bypass -File windows_sync_service\python\install_scada_firestore_service.ps1 -StartService
```

This creates/uses config at `C:\SCADA\config\firestore_analyzer.json`. Update `service_account_path` there before first run.

### Uninstall Windows service

```powershell
powershell -ExecutionPolicy Bypass -File windows_sync_service\python\uninstall_scada_firestore_service.ps1
```

## Future Roadmap & Technical Debt

Based on the deep architectural audit and data-integrity check completed in April 2026, the following items are prioritized for future implementation:

### 1. Security & Access Control
- **RBAC Enforcement:** Transition Firestore and Storage rules from "Development Mode" to production-grade Role-Based Access Control. Implement the predefined `isAdmin`, `isOperator`, and `isAuthenticated` logic.
- **Audit Logging:** Fully enable the `acknowledgment_logs` collection to track all supervisor actions for regulatory compliance (ISA-18.2).

### 2. Industrial Protocol Expansion
- **Native OPC UA Integration:** While the C# `ScadaWatcherService` provides a framework, full native integration with industrial PLCs via OPC UA or Modbus TCP is slated for the next phase to replace the current file-watcher dependency.
- **Historian Activation:** Enable the SQLite-backed `SqliteHistorianService` in `appsettings.json` to allow for local sub-second data persistence during cloud outages.

### 3. Architectural Optimizations
- **Edge-to-Cloud Sync:** Refactor the Node.js middleware to handle bidirectional stream buffering, ensuring that high-frequency industrial data does not exceed Firebase's write quotas.
- **Trend Visualization:** Leverage the `trendData` field in `AlertModel` to implement sparklines and historical graphs directly in the Alert Details screen.
- **Canonical Schema Enforcement:** Complete the removal of legacy `snake_case` field fallbacks in any remaining secondary modules to maintain 100% `camelCase` consistency across the stack.

### 4. Reliability & Testing
- **Automated Lifecycle Tests:** Implement integration tests for the `enforce_alert_lifecycle.mjs` script to prevent "zombie" alerts from reappearing during mass data migrations.
- **Heartbeat Monitoring:** Expand the `client_heartbeats` logic to include system-level metrics (CPU/RAM usage) for the Windows Sync Service.

---

## License

Copyright © 2026. All Rights Reserved.
