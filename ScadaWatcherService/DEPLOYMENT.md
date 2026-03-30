# SCADA Watcher Service - Deployment Guide

## Production-Grade Windows Service for Industrial SCADA Environments

This service provides industrial-reliable process management for Flutter applications running in headless mode on Windows servers. Designed for 24/7 operation with zero manual intervention.

---

## ARCHITECTURE OVERVIEW

### Components
1. **Program.cs** - Entry point, logging configuration, Windows Service registration
2. **Worker.cs** - Core watchdog loop, process management, auto-restart logic
3. **ProcessConfiguration.cs** - Configuration models with validation
4. **appsettings.json** - External configuration (NEVER hardcode paths)

### Key Features
- ✅ Automatic process restart on crash
- ✅ Exponential backoff to prevent restart loops
- ✅ Graceful shutdown with timeout-based force kill
- ✅ Comprehensive logging with rotation
- ✅ Configuration validation on startup
- ✅ Delayed startup for network initialization
- ✅ Headless/background mode support
- ✅ Production-grade exception handling

---

## BUILD INSTRUCTIONS

### Prerequisites
- .NET 8 SDK installed
- Windows 10/11 or Windows Server 2019+
- Administrator privileges for service installation

### Build Steps

1. **Restore Dependencies**
   ```powershell
   dotnet restore
   ```

2. **Build Release Version**
   ```powershell
   dotnet build --configuration Release
   ```

3. **Publish Self-Contained Executable**
   ```powershell
   dotnet publish --configuration Release --output "C:\Services\ScadaWatcher" --self-contained true --runtime win-x64
   ```

   This creates a standalone executable that doesn't require .NET runtime on the target machine.

---

## CONFIGURATION

### Step 1: Edit appsettings.json

**CRITICAL**: Update the ExecutablePath before deployment!

```json
{
  "Logging": {
    "LogDirectory": "C:\\Logs\\ScadaWatcher",
    "FileSizeLimitMB": 50,
    "RetainedFileCount": 30
  },
  "ProcessManagement": {
    "ExecutablePath": "C:\\SCADA\\FlutterApp\\your_flutter_app.exe",
    "Arguments": "",
    "WorkingDirectory": "",
    "StartupDelaySeconds": 15,
    "MonitoringIntervalSeconds": 5,
    "RestartDelaySeconds": 10,
    "MaxRestartDelaySeconds": 300,
    "ShutdownTimeoutMs": 5000,
    "HeadlessMode": true,
    "AutoRestart": true
  }
}
```

### Configuration Parameters Explained

| Parameter | Description | Recommended Value |
|-----------|-------------|-------------------|
| `ExecutablePath` | Full path to Flutter .exe | `C:\SCADA\App\app.exe` |
| `Arguments` | Command-line arguments | `""` or `"--port 8080"` |
| `WorkingDirectory` | Process working directory | `""` (auto-detects) |
| `StartupDelaySeconds` | Wait time after service start | `15-30` for SCADA |
| `MonitoringIntervalSeconds` | Health check frequency | `5-10` seconds |
| `RestartDelaySeconds` | Initial restart delay | `10` seconds |
| `MaxRestartDelaySeconds` | Max backoff delay | `300` (5 minutes) |
| `ShutdownTimeoutMs` | Graceful shutdown timeout | `5000` ms |
| `HeadlessMode` | Hide window | `true` for production |
| `AutoRestart` | Enable auto-restart | `true` for production |

### Step 2: Create Log Directory

```powershell
New-Item -Path "C:\Logs\ScadaWatcher" -ItemType Directory -Force
```

---

## INSTALLATION AS WINDOWS SERVICE

### Method 1: Using sc.exe (Recommended)

1. **Create the Service**
   ```powershell
   sc.exe create ScadaWatcherService `
     binPath= "C:\Services\ScadaWatcher\ScadaWatcherService.exe" `
     start= auto `
     DisplayName= "SCADA Watcher Service" `
     description= "Industrial-grade process manager for Flutter SCADA applications. Provides automatic restart, health monitoring, and 24/7 reliability."
   ```

2. **Configure Service Recovery Options**
   ```powershell
   sc.exe failure ScadaWatcherService reset= 86400 actions= restart/60000/restart/120000/restart/300000
   ```

3. **Set Service to Run as Local System**
   ```powershell
   sc.exe config ScadaWatcherService obj= LocalSystem
   ```

4. **Set Delayed Auto Start (Wait for network)**
   ```powershell
   sc.exe config ScadaWatcherService start= delayed-auto
   ```

5. **Start the Service**
   ```powershell
   sc.exe start ScadaWatcherService
   ```

### Method 2: Using PowerShell

```powershell
New-Service -Name "ScadaWatcherService" `
  -BinaryPathName "C:\Services\ScadaWatcher\ScadaWatcherService.exe" `
  -DisplayName "SCADA Watcher Service" `
  -Description "Industrial-grade process manager for Flutter SCADA applications" `
  -StartupType Automatic
```

---

## SERVICE MANAGEMENT

### Check Service Status
```powershell
sc.exe query ScadaWatcherService
# or
Get-Service ScadaWatcherService
```

### Start Service
```powershell
sc.exe start ScadaWatcherService
# or
Start-Service ScadaWatcherService
```

### Stop Service
```powershell
sc.exe stop ScadaWatcherService
# or
Stop-Service ScadaWatcherService
```

### Restart Service
```powershell
Restart-Service ScadaWatcherService
```

### View Service Configuration
```powershell
sc.exe qc ScadaWatcherService
```

### Uninstall Service
```powershell
sc.exe stop ScadaWatcherService
sc.exe delete ScadaWatcherService
```

---

## MONITORING & TROUBLESHOOTING

### Check Logs

Logs are written to: `C:\Logs\ScadaWatcher\ScadaWatcher-YYYYMMDD.log`

**View Recent Logs:**
```powershell
Get-Content "C:\Logs\ScadaWatcher\ScadaWatcher-$(Get-Date -Format 'yyyyMMdd').log" -Tail 50 -Wait
```

### Common Log Events

| Event | Meaning | Action Required |
|-------|---------|-----------------|
| `Service Starting` | Service initialized | None - normal |
| `Process started successfully` | Flutter app launched | None - normal |
| `Process exited with code X` | Crash detected | Check Flutter app logs |
| `Applying exponential backoff` | Rapid restart loop | Investigate Flutter app stability |
| `VALIDATION ERROR` | Configuration invalid | Fix appsettings.json |
| `CRITICAL ERROR` | Startup failure | Check logs, validate paths |

### Debugging Steps

1. **Service won't start:**
   - Check Event Viewer: `Windows Logs > Application`
   - Verify .NET 8 runtime installed (if not self-contained)
   - Verify executable path in appsettings.json
   - Check file permissions

2. **Flutter app crashes repeatedly:**
   - Check Flutter app logs
   - Disable auto-restart temporarily: `"AutoRestart": false`
   - Test Flutter app manually
   - Review exponential backoff in logs

3. **Service stops unexpectedly:**
   - Check Windows Event Viewer
   - Review service logs for CRITICAL errors
   - Verify system resources (memory, disk)

---

## SECURITY CONSIDERATIONS

### Recommended Permissions

1. **Service Account**: Run as `LocalSystem` or dedicated service account
2. **Log Directory**: Write permissions required
3. **Flutter Executable**: Read/execute permissions required

### Network Security

- Service starts after network initialization (configurable delay)
- No inbound network connections by default
- Flutter app network behavior depends on app implementation

---

## PRODUCTION CHECKLIST

Before deploying to production SCADA environment:

- [ ] Update `ExecutablePath` in appsettings.json
- [ ] Test Flutter app runs correctly in headless mode
- [ ] Create log directory with appropriate permissions
- [ ] Configure service recovery options
- [ ] Set delayed auto-start for network dependencies
- [ ] Test service start/stop/restart cycles
- [ ] Verify logs are being written
- [ ] Confirm auto-restart works after simulated crash
- [ ] Document emergency shutdown procedure
- [ ] Schedule log rotation/cleanup (30-day retention default)

---

## MAINTENANCE

### Log Rotation

Logs automatically rotate:
- **Daily**: New file created at midnight
- **Size-based**: When file exceeds 50MB
- **Retention**: 30 days (configurable)

Old logs are automatically deleted.

### Configuration Updates

To update configuration without rebuilding:

1. Stop the service
2. Edit `appsettings.json`
3. Start the service

Changes take effect immediately.

### Upgrading the Service

1. Stop the service: `sc.exe stop ScadaWatcherService`
2. Replace executable: Copy new build to `C:\Services\ScadaWatcher`
3. Start the service: `sc.exe start ScadaWatcherService`
4. Verify logs show successful startup

---

## DISASTER RECOVERY

### Service Fails to Start

1. Check Event Viewer: Application log
2. Review service logs
3. Validate configuration file
4. Test Flutter executable manually
5. Reinstall service if corrupted

### Complete System Failure

Service automatically starts on boot (delayed auto-start). No manual intervention required.

### Emergency Shutdown

```powershell
# Stop service and kill all related processes
sc.exe stop ScadaWatcherService
taskkill /F /IM your_flutter_app.exe
```

---

## SUPPORT

For issues or questions:
1. Check logs first: `C:\Logs\ScadaWatcher`
2. Review Event Viewer: Application log
3. Verify configuration: `appsettings.json`
4. Test Flutter app independently

---

## VERSION HISTORY

- **v1.0** - Initial production release
  - Auto-restart with exponential backoff
  - Comprehensive logging with rotation
  - Graceful shutdown with force-kill timeout
  - Configuration validation
  - Industrial-grade exception handling
