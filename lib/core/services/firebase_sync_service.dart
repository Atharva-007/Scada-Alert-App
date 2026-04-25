import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/models/alert_model.dart';

class FirebaseSyncService {
  final FirebaseFirestore _firestore;
  final Connectivity _connectivity = Connectivity();

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  String get _clientPlatform {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String get _heartbeatDocumentId => '${_clientPlatform}_client';

  StreamSubscription? _connectivitySubscription;
  Timer? _heartbeatTimer;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  FirebaseSyncService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> initialize() async {
    debugPrint('🔄 Initializing Firebase Sync Service...');

    // Check initial connectivity
    await _checkConnectivity();

    // Monitor connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    // Start heartbeat
    _startHeartbeat();

    debugPrint('✅ Firebase Sync Service initialized');
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    _updateSyncStatus();
  }

  void _handleConnectivityChange(dynamic results) {
    // Cast to List<ConnectivityResult> safely for Web/Mobile compatibility
    final List<ConnectivityResult> connectivityResults = results is List
        ? List<ConnectivityResult>.from(results)
        : [ConnectivityResult.none];

    final wasOnline = _isOnline;
    _isOnline = !connectivityResults.contains(ConnectivityResult.none);

    if (!wasOnline && _isOnline) {
      _updateSyncStatus(message: 'Connected to network - syncing data...');
      _performFullSync();
    } else if (wasOnline && !_isOnline) {
      _updateSyncStatus(
        message: 'Network disconnected - switching to offline mode',
      );
    }

    _updateSyncStatus();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_isOnline) {
        await _sendHeartbeat();
      }
    });
  }

  Future<void> _sendHeartbeat() async {
    try {
      await _firestore
          .collection('client_heartbeats')
          .doc(_heartbeatDocumentId)
          .set({
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'online',
            'version': '1.2.0',
            'platform': _clientPlatform,
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Heartbeat error: $e');
      _isOnline = false;
      _updateSyncStatus();
    }
  }

  Future<void> _performFullSync() async {
    if (!_isOnline) return;

    try {
      _updateSyncStatus(message: 'Starting full sync...');

      // Sync active alerts
      await _syncActiveAlerts();

      _updateSyncStatus(message: 'Full sync completed');
    } catch (e) {
      _updateSyncStatus(message: 'Sync error: $e');
    }
  }

  Future<void> _syncActiveAlerts() async {
    final snapshot = await _firestore.collection('alerts_active').get();

    final activeCount = snapshot.docs.map(AlertModel.fromFirestore).length;

    _updateSyncStatus(message: 'Synced $activeCount active alerts');
  }

  Stream<List<AlertModel>> watchActiveAlerts() {
    return _firestore.collection('alerts_active').snapshots().map((snapshot) {
      return snapshot.docs.map(AlertModel.fromFirestore).toList()
        ..sort((a, b) => b.sortPriority.compareTo(a.sortPriority));
    });
  }

  Future<void> acknowledgeAlert(
    String alertId,
    String acknowledgedBy, {
    String? comment,
  }) async {
    final updateData = {
      'status': 'acknowledged',
      'approvalStatus': 'pending',
      'isAcknowledged': true,
      'acknowledged': true,
      'acknowledgedAt': FieldValue.serverTimestamp(),
      'acknowledgedBy': acknowledgedBy,
      'acknowledged_by': acknowledgedBy,
      'acknowledgedComment': comment,
      'acknowledgement_detail': comment,
      'lastUpdatedTime': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('alerts_active')
        .doc(alertId)
        .update(updateData);

    // Log acknowledgment
    await _firestore.collection('acknowledgment_logs').add({
      'alertId': alertId,
      'acknowledgedBy': acknowledgedBy,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> syncAlertToHistory(AlertModel alert) async {
    final normalizedAlert = alert.copyWith(
      isActive: false,
      lastUpdatedTime: DateTime.now(),
    );

    await _firestore
        .collection('alerts_history')
        .doc(alert.id)
        .set(normalizedAlert.toFirestore(), SetOptions(merge: true));
    await _firestore.collection('alerts_active').doc(alert.id).delete();
  }

  Future<Map<String, int>> getAlertStatistics() async {
    final activeSnapshot = await _firestore.collection('alerts_active').get();
    final alerts = activeSnapshot.docs.map(AlertModel.fromFirestore).toList();

    return {
      'total': alerts.length,
      'critical': alerts.where((alert) => alert.isCriticalSeverity).length,
      'acknowledged': alerts.where((alert) => alert.isAcknowledged).length,
    };
  }

  void _updateSyncStatus({String? message}) {
    _syncStatusController.add(
      SyncStatus(
        isOnline: _isOnline,
        lastSync: DateTime.now(),
        message: message,
      ),
    );
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _heartbeatTimer?.cancel();
    _syncStatusController.close();
  }
}

class SyncStatus {
  final bool isOnline;
  final DateTime lastSync;
  final String? message;

  SyncStatus({required this.isOnline, required this.lastSync, this.message});

  @override
  String toString() {
    return 'SyncStatus(online: $isOnline, lastSync: $lastSync, message: $message)';
  }
}
