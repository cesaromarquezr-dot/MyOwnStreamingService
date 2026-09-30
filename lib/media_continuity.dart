import 'package:flutter/material.dart';

import 'app_core.dart';

/// Account-scoped presentation and editing surface for canonical versions,
/// version-specific scenes, and typed story relationships.
class MediaContinuityPanel extends StatefulWidget {
  final String mediaId;
  final String mediaTitle;

  const MediaContinuityPanel({
    super.key,
    required this.mediaId,
    required this.mediaTitle,
  });

  @override
  State<MediaContinuityPanel> createState() => _MediaContinuityPanelState();
}

class _MediaContinuityPanelState extends State<MediaContinuityPanel> {
  static const _recordType = 'media_continuity';
  late Future<Map<String, dynamic>?> _record;
  bool _saving = false;

  String get _recordKey => 'media_continuity:${widget.mediaId}';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant MediaContinuityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) _reload();
  }

  void _reload() {
    final api = AppController.instance.backendApi;
    _record = api.isAuthenticated
        ? api.getPhase2Records(recordType: _recordType).then((records) {
            for (final record in records) {
              if (record['recordKey'] == _recordKey && record['data'] is Map) {
                return Map<String, dynamic>.from(record['data'] as Map);
              }
            }
            return null;
          })
        : Future<Map<String, dynamic>?>.value(null);
  }

  Future<void> _save(Map<String, dynamic> data) async {
    setState(() => _saving = true);
    try {
      await AppController.instance.backendApi.savePhase2Record(
        recordType: _recordType,
        recordKey: _recordKey,
        data: {
          'mediaId': widget.mediaId,
          'mediaTitle': widget.mediaTitle,
          ...data,
        },
      );
      _reload();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save media connections: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addVersion(Map<String, dynamic> current) async {
    final name = TextEditingController();
    final cut = TextEditingController();
    final formats = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a version'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Version name', hintText: 'Encore')),
            TextField(controller: cut, decoration: const InputDecoration(labelText: 'Cut or edition notes')),
            TextField(controller: formats, decoration: const InputDecoration(labelText: 'Physical formats', hintText: 'DVD, Blu-ray, 4K UHD')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add version')),
        ],
      ),
    );
    final versionName = name.text.trim();
    final cutNotes = cut.text.trim();
    final physicalFormats = formats.text.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
    name.dispose(); cut.dispose(); formats.dispose();
    if (confirmed != true || versionName.isEmpty) return;
    final versions = _maps(current['versions']);
    versions.add({
      'id': 'version_${DateTime.now().microsecondsSinceEpoch}',
      'name': versionName,
      'cut': cutNotes,
      'physicalFormats': physicalFormats,
      'scenes': <Map<String, dynamic>>[],
    });
    await _save({...current, 'versions': versions});
  }

  Future<void> _addScene(Map<String, dynamic> current, int versionIndex) async {
    final sceneTitle = TextEditingController();
    final position = TextEditingController();
    final storyDate = TextEditingController();
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a version scene'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: sceneTitle, decoration: const InputDecoration(labelText: 'Scene title', hintText: 'TVA incursion scene')),
            TextField(controller: position, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Story order', hintText: '1')),
            TextField(controller: storyDate, decoration: const InputDecoration(labelText: 'Story-time note', hintText: 'After Spider-Man: Brand New Day')),
            TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add scene')),
        ],
      ),
    );
    final title = sceneTitle.text.trim();
    final values = {
      'title': title,
      'storyOrder': int.tryParse(position.text.trim()),
      'storyTime': storyDate.text.trim(),
      'description': note.text.trim(),
    };
    sceneTitle.dispose(); position.dispose(); storyDate.dispose(); note.dispose();
    if (confirmed != true || title.isEmpty) return;
    final versions = _maps(current['versions']);
    if (versionIndex >= versions.length) return;
    final version = versions[versionIndex];
    final scenes = _maps(version['scenes'])..add(values);
    versions[versionIndex] = {...version, 'scenes': scenes};
    await _save({...current, 'versions': versions});
  }

  Future<void> _addRelationship(Map<String, dynamic> current) async {
    final target = TextEditingController();
    final targetId = TextEditingController();
    final type = TextEditingController(text: 'leads_into');
    final timing = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Link a story'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: target, decoration: const InputDecoration(labelText: 'Related title')),
          TextField(controller: targetId, decoration: const InputDecoration(labelText: 'Canonical media ID (optional)')),
          TextField(controller: type, decoration: const InputDecoration(labelText: 'Relationship', hintText: 'leads_into / sequel_to')),
          TextField(controller: timing, decoration: const InputDecoration(labelText: 'Story timing note')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add link')),
        ],
      ),
    );
    final title = target.text.trim();
    final id = targetId.text.trim();
    final relationshipType = type.text.trim();
    final storyTime = timing.text.trim();
    target.dispose(); targetId.dispose(); type.dispose(); timing.dispose();
    if (confirmed != true || title.isEmpty || relationshipType.isEmpty) return;
    final relationships = _maps(current['relationships'])
      ..add({
        'title': title,
        if (id.isNotEmpty) 'mediaId': id,
        'type': relationshipType,
        'storyTime': storyTime,
      });
    await _save({...current, 'relationships': relationships});
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
      : <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
        future: _record,
        builder: (context, snapshot) {
          final record = snapshot.data ?? const <String, dynamic>{};
          final versions = _maps(record['versions']);
          final relationships = _maps(record['relationships']);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('Versions & story connections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  IconButton(
                    onPressed: _saving || !AppController.instance.backendApi.isAuthenticated
                        ? null
                        : () => _addVersion(record),
                    tooltip: 'Add version',
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ]),
                if (!AppController.instance.backendApi.isAuthenticated)
                  const Text('Sign in to save versions and story connections.', style: TextStyle(color: Colors.white60))
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator()
                else if (versions.isEmpty && relationships.isEmpty)
                  const Text('Add alternate cuts, their physical editions, version-specific scenes, and story links.', style: TextStyle(color: Colors.white60))
                else ...[
                  for (var index = 0; index < versions.length; index++)
                    _versionTile(record, versions[index], index),
                  for (final relationship in relationships)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_tree_outlined),
                      title: Text('${relationship['type']} → ${relationship['title']}'),
                      subtitle: [
                        if (relationship['storyTime']?.toString().trim().isNotEmpty ?? false)
                          relationship['storyTime'].toString(),
                        if (relationship['mediaId']?.toString().trim().isNotEmpty ?? false)
                          'ID: ${relationship['mediaId']}',
                      ].isEmpty ? null : Text([
                        if (relationship['storyTime']?.toString().trim().isNotEmpty ?? false)
                          relationship['storyTime'].toString(),
                        if (relationship['mediaId']?.toString().trim().isNotEmpty ?? false)
                          'ID: ${relationship['mediaId']}',
                      ].join(' · ')),
                    ),
                ],
                if (AppController.instance.backendApi.isAuthenticated)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving ? null : () => _addRelationship(record),
                      icon: const Icon(Icons.add_link),
                      label: const Text('Link another story'),
                    ),
                  ),
                if (_saving) const LinearProgressIndicator(),
              ]),
            ),
          );
        },
      );

  Widget _versionTile(Map<String, dynamic> record, Map<String, dynamic> version, int index) {
    final scenes = _maps(version['scenes'])..sort((a, b) => ((a['storyOrder'] as num?)?.toInt() ?? 999).compareTo((b['storyOrder'] as num?)?.toInt() ?? 999));
    final formats = (version['physicalFormats'] as List?)?.map((item) => item.toString()).join(', ') ?? '';
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(version['name']?.toString() ?? 'Version'),
      subtitle: Text([version['cut'], if (formats.isNotEmpty) formats].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ')),
      children: [
        for (final scene in scenes)
          ListTile(
            dense: true,
            leading: const Icon(Icons.movie_filter_outlined),
            title: Text(scene['title']?.toString() ?? 'Scene'),
            subtitle: Text([
              if (scene['storyTime']?.toString().trim().isNotEmpty ?? false) scene['storyTime'].toString(),
              if (scene['description']?.toString().trim().isNotEmpty ?? false) scene['description'].toString(),
            ].join(' · ')),
            trailing: scene['storyOrder'] == null ? null : Text('#${scene['storyOrder']}'),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _saving ? null : () => _addScene(record, index),
            icon: const Icon(Icons.add),
            label: const Text('Add scene'),
          ),
        ),
      ],
    );
  }
}
