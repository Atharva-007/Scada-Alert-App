# Quick Deploy Script for GOT_Alarms Integration
# This script sets up the Windows Service to monitor C:\GOT_Alarms

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "   SCADA Alarm Watcher - GOT_Alarms Setup" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n❌ ERROR: This script must run as Administrator" -ForegroundColor Red
    Write-Host "   Right-click PowerShell and select 'Run as Administrator'`n" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "`n✅ Running as Administrator" -ForegroundColor Green

# Step 1: Check GOT_Alarms folder
Write-Host "`n📁 Step 1: Checking GOT_Alarms folder..." -ForegroundColor Yellow

if (Test-Path "C:\GOT_Alarms") {
    $fileCount = (Get-ChildItem "C:\GOT_Alarms" -Filter "*.csv").Count
    Write-Host "   ✅ Folder exists: C:\GOT_Alarms" -ForegroundColor Green
    Write-Host "   ✅ Found $fileCount CSV files" -ForegroundColor Green
} else {
    Write-Host "   ❌ Folder not found: C:\GOT_Alarms" -ForegroundColor Red
    Write-Host "   Creating folder..." -ForegroundColor Yellow
    New-Item -Path "C:\GOT_Alarms" -ItemType Directory -Force | Out-Null
    Write-Host "   ✅ Created: C:\GOT_Alarms" -ForegroundColor Green
}

# Step 2: Check Firebase service account key
Write-Host "`n🔑 Step 2: Checking Firebase service account key..." -ForegroundColor Yellow

if (-not (Test-Path "C:\ScadaAlarms")) {
    New-Item -Path "C:\ScadaAlarms" -ItemType Directory -Force | Out-Null
}

if (Test-Path "C:\ScadaAlarms\firebase-service-account.json") {
    Write-Host "   ✅ Firebase key found" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Firebase key NOT found" -ForegroundColor Red
    Write-Host "`n   ACTION REQUIRED:" -ForegroundColor Yellow
    Write-Host "   1. Go to: https://console.firebase.google.com/project/scadadataserver/settings/serviceaccounts"
    Write-Host "   2. Click: 'Generate new private key'"
    Write-Host "   3. Save as: C:\ScadaAlarms\firebase-service-account.json"
    Write-Host ""
    
    $continue = Read-Host "   Have you done this? (y/n)"
    if ($continue -ne "y") {
        Write-Host "`n   Please complete this step first, then run this script again.`n" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit
    }
}

# Step 3: Build service
Write-Host "`n🔨 Step 3: Building Windows Service..." -ForegroundColor Yellow

$serviceFolder = "E:\scada_alarm_client\ScadaWatcherService"
$outputFolder = "C:\Services\ScadaAlarmWatcher"

if (-not (Test-Path $serviceFolder)) {
    Write-Host "   ❌ Service source not found: $serviceFolder" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "   Building service..." -ForegroundColor Gray
Set-Location $serviceFolder

try {
    dotnet publish --configuration Release --output $outputFolder --verbosity quiet
    Write-Host "   ✅ Service built successfully" -ForegroundColor Green
    Write-Host "   📂 Output: $outputFolder" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Build failed: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

# Step 4: Check if service already exists
Write-Host "`n🔧 Step 4: Checking existing service..." -ForegroundColor Yellow

$serviceName = "ScadaAlarmWatcher"
$existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($existingService) {
    Write-Host "   ⚠️  Service already exists" -ForegroundColor Yellow
    Write-Host "   Current status: $($existingService.Status)" -ForegroundColor Gray
    
    $reinstall = Read-Host "   Reinstall service? (y/n)"
    if ($reinstall -eq "y") {
        Write-Host "   Stopping service..." -ForegroundColor Gray
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        Write-Host "   Removing service..." -ForegroundColor Gray
        sc.exe delete $serviceName | Out-Null
        Start-Sleep -Seconds 2
        Write-Host "   ✅ Old service removed" -ForegroundColor Green
    } else {
        Write-Host "`n   Skipping installation. Updating files only." -ForegroundColor Yellow
        Write-Host "   You may need to restart the service manually.`n" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit
    }
}

# Step 5: Install service
Write-Host "`n📦 Step 5: Installing Windows Service..." -ForegroundColor Yellow

$binPath = "$outputFolder\ScadaWatcherService.exe"
$displayName = "SCADA Alarm Watcher - GOT Alarms"

try {
    sc.exe create $serviceName `
        binPath= $binPath `
        start= delayed-auto `
        DisplayName= $displayName | Out-Null
    
    Write-Host "   ✅ Service installed successfully" -ForegroundColor Green
    Write-Host "   Name: $serviceName" -ForegroundColor Gray
    Write-Host "   Display: $displayName" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Installation failed: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

# Step 6: Start service
Write-Host "`n▶️  Step 6: Starting service..." -ForegroundColor Yellow

try {
    sc.exe start $serviceName | Out-Null
    Start-Sleep -Seconds 3
    
    $status = (Get-Service -Name $serviceName).Status
    if ($status -eq "Running") {
        Write-Host "   ✅ Service started successfully" -ForegroundColor Green
        Write-Host "   Status: RUNNING" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Service status: $status" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  Service start issue: $_" -ForegroundColor Yellow
    Write-Host "   Check logs for details" -ForegroundColor Gray
}

# Step 7: Show summary
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "              SETUP COMPLETE!" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

Write-Host "`n✅ Configuration:" -ForegroundColor Green
Write-Host "   Watch Folder: C:\GOT_Alarms"
Write-Host "   Service: $serviceName"
Write-Host "   Status: $($(Get-Service -Name $serviceName).Status)"
Write-Host "   Logs: C:\Logs\ScadaWatcher\"

Write-Host "`n📋 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Check logs:"
Write-Host "      Get-Content C:\Logs\ScadaWatcher\ScadaWatcher-*.log -Tail 50 -Wait"
Write-Host ""
Write-Host "   2. View existing alarms in Firebase Console:"
Write-Host "      https://console.firebase.google.com/project/scadadataserver/firestore"
Write-Host ""
Write-Host "   3. Run Flutter mobile app:"
Write-Host "      cd E:\scada_alarm_client"
Write-Host "      flutter run"
Write-Host ""
Write-Host "   4. Add new alarm to test:"
Write-Host "      `$time = Get-Date -Format 'yyyy/MM/dd HH:mm'"
Write-Host "      `"`$time,Test alarm`" | Out-File C:\GOT_Alarms\new_test.csv"

Write-Host "`n📊 Expected Behavior:" -ForegroundColor Yellow
Write-Host "   • Service detects CSV files in C:\GOT_Alarms"
Write-Host "   • Processes alarm data within 1 second"
Write-Host "   • Pushes to Firebase Cloud"
Write-Host "   • Sends push notifications"
Write-Host "   • Alerts appear in mobile app (< 5 sec)"

Write-Host "`n🎯 Files Found:" -ForegroundColor Yellow
if (Test-Path "C:\GOT_Alarms") {
    Get-ChildItem "C:\GOT_Alarms" -Filter "*.csv" | 
        Select-Object Name, Length, LastWriteTime | 
        Format-Table -AutoSize
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Offer to show logs
$showLogs = Read-Host "Show service logs now? (y/n)"
if ($showLogs -eq "y") {
    Write-Host "`nShowing logs (Ctrl+C to exit)...`n" -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    Get-Content C:\Logs\ScadaWatcher\ScadaWatcher-*.log -Tail 50 -Wait
}
