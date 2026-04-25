import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/mock_data.dart';
import '../models/alert_model.dart';

class AlertRepository {
  final FirebaseFirestore? _firestore;
  final bool useMockData;

  AlertRepository({FirebaseFirestore? firestore, this.useMockData = false})
    : _firestore =
          firestore ?? (useMockData ? null : FirebaseFirestore.instance);

  FirebaseFirestore get _requiredFirestore {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firestore is not configured.');
    }
    return firestore;
  }

  /// Streams alerts from the active Firestore collection.
  Stream<List<AlertModel>> watchAllLiveAlerts() {
    if (useMockData) {
      return Stream.value(_sortAlerts(MockData.mockActiveAlerts));
    }

    if (_firestore == null) {
      return Stream.value(const <AlertModel>[]);
    }

    return _requiredFirestore.collection('alerts_active').snapshots().map((
      snapshot,
    ) {
      final alerts = snapshot.docs.map(AlertModel.fromFirestore);
      return _sortAlerts(alerts);
    });
  }

  Stream<List<AlertModel>> watchPendingApprovals() {
    return watchAllLiveAlerts().map((alerts) {
      final pendingAlerts = alerts.where((alert) => alert.isPendingApproval);
      return _sortAlerts(pendingAlerts);
    });
  }

  Stream<AlertModel?> watchAlertById(String alertId) {
    if (useMockData) {
      final alerts = [
        ...MockData.mockActiveAlerts,
        ...MockData.mockHistoryAlerts,
      ];
      for (final alert in alerts) {
        if (alert.id == alertId) {
          return Stream.value(alert);
        }
      }
      return Stream.value(null);
    }

    if (_firestore == null) {
      return Stream.value(null);
    }

    final firestore = _requiredFirestore;

    return Stream<AlertModel?>.multi((controller) {
      AlertModel? activeAlert;
      AlertModel? historyAlert;
      var activeReady = false;
      var historyReady = false;

      void emitBestMatch() {
        if (!activeReady || !historyReady || controller.isClosed) {
          return;
        }
        controller.add(activeAlert ?? historyAlert);
      }

      final activeSubscription = firestore
          .collection('alerts_active')
          .doc(alertId)
          .snapshots()
          .listen((doc) {
            activeAlert = doc.exists ? AlertModel.fromFirestore(doc) : null;
            activeReady = true;
            emitBestMatch();
          }, onError: controller.addError);

      final historySubscription = firestore
          .collection('alerts_history')
          .doc(alertId)
          .snapshots()
          .listen((doc) {
            historyAlert = doc.exists ? AlertModel.fromFirestore(doc) : null;
            historyReady = true;
            emitBestMatch();
          }, onError: controller.addError);

      controller.onCancel = () async {
        await activeSubscription.cancel();
        await historySubscription.cancel();
      };
    }, isBroadcast: true);
  }

  List<AlertModel> _sortAlerts(Iterable<AlertModel> alerts) {
    final sorted = alerts.toList()
      ..sort((a, b) => b.raisedAt.compareTo(a.raisedAt));
    return sorted;
  }

  Future<List<AlertModel>> getAlertHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? severity,
    int limit = 100,
    DocumentSnapshot? lastDocument,
  }) async {
    if (useMockData || _firestore == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      var filtered = MockData.mockHistoryAlerts;
      if (severity != null && severity.isNotEmpty) {
        filtered = filtered
            .where((a) => a.severity.toLowerCase() == severity.toLowerCase())
            .toList();
      }
      return filtered;
    }

    final fetchLimit = limit;
    Query firestoreQuery = _requiredFirestore.collection('alerts_history');

    if (severity != null && severity.isNotEmpty) {
      firestoreQuery = firestoreQuery.where(
        'severity',
        isEqualTo: severity.toLowerCase(),
      );
    }

    // Map the dates to Firestore Timestamps for the query using the indexed 'timestamp' field
    if (startDate != null) {
      firestoreQuery = firestoreQuery.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      firestoreQuery = firestoreQuery.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    firestoreQuery = firestoreQuery
        .orderBy('timestamp', descending: true)
        .limit(fetchLimit);

    if (lastDocument != null) {
      firestoreQuery = firestoreQuery.startAfterDocument(lastDocument);
    }

    final firestoreSnapshot = await firestoreQuery.get();
    var alerts = firestoreSnapshot.docs
        .map((doc) => AlertModel.fromFirestore(doc))
        .toList();

    return alerts;
  }

  Future<void> acknowledgeAlert(
    String alertId,
    String acknowledgedBy, {
    String? comment,
  }) async {
    if (_firestore == null) {
      return;
    }

    final updateDataFirestore = {
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

    await _requiredFirestore
        .collection('alerts_active')
        .doc(alertId)
        .update(updateDataFirestore);
  }

  Future<void> approveAlert(String alertId, String approvedBy) async {
    if (_firestore == null) {
      return;
    }

    final now = DateTime.now();
    final firestore = _requiredFirestore;

    AlertModel? alert;
    var doc = await firestore.collection('alerts_active').doc(alertId).get();
    if (doc.exists) {
      alert = AlertModel.fromFirestore(doc);
    } else {
      doc = await firestore.collection('alerts_history').doc(alertId).get();
      if (doc.exists) {
        alert = AlertModel.fromFirestore(doc);
      }
    }

    if (alert == null) return;

    final updatedAlert = alert.copyWith(
      status: 'approved',
      approvalStatus: 'approved',
      approvedBy: approvedBy,
      approvedAt: now,
      isActive: false,
      clearedAt: alert.clearedAt ?? now,
      lastUpdatedTime: now,
    );

    final batch = firestore.batch();
    batch.set(
      firestore.collection('alerts_history').doc(alertId),
      updatedAlert.toFirestore(),
    );
    batch.delete(firestore.collection('alerts_active').doc(alertId));
    await batch.commit();
  }

  Future<void> rejectAlert(
    String alertId,
    String rejectedBy,
    String reason,
  ) async {
    if (_firestore == null) {
      return;
    }

    final now = DateTime.now();
    final firestore = _requiredFirestore;

    AlertModel? alert;
    final doc = await firestore.collection('alerts_active').doc(alertId).get();
    if (doc.exists) {
      alert = AlertModel.fromFirestore(doc);
    }

    if (alert == null) return;

    final updatedAlert = alert.copyWith(
      status: 'rejected',
      approvalStatus: 'rejected',
      rejectedBy: rejectedBy,
      rejectedAt: now,
      rejectionReason: reason,
      isActive: false,
      clearedAt: alert.clearedAt ?? now,
      lastUpdatedTime: now,
    );

    final batch = firestore.batch();
    batch.set(
      firestore.collection('alerts_history').doc(alertId),
      updatedAlert.toFirestore(),
    );
    batch.delete(firestore.collection('alerts_active').doc(alertId));
    await batch.commit();
  }

  Future<void> clearAlert(String alertId) async {
    if (_firestore == null) {
      return;
    }

    final now = DateTime.now();
    final firestore = _requiredFirestore;

    AlertModel? alert;
    final doc = await firestore.collection('alerts_active').doc(alertId).get();
    if (doc.exists) {
      alert = AlertModel.fromFirestore(doc);
    }

    if (alert == null) return;

    final updatedAlert = alert.copyWith(
      status: 'cleared',
      approvalStatus: alert.effectiveApprovalStatusKey == 'rejected'
          ? 'rejected'
          : 'approved',
      isActive: false,
      clearedAt: now,
      lastUpdatedTime: now,
    );

    final batch = firestore.batch();
    batch.set(
      firestore.collection('alerts_history').doc(alertId),
      updatedAlert.toFirestore(),
    );
    batch.delete(firestore.collection('alerts_active').doc(alertId));
    await batch.commit();
  }

  Future<int> getActiveAlertCount({String? severity}) async {
    if (useMockData || _firestore == null) {
      if (severity == null) return MockData.mockActiveAlerts.length;
      final normalizedSeverity = severity.toLowerCase();
      return MockData.mockActiveAlerts
          .where((a) => a.severityBucket == normalizedSeverity)
          .length;
    }

    try {
      Query query = _requiredFirestore.collection('alerts_active');
      if (severity != null) {
        query = query.where('severity', isEqualTo: severity.toLowerCase());
      }
      final aggregateQuery = query.count();
      final snapshot = await aggregateQuery.get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getAcknowledgedCount() async {
    if (useMockData || _firestore == null) {
      return MockData.mockActiveAlerts.where((a) => a.isAcknowledged).length;
    }

    try {
      final aggregateQuery = _requiredFirestore
          .collection('alerts_active')
          .where('acknowledged', isEqualTo: true)
          .count();
      final snapshot = await aggregateQuery.get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getClearedLast24Hours() async {
    if (useMockData || _firestore == null) {
      return MockData.mockHistoryAlerts.length;
    }

    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final aggregateQuery = _requiredFirestore
          .collection('alerts_history')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday),
          )
          .count();
      final snapshot = await aggregateQuery.get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getHistoryAlertCount() async {
    if (useMockData || _firestore == null) {
      return MockData.mockHistoryAlerts.length;
    }

    try {
      final aggregateQuery = _requiredFirestore
          .collection('alerts_history')
          .count();
      final snapshot = await aggregateQuery.get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
