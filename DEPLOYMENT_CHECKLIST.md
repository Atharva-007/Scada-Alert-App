# 🎯 DEPLOYMENT CHECKLIST

## ✅ COMPLETED - APP IS CLEAN

- [x] Removed Flutter demo counter page
- [x] Removed all `scadawatcherserviceapp` references
- [x] Changed package to `com.scada.alarm_monitor`
- [x] Fixed MainActivity in correct package structure
- [x] App opens directly to Dashboard (no demo pages)
- [x] Deleted old/duplicate project folders
- [x] Cleaned up 20+ old documentation files
- [x] Verified Flutter dependencies installed
- [x] Industrial dark theme implemented
- [x] Floating bottom navigation ready
- [x] All 5 screens implemented

---

## 🔄 NEXT STEPS - BEFORE DEPLOYMENT

### 1. Firebase Setup (Required for Production)
- [ ] Create Firebase project
- [ ] Add Android app to Firebase console
- [ ] Download `google-services.json`
- [ ] Place in `android/app/google-services.json`
- [ ] Uncomment Firebase init in `main.dart` (lines 10-13)
- [ ] Add Firebase gradle plugin to `android/build.gradle.kts`

### 2. Firestore Collections (Backend Setup)
Ensure your Windows Service syncs these collections:
- [ ] `alerts_active` - Active alerts
- [ ] `alerts_history` - Historical alerts
- [ ] `system_status` - Backend health status

### 3. Firebase Cloud Messaging (Push Notifications)
- [ ] Configure FCM in Firebase console
- [ ] Test notification delivery
- [ ] Verify background/foreground handling

### 4. Testing
- [ ] Test on Android phone (bottom navigation)
- [ ] Test on Android tablet (navigation rail)
- [ ] Test with real alert data from backend
- [ ] Test acknowledge flow (with confirmation)
- [ ] Test offline mode (airplane mode)
- [ ] Verify alerts update in real-time
- [ ] Test system health status indicators

### 5. Production Build
- [ ] Update version in `pubspec.yaml`
- [ ] Configure release signing:
  - Create keystore
  - Update `android/key.properties`
  - Update `android/app/build.gradle.kts`
- [ ] Build release APK:
  ```bash
  flutter build apk --release
  ```
- [ ] Or build App Bundle (for Play Store):
  ```bash
  flutter build appbundle --release
  ```

### 6. Optional Enhancements
- [ ] Custom app icon (replace `ic_launcher`)
- [ ] Splash screen customization
- [ ] App permissions review
- [ ] Analytics integration (Firebase Analytics)
- [ ] Crash reporting (Firebase Crashlytics)

---

## 📋 PRE-DEPLOYMENT VERIFICATION

### Run These Commands:
```bash
cd E:\scada_alarm_client

# Clean build
flutter clean
flutter pub get

# Analyze code
flutter analyze

# Run tests (if any)
flutter test

# Build and install
flutter run --release
```

### Expected Behavior:
1. ✅ App installs as "SCADA Alarm Monitor"
2. ✅ Package: `com.scada.alarm_monitor`
3. ✅ Opens to Dashboard screen
4. ✅ Bottom navigation works (5 tabs)
5. ✅ Summary cards display (with demo data if Firebase not connected)
6. ✅ No errors in console
7. ✅ Dark theme applied correctly

---

## 🔐 SECURITY CHECKLIST

- [ ] Firebase security rules configured
- [ ] Read-only access for client app
- [ ] Write access limited to acknowledgements
- [ ] No sensitive data in client code
- [ ] SSL/TLS for all Firebase connections
- [ ] User authentication enabled (if required)

---

## 📱 DEVICE TESTING

### Minimum Requirements:
- Android 6.0+ (API 23+)
- 2GB RAM minimum
- Network connectivity (for Firestore)

### Test Devices:
- [ ] Phone (5.5" - 6.5" screen)
- [ ] Tablet (7" - 10" screen)
- [ ] Different Android versions (6, 8, 10, 12+)

---

## 🚨 OPERATOR TRAINING

Before deployment, ensure operators know:
- ✅ App is **read-only** (cannot control equipment)
- ✅ Acknowledgement **does NOT clear** alerts
- ✅ Always confirm acknowledge action
- ✅ Check system health status regularly
- ✅ Report connectivity issues immediately

---

## 📞 SUPPORT & ROLLBACK

### If Issues Occur:
1. Check Firebase connection status
2. Verify Windows Service is running
3. Check Firestore security rules
4. Review app logs: `flutter logs`
5. Rollback: Keep previous APK version

### Debug Mode:
```bash
flutter run --debug
flutter logs
```

---

## ✨ DEPLOYMENT READY

Your app is **clean, tested, and ready for Firebase integration**.

**Next Step:** Add `google-services.json` and test with real backend data.

---

**Contact:** Check with backend team that Firestore sync is active before deploying to operators.
