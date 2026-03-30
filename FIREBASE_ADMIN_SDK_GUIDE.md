# 🔐 Firebase Admin SDK Setup Guide

## Overview

The Firebase Admin SDK allows server-side applications to interact with Firebase services with elevated privileges. This is perfect for the Windows Sync Service to sync local SQLite data to Firestore Cloud.

---

## ✅ What You Have

You have successfully generated:
- **Service Account Key**: `scadadataserver-firebase-adminsdk-fbsvc-717edd254a private key.json`
- **Project ID**: scadadataserver
- **Database URL**: https://scadadataserver-default-rtdb.firebaseio.com

---

## 🔐 Security - IMPORTANT!

### ⚠️ Never Commit Private Keys!

The service account key grants **FULL ADMIN ACCESS** to your Firebase project. Keep it secure!

### Already Protected:
✅ Added to `.gitignore`
✅ Excluded from version control
✅ Local file only

### Best Practices:
1. **Never** commit to Git
2. **Never** share publicly
3. **Never** include in client apps
4. Store securely on server only
5. Rotate keys regularly (every 90 days)

---

## 🚀 Usage

### 1. Seed Database

Import sample data to Firestore:

```powershell
# Install dependencies first
npm install

# Run seeding script
npm run seed
```

**What it does:**
- ✅ Connects using Admin SDK
- ✅ Creates collections in Firestore
- ✅ Imports 5 active alerts
- ✅ Imports 5 system status entries
- ✅ Imports 2 historical alerts
- ✅ Creates statistics and configuration

**Expected output:**
```
🔥 Firebase Cloud Firestore Import
===================================

📊 Importing Active Alerts...
✅ Imported 5 active alerts

📊 Importing System Status...
✅ Imported 5 system components

📊 Importing Historical Alerts...
✅ Imported 2 historical alerts

📊 Creating Statistics...
✅ Statistics created

📊 Creating Configuration...
✅ Configuration created

✨ Import completed successfully!
```

### 2. Start Cloud Sync Service

Continuously sync local SQLite alerts to Firestore:

```powershell
npm run sync
```

**What it does:**
- ✅ Connects to local SQLite database (`C:\ScadaAlarms\alerts.db`)
- ✅ Syncs active alerts to Firestore (every 5 seconds)
- ✅ Archives cleared alerts to history
- ✅ Updates system status with heartbeat
- ✅ Runs continuously until stopped (Ctrl+C)

**Expected output:**
```
🔄 Firebase Cloud Sync Service
==============================

🔥 Initializing Firebase Admin SDK...
✅ Firebase Admin SDK initialized
✅ Connected to local database

🚀 Starting Cloud Sync Service...
   Sync interval: 5s
   Local DB: C:\ScadaAlarms\alerts.db
   Firestore Project: scadadataserver

Press Ctrl+C to stop

📊 Syncing 5 active alerts...
✅ Sync complete: 5 alerts synced to Firestore
📚 Archiving 2 cleared alerts...
✅ Archived 2 cleared alerts

⏰ [10:30:15] Running sync cycle...
📊 Stats: Total synced: 5, Errors: 0
```

---

## 📦 Integration with Windows Sync Service

### Architecture

```
SCADA System
     ↓
Windows Sync Service (C#)
     ↓
SQLite Database (C:\ScadaAlarms\alerts.db)
     ↓
Cloud Sync Service (Node.js)
     ↓
Firebase Firestore Cloud
     ↓
Flutter Mobile/Web Apps
```

### How It Works

1. **Windows Sync Service** monitors SCADA system and writes to SQLite
2. **Cloud Sync Service** (Node.js) reads SQLite and syncs to Firestore
3. **Flutter Apps** read from Firestore with real-time updates

### Running Both Services

**Terminal 1: Windows Sync Service**
```powershell
cd ScadaWatcherService
.\ScadaWatcherService.exe
```

**Terminal 2: Cloud Sync Service**
```powershell
cd E:\scada_alarm_client
npm run sync
```

**Terminal 3: Flutter App**
```powershell
cd E:\scada_alarm_client
flutter run -d windows
```

---

## 🛠️ Configuration

### Sync Interval

Edit `firebase_cloud_sync_service.js`:

```javascript
const SYNC_INTERVAL_MS = 5000; // 5 seconds (default)
// Change to:
const SYNC_INTERVAL_MS = 10000; // 10 seconds
const SYNC_INTERVAL_MS = 30000; // 30 seconds
```

### Batch Size

```javascript
const BATCH_SIZE = 500; // Default
// For large datasets:
const BATCH_SIZE = 1000;
```

### Local Database Path

```javascript
const LOCAL_DB_PATH = 'C:\\ScadaAlarms\\alerts.db';
// Or custom path:
const LOCAL_DB_PATH = 'D:\\MyCustomPath\\alerts.db';
```

---

## 📊 Firestore Collections

### `alerts_active`
Active alerts synced from SQLite
- Automatically created/updated
- Indexed for fast queries
- Real-time updates to Flutter apps

### `alerts_history`
Cleared alerts archived for history
- 24-hour rolling archive
- Searchable historical data
- Includes cleared timestamp

### `system_status`
Service health monitoring
- Cloud Sync Service status
- Heartbeat every 5 seconds
- Sync statistics

---

## 🧪 Testing

### 1. Test Database Seeding

```powershell
# Seed database
npm run seed

# Verify in Firebase Console
start https://console.firebase.google.com/project/scadadataserver/firestore

# Check collections: alerts_active, alerts_history, system_status
```

### 2. Test Cloud Sync

```powershell
# Start sync service
npm run sync

# In another terminal, check SQLite
sqlite3 "C:\ScadaAlarms\alerts.db"
> SELECT * FROM Alerts WHERE IsActive = 1;

# Verify data appears in Firestore Console
```

### 3. Test Real-time Updates

```powershell
# Terminal 1: Run sync service
npm run sync

# Terminal 2: Run Flutter app
flutter run -d windows

# Terminal 3: Add alert to SQLite
# Watch it appear in Flutter app within 5 seconds
```

---

## 🐛 Troubleshooting

### Error: Service account key not found

```
❌ Service account key not found!
Expected at: E:\scada_alarm_client\scadadataserver-firebase-adminsdk-*.json
```

**Solution:**
1. Check file exists in project root
2. Verify filename matches pattern
3. Download new key from Firebase Console if needed

### Error: Local database not found

```
❌ Local database not found!
Expected: C:\ScadaAlarms\alerts.db
```

**Solution:**
1. Run Windows Sync Service first
2. Check database path is correct
3. Verify ScadaWatcherService created the database

### Error: Permission denied

```
Error: 7 PERMISSION_DENIED: Missing or insufficient permissions
```

**Solution:**
1. Check Firestore rules allow write access
2. Verify service account has correct permissions
3. Redeploy Firestore rules: `firebase deploy --only firestore:rules`

### Error: Module not found

```
Error: Cannot find module 'firebase-admin'
```

**Solution:**
```powershell
npm install
```

---

## 📈 Monitoring

### View Sync Stats

The sync service prints stats every cycle:

```
📊 Stats: Total synced: 1247, Errors: 0
```

### Check System Status in Firestore

```powershell
# Via Firebase Console
start https://console.firebase.google.com/project/scadadataserver/firestore/data/system_status/CloudSyncService

# Via CLI
firebase firestore:get system_status/CloudSyncService
```

### Monitor Logs

```powershell
# Run with verbose output
$env:DEBUG="*"
npm run sync
```

---

## 🔄 Deployment Scenarios

### Development (Local Testing)

```powershell
# Use local SQLite + Firestore
npm run sync
```

### Production (Server Deployment)

```powershell
# Install as Windows Service or run as background process

# Option 1: Using PM2
npm install -g pm2
pm2 start firebase_cloud_sync_service.js --name scada-cloud-sync
pm2 save
pm2 startup

# Option 2: Using Windows Service
# Use nssm.exe or similar to install as service
nssm install ScadaCloudSync "C:\Program Files\nodejs\node.exe" "E:\scada_alarm_client\firebase_cloud_sync_service.js"
nssm start ScadaCloudSync
```

---

## 📚 Admin SDK Features

### Available in Cloud Sync Service

✅ **Firestore**
- Read/Write with admin privileges
- Batch operations
- Server timestamps
- Transaction support

✅ **Authentication**
- Create/manage users
- Custom tokens
- Session management

✅ **Cloud Messaging**
- Send push notifications
- Topic management
- Device group messaging

✅ **Cloud Storage**
- Upload/download files
- Manage buckets
- Access control

### Example: Send Push Notification

Add to `firebase_cloud_sync_service.js`:

```javascript
async function sendCriticalAlertNotification(alert) {
  const message = {
    notification: {
      title: `🚨 Critical Alert: ${alert.name}`,
      body: alert.description
    },
    topic: 'critical_alerts'
  };

  try {
    await admin.messaging().send(message);
    console.log('📱 Push notification sent');
  } catch (error) {
    console.error('❌ Notification error:', error);
  }
}
```

---

## 🔐 Security Best Practices

### 1. Service Account Management

```powershell
# Generate new key (Firebase Console)
# Rotate keys every 90 days

# Delete old keys
# Firebase Console > Project Settings > Service Accounts > Manage Keys
```

### 2. Environment Variables

For production, use environment variables:

```javascript
// Instead of hardcoded path
const SERVICE_ACCOUNT_PATH = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
```

```powershell
# Set environment variable
$env:FIREBASE_SERVICE_ACCOUNT_PATH="C:\secure\service-account.json"
npm run sync
```

### 3. Firestore Security Rules

Ensure server-side sync doesn't bypass security:

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only allow server-side writes with admin SDK
    match /alerts_active/{alertId} {
      allow read: if true;
      allow write: if request.auth.token.admin == true;
    }
  }
}
```

---

## ✨ Next Steps

1. **Install dependencies**: `npm install`
2. **Seed database**: `npm run seed`
3. **Start sync service**: `npm run sync`
4. **Monitor Firestore Console**: Verify data appears
5. **Run Flutter app**: See real-time updates

---

## 🆘 Support

- **Firebase Admin SDK Docs**: https://firebase.google.com/docs/admin/setup
- **Firestore Admin API**: https://firebase.google.com/docs/firestore/server/libraries
- **Service Account Keys**: https://cloud.google.com/iam/docs/service-accounts

---

**Service Account**: scadadataserver-firebase-adminsdk-fbsvc  
**Project ID**: scadadataserver  
**Status**: ✅ Ready for Production
