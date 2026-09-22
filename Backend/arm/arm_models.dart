// FILE: `Backend/arm/arm_models.dart`.
// Purpose: Defines ARM domain models used by the streaming service backend.
//
// This file is part of the documented Flutter/home-server architecture.
//
// The models intentionally distinguish:
//   PhysicalRelease -> Disc -> DiscContent
// from the canonical media identity represented by the content.
//
// This allows a physical package to contain multiple discs and allows a disc
// to contain multiple pieces of content without creating fake movie/music
// titles in the normal library.
//
// Music also distinguishes:
//
//   MusicRelease -> MusicMedium -> MusicTrack -> MusicRecording
//
// A MusicRecording represents the canonical underlying recording. Therefore,
// the same song can be present on a movie soundtrack and an artist album
// without becoming two unrelated songs.

class ArmDrive {
  final String id;
  final String path;
  final String name;
  final bool available;
  final bool discInserted;

  ArmDrive({
    required this.id,
    required this.path,
    required this.name,
    required this.available,
    required this.discInserted,
  });

  factory ArmDrive.fromJson(Map<String, dynamic> json) {
    return ArmDrive(
      id: json['id']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      available: json['available'] == true,
      discInserted: json['discInserted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'name': name,
        'available': available,
        'discInserted': discInserted,
      };
}

/// Broad classification of a physical media release.
enum ArmReleaseType {
  movie,
  tv,
  soundtrack,
  album,
  compilation,
  musicVideo,
  game,
  data,
  mixed,
  other,
}

extension ArmReleaseTypeExtension on ArmReleaseType {
  String get value => name;

  static ArmReleaseType fromValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';

    for (final type in ArmReleaseType.values) {
      if (type.name == normalized) {
        return type;
      }
    }

    return ArmReleaseType.other;
  }
}

/// Describes the physical role of a disc inside a release.
enum ArmDiscType {
  movie,
  bonusFeatures,
  soundtrack,
  music,
  data,
  extras,
  mixed,
  other,
}

extension ArmDiscTypeExtension on ArmDiscType {
  String get value => name;

  static ArmDiscType fromValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';

    switch (normalized) {
      case 'movie':
      case 'film':
      case 'feature':
        return ArmDiscType.movie;

      case 'bonus':
      case 'bonus_features':
      case 'bonusfeatures':
        return ArmDiscType.bonusFeatures;

      case 'soundtrack':
      case 'ost':
        return ArmDiscType.soundtrack;

      case 'music':
      case 'album':
        return ArmDiscType.music;

      case 'data':
        return ArmDiscType.data;

      case 'extras':
      case 'extra':
        return ArmDiscType.extras;

      case 'mixed':
        return ArmDiscType.mixed;

      default:
        return ArmDiscType.other;
    }
  }
}

/// Describes what an individual item on a physical disc represents.
enum ArmDiscContentType {
  feature,
  episode,
  bonusFeature,
  deletedScene,
  commentary,
  trailer,
  makingOf,
  interview,
  musicVideo,
  soundtrack,
  song,
  album,
  data,
  subtitle,
  menu,
  other,
}

extension ArmDiscContentTypeExtension on ArmDiscContentType {
  String get value => name;

  static ArmDiscContentType fromValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';

    switch (normalized) {
      case 'feature':
      case 'main_feature':
      case 'movie':
      case 'film':
        return ArmDiscContentType.feature;

      case 'episode':
      case 'tv_episode':
        return ArmDiscContentType.episode;

      case 'bonus':
      case 'bonus_feature':
      case 'bonus_features':
        return ArmDiscContentType.bonusFeature;

      case 'deleted_scene':
      case 'deleted_scenes':
        return ArmDiscContentType.deletedScene;

      case 'commentary':
      case 'audio_commentary':
        return ArmDiscContentType.commentary;

      case 'trailer':
      case 'trailers':
        return ArmDiscContentType.trailer;

      case 'making_of':
      case 'makingof':
      case 'behind_the_scenes':
        return ArmDiscContentType.makingOf;

      case 'interview':
      case 'interviews':
        return ArmDiscContentType.interview;

      case 'music_video':
      case 'musicvideo':
        return ArmDiscContentType.musicVideo;

      case 'soundtrack':
      case 'ost':
        return ArmDiscContentType.soundtrack;

      case 'song':
      case 'track':
        return ArmDiscContentType.song;

      case 'album':
        return ArmDiscContentType.album;

      case 'data':
        return ArmDiscContentType.data;

      case 'subtitle':
      case 'subtitles':
        return ArmDiscContentType.subtitle;

      case 'menu':
      case 'menus':
        return ArmDiscContentType.menu;

      default:
        return ArmDiscContentType.other;
    }
  }
}

/// Represents a physical retail/release package.
///
/// Example:
///
/// Back to the Future Trilogy — 4 Disc Edition
///   Disc 1 -> Back to the Future
///   Disc 2 -> Back to the Future Part II
///   Disc 3 -> Back to the Future Part III
///   Disc 4 -> Bonus Features
///
/// The release is the package. Individual discs belong to the release.
class ArmPhysicalRelease {
  final String id;
  final String title;
  final ArmReleaseType releaseType;
  final String? edition;
  final String? barcode;
  final String? catalogNumber;
  final String? country;
  final String? region;
  final int? releaseYear;
  final String? label;
  final String? publisher;
  final String? format;
  final String? notes;
  final List<ArmPhysicalDisc> discs;
  final Map<String, dynamic> metadata;

  ArmPhysicalRelease({
    required this.id,
    required this.title,
    this.releaseType = ArmReleaseType.other,
    this.edition,
    this.barcode,
    this.catalogNumber,
    this.country,
    this.region,
    this.releaseYear,
    this.label,
    this.publisher,
    this.format,
    this.notes,
    this.discs = const [],
    this.metadata = const {},
  });

  int get discCount => discs.length;

  factory ArmPhysicalRelease.fromJson(Map<String, dynamic> json) {
    return ArmPhysicalRelease(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ??
          json['name']?.toString() ??
          'Unknown release',
      releaseType: ArmReleaseTypeExtension.fromValue(
        json['releaseType'] ?? json['type'],
      ),
      edition: _string(json['edition']),
      barcode: _string(json['barcode']),
      catalogNumber: _string(
        json['catalogNumber'] ?? json['catalog_number'],
      ),
      country: _string(json['country']),
      region: _string(json['region']),
      releaseYear: _int(
        json['releaseYear'] ?? json['year'],
      ),
      label: _string(json['label']),
      publisher: _string(json['publisher']),
      format: _string(json['format']),
      notes: _string(json['notes']),
      discs: _maps(json['discs'])
          .map(ArmPhysicalDisc.fromJson)
          .toList(),
      metadata: Map<String, dynamic>.from(
        json['metadata'] is Map ? json['metadata'] as Map : json,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'releaseType': releaseType.name,
        'edition': edition,
        'barcode': barcode,
        'catalogNumber': catalogNumber,
        'country': country,
        'region': region,
        'releaseYear': releaseYear,
        'label': label,
        'publisher': publisher,
        'format': format,
        'notes': notes,
        'discCount': discs.length,
        'discs': discs.map((disc) => disc.toJson()).toList(),
        'metadata': metadata,
      };
}

/// A physical disc belonging to a physical release.
///
/// A disc is deliberately separate from the media it contains.
///
/// For example, a bonus disc does not become another movie merely because it
/// contains video files.
class ArmPhysicalDisc {
  final String id;
  final String releaseId;
  final int discNumber;
  final String? title;
  final ArmDiscType discType;
  final String? region;
  final String? barcode;
  final String? side;
  final String? format;
  final String? filesystem;
  final String? discFingerprint;
  final String? outputPath;
  final List<ArmDiscContent> contents;
  final Map<String, dynamic> metadata;

  ArmPhysicalDisc({
    required this.id,
    required this.releaseId,
    required this.discNumber,
    this.title,
    this.discType = ArmDiscType.other,
    this.region,
    this.barcode,
    this.side,
    this.format,
    this.filesystem,
    this.discFingerprint,
    this.outputPath,
    this.contents = const [],
    this.metadata = const {},
  });

  bool get isBonusDisc =>
      discType == ArmDiscType.bonusFeatures ||
      discType == ArmDiscType.extras;

  bool get isMusicDisc =>
      discType == ArmDiscType.soundtrack ||
      discType == ArmDiscType.music;

  factory ArmPhysicalDisc.fromJson(Map<String, dynamic> json) {
    final releaseId =
        json['releaseId']?.toString() ??
            json['physicalReleaseId']?.toString() ??
            '';

    return ArmPhysicalDisc(
      id: json['id']?.toString() ?? '',
      releaseId: releaseId,
      discNumber: _int(json['discNumber'] ?? json['number']) ?? 1,
      title: _string(json['title']),
      discType: ArmDiscTypeExtension.fromValue(
        json['discType'] ?? json['type'],
      ),
      region: _string(json['region']),
      barcode: _string(json['barcode']),
      side: _string(json['side']),
      format: _string(json['format']),
      filesystem: _string(json['filesystem']),
      discFingerprint: _string(
        json['discFingerprint'] ?? json['fingerprint'],
      ),
      outputPath: _string(json['outputPath'] ?? json['path']),
      contents: _maps(json['contents'])
          .map(ArmDiscContent.fromJson)
          .toList(),
      metadata: Map<String, dynamic>.from(
        json['metadata'] is Map ? json['metadata'] as Map : json,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'releaseId': releaseId,
        'discNumber': discNumber,
        'title': title,
        'discType': discType.name,
        'region': region,
        'barcode': barcode,
        'side': side,
        'format': format,
        'filesystem': filesystem,
        'discFingerprint': discFingerprint,
        'outputPath': outputPath,
        'contentCount': contents.length,
        'contents': contents.map((content) => content.toJson()).toList(),
        'metadata': metadata,
      };
}

/// Represents an individual piece of content found on a physical disc.
///
/// This is the key model that prevents bonus material from being confused
/// with the primary movie/show/music title.
class ArmDiscContent {
  final String id;
  final String discId;
  final int? position;
  final ArmDiscContentType contentType;
  final String title;
  final String? mediaId;
  final String? recordingId;
  final String? releaseId;
  final String? outputPath;
  final String? container;
  final String? codec;
  final double? durationSeconds;
  final int? sizeBytes;
  final String? fingerprint;
  final double confidence;
  final bool primary;
  final Map<String, dynamic> metadata;

  ArmDiscContent({
    required this.id,
    required this.discId,
    required this.title,
    this.position,
    this.contentType = ArmDiscContentType.other,
    this.mediaId,
    this.recordingId,
    this.releaseId,
    this.outputPath,
    this.container,
    this.codec,
    this.durationSeconds,
    this.sizeBytes,
    this.fingerprint,
    this.confidence = 0,
    this.primary = false,
    this.metadata = const {},
  });

  bool get isFeature =>
      contentType == ArmDiscContentType.feature;

  bool get isBonus =>
      contentType == ArmDiscContentType.bonusFeature ||
      contentType == ArmDiscContentType.deletedScene ||
      contentType == ArmDiscContentType.commentary ||
      contentType == ArmDiscContentType.trailer ||
      contentType == ArmDiscContentType.makingOf ||
      contentType == ArmDiscContentType.interview;

  bool get isMusic =>
      contentType == ArmDiscContentType.song ||
      contentType == ArmDiscContentType.soundtrack ||
      contentType == ArmDiscContentType.album ||
      contentType == ArmDiscContentType.musicVideo;

  factory ArmDiscContent.fromJson(Map<String, dynamic> json) {
    return ArmDiscContent(
      id: json['id']?.toString() ??
          json['contentId']?.toString() ??
          '',
      discId: json['discId']?.toString() ?? '',
      position: _int(json['position'] ?? json['trackNumber']),
      contentType: ArmDiscContentTypeExtension.fromValue(
        json['contentType'] ??
            json['type'] ??
            json['classification'],
      ),
      title: json['title']?.toString() ??
          json['name']?.toString() ??
          'Unknown content',
      mediaId: _string(
        json['mediaId'] ?? json['movieId'] ?? json['showId'],
      ),
      recordingId: _string(
        json['recordingId'] ?? json['canonicalRecordingId'],
      ),
      releaseId: _string(
        json['releaseId'] ?? json['musicReleaseId'],
      ),
      outputPath: _string(
        json['outputPath'] ?? json['path'],
      ),
      container: _string(
        json['container'] ?? json['format'],
      ),
      codec: _string(
        json['codec'] ?? json['codecName'],
      ),
      durationSeconds: _double(
        json['durationSeconds'] ??
            json['duration'] ??
            json['runtime'],
      ),
      sizeBytes: _int(
        json['sizeBytes'] ?? json['fileSize'],
      ),
      fingerprint: _string(
        json['fingerprint'] ?? json['contentFingerprint'],
      ),
      confidence: _double(
            json['confidence'] ?? json['matchConfidence'],
          ) ??
          0,
      primary: json['primary'] == true ||
          json['isPrimary'] == true,
      metadata: Map<String, dynamic>.from(
        json['metadata'] is Map ? json['metadata'] as Map : json,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'discId': discId,
        'position': position,
        'contentType': contentType.name,
        'title': title,
        'mediaId': mediaId,
        'recordingId': recordingId,
        'releaseId': releaseId,
        'outputPath': outputPath,
        'container': container,
        'codec': codec,
        'durationSeconds': durationSeconds,
        'sizeBytes': sizeBytes,
        'fingerprint': fingerprint,
        'confidence': confidence,
        'primary': primary,
        'metadata': metadata,
      };
}

/// Canonical identity of an underlying musical recording.
///
/// This is intentionally separate from an album/soundtrack release.
///
/// Example:
///
///   Recording: "EOO" by Bad Bunny
///
/// can be referenced by:
///
///   Spider-Man: Brand New Day soundtrack -> track -> recording
///   Bad Bunny album                      -> track -> same recording
///
/// Therefore ingestion order does not matter.
class ArmMusicRecording {
  final String id;
  final String title;
  final List<String> artistIds;
  final List<String> artists;
  final String? albumArtist;
  final double? durationSeconds;
  final String? isrc;
  final String? audioFingerprint;
  final String? normalizedFingerprint;
  final String? releaseDate;
  final Map<String, dynamic> metadata;

  ArmMusicRecording({
    required this.id,
    required this.title,
    this.artistIds = const [],
    this.artists = const [],
    this.albumArtist,
    this.durationSeconds,
    this.isrc,
    this.audioFingerprint,
    this.normalizedFingerprint,
    this.releaseDate,
    this.metadata = const {},
  });

  factory ArmMusicRecording.fromJson(Map<String, dynamic> json) {
    return ArmMusicRecording(
      id: json['id']?.toString() ??
          json['recordingId']?.toString() ??
          '',
      title: json['title']?.toString() ??
          json['name']?.toString() ??
          'Unknown recording',
      artistIds: _strings(
        json['artistIds'] ?? json['artist_ids'],
      ),
      artists: _strings(
        json['artists'] ??
            json['artistNames'] ??
            json['artist'],
      ),
      albumArtist: _string(json['albumArtist']),
      durationSeconds: _double(
        json['durationSeconds'] ??
            json['duration'],
      ),
      isrc: _string(json['isrc'] ?? json['ISRC']),
      audioFingerprint: _string(
        json['audioFingerprint'] ??
            json['fingerprint'],
      ),
      normalizedFingerprint: _string(
        json['normalizedFingerprint'],
      ),
      releaseDate: _string(json['releaseDate']),
      metadata: Map<String, dynamic>.from(
        json['metadata'] is Map ? json['metadata'] as Map : json,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artistIds': artistIds,
        'artists': artists,
        'albumArtist': albumArtist,
        'durationSeconds': durationSeconds,
        'isrc': isrc,
        'audioFingerprint': audioFingerprint,
        'normalizedFingerprint': normalizedFingerprint,
        'releaseDate': releaseDate,
        'metadata': metadata,
      };
}

/// A music release such as an album, soundtrack, EP, single, or compilation.
///
/// The release owns track listings, but the tracks reference canonical
/// ArmMusicRecording objects.
class ArmMusicRelease {
  final String id;
  final String title;
  final String? artist;
  final List<String> artistIds;
  final String releaseType;
  final String? edition;
  final String? releaseDate;
  final int? releaseYear;
  final String? barcode;
  final String? catalogNumber;
  final String? label;
  final String? country;
  final String? artworkPath;
  final List<ArmMusicMedium> mediums;
  final Map<String, dynamic> metadata;

  ArmMusicRelease({
    required this.id,
    required this.title,
    this.artist,
    this.artistIds = const [],
    this.releaseType = 'album',
    this.edition,
    this.releaseDate,
    this.releaseYear,
    this.barcode,
    this.catalogNumber,
    this.label,
    this.country,
    this.artworkPath,
    this.mediums = const [],
    this.metadata = const {},
  });

  int get trackCount =>
      mediums.fold<int>(0, (count, medium) => count + medium.tracks.length);

  int get discCount => mediums.length;

  factory ArmMusicRelease.fromJson(Map<String, dynamic> json) {
    return ArmMusicRelease(
      id: json['id']?.toString() ??
          json['releaseId']?.toString() ??
          '',
      title: json['title']?.toString() ??
          json['name']?.toString() ??
          'Unknown release',
      artist: _string(
        json['artist'] ?? json['artistName'],
      ),
      artistIds: _strings(
        json['artistIds'] ?? json['artist_ids'],
      ),
      releaseType: json['releaseType']?.toString() ??
          json['type']?.toString() ??
          'album',
      edition: _string(json['edition']),
      releaseDate: _string(json['releaseDate']),
      releaseYear: _int(
        json['releaseYear'] ?? json['year'],
      ),
      barcode: _string(json['barcode']),
      catalogNumber: _string(
        json['catalogNumber'] ?? json['catalog_number'],
      ),
      label: _string(json['label']),
      country: _string(json['country']),
      artworkPath: _string(
        json['artworkPath'] ?? json['coverPath'],
      ),
      mediums: _maps(
        json['mediums'] ?? json['discs'],
      ).map(ArmMusicMedium.fromJson).toList(),
      metadata: Map<String, dynamic>.from(
        json['metadata'] is Map ? json['metadata'] as Map : json,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'artistIds': artistIds,
        'releaseType': releaseType,
        'edition': edition,
        'releaseDate': releaseDate,
        'releaseYear': releaseYear,
        'barcode': barcode,
        'catalogNumber': catalogNumber,
        'label': label,
        'country': country,
        'artworkPath': artworkPath,
        'discCount': mediums.length,
        'trackCount': trackCount,
        'mediums': mediums.map((medium) => medium.toJson()).toList(),
        'metadata': metadata,
      };
}

/// A physical/logical medium within a music release.
///
/// A multi-disc album therefore becomes:
///
/// MusicRelease
///   -> Medium 1
///   -> Medium 2
///
/// rather than pretending the two discs are separate albums.
class ArmMusicMedium {
  final String id;
  final String releaseId;
  final int mediumNumber;
  final String? title;
  final String? mediumType;
  final List<ArmMusicTrack> tracks;
  final Map<String, dynamic> metadata;

  ArmMusicMedium({
    required this.id,
    required this.releaseId,
    required this.mediumNumber,
    this.title,
    this.mediumType,
    this.tracks = const [],
    this.metadata = const {},
  });

  factory ArmMusicMedium.fromJson(Map<String, dynamic> json) {
    return ArmMusicMedium(
      id: json['id']?.toString() ??
          json['mediumId']?.toString() ??
          '',
      releaseId: json['releaseId']?.toString() ?? '',
      mediumNumber: _int(
            json['mediumNumber'] ??
                json['discNumber'] ??
                json['number'],
          ) ??
          1,
      title: _string(json['title']),
      mediumType: _string(
        json['mediumType'] ?? json['type'],
      ),
      tracks: _maps(json['tracks'])
          .map(ArmMusicTrack.fromJson)
          .toList(),
      metadata: Map<String, dynamic>.from(
        json['metadata'] is Map ? json['metadata'] as Map : json,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'releaseId': releaseId,
        'mediumNumber': mediumNumber,
        'title': title,
        'mediumType': mediumType,
        'trackCount': tracks.length,
        'tracks': tracks.map((track) => track.toJson()).toList(),
        'metadata': metadata,
      };
}

/// A track listing on a specific music release.
///
/// The important relationship is `recordingId`.
///
/// Two tracks on different releases can point to the same recording.
class ArmMusicTrack {
  final String id;
  final String releaseId;
  final String mediumId;
  final int trackNumber;
  final String title;
  final String? recordingId;
  final ArmMusicRecording? recording;
  final String? artist;
  final double? durationSeconds;
  final String? isrc;
  final String? outputPath;
  final String? fingerprint;
  final bool explicit;
  final Map<String, dynamic> metadata;

  ArmMusicTrack({
    required this.id,
    required this.releaseId,
    required this.mediumId,
    required this.trackNumber,
    required this.title,
    this.recordingId,
    this.recording,
    this.artist,
    this.durationSeconds,
    this.isrc,
    this.outputPath,
    this.fingerprint,
    this.explicit = false,
    this.metadata = const {},
  });

  bool get hasCanonicalRecording =>
      recordingId?.trim().isNotEmpty == true ||
      recording != null;

  factory ArmMusicTrack.fromJson(Map<String, dynamic> json) {
    final rawRecording = json['recording'];

    return ArmMusicTrack(
      id: json['id']?.toString() ??
          json['trackId']?.toString() ??
          '',
      releaseId: json['releaseId']?.toString() ?? '',
      mediumId: json['mediumId']?.toString() ?? '',
      trackNumber: _int(
            json['trackNumber'] ??
                json['track'] ??
                json['position'],
          ) ??
          1,
      title: json['title']?.toString() ??
          json['name']?.toString() ??
          'Unknown track',
      recordingId: _string(
        json['recordingId'] ??
            json['canonicalRecordingId'],
      ),
      recording: rawRecording is Map
          ? ArmMusicRecording.fromJson(
              Map<String, dynamic>.from(rawRecording),
            )
          : null,
      artist: _string(
        json['artist'] ?? json['artistName'],
      ),
      durationSeconds: _double(
        json['durationSeconds'] ??
            json['duration'],
      ),
      isrc: _string(json['isrc'] ?? json['ISRC']),
      outputPath: _string(
        json['outputPath'] ?? json['path'],
      ),
      fingerprint: _string(
        json['fingerprint'] ??
            json['audioFingerprint'],
      ),
      explicit: json['explicit'] == true,
      metadata: Map<String, dynamic>.from(
        json['metadata'] is Map ? json['metadata'] as Map : json,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'releaseId': releaseId,
        'mediumId': mediumId,
        'trackNumber': trackNumber,
        'title': title,
        'recordingId': recordingId,
        'recording': recording?.toJson(),
        'artist': artist,
        'durationSeconds': durationSeconds,
        'isrc': isrc,
        'outputPath': outputPath,
        'fingerprint': fingerprint,
        'explicit': explicit,
        'hasCanonicalRecording': hasCanonicalRecording,
        'metadata': metadata,
      };
}

/// Result of attempting to associate an imported/ripped track with a
/// canonical recording.
///
/// `created` means a new canonical recording was necessary.
/// `matched` means an existing canonical recording was found.
///
/// This allows ingestion order to be independent.
class ArmRecordingMatch {
  final String recordingId;
  final bool matched;
  final bool created;
  final double confidence;
  final String? method;
  final String? reason;

  ArmRecordingMatch({
    required this.recordingId,
    this.matched = false,
    this.created = false,
    this.confidence = 0,
    this.method,
    this.reason,
  });

  factory ArmRecordingMatch.fromJson(Map<String, dynamic> json) {
    return ArmRecordingMatch(
      recordingId: json['recordingId']?.toString() ??
          json['id']?.toString() ??
          '',
      matched: json['matched'] == true,
      created: json['created'] == true,
      confidence: _double(
            json['confidence'] ??
                json['matchConfidence'],
          ) ??
          0,
      method: _string(json['method']),
      reason: _string(json['reason']),
    );
  }

  Map<String, dynamic> toJson() => {
        'recordingId': recordingId,
        'matched': matched,
        'created': created,
        'confidence': confidence,
        'method': method,
        'reason': reason,
      };
}

/// ARM's legacy/flat representation of detected title content.
///
/// This remains in place for compatibility with existing ARM routes/services.
/// New code that needs package/disc provenance can use
/// ArmPhysicalRelease -> ArmPhysicalDisc -> ArmDiscContent.
class ArmDiscTitle {
  final String id;
  final String title;
  final String mediaType;
  final String? classification;
  final int? year;
  final double? durationSeconds;
  final double confidence;
  final String? outputPath;
  final Map<String, dynamic> metadata;
  final String? canonicalTitle;
  final String? originalTitle;
  final String? originalLanguage;
  final String? countryOfOrigin;
  final String? discTitle;
  final String? discMarketCountry;
  final String? detectedRegion;
  final String? audioCodec;
  final String archiveFormat;
  final bool losslessAudio;
  final int? trackNumber;
  final int? discNumber;
  final String? artist;
  final String? album;

  ArmDiscTitle({
    required this.id,
    required this.title,
    this.mediaType = 'movie',
    this.classification = 'feature',
    this.year,
    this.durationSeconds,
    this.confidence = 0,
    this.outputPath,
    this.metadata = const {},
    this.canonicalTitle,
    this.originalTitle,
    this.originalLanguage,
    this.countryOfOrigin,
    this.discTitle,
    this.discMarketCountry,
    this.detectedRegion,
    this.audioCodec,
    this.archiveFormat = 'flac',
    this.losslessAudio = false,
    this.trackNumber,
    this.discNumber,
    this.artist,
    this.album,
  });

  bool get isMusic =>
      mediaType.toLowerCase().contains('music') ||
      mediaType.toLowerCase().contains('audio') ||
      classification?.toLowerCase() == 'track' ||
      classification?.toLowerCase() == 'album';

  String get preferredArchiveFormat =>
      isMusic ? 'flac' : 'source';

  bool get isFeatureMovie {
    final type = mediaType.toLowerCase();
    final kind = (classification ?? '').toLowerCase();

    return (type.contains('movie') || type.contains('film')) &&
        (kind.isEmpty ||
            kind == 'feature' ||
            kind == 'feature_film' ||
            kind == 'main_feature');
  }

  /// Converts this legacy ARM title into the newer disc-content model.
  ArmDiscContent toDiscContent({
    required String discId,
    String? contentId,
  }) {
    return ArmDiscContent(
      id: contentId ?? id,
      discId: discId,
      position: trackNumber,
      contentType: _contentTypeFromLegacyClassification(
        classification,
        mediaType,
      ),
      title: title,
      mediaId: isFeatureMovie ? id : null,
      outputPath: outputPath,
      codec: audioCodec,
      durationSeconds: durationSeconds,
      confidence: confidence,
      primary: isFeatureMovie,
      metadata: metadata,
    );
  }

  factory ArmDiscTitle.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
  }) {
    final rawConfidence =
        json['confidence'] ?? json['matchConfidence'];

    return ArmDiscTitle(
      id: json['id']?.toString() ??
          json['titleId']?.toString() ??
          fallbackId ??
          '',
      title: json['title']?.toString() ??
          json['name']?.toString() ??
          'Unknown title',
      mediaType: json['mediaType']?.toString() ??
          json['type']?.toString() ??
          json['videotype']?.toString() ??
          'movie',
      classification: json['classification']?.toString() ??
          json['kind']?.toString() ??
          json['contentType']?.toString() ??
          'feature',
      year: _int(
        json['year'] ?? json['releaseYear'],
      ),
      durationSeconds: _double(
        json['durationSeconds'] ??
            json['duration'] ??
            json['runtime'] ??
            json['length'],
      ),
      confidence: rawConfidence is num
          ? rawConfidence.toDouble()
          : double.tryParse(
                rawConfidence?.toString() ?? '',
              ) ??
              0,
      outputPath: json['outputPath']?.toString() ??
          json['output_path']?.toString() ??
          json['path']?.toString(),
      metadata: Map<String, dynamic>.from(json),
      canonicalTitle: json['canonicalTitle']?.toString() ??
          json['originalTitle']?.toString(),
      originalTitle: json['originalTitle']?.toString(),
      originalLanguage: json['originalLanguage']?.toString(),
      countryOfOrigin: json['countryOfOrigin']?.toString(),
      discTitle: json['discTitle']?.toString() ??
          json['title']?.toString(),
      discMarketCountry: json['discMarketCountry']?.toString() ??
          json['discCountry']?.toString(),
      detectedRegion: json['detectedRegion']?.toString() ??
          json['region']?.toString(),
      audioCodec: json['audioCodec']?.toString() ??
          json['codec_name']?.toString(),
      archiveFormat: json['archiveFormat']?.toString() ??
          (json['mediaType']
                      ?.toString()
                      .toLowerCase()
                      .contains('music') ==
                  true
              ? 'flac'
              : 'source'),
      losslessAudio: json['losslessAudio'] == true ||
          _isLosslessCodec(
            json['audioCodec'] ?? json['codec_name'],
          ),
      trackNumber: _int(
        json['trackNumber'] ?? json['track'],
      ),
      discNumber: _int(
        json['discNumber'] ?? json['disc'],
      ),
      artist: json['artist']?.toString(),
      album: json['album']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'mediaType': mediaType,
        'classification': classification,
        'year': year,
        'durationSeconds': durationSeconds,
        'confidence': confidence,
        'outputPath': outputPath,
        'metadata': metadata,
        'canonicalTitle': canonicalTitle,
        'originalTitle': originalTitle,
        'originalLanguage': originalLanguage,
        'countryOfOrigin': countryOfOrigin,
        'discTitle': discTitle,
        'discMarketCountry': discMarketCountry,
        'detectedRegion': detectedRegion,
        'audioCodec': audioCodec,
        'archiveFormat': archiveFormat,
        'losslessAudio': losslessAudio,
        'trackNumber': trackNumber,
        'discNumber': discNumber,
        'artist': artist,
        'album': album,
      };

  static double? _double(dynamic value) =>
      value is num
          ? value.toDouble()
          : double.tryParse(
              value?.toString() ?? '',
            );

  static int? _int(dynamic value) =>
      value is num
          ? value.toInt()
          : int.tryParse(
              value?.toString() ?? '',
            );

  static bool _isLosslessCodec(dynamic value) {
    final codec = value?.toString().toLowerCase().trim();

    return codec == 'flac' ||
        codec == 'alac' ||
        codec == 'wavpack' ||
        codec == 'pcm_s16le' ||
        codec == 'pcm_s24le' ||
        codec == 'pcm_s32le';
  }

  static ArmDiscContentType _contentTypeFromLegacyClassification(
    String? classification,
    String mediaType,
  ) {
    final normalized =
        (classification ?? '').trim().toLowerCase();
    final normalizedMediaType =
        mediaType.trim().toLowerCase();

    if (normalized == 'track' ||
        normalized == 'song' ||
        normalizedMediaType.contains('music') ||
        normalizedMediaType.contains('audio')) {
      return ArmDiscContentType.song;
    }

    if (normalized == 'album') {
      return ArmDiscContentType.album;
    }

    if (normalized == 'bonus' ||
        normalized == 'bonus_feature' ||
        normalized == 'bonus_features') {
      return ArmDiscContentType.bonusFeature;
    }

    if (normalized == 'deleted_scene' ||
        normalized == 'deleted_scenes') {
      return ArmDiscContentType.deletedScene;
    }

    if (normalized == 'commentary') {
      return ArmDiscContentType.commentary;
    }

    if (normalized == 'trailer' ||
        normalized == 'trailers') {
      return ArmDiscContentType.trailer;
    }

    if (normalized == 'making_of' ||
        normalized == 'makingof') {
      return ArmDiscContentType.makingOf;
    }

    if (normalized == 'interview') {
      return ArmDiscContentType.interview;
    }

    if (normalized == 'music_video' ||
        normalized == 'musicvideo') {
      return ArmDiscContentType.musicVideo;
    }

    return ArmDiscContentType.feature;
  }
}

/// ARM's detected disc representation.
///
/// Kept for compatibility with existing ARM detection APIs. A detected disc
/// can later be promoted into an ArmPhysicalDisc once the release/package
/// relationship is known.
class ArmDisc {
  final String driveId;
  final String? title;
  final String? mediaType;
  final String? discType;
  final String? region;
  final bool detected;
  final List<ArmDiscTitle> titles;

  ArmDisc({
    required this.driveId,
    this.title,
    this.mediaType,
    this.discType,
    this.region,
    required this.detected,
    this.titles = const [],
  });

  /// Converts the detected ARM disc into the richer physical-disc model.
  ArmPhysicalDisc toPhysicalDisc({
    required String id,
    required String releaseId,
    int discNumber = 1,
  }) {
    return ArmPhysicalDisc(
      id: id,
      releaseId: releaseId,
      discNumber: discNumber,
      title: title,
      discType: ArmDiscTypeExtension.fromValue(discType),
      region: region,
      contents: titles
          .map(
            (title) => title.toDiscContent(
              discId: id,
            ),
          )
          .toList(),
      metadata: {
        'driveId': driveId,
        'mediaType': mediaType,
        'detected': detected,
      },
    );
  }

  factory ArmDisc.fromJson(
    Map<String, dynamic> json,
  ) =>
      ArmDisc(
        driveId: json['driveId']?.toString() ?? '',
        title: json['title']?.toString(),
        mediaType: json['mediaType']?.toString(),
        discType: json['discType']?.toString(),
        region: json['region']?.toString(),
        detected: json['detected'] == true,
        titles: json['titles'] is List
            ? (json['titles'] as List)
                .whereType<Map>()
                .map(
                  (e) => ArmDiscTitle.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'driveId': driveId,
        'title': title,
        'mediaType': mediaType,
        'discType': discType,
        'region': region,
        'detected': detected,
        'titles': titles
            .map((title) => title.toJson())
            .toList(),
      };
}

enum ArmJobStatus {
  queued,
  detecting,
  identifying,
  ripping,
  processing,
  verifying,
  readyForReview,
  completed,
  failed,
  rejected,
  cancelled,
}

class ArmVerificationResult {
  final bool passed;
  final double score;
  final String? reason;
  final List<String> checks;
  final List<String> failures;
  final double? durationSeconds;
  final double? expectedDurationSeconds;
  final int? chapterCount;
  final int? expectedChapterCount;
  final bool hasVideo;
  final bool hasAudio;
  final bool contentFingerprintAvailable;

  ArmVerificationResult({
    required this.passed,
    required this.score,
    this.reason,
    this.checks = const [],
    this.failures = const [],
    this.durationSeconds,
    this.expectedDurationSeconds,
    this.chapterCount,
    this.expectedChapterCount,
    this.hasVideo = false,
    this.hasAudio = false,
    this.contentFingerprintAvailable = false,
  });

  factory ArmVerificationResult.fromJson(
    Map<String, dynamic> json,
  ) =>
      ArmVerificationResult(
        passed: json['passed'] == true,
        score: json['score'] is num
            ? (json['score'] as num).toDouble()
            : 0,
        reason: json['reason']?.toString(),
        checks: _strings(json['checks']),
        failures: _strings(json['failures']),
        durationSeconds: _double(
          json['durationSeconds'],
        ),
        expectedDurationSeconds: _double(
          json['expectedDurationSeconds'],
        ),
        chapterCount: _int(
          json['chapterCount'],
        ),
        expectedChapterCount: _int(
          json['expectedChapterCount'],
        ),
        hasVideo: json['hasVideo'] == true,
        hasAudio: json['hasAudio'] == true,
        contentFingerprintAvailable:
            json['contentFingerprintAvailable'] == true,
      );

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'score': score,
        'reason': reason,
        'checks': checks,
        'failures': failures,
        'durationSeconds': durationSeconds,
        'expectedDurationSeconds': expectedDurationSeconds,
        'chapterCount': chapterCount,
        'expectedChapterCount': expectedChapterCount,
        'hasVideo': hasVideo,
        'hasAudio': hasAudio,
        'contentFingerprintAvailable':
            contentFingerprintAvailable,
      };

  static List<String> _strings(dynamic value) =>
      value is List
          ? value.map((e) => e.toString()).toList()
          : <String>[];

  static double? _double(dynamic value) =>
      value is num
          ? value.toDouble()
          : double.tryParse(
              value?.toString() ?? '',
            );

  static int? _int(dynamic value) =>
      value is num
          ? value.toInt()
          : int.tryParse(
              value?.toString() ?? '',
            );
}

class ArmRipJob {
  final String id;
  final String driveId;
  String status;
  double progress;
  String? title;
  String? mediaType;
  String? message;
  String? outputPath;
  String? discType;
  String? region;
  DateTime createdAt;
  DateTime? completedAt;
  ArmVerificationResult? verification;
  List<ArmDiscTitle> titles;
  String? collectionTitle;

  /// Physical release identified for this rip.
  ArmPhysicalRelease? physicalRelease;

  /// Physical disc represented by this rip.
  ArmPhysicalDisc? physicalDisc;

  /// Canonical music recordings identified during this rip.
  List<ArmMusicRecording> recordings;

  ArmRipJob({
    required this.id,
    required this.driveId,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.title,
    this.mediaType,
    this.message,
    this.outputPath,
    this.discType,
    this.region,
    this.completedAt,
    this.verification,
    this.titles = const [],
    this.collectionTitle,
    this.physicalRelease,
    this.physicalDisc,
    this.recordings = const [],
  });

  bool get isFinished =>
      {
        ArmJobStatus.completed.name,
        ArmJobStatus.failed.name,
        ArmJobStatus.rejected.name,
        ArmJobStatus.cancelled.name,
        ArmJobStatus.readyForReview.name,
      }.contains(status);

  bool get containsBonusContent =>
      physicalDisc?.contents.any(
            (content) => content.isBonus,
          ) ??
      false;

  bool get containsMusic =>
      physicalDisc?.contents.any(
            (content) => content.isMusic,
          ) ??
      recordings.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'driveId': driveId,
        'status': status,
        'progress': progress,
        'title': title,
        'mediaType': mediaType,
        'message': message,
        'outputPath': outputPath,
        'discType': discType,
        'region': region,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'isFinished': isFinished,
        'verification': verification?.toJson(),
        'collectionTitle': collectionTitle,
        'titleCount': titles.length,
        'titles': titles
            .map((title) => title.toJson())
            .toList(),
        'physicalRelease': physicalRelease?.toJson(),
        'physicalDisc': physicalDisc?.toJson(),
        'recordingCount': recordings.length,
        'recordings': recordings
            .map((recording) => recording.toJson())
            .toList(),
        'containsBonusContent': containsBonusContent,
        'containsMusic': containsMusic,
      };
}

class ArmImportResult {
  final bool success;
  final String? jobId;
  final String? message;
  final ArmRipJob? job;

  ArmImportResult({
    required this.success,
    this.jobId,
    this.message,
    this.job,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'jobId': jobId,
        'message': message,
        'job': job?.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Shared parsing helpers.
// ---------------------------------------------------------------------------

String? _string(dynamic value) {
  if (value == null) {
    return null;
  }

  final result = value.toString().trim();

  return result.isEmpty ? null : result;
}

double? _double(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
    value?.toString() ?? '',
  );
}

int? _int(dynamic value) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
    value?.toString() ?? '',
  );
}

List<String> _strings(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  if (value == null) {
    return <String>[];
  }

  final single = value.toString().trim();

  return single.isEmpty ? <String>[] : <String>[single];
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) {
    return <Map<String, dynamic>>[];
  }

  return value
      .whereType<Map>()
      .map(
        (item) => Map<String, dynamic>.from(item),
      )
      .toList();
}