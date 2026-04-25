param(
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$serviceScript = Join-Path $scriptDir "scada_firestore_analysis_service.py"

Write-Host "Stopping service (if running)..."
& $PythonExe $serviceScript stop

Write-Host "Removing service..."
& $PythonExe $serviceScript remove

Write-Host "Done."
