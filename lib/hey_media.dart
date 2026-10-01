// FILE: `lib/hey_media.dart`.
// Purpose: User-facing Hey Media entry point for natural-language media help.
// The current implementation performs local catalog search and exposes the
// capability surface without pretending to be a remote AI transaction engine.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'smart_search.dart';

class HeyMediaScreen extends StatefulWidget {
  const HeyMediaScreen({super.key});

  @override
  State<HeyMediaScreen> createState() => _HeyMediaScreenState();
}

class _HeyMediaScreenState extends State<HeyMediaScreen> {
  final promptController = TextEditingController();
  List<MediaItem> results = const [];
  String? message;

  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }

  void ask() {
    final query = promptController.text.trim();
    if (query.isEmpty) return;

    final library = AppController.instance.library;
    final matches = SmartSearch.search(query, library);
    setState(() {
      results = matches;
      message = matches.isEmpty
          ? 'I did not find an exact match in the account library. Try a title, actor, artist, album, or genre.'
          : 'I found ${matches.length} matching library item${matches.length == 1 ? '' : 's'}.';
    });
  }

  void usePrompt(String value) {
    promptController.text = value;
    ask();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hey Media'),
        actions: [
          IconButton(
            tooltip: 'Open universal search',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartSearchScreen())),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 32),
                      SizedBox(width: 10),
                      Text('Hey Media', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask in plain language about media in your account library. Results stay tied to the media catalog you are authorized to access.',
                    style: TextStyle(color: Colors.white60, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: promptController,
                    autofocus: true,
                    onSubmitted: (_) => ask(),
                    decoration: InputDecoration(
                      hintText: 'Ask Hey Media… e.g. “find horror movies”',
                      prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                      suffixIcon: IconButton(onPressed: ask, icon: const Icon(Icons.arrow_upward_rounded)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _promptChip('Find horror movies'),
                      _promptChip('Find music'),
                      _promptChip('Find sci-fi'),
                      _promptChip('Find TV shows'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 16),
          for (final media in results)
            Card(
              child: ListTile(
                leading: media.imageUrl == null || media.imageUrl!.isEmpty
                    ? const Icon(Icons.play_circle_outline_rounded)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(media.imageUrl!, width: 44, height: 62, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_outline_rounded)),
                      ),
                title: Text(media.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(media.type),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: media))),
              ),
            ),
          if (results.isEmpty && message == null)
            const Card(
              child: ListTile(
                leading: Icon(Icons.lightbulb_outline_rounded),
                title: Text('Try asking for a title, genre, actor, artist, album, or show.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _promptChip(String value) => ActionChip(
        avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
        label: Text(value),
        onPressed: () => usePrompt(value),
      );
}
