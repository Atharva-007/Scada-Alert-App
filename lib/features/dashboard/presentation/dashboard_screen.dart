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
      backgroundColor: const Color(0xFF0F0F0F),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeCriticalCountProvider);
          ref.invalidate(activeWarningCountProvider);
          ref.invalidate(acknowledgedCountProvider);
          ref.invalidate(clearedLast24hCountProvider);
          // Add a small delay for UX so it doesn't instantly snap back
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              backgroundColor: const Color(0xFF0F0F0F),
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: const Text(
                  'SCADA Monitor',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.infoColor.withOpacity(0.1),
                            const Color(0xFF0F0F0F),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh',
                    onPressed: () {
                      ref.invalidate(activeCriticalCountProvider);
                      ref.invalidate(activeWarningCountProvider);
                      ref.invalidate(acknowledgedCountProvider);
                      ref.invalidate(clearedLast24hCountProvider);
                    },
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 18, color: AppTheme.infoColor),
                      const SizedBox(width: 8),
                      Text(
                        'SYSTEM OVERVIEW',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppTheme.infoColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      SummaryCard(
                        title: 'Critical Active',
                        subtitle: 'Requires immediate action',
                        value: criticalCount.when(
                          data: (count) => count.toString(),
                          loading: () => '-',
                          error: (_, __) => '!',
                        ),
                        icon: Icons.error_outline,
                        color: AppTheme.criticalColor,
                      ),
                      SummaryCard(
                        title: 'Warnings',
                        subtitle: 'Needs attention',
                        value: warningCount.when(
                          data: (count) => count.toString(),
                          loading: () => '-',
                          error: (_, __) => '!',
                        ),
                        icon: Icons.warning_amber_rounded,
                        color: AppTheme.warningColor,
                      ),
                      SummaryCard(
                        title: 'Acknowledged',
                        subtitle: 'Being investigated',
                        value: acknowledgedCount.when(
                          data: (count) => count.toString(),
                          loading: () => '-',
                          error: (_, __) => '!',
                        ),
                        icon: Icons.check_circle_outline,
                        color: AppTheme.infoColor,
                      ),
                      SummaryCard(
                        title: 'Resolved',
                        subtitle: 'Past 24 hours',
                        value: clearedCount.when(
                          data: (count) => count.toString(),
                          loading: () => '-',
                          error: (_, __) => '!',
                        ),
                        icon: Icons.task_alt,
                        color: AppTheme.normalColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 100), // Bottom padding for floating nav bar
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

