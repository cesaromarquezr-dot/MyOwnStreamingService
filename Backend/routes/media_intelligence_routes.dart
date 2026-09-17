// FILE: `Backend/routes/media_intelligence_routes.dart`.
// Purpose: Exposes the unified media graph, session, artwork and intelligence foundation.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../models/media_artwork.dart';
import '../models/media_relationship.dart';
import '../models/media_session.dart';
import '../models/media_work.dart';
import '../services/media_intelligence_service.dart';

class MediaIntelligenceRoutes {
  final AuthenticationMiddleware authentication;
  final MediaIntelligenceService service;

  MediaIntelligenceRoutes({required this.authentication, required this.service});

  /// Handles all `/api/v1/media-intelligence/*` requests.
  Future<void> handle(HttpRequest request) async {
    final account = authentication.authenticate(request);
    if (account == null) {
      await _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});
      return;
    }

    final path = request.uri.path;
    if (request.method == 'GET' && path == '/api/v1/media-intelligence/capabilities') {
      await _json(request.response, 200, {'success': true, ...service.capabilities()});
      return;
    }
    if (request.method == 'GET' && path == '/api/v1/media-intelligence/health') {
      await _json(request.response, 200, {'success': true, 'health': service.libraryHealth()});
      return;
    }
    if (request.method == 'GET' && path == '/api/v1/media-intelligence/works') {
      await _json(request.response, 200, {'success': true, 'works': service.works.values.map((w) => w.toJson()).toList()});
      return;
    }
    if (request.method == 'GET' && path == '/api/v1/media-intelligence/connections') {
      final id = request.uri.queryParameters['id']?.trim() ?? '';
      await _json(request.response, 200, {'success': true, 'connections': service.connections(id).map((r) => r.toJson()).toList()});
      return;
    }
    if (request.method == 'GET' && path == '/api/v1/media-intelligence/artwork') {
      await _json(request.response, 200, {'success': true, 'artwork': service.profileArtwork().map((a) => a.toJson()).toList()});
      return;
    }
    if (request.method == 'GET' && path == '/api/v1/media-intelligence/surprise-me') {
      final type = request.uri.queryParameters['type']?.trim();
      await _json(request.response, 200, {'success': true, 'media': service.surpriseMe(type: type).map((w) => w.toJson()).toList()});
      return;
    }
    if (request.method == 'POST' && path == '/api/v1/media-intelligence/work') {
      final body = await _body(request);
      final work = MediaWork(
        id: body['id']?.toString() ?? 'work_${DateTime.now().microsecondsSinceEpoch}',
        title: body['title']?.toString() ?? 'Untitled',
        type: body['type']?.toString() ?? 'movie',
        releaseYear: _int(body['releaseYear']),
        originalLanguage: body['originalLanguage']?.toString(),
        genres: _strings(body['genres']),
        themes: _strings(body['themes']),
        tags: _strings(body['tags']),
        productionCountries: _strings(body['productionCountries']),
        settingCountries: _strings(body['settingCountries']),
        culturalAssociationCountries: _strings(body['culturalAssociationCountries']),
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
      await _json(request.response, 201, {'success': true, 'work': work.toJson()});
      return;
    }
    if (request.method == 'POST' && path == '/api/v1/media-intelligence/relationship') {
      final body = await _body(request);
      final relationship = MediaRelationship(
        id: body['id']?.toString() ?? 'rel_${DateTime.now().microsecondsSinceEpoch}',
        fromId: body['fromId']?.toString() ?? '',
        relationshipType: body['relationshipType']?.toString() ?? 'relatedTo',
        toId: body['toId']?.toString() ?? '',
        confidence: (body['confidence'] is num) ? (body['confidence'] as num).toDouble() : 1.0,
        source: body['source']?.toString() ?? 'catalog',
        metadata: body['metadata'] is Map ? Map<String, dynamic>.from(body['metadata'] as Map) : const {},
      );
      service.addRelationship(relationship);
      await _json(request.response, 201, {'success': true, 'relationship': relationship.toJson()});
      return;
    }
    if (request.method == 'POST' && path == '/api/v1/media-intelligence/device') {
      final body = await _body(request);
      final now = DateTime.now();
      final device = MediaDevice(
        id: body['id']?.toString() ?? 'device_${DateTime.now().microsecondsSinceEpoch}',
        profileId: body['profileId']?.toString() ?? '',
        name: body['name']?.toString() ?? 'Device',
        type: body['type']?.toString() ?? 'unknown',
        lastSeenAt: now,
        online: body['online'] != false,
      );
      service.upsertDevice(device);
      await _json(request.response, 201, {'success': true, 'device': device.toJson()});
      return;
    }
    if (request.method == 'POST' && path == '/api/v1/media-intelligence/session') {
      final body = await _body(request);
      final now = DateTime.now();
      final session = PlaybackSession(
        id: body['id']?.toString() ?? 'session_${DateTime.now().microsecondsSinceEpoch}',
        profileId: body['profileId']?.toString() ?? '',
        deviceId: body['deviceId']?.toString() ?? '',
        mediaId: body['mediaId']?.toString(),
        state: body['state']?.toString() ?? 'playing',
        positionSeconds: body['positionSeconds'] is num ? (body['positionSeconds'] as num).toDouble() : 0,
        startedAt: now,
        lastActivityAt: now,
      );
      service.upsertSession(session);
      await _json(request.response, 201, {'success': true, 'session': session.toJson()});
      return;
    }

    await _json(request.response, 404, {'success': false, 'error': 'Media intelligence route not found.'});
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final text = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(text);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
  }

  Future<void> _json(HttpResponse response, int status, Map<String, dynamic> body) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  static int? _int(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  static List<String> _strings(dynamic value) => value is List ? value.map((e) => e.toString()).toList() : <String>[];
}
