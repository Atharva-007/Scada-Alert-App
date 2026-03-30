@echo off
REM Quick test script to run the service in console mode for debugging

echo Starting SCADA Alarm Sync Service in Debug Mode...
echo.

cd /d "%~dp0"
dotnet run --project ScadaAlarmSyncService.csproj

pause
