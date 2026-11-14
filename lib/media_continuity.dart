import 'package:material_ui/material_ui.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'localization.dart';

import 'backend_api_compatibility.dart';

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

/// Shows canonical production links without combining season numbering.
/// A continuation appears as its own production and owns its own seasons.
class MediaFranchiseConnectionsPanel extends StatefulWidget {
  final String mediaId;
  final bool hasSeasons;

  const MediaFranchiseConnectionsPanel(
      {super.key, required this.mediaId, this.hasSeasons = false});

  @override
  State<MediaFranchiseConnectionsPanel> createState() =>
      _MediaFranchiseConnectionsPanelState();
}

class MediaMetadataProvenancePanel extends StatefulWidget {
  const MediaMetadataProvenancePanel({
    super.key,
    required this.media,
  });

  final MediaItem media;

  @override
  State<MediaMetadataProvenancePanel> createState() =>
      _MediaMetadataProvenancePanelState();
}

class _MediaMetadataProvenancePanelState
    extends State<MediaMetadataProvenancePanel> {
  static const String _recordType = 'media_metadata_provenance';
  late Future<Map<String, dynamic>> _record;
  bool _saving = false;

  String get _recordKey => 'media:${widget.media.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MediaMetadataProvenancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.id != widget.media.id) _load();
  }

  Future<Map<String, dynamic>> _loadRecord() async {
    final api = AppController.instance.backendApi;
    final profile = AppController.instance.currentProfile;
    if (!api.isAuthenticated || profile == null) {
      return <String, dynamic>{};
    }
    final records = await api.getAppRecords(
      profileId: profile.id,
      recordType: _recordType,
    );
    for (final record in records) {
      if (record['recordKey'] == _recordKey && record['data'] is Map) {
        return Map<String, dynamic>.from(record['data'] as Map);
      }
    }
    return <String, dynamic>{};
  }

  void _load() {
    _record = _loadRecord();
  }

  Set<String> _protectedFields(Map<String, dynamic> record) {
    final values = record['protectedFields'];
    if (values is! List) return <String>{};
    return values.map((value) => value.toString()).toSet();
  }

  Map<String, dynamic> _sources(Map<String, dynamic> record) {
    final value = record['sources'];
    if (value is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(value);
  }

  Future<void> _setProtected(
      Map<String, dynamic> current, String field, bool value) async {
    final api = AppController.instance.backendApi;
    final profile = AppController.instance.currentProfile;
    if (!api.isAuthenticated || profile == null) return;

    final protected = _protectedFields(current);
    if (value) {
      protected.add(field);
    } else {
      protected.remove(field);
    }
    final sources = _sources(current);
    final protectionUpdatedAt = Map<String, dynamic>.from(
      current['protectionUpdatedAt'] is Map
          ? current['protectionUpdatedAt'] as Map
          : const <String, dynamic>{},
    )..[field] = DateTime.now().toUtc().toIso8601String();
    setState(() => _saving = true);
    try {
      await api.saveAppRecord(
        profileId: profile.id,
        recordType: _recordType,
        recordKey: _recordKey,
        data: {
          'mediaId': widget.media.id,
          'protectedFields': protected.toList()..sort(),
          'sources': sources,
          'protectionUpdatedAt': protectionUpdatedAt,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (mounted) {
        setState(() {
          _record = _loadRecord();
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not update metadata protection: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _displayValue(dynamic value) {
    if (value == null) return 'Empty';
    if (value is List) {
      final values = value.map((entry) => entry.toString()).toList();
      return values.isEmpty ? 'Empty' : values.join(', ');
    }
    final text = value.toString().trim();
    if (text.isEmpty) return 'Empty';
    return text.length > 120 ? '${text.substring(0, 117)}...' : text;
  }

  List<({String field, String label, dynamic value})> get _fields {
    final media = widget.media;
    return <({String field, String label, dynamic value})>[
      (field: 'imageUrl', label: 'Poster artwork', value: media.imageUrl),
      (
        field: 'releaseDate',
        label: 'Release / series dates',
        value: media.releaseDate?.toIso8601String().substring(0, 10) ??
            media.seriesStartDate?.toIso8601String().substring(0, 10) ??
            media.seriesStartYear,
      ),
      (field: 'actors', label: 'Cast', value: media.actors),
      (field: 'characters', label: 'Characters', value: media.characters),
      (field: 'directors', label: 'Directors', value: media.directors),
      (field: 'writers', label: 'Writers', value: media.writers),
      (field: 'music', label: 'Music credits', value: media.music),
      (field: 'genres', label: 'Genres', value: media.genres),
      (field: 'tags', label: 'Keywords', value: media.tags),
    ];
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UniversalText(
                'Metadata sources & protection',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review the current source and protect curated fields from future automatic metadata updates. Unlocking a field allows future provider updates; it does not immediately replace its value.',
                style: TextStyle(color: Colors.white60),
              ),
              if (!AppController.instance.backendApi.isAuthenticated)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: UniversalText(
                    'Sign in to save field protection and provider provenance to your profile.',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              else
                FutureBuilder<Map<String, dynamic>>(
                  future: _record,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: LinearProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Could not load metadata provenance: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }
                    final record = snapshot.data ?? const <String, dynamic>{};
                    final protected = _protectedFields(record);
                    final sources = _sources(record);
                    return Column(
                      children: [
                        for (final field in _fields)
                          Builder(builder: (context) {
                            final isProtected = protected.contains(field.field);
                            final source = sources[field.field];
                            final sourceName = source is Map
                                ? source['source']?.toString()
                                : null;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(field.label),
                              subtitle: Text(
                                '${_displayValue(field.value)}\nSource: ${sourceName?.trim().isNotEmpty == true ? sourceName : 'Existing catalog (original source not recorded)'}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                tooltip: isProtected
                                    ? 'Allow automatic updates'
                                    : 'Protect this field',
                                onPressed: _saving ||
                                        !AppController
                                            .instance.backendApi.isAuthenticated
                                    ? null
                                    : () => _setProtected(
                                        record, field.field, !isProtected),
                                icon: Icon(
                                  isProtected
                                      ? Icons.lock_rounded
                                      : Icons.lock_open_rounded,
                                  color: isProtected
                                      ? Colors.amberAccent
                                      : Colors.white54,
                                ),
                              ),
                            );
                          }),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Editions and manual franchise connections are stored separately and are not changed by provider metadata refreshes.',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ),
                        if (_saving) const LinearProgressIndicator(),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      );
}

class _MediaFranchiseConnectionsPanelState
    extends State<MediaFranchiseConnectionsPanel> {
  static const String _manualRecordType = 'media_franchise_connections';
  late Future<List<Map<String, dynamic>>> _connections;

  String get _manualRecordKey =>
      'media_franchise_connections:${widget.mediaId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MediaFranchiseConnectionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) _load();
  }

  List<Map<String, dynamic>> _mapList(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
      : const <Map<String, dynamic>>[];

  Future<Map<String, dynamic>> _loadManualRecord() async {
    final api = AppController.instance.backendApi;
    if (!api.isAuthenticated) return <String, dynamic>{};
    final records = await api.getAppRecords(recordType: _manualRecordType);
    for (final record in records) {
      if (record['recordKey'] != _manualRecordKey || record['data'] is! Map) {
        continue;
      }
      return Map<String, dynamic>.from(record['data'] as Map);
    }
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> _loadManualConnections() async {
    final data = await _loadManualRecord();
    final connections = _mapList(data['connections']);
    return connections.map((entry) {
      final normalized = Map<String, dynamic>.from(entry);
      normalized['isManual'] = true;
      normalized['otherTitle'] ??= normalized['title'] ?? 'Related production';
      normalized['relationshipType'] ??= 'related to';
      return normalized;
    }).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadConnectionHistory() async {
    final data = await _loadManualRecord();
    return _mapList(data['history']).reversed.toList(growable: false);
  }

  Future<void> _restoreConnectionSnapshot(Map<String, dynamic> entry) async {
    final snapshot = _mapList(entry['connections']);
    final restored = snapshot
        .map((connection) => <String, dynamic>{
              ...connection,
              'isManual': true,
            })
        .toList(growable: false);
    await _saveManualConnections(
      restored,
      action: 'restored',
      reason:
          'Restored saved version from ${entry['changedAt'] ?? 'change history'}.',
    );
  }

  Future<void> _showConnectionHistory() async {
    late final List<Map<String, dynamic>> history;
    try {
      history = await _loadConnectionHistory();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load connection history: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connection change history',
                    style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                    'Each entry records the profile, time, reason, and complete saved connection list. Restore creates a new history entry.'),
                const SizedBox(height: 8),
                if (history.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No custom connection changes recorded yet.'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final entry = history[index];
                        final date = DateTime.tryParse(
                          entry['changedAt']?.toString() ?? '',
                        )?.toLocal();
                        final connections = _mapList(entry['connections']);
                        return Card(
                          child: ListTile(
                            title: Text(
                              '${entry['action'] ?? 'updated'} · ${connections.length} connection(s)',
                            ),
                            subtitle: Text([
                              if (date != null) date.toString(),
                              if ((entry['profileName']?.toString() ?? '')
                                  .trim()
                                  .isNotEmpty)
                                'By ${entry['profileName']}',
                              if ((entry['reason']?.toString() ?? '')
                                  .trim()
                                  .isNotEmpty)
                                entry['reason'].toString(),
                            ].join('\n')),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: 'Restore this saved version',
                              icon: const Icon(Icons.restore_rounded),
                              onPressed: _savingConnections
                                  ? null
                                  : () async {
                                      Navigator.pop(sheetContext);
                                      await _restoreConnectionSnapshot(entry);
                                    },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveManualConnections(
    List<Map<String, dynamic>> connections, {
    required String action,
    String reason = '',
  }) async {
    final api = AppController.instance.backendApi;
    final profile = AppController.instance.currentProfile;
    if (!api.isAuthenticated || profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sign in to save custom franchise connections.')),
        );
      }
      return;
    }

    setState(() => _savingConnections = true);
    try {
      final currentRecord = await _loadManualRecord();
      final previous = _mapList(currentRecord['connections']);
      final history = _mapList(currentRecord['history']);
      final changedAt = DateTime.now().toUtc().toIso8601String();
      history.add({
        'action': action,
        'changedAt': changedAt,
        'profileId': profile.id,
        'profileName': profile.name,
        'reason': reason.trim(),
        'previousConnections': previous,
        'connections': connections
            .map((connection) => Map<String, dynamic>.from(connection))
            .toList(growable: false),
      });
      if (history.length > 100) {
        history.removeRange(0, history.length - 100);
      }
      await api.saveAppRecord(
        recordType: _manualRecordType,
        recordKey: _manualRecordKey,
        data: {
          'mediaId': widget.mediaId,
          'connections': connections,
          'history': history,
        },
      );
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save connection change: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingConnections = false);
    }
  }

  bool _savingConnections = false;

  void _load() {
    final api = AppController.instance.backendApi;
    if (!api.isAuthenticated) {
      _connections = Future.value(const <Map<String, dynamic>>[]);
      return;
    }
    _connections = Future.wait([
      api.getMediaConnections(mediaId: widget.mediaId),
      api.getMediaWorks(),
      _loadManualConnections(),
    ]).then((results) {
      final works = {
        for (final work in results[1]) work['id']?.toString(): work
      };
      final backendConnections = results[0].where((edge) {
        final kind = (edge['relationshipType'] ?? '').toString().toLowerCase();
        return kind.contains('sequel') ||
            kind.contains('prequel') ||
            kind.contains('continu') ||
            kind.contains('revival') ||
            kind.contains('spin') ||
            kind.contains('reboot') ||
            kind.contains('remake') ||
            kind.contains('alternate') ||
            kind.contains('samecontinuity') ||
            kind.contains('same_continuity') ||
            kind.contains('anthology');
      }).map((edge) {
        final from = edge['fromId']?.toString();
        final otherId =
            from == widget.mediaId ? edge['toId']?.toString() : from;
        final related = works[otherId];
        return <String, dynamic>{
          ...edge,
          'otherTitle': related?['title'] ?? otherId ?? 'Related production',
          'otherYear': related?['releaseYear'],
          'isManual': false,
        };
      }).toList(growable: false);

      final manualConnections = results[2].map((connection) {
        final relatedId = connection['relatedId']?.toString() ??
            connection['mediaId']?.toString() ??
            connection['otherId']?.toString();
        final related = relatedId == null ? null : works[relatedId];
        return <String, dynamic>{
          ...connection,
          'otherTitle': connection['otherTitle']?.toString() ??
              related?['title']?.toString() ??
              'User-defined connection',
          'otherYear': related?['releaseYear'],
          'isManual': true,
        };
      }).toList(growable: false);

      final combined = <Map<String, dynamic>>[
        ...backendConnections,
        ...manualConnections
      ];
      combined.sort((a, b) {
        final aType = a['relationshipType']?.toString() ?? '';
        final bType = b['relationshipType']?.toString() ?? '';
        final typeCompare = aType.toLowerCase().compareTo(bType.toLowerCase());
        if (typeCompare != 0) return typeCompare;
        final aTitle = a['otherTitle']?.toString() ?? '';
        final bTitle = b['otherTitle']?.toString() ?? '';
        return aTitle.toLowerCase().compareTo(bTitle.toLowerCase());
      });
      return combined;
    });
  }

  Future<void> _addConnection() async {
    final titleController = TextEditingController();
    final idController = TextEditingController();
    final relationshipController = TextEditingController(text: 'Sequel to');
    final noteController = TextEditingController();
    final changeReasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Add a franchise connection'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Related title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'Catalog media ID (optional)',
                  hintText: 'optional if not in this catalog',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  hintText: 'Sequel to / Prequel to / Shared character',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Optional note',
                  hintText: 'Story context or continuity note',
                ),
              ),
              TextField(
                controller: changeReasonController,
                decoration: const InputDecoration(
                  labelText: 'Why are you adding this? (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const UniversalText('Save'),
          ),
        ],
      ),
    );

    final title = titleController.text.trim();
    final relationship = relationshipController.text.trim();
    final note = noteController.text.trim();
    final changeReason = changeReasonController.text.trim();
    final relatedId = idController.text.trim();
    titleController.dispose();
    idController.dispose();
    relationshipController.dispose();
    noteController.dispose();
    changeReasonController.dispose();

    if (confirmed != true || title.isEmpty || relationship.isEmpty) return;
    final connections = await _loadManualConnections();
    connections.add({
      'id': 'manual-${DateTime.now().microsecondsSinceEpoch}',
      'otherTitle': title,
      'title': title,
      'relatedId': relatedId,
      'mediaId': relatedId,
      'relationshipType': relationship,
      'note': note,
      'isManual': true,
    });
    await _saveManualConnections(
      connections,
      action: 'added',
      reason: changeReason,
    );
  }

  Future<void> _editConnection(Map<String, dynamic> connection) async {
    final titleController = TextEditingController(
      text: (connection['otherTitle'] ?? connection['title'] ?? '').toString(),
    );
    final idController = TextEditingController(
      text: (connection['relatedId'] ?? connection['mediaId'] ?? '').toString(),
    );
    final relationshipController = TextEditingController(
      text: (connection['relationshipType'] ?? 'related to').toString(),
    );
    final noteController = TextEditingController(
      text: (connection['note'] ?? connection['description'] ?? '').toString(),
    );
    final changeReasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Edit franchise connection'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Related title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                    labelText: 'Catalog media ID (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(labelText: 'Relationship'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Optional note'),
              ),
              TextField(
                controller: changeReasonController,
                decoration: const InputDecoration(
                  labelText: 'Why are you changing this? (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const UniversalText('Save'),
          ),
        ],
      ),
    );

    final title = titleController.text.trim();
    final relationship = relationshipController.text.trim();
    final note = noteController.text.trim();
    final changeReason = changeReasonController.text.trim();
    final relatedId = idController.text.trim();
    titleController.dispose();
    idController.dispose();
    relationshipController.dispose();
    noteController.dispose();
    changeReasonController.dispose();

    if (confirmed != true || title.isEmpty || relationship.isEmpty) return;
    final connections = await _loadManualConnections();
    for (final entry in connections) {
      final sameId = entry['id']?.toString() == connection['id']?.toString();
      final sameLegacy = sameId ||
          ((entry['otherTitle'] ?? entry['title'])?.toString() ?? '') ==
                  (connection['otherTitle'] ?? connection['title'])
                      ?.toString() &&
              (entry['relationshipType'] ?? '').toString() ==
                  (connection['relationshipType'] ?? '').toString();
      if (sameId || sameLegacy) {
        entry['otherTitle'] = title;
        entry['title'] = title;
        entry['relatedId'] = relatedId;
        entry['mediaId'] = relatedId;
        entry['relationshipType'] = relationship;
        entry['note'] = note;
        entry['description'] = note;
        break;
      }
    }
    await _saveManualConnections(
      connections,
      action: 'edited',
      reason: changeReason,
    );
  }

  Future<void> _deleteConnection(Map<String, dynamic> connection) async {
    final changeReasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Remove connection?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Remove "${connection['otherTitle'] ?? connection['title'] ?? 'this connection'}" from your custom franchise links?'),
            const SizedBox(height: 12),
            TextField(
              controller: changeReasonController,
              decoration: const InputDecoration(
                labelText: 'Why are you removing this? (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const UniversalText('Remove'),
          ),
        ],
      ),
    );
    final changeReason = changeReasonController.text.trim();
    changeReasonController.dispose();
    if (confirmed != true) return;
    final connections = await _loadManualConnections();
    connections.removeWhere((entry) {
      final matchId = entry['id']?.toString() == connection['id']?.toString();
      if (matchId) return true;
      final entryTitle =
          (entry['otherTitle'] ?? entry['title'] ?? '').toString();
      final targetTitle =
          (connection['otherTitle'] ?? connection['title'] ?? '').toString();
      final sameTitle = entryTitle == targetTitle &&
          (entry['relationshipType'] ?? '').toString() ==
              (connection['relationshipType'] ?? '').toString();
      return sameTitle;
    });
    await _saveManualConnections(
      connections,
      action: 'removed',
      reason: changeReason,
    );
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: UniversalText('Franchise connections',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                if (AppController.instance.backendApi.isAuthenticated)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed:
                            _savingConnections ? null : _showConnectionHistory,
                        tooltip: 'View and restore connection history',
                        icon: const Icon(Icons.history_rounded),
                      ),
                      IconButton(
                        onPressed: _savingConnections ? null : _addConnection,
                        tooltip: 'Add custom franchise connection',
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                widget.hasSeasons
                    ? 'Related productions keep their own season numbering and identity.'
                    : 'Related titles remain separate works and can belong to different continuity branches.',
                style: const TextStyle(color: Colors.white60)),
            if (!AppController.instance.backendApi.isAuthenticated)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: UniversalText('Sign in to view linked productions.',
                    style: TextStyle(color: Colors.white60)),
              )
            else
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _connections,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: LinearProgressIndicator());
                  }
                  final links = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (links.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: UniversalText(
                          'No franchise relationships are recorded for this title yet. Add your own manual links below.',
                          style: TextStyle(color: Colors.white60)),
                    );
                  }
                  return Column(children: [
                    for (final link in links)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.account_tree_outlined),
                        title: Text(link['otherTitle']?.toString() ??
                            'Related production'),
                        subtitle: Text(
                            '${link['relationshipType'] ?? 'related to'}${link['otherYear'] == null ? '' : ' · ${link['otherYear']}'}${link['note']?.toString().trim().isNotEmpty == true ? ' · ${link['note']}' : ''}${widget.hasSeasons ? ' · separate production' : ''}'),
                        trailing: link['isManual'] == true
                            ? PopupMenuButton<String>(
                                tooltip: 'Manage connection',
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _editConnection(link);
                                  } else if (value == 'delete') {
                                    await _deleteConnection(link);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('Remove')),
                                ],
                              )
                            : null,
                      ),
                  ]);
                },
              ),
          ]),
        ),
      );
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
        ? api.getAppRecords(recordType: _recordType).then((records) {
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
      await AppController.instance.backendApi.saveAppRecord(
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
    final runtime = TextEditingController();
    final releaseDate = TextEditingController();
    final resolution = TextEditingController();
    final audio = TextEditingController();
    final subtitles = TextEditingController();
    final serverItemId = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Add a version'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'Version name', hintText: 'Encore')),
            TextField(
                controller: cut,
                decoration:
                    const InputDecoration(labelText: 'Cut or edition notes')),
            TextField(
                controller: formats,
                decoration: const InputDecoration(
                    labelText: 'Physical formats',
                    hintText: 'DVD, Blu-ray, 4K UHD')),
            TextField(
                controller: runtime,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Runtime (minutes)')),
            TextField(
                controller: releaseDate,
                decoration: const InputDecoration(
                    labelText: 'Edition release date', hintText: 'YYYY-MM-DD')),
            TextField(
                controller: resolution,
                decoration: const InputDecoration(
                    labelText: 'Resolution / video format',
                    hintText: '4K UHD, 1080p, HDR10')),
            TextField(
                controller: audio,
                decoration: const InputDecoration(
                    labelText: 'Audio formats',
                    hintText: 'Dolby Atmos, DTS-HD MA')),
            TextField(
                controller: subtitles,
                decoration: const InputDecoration(
                    labelText: 'Subtitle languages / formats',
                    hintText: 'English SDH, Spanish')),
            TextField(
                controller: serverItemId,
                decoration: const InputDecoration(
                    labelText: 'Media-server item ID (optional)',
                    helperText:
                        'Use an authorized server ID, not a filesystem path.')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const UniversalText('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const UniversalText('Add version')),
        ],
      ),
    );
    final versionName = name.text.trim();
    final cutNotes = cut.text.trim();
    final physicalFormats = formats.text
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    final runtimeMinutes = int.tryParse(runtime.text.trim());
    final editionReleaseDate = releaseDate.text.trim();
    final videoFormat = resolution.text.trim();
    final audioFormats = audio.text
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    final subtitleFormats = subtitles.text
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    final mediaServerItemId = serverItemId.text.trim();
    name.dispose();
    cut.dispose();
    formats.dispose();
    runtime.dispose();
    releaseDate.dispose();
    resolution.dispose();
    audio.dispose();
    subtitles.dispose();
    serverItemId.dispose();
    if (confirmed != true || versionName.isEmpty) return;
    final versions = _maps(current['versions']);
    versions.add({
      'id': 'version_${DateTime.now().microsecondsSinceEpoch}',
      'name': versionName,
      'cut': cutNotes,
      'physicalFormats': physicalFormats,
      if (runtimeMinutes != null && runtimeMinutes > 0)
        'runtimeMinutes': runtimeMinutes,
      if (editionReleaseDate.isNotEmpty) 'releaseDate': editionReleaseDate,
      if (videoFormat.isNotEmpty) 'videoFormat': videoFormat,
      'audioFormats': audioFormats,
      'subtitleFormats': subtitleFormats,
      if (mediaServerItemId.isNotEmpty) 'mediaServerItemId': mediaServerItemId,
      'scenes': <Map<String, dynamic>>[],
    });
    await _save({...current, 'versions': versions});
  }

  Future<void> _editVersion(Map<String, dynamic> current,
      Map<String, dynamic> version, int versionIndex) async {
    final name = TextEditingController(text: version['name']?.toString() ?? '');
    final cut = TextEditingController(text: version['cut']?.toString() ?? '');
    final formats = TextEditingController(
        text: (version['physicalFormats'] as List?)
                ?.map((value) => value.toString())
                .join(', ') ??
            '');
    final runtime = TextEditingController(
        text: version['runtimeMinutes']?.toString() ?? '');
    final releaseDate =
        TextEditingController(text: version['releaseDate']?.toString() ?? '');
    final resolution =
        TextEditingController(text: version['videoFormat']?.toString() ?? '');
    final audio = TextEditingController(
        text: (version['audioFormats'] as List?)
                ?.map((value) => value.toString())
                .join(', ') ??
            '');
    final subtitles = TextEditingController(
        text: (version['subtitleFormats'] as List?)
                ?.map((value) => value.toString())
                .join(', ') ??
            '');
    final serverItemId = TextEditingController(
        text: version['mediaServerItemId']?.toString() ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Edit version details'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Version name')),
            TextField(
                controller: cut,
                decoration:
                    const InputDecoration(labelText: 'Cut or edition notes')),
            TextField(
                controller: formats,
                decoration: const InputDecoration(
                    labelText: 'Physical formats',
                    hintText: 'DVD, Blu-ray, 4K UHD')),
            TextField(
                controller: runtime,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Runtime (minutes)')),
            TextField(
                controller: releaseDate,
                decoration: const InputDecoration(
                    labelText: 'Edition release date', hintText: 'YYYY-MM-DD')),
            TextField(
                controller: resolution,
                decoration: const InputDecoration(
                    labelText: 'Resolution / video format')),
            TextField(
                controller: audio,
                decoration: const InputDecoration(labelText: 'Audio formats')),
            TextField(
                controller: subtitles,
                decoration: const InputDecoration(
                    labelText: 'Subtitle languages / formats')),
            TextField(
                controller: serverItemId,
                decoration: const InputDecoration(
                    labelText: 'Media-server item ID (optional)',
                    helperText:
                        'Use an authorized server ID, not a filesystem path.')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const UniversalText('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const UniversalText('Save')),
        ],
      ),
    );
    final updatedName = name.text.trim();
    final updatedCut = cut.text.trim();
    final physicalFormats = formats.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final runtimeMinutes = int.tryParse(runtime.text.trim());
    final updatedReleaseDate = releaseDate.text.trim();
    final updatedVideoFormat = resolution.text.trim();
    final audioFormats = audio.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final subtitleFormats = subtitles.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final updatedServerItemId = serverItemId.text.trim();
    name.dispose();
    cut.dispose();
    formats.dispose();
    runtime.dispose();
    releaseDate.dispose();
    resolution.dispose();
    audio.dispose();
    subtitles.dispose();
    serverItemId.dispose();
    if (confirmed != true || updatedName.isEmpty) return;

    final versions = _maps(current['versions']);
    if (versionIndex >= versions.length) return;
    versions[versionIndex] = {
      ...version,
      'name': updatedName,
      'cut': updatedCut,
      'physicalFormats': physicalFormats,
      'runtimeMinutes':
          runtimeMinutes != null && runtimeMinutes > 0 ? runtimeMinutes : null,
      'releaseDate': updatedReleaseDate.isEmpty ? null : updatedReleaseDate,
      'videoFormat': updatedVideoFormat.isEmpty ? null : updatedVideoFormat,
      'audioFormats': audioFormats,
      'subtitleFormats': subtitleFormats,
      'mediaServerItemId':
          updatedServerItemId.isEmpty ? null : updatedServerItemId,
    };
    await _save({...current, 'versions': versions});
  }

  Future<void> _removeVersion(Map<String, dynamic> current,
      Map<String, dynamic> version, int versionIndex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Remove version?'),
        content: Text(
            'Remove "${version['name'] ?? 'this version'}" and its version-specific scenes?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const UniversalText('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const UniversalText('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = version['id']?.toString();
    final updated = _maps(current['versions']);
    if (versionIndex >= updated.length ||
        (id != null && updated[versionIndex]['id']?.toString() != id)) {
      return;
    }
    updated.removeAt(versionIndex);
    await _save({...current, 'versions': updated});
  }

  Future<void> _addScene(Map<String, dynamic> current, int versionIndex) async {
    final sceneTitle = TextEditingController();
    final position = TextEditingController();
    final storyDate = TextEditingController();
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Add a version scene'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: sceneTitle,
                decoration: const InputDecoration(
                    labelText: 'Scene title', hintText: 'TVA incursion scene')),
            TextField(
                controller: position,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Story order', hintText: '1')),
            TextField(
                controller: storyDate,
                decoration: const InputDecoration(
                    labelText: 'Story-time note',
                    hintText: 'After Spider-Man: Brand New Day')),
            TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const UniversalText('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const UniversalText('Add scene')),
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
    sceneTitle.dispose();
    position.dispose();
    storyDate.dispose();
    note.dispose();
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
        title: const UniversalText('Link a story'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: target,
              decoration: const InputDecoration(labelText: 'Related title')),
          TextField(
              controller: targetId,
              decoration: const InputDecoration(
                  labelText: 'Canonical media ID (optional)')),
          TextField(
              controller: type,
              decoration: const InputDecoration(
                  labelText: 'Relationship',
                  hintText: 'leads_into / sequel_to')),
          TextField(
              controller: timing,
              decoration:
                  const InputDecoration(labelText: 'Story timing note')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const UniversalText('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const UniversalText('Add link')),
        ],
      ),
    );
    final title = target.text.trim();
    final id = targetId.text.trim();
    final relationshipType = type.text.trim();
    final storyTime = timing.text.trim();
    target.dispose();
    targetId.dispose();
    type.dispose();
    timing.dispose();
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

  Future<void> _editStoryChronology(Map<String, dynamic> current) async {
    final existing = current['storyChronology'] is Map
        ? Map<String, dynamic>.from(current['storyChronology'] as Map)
        : <String, dynamic>{};
    final year =
        TextEditingController(text: existing['year']?.toString() ?? '');
    final order =
        TextEditingController(text: existing['order']?.toString() ?? '');
    final placement =
        TextEditingController(text: existing['placement']?.toString() ?? '');
    final note =
        TextEditingController(text: existing['note']?.toString() ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UniversalText('Story timeline placement'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Story year (optional)',
                hintText: '2016',
              ),
            ),
            TextField(
              controller: order,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Order within the timeline (optional)',
                hintText: '1',
              ),
            ),
            TextField(
              controller: placement,
              decoration: const InputDecoration(
                labelText: 'Placement label',
                hintText: 'Approx. 2016 · after Civil War',
              ),
            ),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Chronology note (optional)',
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const UniversalText('Save placement'),
          ),
        ],
      ),
    );
    final storyYear = int.tryParse(year.text.trim());
    final storyOrder = int.tryParse(order.text.trim());
    final storyPlacement = placement.text.trim();
    final storyNote = note.text.trim();
    year.dispose();
    order.dispose();
    placement.dispose();
    note.dispose();
    if (confirmed != true) return;
    await _save({
      ...current,
      'storyChronology': <String, dynamic>{
        if (storyYear != null) 'year': storyYear,
        if (storyOrder != null) 'order': storyOrder,
        if (storyPlacement.isNotEmpty) 'placement': storyPlacement,
        if (storyNote.isNotEmpty) 'note': storyNote,
      },
    });
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
        future: _record,
        builder: (context, snapshot) {
          final record = snapshot.data ?? const <String, dynamic>{};
          final versions = _maps(record['versions']);
          final relationships = _maps(record['relationships']);
          final storyChronology = record['storyChronology'] is Map
              ? Map<String, dynamic>.from(record['storyChronology'] as Map)
              : <String, dynamic>{};
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: UniversalText('Versions & story connections',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800))),
                      IconButton(
                        onPressed: _saving ||
                                !AppController
                                    .instance.backendApi.isAuthenticated
                            ? null
                            : () => _addVersion(record),
                        tooltip: 'Add version',
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ]),
                    if (!AppController.instance.backendApi.isAuthenticated)
                      const UniversalText(
                          'Sign in to save versions and story connections.',
                          style: TextStyle(color: Colors.white60))
                    else if (snapshot.connectionState ==
                        ConnectionState.waiting)
                      const LinearProgressIndicator()
                    else if (versions.isEmpty &&
                        relationships.isEmpty &&
                        storyChronology.isEmpty)
                      const UniversalText(
                          'Add alternate cuts, version-specific scenes, story links, or a manual story-timeline placement.',
                          style: TextStyle(color: Colors.white60))
                    else ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.timeline_rounded),
                        title: const Text('Story timeline placement'),
                        subtitle: Text([
                          if (storyChronology['year'] != null)
                            storyChronology['year'].toString(),
                          if ((storyChronology['placement']?.toString() ?? '')
                              .trim()
                              .isNotEmpty)
                            storyChronology['placement'].toString(),
                          if (storyChronology['order'] != null)
                            'Order ${storyChronology['order']}',
                          if ((storyChronology['note']?.toString() ?? '')
                              .trim()
                              .isNotEmpty)
                            storyChronology['note'].toString(),
                          if (storyChronology.isEmpty)
                            'No manual story placement set',
                        ].join(' · ')),
                        trailing: IconButton(
                          tooltip: 'Edit story timeline placement',
                          onPressed: _saving
                              ? null
                              : () => _editStoryChronology(record),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                      for (var index = 0; index < versions.length; index++)
                        _versionTile(record, versions[index], index),
                      for (final relationship in relationships)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.account_tree_outlined),
                          title: Text(
                              '${relationship['type']} → ${relationship['title']}'),
                          subtitle: [
                            if (relationship['storyTime']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ??
                                false)
                              relationship['storyTime'].toString(),
                            if (relationship['mediaId']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ??
                                false)
                              'ID: ${relationship['mediaId']}',
                          ].isEmpty
                              ? null
                              : Text([
                                  if (relationship['storyTime']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ??
                                      false)
                                    relationship['storyTime'].toString(),
                                  if (relationship['mediaId']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ??
                                      false)
                                    'ID: ${relationship['mediaId']}',
                                ].join(' · ')),
                        ),
                    ],
                    if (AppController.instance.backendApi.isAuthenticated)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _editStoryChronology(record),
                            icon: const Icon(Icons.timeline_rounded),
                            label: const UniversalText('Set story order'),
                          ),
                          TextButton.icon(
                            onPressed:
                                _saving ? null : () => _addRelationship(record),
                            icon: const Icon(Icons.add_link),
                            label: const UniversalText('Link another story'),
                          ),
                        ],
                      ),
                    if (_saving) const LinearProgressIndicator(),
                  ]),
            ),
          );
        },
      );

  Widget _versionTile(
      Map<String, dynamic> record, Map<String, dynamic> version, int index) {
    final scenes = _maps(version['scenes'])
      ..sort((a, b) => ((a['storyOrder'] as num?)?.toInt() ?? 999)
          .compareTo((b['storyOrder'] as num?)?.toInt() ?? 999));
    final formats = (version['physicalFormats'] as List?)
            ?.map((item) => item.toString())
            .join(', ') ??
        '';
    final audioFormats = (version['audioFormats'] as List?)
            ?.map((item) => item.toString())
            .join(', ') ??
        '';
    final subtitleFormats = (version['subtitleFormats'] as List?)
            ?.map((item) => item.toString())
            .join(', ') ??
        '';
    final metadata = <String>[
      if ((version['cut']?.toString().trim() ?? '').isNotEmpty)
        version['cut'].toString(),
      if (formats.isNotEmpty) formats,
      if (version['runtimeMinutes'] != null) '${version['runtimeMinutes']} min',
      if ((version['releaseDate']?.toString().trim() ?? '').isNotEmpty)
        'Released ${version['releaseDate']}',
      if ((version['videoFormat']?.toString().trim() ?? '').isNotEmpty)
        version['videoFormat'].toString(),
      if (audioFormats.isNotEmpty) 'Audio: $audioFormats',
      if (subtitleFormats.isNotEmpty) 'Subtitles: $subtitleFormats',
    ];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(version['name']?.toString() ?? 'Version'),
      subtitle: Text(metadata.join(' · ')),
      children: [
        for (final scene in scenes)
          ListTile(
            dense: true,
            leading: const Icon(Icons.movie_filter_outlined),
            title: Text(scene['title']?.toString() ?? 'Scene'),
            subtitle: Text([
              if (scene['storyTime']?.toString().trim().isNotEmpty ?? false)
                scene['storyTime'].toString(),
              if (scene['description']?.toString().trim().isNotEmpty ?? false)
                scene['description'].toString(),
            ].join(' · ')),
            trailing: scene['storyOrder'] == null
                ? null
                : Text('#${scene['storyOrder']}'),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton.icon(
                onPressed:
                    _saving ? null : () => _editVersion(record, version, index),
                icon: const Icon(Icons.edit_outlined),
                label: const UniversalText('Edit edition'),
              ),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => _removeVersion(record, version, index),
                icon: const Icon(Icons.delete_outline),
                label: const UniversalText('Remove'),
              ),
              TextButton.icon(
                onPressed: _saving ? null : () => _addScene(record, index),
                icon: const Icon(Icons.add),
                label: const UniversalText('Add scene'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
