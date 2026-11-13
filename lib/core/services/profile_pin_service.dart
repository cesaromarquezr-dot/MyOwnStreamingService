import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local profile PIN vault. PINs are stored in the platform secure
/// storage; only the profile's enabled flag is synchronized by account policy.
/// A PIN must be configured separately on each device.
class ProfilePinService {
  ProfilePinService._();

  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 1);

  static String _scope(String accountId, String profileId) =>
      '${Uri.encodeComponent(accountId.trim().isEmpty ? 'local' : accountId.trim())}_${Uri.encodeComponent(profileId.trim())}';

  static String _pinKey(String accountId, String profileId) =>
      'moss_profile_pin_v1_${_scope(accountId, profileId)}';

  static String _attemptKey(String accountId, String profileId) =>
      'moss_profile_pin_attempts_v1_${_scope(accountId, profileId)}';

  static String _lockKey(String accountId, String profileId) =>
      'moss_profile_pin_lock_v1_${_scope(accountId, profileId)}';

  static bool isValidPin(String value) => RegExp(r'^\d{4,8}$').hasMatch(value);

  static Future<bool> hasPin({
    required String accountId,
    required String profileId,
  }) async {
    final value = await _secure.read(key: _pinKey(accountId, profileId));
    return value != null && isValidPin(value);
  }

  static Future<void> setPin({
    required String accountId,
    required String profileId,
    required String pin,
  }) async {
    if (!isValidPin(pin)) {
      throw const FormatException('PIN must contain 4 to 8 digits.');
    }
    await _secure.write(key: _pinKey(accountId, profileId), value: pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attemptKey(accountId, profileId));
    await prefs.remove(_lockKey(accountId, profileId));
  }

  static Future<void> removePin({
    required String accountId,
    required String profileId,
  }) async {
    await _secure.delete(key: _pinKey(accountId, profileId));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attemptKey(accountId, profileId));
    await prefs.remove(_lockKey(accountId, profileId));
  }

  static Future<bool> verifyPin({
    required String accountId,
    required String profileId,
    required String pin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lockUntil = prefs.getInt(_lockKey(accountId, profileId)) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lockUntil > now) {
      final seconds = ((lockUntil - now) / 1000).ceil();
      throw StateError('Too many attempts. Try again in $seconds seconds.');
    }

    final saved = await _secure.read(key: _pinKey(accountId, profileId));
    if (saved == null || !isValidPin(saved)) {
      throw StateError('No PIN is configured for this profile on this device.');
    }
    if (saved == pin) {
      await prefs.remove(_attemptKey(accountId, profileId));
      await prefs.remove(_lockKey(accountId, profileId));
      return true;
    }

    final attempts = (prefs.getInt(_attemptKey(accountId, profileId)) ?? 0) + 1;
    if (attempts >= maxAttempts) {
      await prefs.setInt(_attemptKey(accountId, profileId), 0);
      await prefs.setInt(
        _lockKey(accountId, profileId),
        now + lockoutDuration.inMilliseconds,
      );
      throw StateError('Too many incorrect PINs. Try again in 60 seconds.');
    }
    await prefs.setInt(_attemptKey(accountId, profileId), attempts);
    return false;
  }

  static Future<bool> configureFromDialog(
    BuildContext context, {
    required String accountId,
    required String profileId,
    required String profileName,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ProfilePinSetupDialog(
            accountId: accountId,
            profileId: profileId,
            profileName: profileName,
          ),
        ) ??
        false;
  }

  static Future<bool> requestUnlock(
    BuildContext context, {
    required String accountId,
    required String profileId,
    required String profileName,
  }) async {
    if (!await hasPin(accountId: accountId, profileId: profileId)) {
      if (!context.mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Profile PIN not configured'),
          content: Text(
            'PIN protection is enabled for $profileName, but this device has no PIN stored for that profile. Ask the account owner to configure it in Profile Administration on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return false;
    }
    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ProfilePinUnlockDialog(
            accountId: accountId,
            profileId: profileId,
            profileName: profileName,
          ),
        ) ??
        false;
  }
}

class _ProfilePinSetupDialog extends StatefulWidget {
  const _ProfilePinSetupDialog({
    required this.accountId,
    required this.profileId,
    required this.profileName,
  });
  final String accountId;
  final String profileId;
  final String profileName;

  @override
  State<_ProfilePinSetupDialog> createState() => _ProfilePinSetupDialogState();
}

class _ProfilePinSetupDialogState extends State<_ProfilePinSetupDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!ProfilePinService.isValidPin(_pin.text)) {
      setState(() => _error = 'Enter 4 to 8 digits.');
      return;
    }
    if (_pin.text != _confirm.text) {
      setState(() => _error = 'The PIN entries do not match.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ProfilePinService.setPin(
        accountId: widget.accountId,
        profileId: widget.profileId,
        pin: _pin.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Set ${widget.profileName} PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This PIN is stored in this device’s secure storage. Set it separately on other devices.'),
            const SizedBox(height: 12),
            TextField(controller: _pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'New PIN', counterText: '4–8 digits')),
            TextField(controller: _confirm, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'Confirm PIN', counterText: '')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save PIN')),
        ],
      );
}

class _ProfilePinUnlockDialog extends StatefulWidget {
  const _ProfilePinUnlockDialog({
    required this.accountId,
    required this.profileId,
    required this.profileName,
  });
  final String accountId;
  final String profileId;
  final String profileName;

  @override
  State<_ProfilePinUnlockDialog> createState() => _ProfilePinUnlockDialogState();
}

class _ProfilePinUnlockDialogState extends State<_ProfilePinUnlockDialog> {
  final _pin = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() { _pin.dispose(); super.dispose(); }

  Future<void> _verify() async {
    setState(() { _checking = true; _error = null; });
    try {
      final valid = await ProfilePinService.verifyPin(
        accountId: widget.accountId,
        profileId: widget.profileId,
        pin: _pin.text,
      );
      if (!mounted) return;
      if (valid) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = 'That PIN is not correct.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Unlock ${widget.profileName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter this profile’s PIN to continue.'),
            const SizedBox(height: 12),
            TextField(controller: _pin, autofocus: true, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'Profile PIN', counterText: '')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
        actions: [
          TextButton(onPressed: _checking ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: _checking ? null : _verify, child: Text(_checking ? 'Checking…' : 'Unlock')),
        ],
      );
}
