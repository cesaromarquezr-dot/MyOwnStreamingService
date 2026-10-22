import 'core/models/profile_governance.dart';

/// The high-level experience selected when a profile is first created.
///
/// The selected value is persisted through ProfileGovernance. Existing profile
/// policies are not changed by this enum; callers only use [initialGovernance]
/// for newly created profiles.
enum ProfileCreationType { normal, kids }

extension ProfileCreationTypePolicy on ProfileCreationType {
  String get label => switch (this) {
        ProfileCreationType.normal => 'Normal profile',
        ProfileCreationType.kids => 'Kids profile',
      };

  String get description => switch (this) {
        ProfileCreationType.normal =>
          'The standard entertainment experience, respecting the profile’s content settings.',
        ProfileCreationType.kids =>
          'Age-appropriate discovery. Explicit music, social features and purchases are restricted.',
      };

  /// Initial backend-compatible policy for a newly created profile.
  ///
  /// Normal does not mean unrestricted; it preserves the app's standard teen
  /// default. Kids opts into the child content level and additional restrictions.
  ProfileGovernance get initialGovernance => switch (this) {
        ProfileCreationType.normal => const ProfileGovernance(),
        ProfileCreationType.kids => const ProfileGovernance(
            contentLevel: ProfileContentLevel.kids,
            explicitMusicAllowed: false,
            explicitLyricsAllowed: false,
            socialRestricted: true,
            purchasesRestricted: true,
            childAccessMode: SharedProfileChildAccessMode.separateRequired,
          ),
      };

  static ProfileCreationType fromGovernance(ProfileGovernance governance) {
    final level = governance.contentLevel;
    return level == ProfileContentLevel.littleKids ||
            level == ProfileContentLevel.kids ||
            level == ProfileContentLevel.olderKids
        ? ProfileCreationType.kids
        : ProfileCreationType.normal;
  }
}
