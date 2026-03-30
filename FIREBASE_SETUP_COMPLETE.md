# 🔥 Firebase Setup Complete - Quick Start

## ✅ What Has Been Configured

### 1. Firebase Cloud Sync Service
**Location**: `lib/core/services/firebase_sync_service.dart`

Features:
- ✅ Real-time alert synchronization
- ✅ Offline data persistence  
- ✅ Automatic reconnection
- ✅ Push notifications (FCM)
- ✅ Device heartbeat monitoring (30s intervals)
- ✅ Multi-device sync
- ✅ Connection state management

### 2. Riverpod Providers
**Location**: `lib/data/providers/sync_provider.dart`

Providers created:
- `firebaseSyncServiceProvider` - Main sync service
- `syncStatusProvider` - Stream of sync status
- `isOnlineProvider` - Online/offline state

### 3. Firebase Rules Deployed
- ✅ **Firestore Rules**: `firestore.rules` - Deployed successfully
- ✅ **Firestore Indexes**: `firestore.indexes.json` - Deployed successfully
- ⚠️ **Storage Rules**: Need to enable Storage in Firebase Console first

### 4. Scripts Created

| Script | Purpose |
|--------|---------|
| `setup_firebase_complete.ps1` | Full Firebase deployment |
| `seed_firebase_cloud.ps1` | Generate seed data files |
| `firebase_import.js` | Import data to Firestore |
| `quick_setup.ps1` | One-command complete setup |
| `package.json` | Node.js dependencies |

---

## 🚀 How to Use

### Quick Start (Recommended)

```powershell
# Run one-command setup
.\quick_setup.ps1
```

This will:
1. Check prerequisites (Flutter, Firebase CLI, Node.js)
2. Authenticate with Firebase
3. Deploy rules and indexes
4. Install dependencies
5. Optionally seed database
6. Launch the app

### Manual Setup

```powershell
# 1. Deploy Firebase configuration
firebase use scadadataserver
firebase deploy --only firestore:rules,firestore:indexes

# 2. Install Flutter dependencies
flutter pub get

# 3. Install Node.js dependencies (for seeding)
npm install

# 4. Seed database (optional)
npm run seed

# 5. Run app
flutter run -d windows
```

---

## 📊 Firebase Collections

### `alerts_active`
Active SCADA alarms with real-time sync

```dart
{
  id: String,
  title: String,
  message: String,
  severity: 'Critical' | 'High' | 'Warning' | 'Info',
  isActive: bool,
  isAcknowledged: bool,
  raisedAt: Timestamp,
  acknowledgedAt?: Timestamp,
  acknowledgedBy?: String,
  // ... more fields
}
```

### `system_status`
Component health monitoring

```dart
{
  componentName: String,
  status: 'Online' | 'Offline' | 'Degraded',
  lastHeartbeat: Timestamp,
  version: String,
  metadata: Map<String, dynamic>
}
```

### `alerts_history`
Historical alarm data

```dart
{
  id: String,
  // ... same as alerts_active
  clearedAt: Timestamp,
  duration: int,
  archivedAt: Timestamp
}
```

---

## 🌐 Cloud Sync Features in App

### Using the Sync Service

```dart
// Watch sync status
final syncStatus = ref.watch(syncStatusProvider);

syncStatus.when(
  data: (status) {
    if (status.isOnline) {
      print('Online - Last sync: ${status.lastSync}');
    } else {
      print('Offline mode');
    }
  },
  loading: () => CircularProgressIndicator(),
  error: (err, _) => Text('Error: $err'),
);

// Check online state
final isOnline = ref.watch(isOnlineProvider);

// Access sync service directly
final syncService = ref.read(firebaseSyncServiceProvider);
await syncService.acknowledgeAlert('ALT001', 'operator_john');
```

### Real-time Alerts Stream

```dart
// Stream of active alerts (already implemented in repository)
final activeAlerts = ref.watch(activeAlertsProvider);
```

---

## 📱 Firebase Console Links

### Project: scadadataserver

- **Overview**: https://console.firebase.google.com/project/scadadataserver
- **Firestore**: https://console.firebase.google.com/project/scadadataserver/firestore
- **Cloud Messaging**: https://console.firebase.google.com/project/scadadataserver/notification
- **Storage**: https://console.firebase.google.com/project/scadadataserver/storage
- **Authentication**: https://console.firebase.google.com/project/scadadataserver/authentication

---

## 🔐 Security Rules

### Firestore Access Control

```javascript
// Active alerts - Public read, Operator write
match /alerts_active/{alertId} {
  allow read: if true;  // Public read for monitoring
  allow write: if isOperator();
}

// System status - Public read
match /system_status/{statusId} {
  allow read: if true;
  allow write: if isOperator();
}

// User data - Private
match /users/{userId} {
  allow read: if isAuthenticated() && 
              (request.auth.uid == userId || isAdmin());
}
```

---

## 🧪 Testing Cloud Sync

### 1. Real-time Sync Test

```powershell
# Terminal 1: Run app
flutter run -d windows

# Terminal 2 or Firebase Console: Update data
# In Firestore console, modify an alert
# App should update instantly
```

### 2. Offline Mode Test

```powershell
# 1. Run app and load data
# 2. Disconnect internet
# 3. Acknowledge an alert (should work offline)
# 4. Reconnect internet
# 5. Check console logs for sync confirmation
```

### 3. Push Notification Test

```powershell
# Via Firebase Console:
# 1. Go to Cloud Messaging
# 2. Create campaign > Send test message
# 3. Enter FCM token from app logs
# 4. Send notification
```

---

## 📦 Seed Sample Data

### Option 1: Node.js Script (Recommended)

```powershell
npm run seed
```

### Option 2: PowerShell Script

```powershell
.\seed_firebase_cloud.ps1
```

This creates JSON files that can be imported via Firebase Console.

### Sample Data Includes:
- 5 active alerts (Critical, High, Warning)
- 5 system components (all online)
- 2 historical alerts (cleared)
- Statistics overview
- Sync configuration

---

## 🔧 Troubleshooting

### Firebase Not Initialized

**Error**: `⚠️ Firebase initialization failed`

**Solution**:
```powershell
# Reconfigure Firebase
flutterfire configure --project=scadadataserver
```

### Storage Rules Failed

**Error**: `Firebase Storage has not been set up`

**Solution**:
1. Go to https://console.firebase.google.com/project/scadadataserver/storage
2. Click "Get Started"
3. Enable Storage
4. Run: `firebase deploy --only storage`

### Sync Service Not Working

**Error**: No real-time updates

**Solutions**:
1. Check internet connection
2. Verify Firestore rules deployed: `firebase deploy --only firestore:rules`
3. Check console for errors
4. Enable Firestore debug logging

### FCM Notifications Not Received

**Solutions**:
1. Check FCM token in console logs
2. Verify Windows notification permissions
3. Check Firebase Console > Cloud Messaging
4. Ensure `firebase_messaging` package is up to date

---

## 📚 Documentation

- **Complete Guide**: `FIREBASE_CLOUD_SYNC_GUIDE.md`
- **This Quick Start**: `FIREBASE_SETUP_COMPLETE.md`
- **Firebase Docs**: https://firebase.google.com/docs
- **FlutterFire Docs**: https://firebase.flutter.dev

---

## ✨ Features Ready to Use

### ✅ Implemented & Working

1. **Real-time Alerts Sync**
   - Stream-based updates
   - Automatic reconnection
   - Offline support

2. **System Status Monitoring**
   - Component health tracking
   - Heartbeat monitoring
   - Version tracking

3. **Alert Acknowledgment**
   - Cloud-synced acknowledgments
   - Comment support
   - User tracking

4. **Offline Mode**
   - Local data persistence
   - Queue-based sync
   - Automatic retry

5. **Push Notifications**
   - FCM integration
   - Background handler
   - Custom sounds support

### 🎯 Next Steps for Production

- [ ] Enable Firebase Authentication
- [ ] Set up Firebase App Check
- [ ] Configure backup schedule
- [ ] Enable Performance Monitoring
- [ ] Set up Crashlytics
- [ ] Configure production FCM
- [ ] Set budget alerts
- [ ] Review security rules for production

---

## 🆘 Need Help?

1. **Check Console Logs**: Look for Firebase errors
2. **Firebase Console**: Check service status
3. **Documentation**: See `FIREBASE_CLOUD_SYNC_GUIDE.md`
4. **Firebase Status**: https://status.firebase.google.com

---

**Project ID**: scadadataserver  
**Setup Date**: January 26, 2026  
**Version**: 1.2.0  
**Status**: ✅ Ready for Development
