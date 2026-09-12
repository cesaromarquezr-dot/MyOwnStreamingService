// FILE: `Backend/routes/library_routes.dart`.
// Purpose: Implements the library routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';

class LibraryRoutes {
  final AuthenticationMiddleware authentication;

  LibraryRoutes({required this.authentication});

  /// Performs `handle` for this feature. Update this documentation when its contract changes.
  Future<void> handle(HttpRequest request) async {
    final account = authentication.authenticate(request);
    if (account == null) {
      return _json(request.response, 401, {
      'success': false,
      'error': 'Authentication required.',
      });
    }

    final path = request.uri.path;
    // Authenticated media streaming for the Flutter music/background player.
    if (request.method == 'GET' && path == '/api/v1/library/stream') {
      final relative = request.uri.queryParameters['path'] ?? '';
      if (relative.isEmpty || relative.contains('..')) {
        return _json(request.response, 400, {'success': false, 'error': 'A safe relative media path is required.'});
      }
      final rootPath = Platform.environment['MEDIA_ROOT']?.trim().isNotEmpty == true ? Platform.environment['MEDIA_ROOT']!.trim() : './media';
      final root = Directory(rootPath).absolute;
      final file = File('${root.path}${Platform.pathSeparator}$relative').absolute;
      if (!file.path.startsWith(root.path) || !file.existsSync()) {
        return _json(request.response, 404, {'success': false, 'error': 'Media file not found.'});
      }
      request.response.headers.contentType = _contentType(file.path);
      await request.response.addStream(file.openRead());
      await request.response.close();
      return;
    }

    // Server media scanner: discovers completed ARM files without exposing filesystem details.
    if (request.method == 'GET' && path == '/api/v1/library/server-scan') {
      final root = Directory(Platform.environment['MEDIA_ROOT']?.trim().isNotEmpty == true ? Platform.environment['MEDIA_ROOT']!.trim() : './media');
      final files = <Map<String, dynamic>>[];
      if (root.existsSync()) {
        for (final entity in root.listSync(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final lower = entity.path.toLowerCase();
          if (!RegExp(r'\.(mkv|mp4|m4v|avi|mov|mp3|flac|m4a|aac|wav)$').hasMatch(lower)) continue;
          final relative = entity.path.startsWith(root.path) ? entity.path.substring(root.path.length).replaceAll('\\', '/') : entity.path;
          final segments = relative.split('/').where((e) => e.isNotEmpty).toList();
          final type = lower.endsWith('.mp3') || lower.endsWith('.flac') || lower.endsWith('.m4a') || lower.endsWith('.aac') || lower.endsWith('.wav') ? 'music' : (segments.any((e) => e.toLowerCase().contains('series') || e.toLowerCase().contains('tv')) ? 'tvShow' : 'movie');
          files.add({'id': relative, 'title': _cleanTitle(entity.uri.pathSegments.isEmpty ? entity.path : entity.uri.pathSegments.last), 'type': type, 'filePath': entity.path, 'fileSize': entity.lengthSync()});
        }
      }
      return _json(request.response, 200, {'success': true, 'media': files});
    }

    if (request.method == 'GET' && path == '/api/v1/library/privacy') {
      return _json(request.response, 200, {
        'success': true,
        'accountId': account.id,
        'privateLibrary': true,
        'storage': {
          'limitBytes': account.storageLimitBytes,
          'usedBytes': account.storageUsedBytes,
        },
        'ownershipDeclarationRequiredForDiscImport': true,
        'deleteMediaWithAccountDeletion': true,
      });
    }

    if (request.method == 'POST' && path == '/api/v1/library/ownership-declaration') {
      final body = await _body(request);
      if (body['confirmed'] != true) {
        return _json(request.response, 400, {
          'success': false,
          'error': 'Ownership/authorization confirmation is required.',
        });
      }
      return _json(request.response, 200, {
        'success': true,
        'accountId': account.id,
        'confirmed': true,
        'message': 'Authorized-use declaration recorded for this import session.',
      });
    }

    if (request.method == 'POST' && path == '/api/v1/library/deletion-request') {
      return _json(request.response, 202, {
        'success': true,
        'accountId': account.id,
        'status': 'queued',
        'message': 'Library deletion has been queued. Production storage workers must remove originals, derivatives, caches and backups according to the retention policy.',
      });
    }

    return _json(request.response, 404, {
      'success': false,
      'error': 'Library route not found.',
    });
  }

  ContentType _contentType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp3': return ContentType('audio', 'mpeg');
      case 'm4a': return ContentType('audio', 'mp4');
      case 'aac': return ContentType('audio', 'aac');
      case 'wav': return ContentType('audio', 'wav');
      case 'flac': return ContentType('audio', 'flac');
      default: return ContentType('application', 'octet-stream');
    }
  }

  String _cleanTitle(String value) {
    final name = value.replaceFirst(RegExp(r'\.[^.]+$'), '').replaceAll(RegExp(r'[._]+'), ' ').trim();
    return name.isEmpty ? 'Imported Media' : name;
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('JSON object required.');
    return Map<String, dynamic>.from(decoded);
  }

  /// Performs `_json` for this feature. Update this documentation when its contract changes.
  Future<void> _json(HttpResponse response, int code, Map<String, dynamic> data) async {
    response.statusCode = code;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }
}
