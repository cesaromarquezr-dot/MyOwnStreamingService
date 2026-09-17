// FILE: Backend/services/transcode_cache_service.dart.
// Purpose: Stores generated playback copies separately from original media.

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class TranscodeCacheService {
  final Directory cacheRoot;

  TranscodeCacheService({Directory? root})
      : cacheRoot = root ?? Directory(
          Platform.environment['TRANSCODE_CACHE_ROOT']?.trim().isNotEmpty == true
              ? Platform.environment['TRANSCODE_CACHE_ROOT']!.trim()
              : './transcode_cache',
        );

  String key(String inputPath, Map<String, dynamic> profile) {
    final raw = '$inputPath|${jsonEncode(profile)}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  File fileFor(String key) => File('${cacheRoot.path}${Platform.pathSeparator}$key.mp4');

  Future<void> ensureDirectory() async {
    if (!cacheRoot.existsSync()) await cacheRoot.create(recursive: true);
  }
}
