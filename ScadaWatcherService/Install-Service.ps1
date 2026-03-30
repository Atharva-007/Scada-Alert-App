# ============================================================================
# SCADA Watcher Service - Installation Script
# Run as Administrator
# ============================================================================

param(
    [string]$InstallPath = "C:\Services\ScadaWatcher",
    [string]$FlutterAppPath = "C:\SCADA\FlutterApp\your_flutter_app.exe",
    [string]$LogPath = "C:\Logs\ScadaWatcher"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SCADA Watcher Service - Installation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Step 1: Build the service
Write-Host "[1/6] Building service..." -ForegroundColor Green
Set-Location $PSScriptRoot
dotnet publish --configuration Release --output $InstallPath --self-contained true --runtime win-x64
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed!" -ForegroundColor Red
    exit 1
}
Write-Host "Build completed successfully." -ForegroundColor Green
Write-Host ""

# Step 2: Create log directory
Write-Host "[2/6] Creating log directory..." -ForegroundColor Green
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    Write-Host "Created: $LogPath" -ForegroundColor Green
} else {
    Write-Host "Log directory already exists: $LogPath" -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Update configuration
Write-Host "[3/6] Configuring service..." -ForegroundColor Green
$configPath = Join-Path $InstallPath "appsettings.json"
$config = Get-Content $configPath | ConvertFrom-Json
$config.ProcessManagement.ExecutablePath = $FlutterAppPath
$config.Logging.LogDirectory = $LogPath
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath
Write-Host "Configuration updated:" -ForegroundColor Green
Write-Host "  Flutter App: $FlutterAppPath" -ForegroundColor Cyan
Write-Host "  Log Path: $LogPath" -ForegroundColor Cyan
Write-Host ""

# Step 4: Stop existing service if running
Write-Host "[4/6] Checking for existing service..." -ForegroundColor Green
$existingService = Get-Service -Name "ScadaWatcherService" -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Existing service found. Stopping..." -ForegroundColor Yellow
    Stop-Service -Name "ScadaWatcherService" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    Write-Host "Removing existing service..." -ForegroundColor Yellow
    sc.exe delete ScadaWatcherService | Out-Null
    Start-Sleep -Seconds 2
}
Write-Host ""

# Step 5: Create Windows Service
Write-Host "[5/6] Installing Windows Service..." -ForegroundColor Green
$servicePath = Join-Path $InstallPath "ScadaWatcherService.exe"
sc.exe create ScadaWatcherService `
    binPath= "`"$servicePath`"" `
    start= delayed-auto `
    DisplayName= "SCADA Watcher Service" `
    description= "Industrial-grade process manager for Flutter SCADA applications. Provides automatic restart, health monitoring, and 24/7 reliability."

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Service creation failed!" -ForegroundColor Red
    exit 1
}

# Configure service recovery options
Write-Host "Configuring service recovery options..." -ForegroundColor Green
sc.exe failure ScadaWatcherService reset= 86400 actions= restart/60000/restart/120000/restart/300000 | Out-Null

Write-Host "Service installed successfully." -ForegroundColor Green
Write-Host ""

# Step 6: Start the service
Write-Host "[6/6] Starting service..." -ForegroundColor Green
Write-Host ""
Write-Host "Do you want to start the service now? (Y/N): " -ForegroundColor Yellow -NoNewline
$response = Read-Host

if ($response -eq 'Y' -or $response -eq 'y') {
    sc.exe start ScadaWatcherService
    Start-Sleep -Seconds 2
    
    $service = Get-Service -Name "ScadaWatcherService"
    if ($service.Status -eq "Running") {
        Write-Host "Service started successfully!" -ForegroundColor Green
    } else {
        Write-Host "Service status: $($service.Status)" -ForegroundColor Yellow
        Write-Host "Check logs at: $LogPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "Service installed but not started." -ForegroundColor Yellow
    Write-Host "To start manually: sc.exe start ScadaWatcherService" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Service Name: ScadaWatcherService" -ForegroundColor Cyan
Write-Host "Install Path: $InstallPath" -ForegroundColor Cyan
Write-Host "Log Path: $LogPath" -ForegroundColor Cyan
Write-Host "Flutter App: $FlutterAppPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Yellow
Write-Host "  Start:   sc.exe start ScadaWatcherService" -ForegroundColor White
Write-Host "  Stop:    sc.exe stop ScadaWatcherService" -ForegroundColor White
Write-Host "  Status:  sc.exe query ScadaWatcherService" -ForegroundColor White
Write-Host "  Logs:    Get-Content '$LogPath\ScadaWatcher-*.log' -Tail 50 -Wait" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANT: Update the Flutter app path in:" -ForegroundColor Red
Write-Host "  $configPath" -ForegroundColor Red
Write-Host ""
