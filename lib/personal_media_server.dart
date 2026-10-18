// FILE: lib/personal_media_server.dart.
// Purpose: Configure and explain a self-hosted personal media setup.
// These preferences describe the user's intended setup; they do not install
// third-party software or claim a provider is connected until it is verified.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'localization.dart';

class PersonalMediaServerScreen extends StatefulWidget {
  const PersonalMediaServerScreen({super.key});

  @override
  State<PersonalMediaServerScreen> createState() => _PersonalMediaServerScreenState();
}

class _PersonalMediaServerScreenState extends State<PersonalMediaServerScreen> {
  static const _hosts = <String, String>{
    'existing_computer': 'Existing laptop or desktop',
    'nas': 'NAS (e.g. TerraMaster F2-212)',
    'dedicated': 'Dedicated home server',
  };
  static const _servers = <String, String>{
    'built_in': 'MyOwnStreamingService library',
    'jellyfin': 'Jellyfin',
    'navidrome': 'Navidrome (music server)',
    'plex': 'Plex',
    'dlna': 'DLNA media server',
  };
  static const _remoteModes = <String, String>{
    'local_only': 'Home network only (recommended to start)',
    'vpn': 'Private VPN (recommended for remote access)',
    'https_proxy': 'HTTPS reverse proxy with authentication',
  };

  String _host = 'existing_computer';
  String _server = 'built_in';
  String _remoteMode = 'local_only';
  bool _autoScan = true;
  bool _transcoding = false;
  bool _loading = true;
  bool _saving = false;
  String? _lastSaved;

  String get _keyPrefix {
    final profileId = AppController.instance.currentProfile?.id;
    return profileId == null ? 'personal_media_server' : 'personal_media_server_$profileId';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _host = prefs.getString('${_keyPrefix}_host') ?? _host;
      _server = prefs.getString('${_keyPrefix}_software') ?? _server;
      _remoteMode = prefs.getString('${_keyPrefix}_remote') ?? _remoteMode;
      _autoScan = prefs.getBool('${_keyPrefix}_auto_scan') ?? _autoScan;
      _transcoding = prefs.getBool('${_keyPrefix}_transcoding') ?? _transcoding;
      _lastSaved = prefs.getString('${_keyPrefix}_saved_at');
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toLocal().toString().substring(0, 16);
      await Future.wait([
        prefs.setString('${_keyPrefix}_host', _host),
        prefs.setString('${_keyPrefix}_software', _server),
        prefs.setString('${_keyPrefix}_remote', _remoteMode),
        prefs.setBool('${_keyPrefix}_auto_scan', _autoScan),
        prefs.setBool('${_keyPrefix}_transcoding', _transcoding),
        prefs.setString('${_keyPrefix}_saved_at', now),
      ]);
      if (!mounted) return;
      setState(() {
        _lastSaved = now;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal media server preferences saved on this device.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save preferences: $error')),
      );
    }
  }

  List<String> get _steps {
    final hostStep = switch (_host) {
      'nas' => '1. Set up your NAS (for example, a compatible TerraMaster 2-bay model), create a dedicated media share, and restrict it to trusted users. Verify supported drive capacities and redundancy options in the current NAS documentation.',
      'dedicated' => '1. Install a supported operating system on the dedicated server and use a separate media data volume.',
      _ => '1. Reuse your laptop or desktop first; keep it powered, updated, and on your trusted home network.',
    };
    final serverStep = switch (_server) {
      'jellyfin' => '2. Install Jellyfin on the host, add read-only media library paths first, and verify playback locally.',
      'navidrome' => '2. Deploy Navidrome on the host, map your authorized music folder read-only where practical, and test a Subsonic-compatible client on your home network.',
      'plex' => '2. Install Plex Media Server on the host, create libraries, and test playback on your home network.',
      'dlna' => '2. Enable the host’s DLNA server and check that your TV or player can discover it on the same home network. DLNA is a simple local-network option; it may offer less library organization than Jellyfin or Plex.',
      _ => '2. Use the MyOwnStreamingService server agent and library APIs; media files remain on your configured home storage.',
    };
    return [
      hostStep,
      serverStep,
      '3. Organize authorized files into Movies, TV Shows, and Music folders; match metadata and check for duplicates. Keep a separate backup of irreplaceable files.',
      '4. Test direct play, subtitles, audio tracks, backups, and storage alerts before enabling remote access.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const UniversalText('Personal Media Server')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.colorScheme.primaryContainer, theme.colorScheme.surfaceContainerHighest],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.video_library_rounded, size: 38),
              const SizedBox(height: 12),
              Text('Your library. Your hardware. Your rules.', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Start with a computer you already own, or use a NAS for always-on storage. Keep the files on your server and use MyOwnStreamingService to organize and discover them.'),
            ]),
          ),
          const SizedBox(height: 16),
          _sectionTitle('1. Choose your hardware'),
          DropdownButtonFormField<String>(
            initialValue: _host,
            decoration: const InputDecoration(labelText: 'Server host', border: OutlineInputBorder()),
            items: _hosts.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (value) => setState(() => _host = value ?? _host),
          ),
          const SizedBox(height: 8),
          const Text('A NAS is convenient for always-on storage, but an old laptop is a valid low-cost starting point. Choose storage capacity and backup strategy before buying hardware.'),
          if (_host == 'nas') ...[
            const SizedBox(height: 10),
            const Card(child: ListTile(
              leading: Icon(Icons.storage_rounded),
              title: Text('NAS buying and storage checklist'),
              subtitle: Text('The TerraMaster F2-212 is one example of a compact two-bay NAS. Confirm current drive-size compatibility, usable capacity, RAID trade-offs, network speed, and backup needs before purchasing. RAID is not a backup; keep another copy of important media.'),
            )),
          ],
          const SizedBox(height: 20),
          _sectionTitle('2. Choose your playback server'),
          DropdownButtonFormField<String>(
            initialValue: _server,
            decoration: const InputDecoration(labelText: 'Media server software', border: OutlineInputBorder()),
            items: _servers.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (value) => setState(() => _server = value ?? _server),
          ),
          const SizedBox(height: 8),
          const Text('Plex and Jellyfin offer a poster-rich library interface; Navidrome is designed for music; DLNA is a simpler option for compatible devices. Selecting an option here records your plan—it does not install or connect that software.'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Row(children: [Icon(Icons.album_rounded), SizedBox(width: 8), Expanded(child: Text('From physical media to your private library', style: TextStyle(fontWeight: FontWeight.w800)))]),
                SizedBox(height: 10),
                Text('1. Keep your discs and use media files you are authorized to create and store.'),
                SizedBox(height: 6),
                Text('2. If you are entitled to make a personal digital copy, use a compatible tool and follow local law and the disc/software terms. This app does not rip discs or bypass DRM.'),
                SizedBox(height: 6),
                Text('3. Place supported video files (often MKV) in your Movies or TV Shows share, and music in Music; keep filenames and metadata tidy.'),
                SizedBox(height: 6),
                Text('4. Start with DLNA for compatible TVs on your home network, or choose Jellyfin/Plex for richer browsing, artwork, and library management.'),
                SizedBox(height: 6),
                Text('5. Test playback locally, then configure secure remote access only if needed. Never expose NAS administration directly to the public internet.'),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('3. Playback and library behavior'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Scan library for new media'),
            subtitle: const Text('Preference only; scanning requires a configured server-agent connection.'),
            value: _autoScan,
            onChanged: (value) => setState(() => _autoScan = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Plan for video transcoding'),
            subtitle: const Text('Transcoding needs compatible CPU/GPU hardware and software. Direct play is usually less demanding.'),
            value: _transcoding,
            onChanged: (value) => setState(() => _transcoding = value),
          ),
          const SizedBox(height: 12),
          _sectionTitle('4. Remote access'),
          DropdownButtonFormField<String>(
            initialValue: _remoteMode,
            decoration: const InputDecoration(labelText: 'Access policy', border: OutlineInputBorder()),
            items: _remoteModes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (value) => setState(() => _remoteMode = value ?? _remoteMode),
          ),
          const SizedBox(height: 8),
          const Card(child: ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Security defaults matter'),
            subtitle: Text('Keep local-only access until tested. For remote access, prefer a private VPN or authenticated HTTPS reverse proxy. Do not expose the raw backend port or NAS credentials to the internet.'),
          )),
          const SizedBox(height: 20),
          _sectionTitle('Your setup checklist'),
          ..._steps.map((step) => Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.checklist_rounded), const SizedBox(width: 10), Expanded(child: Text(step))])))),
          const Card(child: ListTile(
            leading: Icon(Icons.policy_outlined),
            title: Text('Use media you are authorized to access'),
            subtitle: Text('Import and playback tools are for authorized personal media. Do not use the service to distribute pirated content or bypass DRM or other access controls. A disc title or barcode alone cannot prove legal authorization.'),
          )),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving…' : 'Save setup preferences'),
          ),
          if (_lastSaved != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Last saved on this device: $_lastSaved', textAlign: TextAlign.center, style: theme.textTheme.bodySmall)),
          const SizedBox(height: 8),
          Text('These preferences are stored locally on this device. Server discovery, third-party installation, remote access, and automatic ripping are separate integrations and are not activated by saving this page.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
  );
}
