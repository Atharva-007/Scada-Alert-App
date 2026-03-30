// Firebase Admin SDK - Windows Sync Service Integration
// Syncs local SQLite alerts to Firebase Firestore Cloud

const admin = require('firebase-admin');
const sqlite3 = require('sqlite3').verbose();
const fs = require('fs');
const path = require('path');

// Configuration
const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'scadadataserver-firebase-adminsdk-fbsvc-717edd254a private key.json');
const LOCAL_DB_PATH = 'C:\\ScadaAlarms\\alerts.db';
const SYNC_INTERVAL_MS = 5000; // 5 seconds
const BATCH_SIZE = 500;

console.log('🔄 Firebase Cloud Sync Service');
console.log('==============================');
console.log('');

// Check service account
if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('❌ Service account key not found!');
  console.error('Expected:', SERVICE_ACCOUNT_PATH);
  process.exit(1);
}

// Check local database
if (!fs.existsSync(LOCAL_DB_PATH)) {
  console.error('❌ Local database not found!');
  console.error('Expected:', LOCAL_DB_PATH);
  console.error('Run Windows Sync Service first to create the database');
  process.exit(1);
}

// Initialize Firebase Admin
console.log('🔥 Initializing Firebase Admin SDK...');
const serviceAccount = require(SERVICE_ACCOUNT_PATH);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://scadadataserver-default-rtdb.firebaseio.com"
});

const db = admin.firestore();
const localDb = new sqlite3.Database(LOCAL_DB_PATH);

console.log('✅ Firebase Admin SDK initialized');
console.log('✅ Connected to local database');
console.log('');

// Track sync status
let syncStats = {
  totalSynced: 0,
  lastSyncTime: null,
  errors: 0,
  isRunning: false
};

// Sync active alerts to Firestore
async function syncActiveAlerts() {
  if (syncStats.isRunning) {
    console.log('⏭️  Previous sync still running, skipping...');
    return;
  }

  syncStats.isRunning = true;
  
  try {
    // Get active alerts from local SQLite
    const alerts = await new Promise((resolve, reject) => {
      localDb.all(
        `SELECT * FROM Alerts WHERE IsActive = 1 ORDER BY RaisedAt DESC`,
        (err, rows) => {
          if (err) reject(err);
          else resolve(rows);
        }
      );
    });

    if (alerts.length === 0) {
      console.log('📭 No active alerts to sync');
      syncStats.isRunning = false;
      return;
    }

    console.log(`📊 Syncing ${alerts.length} active alerts...`);

    // Batch write to Firestore
    const batch = db.batch();
    let batchCount = 0;
    let totalSynced = 0;

    for (const alert of alerts) {
      const docRef = db.collection('alerts_active').doc(alert.Id);
      
      const alertData = {
        id: alert.Id,
        name: alert.Name || 'Unknown Alert',
        description: alert.Description || '',
        severity: alert.Severity || 'Info',
        source: alert.Source || 'SCADA System',
        tagName: alert.TagName || '',
        currentValue: alert.CurrentValue || 0,
        threshold: alert.Threshold || 0,
        condition: alert.Condition || '',
        isActive: alert.IsActive === 1,
        isAcknowledged: alert.IsAcknowledged === 1,
        raisedAt: admin.firestore.Timestamp.fromDate(new Date(alert.RaisedAt)),
        lastSynced: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Add optional fields
      if (alert.AcknowledgedAt) {
        alertData.acknowledgedAt = admin.firestore.Timestamp.fromDate(new Date(alert.AcknowledgedAt));
      }
      if (alert.AcknowledgedBy) {
        alertData.acknowledgedBy = alert.AcknowledgedBy;
      }
      if (alert.AcknowledgedComment) {
        alertData.acknowledgedComment = alert.AcknowledgedComment;
      }
      if (alert.ClearedAt) {
        alertData.clearedAt = admin.firestore.Timestamp.fromDate(new Date(alert.ClearedAt));
      }

      batch.set(docRef, alertData, { merge: true });
      batchCount++;
      totalSynced++;

      // Commit batch every BATCH_SIZE operations
      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        console.log(`  ✓ Batch committed: ${totalSynced} alerts synced`);
        batchCount = 0;
      }
    }

    // Commit remaining batch
    if (batchCount > 0) {
      await batch.commit();
    }

    syncStats.totalSynced += totalSynced;
    syncStats.lastSyncTime = new Date();
    
    console.log(`✅ Sync complete: ${totalSynced} alerts synced to Firestore`);

  } catch (error) {
    console.error('❌ Sync error:', error.message);
    syncStats.errors++;
  } finally {
    syncStats.isRunning = false;
  }
}

// Sync cleared alerts to history
async function syncClearedAlerts() {
  try {
    // Get recently cleared alerts (last 24 hours)
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    
    const clearedAlerts = await new Promise((resolve, reject) => {
      localDb.all(
        `SELECT * FROM Alerts WHERE IsActive = 0 AND ClearedAt > ? LIMIT 100`,
        [yesterday],
        (err, rows) => {
          if (err) reject(err);
          else resolve(rows);
        }
      );
    });

    if (clearedAlerts.length === 0) return;

    console.log(`📚 Archiving ${clearedAlerts.length} cleared alerts...`);

    const batch = db.batch();

    for (const alert of clearedAlerts) {
      const docRef = db.collection('alerts_history').doc(alert.Id);
      
      const alertData = {
        id: alert.Id,
        name: alert.Name,
        description: alert.Description,
        severity: alert.Severity,
        source: alert.Source,
        tagName: alert.TagName,
        currentValue: alert.CurrentValue,
        threshold: alert.Threshold,
        condition: alert.Condition,
        isActive: false,
        isAcknowledged: alert.IsAcknowledged === 1,
        raisedAt: admin.firestore.Timestamp.fromDate(new Date(alert.RaisedAt)),
        clearedAt: admin.firestore.Timestamp.fromDate(new Date(alert.ClearedAt)),
        archivedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (alert.AcknowledgedAt) {
        alertData.acknowledgedAt = admin.firestore.Timestamp.fromDate(new Date(alert.AcknowledgedAt));
      }
      if (alert.AcknowledgedBy) {
        alertData.acknowledgedBy = alert.AcknowledgedBy;
      }

      batch.set(docRef, alertData, { merge: true });

      // Remove from active alerts
      const activeDocRef = db.collection('alerts_active').doc(alert.Id);
      batch.delete(activeDocRef);
    }

    await batch.commit();
    console.log(`✅ Archived ${clearedAlerts.length} cleared alerts`);

  } catch (error) {
    console.error('❌ Archive error:', error.message);
  }
}

// Update system status in Firestore
async function updateSystemStatus() {
  try {
    await db.collection('system_status').doc('CloudSyncService').set({
      componentName: 'Cloud Sync Service',
      status: 'Online',
      lastHeartbeat: admin.firestore.FieldValue.serverTimestamp(),
      version: '1.0.0',
      metadata: {
        totalSynced: syncStats.totalSynced,
        lastSyncTime: syncStats.lastSyncTime ? syncStats.lastSyncTime.toISOString() : null,
        errors: syncStats.errors,
        localDbPath: LOCAL_DB_PATH,
      }
    });
  } catch (error) {
    console.error('⚠️ Status update error:', error.message);
  }
}

// Main sync loop
async function startSyncService() {
  console.log('🚀 Starting Cloud Sync Service...');
  console.log(`   Sync interval: ${SYNC_INTERVAL_MS / 1000}s`);
  console.log(`   Local DB: ${LOCAL_DB_PATH}`);
  console.log(`   Firestore Project: ${serviceAccount.project_id}`);
  console.log('');
  console.log('Press Ctrl+C to stop');
  console.log('');

  // Initial sync
  await syncActiveAlerts();
  await syncClearedAlerts();
  await updateSystemStatus();

  // Periodic sync
  setInterval(async () => {
    const now = new Date().toLocaleTimeString();
    console.log(`\n⏰ [${now}] Running sync cycle...`);
    
    await syncActiveAlerts();
    await syncClearedAlerts();
    await updateSystemStatus();
    
    console.log(`📊 Stats: Total synced: ${syncStats.totalSynced}, Errors: ${syncStats.errors}`);
  }, SYNC_INTERVAL_MS);
}

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n\n🛑 Shutting down Cloud Sync Service...');
  
  // Update status to offline
  try {
    await db.collection('system_status').doc('CloudSyncService').update({
      status: 'Offline',
      lastHeartbeat: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('Error updating status:', error.message);
  }

  console.log('✅ Cloud Sync Service stopped');
  console.log('');
  console.log('📊 Final Stats:');
  console.log(`   Total alerts synced: ${syncStats.totalSynced}`);
  console.log(`   Errors encountered: ${syncStats.errors}`);
  console.log(`   Last sync: ${syncStats.lastSyncTime ? syncStats.lastSyncTime.toLocaleString() : 'Never'}`);
  
  localDb.close();
  process.exit(0);
});

// Start the service
startSyncService().catch(error => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
