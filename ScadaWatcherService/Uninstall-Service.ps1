# ============================================================================
# SCADA Watcher Service - Uninstallation Script
# Run as Administrator
# ============================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SCADA Watcher Service - Uninstall" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

# Check if service exists
$service = Get-Service -Name "ScadaWatcherService" -ErrorAction SilentlyContinue
if (-not $service) {
    Write-Host "Service 'ScadaWatcherService' not found." -ForegroundColor Yellow
    Write-Host "Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

# Stop the service
Write-Host "[1/2] Stopping service..." -ForegroundColor Green
if ($service.Status -eq "Running") {
    Stop-Service -Name "ScadaWatcherService" -Force
    Write-Host "Service stopped." -ForegroundColor Green
} else {
    Write-Host "Service is not running." -ForegroundColor Yellow
}

Start-Sleep -Seconds 2

# Delete the service
Write-Host "[2/2] Removing service..." -ForegroundColor Green
sc.exe delete ScadaWatcherService

if ($LASTEXITCODE -eq 0) {
    Write-Host "Service removed successfully." -ForegroundColor Green
} else {
    Write-Host "ERROR: Failed to remove service." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Uninstallation Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: Log files and service binaries were NOT deleted." -ForegroundColor Yellow
Write-Host "Delete manually if needed:" -ForegroundColor Yellow
Write-Host "  - Logs: C:\Logs\ScadaWatcher" -ForegroundColor Cyan
Write-Host "  - Binaries: C:\Services\ScadaWatcher" -ForegroundColor Cyan
Write-Host ""
