// FILE: `lib/self_hosting_settings.dart`.
// Purpose: Displays the authenticated home-server self-hosting status and
// explains the public HTTPS/reverse-proxy connection used by the app.

import 'package:flutter/material.dart';

import 'app_core.dart';

/// Displays Cloudflare, reverse-proxy, DDNS, VPN, and port status.
class SelfHostingSettingsScreen extends StatefulWidget {
  const SelfHostingSettingsScreen({super.key});

  @override
  State<SelfHostingSettingsScreen> createState() => _SelfHostingSettingsScreenState();
}

class _SelfHostingSettingsScreenState extends State<SelfHostingSettingsScreen> {
  Map<String, dynamic>? status;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await AppController.instance.backendApi.getSelfHostingStatus();
      if (mounted) setState(() => status = value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Self-hosting & Server Connection')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Card(child: ListTile(
            leading: Icon(Icons.security),
            title: Text('Production connection'),
            subtitle: Text('Use the public HTTPS hostname. The internal Dart port should remain behind the firewall and reverse proxy.'),
          )),
          if (error != null) Card(child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('Status unavailable'),
            subtitle: Text(error!),
          )),
          if (status != null) ...[
            _item('Public URL', status!['publicUrl']),
            _item('DDNS hostname', (status!['ddns'] as Map?)?['hostname']),
            _item('DDNS provider', (status!['ddns'] as Map?)?['provider']),
            _item('Reverse proxy required', (status!['reverseProxy'] as Map?)?['required']),
            _item('VPN configured', (status!['vpn'] as Map?)?['configured']),
            _item('Public HTTPS port', (status!['ports'] as Map?)?['publicHttps']),
            _item('Internal backend port', (status!['ports'] as Map?)?['internalBackend']),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh status')),
        ],
      ),
    );
  }

  Widget _item(String label, Object? value) => Card(
    child: ListTile(title: Text(label), subtitle: Text(value?.toString().isNotEmpty == true ? value.toString() : 'Not configured')),
  );
}
