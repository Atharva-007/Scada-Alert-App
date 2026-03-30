# Quick Install Script for SCADA Watcher Service
# This script builds and installs the service in one command

param(
    [Parameter(Mandatory=$true)]
    [string]$FirebaseProjectId,
    
    [Parameter(Mandatory=$true)]
    [string]$FirebaseKeyPath
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SCADA Watcher Service - Quick Install" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validate parameters
if (-not (Test-Path $FirebaseKeyPath)) {
    Write-Host "ERROR: Firebase key file not found: $FirebaseKeyPath" -ForegroundColor Red
    Write-Host "Please download the service account JSON from Firebase Console" -ForegroundColor Yellow
    exit 1
}

Write-Host "Configuration:" -ForegroundColor Green
Write-Host "  Firebase Project ID: $FirebaseProjectId" -ForegroundColor White
Write-Host "  Firebase Key: $FirebaseKeyPath" -ForegroundColor White
Write-Host ""

# Create directories
Write-Host "[1/7] Creating directories..." -ForegroundColor Cyan
$dirs = @(
    "C:\Services\ScadaWatcher",
    "C:\Logs\ScadaWatcher",
    "C:\GOT_Alarms",
    "C:\AlarmSystem",
    "C:\SecureKeys"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Gray
    } else {
        Write-Host "  Exists: $dir" -ForegroundColor Gray
    }
}

# Copy Firebase key to secure location
Write-Host ""
Write-Host "[2/7] Copying Firebase service account key..." -ForegroundColor Cyan
$secureKeyPath = "C:\SecureKeys\firebase-service-account.json"
Copy-Item -Path $FirebaseKeyPath -Destination $secureKeyPath -Force
Write-Host "  ✓ Key copied to: $secureKeyPath" -ForegroundColor Green

# Update appsettings.json
Write-Host ""
Write-Host "[3/7] Updating configuration..." -ForegroundColor Cyan
$configPath = Join-Path $PSScriptRoot "appsettings.json"

if (-not (Test-Path $configPath)) {
    Write-Host "  ERROR: appsettings.json not found in current directory" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Enable and configure Firebase
$config.Firebase.Enabled = $true
$config.Firebase.ProjectId = $FirebaseProjectId
$config.Firebase.ServiceAccountJsonPath = "C:\\SecureKeys\\firebase-service-account.json"

# Enable AlarmFileWatcher
$config.AlarmFileWatcher.Enabled = $true

# Enable Alerts
$config.Alerts.Enabled = $true

# Save updated config
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath
Write-Host "  ✓ Configuration updated" -ForegroundColor Green
Write-Host "    - Firebase: Enabled" -ForegroundColor Gray
Write-Host "    - AlarmFileWatcher: Enabled" -ForegroundColor Gray
Write-Host "    - Alerts: Enabled" -ForegroundColor Gray

# Restore dependencies
Write-Host ""
Write-Host "[4/7] Restoring NuGet packages..." -ForegroundColor Cyan
dotnet restore
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to restore packages" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Packages restored" -ForegroundColor Green

# Build
Write-Host ""
Write-Host "[5/7] Building project..." -ForegroundColor Cyan
dotnet build --configuration Release
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Build failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Build succeeded" -ForegroundColor Green

# Publish
Write-Host ""
Write-Host "[6/7] Publishing service..." -ForegroundColor Cyan
dotnet publish --configuration Release --output "C:\Services\ScadaWatcher"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Publish failed" -ForegroundColor Red
    exit 1
}

# Copy updated config to publish directory
Copy-Item -Path $configPath -Destination "C:\Services\ScadaWatcher\appsettings.json" -Force
Write-Host "  ✓ Service published to C:\Services\ScadaWatcher" -ForegroundColor Green

# Install and start service
Write-Host ""
Write-Host "[7/7] Installing Windows Service..." -ForegroundColor Cyan

# Check if service already exists
$existingService = Get-Service -Name "ScadaWatcherService" -ErrorAction SilentlyContinue

if ($existingService) {
    Write-Host "  Service already exists. Stopping and removing..." -ForegroundColor Yellow
    Stop-Service -Name "ScadaWatcherService" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    sc.exe delete ScadaWatcherService | Out-Null
    Start-Sleep -Seconds 2
}

# Create service
sc.exe create ScadaWatcherService `
    binPath= "C:\Services\ScadaWatcher\ScadaWatcherService.exe" `
    start= delayed-auto `
    DisplayName= "SCADA Watcher Service" | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to create service" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ Service created" -ForegroundColor Green

# Start service
Write-Host "  Starting service..." -ForegroundColor Cyan
sc.exe start ScadaWatcherService | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "  WARNING: Service created but failed to start" -ForegroundColor Yellow
    Write-Host "  Check logs: C:\Logs\ScadaWatcher\" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ Service started successfully" -ForegroundColor Green
}

# Wait for service to initialize
Write-Host ""
Write-Host "Waiting for service to initialize (10 seconds)..." -ForegroundColor Cyan
Start-Sleep -Seconds 10

# Check service status
$service = Get-Service -Name "ScadaWatcherService"
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Service Status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq 'Running') { 'Green' } else { 'Yellow' })
Write-Host ""

# Show log location
Write-Host "View Logs:" -ForegroundColor Cyan
Write-Host "  Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50 -Wait" -ForegroundColor White
Write-Host ""

# Show test command
Write-Host "Create Test Alarm:" -ForegroundColor Cyan
Write-Host "  `"$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss'),Test alarm message`" | Out-File C:\GOT_Alarms\test.csv" -ForegroundColor White
Write-Host ""

# Show folder to monitor
Write-Host "Alarm Files Folder:" -ForegroundColor Cyan
Write-Host "  C:\GOT_Alarms\" -ForegroundColor White
Write-Host "  (Put your CSV alarm files here)" -ForegroundColor Gray
Write-Host ""

# Show database location
Write-Host "Local Database:" -ForegroundColor Cyan
Write-Host "  C:\AlarmSystem\alarm_history.db" -ForegroundColor White
Write-Host ""

# Check logs for errors
Write-Host "Recent Logs:" -ForegroundColor Cyan
$logFile = Get-ChildItem "C:\Logs\ScadaWatcher\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($logFile) {
    Get-Content $logFile.FullName -Tail 10 | ForEach-Object {
        if ($_ -match "ERROR|CRITICAL") {
            Write-Host "  $_" -ForegroundColor Red
        } elseif ($_ -match "WARNING|WARN") {
            Write-Host "  $_" -ForegroundColor Yellow
        } else {
            Write-Host "  $_" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Check logs above for any errors" -ForegroundColor White
Write-Host "2. Create test alarm file to verify" -ForegroundColor White
Write-Host "3. Setup your Flutter app (see SIMPLE_SETUP_GUIDE.md)" -ForegroundColor White
Write-Host "4. Put your real alarm CSV files in C:\GOT_Alarms\" -ForegroundColor White
Write-Host ""
Write-Host "Documentation: E:\ScadaWatcherService\SIMPLE_SETUP_GUIDE.md" -ForegroundColor Gray
Write-Host ""
Write-Host "✅ Done! Service is monitoring C:\GOT_Alarms\ and sending to Firebase!" -ForegroundColor Green
