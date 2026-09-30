import 'package:flutter/material.dart';

import 'app_core.dart';

/// A profile-scoped feed of interactions recorded by the shared media action
/// contract. Domain state is still read from its owning service.
class ActivityTimeline extends StatefulWidget {
  final String profileId;
  final int limit;

  const ActivityTimeline({
    super.key,
    required this.profileId,
    this.limit = 50,
  });

  @override
  State<ActivityTimeline> createState() => _ActivityTimelineState();
}

class _ActivityTimelineState extends State<ActivityTimeline> {
  late Future<List<Map<String, dynamic>>> _activity;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ActivityTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId || oldWidget.limit != widget.limit) {
      _load();
    }
  }

  void _load() {
    final api = AppController.instance.backendApi;
    _activity = api.isAuthenticated
        ? api.getMediaActivity(profileId: widget.profileId, limit: widget.limit)
        : Future<List<Map<String, dynamic>>>.value(const []);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _activity,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load activity.'));
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return const Center(child: Text('No activity yet.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final action = (item['action'] ?? 'interact').toString();
              final type = (item['contentType'] ?? 'media').toString();
              final id = (item['contentId'] ?? '').toString();
              final timestamp = DateTime.tryParse(
                (item['occurredAt'] ?? '').toString(),
              );
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text('${_label(action)} ${_label(type)}'),
                subtitle: Text(id),
                trailing: timestamp == null
                    ? null
                    : Text(MaterialLocalizations.of(context).formatShortDate(timestamp)),
              );
            },
          );
        },
      );

  String _label(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
