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
  // When a group recommendation receives a majority YES vote,
  // the recommendation service adds the media ID here.
  //
  // The media is NOT automatically owned by every profile.
  //
  // When someone acquires/rips the media, it can be removed from
  // this shared wishlist and added to the selected profile's
  // personal library.
  //
  final List<String> wishlistMediaIds;

  Account({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    this.subscription,
    List<Profile>? profiles,
    List<String>? wishlistMediaIds,
  })  : profiles = profiles ?? [],
        wishlistMediaIds =
            wishlistMediaIds ?? [];

  // ------------------------------------------------------------
  // SUBSCRIPTION
  // ------------------------------------------------------------

  bool get hasActiveSubscription {
    subscription?.expireIfNeeded();

    return subscription?.isCurrentlyActive ??
        false;
  }

  // ------------------------------------------------------------
  // PROFILE HELPERS
  // ------------------------------------------------------------

  bool get canAddProfile {
    return profiles.length < maxProfiles;
  }

  Profile? getProfileById(String profileId) {
    final id = profileId.trim();

    if (id.isEmpty) {
      return null;
    }

    for (final profile in profiles) {
      if (profile.id == id) {
        return profile;
      }
    }

    return null;
  }

  Profile? getProfileByName(String name) {
    final normalizedName =
        name.trim().toLowerCase();

    if (normalizedName.isEmpty) {
      return null;
    }

    for (final profile in profiles) {
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
    final id = profileId.trim();

    if (id.isEmpty) {
      return false;
    }

    final originalLength =
        profiles.length;

    profiles.removeWhere(
      (profile) => profile.id == id,
    );

    return profiles.length !=
        originalLength;
  }

  // ------------------------------------------------------------
  // PROFILE MEDIA HELPERS
  // ------------------------------------------------------------

  bool profileOwnsMedia(
    String profileId,
    String mediaId,
  ) {
    final profile =
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
    final profile =
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
    final profile =
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
    final profile =
        getProfileById(profileId);

    if (profile == null) {
      return false;
    }

    return profile.hasDisliked(mediaId);
  }

  // ------------------------------------------------------------
  // GROUP WISHLIST
  // ------------------------------------------------------------

  bool isInWishlist(String mediaId) {
    final id = mediaId.trim();

    if (id.isEmpty) {
      return false;
    }

    return wishlistMediaIds.contains(id);
  }

  bool addToWishlist(String mediaId) {
    final id = mediaId.trim();

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
    final id = mediaId.trim();

    if (id.isEmpty) {
      return false;
    }

    final originalLength =
        wishlistMediaIds.length;

    wishlistMediaIds.remove(id);

    return wishlistMediaIds.length !=
        originalLength;
  }

  // ------------------------------------------------------------
  // ACQUIRE GROUP WISHLIST ITEM
  // ------------------------------------------------------------
  //
  // Removes the media from the shared account wishlist and,
  // optionally, adds it to a specific profile's library.
  //
  bool markWishlistItemAcquired(
    String mediaId, {
    String? profileId,
  }) {
    final id = mediaId.trim();

    if (id.isEmpty) {
      return false;
    }

    final removed =
        removeFromWishlist(id);

    if (profileId != null &&
        profileId.trim().isNotEmpty) {
      final profile =
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
    final data =
        <String, dynamic>{
      'id': id,
      'username': username,
      'email': email,

      'profiles': profiles
          .map(
            (profile) =>
                profile.toJson(),
          )
          .toList(),

      'profileCount':
          profiles.length,

      'maxProfiles':
          maxProfiles,

      // Shared account-level group wishlist.
      'wishlistMediaIds':
          wishlistMediaIds,

      'subscription':
          subscription?.toJson(),

      'hasActiveSubscription':
          hasActiveSubscription,
    };

    if (includeSensitiveData) {
      data['password'] =
          password;
    }

    return data;
  }
}