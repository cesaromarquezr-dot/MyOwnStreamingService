// FILE: `Backend/routes/library_routes.dart`.
// Purpose: Implements authenticated home-server library access and metadata sync.
// Physical media files remain on the account's own home server.
//
// Security boundary:
// - Every route is authenticated except browser CORS preflight.
// - Physical media is never exposed by absolute filesystem path.
// - Stream requests accept only relative paths.
// - Canonical filesystem paths are checked against MEDIA_ROOT.
// - Symbolic links resolving outside MEDIA_ROOT are rejected.
// - Database operations are scoped to the authenticated account.
// - Deleting library metadata never deletes the physical home-server file.
//
// The home-server process is expected to serve the MEDIA_ROOT belonging to
// the authenticated account/environment. A multi-tenant deployment should
// provide a separate storage root/worker boundary for each account rather
// than sharing one MEDIA_ROOT between unrelated accounts.

import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../supabase_store.dart';

class LibraryRoutes {
  static const String _streamPath = '/api/v1/library/stream';
  static const String _scanPath = '/api/v1/library/server-scan';
  static const String _approvedImportPath =
      '/api/v1/library/import-approved';
  static const String _mediaPrefix = '/api/v1/library/media/';
  static const String _privacyPath = '/api/v1/library/privacy';
  static const String _ownershipPath =
      '/api/v1/library/ownership-declaration';
  static const String _deletionPath =
      '/api/v1/library/deletion-request';

  static final RegExp _supportedMediaExtension = RegExp(
    r'\.(mkv|mp4|m4v|avi|mov|webm|mp3|flac|m4a|aac|wav)$',
    caseSensitive: false,
  );

  static final RegExp _audioExtension = RegExp(
    r'\.(mp3|flac|m4a|aac|wav)$',
    caseSensitive: false,
  );

  final AuthenticationMiddleware authentication;
  final SupabaseStore store;

  LibraryRoutes({
    required this.authentication,
    SupabaseStore? store,
  }) : store = store ?? SupabaseStore.instance;

  Future<void> handle(HttpRequest request) async {
    _applyCorsHeaders(request.response);

    // Browser preflight requests do not carry the application's bearer
    // credential and therefore must be handled before authentication.
    if (request.method == 'OPTIONS') {
      await _json(
        request.response,
        HttpStatus.noContent,
        <String, dynamic>{},
      );
      return;
    }

    final account = authentication.authenticate(request);

    if (account == null) {
      await _json(
        request.response,
        HttpStatus.unauthorized,
        <String, dynamic>{
          'success': false,
          'error': 'Authentication required.',
        },
      );
      return;
    }

    final path = request.uri.path;

    try {
      // --------------------------------------------------------------
      // AUTHENTICATED MEDIA STREAMING
      // --------------------------------------------------------------

      if (request.method == 'GET' && path == _streamPath) {
        await _streamMedia(request);
        return;
      }

      // --------------------------------------------------------------
      // SERVER MEDIA SCANNER
      // --------------------------------------------------------------

      if (request.method == 'GET' && path == _scanPath) {
        await _serverScan(
          accountExternalId: account.id,
          request: request,
        );
        return;
      }

      // Copy a reviewed ARM rip from the configured ARM output mount into
      // MEDIA_ROOT when needed, then register it in the persistent library.
      if (request.method == 'POST' && path == _approvedImportPath) {
        final body = await _body(request);
        final requestedPath = body['outputPath']?.toString().trim() ?? '';
        if (requestedPath.isEmpty) {
          await _json(request.response, HttpStatus.badRequest, {
            'success': false,
            'error': 'The rip output path is required.',
          });
          return;
        }

        final title = body['title']?.toString().trim() ?? '';
        final type = body['type']?.toString().trim() ?? 'movie';
        if (title.isEmpty) {
          await _json(request.response, HttpStatus.badRequest, {
            'success': false,
            'error': 'A reviewed title is required.',
          });
          return;
        }

        final root = _mediaRoot();
        final isMockOutput = requestedPath.startsWith('MOCK://');
        final mockMode =
            (Platform.environment['ARM_MOCK'] ?? '').trim().toLowerCase() ==
                'true';
        if (isMockOutput && !mockMode) {
          await _json(request.response, HttpStatus.badRequest, {
            'success': false,
            'error': 'A mock ARM output can only be imported while ARM_MOCK=true.',
          });
          return;
        }

        final candidate = isMockOutput
            ? await _createMockMediaFile(root, requestedPath, title)
            : await _resolveImportedMediaFile(requestedPath);
        if (candidate == null) {
          await _json(request.response, HttpStatus.notFound, {
            'success': false,
            'error': 'The ripped output is not reachable from the home server. Mount the ARM output directory on the home server and set ARM_OUTPUT_ROOT, or configure ARM to rip directly into MEDIA_ROOT.',
          });
          return;
        }

        var relative = _relativePathFromRoot(root, candidate);
        if (relative == null) {
          final armOutputRoot =
              Platform.environment['ARM_OUTPUT_ROOT']?.trim();
          if (armOutputRoot == null || armOutputRoot.isEmpty ||
              !_isPathInside(
                Directory(armOutputRoot).resolveSymbolicLinksSync(),
                candidate.resolveSymbolicLinksSync(),
              )) {
            await _json(request.response, HttpStatus.forbidden, {
              'success': false,
              'error': 'The ripped file is outside MEDIA_ROOT and the configured ARM_OUTPUT_ROOT.',
            });
            return;
          }

          final safeTitle = title
              .replaceAll(RegExp(r'[^A-Za-z0-9._ -]+'), '_')
              .replaceAll(RegExp(r'\s+'), '_')
              .replaceAll(RegExp(r'_+'), '_');
          final extension =
              candidate.path.substring(candidate.path.lastIndexOf('.'));
          final destinationRelative =
              'arm_imports/${DateTime.now().microsecondsSinceEpoch}_$safeTitle$extension';
          final destination = File(
            '${root.path}${Platform.pathSeparator}'
            '${destinationRelative.replaceAll('/', Platform.pathSeparator)}',
          );
          await destination.parent.create(recursive: true);
          await candidate.copy(destination.path);
          relative = destinationRelative;
        }

        if (!_isSafeRelativePath(relative) ||
            !_supportedMediaExtension.hasMatch(relative)) {
          await _json(request.response, HttpStatus.badRequest, {
            'success': false,
            'error': 'The rip output must be a supported media file.',
          });
          return;
        }

        final metadata = body['metadata'] is Map
            ? Map<String, dynamic>.from(body['metadata'] as Map)
            : <String, dynamic>{};
        metadata['source'] = 'approved-arm-import';
        metadata['relativeMediaId'] = relative;
        if (isMockOutput) metadata['mockMedia'] = true;
        await store.upsertServerMedia(
          accountExternalId: account.id,
          relativeMediaId: relative,
          title: title,
          type: type,
          year: _optionalInt(body['year']),
          description: _optionalString(body['description']),
          posterUrl: _optionalString(body['posterUrl']),
          trailerUrl: _optionalString(body['trailerUrl']),
          metadata: metadata,
          fileSizeBytes: candidate.lengthSync(),
        );
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'mediaId': relative,
          'message': 'Reviewed rip saved to the home server library.',
        });
        return;
      }

      // --------------------------------------------------------------
      // UPDATE DATABASE MEDIA METADATA
      // --------------------------------------------------------------

      if (request.method == 'PUT' &&
          path.startsWith(_mediaPrefix)) {
        final relativeMediaId = _decodeRelativeIdentifier(
          path.substring(_mediaPrefix.length),
        );

        if (!_isSafeRelativePath(relativeMediaId)) {
          await _json(
            request.response,
            HttpStatus.badRequest,
            <String, dynamic>{
              'success': false,
              'error': 'A safe media identifier is required.',
            },
          );
          return;
        }

        final body = await _body(request);

        final metadata = body['metadata'] is Map
            ? Map<String, dynamic>.from(
                body['metadata'] as Map,
              )
            : null;

        await store.updateServerMediaMetadata(
          accountExternalId: account.id,
          relativeMediaId: relativeMediaId,
          title: _optionalString(body['title']),
          year: _optionalInt(body['year']),
          description: _optionalString(body['description']),
          posterUrl: _optionalString(body['posterUrl']),
          trailerUrl: _optionalString(body['trailerUrl']),
          metadata: metadata,
        );

        await _json(
          request.response,
          HttpStatus.ok,
          <String, dynamic>{
            'success': true,
            'message': 'Media metadata updated.',
          },
        );
        return;
      }

      // --------------------------------------------------------------
      // REMOVE DATABASE MEDIA INDEX
      // --------------------------------------------------------------

      if (request.method == 'DELETE' &&
          path.startsWith(_mediaPrefix)) {
        final relativeMediaId = _decodeRelativeIdentifier(
          path.substring(_mediaPrefix.length),
        );

        if (!_isSafeRelativePath(relativeMediaId)) {
          await _json(
            request.response,
            HttpStatus.badRequest,
            <String, dynamic>{
              'success': false,
              'error': 'A safe media identifier is required.',
            },
          );
          return;
        }

        // This removes only the database index. The physical file remains
        // untouched on the home server.
        await store.deleteServerMedia(
          accountExternalId: account.id,
          relativeMediaId: relativeMediaId,
        );

        await _json(
          request.response,
          HttpStatus.ok,
          <String, dynamic>{
            'success': true,
            'message':
                'Media removed from the database index. '
                'The physical file was not deleted.',
          },
        );
        return;
      }

      // --------------------------------------------------------------
      // LIBRARY PRIVACY / STORAGE INFORMATION
      // --------------------------------------------------------------

      if (request.method == 'GET' && path == _privacyPath) {
        await _json(
          request.response,
          HttpStatus.ok,
          <String, dynamic>{
            'success': true,
            'accountId': account.id,
            'privateLibrary': true,
            'storage': <String, dynamic>{
              'limitBytes': account.storageLimitBytes,
              'usedBytes': account.storageUsedBytes,
            },
            'ownershipDeclarationRequiredForDiscImport': true,
            'deleteMediaWithAccountDeletion': true,
            'physicalFilesRemainOnHomeServer': true,
          },
        );
        return;
      }

      // --------------------------------------------------------------
      // OWNERSHIP / AUTHORIZED-USE DECLARATION
      // --------------------------------------------------------------

      if (request.method == 'POST' &&
          path == _ownershipPath) {
        final body = await _body(request);

        if (body['confirmed'] != true) {
          await _json(
            request.response,
            HttpStatus.badRequest,
            <String, dynamic>{
              'success': false,
              'error':
                  'Ownership/authorization confirmation is required.',
            },
          );
          return;
        }

        await _json(
          request.response,
          HttpStatus.ok,
          <String, dynamic>{
            'success': true,
            'accountId': account.id,
            'confirmed': true,
            'message':
                'Authorized-use declaration recorded for this import session.',
          },
        );
        return;
      }

      // --------------------------------------------------------------
      // LIBRARY DELETION REQUEST
      // --------------------------------------------------------------

      if (request.method == 'POST' &&
          path == _deletionPath) {
        await _json(
          request.response,
          HttpStatus.accepted,
          <String, dynamic>{
            'success': true,
            'accountId': account.id,
            'status': 'queued',
            'message':
                'Library deletion has been queued. Production storage '
                'workers must remove originals, derivatives, caches and '
                'backups according to the retention policy.',
          },
        );
        return;
      }

      await _json(
        request.response,
        HttpStatus.notFound,
        <String, dynamic>{
          'success': false,
          'error': 'Library route not found.',
        },
      );
    } on FormatException catch (error) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': error.message,
        },
      );
    } catch (error, stackTrace) {
      stderr.writeln('LibraryRoutes error: $error');
      stderr.writeln(stackTrace);

      // The client receives a generic error rather than filesystem,
      // database, or internal implementation details.
      if (!_responseHasContentType(request.response)) {
        await _json(
          request.response,
          HttpStatus.internalServerError,
          <String, dynamic>{
            'success': false,
            'error': 'Library request failed.',
          },
        );
      }
    }
  }

  // --------------------------------------------------------------------------
  // MEDIA STREAMING
  // --------------------------------------------------------------------------

  Future<void> _streamMedia(HttpRequest request) async {
    final rawRelativePath =
        request.uri.queryParameters['path'] ?? '';

    if (rawRelativePath.trim().isEmpty) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'A safe relative media path is required.',
        },
      );
      return;
    }

    final relativePath = _decodeRelativeIdentifier(
      rawRelativePath,
    );

    if (!_isSafeRelativePath(relativePath)) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'A safe relative media path is required.',
        },
      );
      return;
    }

    final root = _mediaRoot();

    if (!root.existsSync()) {
      await _json(
        request.response,
        HttpStatus.notFound,
        <String, dynamic>{
          'success': false,
          'error': 'Media root does not exist.',
        },
      );
      return;
    }

    final requestedFile = File(
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );

    if (!requestedFile.existsSync()) {
      await _json(
        request.response,
        HttpStatus.notFound,
        <String, dynamic>{
          'success': false,
          'error': 'Media file not found.',
        },
      );
      return;
    }

    final stat = requestedFile.statSync();

    if (stat.type != FileSystemEntityType.file) {
      await _json(
        request.response,
        HttpStatus.notFound,
        <String, dynamic>{
          'success': false,
          'error': 'Media file not found.',
        },
      );
      return;
    }

    // Resolve both sides before the containment test so a symlink inside
    // MEDIA_ROOT cannot point to an arbitrary file elsewhere.
    final canonicalRoot = root.resolveSymbolicLinksSync();
    final canonicalFilePath = requestedFile.resolveSymbolicLinksSync();
    final canonicalFile = File(canonicalFilePath);

    if (!_isPathInside(
      canonicalRoot,
      canonicalFilePath,
    )) {
      await _json(
        request.response,
        HttpStatus.forbidden,
        <String, dynamic>{
          'success': false,
          'error':
              'Media path is outside the configured media root.',
        },
      );
      return;
    }

    final fileLength = canonicalFile.lengthSync();

    if (fileLength == 0) {
      await _json(
        request.response,
        HttpStatus.noContent,
        <String, dynamic>{},
      );
      return;
    }

    request.response.headers.contentType =
        _contentType(canonicalFile.path);

    request.response.headers.set(
      HttpHeaders.acceptRangesHeader,
      'bytes',
    );
    request.response.headers.set(
      HttpHeaders.cacheControlHeader,
      'private, no-store',
    );
    request.response.headers.set(
      'X-Content-Type-Options',
      'nosniff',
    );

    final rangeHeader =
        request.headers.value(HttpHeaders.rangeHeader);

    final rangeResult = _parseRange(
      rangeHeader,
      fileLength,
    );

    // A malformed Range header is ignored, but a syntactically valid range
    // that cannot be satisfied must return 416.
    if (rangeHeader != null &&
        rangeHeader.trim().isNotEmpty &&
        rangeResult == null &&
        _isUnsatisfiableRange(
          rangeHeader,
          fileLength,
        )) {
      request.response.statusCode =
          HttpStatus.requestedRangeNotSatisfiable;

      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes */$fileLength',
      );

      await request.response.close();
      return;
    }

    if (rangeResult == null) {
      request.response.statusCode = HttpStatus.ok;
      request.response.contentLength = fileLength;

      await request.response.addStream(
        canonicalFile.openRead(),
      );
      await request.response.close();
      return;
    }

    final start = rangeResult.start;
    final end = rangeResult.end;
    final length = end - start + 1;

    request.response.statusCode =
        HttpStatus.partialContent;
    request.response.contentLength = length;

    request.response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/$fileLength',
    );

    await request.response.addStream(
      canonicalFile.openRead(
        start,
        end + 1,
      ),
    );

    await request.response.close();
  }

  // --------------------------------------------------------------------------
  // SERVER SCAN
  // --------------------------------------------------------------------------

  Future<void> _serverScan({
    required HttpRequest request,
    required String accountExternalId,
  }) async {
    final root = _mediaRoot();
    final files = <Map<String, dynamic>>[];
    var persisted = 0;

    if (root.existsSync()) {
      for (final entity in root.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }

        final lower = entity.path.toLowerCase();

        if (!_supportedMediaExtension.hasMatch(lower)) {
          continue;
        }

        final relative = _relativePathFromRoot(
          root,
          entity,
        );

        if (relative == null ||
            !_isSafeRelativePath(relative)) {
          continue;
        }

        final segments = relative.split('/');
        final type = _mediaType(
          lower,
          segments,
        );

        final fileName = entity.uri.pathSegments.isEmpty
            ? entity.path
            : entity.uri.pathSegments.last;

        final title = _cleanTitle(fileName);
        final fileSize = entity.lengthSync();
        final modifiedAt = entity.lastModifiedSync().toUtc().toIso8601String();

        final item = <String, dynamic>{
          'id': relative,
          'title': title,
          'type': type,
          'fileSize': fileSize,
          'modifiedAt': modifiedAt,
        };
        if (type == 'music') {
          final album = _inferMusicAlbum(segments);
          final artist = _inferMusicArtist(segments);
          if (album != null) item['album'] = album;
          if (artist != null) item['artist'] = artist;
        }

        try {
          await store.upsertServerMedia(
            accountExternalId: accountExternalId,
            relativeMediaId: relative,
            title: title,
            type: type,
            metadata: <String, dynamic>{
              'source': 'home-server-scanner',
              'relativeMediaId': relative,
              'modifiedAt': modifiedAt,
              if (item['album'] != null) 'album': item['album'],
              if (item['artist'] != null) 'artist': item['artist'],
            },
            fileSizeBytes: fileSize,
          );

          persisted++;
        } catch (error, stackTrace) {
          // Local discovery should continue even if the remote database is
          // temporarily unavailable.
          stderr.writeln(
            'LibraryRoutes: unable to persist scanned media '
            '"$relative": $error',
          );
          stderr.writeln(stackTrace);
        }

        files.add(item);
      }
    }

    await _json(
      request.response,
      HttpStatus.ok,
      <String, dynamic>{
        'success': true,
        'media': files,
        'persisted': persisted,
      },
    );
  }

  // --------------------------------------------------------------------------
  // PATH SECURITY
  // --------------------------------------------------------------------------

  Directory _mediaRoot() {
    final configured =
        Platform.environment['MEDIA_ROOT']?.trim();

    final rootPath =
        configured != null && configured.isNotEmpty
            ? configured
            : './media';

    return Directory(rootPath).absolute;
  }

  String _decodeRelativeIdentifier(String value) {
    var decoded = value;

    // Bound repeated URL decoding. This catches common double-encoded
    // traversal attempts without allowing arbitrary recursive decoding.
    for (var i = 0; i < 2; i++) {
      final next = Uri.decodeComponent(decoded);

      if (next == decoded) {
        break;
      }

      decoded = next;
    }

    return decoded
        .replaceAll('\\', '/')
        .trim();
  }

  bool _isSafeRelativePath(String value) {
    if (value.isEmpty) {
      return false;
    }

    if (value.startsWith('/') ||
        value.startsWith('\\') ||
        value.startsWith('~')) {
      return false;
    }

    // Reject Windows drive-letter paths such as C:/media/file.mkv.
    if (RegExp(r'^[A-Za-z]:').hasMatch(value)) {
      return false;
    }

    final normalized = value.replaceAll('\\', '/');

    for (final segment in normalized.split('/')) {
      if (segment.isEmpty || segment == '.') {
        continue;
      }

      if (segment == '..') {
        return false;
      }

      // Never allow a NUL byte to reach filesystem APIs.
      if (segment.contains('\u0000')) {
        return false;
      }
    }

    return true;
  }

  bool _isPathInside(
    String rootPath,
    String candidatePath,
  ) {
    final root = _normalizeFilesystemPath(rootPath);
    final candidate =
        _normalizeFilesystemPath(candidatePath);

    if (_pathsEqual(root, candidate)) {
      return true;
    }

    final separator = Platform.pathSeparator;

    final rootPrefix = root.endsWith(separator)
        ? root
        : '$root$separator';

    if (Platform.isWindows) {
      return candidate
          .toLowerCase()
          .startsWith(rootPrefix.toLowerCase());
    }

    return candidate.startsWith(rootPrefix);
  }

  bool _pathsEqual(String a, String b) {
    if (Platform.isWindows) {
      return a.toLowerCase() == b.toLowerCase();
    }

    return a == b;
  }

  String _normalizeFilesystemPath(String value) {
    var normalized = value;

    if (Platform.isWindows) {
      normalized = normalized.replaceAll('/', '\\');
    } else {
      normalized = normalized.replaceAll('\\', '/');
    }

    while (normalized.length > 1 &&
        (normalized.endsWith('/') ||
            normalized.endsWith('\\'))) {
      normalized = normalized.substring(
        0,
        normalized.length - 1,
      );
    }

    return normalized;
  }

  String? _relativePathFromRoot(
    Directory root,
    File file,
  ) {
    try {
      final canonicalRoot =
          root.resolveSymbolicLinksSync();
      final canonicalFile =
          file.resolveSymbolicLinksSync();

      if (!_isPathInside(
        canonicalRoot,
        canonicalFile,
      )) {
        return null;
      }

      final normalizedRoot =
          _normalizeFilesystemPath(canonicalRoot);
      final normalizedFile =
          _normalizeFilesystemPath(canonicalFile);

      final separator = Platform.pathSeparator;
      final prefix = normalizedRoot.endsWith(separator)
          ? normalizedRoot
          : '$normalizedRoot$separator';

      final comparisonFile =
          Platform.isWindows
              ? normalizedFile.toLowerCase()
              : normalizedFile;

      final comparisonPrefix =
          Platform.isWindows
              ? prefix.toLowerCase()
              : prefix;

      if (!comparisonFile.startsWith(comparisonPrefix)) {
        return null;
      }

      final relative = normalizedFile
          .substring(prefix.length)
          .replaceAll('\\', '/')
          .replaceAll(RegExp(r'/+'), '/');

      return relative;
    } catch (_) {
      return null;
    }
  }

  Future<File> _createMockMediaFile(
    Directory root,
    String mockPath,
    String title,
  ) async {
    final extension = RegExp(
      r'\.(mkv|mp4|m4v|avi|mov|webm|mp3|flac|m4a|aac|wav)$',
      caseSensitive: false,
    ).firstMatch(mockPath)?.group(0) ?? '.mkv';
    final safeTitle = title
        .replaceAll(RegExp(r'[^A-Za-z0-9._ -]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final relative =
        'arm_mock/${DateTime.now().microsecondsSinceEpoch}_$safeTitle$extension';
    final file = File(
      '${root.path}${Platform.pathSeparator}'
      '${relative.replaceAll('/', Platform.pathSeparator)}',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      'Streaming service mock media artifact. '
      'This placeholder is not playable content. Source: $mockPath\n',
      flush: true,
    );
    return file;
  }

  Future<File?> _resolveImportedMediaFile(String path) async {
    final entityType = FileSystemEntity.typeSync(path, followLinks: true);
    if (entityType == FileSystemEntityType.file) {
      final file = File(path).absolute;
      return _supportedMediaExtension.hasMatch(file.path) ? file : null;
    }
    if (entityType != FileSystemEntityType.directory) return null;

    File? largestMediaFile;
    var largestSize = 0;
    await for (final entity in Directory(path).list(recursive: true)) {
      if (entity is! File || !_supportedMediaExtension.hasMatch(entity.path)) {
        continue;
      }
      final size = await entity.length();
      if (size > largestSize) {
        largestMediaFile = entity;
        largestSize = size;
      }
    }
    return largestMediaFile;
  }

  // --------------------------------------------------------------------------
  // MEDIA CLASSIFICATION
  // --------------------------------------------------------------------------

  String _mediaType(
    String lowerPath,
    List<String> segments,
  ) {
    if (_audioExtension.hasMatch(lowerPath)) {
      return 'music';
    }

    final looksLikeShow = segments.any(
      (segment) {
        final lower = segment.toLowerCase();

        return lower.contains('series') ||
            lower.contains('tv') ||
            RegExp(r's\d{1,2}')
                .hasMatch(lower) ||
            RegExp(r'\bseason[\s._-]*\d+\b')
                .hasMatch(lower);
      },
    );

    return looksLikeShow ? 'tvShow' : 'movie';
  }

  ContentType _contentType(String path) {
    final ext = path
        .split('.')
        .last
        .toLowerCase();

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
      case 'avi':
        return ContentType('video', 'x-msvideo');
      case 'webm':
        return ContentType('video', 'webm');
      default:
        return ContentType(
          'application',
          'octet-stream',
        );
    }
  }


  /// Uses a conventional Artist/Album/Track folder layout when available.
  /// Generic roots such as Music or Audio are never promoted to album names.
  String? _inferMusicAlbum(List<String> segments) {
    if (segments.length < 3) return null;
    final folder = _cleanTitle(segments[segments.length - 2]);
    if (_isGenericMusicFolder(folder)) return null;
    return folder;
  }

  String? _inferMusicArtist(List<String> segments) {
    if (segments.length < 3) return null;
    final folder = _cleanTitle(segments[segments.length - 3]);
    if (_isGenericMusicFolder(folder)) return null;
    final album = _inferMusicAlbum(segments);
    if (album != null && folder.toLowerCase() == album.toLowerCase()) {
      return null;
    }
    return folder;
  }

  bool _isGenericMusicFolder(String value) => const <String>{
        'music', 'audio', 'songs', 'song', 'media', 'library',
        'soundtracks', 'albums', 'album', 'unknown album', 'unknown artist',
      }.contains(value.trim().toLowerCase());

  String _cleanTitle(String value) {
    final name = value
        .replaceFirst(
          RegExp(r'\.[^.]+$'),
          '',
        )
        .replaceAll(
          RegExp(r'[._]+'),
          ' ',
        )
        .trim();

    return name.isEmpty
        ? 'Imported Media'
        : name;
  }

  String? _optionalString(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    return result.isEmpty ? null : result;
  }

  int? _optionalInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString().trim() ?? '',
    );
  }

  // --------------------------------------------------------------------------
  // BYTE RANGE SUPPORT
  // --------------------------------------------------------------------------

  _ByteRange? _parseRange(
    String? header,
    int fileLength,
  ) {
    if (header == null ||
        header.trim().isEmpty ||
        fileLength <= 0) {
      return null;
    }

    final value = header.trim();

    if (!value.startsWith('bytes=')) {
      return null;
    }

    final rangeValue =
        value.substring('bytes='.length);

    // Only one range is supported. Multipart ranges would require a
    // multipart/byteranges response and are unnecessary for the media player.
    if (rangeValue.contains(',')) {
      return null;
    }

    final parts = rangeValue.split('-');

    if (parts.length != 2) {
      return null;
    }

    final startText = parts[0].trim();
    final endText = parts[1].trim();

    // Suffix range: bytes=-500
    if (startText.isEmpty) {
      final suffixLength =
          int.tryParse(endText);

      if (suffixLength == null ||
          suffixLength <= 0) {
        return null;
      }

      final length =
          suffixLength > fileLength
              ? fileLength
              : suffixLength;

      return _ByteRange(
        fileLength - length,
        fileLength - 1,
      );
    }

    final start = int.tryParse(startText);

    if (start == null ||
        start < 0 ||
        start >= fileLength) {
      return null;
    }

    var end = fileLength - 1;

    if (endText.isNotEmpty) {
      final parsedEnd =
          int.tryParse(endText);

      if (parsedEnd == null) {
        return null;
      }

      end = parsedEnd;
    }

    if (end < start) {
      return null;
    }

    if (end >= fileLength) {
      end = fileLength - 1;
    }

    return _ByteRange(start, end);
  }

  bool _isUnsatisfiableRange(
    String header,
    int fileLength,
  ) {
    final value = header.trim();

    if (!value.startsWith('bytes=')) {
      return false;
    }

    final rangeValue =
        value.substring('bytes='.length);

    if (rangeValue.contains(',')) {
      return false;
    }

    final parts = rangeValue.split('-');

    if (parts.length != 2) {
      return false;
    }

    final startText = parts[0].trim();
    final endText = parts[1].trim();

    if (startText.isEmpty) {
      final suffixLength =
          int.tryParse(endText);

      return suffixLength != null &&
          suffixLength <= 0;
    }

    final start =
        int.tryParse(startText);

    if (start == null) {
      return false;
    }

    if (start >= fileLength) {
      return true;
    }

    if (endText.isEmpty) {
      return false;
    }

    final end =
        int.tryParse(endText);

    if (end == null) {
      return false;
    }

    return end < start;
  }

  // --------------------------------------------------------------------------
  // REQUEST/RESPONSE HELPERS
  // --------------------------------------------------------------------------

  Future<Map<String, dynamic>> _body(
    HttpRequest request,
  ) async {
    final raw =
        await utf8.decoder.bind(request).join();

    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw const FormatException(
        'JSON object required.',
      );
    }

    return Map<String, dynamic>.from(decoded);
  }

  bool _responseHasContentType(
    HttpResponse response,
  ) {
    return response.headers.contentType != null;
  }

  void _applyCorsHeaders(
    HttpResponse response,
  ) {
    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, PUT, DELETE, POST, OPTIONS',
    );
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type, Range',
    );
    response.headers.set(
      'Access-Control-Expose-Headers',
      'Content-Type, Content-Length, Content-Range, Accept-Ranges',
    );
  }

  Future<void> _json(
    HttpResponse response,
    int code,
    Map<String, dynamic> data,
  ) async {
    response.statusCode = code;
    response.headers.contentType = ContentType.json;

    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set(
      'Pragma',
      'no-cache',
    );

    response.write(jsonEncode(data));
    await response.close();
  }
}

class _ByteRange {
  final int start;
  final int end;

  const _ByteRange(
    this.start,
    this.end,
  );
}
