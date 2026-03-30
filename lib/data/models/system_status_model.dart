import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_status_model.freezed.dart';
part 'system_status_model.g.dart';

@freezed
class SystemStatusModel with _$SystemStatusModel {
  const factory SystemStatusModel({
    required String componentName,
    required String status,
    required DateTime lastHeartbeat,
    String? version,
    Map<String, dynamic>? metadata,
  }) = _SystemStatusModel;

  factory SystemStatusModel.fromJson(Map<String, dynamic> json) =>
      _$SystemStatusModelFromJson(json);

  factory SystemStatusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SystemStatusModel(
      componentName: data['componentName'] ?? '',
      status: data['status'] ?? 'unknown',
      lastHeartbeat: (data['lastHeartbeat'] as Timestamp).toDate(),
      version: data['version'],
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
    );
  }
}

@freezed
class DashboardSummary with _$DashboardSummary {
  const factory DashboardSummary({
    required int activeCritical,
    required int activeWarning,
    required int acknowledgedCount,
    required int clearedLast24h,
    required List<SystemStatusModel> systemStatuses,
  }) = _DashboardSummary;
}
