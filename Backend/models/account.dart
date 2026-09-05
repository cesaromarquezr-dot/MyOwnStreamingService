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

  // Every profile has its own:
  // - owned media
  // - watched media
  // - liked media
  // - disliked media
  // - watch progress
  // - watch history
  //
  // This keeps profiles completely independent.
  final List<Profile> profiles;

  static const int maxProfiles = 7;

  Account({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    this.subscription,
    List<Profile>? profiles,
  }) : profiles = profiles ?? [];

  // ------------------------------------------------------------
  // SUBSCRIPTION
  // ------------------------------------------------------------

  bool get hasActiveSubscription {
    subscription?.expireIfNeeded();

    return subscription?.isCurrentlyActive ?? false;
  }

  // ------------------------------------------------------------
  // PROFILE LIMIT
  // ------------------------------------------------------------

  bool get canAddProfile {
    return profiles.length < maxProfiles;
  }

  // ------------------------------------------------------------
  // PROFILE LOOKUPS
  // ------------------------------------------------------------

  Profile? getProfileById(
    String profileId,
  ) {
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

  Profile? getProfileByName(
    String name,
  ) {
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

  // ------------------------------------------------------------
  // PROFILE MANAGEMENT
  // ------------------------------------------------------------

  bool addExistingProfile(
    Profile profile,
  ) {
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

  bool removeProfile(
    String profileId,
  ) {
    final id = profileId.trim();

    if (id.isEmpty) {
      return false;
    }

    final originalLength =
        profiles.length;

    profiles.removeWhere(
      (profile) => profile.id == id,
    );

    return profiles.length != originalLength;
  }

  // ------------------------------------------------------------
  // PROFILE STATE
  // ------------------------------------------------------------

  //
  // These helpers make it clear that media state belongs to
  // the selected profile, not to the account as a whole.
  //

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

      'profiles': profiles.map(
        (profile) {
          return profile.toJson();
        },
      ).toList(),

      'profileCount':
          profiles.length,

      'maxProfiles':
          maxProfiles,

      'subscription':
          subscription?.toJson(),

      'hasActiveSubscription':
          hasActiveSubscription,
    };

    // Never expose the password during normal API responses.
    //
    // This parameter exists only for controlled internal/prototype
    // use and will eventually become unnecessary once passwords
    // are stored as secure hashes.
    if (includeSensitiveData) {
      data['password'] = password;
    }

    return data;
  }
}