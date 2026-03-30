#!/usr/bin/env node
// Firebase Cloud Firestore Import Script
// Imports seed data to Firestore using Firebase Admin SDK

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Load service account key
const serviceAccountPath = path.join(__dirname, 'scadadataserver-firebase-adminsdk-fbsvc-717edd254a private key.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ Service account key not found!');
  console.error('Expected at:', serviceAccountPath);
  console.error('Download from: Firebase Console > Project Settings > Service Accounts');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://scadadataserver-default-rtdb.firebaseio.com"
});

const db = admin.firestore();

console.log('🔥 Firebase Cloud Firestore Import');
console.log('===================================');
console.log('');

async function importData() {
  try {
    // Import Active Alerts
    console.log('📊 Importing Active Alerts...');
    const activeAlerts = [
      {
        id: 'ALT001',
        title: 'High Temperature Alert - Reactor 1',
        message: 'Temperature exceeds normal operating range',
        severity: 'Critical',
        location: 'Reactor Area A1',
        equipment: 'Reactor-1',
        status: 'Active',
        isActive: true,
        isAcknowledged: false,
        raisedAt: admin.firestore.Timestamp.fromDate(new Date('2026-01-26T10:00:00Z')),
        value: 185.5,
        unit: '°C',
        threshold: 150.0,
        category: 'Temperature',
        priority: 1
      },
      {
        id: 'ALT002',
        title: 'Pressure Anomaly - Tank 3',
        message: 'Pressure reading outside acceptable limits',
        severity: 'Warning',
        location: 'Storage Area B2',
        equipment: 'Tank-3',
        status: 'Active',
        isActive: true,
        isAcknowledged: false,
        raisedAt: admin.firestore.Timestamp.fromDate(new Date('2026-01-26T10:15:00Z')),
        value: 95.2,
        unit: 'PSI',
        threshold: 100.0,
        category: 'Pressure',
        priority: 2
      },
      {
        id: 'ALT003',
        title: 'Flow Rate Low - Pump 2',
        message: 'Flow rate below minimum required',
        severity: 'Warning',
        location: 'Pump Station C1',
        equipment: 'Pump-2',
        status: 'Active',
        isActive: true,
        isAcknowledged: true,
        acknowledgedBy: 'operator_john',
        acknowledgedAt: admin.firestore.Timestamp.fromDate(new Date('2026-01-26T10:20:00Z')),
        raisedAt: admin.firestore.Timestamp.fromDate(new Date('2026-01-26T10:10:00Z')),
        value: 45.0,
        unit: 'L/min',
        threshold: 50.0,
        category: 'Flow',
        priority: 2
      },
      {
        id: 'ALT004',
        title: 'Communication Error - PLC 5',
        message: 'Lost communication with remote PLC',
        severity: 'High',
        location: 'Control Room',
        equipment: 'PLC-5',
        status: 'Active',
        isActive: true,
        isAcknowledged: false,
        raisedAt: admin.firestore.Timestamp.fromDate(new Date('2026-01-26T10:25:00Z')),
        category: 'Communication',
        priority: 1
      },
      {
        id: 'ALT005',
        title: 'Level Sensor Failure - Tank 7',
        message: 'Level sensor reporting invalid values',
        severity: 'High',
        location: 'Storage Area D3',
        equipment: 'Tank-7',
        status: 'Active',
        isActive: true,
        isAcknowledged: false,
        raisedAt: admin.firestore.Timestamp.fromDate(new Date('2026-01-26T10:30:00Z')),
        value: -999.0,
        unit: '%',
        category: 'Sensor',
        priority: 1
      }
    ];

    const batch1 = db.batch();
    activeAlerts.forEach(alert => {
      const docRef = db.collection('alerts_active').doc(alert.id);
      batch1.set(docRef, alert);
    });
    await batch1.commit();
    console.log('✅ Imported', activeAlerts.length, 'active alerts');

    // Import System Status
    console.log('📊 Importing System Status...');
    const systemStatuses = [
      {
        componentName: 'Windows Sync Service',
        status: 'Online',
        lastHeartbeat: admin.firestore.Timestamp.now(),
        version: '1.2.0',
        metadata: {
          uptime: '24:15:30',
          alertsProcessed: 1247,
          syncedToCloud: 1247
        }
      },
      {
        componentName: 'OPC UA Server',
        status: 'Online',
        lastHeartbeat: admin.firestore.Timestamp.now(),
        version: '2.1.5',
        metadata: {
          connectedClients: 3,
          dataPoints: 256,
          updateRate: '1000ms'
        }
      },
      {
        componentName: 'Database Server',
        status: 'Online',
        lastHeartbeat: admin.firestore.Timestamp.now(),
        version: 'SQLite 3.41.0',
        metadata: {
          size: '45.2 MB',
          activeConnections: 2,
          lastBackup: admin.firestore.Timestamp.fromDate(new Date('2026-01-26T02:00:00Z'))
        }
      },
      {
        componentName: 'Alert Engine',
        status: 'Online',
        lastHeartbeat: admin.firestore.Timestamp.now(),
        version: '1.0.3',
        metadata: {
          rulesLoaded: 48,
          alertsGenerated: 127,
          processingTime: '15ms'
        }
      },
      {
        componentName: 'Notification Service',
        status: 'Online',
        lastHeartbeat: admin.firestore.Timestamp.now(),
        version: '1.1.2',
        metadata: {
          notificationsSent: 89,
          fcmTokens: 5,
          deliveryRate: '98.9%'
        }
      }
    ];

    const batch2 = db.batch();
    systemStatuses.forEach(status => {
      const docRef = db.collection('system_status').doc(status.componentName);
      batch2.set(docRef, status);
    });
    await batch2.commit();
    console.log('✅ Imported', systemStatuses.length, 'system components');

    // Import Historical Alerts
    console.log('📊 Importing Historical Alerts...');
    const historyAlerts = [
      {
        id: 'ALT_H001',
        title: 'Motor Overload - Conveyor 1',
        message: 'Motor current exceeded rated capacity',
        severity: 'Critical',
        location: 'Production Line 1',
        equipment: 'Conveyor-1',
        status: 'Cleared',
        isActive: false,
        raisedAt: admin.firestore.Timestamp.fromDate(new Date('2026-01-25T14:00:00Z')),
        clearedAt: admin.firestore.Timestamp.fromDate(new Date('2026-01-25T14:30:00Z')),
        duration: 1800,
        acknowledgedBy: 'operator_sarah',
        category: 'Electrical'
      },
      {
        id: 'ALT_H002',
        title: 'Valve Position Error - V-103',
        message: 'Valve failed to reach commanded position',
        severity: 'Warning',
        location: 'Process Area 2',
        equipment: 'Valve-103',
        status: 'Cleared',
        isActive: false,
        raisedAt: admin.firestore.Timestamp.fromDate(new Date('2026-01-25T16:00:00Z')),
        clearedAt: admin.firestore.Timestamp.fromDate(new Date('2026-01-25T16:15:00Z')),
        duration: 900,
        acknowledgedBy: 'operator_mike',
        category: 'Mechanical'
      }
    ];

    const batch3 = db.batch();
    historyAlerts.forEach(alert => {
      const docRef = db.collection('alerts_history').doc(alert.id);
      batch3.set(docRef, alert);
    });
    await batch3.commit();
    console.log('✅ Imported', historyAlerts.length, 'historical alerts');

    // Create Statistics
    console.log('📊 Creating Statistics...');
    await db.collection('statistics').doc('overview').set({
      totalAlerts: activeAlerts.length,
      criticalAlerts: activeAlerts.filter(a => a.severity === 'Critical').length,
      acknowledgedAlerts: activeAlerts.filter(a => a.isAcknowledged).length,
      totalCleared24h: historyAlerts.length,
      lastUpdated: admin.firestore.Timestamp.now()
    });
    console.log('✅ Statistics created');

    // Create Configuration
    console.log('📊 Creating Configuration...');
    await db.collection('config').doc('sync_settings').set({
      syncInterval: 5000,
      offlineQueueEnabled: true,
      maxOfflineQueueSize: 1000,
      enableNotifications: true,
      notificationSound: true,
      heartbeatInterval: 30000,
      lastUpdated: admin.firestore.Timestamp.now()
    });
    console.log('✅ Configuration created');

    console.log('');
    console.log('✨ Import completed successfully!');
    console.log('');
    console.log('📊 Summary:');
    console.log('  • Active Alerts:', activeAlerts.length);
    console.log('  • System Components:', systemStatuses.length);
    console.log('  • Historical Alerts:', historyAlerts.length);
    console.log('');
    console.log('🌐 View in Firebase Console:');
    console.log('  https://console.firebase.google.com/project/scadadataserver/firestore');
    console.log('');

  } catch (error) {
    console.error('❌ Import failed:', error);
    process.exit(1);
  }
}

// Run import
importData()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
