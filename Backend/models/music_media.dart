// FILE: Backend/models/music_media.dart.
// Purpose: Defines lossless music media/version metadata used by ARM and playback.
// This file is part of the documented Flutter/home-server architecture.
//
// A MusicMediaVersion represents one imported/derived audio file or media
// version associated with a release track.
//
// It is deliberately separate from the canonical recording identity:
//   MusicRelease -> MusicMedium -> Track -> Recording
//                         |
//                         +-> MusicMediaVersion
//
// This allows the same canonical recording to appear on multiple releases
// without duplicating the underlying recording identity.
//
// The archive/master file should remain lossless when the source permits it.
// Playback derivatives can be generated independently from the archive master.

/// Describes an imported music master and the formats derived from it for playback.
class MusicMediaVersion {
  final String id;
  final String trackId;
  final String title;
  final String? artist;
  final String? album;
  final int? trackNumber;
  final int? discNumber;
  final String sourceFormat;
  final String archiveFormat;
  final bool lossless;
  final String? filePath;
  final List<String> genres;
  final String? artworkUrl;

  const MusicMediaVersion({
    required this.id,
    required this.trackId,
    required this.title,
    this.artist,
    this.album,
    this.trackNumber,
    this.discNumber,
    this.sourceFormat = 'unknown',
    this.archiveFormat = 'flac',
    this.lossless = true,
    this.filePath,
    this.genres = const [],
    this.artworkUrl,
  });

  /// Indicates whether this version should be retained as the lossless
  /// archive master.
  bool get isLosslessArchiveMaster {
    final format = archiveFormat.trim().toLowerCase();

    return lossless &&
        (format == 'flac' ||
            format == 'alac' ||
            format == 'wav' ||
            format == 'aiff');
  }

  /// Indicates whether this version has a usable source file.
  bool get hasFilePath => filePath?.trim().isNotEmpty == true;

  /// Indicates whether the track has enough identity information for
  /// persistence.
  bool get isValid =>
      id.trim().isNotEmpty &&
      trackId.trim().isNotEmpty &&
      title.trim().isNotEmpty;

  /// Normalized archive format.
  String get normalizedArchiveFormat =>
      archiveFormat.trim().toLowerCase();

  /// Normalized source format.
  String get normalizedSourceFormat =>
      sourceFormat.trim().toLowerCase();

  /// Serializes the music version for persistence and event payloads.
  Map<String, dynamic> toJson() => {
        'id': id,
        'trackId': trackId,
        'title': title,
        'artist': artist,
        'album': album,
        'trackNumber': trackNumber,
        'discNumber': discNumber,
        'sourceFormat': sourceFormat,
        'archiveFormat': archiveFormat,
        'lossless': lossless,
        'filePath': filePath,
        'genres': List<String>.from(genres),
        'artworkUrl': artworkUrl,
      };

  factory MusicMediaVersion.fromJson(
    Map<String, dynamic> json,
  ) {
    return MusicMediaVersion(
      id: _stringValue(json['id']),
      trackId: _stringValue(json['trackId']),
      title: _stringValue(json['title']),
      artist: _nullableString(json['artist']),
      album: _nullableString(json['album']),
      trackNumber: _nullableInt(json['trackNumber']),
      discNumber: _nullableInt(json['discNumber']),
      sourceFormat: _stringValue(
        json['sourceFormat'],
        fallback: 'unknown',
      ),
      archiveFormat: _stringValue(
        json['archiveFormat'],
        fallback: 'flac',
      ),
      lossless: _boolValue(
        json['lossless'],
        fallback: true,
      ),
      filePath: _nullableString(json['filePath']),
      genres: _stringList(json['genres']),
      artworkUrl: _nullableString(json['artworkUrl']),
    );
  }

  /// Creates a modified copy without changing the original version.
  MusicMediaVersion copyWith({
    String? id,
    String? trackId,
    String? title,
    String? artist,
    String? album,
    int? trackNumber,
    int? discNumber,
    String? sourceFormat,
    String? archiveFormat,
    bool? lossless,
    String? filePath,
    List<String>? genres,
    String? artworkUrl,
    bool clearArtist = false,
    bool clearAlbum = false,
    bool clearFilePath = false,
    bool clearArtworkUrl = false,
  }) {
    return MusicMediaVersion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artist: clearArtist ? null : (artist ?? this.artist),
      album: clearAlbum ? null : (album ?? this.album),
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      archiveFormat: archiveFormat ?? this.archiveFormat,
      lossless: lossless ?? this.lossless,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      genres: genres ?? this.genres,
      artworkUrl:
          clearArtworkUrl ? null : (artworkUrl ?? this.artworkUrl),
    );
  }

  @override
  String toString() {
    return 'MusicMediaVersion('
        'id: $id, '
        'trackId: $trackId, '
        'title: $title, '
        'archiveFormat: $archiveFormat, '
        'lossless: $lossless'
        ')';
  }
}

String _stringValue(
  Object? value, {
  String fallback = '',
}) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();

  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();

  return text.isEmpty ? null : text;
}

int? _nullableInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value.trim());
  }

  return null;
}

bool _boolValue(
  Object? value, {
  bool fallback = false,
}) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;

      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
    }
  }

  return fallback;
}

List<String> _stringList(Object? value) {
  if (value is String) {
    final text = value.trim();

    return text.isEmpty ? const [] : [text];
  }

  if (value is! List) {
    return const [];
  }

  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}