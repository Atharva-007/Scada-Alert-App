param(
    [string]$ServiceName = "ScadaWatcherService"
)

$ErrorActionPreference = "Stop"

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script as Administrator."
}

$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($null -eq $existingService) {
    Write-Host "Service '$ServiceName' is not installed."
    exit 0
}

if ($existingService.Status -ne "Stopped") {
    Stop-Service -Name $ServiceName -Force -ErrorAction Stop
}

sc.exe delete $ServiceName | Out-Null
Write-Host "Service '$ServiceName' has been removed."
