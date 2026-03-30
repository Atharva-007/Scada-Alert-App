# SCADA Watcher Service - Quick Reference Card

## 🚀 Installation (3 Commands)

```powershell
# 1. Edit configuration
notepad appsettings.json  # Update ExecutablePath

# 2. Install service (as Administrator)
.\Install-Service.ps1 -FlutterAppPath "C:\Your\Flutter\App.exe"

# 3. Verify running
sc.exe query ScadaWatcherService
```

---

## 📋 Essential Commands

### Service Control
```powershell
sc.exe start ScadaWatcherService        # Start
sc.exe stop ScadaWatcherService         # Stop
sc.exe query ScadaWatcherService        # Status
Restart-Service ScadaWatcherService     # Restart
```

### View Logs
```powershell
# Live tail
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 50 -Wait

# Today's log
Get-Content C:\Logs\ScadaWatcher\ScadaWatcher-$(Get-Date -Format 'yyyyMMdd').log

# Find errors
Select-String -Path C:\Logs\ScadaWatcher\*.log -Pattern "ERROR|CRITICAL"
```

### Update Configuration
```powershell
notepad C:\Services\ScadaWatcher\appsettings.json
Restart-Service ScadaWatcherService
```

---

## ⚙️ Configuration Template

```json
{
  "Logging": {
    "LogDirectory": "C:\\Logs\\ScadaWatcher",
    "FileSizeLimitMB": 50,
    "RetainedFileCount": 30
  },
  "ProcessManagement": {
    "ExecutablePath": "C:\\Path\\To\\Your\\App.exe",
    "Arguments": "",
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

---

## 🔧 Troubleshooting

| Problem | Check | Fix |
|---------|-------|-----|
| Won't start | Event Viewer | Verify executable path |
| App crashes | Flutter logs | Test app manually |
| No logs | Permissions | Grant write access |
| Rapid restarts | Service logs | Check app stability |

---

## 📊 Health Checks

✅ **Healthy Service**
```
Service Status: Running
Log Shows: "Process started successfully"
No ERROR messages
No rapid restarts
```

⚠️ **Needs Attention**
```
Service Status: Stopped
Log Shows: ERROR/CRITICAL
Repeated "exponential backoff"
Process exits with error codes
```

---

## 🎯 Key Features

- ✅ Auto-start on boot (delayed)
- ✅ Headless Flutter app execution
- ✅ Auto-restart on crash
- ✅ Exponential backoff (10s → 300s)
- ✅ Graceful shutdown (5s timeout)
- ✅ Daily log rotation (50MB limit)
- ✅ 30-day log retention
- ✅ Never crashes

---

## 📁 File Locations

| Item | Path |
|------|------|
| Service Binary | `C:\Services\ScadaWatcher\ScadaWatcherService.exe` |
| Configuration | `C:\Services\ScadaWatcher\appsettings.json` |
| Logs | `C:\Logs\ScadaWatcher\ScadaWatcher-YYYYMMDD.log` |
| Event Viewer | `Windows Logs > Application` |

---

## 🛡️ Security

```powershell
# Run as dedicated account (recommended)
sc.exe config ScadaWatcherService obj= ".\ScadaWatcherSvc"

# Set file permissions
icacls "C:\Logs\ScadaWatcher" /grant "ScadaWatcherSvc:(OI)(CI)M"
icacls "C:\SCADA\App" /grant "ScadaWatcherSvc:(OI)(CI)RX"
```

---

## 📞 Emergency Commands

```powershell
# Emergency stop (kills everything)
sc.exe stop ScadaWatcherService
taskkill /F /IM your_flutter_app.exe

# Disable auto-restart (maintenance mode)
# Edit appsettings.json: "AutoRestart": false
Restart-Service ScadaWatcherService

# Uninstall service
.\Uninstall-Service.ps1
```

---

## 📚 Full Documentation

- **README.md** - Quick start guide
- **DEPLOYMENT.md** - Complete deployment manual
- **ARCHITECTURE.md** - Technical deep-dive
- **IMPLEMENTATION_SUMMARY.md** - Overview

---

**Production-Grade | 24/7 Reliability | Zero Manual Intervention**
