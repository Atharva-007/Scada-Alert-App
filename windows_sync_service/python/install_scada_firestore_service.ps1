param(
    [string]$PythonExe = "python",
    [switch]$StartService
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetConfigPath = "C:\SCADA\config\firestore_analyzer.json"
$sourceConfigPath = Join-Path $scriptDir "firestore_analyzer.config.example.json"

Write-Host "Installing Python dependencies..."
& $PythonExe -m pip install -r (Join-Path $scriptDir "requirements.txt")

if (-not (Test-Path $targetConfigPath)) {
    New-Item -ItemType Directory -Path (Split-Path $targetConfigPath) -Force | Out-Null
    Copy-Item $sourceConfigPath $targetConfigPath
    Write-Host "Created config file at: $targetConfigPath"
    Write-Host "Update service_account_path before starting the service."
}

Write-Host "Registering Windows service..."
& $PythonExe (Join-Path $scriptDir "scada_firestore_analysis_service.py") --startup auto install

if ($StartService) {
    Write-Host "Starting service..."
    & $PythonExe (Join-Path $scriptDir "scada_firestore_analysis_service.py") start
}

Write-Host "Done."
