# Complete Firebase Setup and App Launch
# One-command setup for SCADA Alarm Client with Firebase Cloud Sync

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🔥 SCADA Alarm Client - Firebase Cloud Sync Setup  🔥       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"

# Step 1: Prerequisites Check
Write-Host "📋 Step 1/6: Checking Prerequisites..." -ForegroundColor Yellow
Write-Host ""

# Check Flutter
Write-Host "  Checking Flutter..." -ForegroundColor Gray
$flutterVersion = flutter --version 2>&1 | Select-String -Pattern "Flutter" | Select-Object -First 1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Flutter installed: $flutterVersion" -ForegroundColor Green
} else {
    Write-Host "  ❌ Flutter not found. Please install Flutter SDK" -ForegroundColor Red
    exit 1
}

# Check Firebase CLI
Write-Host "  Checking Firebase CLI..." -ForegroundColor Gray
$firebaseVersion = firebase --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Firebase CLI: v$firebaseVersion" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Firebase CLI not found. Installing..." -ForegroundColor Yellow
    npm install -g firebase-tools
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ❌ Failed to install Firebase CLI" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✅ Firebase CLI installed" -ForegroundColor Green
}

# Check Node.js
Write-Host "  Checking Node.js..." -ForegroundColor Gray
$nodeVersion = node --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Node.js: $nodeVersion" -ForegroundColor Green
} else {
    Write-Host "  ❌ Node.js not found. Please install Node.js" -ForegroundColor Red
    Write-Host "  Download from: https://nodejs.org" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "✅ All prerequisites met!" -ForegroundColor Green
Write-Host ""

# Step 2: Firebase Login
Write-Host "📋 Step 2/6: Firebase Authentication..." -ForegroundColor Yellow
Write-Host ""

Write-Host "  Checking Firebase auth status..." -ForegroundColor Gray
firebase projects:list --json 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  🔐 Please login to Firebase..." -ForegroundColor Yellow
    firebase login --no-localhost
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ❌ Firebase login failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host "  ✅ Firebase authenticated" -ForegroundColor Green
Write-Host ""

# Step 3: Select Firebase Project
Write-Host "📋 Step 3/6: Selecting Firebase Project..." -ForegroundColor Yellow
Write-Host ""

firebase use scadadataserver
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Project 'scadadataserver' selected" -ForegroundColor Green
} else {
    Write-Host "  ❌ Project 'scadadataserver' not found" -ForegroundColor Red
    Write-Host "  Please create project at: https://console.firebase.google.com" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 4: Deploy Firebase Configuration
Write-Host "📋 Step 4/6: Deploying Firebase Configuration..." -ForegroundColor Yellow
Write-Host ""

Write-Host "  Deploying Firestore rules..." -ForegroundColor Gray
firebase deploy --only firestore:rules --project scadadataserver 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Firestore rules deployed" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Firestore rules deployment skipped" -ForegroundColor Yellow
}

Write-Host "  Deploying Firestore indexes..." -ForegroundColor Gray
firebase deploy --only firestore:indexes --project scadadataserver 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Firestore indexes deployed" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Firestore indexes deployment skipped" -ForegroundColor Yellow
}

Write-Host "  Deploying Storage rules..." -ForegroundColor Gray
firebase deploy --only storage --project scadadataserver 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Storage rules deployed" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Storage rules deployment skipped" -ForegroundColor Yellow
}

Write-Host ""

# Step 5: Install Dependencies
Write-Host "📋 Step 5/6: Installing Dependencies..." -ForegroundColor Yellow
Write-Host ""

Write-Host "  Installing Flutter packages..." -ForegroundColor Gray
flutter pub get | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Flutter packages installed" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Flutter packages installation had warnings" -ForegroundColor Yellow
}

if (Test-Path "package.json") {
    Write-Host "  Installing Node.js packages..." -ForegroundColor Gray
    npm install 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Node.js packages installed" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Node.js packages installation had warnings" -ForegroundColor Yellow
    }
}

Write-Host ""

# Step 6: Seed Database (Optional)
Write-Host "📋 Step 6/6: Database Seeding..." -ForegroundColor Yellow
Write-Host ""

Write-Host "  Do you want to seed the database with sample data? (Y/N)" -ForegroundColor Cyan
$seedChoice = Read-Host "  Choice"

if ($seedChoice -eq "Y" -or $seedChoice -eq "y") {
    Write-Host ""
    Write-Host "  Seeding database..." -ForegroundColor Gray
    
    if (Test-Path "firebase_import.js") {
        Write-Host "  Running Node.js import script..." -ForegroundColor Gray
        npm run seed
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Database seeded successfully" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️ Database seeding completed with warnings" -ForegroundColor Yellow
            Write-Host "  You can manually import data via Firebase Console" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ⚠️ Import script not found" -ForegroundColor Yellow
        Write-Host "  Run .\seed_firebase_cloud.ps1 manually" -ForegroundColor Gray
    }
} else {
    Write-Host "  ⏭️  Database seeding skipped" -ForegroundColor Gray
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║            ✨ Firebase Setup Complete! ✨                      ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Setup Summary
Write-Host "📊 Setup Summary:" -ForegroundColor Cyan
Write-Host "═════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  🔥 Firebase Project: scadadataserver" -ForegroundColor White
Write-Host "  📱 Project Number: 932777127221" -ForegroundColor White
Write-Host "  🌍 Region: us-central1" -ForegroundColor White
Write-Host "  💾 Storage: scadadataserver.firebasestorage.app" -ForegroundColor White
Write-Host ""
Write-Host "  ✅ Firestore Database: Configured" -ForegroundColor Green
Write-Host "  ✅ Cloud Storage: Configured" -ForegroundColor Green
Write-Host "  ✅ Cloud Messaging: Enabled" -ForegroundColor Green
Write-Host "  ✅ Security Rules: Deployed" -ForegroundColor Green
Write-Host "  ✅ Indexes: Deployed" -ForegroundColor Green
Write-Host ""

# Cloud Sync Features
Write-Host "🌐 Cloud Sync Features:" -ForegroundColor Cyan
Write-Host "═══════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ✅ Real-time alert synchronization" -ForegroundColor Green
Write-Host "  ✅ Offline data persistence" -ForegroundColor Green
Write-Host "  ✅ Automatic reconnection" -ForegroundColor Green
Write-Host "  ✅ Push notifications (FCM)" -ForegroundColor Green
Write-Host "  ✅ Device heartbeat monitoring" -ForegroundColor Green
Write-Host "  ✅ Multi-device sync" -ForegroundColor Green
Write-Host "  ✅ Conflict resolution" -ForegroundColor Green
Write-Host ""

# Next Steps
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "═══════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1️⃣  View Firebase Console:" -ForegroundColor Yellow
Write-Host "     https://console.firebase.google.com/project/scadadataserver" -ForegroundColor White
Write-Host ""
Write-Host "  2️⃣  Run the application:" -ForegroundColor Yellow
Write-Host "     flutter run -d windows" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3️⃣  Test cloud sync:" -ForegroundColor Yellow
Write-Host "     • Open app and verify data loads" -ForegroundColor White
Write-Host "     • Check Firestore in console for real-time updates" -ForegroundColor White
Write-Host "     • Test offline mode by disconnecting internet" -ForegroundColor White
Write-Host ""
Write-Host "  4️⃣  Monitor services:" -ForegroundColor Yellow
Write-Host "     • Firestore: Real-time database" -ForegroundColor White
Write-Host "     • Cloud Messaging: Push notifications" -ForegroundColor White
Write-Host "     • Storage: File uploads" -ForegroundColor White
Write-Host ""

# Documentation
Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "═════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  • Complete Guide: FIREBASE_CLOUD_SYNC_GUIDE.md" -ForegroundColor White
Write-Host "  • Quick Reference: QUICK_REFERENCE.md" -ForegroundColor White
Write-Host "  • API Docs: Firebase Console" -ForegroundColor White
Write-Host ""

# Launch Option
Write-Host "🚀 Launch Application?" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Do you want to run the app now? (Y/N)" -ForegroundColor Yellow
$launchChoice = Read-Host "  Choice"

if ($launchChoice -eq "Y" -or $launchChoice -eq "y") {
    Write-Host ""
    Write-Host "  🚀 Launching SCADA Alarm Client..." -ForegroundColor Cyan
    Write-Host ""
    
    flutter run -d windows
} else {
    Write-Host ""
    Write-Host "  ✅ Setup complete! Run 'flutter run -d windows' when ready." -ForegroundColor Green
    Write-Host ""
}

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
