import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/alert_model.dart';

class SearchProvider extends StateNotifier<String> {
  SearchProvider() : super('');

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

final searchQueryProvider = StateNotifierProvider<SearchProvider, String>((ref) {
  return SearchProvider();
});

final filteredAlertsProvider = Provider.family<List<AlertModel>, List<AlertModel>>((ref, alerts) {
  final query = ref.watch(searchQueryProvider);
  
  if (query.isEmpty) {
    return alerts;
  }

  final lowerQuery = query.toLowerCase();
  
  return alerts.where((alert) {
    return alert.name.toLowerCase().contains(lowerQuery) ||
           alert.description.toLowerCase().contains(lowerQuery) ||
           alert.source.toLowerCase().contains(lowerQuery) ||
           alert.tagName.toLowerCase().contains(lowerQuery) ||
           alert.severity.toLowerCase().contains(lowerQuery);
  }).toList();
});

class AlertSearchDelegate extends SearchDelegate<AlertModel?> {
  final List<AlertModel> alerts;
  
  AlertSearchDelegate(this.alerts);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search alerts by name, source, or tag',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    final lowerQuery = query.toLowerCase();
    final results = alerts.where((alert) {
      return alert.name.toLowerCase().contains(lowerQuery) ||
             alert.description.toLowerCase().contains(lowerQuery) ||
             alert.source.toLowerCase().contains(lowerQuery) ||
             alert.tagName.toLowerCase().contains(lowerQuery) ||
             alert.severity.toLowerCase().contains(lowerQuery);
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No alerts found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (context, index) => Divider(height: 1),
      itemBuilder: (context, index) {
        final alert = results[index];
        return ListTile(
          leading: Icon(
            _getSeverityIcon(alert.severity),
            color: _getSeverityColor(alert.severity),
          ),
          title: Text(
            alert.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${alert.source} • ${alert.tagName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getSeverityColor(alert.severity).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              alert.severity.toUpperCase(),
              style: TextStyle(
                color: _getSeverityColor(alert.severity),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () {
            close(context, alert);
          },
        );
      },
    );
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Color(0xFFEF5350);
      case 'warning':
        return Color(0xFFFFA726);
      default:
        return Color(0xFF42A5F5);
    }
  }
}
