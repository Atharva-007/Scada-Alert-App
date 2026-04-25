import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/summary_card.dart';
import '../../alerts/providers/alert_providers.dart';
import '../../alerts/presentation/critical_alerts_screen.dart';
import '../../alerts/presentation/pending_approvals_screen.dart';
import '../../alerts/presentation/warning_alerts_screen.dart';
import '../../history/presentation/alert_history_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveCounts = ref.watch(dashboardLiveCountsProvider);
    final totalHistoryCount = ref.watch(historicalAlertsCountProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allLiveAlertsProvider);
          ref.invalidate(historicalAlertsCountProvider);
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              floating: true,
              pinned: true,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Text(
                  'SCADA Monitor',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    letterSpacing: -0.8,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.infoColor.withValues(
                              alpha: isDark ? 0.15 : 0.12,
                            ),
                            isDark
                                ? AppTheme.backgroundDark
                                : AppTheme.backgroundLight,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        Icons.dashboard_outlined,
                        size: 140,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () {
                      ref.invalidate(allLiveAlertsProvider);
                      ref.invalidate(historicalAlertsCountProvider);
                    },
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      const Icon(
                        Icons.analytics_outlined,
                        size: 16,
                        color: AppTheme.infoColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SYSTEM OVERVIEW',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.infoColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.0,
                    children: [
                      SummaryCard(
                        title: 'Critical Alerts',
                        subtitle: 'Tap to view',
                        value: _countLabel(
                          liveCounts.whenData((counts) => counts.critical),
                        ),
                        icon: Icons.error_outline,
                        color: AppTheme.criticalColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, anim, sec) =>
                                  const CriticalAlertsScreen(),
                              transitionsBuilder: (context, anim, sec, child) {
                                return FadeTransition(
                                  opacity: anim,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                      ),
                      SummaryCard(
                        title: 'Warnings',
                        subtitle: 'Tap to view',
                        value: _countLabel(
                          liveCounts.whenData((counts) => counts.warning),
                        ),
                        icon: Icons.warning_amber_rounded,
                        color: AppTheme.warningColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, anim, sec) =>
                                  const WarningAlertsScreen(),
                              transitionsBuilder: (context, anim, sec, child) {
                                return FadeTransition(
                                  opacity: anim,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                      ),
                      SummaryCard(
                        title: 'Pending Approval',
                        subtitle: 'Supervisor queue',
                        value: _countLabel(
                          liveCounts.whenData(
                            (counts) => counts.pendingApprovals,
                          ),
                        ),
                        icon: Icons.check_circle_outline,
                        color: AppTheme.infoColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, anim, sec) =>
                                  const PendingApprovalsScreen(),
                              transitionsBuilder: (context, anim, sec, child) {
                                return FadeTransition(
                                  opacity: anim,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                      ),
                      SummaryCard(
                        title: 'Total History',
                        subtitle: 'Archived alerts',
                        value: _countLabel(totalHistoryCount),
                        icon: Icons.history_rounded,
                        color: AppTheme.normalColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, anim, sec) =>
                                  const AlertHistoryScreen(),
                              transitionsBuilder: (context, anim, sec, child) {
                                return FadeTransition(
                                  opacity: anim,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _countLabel(AsyncValue<int> count) {
    return count.when(
      data: (value) => value.toString(),
      loading: () => '-',
      error: (_, __) => '!',
    );
  }
}
