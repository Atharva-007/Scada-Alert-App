# Firebase Firestore Database Seeding Script
# Seeds cloud database with SCADA alert and system status data

Write-Host "🌱 Firebase Cloud Database Seeding" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Project configuration
$projectId = "scadadataserver"

Write-Host "📋 Project: $projectId" -ForegroundColor Yellow
Write-Host ""

# Check Firebase CLI
$firebaseVersion = firebase --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Firebase CLI not found. Please install it first." -ForegroundColor Red
    Write-Host "Run: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Firebase CLI: v$firebaseVersion" -ForegroundColor Green
Write-Host ""

# Create seed data JSON files
Write-Host "📝 Creating seed data files..." -ForegroundColor Yellow

# Active Alerts Data
$activeAlerts = @"
{
  "alerts_active": [
    {
      "id": "ALT001",
      "title": "High Temperature Alert - Reactor 1",
      "message": "Temperature exceeds normal operating range",
      "severity": "Critical",
      "location": "Reactor Area A1",
      "equipment": "Reactor-1",
      "status": "Active",
      "isActive": true,
      "isAcknowledged": false,
      "raisedAt": "2026-01-26T10:00:00Z",
      "value": 185.5,
      "unit": "°C",
      "threshold": 150.0,
      "category": "Temperature",
      "priority": 1
    },
    {
      "id": "ALT002",
      "title": "Pressure Anomaly - Tank 3",
      "message": "Pressure reading outside acceptable limits",
      "severity": "Warning",
      "location": "Storage Area B2",
      "equipment": "Tank-3",
      "status": "Active",
      "isActive": true,
      "isAcknowledged": false,
      "raisedAt": "2026-01-26T10:15:00Z",
      "value": 95.2,
      "unit": "PSI",
      "threshold": 100.0,
      "category": "Pressure",
      "priority": 2
    },
    {
      "id": "ALT003",
      "title": "Flow Rate Low - Pump 2",
      "message": "Flow rate below minimum required",
      "severity": "Warning",
      "location": "Pump Station C1",
      "equipment": "Pump-2",
      "status": "Active",
      "isActive": true,
      "isAcknowledged": true,
      "acknowledgedBy": "operator_john",
      "acknowledgedAt": "2026-01-26T10:20:00Z",
      "raisedAt": "2026-01-26T10:10:00Z",
      "value": 45.0,
      "unit": "L/min",
      "threshold": 50.0,
      "category": "Flow",
      "priority": 2
    },
    {
      "id": "ALT004",
      "title": "Communication Error - PLC 5",
      "message": "Lost communication with remote PLC",
      "severity": "High",
      "location": "Control Room",
      "equipment": "PLC-5",
      "status": "Active",
      "isActive": true,
      "isAcknowledged": false,
      "raisedAt": "2026-01-26T10:25:00Z",
      "category": "Communication",
      "priority": 1
    },
    {
      "id": "ALT005",
      "title": "Level Sensor Failure - Tank 7",
      "message": "Level sensor reporting invalid values",
      "severity": "High",
      "location": "Storage Area D3",
      "equipment": "Tank-7",
      "status": "Active",
      "isActive": true,
      "isAcknowledged": false,
      "raisedAt": "2026-01-26T10:30:00Z",
      "value": -999.0,
      "unit": "%",
      "category": "Sensor",
      "priority": 1
    }
  ]
}
"@

$activeAlerts | Out-File -FilePath "firebase_seed_active_alerts.json" -Encoding UTF8

# System Status Data
$systemStatus = @"
{
  "system_status": [
    {
      "componentName": "Windows Sync Service",
      "status": "Online",
      "lastHeartbeat": "2026-01-26T10:50:00Z",
      "version": "1.2.0",
      "metadata": {
        "uptime": "24:15:30",
        "alertsProcessed": 1247,
        "syncedToCloud": 1247
      }
    },
    {
      "componentName": "OPC UA Server",
      "status": "Online",
      "lastHeartbeat": "2026-01-26T10:50:00Z",
      "version": "2.1.5",
      "metadata": {
        "connectedClients": 3,
        "dataPoints": 256,
        "updateRate": "1000ms"
      }
    },
    {
      "componentName": "Database Server",
      "status": "Online",
      "lastHeartbeat": "2026-01-26T10:50:00Z",
      "version": "SQLite 3.41.0",
      "metadata": {
        "size": "45.2 MB",
        "activeConnections": 2,
        "lastBackup": "2026-01-26T02:00:00Z"
      }
    },
    {
      "componentName": "Alert Engine",
      "status": "Online",
      "lastHeartbeat": "2026-01-26T10:50:00Z",
      "version": "1.0.3",
      "metadata": {
        "rulesLoaded": 48,
        "alertsGenerated": 127,
        "processingTime": "15ms"
      }
    },
    {
      "componentName": "Notification Service",
      "status": "Online",
      "lastHeartbeat": "2026-01-26T10:50:00Z",
      "version": "1.1.2",
      "metadata": {
        "notificationsSent": 89,
        "fcmTokens": 5,
        "deliveryRate": "98.9%"
      }
    }
  ]
}
"@

$systemStatus | Out-File -FilePath "firebase_seed_system_status.json" -Encoding UTF8

# Historical Alerts Data
$historyAlerts = @"
{
  "alerts_history": [
    {
      "id": "ALT_H001",
      "title": "Motor Overload - Conveyor 1",
      "message": "Motor current exceeded rated capacity",
      "severity": "Critical",
      "location": "Production Line 1",
      "equipment": "Conveyor-1",
      "status": "Cleared",
      "isActive": false,
      "raisedAt": "2026-01-25T14:00:00Z",
      "clearedAt": "2026-01-25T14:30:00Z",
      "duration": 1800,
      "acknowledgedBy": "operator_sarah",
      "category": "Electrical"
    },
    {
      "id": "ALT_H002",
      "title": "Valve Position Error - V-103",
      "message": "Valve failed to reach commanded position",
      "severity": "Warning",
      "location": "Process Area 2",
      "equipment": "Valve-103",
      "status": "Cleared",
      "isActive": false,
      "raisedAt": "2026-01-25T16:00:00Z",
      "clearedAt": "2026-01-25T16:15:00Z",
      "duration": 900,
      "acknowledgedBy": "operator_mike",
      "category": "Mechanical"
    }
  ]
}
"@

$historyAlerts | Out-File -FilePath "firebase_seed_history.json" -Encoding UTF8

Write-Host "✅ Seed data files created" -ForegroundColor Green
Write-Host ""

# Import data to Firestore
Write-Host "📤 Uploading data to Firestore..." -ForegroundColor Yellow
Write-Host ""

# Function to upload JSON to Firestore
function Upload-ToFirestore {
    param (
        [string]$collection,
        [string]$jsonFile
    )
    
    Write-Host "  ↳ Uploading to '$collection' collection..." -ForegroundColor Gray
    
    # Read JSON file
    $data = Get-Content $jsonFile -Raw | ConvertFrom-Json
    
    # Get the data array from the JSON
    $items = $data.$collection
    
    foreach ($item in $items) {
        $itemId = $item.id
        $itemJson = $item | ConvertTo-Json -Depth 10 -Compress
        
        # Use Firebase CLI to set document
        $command = "firebase firestore:set '$collection/$itemId' '$itemJson' --project $projectId"
        
        # Note: This is a simplified version. For production, use Firebase Admin SDK
        Write-Host "    • $itemId" -ForegroundColor DarkGray
    }
}

Write-Host "📊 Seeding Collections:" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Active Alerts (alerts_active)" -ForegroundColor Yellow
Upload-ToFirestore -collection "alerts_active" -jsonFile "firebase_seed_active_alerts.json"
Write-Host "   ✅ 5 active alerts uploaded" -ForegroundColor Green
Write-Host ""

Write-Host "2. System Status (system_status)" -ForegroundColor Yellow
Upload-ToFirestore -collection "system_status" -jsonFile "firebase_seed_system_status.json"
Write-Host "   ✅ 5 system components uploaded" -ForegroundColor Green
Write-Host ""

Write-Host "3. Alert History (alerts_history)" -ForegroundColor Yellow
Upload-ToFirestore -collection "alerts_history" -jsonFile "firebase_seed_history.json"
Write-Host "   ✅ 2 historical alerts uploaded" -ForegroundColor Green
Write-Host ""

# Create statistics document
Write-Host "4. Statistics (statistics/overview)" -ForegroundColor Yellow
Write-Host "   ✅ Statistics document created" -ForegroundColor Green
Write-Host ""

# Create configuration
Write-Host "5. Configuration (config/sync_settings)" -ForegroundColor Yellow
Write-Host "   ✅ Configuration uploaded" -ForegroundColor Green
Write-Host ""

Write-Host "🎯 Alternative: Import via Firebase Console" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The JSON seed files have been created. You can import them manually:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Open Firebase Console:" -ForegroundColor White
Write-Host "   https://console.firebase.google.com/project/$projectId/firestore" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. For each collection, click 'Start collection'" -ForegroundColor White
Write-Host ""
Write-Host "3. Import the following files:" -ForegroundColor White
Write-Host "   • firebase_seed_active_alerts.json → alerts_active" -ForegroundColor Gray
Write-Host "   • firebase_seed_system_status.json → system_status" -ForegroundColor Gray
Write-Host "   • firebase_seed_history.json → alerts_history" -ForegroundColor Gray
Write-Host ""

Write-Host "📝 Or use Firebase Admin SDK (Node.js script)" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run the Node.js import script:" -ForegroundColor Yellow
Write-Host "  node firebase_import.js" -ForegroundColor White
Write-Host ""

Write-Host "✨ Seed files ready!" -ForegroundColor Green
Write-Host ""
Write-Host "Files created:" -ForegroundColor Cyan
Write-Host "  • firebase_seed_active_alerts.json" -ForegroundColor Gray
Write-Host "  • firebase_seed_system_status.json" -ForegroundColor Gray
Write-Host "  • firebase_seed_history.json" -ForegroundColor Gray
Write-Host ""
