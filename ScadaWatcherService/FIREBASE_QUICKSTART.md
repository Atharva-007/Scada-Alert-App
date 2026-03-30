# Firebase Quick Reference - SCADA Watcher Service

## 🚀 Quick Setup (5 Minutes)

### 1. Create Firebase Project
```
→ https://console.firebase.google.com
→ Add project → "scada-watcher-production"
→ Note Project ID (e.g., scada-watcher-prod-a1b2c)
```

### 2. Enable Firestore
```
→ Build → Firestore Database → Create database
→ Select "Production mode"
→ Choose location: us-central1 (or nearest)
→ Enable
```

### 3. Generate Service Account
```
→ Settings ⚙️ → Service accounts
→ Generate new private key
→ Download JSON → Rename to "firebase-service-account.json"
```

### 4. Secure the Key
```powershell
# Create secure directory
New-Item -Path "C:\ProgramData\ScadaWatcher\Credentials" -ItemType Directory -Force

# Move key file
Move-Item -Path ".\firebase-service-account.json" `
          -Destination "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json"

# Restrict permissions (Administrators + SYSTEM only)
icacls "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json" /inheritance:r
icacls "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json" /grant:r "SYSTEM:(F)"
icacls "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json" /grant:r "Administrators:(F)"
icacls "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json" /grant:r "NT SERVICE\ScadaWatcherService:(R)"
```

### 5. Update appsettings.json
```json
{
  "Firebase": {
    "Enabled": true,
    "ProjectId": "scada-watcher-prod-a1b2c",
    "ServiceAccountJsonPath": "C:\\ProgramData\\ScadaWatcher\\Credentials\\firebase-service-account.json"
  }
}
```

### 6. Test Connection
```powershell
# Start service and check logs
.\ScadaWatcherService.exe
Get-Content "C:\ProgramData\ScadaWatcher\Logs\scada-watcher-*.log" | Select-String "Firebase"
```

---

## 📊 Firestore Collections

### Structure
```
/alerts_active/{alertId}
├─ alertId: string
├─ nodeId: string
├─ ruleId: string
├─ severity: string (Info|Warning|Critical)
├─ currentState: string (Active|Acknowledged|Cleared)
├─ message: string
├─ triggerValue: double
├─ raisedTime: timestamp
├─ acknowledgedTime: timestamp?
├─ acknowledgedBy: string?
├─ clearedTime: timestamp?
└─ escalationCount: number

/alerts_history/{alertId}
└─ (same structure as active, archived when cleared)

/alert_events/{eventId}
├─ alertId: string
├─ eventType: string (Raised|Acknowledged|Cleared|Escalated)
├─ timestamp: timestamp
└─ metadata: map
```

---

## 🔒 Security Rules (Production)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Deny all client access - service account only
    match /{document=**} {
      allow read, write: if false;
    }
    
    // Allow authenticated mobile users to acknowledge only
    match /alerts_active/{alertId} {
      allow read: if request.auth != null;
      allow update: if request.auth != null 
                    && request.resource.data.diff(resource.data).affectedKeys()
                       .hasOnly(['acknowledgedTime', 'acknowledgedBy', 'currentState']);
    }
  }
}
```

---

## 📱 Cloud Messaging Topics

| Topic | Purpose | Severity |
|-------|---------|----------|
| `scada_alerts` | All alerts (default) | All |
| `scada_alerts_warning` | Warning-level alerts | Warning |
| `scada_alerts_critical` | Critical alerts only | Critical |
| `scada_alerts_escalation` | Escalated alerts (unacknowledged) | Critical |

### Subscribe in Flutter
```dart
await FirebaseMessaging.instance.subscribeToTopic('scada_alerts_critical');
```

---

## 🛠️ Common Operations

### View Active Alerts
```
Firebase Console → Firestore → alerts_active
```

### Manually Acknowledge Alert
```javascript
// In Firebase Console or mobile app
db.collection('alerts_active').doc(alertId).update({
  currentState: 'Acknowledged',
  acknowledgedTime: firebase.firestore.FieldValue.serverTimestamp(),
  acknowledgedBy: 'operator@scadaplant.com'
});
```

### Query Critical Alerts
```javascript
db.collection('alerts_active')
  .where('severity', '==', 'Critical')
  .where('currentState', '==', 'Active')
  .orderBy('raisedTime', 'desc')
  .get();
```

### Export Historical Data
```bash
gcloud firestore export gs://scada-watcher-backups/$(date +%Y%m%d) \
       --project=scada-watcher-prod-a1b2c \
       --collection-ids=alerts_history
```

---

## 🔍 Troubleshooting

### ❌ "Permission denied" Error
**Cause**: Service account file not accessible or security rules blocking

**Fix**:
```powershell
# Verify file exists
Test-Path "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json"

# Check permissions
icacls "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json"

# Verify service account has read access
```

### ❌ "Project not found"
**Cause**: Wrong Project ID in appsettings.json

**Fix**:
```powershell
# Check Project ID in service account JSON
Get-Content "C:\ProgramData\ScadaWatcher\Credentials\firebase-service-account.json" | ConvertFrom-Json | Select-Object project_id

# Update appsettings.json to match
```

### ❌ Mobile app not receiving push notifications
**Cause**: Topic subscription failed or FCM token not registered

**Fix**:
```dart
// Verify subscription
String? token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');

// Re-subscribe to topics
await FirebaseMessaging.instance.subscribeToTopic('scada_alerts_critical');
```

### ❌ High Firestore costs
**Cause**: Too many individual writes

**Fix**:
```json
// Increase batch size in appsettings.json
"Firebase": {
  "BatchSize": 50,
  "FlushIntervalMs": 5000
}
```

---

## 📈 Performance Tuning

### Recommended Indexes

Create in Firebase Console → Firestore → Indexes:

1. **Active alerts by severity and time**
   - Collection: `alerts_active`
   - Fields: `severity` (Asc), `raisedTime` (Desc)

2. **History by cleared time**
   - Collection: `alerts_history`
   - Fields: `clearedTime` (Desc), `severity` (Asc)

3. **Unacknowledged critical alerts**
   - Collection: `alerts_active`
   - Fields: `severity` (Asc), `currentState` (Asc), `raisedTime` (Desc)

---

## 🔐 Security Checklist

- [x] Service account JSON stored in secure directory
- [x] File permissions restricted (no user access)
- [x] Security rules set to deny-by-default
- [x] Service account key NOT in version control
- [x] HTTPS-only communication (automatic)
- [x] Network firewall rules configured
- [x] Audit logging enabled
- [x] Key rotation schedule documented (annually)

---

## 📞 Support

| Issue | Resource |
|-------|----------|
| Firebase Console | https://console.firebase.google.com |
| Firestore Docs | https://firebase.google.com/docs/firestore |
| FCM Docs | https://firebase.google.com/docs/cloud-messaging |
| Security Rules | https://firebase.google.com/docs/firestore/security/rules-structure |
| Pricing | https://firebase.google.com/pricing |

---

## 💰 Cost Estimates (Small SCADA Plant)

**Assumptions**:
- 100 OPC UA nodes
- 10 alerts/day average
- 1,000 alert history records
- 5 mobile users

**Firestore**:
- Reads: ~1,000/day × $0.06/100k = $0.02/day
- Writes: ~50/day × $0.18/100k = $0.01/day
- Storage: 1 GB × $0.18/GB/month = $0.18/month
- **Total: ~$1/month**

**Cloud Messaging**:
- Free (unlimited notifications)

**Grand Total: ~$1-2/month** (well within free tier initially)

---

**Version**: 1.0  
**Last Updated**: 2026-01-25
