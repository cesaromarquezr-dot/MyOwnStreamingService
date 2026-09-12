// FILE: `lib/app_core.dart`.
// Purpose: Implements the app core portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api.dart';

enum SubscriptionPlan {
  monthly,
  yearly,
}

enum SubscriptionStatus {
  active,
  expired,
}

class Subscription {
  final SubscriptionPlan plan;
  SubscriptionStatus status;

  Subscription({
    required this.plan,
    this.status = SubscriptionStatus.active,
  });

  double get price {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return 10.0;
      case SubscriptionPlan.yearly:
        return 100.0;
    }
  }

  String get displayName {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return '\$10/month';
      case SubscriptionPlan.yearly:
        return '\$100/year';
    }
  }
}

class MediaItem {
  final String id;
  final String title;
  final String type;
  final String? imageUrl;
  final String? description;
  final int? releaseYear;
  /// Official/provider/critic rating (IMDb, Rotten Tomatoes, etc.).
  final double? rating;
  final String? ratingReason;
  /// Optional explicit audience/community rating maintained separately from the official rating.
  final double? audienceRating;
  final int audienceReviewCount;
  final String? trailerUrl;
  final DateTime addedAt;
  final List<Map<String, dynamic>> seasons;

  // Disc/archive metadata populated by the ARM import workflow.
  final String? discType;
  final String? discRegion;
  final String? discCollectionId;
  final String? discCollectionTitle;
  final int? discNumber;
  final String? discTitleId;
  final String? discTitle;
  final String? discMarketCountry;
  final String? originalTitle;
  final String? originalLanguage;
  final String? countryOfOrigin;
  final String? canonicalTitle;

  // Franchise/collection metadata. A franchise is different from a physical disc collection.
  final String? franchiseId;
  final String? franchiseName;
  final String? franchiseType;
  final int? franchiseOrder;

  // Catalog entities and technical metadata discovered during import.
  final List<String> actors;
  final List<String> directors;
  final List<String> writers;
  final List<String> music;
  final List<String> genres;
  final List<String> tags;
  final List<String> chapters;
  final List<String> audioTracks;
  final List<String> subtitles;
  final List<String> extras;

  MediaItem({
    this.trailerUrl,
    DateTime? addedAt,
    List<Map<String, dynamic>>? seasons,
    this.discType,
    this.discRegion,
    this.discCollectionId,
    this.discCollectionTitle,
    this.discNumber,
    this.discTitleId,
    this.discTitle,
    this.discMarketCountry,
    this.originalTitle,
    this.originalLanguage,
    this.countryOfOrigin,
    this.canonicalTitle,
    this.franchiseId,
    this.franchiseName,
    this.franchiseType,
    this.franchiseOrder,
    List<String>? actors,
    List<String>? directors,
    List<String>? writers,
    List<String>? music,
    List<String>? genres,
    List<String>? tags,
    List<String>? chapters,
    List<String>? audioTracks,
    List<String>? subtitles,
    List<String>? extras,
    required this.id,
    required this.title,
    required this.type,
    this.imageUrl,
    this.description,
    this.releaseYear,
    this.rating,
    this.ratingReason,
    this.audienceRating,
    this.audienceReviewCount = 0,
  }) : addedAt = addedAt ?? DateTime.now(),
       seasons = seasons ?? <Map<String, dynamic>>[],
       actors = actors ?? <String>[],
       directors = directors ?? <String>[],
       writers = writers ?? <String>[],
       music = music ?? <String>[],
       genres = genres ?? <String>[],
       tags = tags ?? <String>[],
       chapters = chapters ?? <String>[],
       audioTracks = audioTracks ?? <String>[],
       subtitles = subtitles ?? <String>[],
       extras = extras ?? <String>[];

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'movie',
      imageUrl: json['imageUrl']?.toString(),
      description: json['description']?.toString(),
      releaseYear: json['releaseYear'] is int
          ? json['releaseYear'] as int
          : int.tryParse(
              json['releaseYear']?.toString() ?? '',
            ),
      rating: json['rating'] is num
          ? (json['rating'] as num).toDouble()
          : double.tryParse(
              json['rating']?.toString() ?? '',
            ),
      ratingReason: json['ratingReason']?.toString(),
      audienceRating: json['audienceRating'] is num ? (json['audienceRating'] as num).toDouble() : double.tryParse(json['audienceRating']?.toString() ?? ''),
      audienceReviewCount: json['audienceReviewCount'] is num ? (json['audienceReviewCount'] as num).toInt() : int.tryParse(json['audienceReviewCount']?.toString() ?? '') ?? 0,
      trailerUrl: json['trailerUrl']?.toString(),
      addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? ''),
      discType: json['discType']?.toString(),
      discRegion: json['discRegion']?.toString(),
      discCollectionId: json['discCollectionId']?.toString(),
      discCollectionTitle: json['discCollectionTitle']?.toString(),
      discNumber: json['discNumber'] is num ? (json['discNumber'] as num).toInt() : int.tryParse(json['discNumber']?.toString() ?? ''),
      discTitleId: json['discTitleId']?.toString(),
      discTitle: json['discTitle']?.toString(),
      discMarketCountry: json['discMarketCountry']?.toString(),
      originalTitle: json['originalTitle']?.toString(),
      originalLanguage: json['originalLanguage']?.toString(),
      countryOfOrigin: json['countryOfOrigin']?.toString(),
      canonicalTitle: json['canonicalTitle']?.toString(),
      franchiseId: json['franchiseId']?.toString(),
      franchiseName: json['franchiseName']?.toString(),
      franchiseType: json['franchiseType']?.toString(),
      franchiseOrder: json['franchiseOrder'] is num ? (json['franchiseOrder'] as num).toInt() : int.tryParse(json['franchiseOrder']?.toString() ?? ''),
      actors: _stringList(json['actors']),
      directors: _stringList(json['directors']),
      writers: _stringList(json['writers']),
      music: _stringList(json['music']),
      genres: _stringList(json['genres']),
      tags: _stringList(json['tags']),
      chapters: _stringList(json['chapters']),
      audioTracks: _stringList(json['audioTracks']),
      subtitles: _stringList(json['subtitles']),
      extras: _stringList(json['extras']),
      seasons: (json['seasons'] is List)
          ? (json['seasons'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[],
    );
  }


  static List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'imageUrl': imageUrl,
      'description': description,
      'releaseYear': releaseYear,
      'rating': rating,
      'ratingReason': ratingReason,
      'audienceRating': audienceRating,
      'audienceReviewCount': audienceReviewCount,
      'trailerUrl': trailerUrl,
      'addedAt': addedAt.toIso8601String(),
      'discType': discType,
      'discRegion': discRegion,
      'discCollectionId': discCollectionId,
      'discCollectionTitle': discCollectionTitle,
      'discNumber': discNumber,
      'discTitleId': discTitleId, 'discTitle': discTitle, 'discMarketCountry': discMarketCountry, 'originalTitle': originalTitle, 'originalLanguage': originalLanguage, 'countryOfOrigin': countryOfOrigin, 'canonicalTitle': canonicalTitle,
      'franchiseId': franchiseId,
      'franchiseName': franchiseName,
      'franchiseType': franchiseType,
      'franchiseOrder': franchiseOrder,
      'actors': actors,
      'directors': directors,
      'writers': writers,
      'music': music,
      'genres': genres,
      'tags': tags,
      'chapters': chapters,
      'audioTracks': audioTracks,
      'subtitles': subtitles,
      'extras': extras,
      'seasons': seasons,
    };
  }
}



/// Builds the conversational, streaming-service-style synopses used when a
/// description is not supplied manually. Story notes can be entered during
/// import when a more title-specific synopsis is desired.
class DescriptionGenerator {
  static String movie({
    required String title,
    int? year,
    String? storyNotes,
  }) {
    final notes = storyNotes?.trim();
    if (notes != null && notes.isNotEmpty) {
      return '$title${year == null ? '' : ' ($year)'}: $notes';
    }
    return '$title${year == null ? '' : ' ($year)'}: Step into this movie and follow the characters as an unexpected challenge changes everything. With memorable moments, rising stakes, and a story that keeps moving forward, it is ready for another watch in your personal streaming library.';
  }

  static String show({
    required String title,
    int? year,
    String? storyNotes,
  }) {
    final notes = storyNotes?.trim();
    if (notes != null && notes.isNotEmpty) {
      return '$title${year == null ? '' : ' ($year)'}: $notes';
    }
    return '$title${year == null ? '' : ' ($year)'}: Meet the characters at the center of this series as their lives, friendships, challenges, and adventures unfold across the seasons. Settle in and follow the story episode by episode.';
  }

  static String season({
    required String showTitle,
    required int seasonNumber,
    String? seasonName,
    String? storyNotes,
  }) {
    final notes = storyNotes?.trim();
    final label = seasonName?.trim().isNotEmpty == true
        ? seasonName!.trim()
        : 'Season $seasonNumber';
    if (notes != null && notes.isNotEmpty) {
      return '$showTitle $label: $notes';
    }
    return '$showTitle $label: The story continues with new situations, character moments, and episodes that build the season from beginning to end.';
  }

  static String episode({
    required String showTitle,
    required int seasonNumber,
    required int episodeNumber,
    required String episodeTitle,
    String? alternateTitle,
    String? storyNotes,
  }) {
    final notes = storyNotes?.trim();
    final alt = alternateTitle?.trim();
    final displayTitle = alt != null && alt.isNotEmpty
        ? '$episodeTitle — "$alt"'
        : '"$episodeTitle"';
    if (notes != null && notes.isNotEmpty) {
      return '$showTitle Season $seasonNumber Episode $episodeNumber $displayTitle: $notes';
    }
    return '$showTitle Season $seasonNumber Episode $episodeNumber $displayTitle: Join the characters for another chapter as their plans, relationships, and problems take an unexpected turn.';
  }
}

class Profile {
  final String id;
  String name;
  String? avatarUrl;

  Profile({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Profile',
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
    };
  }
}

class UserAccount {
  final String username;
  final String email;
  Subscription subscription;
  final List<Profile> profiles;
  int storageLimitBytes;
  int storageUsedBytes;

  UserAccount({
    required this.username,
    required this.email,
    required this.subscription,
    List<Profile>? profiles,
    this.storageLimitBytes = 1000000000000,
    this.storageUsedBytes = 0,
  }) : profiles = profiles ?? [];

  bool get hasActiveSubscription =>
      subscription.status == SubscriptionStatus.active;

  Profile? get firstProfile =>
      profiles.isEmpty ? null : profiles.first;

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'subscription': {
        'plan': subscription.plan.name,
        'status': subscription.status.name,
      },
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'storageLimitBytes': storageLimitBytes,
      'storageUsedBytes': storageUsedBytes,
    };
  }
}


class MediaCollection {
  final String id;
  String name;
  String description;
  String? createdByProfileId;
  bool isShared;
  bool isOfficial;
  bool isAutomatic;
  bool isFeatured;
  String posterMode;
  String? customPosterUrl;
  String? automaticFranchiseId;
  String? automaticFranchiseType;
  String sortMode;
  bool autoPlayEnabled;
  bool autoPlayNextEnabled;
  String autoPlayVersionPreference;
  String autoPlayNextTiming;
  final List<String> mediaIds;
  final List<String> episodeKeys;
  final Set<String> likedByProfileIds;
  final Set<String> contributorProfileIds;
  DateTime createdAt;

  MediaCollection({
    required this.id,
    required this.name,
    this.description = '',
    this.createdByProfileId,
    this.isShared = true,
    this.isOfficial = false,
    this.isAutomatic = false,
    this.isFeatured = false,
    this.posterMode = 'First 4 Posters',
    this.customPosterUrl,
    this.automaticFranchiseId,
    this.automaticFranchiseType,
    this.sortMode = 'Collection order',
    this.autoPlayEnabled = true,
    this.autoPlayNextEnabled = true,
    this.autoPlayVersionPreference = 'Preferred version',
    this.autoPlayNextTiming = 'End credits',
    List<String>? mediaIds,
    List<String>? episodeKeys,
    Set<String>? likedByProfileIds,
    Set<String>? contributorProfileIds,
    DateTime? createdAt,
  })  : mediaIds = mediaIds ?? <String>[],
        episodeKeys = episodeKeys ?? <String>[],
        likedByProfileIds = likedByProfileIds ?? <String>{},
        contributorProfileIds = contributorProfileIds ?? <String>{},
        createdAt = createdAt ?? DateTime.now();

  bool get isLikedByCurrentProfile {
    final id = AppController.instance.currentProfile?.id;
    return id != null && likedByProfileIds.contains(id);
  }

  /// Performs `canCurrentProfileEdit` for this feature. Update this documentation when its contract changes.
  bool canCurrentProfileEdit() {
    final profileId = AppController.instance.currentProfile?.id;
    if (profileId == null) return false;
    return profileId == createdByProfileId || contributorProfileIds.contains(profileId);
  }

  /// Performs `canCurrentProfileAdd` for this feature. Update this documentation when its contract changes.
  bool canCurrentProfileAdd() {
    if (!isShared) return AppController.instance.currentProfile?.id == createdByProfileId;
    return canCurrentProfileEdit();
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description,
    'createdByProfileId': createdByProfileId, 'isShared': isShared,
    'isOfficial': isOfficial, 'isAutomatic': isAutomatic, 'isFeatured': isFeatured,
    'posterMode': posterMode, 'customPosterUrl': customPosterUrl,
    'automaticFranchiseId': automaticFranchiseId,
    'automaticFranchiseType': automaticFranchiseType,
    'sortMode': sortMode, 'autoPlayEnabled': autoPlayEnabled,
    'autoPlayNextEnabled': autoPlayNextEnabled,
    'autoPlayVersionPreference': autoPlayVersionPreference,
    'autoPlayNextTiming': autoPlayNextTiming,
    'mediaIds': mediaIds, 'episodeKeys': episodeKeys, 'likedByProfileIds': likedByProfileIds.toList(),
    'contributorProfileIds': contributorProfileIds.toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory MediaCollection.fromJson(Map<String, dynamic> json) => MediaCollection(
    id: json['id']?.toString() ?? '', name: json['name']?.toString() ?? 'Collection',
    description: json['description']?.toString() ?? '', createdByProfileId: json['createdByProfileId']?.toString(),
    isShared: json['isShared'] != false, isOfficial: json['isOfficial'] == true,
    isAutomatic: json['isAutomatic'] == true, isFeatured: json['isFeatured'] == true,
    posterMode: json['posterMode']?.toString() ?? 'First 4 Posters', customPosterUrl: json['customPosterUrl']?.toString(),
    automaticFranchiseId: json['automaticFranchiseId']?.toString(), automaticFranchiseType: json['automaticFranchiseType']?.toString(),
    sortMode: json['sortMode']?.toString() ?? 'Collection order', autoPlayEnabled: json['autoPlayEnabled'] != false,
    autoPlayNextEnabled: json['autoPlayNextEnabled'] != false,
    autoPlayVersionPreference: json['autoPlayVersionPreference']?.toString() ?? 'Preferred version',
    autoPlayNextTiming: json['autoPlayNextTiming']?.toString() ?? 'End credits',
    mediaIds: (json['mediaIds'] as List?)?.map((e) => e.toString()).toList(),
    episodeKeys: (json['episodeKeys'] as List?)?.map((e) => e.toString()).toList(),
    likedByProfileIds: (json['likedByProfileIds'] as List?)?.map((e) => e.toString()).toSet(),
    contributorProfileIds: (json['contributorProfileIds'] as List?)?.map((e) => e.toString()).toSet(),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
  );
}

class CollectionPreferences {
  String collectionOrder;
  String layout;
  String automaticPosition;
  String customPosition;
  String itemLayout;
  String itemSort;

  CollectionPreferences({
    this.collectionOrder = 'Automatic first',
    this.layout = 'Grid',
    this.automaticPosition = 'Top',
    this.customPosition = 'Bottom',
    this.itemLayout = 'Grid',
    this.itemSort = 'Collection order',
  });

  CollectionPreferences copy() => CollectionPreferences(
    collectionOrder: collectionOrder, layout: layout, automaticPosition: automaticPosition,
    customPosition: customPosition, itemLayout: itemLayout, itemSort: itemSort,
  );
}

class ActivityItem {
  final String id;
  final String title;
  final String action;
  final DateTime timestamp;

  ActivityItem({
    required this.id,
    required this.title,
    required this.action,
    required this.timestamp,
  });
}

class BackendGroupChatMessage {
  final String id;
  final String profileId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final String? badgeName;

  BackendGroupChatMessage({required this.id, required this.profileId, required this.senderName, required this.message, required this.timestamp, this.badgeName});

  factory BackendGroupChatMessage.fromJson(Map<String, dynamic> json) => BackendGroupChatMessage(
    id: json['id']?.toString() ?? '', profileId: json['profileId']?.toString() ?? '', senderName: json['senderName']?.toString() ?? 'Profile', message: json['message']?.toString() ?? '', timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    badgeName: json['badgeName']?.toString(),
  );
}

class BackendGroupChatRoom {
  final String id;
  final String name;
  final List<Map<String, dynamic>> members;
  final List<BackendGroupChatMessage> messages;
  BackendGroupChatRoom({required this.id, required this.name, required this.members, required this.messages});

  factory BackendGroupChatRoom.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final rawMessages = json['messages'];
    return BackendGroupChatRoom(
      id: json['id']?.toString() ?? '', name: json['name']?.toString() ?? 'Group Room',
      members: rawMembers is List ? rawMembers.whereType<Map>().map((m) => Map<String,dynamic>.from(m)).toList() : <Map<String,dynamic>>[],
      messages: rawMessages is List ? rawMessages.whereType<Map>().map((m) => BackendGroupChatMessage.fromJson(Map<String,dynamic>.from(m))).toList() : <BackendGroupChatMessage>[],
    );
  }
}

class ChatMessage {
  final String id;
  final String sender;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.message,
    required this.timestamp,
  });
}

class WishlistItem {
  final String id;
  final String title;
  final String type;

  WishlistItem({
    required this.id,
    required this.title,
    required this.type,
  });
}

/// Frontend representation of one participant in a Group Watch session.
///
/// Audio and subtitle selections are stored independently for every
/// participant. Playback position and play/pause state are shared by the
/// entire Group Watch session.
class GroupWatchParticipant {
  final String profileId;
  String profileName;
  String invitationStatus;
  String? audioTrackId;
  String? subtitleTrackId;
  DateTime? joinedAt;

  GroupWatchParticipant({
    required this.profileId,
    required this.profileName,
    this.invitationStatus = 'pending',
    this.audioTrackId,
    this.subtitleTrackId,
    this.joinedAt,
  });

  bool get isAccepted =>
      invitationStatus.toLowerCase() == 'accepted';

  bool get isPending =>
      invitationStatus.toLowerCase() == 'pending';

  bool get isDeclined =>
      invitationStatus.toLowerCase() == 'declined';

  bool get isExpired =>
      invitationStatus.toLowerCase() == 'expired';

  factory GroupWatchParticipant.fromJson(
    Map<String, dynamic> json, {
    String? fallbackProfileName,
  }) {
    final profileId =
        json['profileId']?.toString() ?? '';

    return GroupWatchParticipant(
      profileId: profileId,
      profileName:
          json['profileName']?.toString() ??
          fallbackProfileName ??
          'Profile',
      invitationStatus:
          json['invitationStatus']?.toString() ??
          'pending',
      audioTrackId:
          json['audioTrackId']?.toString(),
      subtitleTrackId:
          json['subtitleTrackId']?.toString(),
      joinedAt: _dateTimeFromJson(
        json['joinedAt'],
      ),
    );
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return {
      'profileId': profileId,
      'profileName': profileName,
      'invitationStatus': invitationStatus,
      'audioTrackId': audioTrackId,
      'subtitleTrackId': subtitleTrackId,
      'joinedAt': joinedAt?.toIso8601String(),
    };
  }
}

/// Backend-connected Group Watch session.
///
/// Playback state is global to the session while audio and subtitle
/// selections remain participant-specific.
class GroupWatchSession {
  final String id;
  final String title;
  final String mediaId;
  final String type;
  final String hostProfileId;

  final List<String> participants;

  final Map<String, GroupWatchParticipant>
      participantStates;

  String status;
  DateTime createdAt;
  DateTime? invitationExpiresAt;
  DateTime? startedAt;
  DateTime? endedAt;

  Duration playbackPosition;
  bool isPlaying;

  String? pausedByProfileId;
  String? pauseReason;

  /// Compatibility property retained for older UI code.
  ///
  /// Actual synchronization is controlled by the backend.
  bool synchronized;

  GroupWatchSession({
    required this.id,
    required this.title,
    this.mediaId = '',
    this.type = 'movie',
    this.hostProfileId = '',
    required this.participants,
    Map<String, GroupWatchParticipant>?
        participantStates,
    this.status = 'waiting',
    DateTime? createdAt,
    this.invitationExpiresAt,
    this.startedAt,
    this.endedAt,
    this.playbackPosition = Duration.zero,
    this.isPlaying = false,
    this.pausedByProfileId,
    this.pauseReason,
    this.synchronized = true,
  }) : participantStates =
            participantStates ??
            <String, GroupWatchParticipant>{},
       createdAt =
            createdAt ?? DateTime.now();

  bool get isWaiting =>
      status.toLowerCase() == 'waiting';

  bool get isReady =>
      status.toLowerCase() == 'ready';

  bool get isPlayingStatus =>
      status.toLowerCase() == 'playing';

  bool get isPaused =>
      status.toLowerCase() == 'paused';

  bool get isEnded =>
      status.toLowerCase() == 'ended';

  bool get invitationsExpired {
    final currentStatus = status.toLowerCase();

    if (currentStatus != 'waiting' &&
        currentStatus != 'ready') {
      return true;
    }

    final expiry = invitationExpiresAt;

    if (expiry == null) {
      return false;
    }

    return DateTime.now().isAfter(expiry);
  }

  /// Performs `canResume` for this feature. Update this documentation when its contract changes.
  bool canResume(String profileId) {
    return pausedByProfileId == profileId;
  }

  GroupWatchParticipant? participantForProfile(
    String profileId,
  ) {
    return participantStates[profileId];
  }

  factory GroupWatchSession.fromJson(
    Map<String, dynamic> json, {
    List<Profile> knownProfiles =
        const <Profile>[],
  }) {
    final participantStates =
        <String, GroupWatchParticipant>{};

    final participantData =
        json['participants'];

    if (participantData is Map) {
      participantData.forEach(
        (key, value) {
          if (value is! Map) {
            return;
          }

          final participantMap =
              Map<String, dynamic>.from(
            value,
          );

          final profileId =
              participantMap['profileId']
                      ?.toString() ??
                  key.toString();

          if (profileId.isEmpty) {
            return;
          }

          final knownProfile =
              _profileFromList(
            knownProfiles,
            profileId,
          );

          participantStates[profileId] =
              GroupWatchParticipant.fromJson(
            participantMap,
            fallbackProfileName:
                knownProfile?.name,
          );
        },
      );
    } else if (participantData is List) {
      for (final item in participantData) {
        if (item is! Map) {
          continue;
        }

        final participantMap =
            Map<String, dynamic>.from(
          item,
        );

        final profileId =
            participantMap['profileId']
                    ?.toString() ??
                '';

        if (profileId.isEmpty) {
          continue;
        }

        final knownProfile =
            _profileFromList(
          knownProfiles,
          profileId,
        );

        participantStates[profileId] =
            GroupWatchParticipant.fromJson(
          participantMap,
          fallbackProfileName:
              knownProfile?.name,
        );
      }
    }

    final participantNames =
        <String>[];

    for (final participant
        in participantStates.values) {
      participantNames.add(
        participant.profileName,
      );
    }

    final positionSeconds =
        _doubleFromJson(
      json['playbackPosition'],
    );

    return GroupWatchSession(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      mediaId: json['mediaId']?.toString() ?? '',
      type:
          json['type']?.toString() ??
          'movie',
      hostProfileId:
          json['hostProfileId']?.toString() ??
          '',
      participants:
          participantNames,
      participantStates:
          participantStates,
      status:
          json['status']?.toString() ??
          'waiting',
      createdAt:
          _dateTimeFromJson(
            json['createdAt'],
          ) ??
          DateTime.now(),
      invitationExpiresAt:
          _dateTimeFromJson(
        json['invitationExpiresAt'],
      ),
      startedAt:
          _dateTimeFromJson(
        json['startedAt'],
      ),
      endedAt:
          _dateTimeFromJson(
        json['endedAt'],
      ),
      playbackPosition:
          Duration(
        milliseconds:
            (positionSeconds * 1000)
                .round(),
      ),
      isPlaying:
          json['isPlaying'] == true,
      pausedByProfileId:
          json['pausedByProfileId']
              ?.toString(),
      pauseReason:
          json['pauseReason']
              ?.toString(),
      synchronized: true,
    );
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'mediaId': mediaId,
      'type': type,
      'hostProfileId':
          hostProfileId,
      'participants':
          participantStates.map(
        (key, value) => MapEntry(
          key,
          value.toJson(),
        ),
      ),
      'status': status,
      'createdAt':
          createdAt.toIso8601String(),
      'invitationExpiresAt':
          invitationExpiresAt
              ?.toIso8601String(),
      'startedAt':
          startedAt?.toIso8601String(),
      'endedAt':
          endedAt?.toIso8601String(),
      'playbackPosition':
          playbackPosition.inMilliseconds /
              1000.0,
      'isPlaying': isPlaying,
      'pausedByProfileId':
          pausedByProfileId,
      'pauseReason': pauseReason,
    };
  }
}

class AppController extends ChangeNotifier {
  Map<String, dynamic>? lastLoginSecurity;

  AppController._();

  static final AppController instance =
      AppController._();

  final BackendApi backendApi = BackendApi();

  bool get isBackendAuthenticated =>
      backendApi.isAuthenticated;

  String? get backendToken =>
      backendApi.token;

  UserAccount? currentAccount;
  Profile? currentProfile;

  final List<MediaItem> library =
      <MediaItem>[];

  // Catalog sections populated when a confirmed ARM import is added.
  final List<String> actorsCatalog = <String>[];
  final List<String> directorsCatalog = <String>[];
  final List<String> writersCatalog = <String>[];
  final List<String> musicCatalog = <String>[];
  final List<String> genresCatalog = <String>[];
  final List<String> tagsCatalog = <String>[];

  final List<MediaCollection> collections = <MediaCollection>[];
  final List<String> collectionSectionOrder = <String>[
    'Featured Collections',
    'My Collections',
    'Liked Collections',
  ];
  final List<String> featuredCollectionOrder = <String>[];
  final Map<String, CollectionPreferences> collectionPreferencesByProfile = <String, CollectionPreferences>{};

  final List<MediaItem> watched =
      <MediaItem>[];

  final List<MediaItem> liked =
      <MediaItem>[];

  final List<MediaItem> disliked =
      <MediaItem>[];

  final List<ActivityItem> activity =
      <ActivityItem>[];

  final List<ChatMessage> groupMessages =
      <ChatMessage>[];

  // Monthly profile viewing activity used to award the profile's current badge.
  // Events are retained locally so the badge can change automatically when a
  // new calendar month begins.
  final Map<String, List<Map<String, dynamic>>> _monthlyWatchEvents =
      <String, List<Map<String, dynamic>>>{};
  SharedPreferences? _badgePrefs;
  bool _badgeDataLoaded = false;

  BackendGroupChatRoom? activeGroupChatRoom;
  bool groupChatLoading = false;
  String? groupChatError;

  final List<WishlistItem> wishlist =
      <WishlistItem>[];

  final List<GroupWatchSession>
      groupWatchSessions =
      <GroupWatchSession>[];

  final Map<String, double>
      playbackProgress =
      <String, double>{};

  final Map<String, String>
      nextEpisodes =
      <String, String>{};

  final Set<String>
      activeProfileIds =
      <String>{};

  List<MediaItem> recommendations =
      <MediaItem>[];

  bool recommendationsLoading = false;

  String? recommendationsError;

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>>
      groupRecommendations =
      <Map<String, dynamic>>[];

  bool groupRecommendationsLoading =
      false;

  String? groupRecommendationsError;

  // ---------------------------------------------------------------------------
  // GROUP WISHLIST
  // ---------------------------------------------------------------------------

  bool groupWishlistLoading = false;

  String? groupWishlistError;

  // ---------------------------------------------------------------------------
  // GROUP WATCH STATE
  // ---------------------------------------------------------------------------

  bool groupWatchLoading = false;

  String? groupWatchError;

  String? activeGroupWatchSessionId;

  GroupWatchSession?
      get activeGroupWatchSession {
    final id = activeGroupWatchSessionId;

    if (id == null || id.isEmpty) {
      return null;
    }

    return getGroupWatchSession(id);
  }

  // ---------------------------------------------------------------------------
  // MONTHLY BADGES
  // ---------------------------------------------------------------------------

  Future<void> initializeBadges() async {
    if (_badgeDataLoaded) return;
    _badgePrefs = await SharedPreferences.getInstance();
    for (final key in _badgePrefs!.getKeys()) {
      if (!key.startsWith('monthly_watch_events_')) continue;
      final profileId = key.substring('monthly_watch_events_'.length);
      final raw = _badgePrefs!.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _monthlyWatchEvents[profileId] = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {
        // Ignore malformed legacy badge data.
      }
    }
    _badgeDataLoaded = true;
  }

  String _monthKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  Future<void> _saveMonthlyWatchEvents(String profileId) async {
    final prefs = _badgePrefs;
    if (prefs == null) return;
    await prefs.setString(
      'monthly_watch_events_$profileId',
      jsonEncode(_monthlyWatchEvents[profileId] ?? <Map<String, dynamic>>[]),
    );
  }

  void _recordMonthlyWatch(MediaItem media) {
    final profileId = currentProfile?.id;
    if (profileId == null || profileId.isEmpty) return;
    final now = DateTime.now();
    final events = _monthlyWatchEvents.putIfAbsent(profileId, () => <Map<String, dynamic>>[]);
    final month = _monthKey(now);
    // Watching the same title more than once in a month counts once toward the
    // monthly title badge, while the watched list still controls overall state.
    if (events.any((e) => e['month'] == month && e['mediaId'] == media.id)) return;
    events.add({
      'month': month,
      'mediaId': media.id,
      'title': media.title,
      'type': media.type,
      'genres': media.genres,
      'timestamp': now.toIso8601String(),
    });
    // Keep a reasonable local history while preserving enough months to show
    // the current badge and future badge history.
    if (events.length > 5000) events.removeRange(0, events.length - 5000);
    _saveMonthlyWatchEvents(profileId);
  }

  String badgeForProfile(String profileId, {DateTime? now}) {
    final date = now ?? DateTime.now();
    final month = _monthKey(date);
    final events = (_monthlyWatchEvents[profileId] ?? <Map<String, dynamic>>[])
        .where((e) => e['month'] == month)
        .toList();
    if (events.isEmpty) return 'The Explorer';

    final movieCount = events.where((e) => (e['type']?.toString().toLowerCase() ?? '') == 'movie').length;
    final showCount = events.where((e) {
      final type = e['type']?.toString().toLowerCase() ?? '';
      return type == 'tvshow' || type == 'tv_show' || type == 'tv show' || type == 'series';
    }).length;
    final genres = <String>{};
    for (final event in events) {
      final rawGenres = event['genres'];
      if (rawGenres is List) {
        genres.addAll(rawGenres.map((g) => g.toString().trim().toLowerCase()).where((g) => g.isNotEmpty));
      }
    }

    if (events.length >= 20) return 'Binge Master';
    if (genres.length >= 6) return 'Genre Explorer';
    if (movieCount >= 10) return 'Movie Buff';
    if (showCount >= 8) return 'Series Fan';
    if (events.length >= 5) return 'Regular Viewer';
    return 'The Explorer';
  }

  String currentProfileBadge() {
    final id = currentProfile?.id;
    return id == null || id.isEmpty ? 'The Explorer' : badgeForProfile(id);
  }

  // ---------------------------------------------------------------------------
  // LOCAL ACCOUNT CREATION
  // ---------------------------------------------------------------------------

  UserAccount createAccount({
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String firstProfileName,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    // Internal username for compatibility. 
    //// The user does not enter or choose this username. 
    final username = cleanEmail.split('@').first;
    final account = UserAccount(
      username: username,
      email: email.trim(),
      subscription: Subscription(
        plan: plan,
        status: SubscriptionStatus.active,
      ),
      profiles: <Profile>[],
    );

    currentAccount = account;
    currentProfile = null;
    activeProfileIds.clear();
    collections.clear();
    seedCollections();

    groupWatchSessions.clear();
    activeGroupWatchSessionId = null;
    groupWatchError = null;
    groupWatchLoading = false;

    notifyListeners();

    return account;
  }

  // ---------------------------------------------------------------------------
  // BACKEND SIGNUP
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>>
      createAccountWithBackend({
    required String email,
    required String password,
    required SubscriptionPlan plan,
    required String firstProfileName,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    final planValue =
        plan == SubscriptionPlan.yearly
            ? 'yearly'
            : 'monthly';

    final response =
        await backendApi.signup(
      email: email.trim(),
      password: password,
      firstProfileName: firstProfileName.trim(),
      plan: planValue,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      termsVersion: '2026-09-10',
      privacyVersion: '2026-09-10',
      acceptableUseVersion: '2026-09-10',
    );

    final accountData =
        response['account'];

    final subscriptionData =
        response['subscription'];

    String accountUsername =
        email.trim();

    String accountEmail =
        email.trim();

    if (accountData is Map) {
      final backendUsername =
          accountData['username']
              ?.toString();

      final backendEmail =
          accountData['email']
              ?.toString();

      if (backendUsername != null &&
          backendUsername.isNotEmpty) {
        accountUsername =
            backendUsername;
      }

      if (backendEmail != null &&
          backendEmail.isNotEmpty) {
        accountEmail =
            backendEmail;
      }
    }

    SubscriptionStatus
        subscriptionStatus =
        SubscriptionStatus.expired;

    if (subscriptionData is Map) {
      final statusValue =
          subscriptionData['status']
              ?.toString()
              .toLowerCase();

      if (statusValue == 'active') {
        subscriptionStatus =
            SubscriptionStatus.active;
      }
    }

    final localSubscription =
        Subscription(
      plan: plan,
      status: subscriptionStatus,
    );

    final List<Profile> profiles =
        <Profile>[];

    if (accountData is Map) {
      final profilesData =
          accountData['profiles'];

      if (profilesData is List) {
        for (final item in profilesData) {
          if (item is Map) {
            profiles.add(
              Profile.fromJson(
                Map<String, dynamic>.from(
                  item,
                ),
              ),
            );
          }
        }
      }
    }

    // New backend accounts are allowed to have zero profiles.

    final account =
        UserAccount(
      username: accountUsername,
      email: accountEmail,
      subscription:
          localSubscription,
      profiles: profiles,
      storageLimitBytes: accountData is Map && accountData['storageLimitBytes'] is num ? (accountData['storageLimitBytes'] as num).toInt() : 1000000000000,
      storageUsedBytes: accountData is Map && accountData['storageUsedBytes'] is num ? (accountData['storageUsedBytes'] as num).toInt() : 0,
    );

    currentAccount = account;
    currentProfile = profiles.isEmpty ? null : profiles.first;

    activeProfileIds
      .clear();
    if (profiles.isNotEmpty) {
      activeProfileIds.add(profiles.first.id);
    }

    backendApi.clearToken();

    recommendations.clear();
    groupRecommendations.clear();
    wishlist.clear();
    groupWatchSessions.clear();

    activeGroupWatchSessionId = null;

    recommendationsError = null;
    recommendationsLoading = false;

    groupRecommendationsError =
        null;
    groupRecommendationsLoading =
        false;

    groupWishlistError = null;
    groupWishlistLoading = false;

    groupWatchError = null;
    groupWatchLoading = false;

    notifyListeners();

    return response;
  }

  // ---------------------------------------------------------------------------
  // BACKEND LOGIN
  // ---------------------------------------------------------------------------

  /// Performs `loginWithBackend` for this feature. Update this documentation when its contract changes.
  Future<void> loginWithBackend({
    required String email,
    required String password,
  }) async {
    final response =
        await backendApi.login(
      email:
          email.trim().toLowerCase(),
      password: password,
    );

    lastLoginSecurity = response['security'] is Map
        ? Map<String, dynamic>.from(response['security'] as Map)
        : null;

    final accountData =
        response['account'];

    if (accountData is! Map) {
      throw BackendApiException(
        'The server returned an invalid account response.',
      );
    }

    final accountMap =
        Map<String, dynamic>.from(
      accountData,
    );

    final username =
        accountMap['username']
                ?.toString() ??
            '';

    final accountEmail =
        accountMap['email']
                ?.toString() ??
            '';

    if (username.isEmpty ||
        email.isEmpty) {
      throw BackendApiException(
        'The server returned incomplete account information.',
      );
    }

    final subscriptionData =
        accountMap['subscription'];

    SubscriptionPlan plan =
        SubscriptionPlan.monthly;

    if (subscriptionData is Map) {
      final planValue =
          subscriptionData['plan']
              ?.toString()
              .toLowerCase();

      if (planValue == 'yearly') {
        plan =
            SubscriptionPlan.yearly;
      }
    }

    SubscriptionStatus
        subscriptionStatus =
        SubscriptionStatus.expired;

    if (subscriptionData is Map) {
      final statusValue =
          subscriptionData['status']
              ?.toString()
              .toLowerCase();

      if (statusValue == 'active') {
        subscriptionStatus =
            SubscriptionStatus.active;
      }
    }

    final List<Profile> profiles =
        <Profile>[];

    final profilesData =
        accountMap['profiles'];

    if (profilesData is List) {
      for (final item in profilesData) {
        if (item is Map) {
          profiles.add(
            Profile.fromJson(
              Map<String, dynamic>.from(
                item,
              ),
            ),
          );
        }
      }
    }

    // New accounts intentionally keep ZERO profiles. The owner creates the
    // first profile from the profile-selection screen after signing in.

    currentAccount =
        UserAccount(
      username: username,
      email: accountEmail,
      subscription:
          Subscription(
        plan: plan,
        status:
            subscriptionStatus,
      ),
      profiles: profiles,
    );

    currentProfile = profiles.isEmpty ? null : profiles.first;

    activeProfileIds.clear();
    if (currentProfile != null) {
      activeProfileIds.add(currentProfile!.id);
    }

    recommendations.clear();
    groupRecommendations.clear();
    wishlist.clear();
    groupWatchSessions.clear();

    activeGroupWatchSessionId = null;

    recommendationsError = null;
    recommendationsLoading = false;

    groupRecommendationsError =
        null;
    groupRecommendationsLoading =
        false;

    groupWishlistError = null;
    groupWishlistLoading = false;

    groupWatchError = null;
    groupWatchLoading = false;

    notifyListeners();

    await loadRecommendations();
    await loadGroupWishlist();
    await loadGroupRecommendations();
    await loadGroupWatchSessions();
  }

  // ---------------------------------------------------------------------------
  // BACKEND ACCOUNT REFRESH
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>>
      refreshBackendAccount() async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You are not logged in.',
      );
    }

    if (currentAccount == null) {
      throw BackendApiException(
        'No account is currently loaded.',
      );
    }

    return currentAccount!.toJson();
  }

  // ---------------------------------------------------------------------------
  // BACKEND LOGOUT
  // ---------------------------------------------------------------------------

  /// Performs `logoutFromBackend` for this feature. Update this documentation when its contract changes.
  Future<void> logoutFromBackend() async {
    try {
      if (backendApi.isAuthenticated) {
        await backendApi.logout();
      }
    } finally {
      backendApi.clearToken();

      currentAccount = null;
      currentProfile = null;

      activeProfileIds.clear();

      recommendations.clear();
      recommendationsError = null;
      recommendationsLoading = false;

      groupRecommendations.clear();
      groupRecommendationsError = null;
      groupRecommendationsLoading = false;

      wishlist.clear();
      groupWishlistError = null;
      groupWishlistLoading = false;

      groupWatchSessions.clear();
      groupWatchError = null;
      groupWatchLoading = false;
      activeGroupWatchSessionId = null;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // LOCAL LOGIN
  // ---------------------------------------------------------------------------

  /// Performs `login` for this feature. Update this documentation when its contract changes.
  bool login(
    String usernameOrEmail,
    String password,
  ) {
    if (currentAccount == null) {
      return false;
    }

    final matchesUsername =
        currentAccount!.username
                .toLowerCase() ==
            usernameOrEmail
                .trim()
                .toLowerCase();

    final matchesEmail =
        currentAccount!.email
                .toLowerCase() ==
            usernameOrEmail
                .trim()
                .toLowerCase();

    if (!matchesUsername &&
        !matchesEmail) {
      return false;
    }

    if (!currentAccount!
        .hasActiveSubscription) {
      return false;
    }

    if (currentAccount!
        .profiles
        .isNotEmpty) {
      currentProfile =
          currentAccount!
              .profiles
              .first;

      activeProfileIds
        ..clear()
        ..add(currentProfile!.id);
    }

    notifyListeners();

    return true;
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------

  /// Performs `logout` for this feature. Update this documentation when its contract changes.
  void logout() {
    backendApi.clearToken();

    currentAccount = null;
    currentProfile = null;

    activeProfileIds.clear();

    recommendations.clear();
    recommendationsError = null;
    recommendationsLoading = false;

    groupRecommendations.clear();
    groupRecommendationsError = null;
    groupRecommendationsLoading = false;

    wishlist.clear();
    groupWishlistError = null;
    groupWishlistLoading = false;

    groupWatchSessions.clear();
    groupWatchError = null;
    groupWatchLoading = false;
    activeGroupWatchSessionId = null;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SUBSCRIPTION
  // ---------------------------------------------------------------------------

  Subscription? get subscription =>
      currentAccount?.subscription;

  bool get hasActiveSubscription =>
      currentAccount
          ?.hasActiveSubscription ??
      false;

  SubscriptionPlan? get subscriptionPlan =>
      currentAccount
          ?.subscription.plan;

  /// Performs `subscribe` for this feature. Update this documentation when its contract changes.
  void subscribe(
    SubscriptionPlan plan,
  ) {
    if (currentAccount == null) {
      return;
    }

    currentAccount!.subscription =
        Subscription(
      plan: plan,
      status:
          SubscriptionStatus.active,
    );

    notifyListeners();
  }

  /// Performs `expireSubscription` for this feature. Update this documentation when its contract changes.
  void expireSubscription() {
    if (currentAccount == null) {
      return;
    }

    currentAccount!
        .subscription
        .status =
        SubscriptionStatus.expired;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PROFILES
  // ---------------------------------------------------------------------------

  Profile addProfile(
    String name, {
    String? avatarUrl,
  }) {
    if (currentAccount == null) {
      throw StateError(
        'No account is currently signed in.',
      );
    }

    if (currentAccount!
            .profiles
            .length >=
        7) {
      throw StateError(
        'You can have a maximum of 7 profiles.',
      );
    }

    final cleanedName = name.trim();

    final profile =
        Profile(
      id: _generateId('profile'),
      name: cleanedName.isEmpty
          ? 'Profile ${currentAccount!.profiles.length + 1}'
          : cleanedName,
      avatarUrl: avatarUrl,
    );

    currentAccount!
        .profiles
        .add(profile);

    notifyListeners();

    return profile;
  }

  /// Performs `removeProfile` for this feature. Update this documentation when its contract changes.
  void removeProfile(
    String profileId,
  ) {
    if (currentAccount == null) {
      return;
    }

    currentAccount!.profiles.removeWhere((profile) => profile.id == profileId);
    activeProfileIds.remove(profileId);

    if (currentProfile?.id == profileId) {
      currentProfile = currentAccount!.profiles.isEmpty
          ? null
          : currentAccount!.profiles.first;
      if (currentProfile != null) {
        activeProfileIds.add(currentProfile!.id);
      }
    }
    notifyListeners();

    notifyListeners();
  }

  /// Performs `switchProfile` for this feature. Update this documentation when its contract changes.
  void switchProfile(
    String profileId,
  ) {
    if (currentAccount == null) {
      return;
    }

    Profile? profile;

    for (final item
        in currentAccount!.profiles) {
      if (item.id == profileId) {
        profile = item;
        break;
      }
    }

    if (profile == null) {
      return;
    }

    currentProfile = profile;

    activeProfileIds
      ..clear()
      ..add(profile.id);

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ARM DRIVES
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>>
      getArmDrives() async {
    final drives =
        await backendApi.getArmDrives();

    return drives
        .whereType<Map>()
        .map(
          (drive) =>
              Map<String, dynamic>.from(
            drive,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // LIBRARY
  // ---------------------------------------------------------------------------

  /// Performs `isOwned` for this feature. Update this documentation when its contract changes.
  bool isOwned(String mediaId) {
    return library.any(
      (item) => item.id == mediaId,
    );
  }

  /// Replaces the client library with media discovered on the home server.
  void replaceLibraryFromServer(List<MediaItem> media) {
    library
      ..clear()
      ..addAll(media);
    notifyListeners();
  }

  /// Performs `addToLibrary` for this feature. Update this documentation when its contract changes.
  void addToLibrary(
    MediaItem media,
  ) {
    if (isOwned(media.id)) {
      return;
    }

    library.add(media);

    _mergeCatalog(actorsCatalog, media.actors);
    _mergeCatalog(directorsCatalog, media.directors);
    _mergeCatalog(writersCatalog, media.writers);
    _mergeCatalog(musicCatalog, media.music);
    _mergeCatalog(genresCatalog, media.genres);
    _mergeCatalog(tagsCatalog, media.tags);

    addNotification(
      action: 'added ${_mediaTypeLabel(media)} "${media.title}"',
    );

    _autoAssignFranchiseMetadata(media);
    _refreshAutomaticCollections();
    notifyListeners();
  }

  /// Performs `_mergeCatalog` for this feature. Update this documentation when its contract changes.
  void _mergeCatalog(List<String> target, List<String> values) {
    for (final value in values) {
      final clean = value.trim();
      if (clean.isNotEmpty && !target.any((item) => item.toLowerCase() == clean.toLowerCase())) {
        target.add(clean);
      }
    }
  }

  /// Performs `removeFromLibrary` for this feature. Update this documentation when its contract changes.
  void removeFromLibrary(
    String mediaId,
  ) {
    library.removeWhere(
      (item) => item.id == mediaId,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // WATCHED / PLAYBACK
  // ---------------------------------------------------------------------------

  /// Performs `isWatched` for this feature. Update this documentation when its contract changes.
  bool isWatched(String mediaId) {
    return watched.any(
      (item) => item.id == mediaId,
    );
  }

  /// Performs `getPlaybackProgress` for this feature. Update this documentation when its contract changes.
  double getPlaybackProgress(
    String mediaId,
  ) {
    return playbackProgress[mediaId] ?? 0;
  }

  /// Performs `updatePlaybackProgress` for this feature. Update this documentation when its contract changes.
  void updatePlaybackProgress(
    String mediaId,
    double progress,
  ) {
    final clamped =
        progress.clamp(0.0, 1.0);

    playbackProgress[mediaId] =
        clamped.toDouble();

    notifyListeners();
  }

  /// Performs `markWatched` for this feature. Update this documentation when its contract changes.
  void markWatched(
    MediaItem media,
  ) {
    if (!isWatched(media.id)) {
      watched.add(media);
      _recordMonthlyWatch(media);

      _addActivity(
        title: media.title,
        action: 'Watched',
      );
    }

    playbackProgress[media.id] = 1.0;

    notifyListeners();
  }

  /// Performs `finishWatching` for this feature. Update this documentation when its contract changes.
  void finishWatching(
    MediaItem media,
  ) {
    markWatched(media);
  }

  // ---------------------------------------------------------------------------
  // LIKES / DISLIKES
  // ---------------------------------------------------------------------------

  /// Performs `isLiked` for this feature. Update this documentation when its contract changes.
  bool isLiked(String mediaId) {
    return liked.any(
      (item) => item.id == mediaId,
    );
  }

  /// Performs `isDisliked` for this feature. Update this documentation when its contract changes.
  bool isDisliked(String mediaId) {
    return disliked.any(
      (item) => item.id == mediaId,
    );
  }

  /// Performs `likeMedia` for this feature. Update this documentation when its contract changes.
  void likeMedia(
    MediaItem media,
  ) {
    disliked.removeWhere(
      (item) => item.id == media.id,
    );

    if (!isLiked(media.id)) {
      liked.add(media);
    }

    notifyListeners();
  }

  /// Performs `dislikeMedia` for this feature. Update this documentation when its contract changes.
  void dislikeMedia(
    MediaItem media,
  ) {
    liked.removeWhere(
      (item) => item.id == media.id,
    );

    if (!isDisliked(media.id)) {
      disliked.add(media);
    }

    notifyListeners();
  }

  /// Performs `clearReaction` for this feature. Update this documentation when its contract changes.
  void clearReaction(
    String mediaId,
  ) {
    liked.removeWhere(
      (item) => item.id == mediaId,
    );

    disliked.removeWhere(
      (item) => item.id == mediaId,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  Future<void>
      loadRecommendations() async {
    if (!backendApi.isAuthenticated) {
      recommendations.clear();
      recommendationsError = null;
      recommendationsLoading = false;
      notifyListeners();
      return;
    }

    recommendationsLoading = true;
    recommendationsError = null;

    notifyListeners();

    try {
      final response =
          await backendApi
              .getRecommendations();

      final List<MediaItem> loaded =
          <MediaItem>[];

      final data =
          response['recommendations'];

      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            loaded.add(
              MediaItem.fromJson(
                Map<String, dynamic>.from(
                  item,
                ),
              ),
            );
          }
        }
      }

      recommendations = loaded;
    } catch (error) {
      recommendationsError =
          error.toString();
    } finally {
      recommendationsLoading =
          false;

      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIVITY
  // ---------------------------------------------------------------------------

  /// Performs `_addActivity` for this feature. Update this documentation when its contract changes.
  void _addActivity({
    required String title,
    required String action,
  }) {
    activity.insert(
      0,
      ActivityItem(
        id: _generateId('activity'),
        title: title,
        action: action,
        timestamp: DateTime.now(),
      ),
    );

    if (activity.length > 100) {
      activity.removeLast();
    }
    notifyListeners();
  }

  /// Adds a user-facing notification to the activity center.
  ///
  /// This is public so features outside AppController, such as Music, can
  /// create the same notification style without duplicating activity logic.
  void addNotification({required String action, String? profileName}) {
    final name = (profileName ?? currentProfile?.name ?? currentAccount?.username ?? 'User').trim();
    _addActivity(
      title: name.isEmpty ? 'User' : name,
      action: action.trim(),
    );
  }

  String _mediaTypeLabel(MediaItem media) {
    final type = media.type.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (type == 'tvshow' || type == 'series') return 'TV show';
    if (type == 'album') return 'album';
    return 'movie';
  }

  // ---------------------------------------------------------------------------
  // BACKEND CROSS-ACCOUNT GROUP CHAT
  // ---------------------------------------------------------------------------

  /// Performs `loadGroupChatRoom` for this feature. Update this documentation when its contract changes.
  Future<void> loadGroupChatRoom({String? roomId}) async {
    if (!backendApi.isAuthenticated) return;
    groupChatLoading = true;
    groupChatError = null;
    notifyListeners();
    try {
      Map<String, dynamic> response;
      if (roomId != null && roomId.isNotEmpty) {
        response = await backendApi.getGroupChatRoom(roomId);
      } else {
        final rooms = await backendApi.getGroupChatRooms();
        final data = rooms['rooms'];
        if (data is! List || data.isEmpty) {
          activeGroupChatRoom = null;
          return;
        }
        response = {'room': data.first};
      }
      final raw = response['room'];
      if (raw is Map) activeGroupChatRoom = BackendGroupChatRoom.fromJson(Map<String,dynamic>.from(raw));
    } catch (error) {
      groupChatError = error.toString();
    } finally {
      groupChatLoading = false;
      notifyListeners();
    }
  }

  /// Performs `createCrossAccountGroupChat` for this feature. Update this documentation when its contract changes.
  Future<void> createCrossAccountGroupChat({required String name, required String profileId, Set<String>? invitedProfiles}) async {
    final response = await backendApi.createGroupChatRoom(name: name, profileId: profileId, invitedProfiles: invitedProfiles);
    final raw = response['room'];
    if (raw is Map) activeGroupChatRoom = BackendGroupChatRoom.fromJson(Map<String,dynamic>.from(raw));
    notifyListeners();
  }

  /// Performs `sendCrossAccountGroupMessage` for this feature. Update this documentation when its contract changes.
  Future<void> sendCrossAccountGroupMessage({required String roomId, required String profileId, required String message}) async {
    await backendApi.sendGroupChatMessage(roomId: roomId, profileId: profileId, message: message, badgeName: badgeForProfile(profileId));
    addNotification(action: 'sent a message', profileName: _profileNameForId(profileId));
    await loadGroupChatRoom(roomId: roomId);
  }

  // ---------------------------------------------------------------------------
  // GROUP CHAT
  // ---------------------------------------------------------------------------

  /// Performs `sendGroupMessage` for this feature. Update this documentation when its contract changes.
  void sendGroupMessage({
    required String message,
  }) {
    final cleanedMessage =
        message.trim();

    if (cleanedMessage.isEmpty) {
      return;
    }

    groupMessages.add(
      ChatMessage(
        id: _generateId('message'),
        sender:
            currentProfile?.name ??
                currentAccount?.username ??
                'You',
        message: cleanedMessage,
        timestamp: DateTime.now(),
      ),
    );

    addNotification(action: 'sent a message');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  Future<void>
      loadGroupRecommendations() async {
    if (!backendApi.isAuthenticated) {
      groupRecommendations.clear();
      groupRecommendationsError = null;
      groupRecommendationsLoading =
          false;

      notifyListeners();
      return;
    }

    groupRecommendationsLoading =
        true;

    groupRecommendationsError =
        null;

    notifyListeners();

    try {
      final response =
          await backendApi
              .getGroupRecommendations();

      final data =
          response['recommendations'];

      final loaded =
          <Map<String, dynamic>>[];

      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            loaded.add(
              Map<String, dynamic>.from(
                item,
              ),
            );
          }
        }
      }

      groupRecommendations =
          loaded;
    } catch (error) {
      groupRecommendationsError =
          error.toString();
    } finally {
      groupRecommendationsLoading =
          false;

      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?>
      createGroupRecommendation({
    required String title,
    required String type,
    required String profileId,
    String? mediaId,
    Set<String>? activeParticipants,
    int? votingDurationHours,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before creating a group recommendation.',
      );
    }

    final String cleanedTitle =
        title.trim();

    final String cleanedType =
        type.trim();

    final String cleanedProfileId =
        profileId.trim();

    if (cleanedTitle.isEmpty) {
      throw ArgumentError(
        'Recommendation title cannot be empty.',
      );
    }

    if (cleanedType != 'movie' &&
        cleanedType != 'tvShow') {
      throw ArgumentError(
        'Recommendation type must be "movie" or "tvShow".',
      );
    }

    if (cleanedProfileId.isEmpty) {
      throw ArgumentError(
        'Profile ID cannot be empty.',
      );
    }

    if (votingDurationHours != null &&
        votingDurationHours <= 0) {
      throw ArgumentError(
        'Voting duration must be greater than zero.',
      );
    }

    String? cleanedMediaId =
        mediaId?.trim();

    if (cleanedMediaId != null &&
        cleanedMediaId.isEmpty) {
      cleanedMediaId = null;
    }

    // Recommendation voting is account-wide for normal profiles.  The
    // creator may still supply a participant list, but every profile on the
    // current account is always eligible so one profile cannot accidentally
    // create a recommendation that other profiles cannot vote on.
    final Set<String> participants = <String>{
      ...?activeParticipants,
      ...?currentAccount?.profiles.map((profile) => profile.id),
    };

    participants.removeWhere((id) => id.trim().isEmpty);
    participants.add(cleanedProfileId);

    final response =
        await backendApi
            .createGroupRecommendation(
      title: cleanedTitle,
      type: cleanedType,
      profileId: cleanedProfileId,
      mediaId: cleanedMediaId,
      activeParticipants: participants,
      votingDurationHours:
          votingDurationHours,
    );

    final recommendation =
        response['recommendation'];

    if (recommendation is Map) {
      final recommendationMap =
          Map<String, dynamic>.from(
        recommendation,
      );

      groupRecommendations
          .removeWhere(
        (item) =>
            item['id']?.toString() ==
            recommendationMap['id']
                ?.toString(),
      );

      groupRecommendations.insert(
        0,
        recommendationMap,
      );

      final String titleForMessage =
          recommendationMap['title']
                  ?.toString() ??
              cleanedTitle;

      final String icon =
          cleanedType == 'tvShow'
              ? '📺'
              : '🎬';

      final String typeLabel =
          cleanedType == 'tvShow'
              ? 'TV show'
              : 'movie';

      sendGroupMessage(
        message:
            '$icon ${currentProfile?.name ?? 'You'} recommended the $typeLabel "$titleForMessage"',
      );
      addNotification(
        action: 'added a $typeLabel recommendation "$titleForMessage"',
      );

      notifyListeners();

      return recommendationMap;
    }

    await loadGroupRecommendations();

    return null;
  }

  Future<Map<String, dynamic>?>
      getGroupRecommendation(
    String recommendationId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId =
        recommendationId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .getGroupRecommendation(
      recommendationId:
          cleanedId,
    );

    final recommendation =
        response['recommendation'];

    if (recommendation is! Map) {
      return null;
    }

    final recommendationMap =
        Map<String, dynamic>.from(
      recommendation,
    );

    groupRecommendations
        .removeWhere(
      (item) =>
          item['id']?.toString() ==
          cleanedId,
    );

    groupRecommendations.insert(
      0,
      recommendationMap,
    );

    notifyListeners();

    return recommendationMap;
  }

  Future<Map<String, dynamic>?>
      voteOnGroupRecommendation({
    required String recommendationId,
    required String profileId,
    required String vote,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedRecommendationId =
        recommendationId.trim();

    final cleanedProfileId =
        profileId.trim();

    final cleanedVote =
        vote.trim().toLowerCase();

    if (cleanedRecommendationId
        .isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    if (cleanedProfileId.isEmpty) {
      throw ArgumentError(
        'Profile ID cannot be empty.',
      );
    }

    if (cleanedVote != 'yes' &&
        cleanedVote != 'no') {
      throw ArgumentError(
        'Vote must be either "yes" or "no".',
      );
    }

    final response =
        await backendApi
            .voteOnGroupRecommendation(
      recommendationId:
          cleanedRecommendationId,
      profileId:
          cleanedProfileId,
      vote: cleanedVote,
    );

    final recommendation =
        response['recommendation'];

    if (recommendation is Map) {
      final recommendationMap =
          Map<String, dynamic>.from(
        recommendation,
      );

      groupRecommendations
          .removeWhere(
        (item) =>
            item['id']?.toString() ==
            cleanedRecommendationId,
      );

      groupRecommendations.insert(
        0,
        recommendationMap,
      );

      final String title =
          recommendationMap['title']
                  ?.toString() ??
              'this recommendation';

      final String voterName =
          _profileNameForId(
        cleanedProfileId,
      );

      final int yesVotes =
          _intFromValue(
        recommendationMap['yesVotes'],
      );

      final int noVotes =
          _intFromValue(
        recommendationMap['noVotes'],
      );

      final double yesPercentage =
          _doubleFromValue(
        recommendationMap['yesPercentage'],
        fallback:
            _percentage(
          yesVotes,
          yesVotes + noVotes,
        ),
      );

      final double noPercentage =
          _doubleFromValue(
        recommendationMap['noPercentage'],
        fallback:
            _percentage(
          noVotes,
          yesVotes + noVotes,
        ),
      );

      sendGroupMessage(
        message:
            '$voterName voted ${cleanedVote.toUpperCase()} on "$title" — '
            'YES ${_formatPercentage(yesPercentage)}% '
            'NO ${_formatPercentage(noPercentage)}%',
      );

      final status =
          recommendationMap['status']
              ?.toString()
              .toLowerCase();

      if (status == 'approved') {
        await loadGroupWishlist();
      }

      notifyListeners();

      return recommendationMap;
    }

    await loadGroupRecommendations();

    return null;
  }

  Future<Map<String, dynamic>?>
      closeGroupRecommendationVoting({
    required String recommendationId,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId =
        recommendationId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .closeGroupRecommendationVoting(
      recommendationId:
          cleanedId,
    );

    final recommendation =
        response['recommendation'];

    if (recommendation is Map) {
      final recommendationMap =
          Map<String, dynamic>.from(
        recommendation,
      );

      groupRecommendations
          .removeWhere(
        (item) =>
            item['id']?.toString() ==
            cleanedId,
      );

      groupRecommendations.insert(
        0,
        recommendationMap,
      );

      final status =
          recommendationMap['status']
              ?.toString()
              .toLowerCase();

      if (status == 'approved') {
        await loadGroupWishlist();
      }

      notifyListeners();

      return recommendationMap;
    }

    await loadGroupRecommendations();

    return null;
  }

  Future<void>
      deleteGroupRecommendation(
    String recommendationId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId =
        recommendationId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Recommendation ID cannot be empty.',
      );
    }

    await backendApi
        .deleteGroupRecommendation(
      recommendationId:
          cleanedId,
    );

    groupRecommendations
        .removeWhere(
      (item) =>
          item['id']?.toString() ==
          cleanedId,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP WISHLIST
  // ---------------------------------------------------------------------------

  Future<void>
      loadGroupWishlist() async {
    if (!backendApi.isAuthenticated) {
      wishlist.clear();
      groupWishlistError = null;
      groupWishlistLoading = false;

      notifyListeners();
      return;
    }

    groupWishlistLoading = true;
    groupWishlistError = null;

    notifyListeners();

    try {
      final response =
          await backendApi
              .getGroupWishlist();

      final data =
          response['wishlist'];

      final loaded =
          <WishlistItem>[];

      if (data is List) {
        for (final item in data) {
          if (item is! Map) {
            continue;
          }

          final map =
              Map<String, dynamic>.from(
            item,
          );

          final id =
              map['id']?.toString() ??
                  '';

          if (id.isEmpty) {
            continue;
          }

          loaded.add(
            WishlistItem(
              id: id,
              title:
                  map['title']
                          ?.toString() ??
                      id,
              type:
                  map['type']
                          ?.toString() ??
                      'unknown',
            ),
          );
        }
      }

      wishlist
        ..clear()
        ..addAll(loaded);
    } catch (error) {
      groupWishlistError =
          error.toString();
    } finally {
      groupWishlistLoading =
          false;

      notifyListeners();
    }
  }

  /// Performs `isInGroupWishlist` for this feature. Update this documentation when its contract changes.
  bool isInGroupWishlist(
    String mediaId,
  ) {
    return wishlist.any(
      (item) => item.id == mediaId,
    );
  }

  Future<void>
      removeFromGroupWishlist(
    String mediaId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId =
        mediaId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Media ID cannot be empty.',
      );
    }

    await backendApi
        .removeFromGroupWishlist(
      mediaId: cleanedId,
    );

    wishlist.removeWhere(
      (item) => item.id == cleanedId,
    );

    notifyListeners();
  }

  Future<void>
      acquireGroupWishlistItem({
    required String mediaId,
    required String profileId,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedMediaId =
        mediaId.trim();

    final cleanedProfileId =
        profileId.trim();

    if (cleanedMediaId.isEmpty) {
      throw ArgumentError(
        'Media ID cannot be empty.',
      );
    }

    if (cleanedProfileId.isEmpty) {
      throw ArgumentError(
        'Profile ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .acquireGroupWishlistItem(
      mediaId:
          cleanedMediaId,
      profileId:
          cleanedProfileId,
    );

    wishlist.removeWhere(
      (item) =>
          item.id ==
          cleanedMediaId,
    );

    final mediaData =
        response['media'];

    if (mediaData is Map) {
      final media =
          MediaItem.fromJson(
        Map<String, dynamic>.from(
          mediaData,
        ),
      );

      if (media.id.isNotEmpty &&
          !isOwned(media.id)) {
        library.add(media);

        _addActivity(
          title: media.title,
          action:
              'Added from group wishlist',
        );
      }
    }

    notifyListeners();

    await loadGroupWishlist();
  }

  // ---------------------------------------------------------------------------
  // BACKWARD-COMPATIBLE LOCAL WISHLIST API
  // ---------------------------------------------------------------------------

  /// Performs `isInWishlist` for this feature. Update this documentation when its contract changes.
  bool isInWishlist(
    String mediaId,
  ) {
    return wishlist.any(
      (item) => item.id == mediaId,
    );
  }

  /// Performs `addToWishlist` for this feature. Update this documentation when its contract changes.
  void addToWishlist(
    MediaItem media,
  ) {
    if (isInWishlist(media.id)) {
      return;
    }

    wishlist.add(
      WishlistItem(
        id: media.id,
        title: media.title,
        type: media.type,
      ),
    );

    notifyListeners();
  }

  /// Performs `removeFromWishlist` for this feature. Update this documentation when its contract changes.
  void removeFromWishlist(
    String mediaId,
  ) {
    wishlist.removeWhere(
      (item) => item.id == mediaId,
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP WATCH
  // ---------------------------------------------------------------------------

  /// Loads every Group Watch session belonging to the authenticated account.
  Future<void>
      loadGroupWatchSessions() async {
    if (!backendApi.isAuthenticated) {
      groupWatchSessions.clear();
      activeGroupWatchSessionId = null;
      groupWatchError = null;
      groupWatchLoading = false;

      notifyListeners();
      return;
    }

    groupWatchLoading = true;
    groupWatchError = null;

    notifyListeners();

    try {
      final response =
          await backendApi
              .getGroupWatchSessions();

      final data =
          response['sessions'];

      final loaded =
          <GroupWatchSession>[];

      if (data is List) {
        for (final item in data) {
          if (item is! Map) {
            continue;
          }

          final session =
              GroupWatchSession.fromJson(
            Map<String, dynamic>.from(
              item,
            ),
            knownProfiles:
                currentAccount?.profiles ??
                const <Profile>[],
          );

          if (session.id.isNotEmpty) {
            loaded.add(session);
          }
        }
      }

      groupWatchSessions
        ..clear()
        ..addAll(loaded);

      final activeId =
          activeGroupWatchSessionId;

      if (activeId != null &&
          !groupWatchSessions.any(
            (session) =>
                session.id == activeId,
          )) {
        activeGroupWatchSessionId = null;
      }
    } catch (error) {
      groupWatchError =
          error.toString();

      debugPrint(
        'Failed to load Group Watch sessions: $error',
      );
    } finally {
      groupWatchLoading = false;

      notifyListeners();
    }
  }

  /// Returns a locally cached Group Watch session by ID.
  GroupWatchSession?
      getGroupWatchSession(
    String sessionId,
  ) {
    final cleanedId =
        sessionId.trim();

    if (cleanedId.isEmpty) {
      return null;
    }

    for (final session
        in groupWatchSessions) {
      if (session.id == cleanedId) {
        return session;
      }
    }

    return null;
  }

  /// Marks a Group Watch session as the session currently being watched.
  void setActiveGroupWatchSession(
    String? sessionId,
  ) {
    final cleanedId =
        sessionId?.trim();

    if (cleanedId == null ||
        cleanedId.isEmpty) {
      activeGroupWatchSessionId = null;
    } else {
      activeGroupWatchSessionId =
          cleanedId;
    }

    notifyListeners();
  }

  /// Refreshes one Group Watch session from the backend.
  Future<GroupWatchSession?>
      refreshGroupWatchSession(
    String sessionId,
  ) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in.',
      );
    }

    final cleanedId =
        sessionId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .getGroupWatchSession(
      sessionId: cleanedId,
    );

    final sessionData =
        response['session'];

    if (sessionData is! Map) {
      return null;
    }

    final session =
        GroupWatchSession.fromJson(
      Map<String, dynamic>.from(
        sessionData,
      ),
      knownProfiles:
          currentAccount?.profiles ??
          const <Profile>[],
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Creates a local Group Watch session for backwards compatibility with
  /// older UI code.
  ///
  /// The real backend-connected implementation is
  /// [createBackendGroupWatchSession].
  ///
  /// This compatibility method does not claim that the backend session was
  /// created. The player will be migrated to the backend method in the next
  /// implementation step.
  GroupWatchSession createGroupWatchSession(
    MediaItem media, {
    String? profileId,
    Set<String>? invitedProfileIds,
    int? invitationDurationHours,
  }) {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    final invited =
        invitedProfileIds == null
            ? <String>{}
            : Set<String>.from(
                invitedProfileIds,
              );

    invited.removeWhere(
      (id) => id.trim().isEmpty,
    );

    invited.remove(selectedProfileId);

    final sessionId =
        _generateId('group-watch');

    final participantStates =
        <String, GroupWatchParticipant>{};

    if (selectedProfileId.isNotEmpty) {
      participantStates[
          selectedProfileId] =
          GroupWatchParticipant(
        profileId:
            selectedProfileId,
        profileName:
            _profileNameForId(
          selectedProfileId,
        ),
        invitationStatus:
            'accepted',
        joinedAt:
            DateTime.now(),
      );
    }

    for (final invitedId
        in invited) {
      final cleanId =
          invitedId.trim();

      participantStates[cleanId] =
          GroupWatchParticipant(
        profileId: cleanId,
        profileName:
            _profileNameForId(
          cleanId,
        ),
        invitationStatus:
            'pending',
      );
    }

    DateTime? invitationExpiresAt;

    if (invitationDurationHours != null &&
        invitationDurationHours > 0) {
      invitationExpiresAt =
          DateTime.now().add(
        Duration(
          hours:
              invitationDurationHours,
        ),
      );
    } else if (invited.isNotEmpty) {
      invitationExpiresAt =
          DateTime.now().add(
        const Duration(
          hours: 24,
        ),
      );
    }

    final session =
        GroupWatchSession(
      id: sessionId,
      title: media.title,
      mediaId: media.id,
      type: _backendMediaType(
        media.type,
      ),
      hostProfileId:
          selectedProfileId,
      participants:
          participantStates.values
              .map(
                (participant) =>
                    participant.profileName,
              )
              .toList(),
      participantStates:
          participantStates,
      status: 'waiting',
      invitationExpiresAt:
          invitationExpiresAt,
    );

    _upsertGroupWatchSession(
      session,
    );

    activeGroupWatchSessionId =
        session.id;

    notifyListeners();

    return session;
  }

  /// Creates a real backend Group Watch session.
  ///
  /// The selected profile becomes the host. Invited profiles are individual
  /// profiles from the same account.
  Future<GroupWatchSession>
      createBackendGroupWatchSession(
    MediaItem media, {
    String? profileId,
    Set<String>? invitedProfileIds,
    int? invitationDurationHours,
  }) async {
    if (!backendApi.isAuthenticated) {
      throw BackendApiException(
        'You must be logged in before creating a Group Watch.',
      );
    }

    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A host profile is required.',
      );
    }

    if (!_accountHasProfile(
      selectedProfileId,
    )) {
      throw ArgumentError(
        'The selected host profile does not belong to the current account.',
      );
    }

    final cleanedMediaId =
        media.id.trim();

    if (cleanedMediaId.isEmpty) {
      throw ArgumentError(
        'Media ID cannot be empty.',
      );
    }

    final cleanedTitle =
        media.title.trim();

    if (cleanedTitle.isEmpty) {
      throw ArgumentError(
        'Media title cannot be empty.',
      );
    }

    if (invitationDurationHours != null &&
        invitationDurationHours <= 0) {
      throw ArgumentError(
        'Invitation duration must be greater than zero.',
      );
    }

    final invited =
        invitedProfileIds == null
            ? <String>{}
            : Set<String>.from(
                invitedProfileIds,
              );

    invited.removeWhere(
      (id) => id.trim().isEmpty,
    );

    invited.remove(selectedProfileId);

    for (final invitedId
        in invited) {
      if (!_accountHasProfile(
        invitedId.trim(),
      )) {
        throw ArgumentError(
          'One or more invited profiles do not belong to the current account.',
        );
      }
    }

    groupWatchLoading = true;
    groupWatchError = null;

    notifyListeners();

    try {
      final response =
          await backendApi
              .createGroupWatchSession(
        mediaId: cleanedMediaId,
        title: cleanedTitle,
        type: _backendMediaType(
          media.type,
        ),
        profileId: selectedProfileId,
        invitedProfileIds: invited,
        invitationDurationHours:
            invitationDurationHours,
      );

      final sessionData =
          response['session'];

      if (sessionData is! Map) {
        throw BackendApiException(
          'The server returned an invalid Group Watch session.',
        );
      }

      final session =
          GroupWatchSession.fromJson(
        Map<String, dynamic>.from(
          sessionData,
        ),
        knownProfiles:
            currentAccount?.profiles ??
            const <Profile>[],
      );

      _upsertGroupWatchSession(
        session,
      );

      activeGroupWatchSessionId =
          session.id;

      groupWatchError = null;

      return session;
    } catch (error) {
      groupWatchError =
          error.toString();
      rethrow;
    } finally {
      groupWatchLoading = false;

      notifyListeners();
    }
  }

  /// Accepts an invitation for a profile.
  ///
  /// If the invitation has expired or the session has already started, the
  /// backend rejects the request. The UI can surface the backend's exact
  /// "This invite has expired" message.
  Future<GroupWatchSession>
      acceptGroupWatchInvitation({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (!_accountHasProfile(
      selectedProfileId,
    )) {
      throw ArgumentError(
        'The selected profile does not belong to the current account.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .acceptGroupWatchInvitation(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    sendGroupMessage(
      message:
          '${_profileNameForId(selectedProfileId)} joined the Group Watch — "${session.title}"',
    );

    notifyListeners();

    return session;
  }

  /// Declines an invitation for a profile.
  Future<GroupWatchSession>
      declineGroupWatchInvitation({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (!_accountHasProfile(
      selectedProfileId,
    )) {
      throw ArgumentError(
        'The selected profile does not belong to the current account.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .declineGroupWatchInvitation(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Sets the current participant's audio track.
  ///
  /// This changes audio only for the specified participant.
  Future<GroupWatchSession>
      setGroupWatchAudioTrack({
    required String sessionId,
    String? profileId,
    String? audioTrackId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final cleanedTrackId =
        audioTrackId?.trim();

    final response =
        await backendApi
            .setGroupWatchAudioTrack(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
      audioTrackId:
          cleanedTrackId?.isEmpty == true
              ? null
              : cleanedTrackId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Sets the current participant's subtitle track.
  ///
  /// This changes subtitles only for the specified participant.
  Future<GroupWatchSession>
      setGroupWatchSubtitleTrack({
    required String sessionId,
    String? profileId,
    String? subtitleTrackId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final cleanedTrackId =
        subtitleTrackId?.trim();

    final response =
        await backendApi
            .setGroupWatchSubtitleTrack(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
      subtitleTrackId:
          cleanedTrackId?.isEmpty == true
              ? null
              : cleanedTrackId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Starts Group Watch playback for everyone.
  Future<GroupWatchSession>
      startGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .startGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    activeGroupWatchSessionId =
        session.id;

    notifyListeners();

    return session;
  }

  /// Starts global playback.
  Future<GroupWatchSession>
      playGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .playGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    activeGroupWatchSessionId =
        session.id;

    notifyListeners();

    return session;
  }

  /// Pauses playback for EVERYONE.
  ///
  /// The backend stores the pausing profile and reason. The same reason is
  /// posted to the local group chat.
  Future<GroupWatchSession>
      pauseGroupWatchSession({
    required String sessionId,
    required String reason,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    final cleanedReason =
        reason.trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (cleanedReason.isEmpty) {
      throw ArgumentError(
        'A pause reason is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .pauseGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
      reason:
          cleanedReason,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    final profileName =
        _profileNameForId(
      selectedProfileId,
    );

    sendGroupMessage(
      message:
          '$profileName paused the Group Watch — ${_pauseReasonDisplay(cleanedReason)}',
    );

    notifyListeners();

    return session;
  }

  /// Resumes global playback.
  ///
  /// Only the profile that paused the session is permitted to resume.
  Future<GroupWatchSession>
      resumeGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final localSession =
        getGroupWatchSession(
      cleanedSessionId,
    );

    if (localSession != null &&
        localSession.pausedByProfileId !=
            null &&
        localSession.pausedByProfileId !=
            selectedProfileId) {
      throw BackendApiException(
        'Only the person who paused the Group Watch can resume it.',
      );
    }

    final response =
        await backendApi
            .resumeGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Updates the shared playback position.
  Future<GroupWatchSession>
      updateGroupWatchPosition({
    required String sessionId,
    required Duration position,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    if (position.isNegative) {
      throw ArgumentError(
        'Playback position cannot be negative.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .updateGroupWatchPosition(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
      position:
          position,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    notifyListeners();

    return session;
  }

  /// Ends Group Watch for everyone.
  Future<GroupWatchSession>
      endGroupWatchSession({
    required String sessionId,
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    final response =
        await backendApi
            .endGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    final session =
        _sessionFromResponse(
      response,
    );

    _upsertGroupWatchSession(
      session,
    );

    if (activeGroupWatchSessionId ==
        session.id) {
      activeGroupWatchSessionId = null;
    }

    notifyListeners();

    return session;
  }

  /// Deletes a Group Watch session.
  Future<void>
      deleteGroupWatchSession(
    String sessionId, {
    String? profileId,
  }) async {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    if (selectedProfileId.isEmpty) {
      throw ArgumentError(
        'A profile ID is required.',
      );
    }

    final cleanedSessionId =
        sessionId.trim();

    if (cleanedSessionId.isEmpty) {
      throw ArgumentError(
        'Group Watch session ID cannot be empty.',
      );
    }

    await backendApi
        .deleteGroupWatchSession(
      sessionId:
          cleanedSessionId,
      profileId:
          selectedProfileId,
    );

    groupWatchSessions
        .removeWhere(
      (session) =>
          session.id ==
          cleanedSessionId,
    );

    if (activeGroupWatchSessionId ==
        cleanedSessionId) {
      activeGroupWatchSessionId = null;
    }

    notifyListeners();
  }

  /// Returns whether the specified profile can resume the session.
  bool canResumeGroupWatchSession(
    String sessionId, {
    String? profileId,
  }) {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    final session =
        getGroupWatchSession(
      sessionId,
    );

    if (session == null) {
      return false;
    }

    return session.canResume(
      selectedProfileId,
    );
  }

  /// Returns the participant state for a profile.
  GroupWatchParticipant?
      getGroupWatchParticipant({
    required String sessionId,
    String? profileId,
  }) {
    final selectedProfileId =
        (profileId ??
                currentProfile?.id ??
                '')
            .trim();

    final session =
        getGroupWatchSession(
      sessionId,
    );

    if (session == null) {
      return null;
    }

    return session.participantForProfile(
      selectedProfileId,
    );
  }

  String? getGroupWatchAudioTrack({
    required String sessionId,
    String? profileId,
  }) {
    return getGroupWatchParticipant(
      sessionId: sessionId,
      profileId: profileId,
    )?.audioTrackId;
  }

  String? getGroupWatchSubtitleTrack({
    required String sessionId,
    String? profileId,
  }) {
    return getGroupWatchParticipant(
      sessionId: sessionId,
      profileId: profileId,
    )?.subtitleTrackId;
  }

  Duration getGroupWatchPosition(
    String sessionId,
  ) {
    return getGroupWatchSession(
          sessionId,
        )?.playbackPosition ??
        Duration.zero;
  }

  /// Performs `isGroupWatchPlaying` for this feature. Update this documentation when its contract changes.
  bool isGroupWatchPlaying(
    String sessionId,
  ) {
    return getGroupWatchSession(
          sessionId,
        )?.isPlaying ??
        false;
  }

  /// Returns whether a Group Watch invitation is no longer joinable.
  bool isGroupWatchInvitationExpired(
    String sessionId,
  ) {
    final session =
        getGroupWatchSession(
      sessionId,
    );

    return session?.invitationsExpired ??
        true;
  }

  /// Returns the exact UI message used when an invitation is no longer
  /// joinable.
  String groupWatchInvitationExpiredMessage(
    String sessionId,
  ) {
    if (isGroupWatchInvitationExpired(
      sessionId,
    )) {
      return 'This invite has expired';
    }

    return '';
  }

  /// Compatibility method retained for older UI code.
  ///
  /// Real Group Watch synchronization is always controlled by the backend.
  void toggleGroupWatchSync(
    String sessionId,
  ) {
    final session =
        getGroupWatchSession(
      sessionId,
    );

    if (session == null) {
      return;
    }

    session.synchronized =
        !session.synchronized;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // MUSIC ACTIVITY
  // ---------------------------------------------------------------------------

  /// Performs `recordMusicActivity` for this feature. Update this documentation when its contract changes.
  void recordMusicActivity(
    String title,
  ) {
    _addActivity(
      title: title,
      action: 'Played music',
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // NEXT EPISODE
  // ---------------------------------------------------------------------------

  String? getNextEpisode(
    String mediaId,
  ) {
    return nextEpisodes[mediaId];
  }

  /// Performs `setNextEpisode` for this feature. Update this documentation when its contract changes.
  void setNextEpisode(
    String mediaId,
    String episodeTitle,
  ) {
    nextEpisodes[mediaId] =
        episodeTitle;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // RESET
  // ---------------------------------------------------------------------------

  /// Performs `reset` for this feature. Update this documentation when its contract changes.
  void reset() {
    backendApi.clearToken();

    currentAccount = null;
    currentProfile = null;

    library.clear();
    watched.clear();
    liked.clear();
    disliked.clear();

    activity.clear();
    groupMessages.clear();
    wishlist.clear();
    groupWatchSessions.clear();

    playbackProgress.clear();
    nextEpisodes.clear();
    activeProfileIds.clear();

    recommendations.clear();
    recommendationsLoading = false;
    recommendationsError = null;

    groupRecommendations.clear();
    groupRecommendationsLoading =
        false;
    groupRecommendationsError = null;

    wishlist.clear();
    groupWishlistLoading = false;
    groupWishlistError = null;

    groupWatchLoading = false;
    groupWatchError = null;
    activeGroupWatchSessionId = null;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GROUP RECOMMENDATION HELPERS
  // ---------------------------------------------------------------------------

  /// Performs `_profileNameForId` for this feature. Update this documentation when its contract changes.
  String _profileNameForId(
    String profileId,
  ) {
    final account = currentAccount;

    if (account != null) {
      for (final profile
          in account.profiles) {
        if (profile.id == profileId) {
          return profile.name;
        }
      }
    }

    if (currentProfile?.id ==
        profileId) {
      return currentProfile!.name;
    }

    return 'Profile';
  }

  /// Performs `_accountHasProfile` for this feature. Update this documentation when its contract changes.
  bool _accountHasProfile(
    String profileId,
  ) {
    final account = currentAccount;

    if (account == null) {
      return false;
    }

    return account.profiles.any(
      (profile) =>
          profile.id == profileId,
    );
  }

  /// Performs `_intFromValue` for this feature. Update this documentation when its contract changes.
  int _intFromValue(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  /// Performs `_doubleFromValue` for this feature. Update this documentation when its contract changes.
  double _doubleFromValue(
    dynamic value, {
    required double fallback,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    final parsed =
        double.tryParse(
      value?.toString() ?? '',
    );

    return parsed ?? fallback;
  }

  /// Performs `_percentage` for this feature. Update this documentation when its contract changes.
  double _percentage(
    int votes,
    int total,
  ) {
    if (total <= 0) {
      return 0;
    }

    return (votes / total) * 100;
  }

  /// Performs `_formatPercentage` for this feature. Update this documentation when its contract changes.
  String _formatPercentage(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  // ---------------------------------------------------------------------------
  // GROUP WATCH HELPERS
  // ---------------------------------------------------------------------------

  GroupWatchSession
      _sessionFromResponse(
    Map<String, dynamic> response,
  ) {
    final sessionData =
        response['session'];

    if (sessionData is! Map) {
      throw BackendApiException(
        'The server returned an invalid Group Watch session.',
      );
    }

    return GroupWatchSession.fromJson(
      Map<String, dynamic>.from(
        sessionData,
      ),
      knownProfiles:
          currentAccount?.profiles ??
          const <Profile>[],
    );
  }

  /// Performs `_upsertGroupWatchSession` for this feature. Update this documentation when its contract changes.
  void _upsertGroupWatchSession(
    GroupWatchSession session,
  ) {
    if (session.id.isEmpty) {
      return;
    }

    final index =
        groupWatchSessions.indexWhere(
      (item) => item.id == session.id,
    );

    if (index == -1) {
      groupWatchSessions.insert(
        0,
        session,
      );
      return;
    }

    groupWatchSessions[index] =
        session;
  }

  /// Performs `_backendMediaType` for this feature. Update this documentation when its contract changes.
  String _backendMediaType(
    String type,
  ) {
    final cleaned =
        type.trim().toLowerCase();

    if (cleaned == 'tvshow' ||
        cleaned == 'tv_show' ||
        cleaned == 'tv show' ||
        cleaned == 'series' ||
        cleaned == 'episode') {
      return 'tvShow';
    }

    return 'movie';
  }

  /// Performs `_pauseReasonDisplay` for this feature. Update this documentation when its contract changes.
  String _pauseReasonDisplay(
    String reason,
  ) {
    final cleaned =
        reason.trim();

    switch (cleaned.toLowerCase()) {
      case 'voy a cargar':
        return '🔋 Voy a cargar';

      case 'voy por un snack':
        return '🍿 Voy por un snack';

      case 'otro':
        return '💬 Otro';

      default:
        return '💬 $cleaned';
    }
  }


  // ---------------------------------------------------------------------------
  // COLLECTIONS
  // ---------------------------------------------------------------------------

  CollectionPreferences get currentCollectionPreferences {
    final profileId = currentProfile?.id ?? 'default';
    return collectionPreferencesByProfile.putIfAbsent(profileId, () => CollectionPreferences());
  }

  /// Performs `updateCollectionPreferences` for this feature. Update this documentation when its contract changes.
  void updateCollectionPreferences(CollectionPreferences preferences) {
    final profileId = currentProfile?.id ?? 'default';
    collectionPreferencesByProfile[profileId] = preferences;
    notifyListeners();
  }

  /// Performs `seedCollections` for this feature. Update this documentation when its contract changes.
  void seedCollections() {
    _refreshAutomaticCollections();
  }

  MediaCollection createCollection({
    required String name, String description = '', bool shared = true, bool featured = false,
    bool automatic = false, String posterMode = 'First 4 Posters', String? customPosterUrl,
  }) {
    final collection = MediaCollection(
      id: _generateId('collection'), name: name.trim(), description: description.trim(),
      createdByProfileId: currentProfile?.id, isShared: shared, isFeatured: featured,
      isAutomatic: automatic, posterMode: posterMode, customPosterUrl: customPosterUrl,
      contributorProfileIds: shared ? <String>{...?currentAccount?.profiles.map((p) => p.id)} : <String>{},
    );
    // The creator always has edit/add rights.
    if (currentProfile?.id != null) collection.contributorProfileIds.add(currentProfile!.id);
    collections.add(collection);
    if (featured) featuredCollectionOrder.add(collection.id);
    addNotification(action: 'created collection "${collection.name}"');
    notifyListeners();
    return collection;
  }

  /// Performs `deleteCollection` for this feature. Update this documentation when its contract changes.
  void deleteCollection(String id) {
    collections.removeWhere((c) => c.id == id && !c.isOfficial && c.canCurrentProfileEdit());
    featuredCollectionOrder.remove(id);
    notifyListeners();
  }

  /// Performs `addToCollection` for this feature. Update this documentation when its contract changes.
  void addToCollection(String collectionId, String mediaId) {
    final matches = collections.where((x) => x.id == collectionId);
    if (matches.isEmpty) return;
    final c = matches.first;
    if (!c.canCurrentProfileAdd()) return;
    if (!c.mediaIds.contains(mediaId)) { c.mediaIds.add(mediaId); notifyListeners(); }
  }

  void addEpisodeToCollection(String collectionId, String episodeKey) {
    final matches = collections.where((x) => x.id == collectionId);
    if (matches.isEmpty) return;
    final c = matches.first;
    if (!c.canCurrentProfileAdd() || episodeKey.trim().isEmpty) return;
    if (!c.episodeKeys.contains(episodeKey)) c.episodeKeys.add(episodeKey);
    notifyListeners();
  }

  /// Performs `removeFromCollection` for this feature. Update this documentation when its contract changes.
  void removeFromCollection(String collectionId, String mediaId) {
    final matches = collections.where((x) => x.id == collectionId);
    if (matches.isEmpty) return;
    final c = matches.first;
    if (!c.canCurrentProfileEdit() || c.isAutomatic) return;
    c.mediaIds.remove(mediaId);
    notifyListeners();
  }

  /// Performs `addCollectionContributor` for this feature. Update this documentation when its contract changes.
  void addCollectionContributor(String collectionId, String profileId) {
    final c = collections.where((x) => x.id == collectionId).isEmpty ? null : collections.where((x) => x.id == collectionId).first;
    if (c == null || !c.canCurrentProfileEdit() || !c.isShared) return;
    c.contributorProfileIds.add(profileId);
    notifyListeners();
  }

  /// Performs `removeCollectionContributor` for this feature. Update this documentation when its contract changes.
  void removeCollectionContributor(String collectionId, String profileId) {
    final c = collections.where((x) => x.id == collectionId).isEmpty ? null : collections.where((x) => x.id == collectionId).first;
    if (c == null || !c.canCurrentProfileEdit() || profileId == c.createdByProfileId) return;
    c.contributorProfileIds.remove(profileId);
    notifyListeners();
  }

  /// Performs `toggleCollectionLike` for this feature. Update this documentation when its contract changes.
  void toggleCollectionLike(String collectionId) {
    final profileId = currentProfile?.id;
    if (profileId == null) return;
    final c = collections.where((x) => x.id == collectionId).isEmpty ? null : collections.where((x) => x.id == collectionId).first;
    if (c == null) return;
    if (!c.likedByProfileIds.add(profileId)) c.likedByProfileIds.remove(profileId);
    notifyListeners();
  }

  /// Performs `reorderCollectionSections` for this feature. Update this documentation when its contract changes.
  void reorderCollectionSections(List<String> order) {
    collectionSectionOrder..clear()..addAll(order);
    notifyListeners();
  }

  /// Performs `reorderFeaturedCollections` for this feature. Update this documentation when its contract changes.
  void reorderFeaturedCollections(List<String> order) {
    featuredCollectionOrder..clear()..addAll(order);
    notifyListeners();
  }

  /// Performs `_autoAssignFranchiseMetadata` for this feature. Update this documentation when its contract changes.
  void _autoAssignFranchiseMetadata(MediaItem media) {
    // Prefer authoritative metadata from an importer/provider when present.
    if (media.franchiseId != null && media.franchiseName != null) return;
    final detected = _knownFranchiseFor(media.title, media.releaseYear);
    if (detected == null) return;
    // MediaItem is intentionally immutable; automatic collection matching therefore
    // uses title/year matching too. Future provider metadata can populate these fields.
  }

  Map<String, dynamic>? _knownFranchiseFor(String title, int? year) {
    final t = _normalizeCollectionTitle(title);
    if (t.contains('back to the future')) return {'id':'back-to-the-future','name':'Back to the Future Trilogy','type':'Trilogy','expected':3};
    if (t == 'ted' || t.startsWith('ted ')) return {'id':'ted','name':'Ted Collection','type':'Duology','expected':2};
    if (RegExp(r'^harry potter').hasMatch(t)) return {'id':'harry-potter','name':'Harry Potter Collection','type':'Saga','expected':8};
    if (t.contains('twilight')) return {'id':'twilight','name':'Twilight Saga Collection','type':'Saga','expected':5};
    if (t.contains('jurassic park') || t.contains('jurassic world')) return {'id':'jurassic','name':'Jurassic Park / Jurassic World Collection','type':'Franchise','expected':7};
    return null;
  }

  /// Performs `_normalizeCollectionTitle` for this feature. Update this documentation when its contract changes.
  String _normalizeCollectionTitle(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// Performs `_refreshAutomaticCollections` for this feature. Update this documentation when its contract changes.
  void _refreshAutomaticCollections() {
    final definitions = <Map<String, dynamic>>[
      {'id':'back-to-the-future','name':'Back to the Future Trilogy','type':'Trilogy','expected':3, 'match': (MediaItem m) => _normalizeCollectionTitle(m.title).contains('back to the future')},
      {'id':'ted','name':'Ted Collection','type':'Duology','expected':2, 'match': (MediaItem m) => _normalizeCollectionTitle(m.title) == 'ted' || _normalizeCollectionTitle(m.title).startsWith('ted ')},
      {'id':'harry-potter','name':'Harry Potter Collection','type':'Saga','expected':8, 'match': (MediaItem m) => RegExp(r'^harry potter').hasMatch(_normalizeCollectionTitle(m.title))},
      {'id':'twilight','name':'Twilight Saga Collection','type':'Saga','expected':5, 'match': (MediaItem m) => _normalizeCollectionTitle(m.title).contains('twilight')},
      {'id':'jurassic','name':'Jurassic Park / Jurassic World Collection','type':'Franchise','expected':7, 'match': (MediaItem m) => _normalizeCollectionTitle(m.title).contains('jurassic park') || _normalizeCollectionTitle(m.title).contains('jurassic world')},
    ];
    for (final definition in definitions) {
      final matches = library.where((m) => (definition['match'] as bool Function(MediaItem))(m)).toList();
      if (matches.length < (definition['expected'] as int)) continue;
      var existing = collections.where((c) => c.isAutomatic && c.automaticFranchiseId == definition['id']);
      final collection = existing.isEmpty ? MediaCollection(
        id: _generateId('collection'), name: definition['name'] as String, isOfficial: true, isAutomatic: true,
        isFeatured: true, isShared: true, automaticFranchiseId: definition['id'] as String,
        automaticFranchiseType: definition['type'] as String, contributorProfileIds: <String>{...?currentAccount?.profiles.map((p) => p.id)},
      ) : existing.first;
      if (existing.isEmpty) { collections.add(collection); featuredCollectionOrder.add(collection.id); }
      collection.mediaIds..clear()..addAll(matches.map((m) => m.id));
    }
  }
  // ---------------------------------------------------------------------------
  // ID GENERATION
  // ---------------------------------------------------------------------------

  /// Performs `_generateId` for this feature. Update this documentation when its contract changes.
  String _generateId(
    String prefix,
  ) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// -----------------------------------------------------------------------------
// GROUP WATCH / JSON HELPERS
// -----------------------------------------------------------------------------

DateTime? _dateTimeFromJson(
  dynamic value,
) {
  if (value is DateTime) {
    return value;
  }

  if (value == null) {
    return null;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}

double _doubleFromJson(
  dynamic value,
) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

Profile? _profileFromList(
  List<Profile> profiles,
  String profileId,
) {
  for (final profile in profiles) {
    if (profile.id == profileId) {
      return profile;
    }
  }

  return null;
}
// -----------------------------------------------------------------------------
// DETAILS CUSTOMIZATION
// -----------------------------------------------------------------------------

class DetailsCustomization {
  bool showPoster;
  bool showTitle;
  bool showMetadata;
  bool showOwnership;
  bool showDescription;
  bool showSeasons;
  bool showPlay;
  bool showTrailer;
  bool showGroupWatch;
  bool showAudioSubtitles;
  bool showReactions;
  bool showInformation;
  bool showLibrary;

  bool showReleaseYear;
  bool showRating;
  bool showContentRating;
  bool showRuntime;

  String posterStyle;
  String posterPosition;
  String posterSize;
  String titleAlignment;
  String buttonAlignment;
  String informationAlignment;
  String seasonPlacement;
  String seasonOrder;
  String seasonSelectorStyle;
  String episodeNaming;

  List<String> sectionOrder;

  DetailsCustomization({
    this.showPoster = true,
    this.showTitle = true,
    this.showMetadata = true,
    this.showOwnership = true,
    this.showDescription = true,
    this.showSeasons = true,
    this.showPlay = true,
    this.showTrailer = true,
    this.showGroupWatch = true,
    this.showAudioSubtitles = true,
    this.showReactions = true,
    this.showInformation = true,
    this.showLibrary = true,
    this.showReleaseYear = true,
    this.showRating = true,
    this.showContentRating = true,
    this.showRuntime = true,
    this.posterStyle = 'Standard',
    this.posterPosition = 'Center',
    this.posterSize = 'Medium',
    this.titleAlignment = 'Left',
    this.buttonAlignment = 'Left',
    this.informationAlignment = 'Left',
    this.seasonPlacement = 'Center',
    this.seasonOrder = 'Top to Bottom',
    this.seasonSelectorStyle = 'Buttons',
    this.episodeNaming = 'Actual Title',
    List<String>? sectionOrder,
  }) : sectionOrder = sectionOrder ??
            [
              'Poster',
              'Title',
              'Metadata',
              'Ownership',
              'Description',
              'Seasons',
              'Play',
              'Trailer',
              'Group Watch',
              'Reviews',
              'Audio & Subtitles',
              'Reactions',
              'Information',
              'Library',
            ];

  DetailsCustomization copy() {
    return DetailsCustomization(
      showPoster: showPoster,
      showTitle: showTitle,
      showMetadata: showMetadata,
      showOwnership: showOwnership,
      showDescription: showDescription,
      showSeasons: showSeasons,
      showPlay: showPlay,
      showTrailer: showTrailer,
      showGroupWatch: showGroupWatch,
      showAudioSubtitles: showAudioSubtitles,
      showReactions: showReactions,
      showInformation: showInformation,
      showLibrary: showLibrary,
      showReleaseYear: showReleaseYear,
      showRating: showRating,
      showContentRating: showContentRating,
      showRuntime: showRuntime,
      posterStyle: posterStyle,
      posterPosition: posterPosition,
      posterSize: posterSize,
      titleAlignment: titleAlignment,
      buttonAlignment: buttonAlignment,
      informationAlignment: informationAlignment,
      seasonPlacement: seasonPlacement,
      seasonOrder: seasonOrder,
      seasonSelectorStyle: seasonSelectorStyle,
      episodeNaming: episodeNaming,
      sectionOrder: List<String>.from(sectionOrder),
    );
  }
}

class DetailsCustomizationStore {
  DetailsCustomizationStore._();

  static final Map<String, DetailsCustomization> _settings =
      <String, DetailsCustomization>{};
  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    const prefix = 'details_customization_';
    for (final key in _prefs!.getKeys().where((k) => k.startsWith(prefix))) {
      final raw = _prefs!.getString(key);
      if (raw == null) continue;
      try {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _settings[key.substring(prefix.length)] = _fromJson(map);
      } catch (_) {}
    }
  }

  static DetailsCustomization settingsFor(Profile? profile) {
    final key = profile?.id ?? 'default';
    return _settings.putIfAbsent(key, () => DetailsCustomization()).copy();
  }

  static void apply(Profile? profile, DetailsCustomization value) {
    final key = profile?.id ?? 'default';
    final copy = value.copy();
    _settings[key] = copy;
    _prefs?.setString('details_customization_$key', jsonEncode(_toJson(copy)));
  }

  static void removeProfile(Profile profile) {
    _settings.remove(profile.id);
    _prefs?.remove('details_customization_${profile.id}');
  }

  static void clear() {
    for (final key in _settings.keys) {
      _prefs?.remove('details_customization_$key');
    }
    _settings.clear();
  }

  static Map<String, dynamic> _toJson(DetailsCustomization v) => {
    'showPoster': v.showPoster, 'showTitle': v.showTitle, 'showMetadata': v.showMetadata,
    'showOwnership': v.showOwnership, 'showDescription': v.showDescription, 'showSeasons': v.showSeasons,
    'showPlay': v.showPlay, 'showTrailer': v.showTrailer, 'showGroupWatch': v.showGroupWatch,
    'showAudioSubtitles': v.showAudioSubtitles, 'showReactions': v.showReactions, 'showInformation': v.showInformation,
    'showLibrary': v.showLibrary, 'showReleaseYear': v.showReleaseYear, 'showRating': v.showRating,
    'showContentRating': v.showContentRating, 'showRuntime': v.showRuntime, 'posterStyle': v.posterStyle,
    'posterPosition': v.posterPosition, 'posterSize': v.posterSize, 'titleAlignment': v.titleAlignment,
    'buttonAlignment': v.buttonAlignment, 'informationAlignment': v.informationAlignment, 'seasonPlacement': v.seasonPlacement,
    'seasonOrder': v.seasonOrder, 'seasonSelectorStyle': v.seasonSelectorStyle, 'episodeNaming': v.episodeNaming,
    'sectionOrder': v.sectionOrder,
  };

  static DetailsCustomization _fromJson(Map<String, dynamic> m) => DetailsCustomization(
    showPoster: m['showPoster'] == false ? false : true, showTitle: m['showTitle'] == false ? false : true,
    showMetadata: m['showMetadata'] == false ? false : true, showOwnership: m['showOwnership'] == false ? false : true,
    showDescription: m['showDescription'] == false ? false : true, showSeasons: m['showSeasons'] == false ? false : true,
    showPlay: m['showPlay'] == false ? false : true, showTrailer: m['showTrailer'] == false ? false : true,
    showGroupWatch: m['showGroupWatch'] == false ? false : true, showAudioSubtitles: m['showAudioSubtitles'] == false ? false : true,
    showReactions: m['showReactions'] == false ? false : true, showInformation: m['showInformation'] == false ? false : true,
    showLibrary: m['showLibrary'] == false ? false : true, showReleaseYear: m['showReleaseYear'] == false ? false : true,
    showRating: m['showRating'] == false ? false : true, showContentRating: m['showContentRating'] == false ? false : true,
    showRuntime: m['showRuntime'] == false ? false : true, posterStyle: m['posterStyle']?.toString() ?? 'Standard',
    posterPosition: m['posterPosition']?.toString() ?? 'Center', posterSize: m['posterSize']?.toString() ?? 'Medium',
    titleAlignment: m['titleAlignment']?.toString() ?? 'Left', buttonAlignment: m['buttonAlignment']?.toString() ?? 'Left',
    informationAlignment: m['informationAlignment']?.toString() ?? 'Left', seasonPlacement: m['seasonPlacement']?.toString() ?? 'Center',
    seasonOrder: m['seasonOrder']?.toString() ?? 'Top to Bottom', seasonSelectorStyle: m['seasonSelectorStyle']?.toString() ?? 'Buttons',
    episodeNaming: m['episodeNaming']?.toString() ?? 'Actual Title',
    sectionOrder: (m['sectionOrder'] is List) ? List<String>.from(m['sectionOrder'] as List) : null,
  );
}
