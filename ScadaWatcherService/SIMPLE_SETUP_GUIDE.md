# 🚀 SIMPLIFIED SETUP - Direct Alerts to App

## ✅ WHAT YOU WANT

**Simple Flow:**
```
CSV Files in C:\GOT_Alarms → Windows Service → Firebase → Your App
                                    ↓
                            Local Database Storage
```

**No complex configuration needed!**

---

## 📋 STEP-BY-STEP SETUP

### STEP 1: Get Firebase Credentials (5 minutes)

1. Go to **https://console.firebase.google.com/**
2. Click **"Add project"**
3. Project name: `scada-alerts` (or any name)
4. Click **Create project**

5. **Enable Firestore:**
   - Left menu → **Firestore Database**
   - Click **"Create database"**
   - Choose **Production mode**
   - Select your region
   - Click **Enable**

6. **Download Service Account Key:**
   - Click gear icon ⚙️ → **Project settings**
   - Go to **"Service accounts"** tab
   - Click **"Generate new private key"**
   - Download the JSON file
   - **Important:** Note your **Project ID** (shown at top of page)

7. **Save the JSON file:**
   ```powershell
   # Create folder
   New-Item -Path C:\SecureKeys -ItemType Directory -Force
   
   # Copy downloaded JSON file to: C:\SecureKeys\firebase-service-account.json
   ```

---

### STEP 2: Configure the Service (2 minutes)

Open `E:\ScadaWatcherService\appsettings.json` in Notepad:

```powershell
notepad E:\ScadaWatcherService\appsettings.json
```

**Find and update these 3 sections:**

#### 2.1 Enable Firebase:
```json
"Firebase": {
  "Enabled": true,
  "ProjectId": "YOUR_PROJECT_ID_HERE",
  "ServiceAccountJsonPath": "C:\\SecureKeys\\firebase-service-account.json",
  "NotificationTopic": "scada_alerts",
  "SendNotificationsForWarning": true,
  "SendNotificationsForCritical": true
}
```

**Replace `YOUR_PROJECT_ID_HERE` with your Firebase Project ID!**

#### 2.2 Enable Alarm File Watcher:
```json
"AlarmFileWatcher": {
  "Enabled": true,
  "WatchFolder": "C:\\GOT_Alarms",
  "DatabasePath": "C:\\AlarmSystem\\alarm_history.db",
  "PollIntervalSeconds": 1,
  "UseFileSystemWatcher": true,
  "DefaultSeverity": "Warning"
}
```

#### 2.3 Enable Alerts:
```json
"Alerts": {
  "Enabled": true,
  "EvaluationIntervalSeconds": 5
}
```

**Save and close the file.**

---

### STEP 3: Build and Install Service (5 minutes)

Open **PowerShell as Administrator** and run:

```powershell
# Navigate to project folder
cd E:\ScadaWatcherService

# Restore dependencies
dotnet restore

# Build the service
dotnet build --configuration Release

# Publish to install location
dotnet publish --configuration Release --output C:\Services\ScadaWatcher

# Copy configuration file
Copy-Item appsettings.json C:\Services\ScadaWatcher\appsettings.json -Force

# Create required directories
New-Item -Path C:\Logs\ScadaWatcher -ItemType Directory -Force
New-Item -Path C:\GOT_Alarms -ItemType Directory -Force
New-Item -Path C:\AlarmSystem -ItemType Directory -Force
New-Item -Path C:\SecureKeys -ItemType Directory -Force

# Install as Windows Service
sc.exe create ScadaWatcherService binPath= "C:\Services\ScadaWatcher\ScadaWatcherService.exe" start= delayed-auto DisplayName= "SCADA Watcher Service"

# Start the service
sc.exe start ScadaWatcherService
```

**Wait 10 seconds for service to initialize...**

---

### STEP 4: Verify Service is Running (1 minute)

```powershell
# Check service status
sc.exe query ScadaWatcherService
```

**Expected output:**
```
STATE: 4 RUNNING
```

**View logs:**
```powershell
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50
```

**Look for these messages:**
```
[INF] Alarm File Watcher started successfully
[INF] Firebase Notification Adapter started successfully
[INF] Alert Engine started successfully
```

---

### STEP 5: Test with Sample Alarm (2 minutes)

**Create a test alarm file:**

```powershell
# Create test CSV file
@"
2026/01/26 10:30:00,High temperature detected in reactor 1
2026/01/26 10:31:00,Pressure drop detected in system 2
"@ | Out-File -FilePath "C:\GOT_Alarms\test_alarm.csv" -Encoding UTF8
```

**Watch the logs in real-time:**
```powershell
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50 -Wait
```

**Expected output:**
```
[INF] 🚨 ALARM DETECTED: High temperature detected in reactor 1
[INF]    Time: 2026/01/26 10:30:00
[INF]    File: test_alarm.csv
[INF] Alert forwarded to Firebase: High temperature detected in reactor 1
[INF] Synced alert to Firestore: FILE_ALARM_xxx (alerts_active)
[INF] Push notification sent: FILE_ALARM_xxx (MessageId: xxx)
```

**Check Firestore Database:**
1. Go to Firebase Console → Firestore Database
2. You should see collection: `alerts_active`
3. Documents contain your alerts

---

### STEP 6: Setup Your Flutter App

#### 6.1 Add Firebase to Flutter App

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
  cloud_firestore: ^4.13.0
```

Run:
```bash
flutter pub get
```

#### 6.2 Initialize Firebase

In `lib/main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'YOUR_API_KEY',
      appId: 'YOUR_APP_ID',
      messagingSenderId: 'YOUR_SENDER_ID',
      projectId: 'scada-alerts', // Your Firebase project ID
      storageBucket: 'scada-alerts.appspot.com',
    ),
  );
  
  // Setup background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Request notification permissions
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    criticalAlert: true,
  );
  
  // Subscribe to alerts topic
  await messaging.subscribeToTopic('scada_alerts');
  
  print('Subscribed to scada_alerts topic');
  
  runApp(MyApp());
}
```

**Get Firebase config values:**
1. Firebase Console → Project Settings
2. Scroll down to "Your apps"
3. Click Android/iOS icon
4. Copy the values

#### 6.3 Listen for Notifications

```dart
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  void _setupNotifications() {
    // Foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Received foreground message!');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      
      // Show dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(message.notification?.title ?? 'Alert'),
            content: Text(message.notification?.body ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    });

    // Notification tapped (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 Notification tapped!');
      // Navigate to alerts screen
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCADA Alerts',
      home: AlertsListScreen(),
    );
  }
}
```

#### 6.4 Display Alerts List

```dart
class AlertsListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Active Alerts'),
        backgroundColor: Colors.red,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts_active')
            .orderBy('firstRaisedTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('No active alerts', 
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final alerts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final data = alerts[index].data() as Map<String, dynamic>;
              final severity = data['severity'] ?? 'Warning';
              final description = data['description'] ?? 'Alert';
              final message = data['message'] ?? '';
              final timestamp = data['firstRaisedTime'];
              
              Color severityColor = severity == 'Critical' 
                  ? Colors.red 
                  : Colors.orange;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    Icons.warning,
                    color: severityColor,
                    size: 32,
                  ),
                  title: Text(
                    description,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text(message),
                      SizedBox(height: 4),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      severity,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: severityColor,
                  ),
                  onTap: () => _showAlertDetails(context, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      if (timestamp is Timestamp) {
        final dt = timestamp.toDate();
        return '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute}';
      }
      return timestamp.toString();
    } catch (e) {
      return '';
    }
  }

  void _showAlertDetails(BuildContext context, Map<String, dynamic> alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert['description'] ?? 'Alert Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Severity: ${alert['severity'] ?? 'Unknown'}',
                style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Message:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(alert['message'] ?? ''),
              SizedBox(height: 8),
              Text('Alert ID: ${alert['alertId'] ?? 'Unknown'}',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
```

---

## ✅ DONE! HOW IT WORKS

### When Alarm Occurs:

1. **CSV file created** in `C:\GOT_Alarms`:
   ```
   2026/01/26 10:30:00,Temperature too high
   ```

2. **Windows Service detects it** (within 1 second)

3. **Service processes**:
   - Reads CSV file
   - Checks if already processed (deduplication)
   - Saves to local database: `C:\AlarmSystem\alarm_history.db`

4. **Sends to Firebase**:
   - Creates document in Firestore: `alerts_active` collection
   - Sends push notification to topic: `scada_alerts`

5. **Your Flutter app receives**:
   - Push notification appears
   - Alert appears in alerts list
   - Updates in real-time

---

## 📊 LOCAL DATABASE

**Location:** `C:\AlarmSystem\alarm_history.db`

**Schema:**
```sql
CREATE TABLE alarms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    occurred TEXT NOT NULL,           -- Timestamp from CSV
    message TEXT NOT NULL,            -- Alert message
    file TEXT NOT NULL,               -- Source CSV filename
    uniq TEXT UNIQUE NOT NULL,        -- Deduplication key
    processed_time TEXT NOT NULL      -- When service processed it
);
```

**View database:**
1. Download **DB Browser for SQLite**: https://sqlitebrowser.org/
2. Open: `C:\AlarmSystem\alarm_history.db`
3. Browse table: `alarms`

**Query via PowerShell:**
```powershell
# Install SQLite module (one-time)
Install-Module -Name PSSQLite -Force

# Query alarms
Invoke-SqliteQuery -DataSource "C:\AlarmSystem\alarm_history.db" -Query "SELECT * FROM alarms ORDER BY id DESC LIMIT 10"
```

---

## 🔍 MONITORING & TROUBLESHOOTING

### Check Service Status:
```powershell
sc.exe query ScadaWatcherService
```

### View Live Logs:
```powershell
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50 -Wait
```

### Check Database:
```powershell
# Count total alarms processed
$db = "C:\AlarmSystem\alarm_history.db"
$query = "SELECT COUNT(*) as total FROM alarms"
Invoke-SqliteQuery -DataSource $db -Query $query
```

### Restart Service:
```powershell
Restart-Service ScadaWatcherService
```

### Stop Service:
```powershell
sc.exe stop ScadaWatcherService
```

### Uninstall Service:
```powershell
sc.exe stop ScadaWatcherService
sc.exe delete ScadaWatcherService
```

---

## 🚨 TESTING

### Test 1: Manual CSV File

Create file: `C:\GOT_Alarms\manual_test.csv`
```csv
2026/01/26 14:30:00,Manual test alarm - please acknowledge
```

**Expected:**
- Service logs show "ALARM DETECTED"
- Firestore has new document
- App receives push notification

### Test 2: Multiple Alarms

```csv
2026/01/26 15:00:00,Temperature sensor 1 - high reading
2026/01/26 15:01:00,Pressure sensor 2 - low reading
2026/01/26 15:02:00,Flow meter 3 - stopped
```

**Expected:**
- 3 separate notifications
- 3 documents in Firestore
- 3 rows in local database

### Test 3: Duplicate Detection

Create same file again.

**Expected:**
- Service logs show alarms already processed
- NO new notifications
- NO new database entries

---

## 📋 CSV FILE FORMAT

### Supported Formats:

**Standard (timestamp,message):**
```csv
2026/01/26 10:30:00,Temperature too high
```

**With header (ignored):**
```csv
Time,Message
2026/01/26 10:30:00,Temperature too high
```

**Message with commas:**
```csv
2026/01/26 10:30:00,Temperature 85°C, exceeds limit of 80°C, immediate action required
```

**Multiple lines:**
```csv
2026/01/26 10:30:00,First alarm
2026/01/26 10:31:00,Second alarm
2026/01/26 10:32:00,Third alarm
```

---

## 🎯 QUICK REFERENCE

### Service Management:
```powershell
# Start
sc.exe start ScadaWatcherService

# Stop
sc.exe stop ScadaWatcherService

# Restart
Restart-Service ScadaWatcherService

# Status
sc.exe query ScadaWatcherService

# Logs
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 100 -Wait
```

### Testing:
```powershell
# Create test alarm
"$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss'),Test alarm message" | Out-File C:\GOT_Alarms\test.csv

# View database count
Invoke-SqliteQuery -DataSource "C:\AlarmSystem\alarm_history.db" -Query "SELECT COUNT(*) FROM alarms"
```

### File Locations:
- **Alarm Files:** `C:\GOT_Alarms\`
- **Local Database:** `C:\AlarmSystem\alarm_history.db`
- **Service Logs:** `C:\Logs\ScadaWatcher\`
- **Service Binary:** `C:\Services\ScadaWatcher\`
- **Firebase Key:** `C:\SecureKeys\firebase-service-account.json`

---

## ✅ THAT'S IT!

**Your system is now:**
- ✅ Monitoring `C:\GOT_Alarms` folder
- ✅ Processing CSV alarm files
- ✅ Storing in local database
- ✅ Sending to Firebase
- ✅ Pushing to your Flutter app
- ✅ Running 24/7 as Windows Service

**Just put CSV files in the folder and your app gets the alerts instantly!** 🚀
