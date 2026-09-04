import 'profile.dart';
import 'subscription.dart';

class Account {
  final String id;

  String username;
  String email;

  // Prototype only.
  //
  // DO NOT use plain-text passwords in production.
  // We will replace this with secure password hashing
  // when we move beyond the first backend stage.
  String password;

  Subscription? subscription;

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

  bool get hasActiveSubscription {
    subscription?.expireIfNeeded();

    return subscription?.isCurrentlyActive ?? false;
  }

  bool get canAddProfile {
    return profiles.length < maxProfiles;
  }

  Profile? getProfileById(String profileId) {
    for (final profile in profiles) {
      if (profile.id == profileId) {
        return profile;
      }
    }

    return null;
  }

  Map<String, dynamic> toJson({
    bool includeSensitiveData = false,
  }) {
    final data = <String, dynamic>{
      'id': id,
      'username': username,
      'email': email,
      'profiles': profiles.map((profile) {
        return profile.toJson();
      }).toList(),
      'profileCount': profiles.length,
      'maxProfiles': maxProfiles,
      'subscription': subscription?.toJson(),
      'hasActiveSubscription': hasActiveSubscription,
    };

    if (includeSensitiveData) {
      data['password'] = password;
    }

    return data;
  }
}