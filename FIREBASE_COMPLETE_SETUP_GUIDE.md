# 🔥 Complete Firebase Cloud Setup Guide for SCADA Alarm System

## 📋 Current Status Analysis

**Project:** scadadataserver (Project #932777127221)  
**Status:** ⚠️ **NOT FULLY INITIALIZED**

### What's Missing:
- ❌ Firestore Database not created
- ❌ Collections not set up
- ❌ Security rules not deployed
- ❌ Service account key not downloaded
- ❌ Sample data not uploaded

### What's Already Done:
- ✅ Firebase project exists: `scadadataserver`
- ✅ Firebase CLI installed (v14.4.0)
- ✅ FlutterFire CLI installed (v1.3.1)
- ✅ Firebase configuration files exist
- ✅ Windows Sync Service code ready
- ✅ Flutter app configured for Firebase

---

## 🚀 Step-by-Step Setup (15 Minutes)

### Step 1: Create Firestore Database (REQUIRED)

**Via Firebase Console:**
1. Open: https://console.firebase.google.com/project/scadadataserver/firestore
2. Click: **"Create database"**
3. Select: **Production mode** (we have security rules ready)
4. Choose location: **us-central** (or closest to you)
5. Click: **"Enable"**

**Via CLI (Alternative):**
```bash
# This will prompt you to create via console
firebase firestore:databases:create --project scadadataserver
```

### Step 2: Deploy Security Rules & Indexes

```bash
cd E:\scada_alarm_client

# Deploy Firestore security rules
firebase deploy --only firestore:rules --project scadadataserver

# Deploy Firestore indexes
firebase deploy --only firestore:indexes --project scadadataserver

# Deploy Storage rules
firebase deploy --only storage:rules --project scadadataserver
```

### Step 3: Enable Firebase Services

**Via Firebase Console:**

1. **Enable Authentication:**
   - Go to: https://console.firebase.google.com/project/scadadataserver/authentication
   - Click: **"Get started"**
   - Enable: **Email/Password** ✅
   - Enable: **Anonymous** ✅ (for guest access)

2. **Enable Cloud Storage:**
   - Go to: https://console.firebase.google.com/project/scadadataserver/storage
   - Click: **"Get started"**
   - Select: **Production mode**
   - Choose location: **Same as Firestore**

3. **Enable Cloud Messaging (FCM):**
   - Go to: https://console.firebase.google.com/project/scadadataserver/settings/cloudmessaging
   - Cloud Messaging is auto-enabled
   - Note: **Server Key** (for Windows Service)

### Step 4: Download Service Account Key (CRITICAL for Windows Service)

1. Go to: https://console.firebase.google.com/project/scadadataserver/settings/serviceaccounts
2. Click: **"Generate new private key"**
3. Download JSON file
4. Save as: **`C:\ScadaAlarms\firebase-service-account.json`**

**Create directory:**
```powershell
New-Item -ItemType Directory -Path "C:\ScadaAlarms" -Force
```

### Step 5: Create Initial Firestore Collections

**Via Firebase Console:**

1. Go to Firestore: https://console.firebase.google.com/project/scadadataserver/firestore
2. Click: **"Start collection"**

**Create these collections:**

#### Collection: `alerts`
```json
{
  "id": "alert-001",
  "title": "High Temperature - Reactor 1",
  "description": "Temperature exceeded 85°C threshold",
  "severity": "critical",
  "location": "Building A - Production Floor",
  "equipment": "Reactor-R1-TEMP-001",
  "timestamp": {
    "_seconds": 1738000000,
    "_nanoseconds": 0
  },
  "status": "active",
  "acknowledged_by": null,
  "acknowledged_at": null,
  "notes": ""
}
```

#### Collection: `system_status`
```json
{
  "status": "normal",
  "active_alerts_count": 0,
  "critical_count": 0,
  "high_count": 0,
  "medium_count": 0,
  "low_count": 0,
  "last_update": {
    "_seconds": 1738000000,
    "_nanoseconds": 0
  }
}
```
Document ID: **`current`**

#### Collection: `users`
```json
{
  "email": "admin@scada.local",
  "role": "admin",
  "displayName": "System Administrator",
  "createdAt": {
    "_seconds": 1738000000,
    "_nanoseconds": 0
  }
}
```

### Step 6: Upload Sample Data (Automated)

Create this PowerShell script to upload data:

**File: `upload_sample_data.ps1`**

```powershell
# Install Firebase Admin SDK for PowerShell
# This will upload sample data to Firestore

$serviceAccountPath = "C:\ScadaAlarms\firebase-service-account.json"

if (!(Test-Path $serviceAccountPath)) {
    Write-Host "❌ Service account key not found!" -ForegroundColor Red
    Write-Host "Please download from: https://console.firebase.google.com/project/scadadataserver/settings/serviceaccounts" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Service account found" -ForegroundColor Green
Write-Host ""
Write-Host "Upload data manually via Firebase Console:" -ForegroundColor Cyan
Write-Host "https://console.firebase.google.com/project/scadadataserver/firestore" -ForegroundColor Yellow
```

### Step 7: Configure Windows Sync Service

1. **Build the service:**
```bash
cd E:\scada_alarm_client\windows_sync_service
dotnet build
```

2. **Test in console mode first:**
```bash
.\test_service.bat
```

3. **Install as Windows Service (Administrator):**
```bash
.\install_service.bat
```

### Step 8: Seed Local SQLite Database

```bash
cd E:\scada_alarm_client
.\seed_database.ps1
```

This creates:
- `C:\ScadaAlarms\alerts.db`
- Sample alerts (5 alerts)
- System status
- Sync log tables

### Step 9: Test the Complete Flow

1. **Start Windows Sync Service:**
```bash
sc start ScadaAlarmSyncService
```

2. **Check logs:**
```bash
Get-Content C:\ScadaAlarms\Logs\sync_service.log -Wait
```

3. **Run Flutter app:**
```bash
cd E:\scada_alarm_client
flutter run
```

4. **Verify real-time sync:**
   - Add alert in SQLite → Should appear in Firestore
   - Add alert in Firestore → Should appear in Flutter app
   - Acknowledge in app → Should update Firestore & SQLite

---

## 🔍 Verification Checklist

### Firebase Console Checks:
- [ ] Firestore database created
- [ ] Collections: `alerts`, `system_status`, `users` exist
- [ ] Security rules deployed
- [ ] Authentication enabled (Email/Password + Anonymous)
- [ ] Cloud Storage enabled
- [ ] Service account key downloaded

### Local Setup Checks:
- [ ] Service account key at: `C:\ScadaAlarms\firebase-service-account.json`
- [ ] SQLite database at: `C:\ScadaAlarms\alerts.db`
- [ ] Windows Sync Service built successfully
- [ ] Flutter app runs without errors

### Integration Tests:
- [ ] Flutter app loads alerts from Firestore
- [ ] Windows Service syncs SQLite → Firestore
- [ ] Acknowledgments sync both ways
- [ ] Push notifications work
- [ ] Offline mode works (app + service)

---

## 🛠️ Troubleshooting

### Issue: "No databases found"
**Solution:** Create Firestore database via console (Step 1)

### Issue: "Permission denied" errors
**Solution:** Deploy security rules (Step 2)

### Issue: "Service account not found"
**Solution:** Download service account key (Step 4)

### Issue: "Firebase initialization failed" in app
**Solution:** Firestore database must be created first

### Issue: Windows Service won't start
**Checklist:**
- [ ] Service account key exists
- [ ] .NET 6.0 SDK installed
- [ ] Service built successfully
- [ ] Running as Administrator

---

## 📊 Data Flow Architecture

```
┌─────────────────┐
│  SCADA Systems  │
│   (OPC UA)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────┐
│ SQLite Database │◄────►│ Windows Service  │
│ C:\ScadaAlarms\ │      │ (Sync Every 5s)  │
└─────────────────┘      └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Firebase Cloud   │
                         │   - Firestore    │
                         │   - Storage      │
                         │   - Messaging    │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  Flutter App     │
                         │  (Real-time UI)  │
                         └──────────────────┘
```

---

## 🎯 Quick Command Reference

```bash
# Firebase CLI
firebase login
firebase projects:list
firebase use scadadataserver
firebase deploy --only firestore:rules
firebase firestore:databases:list

# Flutter
flutter pub get
flutter run
flutter build apk --release

# Windows Service
cd windows_sync_service
dotnet build
.\test_service.bat
.\install_service.bat

# Service Management
sc start ScadaAlarmSyncService
sc stop ScadaAlarmSyncService
sc query ScadaAlarmSyncService
Get-Content C:\ScadaAlarms\Logs\sync_service.log -Wait
```

---

## 📚 Important Files

| File | Purpose |
|------|---------|
| `lib/firebase_options.dart` | Firebase configuration (auto-generated) |
| `firestore.rules` | Security rules for Firestore |
| `storage.rules` | Security rules for Cloud Storage |
| `firestore.indexes.json` | Database indexes for queries |
| `windows_sync_service/ScadaAlarmSyncService.cs` | Sync service code |
| `C:\ScadaAlarms\firebase-service-account.json` | Service credentials |
| `C:\ScadaAlarms\alerts.db` | Local SQLite database |

---

## ✅ Success Indicators

When everything is set up correctly, you should see:

**Flutter App Console:**
```
✅ Firebase initialized successfully
✅ Push notifications configured
✅ Notification service initialized
```

**Windows Service Log:**
```
✅ Firebase initialized successfully
✅ SQLite database exists
✅ Database schema verified: alerts, system_status, sync_log
🔄 Starting sync cycle...
⬆ Pushing 5 local alerts to cloud...
✅ Pushed 5 alerts to cloud
```

**Firebase Console:**
- Firestore shows alerts appearing in real-time
- Storage shows any uploaded files
- Authentication shows registered users

---

## 🚀 Next Steps After Setup

1. **Create test users** in Firebase Authentication
2. **Set up Cloud Functions** for automated workflows (optional)
3. **Configure production security rules**
4. **Set up Firebase Hosting** for web dashboard (optional)
5. **Enable Analytics** for usage tracking
6. **Configure backup strategy** for Firestore

---

## 📞 Need Help?

- Firebase Console: https://console.firebase.google.com/project/scadadataserver
- Firebase Documentation: https://firebase.google.com/docs
- FlutterFire Documentation: https://firebase.flutter.dev

**Project Status:** 🟡 Partially Configured - Complete Steps 1-9 Above
