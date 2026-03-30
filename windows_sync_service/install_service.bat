@echo off
REM ====================================================
REM SCADA Alarm Sync Service - Build & Install Script
REM ====================================================

echo.
echo ====================================
echo SCADA Alarm Cloud Sync Service
echo Build and Installation Script
echo ====================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges
    echo Please run as Administrator
    pause
    exit /b 1
)

echo [1/6] Stopping existing service if running...
sc query ScadaAlarmSyncService >nul 2>&1
if %errorLevel% equ 0 (
    echo Stopping service...
    net stop ScadaAlarmSyncService
    timeout /t 3 >nul
    echo Uninstalling old service...
    sc delete ScadaAlarmSyncService
    timeout /t 2 >nul
)

echo [2/6] Building the service...
dotnet build ScadaAlarmSyncService.csproj -c Release
if %errorLevel% neq 0 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

echo [3/6] Creating required directories...
if not exist "C:\ScadaAlarms" mkdir "C:\ScadaAlarms"
if not exist "C:\ScadaAlarms\Logs" mkdir "C:\ScadaAlarms\Logs"

echo [4/6] Checking Firebase service account...
if not exist "C:\ScadaAlarms\firebase-service-account.json" (
    echo WARNING: Firebase service account not found
    echo Please download it from Firebase Console:
    echo 1. Go to Firebase Console ^> Project Settings
    echo 2. Service Accounts tab
    echo 3. Click "Generate new private key"
    echo 4. Save as C:\ScadaAlarms\firebase-service-account.json
    echo.
    pause
)

echo [5/6] Installing the Windows Service...
set SERVICE_PATH=%~dp0bin\Release\net6.0-windows\ScadaAlarmSyncService.exe
sc create ScadaAlarmSyncService binPath= "%SERVICE_PATH%" start= auto
if %errorLevel% neq 0 (
    echo ERROR: Service installation failed
    pause
    exit /b 1
)

sc description ScadaAlarmSyncService "Synchronizes SCADA alarm data with Firebase cloud backend"
sc failure ScadaAlarmSyncService reset= 86400 actions= restart/60000/restart/60000/restart/60000

echo [6/6] Starting the service...
net start ScadaAlarmSyncService

echo.
echo ====================================
echo Installation completed successfully!
echo ====================================
echo.
echo Service Name: ScadaAlarmSyncService
echo Status: Running
echo Logs: C:\ScadaAlarms\Logs\sync_service.log
echo Database: C:\ScadaAlarms\alerts.db
echo.
echo To view logs: type C:\ScadaAlarms\Logs\sync_service.log
echo To stop: net stop ScadaAlarmSyncService
echo To start: net start ScadaAlarmSyncService
echo To uninstall: sc delete ScadaAlarmSyncService
echo.
pause
