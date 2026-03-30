import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F0F),
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Settings',
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
                          AppTheme.infoColor.withOpacity(0.05),
                          const Color(0xFF0F0F0F),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(title: 'USER INFORMATION'),
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'User',
                  subtitle: 'Mobile Operator',
                  trailing: null,
                ),
                _SettingsTile(
                  icon: Icons.badge_outlined,
                  title: 'Role',
                  subtitle: 'View & Acknowledge',
                  trailing: null,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(color: Color(0xFF1E1E1E)),
                ),
                _SectionHeader(title: 'NOTIFICATIONS'),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_none, color: Colors.white70),
                  title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Receive alerts on device', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  value: true,
                  activeColor: AppTheme.infoColor,
                  onChanged: null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration, color: Colors.white70),
                  title: const Text('Vibration', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Vibrate on critical alerts', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  value: true,
                  activeColor: AppTheme.infoColor,
                  onChanged: null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined, color: Colors.white70),
                  title: const Text('Sound', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Alert sound on notifications', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  value: false,
                  activeColor: AppTheme.infoColor,
                  onChanged: null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(color: Color(0xFF1E1E1E)),
                ),
                _SectionHeader(title: 'BACKEND CONFIGURATION'),
                _SettingsTile(
                  icon: Icons.cloud_outlined,
                  title: 'Firebase Project',
                  subtitle: 'scada-alarm-system',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.normalColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.normalColor.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'CONNECTED',
                      style: TextStyle(
                        color: AppTheme.normalColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.storage_outlined,
                  title: 'Firestore Collections',
                  subtitle: 'alerts_active, alerts_history',
                  trailing: null,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(color: Color(0xFF1E1E1E)),
                ),
                _SectionHeader(title: 'APPLICATION'),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'App Version',
                  subtitle: '1.0.0+1',
                  trailing: null,
                ),
                _SettingsTile(
                  icon: Icons.build_outlined,
                  title: 'Backend Version',
                  subtitle: '2.1.0',
                  trailing: null,
                ),
                _SettingsTile(
                  icon: Icons.code,
                  title: 'ISA-18.2 Compliance',
                  subtitle: 'Enabled',
                  trailing: const Icon(
                    Icons.verified,
                    color: AppTheme.normalColor,
                    size: 18,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(color: Color(0xFF1E1E1E)),
                ),
                _SectionHeader(title: 'ABOUT'),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151515),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF252525)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'SCADA Alarm Client',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Industrial alarm monitoring system\nRead-only mobile client for operators',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.normalColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.security_outlined,
                                size: 16,
                                color: AppTheme.normalColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'View & Acknowledge Only',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.normalColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.infoColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontSize: 11,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
        ),
      ),
      trailing: trailing,
    );
  }
}
