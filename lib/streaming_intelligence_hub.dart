import 'dart:async';

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'ai_operations_center.dart';
import 'coming_soon_release_screen.dart';
import 'details.dart';
import 'franchise_universe_browse_hub.dart';
import 'library_protection_center.dart';
import 'music.dart';
import 'perfect_streaming_experience.dart';
import 'profiles.dart';
import 'public_live_tv.dart';
import 'smart_search.dart';
import 'xray.dart';
import 'collection_details.dart';

/// A single entry point for the platform's discovery, library, profile and
/// playback features. These links deliberately reuse the existing screens and
/// services so they keep the same profile and provider rules as the rest of
/// the application.
class StreamingIntelligenceHubScreen extends StatelessWidget {
  const StreamingIntelligenceHubScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  List<MediaItem> _visibleLibrary() {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    return controller.library
        .where((item) => profile == null || item.isAccessibleTo(profile))
        .toList(growable: false);
  }

  void _chooseTitle(BuildContext context, {required bool xray}) {
    final items = _visibleLibrary();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your accessible library is empty. Import or connect media first.'),
        ),
      );
      return;
    }
    _open(context, _MediaTargetPickerScreen(items: items, openXRay: xray));
  }

  void _chooseCollection(BuildContext context) {
    final collections = AppController.instance.collections.toList(growable: false);
    if (collections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No collections are available for this account yet.')),
      );
      return;
    }
    _open(context, _CollectionTargetPickerScreen(collections: collections));
  }

  @override
  Widget build(BuildContext context) {
    final library = _visibleLibrary();
    final movies = library.where((item) => !item.isSeries && !_isMusic(item)).length;
    final shows = library.where((item) => item.isSeries).length;
    final music = library.where(_isMusic).length;
    final withBonus = library.where((item) =>
        item.extras.isNotEmpty || item.chapters.isNotEmpty ||
        item.audioTracks.isNotEmpty || item.subtitles.isNotEmpty).length;
    final currentProfile = AppController.instance.currentProfile?.name ?? 'Default profile';

    return Scaffold(
      appBar: AppBar(title: const Text('Streaming Intelligence Hub')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xff252143), Color(0xff111722)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 32),
                const SizedBox(height: 10),
                Text('One platform. One connected experience.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text('Quick access for $currentProfile. The counts below come from the local, profile-accessible catalog.',
                    style: const TextStyle(color: Colors.white70, height: 1.4)),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _HubMetric(label: 'Library items', value: '${library.length}', icon: Icons.video_library_outlined),
                  _HubMetric(label: 'Movies', value: '$movies', icon: Icons.movie_outlined),
                  _HubMetric(label: 'Series', value: '$shows', icon: Icons.live_tv_outlined),
                  _HubMetric(label: 'Music', value: '$music', icon: Icons.music_note_rounded),
                  _HubMetric(label: 'Items with extras', value: '$withBonus', icon: Icons.library_add_outlined),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle(context, 'The 9 core upgrades', 'Use the features together rather than navigating disconnected screens.'),
          _HubTile(
            icon: Icons.event_available_rounded,
            title: '1. Coming Soon & Release Calendar',
            description: 'Movie, series, episode, album and physical-media dates, plus saved reminders.',
            onTap: () => _open(context, const ComingSoonReleaseScreen()),
          ),
          _HubTile(
            icon: Icons.movie_filter_rounded,
            title: '2. Personalized Streaming Experience',
            description: 'Profile-level discovery, playback continuity, seasons and Live TV preferences.',
            onTap: () => _open(context, const PerfectStreamingExperienceScreen()),
          ),
          _HubTile(
            icon: Icons.info_outline_rounded,
            title: '3. Movie, Show & Episode Metadata',
            description: 'Open title details, seasons, episode data, credits, release dates, editions and extras.',
            onTap: () => _chooseTitle(context, xray: false),
          ),
          _HubTile(
            icon: Icons.album_rounded,
            title: '4. Music Intelligence',
            description: 'Open music, albums and artist pages backed by the current music catalog and library.',
            onTap: () => _open(context, const MusicScreen()),
          ),
          _HubTile(
            icon: Icons.manage_search_rounded,
            title: '5. Universal Smart Search',
            description: 'Search your accessible library, alternate titles, people and available discovery metadata.',
            onTap: () => _open(context, const SmartSearchScreen()),
          ),
          _HubTile(
            icon: Icons.live_tv_rounded,
            title: '6. Live TV Guide',
            description: 'Browse channels, filter by category and save profile-specific channel favorites.',
            onTap: () => _open(context, const PublicLiveTvScreen()),
          ),
          _HubTile(
            icon: Icons.fact_check_outlined,
            title: '7. Library Intelligence & Quality',
            description: 'Review metadata gaps, local extras, edition data and possible duplicate candidates.',
            onTap: () => _open(context, const LibraryIntelligenceScreen()),
          ),
          _HubTile(
            icon: Icons.people_alt_rounded,
            title: '8. Profiles & Collections',
            description: 'Switch profiles or open a shared, custom or automatic collection.',
            onTap: () => _openProfileAndCollections(context),
            trailingAction: IconButton(
              tooltip: 'Browse collections',
              onPressed: () => _chooseCollection(context),
              icon: const Icon(Icons.collections_bookmark_outlined),
            ),
          ),
          _HubTile(
            icon: Icons.health_and_safety_outlined,
            title: '9. Reliability & Automation',
            description: 'Inspect actual operations events, library repair findings, backups and recovery points.',
            onTap: () => _open(context, const AiOperationsCenterScreen()),
            trailingAction: IconButton(
              tooltip: 'Open library protection and backups',
              onPressed: () => _open(context, const LibraryProtectionCenterScreen()),
              icon: const Icon(Icons.backup_outlined),
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle(context, 'Standout experiences', 'Built around the existing player, metadata and franchise systems.'),
          _HubTile(
            icon: Icons.person_search_rounded,
            title: 'X-Ray & Cast/Crew Context',
            description: 'Explore cast, crew, music, notes and connected facts. The player-launched X-Ray remains linked to live playback position.',
            onTap: () => _chooseTitle(context, xray: true),
          ),
          _HubTile(
            icon: Icons.account_tree_rounded,
            title: 'Franchise & Cinematic Universe Mode',
            description: 'Browse franchise timelines, universe connections and available watch-order tools.',
            onTap: () => _open(context, const FranchiseUniverseBrowseHubScreen(mode: FranchiseUniverseBrowseMode.franchises)),
            trailingAction: IconButton(
              tooltip: 'Browse cinematic universes',
              onPressed: () => _open(context, const FranchiseUniverseBrowseHubScreen(mode: FranchiseUniverseBrowseMode.universes)),
              icon: const Icon(Icons.hub_outlined),
            ),
          ),
          _HubTile(
            icon: Icons.tune_rounded,
            title: 'Premium Playback Preferences',
            description: 'Manage playback continuity and supported player options; source-specific audio/subtitle data stays with the media.',
            onTap: () => _open(context, const PerfectStreamingExperienceScreen()),
          ),
          const SizedBox(height: 12),
          const Text(
            'Provider-dependent dates, metadata and recommendations can be incomplete or delayed. Local media and saved profile preferences remain available when an external provider is offline; this hub does not claim that a stream or provider is live unless its existing integration reports it.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }

  void _openProfileAndCollections(BuildContext context) {
    _open(context, const ProfileSelectionScreen());
  }

  static bool _isMusic(MediaItem item) {
    final type = item.type.toLowerCase();
    return type.contains('music') || type.contains('album') ||
        type.contains('song') || type.contains('track') || type.contains('audio');
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: Colors.white60, height: 1.35)),
    ]),
  );
}

class LibraryIntelligenceScreen extends StatefulWidget {
  const LibraryIntelligenceScreen({super.key});

  @override
  State<LibraryIntelligenceScreen> createState() => _LibraryIntelligenceScreenState();
}

class _LibraryIntelligenceScreenState extends State<LibraryIntelligenceScreen> {
  String _filter = 'All';
  String _query = '';

  List<MediaItem> get _items {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final all = controller.library.where((item) => profile == null || item.isAccessibleTo(profile));
    final query = _query.trim().toLowerCase();
    return all.where((item) {
      final music = _isMusic(item);
      final needsMetadata = _needsMetadata(item);
      final hasExtras = item.extras.isNotEmpty || item.chapters.isNotEmpty || item.audioTracks.isNotEmpty || item.subtitles.isNotEmpty;
      final include = switch (_filter) {
        'Needs metadata' => needsMetadata,
        'Series' => item.isSeries,
        'Bonus & technical data' => hasExtras,
        'Music' => music,
        _ => true,
      };
      if (!include) return false;
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          (item.originalTitle?.toLowerCase().contains(query) ?? false) ||
          item.actors.any((person) => person.toLowerCase().contains(query)) ||
          item.directors.any((person) => person.toLowerCase().contains(query));
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  static bool _isMusic(MediaItem item) {
    final type = item.type.toLowerCase();
    return type.contains('music') || type.contains('album') || type.contains('song') || type.contains('track') || type.contains('audio');
  }

  static bool _needsMetadata(MediaItem item) {
    final noArtwork = item.imageUrl?.trim().isNotEmpty != true;
    final noDescription = item.description?.trim().isNotEmpty != true;
    final noDate = item.isSeries
        ? item.seriesStartDate == null && item.seriesStartYear == null && item.releaseYear == null
        : item.releaseDate == null && item.releaseYear == null;
    final noPeople = !_isMusic(item) && item.actors.isEmpty && item.directors.isEmpty && item.writers.isEmpty;
    final noSeasonData = item.isSeries && item.seasons.isEmpty;
    return noArtwork || noDescription || noDate || noPeople || noSeasonData;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final all = controller.library.where((item) => profile == null || item.isAccessibleTo(profile)).toList(growable: false);
    final items = _items;
    final metadataGaps = all.where(_needsMetadata).length;
    final seriesWithoutSeasonData = all.where((item) => item.isSeries && item.seasons.isEmpty).length;
    final withLocalExtras = all.where((item) => item.extras.isNotEmpty || item.chapters.isNotEmpty || item.audioTracks.isNotEmpty || item.subtitles.isNotEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Intelligence'),
        actions: [
          IconButton(
            tooltip: 'Open duplicate review and backups',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const LibraryProtectionCenterScreen(initialTabIndex: 1))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Catalog health', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('This is a review checklist, not a claim that media files are broken. Missing fields may simply mean the source did not provide them.', style: TextStyle(color: Colors.white60, height: 1.4)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _HubMetric(label: 'Accessible items', value: '${all.length}', icon: Icons.video_library_outlined),
                  _HubMetric(label: 'Metadata review', value: '$metadataGaps', icon: Icons.info_outline_rounded),
                  _HubMetric(label: 'Series without seasons', value: '$seriesWithoutSeasonData', icon: Icons.live_tv_outlined),
                  _HubMetric(label: 'With extras/tracks', value: '$withLocalExtras', icon: Icons.library_add_outlined),
                ]),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const LibraryProtectionCenterScreen(initialTabIndex: 2))),
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('Open repair queue & backup center'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(labelText: 'Find title, original title or credited person', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _filter,
            decoration: const InputDecoration(labelText: 'Review category', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All accessible media')),
              DropdownMenuItem(value: 'Needs metadata', child: Text('Needs metadata review')),
              DropdownMenuItem(value: 'Series', child: Text('Series & seasons')),
              DropdownMenuItem(value: 'Bonus & technical data', child: Text('Bonus & technical data')),
              DropdownMenuItem(value: 'Music', child: Text('Music')),
            ],
            onChanged: (value) => setState(() => _filter = value ?? 'All'),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No titles match this review filter. Try another category or import/connect more media.')))
          else ...items.map((item) => _LibraryIntelligenceTile(item: item, onOpen: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: item))))),
          const SizedBox(height: 12),
          const Text('Potential duplicates are not auto-merged or deleted. Use the duplicate review tab to inspect candidates before making changes.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

class _MediaTargetPickerScreen extends StatelessWidget {
  const _MediaTargetPickerScreen({required this.items, required this.openXRay});
  final List<MediaItem> items;
  final bool openXRay;

  Future<void> _openXRay(BuildContext context, MediaItem item) async {
    final position = ValueNotifier<Duration>(Duration.zero);
    try {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => XRayScreen(media: item, playbackPosition: position),
      ));
    } finally {
      position.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(openXRay ? 'Choose a title for X-Ray' : 'Choose a title to inspect')),
    body: ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: const Icon(Icons.movie_outlined),
          title: Text(item.title),
          subtitle: Text('${item.type}${item.releaseYear == null ? '' : ' • ${item.releaseYear}'}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            if (!openXRay) {
              Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: item)));
              return;
            }
            unawaited(_openXRay(context, item));
          },
        );
      },
    ),
  );
}

class _CollectionTargetPickerScreen extends StatelessWidget {
  const _CollectionTargetPickerScreen({required this.collections});
  final List<MediaCollection> collections;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose a collection')),
    body: ListView.builder(
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final collection = collections[index];
        return ListTile(
          leading: const Icon(Icons.collections_bookmark_outlined),
          title: Text(collection.name),
          subtitle: Text('${collection.mediaIds.length} item(s)${collection.description.trim().isEmpty ? '' : ' • ${collection.description}'}'),
          onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => CollectionDetailsScreen(collection: collection))),
        );
      },
    ),
  );
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.icon, required this.title, required this.description, required this.onTap, this.trailingAction});
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 9),
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(description, style: const TextStyle(height: 1.35))),
      trailing: trailingAction ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
      isThreeLine: true,
    ),
  );
}

class _HubMetric extends StatelessWidget {
  const _HubMetric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: Colors.white70),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ]),
    ]),
  );
}

class _LibraryIntelligenceTile extends StatelessWidget {
  const _LibraryIntelligenceTile({required this.item, required this.onOpen});
  final MediaItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isMusic = _typeIsMusic(item.type);
    final flags = <String>[];
    if (item.imageUrl?.trim().isNotEmpty != true) flags.add('No artwork');
    if (item.description?.trim().isNotEmpty != true) flags.add('No description');
    final hasDate = item.isSeries
        ? item.seriesStartDate != null || item.seriesStartYear != null || item.releaseYear != null
        : item.releaseDate != null || item.releaseYear != null;
    if (!hasDate) flags.add('No release date/year');
    if (!isMusic && item.actors.isEmpty && item.directors.isEmpty && item.writers.isEmpty) flags.add('No cast/crew indexed');
    if (item.isSeries && item.seasons.isEmpty) flags.add('No season data indexed');
    final indexedDetails = <String>[];
    if (item.extras.isNotEmpty) indexedDetails.add('${item.extras.length} extras');
    if (item.chapters.isNotEmpty) indexedDetails.add('${item.chapters.length} chapters');
    if (item.audioTracks.isNotEmpty) indexedDetails.add('${item.audioTracks.length} audio tracks');
    if (item.subtitles.isNotEmpty) indexedDetails.add('${item.subtitles.length} subtitle tracks');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: item.imageUrl?.trim().isNotEmpty == true
            ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(item.imageUrl!, width: 44, height: 62, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 62, child: Icon(Icons.movie_outlined))) )
            : const SizedBox(width: 44, height: 62, child: Icon(Icons.movie_outlined)),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${item.type}${item.releaseYear == null ? '' : ' • ${item.releaseYear}'}'),
          if (flags.isNotEmpty) Text('Review: ${flags.join(' · ')}', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
          if (indexedDetails.isNotEmpty) Text('Indexed: ${indexedDetails.join(' · ')}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          if (item.editionName?.trim().isNotEmpty == true) Text('Edition: ${item.editionName}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ])),
        trailing: const Icon(Icons.chevron_right_rounded),
        isThreeLine: true,
        onTap: onOpen,
      ),
    );
  }

  static bool _typeIsMusic(String type) {
    final value = type.toLowerCase();
    return value.contains('music') || value.contains('album') || value.contains('song') || value.contains('track') || value.contains('audio');
  }
}
