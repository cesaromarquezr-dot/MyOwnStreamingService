// FILE: lib/navidrome_setup.dart.
// Stores per-profile Navidrome connection preferences. This is configuration only;
// it does not claim the server is reachable or authenticate with Navidrome.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_core.dart';
import 'localization.dart';

class NavidromeSetupScreen extends StatefulWidget {
  const NavidromeSetupScreen({super.key});
  @override
  State<NavidromeSetupScreen> createState() => _NavidromeSetupScreenState();
}

class _NavidromeSetupScreenState extends State<NavidromeSetupScreen> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  bool _scrobble = false;
  bool _offline = true;
  bool _loading = true;
  bool _saving = false;
  String get _prefix => 'navidrome_${AppController.instance.currentProfile?.id ?? 'default'}';

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _url.text = p.getString('${_prefix}_url') ?? '';
    _user.text = p.getString('${_prefix}_username') ?? '';
    _scrobble = p.getBool('${_prefix}_scrobble') ?? false;
    _offline = p.getBool('${_prefix}_offline') ?? true;
    if (mounted) setState(() => _loading = false);
  }
  Future<void> _save() async {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null || !uri.hasAuthority || !{'http','https'}.contains(uri.scheme)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid http:// or https:// Navidrome server URL.'))); return;
    }
    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();
    await p.setString('${_prefix}_url', uri.toString().replaceFirst(RegExp(r'/$'), ''));
    await p.setString('${_prefix}_username', _user.text.trim());
    await p.setBool('${_prefix}_scrobble', _scrobble);
    await p.setBool('${_prefix}_offline', _offline);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navidrome preferences saved on this device.')));
  }
  @override
  void dispose() { _url.dispose(); _user.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(appBar: AppBar(title: const UniversalText('Navidrome Music Server')), body: ListView(padding: const EdgeInsets.all(18), children: [
      const Card(child: ListTile(leading: Icon(Icons.library_music_rounded), title: Text('Your music, on your server'), subtitle: Text('Navidrome is a lightweight self-hosted music server with Subsonic-compatible clients. Run it on a computer or NAS and keep your music files in a library folder.'))),
      const SizedBox(height: 14),
      TextField(controller: _url, keyboardType: TextInputType.url, autocorrect: false, decoration: const InputDecoration(labelText: 'Server URL', hintText: 'https://music.example.com', prefixIcon: Icon(Icons.link), border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _user, autocorrect: false, decoration: const InputDecoration(labelText: 'Navidrome username (optional)', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
      const SizedBox(height: 8),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Enable scrobbling preference'), subtitle: const Text('ListenBrainz or another scrobble service must be connected separately.'), value: _scrobble, onChanged: (v) => setState(() => _scrobble = v)),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Plan for offline listening'), subtitle: const Text('Offline downloads depend on the chosen Subsonic-compatible client and its permissions.'), value: _offline, onChanged: (v) => setState(() => _offline = v)),
      const Card(child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Keep access secure'), subtitle: Text('Use HTTPS or a private VPN for remote access. Do not enter or store your Navidrome password here; authenticate only through a verified client or secure integration.'))),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_rounded), label: Text(_saving ? 'Saving…' : 'Save Navidrome settings')),
      const SizedBox(height: 10),
      const Text('Saving these preferences does not test connectivity, sign you in, install Navidrome, or import tracks. Those steps require a configured server API/client integration.'),
    ]));
  }
}
