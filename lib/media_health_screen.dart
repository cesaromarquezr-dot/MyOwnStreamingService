import 'package:flutter/material.dart';

import 'app_core.dart';

/// Standalone fallback for builds where the command-center MediaHealthScreen
/// is not available. Import this library with a prefix to avoid name conflicts.
class MediaHealthScreen extends StatelessWidget {
  const MediaHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = AppController.instance.library;
    final missingArtwork = items.where((item) => (item.imageUrl ?? '').trim().isEmpty).length;
    final missingDescription = items.where((item) => (item.description ?? '').trim().isEmpty).length;
    final missingPlayback = items.where((item) => (item.playbackUrl ?? '').trim().isEmpty).length;

    return Scaffold(
      appBar: AppBar(title: const Text('My Media Health')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Catalog items: ${items.length}'),
          const SizedBox(height: 8),
          _HealthRow(label: 'Missing artwork', value: missingArtwork),
          _HealthRow(label: 'Missing descriptions', value: missingDescription),
          _HealthRow(label: 'Missing direct playback URL', value: missingPlayback),
          const SizedBox(height: 12),
          const Text(
            'A missing direct playback URL does not necessarily mean a title is unavailable; a configured server can resolve playback on demand.',
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(label),
          trailing: Text('$value', style: Theme.of(context).textTheme.titleMedium),
        ),
      );
}
