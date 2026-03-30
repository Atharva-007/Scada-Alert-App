# SCADA Alarm System - Database Seed Script
# Creates sample data for testing the sync service

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SCADA Alarm System - Database Seed Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$dbPath = "C:\ScadaAlarms\alerts.db"
$dbDir = Split-Path $dbPath

# Create directory if it doesn't exist
if (!(Test-Path $dbDir)) {
    Write-Host "Creating directory: $dbDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
}

# Check if SQLite command is available
try {
    $sqliteTest = Get-Command sqlite3 -ErrorAction Stop
    Write-Host "✅ SQLite3 command found" -ForegroundColor Green
} catch {
    Write-Host "❌ SQLite3 command not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install SQLite3:" -ForegroundColor Yellow
    Write-Host "1. Download from: https://www.sqlite.org/download.html" -ForegroundColor Yellow
    Write-Host "2. Extract sqlite3.exe to C:\Windows\System32\" -ForegroundColor Yellow
    Write-Host "   OR add to PATH environment variable" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Use the Windows Sync Service to create the database" -ForegroundColor Yellow
    Write-Host "  cd windows_sync_service" -ForegroundColor Yellow
    Write-Host "  .\test_service.bat" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host ""
Write-Host "Creating sample alerts in database..." -ForegroundColor Cyan
Write-Host ""

# Sample SQL to insert test data
$sql = @"
-- Create alerts table if not exists
CREATE TABLE IF NOT EXISTS alerts (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    severity TEXT NOT NULL,
    location TEXT,
    equipment TEXT,
    timestamp INTEGER NOT NULL,
    status TEXT NOT NULL,
    acknowledged_by TEXT,
    acknowledged_at INTEGER,
    resolved_at INTEGER,
    notes TEXT,
    synced_to_cloud INTEGER DEFAULT 0,
    last_cloud_sync INTEGER
);

-- Insert sample critical alert
INSERT OR REPLACE INTO alerts VALUES (
    'alert-001',
    'High Temperature Alarm - Reactor 1',
    'Temperature exceeded safe operating threshold of 85°C. Current: 92°C',
    'critical',
    'Production Floor - Building A',
    'Reactor-R1-TEMP-001',
    strftime('%s', 'now'),
    'active',
    NULL,
    NULL,
    NULL,
    'Auto-generated alert from temperature sensor',
    0,
    NULL
);

-- Insert sample high severity alert
INSERT OR REPLACE INTO alerts VALUES (
    'alert-002',
    'Pressure Spike Detected - Line 3',
    'Pressure reading shows abnormal spike. Investigate immediately.',
    'high',
    'Production Floor - Building B',
    'Line3-PRESS-002',
    strftime('%s', 'now', '-5 minutes'),
    'active',
    NULL,
    NULL,
    NULL,
    'Sensor calibration due next week',
    0,
    NULL
);

-- Insert sample medium severity alert
INSERT OR REPLACE INTO alerts VALUES (
    'alert-003',
    'Flow Rate Below Normal - Pump 5',
    'Flow rate has decreased by 15% from baseline.',
    'medium',
    'Utilities Room - Building C',
    'Pump5-FLOW-003',
    strftime('%s', 'now', '-15 minutes'),
    'active',
    NULL,
    NULL,
    NULL,
    'May require maintenance soon',
    0,
    NULL
);

-- Insert sample low severity alert
INSERT OR REPLACE INTO alerts VALUES (
    'alert-004',
    'Communication Delay - PLC 12',
    'Intermittent communication delays detected.',
    'low',
    'Control Room - Building A',
    'PLC12-COMM-004',
    strftime('%s', 'now', '-30 minutes'),
    'active',
    NULL,
    NULL,
    NULL,
    'Network congestion possible',
    0,
    NULL
);

-- Insert acknowledged alert
INSERT OR REPLACE INTO alerts VALUES (
    'alert-005',
    'Motor Vibration - Conveyor 2',
    'Abnormal vibration levels detected on conveyor motor.',
    'high',
    'Production Floor - Building A',
    'Conv2-VIB-005',
    strftime('%s', 'now', '-1 hour'),
    'active',
    'operator@scada.local',
    strftime('%s', 'now', '-45 minutes'),
    NULL,
    'Acknowledged by operator - investigating',
    0,
    NULL
);

-- Create system_status table
CREATE TABLE IF NOT EXISTS system_status (
    id TEXT PRIMARY KEY,
    status TEXT NOT NULL,
    active_alerts_count INTEGER DEFAULT 0,
    critical_count INTEGER DEFAULT 0,
    high_count INTEGER DEFAULT 0,
    medium_count INTEGER DEFAULT 0,
    low_count INTEGER DEFAULT 0,
    last_update INTEGER NOT NULL,
    synced_to_cloud INTEGER DEFAULT 0
);

-- Insert current system status
INSERT OR REPLACE INTO system_status VALUES (
    'current',
    'critical',
    5,
    1,
    2,
    1,
    1,
    strftime('%s', 'now'),
    0
);

-- Create sync_log table
CREATE TABLE IF NOT EXISTS sync_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sync_type TEXT NOT NULL,
    direction TEXT NOT NULL,
    records_count INTEGER,
    status TEXT NOT NULL,
    error_message TEXT,
    timestamp INTEGER NOT NULL
);
"@

# Write SQL to temp file
$tempSqlFile = "$env:TEMP\scada_seed.sql"
$sql | Out-File -FilePath $tempSqlFile -Encoding UTF8

# Execute SQL
try {
    Write-Host "Executing SQL seed script..." -ForegroundColor Yellow
    sqlite3 $dbPath ".read $tempSqlFile"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database seeded successfully!" -ForegroundColor Green
        Write-Host ""
        
        # Query and display results
        Write-Host "Sample Alerts Created:" -ForegroundColor Cyan
        Write-Host "-----------------------------------------------------------" -ForegroundColor Cyan
        
        $query = "SELECT id, title, severity, location FROM alerts ORDER BY timestamp DESC;"
        sqlite3 $dbPath $query | ForEach-Object {
            Write-Host $_ -ForegroundColor White
        }
        
        Write-Host "-----------------------------------------------------------" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Database Location: $dbPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Start the Windows Sync Service to sync with Firebase" -ForegroundColor White
        Write-Host "   cd windows_sync_service" -ForegroundColor White
        Write-Host "   .\install_service.bat (as Administrator)" -ForegroundColor White
        Write-Host ""
        Write-Host "2. Or test in console mode:" -ForegroundColor White
        Write-Host "   cd windows_sync_service" -ForegroundColor White
        Write-Host "   .\test_service.bat" -ForegroundColor White
        Write-Host ""
        Write-Host "3. View logs:" -ForegroundColor White
        Write-Host "   Get-Content C:\ScadaAlarms\Logs\sync_service.log -Wait" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "❌ Error seeding database" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
} finally {
    # Clean up temp file
    if (Test-Path $tempSqlFile) {
        Remove-Item $tempSqlFile -Force
    }
}

Write-Host "============================================" -ForegroundColor Cyan
pause
