import 'package:flutter/material.dart';

import 'app_core.dart';

class LibraryPrivacyScreen extends StatefulWidget {
  const LibraryPrivacyScreen({super.key});

  @override
  State<LibraryPrivacyScreen> createState() => _LibraryPrivacyScreenState();
}

class _LibraryPrivacyScreenState extends State<LibraryPrivacyScreen> {
  bool privateLibrary = true;
  bool allowUsageDiagnostics = true;
  bool ownershipConfirmed = false;
  bool deleteMediaOnAccountDeletion = true;

  Future<void> _deleteAccount() async {
    if (!deleteMediaOnAccountDeletion) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account and library?'),
        content: const Text(
          'This requests account deletion and removal of stored media according to the service deletion policy. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete account')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppController.instance.backendApi.deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion request completed.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = AppController.instance.currentAccount;
    final used = account?.storageUsedBytes ?? 0;
    final limit = account?.storageLimitBytes ?? 0;
    final ratio = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Ownership')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PolicyCard(
            icon: Icons.verified_user_outlined,
            title: 'Your library is private',
            body: 'Media is associated with your account/profile and must be protected by backend authorization and database row-level security. Normal service operation should not require manual inspection of your personal library.',
          ),
          const SizedBox(height: 14),
          _PolicyCard(
            icon: Icons.copyright_outlined,
            title: 'Authorized personal media',
            body: 'Only import content you own or are legally authorized to copy and use. Owning a physical disc does not by itself guarantee every form of copying or remote streaming is lawful in every country.',
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            title: const Text('Private library'),
            subtitle: const Text('Keep your collection isolated from other accounts.'),
            value: privateLibrary,
            onChanged: (v) => setState(() => privateLibrary = v),
          ),
          SwitchListTile(
            title: const Text('Usage diagnostics'),
            subtitle: const Text('Allow privacy-conscious service diagnostics and reliability metrics.'),
            value: allowUsageDiagnostics,
            onChanged: (v) => setState(() => allowUsageDiagnostics = v),
          ),
          SwitchListTile(
            title: const Text('Delete stored media with account deletion'),
            subtitle: const Text('Queue the account library and its derived media for deletion according to the retention policy.'),
            value: deleteMediaOnAccountDeletion,
            onChanged: (v) => setState(() => deleteMediaOnAccountDeletion = v),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STORAGE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: ratio),
                  const SizedBox(height: 8),
                  Text('${_formatBytes(used)} used of ${_formatBytes(limit)}'),
                  const SizedBox(height: 8),
                  const Text('Storage includes originals, streaming versions, thumbnails and other derived media where applicable.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('IMPORT DECLARATION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  const Text('Before adding disc-based media, confirm that you own or are legally authorized to use the content and understand that local law controls what copying and remote streaming are permitted.'),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: ownershipConfirmed,
                    onChanged: (v) => setState(() => ownershipConfirmed = v ?? false),
                    title: const Text('I confirm authorized use of the media I import.'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _showPolicy(context),
            icon: const Icon(Icons.description_outlined),
            label: const Text('VIEW OWNERSHIP & PRIVACY POLICY'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: deleteMediaOnAccountDeletion ? _deleteAccount : null,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('DELETE ACCOUNT & STORED LIBRARY'),
          ),
        ],
      ),
    );
  }

  void _showPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      builder: (_) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 22, 22, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your content. Your library.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              SizedBox(height: 12),
              Text('My Streaming Service provides applications, storage and streaming infrastructure for customers managing authorized personal media. The service does not grant ownership or copyright rights in movies, shows, music or other works.'),
              SizedBox(height: 12),
              Text('Privacy: Your library should be isolated from other customers. Service providers may still process technical data, metadata, security events and information necessary to operate, secure and comply with lawful requests.'),
              SizedBox(height: 12),
              Text('Deletion: Account deletion can queue stored media, transcoded versions, thumbnails and associated library records for deletion under the service retention policy.'),
              SizedBox(height: 12),
              Text('Legal use: Customers are responsible for ensuring that importing, storing, copying and remotely streaming their media is permitted by applicable law.'),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _PolicyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PolicyCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(body, style: TextStyle(color: Colors.grey.shade300, height: 1.35)),
            ])),
          ],
        ),
      ),
    );
  }
}
