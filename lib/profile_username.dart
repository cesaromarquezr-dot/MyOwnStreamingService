/// Canonical username rules shared by profile-creation flows.
///
/// Public usernames belong to profiles, not to subscription accounts. The
/// backend and shared database enforce uniqueness; this helper only normalizes
/// input and provides fast client-side validation.
class ProfileUsername {
  ProfileUsername._();

  static const int minLength = 3;
  static const int maxLength = 32;

  static String normalize(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^@'), '')
      .toLowerCase();

  static bool isValid(String value) => RegExp(
        r'^[a-z0-9_]{3,32}$',
      ).hasMatch(normalize(value));

  static String? validationMessage(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) {
      return 'Choose a username for this profile.';
    }
    if (normalized.length < minLength || normalized.length > maxLength) {
      return 'Username must be 3–32 characters long.';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(normalized)) {
      return 'Use only letters, numbers, and underscores in your username.';
    }
    return null;
  }

  /// Removes common Dart/API exception wrappers before showing a username
  /// validation result to the user.
  static String userFacingError(Object error) {
    return error
        .toString()
        .replaceFirst(
          RegExp(r'^(?:Exception|Bad state|StateError|BackendApiException(?:\s+\(\d+\))?):\s*'),
          '',
        )
        .trim();
  }
}
