import 'profile.dart';
import 'subscription.dart';

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

  // Account-level shared wishlist.
  final List<String> wishlistMediaIds;
  final List<String> wishlistRecommendationIds;

  // Account-wide server storage. Every profile shares the same library/storage.
  int storageLimitBytes;
  int storageUsedBytes;
  bool storageRequestPending;
  DateTime? storageRequestAt;

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
    List<String>? wishlistMediaIds,
    List<String>? wishlistRecommendationIds,
    this.storageLimitBytes = 1000000000000,
    this.storageUsedBytes = 0,
    this.storageRequestPending = false,
    this.storageRequestAt,
    this.termsVersionAccepted = '',
    this.privacyVersionAccepted = '',
    this.acceptableUseVersionAccepted = '',
    this.legalAcceptedAt,
  })  : profiles = profiles ?? [],
        wishlistMediaIds =
            wishlistMediaIds ?? [],
        wishlistRecommendationIds =
            wishlistRecommendationIds ?? [];

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

  bool hasProfile(
    String name,
  ) {
    return getProfileByName(name) != null;
  }

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
  // WISHLIST
  // ---------------------------------------------------------------------------

  bool hasWishlistMedia(
    String mediaId,
  ) {
    return wishlistMediaIds.contains(mediaId);
  }

  bool hasWishlistRecommendation(
    String recommendationId,
  ) {
    return wishlistRecommendationIds.contains(
      recommendationId,
    );
  }

  void addWishlistMedia(
    String mediaId,
  ) {
    if (!wishlistMediaIds.contains(mediaId)) {
      wishlistMediaIds.add(mediaId);
    }
  }

  void removeWishlistMedia(
    String mediaId,
  ) {
    wishlistMediaIds.remove(mediaId);
  }

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

  void removeWishlistRecommendation(
    String recommendationId,
  ) {
    wishlistRecommendationIds.remove(
      recommendationId,
    );
  }

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