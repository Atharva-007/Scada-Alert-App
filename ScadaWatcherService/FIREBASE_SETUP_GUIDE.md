# Firebase Setup Guide for SCADA Watcher Service
## Production-Grade Configuration for Industrial Environments

---

## Overview

This guide walks you through setting up Firebase Cloud Firestore and Firebase Cloud Messaging (FCM) for the SCADA Watcher Service notification and cloud synchronization system.

**SECURITY NOTICE**: This setup involves credentials that provide access to your cloud infrastructure. Follow all security steps carefully.

---

## Prerequisites

- Google Account (preferably a dedicated service account)
- Access to Firebase Console (https://console.firebase.google.com)
- Administrator privileges on the Windows Server
- Network access from Windows Server to Firebase APIs (firebaseio.com, googleapis.com)

---

## Step 1: Create Firebase Project

### 1.1 Access Firebase Console

1. Navigate to: https://console.firebase.google.com
2. Sign in with your Google account
3. Click **"Add project"** or **"Create a project"**

### 1.2 Configure Project

1. **Project Name**: `scada-watcher-production` (or your naming convention)
2. **Project ID**: Firebase auto-generates (e.g., `scada-watcher-prod-a1b2c`)
   - **IMPORTANT**: Note this ID - you'll need it for configuration
3. **Google Analytics**: 
   - For SCADA/industrial use: **Disable** (not needed)
   - For operational analytics: **Enable** (optional)
4. Click **"Create project"**
5. Wait for provisioning (30-60 seconds)

### 1.3 Note Project Details

```
Project Name: scada-watcher-production
Project ID: scada-watcher-prod-a1b2c
Project Number: 123456789012
```

---

## Step 2: Enable Cloud Firestore

### 2.1 Navigate to Firestore

1. In Firebase Console, select your project
2. Click **"Build"** in left sidebar
3. Click **"Firestore Database"**
4. Click **"Create database"**

### 2.2 Configure Security Mode

**CRITICAL DECISION**: Choose security mode carefully

#### Option A: Production Mode (RECOMMENDED for SCADA)
```
Advantages:
- Denies all client access by default
- Only service account can read/write
- Maximum security for industrial systems

Disadvantages:
- Requires server-side authentication
- Mobile apps must authenticate via your backend
```

**Security Rules for Production Mode**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Deny all direct client access
    // Only service account access allowed
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

#### Option B: Test Mode (ONLY for development/testing)
```
WARNING: Allows public read/write for 30 days
DO NOT USE IN PRODUCTION SCADA ENVIRONMENTS
```

**For SCADA**: Select **"Start in production mode"**

### 2.3 Select Location

1. **Location**: Choose closest to your operation
   - North America: `us-central1` (Iowa) or `us-east1` (South Carolina)
   - Europe: `europe-west1` (Belgium) or `europe-west3` (Frankfurt)
   - Asia: `asia-southeast1` (Singapore)

   **IMPORTANT**: Location CANNOT be changed later

2. Click **"Enable"**

### 2.4 Verify Firestore Activation

You should see an empty Firestore database with tabs:
- Data
- Rules
- Indexes
- Usage

---

## Step 3: Enable Firebase Cloud Messaging (FCM)

### 3.1 Navigate to Cloud Messaging

1. In Firebase Console, click **"Build"** → **"Cloud Messaging"**
2. No explicit "enable" required - FCM is enabled by default

### 3.2 Note Server Key (Legacy - Optional)

1. Click gear icon (⚙️) → **"Project settings"**
2. Navigate to **"Cloud Messaging"** tab
3. **Server key**: This is your legacy FCM API key
   - Not used in this implementation (we use service account)
   - Keep secure if you need it for other integrations

---

## Step 4: Generate Service Account JSON Key

### 4.1 Access Service Accounts

1. In Firebase Console, click gear icon (⚙️) → **"Project settings"**
2. Navigate to **"Service accounts"** tab
3. You'll see: **"Firebase Admin SDK"**

### 4.2 Generate Private Key

1. Under **"Firebase Admin SDK"**, select **".NET"** (language doesn't matter)
2. Click **"Generate new private key"**
3. **WARNING DIALOG** appears:
   ```
   Keep this key confidential and never commit it to version control.
   This key grants admin access to your Firebase project.
   ```
4. Click **"Generate key"**

### 4.3 Download and Secure

A JSON file downloads automatically:
```
Filename: scada-watcher-prod-a1b2c-firebase-adminsdk-xyz12.json
```

**CRITICAL SECURITY STEPS**:

#### Step A: Rename File
```powershell
# Original name is too long and contains random characters
# Rename to something standard
Rename-Item -Path ".\scada-watcher-prod-a1b2c-firebase-adminsdk-xyz12.json" `
            -NewName "firebase-service-account.json"
```

#### Step B: Create Secure Directory
```powershell
# Create a secure credentials directory
New-Item -Path "C:\ProgramData\ScadaWatcher\Credentials" -ItemType Directory -Force

# Move the service account file
Move-Item -Path ".\firebase-service-account.json" `
          -Destination "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json"
```

#### Step C: Set File Permissions
```powershell
# Remove inheritance
$acl = Get-Acl "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json"
$acl.SetAccessRuleProtection($true, $false)

# Remove all existing permissions
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }

# Grant SYSTEM full control
$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "NT AUTHORITY\SYSTEM", "FullControl", "Allow"
)
$acl.AddAccessRule($systemRule)

# Grant Administrators full control
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "BUILTIN\Administrators", "FullControl", "Allow"
)
$acl.AddAccessRule($adminRule)

# Grant service account read access (replace with your service account)
$serviceRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "NT SERVICE\ScadaWatcherService", "Read", "Allow"
)
$acl.AddAccessRule($serviceRule)

# Apply permissions
Set-Acl "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json" $acl
```

#### Step D: Verify Permissions
```powershell
Get-Acl "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json" | 
    Select-Object -ExpandProperty Access | 
    Format-Table IdentityReference, FileSystemRights, AccessControlType
```

Expected output:
```
IdentityReference              FileSystemRights AccessControlType
-----------------              ---------------- -----------------
NT AUTHORITY\SYSTEM            FullControl      Allow
BUILTIN\Administrators         FullControl      Allow
NT SERVICE\ScadaWatcherService Read             Allow
```

### 4.4 Inspect Service Account File

```powershell
Get-Content "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json" | ConvertFrom-Json
```

Expected structure:
```json
{
  "type": "service_account",
  "project_id": "scada-watcher-prod-a1b2c",
  "private_key_id": "abc123...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xyz12@scada-watcher-prod-a1b2c.iam.gserviceaccount.com",
  "client_id": "123456789012345678901",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-xyz12%40scada-watcher-prod-a1b2c.iam.gserviceaccount.com"
}
```

---

## Step 5: Configure Firestore Collections

### 5.1 Pre-Create Collections (Optional)

While the service will auto-create collections, you can pre-create them for testing:

1. In Firebase Console → **Firestore Database** → **Data** tab
2. Click **"Start collection"**

#### Collection: `alerts_active`
```
Collection ID: alerts_active
Document ID: (auto-generate for testing, or leave empty)
Fields:
  - alertId (string): "TEST_001"
  - nodeId (string): "ns=2;s=Temperature.Tank1"
  - severity (string): "Warning"
  - currentState (string): "Active"
  - message (string): "High temperature detected"
  - triggerValue (number): 85.5
  - raisedTime (timestamp): (current time)
```

#### Collection: `alerts_history`
```
Collection ID: alerts_history
(Leave empty - will be populated by service)
```

#### Collection: `alert_events`
```
Collection ID: alert_events
(Leave empty - optional audit trail)
```

### 5.2 Create Indexes (Performance)

1. Navigate to **Firestore** → **Indexes** tab
2. Click **"Add Index"**

**Index 1: Active Alerts by Severity**
```
Collection ID: alerts_active
Fields:
  - severity (Ascending)
  - raisedTime (Descending)
Query Scope: Collection
```

**Index 2: History by Time Range**
```
Collection ID: alerts_history
Fields:
  - clearedTime (Descending)
  - severity (Ascending)
Query Scope: Collection
```

**Index 3: Events by Alert ID**
```
Collection ID: alert_events
Fields:
  - alertId (Ascending)
  - timestamp (Descending)
Query Scope: Collection
```

---

## Step 6: Configure Security Rules

### 6.1 Production Security Rules

Navigate to **Firestore** → **Rules** tab:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Global: Deny all by default
    match /{document=**} {
      allow read, write: if false;
    }
    
    // Service account has full access (authenticated via SDK)
    // This is implicit - no rules needed
    
    // If you want to allow authenticated mobile app users 
    // to ACKNOWLEDGE alerts only:
    match /alerts_active/{alertId} {
      // Allow authenticated users to update acknowledgement fields only
      allow read: if request.auth != null;
      allow update: if request.auth != null 
                    && request.resource.data.diff(resource.data).affectedKeys()
                       .hasOnly(['acknowledgedTime', 'acknowledgedBy', 'currentState'])
                    && request.resource.data.currentState == 'Acknowledged';
    }
    
    // Read-only access to history for authenticated users
    match /alerts_history/{alertId} {
      allow read: if request.auth != null;
    }
  }
}
```

### 6.2 Publish Rules

1. Click **"Publish"**
2. Confirm changes

---

## Step 7: Configure Firebase Authentication (Optional)

If you want mobile apps to authenticate and acknowledge alerts:

### 7.1 Enable Authentication

1. Navigate to **"Build"** → **"Authentication"**
2. Click **"Get started"**
3. Enable sign-in providers:
   - **Email/Password**: For operator accounts
   - **Anonymous**: For testing only (disable in production)

### 7.2 Create User Accounts

```powershell
# Use Firebase CLI or Firebase Console to create users
# Example: operator@scadaplant.com
```

---

## Step 8: Update appsettings.json

### 8.1 Configure Service

Edit `appsettings.json`:

```json
{
  "Firebase": {
    "Enabled": true,
    "ProjectId": "scada-watcher-prod-a1b2c",
    "ServiceAccountJsonPath": "C:\\ProgramData\\ScadaWatcher\\Credentials\\firebase-service-account.json",
    "Collections": {
      "ActiveAlerts": "alerts_active",
      "HistoryAlerts": "alerts_history",
      "AuditEvents": "alert_events"
    },
    "CloudMessaging": {
      "Enabled": true,
      "DefaultTopic": "scada_alerts"
    },
    "NotificationRouting": {
      "Info": {
        "SendPush": false,
        "WriteToFirestore": true
      },
      "Warning": {
        "SendPush": true,
        "WriteToFirestore": true,
        "Topic": "scada_alerts_warning"
      },
      "Critical": {
        "SendPush": true,
        "WriteToFirestore": true,
        "Topic": "scada_alerts_critical",
        "EscalationTopic": "scada_alerts_escalation"
      }
    },
    "RetryPolicy": {
      "MaxRetries": 5,
      "InitialDelayMs": 1000,
      "MaxDelayMs": 60000,
      "BackoffMultiplier": 2.0
    }
  }
}
```

---

## Step 9: Verify Connectivity

### 9.1 Test Firestore Connection

```powershell
# Run the service in test mode
cd C:\ScadaWatcher\bin\Release\net8.0
.\ScadaWatcherService.exe

# Check logs for Firebase initialization
Get-Content "C:\ProgramData\ScadaWatcher\Logs\scada-watcher-*.log" | Select-String "Firebase"
```

Expected output:
```
[INF] Firebase configuration loaded. ProjectId: scada-watcher-prod-a1b2c
[INF] Firebase Admin SDK initialized successfully
[INF] Firestore client created for project: scada-watcher-prod-a1b2c
```

### 9.2 Test Write Operation

Trigger a test alert and verify it appears in Firebase Console:

1. Modify OPC UA value to trigger an alert
2. Check **Firestore** → **Data** → **alerts_active**
3. Verify document created with correct fields

---

## Step 10: Security Hardening

### 10.1 Rotate Service Account Keys Annually

```powershell
# Procedure for key rotation:
# 1. Generate new service account key (Step 4)
# 2. Update appsettings.json with new path
# 3. Restart service
# 4. Verify connectivity
# 5. Delete old key from Firebase Console
# 6. Delete old key file from server
```

### 10.2 Restrict Network Access

Configure Windows Firewall to allow outbound HTTPS only to Firebase:

```powershell
# Allow outbound to Firebase APIs
New-NetFirewallRule -DisplayName "Firebase Firestore API" `
                    -Direction Outbound `
                    -Protocol TCP `
                    -RemoteAddress "firestore.googleapis.com" `
                    -RemotePort 443 `
                    -Action Allow

New-NetFirewallRule -DisplayName "Firebase Cloud Messaging" `
                    -Direction Outbound `
                    -Protocol TCP `
                    -RemoteAddress "fcm.googleapis.com" `
                    -RemotePort 443 `
                    -Action Allow
```

### 10.3 Enable Audit Logging

In Firebase Console → **Settings** → **Usage and billing** → **Details & settings**:
- Enable **Cloud Audit Logs**
- Monitor for unauthorized access attempts

### 10.4 Backup Firestore Data

```bash
# Install gcloud CLI
# https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login

# Export Firestore data weekly
gcloud firestore export gs://scada-watcher-backups/$(date +%Y%m%d) \
       --project=scada-watcher-prod-a1b2c
```

---

## Step 11: Mobile App Configuration (FCM)

### 11.1 Android App Setup

1. In Firebase Console → **Project settings** → **General**
2. Scroll to **"Your apps"**
3. Click **"Add app"** → **"Android"**
4. Enter package name: `com.scadaplant.watcher`
5. Download `google-services.json`
6. Add to Flutter project: `android/app/google-services.json`

### 11.2 iOS App Setup

1. Click **"Add app"** → **"iOS"**
2. Enter bundle ID: `com.scadaplant.watcher`
3. Download `GoogleService-Info.plist`
4. Add to Flutter project: `ios/Runner/GoogleService-Info.plist`

### 11.3 Subscribe to Topics

In your Flutter app:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> setupNotifications() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  
  // Request permissions (iOS)
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  
  // Subscribe to topics based on user role
  await messaging.subscribeToTopic('scada_alerts');
  await messaging.subscribeToTopic('scada_alerts_warning');
  await messaging.subscribeToTopic('scada_alerts_critical');
  
  // Get FCM token
  String? token = await messaging.getToken();
  print('FCM Token: $token');
}
```

---

## Troubleshooting

### Issue: "Permission Denied" when writing to Firestore

**Cause**: Service account file not loaded or security rules too restrictive

**Solution**:
1. Verify file path in appsettings.json
2. Check file permissions (service account must have read access)
3. Verify security rules allow service account access

### Issue: "Project not found"

**Cause**: Incorrect Project ID in configuration

**Solution**:
1. Verify `ProjectId` in appsettings.json matches Firebase Console
2. Check for typos (case-sensitive)

### Issue: Mobile app not receiving notifications

**Cause**: Topic subscription failed or FCM credentials invalid

**Solution**:
1. Verify mobile app subscribed to correct topic
2. Check `google-services.json` / `GoogleService-Info.plist` present
3. Test with Firebase Console → **Cloud Messaging** → **Send test message**

### Issue: High Firestore costs

**Cause**: Too many individual writes

**Solution**:
1. Enable batching in NotificationAdapterService
2. Reduce notification frequency for low-severity alerts
3. Use Firestore batch writes (already implemented)

---

## Production Checklist

Before deploying to production:

- [ ] Firebase project created with production-appropriate name
- [ ] Firestore enabled in **production mode**
- [ ] Service account JSON downloaded and secured
- [ ] File permissions restricted to service account only
- [ ] Security rules configured (deny-by-default)
- [ ] Indexes created for performance
- [ ] `appsettings.json` updated with correct paths
- [ ] Connectivity tested successfully
- [ ] Backup strategy configured
- [ ] Audit logging enabled
- [ ] Key rotation schedule documented
- [ ] Mobile apps configured with FCM
- [ ] Network firewall rules applied
- [ ] Service account key NOT committed to version control

---

## Support Resources

- **Firebase Console**: https://console.firebase.google.com
- **Firestore Documentation**: https://firebase.google.com/docs/firestore
- **FCM Documentation**: https://firebase.google.com/docs/cloud-messaging
- **Security Rules**: https://firebase.google.com/docs/firestore/security/get-started
- **Service Account Auth**: https://firebase.google.com/docs/admin/setup

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-25  
**Maintained By**: SCADA Platform Team
