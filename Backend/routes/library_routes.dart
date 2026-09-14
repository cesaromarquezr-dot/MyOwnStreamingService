// FILE: `Backend/routes/library_routes.dart`.
// Purpose: Implements authenticated home-server library access and metadata sync.
// Physical media files remain on the account's own home server.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../supabase_store.dart';

class LibraryRoutes {
  final AuthenticationMiddleware authentication;
  final SupabaseStore store;

  LibraryRoutes({
    required this.authentication,
    SupabaseStore? store,
  }) : store = store ?? SupabaseStore.instance;

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
    // The client supplies only a relative server-owned path.
    if (request.method == 'GET' && path == '/api/v1/library/stream') {
      final relative = request.uri.queryParameters['path'] ?? '';
      if (relative.isEmpty || relative.contains('..')) {
        return _json(request.response, 400, {
          'success': false,
          'error': 'A safe relative media path is required.',
        });
      }

      final rootPath =
          Platform.environment['MEDIA_ROOT']?.trim().isNotEmpty == true
              ? Platform.environment['MEDIA_ROOT']!.trim()
              : './media';
      final root = Directory(rootPath).absolute;
      final file = File(
        '${root.path}${Platform.pathSeparator}$relative',
      ).absolute;

      if (!file.path.startsWith(root.path) || !file.existsSync()) {
        return _json(request.response, 404, {
          'success': false,
          'error': 'Media file not found.',
        });
      }

      request.response.headers.contentType = _contentType(file.path);
      await request.response.addStream(file.openRead());
      await request.response.close();
      return;
    }

    // Server media scanner.
    // It returns metadata only and never returns the absolute filesystem path.
    if (request.method == 'GET' && path == '/api/v1/library/server-scan') {
      final rootPath =
          Platform.environment['MEDIA_ROOT']?.trim().isNotEmpty == true
              ? Platform.environment['MEDIA_ROOT']!.trim()
              : './media';
      final root = Directory(rootPath).absolute;
      final files = <Map<String, dynamic>>[];
      var persisted = 0;

      if (root.existsSync()) {
        for (final entity in root.listSync(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;

          final lower = entity.path.toLowerCase();
          if (!RegExp(
            r'\.(mkv|mp4|m4v|avi|mov|mp3|flac|m4a|aac|wav)$',
          ).hasMatch(lower)) {
            continue;
          }

          final relative = entity.path.startsWith(root.path)
              ? entity.path
                  .substring(root.path.length)
                  .replaceAll('\\', '/')
              : entity.path;
          final safeRelative = relative
              .split('/')
              .where((segment) => segment.isNotEmpty)
              .join('/');
          if (safeRelative.isEmpty || safeRelative.contains('..')) continue;

          final segments = safeRelative.split('/');
          final type = _mediaType(lower, segments);
          final title = _cleanTitle(
            entity.uri.pathSegments.isEmpty
                ? entity.path
                : entity.uri.pathSegments.last,
          );
          final fileSize = entity.lengthSync();

          final item = <String, dynamic>{
            'id': safeRelative,
            'title': title,
            'type': type,
            'fileSize': fileSize,
          };

          try {
            await store.upsertServerMedia(
              accountExternalId: account.id,
              relativeMediaId: safeRelative,
              title: title,
              type: type,
              metadata: {
                'source': 'home-server-scanner',
                'relativeMediaId': safeRelative,
              },
              fileSizeBytes: fileSize,
            );
            persisted++;
          } catch (_) {
            // A temporary Supabase outage must not prevent the local server
            // scan from returning its discovered media.
          }

          files.add(item);
        }
      }

      return _json(request.response, 200, {
        'success': true,
        'media': files,
        'persisted': persisted,
      });
    }

    // Update database metadata without changing the physical home-server file.
    if (request.method == 'PUT' &&
        path.startsWith('/api/v1/library/media/')) {
      final relativeMediaId = Uri.decodeComponent(
        path.substring('/api/v1/library/media/'.length),
      );
      if (relativeMediaId.trim().isEmpty || relativeMediaId.contains('..')) {
        return _json(request.response, 400, {
          'success': false,
          'error': 'A safe media identifier is required.',
        });
      }

      final body = await _body(request);
      final year = _optionalInt(body['year']);
      final metadata = body['metadata'] is Map
          ? Map<String, dynamic>.from(body['metadata'] as Map)
          : null;

      await store.updateServerMediaMetadata(
        accountExternalId: account.id,
        relativeMediaId: relativeMediaId,
        title: body['title']?.toString(),
        year: year,
        description: body['description']?.toString(),
        posterUrl: body['posterUrl']?.toString(),
        trailerUrl: body['trailerUrl']?.toString(),
        metadata: metadata,
      );

      return _json(request.response, 200, {
        'success': true,
        'message': 'Media metadata updated.',
      });
    }

    // Remove the database index for a server media item. This does NOT delete
    // the physical file on the home server.
    if (request.method == 'DELETE' &&
        path.startsWith('/api/v1/library/media/')) {
      final relativeMediaId = Uri.decodeComponent(
        path.substring('/api/v1/library/media/'.length),
      );
      if (relativeMediaId.trim().isEmpty || relativeMediaId.contains('..')) {
        return _json(request.response, 400, {
          'success': false,
          'error': 'A safe media identifier is required.',
        });
      }

      await store.deleteServerMedia(
        accountExternalId: account.id,
        relativeMediaId: relativeMediaId,
      );

      return _json(request.response, 200, {
        'success': true,
        'message': 'Media removed from the database index. The physical file was not deleted.',
      });
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
        'physicalFilesRemainOnHomeServer': true,
      });
    }

    if (request.method == 'POST' &&
        path == '/api/v1/library/ownership-declaration') {
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

    if (request.method == 'POST' &&
        path == '/api/v1/library/deletion-request') {
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

  String _mediaType(String lowerPath, List<String> segments) {
    if (RegExp(r'\.(mp3|flac|m4a|aac|wav)$').hasMatch(lowerPath)) {
      return 'music';
    }
    final looksLikeShow = segments.any(
      (segment) =>
          segment.toLowerCase().contains('series') ||
          segment.toLowerCase().contains('tv') ||
          RegExp(r's\d{1,2}').hasMatch(segment.toLowerCase()),
    );
    return looksLikeShow ? 'tvShow' : 'movie';
  }

  ContentType _contentType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp3':
        return ContentType('audio', 'mpeg');
      case 'm4a':
        return ContentType('audio', 'mp4');
      case 'aac':
        return ContentType('audio', 'aac');
      case 'wav':
        return ContentType('audio', 'wav');
      case 'flac':
        return ContentType('audio', 'flac');
      case 'mp4':
        return ContentType('video', 'mp4');
      case 'mkv':
        return ContentType('video', 'x-matroska');
      case 'm4v':
        return ContentType('video', 'x-m4v');
      case 'mov':
        return ContentType('video', 'quicktime');
      case 'webm':
        return ContentType('video', 'webm');
      default:
        return ContentType('application', 'octet-stream');
    }
  }

  String _cleanTitle(String value) {
    final name = value
        .replaceFirst(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[._]+'), ' ')
        .trim();
    return name.isEmpty ? 'Imported Media' : name;
  }

  int? _optionalInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('JSON object required.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _json(
    HttpResponse response,
    int code,
    Map<String, dynamic> data,
  ) async {
    response.statusCode = code;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }
}
