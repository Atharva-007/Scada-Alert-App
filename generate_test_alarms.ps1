# Test Alarm Generator
# Generates sample alarm files for testing the SCADA Alarm File Watcher Service

# Configuration
$alertFolder = "C:\ScadaAlarms\AlertFiles"

# Ensure folder exists
if (-not (Test-Path $alertFolder)) {
    New-Item -Path $alertFolder -ItemType Directory -Force | Out-Null
    Write-Host "Created folder: $alertFolder" -ForegroundColor Green
}

Write-Host "`n🚨 SCADA Alarm Generator" -ForegroundColor Cyan
Write-Host "========================`n" -ForegroundColor Cyan

# Menu
Write-Host "Select test scenario:" -ForegroundColor Yellow
Write-Host "1. Single test alarm"
Write-Host "2. Multiple alarms (5)"
Write-Host "3. Critical alarm"
Write-Host "4. Mixed severity alarms"
Write-Host "5. Continuous alarm stream (Ctrl+C to stop)"
Write-Host "6. Custom alarm`n"

$choice = Read-Host "Enter choice (1-6)"

switch ($choice) {
    "1" {
        # Single test alarm
        $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
        $alarm = "$timestamp,Test alarm - System is operational"
        $alarm | Out-File -FilePath "$alertFolder\test_single.csv" -Encoding UTF8
        Write-Host "`n✅ Created test alarm: test_single.csv" -ForegroundColor Green
    }
    
    "2" {
        # Multiple alarms
        $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
        $alarms = @(
            "$timestamp,Tank A level high",
            "$timestamp,Pump B vibration detected",
            "$timestamp,Temperature rising in Reactor C",
            "$timestamp,Pressure sensor D reading abnormal",
            "$timestamp,Flow rate low in Line E"
        )
        
        $alarms | Out-File -FilePath "$alertFolder\test_multiple.csv" -Encoding UTF8
        Write-Host "`n✅ Created 5 test alarms: test_multiple.csv" -ForegroundColor Green
    }
    
    "3" {
        # Critical alarm
        $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
        $alarm = "$timestamp,Critical,EMERGENCY - Temperature critical in Reactor A (95°C)"
        $alarm | Out-File -FilePath "$alertFolder\critical_alarm.csv" -Encoding UTF8
        Write-Host "`n🚨 Created CRITICAL alarm: critical_alarm.csv" -ForegroundColor Red
        Write-Host "⚠️  This should trigger high-priority push notification!" -ForegroundColor Yellow
    }
    
    "4" {
        # Mixed severity
        $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
        $alarms = @(
            "$timestamp,Critical,Tank overflow imminent - Level at 98%",
            "$timestamp,Warning,Pump vibration increased - Maintenance recommended",
            "$timestamp,Info,Temperature within normal range",
            "$timestamp,Warning,Pressure approaching high threshold",
            "$timestamp,Critical,Emergency shutdown initiated for Line 3"
        )
        
        $alarms | Out-File -FilePath "$alertFolder\mixed_severity.csv" -Encoding UTF8
        Write-Host "`n✅ Created mixed severity alarms: mixed_severity.csv" -ForegroundColor Green
        Write-Host "   - 2 Critical" -ForegroundColor Red
        Write-Host "   - 2 Warning" -ForegroundColor Yellow
        Write-Host "   - 1 Info" -ForegroundColor Cyan
    }
    
    "5" {
        # Continuous stream
        Write-Host "`n⚡ Starting continuous alarm stream..." -ForegroundColor Cyan
        Write-Host "   Creating 1 alarm every 5 seconds" -ForegroundColor Gray
        Write-Host "   Press Ctrl+C to stop`n" -ForegroundColor Gray
        
        $counter = 1
        $severities = @("Info", "Warning", "Critical")
        $locations = @("Reactor-A", "Tank-B", "Pump-C", "Line-D", "PLC-01")
        $messages = @(
            "Temperature reading: {0}°C",
            "Pressure: {0} PSI",
            "Flow rate: {0} L/min",
            "Vibration detected: {0} Hz",
            "Level: {0}%"
        )
        
        while ($true) {
            $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
            $severity = $severities | Get-Random
            $location = $locations | Get-Random
            $message = ($messages | Get-Random) -f (Get-Random -Minimum 50 -Maximum 100)
            
            $alarm = "$timestamp,$severity,$location - $message"
            $alarm | Out-File -FilePath "$alertFolder\stream_$counter.csv" -Encoding UTF8
            
            Write-Host "[$timestamp] Created alarm #$counter - $severity" -ForegroundColor $(
                switch ($severity) {
                    "Critical" { "Red" }
                    "Warning" { "Yellow" }
                    "Info" { "Cyan" }
                }
            )
            
            $counter++
            Start-Sleep -Seconds 5
        }
    }
    
    "6" {
        # Custom alarm
        Write-Host "`nCreate custom alarm:" -ForegroundColor Yellow
        $severity = Read-Host "Severity (Critical/Warning/Info)"
        $message = Read-Host "Message"
        
        $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
        $alarm = "$timestamp,$severity,$message"
        $filename = "custom_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $alarm | Out-File -FilePath "$alertFolder\$filename" -Encoding UTF8
        
        Write-Host "`n✅ Created custom alarm: $filename" -ForegroundColor Green
    }
    
    default {
        Write-Host "`n❌ Invalid choice" -ForegroundColor Red
        exit
    }
}

# Show next steps
Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Check service logs: Get-Content C:\Logs\ScadaWatcher\*.log -Tail 20"
Write-Host "2. Verify in Firebase Console: https://console.firebase.google.com/project/scadadataserver/firestore"
Write-Host "3. Check mobile app for real-time alert`n"

# Show created files
Write-Host "📁 Alert files:" -ForegroundColor Cyan
Get-ChildItem -Path $alertFolder -Filter "*.csv" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 5 | 
    Format-Table Name, Length, LastWriteTime -AutoSize
