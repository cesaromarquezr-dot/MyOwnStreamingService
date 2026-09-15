// FILE: `lib/home_server.dart`.
// Purpose: Provides the account home-server dashboard, restored server banner,
// member management, storage status, and secure invitation-link UI.
// Physical media remains on the account's home server.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_core.dart';
import 'storage_dashboard.dart';
import 'music.dart';
import 'localization.dart';

/// Displays the authenticated account's home server and its members.
class HomeServerScreen extends StatefulWidget {
  const HomeServerScreen({super.key});

  @override
  State<HomeServerScreen> createState() => _HomeServerScreenState();
}

class _HomeServerScreenState extends State<HomeServerScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic>? storage;
  Map<String, dynamic>? arm;
  List<Map<String, dynamic>> members = <Map<String, dynamic>>[];
  bool membersLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads server health, storage, ARM status, and account members.
  Future<void> _load() async {
    if (!AppController.instance.backendApi.isAuthenticated) {
      setState(() {
        loading = false;
        error = 'Sign in to connect to the home server.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = AppController.instance.backendApi;
      final values = await Future.wait<dynamic>([
        api.getHomeServerStorage(),
        api.getHomeServerArm(),
        api.getAccountMembers(),
      ]);
      if (!mounted) return;
      setState(() {
        storage = values[0] as Map<String, dynamic>;
        arm = values[1] as Map<String, dynamic>;
        members = (values[2] as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Reloads only the account-member list.
  Future<void> _loadMembers() async {
    if (!AppController.instance.backendApi.isAuthenticated) return;
    setState(() => membersLoading = true);
    try {
      final loaded = await AppController.instance.backendApi.getAccountMembers();
      if (mounted) setState(() => members = loaded);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => membersLoading = false);
    }
  }

  /// Opens the account invitation dialog and refreshes members afterwards.
  Future<void> _inviteMember() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _InviteMemberDialog(),
    );
    if (result == true) await _loadMembers();
  }

  /// Scans ARM's completed-media directories and syncs discovered metadata.
  Future<void> _syncLibrary() async {
    try {
      final data = await AppController.instance.backendApi.scanServerLibrary();
      final raw = data['media'];
      if (raw is! List) return;
      final serverApi = AppController.instance.backendApi;
      final media = raw.whereType<Map>().where((m) => m['type']?.toString() != 'music').map((m) => MediaItem(
        id: m['id']?.toString() ?? '',
        title: m['title']?.toString() ?? 'Imported Media',
        type: m['type']?.toString() ?? 'movie',
        description: tr('Imported from the home server media library.'),
      )).toList();
      final music = raw.whereType<Map>().where((m) => m['type']?.toString() == 'music').map((m) => MusicTrack(
        id: m['id']?.toString() ?? '',
        title: m['title']?.toString() ?? 'Imported Song',
        artist: 'Imported Artist',
        album: 'Server Library',
        audioUrl: '${serverApi.baseUrl}/library/stream?path=${Uri.encodeComponent(m['id']?.toString() ?? '')}',
      )).toList();
      MusicLibraryStore.instance.tracks
        ..clear()
        ..addAll(music);
      AppController.instance.replaceLibraryFromServer(media);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: UniversalText('Synced ${media.length} server media files.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = AppController.instance.currentAccount;
    final serverName = account == null ? 'Home Server' : '${account.username} Server';
    final serverOnline = arm?['connected'] == true || storage != null;
    final used = (storage?['usedBytes'] as num?)?.toInt() ?? 0;
    final limit = (storage?['limitBytes'] as num?)?.toInt() ?? 0;
    final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0).toDouble() : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Home Server & Members'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                if (error != null)
                  Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent)))),
                _serverBanner(serverName, serverOnline, used, limit, progress),
                const SizedBox(height: 18),
                _membersSection(),
                const SizedBox(height: 18),
                _infoCard('Architecture', 'Optical drive → ARM → completed media → server importer → database → Flutter. ARM performs ripping; the home server owns the physical media and library storage.', Icons.account_tree_rounded),
                const SizedBox(height: 10),
                _statusCard('ARM connection', arm?['connected'] == true, '${arm?['armServerUrl'] ?? 'Not configured'}\nMedia root: ${arm?['mediaRoot'] ?? 'Unknown'}'),
                _statusCard('Server storage', storage != null, storage == null ? 'Unavailable' : '${storage!['root']}'),
                if (storage != null) ...[
                  const SizedBox(height: 8),
                  for (final c in (storage!['categories'] as List? ?? const [])) _category(c),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _syncLibrary, icon: const Icon(Icons.sync_rounded), label: const UniversalText('Scan & sync server library')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageDashboardScreen())), icon: const Icon(Icons.storage_rounded), label: const UniversalText('Open storage manager')),
                ],
                const SizedBox(height: 20),
                _infoCard('Physical setup', 'Connect a DVD/Blu-ray/UHD-capable optical drive to the ARM host. Configure the exact drive/firmware for UHD support, then point ARM at the server media directories. Do not assume every Blu-ray drive supports UHD ripping.', Icons.album_rounded),
              ],
            ),
    );
  }

  /// Restores the prominent server banner with online status and capacity.
  Widget _serverBanner(String name, bool online, int used, int limit, double progress) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primary.withValues(alpha: .24), Theme.of(context).colorScheme.surface]),
        border: Border.all(color: primary.withValues(alpha: .24)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), color: primary.withValues(alpha: .16)), child: const Icon(Icons.dns_rounded, size: 30)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const UniversalText('YOUR SERVER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)), const SizedBox(height: 3), Text(name, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))])),
          _statusPill(online),
        ]),
        const SizedBox(height: 20),
        Row(children: [const Icon(Icons.storage_rounded, size: 20), const SizedBox(width: 8), const UniversalText('Storage', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), Text(limit > 0 ? '${_bytes(used)} / ${_bytes(limit)}' : 'Unavailable', style: const TextStyle(fontWeight: FontWeight.w700))]),
        const SizedBox(height: 9),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(minHeight: 10, value: progress)),
        const SizedBox(height: 7),
        Text(limit > 0 ? '${(progress * 100).round()}% used' : 'Storage capacity is not currently available.', style: const TextStyle(color: Colors.white60)),
      ]),
    );
  }

  /// Builds the account member list and account-invitation controls.
  Widget _membersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.people_alt_rounded), const SizedBox(width: 9), const Expanded(child: UniversalText('Members', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), if (membersLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))]),
          const SizedBox(height: 5),
          const UniversalText('People who can use this account and stream from this account’s home server.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 14),
          if (members.isEmpty)
            ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_outline_rounded), title: UniversalText('No members loaded'), subtitle: UniversalText('The account owner can invite a member below.'))
          else
            ...members.map(_memberTile),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _inviteMember, icon: const Icon(Icons.person_add_alt_1_rounded), label: const UniversalText('INVITE MEMBER'))),
        ]),
      ),
    );
  }

  Widget _memberTile(Map<String, dynamic> member) {
    final name = member['displayName']?.toString().trim();
    final email = member['email']?.toString() ?? '';
    final role = member['role']?.toString() ?? 'member';
    final status = member['status']?.toString() ?? 'active';
    final avatarText = name?.isNotEmpty == true ? name![0] : email.isNotEmpty ? email[0] : '?';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(avatarText.toUpperCase())),
      title: Text(name?.isNotEmpty == true ? name! : email),
      subtitle: Text(email.isEmpty ? 'Individual login identity' : email),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(role.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)), Text(status, style: const TextStyle(color: Colors.white54, fontSize: 11))]),
    );
  }

  Widget _statusPill(bool online) {
    final color = online ? Colors.greenAccent : Colors.orangeAccent;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), color: color.withValues(alpha: .12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 8, color: color), const SizedBox(width: 6), Text(online ? 'ONLINE' : 'OFFLINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color))]));
  }

  String _bytes(int bytes) {
    if (bytes >= 1000000000000) return '${(bytes / 1000000000000).toStringAsFixed(1)} TB';
    if (bytes >= 1000000000) return '${(bytes / 1000000000).toStringAsFixed(0)} GB';
    if (bytes >= 1000000) return '${(bytes / 1000000).toStringAsFixed(0)} MB';
    return '$bytes B';
  }

  Widget _infoCard(String title, String body, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 30), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(body, style: const TextStyle(color: Colors.white70, height: 1.45))]))])));

  Widget _statusCard(String title, bool ok, String body) => Card(child: ListTile(leading: Icon(ok ? Icons.check_circle : Icons.error_outline, color: ok ? Colors.greenAccent : Colors.orangeAccent), title: Text(title), subtitle: Text(body)));

  Widget _category(dynamic raw) {
    final c = Map<String, dynamic>.from(raw as Map);
    return Card(child: ListTile(leading: const Icon(Icons.folder_rounded), title: Text(c['name']?.toString() ?? 'Media'), subtitle: Text(c['path']?.toString() ?? ''), trailing: Text(StorageDashboardScreen.formatBytes((c['usedBytes'] as num?)?.toInt() ?? 0))));
  }
}

/// Final onboarding step that shows the account members and invitation action.
class AccountInviteScreen extends StatefulWidget {
  final bool firstSetup;

  const AccountInviteScreen({
    super.key,
    this.firstSetup = false,
  });

  @override
  State<AccountInviteScreen> createState() => _AccountInviteScreenState();
}

class _AccountInviteScreenState extends State<AccountInviteScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> members = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (!AppController.instance.backendApi.isAuthenticated) {
      setState(() {
        loading = false;
        error = 'Sign in to manage account members.';
      });
      return;
    }

    try {
      final result =
          await AppController.instance.backendApi.getAccountMembers();
      if (!mounted) return;
      setState(() {
        members = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _invite() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const _InviteMemberDialog(),
    );
    if (mounted) {
      await _loadMembers();
    }
  }

  void _finish() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        automaticallyImplyLeading: !widget.firstSetup,
        title: Text(widget.firstSetup ? 'Account Invite' : 'Account Members'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .22),
                    const Color(0xFF151515),
                  ],
                ),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.group_add_rounded, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    widget.firstSetup
                        ? 'Who should share this account?'
                        : 'Account members',
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const UniversalText('Invite people to this streaming account. They use their own login while streaming from this account’s home server.',
                    style: TextStyle(color: Colors.white60, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline_rounded),
                  title: const UniversalText('Members could not be loaded'),
                  subtitle: Text(error!),
                  trailing: IconButton(
                    onPressed: _loadMembers,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_alt_rounded),
                        const SizedBox(width: 8),
                        Expanded(
                          child: UniversalText('MEMBERS (${members.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        if (loading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!loading && members.isEmpty)
                      const UniversalText('Only the account owner is currently connected. Invite a member below.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    for (final member in members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            (member['displayName']?.toString().trim().isNotEmpty ==
                                        true
                                    ? member['displayName']
                                        .toString()
                                        .trim()[0]
                                    : member['email']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                        ? member['email']
                                            .toString()
                                            .trim()[0]
                                        : '?')
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(
                          member['displayName']?.toString().trim().isNotEmpty ==
                                  true
                              ? member['displayName'].toString()
                              : member['email']?.toString() ?? 'Member',
                        ),
                        subtitle: UniversalText('${member['email'] ?? ''} • ${(member['role'] ?? 'member').toString().toUpperCase()}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _invite,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const UniversalText('INVITE ACCOUNT MEMBER'),
              ),
            ),
            const SizedBox(height: 10),
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: UniversalText('Private invitation'),
                subtitle: UniversalText('Invitation links expire after 7 days. Passwords and server credentials are never placed in the invitation.',
                ),
              ),
            ),
            if (widget.firstSetup) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _finish,
                  icon: const Icon(Icons.home_rounded),
                  label: const UniversalText('CONTINUE TO MY HOME'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Creates an account invitation and presents its secure shareable token link.
class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog();
  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  final emailController = TextEditingController();
  String role = 'member';
  bool submitting = false;
  String? invitationLink;
  DateTime? expiresAt;

  @override
  void dispose() { emailController.dispose(); super.dispose(); }

  /// Creates a seven-day invitation. Supabase stores only the SHA-256 token hash.
  Future<void> _create() async {
    final email = emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: UniversalText('Enter a valid member email address.')));
      return;
    }
    setState(() => submitting = true);
    try {
      final result = await AppController.instance.backendApi.inviteAccountMember(email: email, role: role);
      final token = result['invitationToken']?.toString() ?? '';
      if (token.isEmpty) throw Exception('The server did not return an invitation token.');

      final base = Uri.base;
      final link = (base.scheme == 'http' || base.scheme == 'https')
          ? base.replace(path: '/join', queryParameters: {'token': token}).toString()
          : 'streamingservice://join?token=${Uri.encodeComponent(token)}';

      if (!mounted) return;
      setState(() {
        invitationLink = link;
        expiresAt = DateTime.now().toUtc().add(const Duration(days: 7));
        submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  /// Copies the invitation URL without exposing any password or server secret.
  Future<void> _copy() async {
    final link = invitationLink;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: UniversalText('Invitation link copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const UniversalText('Invite a member'),
      content: SizedBox(
        width: 520,
        child: invitationLink == null
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                const Align(alignment: Alignment.centerLeft, child: UniversalText('Invite an individual login to join this existing account. They will use this account’s home server.')),
                const SizedBox(height: 16),
                TextField(controller: emailController, keyboardType: TextInputType.emailAddress, enabled: !submitting, decoration: InputDecoration(labelText: tr('Member email'), prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(initialValue: role, decoration: InputDecoration(labelText: tr('Role')), items: const [DropdownMenuItem(value: 'member', child: UniversalText('Member')), DropdownMenuItem(value: 'admin', child: UniversalText('Admin'))], onChanged: submitting ? null : (value) => setState(() => role = value ?? 'member')),
                const SizedBox(height: 12),
                const UniversalText('The invitation expires after 7 days. Only a SHA-256 hash of the token is stored in the database.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ])
            : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 34),
                const SizedBox(height: 10),
                const UniversalText('Invitation created', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                UniversalText('Send this link to ${emailController.text.trim()}. It expires in 7 days.'),
                const SizedBox(height: 14),
                SelectableText(invitationLink!, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _copy, icon: const Icon(Icons.copy_rounded), label: const UniversalText('COPY INVITATION LINK'))),
                const SizedBox(height: 8),
                const UniversalText('The recipient must use the invited email. The link grants account membership only; it does not reveal a password or server credentials.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                if (expiresAt != null) ...[const SizedBox(height: 8), UniversalText('Expires: ${expiresAt!.toLocal()}', style: const TextStyle(color: Colors.white38, fontSize: 11))],
              ]),
      ),
      actions: invitationLink == null
          ? [TextButton(onPressed: submitting ? null : () => Navigator.pop(context, false), child: const UniversalText('CANCEL')), FilledButton(onPressed: submitting ? null : _create, child: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const UniversalText('CREATE INVITATION'))]
          : [TextButton(onPressed: () => Navigator.pop(context, true), child: const UniversalText('DONE'))],
    );
  }
}

/// Accepts an account invitation opened from a shared `/join?token=...` link.
class InvitationJoinScreen extends StatefulWidget {
  final String token;
  const InvitationJoinScreen({super.key, required this.token});

  @override
  State<InvitationJoinScreen> createState() => _InvitationJoinScreenState();
}

class _InvitationJoinScreenState extends State<InvitationJoinScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool accepting = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Accepts the invitation through the backend using the token from the link.
  Future<void> _accept() async {
    final email = emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: UniversalText('Enter the email address that received the invitation.')));
      return;
    }
    setState(() => accepting = true);
    try {
      await AppController.instance.backendApi.acceptAccountInvitation(
        token: widget.token,
        email: email,
        password: passwordController.text.isEmpty ? null : passwordController.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const UniversalText('Invitation accepted'),
          content: const UniversalText('You are now a member of the account. Sign in with your individual login to access the account’s home server.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const UniversalText('OK'))],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.group_add_rounded, size: 44),
                  const SizedBox(height: 14),
                  const UniversalText('Join a streaming account', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const UniversalText('This invitation adds your individual login to an existing account. You will stream from that account’s home server; you do not receive the server password or physical media.'),
                  const SizedBox(height: 20),
                  TextField(controller: emailController, enabled: !accepting, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: tr('Invited email'), prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 14),
                  TextField(controller: passwordController, enabled: !accepting, obscureText: obscurePassword, decoration: InputDecoration(labelText: tr('New password (only if you do not already have a login)'), prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => obscurePassword = !obscurePassword)))),
                  const SizedBox(height: 18),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: accepting ? null : _accept, child: accepting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const UniversalText('ACCEPT INVITATION'))),
                  const SizedBox(height: 10),
                  const UniversalText('Invitation links expire after 7 days and are backed by a token whose hash is stored by the backend.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
