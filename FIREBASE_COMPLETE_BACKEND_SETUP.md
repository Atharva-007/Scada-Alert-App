# 🚀 Complete Firebase Backend Implementation Guide

## 📋 Overview

This guide covers the complete end-to-end Firebase backend setup for the SCADA Alarm Client, including:
- Cloud Firestore database
- Cloud Storage for files
- Cloud Functions for backend logic
- Cloud Messaging for push notifications
- Windows service for SQLite → Firebase sync

---

## 🔥 Part 1: Firebase Project Setup

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Project name: `scada-alarm-system`
4. Enable Google Analytics (optional)
5. Create project

### Step 2: Enable Required Services

#### Firestore Database
1. Firebase Console → Firestore Database
2. Click "Create database"
3. Start in **Production mode**
4. Choose location (us-central1 recommended)
5. Click "Enable"

#### Cloud Storage
1. Firebase Console → Storage
2. Click "Get started"
3. Start in **Production mode**
4. Use default bucket: `scada-alarm-system.appspot.com`
5. Click "Done"

#### Cloud Messaging
1. Firebase Console → Cloud Messaging
2. Click "Get started"
3. Enable Cloud Messaging API
4. Note down Server Key for later

#### Authentication (Optional but Recommended)
1. Firebase Console → Authentication
2. Click "Get started"
3. Enable "Email/Password" provider
4. Enable "Anonymous" provider (for testing)

---

## 📊 Part 2: Firestore Database Structure

### Collections Schema

#### Collection: `alerts_active`
```javascript
{
  // Document ID: alert-{timestamp}-{random}
  "id": "alert-001",
  "name": "High Temperature Alert",
  "description": "Reactor core temperature exceeded safe threshold",
  "severity": "critical", // critical, warning, info
  "source": "Reactor-1",
  "tagName": "REACTOR1.TEMP",
  "currentValue": 285.5,
  "threshold": 250.0,
  "condition": "Greater Than", // Greater Than, Less Than, Equal To
  "raisedAt": Timestamp,
  "escalatedAt": Timestamp (optional),
  "acknowledgedAt": Timestamp (optional),
  "acknowledgedBy": "operator@plant.com" (optional),
  "acknowledgedComment": "Checked, adjusting controls" (optional),
  "isActive": true,
  "isAcknowledged": false,
  "isSuppressed": false,
  "notes": "Maintenance team notified",
  "escalationLevel": 2,
  "suppressionCount": 0,
  "relatedAlertIds": [],
  "trendData": [],
  "attachments": [], // URLs from Cloud Storage
  "metadata": {
    "createdBy": "system",
    "lastModified": Timestamp,
    "notificationSent": true
  }
}
```

#### Collection: `alerts_history`
```javascript
{
  "id": "hist-001",
  "name": "Power Supply Fault",
  "description": "UPS battery backup activated",
  "severity": "critical",
  "source": "Electrical-Room-1",
  "tagName": "UPS1.STATUS",
  "currentValue": 0,
  "threshold": 1,
  "condition": "Equal To",
  "raisedAt": Timestamp,
  "clearedAt": Timestamp,
  "acknowledgedAt": Timestamp,
  "acknowledgedBy": "operator@plant.com",
  "acknowledgedComment": "Power restored",
  "isActive": false,
  "isAcknowledged": true,
  "duration": 3600, // seconds
  "resolutionNotes": "Switched to backup generator"
}
```

#### Collection: `system_status`
```javascript
{
  // Document ID: component name (e.g., "opc-ua")
  "componentName": "OPC UA Server",
  "status": "online", // online, degraded, offline
  "lastHeartbeat": Timestamp,
  "version": "1.5.2",
  "metadata": {
    "connectedTags": 245,
    "samplingRate": "1000ms",
    "protocol": "UA-TCP",
    "memoryUsage": "234MB",
    "cpuUsage": "12%"
  },
  "alerts": {
    "errors": 0,
    "warnings": 2
  }
}
```

#### Collection: `notifications`
```javascript
{
  "id": "notif-001",
  "alertId": "alert-001",
  "userId": "user123",
  "title": "Critical Alert",
  "body": "High Temperature detected",
  "sentAt": Timestamp,
  "readAt": Timestamp (optional),
  "acknowledged": false,
  "severity": "critical"
}
```

#### Collection: `shift_reports`
```javascript
{
  "id": "report-2026-01-26-morning",
  "shiftStart": Timestamp,
  "shiftEnd": Timestamp,
  "operator": "john.doe@plant.com",
  "summary": {
    "totalAlerts": 47,
    "criticalAlerts": 12,
    "warningAlerts": 28,
    "acknowledgedAlerts": 45
  },
  "activeAlerts": [], // Array of alert IDs
  "clearedAlerts": [], // Array of alert IDs
  "notes": "Routine shift, reactor temperature spiked twice",
  "reportUrl": "gs://bucket/reports/report-xyz.pdf" // Cloud Storage URL
}
```

---

## 🔐 Part 3: Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOperator() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'operator';
    }
    
    function isSupervisor() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'supervisor';
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Active Alerts - Read for authenticated, Write for system only
    match /alerts_active/{alertId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin(); // Only admin/system can create alerts
      allow update: if isOperator() && 
                      // Operators can only acknowledge, not modify other fields
                      request.resource.data.diff(resource.data).affectedKeys()
                        .hasOnly(['isAcknowledged', 'acknowledgedAt', 
                                 'acknowledgedBy', 'acknowledgedComment']);
    }
    
    // Alert History - Read only
    match /alerts_history/{alertId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
    
    // System Status - Read for all, Write for system
    match /system_status/{component} {
      allow read: if true; // Public read for dashboard
      allow write: if isAdmin();
    }
    
    // Notifications - User-specific
    match /notifications/{notifId} {
      allow read: if isAuthenticated() && 
                    resource.data.userId == request.auth.uid;
      allow write: if isAdmin();
    }
    
    // Shift Reports - Read for authenticated, Write for operators
    match /shift_reports/{reportId} {
      allow read: if isAuthenticated();
      allow create: if isOperator();
      allow update: if isOperator() && 
                      resource.data.operator == request.auth.token.email;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
  }
}
```

---

## 📦 Part 4: Cloud Storage Structure

```
scada-alarm-system.appspot.com/
├── alert_attachments/
│   ├── alert-001/
│   │   ├── image1.jpg
│   │   └── document.pdf
│   └── alert-002/
│       └── screenshot.png
├── shift_reports/
│   ├── 2026/
│   │   ├── 01/
│   │   │   ├── report-2026-01-26-morning.pdf
│   │   │   └── report-2026-01-26-evening.pdf
│   │   └── 02/
│   └── templates/
│       └── shift-report-template.pdf
├── system_logs/
│   └── 2026-01-26/
│       ├── sync-log.txt
│       └── error-log.txt
└── exports/
    ├── alerts_export_2026-01-26.csv
    └── analytics_2026-01.json
```

### Cloud Storage Security Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Alert attachments
    match /alert_attachments/{alertId}/{filename} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
                     request.resource.size < 10 * 1024 * 1024; // Max 10MB
    }
    
    // Shift reports
    match /shift_reports/{year}/{month}/{filename} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // System logs - Admin only
    match /system_logs/{allPaths=**} {
      allow read: if request.auth != null && 
                    request.auth.token.role == 'admin';
      allow write: if request.auth.token.role == 'admin';
    }
    
    // Exports - Time-limited read access
    match /exports/{filename} {
      allow read: if request.auth != null && 
                    request.time < resource.metadata.expiry.toTimestamp();
      allow write: if request.auth.token.role == 'operator';
    }
  }
}
```

---

## ⚙️ Part 5: Cloud Functions (Node.js)

Create `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Trigger: Send notification when new critical alert is created
exports.onNewCriticalAlert = functions.firestore
  .document('alerts_active/{alertId}')
  .onCreate(async (snap, context) => {
    const alert = snap.data();
    
    if (alert.severity === 'critical' && !alert.isAcknowledged) {
      const message = {
        topic: 'critical_alerts',
        notification: {
          title: `🚨 Critical Alert: ${alert.name}`,
          body: `${alert.source} - Value: ${alert.currentValue.toFixed(2)}`,
        },
        data: {
          alertId: context.params.alertId,
          severity: alert.severity,
          source: alert.source,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'critical_alerts',
            color: '#EF5350',
            sound: 'alert_critical',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'critical_alert.wav',
              badge: 1,
            },
          },
        },
      };
      
      try {
        await messaging.send(message);
        console.log('Sent notification for alert:', context.params.alertId);
        
        // Log notification
        await db.collection('notifications').add({
          alertId: context.params.alertId,
          title: message.notification.title,
          body: message.notification.body,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          acknowledged: false,
        });
      } catch (error) {
        console.error('Error sending notification:', error);
      }
    }
  });

// Trigger: Auto-escalate unacknowledged critical alerts
exports.autoEscalateCriticalAlerts = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async (context) => {
    const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);
    
    const alertsSnapshot = await db.collection('alerts_active')
      .where('severity', '==', 'critical')
      .where('isAcknowledged', '==', false)
      .where('raisedAt', '<', fifteenMinutesAgo)
      .get();
    
    const batch = db.batch();
    let escalatedCount = 0;
    
    alertsSnapshot.forEach((doc) => {
      const data = doc.data();
      const newEscalationLevel = (data.escalationLevel || 0) + 1;
      
      batch.update(doc.ref, {
        escalationLevel: newEscalationLevel,
        escalatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      escalatedCount++;
      console.log(`Escalated alert ${doc.id} to level ${newEscalationLevel}`);
    });
    
    if (escalatedCount > 0) {
      await batch.commit();
      console.log(`Escalated ${escalatedCount} critical alerts`);
    }
  });

// Trigger: Move cleared alerts to history
exports.moveToHistory = functions.firestore
  .document('alerts_active/{alertId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // If alert was cleared
    if (before.isActive && !after.isActive && after.clearedAt) {
      try {
        // Copy to history
        await db.collection('alerts_history').doc(context.params.alertId).set({
          ...after,
          movedToHistoryAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Delete from active
        await change.after.ref.delete();
        
        console.log(`Moved alert ${context.params.alertId} to history`);
      } catch (error) {
        console.error('Error moving to history:', error);
      }
    }
  });

// HTTP: Generate shift report
exports.generateShiftReport = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 
      'User must be authenticated');
  }
  
  const { shiftStart, shiftEnd } = data;
  
  try {
    // Get active alerts
    const activeAlertsSnapshot = await db.collection('alerts_active')
      .where('raisedAt', '>=', new Date(shiftStart))
      .where('raisedAt', '<=', new Date(shiftEnd))
      .get();
    
    // Get cleared alerts
    const clearedAlertsSnapshot = await db.collection('alerts_history')
      .where('clearedAt', '>=', new Date(shiftStart))
      .where('clearedAt', '<=', new Date(shiftEnd))
      .get();
    
    const activeAlerts = activeAlertsSnapshot.docs.map(doc => doc.data());
    const clearedAlerts = clearedAlertsSnapshot.docs.map(doc => doc.data());
    
    const report = {
      shiftStart: new Date(shiftStart),
      shiftEnd: new Date(shiftEnd),
      operator: context.auth.token.email,
      summary: {
        totalAlerts: activeAlerts.length + clearedAlerts.length,
        criticalAlerts: [...activeAlerts, ...clearedAlerts]
          .filter(a => a.severity === 'critical').length,
        warningAlerts: [...activeAlerts, ...clearedAlerts]
          .filter(a => a.severity === 'warning').length,
        acknowledgedAlerts: [...activeAlerts, ...clearedAlerts]
          .filter(a => a.isAcknowledged).length,
      },
      activeAlerts: activeAlerts.map(a => a.id),
      clearedAlerts: clearedAlerts.map(a => a.id),
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // Save report
    const reportRef = await db.collection('shift_reports').add(report);
    
    return {
      success: true,
      reportId: reportRef.id,
      summary: report.summary,
    };
  } catch (error) {
    console.error('Error generating shift report:', error);
    throw new functions.https.HttpsError('internal', 
      'Failed to generate shift report');
  }
});

// HTTP: Acknowledge alert from mobile app
exports.acknowledgeAlert = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 
      'User must be authenticated');
  }
  
  const { alertId, comment } = data;
  
  try {
    await db.collection('alerts_active').doc(alertId).update({
      isAcknowledged: true,
      acknowledgedAt: admin.firestore.FieldValue.serverTimestamp(),
      acknowledgedBy: context.auth.token.email,
      acknowledgedComment: comment || '',
    });
    
    return { success: true };
  } catch (error) {
    console.error('Error acknowledging alert:', error);
    throw new functions.https.HttpsError('internal', 
      'Failed to acknowledge alert');
  }
});
```

### Deploy Cloud Functions

```bash
cd functions
npm install firebase-functions firebase-admin
firebase deploy --only functions
```

---

## 💻 Part 6: Windows Service Setup

See `windows_sync_service/` directory for complete C# Windows Service implementation.

### Quick Setup:

1. Install dependencies:
```bash
dotnet add package FirebaseAdmin
dotnet add package Google.Cloud.Firestore
dotnet add package System.Data.SQLite
dotnet add package Newtonsoft.Json
```

2. Configure service account:
   - Download service account JSON from Firebase Console
   - Place at `C:\ScadaAlarms\firebase-service-account.json`

3. Build and install:
```bash
dotnet build
sc create ScadaAlarmSyncService binPath= "C:\Path\To\Service.exe"
sc start ScadaAlarmSyncService
```

---

## 📱 Part 7: Flutter App Configuration

### Update firebase_options.dart with your project details

Get configuration from Firebase Console → Project Settings → Your apps

### Initialize in main.dart (Already done!)

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

---

## 🧪 Part 8: Testing

### Test Firestore Connection
```bash
# In Firebase Console → Firestore
# Add a test document to alerts_active
# Check if it appears in the mobile app
```

### Test Push Notifications
```bash
# Use Firebase Console → Cloud Messaging → Send test message
# Topic: critical_alerts
```

### Test Windows Service
```bash
# Check logs at C:\ScadaAlarms\Logs\sync_service.log
```

---

## 📊 Part 9: Monitoring & Analytics

### Enable Firebase Analytics
1. Firebase Console → Analytics
2. Enable Analytics
3. View real-time data

### Set up Performance Monitoring
```bash
flutter pub add firebase_performance
```

### Crashlytics
```bash
flutter pub add firebase_crashlytics
```

---

## ✅ Deployment Checklist

- [ ] Firebase project created
- [ ] Firestore enabled with proper security rules
- [ ] Cloud Storage enabled with security rules
- [ ] Cloud Functions deployed
- [ ] FCM server key saved
- [ ] Windows service installed and running
- [ ] Mobile app configured with firebase_options.dart
- [ ] Push notifications tested
- [ ] End-to-end sync tested
- [ ] Security rules reviewed
- [ ] Monitoring enabled

---

**🎉 Your complete Firebase backend is now ready!**

The system will automatically:
- Sync SQLite → Firebase every 5 seconds
- Send push notifications for critical alerts
- Auto-escalate unacknowledged alerts
- Move cleared alerts to history
- Generate shift reports

All data is available in real-time on the mobile app!
