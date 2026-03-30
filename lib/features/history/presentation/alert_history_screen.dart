import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/alert_card.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/repositories/alert_repository.dart';
import '../../alerts/presentation/alert_details_screen.dart';
import '../../alerts/providers/alert_providers.dart';

class AlertHistoryScreen extends ConsumerStatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  ConsumerState<AlertHistoryScreen> createState() =>
      _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends ConsumerState<AlertHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  List<AlertModel> _alerts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _selectedSeverity;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoading && _hasMore) {
        _loadAlerts();
      }
    }
  }

  Future<void> _loadAlerts({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _alerts = [];
        _hasMore = true;
      }
    });

    try {
      final repository = ref.read(alertRepositoryProvider);
      final newAlerts = await repository.getAlertHistory(
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        severity: _selectedSeverity,
        limit: 50,
      );

      setState(() {
        if (refresh) {
          _alerts = newAlerts;
        } else {
          _alerts.addAll(newAlerts);
        }
        _hasMore = newAlerts.length >= 50;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      _loadAlerts(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alert History'),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range),
            tooltip: 'Date Range',
            onPressed: _selectDateRange,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: 'Filter Severity',
            onSelected: (value) {
              setState(() {
                _selectedSeverity = value == 'all' ? null : value;
              });
              _loadAlerts(refresh: true);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text('All Severities')),
              PopupMenuItem(value: 'critical', child: Text('Critical')),
              PopupMenuItem(value: 'warning', child: Text('Warning')),
              PopupMenuItem(value: 'info', child: Text('Info')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAlerts(refresh: true),
        child: _alerts.isEmpty && !_isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Color(0xFF757575),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No History Available',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Try adjusting filters',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Color(0xFF9E9E9E),
                          ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (_selectedSeverity != null || _dateRange != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      color: Color(0xFF2D2D2D),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_alt,
                            size: 16,
                            color: Color(0xFFBDBDBD),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Filters: ${_selectedSeverity ?? "All"}'
                              '${_dateRange != null ? " | Date Range" : ""}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedSeverity = null;
                                _dateRange = null;
                              });
                              _loadAlerts(refresh: true);
                            },
                            child: Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(vertical: 8),
                      itemCount: _alerts.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _alerts.length) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final alert = _alerts[index];
                        return AlertCard(
                          alert: alert,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AlertDetailsScreen(alertId: alert.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
