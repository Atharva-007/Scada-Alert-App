import 'package:flutter/material.dart';
import '../../data/models/alert_model.dart';
import '../theme/app_theme.dart';

class AlertCard extends StatefulWidget {
  final AlertModel alert;
  final VoidCallback? onTap;

  const AlertCard({super.key, required this.alert, this.onTap});

  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final severityColor = AppTheme.getSeverityColor(widget.alert.severity);
    final isAck = widget.alert.isAcknowledged;
    final statusKey = widget.alert.statusKey;

    // Solid background colors based on theme
    final bgColor = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;
    final secondaryTextColor = isDark ? Colors.white30 : Colors.black45;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAck ? borderColor : severityColor.withValues(alpha: 0.6),
              width: isAck ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Technical Header: Machine & Timestamp
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(
                        alpha: isDark ? 0.1 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.alert.source.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: severityColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (statusKey != 'active') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          statusKey,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _getStatusColor(
                            statusKey,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        widget.alert.statusLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: _getStatusColor(statusKey),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    widget.alert.timeSinceRaised.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: secondaryTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Main Alert Name & Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.alert.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1C1E),
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'TAG: ${widget.alert.tagName}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: secondaryTextColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (widget.alert.location != null ||
                            widget.alert.equipment != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (widget.alert.location != null) ...[
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: secondaryTextColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.alert.location!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (widget.alert.equipment != null) ...[
                                Icon(
                                  Icons.settings_outlined,
                                  size: 12,
                                  color: secondaryTextColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.alert.equipment!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildCompactStatus(statusKey, isAck, severityColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatus(
    String statusKey,
    bool isAck,
    Color severityColor,
  ) {
    final color = _getStatusColor(statusKey);
    final icon = switch (statusKey) {
      'approved' || 'cleared' => Icons.task_alt_rounded,
      'rejected' => Icons.block_rounded,
      'acknowledged' => Icons.check_rounded,
      _ => isAck ? Icons.check_rounded : Icons.priority_high_rounded,
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'active') {
      return severityColorForActive();
    }
    return AppTheme.getStatusColor(status);
  }

  Color severityColorForActive() {
    return AppTheme.getSeverityColor(widget.alert.severity);
  }
}
