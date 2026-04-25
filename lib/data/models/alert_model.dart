import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'alert_model.freezed.dart';
part 'alert_model.g.dart';

@freezed
class AlertModel with _$AlertModel {
  const AlertModel._();

  const factory AlertModel({
    required String id,
    required String name,
    required String description,
    required String severity,
    required String source,
    required String tagName,
    required double currentValue,
    required double threshold,
    required String condition,
    required DateTime raisedAt,
    DateTime? acknowledgedAt,
    String? acknowledgedBy,
    String? acknowledgedComment,
    DateTime? clearedAt,
    DateTime? escalatedAt,
    required bool isActive,
    required bool isAcknowledged,
    required bool isSuppressed,
    String? notes,
    @Default(0) int escalationLevel,
    @Default(0) int suppressionCount,
    @Default([]) List<String> relatedAlertIds,
    @Default([]) List<Map<String, dynamic>> trendData,

    // Diagnostic additions for Deep Analysis
    String? alertType,
    @Default(0) int escalationCount,
    DateTime? lastUpdatedTime,
    String? equipment,
    String? location,

    // Approval/Rejection Workflow
    @Default('active') String status,
    @Default('pending')
    String approvalStatus, // 'pending', 'approved', 'rejected'
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? rejectionReason,
  }) = _AlertModel;

  factory AlertModel.fromJson(Map<String, dynamic> json) =>
      _$AlertModelFromJson(json);

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertModel.fromMap(data, id: doc.id);
  }

  factory AlertModel.fromMap(Map<dynamic, dynamic> data, {required String id}) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    String normalizeState(dynamic value) {
      return value?.toString().trim().toLowerCase() ?? '';
    }

    // Standardized mapping following the canonical Firestore schema
    final name = data['name'] ?? data['title'] ?? 'SCADA Alarm';
    final description = data['description'] ?? data['message'] ?? '';
    final tagName = data['tagName'] ?? data['nodeId'] ?? 'N/A';
    final severity = normalizeState(data['severity']).isNotEmpty
        ? normalizeState(data['severity'])
        : 'info';
    final statusLower = normalizeState(data['status']);
    final acknowledgedFlag = data['isAcknowledged'] is bool
        ? data['isAcknowledged'] as bool
        : data['acknowledged'] == true;
    final approvalStatusLower = normalizeState(data['approvalStatus']);
    final isActiveFlag = data['isActive'] is bool
        ? data['isActive'] as bool
        : <String>{'active', 'open', 'acknowledged'}.contains(statusLower);

    final normalizedStatus = statusLower.isNotEmpty
        ? statusLower
        : approvalStatusLower == 'approved'
            ? 'approved'
            : approvalStatusLower == 'rejected'
                ? 'rejected'
                : acknowledgedFlag
                    ? 'acknowledged'
                    : isActiveFlag
                        ? 'active'
                        : (data['clearedAt'] != null ||
                                data['clearedTime'] != null)
                            ? 'cleared'
                            : 'active';

    final normalizedApprovalStatus = approvalStatusLower.isNotEmpty
        ? approvalStatusLower
        : normalizedStatus == 'rejected'
            ? 'rejected'
            : normalizedStatus == 'approved' || normalizedStatus == 'cleared'
                ? 'approved'
                : 'pending';

    return AlertModel(
      id: id,
      name: name,
      description: description,
      severity: severity,
      source: data['source'] ?? data['equipment'] ?? 'Unknown',
      tagName: tagName,
      currentValue: parseDouble(data['currentValue'] ?? data['value']),
      threshold: parseDouble(data['threshold']),
      condition: data['condition'] ?? data['alertType'] ?? statusLower,
      raisedAt: _parseTimestamp(data['raisedAt'] ?? data['timestamp']) ??
          DateTime.now(),
      acknowledgedAt: _parseTimestamp(data['acknowledgedAt']),
      acknowledgedBy: data['acknowledgedBy'],
      acknowledgedComment: data['acknowledgedComment'],
      clearedAt: _parseTimestamp(data['clearedAt'] ?? data['clearedTime']),
      escalatedAt: _parseTimestamp(data['escalatedAt']),
      isActive: isActiveFlag,
      isAcknowledged: acknowledgedFlag,
      isSuppressed: data['isSuppressed'] ?? false,
      notes: data['notes'],
      escalationLevel: data['escalationLevel'] ?? data['priority'] ?? 0,
      suppressionCount: data['suppressionCount'] ?? 0,
      relatedAlertIds: List<String>.from(data['relatedAlertIds'] ?? []),
      trendData: List<Map<String, dynamic>>.from(data['trendData'] ?? []),
      alertType: data['alertType'] ?? data['condition'],
      escalationCount: data['escalationCount'] ?? 0,
      lastUpdatedTime: _parseTimestamp(data['lastUpdatedTime']),
      equipment: data['equipment'] ?? data['source'],
      location: data['location'],
      status: normalizedStatus,
      approvalStatus: normalizedApprovalStatus,
      approvedBy: data['approvedBy'],
      approvedAt: _parseTimestamp(data['approvedAt']),
      rejectedBy: data['rejectedBy'],
      rejectedAt: _parseTimestamp(data['rejectedAt']),
      rejectionReason: data['rejectionReason'],
    );
  }

  static DateTime? _parseTimestamp(dynamic ts) {
    if (ts == null) return null;
    if (ts is Timestamp) return ts.toDate();
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    if (ts is num) {
      return DateTime.fromMillisecondsSinceEpoch(ts.toInt(), isUtc: true);
    }
    if (ts is String) return DateTime.tryParse(ts);
    return null;
  }

  bool get isCriticalSeverity {
    final normalized = severity.toLowerCase();
    return normalized == 'critical' || normalized == 'high';
  }

  bool get isWarningSeverity {
    final normalized = severity.toLowerCase();
    return normalized == 'warning' || normalized == 'medium';
  }

  String get statusKey => status.toLowerCase();

  String get approvalStatusKey => approvalStatus.toLowerCase();

  String get effectiveApprovalStatusKey {
    if (approvalStatusKey == 'approved' || approvalStatusKey == 'rejected') {
      return approvalStatusKey;
    }

    switch (statusKey) {
      case 'approved':
      case 'cleared':
        return 'approved';
      case 'rejected':
        return 'rejected';
      default:
        return 'pending';
    }
  }

  bool get isResolved {
    return !isActive ||
        statusKey == 'approved' ||
        statusKey == 'rejected' ||
        statusKey == 'cleared' ||
        effectiveApprovalStatusKey == 'approved' ||
        effectiveApprovalStatusKey == 'rejected';
  }

  String get severityBucket {
    if (isCriticalSeverity) return 'critical';
    if (isWarningSeverity) return 'warning';
    return 'info';
  }

  DateTime get historySortTime {
    return clearedAt ?? approvedAt ?? rejectedAt ?? lastUpdatedTime ?? raisedAt;
  }

  String get statusLabel {
    switch (statusKey) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'cleared':
        return 'Cleared';
      case 'acknowledged':
        return 'Acknowledged';
      default:
        return 'Active';
    }
  }

  bool get isPendingApproval {
    return isActive &&
        isAcknowledged &&
        effectiveApprovalStatusKey == 'pending' &&
        !isResolved;
  }

  bool get isLiveActive {
    return isActive && statusKey == 'active' && !isAcknowledged;
  }

  Map<String, dynamic> toFirestore() {
    final raisedTimestamp = Timestamp.fromDate(raisedAt);
    final acknowledgedTimestamp = acknowledgedAt != null
        ? Timestamp.fromDate(acknowledgedAt!)
        : null;
    final clearedTimestamp = clearedAt != null
        ? Timestamp.fromDate(clearedAt!)
        : null;
    final escalatedTimestamp = escalatedAt != null
        ? Timestamp.fromDate(escalatedAt!)
        : null;
    final approvedTimestamp = approvedAt != null
        ? Timestamp.fromDate(approvedAt!)
        : null;
    final rejectedTimestamp = rejectedAt != null
        ? Timestamp.fromDate(rejectedAt!)
        : null;
    final updatedTimestamp = Timestamp.fromDate(
      lastUpdatedTime ??
          clearedAt ??
          approvedAt ??
          rejectedAt ??
          acknowledgedAt ??
          raisedAt,
    );

    return {
      'id': id,
      'alertId': id,
      'name': name,
      'alert': name,
      'description': description,
      'detail': description,
      'message': description,
      'severity': severity.toLowerCase(),
      'source': source,
      'tagName': tagName,
      'nodeId': tagName,
      'currentValue': currentValue,
      'triggerValue': currentValue,
      'threshold': threshold,
      'condition': condition,
      'raisedAt': raisedTimestamp,
      'timestamp': raisedTimestamp,
      'acknowledgedAt': acknowledgedTimestamp,
      'acknowledgedBy': acknowledgedBy,
      'acknowledged_by': acknowledgedBy,
      'acknowledgedComment': acknowledgedComment,
      'acknowledgement_detail': acknowledgedComment,
      'clearedAt': clearedTimestamp,
      'clearedTime': clearedTimestamp,
      'escalatedAt': escalatedTimestamp,
      'isActive': isActive,
      'isAcknowledged': isAcknowledged,
      'acknowledged': isAcknowledged,
      'isSuppressed': isSuppressed,
      'notes': notes,
      'escalationLevel': escalationLevel,
      'suppressionCount': suppressionCount,
      'relatedAlertIds': relatedAlertIds,
      'trendData': trendData,
      'alertType': alertType,
      'escalationCount': escalationCount,
      'lastUpdatedTime': updatedTimestamp,
      'updated_at': updatedTimestamp,
      'created_at': raisedTimestamp,
      'equipment': equipment,
      'location': location,
      'status': statusKey,
      'approvalStatus': effectiveApprovalStatusKey,
      'approvedBy': approvedBy,
      'approvedAt': approvedTimestamp,
      'rejectedBy': rejectedBy,
      'rejectedAt': rejectedTimestamp,
      'rejectionReason': rejectionReason,
    };
  }

  String get timeSinceRaised {
    final duration = DateTime.now().difference(raisedAt);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  int get sortPriority {
    int severityPriority;
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        severityPriority = 1000;
        break;
      case 'warning':
      case 'medium':
        severityPriority = 500;
        break;
      case 'info':
      case 'low':
        severityPriority = 100;
        break;
      default:
        severityPriority = 0;
    }

    return severityPriority + (isAcknowledged ? 0 : 10000);
  }
}
