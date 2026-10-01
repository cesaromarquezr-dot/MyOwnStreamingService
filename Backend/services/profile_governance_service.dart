import '../database/database.dart';
import '../models/account.dart';
import '../models/authenticated_principal.dart';
import '../models/profile.dart';
import '../models/profile_governance.dart';

class ProfileGovernanceService {
  final Database database;

  const ProfileGovernanceService(this.database);

  Profile? profileFor(Account account, String profileId) {
    final cleanId = profileId.trim();
    if (cleanId.isEmpty) return null;
    for (final profile in account.profiles) {
      if (profile.id == cleanId) return profile;
    }
    return null;
  }

  bool canManageProfile(
    AuthenticatedPrincipal principal,
    Profile profile, {
    ProfilePermission permission = ProfilePermission.editIdentity,
  }) {
    if (principal.isOwner) return true;

    final account = principal.account;
    if (!account.allowMembersToManageOwnProfiles) return false;
    if (profile.governance.adminMode != ProfileAdminMode.selfManaged) return false;

    final member = database.getMemberLoginById(principal.memberId);
    if (member == null || member.accountId != account.id || !member.isActive) return false;
    if (!member.profileIds.contains(profile.id)) return false;

    return profile.governance.hasPermission(permission);
  }

  ProfileGovernance updateGovernance(
    AuthenticatedPrincipal principal,
    Profile profile,
    ProfileGovernance requested,
  ) {
    if (!canManageProfile(
      principal,
      profile,
      permission: ProfilePermission.manageContentPolicy,
    ) && !principal.isOwner) {
      throw StateError('This profile cannot be administered by the current member.');
    }

    // A non-owner self-managed profile may not grant itself stronger
    // administration rights. Content-policy changes are permitted only when
    // that permission was already explicitly granted by the owner.
    if (!principal.isOwner) {
      final current = profile.governance;
      if (!current.hasPermission(ProfilePermission.manageContentPolicy)) {
        throw StateError('The account owner must enable content-policy management for this profile.');
      }
      final next = requested.copyWith(
        adminMode: current.adminMode,
        permissions: current.permissions,
      );
      profile.governance = next;
      database.persistProfile(profile, principal.account);
      return next;
    }

    profile.governance = requested;
    database.persistProfile(profile, principal.account);
    return profile.governance;
  }

  Future<void> assignMemberProfiles(
    AuthenticatedPrincipal principal,
    String memberId,
    List<String> profileIds,
  ) async {
    if (!principal.isOwner) {
      throw StateError('Only the account owner can assign profiles to members.');
    }

    final unique = profileIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    for (final id in unique) {
      if (profileFor(principal.account, id) == null) {
        throw StateError('Profile $id does not belong to this account.');
      }
    }

    final member = database.getMemberLoginById(memberId.trim());
    if (member == null || member.accountId != principal.account.id) {
      throw StateError('Account member not found.');
    }

    await database.supabaseAssignMemberProfiles(
      accountExternalId: principal.account.id,
      memberId: member.memberId,
      profileIds: unique,
    );
    database.updateMemberProfileIds(member.memberId, unique);
  }

  ProfileGovernance setMemberSelfManagement(
    AuthenticatedPrincipal principal,
    Profile profile,
    bool enabled,
  ) {
    if (!principal.isOwner) {
      throw StateError('Only the account owner can change profile administration mode.');
    }

    final next = profile.governance.copyWith(
      adminMode: enabled ? ProfileAdminMode.selfManaged : ProfileAdminMode.ownerManaged,
    );
    profile.governance = next;
    database.persistProfile(profile, principal.account);
    return next;
  }
}
