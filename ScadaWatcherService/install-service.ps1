param(
    [string]$PublishDir = "",
    [string]$ServiceName = "ScadaWatcherService",
    [string]$DisplayName = "SCADA Watcher Service",
    [string]$AlarmWatchFolder = "C:\GOT_Alarms",
    [switch]$ForceReinstall,
    [switch]$StartAfterInstall = $true
)

$ErrorActionPreference = "Stop"

function Assert-Administrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run this script as Administrator."
    }
}

Assert-Administrator

$serviceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($PublishDir)) {
    if (Test-Path (Join-Path $serviceRoot "ScadaWatcherService.exe")) {
        $PublishDir = $serviceRoot
    } else {
        $PublishDir = Join-Path $serviceRoot "publish\win-x64"
    }
}

$exePath = Join-Path $PublishDir "ScadaWatcherService.exe"
$appSettingsPath = Join-Path $PublishDir "appsettings.json"

if (-not (Test-Path $exePath)) {
    throw "Service executable not found: $exePath. Run publish-service.ps1 first."
}

if (-not (Test-Path $appSettingsPath)) {
    throw "appsettings.json not found: $appSettingsPath"
}

$configDir = Join-Path $PublishDir "config"
$runtimeDirs = @(
    (Join-Path $PublishDir "runtime"),
    (Join-Path $PublishDir "runtime\logs"),
    (Join-Path $PublishDir "runtime\historian"),
    (Join-Path $PublishDir "runtime\alarm-file-watcher"),
    $configDir
)

foreach ($directory in $runtimeDirs) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$serviceAccountPath = Join-Path $configDir "firebase-service-account.json"
if (-not (Test-Path $serviceAccountPath)) {
    Write-Warning "Firebase Admin key is missing: $serviceAccountPath"
    Write-Warning "The service will not upload alerts until that file is present."
}

$config = Get-Content $appSettingsPath -Raw | ConvertFrom-Json
if (-not [string]::IsNullOrWhiteSpace($AlarmWatchFolder)) {
    $config.AlarmFileWatcher.WatchFolder = $AlarmWatchFolder
}

$config | ConvertTo-Json -Depth 20 | Set-Content -Path $appSettingsPath -Encoding UTF8

$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($null -ne $existingService) {
    if (-not $ForceReinstall) {
        throw "Service '$ServiceName' already exists. Re-run with -ForceReinstall to replace it."
    }

    if ($existingService.Status -ne "Stopped") {
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
    }

    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

New-Service `
    -Name $ServiceName `
    -BinaryPathName ('"' + $exePath + '"') `
    -DisplayName $DisplayName `
    -Description "Collects SCADA alarm files and uploads them to Firebase Firestore." `
    -StartupType Automatic

if ($StartAfterInstall) {
    Start-Service -Name $ServiceName
}

Write-Host ""
Write-Host "Service installed."
Write-Host "Service name: $ServiceName"
Write-Host "Executable:   $exePath"
Write-Host "Watch folder: $($config.AlarmFileWatcher.WatchFolder)"
Write-Host "Config file:  $appSettingsPath"
Write-Host "Logs folder:  $(Join-Path $PublishDir 'runtime\logs')"
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  Get-Service $ServiceName"
Write-Host "  Start-Service $ServiceName"
Write-Host "  Stop-Service $ServiceName"
Write-Host "  Get-Content (Join-Path '$PublishDir' 'runtime\\logs\\ScadaWatcher-*.log') -Tail 100"
