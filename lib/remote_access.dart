import 'package:flutter/material.dart';
import 'backend_api.dart';

class RemoteAccessScreen extends StatefulWidget {
  const RemoteAccessScreen({super.key});
  @override State<RemoteAccessScreen> createState() => _RemoteAccessScreenState();
}

class _RemoteAccessScreenState extends State<RemoteAccessScreen> {
  final api = BackendApi();
  bool loading = false;
  String? code;
  List<dynamic> workers = [];

  Future<void> loadWorkers() async {
    setState(() => loading = true);
    try { final data = await api.getRemoteWorkers(); if (mounted) setState(() => workers = data['workers'] as List? ?? []); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    if (mounted) setState(() => loading = false);
  }

  Future<void> generateCode() async {
    try { final data = await api.createRemoteAccessCode(); if (mounted) setState(() => code = data['code']?.toString()); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Remote Access & Disc Ripping')),
    body: RefreshIndicator(onRefresh: loadWorkers, child: ListView(padding: const EdgeInsets.all(18), children: [
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Access from another house', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('People who live elsewhere can sign in normally when your server is securely reachable. A paired computer can also act as a remote disc-import worker. Everything it imports goes into the shared account library, so every profile can watch it.'),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: loading ? null : generateCode, icon: const Icon(Icons.password_rounded), label: const Text('Generate one-time worker code')),
        if (code != null) ...[const SizedBox(height: 14), SelectableText(code!, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 5)), const Text('Expires in 10 minutes. Use it only on the computer you trust.', style: TextStyle(color: Colors.white54))],
      ]))),
      const SizedBox(height: 14),
      const Text('Remote computers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if (workers.isEmpty) Card(child: const ListTile(leading: Icon(Icons.computer_rounded), title: Text('No remote computers paired'), subtitle: Text('Install the worker on a computer with an internal or external universal disc reader.'))),
      ...workers.map((w) => Card(child: ListTile(leading: const Icon(Icons.computer_rounded), title: Text(w['name']?.toString() ?? 'Remote computer'), subtitle: Text('${w['platform'] ?? 'Unknown'} • ${w['hasDiscReader'] == true ? 'Disc reader' : 'No internal reader'}${w['supportsExternalReader'] == true ? ' • External reader supported' : ''}')))),
      const SizedBox(height: 14),
      Card(child: const Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How remote ripping works', style: TextStyle(fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        Text('1. Pair a trusted computer with a one-time code.\n2. Insert a DVD, Blu-ray, or 4K UHD disc into its internal or external reader.\n3. Start a remote import from the trusted computer.\n4. The worker reports detecting → identifying → ripping → processing → completed.\n5. The finished movie or TV show is added to the shared account library and is immediately available to every profile; the account owner can receive an email notification.'),
        SizedBox(height: 8),
        Text('The computer/reader integration still needs a real disc-ripping engine and its legal/licensed workflow. The app does not bypass DRM.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]))),
    ])),
  );
}
