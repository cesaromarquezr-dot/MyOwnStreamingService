// FILE: lib/storage_dashboard.dart
// Live, read-only view of the authenticated home-server storage endpoint.
// It never invents usage values and never mutates media files.

import 'package:flutter/material.dart';
import 'app_core.dart';
import 'localization.dart';

const Map<String, Color> namedColors = {
  'Red': Colors.red, 'Blue': Colors.blue, 'Black': Colors.black,
  'White': Colors.white, 'Yellow': Colors.yellow, 'Green': Colors.green,
  'Purple': Colors.purple, 'Violet': Color.fromARGB(255, 238, 130, 238),
  'Indigo': Colors.indigo, 'Pink': Colors.pink,
  'Maroon': Color.fromARGB(255, 128, 0, 0), 'Fuchsia': Color.fromARGB(255, 255, 0, 255),
  'Aqua': Color.fromARGB(255, 0, 255, 255), 'Cyan': Colors.cyan,
  'Orange': Colors.orange, 'Brown': Colors.brown, 'Lime': Colors.lime,
  'Teal': Colors.teal, 'Amber': Colors.amber, 'Grey': Colors.grey,
};

class StorageDashboardScreen extends StatefulWidget {
  const StorageDashboardScreen({super.key});
  static String formatBytes(int bytes) {
    if (bytes < 0) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB', 'PB'];
    var value = bytes / 1024.0;
    var index = 0;
    while (value >= 1024 && index < units.length - 1) { value /= 1024; index++; }
    return '${value.toStringAsFixed(value >= 100 ? 0 : value >= 10 ? 1 : 2)} ${units[index]}';
  }
  @override
  State<StorageDashboardScreen> createState() => _StorageDashboardScreenState();
}

class _StorageDashboardScreenState extends State<StorageDashboardScreen> {
  bool loading = true;
  String? error;
  DateTime? lastUpdated;
  Map<String, dynamic>? snapshot;
  Map<String, dynamic>? armSnapshot;
  final Map<String, Color> colors = <String, Color>{
    'Movies': Colors.red, 'Series': Colors.blue, 'Music': Colors.purple,
  };

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    if (!AppController.instance.backendApi.isAuthenticated) {
      if (!mounted) return;
      setState(() { loading = false; error = 'Sign in to view live home-server storage. No values are estimated.'; });
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait<dynamic>([
        AppController.instance.backendApi.getHomeServerStorage(),
        AppController.instance.backendApi.getHomeServerArm(),
      ]);
      if (!mounted) return;
      setState(() {
        snapshot = Map<String, dynamic>.from(results[0] as Map);
        armSnapshot = Map<String, dynamic>.from(results[1] as Map);
        lastUpdated = DateTime.now(); loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  List<Map<String, dynamic>> get categories {
    final raw = snapshot?['categories'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();
  }

  Map<String, dynamic>? _filesystemFor(String path) {
    final filesystem = snapshot?['filesystem'];
    if (filesystem is! Map) return null;
    final byPath = filesystem['categories'];
    if (byPath is! Map) return null;
    final value = byPath[path];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  int? _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  @override
  Widget build(BuildContext context) {
    final usedTotal = categories.fold<int>(0, (sum, item) => sum + (_int(item['usedBytes']) ?? 0));
    final configuredTotal = categories.fold<int>(0, (sum, item) => sum + (_int(item['capacityBytes']) ?? 0));
    final available = _int(snapshot?['availableBytes']);
    final root = snapshot?['root']?.toString() ?? 'Not reported';
    return Scaffold(
      appBar: AppBar(title: const UniversalText('Server Storage'), actions: [
        IconButton(tooltip: 'Refresh live storage and filesystem health', onPressed: loading ? null : _refresh, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
        if (error != null) Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent), const SizedBox(width: 10), Expanded(child: Text(error!))]))),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary.withValues(alpha: .24), Theme.of(context).colorScheme.surface])), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const UniversalText('Storage health overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6), Text('Media root: $root', style: const TextStyle(color: Colors.white70)),
          if (lastUpdated != null) Text('Last checked: ${lastUpdated!.toLocal().toString().split('.').first}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _metric('Reported media used', StorageDashboardScreen.formatBytes(usedTotal), Icons.storage_rounded),
            _metric('Configured category capacity', configuredTotal > 0 ? StorageDashboardScreen.formatBytes(configuredTotal) : 'Not configured', Icons.pie_chart_outline_rounded),
            _metric('Additional configured space', available == null ? 'Unknown' : StorageDashboardScreen.formatBytes(available), Icons.add_circle_outline_rounded),
          ]),
        ])),
        const SizedBox(height: 16),
        const UniversalText('Media categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        if (categories.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(14), child: UniversalText('The server returned no category measurements. Check the home-server service configuration; this screen does not substitute placeholder zeroes.'))),
        for (final category in categories) _categoryCard(category),
        const SizedBox(height: 14),
        const UniversalText('Filesystem health', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        for (final category in categories) _filesystemCard(category),
        const SizedBox(height: 14),
        Card(child: ListTile(leading: Icon(armSnapshot?['connected'] == true ? Icons.check_circle_rounded : Icons.cloud_off_rounded, color: armSnapshot?['connected'] == true ? Colors.greenAccent : Colors.orangeAccent), title: const Text('ARM / media import worker'), subtitle: Text('${armSnapshot?['armServerUrl'] ?? 'Not configured'}\nDrive: ${armSnapshot?['opticalDriveHint'] ?? 'Unknown'}'), isThreeLine: true, trailing: Icon(armSnapshot?['connected'] == true ? Icons.check_rounded : Icons.warning_amber_rounded))),
        const SizedBox(height: 12),
        _architectureCard(Icons.storage_rounded, 'HDD / ZFS media pool', 'Use redundant storage for availability, snapshots for quick rollback, and separate replication for disaster recovery. RAID/ZFS redundancy is not a backup.'),
        _architectureCard(Icons.speed_rounded, 'SSD metadata and transcode cache', 'Keep artwork thumbnails, indexes, databases and disposable transcodes on a fast tier where appropriate. Do not treat cache files as source media.'),
        _architectureCard(Icons.backup_rounded, 'Backup and restore verification', 'Monitor backup freshness, checksum verification, destination capacity and last successful restore drill. A backup is not proven until it has been restored.'),
        _architectureCard(Icons.battery_charging_full_rounded, 'UPS and clean shutdown', 'Monitor UPS battery, shutdown integration and storage health alerts from the server-side monitoring agent.'),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _editColors, icon: const Icon(Icons.palette_outlined), label: const UniversalText('Customize storage colors')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _showInfo, icon: const Icon(Icons.info_outline_rounded), label: const UniversalText('How storage is measured')),
      ]),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Container(width: 155, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60))]));

  Widget _categoryCard(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Media';
    final path = item['path']?.toString() ?? '';
    final usedBytes = _int(item['usedBytes']);
    final capacity = _int(item['capacityBytes']);
    final usage = item['usagePercent'] is num ? ((item['usagePercent'] as num).toDouble() / 100).clamp(0.0, 1.0).toDouble() : (capacity != null && capacity > 0 && usedBytes != null ? (usedBytes / capacity).clamp(0.0, 1.0).toDouble() : null);
    final exists = item['exists'] == true;
    final color = colors[name] ?? Theme.of(context).colorScheme.primary;
    return Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.folder_rounded, color: color), const SizedBox(width: 9), Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900))), Text(usedBytes == null ? 'Unknown' : StorageDashboardScreen.formatBytes(usedBytes), style: const TextStyle(fontWeight: FontWeight.w800))]),
      const SizedBox(height: 6), Text(path, style: const TextStyle(fontSize: 12, color: Colors.white54), maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 10), LinearProgressIndicator(value: usage, minHeight: 10, backgroundColor: Colors.white12, color: usage != null && usage >= .9 ? Colors.redAccent : color),
      const SizedBox(height: 7),
      Row(children: [Expanded(child: Text('Configured: ${capacity == null || capacity == 0 ? 'Not set' : StorageDashboardScreen.formatBytes(capacity)}', style: const TextStyle(fontSize: 12, color: Colors.white60))), Text(exists ? 'Directory found' : 'Directory missing', style: TextStyle(fontSize: 12, color: exists ? Colors.greenAccent : Colors.orangeAccent))]),
      if (usage != null && usage >= .9) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Warning: configured category usage is at or above 90%. Review free space before importing more media.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
    ])));
  }

  Widget _filesystemCard(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Media';
    final fs = _filesystemFor(item['path']?.toString() ?? '');
    final total = _int(fs?['totalBytes']);
    final free = _int(fs?['freeBytes']);
    final used = _int(fs?['usedBytes']);
    final known = total != null && free != null && total > 0;
    final safeTotal = total ?? 0;
    final safeFree = free ?? 0;
    final safeUsed = used ?? (safeTotal >= safeFree ? safeTotal - safeFree : 0);
    final pct = safeTotal > 0 ? safeUsed / safeTotal : null;
    final summary = known
        ? '${StorageDashboardScreen.formatBytes(safeUsed)} used of ${StorageDashboardScreen.formatBytes(safeTotal)} · ${StorageDashboardScreen.formatBytes(safeFree)} free${pct != null && pct >= .9 ? '\nFilesystem is at or above 90% used.' : ''}'
        : 'Filesystem capacity is not available from the host OS for this configured path.';
    return Card(child: ListTile(leading: Icon(known ? Icons.check_circle_outline_rounded : Icons.help_outline_rounded, color: known ? Colors.greenAccent : Colors.orangeAccent), title: Text('$name filesystem'), subtitle: Text(summary), isThreeLine: true, trailing: known && pct != null && pct >= .9 ? const Icon(Icons.warning_rounded, color: Colors.orangeAccent) : null));
  }

  Widget _architectureCard(IconData icon, String title, String description) => Card(child: ListTile(leading: Icon(icon), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text(description))));

  Future<void> _editColors() async {
    final names = categories.map((c) => c['name']?.toString() ?? 'Media').toList();
    if (names.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No storage categories are available to customize.'))); return; }
    final selectedCategory = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(title: const Text('Choose a category'), children: [for (final name in names) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, name), child: Text(name))]));
    if (selectedCategory == null || !mounted) return;
    final selectedColorName = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(title: Text('$selectedCategory color'), children: [for (final entry in namedColors.entries) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, entry.key), child: Row(children: [Container(width: 20, height: 20, decoration: BoxDecoration(color: entry.value, shape: BoxShape.circle)), const SizedBox(width: 10), Text(entry.key)]))]));
    if (selectedColorName == null || !mounted) return;
    setState(() => colors[selectedCategory] = namedColors[selectedColorName] ?? Colors.grey);
  }

  void _showInfo() => showDialog<void>(context: context, builder: (_) => const AlertDialog(title: UniversalText('Storage measurements'), content: UniversalText('Configured category usage measures files under the server media directories. Filesystem usage is reported separately when the host operating system can inspect the volume. Unknown values remain unknown; the dashboard does not treat missing measurements as zero. Storage capacity and physical free space can differ.')));
}
