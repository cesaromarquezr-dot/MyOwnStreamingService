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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../arm/media_rights_policy.dart';
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
  static const String _membershipPath = '/api/v1/library/membership';

  // Membership overrides live outside the media scanner's index, so a full
  // scan or server restart cannot resurrect a removed item. Writes are queued
  // to prevent concurrent requests from losing each other's updates.
  static Future<void> _membershipQueue = Future<void>.value();

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
      // DURABLE PROFILE-SCOPED LIBRARY MEMBERSHIP OVERRIDES
      // --------------------------------------------------------------

      if (request.method == 'GET' && path == _membershipPath) {
        final profileId = (request.uri.queryParameters['profile_id'] ??
                request.uri.queryParameters['profileId'] ?? '')
            .trim();
        if (profileId.isEmpty || profileId.length > 200) {
          await _json(request.response, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'A valid profile_id is required.',
          });
          return;
        }
        final hiddenIds = await _withMembershipLock<List<String>>(() async {
          final data = await _readMembershipState();
          final accounts = data['accounts'] as Map<String, dynamic>;
          final profiles = accounts[account.id] is Map
              ? Map<String, dynamic>.from(accounts[account.id] as Map)
              : <String, dynamic>{};
          final raw = profiles[profileId];
          if (raw is! List) return <String>[];
          return raw.map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty).toSet().toList()..sort();
        });
        await _json(request.response, HttpStatus.ok, <String, dynamic>{
          'success': true,
          'profileId': profileId,
          'hiddenMediaIds': hiddenIds,
        });
        return;
      }

      if (request.method == 'PUT' && path == _membershipPath) {
        final body = await _body(request);
        final profileId = (body['profileId'] ?? '').toString().trim();
        if (profileId.isEmpty || profileId.length > 200) {
          await _json(request.response, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'A valid profileId is required.',
          });
          return;
        }

        if (body['replace'] == true && body['hiddenMediaIds'] is List) {
          final rawIds = body['hiddenMediaIds'] as List;
          if (rawIds.length > 5000) {
            await _json(request.response, HttpStatus.badRequest, <String, dynamic>{
              'success': false,
              'error': 'At most 5000 hidden media IDs can be reconciled at once.',
            });
            return;
          }
          final ids = <String>{};
          for (final rawId in rawIds) {
            final id = rawId.toString().trim();
            if (id.isEmpty) continue;
            if (id.length > 512) {
              await _json(request.response, HttpStatus.badRequest, <String, dynamic>{
                'success': false,
                'error': 'A media ID exceeds the supported length.',
              });
              return;
            }
            ids.add(id);
          }
          final count = await _withMembershipLock<int>(() async {
            final data = await _readMembershipState();
            final accounts = data['accounts'] as Map<String, dynamic>;
            final profiles = accounts[account.id] is Map
                ? Map<String, dynamic>.from(accounts[account.id] as Map)
                : <String, dynamic>{};
            if (ids.isEmpty) {
              profiles.remove(profileId);
            } else {
              final normalized = ids.toList()..sort();
              profiles[profileId] = normalized;
            }
            if (profiles.isEmpty) {
              accounts.remove(account.id);
            } else {
              accounts[account.id] = profiles;
            }
            data['accounts'] = accounts;
            await _writeMembershipState(data);
            return ids.length;
          });
          await _json(request.response, HttpStatus.ok, <String, dynamic>{
            'success': true,
            'profileId': profileId,
            'hiddenCount': count,
            'replaced': true,
          });
          return;
        }

        final mediaId = (body['mediaId'] ?? '').toString().trim();
        final hidden = body['hidden'];
        if (mediaId.isEmpty || mediaId.length > 512 || hidden is! bool) {
          await _json(request.response, HttpStatus.badRequest, <String, dynamic>{
            'success': false,
            'error': 'profileId, mediaId and a boolean hidden value are required.',
          });
          return;
        }
        final result = await _withMembershipLock<Map<String, dynamic>>(() async {
          final data = await _readMembershipState();
          final accounts = data['accounts'] as Map<String, dynamic>;
          final profiles = accounts[account.id] is Map
              ? Map<String, dynamic>.from(accounts[account.id] as Map)
              : <String, dynamic>{};
          final ids = (profiles[profileId] is List
                  ? (profiles[profileId] as List)
                      .map((value) => value.toString().trim())
                      .where((value) => value.isNotEmpty).toSet()
                  : <String>{});
          if (hidden) {
            ids.add(mediaId);
          } else {
            ids.remove(mediaId);
          }
          final normalized = ids.toList()..sort();
          if (normalized.isEmpty) {
            profiles.remove(profileId);
          } else {
            profiles[profileId] = normalized;
          }
          if (profiles.isEmpty) {
            accounts.remove(account.id);
          } else {
            accounts[account.id] = profiles;
          }
          data['accounts'] = accounts;
          await _writeMembershipState(data);
          return <String, dynamic>{
            'success': true,
            'profileId': profileId,
            'mediaId': mediaId,
            'hidden': hidden,
            'hiddenCount': normalized.length,
          };
        });
        await _json(request.response, HttpStatus.ok, result);
        return;
      }

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
        final requestedMetadata = body['metadata'] is Map
            ? Map<String, dynamic>.from(body['metadata'] as Map)
            : <String, dynamic>{};
        final rightsBlockReason = MediaRightsPolicy.blockReason(requestedMetadata);
        if (rightsBlockReason != null) {
          await _json(request.response, HttpStatus.forbidden, {
            'success': false,
            'code': 'MEDIA_RIGHTS_BLOCKED',
            'error': 'We do not allow pirated content in this service. $rightsBlockReason',
          });
          return;
        }
        // Keep the request metadata isolated from the incoming decoded body,
        // then enrich it with the server-generated import information below.
        final metadata = Map<String, dynamic>.from(requestedMetadata);
        // Trust the current account's canonical profile record for attribution;
        // never accept an arbitrary profile name supplied by a client.
        final submittedProfileId = metadata['addedByProfileId']?.toString().trim() ?? '';
        dynamic addingProfile;
        if (submittedProfileId.isNotEmpty) {
          for (final profile in account.profiles) {
            if (profile.id == submittedProfileId) {
              addingProfile = profile;
              break;
            }
          }
        }
        if (addingProfile != null) {
          metadata['addedByProfileId'] = addingProfile.id;
          metadata['addedByProfileName'] = addingProfile.name;
        } else {
          metadata.remove('addedByProfileId');
          metadata.remove('addedByProfileName');
        }
        metadata['addedAt'] ??= DateTime.now().toUtc().toIso8601String();
        metadata['addedSource'] = 'import/rip';
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
    if (relativePath.toLowerCase().startsWith('arm_mock/')) {
      await _json(
        request.response,
        HttpStatus.conflict,
        <String, dynamic>{
          'success': false,
          'code': 'DEMO_PLACEHOLDER_NOT_PLAYABLE',
          'error': 'ARM mock artifacts are text placeholders, not playable media.',
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
    final attributions = await store.loadServerMediaAttributions(
      accountExternalId: accountExternalId,
    );
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
        final type = _mediaType(lower, segments);
        final fileName = entity.uri.pathSegments.isEmpty
            ? entity.path
            : entity.uri.pathSegments.last;
        final episodeMetadata = type == 'episode'
            ? _episodeFileMetadata(fileName, segments)
            : null;
        final title = episodeMetadata?['episodeTitle']?.toString() ??
            _cleanTitle(fileName);
        final fileSize = entity.lengthSync();
        final modifiedAt = entity.lastModifiedSync().toUtc().toIso8601String();
        final isDemoArtifact = relative
            .replaceAll('\\', '/')
            .toLowerCase()
            .startsWith('arm_mock/');

        final item = <String, dynamic>{
          'id': relative,
          'title': title,
          'type': type,
          if (episodeMetadata != null) ...<String, dynamic>{
            'seriesTitle': episodeMetadata['seriesTitle'],
            'seasonNumber': episodeMetadata['seasonNumber'],
            'episodeNumber': episodeMetadata['episodeNumber'],
          },
          'fileSize': fileSize,
          'modifiedAt': modifiedAt,
          'isDemoArtifact': isDemoArtifact,
          'playable': !isDemoArtifact,
          if (isDemoArtifact) 'availability': 'demo-placeholder',
          if (isDemoArtifact)
            'description': 'ARM mock placeholder only; the file contains text, not playable media.',
        };
        final attribution = attributions[relative];
        if (attribution != null) item.addAll(attribution);
        if (type == 'music') {
          final album = _inferMusicAlbum(segments);
          final artist = _inferMusicArtist(segments);
          if (album != null) item['album'] = album;
          if (artist != null) item['artist'] = artist;
        }

        // ARM_MOCK outputs are intentionally tiny text fixtures. Surface their
        // status to the UI, but never index them as real catalog/playback media.
        if (!isDemoArtifact) {
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
                if (attribution != null) ...attribution,
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

    // Preserve episode-level identity when filenames use the common S02E03 or
    // 2x03 pattern. Treating these as generic shows makes exact themed-episode
    // playback and episode progress impossible.
    final episodeFileName = segments.isEmpty ? lowerPath : segments.last.toLowerCase();
    final hasEpisodeNumber = RegExp(
      r'\bS(\d{1,2})[ ._-]*E(\d{1,3})\b',
      caseSensitive: false,
    ).hasMatch(episodeFileName) || RegExp(r'\b(\d{1,2})x(\d{1,3})\b',
        caseSensitive: false).hasMatch(episodeFileName);
    if (hasEpisodeNumber) return 'episode';

    final looksLikeShow = segments.any(
      (segment) {
        final lower = segment.toLowerCase();

        return lower.contains('series') ||
            lower.contains('tv') ||
            RegExp(r'(^|[._\s-])(show|shows|episode|episodes)([._\s-]|$)')
                .hasMatch(lower) ||
            RegExp(r's\d{1,2}')
                .hasMatch(lower) ||
            RegExp(r'\bseason[\s._-]*\d+\b')
                .hasMatch(lower);
      },
    );

    return looksLikeShow ? 'tvShow' : 'movie';
  }

  Map<String, dynamic>? _episodeFileMetadata(
    String fileName,
    List<String> segments,
  ) {
    final withoutExtension = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final marker = RegExp(
      r'\bS(\d{1,2})[ ._-]*E(\d{1,3})\b',
      caseSensitive: false,
    ).firstMatch(withoutExtension) ??
        RegExp(r'\b(\d{1,2})x(\d{1,3})\b', caseSensitive: false)
            .firstMatch(withoutExtension);
    if (marker == null) return null;
    final isSxxExx = marker.group(1) != null &&
        withoutExtension.substring(marker.start, marker.end).toLowerCase().contains('e');
    final seasonNumber = int.tryParse(marker.group(1) ?? '');
    final episodeNumber = int.tryParse(marker.group(2) ?? '');
    if (seasonNumber == null || episodeNumber == null) return null;

    var episodeTitle = withoutExtension.substring(marker.end)
        .replaceAll(RegExp(r'^[\s._-]+'), '')
        .replaceAll(RegExp(
          r'\b(480p|720p|1080p|2160p|4k|webrip|web[ ._-]?dl|bluray|blu[ ._-]?ray|x264|x265|hevc|hdr|proper|repack)\b.*$',
          caseSensitive: false,
        ), '')
        .replaceAll(RegExp(r'[._]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (episodeTitle.isEmpty) {
      episodeTitle = withoutExtension.substring(0, marker.start)
          .replaceAll(RegExp(r'[._]+'), ' ').trim();
    }
    episodeTitle = episodeTitle.isEmpty ? _cleanTitle(fileName) : episodeTitle;

    const genericFolders = <String>{
      'tv', 'tvs', 'shows', 'show', 'series', 'television', 'video', 'videos',
      'media', 'library', 'movies', 'episodes',
    };
    var folderIndex = segments.length - 2;
    if (folderIndex >= 0 && RegExp(r'^(season|series|s)[ ._-]*\d+$',
        caseSensitive: false).hasMatch(_cleanTitle(segments[folderIndex]))) {
      folderIndex--;
    }
    String seriesTitle = '';
    if (folderIndex >= 0) {
      final folder = _cleanTitle(segments[folderIndex]);
      if (!genericFolders.contains(folder.toLowerCase())) seriesTitle = folder;
    }
    if (seriesTitle.isEmpty) {
      final prefix = withoutExtension.substring(0, marker.start)
          .replaceAll(RegExp(r'[._]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      seriesTitle = prefix.isEmpty ? 'Unknown Series' : prefix;
    }

    return <String, dynamic>{
      'seriesTitle': seriesTitle,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'episodeTitle': episodeTitle,
      'numberingFormat': isSxxExx ? 'SxxExx' : 'NxN',
    };
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
        .replaceFirst(
          RegExp(r'^\d{10,}[_\s-]+'),
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

  static Future<T> _withMembershipLock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _membershipQueue = _membershipQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  File _membershipStateFile() {
    final configured = Platform.environment['LIBRARY_MEMBERSHIP_STORE_PATH']?.trim();
    if (configured != null && configured.isNotEmpty) return File(configured);
    final separator = Platform.pathSeparator;
    return File('${Directory.current.path}${separator}data${separator}library_membership_overrides.json');
  }

  Future<Map<String, dynamic>> _readMembershipState() async {
    final file = _membershipStateFile();
    final backup = File('${file.path}.bak');
    File source = file;
    if (!await source.exists() && await backup.exists()) source = backup;
    if (!await source.exists()) {
      return <String, dynamic>{'schemaVersion': 1, 'accounts': <String, dynamic>{}};
    }
    try {
      final decoded = jsonDecode(await source.readAsString());
      if (decoded is! Map) throw const FormatException('Membership data must be an object.');
      final data = Map<String, dynamic>.from(decoded);
      final rawAccounts = data['accounts'];
      data['schemaVersion'] = 1;
      data['accounts'] = rawAccounts is Map
          ? Map<String, dynamic>.from(rawAccounts)
          : <String, dynamic>{};
      return data;
    } on FormatException {
      // Do not silently overwrite a corrupt file: keep a diagnostic copy and
      // start with an empty state only after preserving the original bytes.
      final corrupt = File('${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      if (await file.exists()) await file.copy(corrupt.path);
      rethrow;
    }
  }

  Future<void> _writeMembershipState(Map<String, dynamic> data) async {
    final file = _membershipStateFile();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp-${pid}-${DateTime.now().microsecondsSinceEpoch}');
    final backup = File('${file.path}.bak');
    await temp.writeAsString(jsonEncode(data), flush: true);
    try {
      if (await file.exists()) {
        if (await backup.exists()) await backup.delete();
        await file.rename(backup.path);
      }
      await temp.rename(file.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    } finally {
      if (await temp.exists()) await temp.delete();
    }
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
