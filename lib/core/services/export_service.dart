import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../data/models/alert_model.dart';

class ExportService {
  
  /// Export alerts to CSV format
  String exportToCSV(List<AlertModel> alerts) {
    final buffer = StringBuffer();
    
    // CSV Header
    buffer.writeln(
      'ID,Name,Description,Severity,Source,Tag Name,Current Value,Threshold,'
      'Condition,Raised At,Acknowledged,Acknowledged By,Acknowledged At,'
      'Acknowledged Comment,Cleared At,Is Active,Escalation Level'
    );

    // CSV Rows
    for (final alert in alerts) {
      buffer.writeln([
        _csvEscape(alert.id),
        _csvEscape(alert.name),
        _csvEscape(alert.description),
        _csvEscape(alert.severity),
        _csvEscape(alert.source),
        _csvEscape(alert.tagName),
        alert.currentValue.toStringAsFixed(2),
        alert.threshold.toStringAsFixed(2),
        _csvEscape(alert.condition),
        alert.raisedAt.toIso8601String(),
        alert.isAcknowledged ? 'Yes' : 'No',
        _csvEscape(alert.acknowledgedBy ?? ''),
        alert.acknowledgedAt?.toIso8601String() ?? '',
        _csvEscape(alert.acknowledgedComment ?? ''),
        alert.clearedAt?.toIso8601String() ?? '',
        alert.isActive ? 'Yes' : 'No',
        alert.escalationLevel.toString(),
      ].join(','));
    }

    return buffer.toString();
  }

  /// Export alerts to JSON format
  String exportToJSON(List<AlertModel> alerts) {
    final jsonList = alerts.map((alert) => alert.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  /// Generate shift report
  String generateShiftReport({
    required List<AlertModel> activeAlerts,
    required List<AlertModel> clearedAlerts,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    required String operatorName,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('         SCADA ALARM SYSTEM - SHIFT REPORT');
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('Operator: $operatorName');
    buffer.writeln('Shift Start: ${_formatDateTime(shiftStart)}');
    buffer.writeln('Shift End: ${_formatDateTime(shiftEnd)}');
    buffer.writeln('Duration: ${_formatDuration(shiftEnd.difference(shiftStart))}');
    buffer.writeln('');
    buffer.writeln('───────────────────────────────────────────────────────');
    buffer.writeln('SUMMARY');
    buffer.writeln('───────────────────────────────────────────────────────');
    buffer.writeln('');
    
    final totalAlerts = activeAlerts.length + clearedAlerts.length;
    final criticalCount = [...activeAlerts, ...clearedAlerts]
        .where((a) => a.severity == 'critical')
        .length;
    final warningCount = [...activeAlerts, ...clearedAlerts]
        .where((a) => a.severity == 'warning')
        .length;
    final acknowledgedCount = [...activeAlerts, ...clearedAlerts]
        .where((a) => a.isAcknowledged)
        .length;
    
    buffer.writeln('Total Alerts: $totalAlerts');
    buffer.writeln('  - Critical: $criticalCount');
    buffer.writeln('  - Warning: $warningCount');
    buffer.writeln('  - Info: ${totalAlerts - criticalCount - warningCount}');
    buffer.writeln('');
    buffer.writeln('Active Alerts: ${activeAlerts.length}');
    buffer.writeln('Cleared Alerts: ${clearedAlerts.length}');
    buffer.writeln('Acknowledged: $acknowledgedCount');
    buffer.writeln('');
    
    if (activeAlerts.isNotEmpty) {
      buffer.writeln('───────────────────────────────────────────────────────');
      buffer.writeln('OUTSTANDING ALERTS (Requires Attention)');
      buffer.writeln('───────────────────────────────────────────────────────');
      buffer.writeln('');
      
      final sortedActive = List<AlertModel>.from(activeAlerts)
        ..sort((a, b) => b.sortPriority.compareTo(a.sortPriority));
      
      for (int i = 0; i < sortedActive.length; i++) {
        final alert = sortedActive[i];
        buffer.writeln('${i + 1}. ${alert.name}');
        buffer.writeln('   Severity: ${alert.severity.toUpperCase()}');
        buffer.writeln('   Source: ${alert.source}');
        buffer.writeln('   Tag: ${alert.tagName}');
        buffer.writeln('   Raised: ${_formatDateTime(alert.raisedAt)}');
        buffer.writeln('   Status: ${alert.isAcknowledged ? "Acknowledged" : "UNACKNOWLEDGED"}');
        if (alert.acknowledgedBy != null) {
          buffer.writeln('   Acknowledged by: ${alert.acknowledgedBy}');
        }
        buffer.writeln('');
      }
    }
    
    if (clearedAlerts.isNotEmpty) {
      buffer.writeln('───────────────────────────────────────────────────────');
      buffer.writeln('CLEARED ALERTS (This Shift)');
      buffer.writeln('───────────────────────────────────────────────────────');
      buffer.writeln('');
      
      for (int i = 0; i < clearedAlerts.length; i++) {
        final alert = clearedAlerts[i];
        buffer.writeln('${i + 1}. ${alert.name}');
        buffer.writeln('   Source: ${alert.source}');
        buffer.writeln('   Raised: ${_formatDateTime(alert.raisedAt)}');
        if (alert.clearedAt != null) {
          buffer.writeln('   Cleared: ${_formatDateTime(alert.clearedAt!)}');
          final duration = alert.clearedAt!.difference(alert.raisedAt);
          buffer.writeln('   Duration: ${_formatDuration(duration)}');
        }
        buffer.writeln('');
      }
    }
    
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('           END OF SHIFT REPORT');
    buffer.writeln('═══════════════════════════════════════════════════════');
    
    return buffer.toString();
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    return '${hours}h ${minutes}m ${seconds}s';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
