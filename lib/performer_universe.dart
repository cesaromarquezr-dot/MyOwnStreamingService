import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'app_core.dart';
import 'backend_api.dart';
import 'core/services/cinematic_person_metadata_service.dart';
import 'details.dart';
import 'music.dart';
import 'music_catalog_screen.dart';
import 'music_video_search_screen.dart';

/// Unified, credit-aware career view for performers who work across film,
/// television, recorded music, music videos, specials and soundtracks.
///
/// External metadata is only attached after an exact person/artist resolution.
/// Local titles and tracks are always restricted to the active profile's view.
class PerformerUniverseScreen extends StatefulWidget {
  const PerformerUniverseScreen({
    super.key,
    required this.performerName,
    this.localCredits = const <Map<String, dynamic>>[],
    this.allowCreateIfMissing = true,
  });

  final String performerName;
  final List<Map<String, dynamic>> localCredits;
  final bool allowCreateIfMissing;

  @override
  State<PerformerUniverseScreen> createState() =>
      _PerformerUniverseScreenState();
}

class _PerformerUniverseScreenState extends State<PerformerUniverseScreen> {
  static const List<String> _sections = <String>[
    'All',
    'Movies',
    'TV Shows',
    'Music',
    'Music Videos',
    'Specials & Performances',
    'Soundtracks',
    'Complete Career',
  ];

  String _selectedSection = 'All';
  CinematicPersonMetadata? _cinematicProfile;
  List<Map<String, dynamic>> _musicArtistChoices = <Map<String, dynamic>>[];
  Map<String, dynamic>? _selectedMusicArtist;
  List<Map<String, dynamic>> _musicRecordings = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _musicReleases = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _backendCareerCredits = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _loadingMusic = false;
  String? _cinematicError;
  String? _musicError;
  String? _careerError;

  AppController get _controller => AppController.instance;
  String get _performerName => widget.performerName.trim();

  @override
  void initState() {
    super.initState();
    MusicLibraryStore.instance.addListener(_onMusicLibraryChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    MusicLibraryStore.instance.removeListener(_onMusicLibraryChanged);
    super.dispose();
  }

  void _onMusicLibraryChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _cinematicError = null;
      _musicError = null;
      _careerError = null;
    });

    final tasks = <Future<void>>[
      _loadCinematicCredits(),
      _loadMusicArtistChoices(),
      _loadIndexedCareerCredits(),
    ];
    await Future.wait(tasks);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCinematicCredits() async {
    try {
      final result = await CinematicPersonMetadataService.lookupPersonProfile(
        _performerName,
      );
      if (mounted) setState(() => _cinematicProfile = result);
    } catch (error) {
      _cinematicError = error.toString();
    }
  }

  Future<void> _loadIndexedCareerCredits() async {
    final api = _controller.backendApi;
    if (!api.isAuthenticated) return;
    try {
      final matches = await api.searchMediaPeople(query: _performerName);
      final exact = matches.where((entry) =>
          _normalize(entry['name']?.toString() ?? '') ==
          _normalize(_performerName));
      final person = exact.isEmpty ? null : exact.first;
      if (person == null && !widget.allowCreateIfMissing) return;
      final storedPersonId = person?['id']?.toString().trim() ?? '';
      final personId = storedPersonId.isNotEmpty
          ? storedPersonId
          : 'person:${Uri.encodeComponent(_performerName.toLowerCase())}';
      if (storedPersonId.isEmpty) {
        await api.createMediaPerson(id: personId, name: _performerName);
      }
      final response = await api.getPersonCareerTimeline(personId: personId);
      final raw = response['credits'];
      if (!mounted || raw is! List) return;
      final credits = <Map<String, dynamic>>[];
      for (final entry in raw.whereType<Map>()) {
        final row = Map<String, dynamic>.from(entry);
        final credit = row['credit'] is Map
            ? Map<String, dynamic>.from(row['credit'] as Map)
            : <String, dynamic>{};
        final work = row['work'] is Map
            ? Map<String, dynamic>.from(row['work'] as Map)
            : <String, dynamic>{};
        final workType = (work['type'] ?? '').toString();
        final rawCategory = (credit['category'] ?? 'Other').toString();
        final lowerCategory = rawCategory.toLowerCase();
        final category =
            lowerCategory.contains('music') || lowerCategory.contains('song')
                ? 'Music'
                : lowerCategory.contains('award')
                    ? 'Awards'
                    : _mediaCategory(workType);
        credits.add(<String, dynamic>{
          'title': work['title'] ?? 'Untitled work',
          'category': category,
          'type': workType.isEmpty ? rawCategory : workType,
          'role': credit['role'] ?? rawCategory,
          'characterName': credit['characterName'],
          'year': credit['startYear'] ?? work['releaseYear'],
          'source': credit['source'] ?? 'Indexed career graph',
          'mediaId': work['id'],
        });
      }
      if (mounted) setState(() => _backendCareerCredits = credits);
    } catch (error) {
      if (mounted) {
        setState(() => _careerError =
            'Indexed career credits could not be loaded: $error');
      }
    }
  }

  Future<void> _loadMusicArtistChoices() async {
    if (!_controller.backendApi.isAuthenticated) return;
    try {
      final payload = await _controller.backendApi.searchMusicCatalog(
        _performerName,
        type: 'artist',
        limit: 10,
      );
      final musicBrainz = payload['musicBrainz'] is Map
          ? Map<String, dynamic>.from(payload['musicBrainz'] as Map)
          : <String, dynamic>{};
      final raw = musicBrainz['artists'];
      final normalized = _normalize(_performerName);
      final exact = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) =>
                  _normalize(item['name']?.toString() ?? '') == normalized)
              .where((item) => (item['id']?.toString() ?? '').trim().isNotEmpty)
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() => _musicArtistChoices = exact);
      if (exact.length == 1) {
        await _selectMusicArtist(exact.first);
      } else if (exact.length > 1) {
        // A shared stage name or homonym must be resolved by the user.
        setState(() => _musicError =
            'More than one exact MusicBrainz artist identity exists. Choose the correct artist before loading recordings.');
      } else {
        setState(() => _musicError =
            'No exact MusicBrainz artist match was found. Local music credits remain available.');
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _musicError = 'MusicBrainz credits could not be loaded: $error');
      }
    }
  }

  Future<void> _selectMusicArtist(Map<String, dynamic> artist) async {
    final mbid = artist['id']?.toString().trim() ?? '';
    if (mbid.isEmpty || !_controller.backendApi.isAuthenticated) return;
    setState(() {
      _selectedMusicArtist = artist;
      _loadingMusic = true;
      _musicError = null;
      _musicRecordings = <Map<String, dynamic>>[];
      _musicReleases = <Map<String, dynamic>>[];
    });
    try {
      final responses = await Future.wait<
          Map<String, dynamic>>(<Future<Map<String, dynamic>>>[
        _controller.backendApi.getMusicArtistRecordings(mbid, limit: 100),
        _controller.backendApi.getMusicDiscography(mbid, limit: 100),
      ]);
      if (!mounted || _selectedMusicArtist?['id']?.toString() != mbid) return;
      setState(() {
        _musicRecordings = _maps(responses[0]['items']);
        _musicReleases = _maps(responses[1]['items']);
      });
    } catch (error) {
      if (mounted) {
        setState(() => _musicError =
            'The artist identity was found, but MusicBrainz recordings or releases could not be loaded: $error');
      }
    } finally {
      if (mounted) setState(() => _loadingMusic = false);
    }
  }

  List<MediaItem> get _visibleMedia => _controller.library
      .where((item) => item.isAccessibleTo(_controller.currentProfile))
      .toList(growable: false);

  List<MusicTrack> get _localTracks {
    final unique = <String, MusicTrack>{};
    for (final track in <MusicTrack>[
      ...MusicLibraryStore.instance.tracks,
      ...MusicLibraryStore.instance.catalogTracks.values,
    ]) {
      final credited = _same(track.artist, _performerName) ||
          track.featuredArtists.any((name) => _same(name, _performerName));
      if (credited) unique[track.id] = track;
    }
    return unique.values.toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  List<Map<String, dynamic>> get _mediaCredits {
    final library = _visibleMedia;
    final localByTitle = <String, MediaItem>{
      for (final item in library)
        '${_normalize(item.title)}|${_mediaCategory(item.type)}': item,
    };
    final entries = <Map<String, dynamic>>[];

    final profile = _cinematicProfile;
    if (profile != null) {
      for (final credit in profile.filmography) {
        final category = credit.mediaType == 'movie' ? 'Movies' : 'TV Shows';
        final local = localByTitle['${_normalize(credit.title)}|$category'];
        entries.add(<String, dynamic>{
          'title': credit.title,
          'category': category,
          'type': category == 'Movies' ? 'Movie' : 'TV Show',
          'role': credit.roleLabel,
          'department': credit.department ?? '',
          'year': credit.releaseYear,
          'overview': credit.overview,
          'imageUrl':
              CinematicPersonMetadataService.imageUrl(credit.posterPath),
          'source': 'TMDB',
          'owned': local != null,
          'mediaId': local?.id,
        });
      }
    }

    for (final media in library) {
      final isActor = media.actors.any((name) => _same(name, _performerName));
      final isDirector =
          media.directors.any((name) => _same(name, _performerName));
      final isWriter = media.writers.any((name) => _same(name, _performerName));
      if (!isActor && !isDirector && !isWriter) continue;
      final category = _mediaCategory(media.type);
      entries.add(<String, dynamic>{
        'title': media.title,
        'category': category,
        'type': media.type,
        'role': isActor
            ? 'Cast credit (specific role not indexed)'
            : isDirector
                ? 'Director'
                : 'Writer',
        'year': media.releaseYear,
        'overview': media.description ?? '',
        'imageUrl': media.imageUrl,
        'source': 'Your library',
        'owned': true,
        'mediaId': media.id,
      });
    }

    // Optional imported career graph credits retain their supplied role labels.
    for (final credit in widget.localCredits) {
      entries.add(<String, dynamic>{
        'title': credit['title']?.toString() ?? 'Untitled work',
        'category': _categoryFromCredit(credit),
        'type': credit['type']?.toString() ?? 'Media',
        'role': credit['characterName'] ?? credit['role'] ?? 'Verified credit',
        'year': credit['year'],
        'overview': '',
        'imageUrl': null,
        'source': credit['source']?.toString() ?? 'Indexed credit',
        'owned': credit['mediaId'] != null,
        'mediaId': credit['mediaId'],
      });
    }

    for (final credit in _backendCareerCredits) {
      entries.add(<String, dynamic>{
        'title': credit['title']?.toString() ?? 'Untitled work',
        'category': credit['category']?.toString() ?? 'Movies',
        'type': credit['type']?.toString() ?? 'Media',
        'role': credit['characterName'] ?? credit['role'] ?? 'Indexed credit',
        'year': credit['year'],
        'overview': '',
        'imageUrl': null,
        'source': credit['source']?.toString() ?? 'Indexed career graph',
        'owned': false,
        'mediaId': credit['mediaId'],
      });
    }

    final seen = <String>{};
    final unique = entries.where((entry) {
      final key = '${_normalize(entry['title']?.toString() ?? '')}|'
          '${entry['category']}|${_normalize(entry['role']?.toString() ?? '')}';
      return seen.add(key);
    }).toList(growable: false);
    unique.sort((a, b) =>
        (_year(a['year']) ?? 9999).compareTo(_year(b['year']) ?? 9999));
    return unique;
  }

  List<Map<String, dynamic>> get _musicCredits {
    final items = <Map<String, dynamic>>[];
    for (final recording in _musicRecordings) {
      items.add(<String, dynamic>{
        'title': recording['title'] ?? 'Untitled recording',
        'artist': recording['artist'] ?? _performerName,
        'year': _year(recording['firstReleaseDate']),
        'role': 'Recording artist credit (MusicBrainz)',
        'source': 'MusicBrainz',
        'id': recording['id'],
      });
    }
    for (final release in _musicReleases) {
      items.add(<String, dynamic>{
        'title': release['title'] ?? 'Untitled release',
        'artist': _performerName,
        'year': _year(release['year'] ?? release['firstReleaseDate']),
        'role':
            '${release['primaryType'] ?? 'Release'} · MusicBrainz discography',
        'source': 'MusicBrainz',
        'id': release['id'],
        'coverArtUrl': release['coverArtUrl'],
      });
    }
    for (final track in _localTracks) {
      final primary = _same(track.artist, _performerName);
      items.add(<String, dynamic>{
        'title': track.title,
        'artist': track.artist,
        'year': null,
        'role': primary ? 'Primary artist credit' : 'Featured artist credit',
        'source': track.catalogOnly ? 'Music catalog' : 'Your music library',
        'localTrackId': track.id,
        'catalogOnly': track.catalogOnly,
        'track': track,
      });
    }
    final seen = <String>{};
    final unique = items.where((item) {
      final key = '${_normalize(item['title']?.toString() ?? '')}|'
          '${_normalize(item['artist']?.toString() ?? '')}|${item['role']}';
      return seen.add(key);
    }).toList(growable: false);
    unique.sort((a, b) =>
        (_year(a['year']) ?? 9999).compareTo(_year(b['year']) ?? 9999));
    return unique;
  }

  List<Map<String, dynamic>> get _musicVideoCredits => _localTracks
      .map((track) => <String, dynamic>{'title': track.title, 'track': track})
      .toList(growable: false);

  List<Map<String, dynamic>> get _specialCredits {
    final specialWords = <String>[
      'special',
      'concert',
      'performance',
      'music video',
      'live'
    ];
    return _visibleMedia
        .where((media) {
          final isSpecial = specialWords
              .any((word) => media.type.toLowerCase().contains(word));
          final personCredit =
              media.actors.any((name) => _same(name, _performerName)) ||
                  media.music.any((name) => _same(name, _performerName));
          return isSpecial && personCredit;
        })
        .map((media) => <String, dynamic>{
              'title': media.title,
              'category': 'Specials & Performances',
              'type': media.type,
              'role': 'Indexed performer / music credit',
              'year': media.releaseYear,
              'source': 'Your library',
              'mediaId': media.id,
              'owned': true,
            })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> get _soundtrackCredits => _localTracks
      .where((track) => track.soundtrackForTitles.isNotEmpty)
      .map((track) => <String, dynamic>{
            'title': track.title,
            'artist': track.artist,
            'role': 'Explicit soundtrack relationship',
            'soundtrackForTitles': track.soundtrackForTitles,
            'source':
                track.soundtrackSourceName ?? 'Imported soundtrack metadata',
            'track': track,
          })
      .toList(growable: false);

  List<Map<String, dynamic>> get _allCareerEntries {
    final entries = <Map<String, dynamic>>[
      ..._mediaCredits,
      ..._musicCredits.map((item) => <String, dynamic>{
            ...item,
            'category': 'Music',
            'type': item['role']?.toString() ?? 'Music',
          }),
      ..._specialCredits,
      ..._soundtrackCredits.map((item) => <String, dynamic>{
            ...item,
            'category': 'Soundtracks',
            'type': 'Soundtrack recording',
          }),
    ];
    entries.sort((a, b) =>
        (_year(a['year']) ?? 9999).compareTo(_year(b['year']) ?? 9999));
    return entries;
  }

  List<Map<String, dynamic>> get _visibleEntries {
    switch (_selectedSection) {
      case 'Movies':
      case 'TV Shows':
        return _mediaCredits
            .where((entry) => entry['category'] == _selectedSection)
            .toList();
      case 'Music':
        return _musicCredits;
      case 'Music Videos':
        return _musicVideoCredits;
      case 'Specials & Performances':
        return _specialCredits;
      case 'Soundtracks':
        return _soundtrackCredits;
      case 'Complete Career':
        return _allCareerEntries;
      default:
        return <Map<String, dynamic>>[
          ..._mediaCredits,
          ..._musicCredits
              .map((item) => <String, dynamic>{...item, 'category': 'Music'}),
          ..._specialCredits,
          ..._soundtrackCredits,
        ];
    }
  }

  String _mediaCategory(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('tv') ||
        normalized.contains('series') ||
        normalized.contains('show') ||
        normalized.contains('episode')) {
      return 'TV Shows';
    }
    if (normalized.contains('special') ||
        normalized.contains('concert') ||
        normalized.contains('performance') ||
        normalized.contains('music video')) {
      return 'Specials & Performances';
    }
    return 'Movies';
  }

  String _categoryFromCredit(Map<String, dynamic> credit) {
    final category = (credit['category'] ?? '').toString().toLowerCase();
    if (category.contains('music') || category.contains('song')) return 'Music';
    if (category.contains('tv') || category.contains('television')) {
      return 'TV Shows';
    }
    return 'Movies';
  }

  String _normalize(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9À-ÖØ-öø-ÿ\u0100-\u024F]+'), '');

  bool _same(String a, String b) => _normalize(a) == _normalize(b);

  int? _year(Object? value) {
    if (value is num) return value.toInt();
    final text = value?.toString() ?? '';
    if (text.length < 4) return int.tryParse(text);
    return int.tryParse(text.substring(0, 4));
  }

  static List<Map<String, dynamic>> _maps(dynamic raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList()
      : <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) {
    final profile = _cinematicProfile;
    final entries = _visibleEntries;
    final image = profile == null
        ? null
        : CinematicPersonMetadataService.imageUrl(profile.person.profilePath,
            size: 'w500');
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D14),
      appBar: AppBar(
        title:
            Text(_performerName, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF111522),
        actions: [
          IconButton(
            tooltip: 'Refresh performer credits',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          _profileHeader(profile, image),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: LinearProgressIndicator(),
            ),
          if (_cinematicError != null ||
              _musicError != null ||
              _careerError != null)
            _notice(
                'Some credits are unavailable',
                [_cinematicError, _musicError, _careerError]
                    .whereType<String>()
                    .join('\n')),
          const SizedBox(height: 14),
          _musicBrainzIdentityPicker(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _sections
                .map((section) => ChoiceChip(
                      label: Text(section),
                      selected: _selectedSection == section,
                      onSelected: (_) =>
                          setState(() => _selectedSection = section),
                    ))
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          _sectionDescription(),
          const SizedBox(height: 8),
          if (_selectedSection == 'Music' ||
              _selectedSection == 'All' ||
              _selectedSection == 'Complete Career')
            _discographyAction(),
          if (_loadingMusic &&
              (_selectedSection == 'Music' || _selectedSection == 'All'))
            const Padding(
                padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          if (entries.isEmpty && !_loading)
            _notice('No indexed credits in this section', _emptyMessage()),
          ...entries.map(_creditTile),
          const SizedBox(height: 14),
          _creditIntegrityNote(),
        ],
      ),
    );
  }

  Widget _profileHeader(CinematicPersonMetadata? profile, String? image) =>
      Card(
        color: const Color(0xFF171D2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 102,
                height: 132,
                child: image == null
                    ? Container(
                        color: const Color(0xFF2A3040),
                        child: const Icon(Icons.person_rounded, size: 46))
                    : Image.network(image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF2A3040),
                              child: const Icon(Icons.person_rounded, size: 46),
                            )),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_performerName,
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w900)),
                  if (profile?.person.knownForDepartment?.trim().isNotEmpty ==
                      true)
                    Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(profile!.person.knownForDepartment!,
                            style: const TextStyle(
                                color: Color(0xFFB8C7FF),
                                fontWeight: FontWeight.w700))),
                  const SizedBox(height: 7),
                  if (profile?.birthday?.isNotEmpty == true)
                    Text(
                        'Born ${profile!.birthday}${profile.placeOfBirth?.isNotEmpty == true ? ' · ${profile.placeOfBirth}' : ''}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  if (profile?.biography.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 7),
                    Text(profile!.biography,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.35)),
                  ],
                  if (profile == null)
                    const Text(
                        'A verified biography or portrait was not found. The profile can still show locally indexed credits.',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
          ]),
        ),
      );

  Widget _musicBrainzIdentityPicker() {
    if (_musicArtistChoices.isEmpty) return const SizedBox.shrink();
    if (_musicArtistChoices.length == 1) {
      final artist = _musicArtistChoices.first;
      return _providerIdentityCard(artist);
    }
    final selectedId = _selectedMusicArtist?['id']?.toString();
    return Card(
      color: const Color(0xFF171D2A),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Choose the correct music artist identity',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'MusicBrainz artist'),
            items: _musicArtistChoices
                .map((artist) => DropdownMenuItem<String>(
                      value: artist['id']?.toString(),
                      child: Text(
                          '${artist['name']}${(artist['disambiguation'] ?? '').toString().isEmpty ? '' : ' · ${artist['disambiguation']}'}',
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (id) {
              Map<String, dynamic>? choice;
              for (final artist in _musicArtistChoices) {
                if (artist['id']?.toString() == id) {
                  choice = artist;
                  break;
                }
              }
              if (choice != null) unawaited(_selectMusicArtist(choice));
            },
          ),
        ]),
      ),
    );
  }

  Widget _providerIdentityCard(Map<String, dynamic> artist) => Card(
        color: const Color(0xFF171D2A),
        child: ListTile(
          leading: const Icon(Icons.verified_rounded, color: Color(0xFF8BD9B2)),
          title: const Text('MusicBrainz artist identity matched'),
          subtitle: Text(
              '${artist['name']} · ${artist['area'] ?? artist['country'] ?? 'Area not listed'}'),
          trailing: const Icon(Icons.check_circle_outline_rounded),
        ),
      );

  Widget _discographyAction() {
    final artist = _selectedMusicArtist;
    if (artist == null) return const SizedBox.shrink();
    final id = artist['id']?.toString() ?? '';
    if (id.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => MusicDiscographyScreen(
              artistName: _performerName, artistMbid: id),
        )),
        icon: const Icon(Icons.album_rounded),
        label: Text(
            'Open complete discography (${_musicReleases.length} releases indexed)'),
      ),
    );
  }

  Widget _sectionDescription() {
    final descriptions = <String, String>{
      'Movies':
          'Film appearances, with acting/crew credit labels when the source provides them.',
      'TV Shows': 'Television series and indexed episodic appearances.',
      'Music':
          'MusicBrainz recordings/releases plus tracks imported into your own music library.',
      'Music Videos':
          'Search for music-video matches associated with locally indexed songs.',
      'Specials & Performances':
          'Concerts, performance specials and music-video titles that are explicitly indexed in your library.',
      'Soundtracks':
          'Only songs with an explicit soundtrack relationship are included here.',
      'Complete Career':
          'A chronological combination of sourced film, television and music credits.',
    };
    return Text(
        descriptions[_selectedSection] ??
            'Explore this performer across movies, television and music.',
        style:
            const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4));
  }

  Widget _creditTile(Map<String, dynamic> item) {
    final track =
        item['track'] is MusicTrack ? item['track'] as MusicTrack : null;
    final imageUrl =
        (item['imageUrl'] ?? item['coverArtUrl'] ?? track?.artworkUrl)
            ?.toString();
    final title = (item['title'] ?? 'Untitled').toString();
    final subtitleParts = <String>[
      (item['role'] ?? item['type'] ?? item['category'] ?? 'Credit').toString(),
      if ((item['year'] ?? '').toString().isNotEmpty) item['year'].toString(),
      if ((item['source'] ?? '').toString().isNotEmpty)
        item['source'].toString(),
      if (item['owned'] == true) 'In your library',
      if (item['catalogOnly'] == true) 'Catalog metadata only',
    ];
    final category = (item['category'] ?? '').toString();
    final trailing = track != null
        ? IconButton(
            tooltip: 'Find music video',
            icon: const Icon(Icons.ondemand_video_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => MusicVideoSearchScreen(
                  title: track.title, artist: track.artist),
            )),
          )
        : null;
    return Card(
      color: const Color(0xFF151A25),
      margin: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        leading: imageUrl != null && imageUrl.startsWith('http')
            ? ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.network(imageUrl,
                    width: 48,
                    height: 66,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.movie_rounded)))
            : Icon(category == 'Music' || category == 'Soundtracks'
                ? Icons.music_note_rounded
                : Icons.movie_rounded),
        title: Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitleParts.join(' · '),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white60, fontSize: 11, height: 1.3)),
        trailing: trailing,
        onTap: () {
          if (track != null) {
            openMusicSearchTrack(context, track);
            return;
          }
          final mediaId = item['mediaId']?.toString();
          MediaItem? local;
          if (mediaId != null) {
            for (final candidate in _visibleMedia) {
              if (candidate.id == mediaId) {
                local = candidate;
                break;
              }
            }
          }
          if (local != null) {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => MediaDetailsScreen(
                media: local!,
                wrappedContextType: _wrappedPersonContextType(local),
                wrappedContextId:
                    'person:${Uri.encodeComponent(_performerName.toLowerCase())}',
                wrappedContextTitle: _performerName,
              ),
            ));
          } else if (item['source'] == 'MusicBrainz') {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) =>
                  MusicCatalogScreen(initialQuery: '$title $_performerName'),
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'This is an external metadata credit. Add or import the title to your library to open its local details.'),
            ));
          }
        },
      ),
    );
  }

  String _wrappedPersonContextType(MediaItem media) {
    final target = _normalize(_performerName);
    bool contains(Iterable<String> values) =>
        values.any((value) => _normalize(value) == target);
    if (contains(media.actors)) return 'cast';
    if (contains(media.directors)) return 'director';
    if (contains(media.writers)) return 'writer';
    if (contains(media.music)) return 'composer';
    return 'person';
  }

  Widget _creditIntegrityNote() => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Credit accuracy: acting, voice, guest, featured-artist, songwriter, composer and soundtrack-performer roles are kept distinct when the source supplies that detail. A primary artist credit is not automatically treated as proof of lead vocals, and a song in a movie is not assigned to its lead actor without an explicit credit.',
          style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
        ),
      );

  String _emptyMessage() {
    switch (_selectedSection) {
      case 'Music Videos':
        return 'No locally indexed songs are connected to this performer yet. Import music metadata first; then use the video search action for each song.';
      case 'Specials & Performances':
        return 'No concerts, performances or specials with an explicit performer credit are indexed in this profile library.';
      case 'Soundtracks':
        return 'No explicit soundtrack relationships are indexed for this performer. The app will not infer them from a title or actor name.';
      case 'Music':
        return 'No MusicBrainz recording/release match or locally indexed track was found for this performer.';
      default:
        return 'No sourced credits were found in this section yet. Add verified metadata or import the relevant titles into your profile library.';
    }
  }

  Widget _notice(String title, String message) => Card(
        color: const Color(0xFF2A241A),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(message,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.4)),
          ]),
        ),
      );
}
