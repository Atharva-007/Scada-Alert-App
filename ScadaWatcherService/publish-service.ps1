param(
    [string]$Runtime = "win-x64",
    [string]$OutputDir = "",
    [switch]$SelfContained = $true
)

$ErrorActionPreference = "Stop"

$serviceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectPath = Join-Path $serviceRoot "ScadaWatcherService.csproj"
$deploymentGuidePath = Join-Path (Split-Path -Parent $serviceRoot) "docs\windows-service-deployment.md"

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $serviceRoot ("publish\" + $Runtime)
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$publishArgs = @(
    "publish",
    $projectPath,
    "-c", "Release",
    "-r", $Runtime,
    "--output", $OutputDir
)

if ($SelfContained) {
    $publishArgs += @("--self-contained", "true")
} else {
    $publishArgs += @("--self-contained", "false")
}

Write-Host "Publishing ScadaWatcherService to $OutputDir"
dotnet @publishArgs

$configDir = Join-Path $OutputDir "config"
$installScriptDestination = Join-Path $OutputDir "install-service.ps1"
$uninstallScriptDestination = Join-Path $OutputDir "uninstall-service.ps1"
$guideDestination = Join-Path $OutputDir "README-service-deployment.md"
$runtimeDirs = @(
    (Join-Path $OutputDir "runtime"),
    (Join-Path $OutputDir "runtime\logs"),
    (Join-Path $OutputDir "runtime\historian"),
    (Join-Path $OutputDir "runtime\alarm-file-watcher"),
    $configDir
)

foreach ($directory in $runtimeDirs) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

Copy-Item (Join-Path $serviceRoot "install-service.ps1") $installScriptDestination -Force
Copy-Item (Join-Path $serviceRoot "uninstall-service.ps1") $uninstallScriptDestination -Force

if (Test-Path $deploymentGuidePath) {
    Copy-Item $deploymentGuidePath $guideDestination -Force
}

$serviceAccountPath = Join-Path $configDir "firebase-service-account.json"
if (-not (Test-Path $serviceAccountPath)) {
    Write-Warning "Place your Firebase Admin key here before installing on the collector PC: $serviceAccountPath"
}

Write-Host ""
Write-Host "Publish complete."
Write-Host "Next:"
Write-Host "  1. Copy $OutputDir to the collector PC"
Write-Host "  2. Put firebase-service-account.json in $configDir"
Write-Host "  3. Run $installScriptDestination as Administrator on the collector PC"
