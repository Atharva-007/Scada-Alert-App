import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/summary_card.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../alerts/providers/alert_providers.dart';

class EnhancedDashboardScreen extends ConsumerWidget {
  const EnhancedDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final criticalCount = ref.watch(activeCriticalCountProvider);
    final warningCount = ref.watch(activeWarningCountProvider);
    final acknowledgedCount = ref.watch(acknowledgedCountProvider);
    final clearedCount = ref.watch(clearedLast24hCountProvider);

    return Scaffold(
      body: CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          // App Bar with gradient
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                children: [
                  Icon(Icons.factory, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    child: AnimatedTextKit(
                      animatedTexts: [
                        TypewriterAnimatedText('SCADA Monitor',
                            speed: Duration(milliseconds: 100)),
                      ],
                      isRepeatingAnimation: false,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.infoDark,
                      AppTheme.infoColor,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                tooltip: 'Refresh All',
                onPressed: () {
                  ref.invalidate(activeCriticalCountProvider);
                  ref.invalidate(activeWarningCountProvider);
                  ref.invalidate(acknowledgedCountProvider);
                  ref.invalidate(clearedLast24hCountProvider);
                },
              ),
            ],
          ),
          
          // Content
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildWelcomeCard(context),
                SizedBox(height: 24),
                _buildSectionHeader(context, 'Alert Overview'),
                SizedBox(height: 12),
                _buildAlertSummaryGrid(
                  context,
                  criticalCount,
                  warningCount,
                  acknowledgedCount,
                  clearedCount,
                ),
                SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Quick action
        },
        icon: Icon(Icons.add_alert),
        label: Text('New Alert'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.infoColor.withOpacity(0.1),
                    AppTheme.normalColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.infoColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.wb_sunny_outlined,
                      color: AppTheme.infoColor,
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'System Operator',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.normalColor,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Color(0xFF9E9E9E),
            letterSpacing: 1.2,
          ),
    );
  }

  Widget _buildAlertSummaryGrid(
    BuildContext context,
    AsyncValue<int> criticalCount,
    AsyncValue<int> warningCount,
    AsyncValue<int> acknowledgedCount,
    AsyncValue<int> clearedCount,
  ) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildAnimatedSummaryCard(
                  context,
                  'Critical Alerts',
                  criticalCount,
                  Icons.error,
                  AppTheme.criticalColor,
                  0,
                ),
                _buildAnimatedSummaryCard(
                  context,
                  'Warning Alerts',
                  warningCount,
                  Icons.warning,
                  AppTheme.warningColor,
                  100,
                ),
                _buildAnimatedSummaryCard(
                  context,
                  'Acknowledged',
                  acknowledgedCount,
                  Icons.check_circle,
                  AppTheme.infoColor,
                  200,
                ),
                _buildAnimatedSummaryCard(
                  context,
                  'Cleared (24h)',
                  clearedCount,
                  Icons.done_all,
                  AppTheme.normalColor,
                  300,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSummaryCard(
    BuildContext context,
    String title,
    AsyncValue<int> count,
    IconData icon,
    Color color,
    int delay,
  ) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: count.when(
              data: (value) => Hero(
                tag: 'summary_$title',
                child: Material(
                  color: Colors.transparent,
                  child: SummaryCard(
                    title: title,
                    value: value.toString(),
                    icon: icon,
                    color: color,
                  ),
                ),
              ),
              loading: () => ShimmerLoading(
                width: double.infinity,
                height: 100,
                borderRadius: 12,
              ),
              error: (_, __) => SummaryCard(
                title: title,
                value: '!',
                icon: icon,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}
