import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';

/// A searchable, collection-wide shelf of imported bonus media. It uses the
/// explicit parentMediaId relationship already stored by the import pipeline.
class MediaExtrasLibraryScreen extends StatefulWidget {
  const MediaExtrasLibraryScreen({super.key});

  @override
  State<MediaExtrasLibraryScreen> createState() => _MediaExtrasLibraryScreenState();
}

class _MediaExtrasLibraryScreenState extends State<MediaExtrasLibraryScreen> {
  final TextEditingController _search = TextEditingController();
  String _category = 'All';
  bool _showUnlinked = true;

  static const List<String> _categories = <String>[
    'All',
    'Deleted scenes',
    'Behind the scenes',
    'Commentary',
    'Trailers',
    'Alternate cuts',
    'Other',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _kind(MediaItem item) {
    final text = <String>[item.title, ...item.tags, ...item.extras]
        .join(' ')
        .toLowerCase();
    if (text.contains('deleted scene') || text.contains('deleted scenes') || text.contains('cut scene')) {
      return 'Deleted scenes';
    }
    if (text.contains('behind the scenes') || text.contains('making of') || text.contains('featurette') || text.contains('production diary')) {
      return 'Behind the scenes';
    }
    if (text.contains('commentary') || text.contains('audio comment')) {
      return 'Commentary';
    }
    if (text.contains('trailer') || text.contains('teaser')) return 'Trailers';
    if (text.contains('alternate cut') || text.contains('extended cut') || text.contains('director\'s cut') || text.contains('alternate ending')) {
      return 'Alternate cuts';
    }
    return 'Other';
  }

  bool _looksLikeExtra(MediaItem item) {
    final type = item.type.toLowerCase();
    return item.parentMediaId?.trim().isNotEmpty == true ||
        type.contains('extra') ||
        type.contains('featurette') ||
        item.tags.any((tag) => tag.toLowerCase().contains('disc extra')) ||
        item.tags.any((tag) => tag.toLowerCase().contains('bonus'));
  }

  @override
  Widget build(BuildContext context) {
    final allItems = AppController.instance.library.where(_looksLikeExtra).toList(growable: false);
    final normalizedQuery = _search.text.trim().toLowerCase();
    final parents = <String, MediaItem>{
      for (final item in AppController.instance.library) item.id: item,
    };
    final filtered = allItems.where((item) {
      final parent = parents[item.parentMediaId];
      if (!_showUnlinked && parent == null) return false;
      if (_category != 'All' && _kind(item) != _category) return false;
      if (normalizedQuery.isEmpty) return true;
      return <String>[
        item.title,
        item.description ?? '',
        item.parentMediaId ?? '',
        parent?.title ?? '',
        ...item.tags,
        ...item.extras,
      ].join(' ').toLowerCase().contains(normalizedQuery);
    }).toList()
      ..sort((a, b) {
        final parentA = parents[a.parentMediaId]?.title ?? '';
        final parentB = parents[b.parentMediaId]?.title ?? '';
        final byParent = parentA.toLowerCase().compareTo(parentB.toLowerCase());
        return byParent != 0 ? byParent : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    final linkedCount = filtered.where((item) => parents[item.parentMediaId] != null).length;
    final unlinkedCount = filtered.length - linkedCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Movie & Show Extras Library')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Bonus content, kept with the right title', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Browse imported deleted scenes, featurettes, trailers, commentary tracks and alternate cuts. Linkage is based on the stored parent title; nothing is moved or deleted from disk.', style: TextStyle(color: Colors.white60, height: 1.4)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(label: Text('${allItems.length} extras')),
                  Chip(label: Text('$linkedCount linked in current view')),
                  Chip(label: Text('$unlinkedCount unlinked in current view')),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search extra or parent title',
              suffixIcon: _search.text.isEmpty ? null : IconButton(
                tooltip: 'Clear search',
                onPressed: () { _search.clear(); setState(() {}); },
                icon: const Icon(Icons.clear_rounded),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include unlinked bonus items'),
            subtitle: const Text('Turn this off to show only extras connected to a movie or show.'),
            value: _showUnlinked,
            onChanged: (value) => setState(() => _showUnlinked = value),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _categories.map((category) => Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(label: Text(category), selected: _category == category, onSelected: (_) => setState(() => _category = category)),
            )).toList()),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No bonus items match these filters. Import the bonus title and link it to its parent through the media import workflow.')))
          else
            for (final item in filtered)
              Builder(builder: (context) {
                final parent = parents[item.parentMediaId];
                final playable = (item.playbackUrl?.trim().isNotEmpty ?? false);
                final metadata = <String>[
                  _kind(item),
                  if (item.releaseYear != null) item.releaseYear.toString(),
                  if (item.tags.isNotEmpty) item.tags.take(2).join(', '),
                ].join(' · ');
                return Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: SizedBox(
                        width: 54,
                        height: 76,
                        child: (item.imageUrl?.trim().isNotEmpty ?? false)
                            ? Image.network(item.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF292936), child: Icon(Icons.movie_filter_outlined)))
                            : const ColoredBox(color: Color(0xFF292936), child: Icon(Icons.movie_filter_outlined)),
                      ),
                    ),
                    title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${parent == null ? 'Not linked to a parent title' : 'For: ${parent.title}'}\n$metadata${playable ? '' : '\nNo playable media-server URL found'}', maxLines: 4, overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    trailing: Icon(playable ? Icons.play_circle_outline_rounded : Icons.info_outline_rounded, color: playable ? Colors.greenAccent : Colors.white54),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: item))),
                    onLongPress: parent == null ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: parent))),
                  ),
                );
              }),
          const SizedBox(height: 12),
          const Text('DVD menus, IFO/BUP navigation, and interactive mini-games are not regular playable media files. Preserve a lawful full-disc backup if you need the original interactive disc experience.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}
