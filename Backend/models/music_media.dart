// FILE: Backend/models/music_media.dart.
// Purpose: Defines lossless music media/version metadata used by ARM and playback.
// This file is part of the documented Flutter/home-server architecture.

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

  /// Indicates whether this version should be retained as the lossless archive master.
  bool get isLosslessArchiveMaster => lossless && archiveFormat.toLowerCase() == 'flac';

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
        'genres': genres,
        'artworkUrl': artworkUrl,
      };
}
