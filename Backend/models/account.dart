// FILE: `Backend/models/account.dart`.
// Purpose: Implements the account portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Account represents the account/home-server boundary. Authentication
// credentials are maintained separately from public account/member data.
// The password hash below is retained for compatibility with the existing
// authentication implementation, but must never contain plaintext credentials.

import 'profile.dart';
import 'subscription.dart';

/// Represents a streaming-service account and its account-wide state.
///
/// An account owns the shared server library and account-level preferences.
/// Individual profiles provide the per-person viewing experience.
class Account {
final String id;

String username;
String email;

// SECURITY:
// This must contain an Argon2id password hash, never plaintext.
//
// New authentication flows should prefer MemberLoginRecord from
// account_member.dart so login identity can remain separate from the
// account itself. This field remains for compatibility with existing
// account/authentication persistence.
String passwordHash;

// Security question used to verify suspicious sign-ins.
String securityQuestion;

// SECURITY:
// Hash of the security answer. Never expose through normal API JSON.
String securityAnswerHash;

// MFA uses a short-lived email challenge.
// Only the challenge hash is stored.
bool mfaEnabled;
String mfaChallengeHash;
DateTime? mfaChallengeExpiresAt;

Subscription? subscription;

final List<Profile> profiles;

static const int maxProfiles = 7;

// Account-wide server library.
//
// These IDs identify media physically stored on the account's server.
// Every active profile may stream media in this shared library.
final List<String> sharedMediaIds;

// Account-level shared wishlist.
final List<String> wishlistMediaIds;
final List<String> wishlistRecommendationIds;

// Account-wide server storage.
// Every profile shares the same library/storage allocation.
int storageLimitBytes;
int storageUsedBytes;
bool storageRequestPending;
DateTime? storageRequestAt;
int storageRequestedTerabytes;
double storageRequestFeeUsd;
String storageRequestStatus;

// In-app notifications available to phone, TV, web, and desktop clients.
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
this.mfaEnabled = false,
this.mfaChallengeHash = '',
this.mfaChallengeExpiresAt,
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
wishlistRecommendationIds = wishlistRecommendationIds ?? [],
notifications = notifications ?? [];

// ---------------------------------------------------------------------------
// ACCOUNT IDENTITY
// ---------------------------------------------------------------------------

String get normalizedUsername {
return username.trim().toLowerCase();
}

String get normalizedEmail {
return email.trim().toLowerCase();
}

// ---------------------------------------------------------------------------
// NOTIFICATIONS
// ---------------------------------------------------------------------------

/// Adds an in-app notification that can be shown on phone, TV, web, and
/// desktop clients.
void addNotification(
String title,
String message,
) {
final now = DateTime.now();

notifications.insert(
  0,
  {
    'id': '${now.microsecondsSinceEpoch}',
    'title': title,
    'message': message,
    'createdAt': now.toIso8601String(),
    'read': false,
  },
);

if (notifications.length > 100) {
  notifications.removeLast();
}

}

/// Marks a notification as read.
///
/// Silently does nothing when the notification ID does not exist.
void markNotificationRead(
String notificationId,
) {
final index = notifications.indexWhere(
(notification) =>
notification['id']?.toString() == notificationId,
);

if (index == -1) {
  return;
}

notifications[index]['read'] = true;

}

/// Marks every notification as read.
void markAllNotificationsRead() {
for (final notification in notifications) {
notification['read'] = true;
}
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
  if (profile.name.trim().toLowerCase() == cleanName) {
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

/// Adds an existing profile to this account.
///
/// Profile IDs and profile names must both be unique within the account.
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

void removeProfile(
String profileId,
) {
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

/// Returns whether media is present in this account's shared server
/// library.
bool hasSharedMedia(
String mediaId,
) {
return sharedMediaIds.contains(mediaId);
}

/// Adds media to the account-wide server library so every profile can
/// stream it.
void addSharedMedia(
String mediaId,
) {
final clean = mediaId.trim();

if (clean.isNotEmpty && !sharedMediaIds.contains(clean)) {
  sharedMediaIds.add(clean);
}

}

/// Removes media from the account-wide server library index.
void removeSharedMedia(
String mediaId,
) {
sharedMediaIds.remove(mediaId);
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
final clean = mediaId.trim();

if (clean.isNotEmpty && !wishlistMediaIds.contains(clean)) {
  wishlistMediaIds.add(clean);
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
final clean = recommendationId.trim();

if (clean.isNotEmpty &&
    !wishlistRecommendationIds.contains(clean)) {
  wishlistRecommendationIds.add(clean);
}

}

void removeWishlistRecommendation(
String recommendationId,
) {
wishlistRecommendationIds.remove(
recommendationId,
);
}

/// Removes an acquired wishlist item and optionally records ownership on
/// the supplied profile.
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

return subscription?.isCurrentlyActive ?? false;

}

// ---------------------------------------------------------------------------
// LEGAL
// ---------------------------------------------------------------------------

bool get hasAcceptedRequiredLegal {
return termsVersionAccepted.isNotEmpty &&
privacyVersionAccepted.isNotEmpty &&
acceptableUseVersionAccepted.isNotEmpty;
}

// ---------------------------------------------------------------------------
// JSON
// ---------------------------------------------------------------------------

/// Serializes the account for API/persistence use.
///
/// Sensitive authentication material is excluded by default.
///
/// [includeSensitiveData] exists only for tightly controlled internal
/// persistence/debugging code. HTTP routes should leave this false.
///
/// Sensitive fields included when explicitly requested:
/// - passwordHash
/// - securityAnswerHash
/// - mfaChallengeHash
/// - mfaChallengeExpiresAt
Map<String, dynamic> toJson({
bool includeSensitiveData = false,
}) {
final data = <String, dynamic>{
'id': id,
'username': username,
'email': email,

  // Deliberately excludes:
  // passwordHash
  // securityAnswerHash
  // mfaChallengeHash
  // mfaChallengeExpiresAt

  'securityQuestion': securityQuestion,
  'mfaEnabled': mfaEnabled,

  'profiles': profiles
      .map(
        (profile) => profile.toJson(),
      )
      .toList(),

  'profileCount': profiles.length,
  'maxProfiles': maxProfiles,

  'sharedMediaIds': List<String>.from(
    sharedMediaIds,
  ),

  'wishlistMediaIds': List<String>.from(
    wishlistMediaIds,
  ),

  'wishlistRecommendationIds':
      List<String>.from(
    wishlistRecommendationIds,
  ),

  'subscription': subscription?.toJson(),

  'hasActiveSubscription': hasActiveSubscription,

  'storageLimitBytes': storageLimitBytes,
  'storageUsedBytes': storageUsedBytes,
  'storageRequestPending': storageRequestPending,
  'storageRequestAt':
      storageRequestAt?.toIso8601String(),
  'storageRequestedTerabytes':
      storageRequestedTerabytes,
  'storageRequestFeeUsd':
      storageRequestFeeUsd,
  'storageRequestStatus':
      storageRequestStatus,

  'notifications': notifications
      .map(
        (notification) =>
            Map<String, dynamic>.from(notification),
      )
      .toList(),

  'legalAccepted': hasAcceptedRequiredLegal,
  'termsVersionAccepted':
      termsVersionAccepted,
  'privacyVersionAccepted':
      privacyVersionAccepted,
  'acceptableUseVersionAccepted':
      acceptableUseVersionAccepted,
  'legalAcceptedAt':
      legalAcceptedAt?.toIso8601String(),
};

if (includeSensitiveData) {
  data['passwordHash'] = passwordHash;
  data['securityAnswerHash'] =
      securityAnswerHash;
  data['mfaChallengeHash'] =
      mfaChallengeHash;
  data['mfaChallengeExpiresAt'] =
      mfaChallengeExpiresAt?.toIso8601String();
}

return data;

}
}
