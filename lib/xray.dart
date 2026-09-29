// FILE: `lib/xray.dart`.
// Purpose: Provides an X-Ray-style cast and production overlay for playback.
// Actor identity/photo services can be connected later without changing the
// player contract; the screen is driven by imported media metadata today.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_core.dart';
import 'localization.dart';

/// X-Ray screen showing cast, directors, music and other context for a title.
class XRayScreen extends StatelessWidget {
  final MediaItem media;
  final ValueListenable<Duration> playbackPosition;

  const XRayScreen({
    super.key,
    required this.media,
    required this.playbackPosition,
  });

  @override
  Widget build(BuildContext context) {
    final actors = media.actors.where((e) => e.trim().isNotEmpty).toList();
    final directors =
        media.directors.where((e) => e.trim().isNotEmpty).toList();
    final writers = media.writers.where((e) => e.trim().isNotEmpty).toList();

    final castEntries = actors.map(_parseCastEntry).toList();

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('X-Ray'),
        actions: [
          if (media.trailerUrl?.trim().isNotEmpty == true)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.verified_outlined),
            ),
        ],
      ),
      body: ValueListenableBuilder<Duration>(
        valueListenable: playbackPosition,
        builder: (context, currentPosition, _) {
          final event = _activeEvent(currentPosition);
          final people = event == null ? castEntries : _eventPeople(event);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
            children: [
              _heroCard(),
              const SizedBox(height: 18),
              if (event != null) ...[
                _sceneCard(event, currentPosition),
                const SizedBox(height: 18),
              ],
              if (people.isNotEmpty) ...[
                _heading(event == null ? 'CAST' : 'ON SCREEN',
                    Icons.people_alt_outlined),
                const SizedBox(height: 10),
                for (final cast in people) _castTile(context, cast),
              ],
              if (event != null) ...[
                _contextSection(
                    event, 'music', 'MUSIC', Icons.music_note_rounded),
                _contextSection(
                    event, 'trivia', 'TRIVIA', Icons.lightbulb_outline_rounded),
                _contextSection(
                    event, 'location', 'LOCATION', Icons.place_outlined),
                _contextSection(
                    event, 'objects', 'OBJECTS', Icons.category_outlined),
                _contextSection(
                    event, 'references', 'REFERENCES', Icons.link_rounded),
                _contextSection(
                    event, 'relatedMedia', 'RELATED', Icons.movie_outlined),
              ] else if (media.music.isNotEmpty) ...[
                const SizedBox(height: 18),
                _heading('MUSIC', Icons.music_note_rounded),
                const SizedBox(height: 10),
                _contextItems(media.music),
              ],
              if (directors.isNotEmpty) ...[
                const SizedBox(height: 18),
                _heading('DIRECTORS', Icons.movie_creation_outlined),
                const SizedBox(height: 10),
                for (final director in directors)
                  _creditTile(
                      name: director,
                      subtitle: tr('Director'),
                      icon: Icons.videocam_outlined),
              ],
              if (writers.isNotEmpty) ...[
                const SizedBox(height: 18),
                _heading('WRITERS', Icons.edit_note_rounded),
                const SizedBox(height: 10),
                for (final writer in writers)
                  _creditTile(
                      name: writer,
                      subtitle: tr('Writer'),
                      icon: Icons.edit_outlined),
              ],
              if (event == null && people.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: UniversalText(
                    'No cast or scene-specific X-Ray metadata is available for this title yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Map<String, dynamic>? _activeEvent(Duration position) {
    final events = media.xrayEvents
        .where((event) =>
            _timeSeconds(_eventValue(
                event, const ['startSeconds', 'startTime', 'start'])) !=
            null)
        .toList()
      ..sort((first, second) => _timeSeconds(
              _eventValue(first, const ['startSeconds', 'startTime', 'start']))!
          .compareTo(_timeSeconds(_eventValue(
              second, const ['startSeconds', 'startTime', 'start']))!));

    final seconds = position.inMilliseconds / 1000;
    for (var index = 0; index < events.length; index++) {
      final event = events[index];
      final start = _timeSeconds(
        _eventValue(event, const ['startSeconds', 'startTime', 'start']),
      )!;
      final explicitEnd = _timeSeconds(
        _eventValue(event, const ['endSeconds', 'endTime', 'end']),
      );
      final nextStart = index + 1 < events.length
          ? _timeSeconds(
              _eventValue(events[index + 1],
                  const ['startSeconds', 'startTime', 'start']),
            )
          : null;
      final end = explicitEnd ?? nextStart;
      if (seconds >= start && (end == null || seconds < end)) return event;
    }
    return null;
  }

  List<_CastEntry> _eventPeople(Map<String, dynamic> event) {
    final rawPeople = event['people'] ?? event['cast'];
    if (rawPeople is! List) return const <_CastEntry>[];
    return rawPeople
        .map((person) {
          if (person is! Map) return _parseCastEntry(person.toString());
          final data = Map<String, dynamic>.from(person);
          return _CastEntry(
            actor: (data['actor'] ??
                    data['actorName'] ??
                    data['name'] ??
                    'Unknown')
                .toString(),
            character: (data['character'] ??
                    data['characterName'] ??
                    data['role'] ??
                    'Featured cast')
                .toString(),
            biography: (data['biography'] ?? data['bio'])?.toString(),
            characterBiography:
                (data['characterBiography'] ?? data['characterBio'])
                    ?.toString(),
            filmography: _eventStrings(data['filmography']),
            relatedCharacters: _eventStrings(data['relatedCharacters']),
          );
        })
        .where((entry) => entry.actor.trim().isNotEmpty)
        .toList();
  }

  Object? _eventValue(Map<String, dynamic> event, List<String> keys) {
    for (final key in keys) {
      if (event[key] != null) return event[key];
    }
    return null;
  }

  double? _timeSeconds(Object? value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final numeric = double.tryParse(text);
    if (numeric != null) return numeric;
    final parts = text.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final parsed = parts.map(double.tryParse).toList();
    if (parsed.any((part) => part == null)) return null;
    if (parts.length == 2) return parsed[0]! * 60 + parsed[1]!;
    return parsed[0]! * 3600 + parsed[1]! * 60 + parsed[2]!;
  }

  List<String> _eventStrings(Object? value) {
    if (value is String) {
      return value.trim().isEmpty ? const [] : [value.trim()];
    }
    if (value is! List) return const [];
    return value
        .map((entry) {
          if (entry is Map) {
            return (entry['title'] ?? entry['name'] ?? entry['label'] ?? '')
                .toString()
                .trim();
          }
          return entry.toString().trim();
        })
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  Widget _sceneCard(Map<String, dynamic> event, Duration position) {
    final title =
        (event['title'] ?? event['scene'] ?? 'Current scene').toString();
    final description = (event['description'] ?? event['summary'])?.toString();
    final location = event['location']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                    child: UniversalText('CURRENT SCENE',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1))),
                Text(_formatPosition(position),
                    style: const TextStyle(color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            if (description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(description!,
                  style: const TextStyle(color: Colors.white70, height: 1.45)),
            ],
            if (location?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.place_outlined,
                      size: 16, color: Colors.white60),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(location!,
                          style: const TextStyle(color: Colors.white60))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contextSection(
      Map<String, dynamic> event, String key, String title, IconData icon) {
    final values = _eventStrings(event[key]);
    if (values.isEmpty || key == 'location') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(title, icon),
          const SizedBox(height: 10),
          _contextItems(values),
        ],
      ),
    );
  }

  Widget _contextItems(List<String> values) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < values.length; index++)
            ListTile(
              dense: true,
              title: Text(values[index]),
              trailing:
                  index == values.length - 1 ? null : const Divider(height: 1),
            ),
        ],
      ),
    );
  }

  String _formatPosition(Duration position) {
    final minutes = position.inMinutes;
    final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  _CastEntry _parseCastEntry(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return const _CastEntry(actor: 'Unknown', character: 'Featured cast');
    }

    final patterns = [
      RegExp(r'^(.*?)(?:\s+as\s+|\s+-\s+|\s+\|\s+|\s*/\s*)(.+)$',
          caseSensitive: false),
      RegExp(r'^(.*?)(?:\s+\((.+)\))$', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final actor = match.group(1)?.trim();
        final character = match.group(2)?.trim();
        if (actor != null &&
            actor.isNotEmpty &&
            character != null &&
            character.isNotEmpty) {
          return _CastEntry(actor: actor, character: character);
        }
      }
    }

    return _CastEntry(actor: normalized, character: 'Featured cast');
  }

  Widget _castTile(BuildContext context, _CastEntry cast) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ActorBiographyScreen(
              actorName: cast.actor,
              characterName: cast.character,
              biography: cast.biography,
              characterBiography: cast.characterBiography,
              filmography: cast.filmography,
              relatedCharacters: cast.relatedCharacters,
              media: media,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                child: Text(
                  cast.actor.isNotEmpty ? cast.actor[0].toUpperCase() : 'A',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cast.actor,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'as ${cast.character}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (cast.biography?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        cast.biography!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white60, height: 1.45),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1B1B), Color(0xFF0D0D0D)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 72,
              height: 104,
              child: _poster(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UniversalText(
                  'X-RAY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  media.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (media.releaseYear != null) '${media.releaseYear}',
                    if (media.genres.isNotEmpty)
                      media.genres.take(2).join(' • '),
                  ].join(' • '),
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _poster() {
    final url = media.imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return Container(
        color: const Color(0xFF181818),
        child: const Icon(Icons.movie_outlined, color: Colors.white38),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF181818),
        child: const Icon(Icons.movie_outlined, color: Colors.white38),
      ),
    );
  }

  Widget _heading(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _creditTile({
    required String name,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          child: Icon(icon),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing:
            onTap == null ? null : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

/// Displays a person-focused X-Ray card for an actor.
class ActorBiographyScreen extends StatelessWidget {
  final String actorName;
  final String? characterName;
  final String? biography;
  final String? characterBiography;
  final List<String> filmography;
  final List<String> relatedCharacters;
  final MediaItem media;

  const ActorBiographyScreen({
    super.key,
    required this.actorName,
    this.characterName,
    this.biography,
    this.characterBiography,
    this.filmography = const <String>[],
    this.relatedCharacters = const <String>[],
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final initial = actorName.trim().isEmpty ? '?' : actorName.trim()[0];
    final character = (characterName ?? 'Featured cast').trim();

    return Scaffold(
      appBar: AppBar(title: Text(actorName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 64,
                  child: Text(
                    initial.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  actorName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                UniversalText(
                  character.isNotEmpty ? 'AS $character' : 'ACTOR PROFILE',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (biography?.trim().isNotEmpty == true)
            _profileSection('BIOGRAPHY', [biography!.trim()]),
          if (characterBiography?.trim().isNotEmpty == true)
            _profileSection('CHARACTER', [characterBiography!.trim()]),
          if (filmography.isNotEmpty)
            _profileSection('FILMOGRAPHY', filmography),
          if (relatedCharacters.isNotEmpty)
            _profileSection('RELATED CHARACTERS', relatedCharacters),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.movie_outlined),
              title: const UniversalText('Featured in'),
              subtitle: Text(media.title),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileSection(String title, List<String> values) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: Colors.white54)),
            const SizedBox(height: 9),
            for (final value in values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(value,
                    style: const TextStyle(color: Colors.white70, height: 1.5)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CastEntry {
  final String actor;
  final String character;
  final String? biography;
  final String? characterBiography;
  final List<String> filmography;
  final List<String> relatedCharacters;

  const _CastEntry({
    required this.actor,
    required this.character,
    this.biography,
    this.characterBiography,
    this.filmography = const <String>[],
    this.relatedCharacters = const <String>[],
  });
}
