// FILE: Backend/services/media_intelligence_service.dart.
//
// Purpose:
// Central in-memory foundation for the media graph, sessions, artwork,
// discovery, library health, and explainable intelligence APIs.
//
// This service is intentionally in-memory. Durable persistence belongs to
// the database/store layer. The service does not treat its in-memory maps as
// the permanent source of truth.

import 'dart:math';

import '../models/media_artwork.dart';
import '../models/media_relationship.dart';
import '../models/media_session.dart';
import '../models/media_work.dart';

class MediaIntelligenceService {
  static const String serviceVersion = '1';

  /// Maximum number of recent events retained in memory.
  static const int maxEvents = 5000;

  final Map<String, MediaWork> works = <String, MediaWork>{};
  final List<MediaRelationship> relationships = <MediaRelationship>[];
  final Map<String, MediaDevice> devices = <String, MediaDevice>{};
  final Map<String, PlaybackSession> sessions = <String, PlaybackSession>{};
  final Map<String, MediaArtwork> artwork = <String, MediaArtwork>{};
  final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];

  final Random _random = Random.secure();

  /// Returns a compact capability manifest for the platform foundation.
  Map<String, dynamic> capabilities() => {
        'serviceVersion': serviceVersion,

        'mediaGraph': true,
        'multiSession': true,
        'profileArtworkFromDisc': true,
        'musicVideos': true,
        'lyrics': true,
        'geographicAssociations': true,
        'extras': true,
        'trailers': true,
        'physicalMedia': true,
        'surpriseMe': true,
        'libraryHealth': true,
        'explainableRecommendations': true,
        'eventSystem': true,
        'privacyFirstRecaps': true,
        'futureMediaTypes': true,

        // ARM / physical-media capabilities.
        'armAutomaticDiscIngestion': true,
        'armMultiTitleDiscImport': true,
        'armMetadataArtworkCastImport': true,
        'armLosslessFlacArchive': true,
        'armRepairRecovery': true,

        // Playback/transcoding capabilities.
        'concurrentTranscoding': true,

        // Discovery/recommendation capabilities.
        'internationalAdaptationRecommendations': true,
        'crossFormatRecommendations': true,

        // Access / commerce / social capabilities.
        'profileLevelMediaAccess': true,
        'eligibleMerchandiseOnly': true,
        'shopGraphRelationships': true,
        'groupWatchCompatibility': true,

        // Identity / architecture guarantees.
        'universalStableIds': true,
        'singleSourceOfTruth': true,

        // Operational characteristics.
        'durablePersistence': false,
        'inMemoryEventRetention': maxEvents,
      };

  /// Adds or replaces a work in the global in-memory catalog.
  ///
  /// The caller remains responsible for durable persistence.
  void upsertWork(MediaWork work) {
    _requireId(work.id, 'MediaWork');

    works[work.id] = work;

    recordEvent(
      'MediaWorkUpserted',
      <String, dynamic>{
        'mediaId': work.id,
        'type': work.type,
      },
    );
  }

  /// Adds a graph edge while avoiding duplicate edges.
  ///
  /// Duplicate detection is based on the complete directed edge:
  /// fromId + relationshipType + toId.
  void addRelationship(MediaRelationship relationship) {
    _requireId(relationship.fromId, 'Relationship source');
    _requireId(relationship.toId, 'Relationship target');

    final exists = relationships.any(
      (item) =>
          item.fromId == relationship.fromId &&
          item.relationshipType == relationship.relationshipType &&
          item.toId == relationship.toId,
    );

    if (exists) {
      return;
    }

    relationships.add(relationship);

    recordEvent(
      'MediaRelationshipAdded',
      relationship.toJson(),
    );
  }

  /// Returns graph edges attached to a work/person/franchise node.
  ///
  /// The returned list is detached from the internal collection so callers
  /// cannot mutate the service's relationship list accidentally.
  List<MediaRelationship> connections(String id) {
    final normalizedId = id.trim();

    if (normalizedId.isEmpty) {
      return const <MediaRelationship>[];
    }

    return relationships
        .where(
          (item) =>
              item.fromId == normalizedId || item.toId == normalizedId,
        )
        .toList(growable: false);
  }

  /// Registers or updates a device.
  ///
  /// A device is keyed by its stable device ID and does not implicitly
  /// terminate or replace playback sessions belonging to other devices.
  void upsertDevice(MediaDevice device) {
    _requireId(device.id, 'MediaDevice');

    devices[device.id] = device;

    recordEvent(
      'DeviceSeen',
      device.toJson(),
    );
  }

  /// Starts or updates a playback session without hijacking another device.
  void upsertSession(PlaybackSession session) {
    _requireId(session.id, 'PlaybackSession');

    sessions[session.id] = session;

    recordEvent(
      'PlaybackSessionUpdated',
      session.toJson(),
    );
  }

  /// Stores artwork while preserving its original source information.
  ///
  /// Artwork identity is keyed by artwork ID. Re-ingesting the same artwork
  /// replaces the current in-memory representation rather than creating
  /// duplicate entries.
  void addArtwork(MediaArtwork item) {
    _requireId(item.id, 'MediaArtwork');

    artwork[item.id] = item;

    recordEvent(
      'ArtworkAdded',
      item.toJson(),
    );
  }

  /// Returns artwork suitable for profile selection, including disc-derived
  /// artwork when the artwork model marks it as profile eligible.
  List<MediaArtwork> profileArtwork() {
    return artwork.values
        .where((item) => item.profileEligible)
        .toList(growable: false);
  }

  /// Creates a compact library-health report for the UI and diagnostics.
  ///
  /// This is an observational report. It does not repair or modify the
  /// catalog.
  Map<String, dynamic> libraryHealth() {
    final missingArtwork = works.values.where(
      (work) {
        // Extras may legitimately have no profile artwork.
        if (work.type == 'extra') {
          return false;
        }

        return artwork.values.every(
          (art) => art.mediaId != work.id,
        );
      },
    ).length;

    final relationshipless = works.values.where(
      (work) => connections(work.id).isEmpty,
    ).length;

    final activeSessions = sessions.values.where(
      (session) => session.state != 'idle',
    ).length;

    final pendingReview = events.where(
      (event) => event['type'] == 'PendingReview',
    ).length;

    return {
      'serviceVersion': serviceVersion,
      'works': works.length,
      'relationships': relationships.length,
      'devices': devices.length,
      'activeSessions': activeSessions,
      'artwork': artwork.length,
      'missingArtwork': missingArtwork,
      'relationshiplessWorks': relationshipless,
      'pendingReview': pendingReview,
      'eventCount': events.length,
      'eventRetentionLimit': maxEvents,
    };
  }

  /// Records an event consumed later by recaps, achievements, analytics,
  /// notifications, and other in-memory consumers.
  ///
  /// Events are bounded to prevent an active home server from growing memory
  /// without limit. Durable analytics/events should be persisted separately.
  void recordEvent(
    String type,
    Map<String, dynamic> data,
  ) {
    final normalizedType = type.trim();

    if (normalizedType.isEmpty) {
      throw ArgumentError.value(
        type,
        'type',
        'Event type must not be empty.',
      );
    }

    final now = DateTime.now().toUtc();

    events.add(
      <String, dynamic>{
        'id': _eventId(now),
        'type': normalizedType,
        'at': now.toIso8601String(),
        'data': Map<String, dynamic>.from(data),
      },
    );

    if (events.length > maxEvents) {
      final removeCount = events.length - maxEvents;
      events.removeRange(0, removeCount);
    }
  }

  /// Builds a randomized cross-media Surprise Me candidate list.
  ///
  /// The optional [type] filter is exact and case-sensitive to preserve the
  /// existing catalog type contract.
  List<MediaWork> surpriseMe({String? type}) {
    final normalizedType = type?.trim();

    final values = works.values
        .where(
          (work) =>
              normalizedType == null ||
              normalizedType.isEmpty ||
              work.type == normalizedType,
        )
        .toList();

    values.shuffle(_random);

    return values;
  }

  /// Provides explainable similarity factors rather than a ranking of
  /// people or profiles.
  ///
  /// The result deliberately exposes the underlying matching factors instead
  /// of reducing them to an opaque recommendation score.
  Map<String, dynamic> explainSimilarity(
    MediaWork a,
    MediaWork b,
  ) {
    final sharedGenres = _sharedValues(a.genres, b.genres);
    final sharedThemes = _sharedValues(a.themes, b.themes);
    final sharedTags = _sharedValues(a.tags, b.tags);

    final sameEra = a.releaseYear != null &&
        b.releaseYear != null &&
        (a.releaseYear! ~/ 10) == (b.releaseYear! ~/ 10);

    final factors = <String, dynamic>{
      'sharedGenres': sharedGenres,
      'sharedThemes': sharedThemes,
      'sharedTags': sharedTags,
      'sameEra': sameEra,
    };

    final factorCount = sharedGenres.length +
        sharedThemes.length +
        sharedTags.length +
        (sameEra ? 1 : 0);

    return {
      'matchFactors': factors,
      'factorCount': factorCount,
    };
  }

  List<String> _sharedValues(
    Iterable<String> first,
    Iterable<String> second,
  ) {
    final secondValues = second.toSet();

    return first
        .where(secondValues.contains)
        .toSet()
        .toList(growable: false);
  }

  String _eventId(DateTime now) {
    final timestamp = now.microsecondsSinceEpoch;
    final randomPart = _random.nextInt(1 << 32).toRadixString(16);

    return 'evt_${timestamp}_$randomPart';
  }

  void _requireId(String id, String entityName) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(
        id,
        'id',
        '$entityName ID must not be empty.',
      );
    }
  }
}