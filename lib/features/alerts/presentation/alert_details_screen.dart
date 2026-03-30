import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../alerts/providers/alert_providers.dart';
import '../../../data/models/alert_model.dart';

class AlertDetailsScreen extends ConsumerWidget {
  final String alertId;

  const AlertDetailsScreen({super.key, required this.alertId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertAsync = ref.watch(alertByIdProvider(alertId));

    return alertAsync.when(
      data: (alert) {
        if (alert == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Alert Details')),
            body: const Center(child: Text('Alert not found or has been cleared.')),
          );
        }
        return _buildDetailsScaffold(context, ref, alert);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading Details...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildDetailsScaffold(BuildContext context, WidgetRef ref, AlertModel alert) {
    final isCritical = alert.severity.toLowerCase() == 'critical';
    final themeColor = isCritical ? AppTheme.criticalColor : AppTheme.warningColor;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, alert, themeColor),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickActionBanner(context, ref, alert),
                  const SizedBox(height: 24),
                  _buildSectionHeader('DIAGNOSTIC DATA'),
                  const SizedBox(height: 12),
                  _buildDiagnosticGrid(alert),
                  const SizedBox(height: 32),
                  _buildSectionHeader('ALARM ANALYSIS'),
                  const SizedBox(height: 12),
                  _buildAnalysisCard(alert, themeColor),
                  const SizedBox(height: 32),
                  _buildSectionHeader('EVENT HISTORY'),
                  const SizedBox(height: 12),
                  _buildTimeline(alert),
                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: !alert.isAcknowledged
          ? FloatingActionButton.extended(
              onPressed: () => _showAcknowledgeDialog(context, ref, alert),
              label: const Text('ACKNOWLEDGE NOW'),
              icon: const Icon(Icons.check_circle),
              backgroundColor: AppTheme.infoColor,
            )
          : null,
    );
  }

  Widget _buildSliverAppBar(BuildContext context, AlertModel alert, Color themeColor) {
    return SliverAppBar(
      expandedHeight: 200.0,
      pinned: true,
      backgroundColor: themeColor.withOpacity(0.8),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                shadows: [Shadow(blurRadius: 10, color: Colors.black)],
              ),
            ),
            Text(
              'ID: ${alert.id.length > 8 ? alert.id.substring(0, 8) : alert.id}...',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Industrial background pattern
            Opacity(
              opacity: 0.2,
              child: Lottie.network(
                'https://assets9.lottiefiles.com/packages/lf20_pk5puaqq.json', // Pulse animation
                fit: BoxFit.cover,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    themeColor.withOpacity(0.2),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionBanner(BuildContext context, WidgetRef ref, AlertModel alert) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3F3F3F)),
      ),
      child: Row(
        children: [
          _buildStatusChip(alert),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white70),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(AlertModel alert) {
    final isAck = alert.isAcknowledged;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAck ? AppTheme.normalColor.withOpacity(0.2) : AppTheme.criticalColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAck ? AppTheme.normalColor : AppTheme.criticalColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAck ? Icons.check_circle : Icons.error_outline,
            size: 14,
            color: isAck ? AppTheme.normalColor : AppTheme.criticalColor,
          ),
          const SizedBox(width: 6),
          Text(
            isAck ? 'ACKNOWLEDGED' : 'UNACKNOWLEDGED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isAck ? AppTheme.normalColor : AppTheme.criticalColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF9E9E9E),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildDiagnosticGrid(AlertModel alert) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildInfoTile('TAG NAME', alert.tagName, Icons.tag),
        _buildInfoTile('EQUIPMENT', alert.equipment ?? 'N/A', Icons.settings_input_component),
        _buildInfoTile('SOURCE', alert.source, Icons.lan),
        _buildInfoTile('LOCATION', alert.location ?? 'N/A', Icons.location_on),
        _buildInfoTile('LATENCY', 'REAL-TIME', Icons.speed, color: AppTheme.infoColor),
        _buildInfoTile('ESCALATIONS', '${alert.escalationCount}', Icons.trending_up, 
            color: alert.escalationCount > 0 ? AppTheme.criticalColor : Colors.white70),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2D2D2D)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 8, color: Colors.white38)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(AlertModel alert, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardDark,
            const Color(0xFF1A1A1A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildValueIndicator('TRIGGER VALUE', '${alert.currentValue}', themeColor),
              Container(
                height: 40,
                width: 1,
                color: Colors.white10,
              ),
              _buildValueIndicator('THRESHOLD', '${alert.threshold}', Colors.white38),
            ],
          ),
          const Divider(height: 40, color: Colors.white10),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Colors.white38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValueIndicator(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildTimeline(AlertModel alert) {
    final dateFormat = DateFormat('HH:mm:ss (MMM dd)');
    
    return Column(
      children: [
        _buildTimelineItem(
          'ALARM RAISED',
          dateFormat.format(alert.raisedAt),
          'Condition: ${alert.condition}',
          Icons.notification_important,
          AppTheme.criticalColor,
          true,
        ),
        if (alert.isAcknowledged && alert.acknowledgedAt != null)
          _buildTimelineItem(
            'ACKNOWLEDGED',
            dateFormat.format(alert.acknowledgedAt!),
            'By: ${alert.acknowledgedBy ?? "System"}\nComment: ${alert.acknowledgedComment ?? "None"}',
            Icons.check_circle,
            AppTheme.infoColor,
            alert.clearedAt != null,
          ),
        if (alert.clearedAt != null)
          _buildTimelineItem(
            'RESOLVED',
            dateFormat.format(alert.clearedAt!),
            'System returned to normal operations.',
            Icons.done_all,
            AppTheme.normalColor,
            false,
          ),
      ],
    );
  }

  Widget _buildTimelineItem(String title, String time, String details, IconData icon, Color color, bool hasNext) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxBoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              if (hasNext)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.white10,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                      Text(time, style: const TextStyle(fontSize: 12, color: Colors.white38)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(details, style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAcknowledgeDialog(BuildContext context, WidgetRef ref, AlertModel alert) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acknowledge Alarm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter comments or action taken:'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: 'e.g., Investigating motor heat',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final repository = ref.read(alertRepositoryProvider);
              await repository.acknowledgeAlert(
                alert.id,
                'User-App', // In production, get actual user name
                comment: commentController.text,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
  }
}

// Fixed circular shape reference
class BoxBoxShape {
  static const circle = BoxShape.circle;
}
