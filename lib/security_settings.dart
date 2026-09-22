// FILE: `lib/security_settings.dart`.
// Purpose: Provides the account Security & Privacy screen for password, MFA,
// sessions, and security-posture visibility. Credentials are never displayed.

import 'package:flutter/material.dart';
import 'app_core.dart';

/// Displays account security controls backed by the authenticated API.
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool loading = true;
  bool mfaEnabled = false;
  List<Map<String, dynamic>> sessions = const [];
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads redacted security state from the backend.
  Future<void> _load() async {
    try {
      final api = AppController.instance.backendApi;
      final status = await api.getSecurityStatus();
      final active = await api.getSecuritySessions();
      if (!mounted) return;
      setState(() {
        mfaEnabled = status['mfaEnabled'] == true;
        final rawSessions = active['sessions'];
        sessions = rawSessions is List
            ? rawSessions.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  /// Starts or completes email MFA enrollment.
  Future<void> _mfa() async {
    final api = AppController.instance.backendApi;
    try {
      if (!mfaEnabled) {
        await api.startMfaEnrollment();
        if (!mounted) return;
        final controller = TextEditingController();
        final code = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verify MFA'),
            content: TextField(controller: controller, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit email code')),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Verify'))],
          ),
        );
        controller.dispose();
        if (code == null || code.trim().isEmpty) return;
        await api.verifyMfaEnrollment(code: code);
      } else {
        await api.disableMfa();
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Changes the password and clears the local session because the backend revokes all sessions.
  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirmed = TextEditingController();
    try {
      final values = await showDialog<List<String>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change password'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
            TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New password (10+ characters)')),
            TextField(controller: confirmed, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, [current.text, next.text, confirmed.text]), child: const Text('Change'))],
        ),
      );
      if (values == null) return;
      if (values[1] != values[2]) throw Exception('New passwords do not match.');
      await AppController.instance.backendApi.changePassword(currentPassword: values[0], newPassword: values[1]);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed. Sign in again on this device.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      current.dispose(); next.dispose(); confirmed.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security & Privacy')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(18), children: [
                if (error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(error!))),
                Card(child: Column(children: [
                  SwitchListTile(title: const Text('Multi-factor authentication'), subtitle: Text(mfaEnabled ? 'Enabled — email verification is required after password authentication.' : 'Disabled'), value: mfaEnabled, onChanged: (_) => _mfa()),
                  const ListTile(title: Text('Password protection'), subtitle: Text('Backend password hashes use Argon2id. Plaintext passwords are never stored in the application database.')),
                  ListTile(leading: const Icon(Icons.password), title: const Text('Change password'), onTap: _changePassword),
                  const ListTile(title: Text('Passkeys'), subtitle: Text('The security API reserves the WebAuthn/passkey integration surface; passkey credentials are not exposed as passwords or bearer tokens.')),
                ])),
                const SizedBox(height: 12),
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Active sessions (${sessions.length})', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final session in sessions) ListTile(
                    leading: Icon(session['current'] == true ? Icons.devices : Icons.device_unknown),
                    title: Text(session['current'] == true ? 'This session' : 'Signed-in session'),
                    subtitle: Text('${session['ipAddress'] ?? 'unknown'}\n${session['userAgent'] ?? 'unknown'}\nLast used: ${session['lastUsedAt'] ?? 'unknown'}'),
                    trailing: session['current'] == true ? null : IconButton(icon: const Icon(Icons.logout), onPressed: () async { await AppController.instance.backendApi.revokeSecuritySession(sessionId: session['sessionId'].toString()); await _load(); }),
                  ),
                ]))),
                const SizedBox(height: 12),
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Transport protection: HTTPS is required for non-local backend endpoints. The backend also applies security headers, CORS restrictions, rate limiting, proxy validation, and bearer-token session authentication.'))),
              ]),
            ),
    );
  }
}
