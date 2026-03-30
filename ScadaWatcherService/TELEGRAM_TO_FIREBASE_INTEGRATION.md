# 🚨 Telegram to Firebase Integration Guide

## 📊 OVERVIEW

This guide shows you how to **replace your Python Telegram script** with the **SCADA Watcher Service** to send alerts to your **Flutter mobile app via Firebase**.

### What Changes:

**BEFORE (Python Script):**
```
Alarm Files (CSV/TXT) → Python Script → Telegram Bot → Mobile Phones
```

**AFTER (SCADA Watcher Service):**
```
Alarm Files (CSV/TXT) → AlarmFileWatcherService → AlertEngine → Firebase → Flutter App
```

### Benefits:

✅ **Unified System** - One service for OPC UA + file monitoring + Firebase  
✅ **More Reliable** - Production-grade C# service vs Python script  
✅ **Better Alerts** - Rich notifications with severity, acknowledgement, history  
✅ **Mobile App** - Professional Flutter app instead of Telegram  
✅ **Cloud Sync** - Firestore database for alert history and sync  
✅ **No Bot Limits** - No Telegram API rate limits  

---

## 🔧 STEP 1: SETUP FIREBASE PROJECT

### 1.1 Create Firebase Project

1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Enter project name: **"scada-alerts"** (or your choice)
4. Disable Google Analytics (optional)
5. Click "Create project"

### 1.2 Enable Firestore Database

1. In Firebase Console, go to **Firestore Database**
2. Click "Create database"
3. Select **"Production mode"** (we'll set rules later)
4. Choose closest region
5. Click "Enable"

### 1.3 Enable Cloud Messaging

1. Go to **Project Settings** (gear icon)
2. Go to **Cloud Messaging** tab
3. Copy your **Server Key** (you'll need this later)

### 1.4 Download Service Account Key

1. In Project Settings, go to **Service Accounts** tab
2. Click "Generate new private key"
3. Download the JSON file
4. Save it to: `C:\SecureKeys\firebase-service-account.json`

---

## 🔧 STEP 2: CONFIGURE SCADA WATCHER SERVICE

### 2.1 Enable Firebase in appsettings.json

Edit `E:\ScadaWatcherService\appsettings.json`:

```json
{
  "Firebase": {
    "Enabled": true,
    "ProjectId": "scada-alerts",
    "ServiceAccountJsonPath": "C:\\SecureKeys\\firebase-service-account.json",
    "ActiveAlertsCollection": "alerts_active",
    "HistoryAlertsCollection": "alerts_history",
    "EventsCollection": "alert_events",
    "NotificationTopic": "scada_alerts",
    "SendNotificationsForWarning": true,
    "SendNotificationsForCritical": true,
    "NotificationThrottleSeconds": 60
  }
}
```

**Important:** Replace `"scada-alerts"` with your actual Firebase Project ID!

### 2.2 Enable Alarm File Watcher

In the same `appsettings.json`:

```json
{
  "AlarmFileWatcher": {
    "Enabled": true,
    "WatchFolder": "C:\\GOT_Alarms",
    "DatabasePath": "C:\\AlarmSystem\\alarm_history.db",
    "PollIntervalSeconds": 1,
    "UseFileSystemWatcher": true,
    "DefaultSeverity": "Warning"
  }
}
```

### 2.3 Enable Alert Engine

```json
{
  "Alerts": {
    "Enabled": true,
    "EvaluationIntervalSeconds": 5
  }
}
```

---

## 🔧 STEP 3: BUILD AND INSTALL SERVICE

### 3.1 Create Secure Keys Folder

```powershell
New-Item -Path C:\SecureKeys -ItemType Directory -Force
```

Copy your `firebase-service-account.json` to this folder.

### 3.2 Build the Service

```powershell
cd E:\ScadaWatcherService

# Restore dependencies (includes System.Data.SQLite)
dotnet restore

# Build
dotnet build --configuration Release

# Publish
dotnet publish --configuration Release --output C:\Services\ScadaWatcher
```

### 3.3 Copy Configuration

```powershell
# Copy appsettings.json to published folder
Copy-Item appsettings.json C:\Services\ScadaWatcher\appsettings.json -Force
```

### 3.4 Install Service

```powershell
# Create directories
New-Item -Path C:\Logs\ScadaWatcher -ItemType Directory -Force
New-Item -Path C:\GOT_Alarms -ItemType Directory -Force
New-Item -Path C:\AlarmSystem -ItemType Directory -Force

# Install service
sc.exe create ScadaWatcherService binPath= "C:\Services\ScadaWatcher\ScadaWatcherService.exe" start= delayed-auto DisplayName= "SCADA Watcher Service"

# Start service
sc.exe start ScadaWatcherService
```

---

## 🔧 STEP 4: SETUP FLUTTER MOBILE APP

### 4.1 Add Firebase to Flutter App

In your Flutter app's `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
  cloud_firestore: ^4.13.0
```

### 4.2 Initialize Firebase in Flutter

Create `lib/firebase_options.dart`:

```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'scada-alerts',
    storageBucket: 'scada-alerts.appspot.com',
  );
}
```

Get these values from Firebase Console → Project Settings → Your apps

### 4.3 Subscribe to Notifications Topic

In your Flutter app's main.dart:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Subscribe to alerts topic
  final messaging = FirebaseMessaging.instance;
  await messaging.subscribeToTopic('scada_alerts');
  
  // Request permission for notifications
  await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: true,
    provisional: false,
    sound: true,
  );
  
  runApp(MyApp());
}
```

### 4.4 Listen for Notifications

```dart
// Foreground messages
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('Got a message whilst in the foreground!');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  
  // Show alert dialog or notification
  showAlertDialog(
    title: message.notification?.title ?? 'Alert',
    message: message.notification?.body ?? '',
  );
});

// Background messages
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  print('Message clicked!');
  // Navigate to alert details screen
});
```

### 4.5 Display Active Alerts (Firestore)

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AlertsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts_active')
          .orderBy('firstRaisedTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }
        
        final alerts = snapshot.data!.docs;
        
        return ListView.builder(
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index].data() as Map<String, dynamic>;
            
            return ListTile(
              leading: Icon(
                Icons.warning,
                color: alert['severity'] == 'Critical' ? Colors.red : Colors.orange,
              ),
              title: Text(alert['description'] ?? 'Alert'),
              subtitle: Text(alert['message'] ?? ''),
              trailing: Text(
                alert['severity'] ?? 'Warning',
                style: TextStyle(
                  color: alert['severity'] == 'Critical' ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showAlertDetails(context, alert),
            );
          },
        );
      },
    );
  }
}
```

---

## 🧪 STEP 5: TEST THE INTEGRATION

### 5.1 Create Test Alarm File

Create a test file: `C:\GOT_Alarms\test_alarm.csv`

```csv
2026/01/26 10:30:00,High temperature detected in reactor 1
2026/01/26 10:31:00,Pressure drop in system 2
```

### 5.2 Verify Service Logs

```powershell
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50 -Wait
```

**Expected log messages:**
```
🚨 ALARM DETECTED: High temperature detected in reactor 1
   Time: 2026/01/26 10:30:00
   File: test_alarm.csv
Alert forwarded to Firebase: High temperature detected in reactor 1
Push notification sent: FILE_ALARM_xxx
```

### 5.3 Check Firestore Database

1. Go to Firebase Console → Firestore Database
2. Look for `alerts_active` collection
3. You should see documents for each alarm

### 5.4 Check Mobile App

1. Open your Flutter app
2. You should receive push notification
3. Alert should appear in active alerts list

---

## 📋 MIGRATION FROM PYTHON SCRIPT

### What to Keep:

✅ **Alarm Files** - Same CSV/TXT format works  
✅ **Watch Folder** - Same `C:\GOT_Alarms` folder  
✅ **Database** - Uses same SQLite database for deduplication  

### What to Remove:

❌ **Python Script** - No longer needed  
❌ **Telegram Bot Token** - Not used anymore  
❌ **Chat IDs** - Replaced with Firebase topic subscription  
❌ **NSSM Service** - Use Windows Service instead  

### Migration Steps:

1. **Stop Python Script**
   ```powershell
   # If using NSSM
   nssm stop GOT_AlarmService
   nssm remove GOT_AlarmService confirm
   
   # If using Task Scheduler
   Unregister-ScheduledTask -TaskName "GOT_AlarmWatcher" -Confirm:$false
   ```

2. **Keep Existing Files**
   - Don't delete `C:\GOT_Alarms` folder
   - Don't delete `C:\AlarmSystem\alarm_history.db`
   - SCADA Watcher will use the same database!

3. **Start SCADA Watcher Service**
   ```powershell
   sc.exe start ScadaWatcherService
   ```

4. **Verify Migration**
   - Check logs for "Alarm File Watcher started"
   - Create test alarm file
   - Verify notification received in Flutter app

---

## 🔍 COMPARISON: PYTHON VS C# SERVICE

| Feature | Python Script | SCADA Watcher Service |
|---------|---------------|----------------------|
| **Platform** | Telegram Bot | Firebase Cloud Messaging |
| **Language** | Python | C# (.NET 8) |
| **Reliability** | Script can crash | Production-grade service |
| **Monitoring** | Manual check | Windows Service auto-restart |
| **Notifications** | Limited (text only) | Rich (title, body, data, priority) |
| **Alert History** | SQLite only | SQLite + Firestore sync |
| **Acknowledgement** | No | Yes (via mobile app) |
| **Severity Levels** | No | Yes (Info, Warning, Critical) |
| **Throttling** | No | Yes (prevent spam) |
| **Multi-Device** | Must add chat IDs | Automatic (topic subscription) |
| **Cloud Backup** | No | Yes (Firestore) |
| **Integration** | Standalone | Part of SCADA system |

---

## 🛠️ TROUBLESHOOTING

### Issue: No notifications received

**Check:**
1. Firebase enabled in appsettings.json: `"Enabled": true`
2. AlarmFileWatcher enabled: `"Enabled": true`
3. Service running: `sc.exe query ScadaWatcherService`
4. Logs show "Alert forwarded to Firebase"
5. Flutter app subscribed to topic: `scada_alerts`

### Issue: Service won't start

**Check:**
1. Service account JSON file exists: `C:\SecureKeys\firebase-service-account.json`
2. Folders created: `C:\GOT_Alarms`, `C:\AlarmSystem`
3. Event Viewer: `Windows Logs > Application`
4. Service logs: `C:\Logs\ScadaWatcher\*.log`

### Issue: Duplicate alerts

**Solution:**
- SCADA Watcher uses the same deduplication database
- Each alarm is processed only once
- If migrating, existing alarms in database won't re-trigger

### Issue: Firebase authentication failed

**Check:**
1. Project ID correct in appsettings.json
2. Service account JSON file is valid
3. Firestore enabled in Firebase Console
4. Service account has permissions (Firestore + Cloud Messaging)

---

## 📊 ALERT DATA STRUCTURE

### Firestore Document (alerts_active):

```json
{
  "alertId": "FILE_ALARM_abc123",
  "nodeId": "FILE_WATCHER",
  "description": "File-Based Alarm",
  "message": "🚨 High temperature detected\n\nTime: 2026/01/26 10:30:00\nSource: alarms.csv",
  "severity": "Warning",
  "state": "Active",
  "firstRaisedTime": "2026-01-26T10:30:00Z",
  "lastUpdatedTime": "2026-01-26T10:30:00Z",
  "acknowledged": false
}
```

### Push Notification Payload:

```json
{
  "notification": {
    "title": "Warning Alert: File-Based Alarm",
    "body": "🚨 High temperature detected\n\nTime: 2026/01/26 10:30:00"
  },
  "data": {
    "alertId": "FILE_ALARM_abc123",
    "nodeId": "FILE_WATCHER",
    "severity": "Warning",
    "state": "Active",
    "type": "Alert Raised",
    "timestamp": "2026-01-26T10:30:00.000Z"
  }
}
```

---

## ✅ FINAL CHECKLIST

Before going live:

- [ ] Firebase project created
- [ ] Service account key downloaded and saved
- [ ] appsettings.json configured (Firebase + AlarmFileWatcher enabled)
- [ ] Service built and installed
- [ ] Test alarm file created and detected
- [ ] Push notification received in Flutter app
- [ ] Active alerts visible in Firestore
- [ ] Python script disabled/removed
- [ ] Service auto-starts on boot
- [ ] Logs monitored for errors

---

## 📞 NEXT STEPS

1. **Deploy to Production:**
   - Install service on production server
   - Configure alert severity levels
   - Set up mobile app for all users

2. **Enhance Mobile App:**
   - Add alert details screen
   - Implement acknowledgement
   - Add alert history view
   - Enable critical alert sounds

3. **Monitor Performance:**
   - Check service logs daily
   - Monitor Firestore usage
   - Track notification delivery rates
   - Analyze alert patterns

---

**Your alarms will now go directly to your Flutter app via Firebase! 🚀**
