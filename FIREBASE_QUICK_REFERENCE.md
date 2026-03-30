# 🚀 Firebase Cloud Sync - Quick Command Reference

## 🎯 Quick Start

```powershell
# One-command setup
.\quick_setup.ps1

# Or manual
flutter pub get
npm install
flutter run -d windows
```

---

## 📦 Firebase Commands

### Deploy Configuration
```powershell
# Deploy everything
firebase deploy

# Deploy Firestore rules only
firebase deploy --only firestore:rules

# Deploy Firestore indexes
firebase deploy --only firestore:indexes

# Deploy Storage rules
firebase deploy --only storage

# Deploy specific items
firebase deploy --only firestore:rules,firestore:indexes,storage
```

### Project Management
```powershell
# List projects
firebase projects:list

# Select project
firebase use scadadataserver

# Check current project
firebase use
```

### Database Operations
```powershell
# Seed database
npm run seed

# View Firestore data
firebase firestore:get alerts_active/ALT001

# List collections
firebase firestore:collections
```

---

## 🛠️ Flutter Commands

```powershell
# Get dependencies
flutter pub get

# Run on Windows
flutter run -d windows

# Build release
flutter build windows --release

# Analyze code
flutter analyze

# Check for issues
flutter doctor
```

---

## 📊 Monitoring Commands

```powershell
# Open Firebase Console
start https://console.firebase.google.com/project/scadadataserver

# Open Firestore
start https://console.firebase.google.com/project/scadadataserver/firestore

# Open Cloud Messaging
start https://console.firebase.google.com/project/scadadataserver/notification

# Open Storage
start https://console.firebase.google.com/project/scadadataserver/storage
```

---

## 🧪 Testing

```powershell
# Test Firebase connection
firebase projects:list

# Test FlutterFire config
flutter pub get
flutter analyze lib/firebase_options.dart

# Test app compilation
flutter build windows --debug
```

---

## 🔧 Troubleshooting

```powershell
# Reset Firebase CLI
firebase logout
firebase login

# Reconfigure FlutterFire
flutterfire configure --project=scadadataserver

# Clean Flutter
flutter clean
flutter pub get

# Reinstall Node packages
rm -r node_modules
npm install
```

---

## 📝 Common Tasks

### Add New Alert
```dart
final syncService = ref.read(firebaseSyncServiceProvider);
// Alert added via Windows Sync Service
// Automatically synced to Firestore
```

### Acknowledge Alert
```dart
await syncService.acknowledgeAlert(
  'ALT001',
  'operator_name',
  comment: 'Resolved issue',
);
```

### Check Sync Status
```dart
final isOnline = ref.watch(isOnlineProvider);
final syncStatus = ref.watch(syncStatusProvider);
```

### Watch Real-time Data
```dart
// Alerts stream (already in repository)
final alerts = ref.watch(activeAlertsProvider);

// System status stream
final status = ref.watch(systemStatusProvider);
```

---

## 🔐 Security Commands

```powershell
# Test Firestore rules
firebase emulators:start --only firestore

# Validate rules
firebase deploy --only firestore:rules --dry-run
```

---

## 📁 Important Files

| File | Purpose |
|------|---------|
| `firebase.json` | Firebase project config |
| `firestore.rules` | Security rules |
| `firestore.indexes.json` | Query indexes |
| `storage.rules` | Storage security |
| `lib/firebase_options.dart` | Flutter Firebase config |
| `lib/core/services/firebase_sync_service.dart` | Sync service |
| `lib/data/providers/sync_provider.dart` | Riverpod providers |

---

## 🌐 URLs

- **Console**: https://console.firebase.google.com/project/scadadataserver
- **Firestore**: https://console.firebase.google.com/project/scadadataserver/firestore
- **FCM**: https://console.firebase.google.com/project/scadadataserver/notification
- **Storage**: https://console.firebase.google.com/project/scadadataserver/storage
- **Auth**: https://console.firebase.google.com/project/scadadataserver/authentication
- **Status**: https://status.firebase.google.com

---

## 💡 Tips

1. **Use quick_setup.ps1** for fastest setup
2. **Monitor Firebase Console** during development
3. **Test offline mode** by disconnecting internet
4. **Check console logs** for sync status
5. **Enable Storage** in Firebase Console before using

---

## ✅ Checklist

### First Time Setup
- [ ] Run `.\quick_setup.ps1`
- [ ] Enable Storage in Firebase Console
- [ ] Verify Firestore rules deployed
- [ ] Test app runs successfully
- [ ] Check sync logs in console

### Daily Development
- [ ] Check Firebase Console for errors
- [ ] Monitor sync status in app
- [ ] Test offline functionality
- [ ] Review security rules regularly

---

**Project**: scadadataserver  
**Version**: 1.2.0  
**Status**: ✅ Ready
