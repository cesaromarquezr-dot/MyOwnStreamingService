```dart id="5v8k2c"
// FILE: `Backend/arm/metadata_service.dart`.
//
// Purpose:
// Provides the provider-neutral metadata contracts used by ARM import
// review, physical-release identification, and canonical media matching.
//
// This file intentionally does NOT integrate a specific external metadata
// provider.
//
// Providers such as movie databases, music databases, barcode databases, or
// other licensed metadata services can implement MetadataProviderClient
// independently.
//
// Identity rules:
//
//   Physical Release
//       -> Physical Disc
//           -> Disc Content
//
//   Music Release
//       -> Music Track
//           -> Canonical Recording
//
// Metadata candidates describe possible identities. They do not by
// themselves establish that two pieces of media are the same canonical
// recording/title. The identity/persistence layer must perform that decision
// using verified identifiers, metadata, fingerprints, and/or human review.
//
// This file is part of the documented Flutter/home-server architecture.

import 'arm_models.dart';

/// Identifies the source that produced a metadata candidate.
///
/// `mock` is retained for the current unverified/import-review phase.
/// Production providers should use their own explicit enum value once
/// integrated.
enum MetadataProvider {
  mock,
  tmdb,
  imdb,
  musicBrainz,
  barcode,
  custom,
}

/// General type of metadata entity being identified.
enum MetadataEntityType {
  movie,
  tv,
  episode,
  bonusFeature,
  physicalRelease,
  musicRelease,
  recording,
  artist,
  unknown,
}

/// A provider-neutral external identifier.
///
/// Examples:
///   TMDB movie ID
///   IMDb title ID
///   MusicBrainz release ID
///   MusicBrainz recording ID
///   ISRC
///   UPC/EAN/GTIN
class MetadataExternalId {
  final String namespace;
  final String value;

  const MetadataExternalId({
    required this.namespace,
    required this.value,
  });

  bool get isValid =>
      namespace.trim().isNotEmpty &&
      value.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'namespace': namespace,
      'value': value,
    };
  }
}

/// Provider-neutral metadata search candidate.
///
/// A candidate is a possible match, not an automatically accepted identity.
class MetadataCandidate {
  final String id;
  final MetadataProvider provider;
  final MetadataEntityType entityType;

  final String title;
  final String? originalTitle;
  final int? year;

  final String? originalLanguage;
  final String? countryOfOrigin;

  final String? description;
  final String? artworkUrl;

  final double confidence;

  final List<MetadataExternalId> externalIds;

  /// Additional provider-specific metadata that does not belong in the
  /// provider-neutral fields.
  final Map<String, dynamic> metadata;

  const MetadataCandidate({
    required this.id,
    required this.provider,
    required this.entityType,
    required this.title,
    this.originalTitle,
    this.year,
    this.originalLanguage,
    this.countryOfOrigin,
    this.description,
    this.artworkUrl,
    this.confidence = 0,
    this.externalIds = const [],
    this.metadata = const {},
  });

  bool get isValid =>
      id.trim().isNotEmpty &&
      title.trim().isNotEmpty;

  /// Finds an external identifier by namespace.
  String? externalId(
    String namespace,
  ) {
    final normalized =
        namespace.trim().toLowerCase();

    for (final id in externalIds) {
      if (id.namespace.trim().toLowerCase() ==
          normalized) {
        final value = id.value.trim();

        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider': provider.name,
      'entityType': entityType.name,
      'title': title,
      'originalTitle': originalTitle,
      'year': year,
      'originalLanguage': originalLanguage,
      'countryOfOrigin': countryOfOrigin,
      'description': description,
      'artworkUrl': artworkUrl,
      'confidence': confidence,
      'externalIds':
          externalIds.map(
            (id) => id.toJson(),
          ).toList(),
      'metadata': metadata,
    };
  }
}

/// Search request passed to a metadata provider.
class MetadataSearchRequest {
  final String? title;
  final String? originalTitle;
  final String? discTitle;

  final int? year;
  final String? mediaType;

  final String? artist;
  final String? album;
  final String? trackTitle;

  final String? barcode;
  final String? isrc;

  final List<MetadataExternalId> externalIds;

  /// Allows a provider to receive additional hints without requiring the
  /// common interface to change every time a new provider is added.
  final Map<String, dynamic> hints;

  const MetadataSearchRequest({
    this.title,
    this.originalTitle,
    this.discTitle,
    this.year,
    this.mediaType,
    this.artist,
    this.album,
    this.trackTitle,
    this.barcode,
    this.isrc,
    this.externalIds = const [],
    this.hints = const {},
  });

  bool get hasUsefulQuery {
    return _nonEmpty(title) ||
        _nonEmpty(originalTitle) ||
        _nonEmpty(discTitle) ||
        _nonEmpty(artist) ||
        _nonEmpty(album) ||
        _nonEmpty(trackTitle) ||
        _nonEmpty(barcode) ||
        _nonEmpty(isrc) ||
        externalIds.any(
          (id) => id.isValid,
        );
  }

  bool _nonEmpty(
    String? value,
  ) =>
      value != null &&
      value.trim().isNotEmpty;
}

/// Provider-neutral result returned by a metadata search.
class MetadataSearchResult {
  final MetadataProvider provider;
  final MetadataSearchRequest request;
  final List<MetadataCandidate> candidates;

  final DateTime searchedAt;

  final bool fromCache;
  final String? error;

  const MetadataSearchResult({
    required this.provider,
    required this.request,
    required this.candidates,
    required this.searchedAt,
    this.fromCache = false,
    this.error,
  });

  bool get succeeded =>
      error == null;

  bool get hasCandidates =>
      candidates.isNotEmpty;

  MetadataCandidate? get highestConfidence {
    if (candidates.isEmpty) {
      return null;
    }

    MetadataCandidate best =
        candidates.first;

    for (final candidate
        in candidates.skip(1)) {
      if (candidate.confidence >
          best.confidence) {
        best = candidate;
      }
    }

    return best;
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.name,
      'request': {
        'title': request.title,
        'originalTitle': request.originalTitle,
        'discTitle': request.discTitle,
        'year': request.year,
        'mediaType': request.mediaType,
        'artist': request.artist,
        'album': request.album,
        'trackTitle': request.trackTitle,
        'barcode': request.barcode,
        'isrc': request.isrc,
      },
      'candidates':
          candidates.map(
            (candidate) => candidate.toJson(),
          ).toList(),
      'searchedAt':
          searchedAt.toUtc().toIso8601String(),
      'fromCache': fromCache,
      'error': error,
    };
  }
}

/// Interface implemented by actual metadata providers.
///
/// The ARM layer should depend on this interface rather than directly on
/// TMDB, MusicBrainz, IMDb, or another provider.
abstract class MetadataProviderClient {
  MetadataProvider get provider;

  Future<MetadataSearchResult> search(
    MetadataSearchRequest request,
  );
}

/// Provider-neutral metadata service.
///
/// Multiple providers can be registered and searched without coupling the ARM
/// import workflow to a particular vendor.
class MetadataService {
  final List<MetadataProviderClient> providers;

  const MetadataService({
    this.providers = const [],
  });

  /// Searches all registered providers.
  ///
  /// Provider failures do not prevent other providers from returning results.
  Future<List<MetadataSearchResult>> search(
    MetadataSearchRequest request,
  ) async {
    if (!request.hasUsefulQuery) {
      return const [];
    }

    final results = <MetadataSearchResult>[];

    for (final provider in providers) {
      try {
        results.add(
          await provider.search(request),
        );
      } catch (error) {
        results.add(
          MetadataSearchResult(
            provider: provider.provider,
            request: request,
            candidates: const [],
            searchedAt: DateTime.now().toUtc(),
            error: error.toString(),
          ),
        );
      }
    }

    return results;
  }

  /// Combines candidates from multiple provider responses.
  ///
  /// Candidates are not automatically declared to be the same identity.
  /// They remain attributed to their source provider.
  List<MetadataCandidate> combineCandidates(
    Iterable<MetadataSearchResult> results,
  ) {
    final candidates = <MetadataCandidate>[];

    for (final result in results) {
      candidates.addAll(
        result.candidates.where(
          (candidate) => candidate.isValid,
        ),
      );
    }

    candidates.sort(
      (a, b) => b.confidence.compareTo(
        a.confidence,
      ),
    );

    return candidates;
  }

  /// Builds a provider-neutral search request from an ARM title.
  MetadataSearchRequest requestForDiscTitle(
    ArmDiscTitle title, {
    String? barcode,
  }) {
    return MetadataSearchRequest(
      title: title.canonicalTitle ??
          title.title,
      originalTitle: title.originalTitle,
      discTitle: title.discTitle,
      year: title.year,
      mediaType: title.mediaType,
      artist: title.artist,
      album: title.album,
      barcode: barcode ??
          title.metadata['barcode']?.toString(),
      isrc: title.metadata['isrc']?.toString(),
      externalIds: _externalIdsFromMetadata(
        title.metadata,
      ),
      hints: {
        'classification': title.classification,
        'discMarketCountry':
            title.discMarketCountry,
        'detectedRegion':
            title.detectedRegion,
        'discNumber': title.discNumber,
        'trackNumber': title.trackNumber,
      },
    );
  }

  /// Builds a music-recording search request from an ARM recording candidate.
  MetadataSearchRequest requestForRecording(
    ArmMusicRecording recording,
  ) {
    final artist = recording.artists.isEmpty
        ? null
        : recording.artists.first;

    return MetadataSearchRequest(
      title: recording.title,
      trackTitle: recording.title,
      artist: artist,
      isrc: recording.isrc,
      externalIds: _externalIdsFromMetadata(
        recording.metadata,
      ),
      hints: {
        'durationSeconds':
            recording.durationSeconds,
        'audioFingerprint':
            recording.audioFingerprint,
      },
    );
  }

  List<MetadataExternalId>
      _externalIdsFromMetadata(
    Map<String, dynamic> metadata,
  ) {
    final result =
        <MetadataExternalId>[];

    const namespaces = [
      'tmdb',
      'imdb',
      'musicbrainz',
      'musicbrainzRelease',
      'musicbrainzRecording',
      'isrc',
      'upc',
      'ean',
      'gtin',
    ];

    for (final namespace in namespaces) {
      final value = metadata[namespace]
          ?.toString()
          .trim();

      if (value == null ||
          value.isEmpty) {
        continue;
      }

      result.add(
        MetadataExternalId(
          namespace: namespace,
          value: value,
        ),
      );
    }

    return result;
  }
}
```
