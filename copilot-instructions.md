# Copilot Instructions - SCADA Alarm Monitor

## Project Overview

**Industrial-grade Flutter mobile & desktop application for SCADA alarm monitoring with complete Firebase cloud backend integration.**

- **Package**: `com.scada.alarm_monitor`
- **Platforms**: Android (tablet + phone), Windows Desktop
- **Version**: 1.2.0
- **Status**: Production-ready with complete Firebase backend & cloud sync

## Core Purpose & Constraints

### What This App Does
- **Read-only monitoring** of industrial SCADA alarms
- **Acknowledgment only** - operators can acknowledge alerts
- **Real-time sync** with Firebase Firestore backend
- **Safety-critical** - prevents accidental equipment control

### Critical Safety Rules
✅ **CAN DO**: View alerts, acknowledge alerts, export data, view analytics  
❌ **CANNOT DO**: Clear/dismiss alerts, control equipment, modify SCADA data

**Why**: This is a monitoring-only client. Alert clearing must happen through the SCADA system backend.

## Architecture & Patterns

### Clean Architecture + MVVM
```
lib/
├── core/              # Shared resources (theme, widgets, utils)
├── features/          # Feature modules (dashboard, alerts, history, analytics, etc.)
├── data/              # Models, repositories, Firestore abstraction
└── main.dart
```

### State Management: Riverpod
- **Why Riverpod?** Compile-time safety, stream-based real-time updates, better testability
- Use `flutter_riverpod` for all state management
- Use `riverpod_annotation` with code generation
- Prefer `StreamProvider` for Firebase real-time data

### Key Design Principles
1. **Industrial UX First**: Dark mode, high contrast, large tap targets (48dp+), glove-friendly
2. **Zero Distractions**: No unnecessary animations, no hidden gestures
3. **Safety-Critical**: Confirmation dialogs for actions, prevent accidental taps
4. **Responsive**: Navigation Rail (tablet) / Bottom Nav (phone)
5. **Offline-First**: Graceful degradation when Firebase unavailable

## Technology Stack

### Core Dependencies
- **Firebase Suite**: `firebase_core`, `cloud_firestore`, `firebase_messaging`, `firebase_storage`, `firebase_auth`
- **State Management**: `flutter_riverpod`, `riverpod_annotation`
- **UI**: `shimmer`, `animated_text_kit`, `lottie`, `flutter_animate`
- **Utils**: `intl`, `freezed_annotation`, `json_annotation`, `path_provider`, `share_plus`
- **Connectivity**: `connectivity_plus`
- **Notifications**: `flutter_local_notifications`

### Code Generation
- **Freezed**: Immutable data models
- **JSON Serializable**: JSON serialization
- **Riverpod Generator**: Provider code generation

Run code generation:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Firebase Integration

### Firebase Project: `scadadataserver`

### Collections Schema
```
/alerts/{alertId}
  - id: string
  - name: string
  - source: string
  - severity: "Critical" | "Warning" | "Info"
  - timestamp: Timestamp
  - isActive: boolean
  - isAcknowledged: boolean
  - acknowledgedBy: string?
  - acknowledgedAt: Timestamp?
  - description: string
  - tagName: string

/system_health/{componentId}
  - componentName: string
  - status: "online" | "offline" | "degraded"
  - lastUpdate: Timestamp

/users/{userId}
  - email: string
  - role: "admin" | "operator" | "guest"
  - displayName: string
```

### Firebase Services
- **Firestore**: Real-time alert sync
- **Authentication**: Email/Password + Anonymous for guests
- **Cloud Messaging**: Push notifications for critical alerts
- **Cloud Storage**: File uploads/downloads
- **Security Rules**: Already deployed (`firestore.rules`, `storage.rules`)

### Offline Behavior
- App works offline with cached Firestore data
- Falls back to mock data during development if Firebase unavailable
- Windows Sync Service syncs SQLite → Firebase every 5 seconds

## Key Features

### 1. Dashboard
- Summary cards: active alerts, critical count, acknowledgment rate
- System health status indicators
- Real-time statistics

### 2. Active Alerts
- Real-time Firestore stream
- Pull-to-refresh
- Filter by severity (All, Critical, Warning, Info)
- Search functionality
- Haptic feedback on interaction
- Acknowledge with confirmation dialog

### 3. Alert History
- Paginated historical view
- Search across all fields
- Export to CSV/JSON

### 4. Analytics Dashboard
- Real-time statistics & metrics
- Acknowledgment rate tracking
- Average response time
- Alert source breakdown
- 24-hour trend visualization

### 5. System Health
- Monitor OPC UA, Historian, Alert Engine, Firebase connectivity
- Real-time status updates

### 6. Export & Reporting
- Export to CSV/JSON
- Generate shift reports
- Share functionality

### 7. Push Notifications
- Firebase Cloud Messaging integration
- Severity-based topic subscriptions
- Background message handling
- Custom notification channels

### 8. Alert Feedback
- Severity-specific haptic patterns (Critical: double heavy, Warning: single medium, Info: light)
- Mute/unmute controls

## Windows Sync Service

**Location**: `windows_sync_service/`

### Purpose
Background Windows service that syncs SQLite database to Firebase Firestore every 5 seconds.

### Key Features
- Real-time bidirectional sync (SQLite ↔ Firebase)
- Automatic push notifications for critical alerts
- Auto-escalation of unacknowledged alerts
- Self-healing & retry mechanisms
- Comprehensive logging

### Installation
```bash
cd windows_sync_service
.\install_service.bat  # Run as Administrator
```

### Service Configuration
- **Service Name**: `ScadaAlarmSyncService`
- **Sync Interval**: 5 seconds
- **Database**: `C:\ScadaAlarms\alarms.db`
- **Firebase Credentials**: `C:\ScadaAlarms\firebase-service-account.json`

## Development Guidelines

### Code Style
- Use **Dart 3** features (records, pattern matching, sealed classes)
- Follow **Flutter style guide** (dartfmt, lints)
- Use `freezed` for immutable models
- Use `riverpod_annotation` for providers
- Minimal comments (self-documenting code preferred)

### Widget Guidelines
1. **Industrial UX**: Large touch targets, high contrast, clear labels
2. **Accessibility**: WCAG AA compliance, screen reader support
3. **Responsiveness**: Test on tablet (10"+) and phone (6")
4. **Performance**: Lazy loading, pagination, efficient streams

### State Management Patterns
```dart
// Use StreamProvider for real-time Firestore data
@riverpod
Stream<List<Alert>> activeAlerts(ActiveAlertsRef ref) {
  return FirebaseFirestore.instance
      .collection('alerts')
      .where('isActive', isEqualTo: true)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Alert.fromJson(doc.data())).toList());
}

// Use FutureProvider for one-time data fetches
@riverpod
Future<SystemHealth> systemHealth(SystemHealthRef ref) async {
  final doc = await FirebaseFirestore.instance.collection('system_health').doc('main').get();
  return SystemHealth.fromJson(doc.data()!);
}
```

### Error Handling
- Always handle Firebase errors gracefully
- Show user-friendly error messages
- Log errors to console with context
- Provide retry mechanisms
- Never crash the app

### Testing Strategy
- Unit tests for business logic
- Widget tests for UI components
- Integration tests for Firebase flows
- Manual testing on real devices (tablet + phone)

## Common Tasks

### Adding a New Feature
1. Create feature directory in `lib/features/`
2. Add models in `lib/data/models/`
3. Create repository in `lib/data/repositories/`
4. Add providers with Riverpod
5. Build UI screens with industrial design
6. Update navigation

### Modifying Alert Flow
⚠️ **WARNING**: Alert acknowledgment is safety-critical
- Always add confirmation dialogs
- Never auto-acknowledge
- Sync to Firebase immediately
- Log all actions
- Test thoroughly

### Updating Firebase Schema
1. Update Firestore security rules
2. Deploy rules: `firebase deploy --only firestore:rules`
3. Update Dart models
4. Run code generation
5. Update Windows Sync Service schema
6. Test migration path

### Adding Push Notifications
1. Update topic subscriptions in `NotificationService`
2. Handle message payloads in `firebase_messaging` handlers
3. Test foreground/background scenarios
4. Configure notification channels

## Deployment Checklist

### Pre-Deployment
- [ ] Run `flutter analyze` (zero issues)
- [ ] Run `flutter test` (all tests passing)
- [ ] Test on real Android device
- [ ] Test on Windows desktop
- [ ] Verify Firebase connectivity
- [ ] Check Windows Sync Service status
- [ ] Test push notifications
- [ ] Verify security rules

### Build Commands
```bash
# Android Release
flutter build apk --release
flutter build appbundle --release

# Windows Release
flutter build windows --release
```

### Firebase Deployment
```bash
firebase deploy --only firestore:rules,storage:rules --project scadadataserver
```

## Troubleshooting

### Firebase Connection Issues
- Check `google-services.json` exists in `android/app/`
- Verify Firebase project ID: `scadadataserver`
- Check internet connectivity
- Review Firestore security rules
- Check Firebase Console logs

### Windows Sync Service Issues
- Verify service is running: `sc query ScadaAlarmSyncService`
- Check logs: `C:\ScadaAlarms\logs\`
- Verify Firebase credentials path
- Restart service: `sc stop ScadaAlarmSyncService && sc start ScadaAlarmSyncService`

### Build Issues
- Clean build: `flutter clean && flutter pub get`
- Regenerate code: `flutter pub run build_runner build --delete-conflicting-outputs`
- Update dependencies: `flutter pub upgrade`
- Check Flutter/Dart SDK versions

## Documentation

### Key Documents
- `README.md` - Quick start guide
- `FIREBASE_CLOUD_BACKEND_COMPLETE.md` - Complete Firebase setup (400+ lines)
- `FIREBASE_SETUP.md` - Firebase integration guide
- `ACTIVE_ALERTS_IMPROVEMENTS.md` - Active Alerts enhancements
- `IMPROVEMENTS_IMPLEMENTED.md` - v1.1.0 features
- `DEPLOYMENT_CHECKLIST.md` - Pre-deployment checklist
- `QUICK_REFERENCE.md` - Command reference

### PowerShell Scripts
- `quick_setup.ps1` - Automated project setup
- `seed_firebase_cloud.ps1` - Seed Firebase with test data
- `generate_test_alarms.ps1` - Generate test alarms
- `verify_firebase_setup.bat` - Verify Firebase configuration
- `deploy_got_alarms.ps1` - Deploy to GOT_Alarms

## Important Reminders

1. **Safety First**: This is a monitoring-only app. Never add features that control equipment.
2. **Industrial UX**: Large tap targets, high contrast, zero distractions.
3. **Firebase-First**: All data flows through Firebase Firestore for real-time sync.
4. **Offline Support**: App must work with cached data when offline.
5. **Confirmation Dialogs**: Always confirm safety-critical actions (acknowledgment).
6. **Testing**: Test on real devices, not just emulators.
7. **Documentation**: Update docs when adding features.

## Contact & Support

- **Firebase Project**: https://console.firebase.google.com/project/scadadataserver
- **Package Name**: `com.scada.alarm_monitor`
- **Project Location**: `E:\scada_alarm_client`

---

**Built for industrial operators. Read-only monitoring. Acknowledge only. Zero equipment control.**
