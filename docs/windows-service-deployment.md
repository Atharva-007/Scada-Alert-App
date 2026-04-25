# SCADA Watcher Service Deployment

This service is the collector/uploader component.

Flow:
- The collector PC receives alarm CSV/TXT files from the SCADA system.
- `ScadaWatcherService` watches that folder.
- The service uploads alerts to Firestore.
- The Android app reads those alerts from Firestore.

## Service Project

- Project: `ScadaWatcherService`
- Entry point: `ScadaWatcherService/Program.cs`
- Collector implementation: `ScadaWatcherService/AlarmFileWatcherService.cs`

## Folder Layout After Publish

Expected publish folder layout:

```text
ScadaWatcherService.exe
appsettings.json
install-service.ps1
uninstall-service.ps1
README-service-deployment.md
config/
  firebase-service-account.json
runtime/
  logs/
  historian/
  alarm-file-watcher/
```

## What Must Be Configured

The only machine-specific settings you normally need are:

1. `config/firebase-service-account.json`
2. `AlarmFileWatcher.WatchFolder` in `appsettings.json`

The Firebase Admin key stays with the service, not with the Android app.

## Build And Publish

From the repo machine:

```powershell
cd E:\scada_alarm_client\ScadaWatcherService
.\publish-service.ps1
```

That creates a publish folder under:

```text
ScadaWatcherService\publish\win-x64
```

## Install On Another Collector PC

1. Copy the full publish folder to the target PC.
2. Put the Firebase Admin key at:

```text
config\firebase-service-account.json
```

3. Run PowerShell as Administrator.
4. Open the copied publish folder.
5. Install the service:

```powershell
.\install-service.ps1 -AlarmWatchFolder 'C:\GOT_Alarms'
```

Replace `C:\GOT_Alarms` with the real folder where the SCADA system writes alarm CSV/TXT files.

## Service Commands

Check status:

```powershell
Get-Service ScadaWatcherService
```

Start:

```powershell
Start-Service ScadaWatcherService
```

Stop:

```powershell
Stop-Service ScadaWatcherService
```

Uninstall:

```powershell
.\uninstall-service.ps1
```

## Logs

Logs are written to:

```text
runtime\logs
```

Read the latest log:

```powershell
Get-ChildItem .\runtime\logs
Get-Content .\runtime\logs\ScadaWatcher-*.log -Tail 100
```

## Notes

- The Android app does not need the Firebase Admin JSON.
- `google-services.json` is only for the Android client.
- The service account JSON is only for the collector service and admin scripts.
- The published folder is self-contained. You can copy that folder to another Windows PC and run `install-service.ps1` directly there.
- If the SCADA source writes alarms to a network share, use that full UNC path as `-AlarmWatchFolder`.
