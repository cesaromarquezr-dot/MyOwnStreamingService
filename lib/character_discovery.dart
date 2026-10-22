import 'package:flutter/material.dart';

import 'app_core.dart';
import 'backend_api.dart';
import 'core/models/profile_governance.dart';
import 'core/services/tv_programming_service.dart';
import 'details.dart';
import 'people_timeline.dart';

/// Parses natural-language character queries such as "Spider-Man movies" or
/// "show me Spider-Man actors, movies and shows" into a subject and filters.
class CharacterSearchIntent {
  final String subject;
  final bool includeMovies;
  final bool includeShows;
  final bool includePerformers;
  final bool hasTypeFilter;

  const CharacterSearchIntent({
    required this.subject,
    required this.includeMovies,
    required this.includeShows,
    required this.includePerformers,
    required this.hasTypeFilter,
  });

  factory CharacterSearchIntent.parse(String input) {
    final original = input.trim();
    final lower = original.toLowerCase();
    final includeMovies = RegExp(r'\b(movie|movies|film|films)\b').hasMatch(lower);
    final includeShows = RegExp(r'\b(show|shows|series|television|tv)\b').hasMatch(lower);
    final includePerformers = RegExp(r'\b(actor|actors|voice actor|voice actors|performer|performers|cast)\b').hasMatch(lower);
    final hasTypeFilter = includeMovies || includeShows || includePerformers;

    var subject = lower
        .replaceFirst(RegExp(r'^(show me|find|search for|look up|tell me about|explore|who is|who are|what is|who plays)\s+'), '')
        .replaceFirst(RegExp(r'^(everything about|all of|all|every)\s+'), '')
        .replaceFirst(RegExp(r'^(what|which)\s+(?:movies?|films?|shows?|series|actors?|voice actors?)\s+(?:feature|include|star|starring|with|play|plays|played|portray|portrayed|have|has)\s+'), '')
        .replaceFirst(RegExp(r'^(movies?|films?|shows?|series|actors?|voice actors?|performers?|cast)\s+(?:of|with|featuring|starring|for)\s+'), '');

    // Remove output categories and conversational filler, but preserve words
    // that may be part of a canonical character name (for example, The Thing).
    subject = subject
        .replaceAll(RegExp(r'\b(?:movies?|films?|shows?|series|tv shows?|television shows?|actors?|voice actors?|performers?|cast|appearances?)\b'), ' ')
        .replaceAll(RegExp(r'\b(?:everything|all|works|credits|for|of|about|please|me|my|who|what|which|is|plays|play|played|portray|portrayed|featuring|starring|have|has|and|or)\b'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return CharacterSearchIntent(
      subject: subject,
      includeMovies: hasTypeFilter ? includeMovies : true,
      includeShows: hasTypeFilter ? includeShows : true,
      includePerformers: hasTypeFilter ? includePerformers : true,
      hasTypeFilter: hasTypeFilter,
    );
  }
}

/// Local, profile-aware character index built from existing catalog metadata.
/// It never infers an actor-to-character relationship from a title alone.
class CharacterDiscoveryIndex {
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<String> knownCharacterNames(List<MediaItem> library) {
    final names = <String, String>{};
    for (final media in library) {
      if (!_isVisible(media)) continue;
      for (final value in media.characters) {
        _addName(names, value);
      }
      for (final event in media.xrayEvents) {
        for (final value in _characterNamesInMap(event)) {
          _addName(names, value);
        }
      }
    }
    final result = names.values.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  static List<String> matchingCharacterNames(
    String query,
    List<MediaItem> library,
  ) {
    final intent = CharacterSearchIntent.parse(query);
    final subject = normalize(intent.subject);
    if (subject.length < 2) return const <String>[];
    final names = knownCharacterNames(library);
    final exact = names.where((name) => normalize(name) == subject).toList();
    if (exact.isNotEmpty) return exact;
    final matches = names.where((name) {
      final candidate = normalize(name);
      // Avoid interpreting a full title such as "Batman Beyond" as the
      // standalone "Batman" character unless the user explicitly asks for a
      // character media category ("Batman Beyond actors", etc.).
      return candidate.contains(subject) ||
          (intent.hasTypeFilter && subject.contains(candidate));
    }).toList();
    matches.sort((a, b) {
      final aLength = normalize(a).length;
      final bLength = normalize(b).length;
      if (aLength != bLength) return aLength.compareTo(bLength);
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return matches.take(8).toList(growable: false);
  }

  static List<MediaItem> titlesForCharacter(
    String characterName,
    List<MediaItem> library, {
    bool? movies,
    bool? shows,
  }) {
    final wanted = normalize(characterName);
    if (wanted.isEmpty) return const <MediaItem>[];
    if (movies == false && shows == false) return const <MediaItem>[];
    final found = library.where((media) {
      if (!_isVisible(media)) return false;
      final isShow = media.isSeries || const {'episode', 'tvepisode', 'season', 'tvseason'}.contains(_type(media.type));
      final isMovie = const {'movie', 'movies', 'film', 'films'}.contains(_type(media.type));
      if (movies == true && !isMovie) return false;
      if (shows == true && !isShow) return false;
      if (movies == false && isMovie) return false;
      if (shows == false && isShow) return false;
      return media.characters.any((name) => _sameCharacter(name, characterName)) ||
          media.xrayEvents.any((event) => _mapHasCharacter(event, characterName));
    }).toList();
    found.sort((a, b) {
      final year = (a.releaseYear ?? 9999).compareTo(b.releaseYear ?? 9999);
      return year != 0 ? year : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return found;
  }

  /// Extracts only explicit actor/person-to-character links from X-Ray records.
  static List<Map<String, dynamic>> localPerformersForCharacter(
    String characterName,
    List<MediaItem> library,
  ) {
    final result = <String, Map<String, dynamic>>{};
    for (final media in library) {
      if (!_isVisible(media)) continue;
      for (final event in media.xrayEvents) {
        final directCharacter = _firstText(event, const ['characterName', 'character_name', 'character']);
        if (directCharacter != null && _sameCharacter(directCharacter, characterName)) {
          final name = _firstText(event, const [
            'personName', 'person_name', 'actorName', 'actor_name',
            'voiceActorName', 'voice_actor_name', 'performerName',
            'performer_name', 'voiceActor', 'actor', 'performer', 'person'
          ]);
          if (name != null) {
            _addPerformer(result, name, characterName, media.title,
                event['category']?.toString() ?? event['role']?.toString() ?? 'Acting');
          }
        }
        for (final key in const ['cast', 'performers', 'credits', 'people']) {
          final nested = event[key];
          if (nested is! List) continue;
          for (final raw in nested.whereType<Map>()) {
            final entry = Map<String, dynamic>.from(raw);
            final character = _firstText(entry, const ['characterName', 'character_name', 'character']);
            if (character == null || !_sameCharacter(character, characterName)) continue;
            final name = _firstText(entry, const [
              'personName', 'person_name', 'actorName', 'actor_name',
              'voiceActorName', 'voice_actor_name', 'performerName',
              'performer_name', 'voiceActor', 'actor', 'performer', 'person', 'name'
            ]);
            if (name != null) {
              _addPerformer(result, name, characterName, media.title,
                  entry['category']?.toString() ?? entry['role']?.toString() ?? 'Acting');
            }
          }
        }
      }
    }
    return result.values.toList(growable: false)
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

  static bool get isChildProfile {
    final level = AppController.instance.currentProfile?.governance.contentLevel;
    return level == ProfileContentLevel.littleKids ||
        level == ProfileContentLevel.kids ||
        level == ProfileContentLevel.olderKids;
  }

  static bool isMediaAllowedForProfile(MediaItem media, Profile? profile) {
    if (profile == null) return true;
    return media.isAccessibleTo(profile) &&
        TvProgrammingService.eligibleForProfile(media, profile);
  }

  static bool _isVisible(MediaItem media) =>
      isMediaAllowedForProfile(media, AppController.instance.currentProfile);

  static String _type(String value) => value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  static bool _sameCharacter(String candidate, String wanted) {
    final left = normalize(candidate);
    final right = normalize(wanted);
    if (left == right) return true;
    // Accept an explicit parenthetical or slash alias, but avoid folding a
    // distinct variant such as "Spider-Man Noir" into "Spider-Man".
    final raw = candidate.trim().toLowerCase();
    final base = wanted.trim().toLowerCase();
    return raw.startsWith('$base (') || raw.startsWith('$base /') || raw.startsWith('$base —');
  }

  static Iterable<String> _characterNamesInMap(Map<String, dynamic> data) sync* {
    for (final key in const ['characterName', 'character_name', 'character']) {
      final value = data[key];
      final text = value is Map
          ? _firstText(Map<String, dynamic>.from(value), const ['name', 'title', 'characterName'])
          : value?.toString();
      if (text != null && text.trim().isNotEmpty) yield text.trim();
    }
    for (final key in const ['cast', 'performers', 'credits', 'people']) {
      final list = data[key];
      if (list is! List) continue;
      for (final item in list.whereType<Map>()) {
        yield* _characterNamesInMap(Map<String, dynamic>.from(item));
      }
    }
  }

  static bool _mapHasCharacter(Map<String, dynamic> data, String characterName) =>
      _characterNamesInMap(data).any((candidate) => _sameCharacter(candidate, characterName));

  static void _addName(Map<String, String> names, String value) {
    final clean = value.trim();
    final key = normalize(clean);
    if (key.length < 2) return;
    names.putIfAbsent(key, () => clean);
  }

  static void _addPerformer(
    Map<String, Map<String, dynamic>> result,
    String name,
    String characterName,
    String workTitle,
    String role,
  ) {
    final clean = name.trim();
    final key = normalize(clean);
    if (key.isEmpty) return;
    final existing = result.putIfAbsent(key, () => <String, dynamic>{
      'id': 'local-person:$key',
      'name': clean,
      'category': role.toLowerCase().contains('voice') ? 'Voice Actor' : 'Actor',
      'characterName': characterName,
      'source': 'local-xray-credit',
      'workTitles': <String>[],
    });
    final titles = existing['workTitles'] as List<String>;
    if (!titles.contains(workTitle)) titles.add(workTitle);
  }

  static String? _firstText(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is Map) {
        final nested = Map<String, dynamic>.from(value);
        final name = _firstText(nested, const ['name', 'displayName', 'display_name', 'fullName', 'full_name']);
        if (name != null && name.trim().isNotEmpty) return name.trim();
      } else if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}

/// Detail view for a character identity assembled from local appearance tags
/// and registered person-to-work credits. Catalog-only entries are not marked
/// playable unless a matching accessible local library item exists.
class CharacterDiscoveryScreen extends StatefulWidget {
  final String characterName;

  const CharacterDiscoveryScreen({super.key, required this.characterName});

  @override
  State<CharacterDiscoveryScreen> createState() => _CharacterDiscoveryScreenState();
}

class _CharacterDiscoveryScreenState extends State<CharacterDiscoveryScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _remoteCredits = const [];

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  List<Map<String, dynamic>> _localCreditsForPerson(
    String personName,
    String characterName,
    List<MediaItem> library,
    Map<String, dynamic> person,
  ) {
    final result = <Map<String, dynamic>>[];
    final normalizedPerson = CharacterDiscoveryIndex.normalize(personName);
    final normalizedCharacter = CharacterDiscoveryIndex.normalize(characterName);

    for (final media in library) {
      if (!CharacterDiscoveryIndex.isMediaAllowedForProfile(
        media,
        AppController.instance.currentProfile,
      )) {
        continue;
      }
      var matched = false;
      for (final event in media.xrayEvents) {
        final directName = CharacterDiscoveryIndex._firstText(
          event,
          const [
            'personName', 'person_name', 'actorName', 'actor_name',
            'voiceActorName', 'voice_actor_name', 'performerName',
            'performer_name', 'voiceActor', 'actor', 'performer', 'person',
          ],
        );
        final directCharacter = CharacterDiscoveryIndex._firstText(
          event,
          const ['characterName', 'character_name', 'character'],
        );
        if (directName != null &&
            CharacterDiscoveryIndex.normalize(directName) == normalizedPerson &&
            directCharacter != null &&
            CharacterDiscoveryIndex._sameCharacter(directCharacter, characterName)) {
          matched = true;
          break;
        }
        for (final key in const ['cast', 'performers', 'credits', 'people']) {
          final nested = event[key];
          if (nested is! List) continue;
          for (final raw in nested.whereType<Map>()) {
            final entry = Map<String, dynamic>.from(raw);
            final name = CharacterDiscoveryIndex._firstText(entry, const [
              'personName', 'person_name', 'actorName', 'actor_name',
              'voiceActorName', 'voice_actor_name', 'performerName',
              'performer_name', 'voiceActor', 'actor', 'performer', 'person', 'name',
            ]);
            final character = CharacterDiscoveryIndex._firstText(
              entry,
              const ['characterName', 'character_name', 'character'],
            );
            if (name != null && character != null &&
                CharacterDiscoveryIndex.normalize(name) == normalizedPerson &&
                CharacterDiscoveryIndex.normalize(character) == normalizedCharacter) {
              matched = true;
              break;
            }
          }
          if (matched) break;
        }
        if (matched) break;
      }
      if (!matched) continue;
      result.add(<String, dynamic>{
        'id': 'local:${media.id}:$normalizedPerson',
        'mediaId': media.id,
        'title': media.title,
        'category': 'Acting',
        'type': media.type,
        'role': '${person['category'] ?? 'Actor'} as $characterName',
        'characterName': characterName,
        'year': media.releaseYear,
        'source': 'local-xray-credit',
      });
    }
    return result;
  }

  Future<void> _loadCredits() async {
    final api = AppController.instance.backendApi;
    // Child profiles may browse only explicit character tags and credits tied
    // to content already permitted in their own library. Do not fetch global
    // catalog appearances that could reveal restricted works.
    if (!api.isAuthenticated || CharacterDiscoveryIndex.isChildProfile) return;
    if (mounted) setState(() => _loading = true);
    try {
      final groups = await api.searchMediaCharacters(query: widget.characterName);
      final wanted = CharacterDiscoveryIndex.normalize(widget.characterName);
      Map<String, dynamic>? selected;
      for (final group in groups) {
        final name = group['name']?.toString() ?? '';
        if (CharacterDiscoveryIndex.normalize(name) == wanted) {
          selected = group;
          break;
        }
      }
      selected ??= groups.isEmpty ? null : groups.first;
      final credits = selected?['credits'];
      if (mounted) {
        setState(() {
          _remoteCredits = credits is List
              ? credits.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
              : const <Map<String, dynamic>>[];
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() { _loading = false; _error = error.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final appearances = CharacterDiscoveryIndex.titlesForCharacter(
      widget.characterName, library,
    );
    final shows = appearances.where((item) => item.isSeries ||
        CharacterDiscoveryIndex._type(item.type) == 'episode' ||
        CharacterDiscoveryIndex._type(item.type) == 'season').toList();
    final movies = appearances.where((item) =>
        CharacterDiscoveryIndex._type(item.type) == 'movie' ||
        CharacterDiscoveryIndex._type(item.type) == 'film').toList();
    final performers = <String, Map<String, dynamic>>{};
    // Prefer registered person identities when both a global credit and a
    // local X-Ray credit exist for the same performer.
    for (final row in _remoteCredits) {
      final person = row['person'] is Map ? Map<String, dynamic>.from(row['person'] as Map) : <String, dynamic>{};
      final credit = row['credit'] is Map ? Map<String, dynamic>.from(row['credit'] as Map) : <String, dynamic>{};
      final name = person['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      performers.putIfAbsent(CharacterDiscoveryIndex.normalize(name), () => <String, dynamic>{
        'id': person['id'] ?? name,
        'name': name,
        'category': (credit['category']?.toString().toLowerCase().contains('voice') ?? false) ? 'Voice Actor' : 'Actor',
        'characterName': credit['characterName'] ?? widget.characterName,
        'role': credit['role'],
        'source': 'media-intelligence-credit',
      });
    }
    for (final person in CharacterDiscoveryIndex.localPerformersForCharacter(widget.characterName, library)) {
      performers.putIfAbsent(CharacterDiscoveryIndex.normalize(person['name']?.toString() ?? ''), () => person);
    }
    final sortedPerformers = performers.values.toList(growable: false)
      ..sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
    final catalogRows = <String, Map<String, dynamic>>{};
    for (final row in _remoteCredits) {
      final work = row['work'] is Map ? Map<String, dynamic>.from(row['work'] as Map) : <String, dynamic>{};
      final id = work['id']?.toString() ?? '';
      final title = work['title']?.toString().trim() ?? '';
      if (id.isEmpty || title.isEmpty) continue;
      catalogRows.putIfAbsent(id, () => <String, dynamic>{...work, 'credit': row['credit'], 'person': row['person']});
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.characterName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CHARACTER EXPLORER', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(widget.characterName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Explore verified portrayals, shows, movies, and crossovers connected to this character.'),
              if (_loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
              if (_error != null) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Catalog credits could not load. Showing accessible local-library metadata where available.')),
            ],
          ))),
          if (performers.isNotEmpty) ...[
            const _CharacterSectionHeader('Actors & Voice Actors'),
            for (final person in sortedPerformers)
              Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                title: Text(person['name']?.toString() ?? ''),
                subtitle: Text('${person['category'] ?? 'Performer'} · ${person['characterName'] ?? widget.characterName}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                final personName = person['name']?.toString() ?? '';
                if (personName.trim().isEmpty) return;
                final localCredits = person['source'] == 'local-xray-credit'
                    ? _localCreditsForPerson(
                        personName,
                        widget.characterName,
                        library,
                        person,
                      )
                    : const <Map<String, dynamic>>[];
                Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => PeopleCareerTimelineScreen(
                  personName: personName,
                  localCredits: localCredits,
                  allowCreateIfMissing: false,
                )));
              },
              )),
          ],
          if (shows.isNotEmpty) ...[
            const _CharacterSectionHeader('Shows & Episodes'),
            for (final media in shows) _CharacterMediaTile(media: media),
          ],
          if (movies.isNotEmpty) ...[
            const _CharacterSectionHeader('Movies'),
            for (final media in movies) _CharacterMediaTile(media: media),
          ],
          if (catalogRows.isNotEmpty && !CharacterDiscoveryIndex.isChildProfile) ...[
            const _CharacterSectionHeader('Other known catalog credits'),
            for (final row in catalogRows.values)
              Builder(builder: (context) {
                final mediaId = row['id']?.toString() ?? '';
                MediaItem? existing;
                for (final media in library) {
                  if ((media.id == mediaId || media.canonicalWorkId == mediaId) &&
                      CharacterDiscoveryIndex.isMediaAllowedForProfile(
                        media,
                        AppController.instance.currentProfile,
                      )) {
                    existing = media;
                    break;
                  }
                }
                final resolvedMedia = existing;
                final workType = row['type']?.toString() ?? 'Media';
                final year = row['releaseYear']?.toString();
                final subtitle = <String>[workType, if (year != null && year.isNotEmpty) year, if (resolvedMedia == null) 'Not in this profile library'].join(' · ');
                return Card(child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.movie_outlined)),
                  title: Text(row['title']?.toString() ?? 'Untitled work'),
                  subtitle: Text(subtitle),
                  trailing: resolvedMedia == null ? const Icon(Icons.info_outline_rounded) : const Icon(Icons.chevron_right_rounded),
                  onTap: resolvedMedia == null ? null : () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: resolvedMedia))),
                ));
              }),
          ],
          if (appearances.isEmpty && performers.isEmpty && catalogRows.isEmpty && !_loading)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No character appearances are catalogued yet. Add character tags or sourced person-to-work credits to populate this page.'))),
        ],
      ),
    );
  }
}

class _CharacterSectionHeader extends StatelessWidget {
  final String title;
  const _CharacterSectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
  );
}

class _CharacterMediaTile extends StatelessWidget {
  final MediaItem media;
  const _CharacterMediaTile({required this.media});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    leading: media.imageUrl?.trim().isNotEmpty == true
        ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(media.imageUrl!, width: 52, height: 76, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 52, child: Icon(Icons.movie_outlined))) )
        : const CircleAvatar(child: Icon(Icons.movie_outlined)),
    title: Text(media.title),
    subtitle: Text([media.displayYearLabel, media.displaySeasonCount == null ? null : '${media.displaySeasonCount} Seasons', media.type].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ')),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: media))),
  ));
}
