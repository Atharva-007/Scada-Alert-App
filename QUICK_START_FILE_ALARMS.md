# ⚡ QUICK START - File-to-Cloud Alarm System

**Get running in 5 minutes!**

---

## 🎯 WHAT YOU HAVE

A **simplified alarm monitoring system** that:
1. Reads alarm files from a folder (`C:\ScadaAlarms\AlertFiles`)
2. Pushes alerts **directly to Firebase Cloud** (Firestore)
3. Sends **push notifications** to mobile devices
4. Displays alerts in **Flutter mobile app** (real-time)

**NO OPC UA. NO complex setup. Just files → cloud → mobile.**

---

## 🚀 5-MINUTE SETUP

### **Step 1: Get Firebase Key** (2 minutes)

1. Go to: https://console.firebase.google.com/project/scadadataserver/settings/serviceaccounts
2. Click: **"Generate new private key"**
3. Save file to: `C:\ScadaAlarms\firebase-service-account.json`

### **Step 2: Create Alert Folder** (30 seconds)

```powershell
New-Item -Path "C:\ScadaAlarms\AlertFiles" -ItemType Directory -Force
```

### **Step 3: Install Service** (2 minutes)

```powershell
# Build and install
cd E:\scada_alarm_client\ScadaWatcherService
dotnet publish -c Release -o C:\Services\ScadaAlarmWatcher

# Install service
sc.exe create ScadaAlarmWatcher `
  binPath= "C:\Services\ScadaAlarmWatcher\ScadaWatcherService.exe" `
  start= delayed-auto

# Start service
sc.exe start ScadaAlarmWatcher
```

### **Step 4: Test It!** (30 seconds)

```powershell
# Create test alarm
$time = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
"$time,Test alarm - System is working!" | Out-File "C:\ScadaAlarms\AlertFiles\test.csv" -Encoding UTF8
```

**Expected:** Alert appears in Firebase Console + Mobile app in < 5 seconds!

---

## 📁 FILE FORMAT

**Simple CSV/TXT format:**
```csv
timestamp,message
2026-01-26 10:30:15,High temperature in Reactor A
2026-01-26 10:31:22,Pressure exceeds threshold
```

**With severity:**
```csv
timestamp,severity,message
2026-01-26 10:30:15,Critical,High temperature in Reactor A
2026-01-26 10:31:22,Warning,Pressure exceeds threshold
```

---

## 📱 MOBILE APP

### **Run App:**
```bash
cd E:\scada_alarm_client
flutter run
```

### **Features:**
- ✅ Real-time alert display (< 5 second latency)
- ✅ Push notifications on lock screen
- ✅ Acknowledge alerts
- ✅ Search & filter
- ✅ Alert history

---

## 🔍 VERIFY IT'S WORKING

### **Check Service Status:**
```powershell
sc.exe query ScadaAlarmWatcher
```

**Expected:** `STATE: 4 RUNNING`

### **Check Logs:**
```powershell
Get-Content C:\Logs\ScadaWatcher\ScadaWatcher-*.log -Tail 20
```

**Expected:** See `"🚨 ALARM DETECTED"` and `"✅ Alert pushed to Firebase"`

### **Check Firebase Console:**
1. Go to: https://console.firebase.google.com/project/scadadataserver/firestore
2. Open: `alerts` collection
3. See your test alert document

---

## 🎨 CUSTOMIZATION

### **Change Watch Folder:**

Edit: `C:\Services\ScadaAlarmWatcher\appsettings.json`

```json
{
  "AlarmFileWatcher": {
    "WatchFolder": "D:\\YourFolder\\Alarms"
  }
}
```

Restart service: `sc.exe stop ScadaAlarmWatcher && sc.exe start ScadaAlarmWatcher`

### **Change Notification Settings:**

```json
{
  "Firebase": {
    "SendNotificationsForCritical": true,
    "SendNotificationsForWarning": true,
    "SendNotificationsForInfo": false
  }
}
```

---

## 🐛 TROUBLESHOOTING

### **Alerts not appearing?**

1. Check service running: `sc.exe query ScadaAlarmWatcher`
2. Check logs: `Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50`
3. Verify Firebase key exists: `Test-Path C:\ScadaAlarms\firebase-service-account.json`
4. Check file format (CSV/TXT with comma separator)

### **Push notifications not working?**

1. Check mobile app has notification permissions
2. Verify device subscribed to topic: `scada_alerts`
3. Test in Firebase Console: Cloud Messaging → Send test message

---

## 📚 DOCUMENTATION

- **Full Guide:** `SIMPLIFIED_ALARM_SYSTEM.md`
- **Architecture Analysis:** `PROJECT_INTEGRATION_ANALYSIS.md`
- **Firebase Setup:** `FIREBASE_CLOUD_BACKEND_COMPLETE.md`
- **Mobile App:** `README.md`

---

## ✅ SUMMARY

**What you configured:**
- ✅ Windows Service monitoring `C:\ScadaAlarms\AlertFiles`
- ✅ Firebase project: `scadadataserver`
- ✅ Direct cloud push (no intermediate services)
- ✅ Mobile app with real-time updates

**What happens:**
1. You create/update file in `C:\ScadaAlarms\AlertFiles`
2. Service detects file within 1 second
3. Alert pushed to Firebase Firestore
4. Push notification sent to mobile devices
5. Flutter app displays alert in real-time

**Total latency:** < 5 seconds from file creation to mobile display

**That's it! Your alarm system is live!** 🎉

---

**Need help?** Check logs at: `C:\Logs\ScadaWatcher\ScadaWatcher-*.log`
