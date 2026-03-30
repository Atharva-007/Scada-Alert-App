@echo off
REM ====================================================
REM SCADA Firebase Cloud Backend - Setup Verification
REM ====================================================

echo.
echo ================================================
echo SCADA Alarm System - Firebase Setup Verification
echo ================================================
echo.

echo [Step 1] Checking Firebase CLI...
firebase --version
if %errorLevel% neq 0 (
    echo ❌ Firebase CLI not found. Install: npm install -g firebase-tools
    pause
    exit /b 1
)
echo ✅ Firebase CLI installed
echo.

echo [Step 2] Checking Firebase project...
firebase projects:list | findstr "scadadataserver"
if %errorLevel% neq 0 (
    echo ❌ Project scadadataserver not found
    pause
    exit /b 1
)
echo ✅ Project scadadataserver found
echo.

echo [Step 3] Checking Firebase configuration files...

if exist "firebase.json" (
    echo ✅ firebase.json exists
) else (
    echo ❌ firebase.json missing
)

if exist "firestore.rules" (
    echo ✅ firestore.rules exists
) else (
    echo ❌ firestore.rules missing
)

if exist "storage.rules" (
    echo ✅ storage.rules exists
) else (
    echo ❌ storage.rules missing
)

if exist "firestore.indexes.json" (
    echo ✅ firestore.indexes.json exists
) else (
    echo ❌ firestore.indexes.json missing
)
echo.

echo [Step 4] Checking Flutter Firebase configuration...

if exist "lib\firebase_options.dart" (
    echo ✅ firebase_options.dart exists
    findstr "scadadataserver" lib\firebase_options.dart >nul
    if %errorLevel% equ 0 (
        echo ✅ Project ID configured correctly
    ) else (
        echo ⚠ Project ID may not be configured
    )
) else (
    echo ❌ firebase_options.dart missing
)
echo.

echo [Step 5] Checking Windows Service files...

if exist "windows_sync_service\ScadaAlarmSyncService.cs" (
    echo ✅ Service source code exists
) else (
    echo ❌ Service source code missing
)

if exist "windows_sync_service\ScadaAlarmSyncService.csproj" (
    echo ✅ C# project file exists
) else (
    echo ❌ C# project file missing
)

if exist "windows_sync_service\install_service.bat" (
    echo ✅ Installation script exists
) else (
    echo ❌ Installation script missing
)
echo.

echo [Step 6] Checking Authentication Service...

if exist "lib\core\services\auth_service.dart" (
    echo ✅ Auth service exists
) else (
    echo ❌ Auth service missing
)

if exist "lib\features\auth\presentation\login_screen.dart" (
    echo ✅ Login screen exists
) else (
    echo ❌ Login screen missing
)
echo.

echo [Step 7] Checking required directories...

if exist "C:\ScadaAlarms" (
    echo ✅ C:\ScadaAlarms exists
) else (
    echo ⚠ C:\ScadaAlarms not created yet
    echo   Will be created during service installation
)

if exist "C:\ScadaAlarms\Logs" (
    echo ✅ C:\ScadaAlarms\Logs exists
) else (
    echo ⚠ Logs directory not created yet
)

if exist "C:\ScadaAlarms\firebase-service-account.json" (
    echo ✅ Firebase service account key exists
) else (
    echo ❌ Service account key missing
    echo   Download from: Firebase Console ^> Project Settings ^> Service Accounts
    echo   Save as: C:\ScadaAlarms\firebase-service-account.json
)
echo.

echo ================================================
echo Verification Complete!
echo ================================================
echo.
echo 📋 NEXT STEPS:
echo.
echo 1. Create Firestore Database in Firebase Console:
echo    - Go to: https://console.firebase.google.com/project/scadadataserver/firestore
echo    - Click: "Create database"
echo    - Select: Production mode
echo    - Choose: Nearest region
echo.
echo 2. Enable Firebase Authentication:
echo    - Go to: Authentication ^> Sign-in method
echo    - Enable: Email/Password
echo    - Enable: Anonymous
echo.
echo 3. Enable Cloud Storage:
echo    - Go to: Storage
echo    - Click: "Get started"
echo    - Select: Production mode
echo.
echo 4. Download Service Account Key:
echo    - Go to: Project Settings ^> Service Accounts
echo    - Click: "Generate new private key"
echo    - Save as: C:\ScadaAlarms\firebase-service-account.json
echo.
echo 5. Deploy Firebase Rules:
echo    firebase deploy --only firestore:rules,storage:rules --project scadadataserver
echo.
echo 6. Install Windows Sync Service:
echo    cd windows_sync_service
echo    .\install_service.bat (Run as Administrator)
echo.
echo 7. Test Flutter App:
echo    flutter run
echo.
echo 📚 Full Documentation: FIREBASE_CLOUD_BACKEND_COMPLETE.md
echo.
pause
