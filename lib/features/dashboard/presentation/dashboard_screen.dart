import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/summary_card.dart';
import '../../alerts/providers/alert_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final criticalCount = ref.watch(activeCriticalCountProvider);
    final warningCount = ref.watch(activeWarningCountProvider);
    final acknowledgedCount = ref.watch(acknowledgedCountProvider);
    final clearedCount = ref.watch(clearedLast24hCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('SCADA Alarm Monitor'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(activeCriticalCountProvider);
              ref.invalidate(activeWarningCountProvider);
              ref.invalidate(acknowledgedCountProvider);
              ref.invalidate(clearedLast24hCountProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeCriticalCountProvider);
          ref.invalidate(activeWarningCountProvider);
          ref.invalidate(acknowledgedCountProvider);
          ref.invalidate(clearedLast24hCountProvider);
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ALERT SUMMARY',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Color(0xFF9E9E9E),
                      letterSpacing: 1.2,
                    ),
              ),
              SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  SummaryCard(
                    title: 'Critical Alerts',
                    value: criticalCount.when(
                      data: (count) => count.toString(),
                      loading: () => '-',
                      error: (_, __) => '!',
                    ),
                    icon: Icons.error,
                    color: AppTheme.criticalColor,
                  ),
                  SummaryCard(
                    title: 'Warning Alerts',
                    value: warningCount.when(
                      data: (count) => count.toString(),
                      loading: () => '-',
                      error: (_, __) => '!',
                    ),
                    icon: Icons.warning,
                    color: AppTheme.warningColor,
                  ),
                  SummaryCard(
                    title: 'Acknowledged',
                    value: acknowledgedCount.when(
                      data: (count) => count.toString(),
                      loading: () => '-',
                      error: (_, __) => '!',
                    ),
                    icon: Icons.check_circle,
                    color: AppTheme.infoColor,
                  ),
                  SummaryCard(
                    title: 'Cleared (24h)',
                    value: clearedCount.when(
                      data: (count) => count.toString(),
                      loading: () => '-',
                      error: (_, __) => '!',
                    ),
                    icon: Icons.done_all,
                    color: AppTheme.normalColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

