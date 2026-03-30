@echo off
REM Quick Setup Script for SCADA Alarm System Firebase Cloud
REM This script guides you through the complete Firebase setup

echo ============================================
echo   SCADA ALARM SYSTEM - FIREBASE SETUP
echo ============================================
echo.

set PROJECT_ID=scadadataserver

echo This script will help you set up Firebase Cloud for your SCADA Alarm System.
echo.
echo REQUIREMENTS:
echo   1. Internet connection
echo   2. Firebase account
echo   3. Admin access to Firebase project: %PROJECT_ID%
echo.

pause
cls

echo ============================================
echo   STEP 1: Verify Prerequisites
echo ============================================
echo.

echo Checking Firebase CLI...
firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Firebase CLI not installed!
    echo.
    echo Please install: npm install -g firebase-tools
    echo Then run this script again.
    pause
    exit /b 1
) else (
    echo [OK] Firebase CLI installed
)

echo Checking Flutter...
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Flutter not installed!
    echo.
    echo Please install Flutter from: https://flutter.dev
    pause
    exit /b 1
) else (
    echo [OK] Flutter installed
)

echo.
echo All prerequisites installed!
echo.
pause

cls

echo ============================================
echo   STEP 2: Create Firestore Database
echo ============================================
echo.
echo IMPORTANT: This is the most critical step!
echo.
echo Please follow these steps in your web browser:
echo.
echo 1. Opening Firebase Console...
echo.

start https://console.firebase.google.com/project/%PROJECT_ID%/firestore

echo.
echo 2. Click "Create database" button
echo 3. Select "Production mode"
echo 4. Choose location: "us-central" (or closest to you)
echo 5. Click "Enable"
echo.
echo Wait for the database to be created (1-2 minutes)
echo.

set /p DB_CREATED="Have you created the database? (y/n): "
if /i not "%DB_CREATED%"=="y" (
    echo.
    echo Please create the database first, then run this script again.
    pause
    exit /b 1
)

echo.
echo [OK] Firestore database created!
echo.
pause

cls

echo ============================================
echo   STEP 3: Enable Firebase Services
echo ============================================
echo.

echo Opening Authentication settings...
start https://console.firebase.google.com/project/%PROJECT_ID%/authentication
echo.
echo Enable these sign-in methods:
echo   - Email/Password
echo   - Anonymous
echo.
pause

echo.
echo Opening Cloud Storage settings...
start https://console.firebase.google.com/project/%PROJECT_ID%/storage
echo.
echo Click "Get started" and use Production mode
echo.
pause

cls

echo ============================================
echo   STEP 4: Download Service Account Key
echo ============================================
echo.

echo Opening Service Accounts settings...
start https://console.firebase.google.com/project/%PROJECT_ID%/settings/serviceaccounts
echo.
echo Please:
echo   1. Click "Generate new private key"
echo   2. Download the JSON file
echo   3. Save it as: C:\ScadaAlarms\firebase-service-account.json
echo.

set /p KEY_DOWNLOADED="Have you downloaded and saved the key? (y/n): "
if /i not "%KEY_DOWNLOADED%"=="y" (
    echo.
    echo Please download the service account key, then run this script again.
    pause
    exit /b 1
)

echo.
echo Verifying service account key...
if not exist "C:\ScadaAlarms\firebase-service-account.json" (
    echo [ERROR] Service account key not found at C:\ScadaAlarms\firebase-service-account.json
    echo Please make sure you saved it to the correct location.
    pause
    exit /b 1
)

echo [OK] Service account key found!
echo.
pause

cls

echo ============================================
echo   STEP 5: Deploy Security Rules
echo ============================================
echo.

echo Deploying Firestore security rules...
firebase deploy --only firestore:rules --project %PROJECT_ID%

if %errorlevel% neq 0 (
    echo [ERROR] Failed to deploy Firestore rules
    pause
    exit /b 1
)

echo.
echo Deploying Storage security rules...
firebase deploy --only storage:rules --project %PROJECT_ID%

if %errorlevel% neq 0 (
    echo [ERROR] Failed to deploy Storage rules
    pause
    exit /b 1
)

echo.
echo Deploying Firestore indexes...
firebase deploy --only firestore:indexes --project %PROJECT_ID%

echo.
echo [OK] Security rules deployed!
echo.
pause

cls

echo ============================================
echo   STEP 6: Upload Sample Data
echo ============================================
echo.

echo Choose how to upload sample data:
echo.
echo   1. Manual upload via Firebase Console (Recommended)
echo   2. Automatic upload via Windows Sync Service
echo   3. Skip for now
echo.

set /p DATA_CHOICE="Enter choice (1-3): "

if "%DATA_CHOICE%"=="1" (
    echo.
    echo Opening Firestore Console...
    start https://console.firebase.google.com/project/%PROJECT_ID%/firestore
    echo.
    echo Please create these collections manually:
    echo.
    echo Collection: alerts
    echo   Document ID: alert-001
    echo   Fields:
    echo     - id: "alert-001"
    echo     - title: "High Temperature - Reactor 1"
    echo     - description: "Temperature exceeded 85°C"
    echo     - severity: "critical"
    echo     - status: "active"
    echo     - timestamp: [Use current timestamp]
    echo.
    echo Collection: system_status
    echo   Document ID: current
    echo   Fields:
    echo     - status: "normal"
    echo     - active_alerts_count: 0
    echo     - last_update: [Use current timestamp]
    echo.
    pause
)

if "%DATA_CHOICE%"=="2" (
    echo.
    echo Creating local SQLite database with sample data...
    powershell -ExecutionPolicy Bypass -File seed_database.ps1
    
    echo.
    echo Sample data created in local database.
    echo The Windows Sync Service will upload it to Firebase.
    echo.
    pause
)

cls

echo ============================================
echo   STEP 7: Test Flutter App
echo ============================================
echo.

echo Installing Flutter dependencies...
flutter pub get

if %errorlevel% neq 0 (
    echo [ERROR] Failed to install Flutter dependencies
    pause
    exit /b 1
)

echo.
echo [OK] Dependencies installed!
echo.

set /p RUN_APP="Would you like to run the Flutter app now? (y/n): "
if /i "%RUN_APP%"=="y" (
    echo.
    echo Starting Flutter app...
    echo.
    flutter run
)

cls

echo ============================================
echo   SETUP COMPLETE!
echo ============================================
echo.
echo Your SCADA Alarm System Firebase Cloud is now set up!
echo.
echo What's configured:
echo   [OK] Firestore Database
echo   [OK] Authentication
echo   [OK] Cloud Storage
echo   [OK] Security Rules
echo   [OK] Service Account Key
echo   [OK] Sample Data (if uploaded)
echo.
echo Next steps:
echo   1. Run the Flutter app: flutter run
echo   2. Set up Windows Sync Service (optional):
echo      cd windows_sync_service
echo      .\test_service.bat
echo   3. Monitor Firebase Console:
echo      https://console.firebase.google.com/project/%PROJECT_ID%
echo.
echo Documentation:
echo   - Complete Guide: FIREBASE_COMPLETE_SETUP_GUIDE.md
echo   - Analysis: COMPLETE_ANALYSIS_AND_STATUS.md
echo   - Quick Reference: README.md
echo.
echo To verify setup:
echo   powershell -ExecutionPolicy Bypass -File verify_complete_setup.ps1
echo.

pause
