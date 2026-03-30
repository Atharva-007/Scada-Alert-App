import 'package:flutter/material.dart';
import '../../data/models/alert_model.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onTap;
  final bool showBadges;

  const AlertCard({
    super.key,
    required this.alert,
    this.onTap,
    this.showBadges = true,
  });

  @override
  Widget build(BuildContext context) {
    final severityColor = AppTheme.getSeverityColor(alert.severity);
    final severityIcon = AppTheme.getSeverityIcon(alert.severity);
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isAcknowledged 
              ? Color(0xFF3F3F3F) 
              : severityColor.withOpacity(0.3),
          width: alert.isAcknowledged ? 1 : 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Severity icon indicator
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: severityColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    severityIcon,
                    color: severityColor,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Alert Name (Primary)
                      Text(
                        alert.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFFFFF),
                              fontSize: 16,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      // Machine Name
                      Row(
                        children: [
                          Icon(
                            Icons.precision_manufacturing,
                            size: 16,
                            color: severityColor,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              alert.source,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Color(0xFFE0E0E0),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showBadges) ...[
                            if (alert.escalationLevel > 0)
                              _buildBadge(
                                'ESC ${alert.escalationLevel}',
                                AppTheme.warningColor,
                                Icons.trending_up,
                              ),
                            SizedBox(width: 6),
                            if (alert.isSuppressed)
                              _buildBadge(
                                'SUPP',
                                Color(0xFF9E9E9E),
                                Icons.visibility_off,
                              ),
                            SizedBox(width: 6),
                            if (alert.isAcknowledged)
                              _buildBadge(
                                'ACK',
                                AppTheme.normalColor,
                                Icons.check,
                              ),
                          ],
                        ],
                      ),
                      SizedBox(height: 6),
                      // Tag Name
                      Row(
                        children: [
                          Icon(
                            Icons.tag,
                            size: 14,
                            color: Color(0xFF9E9E9E),
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              alert.tagName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Color(0xFFBDBDBD),
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      // Info chips with proper time
                      Row(
                        children: [
                          _SolidInfoChip(
                            icon: Icons.speed,
                            label: '${alert.currentValue.toStringAsFixed(1)}',
                            color: severityColor,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _SolidInfoChip(
                              icon: Icons.calendar_today,
                              label: DateFormatter.formatDateTime(alert.raisedAt),
                              color: Color(0xFF757575),
                            ),
                          ),
                          SizedBox(width: 8),
                          _SolidInfoChip(
                            icon: Icons.timer,
                            label: alert.timeSinceRaised,
                            color: Color(0xFF9E9E9E),
                          ),
                        ],
                      ),
                      if (alert.acknowledgedBy != null) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: AppTheme.normalColor,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Acknowledged by ${alert.acknowledgedBy} • ${alert.acknowledgedAt != null ? DateFormatter.formatDateTime(alert.acknowledgedAt!) : ""}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9E9E9E),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF616161),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SolidInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SolidInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Color(0xFF3F3F3F),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
