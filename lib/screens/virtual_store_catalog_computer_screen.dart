import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_core.dart';
import '../catalog_poster_image.dart';
import '../details.dart';
import '../models/media_case_style.dart';
import '../music.dart';

/// In-store catalog terminal inspired by a video-store recommendation computer.
/// It searches the active profile's accessible library and imported music.
/// It does not imply ownership or playability for catalog-only music results.
class VirtualStoreCatalogComputerScreen extends StatefulWidget {
  const VirtualStoreCatalogComputerScreen({super.key});

  @override
  State<VirtualStoreCatalogComputerScreen> createState() =>
      _VirtualStoreCatalogComputerScreenState();
}

class _VirtualStoreCatalogComputerScreenState
    extends State<VirtualStoreCatalogComputerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MusicLibraryStore _music = MusicLibraryStore.instance;
  String _filter = 'All';
  String _mood = 'Any mood';
  String _length = 'Any length';
  String _seen = 'Either';

  @override
  void initState() {
    super.initState();
    unawaited(_music.initializeForProfile(
      AppController.instance.currentProfile?.id,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MediaItem> get _ownedMedia {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    return controller.library
        .where((item) =>
            item.isAccessibleTo(profile) && controller.isOwned(item.id))
        .toList(growable: false);
  }

  List<MusicTrack> get _musicTracks {
    // The store terminal represents the active profile's imported music, not
    // search-discovered catalog-only tracks that may not be owned or playable.
    final byId = <String, MusicTrack>{};
    for (final track in _music.tracks) {
      byId[track.id] = track;
    }
    return byId.values.toList(growable: false);
  }

  bool _isMusicMedia(MediaItem item) {
    final type = item.type.toLowerCase().replaceAll('_', ' ');
    return type.contains('music') ||
        type.contains('album') ||
        type.contains('audio') ||
        type.contains('song') ||
        type.contains('track') ||
        MediaCaseStyle.canonicalFormat(item.displayCaseFormat)
            .toLowerCase()
            .contains('cd');
  }

  bool _isShow(MediaItem item) {
    final type = item.type.toLowerCase();
    return type.contains('tv') ||
        type.contains('show') ||
        type.contains('series') ||
        type.contains('episode') ||
        type.contains('television') ||
        type.contains('special');
  }

  bool _matchesFormat(MediaItem item, String format) {
    final actual =
        MediaCaseStyle.canonicalFormat(item.displayCaseFormat).toLowerCase();
    final expected = format.toLowerCase();
    if (expected == '4k ultra hd') {
      return actual.contains('4k') ||
          actual.contains('ultra hd') ||
          actual.contains('uhd');
    }
    return actual.contains(expected);
  }

  bool _matchesMood(MediaItem item) {
    if (_mood == 'Any mood' || _mood == 'Something new') {
      return true;
    }
    final tags = <String>[
      ...item.genres,
      if (item.primaryGenre != null) item.primaryGenre!
    ].join(' ').toLowerCase();
    final keywords = switch (_mood) {
      'Funny' => const ['comedy', 'humor', 'satire'],
      'Action' => const ['action', 'adventure', 'superhero'],
      'Thriller' => const ['thriller', 'mystery', 'crime', 'suspense'],
      'Family' => const ['family', 'animation', 'kids', 'children'],
      'Relaxing' => const ['music', 'documentary', 'nature', 'romance'],
      'Scary' => const ['horror', 'supernatural', 'thriller'],
      _ => const <String>[],
    };
    return keywords.isEmpty || keywords.any(tags.contains);
  }

  bool _matchesLength(MediaItem item) {
    final runtime = item.runtimeMinutes;
    if (_length == 'Any length') {
      return true;
    }
    if (runtime == null) {
      return false;
    }
    return switch (_length) {
      'Under 90 min' => runtime < 90,
      '90–120 min' => runtime >= 90 && runtime <= 120,
      'Over 2 hours' => runtime > 120,
      _ => true,
    };
  }

  bool _matchesSeen(MediaItem item) {
    if (_seen == 'Either') {
      if (_mood == 'Something new') {
        return !AppController.instance.watched
            .any((watched) => watched.id == item.id);
      }
      return true;
    }
    if (_seen == 'Favorites') {
      return AppController.instance.liked.any((liked) => liked.id == item.id);
    }
    return !AppController.instance.watched
        .any((watched) => watched.id == item.id);
  }

  List<MediaItem> get _visibleMedia {
    final query = _searchController.text.trim().toLowerCase();
    return _ownedMedia.where((item) {
      final music = _isMusicMedia(item);
      final show = _isShow(item);
      final filterMatches = switch (_filter) {
        'Movies' => !music && !show,
        'Shows' => !music && show,
        'CDs & Music' => music,
        'DVD' => _matchesFormat(item, 'DVD'),
        'Blu-ray' => _matchesFormat(item, 'Blu-ray'),
        '4K Ultra HD' => _matchesFormat(item, '4K Ultra HD'),
        _ => true,
      };
      if (!filterMatches ||
          !_matchesMood(item) ||
          !_matchesLength(item) ||
          !_matchesSeen(item)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = <String>[
        item.title,
        item.type,
        item.description ?? '',
        ...item.genres,
        ...item.tags,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  Map<String, List<MusicTrack>> get _visibleAlbums {
    if (_filter != 'All' && _filter != 'CDs & Music') {
      return const <String, List<MusicTrack>>{};
    }
    final query = _searchController.text.trim().toLowerCase();
    final groups = <String, List<MusicTrack>>{};
    for (final track in _musicTracks) {
      final trackGenres = track.allGenreTags.join(' ').toLowerCase();
      final moodWords = switch (_mood) {
        'Funny' => const ['comedy', 'humor'],
        'Action' => const ['action', 'adventure'],
        'Thriller' => const ['thriller', 'mystery', 'crime'],
        'Family' => const ['family', 'children'],
        'Relaxing' => const [
            'ambient',
            'classical',
            'jazz',
            'acoustic',
            'easy listening'
          ],
        'Scary' => const ['horror', 'dark ambient'],
        _ => const <String>[],
      };
      if (moodWords.isNotEmpty && !moodWords.any(trackGenres.contains)) {
        continue;
      }
      final durationMinutes = track.duration.inMinutes;
      if (_length == 'Under 90 min' && durationMinutes >= 90) {
        continue;
      }
      if (_length == '90–120 min' &&
          (durationMinutes < 90 || durationMinutes > 120)) {
        continue;
      }
      if (_length == 'Over 2 hours' && durationMinutes <= 120) {
        continue;
      }
      final album =
          track.album.trim().isEmpty ? track.title : track.album.trim();
      final key = '$album|${track.artist.trim()}';
      if (query.isNotEmpty &&
          !'$album ${track.title} ${track.artist} ${track.genreDisplayLabel}'
              .toLowerCase()
              .contains(query)) {
        continue;
      }
      (groups[key] ??= <MusicTrack>[]).add(track);
    }
    return groups;
  }

  Future<void> _openMedia(MediaItem item) async {
    if (_isMusicMedia(item)) {
      final album = item.title.trim().toLowerCase();
      final matching = _musicTracks
          .where((track) => track.album.trim().toLowerCase() == album)
          .toList(growable: false);
      if (matching.isNotEmpty) {
        final artist = matching.first.artist.trim();
        await _openAlbum('${item.title}|$artist', matching);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MusicScreen()),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: item)),
    );
  }

  Future<void> _openAlbum(String albumKey, List<MusicTrack> tracks) async {
    final albumTitle = albumKey.split('|').first;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Text(albumTitle,
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final playable =
                        (track.audioUrl?.trim().isNotEmpty ?? false);
                    return ListTile(
                      leading: const Icon(Icons.music_note_rounded),
                      title: Text(track.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${track.artist} · ${playable ? 'Audio available' : 'Catalog metadata only'}'),
                      trailing: Icon(playable
                          ? Icons.play_circle_fill_rounded
                          : Icons.info_outline_rounded),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        if (!playable) {
                          if (mounted && messenger.mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'This entry has no playable audio file linked yet. Import or link the CD audio in your music library.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        await MusicPlaybackController.instance.play(track);
                        if (!mounted || !navigator.mounted) {
                          return;
                        }
                        await navigator.push(
                          MaterialPageRoute<void>(
                              builder: (_) => const MusicScreen()),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _askTheComputer() {
    const moods = <String>[
      'Any mood',
      'Funny',
      'Action',
      'Thriller',
      'Family',
      'Relaxing',
      'Scary',
      'Something new'
    ];
    const lengths = <String>[
      'Any length',
      'Under 90 min',
      '90–120 min',
      'Over 2 hours'
    ];
    const seen = <String>['Either', 'Not seen', 'Favorites'];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                18, 8, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LET THE COMPUTER HELP',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                const SizedBox(height: 8),
                const Text('What are you in the mood for tonight?'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _mood,
                  decoration: const InputDecoration(labelText: 'Mood'),
                  items: moods
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => _mood = value);
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: _length,
                  decoration: const InputDecoration(labelText: 'How long?'),
                  items: lengths
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => _length = value);
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: _seen,
                  decoration:
                      const InputDecoration(labelText: 'Seen it before?'),
                  items: seen
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => _seen = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() => _filter = 'All');
                    },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Find something for me'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = _visibleMedia;
    final albums = _visibleAlbums;
    final albumEntries = albums.entries.toList(growable: false);
    final results = <_ComputerResult>[
      for (final item in media) _ComputerResult.forMedia(item),
      for (final entry in albumEntries)
        _ComputerResult.forAlbum(entry.key, entry.value),
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Scaffold(
      backgroundColor: const Color(0xFF101923),
      appBar: AppBar(
        title: const Text('Store Catalog Computer',
            style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF172A3B),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF20384A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFDBB45E).withValues(alpha: .55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.computer_rounded, color: Color(0xFFF0C76C)),
                  SizedBox(width: 8),
                  Text('ALT VIDEO · CATALOG TERMINAL',
                      style: TextStyle(
                          color: Color(0xFFF0C76C),
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900))
                ]),
                const SizedBox(height: 9),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search a movie, show, album or track…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Ask the computer',
                      onPressed: _askTheComputer,
                      icon: const Icon(Icons.auto_awesome_rounded),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0D1822),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _askTheComputer,
                    icon: const Icon(Icons.psychology_alt_rounded, size: 17),
                    label: const Text('Help me choose tonight'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                for (final filter in const [
                  'All',
                  'Movies',
                  'Shows',
                  'CDs & Music',
                  'DVD',
                  'Blu-ray',
                  '4K Ultra HD'
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Expanded(
                    child: Text('YOUR COLLECTION · ${results.length} MATCHES',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: Colors.white70))),
                const Text('Select a title or CD to open it',
                    style: TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                          'No matching titles were found in this profile’s collection. Import the media or try another search.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    itemCount: results.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 4),
                        leading: SizedBox(
                          width: 54,
                          height: 72,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: result.media != null
                                ? CatalogPosterImage(
                                    media: result.media!, fit: BoxFit.cover)
                                : _AlbumCover(url: result.artworkUrl),
                          ),
                        ),
                        title: Text(result.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(result.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11)),
                        trailing: Icon(
                            result.media != null
                                ? Icons.play_circle_outline_rounded
                                : Icons.album_rounded,
                            color: const Color(0xFFF0C76C)),
                        onTap: () {
                          if (result.media != null) {
                            _openMedia(result.media!);
                          } else {
                            _openAlbum(result.albumKey!, result.tracks!);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ComputerResult {
  const _ComputerResult._({
    required this.title,
    required this.subtitle,
    this.media,
    this.albumKey,
    this.tracks,
    this.artworkUrl,
  });

  factory _ComputerResult.forMedia(MediaItem media) => _ComputerResult._(
        title: media.title,
        subtitle:
            '${media.type} · ${media.releaseYear ?? 'Year unknown'} · ${MediaCaseStyle.canonicalFormat(media.displayCaseFormat)}',
        media: media,
      );

  factory _ComputerResult.forAlbum(String key, List<MusicTrack> tracks) {
    final first = tracks.first;
    final album = key.split('|').first;
    return _ComputerResult._(
      title: album,
      subtitle:
          '${first.artist} · ${tracks.length} tracks · ${tracks.any((track) => (track.audioUrl?.trim().isNotEmpty ?? false)) ? 'Playable audio available' : 'No audio file linked'}',
      albumKey: key,
      tracks: tracks,
      artworkUrl: first.artworkUrl,
    );
  }

  final String title;
  final String subtitle;
  final MediaItem? media;
  final String? albumKey;
  final List<MusicTrack>? tracks;
  final String? artworkUrl;
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF263445),
        child: Center(child: Icon(Icons.album_rounded, color: Colors.white70)),
      );
    }
    return Image.network(
      value,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFF263445),
        child: Center(child: Icon(Icons.album_rounded, color: Colors.white70)),
      ),
    );
  }
}
