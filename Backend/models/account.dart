// FILE: `Backend/models/account.dart`.
// Purpose: Implements the account portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'profile.dart';
import 'subscription.dart';

/// Implements the `Account` class for this feature or UI component.
class Account {
  final String id;

  String username;
  String email;

  // SECURITY:
  // This contains an Argon2id password hash.
  //
  // It must NEVER contain the user's plaintext password.
  String passwordHash;

  // Security question used to verify suspicious sign-ins.
  String securityQuestion;
  String securityAnswerHash;

  Subscription? subscription;

  final List<Profile> profiles;

  static const int maxProfiles = 7;

  // Account-wide server library. These IDs identify media physically stored
  // on the account's server; every active profile may stream them.
  final List<String> sharedMediaIds;

  // Account-level shared wishlist.
  final List<String> wishlistMediaIds;
  final List<String> wishlistRecommendationIds;

  // Account-wide server storage. Every profile shares the same library/storage.
  int storageLimitBytes;
  int storageUsedBytes;
  bool storageRequestPending;
  DateTime? storageRequestAt;
  int storageRequestedTerabytes;
  double storageRequestFeeUsd;
  String storageRequestStatus;
  final List<Map<String, dynamic>> notifications;

  // Versioned legal acceptance recorded at account creation.
  String termsVersionAccepted;
  String privacyVersionAccepted;
  String acceptableUseVersionAccepted;
  DateTime? legalAcceptedAt;

  Account({
    required this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    this.securityQuestion = '',
    this.securityAnswerHash = '',
    this.subscription,
    List<Profile>? profiles,
    List<String>? sharedMediaIds,
    List<String>? wishlistMediaIds,
    List<String>? wishlistRecommendationIds,
    this.storageLimitBytes = 1000000000000,
    this.storageUsedBytes = 0,
    this.storageRequestPending = false,
    this.storageRequestAt,
    this.storageRequestedTerabytes = 0,
    this.storageRequestFeeUsd = 0,
    this.storageRequestStatus = 'none',
    List<Map<String, dynamic>>? notifications,
    this.termsVersionAccepted = '',
    this.privacyVersionAccepted = '',
    this.acceptableUseVersionAccepted = '',
    this.legalAcceptedAt,
  })  : profiles = profiles ?? [],
        sharedMediaIds = sharedMediaIds ?? [],
        wishlistMediaIds = wishlistMediaIds ?? [],
        wishlistRecommendationIds =
            wishlistRecommendationIds ?? [],
        notifications = notifications ?? [];

  /// Adds an in-app notification that can be shown on phone, TV, web, and desktop clients.
  void addNotification(String title, String message) {
    notifications.insert(0, {
      'id': '${DateTime.now().microsecondsSinceEpoch}',
      'title': title,
      'message': message,
      'createdAt': DateTime.now().toIso8601String(),
      'read': false,
    });
    if (notifications.length > 100) notifications.removeLast();
  }

  // ---------------------------------------------------------------------------
  // PROFILE MANAGEMENT
  // ---------------------------------------------------------------------------

  bool get canAddProfile {
    return profiles.length < maxProfiles;
  }

  Profile? getProfileById(
    String profileId,
  ) {
    for (final profile in profiles) {
      if (profile.id == profileId) {
        return profile;
      }
    }

    return null;
  }

  Profile? getProfileByName(
    String name,
  ) {
    final cleanName = name.trim().toLowerCase();

    for (final profile in profiles) {
      if (profile.name.trim().toLowerCase() ==
          cleanName) {
        return profile;
      }
    }

    return null;
  }

  /// Performs `hasProfile` for this feature. Update this documentation when its contract changes.
  bool hasProfile(
    String name,
  ) {
    return getProfileByName(name) != null;
  }

  /// Performs `addExistingProfile` for this feature. Update this documentation when its contract changes.
  void addExistingProfile(
    Profile profile,
  ) {
    if (!canAddProfile) {
      throw Exception(
        'Maximum number of profiles reached.',
      );
    }

    if (profiles.any(
      (existing) => existing.id == profile.id,
    )) {
      throw Exception(
        'A profile with this ID already exists.',
      );
    }

    if (hasProfile(profile.name)) {
      throw Exception(
        'A profile with this name already exists.',
      );
    }

    profiles.add(profile);
  }

  /// Performs `removeProfile` for this feature. Update this documentation when its contract changes.
  void removeProfile(String profileId) {
  final index = profiles.indexWhere(
    (profile) => profile.id == profileId,
  );

  if (index == -1) {
    throw Exception(
      'Profile not found.',
    );
  }

  profiles.removeAt(index);
}

  // ---------------------------------------------------------------------------
  // SHARED SERVER LIBRARY
  // ---------------------------------------------------------------------------

  /// Returns whether media is present in this account's shared server library.
  bool hasSharedMedia(String mediaId) => sharedMediaIds.contains(mediaId);

  /// Adds media to the account-wide server library so every profile can stream it.
  void addSharedMedia(String mediaId) {
    final clean = mediaId.trim();
    if (clean.isNotEmpty && !sharedMediaIds.contains(clean)) {
      sharedMediaIds.add(clean);
    }
  }

  /// Removes media from the account-wide server library index.
  void removeSharedMedia(String mediaId) => sharedMediaIds.remove(mediaId);

  // ---------------------------------------------------------------------------
  // WISHLIST
  // ---------------------------------------------------------------------------

  /// Performs `hasWishlistMedia` for this feature. Update this documentation when its contract changes.
  bool hasWishlistMedia(
    String mediaId,
  ) {
    return wishlistMediaIds.contains(mediaId);
  }

  /// Performs `hasWishlistRecommendation` for this feature. Update this documentation when its contract changes.
  bool hasWishlistRecommendation(
    String recommendationId,
  ) {
    return wishlistRecommendationIds.contains(
      recommendationId,
    );
  }

  /// Performs `addWishlistMedia` for this feature. Update this documentation when its contract changes.
  void addWishlistMedia(
    String mediaId,
  ) {
    if (!wishlistMediaIds.contains(mediaId)) {
      wishlistMediaIds.add(mediaId);
    }
  }

  /// Performs `removeWishlistMedia` for this feature. Update this documentation when its contract changes.
  void removeWishlistMedia(
    String mediaId,
  ) {
    wishlistMediaIds.remove(mediaId);
  }

  /// Performs `addWishlistRecommendation` for this feature. Update this documentation when its contract changes.
  void addWishlistRecommendation(
    String recommendationId,
  ) {
    if (!wishlistRecommendationIds.contains(
      recommendationId,
    )) {
      wishlistRecommendationIds.add(
        recommendationId,
      );
    }
  }

  /// Performs `removeWishlistRecommendation` for this feature. Update this documentation when its contract changes.
  void removeWishlistRecommendation(
    String recommendationId,
  ) {
    wishlistRecommendationIds.remove(
      recommendationId,
    );
  }

  /// Performs `markWishlistItemAcquired` for this feature. Update this documentation when its contract changes.
  void markWishlistItemAcquired({
    String? mediaId,
    String? recommendationId,
    Profile? profile,
  }) {
    if (mediaId != null) {
      removeWishlistMedia(mediaId);

      if (profile != null &&
          !profile.ownsMedia(mediaId)) {
        profile.addOwnedMedia(mediaId);
      }
    }

    if (recommendationId != null) {
      removeWishlistRecommendation(
        recommendationId,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // SUBSCRIPTION
  // ---------------------------------------------------------------------------

  bool get hasActiveSubscription {
    subscription?.expireIfNeeded();

    return subscription?.isCurrentlyActive ??
        false;
  }

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson({
    bool includeSensitiveData = false,
  }) {
    final data = <String, dynamic>{
      'id': id,
      'username': username,
      'email': email,
      'securityQuestion': securityQuestion,

      'profiles': profiles
          .map(
            (profile) => profile.toJson(),
          )
          .toList(),

      'profileCount': profiles.length,
      'maxProfiles': maxProfiles,

      'sharedMediaIds': List<String>.from(sharedMediaIds),

      'wishlistMediaIds':
          List<String>.from(
        wishlistMediaIds,
      ),

      'wishlistRecommendationIds':
          List<String>.from(
        wishlistRecommendationIds,
      ),

      'subscription':
          subscription?.toJson(),

      'hasActiveSubscription':
          hasActiveSubscription,
      'storageLimitBytes': storageLimitBytes,
      'storageUsedBytes': storageUsedBytes,
      'storageRequestPending': storageRequestPending,
      'storageRequestAt': storageRequestAt?.toIso8601String(),
      'storageRequestedTerabytes': storageRequestedTerabytes,
      'storageRequestFeeUsd': storageRequestFeeUsd,
      'storageRequestStatus': storageRequestStatus,
      'notifications': notifications,
      'legalAccepted': termsVersionAccepted.isNotEmpty && privacyVersionAccepted.isNotEmpty && acceptableUseVersionAccepted.isNotEmpty,
      'termsVersionAccepted': termsVersionAccepted,
      'privacyVersionAccepted': privacyVersionAccepted,
      'acceptableUseVersionAccepted': acceptableUseVersionAccepted,
      'legalAcceptedAt': legalAcceptedAt?.toIso8601String(),
    };

    // SECURITY:
    // The password hash is intentionally excluded from normal API responses.
    //
    // This parameter exists only for tightly controlled internal/debug use.
    // It should not be used by HTTP routes.
    if (includeSensitiveData) {
      data['passwordHash'] = passwordHash;
    }

    return data;
  }
}
