import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/alert_model.dart';
import '../../../data/repositories/alert_repository.dart';

class DashboardLiveCounts {
  final int critical;
  final int warning;
  final int pendingApprovals;

  const DashboardLiveCounts({
    required this.critical,
    required this.warning,
    required this.pendingApprovals,
  });
}

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepository(firestore: FirebaseFirestore.instance);
});

final allLiveAlertsProvider = StreamProvider<List<AlertModel>>((ref) {
  final repository = ref.watch(alertRepositoryProvider);
  return repository.watchAllLiveAlerts();
});

final activeAlertsProvider = StreamProvider<List<AlertModel>>((ref) {
  final allLiveAsync = ref.watch(allLiveAlertsProvider);
  return allLiveAsync.when(
    data: (alerts) => Stream.value(alerts),
    loading: () => const Stream.empty(),
    error: (err, stack) => Stream.error(err, stack),
  );
});

final pendingApprovalAlertsProvider = StreamProvider<List<AlertModel>>((ref) {
  final allLiveAsync = ref.watch(allLiveAlertsProvider);
  return allLiveAsync.when(
    data: (alerts) =>
        Stream.value(alerts.where((a) => a.isPendingApproval).toList()),
    loading: () => const Stream.empty(),
    error: (err, stack) => Stream.error(err, stack),
  );
});

final criticalAlertsProvider = Provider<AsyncValue<List<AlertModel>>>((ref) {
  final activeAlertsAsync = ref.watch(activeAlertsProvider);
  return activeAlertsAsync.whenData(
    (alerts) => alerts.where((a) => a.isCriticalSeverity).toList(),
  );
});

final warningAlertsProvider = Provider<AsyncValue<List<AlertModel>>>((ref) {
  final activeAlertsAsync = ref.watch(activeAlertsProvider);
  return activeAlertsAsync.whenData(
    (alerts) => alerts.where((a) => a.isWarningSeverity).toList(),
  );
});

final alertByIdProvider = StreamProvider.family<AlertModel?, String>((
  ref,
  alertId,
) {
  final repository = ref.watch(alertRepositoryProvider);
  return repository.watchAlertById(alertId);
});

final dashboardLiveCountsProvider =
    Provider<AsyncValue<DashboardLiveCounts>>((ref) {
      final allLiveAsync = ref.watch(allLiveAlertsProvider);
      return allLiveAsync.whenData((alerts) {
        var critical = 0;
        var warning = 0;
        var pendingApprovals = 0;

        for (final alert in alerts) {
          if (alert.isCriticalSeverity) {
            critical++;
          } else if (alert.isWarningSeverity) {
            warning++;
          }

          if (alert.isPendingApproval) {
            pendingApprovals++;
          }
        }

        return DashboardLiveCounts(
          critical: critical,
          warning: warning,
          pendingApprovals: pendingApprovals,
        );
      });
    });

final activeCriticalCountProvider = Provider<AsyncValue<int>>((ref) {
  final activeAlertsAsync = ref.watch(activeAlertsProvider);
  return activeAlertsAsync.whenData(
    (alerts) => alerts.where((a) => a.isCriticalSeverity).length,
  );
});

final activeWarningCountProvider = Provider<AsyncValue<int>>((ref) {
  final activeAlertsAsync = ref.watch(activeAlertsProvider);
  return activeAlertsAsync.whenData(
    (alerts) => alerts.where((a) => a.isWarningSeverity).length,
  );
});

final acknowledgedCountProvider = Provider<AsyncValue<int>>((ref) {
  final allLiveAsync = ref.watch(allLiveAlertsProvider);
  return allLiveAsync.whenData(
    (alerts) => alerts.where((a) => a.isAcknowledged).length,
  );
});

final pendingApprovalsCountProvider = Provider<AsyncValue<int>>((ref) {
  final allLiveAsync = ref.watch(allLiveAlertsProvider);
  return allLiveAsync.whenData(
    (alerts) => alerts.where((a) => a.isPendingApproval).length,
  );
});

final clearedLast24hCountProvider = FutureProvider<int>((ref) {
  final repository = ref.watch(alertRepositoryProvider);
  return repository.getClearedLast24Hours();
});

final historicalAlertsCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(alertRepositoryProvider);
  return repository.getHistoryAlertCount();
});
