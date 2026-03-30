# Complete Firebase Setup Verification Script
# Checks all components of the SCADA Alarm System

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SCADA ALARM SYSTEM - SETUP VERIFICATION  " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$projectId = "scadadataserver"
$checksPassed = 0
$totalChecks = 0

function Test-Requirement {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$SuccessMessage,
        [string]$FailureMessage,
        [string]$FixInstructions
    )
    
    $script:totalChecks++
    Write-Host "[$script:totalChecks] Checking: $Name..." -ForegroundColor Yellow -NoNewline
    
    try {
        $result = & $Test
        if ($result) {
            Write-Host " ✅" -ForegroundColor Green
            if ($SuccessMessage) {
                Write-Host "    $SuccessMessage" -ForegroundColor Gray
            }
            $script:checksPassed++
            return $true
        } else {
            Write-Host " ❌" -ForegroundColor Red
            if ($FailureMessage) {
                Write-Host "    $FailureMessage" -ForegroundColor Red
            }
            if ($FixInstructions) {
                Write-Host "    Fix: $FixInstructions" -ForegroundColor Yellow
            }
            return $false
        }
    } catch {
        Write-Host " ❌" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        if ($FixInstructions) {
            Write-Host "    Fix: $FixInstructions" -ForegroundColor Yellow
        }
        return $false
    }
}

Write-Host "SECTION 1: Development Tools" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Test-Requirement -Name "Flutter SDK" -Test {
    $version = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
    return $version -ne $null
} -SuccessMessage "Flutter is installed" `
  -FailureMessage "Flutter SDK not found" `
  -FixInstructions "Install from https://flutter.dev/docs/get-started/install"

Test-Requirement -Name "Dart SDK" -Test {
    $version = dart --version 2>&1
    return $version -ne $null
} -SuccessMessage "Dart is installed" `
  -FailureMessage "Dart SDK not found" `
  -FixInstructions "Included with Flutter SDK"

Test-Requirement -Name "Firebase CLI" -Test {
    $version = firebase --version 2>&1
    return $version -ne $null
} -SuccessMessage "Firebase CLI v$((firebase --version))" `
  -FailureMessage "Firebase CLI not installed" `
  -FixInstructions "Run: npm install -g firebase-tools"

Test-Requirement -Name "FlutterFire CLI" -Test {
    $version = flutterfire --version 2>&1
    return $version -ne $null
} -SuccessMessage "FlutterFire CLI installed" `
  -FailureMessage "FlutterFire CLI not installed" `
  -FixInstructions "Run: dart pub global activate flutterfire_cli"

Test-Requirement -Name ".NET 6.0 SDK" -Test {
    $version = dotnet --version 2>&1
    return $version -match "^6\."
} -SuccessMessage ".NET 6.0 SDK installed" `
  -FailureMessage ".NET 6.0 SDK not found" `
  -FixInstructions "Install from https://dotnet.microsoft.com/download/dotnet/6.0"

Write-Host ""
Write-Host "SECTION 2: Firebase Project" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Test-Requirement -Name "Firebase Login" -Test {
    firebase projects:list --json 2>&1 | Out-Null
    return $LASTEXITCODE -eq 0
} -SuccessMessage "Logged in to Firebase" `
  -FailureMessage "Not logged in to Firebase" `
  -FixInstructions "Run: firebase login"

Test-Requirement -Name "Firebase Project" -Test {
    $projects = firebase projects:list 2>&1
    return $projects -match $projectId
} -SuccessMessage "Project '$projectId' found" `
  -FailureMessage "Project '$projectId' not found" `
  -FixInstructions "Create project in Firebase Console"

$firestoreExists = Test-Requirement -Name "Firestore Database" -Test {
    $db = firebase firestore:databases:list --project $projectId 2>&1
    return $db -notmatch "No databases found"
} -SuccessMessage "Firestore database created" `
  -FailureMessage "Firestore database NOT created" `
  -FixInstructions "Create at: https://console.firebase.google.com/project/$projectId/firestore"

Write-Host ""
Write-Host "SECTION 3: Project Files" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Test-Requirement -Name "pubspec.yaml" -Test {
    return Test-Path "E:\scada_alarm_client\pubspec.yaml"
} -SuccessMessage "Flutter project file exists" `
  -FailureMessage "pubspec.yaml not found"

Test-Requirement -Name "firebase_options.dart" -Test {
    return Test-Path "E:\scada_alarm_client\lib\firebase_options.dart"
} -SuccessMessage "Firebase config file exists" `
  -FailureMessage "Firebase options file missing" `
  -FixInstructions "Run: flutterfire configure"

Test-Requirement -Name "firestore.rules" -Test {
    return Test-Path "E:\scada_alarm_client\firestore.rules"
} -SuccessMessage "Firestore security rules exist" `
  -FailureMessage "Firestore rules missing"

Test-Requirement -Name "storage.rules" -Test {
    return Test-Path "E:\scada_alarm_client\storage.rules"
} -SuccessMessage "Storage security rules exist" `
  -FailureMessage "Storage rules missing"

Test-Requirement -Name "Windows Sync Service" -Test {
    return Test-Path "E:\scada_alarm_client\windows_sync_service\ScadaAlarmSyncService.cs"
} -SuccessMessage "Windows service code exists" `
  -FailureMessage "Windows service files missing"

Write-Host ""
Write-Host "SECTION 4: Firebase Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Test-Requirement -Name "Service Account Directory" -Test {
    $dir = "C:\ScadaAlarms"
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return Test-Path $dir
} -SuccessMessage "Service directory created" `
  -FailureMessage "Could not create C:\ScadaAlarms"

$serviceAccountExists = Test-Requirement -Name "Service Account Key" -Test {
    return Test-Path "C:\ScadaAlarms\firebase-service-account.json"
} -SuccessMessage "Service account key found" `
  -FailureMessage "Service account key NOT found" `
  -FixInstructions "Download from: https://console.firebase.google.com/project/$projectId/settings/serviceaccounts"

Test-Requirement -Name "SQLite Database Directory" -Test {
    $dir = "C:\ScadaAlarms"
    return Test-Path $dir
} -SuccessMessage "Database directory exists"

$sqliteExists = Test-Requirement -Name "SQLite Database File" -Test {
    return Test-Path "C:\ScadaAlarms\alerts.db"
} -SuccessMessage "SQLite database exists" `
  -FailureMessage "SQLite database not created" `
  -FixInstructions "Run: .\seed_database.ps1"

Write-Host ""
Write-Host "SECTION 5: Flutter Dependencies" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Test-Requirement -Name "Flutter Packages" -Test {
    Push-Location "E:\scada_alarm_client"
    $result = Test-Path ".dart_tool"
    Pop-Location
    return $result
} -SuccessMessage "Flutter packages installed" `
  -FailureMessage "Flutter packages not installed" `
  -FixInstructions "Run: flutter pub get"

Write-Host ""
Write-Host "SECTION 6: Windows Sync Service" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Test-Requirement -Name "Service Build Directory" -Test {
    return Test-Path "E:\scada_alarm_client\windows_sync_service\bin"
} -SuccessMessage "Service has been built" `
  -FailureMessage "Service not built yet" `
  -FixInstructions "Run: cd windows_sync_service && dotnet build"

$serviceInstalled = Test-Requirement -Name "Windows Service Installed" -Test {
    $service = Get-Service -Name "ScadaAlarmSyncService" -ErrorAction SilentlyContinue
    return $service -ne $null
} -SuccessMessage "Windows service is installed" `
  -FailureMessage "Windows service not installed" `
  -FixInstructions "Run: .\install_service.bat (as Administrator)"

if ($serviceInstalled) {
    Test-Requirement -Name "Windows Service Status" -Test {
        $service = Get-Service -Name "ScadaAlarmSyncService" -ErrorAction SilentlyContinue
        return $service.Status -eq "Running"
    } -SuccessMessage "Service is running" `
      -FailureMessage "Service is not running" `
      -FixInstructions "Run: sc start ScadaAlarmSyncService"
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  VERIFICATION SUMMARY                     " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$percentage = [math]::Round(($checksPassed / $totalChecks) * 100, 0)
Write-Host "Checks Passed: $checksPassed / $totalChecks ($percentage%)" -ForegroundColor $(if ($percentage -ge 80) { "Green" } elseif ($percentage -ge 50) { "Yellow" } else { "Red" })
Write-Host ""

if ($percentage -eq 100) {
    Write-Host "🎉 EXCELLENT! All systems ready!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now:" -ForegroundColor Cyan
    Write-Host "  1. Run the Flutter app: flutter run" -ForegroundColor White
    Write-Host "  2. View service logs: Get-Content C:\ScadaAlarms\Logs\sync_service.log -Wait" -ForegroundColor White
    Write-Host "  3. Monitor Firestore: https://console.firebase.google.com/project/$projectId/firestore" -ForegroundColor White
} elseif ($percentage -ge 80) {
    Write-Host "✅ GOOD! Most systems ready!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Optional improvements:" -ForegroundColor Yellow
    if (!$serviceAccountExists) {
        Write-Host "  • Download service account key for Windows Service" -ForegroundColor White
    }
    if (!$sqliteExists) {
        Write-Host "  • Run .\seed_database.ps1 to create sample data" -ForegroundColor White
    }
    if (!$serviceInstalled) {
        Write-Host "  • Install Windows Sync Service (optional)" -ForegroundColor White
    }
} elseif ($percentage -ge 50) {
    Write-Host "⚠️  PARTIAL SETUP - Action required!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Critical steps missing:" -ForegroundColor Red
    if (!$firestoreExists) {
        Write-Host "  1. CREATE FIRESTORE DATABASE (REQUIRED)" -ForegroundColor Red
        Write-Host "     https://console.firebase.google.com/project/$projectId/firestore" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "Run the setup script:" -ForegroundColor Yellow
    Write-Host "  .\upload_to_firebase.ps1" -ForegroundColor Cyan
} else {
    Write-Host "❌ SETUP INCOMPLETE - Multiple issues!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Follow the complete setup guide:" -ForegroundColor Yellow
    Write-Host "  See: FIREBASE_COMPLETE_SETUP_GUIDE.md" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Quick start:" -ForegroundColor Yellow
    Write-Host "  1. Create Firestore database in console" -ForegroundColor White
    Write-Host "  2. Run: .\upload_to_firebase.ps1" -ForegroundColor White
    Write-Host "  3. Run this verification again" -ForegroundColor White
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DETAILED INSTRUCTIONS                    " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if (!$firestoreExists) {
    Write-Host "🔥 CREATE FIRESTORE DATABASE (REQUIRED):" -ForegroundColor Red
    Write-Host ""
    Write-Host "1. Open: https://console.firebase.google.com/project/$projectId/firestore" -ForegroundColor Cyan
    Write-Host "2. Click: 'Create database'" -ForegroundColor White
    Write-Host "3. Select: 'Production mode'" -ForegroundColor White
    Write-Host "4. Choose: 'us-central' (or closest region)" -ForegroundColor White
    Write-Host "5. Click: 'Enable'" -ForegroundColor White
    Write-Host ""
}

Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "  • Complete Guide: FIREBASE_COMPLETE_SETUP_GUIDE.md" -ForegroundColor White
Write-Host "  • Quick Reference: FIREBASE_SETUP.md" -ForegroundColor White
Write-Host "  • README: README.md" -ForegroundColor White
Write-Host ""

Write-Host "🔧 Quick Commands:" -ForegroundColor Cyan
Write-Host "  • Deploy rules: firebase deploy --only firestore:rules,storage:rules" -ForegroundColor White
Write-Host "  • Upload data: .\upload_to_firebase.ps1" -ForegroundColor White
Write-Host "  • Seed database: .\seed_database.ps1" -ForegroundColor White
Write-Host "  • Run app: flutter run" -ForegroundColor White
Write-Host "  • Test service: cd windows_sync_service && .\test_service.bat" -ForegroundColor White
Write-Host ""

Write-Host "============================================" -ForegroundColor Cyan
pause
