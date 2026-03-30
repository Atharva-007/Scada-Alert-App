# Firebase Data Upload Script for SCADA Alarm System
# This script helps upload sample data to Firebase Cloud

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Firebase Data Upload - SCADA System     " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$projectId = "scadadataserver"
$serviceAccountPath = "C:\ScadaAlarms\firebase-service-account.json"

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow
Write-Host ""

# 1. Check Firebase CLI
try {
    $firebaseVersion = firebase --version
    Write-Host "✅ Firebase CLI: v$firebaseVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase CLI not installed" -ForegroundColor Red
    Write-Host "Install: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

# 2. Check service account
if (Test-Path $serviceAccountPath) {
    Write-Host "✅ Service account key found" -ForegroundColor Green
} else {
    Write-Host "⚠️  Service account key not found" -ForegroundColor Yellow
    Write-Host "Location: $serviceAccountPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Download from:" -ForegroundColor Yellow
    Write-Host "https://console.firebase.google.com/project/$projectId/settings/serviceaccounts" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Steps:" -ForegroundColor Yellow
    Write-Host "1. Click 'Generate new private key'" -ForegroundColor White
    Write-Host "2. Save as: $serviceAccountPath" -ForegroundColor White
    Write-Host ""
    $continue = Read-Host "Continue without service account? (y/n)"
    if ($continue -ne 'y') {
        exit 1
    }
}

# 3. Check if Firestore database exists
Write-Host ""
Write-Host "Checking Firestore database..." -ForegroundColor Yellow
$dbCheck = firebase firestore:databases:list --project $projectId 2>&1

if ($dbCheck -match "No databases found") {
    Write-Host "❌ Firestore database not created!" -ForegroundColor Red
    Write-Host ""
    Write-Host "CRITICAL: You must create the Firestore database first!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Steps:" -ForegroundColor Yellow
    Write-Host "1. Open: https://console.firebase.google.com/project/$projectId/firestore" -ForegroundColor Cyan
    Write-Host "2. Click: 'Create database'" -ForegroundColor White
    Write-Host "3. Select: 'Production mode'" -ForegroundColor White
    Write-Host "4. Choose location: 'us-central' (or closest to you)" -ForegroundColor White
    Write-Host "5. Click: 'Enable'" -ForegroundColor White
    Write-Host ""
    Write-Host "After creating, run this script again." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
} else {
    Write-Host "✅ Firestore database exists" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Deployment Options                       " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Select what to deploy:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Deploy Security Rules (Firestore + Storage)" -ForegroundColor White
Write-Host "2. Deploy Indexes (for query optimization)" -ForegroundColor White
Write-Host "3. Upload Sample Alert Data (via manual JSON import)" -ForegroundColor White
Write-Host "4. All of the above" -ForegroundColor White
Write-Host "5. Exit" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter choice (1-5)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "Deploying security rules..." -ForegroundColor Cyan
        
        Write-Host ""
        Write-Host "Deploying Firestore rules..." -ForegroundColor Yellow
        firebase deploy --only firestore:rules --project $projectId
        
        Write-Host ""
        Write-Host "Deploying Storage rules..." -ForegroundColor Yellow
        firebase deploy --only storage:rules --project $projectId
        
        Write-Host ""
        Write-Host "✅ Security rules deployed!" -ForegroundColor Green
    }
    
    "2" {
        Write-Host ""
        Write-Host "Deploying Firestore indexes..." -ForegroundColor Cyan
        firebase deploy --only firestore:indexes --project $projectId
        
        Write-Host ""
        Write-Host "✅ Indexes deployed!" -ForegroundColor Green
    }
    
    "3" {
        Write-Host ""
        Write-Host "Sample Data Upload Instructions" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Option A: Use Firebase Console (Recommended)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Open Firestore:" -ForegroundColor White
        Write-Host "   https://console.firebase.google.com/project/$projectId/firestore" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "2. Create Collection: 'alerts'" -ForegroundColor White
        Write-Host "   Document ID: alert-001" -ForegroundColor Gray
        Write-Host "   Fields:" -ForegroundColor Gray
        Write-Host "   {" -ForegroundColor Gray
        Write-Host '     "id": "alert-001",' -ForegroundColor Gray
        Write-Host '     "title": "High Temperature - Reactor 1",' -ForegroundColor Gray
        Write-Host '     "description": "Temperature exceeded 85°C",' -ForegroundColor Gray
        Write-Host '     "severity": "critical",' -ForegroundColor Gray
        Write-Host '     "location": "Building A",' -ForegroundColor Gray
        Write-Host '     "equipment": "Reactor-R1-TEMP-001",' -ForegroundColor Gray
        Write-Host '     "status": "active",' -ForegroundColor Gray
        Write-Host '     "timestamp": [Click Add field > Timestamp > Use current time]' -ForegroundColor Gray
        Write-Host "   }" -ForegroundColor Gray
        Write-Host ""
        Write-Host "3. Create Collection: 'system_status'" -ForegroundColor White
        Write-Host "   Document ID: current" -ForegroundColor Gray
        Write-Host "   Fields:" -ForegroundColor Gray
        Write-Host "   {" -ForegroundColor Gray
        Write-Host '     "status": "normal",' -ForegroundColor Gray
        Write-Host '     "active_alerts_count": 0,' -ForegroundColor Gray
        Write-Host '     "critical_count": 0,' -ForegroundColor Gray
        Write-Host '     "high_count": 0,' -ForegroundColor Gray
        Write-Host '     "medium_count": 0,' -ForegroundColor Gray
        Write-Host '     "low_count": 0,' -ForegroundColor Gray
        Write-Host '     "last_update": [Timestamp - current time]' -ForegroundColor Gray
        Write-Host "   }" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Option B: Use Windows Sync Service" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "1. Seed local database:" -ForegroundColor White
        Write-Host "   cd E:\scada_alarm_client" -ForegroundColor Cyan
        Write-Host "   .\seed_database.ps1" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "2. Run sync service in test mode:" -ForegroundColor White
        Write-Host "   cd windows_sync_service" -ForegroundColor Cyan
        Write-Host "   .\test_service.bat" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "This will automatically upload all local data to Firebase!" -ForegroundColor Green
        Write-Host ""
        
        # Create sample JSON files
        Write-Host "Creating sample JSON files..." -ForegroundColor Yellow
        
        $sampleAlert = @{
            id = "alert-001"
            title = "High Temperature - Reactor 1"
            description = "Temperature exceeded 85°C threshold"
            severity = "critical"
            location = "Building A - Production Floor"
            equipment = "Reactor-R1-TEMP-001"
            status = "active"
            acknowledged_by = $null
            acknowledged_at = $null
            notes = ""
        } | ConvertTo-Json -Depth 10
        
        $sampleStatus = @{
            status = "normal"
            active_alerts_count = 0
            critical_count = 0
            high_count = 0
            medium_count = 0
            low_count = 0
        } | ConvertTo-Json -Depth 10
        
        New-Item -ItemType Directory -Path ".\sample_data" -Force | Out-Null
        $sampleAlert | Out-File ".\sample_data\sample_alert.json" -Encoding UTF8
        $sampleStatus | Out-File ".\sample_data\sample_system_status.json" -Encoding UTF8
        
        Write-Host "✅ Sample JSON files created in: .\sample_data\" -ForegroundColor Green
        Write-Host ""
    }
    
    "4" {
        Write-Host ""
        Write-Host "Deploying everything..." -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "1. Deploying Firestore rules..." -ForegroundColor Yellow
        firebase deploy --only firestore:rules --project $projectId
        
        Write-Host ""
        Write-Host "2. Deploying Storage rules..." -ForegroundColor Yellow
        firebase deploy --only storage:rules --project $projectId
        
        Write-Host ""
        Write-Host "3. Deploying Firestore indexes..." -ForegroundColor Yellow
        firebase deploy --only firestore:indexes --project $projectId
        
        Write-Host ""
        Write-Host "✅ All deployments completed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next: Upload sample data (see Option 3)" -ForegroundColor Yellow
    }
    
    "5" {
        Write-Host "Exiting..." -ForegroundColor Yellow
        exit 0
    }
    
    default {
        Write-Host "Invalid choice" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Next Steps                               " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Enable Authentication:" -ForegroundColor White
Write-Host "   https://console.firebase.google.com/project/$projectId/authentication" -ForegroundColor Cyan
Write-Host "   - Enable Email/Password" -ForegroundColor Gray
Write-Host "   - Enable Anonymous" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Enable Cloud Storage:" -ForegroundColor White
Write-Host "   https://console.firebase.google.com/project/$projectId/storage" -ForegroundColor Cyan
Write-Host "   - Click 'Get started'" -ForegroundColor Gray
Write-Host "   - Use Production mode" -ForegroundColor Gray
Write-Host ""

Write-Host "3. Test the Flutter app:" -ForegroundColor White
Write-Host "   cd E:\scada_alarm_client" -ForegroundColor Cyan
Write-Host "   flutter run" -ForegroundColor Cyan
Write-Host ""

Write-Host "4. Set up Windows Sync Service:" -ForegroundColor White
Write-Host "   cd windows_sync_service" -ForegroundColor Cyan
Write-Host "   .\test_service.bat" -ForegroundColor Cyan
Write-Host ""

Write-Host "============================================" -ForegroundColor Cyan
pause
