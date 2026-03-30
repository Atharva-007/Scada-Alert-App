import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/alert_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/providers/network_provider.dart';
import '../../../data/models/alert_model.dart';
import '../providers/alert_providers.dart';
import '../providers/search_provider.dart';
import 'alert_details_screen.dart';

class ActiveAlertsScreen extends ConsumerStatefulWidget {
  const ActiveAlertsScreen({super.key});

  @override
  ConsumerState<ActiveAlertsScreen> createState() => _ActiveAlertsScreenState();
}

class _ActiveAlertsScreenState extends ConsumerState<ActiveAlertsScreen> 
    with AutomaticKeepAliveClientMixin {
  String? _selectedSeverity;
  bool? _filterAcknowledged;
  bool _isRefreshing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final alertsAsync = ref.watch(activeAlertsProvider);
    final audioService = ref.read(audioServiceProvider);
    final isOffline = ref.watch(isOfflineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Active Alerts'),
            if (isOffline) ...[
              SizedBox(width: 8),
              Tooltip(
                message: 'Offline - Showing cached data',
                child: Icon(
                  Icons.cloud_off,
                  size: 20,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            tooltip: 'Search Alerts',
            onPressed: () => _showSearchDialog(context, alertsAsync.value ?? []),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: 'Filter by Severity',
            onSelected: (value) {
              setState(() {
                _selectedSeverity = value == 'all' ? null : value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list_alt, size: 20),
                    SizedBox(width: 12),
                    Text('All Severities'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'critical',
                child: Row(
                  children: [
                    Icon(Icons.error, color: AppTheme.criticalColor, size: 20),
                    SizedBox(width: 12),
                    Text('Critical Only'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'warning',
                child: Row(
                  children: [
                    Icon(Icons.warning, color: AppTheme.warningColor, size: 20),
                    SizedBox(width: 12),
                    Text('Warning Only'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info, color: AppTheme.infoColor, size: 20),
                    SizedBox(width: 12),
                    Text('Info Only'),
                  ],
                ),
              ),
            ],
          ),
          PopupMenuButton<bool?>(
            icon: Icon(Icons.check_circle_outline),
            tooltip: 'Filter by Status',
            onSelected: (value) {
              setState(() {
                _filterAcknowledged = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, size: 20),
                    SizedBox(width: 12),
                    Text('All Alerts'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: false,
                child: Row(
                  children: [
                    Icon(Icons.notification_important, 
                         color: AppTheme.warningColor, size: 20),
                    SizedBox(width: 12),
                    Text('Unacknowledged'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: true,
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.normalColor, size: 20),
                    SizedBox(width: 12),
                    Text('Acknowledged'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: alertsAsync.when(
        data: (alerts) => _buildAlertsList(context, alerts, audioService),
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(error),
      ),
    );
  }

  Widget _buildAlertsList(BuildContext context, List<AlertModel> alerts, AudioService audioService) {
    var filteredAlerts = alerts;

    // Apply severity filter
    if (_selectedSeverity != null) {
      filteredAlerts = filteredAlerts
          .where((a) => a.severity.toLowerCase() == _selectedSeverity!.toLowerCase())
          .toList();
    }

    // Apply acknowledgment filter
    if (_filterAcknowledged != null) {
      filteredAlerts = filteredAlerts
          .where((a) => a.isAcknowledged == _filterAcknowledged)
          .toList();
    }

    // Sort by priority
    final sortedAlerts = List<AlertModel>.from(filteredAlerts)
      ..sort((a, b) => b.sortPriority.compareTo(a.sortPriority));

    if (sortedAlerts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isRefreshing = true);
        ref.invalidate(activeAlertsProvider);
        await Future.delayed(Duration(milliseconds: 500));
        setState(() => _isRefreshing = false);
      },
      child: Column(
        children: [
          // Filter indicator
          if (_selectedSeverity != null || _filterAcknowledged != null)
            _buildFilterBanner(alerts.length, sortedAlerts.length),
          
          // Alerts list
          Expanded(
            child: ListView.builder(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: 8, bottom: 80),
              itemCount: sortedAlerts.length,
              itemBuilder: (context, index) {
                final alert = sortedAlerts[index];
                return AlertCard(
                  alert: alert,
                  onTap: () => _navigateToDetails(context, alert, audioService),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBanner(int totalCount, int filteredCount) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        border: Border(
          bottom: BorderSide(color: Color(0xFF3F3F3F), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 18, color: AppTheme.infoColor),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered: $filteredCount of $totalCount alerts',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedSeverity = null;
                _filterAcknowledged = null;
              });
            },
            icon: Icon(Icons.clear, size: 16),
            label: Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.infoColor,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: AppTheme.normalColor,
          ),
          SizedBox(height: 24),
          Text(
            'No Active Alerts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFFFFF),
            ),
          ),
          SizedBox(height: 12),
          Text(
            _selectedSeverity != null || _filterAcknowledged != null
                ? 'Try adjusting your filters'
                : 'All systems operating normally',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF9E9E9E),
            ),
          ),
          if (_selectedSeverity != null || _filterAcknowledged != null) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedSeverity = null;
                  _filterAcknowledged = null;
                });
              },
              icon: Icon(Icons.clear_all),
              label: Text('Clear All Filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Loading alerts...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: AppTheme.criticalColor,
            ),
            SizedBox(height: 24),
            Text(
              'Connection Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFFFFF),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Unable to load alerts. Running in offline mode.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF9E9E9E),
              ),
            ),
            SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF757575),
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(activeAlertsProvider);
              },
              icon: Icon(Icons.refresh),
              label: Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context, AlertModel alert, AudioService audioService) {
    // Play haptic feedback
    audioService.playAlertSound(alert.severity);
    
    // Navigate to details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertDetailsScreen(alertId: alert.id),
      ),
    ).then((_) {
      // Refresh list when coming back
      if (mounted) {
        ref.invalidate(activeAlertsProvider);
      }
    });
  }

  Future<void> _showSearchDialog(BuildContext context, List<AlertModel> alerts) async {
    final result = await showSearch(
      context: context,
      delegate: AlertSearchDelegate(alerts),
    );
    
    if (result != null && mounted) {
      _navigateToDetails(
        context, 
        result, 
        ref.read(audioServiceProvider),
      );
    }
  }
}
