# SCADA Watcher Service - Company Setup Guide

## 🎯 QUICK SETUP FOR YOUR SCADA MACHINE

This guide helps you configure the service to connect to your SCADA machine and collect data.

---

## STEP 1: Configure OPC UA Connection to SCADA Machine

Edit `appsettings.json` and update the OPC UA section:

```json
{
  "OpcUa": {
    "Enabled": true,
    "EndpointUrl": "opc.tcp://YOUR_SCADA_IP:4840/UA/Server",
    "SecurityMode": "None",
    "SecurityPolicy": "None",
    "AuthenticationMode": "Anonymous",
    "Username": "",
    "Password": ""
  }
}
```

### 🔧 Configuration Parameters:

**EndpointUrl** - Replace with your SCADA machine details:
- Format: `opc.tcp://IP_ADDRESS:PORT/PATH`
- Example: `opc.tcp://192.168.1.100:4840/UA/Server`
- Common ports: 4840 (default OPC UA), 48020, 53530

**For Initial Testing** (Insecure):
```json
{
  "EndpointUrl": "opc.tcp://192.168.1.100:4840",
  "SecurityMode": "None",
  "SecurityPolicy": "None",
  "AuthenticationMode": "Anonymous",
  "AcceptUntrustedCertificates": true,
  "AutoAcceptCertificates": true
}
```

**For Production** (Secure):
```json
{
  "EndpointUrl": "opc.tcp://192.168.1.100:4840/UA/Server",
  "SecurityMode": "SignAndEncrypt",
  "SecurityPolicy": "Basic256Sha256",
  "AuthenticationMode": "UsernamePassword",
  "Username": "scada_user",
  "Password": "your_password",
  "AcceptUntrustedCertificates": false,
  "AutoAcceptCertificates": false
}
```

---

## STEP 2: Configure Nodes to Monitor

In `appsettings.json`, update the Nodes array to match your SCADA tags:

```json
{
  "OpcUa": {
    "Nodes": [
      {
        "NodeId": "ns=2;s=Plant.Temperature",
        "DisplayName": "Reactor Temperature",
        "SamplingIntervalMs": 1000,
        "DeadbandType": "Absolute",
        "DeadbandValue": 0.5
      },
      {
        "NodeId": "ns=2;s=Plant.Pressure",
        "DisplayName": "System Pressure",
        "SamplingIntervalMs": 1000,
        "DeadbandType": "Absolute",
        "DeadbandValue": 0.1
      },
      {
        "NodeId": "ns=2;s=Plant.Flow",
        "DisplayName": "Flow Rate",
        "SamplingIntervalMs": 500,
        "DeadbandType": "Percent",
        "DeadbandValue": 1.0
      }
    ]
  }
}
```

### 📝 Node ID Formats:

Your SCADA system uses one of these formats:

**String-based** (most common):
```
"ns=2;s=Device.Tag.Name"
"ns=2;s=PLC1.DB1.Temperature"
```

**Numeric**:
```
"ns=2;i=1001"
"ns=3;i=5432"
```

**GUID** (rare):
```
"ns=2;g=550e8400-e29b-41d4-a716-446655440000"
```

⚠️ **Important**: Contact your SCADA system administrator to get the exact Node IDs for your tags!

---

## STEP 3: How to Find Your SCADA Machine IP and Port

### Option A: Ask Your SCADA Administrator
They should provide:
- IP Address (e.g., 192.168.1.100)
- OPC UA Port (typically 4840)
- Server Path (e.g., /UA/Server or /OPCUA)
- Node IDs for tags you want to monitor

### Option B: Use OPC UA Client Tools

**Download UaExpert** (free OPC UA browser):
1. Download from: https://www.unified-automation.com/downloads/opc-ua-clients.html
2. Run UaExpert
3. Add Server → Enter endpoint URL
4. Browse the server to see all available nodes
5. Copy Node IDs you need

**Download Prosys OPC UA Browser** (free):
1. Download from: https://www.prosysopc.com/products/opc-ua-browser/
2. Connect to your SCADA server
3. Browse and test connectivity

### Option C: Check SCADA System Documentation
- Siemens WinCC OA: Usually port 4840
- Rockwell FactoryTalk: Usually port 4840
- Schneider Electric: Usually port 4840
- Ignition SCADA: Usually port 62541

---

## STEP 4: Configure Alerts

Edit the Alerts section to monitor your process:

```json
{
  "Alerts": {
    "Enabled": true,
    "EvaluationIntervalSeconds": 5,
    "Rules": [
      {
        "RuleId": "TEMP_HIGH",
        "NodeId": "ns=2;s=Plant.Temperature",
        "Description": "Temperature Too High",
        "AlertType": "HighThreshold",
        "Severity": "Warning",
        "Enabled": true,
        "Threshold": 85.0,
        "Deadband": 5.0,
        "MessageTemplate": "ALERT: Temperature {Value}°C exceeded {Threshold}°C"
      },
      {
        "RuleId": "PRESSURE_LOW",
        "NodeId": "ns=2;s=Plant.Pressure",
        "Description": "Pressure Too Low",
        "AlertType": "LowThreshold",
        "Severity": "Critical",
        "Enabled": true,
        "Threshold": 10.0,
        "Deadband": 2.0,
        "MessageTemplate": "CRITICAL: Pressure {Value} PSI below {Threshold} PSI"
      }
    ]
  }
}
```

---

## STEP 5: Build and Install the Service

### Build the Service:
```powershell
# Open PowerShell as Administrator
cd E:\ScadaWatcherService

# Restore dependencies
dotnet restore

# Build the project
dotnet build --configuration Release

# Publish to C:\Services\ScadaWatcher
dotnet publish --configuration Release --output C:\Services\ScadaWatcher
```

### Install as Windows Service:
```powershell
# Create log directory
New-Item -Path C:\Logs\ScadaWatcher -ItemType Directory -Force

# Install service
sc.exe create ScadaWatcherService binPath= "C:\Services\ScadaWatcher\ScadaWatcherService.exe" start= delayed-auto DisplayName= "SCADA Watcher Service"

# Start service
sc.exe start ScadaWatcherService
```

### Or Use the Installation Script:
```powershell
.\Install-Service.ps1
```

---

## STEP 6: Verify It's Working

### Check Service Status:
```powershell
sc.exe query ScadaWatcherService
```

Should show: `STATE: 4 RUNNING`

### View Live Logs:
```powershell
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50 -Wait
```

### Look for These Messages:
```
✅ "OPC UA client connected to server opc.tcp://..."
✅ "Data received: Temperature = 72.5 [Double], Quality: Good"
✅ "Alert Engine started successfully"
```

### Check for Errors:
```powershell
Select-String -Path C:\Logs\ScadaWatcher\*.log -Pattern "ERROR|CRITICAL"
```

---

## STEP 7: Testing the Connection

### Test 1: Verify OPC UA Connection
Check logs for:
```
[INF] OPC UA client connecting to opc.tcp://192.168.1.100:4840
[INF] OPC UA client connected to server
[INF] Subscribed to 3 nodes
```

### Test 2: Verify Data Reception
Check logs for:
```
[INF] Data received: Temperature = 25.3 [Double], Quality: Good
[INF] Data received: Pressure = 14.7 [Double], Quality: Good
```

### Test 3: Check Historian Database
```powershell
# Check if database was created
Test-Path C:\SCADA\Data\historian.db

# View database size
Get-Item C:\SCADA\Data\historian.db | Select-Object Name, Length
```

---

## COMMON CONNECTION ISSUES

### Issue: "Connection refused"
**Cause**: Wrong IP address, port, or SCADA server not running
**Fix**: 
- Verify SCADA machine IP with `ping 192.168.1.100`
- Verify OPC UA server is running
- Check firewall allows port 4840

### Issue: "Certificate validation failed"
**Cause**: Security mode mismatch
**Fix**: For testing, use:
```json
"SecurityMode": "None",
"AcceptUntrustedCertificates": true,
"AutoAcceptCertificates": true
```

### Issue: "No data received"
**Cause**: Wrong Node IDs
**Fix**: 
- Use UaExpert to browse server and copy exact Node IDs
- Node IDs are case-sensitive!

### Issue: "Authentication failed"
**Cause**: Wrong username/password
**Fix**: 
- Verify credentials with SCADA admin
- Or use `"AuthenticationMode": "Anonymous"` for testing

---

## QUICK REFERENCE

### Service Commands:
```powershell
# Start service
sc.exe start ScadaWatcherService

# Stop service
sc.exe stop ScadaWatcherService

# Restart service (apply config changes)
Restart-Service ScadaWatcherService

# Check status
sc.exe query ScadaWatcherService
```

### View Logs:
```powershell
# Live tail
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50 -Wait

# Today's log
Get-Content C:\Logs\ScadaWatcher\ScadaWatcher-$(Get-Date -Format 'yyyyMMdd').log

# Find errors
Select-String -Path C:\Logs\ScadaWatcher\*.log -Pattern "ERROR"
```

### Update Configuration:
```powershell
# Edit config
notepad C:\Services\ScadaWatcher\appsettings.json

# Restart to apply
Restart-Service ScadaWatcherService
```

---

## EXAMPLE: Complete Configuration for Allen-Bradley PLC

```json
{
  "OpcUa": {
    "Enabled": true,
    "EndpointUrl": "opc.tcp://192.168.1.50:4840",
    "SecurityMode": "None",
    "AuthenticationMode": "Anonymous",
    "AcceptUntrustedCertificates": true,
    "AutoAcceptCertificates": true,
    "Nodes": [
      {
        "NodeId": "ns=2;s=PLC1.Program:MainProgram.Temperature",
        "DisplayName": "Tank Temperature"
      },
      {
        "NodeId": "ns=2;s=PLC1.Program:MainProgram.Level",
        "DisplayName": "Tank Level"
      },
      {
        "NodeId": "ns=2;s=PLC1.Program:MainProgram.Pressure",
        "DisplayName": "Line Pressure"
      }
    ]
  }
}
```

---

## EXAMPLE: Complete Configuration for Siemens S7 PLC

```json
{
  "OpcUa": {
    "Enabled": true,
    "EndpointUrl": "opc.tcp://192.168.0.10:4840",
    "SecurityMode": "None",
    "AuthenticationMode": "Anonymous",
    "Nodes": [
      {
        "NodeId": "ns=3;s=DB1.DBD0",
        "DisplayName": "Temperature Sensor 1"
      },
      {
        "NodeId": "ns=3;s=DB1.DBD4",
        "DisplayName": "Pressure Sensor"
      },
      {
        "NodeId": "ns=3;s=DB2.DBX0.0",
        "DisplayName": "Motor Status"
      }
    ]
  }
}
```

---

## NEXT STEPS

1. ✅ Get IP address and port from SCADA admin
2. ✅ Get Node IDs for tags you want to monitor
3. ✅ Update `appsettings.json` with your values
4. ✅ Build and install service
5. ✅ Verify logs show connection and data
6. ✅ Configure alerts for your process limits
7. ✅ Test alert triggering
8. ✅ Enable Firebase for mobile notifications (optional)

---

## NEED HELP?

**Check the logs first!** Most issues are visible in:
```
C:\Logs\ScadaWatcher\ScadaWatcher-YYYYMMDD.log
```

**Documentation:**
- `README.md` - Overview and quick start
- `OPC_UA_QUICKSTART.md` - OPC UA setup details
- `ALERT_ENGINE_GUIDE.md` - Alert configuration
- `DEPLOYMENT.md` - Full deployment guide

---

**Ready to connect to your SCADA system! 🚀**
