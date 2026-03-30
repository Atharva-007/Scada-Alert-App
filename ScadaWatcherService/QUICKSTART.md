# 🚀 QUICK START - Alarm Files to Mobile App

## ⚡ ONE-COMMAND INSTALLATION

### What This Does:
- ✅ Monitors `C:\GOT_Alarms` folder for CSV alarm files
- ✅ Stores alarms in local database: `C:\AlarmSystem\alarm_history.db`
- ✅ Sends alerts to Firebase Cloud
- ✅ Your Flutter mobile app receives push notifications
- ✅ Runs as Windows Service (24/7 automatic)

### Installation (5 minutes total):

#### Step 1: Get Firebase Credentials (3 minutes)

1. Go to https://console.firebase.google.com/
2. Create project (name it "scada-alerts")
3. Go to Project Settings → Service Accounts
4. Click "Generate new private key"
5. Download the JSON file
6. Note your **Project ID** (shown at top)

#### Step 2: Run Installation (2 minutes)

Open **PowerShell as Administrator**:

```powershell
cd E:\ScadaWatcherService

.\Quick-Install.ps1 `
    -FirebaseProjectId "YOUR_PROJECT_ID" `
    -FirebaseKeyPath "C:\Users\YourName\Downloads\firebase-key.json"
```

**Replace:**
- `YOUR_PROJECT_ID` with your Firebase project ID
- `C:\Users\YourName\Downloads\firebase-key.json` with path to downloaded JSON

**Example:**
```powershell
.\Quick-Install.ps1 `
    -FirebaseProjectId "scada-alerts-12345" `
    -FirebaseKeyPath "C:\Users\Admin\Downloads\scada-alerts-firebase.json"
```

#### That's It! ✅

The script will:
- ✅ Create all required folders
- ✅ Configure the service
- ✅ Build and install
- ✅ Start monitoring `C:\GOT_Alarms`

---

## 📋 HOW TO USE

### Create Alarm File:

Just put a CSV file in `C:\GOT_Alarms\` with format:
```csv
2026/01/26 10:30:00,Your alarm message here
```

**Example:**
```csv
2026/01/26 14:30:00,High temperature detected in reactor 1
2026/01/26 14:31:00,Pressure drop in system 2
2026/01/26 14:32:00,Motor 3 stopped unexpectedly
```

### What Happens:

1. **Within 1 second**, service detects the file
2. **Stores in database**: `C:\AlarmSystem\alarm_history.db`
3. **Sends to Firebase**: Push notification created
4. **Your app receives**: Notification + alert appears in app

---

## 📱 SETUP YOUR FLUTTER APP

### Add Dependencies:

In `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
  cloud_firestore: ^4.13.0
```

### Initialize Firebase:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'YOUR_API_KEY',
      appId: 'YOUR_APP_ID',
      messagingSenderId: 'YOUR_SENDER_ID',
      projectId: 'scada-alerts', // Your project ID
    ),
  );
  
  // Subscribe to alerts
  await FirebaseMessaging.instance.subscribeToTopic('scada_alerts');
  
  runApp(MyApp());
}
```

Get these values from: **Firebase Console → Project Settings → Your apps**

### Listen for Notifications:

```dart
// Foreground notifications
FirebaseMessaging.onMessage.listen((message) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(message.notification?.title ?? 'Alert'),
      content: Text(message.notification?.body ?? ''),
    ),
  );
});
```

**Full Flutter example in:** `SIMPLE_SETUP_GUIDE.md`

---

## 🧪 TEST IT

### Create Test Alarm:

```powershell
"$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss'),Test alarm - please acknowledge" | Out-File C:\GOT_Alarms\test.csv
```

### Check Logs:

```powershell
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50 -Wait
```

**Expected:**
```
[INF] 🚨 ALARM DETECTED: Test alarm - please acknowledge
[INF]    Time: 2026/01/26 10:30:00
[INF]    File: test.csv
[INF] Alert forwarded to Firebase
[INF] Push notification sent
```

### Check Firebase:

1. Go to Firebase Console → Firestore Database
2. Collection: `alerts_active`
3. You should see your alert document

### Check Your App:

- Should receive push notification
- Alert appears in alerts list

---

## 📊 WHERE DATA IS STORED

### Local Database:
```
C:\AlarmSystem\alarm_history.db
```
- All processed alarms
- Used for deduplication (no duplicates)
- Can query with DB Browser for SQLite

### Firebase Firestore:
- Collection: `alerts_active` (active alerts)
- Collection: `alerts_history` (cleared alerts)
- Synced to all connected devices

---

## 🔧 MANAGEMENT COMMANDS

### View Logs:
```powershell
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 100 -Wait
```

### Service Status:
```powershell
sc.exe query ScadaWatcherService
```

### Restart Service:
```powershell
Restart-Service ScadaWatcherService
```

### Stop Service:
```powershell
sc.exe stop ScadaWatcherService
```

### View Database:
```powershell
# Install SQLite module (one-time)
Install-Module PSSQLite -Force

# Query last 10 alarms
Invoke-SqliteQuery -DataSource "C:\AlarmSystem\alarm_history.db" -Query "SELECT * FROM alarms ORDER BY id DESC LIMIT 10"
```

---

## 📁 FILE LOCATIONS

| Item | Location |
|------|----------|
| **Alarm Files** | `C:\GOT_Alarms\` |
| **Local Database** | `C:\AlarmSystem\alarm_history.db` |
| **Service Logs** | `C:\Logs\ScadaWatcher\` |
| **Service Binary** | `C:\Services\ScadaWatcher\` |
| **Firebase Key** | `C:\SecureKeys\firebase-service-account.json` |
| **Configuration** | `C:\Services\ScadaWatcher\appsettings.json` |

---

## 🚨 TROUBLESHOOTING

### Service Won't Start:

```powershell
# Check Event Viewer
Get-EventLog -LogName Application -Source "ScadaWatcherService" -Newest 10

# Check service logs
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 100
```

### No Notifications Received:

**Check:**
1. Service running: `sc.exe query ScadaWatcherService`
2. Logs show "Alert forwarded to Firebase"
3. Firebase ProjectId correct in `appsettings.json`
4. Flutter app subscribed to `scada_alerts` topic

### Duplicate Alerts:

**This is normal!** The service prevents duplicates automatically:
- Same file processed twice = no duplicate alert
- Database tracks all processed alarms

### Update Configuration:

```powershell
# Edit config
notepad C:\Services\ScadaWatcher\appsettings.json

# Restart service
Restart-Service ScadaWatcherService
```

---

## 💡 CSV FILE FORMAT

### Basic Format:
```csv
timestamp,message
```

### Examples:

**Single alarm:**
```csv
2026/01/26 10:30:00,Temperature too high
```

**Multiple alarms:**
```csv
2026/01/26 10:30:00,First alarm
2026/01/26 10:31:00,Second alarm
2026/01/26 10:32:00,Third alarm
```

**Message with commas:**
```csv
2026/01/26 10:30:00,Temperature 85°C, exceeds limit 80°C, take action
```

**With header (will be skipped):**
```csv
Time,Message
2026/01/26 10:30:00,Your alarm
```

---

## 📚 DOCUMENTATION

- **`SIMPLE_SETUP_GUIDE.md`** - Complete setup guide with Flutter code
- **`TELEGRAM_TO_FIREBASE_INTEGRATION.md`** - Migration from Telegram
- **`INTEGRATION_SUMMARY.md`** - Quick overview
- **`PROJECT_ANALYSIS.md`** - Full project details
- **`SETUP_FOR_COMPANY.md`** - SCADA OPC UA connection guide

---

## ✅ QUICK CHECKLIST

Installation:
- [ ] Firebase project created
- [ ] Service account JSON downloaded
- [ ] Ran `Quick-Install.ps1` script
- [ ] Service status shows "RUNNING"
- [ ] Logs show "started successfully"

Testing:
- [ ] Created test CSV file
- [ ] Logs show "ALARM DETECTED"
- [ ] Firestore has alert document
- [ ] Local database has entry

Flutter App:
- [ ] Firebase initialized
- [ ] Subscribed to `scada_alerts` topic
- [ ] Notification received
- [ ] Alert appears in app

---

## 🎯 SUMMARY

**What You Have:**
- ✅ Windows Service monitoring `C:\GOT_Alarms`
- ✅ Automatic alarm detection (1 second polling)
- ✅ Local database storage with deduplication
- ✅ Firebase Cloud integration
- ✅ Push notifications to mobile app
- ✅ 24/7 operation with auto-restart

**What You Do:**
1. Put CSV files in `C:\GOT_Alarms\`
2. Your app receives alerts automatically!

**That's it! Everything else is automatic!** 🚀

---

## 📞 NEED HELP?

**Check logs first:**
```powershell
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 100 -Wait
```

**Common issues are documented in:**
- `SIMPLE_SETUP_GUIDE.md` (Troubleshooting section)
- Service logs show detailed error messages

**Service management:**
```powershell
# Status
sc.exe query ScadaWatcherService

# Restart
Restart-Service ScadaWatcherService

# Logs
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50 -Wait
```

---

**Built for reliability. Designed for simplicity. Ready to use!** ✨
