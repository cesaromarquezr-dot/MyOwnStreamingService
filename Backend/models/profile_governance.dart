/// Backend-authoritative profile governance policy.
///
/// This model contains policy only. A profile PIN must never be stored here;
/// only a password/PIN hash belongs in a protected credential store.

enum ProfileContentLevel {
  littleKids,
  kids,
  olderKids,
  teen,
  mature,
  unrestricted,
  custom,
}

enum ProfileAdminMode { ownerManaged, selfManaged }

enum SharedProfileChildAccessMode { sharedAllowed, separatePreferred, separateRequired }

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
  final SharedProfileChildAccessMode childAccessMode;

  const ProfileGovernance({
    this.contentLevel = ProfileContentLevel.teen,
    this.adminMode = ProfileAdminMode.ownerManaged,
    this.permissions = const {
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
    this.childAccessMode = SharedProfileChildAccessMode.separatePreferred,
  });

  bool hasPermission(ProfilePermission permission) => permissions.contains(permission);

  Map<String, dynamic> toJson() => {
        'contentLevel': contentLevel.name,
        'adminMode': adminMode.name,
        'permissions': permissions.map((item) => item.name).toList()..sort(),
        'explicitMusicAllowed': explicitMusicAllowed,
        'explicitLyricsAllowed': explicitLyricsAllowed,
        'socialRestricted': socialRestricted,
        'purchasesRestricted': purchasesRestricted,
        'profilePinEnabled': profilePinEnabled,
        'childAccessMode': childAccessMode.name,
      };

  factory ProfileGovernance.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    ProfileContentLevel contentLevel = ProfileContentLevel.teen;
    ProfileAdminMode adminMode = ProfileAdminMode.ownerManaged;

    for (final value in ProfileContentLevel.values) {
      if (value.name == (data['contentLevel'] ?? data['content_level'])?.toString()) {
        contentLevel = value;
        break;
      }
    }
    for (final value in ProfileAdminMode.values) {
      if (value.name == (data['adminMode'] ?? data['admin_mode'])?.toString()) {
        adminMode = value;
        break;
      }
    }

    var childAccessMode = SharedProfileChildAccessMode.separatePreferred;
    for (final value in SharedProfileChildAccessMode.values) {
      if (value.name == (data['childAccessMode'] ?? data['child_access_mode'])?.toString()) {
        childAccessMode = value;
        break;
      }
    }

    final permissions = <ProfilePermission>{};
    final rawPermissions = data['permissions'];
    if (rawPermissions is List) {
      for (final raw in rawPermissions) {
        for (final value in ProfilePermission.values) {
          if (value.name == raw?.toString()) permissions.add(value);
        }
      }
    }
    if (permissions.isEmpty) {
      permissions.addAll(const {
        ProfilePermission.editIdentity,
        ProfilePermission.editTheme,
        ProfilePermission.manageCollections,
        ProfilePermission.managePlaylists,
        ProfilePermission.manageNotifications,
      });
    }

    return ProfileGovernance(
      contentLevel: contentLevel,
      adminMode: adminMode,
      permissions: permissions,
      explicitMusicAllowed: data['explicitMusicAllowed'] == true || data['explicit_music_allowed'] == true,
      explicitLyricsAllowed: data['explicitLyricsAllowed'] == true || data['explicit_lyrics_allowed'] == true,
      socialRestricted: data['socialRestricted'] == true || data['social_restricted'] == true,
      purchasesRestricted: data['purchasesRestricted'] != false && data['purchases_restricted'] != false,
      profilePinEnabled: data['profilePinEnabled'] == true || data['profile_pin_enabled'] == true,
      childAccessMode: childAccessMode,
    );
  }

  ProfileGovernance copyWith({
    ProfileContentLevel? contentLevel,
    ProfileAdminMode? adminMode,
    Set<ProfilePermission>? permissions,
    bool? explicitMusicAllowed,
    bool? explicitLyricsAllowed,
    bool? socialRestricted,
    bool? purchasesRestricted,
    bool? profilePinEnabled,
    SharedProfileChildAccessMode? childAccessMode,
  }) => ProfileGovernance(
        contentLevel: contentLevel ?? this.contentLevel,
        adminMode: adminMode ?? this.adminMode,
        permissions: permissions ?? this.permissions,
        explicitMusicAllowed: explicitMusicAllowed ?? this.explicitMusicAllowed,
        explicitLyricsAllowed: explicitLyricsAllowed ?? this.explicitLyricsAllowed,
        socialRestricted: socialRestricted ?? this.socialRestricted,
        purchasesRestricted: purchasesRestricted ?? this.purchasesRestricted,
        profilePinEnabled: profilePinEnabled ?? this.profilePinEnabled,
        childAccessMode: childAccessMode ?? this.childAccessMode,
      );
}
