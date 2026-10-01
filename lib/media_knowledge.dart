// FILE: `lib/media_knowledge.dart`.
// Purpose: Sourced, spoiler-aware facts, stories, and discovery trails for the
// universal media knowledge layer.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';
import 'backend_api.dart';
import 'localization.dart';

class MediaKnowledgePanel extends StatefulWidget {
  final String mediaWorkId;
  final String mediaTitle;

  const MediaKnowledgePanel({super.key, required this.mediaWorkId, required this.mediaTitle});

  @override
  State<MediaKnowledgePanel> createState() => _MediaKnowledgePanelState();
}

class _MediaKnowledgePanelState extends State<MediaKnowledgePanel> {
  List<Map<String, dynamic>> _facts = const [];
  List<Map<String, dynamic>> _stories = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = AppController.instance.backendApi;
    if (!api.isAuthenticated) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        api.getKnowledgeFacts(mediaWorkId: widget.mediaWorkId),
        api.getKnowledgeStories(mediaWorkId: widget.mediaWorkId),
      ]);
      if (mounted) {
        setState(() {
          _facts = results[0];
          _stories = results[1];
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() { _loading = false; _error = error.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_stories_rounded),
            const SizedBox(width: 8),
            Expanded(child: UniversalText('Media Knowledge', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
            if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            IconButton(onPressed: _load, tooltip: tr('Refresh'), icon: const Icon(Icons.refresh_rounded)),
          ]),
          const SizedBox(height: 4),
          const UniversalText('Sourced facts, behind-the-scenes context, career connections, production history, and deeper rabbit holes tied to the same canonical media identity.'),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Knowledge could not load: $_error', style: const TextStyle(color: Colors.amber))),
          if (!_loading && _facts.isEmpty && _stories.isEmpty && _error == null)
            const Padding(padding: EdgeInsets.only(top: 12), child: UniversalText('No published knowledge has been added for this title yet.')),
          if (_stories.isNotEmpty) ...[
            const SizedBox(height: 14),
            const UniversalText('Deep dives', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            for (final story in _stories.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.route_rounded),
                title: Text(story['title']?.toString() ?? 'Story'),
                subtitle: story['summary'] == null ? null : Text(story['summary'].toString()),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showStory(story),
              ),
          ],
          if (_facts.isNotEmpty) ...[
            const SizedBox(height: 12),
            const UniversalText('Facts', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            for (final fact in _facts.take(8)) _FactCard(fact: fact),
          ],
        ]),
      ),
    );
  }

  void _showStory(Map<String, dynamic> story) {
    final steps = story['steps'] is List ? (story['steps'] as List).whereType<Map>().toList() : <Map>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          shrinkWrap: true,
          children: [
            Text(story['title']?.toString() ?? 'Deep dive', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            if (story['summary'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(story['summary'].toString(), style: const TextStyle(color: Colors.white60))),
            const SizedBox(height: 16),
            for (final step in steps)
              Card(child: ListTile(
                leading: CircleAvatar(child: Text('${step['stepNumber'] ?? ''}')),
                title: Text('Fact ${step['factId'] ?? ''}'),
                subtitle: step['transitionNote'] == null ? null : Text(step['transitionNote'].toString()),
              )),
          ],
        ),
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  final Map<String, dynamic> fact;
  const _FactCard({required this.fact});

  @override
  Widget build(BuildContext context) {
    final status = fact['claimStatus']?.toString() ?? 'established';
    final difficulty = fact['difficulty']?.toString() ?? 'casual';
    final spoiler = fact['spoilerScope']?.toString() ?? 'none';
    final sources = fact['sources'] is List ? (fact['sources'] as List).whereType<Map>().toList() : <Map>[];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF121212),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(fact['title']?.toString() ?? 'Fact', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(fact['body']?.toString() ?? '', style: const TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 9),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Chip(label: Text(difficulty)),
            Chip(label: Text(status)),
            if (spoiler != 'none') Chip(avatar: const Icon(Icons.visibility_off_rounded, size: 16), label: Text('Spoiler: $spoiler')),
          ]),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final source in sources.take(3))
              TextButton.icon(
                onPressed: () async {
                  final url = Uri.tryParse(source['url']?.toString() ?? '');
                  if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.source_rounded, size: 17),
                label: Text(source['title']?.toString() ?? 'Source'),
              ),
          ],
        ]),
      ),
    );
  }
}

class MediaKnowledgeScreen extends StatelessWidget {
  final String mediaWorkId;
  final String mediaTitle;
  const MediaKnowledgeScreen({super.key, required this.mediaWorkId, required this.mediaTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: UniversalText('$mediaTitle Knowledge')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        MediaKnowledgePanel(mediaWorkId: mediaWorkId, mediaTitle: mediaTitle),
      ]),
    );
  }
}
