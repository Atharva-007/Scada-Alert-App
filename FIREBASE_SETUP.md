# 🔥 Firebase Integration Guide

## Current Status: ✅ Integrated with Auto-Fallback

The app now has **full Firebase integration** with intelligent fallback to mock data when Firebase is unavailable.

---

## 🚀 Quick Start (3 Options)

### Option 1: Run with Mock Data (No Setup Required)
```bash
flutter run
```
- App works immediately with mock data
- No Firebase configuration needed
- Perfect for development and testing

### Option 2: Connect to Real Firebase
1. Get your `google-services.json` from Firebase Console
2. Place it in `android/app/google-services.json`
3. Update `lib/firebase_options.dart` with your project details
4. Run: `flutter run`

### Option 3: Use Firebase Emulator Suite
```bash
firebase emulators:start
flutter run
```

---

## 📋 Setting Up Firebase (Step-by-Step)

### Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Name it: `scada-alarm-system`
4. Disable Google Analytics (optional)
5. Click "Create project"

### Step 2: Add Android App
1. In Firebase Console, click "Add app" → Android
2. Package name: `com.scada.alarm_monitor`
3. Download `google-services.json`
4. Place in: `E:\scada_alarm_client\android\app\google-services.json`

### Step 3: Update Firebase Options
Edit `lib/firebase_options.dart`:

```dart
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_API_KEY_HERE',              // From google-services.json
    appId: 'YOUR_APP_ID_HERE',                // From google-services.json
    messagingSenderId: 'YOUR_SENDER_ID_HERE', // From google-services.json
    projectId: 'scada-alarm-system',          // Your project ID
    storageBucket: 'scada-alarm-system.appspot.com',
  );
}
```

### Step 4: Enable Firestore
1. In Firebase Console → Firestore Database
2. Click "Create database"
3. Start in **test mode** (for development)
4. Choose location closest to you
5. Click "Enable"

### Step 5: Set Up Collections
Create these collections in Firestore:

#### Collection: `alerts_active`
```javascript
{
  "id": "alert-001",
  "name": "High Temperature Alert",
  "description": "Reactor core temperature exceeded safe threshold",
  "severity": "critical",
  "source": "Reactor-1",
  "tagName": "REACTOR1.TEMP",
  "currentValue": 285.5,
  "threshold": 250.0,
  "condition": "Greater Than",
  "raisedAt": timestamp,
  "isActive": true,
  "isAcknowledged": false,
  "isSuppressed": false,
  "escalationLevel": 0,
  "suppressionCount": 0,
  "relatedAlertIds": [],
  "trendData": []
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
  "raisedAt": timestamp,
  "clearedAt": timestamp,
  "acknowledgedAt": timestamp,
  "acknowledgedBy": "operator@plant.com",
  "isActive": false,
  "isAcknowledged": true
}
```

#### Collection: `system_status`
```javascript
{
  "componentName": "OPC UA",
  "status": "online",
  "lastHeartbeat": timestamp,
  "version": "1.5.2",
  "metadata": {
    "connectedTags": 245,
    "samplingRate": "1000ms"
  }
}
```

### Step 6: Configure Security Rules
In Firestore → Rules, add:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read access to all authenticated users
    match /alerts_active/{document=**} {
      allow read: if true;  // Change to auth requirement in production
      allow write: if true; // Restrict to server/backend in production
    }
    
    match /alerts_history/{document=**} {
      allow read: if true;
      allow write: if true;
    }
    
    match /system_status/{document=**} {
      allow read: if true;
      allow write: if true;
    }
  }
}
```

⚠️ **Production:** Replace `if true` with proper authentication rules!

### Step 7: Enable Cloud Messaging (Optional)
1. Firebase Console → Cloud Messaging
2. Click "Get started"
3. No additional configuration needed
4. Tokens will be generated automatically

---

## 🧪 Testing the Integration

### Test 1: Verify Firebase Connection
```bash
flutter run
```

Check console output:
```
✅ Firebase initialized successfully
✅ Push notifications configured
✅ Notification service initialized
```

### Test 2: Add Test Data
1. Open Firebase Console → Firestore
2. Add a document to `alerts_active` collection
3. App should show it in Active Alerts screen

### Test 3: Test Acknowledgment
1. Open an alert
2. Click "Acknowledge Alert"
3. Check Firestore - `isAcknowledged` should be `true`

### Test 4: Test Offline Mode
1. Disable internet
2. App continues to work with cached/mock data
3. Acknowledgments queued until online

---

## 🔧 Troubleshooting

### Error: "Firebase initialization failed"
**Solution:** App runs in offline mode - no action needed!

### Error: "google-services.json not found"
**Solution:** Either:
- Add the file to `android/app/`
- Or use mock data mode (default)

### Error: "Permission denied" in Firestore
**Solution:** Update security rules (see Step 6)

### Alerts not loading from Firebase
**Checklist:**
- ✅ Firebase initialized successfully?
- ✅ Internet connection active?
- ✅ Firestore collections exist?
- ✅ Security rules allow read?

---

## 📊 How the Auto-Fallback Works

The app uses **intelligent fallback logic**:

```dart
// Tries Firebase first
try {
  return firestore.collection('alerts_active').snapshots();
} catch (e) {
  // Falls back to mock data automatically
  return mockDataStream;
}
```

**Benefits:**
- ✅ Works offline
- ✅ No errors if Firebase not configured
- ✅ Seamless development experience
- ✅ Production-ready when Firebase added

---

## 🚀 Deployment Modes

### Development Mode (Current)
- Mock data available
- Firebase optional
- Test mode security rules
- Debug logging enabled

### Staging Mode (Recommended)
1. Create separate Firebase project: `scada-alarm-staging`
2. Use test data
3. Enable authentication
4. Restricted security rules

### Production Mode (Final)
1. Production Firebase project
2. Strict security rules
3. User authentication required
4. Audit logging enabled
5. Disable mock data:

```dart
AlertRepository({
  firestore: FirebaseFirestore.instance,
  useMockData: false,  // Set to false for production
});
```

---

## 📱 Push Notifications Setup

### Step 1: Generate FCM Server Key
1. Firebase Console → Project Settings → Cloud Messaging
2. Copy "Server key"
3. Save for backend integration

### Step 2: Test Push Notifications
```bash
# Send test notification
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "/topics/critical_alerts",
    "notification": {
      "title": "Critical Alert",
      "body": "High temperature detected",
      "sound": "default"
    }
  }'
```

### Step 3: Subscribe to Topics
Topics are auto-subscribed on app start:
- `all_alerts`
- `critical_alerts`
- `warning_alerts`
- `info_alerts`

---

## 🎯 Next Steps

### Immediate (This Week)
- [ ] Add real Firebase project
- [ ] Import sample alert data
- [ ] Test acknowledgment flow
- [ ] Configure push notifications

### Short Term (2 Weeks)
- [ ] Add user authentication
- [ ] Implement role-based access
- [ ] Set up production security rules
- [ ] Configure offline persistence

### Long Term (1 Month)
- [ ] Backend sync service (OPC UA → Firebase)
- [ ] Analytics integration
- [ ] Custom notification sounds
- [ ] Multi-tenant support

---

## 📚 Resources

- [Firebase Console](https://console.firebase.google.com/)
- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Cloud Messaging Guide](https://firebase.google.com/docs/cloud-messaging)
- [Security Rules Reference](https://firebase.google.com/docs/firestore/security/get-started)

---

## ✅ Firebase Integration Checklist

### Setup
- [ ] Firebase project created
- [ ] Android app registered
- [ ] `google-services.json` downloaded
- [ ] `firebase_options.dart` updated
- [ ] Firestore enabled
- [ ] Collections created

### Testing
- [ ] App connects to Firebase
- [ ] Alerts load from Firestore
- [ ] Acknowledgment updates Firestore
- [ ] Offline mode works
- [ ] Push notifications received

### Production Ready
- [ ] Security rules configured
- [ ] Authentication enabled
- [ ] Backup strategy defined
- [ ] Monitoring set up
- [ ] Rate limits configured

---

**Status:** 🟢 Ready to Connect to Firebase  
**Fallback:** 🟢 Mock Data Available  
**Production:** 🟡 Requires Authentication Setup
