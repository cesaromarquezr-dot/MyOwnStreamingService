// FILE: Backend/services/transcode_cache_service.dart.
// Purpose: Stores generated playback copies separately from original media.
//
// This service manages derived/transcoded files only. It must never overwrite,
// delete, move, or modify original media.
//
// Cache files are disposable and may be regenerated when missing or invalid.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class TranscodeCacheService {
  static const int _maxKeyInputLength = 16 * 1024;
  static const int _maxProfileJsonLength = 16 * 1024;

  final Directory cacheRoot;

  TranscodeCacheService({Directory? root})
      : cacheRoot = root ??
            Directory(
              _configuredRoot(),
            );

  /// Produces a deterministic cache key for an input media path and
  /// transcoding profile.
  ///
  /// The profile is canonicalized before hashing so equivalent map ordering
  /// produces the same cache key.
  String key(
    String inputPath,
    Map<String, dynamic> profile,
  ) {
    final normalizedPath = _normalizeInputPath(inputPath);
    final canonicalProfile = _canonicalize(profile);

    final profileJson = jsonEncode(canonicalProfile);

    if (profileJson.length > _maxProfileJsonLength) {
      throw ArgumentError(
        'Transcoding profile is too large.',
      );
    }

    final raw = '$normalizedPath|$profileJson';

    if (raw.length > _maxKeyInputLength) {
      throw ArgumentError(
        'Transcode cache key input is too large.',
      );
    }

    return sha256
        .convert(utf8.encode(raw))
        .toString();
  }

  /// Returns the derived MP4 path associated with [cacheKey].
  ///
  /// Only SHA-256-style hexadecimal cache keys are accepted. This prevents
  /// callers from turning this method into an arbitrary path construction
  /// primitive.
  File fileFor(String cacheKey) {
    final normalizedKey = _validateCacheKey(cacheKey);

    return File(
      '${cacheRoot.path}'
      '${Platform.pathSeparator}'
      '$normalizedKey.mp4',
    );
  }

  /// Returns whether the cache directory exists.
  bool get exists => cacheRoot.existsSync();

  /// Creates the cache directory if necessary.
  ///
  /// This is the only mutating filesystem operation performed by this
  /// service, and it only creates the dedicated cache directory.
  Future<void> ensureDirectory() async {
    if (await cacheRoot.exists()) {
      return;
    }

    await cacheRoot.create(
      recursive: true,
    );
  }

  /// Returns whether a generated cache file currently exists.
  Future<bool> contains(String cacheKey) async {
    return fileFor(cacheKey).exists();
  }

  /// Returns the generated file if it exists, otherwise null.
  Future<File?> getIfExists(String cacheKey) async {
    final file = fileFor(cacheKey);

    if (!await file.exists()) {
      return null;
    }

    return file;
  }

  /// Deletes one derived cache file.
  ///
  /// This never touches an original media path.
  Future<bool> delete(String cacheKey) async {
    final file = fileFor(cacheKey);

    if (!await file.exists()) {
      return false;
    }

    await file.delete();
    return true;
  }

  /// Removes all regular files directly inside the transcode cache root.
  ///
  /// Subdirectories are intentionally not recursively deleted. This prevents
  /// an accidental cache cleanup from becoming a general-purpose recursive
  /// filesystem deletion operation.
  Future<int> clearFiles() async {
    if (!await cacheRoot.exists()) {
      return 0;
    }

    var deleted = 0;

    await for (final entity in cacheRoot.list(
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      final filename = _basename(entity.path);

      if (!_isValidCacheFilename(filename)) {
        continue;
      }

      try {
        await entity.delete();
        deleted++;
      } on FileSystemException {
        // Continue cleaning other disposable cache entries.
      }
    }

    return deleted;
  }

  /// Returns the total size of regular cache files directly inside the root.
  Future<int> totalBytes() async {
    if (!await cacheRoot.exists()) {
      return 0;
    }

    var total = 0;

    await for (final entity in cacheRoot.list(
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      final filename = _basename(entity.path);

      if (!_isValidCacheFilename(filename)) {
        continue;
      }

      try {
        final length = await entity.length();

        if (length > 0 && total <= 0x7FFFFFFFFFFFFFFF - length) {
          total += length;
        } else if (length > 0) {
          return 0x7FFFFFFFFFFFFFFF;
        }
      } on FileSystemException {
        // A disappearing/inaccessible cache file should not fail the entire
        // storage query.
      }
    }

    return total;
  }

  String _normalizeInputPath(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError(
        'Input media path cannot be empty.',
      );
    }

    if (normalized.length > 8192) {
      throw ArgumentError(
        'Input media path is too long.',
      );
    }

    if (normalized.contains('\u0000')) {
      throw ArgumentError(
        'Input media path contains an invalid character.',
      );
    }

    return normalized;
  }

  dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final entries = <String, dynamic>{};

      for (final entry in value.entries) {
        final name = entry.key.toString();

        if (name.contains('\u0000')) {
          throw ArgumentError(
            'Transcoding profile contains an invalid key.',
          );
        }

        entries[name] = _canonicalize(entry.value);
      }

      final sortedKeys = entries.keys.toList()..sort();

      return <String, dynamic>{
        for (final name in sortedKeys)
          name: entries[name],
      };
    }

    if (value is Iterable) {
      return value.map(_canonicalize).toList(growable: false);
    }

    if (value is num) {
      if (!value.isFinite) {
        throw ArgumentError(
          'Transcoding profile contains a non-finite number.',
        );
      }

      return value;
    }

    if (value is String) {
      if (value.contains('\u0000')) {
        throw ArgumentError(
          'Transcoding profile contains an invalid string.',
        );
      }

      return value;
    }

    if (value == null || value is bool) {
      return value;
    }

    // Preserve JSON compatibility while rejecting arbitrary object values
    // that jsonEncode might serialize through custom behavior.
    throw ArgumentError(
      'Transcoding profile contains an unsupported value.',
    );
  }

  String _validateCacheKey(String value) {
    final normalized = value.trim();

    if (!_isValidCacheKey(normalized)) {
      throw ArgumentError(
        'Invalid transcode cache key.',
      );
    }

    return normalized;
  }

  bool _isValidCacheKey(String value) {
    return RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value);
  }

  bool _isValidCacheFilename(String filename) {
    return RegExp(r'^[a-fA-F0-9]{64}\.mp4$').hasMatch(filename);
  }

  String _basename(String path) {
    final separator = Platform.pathSeparator;

    final index = path.lastIndexOf(separator);

    if (index < 0) {
      return path;
    }

    return path.substring(index + separator.length);
  }

  static String _configuredRoot() {
    final configured =
        Platform.environment['TRANSCODE_CACHE_ROOT']?.trim();

    if (configured != null &&
        configured.isNotEmpty &&
        !configured.contains('\u0000')) {
      return configured;
    }

    return './transcode_cache';
  }
}