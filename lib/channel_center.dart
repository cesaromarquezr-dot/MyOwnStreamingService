import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'home_hero_hover_preview.dart';

/// User-managed channels for curating movies and shows from the local library.
class ChannelCenterScreen extends StatefulWidget {
  const ChannelCenterScreen({super.key});
  @override
  State<ChannelCenterScreen> createState() => _ChannelCenterScreenState();
}

class _ChannelCenterScreenState extends State<ChannelCenterScreen> {
  static const _key = 'myownstreaming.channels.v1';
  final List<Map<String, dynamic>> _channels = [];
  bool _loaded = false;
  final _name = TextEditingController();
  final _description = TextEditingController();
  static const _presets = <Map<String, String>>[
    {
      'name': 'Superhero Channel',
      'description': 'Superhero movies and series',
      'icon': '🦸',
      'kind': 'My Channel'
    },
    {
      'name': 'Comedy Channel',
      'description': 'Comedy movies and series',
      'icon': '😂',
      'kind': 'My Channel'
    },
    {
      'name': 'Horror Channel',
      'description': 'Horror movies and series',
      'icon': '👻',
      'kind': 'My Channel'
    },
    {
      'name': 'Sci-Fi Channel',
      'description': 'Science-fiction adventures',
      'icon': '🚀',
      'kind': 'My Channel'
    },
  ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        var migrated = false;
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _channels.addAll(decoded.whereType<Map>().map((entry) {
            final channel = Map<String, dynamic>.from(entry);
            if ((channel['kind'] ?? '').toString().toLowerCase() == 'live tv') {
              channel['kind'] = 'My Channel';
              channel['description'] = 'Curated channel from your library.';
              channel.remove('streamUrl');
              migrated = true;
            }
            return channel;
          }));
        }
        if (migrated) {
          await prefs.setString(_key, jsonEncode(_channels));
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_channels));
  }

  Future<void> _add({Map<String, String>? preset}) async {
    _name.text = preset?['name'] ?? '';
    _description.text = preset?['description'] ?? '';
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(preset == null
                    ? 'Create channel'
                    : 'Add ${preset['name']}'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: _name,
                      decoration:
                          const InputDecoration(labelText: 'Channel name')),
                  TextField(
                      controller: _description,
                      decoration:
                          const InputDecoration(labelText: 'Description')),
                  const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                          'This creates a curated channel entry from movies and shows in your library.')),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save'))
                ]));
    if (ok != true || _name.text.trim().isEmpty) return;
    setState(() {
      _channels.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'kind': 'My Channel',
        'enabled': true
      });
    });
    await _save();
  }

  Future<void> _edit(Map<String, dynamic> channel) async {
    _name.text = channel['name']?.toString() ?? '';
    _description.text = channel['description']?.toString() ?? '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit channel'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true || _name.text.trim().isEmpty) return;
    setState(() {
      channel['name'] = _name.text.trim();
      channel['description'] = _description.text.trim();
      channel['kind'] = 'My Channel';
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Channels'),
          actions: [
            IconButton(
              onPressed: () => _add(),
              icon: const Icon(Icons.add),
              tooltip: 'Create channel',
            ),
          ],
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('My Channels',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Curate movies and shows from your own library.'),
                  if (_channels.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Start with a channel template:'),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presets
                        .map((preset) => ActionChip(
                              avatar: Text(preset['icon']!),
                              label: Text(preset['name']!),
                              onPressed: () => _add(preset: preset),
                            ))
                        .toList(),
                  ),
                  ..._channels.map(_channelTile),
                  const SizedBox(height: 20),
                ],
              ),
      );

  Widget _channelTile(Map<String, dynamic> channel) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.tv)),
          title: Text(channel['name']?.toString() ?? 'Channel'),
          subtitle: Text(
            '${channel['kind'] ?? 'My Channel'} · ${channel['description'] ?? ''}',
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                await _edit(channel);
              } else if (value == 'delete') {
                setState(() => _channels.remove(channel));
                await _save();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      );
}

/// Horizontal Home row linking to the channel manager. Each channel tile also
/// publishes its identity to the pinned Home hero while it is hovered.
class HomeChannelsSection extends StatelessWidget {
  const HomeChannelsSection({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Channels',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const ChannelCenterScreen()),
                  ),
                  child: const Text('Manage'),
                ),
              ],
            ),
            SizedBox(
              height: 148,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _tile(context, 'My Channels', 'Curated library',
                      Icons.video_library_rounded),
                  _tile(context, 'Superhero Channel', 'Movies & series',
                      Icons.shield_rounded),
                  _tile(context, 'Comedy Channel', 'Movies & series',
                      Icons.theater_comedy_rounded),
                  _tile(context, 'Horror Channel', 'Movies & series',
                      Icons.movie_filter_rounded),
                ],
              ),
            ),
          ],
        ),
      );

  String? _channelArtwork(String title) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final library = controller.library
        .where((media) => media.isAccessibleTo(profile))
        .toList(growable: false);
    final lower = title.toLowerCase();
    final terms = lower.contains('superhero')
        ? const <String>['superhero', 'marvel', 'dc', 'comic', 'super hero']
        : lower.contains('comedy')
            ? const <String>['comedy', 'sitcom', 'funny', 'humor']
            : lower.contains('horror')
                ? const <String>['horror', 'scary', 'thriller', 'ghost']
                : const <String>[];
    String searchText(MediaItem item) => <String>[
          item.title,
          item.description ?? '',
          ...item.genres,
          ...item.tags,
          if (item.franchiseName?.trim().isNotEmpty == true)
            item.franchiseName!,
        ].join(' ').toLowerCase();
    if (terms.isNotEmpty) {
      for (final media in library) {
        if (media.imageUrl?.trim().isNotEmpty == true &&
            terms.any(searchText(media).contains)) {
          return media.imageUrl;
        }
      }
    }
    for (final media in library) {
      if (media.imageUrl?.trim().isNotEmpty == true) return media.imageUrl;
    }
    return null;
  }

  Widget _tile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final normalized =
        title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final preview = MediaItem(
      id: 'home-channel-$normalized',
      title: title,
      type: 'channel',
      imageUrl: _channelArtwork(title),
      description: subtitle,
      tags: <String>[
        'Channel',
        if (title.toLowerCase().contains('tv')) 'Television'
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: HomeHeroHoverPreviewRegion(
        media: preview,
        child: SizedBox(
          width: 164,
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const ChannelCenterScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 30),
                    const SizedBox(height: 8),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
