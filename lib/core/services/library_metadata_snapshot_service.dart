import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../app_core.dart';
import '../../music.dart';

/// Writes a user-initiated, privacy-sanitized export of metadata and progress.
/// This is an export aid, not a database restore mechanism or media-file backup.
class LibraryMetadataSnapshotService {
  const LibraryMetadataSnapshotService();

  static const int schemaVersion = 1;

  Future<File> createSnapshot({DateTime? now}) async {
    final controller = AppController.instance;
    final music = MusicLibraryStore.instance;
    final generatedAt = (now ?? DateTime.now()).toUtc();
    final snapshot = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'generatedAt': generatedAt.toIso8601String(),
      'snapshotType': 'my-own-streaming-service-library-metadata',
      'notes': <String>[
        'Metadata and IDs only; video/audio files are not included.',
        'Playback and download URLs, credentials, tokens, and filesystem paths are omitted.',
        'This export cannot write records back to a remote database by itself.',
      ],
      'library': controller.library.map(_safeMedia).toList(growable: false),
      'watchedMediaIds': controller.watched.map((item) => item.id).where((id) => !_looksLikeLocalPath(id)).toSet().toList()..sort(),
      'likedMediaIds': controller.liked.map((item) => item.id).where((id) => !_looksLikeLocalPath(id)).toSet().toList()..sort(),
      'playbackProgress': Map<String, double>.fromEntries(
        controller.playbackProgress.entries.where((entry) => !_looksLikeLocalPath(entry.key)),
      ),
      'collections': controller.collections.map((collection) => <String, dynamic>{
        'id': collection.id,
        'name': collection.name,
        'description': collection.description,
        'createdByProfileName': _profileNameForId(collection.createdByProfileId),
        'mediaIds': collection.mediaIds.where((id) => !_looksLikeLocalPath(id)).toList(growable: false),
        'episodeKeys': collection.episodeKeys.where((id) => !_looksLikeLocalPath(id)).toList(growable: false),
        'isShared': collection.isShared,
        'isOfficial': collection.isOfficial,
        'isAutomatic': collection.isAutomatic,
        'isFeatured': collection.isFeatured,
        'posterMode': collection.posterMode,
        'customPosterUrl': _safePublicArtworkUrl(collection.customPosterUrl),
        'smartRule': collection.smartRule,
        'sortMode': collection.sortMode,
        'autoPlayEnabled': collection.autoPlayEnabled,
        'autoPlayNextEnabled': collection.autoPlayNextEnabled,
      }).toList(growable: false),
      'music': <String, dynamic>{
        'tracks': music.tracks.map((track) => <String, dynamic>{
          'id': track.id,
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'artworkUrl': _safePublicArtworkUrl(track.artworkUrl),
          'durationMs': track.duration.inMilliseconds,
          'genres': track.genres,
          'subgenres': track.subgenres,
          'featuredArtists': track.featuredArtists,
          'addedByProfileName': track.addedByProfileName,
          'addedSource': track.addedSource,
          'explicit': track.explicit,
          'matureTheme': track.matureTheme,
          'modifiedAt': track.modifiedAt?.toUtc().toIso8601String(),
          'hasAudioSource': track.audioUrl?.trim().isNotEmpty == true,
          'hasMusicVideo': track.musicVideoUrl?.trim().isNotEmpty == true,
        }).toList(growable: false),
        'playlists': <String, List<String>>{
          for (final entry in music.playlists.entries)
            if (!_looksLikeLocalPath(entry.key)) entry.key: entry.value.where((id) => !_looksLikeLocalPath(id)).toList(growable: false),
        },
        'playlistAddedByProfileNames': <String, String>{
          for (final entry in music.playlistAddedByProfileNames.entries)
            if (!_looksLikeLocalPath(entry.key)) entry.key: entry.value,
        },
        'listenCounts': Map<String, int>.fromEntries(
          music.listenCounts.entries.where((entry) => !_looksLikeLocalPath(entry.key)),
        ),
        'listenEventTimestamps': <String, List<int>>{
          for (final entry in music.listenEventTimestamps.entries)
            if (!_looksLikeLocalPath(entry.key)) entry.key: List<int>.from(entry.value),
        },
      },
    };

    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}MyOwnStreamingService'
      '${Platform.pathSeparator}library_exports',
    );
    await directory.create(recursive: true);
    final stamp = '${generatedAt.year.toString().padLeft(4, '0')}'
        '${generatedAt.month.toString().padLeft(2, '0')}'
        '${generatedAt.day.toString().padLeft(2, '0')}_'
        '${generatedAt.hour.toString().padLeft(2, '0')}'
        '${generatedAt.minute.toString().padLeft(2, '0')}'
        '${generatedAt.second.toString().padLeft(2, '0')}';
    final file = File('${directory.path}${Platform.pathSeparator}library_snapshot_$stamp.json');
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    return temporary.rename(file.path);
  }

  String? _profileNameForId(String? profileId) {
    final id = profileId?.trim() ?? '';
    if (id.isEmpty) return null;
    final controller = AppController.instance;
    for (final profile in controller.currentAccount?.profiles ?? const <Profile>[]) {
      if (profile.id == id) return profile.name;
    }
    if (controller.currentProfile?.id == id) return controller.currentProfile?.name;
    return null;
  }

  Map<String, dynamic> _safeMedia(MediaItem media) {
    final raw = Map<String, dynamic>.from(media.toJson());
    final sanitized = _sanitizeMap(raw);
    sanitized['playbackSourceConfigured'] =
        (media.playbackUrl?.trim().isNotEmpty ?? false);
    sanitized['trailerSourceConfigured'] =
        (media.trailerUrl?.trim().isNotEmpty ?? false);
    return sanitized;
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    final output = <String, dynamic>{};
    for (final entry in input.entries) {
      final key = entry.key;
      final lower = key.toLowerCase();
      if (lower.contains('token') ||
          lower.contains('password') ||
          lower.contains('secret') ||
          lower.contains('credential') ||
          lower.contains('authorization') ||
          lower.contains('profileid') ||
          (lower.contains('profilename') &&
              !const <String>{
                'addedbyprofilename',
                'createdbyprofilename',
                'playlistaddedbyprofilenames',
              }.contains(lower)) ||
          lower.contains('accountid') ||
          lower.contains('filepath') ||
          lower.contains('storagepath') ||
          lower == 'path' ||
          lower.endsWith('path')) {
        continue;
      }
      if (lower.endsWith('url') || lower == 'url') {
        if (_isArtworkUrlKey(lower)) {
          final safeUrl = _safePublicArtworkUrl(entry.value?.toString());
          if (safeUrl != null) output[key] = safeUrl;
        }
        continue;
      }
      final value = entry.value;
      if (value is Map) {
        output[key] = _sanitizeMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        output[key] = value.where((item) => item is! String || !_looksLikeLocalPath(item)).map((item) {
          if (item is Map) return _sanitizeMap(Map<String, dynamic>.from(item));
          return item;
        }).toList(growable: false);
      } else if (value is String) {
        if (!_looksLikeLocalPath(value)) output[key] = value;
      } else {
        output[key] = value;
      }
    }
    return output;
  }

  bool _looksLikeLocalPath(String value) {
    final candidate = value.trim();
    if (candidate.isEmpty) return false;
    return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(candidate) ||
        candidate.startsWith(r'\\') ||
        candidate.toLowerCase().startsWith('file://') ||
        RegExp(r'^/(?:Users|home|mnt|media|Volumes|storage|srv)/').hasMatch(candidate);
  }

  bool _isArtworkUrlKey(String lower) =>
      lower == 'imageurl' ||
      lower == 'artworkurl' ||
      lower == 'posterurl' ||
      lower == 'backdropurl' ||
      lower == 'titlelogourl' ||
      lower == 'herotitleartworkurl' ||
      lower == 'detailtitleartworkurl' ||
      lower == 'customposterurl';

  String? _safePublicArtworkUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    // Query strings and fragments may carry signed CDN credentials or tokens.
    return uri.replace(query: '', fragment: '', userInfo: '').toString();
  }
}
