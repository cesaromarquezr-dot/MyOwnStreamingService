// FILE: Backend/routes/media_intelligence_routes.dart.
// Purpose: Exposes the unified media graph, session, artwork and intelligence
// foundation.
//
// Security notes:
// - All media-intelligence endpoints require authentication.
// - Profile/device/session mutations are scoped to profiles belonging to the
//   authenticated account.
// - Client-controlled IDs are accepted for idempotent synchronization, but
//   empty identifiers and malformed payloads are rejected.
// - JSON responses are non-cacheable because they may contain account/profile
//   activity.
// - Service-owned state remains behind MediaIntelligenceService.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../models/media_artwork.dart';
import '../models/media_relationship.dart';
import '../models/media_session.dart';
import '../models/media_work.dart';
import '../models/media_season.dart';
import '../models/media_person.dart';
import '../services/media_intelligence_service.dart';
import '../supabase_store.dart';

class MediaIntelligenceRoutes {
  static const String _prefix = '/api/v1/media-intelligence';

  static const int _maxBodyBytes = 1024 * 1024;
  static const int _maxIdLength = 256;
  static const int _maxNameLength = 200;
  static const int _maxCollectionItems = 500;

  final AuthenticationMiddleware authentication;
  final MediaIntelligenceService service;
  final SupabaseStore store;

  MediaIntelligenceRoutes({
    required this.authentication,
    required this.service,
    required this.store,
  });

  /// Handles all `/api/v1/media-intelligence/*` requests.
  Future<void> handle(HttpRequest request) async {
    _applyCors(request);

    if (request.method == 'OPTIONS') {
      await _empty(request, 204);
      return;
    }

    final account = authentication.authenticate(request);

    if (account == null) {
      await _json(request.response, 401, {
        'success': false,
        'error': 'Authentication required.',
      });
      return;
    }

    final path = request.uri.path;

    try {
      if (request.method == 'GET' &&
          path == '$_prefix/capabilities') {
        await _json(request.response, 200, {
          'success': true,
          ...service.capabilities(),
        });
        return;
      }

      if (request.method == 'GET' &&
          path == '$_prefix/health') {
        await _json(request.response, 200, {
          'success': true,
          'health': service.libraryHealth(),
        });
        return;
      }

      if (request.method == 'GET' &&
          path == '$_prefix/works') {
        await _getWorks(request);
        return;
      }

      if (request.method == 'GET' && path == '$_prefix/knowledge') {
        final mediaWorkId = _requiredId(
          request.uri.queryParameters['mediaWorkId'],
          field: 'mediaWorkId',
        );
        final facts = await store.loadPublishedKnowledgeFacts(mediaWorkId: mediaWorkId);
        await _json(request.response, 200, {
          'success': true,
          'facts': facts,
        });
        return;
      }

      if (request.method == 'GET' && path == '$_prefix/knowledge/stories') {
        final mediaWorkId = _requiredId(
          request.uri.queryParameters['mediaWorkId'],
          field: 'mediaWorkId',
        );
        final stories = await store.loadPublishedKnowledgeStories(mediaWorkId: mediaWorkId);
        await _json(request.response, 200, {
          'success': true,
          'stories': stories,
        });
        return;
      }

      if (request.method == 'GET' && path == '$_prefix/people') {
        final query = request.uri.queryParameters['q']?.trim().toLowerCase() ?? '';
        final people = service.people.values
            .where((person) => query.isEmpty || person.name.toLowerCase().contains(query))
            .map((person) => person.toJson()).toList(growable: false);
        await _json(request.response, 200, {'success': true, 'people': people});
        return;
      }

      if (request.method == 'GET' && path == '$_prefix/people/timeline') {
        final personId = _requiredId(request.uri.queryParameters['personId'], field: 'personId');
        final person = service.people[personId];
        if (person == null) {
          await _json(request.response, 404, {'success': false, 'error': 'Person not found.'});
          return;
        }
        final category = _optionalString(request.uri.queryParameters['category'], maxLength: 80);
        final credits = service.timelineForPerson(personId, category: category).map((credit) => {
          'credit': credit.toJson(),
          'work': service.works[credit.mediaId]?.toJson(),
        }).toList(growable: false);
        final categories = service.timelineForPerson(personId).map((credit) => credit.category).toSet().toList()..sort();
        await _json(request.response, 200, {
          'success': true,
          'person': person.toJson(),
          'credits': credits,
          'categories': categories,
        });
        return;
      }

      if (request.method == 'GET' &&
          path == '$_prefix/connections') {
        await _getConnections(request);
        return;
      }

      if (request.method == 'GET' && path == '$_prefix/seasons') {
        final seriesId = _requiredId(request.uri.queryParameters['seriesId'], field: 'seriesId');
        await _json(request.response, 200, {
          'success': true,
          'seriesId': seriesId,
          'seasons': service.seasonsForSeries(seriesId).map((season) => season.toJson()).toList(),
        });
        return;
      }

      if (request.method == 'GET' &&
          path == '$_prefix/artwork') {
        await _getArtwork(request);
        return;
      }

      if (request.method == 'GET' &&
          path == '$_prefix/surprise-me') {
        await _surpriseMe(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '$_prefix/work') {
        await _createWork(request);
        return;
      }

      if (request.method == 'POST' && path == '$_prefix/person') {
        await _createPerson(request);
        return;
      }

      if (request.method == 'POST' && path == '$_prefix/person-credit') {
        await _createPersonCredit(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '$_prefix/relationship') {
        await _createRelationship(request);
        return;
      }

      if (request.method == 'POST' && path == '$_prefix/season') {
        await _createSeason(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '$_prefix/device') {
        await _createDevice(request, account);
        return;
      }

      if (request.method == 'POST' &&
          path == '$_prefix/session') {
        await _createSession(request, account);
        return;
      }

      if (request.method == 'PUT' &&
          path == '$_prefix/session') {
        await _updateSession(request, account);
        return;
      }

      await _json(request.response, 404, {
        'success': false,
        'error': 'Media intelligence route not found.',
      });
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Invalid media-intelligence request payload.',
        name: 'media_intelligence_routes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(request.response, 400, {
        'success': false,
        'error': 'Invalid request payload.',
      });
    } on ArgumentError catch (error, stackTrace) {
      developer.log(
        'Rejected media-intelligence request.',
        name: 'media_intelligence_routes',
        error: error,
        stackTrace: stackTrace,
      );

      await _json(request.response, 400, {
        'success': false,
        'error': 'Invalid request.',
      });
    } catch (error, stackTrace) {
      developer.log(
        'Unexpected media-intelligence route failure.',
        name: 'media_intelligence_routes',
        error: error,
        stackTrace: stackTrace,
      );

      if (!_responseHasStarted(request.response)) {
        await _json(request.response, 500, {
          'success': false,
          'error': 'Media intelligence request failed.',
        });
      }
    }
  }

  Future<void> _getWorks(HttpRequest request) async {
    final works = service.works.values
        .map((work) => work.toJson())
        .toList(growable: false);

    await _json(request.response, 200, {
      'success': true,
      'works': works,
    });
  }

  Future<void> _getConnections(HttpRequest request) async {
    final id = _requiredId(
      request.uri.queryParameters['id'],
      field: 'id',
    );

    final connections = service
        .connections(id)
        .map((relationship) => relationship.toJson())
        .toList(growable: false);

    await _json(request.response, 200, {
      'success': true,
      'connections': connections,
    });
  }

  Future<void> _getArtwork(HttpRequest request) async {
    final artwork = service
        .profileArtwork()
        .map((item) => item.toJson())
        .toList(growable: false);

    await _json(request.response, 200, {
      'success': true,
      'artwork': artwork,
    });
  }

  Future<void> _surpriseMe(HttpRequest request) async {
    final type = _optionalString(
      request.uri.queryParameters['type'],
      maxLength: 64,
    );

    final media = service
        .surpriseMe(type: type)
        .map((work) => work.toJson())
        .toList(growable: false);

    await _json(request.response, 200, {
      'success': true,
      'media': media,
    });
  }

  Future<void> _createWork(HttpRequest request) async {
    final body = await _body(request);

    final title = _requiredString(
      body['title'],
      field: 'title',
      maxLength: _maxNameLength,
    );

    final type = _requiredString(
      body['type'],
      field: 'type',
      maxLength: 64,
    );

    final workId = _optionalId(body['id']) ??
        'work_${DateTime.now().microsecondsSinceEpoch}';

    final work = MediaWork(
      id: workId,
      title: title,
      type: type,
      releaseYear: _int(body['releaseYear']),
      originalLanguage: _optionalString(
        body['originalLanguage'],
        maxLength: 32,
      ),
      genres: _strings(body['genres']),
      themes: _strings(body['themes']),
      tags: _strings(body['tags']),
      productionCountries: _strings(body['productionCountries']),
      settingCountries: _strings(body['settingCountries']),
      culturalAssociationCountries:
          _strings(body['culturalAssociationCountries']),
      creatorOriginCountries: _strings(body['creatorOriginCountries']),
      sourceOriginCountries: _strings(body['sourceOriginCountries']),
      artistIds: _strings(body['artistIds']),
      personIds: _strings(body['personIds']),
      franchiseIds: _strings(body['franchiseIds']),
      albumIds: _strings(body['albumIds']),
      songIds: _strings(body['songIds']),
      extraIds: _strings(body['extraIds']),
      trailerIds: _strings(body['trailerIds']),
      musicVideoIds: _strings(body['musicVideoIds']),
      hasLyrics: body['hasLyrics'] == true,
    );

    service.upsertWork(work);

    await _json(request.response, 201, {
      'success': true,
      'work': work.toJson(),
    });
  }

  Future<void> _createRelationship(HttpRequest request) async {
    final body = await _body(request);

    final fromId = _requiredString(
      body['fromId'],
      field: 'fromId',
      maxLength: _maxIdLength,
    );

    final toId = _requiredString(
      body['toId'],
      field: 'toId',
      maxLength: _maxIdLength,
    );

    final relationshipType = _requiredString(
      body['relationshipType'],
      field: 'relationshipType',
      maxLength: 100,
    );

    final confidence = _double(
      body['confidence'],
      defaultValue: 1.0,
    );

    if (confidence < 0 || confidence > 1) {
      throw const FormatException(
        'confidence must be between 0 and 1.',
      );
    }

    final relationship = MediaRelationship(
      id: _optionalId(body['id']) ??
          'rel_${DateTime.now().microsecondsSinceEpoch}',
      fromId: fromId,
      relationshipType: relationshipType,
      toId: toId,
      confidence: confidence,
      source: _optionalString(
            body['source'],
            maxLength: 100,
          ) ??
          'catalog',
      metadata: _map(body['metadata']),
    );

    service.addRelationship(relationship);

    await _json(request.response, 201, {
      'success': true,
      'relationship': relationship.toJson(),
    });
  }

  Future<void> _createSeason(HttpRequest request) async {
    final body = await _body(request);
    final seriesId = _requiredString(body['seriesId'], field: 'seriesId', maxLength: _maxIdLength);
    final parent = service.works[seriesId];
    if (parent == null || !{'series', 'tv', 'tv_show', 'television_series'}.contains(parent.type.toLowerCase())) {
      throw const FormatException('seriesId must refer to an existing television series.');
    }
    final seasonNumber = _int(body['seasonNumber']);
    if (seasonNumber == null || seasonNumber < 0) throw const FormatException('seasonNumber must be zero or greater.');
    final season = MediaSeason(
      id: _optionalId(body['id']) ?? 'season_${DateTime.now().microsecondsSinceEpoch}',
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      title: _optionalString(body['title'], maxLength: _maxNameLength),
      startYear: _int(body['startYear']),
      endYear: _int(body['endYear']),
      episodeCount: _int(body['episodeCount']),
    );
    service.upsertSeason(season);
    await _json(request.response, 201, {'success': true, 'season': season.toJson()});
  }

  Future<void> _createPerson(HttpRequest request) async {
    final body = await _body(request);
    final person = MediaPerson(
      id: _requiredString(body['id'], field: 'id', maxLength: _maxIdLength),
      name: _requiredString(body['name'], field: 'name', maxLength: _maxNameLength),
      sortName: _optionalString(body['sortName'], maxLength: _maxNameLength),
      biography: _optionalString(body['biography'], maxLength: 4000),
      birthYear: _int(body['birthYear']),
    );
    service.upsertPerson(person);
    await _json(request.response, 200, {'success': true, 'person': person.toJson()});
  }

  Future<void> _createPersonCredit(HttpRequest request) async {
    final body = await _body(request);
    final credit = PersonCareerCredit(
      id: _optionalId(body['id']) ?? 'credit_${DateTime.now().microsecondsSinceEpoch}',
      personId: _requiredString(body['personId'], field: 'personId', maxLength: _maxIdLength),
      mediaId: _requiredString(body['mediaId'], field: 'mediaId', maxLength: _maxIdLength),
      category: _requiredString(body['category'], field: 'category', maxLength: 80),
      role: _optionalString(body['role'], maxLength: _maxNameLength) ?? '',
      characterName: _optionalString(body['characterName'], maxLength: _maxNameLength),
      creditGroup: _optionalString(body['creditGroup'], maxLength: _maxNameLength),
      startYear: _int(body['startYear']),
      endYear: _int(body['endYear']),
      source: _optionalString(body['source'], maxLength: 1000),
    );
    service.upsertCareerCredit(credit);
    await _json(request.response, 201, {'success': true, 'credit': credit.toJson()});
  }

  Future<void> _createDevice(
    HttpRequest request,
    dynamic account,
  ) async {
    final body = await _body(request);

    final profileId = _requiredString(
      body['profileId'],
      field: 'profileId',
      maxLength: _maxIdLength,
    );

    if (!_profileBelongsToAccount(account, profileId)) {
      await _json(request.response, 403, {
        'success': false,
        'error': 'Profile does not belong to the authenticated account.',
      });
      return;
    }

    final name = _optionalString(
          body['name'],
          maxLength: _maxNameLength,
        ) ??
        'Device';

    final type = _optionalString(
          body['type'],
          maxLength: 64,
        ) ??
        'unknown';

    final now = DateTime.now();

    final device = MediaDevice(
      id: _optionalId(body['id']) ??
          'device_${DateTime.now().microsecondsSinceEpoch}',
      profileId: profileId,
      name: name,
      type: type,
      lastSeenAt: now,
      online: body['online'] != false,
    );

    service.upsertDevice(device);

    await _json(request.response, 201, {
      'success': true,
      'device': device.toJson(),
    });
  }

  Future<void> _updateSession(
    HttpRequest request,
    dynamic account,
  ) async {
    final body = await _body(request);
    final id = _requiredString(body['id'], field: 'id', maxLength: _maxIdLength);
    final existing = service.sessions[id];
    if (existing == null) {
      await _json(request.response, 404, {'success': false, 'error': 'Playback session not found.'});
      return;
    }
    if (!_profileBelongsToAccount(account, existing.profileId)) {
      await _json(request.response, 403, {'success': false, 'error': 'Playback session does not belong to the authenticated account.'});
      return;
    }
    final position = body.containsKey('positionSeconds')
        ? _double(body['positionSeconds'], defaultValue: existing.positionSeconds)
        : existing.positionSeconds;
    if (position < 0) throw const FormatException('positionSeconds cannot be negative.');
    final updated = existing.copyWith(
      mediaId: body.containsKey('mediaId') ? _optionalId(body['mediaId']) : existing.mediaId,
      state: body['state']?.toString() ?? existing.state,
      positionSeconds: position,
      lastActivityAt: DateTime.now(),
    );
    service.upsertSession(updated);
    await _json(request.response, 200, {'success': true, 'session': updated.toJson()});
  }

  Future<void> _createSession(
    HttpRequest request,
    dynamic account,
  ) async {
    final body = await _body(request);

    final profileId = _requiredString(
      body['profileId'],
      field: 'profileId',
      maxLength: _maxIdLength,
    );

    if (!_profileBelongsToAccount(account, profileId)) {
      await _json(request.response, 403, {
        'success': false,
        'error': 'Profile does not belong to the authenticated account.',
      });
      return;
    }

    final deviceId = _requiredString(
      body['deviceId'],
      field: 'deviceId',
      maxLength: _maxIdLength,
    );

    final mediaId = _optionalId(body['mediaId']);

    final positionSeconds = _double(
      body['positionSeconds'],
      defaultValue: 0,
    );

    if (positionSeconds < 0) {
      throw const FormatException(
        'positionSeconds cannot be negative.',
      );
    }

    final state = _optionalString(
          body['state'],
          maxLength: 64,
        ) ??
        'playing';

    final now = DateTime.now();

    final session = PlaybackSession(
      id: _optionalId(body['id']) ??
          'session_${DateTime.now().microsecondsSinceEpoch}',
      profileId: profileId,
      deviceId: deviceId,
      mediaId: mediaId,
      state: state,
      positionSeconds: positionSeconds,
      startedAt: now,
      lastActivityAt: now,
    );

    service.upsertSession(session);

    await _json(request.response, 201, {
      'success': true,
      'session': session.toJson(),
    });
  }

  /// Determines whether a profile belongs to the authenticated account.
  ///
  /// The authentication model used by this backend exposes the account's
  /// profiles. This helper intentionally keeps the authorization check in
  /// the route rather than trusting a client-provided account identifier.
  bool _profileBelongsToAccount(
    dynamic account,
    String profileId,
  ) {
    try {
      final profiles = account.profiles;

      if (profiles is Iterable) {
        for (final profile in profiles) {
          try {
            if (profile.id?.toString() == profileId) {
              return true;
            }
          } catch (_) {
            // Ignore malformed profile entries.
          }
        }
      }
    } catch (_) {
      // Fall through to false if the authentication model does not expose
      // profiles in the expected shape.
    }

    return false;
  }

  Future<Map<String, dynamic>> _body(
    HttpRequest request,
  ) async {
    final contentLength = request.contentLength;

    if (contentLength > _maxBodyBytes) {
      throw const FormatException('Request body is too large.');
    }

    final bytes = <int>[];

    await for (final chunk in request) {
      if (bytes.length + chunk.length > _maxBodyBytes) {
        throw const FormatException('Request body is too large.');
      }

      bytes.addAll(chunk);
    }

    if (bytes.isEmpty) {
      throw const FormatException('Request body is required.');
    }

    final text = utf8.decode(bytes);

    final decoded = jsonDecode(text);

    if (decoded is! Map) {
      throw const FormatException(
        'Request body must be a JSON object.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  String _requiredString(
    dynamic value, {
    required String field,
    required int maxLength,
  }) {
    final result = value?.toString().trim() ?? '';

    if (result.isEmpty) {
      throw FormatException('$field is required.');
    }

    if (result.length > maxLength) {
      throw FormatException('$field is too long.');
    }

    return result;
  }

  String? _optionalString(
    dynamic value, {
    required int maxLength,
  }) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    if (result.isEmpty) {
      return null;
    }

    if (result.length > maxLength) {
      throw const FormatException(
        'String value is too long.',
      );
    }

    return result;
  }

  String? _optionalId(dynamic value) {
    if (value == null) {
      return null;
    }

    final id = value.toString().trim();

    if (id.isEmpty) {
      return null;
    }

    if (id.length > _maxIdLength) {
      throw const FormatException(
        'Identifier is too long.',
      );
    }

    return id;
  }

  String _requiredId(
    dynamic value, {
    required String field,
  }) {
    final id = _optionalId(value);

    if (id == null) {
      throw FormatException('$field is required.');
    }

    return id;
  }

  static int? _int(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString().trim());
  }

  static double _double(
    dynamic value, {
    required double defaultValue,
  }) {
    if (value == null) {
      return defaultValue;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().trim()) ?? defaultValue;
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    final values = <String>[];

    for (final item in value.take(_maxCollectionItems)) {
      final text = item?.toString().trim();

      if (text != null && text.isNotEmpty) {
        values.add(text);
      }
    }

    return values;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(value);
  }

  void _applyCors(HttpRequest request) {
    final headers = request.response.headers;

    headers.set('Access-Control-Allow-Origin', '*');
    headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type',
    );
    headers.set(
      'Access-Control-Expose-Headers',
      'Content-Type',
    );
  }

  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, dynamic> body,
  ) async {
    if (_responseHasStarted(response)) {
      return;
    }

    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set('Pragma', 'no-cache');
    response.headers.set(
      'X-Content-Type-Options',
      'nosniff',
    );

    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _empty(
    HttpRequest request,
    int status,
  ) async {
    final response = request.response;

    if (_responseHasStarted(response)) {
      return;
    }

    response.statusCode = status;
    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set('Pragma', 'no-cache');

    await response.close();
  }

  bool _responseHasStarted(HttpResponse response) {
    return response.headers.contentType != null ||
        response.statusCode != 200;
  }
}
