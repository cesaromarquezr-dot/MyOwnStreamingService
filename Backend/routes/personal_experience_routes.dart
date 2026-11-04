// FILE: Backend/routes/personal_experience_routes.dart
// Profile-scoped listening history, music statistics, episode notebooks,
// disc-to-episode mappings, preservation records, and entertainment timeline.
// All writes are bounded JSON records; audio samples and filesystem paths are
// never accepted by this API.

import 'dart:convert';
import 'dart:io';

import '../database/database.dart';
import '../middleware/authentication.dart';
import '../models/account.dart';
import '../models/profile.dart';

class PersonalExperienceRoutes {
  PersonalExperienceRoutes({
    required this.authentication,
    required this.database,
  });

  final AuthenticationMiddleware authentication;
  final Database database;
  static const String _prefix = '/api/v1/experience';
  static const int _maxHistory = 2000;
  static const int _maxTimeline = 3000;
  static const int _maxEpisodeNotes = 2500;
  static const int _maxDiscMappings = 500;
  static const int _maxPreservationRecords = 2000;

  Future<void> handle(HttpRequest request) async {
    _cors(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final Account? account = authentication.authenticate(request);
    if (account == null) {
      await _send(request.response, HttpStatus.unauthorized, {
        'success': false,
        'error': 'Authentication required.',
      });
      return;
    }

    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == _prefix) {
        final profile = _profile(account, request.uri.queryParameters['profileId']);
        if (profile == null) return _notFound(request.response, 'Profile not found.');
        await _send(request.response, HttpStatus.ok, {
          'success': true,
          'profileId': profile.id,
          'experience': _experience(profile),
          'musicStats': _musicStats(_list(profile, 'musicHistory')),
          'timeline': _timeline(profile),
        });
        return;
      }

      if (path == '$_prefix/interface-designs') {
        if (request.method == 'GET') {
          final profile = _profile(account, request.uri.queryParameters['profileId']);
          if (profile == null) return _notFound(request.response, 'Profile not found.');
          final config = profile.experienceData['interfaceExperienceConfig'];
          await _send(request.response, HttpStatus.ok, {
            'success': true,
            'profileId': profile.id,
            'config': config is Map ? Map<String, dynamic>.from(config) : <String, dynamic>{},
          });
          return;
        }
        if (request.method == 'PUT') {
          final body = await _readBody(request);
          final profile = _profile(account, body['profileId']?.toString());
          if (profile == null) return _notFound(request.response, 'Profile not found.');
          final rawConfig = body['config'];
          if (rawConfig is! Map) {
            return _send(request.response, HttpStatus.badRequest, {
              'success': false,
              'error': 'A configuration object is required.',
            });
          }
          final config = Map<String, dynamic>.from(rawConfig);
          if (jsonEncode(config).length > 220 * 1024) {
            return _send(request.response, HttpStatus.badRequest, {
              'success': false,
              'error': 'Interface designs exceed the 220 KB profile limit.',
            });
          }
          if ((config['schemaVersion'] as num?)?.toInt() != 1) {
            return _send(request.response, HttpStatus.badRequest, {
              'success': false,
              'error': 'Unsupported interface design schema version.',
            });
          }
          profile.experienceData['interfaceExperienceConfig'] = config;
          await database.persistAccountAndWait(account);
          await _send(request.response, HttpStatus.ok, {
            'success': true,
            'profileId': profile.id,
            'savedAt': DateTime.now().toUtc().toIso8601String(),
          });
          return;
        }
      }

      if (request.method == 'GET' && path == '$_prefix/music/history') {
        final profile = _profile(account, request.uri.queryParameters['profileId']);
        if (profile == null) return _notFound(request.response, 'Profile not found.');
        final limit = _boundedInt(request.uri.queryParameters['limit'], 100, 1, 500);
        final events = _list(profile, 'musicHistory').reversed.take(limit).toList();
        await _send(request.response, HttpStatus.ok, {'success': true, 'events': events});
        return;
      }

      if (request.method == 'GET' && path == '$_prefix/music/stats') {
        final profile = _profile(account, request.uri.queryParameters['profileId']);
        if (profile == null) return _notFound(request.response, 'Profile not found.');
        final year = int.tryParse(request.uri.queryParameters['year'] ?? '');
        final scope = request.uri.queryParameters['scope']?.trim().toLowerCase() ?? 'profile';
        var musicHistory = _list(profile, 'musicHistory');
        if (scope == 'account') {
          // The active profile is always included. Other profile histories are
          // included only when that profile opted into household sharing.
          for (final other in account.profiles) {
            if (other.id == profile.id ||
                !other.recommendationPreferences.shareHistoryWithOtherProfiles) {
              continue;
            }
            musicHistory = <Map<String, dynamic>>[
              ...musicHistory,
              ..._list(other, 'musicHistory'),
            ];
          }
        }
        await _send(request.response, HttpStatus.ok, {
          'success': true,
          'scope': scope == 'account' ? 'account-consented' : 'profile',
          'stats': _musicStats(musicHistory, year: year),
        });
        return;
      }

      if (request.method == 'POST' && path == '$_prefix/music/events') {
        final body = await _readBody(request);
        final profile = _profile(account, body['profileId']?.toString());
        if (profile == null) return _notFound(request.response, 'Profile not found.');
        final title = _clean(body['title'], 180);
        final artist = _clean(body['artist'], 180);
        if (title.isEmpty || artist.isEmpty) {
          return _send(request.response, HttpStatus.badRequest, {
            'success': false,
            'error': 'Song title and artist are required.',
          });
        }
        final requestedKind = body['eventType']?.toString();
        final kind = <String>{'identified', 'completed'}.contains(requestedKind)
            ? requestedKind!
            : 'played';
        final history = _list(profile, 'musicHistory');
        final recordedAt = DateTime.now().toUtc().toIso8601String();
        Map<String, dynamic> event;
        if (kind == 'completed') {
          // Completion enriches the matching play rather than creating a
          // second listening-history row for the same playback session.
          final trackId = _clean(body['trackId'], 160);
          final matchingIndex = history.lastIndexWhere((row) =>
              row['eventType'] == 'played' &&
              row['title']?.toString() == title &&
              row['artist']?.toString() == artist &&
              (trackId.isEmpty || row['trackId']?.toString() == trackId));
          final duration = _boundedInt(body['durationSeconds']?.toString(), 0, 0, 86400);
          if (matchingIndex >= 0) {
            event = history[matchingIndex];
            event['durationSeconds'] = duration;
            event['completedAt'] = recordedAt;
            event['completed'] = true;
            history[matchingIndex] = event;
          } else {
            event = <String, dynamic>{
              'id': 'music_${DateTime.now().microsecondsSinceEpoch}',
              'eventType': 'played',
              'title': title,
              'artist': artist,
              'album': _clean(body['album'], 180),
              'trackId': trackId,
              'genre': _clean(body['genre'], 80),
              'source': _clean(body['source'], 60, fallback: 'player'),
              'durationSeconds': duration,
              'completedAt': recordedAt,
              'completed': true,
              'artworkUrl': _safeHttps(body['artworkUrl']),
              'recordedAt': recordedAt,
            };
            history.add(event);
          }
          profile.experienceData['musicHistory'] = history;
        } else {
          event = <String, dynamic>{
            'id': 'music_${DateTime.now().microsecondsSinceEpoch}',
            'eventType': kind,
            'title': title,
            'artist': artist,
            'album': _clean(body['album'], 180),
            'trackId': _clean(body['trackId'], 160),
            'genre': _clean(body['genre'], 80),
            'source': _clean(body['source'], 60, fallback: 'player'),
            'durationSeconds': 0,
            'artworkUrl': _safeHttps(body['artworkUrl']),
            'recordedAt': recordedAt,
          };
          _append(profile, 'musicHistory', event, _maxHistory);
          _appendTimeline(profile, {
            'id': event['id'],
            'type': kind == 'identified' ? 'songIdentified' : 'musicPlayed',
            'title': kind == 'identified' ? 'Identified ${event['title']}' : 'Played ${event['title']}',
            'subtitle': artist,
            'timestamp': event['recordedAt'],
            'metadata': {'album': event['album'], 'trackId': event['trackId']},
          });
        }
        if (history.length > _maxHistory) {
          history.removeRange(0, history.length - _maxHistory);
          profile.experienceData['musicHistory'] = history;
        }
        await database.persistAccountAndWait(account);
        await _send(request.response, HttpStatus.created, {
          'success': true,
          'event': event,
          'stats': _musicStats(_list(profile, 'musicHistory')),
        });
        return;
      }

      if (path == '$_prefix/episode-notes') {
        if (request.method == 'GET') {
          final profile = _profile(account, request.uri.queryParameters['profileId']);
          if (profile == null) return _notFound(request.response, 'Profile not found.');
          final seriesId = request.uri.queryParameters['seriesId']?.trim();
          final season = int.tryParse(request.uri.queryParameters['seasonNumber'] ?? '');
          var notes = _list(profile, 'episodeNotes');
          if (seriesId != null && seriesId.isNotEmpty) {
            notes = notes.where((row) => row['seriesId']?.toString() == seriesId).toList();
          }
          if (season != null) {
            notes = notes.where((row) => row['seasonNumber'] == season).toList();
          }
          await _send(request.response, HttpStatus.ok, {'success': true, 'notes': notes});
          return;
        }
        if (request.method == 'POST' || request.method == 'PUT') {
          final body = await _readBody(request);
          final profile = _profile(account, body['profileId']?.toString());
          if (profile == null) return _notFound(request.response, 'Profile not found.');
          final seriesTitle = _clean(body['seriesTitle'], 180);
          final season = int.tryParse(body['seasonNumber']?.toString() ?? '') ?? -1;
          final episode = int.tryParse(body['episodeNumber']?.toString() ?? '') ?? -1;
          if (seriesTitle.isEmpty || season < 0 || episode < 0) {
            return _send(request.response, HttpStatus.badRequest, {
              'success': false,
              'error': 'Show title, season number, and episode number are required.',
            });
          }
          final seriesId = _clean(body['seriesId'], 160, fallback: _slug(seriesTitle));
          final key = '$seriesId:$season:$episode';
          final rows = _list(profile, 'episodeNotes');
          final old = rows.indexWhere((row) => row['key'] == key);
          final note = <String, dynamic>{
            'key': key,
            'seriesId': seriesId,
            'seriesTitle': seriesTitle,
            'seasonNumber': season,
            'episodeNumber': episode,
            'episodeTitle': _clean(body['episodeTitle'], 180, fallback: 'Episode $episode'),
            'officialOverview': _clean(body['officialOverview'], 1200),
            'openingNotes': _stringList(body['openingNotes'], 12, 240),
            'tags': _stringList(body['tags'], 20, 50),
            'durationSeconds': _boundedInt(body['durationSeconds']?.toString(), 0, 0, 86400),
            'discLabel': _clean(body['discLabel'], 120),
            'armTitleId': _clean(body['armTitleId'], 80),
            'confidence': _boundedDouble(body['confidence'], 0, 0, 1),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
            if (old >= 0) 'createdAt': rows[old]['createdAt'],
          };
          note.putIfAbsent('createdAt', () => note['updatedAt']);
          if (old >= 0) {
            rows[old] = note;
          } else {
            rows.add(note);
            if (rows.length > _maxEpisodeNotes) rows.removeAt(0);
          }
          profile.experienceData['episodeNotes'] = rows;
          _appendTimeline(profile, {
            'id': 'episode_note_${DateTime.now().microsecondsSinceEpoch}',
            'type': 'episodeNoteSaved',
            'title': 'Updated ${note['seriesTitle']} S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}',
            'subtitle': (note['openingNotes'] as List).join(' · '),
            'timestamp': note['updatedAt'],
          });
          await database.persistAccountAndWait(account);
          await _send(request.response, HttpStatus.ok, {'success': true, 'note': note});
          return;
        }
      }

      if (path == '$_prefix/disc-mappings') {
        if (request.method == 'GET') {
          final profile = _profile(account, request.uri.queryParameters['profileId']);
          if (profile == null) return _notFound(request.response, 'Profile not found.');
          await _send(request.response, HttpStatus.ok, {'success': true, 'mappings': _list(profile, 'discMappings')});
          return;
        }
        if (request.method == 'POST' || request.method == 'PUT') {
          final body = await _readBody(request);
          final profile = _profile(account, body['profileId']?.toString());
          if (profile == null) return _notFound(request.response, 'Profile not found.');
          final fingerprint = _clean(body['discFingerprint'], 180);
          final discLabel = _clean(body['discLabel'], 180);
          final show = _clean(body['seriesTitle'], 180);
          if (fingerprint.isEmpty || show.isEmpty) {
            return _send(request.response, HttpStatus.badRequest, {'success': false, 'error': 'A disc fingerprint and show title are required.'});
          }
          final rows = _list(profile, 'discMappings');
          final existing = rows.indexWhere((row) => row['discFingerprint'] == fingerprint);
          final mapping = <String, dynamic>{
            'discFingerprint': fingerprint,
            'discLabel': discLabel,
            'seriesTitle': show,
            'seriesId': _clean(body['seriesId'], 160, fallback: _slug(show)),
            'seasonNumber': _boundedInt(body['seasonNumber']?.toString(), 0, 0, 200),
            'titleMappings': _jsonRows(body['titleMappings'], 120),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          };
          if (existing >= 0) rows[existing] = mapping; else rows.add(mapping);
          if (rows.length > _maxDiscMappings) rows.removeAt(0);
          profile.experienceData['discMappings'] = rows;
          _appendTimeline(profile, {
            'id': 'disc_mapping_${DateTime.now().microsecondsSinceEpoch}',
            'type': 'discMappingSaved',
            'title': 'Remembered disc: $discLabel',
            'subtitle': '$show · Season ${mapping['seasonNumber']}',
            'timestamp': mapping['updatedAt'],
          });
          await database.persistAccountAndWait(account);
          await _send(request.response, HttpStatus.ok, {'success': true, 'mapping': mapping});
          return;
        }
      }

      if (path == '$_prefix/concerts') {
        if (request.method == 'GET') {
          final profile = _profile(account, request.uri.queryParameters['profileId']);
          if (profile == null) return _notFound(request.response, 'Profile not found.');
          await _send(request.response, HttpStatus.ok, {
            'success': true,
            'concerts': _list(profile, 'concerts'),
          });
          return;
        }
        if (request.method == 'POST' || request.method == 'PUT') {
          final body = await _readBody(request);
          final profile = _profile(account, body['profileId']?.toString());
          if (profile == null) return _notFound(request.response, 'Profile not found.');
          final artist = _clean(body['artist'], 180);
          final rawDate = _clean(body['eventDate'], 40);
          final parsedDate = DateTime.tryParse(rawDate);
          if (artist.isEmpty || parsedDate == null) {
            return _send(request.response, HttpStatus.badRequest, {
              'success': false,
              'error': 'Artist and a valid event date are required.',
            });
          }
          final rows = _list(profile, 'concerts');
          final id = _clean(body['id'], 120, fallback: 'concert_${DateTime.now().microsecondsSinceEpoch}');
          final event = <String, dynamic>{
            'id': id,
            'artist': artist,
            'eventDate': DateTime(parsedDate.year, parsedDate.month, parsedDate.day).toIso8601String(),
            'city': _clean(body['city'], 120),
            'venue': _clean(body['venue'], 180),
            'ticketUrl': _safeHttps(body['ticketUrl']),
            'source': _clean(body['source'], 40, fallback: 'manual'),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          };
          final index = rows.indexWhere((row) => row['id'] == id);
          if (index >= 0) rows[index] = event; else rows.add(event);
          if (rows.length > 500) rows.removeAt(0);
          profile.experienceData['concerts'] = rows;
          _appendTimeline(profile, {
            'id': 'concert_${DateTime.now().microsecondsSinceEpoch}',
            'type': 'concertSaved',
            'title': 'Saved ${event['artist']} concert',
            'subtitle': '${event['venue']} · ${event['city']}',
            'timestamp': event['updatedAt'],
          });
          await database.persistAccountAndWait(account);
          await _send(request.response, HttpStatus.ok, {'success': true, 'concert': event});
          return;
        }
      }

      if (path == '$_prefix/preservation') {
        if (request.method == 'GET') {
          final profile = _profile(account, request.uri.queryParameters['profileId']);
          if (profile == null) return _notFound(request.response, 'Profile not found.');
          await _send(request.response, HttpStatus.ok, {'success': true, 'records': _list(profile, 'preservationRecords')});
          return;
        }
        if (request.method == 'POST' || request.method == 'PUT') {
          final body = await _readBody(request);
          final profile = _profile(account, body['profileId']?.toString());
          if (profile == null) return _notFound(request.response, 'Profile not found.');
          final title = _clean(body['title'], 180);
          if (title.isEmpty) return _send(request.response, HttpStatus.badRequest, {'success': false, 'error': 'A media title is required.'});
          final id = _clean(body['id'], 120, fallback: 'pres_${DateTime.now().microsecondsSinceEpoch}');
          final rows = _list(profile, 'preservationRecords');
          final record = <String, dynamic>{
            'id': id,
            'title': title,
            'mediaType': _clean(body['mediaType'], 40, fallback: 'unknown'),
            'source': _clean(body['source'], 60, fallback: 'disc'),
            'status': _clean(body['status'], 40, fallback: 'queued'),
            'verificationStatus': _clean(body['verificationStatus'], 40, fallback: 'pending'),
            'checksum': _clean(body['checksum'], 160),
            'fileSizeBytes': _boundedInt(body['fileSizeBytes']?.toString(), 0, 0, 9007199254740991),
            'discLabel': _clean(body['discLabel'], 180),
            'mediaId': _clean(body['mediaId'], 160),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          };
          final index = rows.indexWhere((row) => row['id'] == id);
          if (index >= 0) rows[index] = record; else rows.add(record);
          if (rows.length > _maxPreservationRecords) rows.removeAt(0);
          profile.experienceData['preservationRecords'] = rows;
          _appendTimeline(profile, {
            'id': 'preservation_${DateTime.now().microsecondsSinceEpoch}',
            'type': 'preservationUpdated',
            'title': 'Preservation record: $title',
            'subtitle': '${record['status']} · ${record['verificationStatus']}',
            'timestamp': record['updatedAt'],
          });
          await database.persistAccountAndWait(account);
          await _send(request.response, HttpStatus.ok, {'success': true, 'record': record});
          return;
        }
      }

      if (request.method == 'GET' && path == '$_prefix/timeline') {
        final profile = _profile(account, request.uri.queryParameters['profileId']);
        if (profile == null) return _notFound(request.response, 'Profile not found.');
        await _send(request.response, HttpStatus.ok, {'success': true, 'timeline': _timeline(profile)});
        return;
      }

      await _send(request.response, HttpStatus.methodNotAllowed, {
        'success': false,
        'error': 'Experience endpoint or HTTP method not supported.',
      });
    } catch (error) {
      await _send(request.response, HttpStatus.internalServerError, {
        'success': false,
        'error': 'Unable to update personal entertainment data.',
      });
    }
  }

  Profile? _profile(Account account, String? rawId) {
    final id = rawId?.trim() ?? '';
    if (id.isEmpty || id.length > 128) return null;
    return account.getProfileById(id);
  }

  Map<String, dynamic> _experience(Profile profile) => {
        'musicHistory': _list(profile, 'musicHistory'),
        'episodeNotes': _list(profile, 'episodeNotes'),
        'discMappings': _list(profile, 'discMappings'),
        'preservationRecords': _list(profile, 'preservationRecords'),
        'concerts': _list(profile, 'concerts'),
      };

  List<Map<String, dynamic>> _list(Profile profile, String key) {
    final raw = profile.experienceData[key];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  void _append(Profile profile, String key, Map<String, dynamic> item, int max) {
    final rows = _list(profile, key)..add(item);
    if (rows.length > max) rows.removeRange(0, rows.length - max);
    profile.experienceData[key] = rows;
  }

  void _appendTimeline(Profile profile, Map<String, dynamic> item) {
    _append(profile, 'timeline', item, _maxTimeline);
  }

  List<Map<String, dynamic>> _timeline(Profile profile) {
    final events = _list(profile, 'timeline');
    for (final mediaId in profile.watchHistory.take(150)) {
      final media = database.getMediaById(mediaId);
      if (media == null) continue;
      events.add({
        'id': 'watch_$mediaId',
        'type': 'mediaWatched',
        'title': 'Watched ${media.title}',
        'subtitle': media.type,
        'timestamp': profile.watchHistoryTimestamps[mediaId]?.toUtc().toIso8601String() ?? '',
      });
    }
    events.sort((a, b) => (DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return events.take(500).toList();
  }

  Map<String, dynamic> _musicStats(List<Map<String, dynamic>> rows, {int? year}) {
    final events = rows.where((row) {
      if (row['eventType']?.toString() != 'played') return false;
      if (year == null) return true;
      final date = DateTime.tryParse(row['recordedAt']?.toString() ?? '');
      return date?.year == year;
    }).toList();
    final identified = rows.where((row) {
      if (row['eventType']?.toString() != 'identified') return false;
      if (year == null) return true;
      final date = DateTime.tryParse(row['recordedAt']?.toString() ?? '');
      return date?.year == year;
    }).length;
    List<Map<String, dynamic>> top(String key) {
      final counts = <String, int>{};
      for (final row in events) {
        final value = row[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) counts[value] = (counts[value] ?? 0) + 1;
      }
      final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return entries.take(10).map((entry) => {'name': entry.key, 'plays': entry.value}).toList();
    }
    final monthly = <String, int>{};
    for (final row in events) {
      final date = DateTime.tryParse(row['recordedAt']?.toString() ?? '');
      if (date == null) continue;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      monthly[key] = (monthly[key] ?? 0) + 1;
    }
    final listenSeconds = events.fold<int>(0, (total, row) => total + _boundedInt(row['durationSeconds']?.toString(), 0, 0, 86400));
    return {
      'playCount': events.length,
      'identifiedCount': identified,
      'listeningMinutes': listenSeconds ~/ 60,
      'uniqueArtists': events.map((row) => row['artist']?.toString().trim().toLowerCase()).whereType<String>().where((s) => s.isNotEmpty).toSet().length,
      'uniqueSongs': events.map((row) => '${row['title']}|${row['artist']}'.toLowerCase()).toSet().length,
      'topArtists': top('artist'),
      'topSongs': top('title'),
      'topAlbums': top('album'),
      'topGenres': top('genre'),
      'monthlyPlays': monthly,
      'periodYear': year,
    };
  }

  Map<String, dynamic> _readBodyMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Future<Map<String, dynamic>> _readBody(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    if (text.length > 256 * 1024) throw const FormatException('Request body is too large.');
    final decoded = text.trim().isEmpty ? <String, dynamic>{} : jsonDecode(text);
    if (decoded is! Map) throw const FormatException('Request body must be a JSON object.');
    return Map<String, dynamic>.from(decoded);
  }

  List<String> _stringList(dynamic value, int maxItems, int maxLength) {
    if (value is! List) return <String>[];
    final result = <String>[];
    for (final item in value.take(maxItems)) {
      final clean = _clean(item, maxLength);
      if (clean.isNotEmpty && !result.contains(clean)) result.add(clean);
    }
    return result;
  }

  List<Map<String, dynamic>> _jsonRows(dynamic value, int maxItems) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.take(maxItems).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  String _clean(dynamic value, int maxLength, {String fallback = ''}) {
    final text = value?.toString().replaceAll(RegExp(r'[\u0000-\u001f]'), ' ').trim() ?? '';
    if (text.isEmpty) return fallback;
    return text.length <= maxLength ? text : text.substring(0, maxLength);
  }

  String _safeHttps(dynamic value) {
    final text = _clean(value, 2048);
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority || uri.userInfo.isNotEmpty) return '';
    return text;
  }

  String _slug(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

  int _boundedInt(String? raw, int fallback, int min, int max) {
    final parsed = int.tryParse(raw ?? '');
    return (parsed ?? fallback).clamp(min, max).toInt();
  }

  double _boundedDouble(dynamic raw, double fallback, double min, double max) {
    final parsed = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) return fallback;
    return parsed.clamp(min, max).toDouble();
  }

  Future<void> _notFound(HttpResponse response, String error) =>
      _send(response, HttpStatus.notFound, {'success': false, 'error': error});

  Future<void> _send(HttpResponse response, int status, Map<String, dynamic> data) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }

  void _cors(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, Authorization');
  }
}
