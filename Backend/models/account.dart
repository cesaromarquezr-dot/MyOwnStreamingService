import 'profile.dart';
import 'subscription.dart';

class Account {
  final String id;

  String username;
  String email;

  // Prototype only.
  //
  // DO NOT use plain-text passwords in production.
  // This will be replaced with secure password hashing
  // before production use.
  String password;

  Subscription? subscription;

  // ------------------------------------------------------------
  // PROFILES
  // ------------------------------------------------------------
  //
  // Every profile has its own:
  // - owned media
  // - watched media
  // - liked media
  // - disliked media
  // - watch progress
  // - watch history
  //
  // This keeps profiles completely independent.
  //
  final List<Profile> profiles;

  static const int maxProfiles = 7;

  // ------------------------------------------------------------
  // GROUP WISHLIST
  // ------------------------------------------------------------
  //
  // The group wishlist belongs to the ACCOUNT rather than an
  // individual profile.
  //
  // Catalog media continues to use wishlistMediaIds.
  //
  // Group recommendations that do NOT exist in the media catalog
  // use wishlistRecommendationIds.
  //
  // This allows the group recommendation system to support titles
  // entered manually by users.
  //
  final List<String> wishlistMediaIds;

  /// IDs of approved GroupRecommendation objects that were added
  /// to the shared group wishlist.
  ///
  /// This is used when a recommendation does not have a catalog
  /// mediaId.
  final List<String> wishlistRecommendationIds;

  Account({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    this.subscription,
    List<Profile>? profiles,
    List<String>? wishlistMediaIds,
    List<String>? wishlistRecommendationIds,
  })  : profiles = profiles ?? [],
        wishlistMediaIds = wishlistMediaIds ?? [],
        wishlistRecommendationIds =
            wishlistRecommendationIds ?? [];

  // ------------------------------------------------------------
  // SUBSCRIPTION
  // ------------------------------------------------------------

  bool get hasActiveSubscription {
    subscription?.expireIfNeeded();

    return subscription?.isCurrentlyActive ?? false;
  }

  // ------------------------------------------------------------
  // PROFILE HELPERS
  // ------------------------------------------------------------

  bool get canAddProfile {
    return profiles.length < maxProfiles;
  }

  Profile? getProfileById(String profileId) {
    final String id = profileId.trim();

    if (id.isEmpty) {
      return null;
    }

    for (final Profile profile in profiles) {
      if (profile.id == id) {
        return profile;
      }
    }

    return null;
  }

  Profile? getProfileByName(String name) {
    final String normalizedName =
        name.trim().toLowerCase();

    if (normalizedName.isEmpty) {
      return null;
    }

    for (final Profile profile in profiles) {
      if (profile.name.trim().toLowerCase() ==
          normalizedName) {
        return profile;
      }
    }

    return null;
  }

  bool hasProfile(String profileId) {
    return getProfileById(profileId) != null;
  }

  bool addExistingProfile(Profile profile) {
    if (!canAddProfile) {
      return false;
    }

    if (profile.id.trim().isEmpty) {
      return false;
    }

    if (hasProfile(profile.id)) {
      return false;
    }

    profiles.add(profile);

    return true;
  }

  bool removeProfile(String profileId) {
    final String id = profileId.trim();

    if (id.isEmpty) {
      return false;
    }

    final int originalLength = profiles.length;

    profiles.removeWhere(
      (profile) => profile.id == id,
    );

    return profiles.length != originalLength;
  }

  // ------------------------------------------------------------
  // PROFILE MEDIA HELPERS
  // ------------------------------------------------------------

  bool profileOwnsMedia(
    String profileId,
    String mediaId,
  ) {
    final Profile? profile =
        getProfileById(profileId);

    if (profile == null) {
      return false;
    }

    return profile.ownsMedia(mediaId);
  }

  bool profileHasWatchedMedia(
    String profileId,
    String mediaId,
  ) {
    final Profile? profile =
        getProfileById(profileId);

    if (profile == null) {
      return false;
    }

    return profile.hasWatched(mediaId);
  }

  bool profileHasLikedMedia(
    String profileId,
    String mediaId,
  ) {
    final Profile? profile =
        getProfileById(profileId);

    if (profile == null) {
      return false;
    }

    return profile.hasLiked(mediaId);
  }

  bool profileHasDislikedMedia(
    String profileId,
    String mediaId,
  ) {
    final Profile? profile =
        getProfileById(profileId);

    if (profile == null) {
      return false;
    }

    return profile.hasDisliked(mediaId);
  }

  // ------------------------------------------------------------
  // GROUP WISHLIST - CATALOG MEDIA
  // ------------------------------------------------------------

  bool isInWishlist(String mediaId) {
    final String id = mediaId.trim();

    if (id.isEmpty) {
      return false;
    }

    return wishlistMediaIds.contains(id);
  }

  bool addToWishlist(String mediaId) {
    final String id = mediaId.trim();

    if (id.isEmpty) {
      return false;
    }

    if (isInWishlist(id)) {
      return false;
    }

    wishlistMediaIds.add(id);

    return true;
  }

  bool removeFromWishlist(String mediaId) {
    final String id = mediaId.trim();

    if (id.isEmpty) {
      return false;
    }

    final int originalLength =
        wishlistMediaIds.length;

    wishlistMediaIds.remove(id);

    return wishlistMediaIds.length !=
        originalLength;
  }

  // ------------------------------------------------------------
  // GROUP WISHLIST - RECOMMENDATIONS
  // ------------------------------------------------------------

  /// Returns true if an approved group recommendation is already
  /// in the shared wishlist.
  bool isRecommendationInWishlist(
    String recommendationId,
  ) {
    final String id = recommendationId.trim();

    if (id.isEmpty) {
      return false;
    }

    return wishlistRecommendationIds.contains(id);
  }

  /// Adds an approved group recommendation to the shared
  /// wishlist.
  ///
  /// This is used for recommendations that do not have a catalog
  /// mediaId.
  bool addRecommendationToWishlist(
    String recommendationId,
  ) {
    final String id = recommendationId.trim();

    if (id.isEmpty) {
      return false;
    }

    if (isRecommendationInWishlist(id)) {
      return false;
    }

    wishlistRecommendationIds.add(id);

    return true;
  }

  /// Removes a recommendation from the shared wishlist.
  bool removeRecommendationFromWishlist(
    String recommendationId,
  ) {
    final String id = recommendationId.trim();

    if (id.isEmpty) {
      return false;
    }

    final int originalLength =
        wishlistRecommendationIds.length;

    wishlistRecommendationIds.remove(id);

    return wishlistRecommendationIds.length !=
        originalLength;
  }

  // ------------------------------------------------------------
  // ACQUIRE GROUP WISHLIST ITEM - CATALOG MEDIA
  // ------------------------------------------------------------
  //
  // Removes the media from the shared account wishlist and,
  // optionally, adds it to a specific profile's library.
  //
  bool markWishlistItemAcquired(
    String mediaId, {
    String? profileId,
  }) {
    final String id = mediaId.trim();

    if (id.isEmpty) {
      return false;
    }

    final bool removed =
        removeFromWishlist(id);

    if (profileId != null &&
        profileId.trim().isNotEmpty) {
      final Profile? profile =
          getProfileById(profileId);

      profile?.addOwnedMedia(id);
    }

    return removed;
  }

  // ------------------------------------------------------------
  // JSON
  // ------------------------------------------------------------

  Map<String, dynamic> toJson({
    bool includeSensitiveData = false,
  }) {
    final Map<String, dynamic> data =
        <String, dynamic>{
      'id': id,
      'username': username,
      'email': email,

      'profiles': profiles
          .map(
            (Profile profile) =>
                profile.toJson(),
          )
          .toList(),

      'profileCount':
          profiles.length,

      'maxProfiles':
          maxProfiles,

      // Shared account-level group wishlist
      // containing catalog media.
      'wishlistMediaIds':
          wishlistMediaIds,

      // Shared account-level group wishlist
      // containing approved recommendations that
      // may not exist in the catalog.
      'wishlistRecommendationIds':
          wishlistRecommendationIds,

      'subscription':
          subscription?.toJson(),

      'hasActiveSubscription':
          hasActiveSubscription,
    };

    if (includeSensitiveData) {
      data['password'] = password;
    }

    return data;
  }
}