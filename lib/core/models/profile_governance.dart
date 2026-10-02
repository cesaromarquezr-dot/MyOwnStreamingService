// Profile governance primitives shared by profile administration UI/API.
//
// The account owner remains the authoritative administrator. A member can
// manage only their own profile when the account enables self-management and
// the profile explicitly permits it. Rating restrictions are represented as
// policy data rather than being inferred from profile names.

enum ProfileContentLevel {
  littleKids,
  kids,
  olderKids,
  teen,
  mature,
  unrestricted,
  custom,
}

enum ProfileAdminMode {
  ownerManaged,
  selfManaged,
}

enum ProfilePermission {
  editIdentity,
  editTheme,
  manageCollections,
  managePlaylists,
  manageNotifications,
  manageContentPolicy,
  purchase,
  manageSocial,
}

class ProfileGovernance {
  final ProfileContentLevel contentLevel;
  final ProfileAdminMode adminMode;
  final Set<ProfilePermission> permissions;
  final bool explicitMusicAllowed;
  final bool explicitLyricsAllowed;
  final bool socialRestricted;
  final bool purchasesRestricted;
  final bool profilePinEnabled;
  final String? pinHint;

  const ProfileGovernance({
    this.contentLevel = ProfileContentLevel.teen,
    this.adminMode = ProfileAdminMode.ownerManaged,
    this.permissions = const <ProfilePermission>{
      ProfilePermission.editIdentity,
      ProfilePermission.editTheme,
      ProfilePermission.manageCollections,
      ProfilePermission.managePlaylists,
      ProfilePermission.manageNotifications,
    },
    this.explicitMusicAllowed = false,
    this.explicitLyricsAllowed = false,
    this.socialRestricted = false,
    this.purchasesRestricted = true,
    this.profilePinEnabled = false,
    this.pinHint,
  });

  bool hasPermission(ProfilePermission permission) => permissions.contains(permission);

  bool allowsUnrestrictedContent() => contentLevel == ProfileContentLevel.unrestricted;

  ProfileGovernance copyWith({
    ProfileContentLevel? contentLevel,
    ProfileAdminMode? adminMode,
    Set<ProfilePermission>? permissions,
    bool? explicitMusicAllowed,
    bool? explicitLyricsAllowed,
    bool? socialRestricted,
    bool? purchasesRestricted,
    bool? profilePinEnabled,
    String? pinHint,
    bool clearPinHint = false,
  }) {
    return ProfileGovernance(
      contentLevel: contentLevel ?? this.contentLevel,
      adminMode: adminMode ?? this.adminMode,
      permissions: permissions ?? Set<ProfilePermission>.unmodifiable(this.permissions),
      explicitMusicAllowed: explicitMusicAllowed ?? this.explicitMusicAllowed,
      explicitLyricsAllowed: explicitLyricsAllowed ?? this.explicitLyricsAllowed,
      socialRestricted: socialRestricted ?? this.socialRestricted,
      purchasesRestricted: purchasesRestricted ?? this.purchasesRestricted,
      profilePinEnabled: profilePinEnabled ?? this.profilePinEnabled,
      pinHint: clearPinHint ? null : (pinHint ?? this.pinHint),
    );
  }

  Map<String, dynamic> toJson() => {
        'contentLevel': contentLevel.name,
        'adminMode': adminMode.name,
        'permissions': permissions.map((item) => item.name).toList()..sort(),
        'explicitMusicAllowed': explicitMusicAllowed,
        'explicitLyricsAllowed': explicitLyricsAllowed,
        'socialRestricted': socialRestricted,
        'purchasesRestricted': purchasesRestricted,
        'profilePinEnabled': profilePinEnabled,
        if (pinHint != null && pinHint!.trim().isNotEmpty) 'pinHint': pinHint,
      };

  factory ProfileGovernance.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};

    ProfileContentLevel parseContentLevel(dynamic value) {
      return ProfileContentLevel.values.firstWhere(
        (item) => item.name == value?.toString(),
        orElse: () => ProfileContentLevel.teen,
      );
    }

    ProfileAdminMode parseAdminMode(dynamic value) {
      return ProfileAdminMode.values.firstWhere(
        (item) => item.name == value?.toString(),
        orElse: () => ProfileAdminMode.ownerManaged,
      );
    }

    final permissions = <ProfilePermission>{};
    final rawPermissions = data['permissions'];
    if (rawPermissions is List) {
      for (final raw in rawPermissions) {
        final match = ProfilePermission.values.cast<ProfilePermission?>().firstWhere(
              (item) => item?.name == raw?.toString(),
              orElse: () => null,
            );
        if (match != null) permissions.add(match);
      }
    }

    if (permissions.isEmpty) {
      permissions.addAll(const <ProfilePermission>{
        ProfilePermission.editIdentity,
        ProfilePermission.editTheme,
        ProfilePermission.manageCollections,
        ProfilePermission.managePlaylists,
        ProfilePermission.manageNotifications,
      });
    }

    return ProfileGovernance(
      contentLevel: parseContentLevel(data['contentLevel'] ?? data['content_level']),
      adminMode: parseAdminMode(data['adminMode'] ?? data['admin_mode']),
      permissions: Set<ProfilePermission>.unmodifiable(permissions),
      explicitMusicAllowed: data['explicitMusicAllowed'] == true || data['explicit_music_allowed'] == true,
      explicitLyricsAllowed: data['explicitLyricsAllowed'] == true || data['explicit_lyrics_allowed'] == true,
      socialRestricted: data['socialRestricted'] == true || data['social_restricted'] == true,
      purchasesRestricted: data['purchasesRestricted'] != false && data['purchases_restricted'] != false,
      profilePinEnabled: data['profilePinEnabled'] == true || data['profile_pin_enabled'] == true,
      pinHint: data['pinHint']?.toString() ?? data['pin_hint']?.toString(),
    );
  }

  bool get isSelfManaged => adminMode == ProfileAdminMode.selfManaged;
  bool get isOwnerManaged => adminMode == ProfileAdminMode.ownerManaged;
}
