import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../alerts/providers/alert_providers.dart';
import '../../dashboard/providers/statistics_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAlertsAsync = ref.watch(activeAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics & Reports'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(activeAlertsProvider);
            },
          ),
        ],
      ),
      body: activeAlertsAsync.when(
        data: (alerts) {
          final stats = AlertStatistics.fromAlerts(alerts);
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCards(context, stats),
                SizedBox(height: 24),
                _buildPerformanceMetrics(context, stats),
                SizedBox(height: 24),
                _buildSourceBreakdown(context, stats),
                SizedBox(height: 24),
                _buildTrendChart(context, stats),
                SizedBox(height: 80),
              ],
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.criticalColor),
              SizedBox(height: 16),
              Text('Error loading analytics'),
              SizedBox(height: 8),
              Text(error.toString(), style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context, AlertStatistics stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OVERVIEW',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Color(0xFF9E9E9E),
                letterSpacing: 1.2,
              ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total',
                value: stats.totalAlerts.toString(),
                icon: Icons.notifications,
                color: AppTheme.infoColor,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Critical',
                value: stats.criticalCount.toString(),
                icon: Icons.error,
                color: AppTheme.criticalColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Warning',
                value: stats.warningCount.toString(),
                icon: Icons.warning,
                color: AppTheme.warningColor,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Info',
                value: stats.infoCount.toString(),
                icon: Icons.info,
                color: Color(0xFF42A5F5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceMetrics(BuildContext context, AlertStatistics stats) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF3F3F3F), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppTheme.infoColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Performance Metrics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildMetricRow(
            'Acknowledgment Rate',
            '${stats.acknowledgmentRate.toStringAsFixed(1)}%',
            stats.acknowledgmentRate >= 90
                ? AppTheme.normalColor
                : stats.acknowledgmentRate >= 70
                    ? AppTheme.warningColor
                    : AppTheme.criticalColor,
          ),
          SizedBox(height: 12),
          _buildMetricRow(
            'Average Response Time',
            _formatDuration(stats.averageResponseTime),
            AppTheme.infoColor,
          ),
          SizedBox(height: 12),
          _buildMetricRow(
            'Unacknowledged Alerts',
            stats.unacknowledgedCount.toString(),
            stats.unacknowledgedCount > 0
                ? AppTheme.warningColor
                : AppTheme.normalColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBreakdown(BuildContext context, AlertStatistics stats) {
    if (stats.alertsBySource.isEmpty) {
      return SizedBox.shrink();
    }

    final sortedSources = stats.alertsBySource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF3F3F3F), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.source, color: AppTheme.infoColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Alerts by Source',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...sortedSources.take(5).map((entry) {
            final percentage = (entry.value / stats.totalAlerts) * 100;
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 6,
                      backgroundColor: AppTheme.surfaceVariantDark,
                      valueColor: AlwaysStoppedAnimation(AppTheme.infoColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTrendChart(BuildContext context, AlertStatistics stats) {
    if (stats.hourlyTrends.isEmpty) {
      return SizedBox.shrink();
    }

    final maxCount = stats.hourlyTrends
        .map((t) => t.count)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF3F3F3F), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: AppTheme.infoColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Alert Trend (24 Hours)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: stats.hourlyTrends.map((trend) {
                final height = maxCount > 0 ? (trend.count / maxCount) * 100.0 : 0.0;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 1),
                    height: height,
                    decoration: BoxDecoration(
                      color: trend.count > 0
                          ? AppTheme.infoColor.withOpacity(0.8)
                          : AppTheme.surfaceVariantDark,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Last 24 hours',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFFB0B0B0),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    } else {
      return '${d.inSeconds}s';
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9E9E9E),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
