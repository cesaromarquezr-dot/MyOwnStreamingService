import 'package:material_ui/material_ui.dart';

import 'actor_connections.dart';
import 'app_core.dart';
import 'cinematic_discovery_studio.dart';
import 'disc_ingestion_center.dart';
import 'media_health_screen.dart';
import 'media_knowledge.dart';
import 'media_universe.dart';
import 'music.dart';
import 'performer_universe.dart';
import 'physical_media_library.dart';
import 'playback_queue.dart';
import 'personal_media_intelligence_center.dart';
import 'profiles.dart';
import 'profiles_permissions_hub.dart';
import 'screens/smart_media_import_center_screen.dart';
import 'song_identification_screen.dart';
import 'watch_history_calendar.dart';

/// A connected launch surface for the project's existing entertainment
/// intelligence capabilities. This screen deliberately reuses the canonical
/// feature owners rather than keeping its own copies of their data.
class EntertainmentUniverseHubScreen extends StatefulWidget {
  const EntertainmentUniverseHubScreen({super.key});

  @override
  State<EntertainmentUniverseHubScreen> createState() =>
      _EntertainmentUniverseHubScreenState();
}

class _EntertainmentUniverseHubScreenState
    extends State<EntertainmentUniverseHubScreen> {
  final TextEditingController _personController = TextEditingController();

  @override
  void dispose() {
    _personController.dispose();
    super.dispose();
  }

  String _cleanPersonQuery() => _personController.text.trim();

  void _requirePerson(
    BuildContext context,
    Widget Function(String name) page, {
    required String route,
  }) {
    final name = _cleanPersonQuery();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a person or artist name first.')),
      );
      return;
    }
    _open(context, page(name), route);
  }

  void _open(BuildContext context, Widget page, String route) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: RouteSettings(name: route),
      builder: (_) => page,
    ));
  }

  List<String> _knownPeople() {
    final controller = AppController.instance;
    final names = <String, String>{};
    void add(String raw) {
      final value = raw.trim();
      if (value.isEmpty) return;
      final key = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      names.putIfAbsent(key, () => value);
    }

    for (final media in controller.library) {
      if (!media.isAccessibleTo(controller.currentProfile)) continue;
      for (final person in <String>[
        ...media.actors,
        ...media.directors,
        ...media.writers,
        ...media.music,
      ]) {
        add(person);
      }
    }
    final store = MusicLibraryStore.instance;
    for (final track in <MusicTrack>[
      ...store.tracks,
      ...store.catalogTracks.values,
    ]) {
      add(track.artist);
      for (final featuredArtist in track.featuredArtists) {
        add(featuredArtist);
      }
    }
    final result = names.values.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  Future<void> _openKnowledgePicker(BuildContext context) async {
    final controller = AppController.instance;
    final media = controller.library
        .where((item) => item.isAccessibleTo(controller.currentProfile))
        .toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    if (media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import or add a library title before opening its knowledge page.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<MediaItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .72,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose a title for Media Knowledge',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: media.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = media[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.auto_stories_rounded),
                      ),
                      title: Text(item.title),
                      subtitle: Text(item.type),
                      onTap: () => Navigator.of(sheetContext).pop(item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || selected == null) return;
    _open(
      context,
      MediaKnowledgeScreen(
        mediaWorkId: selected.id,
        mediaTitle: selected.title,
      ),
      '/app/media-knowledge/${Uri.encodeComponent(selected.id)}',
    );
  }

  Widget _stat({
    required String label,
    required String value,
    required IconData icon,
  }) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF171C29),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF9FB5FF), size: 19),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w900)),
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
      );

  Widget _actionCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) => Card(
        color: const Color(0xFF151A25),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(description,
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              height: 1.3)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54),
              ],
            ),
          ),
        ),
      );

  Widget _sectionTitle(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final music = MusicLibraryStore.instance;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[controller, music]),
      builder: (context, _) {
        final ownedMedia = controller.library
            .where((item) => item.isAccessibleTo(controller.currentProfile))
            .toList(growable: false);
        final ownedTracks = music.tracks
            .where((track) => !track.catalogOnly)
            .toList(growable: false);
        final artists = <String>{};
        for (final track in <MusicTrack>[
          ...ownedTracks,
          ...music.catalogTracks.values,
        ]) {
          if (track.artist.trim().isNotEmpty) artists.add(track.artist.trim());
          artists.addAll(track.featuredArtists.map((name) => name.trim()).where((name) => name.isNotEmpty));
        }
        final people = _knownPeople();
        final physicalItems = ownedMedia
            .where((item) => (item.discType?.trim() ?? '').isNotEmpty)
            .length;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0D14),
          appBar: AppBar(
            title: const Text('Entertainment Universe'),
            backgroundColor: const Color(0xFF111522),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            children: [
              const Text(
                'One connected place for your people, artists, music, physical collection, personal discovery and library tools. Each destination opens the existing feature that owns its data.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(children: [
                _stat(
                  label: 'Accessible library titles',
                  value: ownedMedia.length.toString(),
                  icon: Icons.movie_creation_outlined,
                ),
                const SizedBox(width: 8),
                _stat(
                  label: 'Imported music tracks',
                  value: ownedTracks.length.toString(),
                  icon: Icons.library_music_rounded,
                ),
                const SizedBox(width: 8),
                _stat(
                  label: 'Recorded disc items',
                  value: physicalItems.toString(),
                  icon: Icons.album_rounded,
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                '${people.length} indexed people · ${artists.length} artist names discovered',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              _sectionTitle(
                'Artist, Actor & People Universes',
                'Open a unified career page or explore a verifiable connection between people',
              ),
              TextField(
                controller: _personController,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _requirePerson(
                  context,
                  (name) => PerformerUniverseScreen(performerName: name),
                  route: '/app/page/performer-universe',
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF171C29),
                  prefixIcon: const Icon(Icons.person_search_rounded),
                  labelText: 'Search an actor, actress, artist, band or creator',
                  hintText: 'e.g. Florence Pugh or AC/DC',
                  suffixIcon: IconButton(
                    tooltip: 'Open universal people page',
                    onPressed: () => _requirePerson(
                      context,
                      (name) => PerformerUniverseScreen(performerName: name),
                      route: '/app/page/performer-universe',
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              if (people.isNotEmpty) ...[
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: people
                      .where((name) => _personController.text.trim().isEmpty ||
                          name.toLowerCase().contains(
                              _personController.text.trim().toLowerCase()))
                      .take(10)
                      .map((name) => ActionChip(
                            label: Text(name),
                            onPressed: () => setState(() {
                              _personController.text = name;
                            }),
                          ))
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 10),
              _actionCard(
                context: context,
                title: 'Artist Universe',
                description: 'Songs, albums, discography, videos, features and related artists',
                icon: Icons.mic_external_on_rounded,
                accent: const Color(0xFFFFB6D5),
                onTap: () => _requirePerson(
                  context,
                  (name) => MusicArtistProfileScreen(artistName: name),
                  route: '/app/music/artist-universe',
                ),
              ),
              _actionCard(
                context: context,
                title: 'Actor & Actress Universe',
                description: 'Filmography, TV credits, soundtrack work and complete career context',
                icon: Icons.theater_comedy_rounded,
                accent: const Color(0xFF9DB7FF),
                onTap: () => _requirePerson(
                  context,
                  (name) => PerformerUniverseScreen(performerName: name),
                  route: '/app/people/performer-universe',
                ),
              ),
              _actionCard(
                context: context,
                title: 'Relationship Explorer',
                description: 'Trace the shortest path through shared titles and explicit music collaborations',
                icon: Icons.account_tree_rounded,
                accent: const Color(0xFFA5E6CA),
                onTap: () => _requirePerson(
                  context,
                  (name) => ActorConnectionScreen(initialPerson: name),
                  route: '/app/people/relationships',
                ),
              ),
              _sectionTitle(
                'Identify & Collect',
                'Identify music, inspect your physical media and keep imports reviewed',
              ),
              _actionCard(
                context: context,
                title: 'Identify Music',
                description: 'Use the configured audio recognition provider to identify a song',
                icon: Icons.graphic_eq_rounded,
                accent: const Color(0xFFFFD28C),
                onTap: () => _open(
                  context,
                  const SongIdentificationScreen(),
                  '/app/identify-music',
                ),
              ),
              _actionCard(
                context: context,
                title: 'Physical Media Collector',
                description: 'DVD, CD, Blu-ray, 4K Ultra HD and disc/box-set collections',
                icon: Icons.album_rounded,
                accent: const Color(0xFFBFA8FF),
                onTap: () => _open(
                  context,
                  const PhysicalMediaLibraryScreen(),
                  '/app/physical-media-collector',
                ),
              ),
              _actionCard(
                context: context,
                title: 'Smart Media Import Center',
                description: 'Review disc ingestion, metadata matching and library readiness',
                icon: Icons.move_to_inbox_rounded,
                accent: const Color(0xFFFFB28C),
                onTap: () => _open(
                  context,
                  const SmartMediaImportCenterScreen(),
                  '/app/smart-media-import',
                ),
              ),
              _actionCard(
                context: context,
                title: 'ARM & Disc Ingestion',
                description: 'Inspect optical drives, ARM status and review disc titles before import',
                icon: Icons.disc_full_rounded,
                accent: const Color(0xFFFFA87D),
                onTap: () => _open(
                  context,
                  const DiscIngestionCenterScreen(),
                  '/app/arm-disc-ingestion',
                ),
              ),
              _sectionTitle(
                'Personal Intelligence',
                'Keep Home, profiles, calendar, queue and media knowledge connected',
              ),
              _actionCard(
                context: context,
                title: 'Home & Discovery Intelligence',
                description: 'Personal Media Intelligence, music memory and discovery tools',
                icon: Icons.auto_awesome_rounded,
                accent: const Color(0xFF9CC8FF),
                onTap: () => _open(
                  context,
                  const PersonalMediaIntelligenceCenterScreen(),
                  '/app/personal-media-intelligence',
                ),
              ),
              _actionCard(
                context: context,
                title: 'Profile Selection & Creation',
                description: 'Choose an existing profile or create a new personal profile',
                icon: Icons.manage_accounts_rounded,
                accent: const Color(0xFFB4D5FF),
                onTap: () => _open(
                  context,
                  const ProfileSelectionScreen(),
                  '/app/profile-selection',
                ),
              ),
              _actionCard(
                context: context,
                title: 'Profile Universe & Permissions',
                description: 'Profiles, household roles, permissions and profile-level controls',
                icon: Icons.family_restroom_rounded,
                accent: const Color(0xFFB4D5FF),
                onTap: () => _open(
                  context,
                  const ProfilesAndPermissionsHubScreen(),
                  '/app/profiles-universe',
                ),
              ),
              _actionCard(
                context: context,
                title: 'Entertainment Calendar',
                description: 'Watch/listen history by day and personal premiere reminders',
                icon: Icons.calendar_month_rounded,
                accent: const Color(0xFFB8E6A8),
                onTap: () => _open(
                  context,
                  const WatchHistoryCalendarScreen(),
                  '/app/entertainment-calendar',
                ),
              ),
              _actionCard(
                context: context,
                title: 'Premiere & Release Calendar',
                description: 'Upcoming release and premiere reminders',
                icon: Icons.event_available_rounded,
                accent: const Color(0xFFFFCC9E),
                onTap: () => _open(
                  context,
                  const PremiereCalendarScreen(),
                  '/app/premiere-calendar',
                ),
              ),
              _actionCard(
                context: context,
                title: 'Universal Playback Queue',
                description: 'Review, reorder and play profile-scoped queue entries',
                icon: Icons.queue_music_rounded,
                accent: const Color(0xFF8FDCE0),
                onTap: () => _open(
                  context,
                  const PlaybackQueueScreen(),
                  '/app/universal-queue',
                ),
              ),
              _actionCard(
                context: context,
                title: 'Media Knowledge Center',
                description: 'Open sourced facts and deep dives for a title in your library',
                icon: Icons.auto_stories_rounded,
                accent: const Color(0xFFE5C18D),
                onTap: () => _openKnowledgePicker(context),
              ),
              _actionCard(
                context: context,
                title: 'Library Health',
                description: 'Find missing metadata, artwork, playback sources and duplicates',
                icon: Icons.health_and_safety_rounded,
                accent: const Color(0xFF87D6B5),
                onTap: () => _open(
                  context,
                  const MediaHealthScreen(),
                  '/app/library-health',
                ),
              ),
              _actionCard(
                context: context,
                title: 'Media Relationship Universe',
                description: 'Explore franchise, story, edition and cross-media relationships',
                icon: Icons.hub_rounded,
                accent: const Color(0xFFB8B4FF),
                onTap: () => _open(
                  context,
                  const MediaUniverseScreen(),
                  '/app/media-universe',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ownership and availability stay separate: external catalogs can enrich a person, artist or work page, but do not add an item to your owned library. A title becomes owned library media only through the project’s validated ownership and import flow.',
                style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}
