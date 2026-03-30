# Configure SCADA Connection Helper Script
# This script helps you quickly configure the OPC UA connection to your SCADA machine

param(
    [Parameter(Mandatory=$false)]
    [string]$ScadaIP,
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 4840,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerPath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Password = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Secure
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SCADA Watcher - Connection Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get SCADA IP if not provided
if (-not $ScadaIP) {
    Write-Host "Enter your SCADA machine details:" -ForegroundColor Yellow
    Write-Host ""
    $ScadaIP = Read-Host "SCADA IP Address (e.g., 192.168.1.100)"
    
    if (-not $ScadaIP) {
        Write-Host "ERROR: IP address is required!" -ForegroundColor Red
        exit 1
    }
}

# Validate IP format
if ($ScadaIP -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
    Write-Host "WARNING: IP address format may be incorrect" -ForegroundColor Yellow
}

# Get port if default not acceptable
$portInput = Read-Host "OPC UA Port (default: 4840, press Enter to accept)"
if ($portInput) {
    $Port = [int]$portInput
}

# Get server path
$pathInput = Read-Host "Server Path (e.g., /UA/Server, press Enter if none)"
if ($pathInput) {
    $ServerPath = $pathInput
}

# Build endpoint URL
$EndpointUrl = "opc.tcp://${ScadaIP}:${Port}${ServerPath}"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Configuration Summary:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Endpoint URL: $EndpointUrl" -ForegroundColor White
Write-Host ""

# Ask about security
$secureChoice = Read-Host "Use secure connection? (y/N)"
$UseSecure = $secureChoice -eq 'y' -or $secureChoice -eq 'Y' -or $Secure

if ($UseSecure) {
    Write-Host ""
    Write-Host "Configuring SECURE connection..." -ForegroundColor Green
    
    if (-not $Username) {
        $Username = Read-Host "Username"
    }
    if (-not $Password) {
        $Password = Read-Host "Password" -AsSecureString
        $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    }
    
    $SecurityMode = "SignAndEncrypt"
    $SecurityPolicy = "Basic256Sha256"
    $AuthMode = "UsernamePassword"
    $AcceptUntrusted = "false"
    $AutoAccept = "false"
} else {
    Write-Host ""
    Write-Host "Configuring INSECURE connection (for testing only)..." -ForegroundColor Yellow
    
    $SecurityMode = "None"
    $SecurityPolicy = "None"
    $AuthMode = "Anonymous"
    $AcceptUntrusted = "true"
    $AutoAccept = "true"
}

# Test connectivity
Write-Host ""
Write-Host "Testing connectivity to $ScadaIP..." -ForegroundColor Cyan

$ping = Test-Connection -ComputerName $ScadaIP -Count 2 -Quiet

if ($ping) {
    Write-Host "✓ SCADA machine is reachable" -ForegroundColor Green
} else {
    Write-Host "✗ WARNING: Cannot ping SCADA machine" -ForegroundColor Yellow
    Write-Host "  This may be normal if ICMP is blocked" -ForegroundColor Gray
}

# Update appsettings.json
Write-Host ""
Write-Host "Updating appsettings.json..." -ForegroundColor Cyan

$configPath = Join-Path $PSScriptRoot "appsettings.json"

if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: appsettings.json not found!" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Update OPC UA configuration
$config.OpcUa.Enabled = $true
$config.OpcUa.EndpointUrl = $EndpointUrl
$config.OpcUa.SecurityMode = $SecurityMode
$config.OpcUa.SecurityPolicy = $SecurityPolicy
$config.OpcUa.AuthenticationMode = $AuthMode

if ($UseSecure) {
    $config.OpcUa.Username = $Username
    $config.OpcUa.Password = $Password
    $config.OpcUa.AcceptUntrustedCertificates = $false
    $config.OpcUa.AutoAcceptCertificates = $false
} else {
    $config.OpcUa.Username = ""
    $config.OpcUa.Password = ""
    $config.OpcUa.AcceptUntrustedCertificates = $true
    $config.OpcUa.AutoAcceptCertificates = $true
}

# Save configuration
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath

Write-Host "✓ Configuration saved!" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "1. Edit appsettings.json to add your Node IDs" -ForegroundColor White
Write-Host "   (Contact SCADA admin for exact Node IDs)" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Build and install the service:" -ForegroundColor White
Write-Host "   dotnet publish --configuration Release --output C:\Services\ScadaWatcher" -ForegroundColor Gray
Write-Host "   .\Install-Service.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Monitor logs:" -ForegroundColor White
Write-Host "   Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50 -Wait" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
