import 'package:flutter/material.dart';

import 'app_core.dart';
import 'core/models/profile_governance.dart';
import 'core/services/profile_governance_api.dart';

/// Account/profile governance screen. Owner authorization is enforced by the
/// backend; this screen is intentionally only a presentation/editor surface.
class ProfileAdministrationScreen extends StatefulWidget {
  final Profile profile;

  const ProfileAdministrationScreen({
    super.key,
    required this.profile,
  });

  @override
  State<ProfileAdministrationScreen> createState() => _ProfileAdministrationScreenState();
}

class _ProfileAdministrationScreenState extends State<ProfileAdministrationScreen> {
  late ProfileGovernance _governance;
  bool _loading = true;
  bool _saving = false;
  bool _allowMembersToManageOwnProfiles = false;
  bool _isAccountOwner = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _governance = const ProfileGovernance();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ProfileGovernanceApi(AppController.instance.backendApi);
      final capabilities = await api.getCapabilities();
      _allowMembersToManageOwnProfiles = capabilities['allowMembersToManageOwnProfiles'] == true;
      _isAccountOwner = capabilities['isAccountOwner'] == true;
      _governance = await api.getGovernance(widget.profile.id);
      widget.profile.governance = _governance;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(ProfileGovernance governance) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ProfileGovernanceApi(AppController.instance.backendApi);
      _governance = await api.updateGovernance(
        profileId: widget.profile.id,
        governance: governance,
      );
      widget.profile.governance = _governance;
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = ProfileContentLevel.values;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.profile.name} • Administration')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text('Profile administration', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('The account owner is always able to manage this profile. Self-management is optional and remains limited by backend permissions.'),
                const SizedBox(height: 18),
                if (_error != null)
                  Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!))),
                if (_isAccountOwner)
                  Card(
                    child: SwitchListTile(
                      title: const Text('Allow members to manage their own profiles'),
                      subtitle: const Text('Members can manage only profiles assigned to them that are marked self-managed. The owner remains authoritative.'),
                      value: _allowMembersToManageOwnProfiles,
                      onChanged: _saving
                          ? null
                          : (value) async {
                              setState(() { _saving = true; _error = null; });
                              try {
                                await AppController.instance.backendApi.updateAccountProfileAdministrationPolicy(
                                  allowMembersToManageOwnProfiles: value,
                                );
                                _allowMembersToManageOwnProfiles = value;
                                if (AppController.instance.currentAccount != null) {
                                  AppController.instance.currentAccount!.allowMembersToManageOwnProfiles = value;
                                }
                              } catch (error) {
                                if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
                              } finally {
                                if (mounted) setState(() => _saving = false);
                              }
                              if (mounted) setState(() {});
                            },
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<ProfileContentLevel>(
                      initialValue: _governance.contentLevel,
                      decoration: const InputDecoration(labelText: 'Maximum content level'),
                      items: levels.map((level) => DropdownMenuItem(value: level, child: Text(_label(level)))).toList(),
                      onChanged: _saving ? null : (value) {
                        if (value != null) _save(_governance.copyWith(contentLevel: value));
                      },
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Allow this profile to self-manage'),
                  subtitle: const Text('Members still cannot manage other profiles or account/server settings.'),
                  value: _governance.isSelfManaged,
                  onChanged: _saving
                      ? null
                      : (value) => _save(_governance.copyWith(
                            adminMode: value ? ProfileAdminMode.selfManaged : ProfileAdminMode.ownerManaged,
                          )),
                ),
                if (_isAccountOwner)
                  SwitchListTile(
                    title: const Text('Allow a self-managed member to change content controls'),
                    subtitle: const Text('This separately permits the member to change this profile’s content level and related policy.'),
                    value: _governance.permissions.contains(ProfilePermission.manageContentPolicy),
                    onChanged: _saving
                        ? null
                        : (value) {
                            final permissions = <ProfilePermission>{..._governance.permissions};
                            if (value) {
                              permissions.add(ProfilePermission.manageContentPolicy);
                            } else {
                              permissions.remove(ProfilePermission.manageContentPolicy);
                            }
                            _save(_governance.copyWith(permissions: permissions));
                          },
                  ),
                SwitchListTile(
                  title: const Text('Allow explicit music'),
                  value: _governance.explicitMusicAllowed,
                  onChanged: _saving ? null : (value) => _save(_governance.copyWith(explicitMusicAllowed: value)),
                ),
                SwitchListTile(
                  title: const Text('Allow explicit lyrics'),
                  value: _governance.explicitLyricsAllowed,
                  onChanged: _saving ? null : (value) => _save(_governance.copyWith(explicitLyricsAllowed: value)),
                ),
                SwitchListTile(
                  title: const Text('Restrict purchases'),
                  value: _governance.purchasesRestricted,
                  onChanged: _saving ? null : (value) => _save(_governance.copyWith(purchasesRestricted: value)),
                ),
                SwitchListTile(
                  title: const Text('Require profile PIN protection'),
                  value: _governance.profilePinEnabled,
                  onChanged: _saving ? null : (value) => _save(_governance.copyWith(profilePinEnabled: value)),
                ),
              ],
            ),
    );
  }

  String _label(ProfileContentLevel value) {
    switch (value) {
      case ProfileContentLevel.littleKids:
        return 'Little Kids';
      case ProfileContentLevel.kids:
        return 'Kids';
      case ProfileContentLevel.olderKids:
        return 'Older Kids';
      case ProfileContentLevel.teen:
        return 'Teen';
      case ProfileContentLevel.mature:
        return 'Mature';
      case ProfileContentLevel.unrestricted:
        return 'Unrestricted';
      case ProfileContentLevel.custom:
        return 'Custom';
    }
  }
}
