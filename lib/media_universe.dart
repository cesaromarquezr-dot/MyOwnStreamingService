// FILE: `lib/media_universe.dart`.
// Purpose: Provides the unified Media Universe, intelligence dashboards,
// Surprise Me, session management, library health, artwork and exploration UI.

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'app_core.dart';

class MediaUniverseScreen extends StatefulWidget {
  const MediaUniverseScreen({super.key});

  @override
  State<MediaUniverseScreen> createState() => _MediaUniverseScreenState();
}

class _MediaUniverseScreenState extends State<MediaUniverseScreen> {
  String query = '';

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final filtered = library.where((item) =>
        query.trim().isEmpty || item.title.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Media Universe')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Explore your entire media universe'),
          ),
          const SizedBox(height: 18),
          _heroCard(),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _tile('Surprise Me', Icons.shuffle_rounded, () => _open(context, const SurpriseMeScreen())),
              _tile('Devices & Sessions', Icons.devices_rounded, () => _open(context, const MediaSessionsScreen())),
              _tile('Library Health', Icons.health_and_safety_outlined, () => _open(context, const LibraryHealthScreen())),
              _tile('Artwork Library', Icons.photo_library_outlined, () => _open(context, const MediaArtworkScreen())),
              _tile('AI Media Lab', Icons.auto_awesome_rounded, () => _open(context, const MediaAiLabScreen())),
              _tile('My Media Passport', Icons.badge_outlined, () => _open(context, const MediaPassportScreen())),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Explore Media', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            const _EmptyUniverse()
          else
            ...filtered.take(20).map((item) => _MediaUniverseCard(item: item)),
        ],
      ),
    );
  }

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(colors: [Colors.red.withValues(alpha: .30), Colors.purple.withValues(alpha: .18)]),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.hub_rounded, size: 42),
          SizedBox(height: 12),
          Text('Your Media Universe', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          SizedBox(height: 7),
          Text('Movies, shows, songs, albums, people, characters, franchises, extras, artwork and your personal history connected in one place.', style: TextStyle(color: Colors.white70, height: 1.4)),
        ]),
      );

  Widget _tile(String title, IconData icon, VoidCallback onTap) => ActionChip(
        avatar: Icon(icon, size: 18), label: Text(title), onPressed: onTap,
      );
}

class _MediaUniverseCard extends StatelessWidget {
  final MediaItem item;
  const _MediaUniverseCard({required this.item});
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: _Artwork(imageUrl: item.imageUrl),
          title: Text(item.title),
          subtitle: Text('${item.type}${item.releaseYear == null ? '' : ' • ${item.releaseYear}'}'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPassportItemScreen(item: item))),
        ),
      );
}

class SurpriseMeScreen extends StatefulWidget {
  const SurpriseMeScreen({super.key});
  @override
  State<SurpriseMeScreen> createState() => _SurpriseMeScreenState();
}
class _SurpriseMeScreenState extends State<SurpriseMeScreen> {
  final Random random = Random();
  MediaItem? selected;
  String mode = 'Random Everything';
  void pick() {
    final library = AppController.instance.library;
    if (library.isEmpty) return;
    final candidates = mode == 'Random Everything' ? library : library.where((m) => _matches(m, mode)).toList();
    if (candidates.isEmpty) { setState(() => selected = library[random.nextInt(library.length)]); return; }
    setState(() => selected = candidates[random.nextInt(candidates.length)]);
  }
  bool _matches(MediaItem m, String value) {
    if (value == 'Movies') return m.type.toLowerCase().contains('movie') || m.type.toLowerCase().contains('film');
    if (value == 'TV Episodes') return m.type.toLowerCase().contains('episode') || m.seasons.isNotEmpty;
    if (value == 'Music') return ['song', 'album', 'music', 'track'].any(m.type.toLowerCase().contains);
    if (value == 'Physical') return m.discType != null || m.discCollectionId != null;
    return true;
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Surprise Me')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('True Random', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Random Everything intentionally crosses movies, episodes, songs, albums, music videos and extras.'),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(initialValue: mode, items: const [
        DropdownMenuItem(value: 'Random Everything', child: Text('Random Everything')),
        DropdownMenuItem(value: 'Movies', child: Text('Movies')),
        DropdownMenuItem(value: 'TV Episodes', child: Text('TV Episodes')),
        DropdownMenuItem(value: 'Music', child: Text('Music')),
        DropdownMenuItem(value: 'Physical', child: Text('Something I Own Physically')),
      ], onChanged: (v) => setState(() => mode = v ?? mode), decoration: const InputDecoration(labelText: 'Mode')),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: pick, icon: const Icon(Icons.shuffle_rounded), label: const Text('SURPRISE ME')),
      const SizedBox(height: 24),
      if (selected != null) Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        _Artwork(imageUrl: selected!.imageUrl, size: 180), const SizedBox(height: 14),
        Text(selected!.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        Text(selected!.type, style: const TextStyle(color: Colors.white60)), const SizedBox(height: 12),
        const Text('This selection was chosen from the eligible library items. No taste ranking was used.'),
        const SizedBox(height: 12), OutlinedButton(onPressed: pick, child: const Text('SHUFFLE AGAIN')),
      ])))
    ]),
  );
}

class MediaSessionsScreen extends StatelessWidget {
  const MediaSessionsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Devices & Sessions')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      _sessionCard('Living Room TV', 'TV', 'Playing Jurassic Park', true),
      _sessionCard('Phone', 'Phone', 'Listening to music', true),
      _sessionCard('Bedroom PC', 'Desktop', 'Browsing library', false),
      const SizedBox(height: 18),
      const Text('A profile can have multiple independent sessions. Starting playback on one device does not hijack another session.', style: TextStyle(color: Colors.white60)),
    ]),
  );
  Widget _sessionCard(String name, String type, String activity, bool active) => Card(child: ListTile(
    leading: Icon(type == 'TV' ? Icons.tv : type == 'Phone' ? Icons.phone_android : Icons.computer),
    title: Text(name), subtitle: Text(activity), trailing: Icon(active ? Icons.circle : Icons.circle_outlined, size: 12),
  ));
}

class LibraryHealthScreen extends StatelessWidget {
  const LibraryHealthScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final missingArtwork = library.where((m) => m.imageUrl == null || m.imageUrl!.isEmpty).length;
    final physical = library.where((m) => m.discType != null).length;
    return Scaffold(appBar: AppBar(title: const Text('Library Health')), body: ListView(padding: const EdgeInsets.all(18), children: [
      _metric('Media items', '${library.length}', Icons.video_library_outlined),
      _metric('Missing artwork', '$missingArtwork', Icons.image_not_supported_outlined),
      _metric('Physical imports', '$physical', Icons.album_outlined),
      _metric('Relationships', 'Ready for graph sync', Icons.account_tree_outlined),
      const SizedBox(height: 16),
      const Text('Library Detective', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Future checks include duplicates, edition conflicts, incomplete seasons, missing artwork, missing relationships and uncertain ARM identification. Nothing is deleted automatically.'),
    ]));
  }
  Widget _metric(String title, String value, IconData icon) => Card(child: ListTile(leading: Icon(icon), title: Text(title), trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))));
}

class MediaArtworkScreen extends StatefulWidget {
  const MediaArtworkScreen({super.key});
  @override
  State<MediaArtworkScreen> createState() => _MediaArtworkScreenState();
}
class _MediaArtworkScreenState extends State<MediaArtworkScreen> {
  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library.where((m) => m.imageUrl != null && m.imageUrl!.isNotEmpty).toList();
    final profile = AppController.instance.currentProfile;
    return Scaffold(appBar: AppBar(title: const Text('My Artwork')), body: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Artwork from your media', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('ARM can classify disc/poster/booklet artwork and make approved images available for profile pictures.'),
      const SizedBox(height: 18),
      ...library.map((media) => Card(child: ListTile(
        leading: _Artwork(imageUrl: media.imageUrl), title: Text(media.title), subtitle: Text(media.discType == null ? 'Library artwork' : 'Disc artwork candidate'),
        trailing: FilledButton(
  onPressed: profile == null
      ? null
      : () async {
          profile.avatarUrl = media.imageUrl;

          if (AppController.instance.isBackendAuthenticated) {
            try {
              await AppController.instance.backendApi.updateProfile(
                profileId: profile.id,
                name: profile.name,
                avatarUrl: media.imageUrl,
              );
            } catch (_) {}
          }

          if (mounted) {
            setState(() {});
          }
        },
  child: const Text('USE'),
),
      ))),
    ]));
  }
}

class MediaAiLabScreen extends StatelessWidget {
  const MediaAiLabScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AI Media Lab')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: const [
            _AiPrompt('What should I watch tonight?', 'Uses your history, availability and explainable media relationships.'),
            _AiPrompt('Why do I like this?', 'Explains patterns from your own watched/listened history.'),
            _AiPrompt('Find things connected to this.', 'Traverses people, songs, albums, franchises, extras and geographic associations.'),
            _AiPrompt('Complete my collection.', 'Finds missing pieces without silently buying, downloading or deleting anything.'),
            _AiPrompt('Build a media night.', 'Can combine a movie, soundtrack, extras and related content into one session.'),
          ],
        ),
      );
}
class _AiPrompt extends StatelessWidget {
  final String title; final String description;
  const _AiPrompt(this.title, this.description);
  @override Widget build(BuildContext context) => Card(child: ListTile(leading: const Icon(Icons.auto_awesome), title: Text(title), subtitle: Text(description)));
}

class MediaPassportScreen extends StatelessWidget {
  const MediaPassportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppController.instance;
    return Scaffold(appBar: AppBar(title: const Text('My Media Passport')), body: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Your relationship with media', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 12),
      _row('Library items', '${c.library.length}'), _row('Watched', '${c.watched.length}'), _row('Liked', '${c.liked.length}'), _row('Collections', '${c.collections.length}'), _row('Profiles', '${c.currentAccount?.profiles.length ?? 0}'),
      const SizedBox(height: 20), const Text('This is private personal history. Importing, watching and listening remain separate events.'),
    ]));
  }
  Widget _row(String a, String b) => Card(child: ListTile(title: Text(a), trailing: Text(b, style: const TextStyle(fontWeight: FontWeight.w800))));
}

class MediaPassportItemScreen extends StatelessWidget {
  final MediaItem item;
  const MediaPassportItemScreen({super.key, required this.item});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(item.title)),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Center(child: _Artwork(imageUrl: item.imageUrl, size: 220)),
            const SizedBox(height: 16),
            Text(item.title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            Text(item.type),
            const SizedBox(height: 18),
            _info('Imported', item.addedAt.toLocal().toString()),
            _info('Physical source', item.discType ?? 'Not recorded'),
            _info('Country association', item.countryOfOrigin ?? 'Not recorded'),
            _info('Original language', item.originalLanguage ?? 'Not recorded'),
            _info('Music connections', '${item.music.length}'),
            _info('Extras', '${item.extras.length}'),
            _info('Actors', '${item.actors.length}'),
          ],
        ),
      );

  Widget _info(String a, String b) => Card(child: ListTile(title: Text(a), subtitle: Text(b)));
}

class _Artwork extends StatelessWidget {
  final String? imageUrl; final double size;
  const _Artwork({this.imageUrl, this.size = 52});
  @override Widget build(BuildContext context) {
    final value = imageUrl;
    if (value != null && value.startsWith('http')) return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(value, width: size, height: size, fit: BoxFit.cover));
    if (value != null && value.isNotEmpty && File(value).existsSync()) return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(value), width: size, height: size, fit: BoxFit.cover));
    return Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.image_outlined));
  }
}
class _EmptyUniverse extends StatelessWidget { const _EmptyUniverse(); @override Widget build(BuildContext context) => const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Your Media Universe will populate as media is imported or added to the library.'))); }
