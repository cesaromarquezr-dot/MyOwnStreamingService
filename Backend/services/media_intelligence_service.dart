// FILE: `Backend/services/media_intelligence_service.dart`.
// Purpose: Central in-memory foundation for the media graph, sessions,
// artwork, discovery, library health, and explainable intelligence APIs.

import '../models/media_artwork.dart';
import '../models/media_relationship.dart';
import '../models/media_session.dart';
import '../models/media_work.dart';

class MediaIntelligenceService {
  final Map<String, MediaWork> works = <String, MediaWork>{};
  final List<MediaRelationship> relationships = <MediaRelationship>[];
  final Map<String, MediaDevice> devices = <String, MediaDevice>{};
  final Map<String, PlaybackSession> sessions = <String, PlaybackSession>{};
  final Map<String, MediaArtwork> artwork = <String, MediaArtwork>{};
  final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];

  /// Returns a compact capability manifest for the new platform foundation.
  Map<String, dynamic> capabilities() => {
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
      };

  /// Adds a work to the global catalog and records a media-created event.
  void upsertWork(MediaWork work) {
    works[work.id] = work;
    recordEvent('MediaWorkUpserted', {'mediaId': work.id, 'type': work.type});
  }

  /// Adds a graph edge while avoiding duplicate edges.
  void addRelationship(MediaRelationship relationship) {
    final exists = relationships.any((item) =>
        item.fromId == relationship.fromId &&
        item.relationshipType == relationship.relationshipType &&
        item.toId == relationship.toId);
    if (!exists) {
      relationships.add(relationship);
      recordEvent('MediaRelationshipAdded', relationship.toJson());
    }
  }

  /// Returns graph edges attached to a work/person/franchise node.
  List<MediaRelationship> connections(String id) => relationships
      .where((item) => item.fromId == id || item.toId == id)
      .toList(growable: false);

  /// Registers a device/session independently of other sessions for the same profile.
  void upsertDevice(MediaDevice device) {
    devices[device.id] = device;
    recordEvent('DeviceSeen', device.toJson());
  }

  /// Starts or updates a playback session without hijacking another device.
  void upsertSession(PlaybackSession session) {
    sessions[session.id] = session;
    recordEvent('PlaybackSessionUpdated', session.toJson());
  }

  /// Stores artwork while preserving its original source information.
  void addArtwork(MediaArtwork item) {
    artwork[item.id] = item;
    recordEvent('ArtworkAdded', item.toJson());
  }

  /// Returns artwork suitable for profile selection, including disc-derived art.
  List<MediaArtwork> profileArtwork() => artwork.values
      .where((item) => item.profileEligible)
      .toList(growable: false);

  /// Creates a small, deterministic library-health report for the UI.
  Map<String, dynamic> libraryHealth() {
    final missingArtwork = works.values.where((work) =>
        work.type != 'extra' &&
        artwork.values.every((art) => art.mediaId != work.id)).length;
    final relationshipless = works.values
        .where((work) => connections(work.id).isEmpty)
        .length;
    return {
      'works': works.length,
      'relationships': relationships.length,
      'devices': devices.length,
      'activeSessions': sessions.values.where((s) => s.state != 'idle').length,
      'artwork': artwork.length,
      'missingArtwork': missingArtwork,
      'relationshiplessWorks': relationshipless,
      'pendingReview': events.where((e) => e['type'] == 'PendingReview').length,
    };
  }

  /// Records an event consumed later by recaps, achievements, analytics and notifications.
  void recordEvent(String type, Map<String, dynamic> data) {
    events.add({
      'id': 'evt_${DateTime.now().microsecondsSinceEpoch}',
      'type': type,
      'at': DateTime.now().toIso8601String(),
      'data': data,
    });
    if (events.length > 5000) {
      events.removeRange(0, events.length - 5000);
    }
  }

  /// Builds a true cross-media Surprise Me candidate list.
  List<MediaWork> surpriseMe({String? type}) {
    final values = works.values
        .where((work) => type == null || work.type == type)
        .toList();
    values.shuffle();
    return values;
  }

  /// Provides explainable similarity factors rather than a ranking of people.
  Map<String, dynamic> explainSimilarity(MediaWork a, MediaWork b) {
    final sharedGenres = a.genres.where(b.genres.contains).toList();
    final sharedThemes = a.themes.where(b.themes.contains).toList();
    final sharedTags = a.tags.where(b.tags.contains).toList();
    final sameEra = a.releaseYear != null && b.releaseYear != null &&
        (a.releaseYear! ~/ 10) == (b.releaseYear! ~/ 10);
    final factors = <String, dynamic>{
      'sharedGenres': sharedGenres,
      'sharedThemes': sharedThemes,
      'sharedTags': sharedTags,
      'sameEra': sameEra,
    };
    final matches = sharedGenres.length + sharedThemes.length + sharedTags.length + (sameEra ? 1 : 0);
    return {'matchFactors': factors, 'factorCount': matches};
  }
}
