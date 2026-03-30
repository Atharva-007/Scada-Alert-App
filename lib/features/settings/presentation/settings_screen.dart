import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          _SectionHeader(title: 'USER INFORMATION'),
          _SettingsTile(
            icon: Icons.person,
            title: 'User',
            subtitle: 'Mobile Operator',
            trailing: null,
          ),
          _SettingsTile(
            icon: Icons.badge,
            title: 'Role',
            subtitle: 'View & Acknowledge',
            trailing: null,
          ),
          Divider(height: 1, indent: 56),
          _SectionHeader(title: 'NOTIFICATIONS'),
          SwitchListTile(
            secondary: Icon(Icons.notifications),
            title: Text('Push Notifications'),
            subtitle: Text('Receive alerts on device'),
            value: true,
            onChanged: null,
          ),
          SwitchListTile(
            secondary: Icon(Icons.vibration),
            title: Text('Vibration'),
            subtitle: Text('Vibrate on critical alerts'),
            value: true,
            onChanged: null,
          ),
          SwitchListTile(
            secondary: Icon(Icons.volume_up),
            title: Text('Sound'),
            subtitle: Text('Alert sound on notifications'),
            value: false,
            onChanged: null,
          ),
          Divider(height: 1, indent: 56),
          _SectionHeader(title: 'BACKEND CONFIGURATION'),
          _SettingsTile(
            icon: Icons.cloud,
            title: 'Firebase Project',
            subtitle: 'scada-alarm-system',
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.normalColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CONNECTED',
                style: TextStyle(
                  color: AppTheme.normalColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.storage,
            title: 'Firestore Collections',
            subtitle: 'alerts_active, alerts_history',
            trailing: null,
          ),
          Divider(height: 1, indent: 56),
          _SectionHeader(title: 'APPLICATION'),
          _SettingsTile(
            icon: Icons.info,
            title: 'App Version',
            subtitle: '1.0.0+1',
            trailing: null,
          ),
          _SettingsTile(
            icon: Icons.build,
            title: 'Backend Version',
            subtitle: '2.1.0',
            trailing: null,
          ),
          _SettingsTile(
            icon: Icons.code,
            title: 'ISA-18.2 Compliance',
            subtitle: 'Enabled',
            trailing: Icon(
              Icons.verified,
              color: AppTheme.normalColor,
              size: 20,
            ),
          ),
          Divider(height: 1, indent: 56),
          _SectionHeader(title: 'ABOUT'),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'SCADA Alarm Client',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8),
                Text(
                  'Industrial alarm monitoring system\n'
                  'Read-only mobile client for operators',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Color(0xFF9E9E9E),
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.security,
                      size: 16,
                      color: AppTheme.normalColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'View & Acknowledge Only',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.normalColor,
                          ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'No control actions permitted',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Color(0xFF757575),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Color(0xFF9E9E9E),
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}
