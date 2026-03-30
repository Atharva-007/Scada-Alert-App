import 'package:flutter/material.dart';
import '../../data/models/alert_model.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onTap;

  const AlertCard({
    super.key,
    required this.alert,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final severityColor = AppTheme.getSeverityColor(alert.severity);
    final isAck = alert.isAcknowledged;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAck ? const Color(0xFF2A2A2A) : severityColor.withOpacity(0.5),
          width: isAck ? 1 : 1.5,
        ),
        boxShadow: [
          if (!isAck)
            BoxShadow(
              color: severityColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Severity Color Strip
                  Container(
                    width: 6,
                    color: severityColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alert.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      alert.source,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildValueDisplay(alert.currentValue, severityColor),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildMiniBadge(
                                isAck ? Icons.check_circle : Icons.error_outline,
                                isAck ? 'ACKNOWLEDGED' : 'ACTIVE',
                                isAck ? AppTheme.normalColor : severityColor,
                              ),
                              const Spacer(),
                              Text(
                                alert.timeSinceRaised,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValueDisplay(double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
