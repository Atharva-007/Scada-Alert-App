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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusAndActions(context, ref, alert),
                  const SizedBox(height: 24),
                  
                  // Primary Metrics Section
                  _buildMetricsSection(alert, themeColor),
                  const SizedBox(height: 24),

                  // Description / Context Section
                  _buildDescriptionSection(alert),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('DIAGNOSTIC DETAILS'),
                  const SizedBox(height: 12),
                  _buildDiagnosticGrid(alert),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('EVENT TIMELINE'),
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
              label: const Text(
                'ACKNOWLEDGE ALARM',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              icon: const Icon(Icons.check_circle_outline),
              backgroundColor: AppTheme.infoColor,
              elevation: 4,
            )
          : null,
    );
  }

  Widget _buildSliverAppBar(BuildContext context, AlertModel alert, Color themeColor) {
    return SliverAppBar(
      expandedHeight: 180.0,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF1A1A1A),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
                shadows: [Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black54)],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              alert.tagName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Ambient pulse effect for critical alerts
            if (alert.severity.toLowerCase() == 'critical')
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: Lottie.network(
                    'https://assets9.lottiefiles.com/packages/lf20_pk5puaqq.json',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    themeColor.withOpacity(0.4),
                    const Color(0xFF0F0F0F),
                  ],
                ),
              ),
            ),
            // Decorative elements
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                AppTheme.getSeverityIcon(alert.severity),
                size: 150,
                color: themeColor.withOpacity(0.05),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusAndActions(BuildContext context, WidgetRef ref, AlertModel alert) {
    return Row(
      children: [
        _buildStatusChip(alert),
        const Spacer(),
        _buildActionButton(Icons.history, 'Log', () {}),
        const SizedBox(width: 8),
        _buildActionButton(Icons.share_outlined, 'Share', () {}),
        const SizedBox(width: 8),
        _buildActionButton(Icons.more_vert, null, () {}),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String? label, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: label != null
          ? TextButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18, color: Colors.white70),
              label: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          : IconButton(
              onPressed: onPressed,
              icon: Icon(icon, size: 18, color: Colors.white70),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
    );
  }

  Widget _buildMetricsSection(AlertModel alert, Color themeColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildValueIndicator('TRIGGER VALUE', '${alert.currentValue}', themeColor, true),
              Container(
                height: 50,
                width: 1,
                color: Colors.white10,
              ),
              _buildValueIndicator('THRESHOLD', '${alert.threshold}', Colors.white38, false),
            ],
          ),
          const SizedBox(height: 20),
          // Simple visual comparison bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: alert.threshold != 0 ? (alert.currentValue / alert.threshold).clamp(0.0, 1.0) : 0,
              backgroundColor: Colors.white10,
              color: themeColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Deviation: ${((alert.currentValue - alert.threshold).abs()).toStringAsFixed(2)} units',
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
              Text(
                'Condition: ${alert.condition}',
                style: TextStyle(fontSize: 10, color: themeColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(AlertModel alert) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D2D2D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppTheme.infoColor),
              const SizedBox(width: 8),
              const Text(
                'ALARM CONTEXT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.infoColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.description,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(AlertModel alert) {
    final isAck = alert.isAcknowledged;
    final color = isAck ? AppTheme.normalColor : AppTheme.criticalColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAck ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            isAck ? 'ACKNOWLEDGED' : 'ACTIVE / UNACK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white38,
          letterSpacing: 1.5,
        ),
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
      childAspectRatio: 2.2,
      children: [
        _buildInfoTile('EQUIPMENT', alert.equipment ?? 'N/A', Icons.precision_manufacturing_outlined),
        _buildInfoTile('LOCATION', alert.location ?? 'N/A', Icons.location_on_outlined),
        _buildInfoTile('SOURCE', alert.source, Icons.hub_outlined),
        _buildInfoTile('SOURCE TAG', alert.tagName, Icons.tag_outlined),
        _buildInfoTile('LATENCY', 'REAL-TIME', Icons.timer_outlined, color: AppTheme.infoColor),
        _buildInfoTile('ESCALATIONS', '${alert.escalationCount}', Icons.trending_up_rounded, 
            color: alert.escalationCount > 0 ? AppTheme.criticalColor : Colors.white54),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D2D2D)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color ?? Colors.white38),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 8, color: Colors.white38, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueIndicator(String label, String value, Color color, bool highlight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label, 
          style: const TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1, fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 32 : 24, 
            fontWeight: FontWeight.w900, 
            color: color,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(AlertModel alert) {
    final dateFormat = DateFormat('HH:mm:ss (MMM dd)');
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF252525)),
      ),
      child: Column(
        children: [
          _buildTimelineItem(
            'ALARM RAISED',
            dateFormat.format(alert.raisedAt),
            'Trigger condition detected: ${alert.condition}',
            Icons.notification_important_outlined,
            AppTheme.criticalColor,
            alert.isAcknowledged,
          ),
          if (alert.isAcknowledged && alert.acknowledgedAt != null)
            _buildTimelineItem(
              'ACKNOWLEDGED',
              dateFormat.format(alert.acknowledgedAt!),
              'Verified by: ${alert.acknowledgedBy ?? "System"}\nComment: ${alert.acknowledgedComment ?? "Acknowledged via mobile"}',
              Icons.verified_user_outlined,
              AppTheme.infoColor,
              alert.clearedAt != null,
            ),
          if (alert.clearedAt != null)
            _buildTimelineItem(
              'AUTO-RESOLVED',
              dateFormat.format(alert.clearedAt!),
              'Process values returned to normal range.',
              Icons.task_alt_outlined,
              AppTheme.normalColor,
              false,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, String time, String details, IconData icon, Color color, bool hasNext) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              if (hasNext)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withOpacity(0.5), Colors.white10],
                      ),
                    ),
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
                      Text(
                        title, 
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)
                      ),
                      Text(
                        time, 
                        style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500)
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    details, 
                    style: const TextStyle(fontSize: 12, color: Colors.white60, height: 1.5, fontWeight: FontWeight.w400)
                  ),
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
