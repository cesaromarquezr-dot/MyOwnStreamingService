// FILE: lib/entertainment_studio.dart
// Personal entertainment tools that complement the existing TV, library,
// media-knowledge, customization, and storage modules. User-created notes are
// stored per profile on this device; server syncing is opt-in and handled only
// by dedicated authenticated repositories where available.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'expanded_platform.dart';
import 'localization.dart';
import 'media_knowledge.dart';
import 'music.dart';
import 'supabase/supabase_config.dart';

class EntertainmentStudioScreen extends StatelessWidget {
  const EntertainmentStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final media = controller.library;
    final missingArt = media.where((item) => item.imageUrl?.trim().isNotEmpty != true).length;
    final possibleDuplicates = StudioLibraryAudit.findings(media)
        .where((finding) => finding.kind == 'possible duplicate').length;
    final actions = <_StudioAction>[
      _StudioAction('Entertainment Calendar', 'Releases, watch parties, events and marathon plans', Icons.calendar_month_rounded, const StudioRecordsScreen(kind: StudioRecordKind.calendar)),
      _StudioAction('Entertainment Journal', 'Private watch/listen memories and yearly recap notes', Icons.auto_stories_rounded, const StudioRecordsScreen(kind: StudioRecordKind.journal)),
      _StudioAction('Scene Memory', 'Bookmark a moment with a timestamp and personal note', Icons.bookmark_add_rounded, const StudioRecordsScreen(kind: StudioRecordKind.scenes)),
      _StudioAction('Edition Manager', 'Keep theatrical, extended, remastered and regional editions distinct', Icons.collections_bookmark_rounded, const StudioRecordsScreen(kind: StudioRecordKind.editions)),
      _StudioAction('Household Watchlist', 'Propose titles and vote on what to watch together', Icons.how_to_vote_rounded, const StudioRecordsScreen(kind: StudioRecordKind.watchlist)),
      _StudioAction('Subtitle Workshop', 'Draft corrections and translation suggestions for review', Icons.closed_caption_rounded, const StudioRecordsScreen(kind: StudioRecordKind.subtitles)),
      _StudioAction('Fan Theory Board', 'Save episode-specific theories and discussion prompts', Icons.forum_rounded, const StudioRecordsScreen(kind: StudioRecordKind.theories)),
      _StudioAction('Shareable Layout Presets', 'Save, export and import safe appearance presets', Icons.dashboard_customize_rounded, const StudioRecordsScreen(kind: StudioRecordKind.presets)),
      _StudioAction('Cinema Room Mode', 'Save presets for cinema, late night, family and headphones', Icons.theaters_rounded, const CinemaRoomSettingsScreen()),
      _StudioAction('Smart Media Librarian', 'Audit metadata and flag possible duplicates without deleting files', Icons.health_and_safety_rounded, const SmartMediaLibrarianScreen()),
      _StudioAction('Movie Knowledge Graph', 'Explore connections between titles, people, studios and music', Icons.hub_rounded, const MediaConnectionGraphScreen()),
      _StudioAction('Recommendation Transparency', 'See catalog clues and provide feedback on suggestions', Icons.visibility_rounded, const RecommendationTransparencyScreen()),
      _StudioAction('Media Knowledge', 'Open sourced facts and behind-the-scenes stories for a title', Icons.auto_awesome_rounded, const _KnowledgePickerScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: const UniversalText('Entertainment Studio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary.withValues(alpha: .28), Theme.of(context).colorScheme.surface]),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.auto_awesome_rounded, size: 36),
              SizedBox(height: 10),
              UniversalText('Make your media library your own', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              UniversalText('Plan, remember, organize, annotate and discover. Existing My TV channels, Media Universe, and the storage server remain the authoritative places for playback, library management and server operations.'),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _StudioMetric(label: 'Library items', value: '${media.length}', icon: Icons.video_library_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _StudioMetric(label: 'Missing artwork', value: '$missingArt', icon: Icons.image_not_supported_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _StudioMetric(label: 'Possible duplicates', value: '$possibleDuplicates', icon: Icons.content_copy_rounded)),
          ]),
          const SizedBox(height: 18),
          const UniversalText('Explore tools', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final action in actions)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(action.icon)),
                title: Text(action.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(action.description),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                  settings: RouteSettings(name: '/app/page/entertainment-studio/${action.title.toLowerCase().replaceAll(' ', '-')}'),
                  builder: (_) => action.page,
                )),
              ),
            ),
          const SizedBox(height: 12),
          const Card(child: Padding(padding: EdgeInsets.all(14), child: UniversalText('Privacy note: journals, local watchlist votes, scene notes, subtitle drafts and imported presets are profile-scoped on this device. Cross-device collaboration, notification delivery, and publishing approved subtitle changes require authenticated server workflows; these local tools do not claim remote sync automatically.'))),
        ],
      ),
    );
  }
}

class _StudioAction {
  final String title;
  final String description;
  final IconData icon;
  final Widget page;
  const _StudioAction(this.title, this.description, this.icon, this.page);
}

class _StudioMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StudioMetric({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 19), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60))])));
}

enum StudioRecordKind { calendar, journal, scenes, editions, watchlist, subtitles, theories, presets }

extension on StudioRecordKind {
  String get title => switch (this) {
    StudioRecordKind.calendar => 'Entertainment Calendar',
    StudioRecordKind.journal => 'Entertainment Journal',
    StudioRecordKind.scenes => 'Scene Memory',
    StudioRecordKind.editions => 'Edition Manager',
    StudioRecordKind.watchlist => 'Household Watchlist',
    StudioRecordKind.subtitles => 'Subtitle Workshop',
    StudioRecordKind.theories => 'Fan Theory Board',
    StudioRecordKind.presets => 'Shareable Layout Presets',
  };
  IconData get icon => switch (this) {
    StudioRecordKind.calendar => Icons.calendar_month_rounded,
    StudioRecordKind.journal => Icons.auto_stories_rounded,
    StudioRecordKind.scenes => Icons.bookmark_add_rounded,
    StudioRecordKind.editions => Icons.collections_bookmark_rounded,
    StudioRecordKind.watchlist => Icons.how_to_vote_rounded,
    StudioRecordKind.subtitles => Icons.closed_caption_rounded,
    StudioRecordKind.theories => Icons.forum_rounded,
    StudioRecordKind.presets => Icons.dashboard_customize_rounded,
  };
  String get titleHint => switch (this) {
    StudioRecordKind.calendar => 'Event or release name',
    StudioRecordKind.journal => 'Movie, show, album or song',
    StudioRecordKind.scenes => 'Media title',
    StudioRecordKind.editions => 'Media title',
    StudioRecordKind.watchlist => 'What should we watch?',
    StudioRecordKind.subtitles => 'Media title',
    StudioRecordKind.theories => 'Episode or discussion title',
    StudioRecordKind.presets => 'Preset name',
  };
  String get detailHint => switch (this) {
    StudioRecordKind.calendar => 'Notes, venue or party details',
    StudioRecordKind.journal => 'Your private note or review',
    StudioRecordKind.scenes => 'Timestamp (HH:MM:SS) and note',
    StudioRecordKind.editions => 'Edition, format, region and differences',
    StudioRecordKind.watchlist => 'Why it belongs on the list',
    StudioRecordKind.subtitles => 'Language and proposed correction',
    StudioRecordKind.theories => 'Theory or question (mark spoilers clearly)',
    StudioRecordKind.presets => 'Safe visual settings as a short description or JSON',
  };
  String get addLabel => switch (this) {
    StudioRecordKind.calendar => 'Add event',
    StudioRecordKind.journal => 'Add journal entry',
    StudioRecordKind.scenes => 'Save scene',
    StudioRecordKind.editions => 'Add edition',
    StudioRecordKind.watchlist => 'Suggest a title',
    StudioRecordKind.subtitles => 'Draft correction',
    StudioRecordKind.theories => 'Add theory',
    StudioRecordKind.presets => 'Save preset',
  };
}

String studioTimestampKey(String? profileId, StudioRecordKind kind) {
  if (kind == StudioRecordKind.watchlist) {
    final accountId = AppController.instance.currentAccount?.id;
    return 'mos_studio_household_watchlist_${accountId?.trim().isNotEmpty == true ? accountId!.trim() : (profileId?.trim().isNotEmpty == true ? profileId!.trim() : 'local')}';
  }
  return 'mos_studio_${profileId?.trim().isNotEmpty == true ? profileId!.trim() : 'local'}_${kind.name}';
}

class StudioRecordsScreen extends StatefulWidget {
  final StudioRecordKind kind;
  const StudioRecordsScreen({super.key, required this.kind});
  @override
  State<StudioRecordsScreen> createState() => _StudioRecordsScreenState();
}

class _StudioRecordsScreenState extends State<StudioRecordsScreen> {
  List<Map<String, dynamic>> records = [];
  bool loading = true;
  String? error;
  String get _key => studioTimestampKey(AppController.instance.currentProfile?.id, widget.kind);
  String get _profileToken => AppController.instance.currentProfile?.id ?? 'local';
  bool _cloudReady = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    List<Map<String, dynamic>> loaded = [];
    if (raw != null) {
      try { loaded = (jsonDecode(raw) as List).whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList(); }
      catch (_) { error = 'Saved entries could not be read. A new save will replace the invalid local data.'; }
    }
    final client = SupabaseConfig.client;
    if (client != null && client.auth.currentUser != null) {
      try {
        final baseQuery = client.from('user_entertainment_studio_records')
            .select('id,record_type,record_data,updated_at')
            .eq('record_type', widget.kind.name);
        final remoteRows = widget.kind == StudioRecordKind.watchlist
            ? await baseQuery.order('updated_at', ascending: false)
            : await baseQuery.contains('record_data', {'profileId': _profileToken}).order('updated_at', ascending: false);
        final merged = <String, Map<String, dynamic>>{};
        for (final local in loaded) {
          final id = local['id']?.toString();
          if (id != null && id.isNotEmpty) merged[id] = local;
        }
        for (final row in remoteRows) {
          if (row['record_data'] is! Map) continue;
          final remote = Map<String, dynamic>.from(row['record_data'] as Map);
          remote['_cloudId'] = row['id']?.toString();
          final id = remote['id']?.toString() ?? remote['_cloudId']?.toString();
          if (id != null) merged[id] = remote;
        }
        loaded = merged.values.toList();
        _cloudReady = true;
      } catch (_) {
        // Keep local records usable if the optional cloud table is not deployed yet.
        error = 'Using this device’s saved entries. Cloud sync needs the Entertainment Studio migration and authenticated access.';
      }
    }
    if (widget.kind == StudioRecordKind.calendar) {
      loaded.sort((a, b) => (DateTime.tryParse(a['eventAt']?.toString() ?? '') ?? DateTime(9999)).compareTo(DateTime.tryParse(b['eventAt']?.toString() ?? '') ?? DateTime(9999)));
    }
    if (!mounted) return;
    setState(() { records = loaded; loading = false; });
    if (_cloudReady) await _persistLocalOnlyRecords();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(records));
    if (_cloudReady) await _syncCloud();
  }

  Future<void> _persistLocalOnlyRecords() async {
    for (final record in records.where((item) => item['_cloudId'] == null)) {
      await _upsertCloud(record);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(records));
  }

  Future<void> _syncCloud() async {
    for (final record in records) {
      await _upsertCloud(record);
    }
  }

  Future<void> _upsertCloud(Map<String, dynamic> record) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return;
    final cloudId = record['_cloudId']?.toString();
    final safeData = Map<String, dynamic>.from(record)..remove('_cloudId');
    try {
      if (cloudId != null && cloudId.isNotEmpty) {
        await client.from('user_entertainment_studio_records').update({
          'record_data': safeData,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', cloudId).eq('record_type', widget.kind.name);
      } else {
        final inserted = await client.from('user_entertainment_studio_records').insert({
          'record_type': widget.kind.name,
          'record_data': safeData,
        }).select('id').single();
        record['_cloudId'] = inserted['id']?.toString();
      }
    } catch (_) {
      // The device copy remains authoritative until a later sync succeeds.
    }
  }

  Future<void> _add() async {
    final title = TextEditingController();
    final detail = TextEditingController();
    final category = TextEditingController();
    var rating = 0;
    var eventDate = DateTime.now().add(const Duration(days: 1));
    var spoiler = false;
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(widget.kind.addLabel),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, maxLength: 180, decoration: InputDecoration(labelText: widget.kind.titleHint)),
        const SizedBox(height: 8),
        TextField(controller: detail, maxLines: 3, maxLength: 2000, decoration: InputDecoration(labelText: widget.kind.detailHint)),
        if (widget.kind == StudioRecordKind.calendar) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () async {
            final date = await showDatePicker(context: context, initialDate: eventDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)));
            if (date != null) setDialogState(() => eventDate = DateTime(date.year, date.month, date.day, eventDate.hour, eventDate.minute));
          }, icon: const Icon(Icons.calendar_today_rounded), label: Text('${eventDate.year}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}')),
          OutlinedButton.icon(onPressed: () async {
            final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(eventDate));
            if (time != null) setDialogState(() => eventDate = DateTime(eventDate.year, eventDate.month, eventDate.day, time.hour, time.minute));
          }, icon: const Icon(Icons.schedule_rounded), label: Text(TimeOfDay.fromDateTime(eventDate).format(context))),
          TextField(controller: category, decoration: const InputDecoration(labelText: 'Type (release, watch party, event, marathon)')),
        ],
        if (widget.kind == StudioRecordKind.journal) ...[
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: Text('Your rating (optional)', style: TextStyle(fontWeight: FontWeight.w700))),
          Slider(value: rating.toDouble(), min: 0, max: 5, divisions: 5, label: rating == 0 ? 'Not rated' : '$rating / 5', onChanged: (v) => setDialogState(() => rating = v.round())),
        ],
        if (widget.kind == StudioRecordKind.theories) CheckboxListTile(contentPadding: EdgeInsets.zero, value: spoiler, title: const Text('Contains spoilers'), onChanged: (v) => setDialogState(() => spoiler = v ?? false)),
        if (widget.kind == StudioRecordKind.presets) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Do not include credentials, private URLs, personal history or account identifiers in a preset.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const UniversalText('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const UniversalText('Save'))],
    )));
    if (ok == true && title.text.trim().isNotEmpty) {
      final item = <String, dynamic>{
        'id': 'studio_${DateTime.now().microsecondsSinceEpoch}',
        'title': title.text.trim(), 'detail': detail.text.trim(),
        'category': category.text.trim(), 'createdAt': DateTime.now().toUtc().toIso8601String(),
        'profileId': _profileToken,
        if (widget.kind == StudioRecordKind.calendar) 'eventAt': eventDate.toUtc().toIso8601String(),
        if (widget.kind == StudioRecordKind.journal && rating > 0) 'rating': rating,
        if (widget.kind == StudioRecordKind.theories) 'spoiler': spoiler,
        if (widget.kind == StudioRecordKind.watchlist) 'votes': <String>[_profileToken],
      };
      setState(() {
        records.insert(0, item);
        if (widget.kind == StudioRecordKind.calendar) {
          records.sort((a, b) => (DateTime.tryParse(a['eventAt']?.toString() ?? '') ?? DateTime(9999)).compareTo(DateTime.tryParse(b['eventAt']?.toString() ?? '') ?? DateTime(9999)));
        }
      });
      await _save();
      if (widget.kind == StudioRecordKind.scenes || widget.kind == StudioRecordKind.editions) {
        await _trySyncStructuredRecord(item);
      }
    }
    title.dispose(); detail.dispose(); category.dispose();
  }

  Future<void> _trySyncStructuredRecord(Map<String, dynamic> item) async {
    if (!ExpandedPlatformRepository.instance.isAvailable) return;
    try {
      if (widget.kind == StudioRecordKind.scenes) {
        final parsed = StudioSceneTimestamp.parse(item['detail']?.toString() ?? '');
        if (parsed != null) {
          await ExpandedPlatformRepository.instance.addSceneBookmark(
            mediaKey: _canonicalMediaKey(item['title'].toString()), positionMs: parsed,
            label: item['title'].toString(), note: item['detail'].toString(),
          );
        }
      } else if (widget.kind == StudioRecordKind.editions) {
        await ExpandedPlatformRepository.instance.saveCollectorEdition(
          mediaKey: _canonicalMediaKey(item['title'].toString()),
          editionTitle: item['detail']?.toString().trim().isNotEmpty == true ? item['detail'].toString().split(RegExp(r'[,;]')).first.trim() : 'Unspecified edition',
          editionDetails: <String, dynamic>{'note': item['detail']?.toString() ?? ''},
        );
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved locally. Server sync was unavailable; try again after checking your connection and permissions.')));
    }
  }

  String _canonicalMediaKey(String title) {
    final normalized = title.trim().toLowerCase();
    for (final media in AppController.instance.library) {
      if (media.title.trim().toLowerCase() == normalized) return media.id;
    }
    return title.trim();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final cloudId = item['_cloudId']?.toString();
    setState(() => records.removeWhere((record) => record['id'] == item['id']));
    final client = SupabaseConfig.client;
    if (cloudId != null && client != null && client.auth.currentUser != null) {
      try { await client.from('user_entertainment_studio_records').delete().eq('id', cloudId).eq('record_type', widget.kind.name); } catch (_) {}
    }
    await _save();
  }

  Future<void> _vote(Map<String, dynamic> item) async {
    final ids = (item['votes'] is List ? (item['votes'] as List).map((v) => v.toString()) : const <String>[]).toSet();
    if (!ids.add(_profileToken)) ids.remove(_profileToken);
    item['votes'] = ids.toList();
    setState(() {});
    await _save();
  }

  Future<void> _importPreset() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Import safe preset JSON'),
      content: SizedBox(width: 560, child: TextField(controller: controller, minLines: 4, maxLines: 10, decoration: const InputDecoration(hintText: '{"version":1,"type":"presets","title":"Cinema layout","detail":"..."}', border: OutlineInputBorder()))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Validate & import'))],
    ));
    if (ok == true) {
      try {
        final decoded = jsonDecode(controller.text);
        if (decoded is! Map || decoded['version'] != 1 || decoded['title'] is! String || decoded['detail'] is! String) throw const FormatException('Unsupported preset structure.');
        final title = (decoded['title'] as String).trim();
        if (title.isEmpty || title.length > 180) throw const FormatException('Preset title is empty or too long.');
        final record = <String, dynamic>{'id': 'studio_${DateTime.now().microsecondsSinceEpoch}', 'title': title, 'detail': (decoded['detail'] as String).substring(0, (decoded['detail'] as String).length.clamp(0, 2000).toInt()), 'category': 'imported layout preset', 'createdAt': DateTime.now().toUtc().toIso8601String(), 'profileId': _profileToken};
        setState(() => records.insert(0, record));
        await _save();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preset imported. Review the description before applying it to a page.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preset not imported: $e')));
      }
    }
    controller.dispose();
  }

  Future<void> _export(Map<String, dynamic> item) async {
    final safe = <String, dynamic>{'version': 1, 'type': widget.kind.name, 'title': item['title'], 'detail': item['detail'], 'category': item['category']};
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(safe)));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Safe preset JSON copied. It contains no account credentials or private history.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.kind.title), actions: [if (widget.kind == StudioRecordKind.presets) IconButton(tooltip: 'Import preset JSON', icon: const Icon(Icons.input_rounded), onPressed: _importPreset), if (widget.kind == StudioRecordKind.presets) IconButton(tooltip: 'Copy a preset template', icon: const Icon(Icons.copy_all_rounded), onPressed: () => _export(const {'title': 'My Layout', 'detail': '{"theme":"dark","density":"comfortable"}', 'category': 'layout'})), IconButton(tooltip: widget.kind.addLabel, onPressed: _add, icon: const Icon(Icons.add_rounded))]),
    body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
      Text(_description(widget.kind), style: const TextStyle(color: Colors.white60)),
      if (widget.kind == StudioRecordKind.watchlist) const Padding(padding: EdgeInsets.only(top: 8), child: Text('The household list can sync across devices under the same authenticated account after the Entertainment Studio migration is applied. Sharing with separate accounts needs an explicit membership/invitation workflow.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
      if (widget.kind == StudioRecordKind.subtitles) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Drafts do not overwrite original subtitles or publish translations automatically.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
      if (records.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 44), child: Center(child: Column(children: [Icon(Icons.inbox_outlined, size: 42), SizedBox(height: 10), Text('Nothing saved yet. Add your first entry.')]))),
      for (final item in records) Card(child: ListTile(
        leading: Icon(widget.kind.icon),
        title: Text(item['title']?.toString() ?? 'Entry', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (item['eventAt'] != null) Text('Scheduled: ${DateTime.tryParse(item['eventAt'].toString())?.toLocal().toString().replaceFirst(':00.000', '') ?? item['eventAt']}'),
          if ((item['category'] ?? '').toString().isNotEmpty) Text(item['category'].toString(), style: const TextStyle(color: Colors.white60)),
          if ((item['detail'] ?? '').toString().isNotEmpty) Text(item['detail'].toString(), maxLines: 4, overflow: TextOverflow.ellipsis),
          if (item['rating'] != null) Text('Your rating: ${item['rating']}/5'),
          if (item['spoiler'] == true) const Text('Spoiler warning', style: TextStyle(color: Colors.orangeAccent)),
          if (item['votes'] is List && widget.kind == StudioRecordKind.watchlist) Text('${(item['votes'] as List).length} local vote(s)'),
        ])),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'delete') _delete(item); if (value == 'export') _export(item); if (value == 'vote') _vote(item); }, itemBuilder: (_) => [if (widget.kind == StudioRecordKind.watchlist) const PopupMenuItem(value: 'vote', child: Text('Vote / remove vote')), if (widget.kind == StudioRecordKind.presets) const PopupMenuItem(value: 'export', child: Text('Export safe JSON')), const PopupMenuItem(value: 'delete', child: Text('Delete'))]),
      )),
    ]),
  );

  String _description(StudioRecordKind kind) => switch (kind) {
    StudioRecordKind.calendar => 'A personal calendar for releases, screenings, watch parties and planned marathons. Events are stored locally; this page does not schedule operating-system notifications.',
    StudioRecordKind.journal => 'A private entertainment diary. Add a memory or rating for a movie, season, album, song or event.',
    StudioRecordKind.scenes => 'Save timestamps in HH:MM:SS format with a note. When signed in, scene bookmarks are also submitted to the secured Supabase repository.',
    StudioRecordKind.editions => 'Record distinct cuts and physical/digital editions. An edition note never replaces or modifies the underlying media file.',
    StudioRecordKind.watchlist => 'Collect suggestions for the next group viewing. Keep your household preferences separate from each profile’s private history.',
    StudioRecordKind.subtitles => 'Keep translation and timing corrections as drafts for human review.',
    StudioRecordKind.theories => 'Store theories and discussion prompts; mark spoilers so you can review them before sharing.',
    StudioRecordKind.presets => 'Export safe appearance preferences as JSON. Import/share only presentation settings, never account data or signed media URLs.',
  };
}

class StudioSceneTimestamp {
  static int? parse(String input) {
    final match = RegExp(r'(\d{1,2}):(\d{2}):(\d{2})').firstMatch(input);
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '');
    final minutes = int.tryParse(match.group(2) ?? '');
    final seconds = int.tryParse(match.group(3) ?? '');
    if (hours == null || minutes == null || seconds == null || minutes > 59 || seconds > 59) return null;
    return ((hours * 3600) + (minutes * 60) + seconds) * 1000;
  }
}

class StudioLibraryFinding {
  final String kind;
  final String title;
  final String detail;
  const StudioLibraryFinding(this.kind, this.title, this.detail);
}

class StudioLibraryAudit {
  static List<StudioLibraryFinding> findings(List<MediaItem> library) {
    final results = <StudioLibraryFinding>[];
    final titleGroups = <String, List<MediaItem>>{};
    for (final item in library) {
      final normalized = item.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
      final key = '${item.type.toLowerCase()}::$normalized';
      if (normalized.isNotEmpty) titleGroups.putIfAbsent(key, () => <MediaItem>[]).add(item);
      if (item.imageUrl?.trim().isNotEmpty != true) results.add(StudioLibraryFinding('missing artwork', item.title, 'No artwork URL is recorded.'));
      if (item.description?.trim().isNotEmpty != true) results.add(StudioLibraryFinding('missing description', item.title, 'Description metadata is missing.'));
      if (item.releaseYear == null) results.add(StudioLibraryFinding('missing year', item.title, 'Release year is unknown.'));
    }
    for (final group in titleGroups.values.where((items) => items.length > 1)) {
      results.add(StudioLibraryFinding('possible duplicate', group.first.title, '${group.length} same-type entries share a normalized title. Compare editions and sources before merging; nothing is deleted automatically.'));
    }
    return results;
  }
}

class SmartMediaLibrarianScreen extends StatelessWidget {
  const SmartMediaLibrarianScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final findings = StudioLibraryAudit.findings(AppController.instance.library);
    final counts = <String, int>{};
    for (final finding in findings) {
      counts.update(finding.kind, (v) => v + 1, ifAbsent: () => 1);
    }
    return Scaffold(appBar: AppBar(title: const UniversalText('Smart Media Librarian'), actions: [IconButton(tooltip: 'Refresh audit', onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SmartMediaLibrarianScreen())), icon: const Icon(Icons.refresh_rounded))]), body: ListView(padding: const EdgeInsets.all(16), children: [
      const Card(child: Padding(padding: EdgeInsets.all(16), child: UniversalText('The audit checks imported metadata visible to this profile. It does not scan raw NAS paths, run SMART tests, or modify files.')),),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final entry in counts.entries) Chip(avatar: const Icon(Icons.warning_amber_rounded, size: 17), label: Text('${entry.key}: ${entry.value}'))]),
      if (findings.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No metadata issues detected in the current catalog.'))),
      for (final item in findings) Card(child: ListTile(leading: Icon(item.kind == 'possible duplicate' ? Icons.content_copy_rounded : Icons.info_outline_rounded), title: Text(item.title), subtitle: Text('${item.kind}: ${item.detail}'))),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: () async { final text = const JsonEncoder.withIndent('  ').convert(findings.map((f) => {'kind': f.kind, 'title': f.title, 'detail': f.detail}).toList()); await Clipboard.setData(ClipboardData(text: text)); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Library audit report copied to clipboard.'))); }, icon: const Icon(Icons.copy_rounded), label: const UniversalText('Export audit report')),
    ]));
  }
}

class MediaConnectionGraphScreen extends StatefulWidget {
  const MediaConnectionGraphScreen({super.key});
  @override
  State<MediaConnectionGraphScreen> createState() => _MediaConnectionGraphScreenState();
}

class _MediaConnectionGraphScreenState extends State<MediaConnectionGraphScreen> {
  String query = '';
  String relation = 'All connections';
  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final nodes = <String, Set<String>>{};
    void connect(String left, String right) {
      if (left.trim().isEmpty || right.trim().isEmpty || left == right) return;
      nodes.putIfAbsent(left, () => <String>{}).add(right);
      nodes.putIfAbsent(right, () => <String>{}).add(left);
    }
    for (final media in library) {
      final title = media.title.trim();
      for (final actor in media.actors) { if (relation == 'All connections' || relation == 'People') connect(title, actor); }
      for (final director in media.directors) { if (relation == 'All connections' || relation == 'People') connect(title, director); }
      for (final writer in media.writers) { if (relation == 'All connections' || relation == 'People') connect(title, writer); }
      for (final song in media.music) { if (relation == 'All connections' || relation == 'Music') connect(title, song); }
      for (final genre in media.genres) { if (relation == 'All connections' || relation == 'Genres') connect(title, genre); }
      if (media.franchiseName?.trim().isNotEmpty == true && (relation == 'All connections' || relation == 'Franchises')) connect(title, media.franchiseName!.trim());
      for (final studio in media.studios) { if (relation == 'All connections' || relation == 'Studios') connect(title, studio); }
    }
    for (final track in MusicLibraryStore.instance.tracks) {
      if (relation == 'All connections' || relation == 'People') connect(track.title, track.artist);
      if (relation == 'All connections' || relation == 'Music') connect(track.title, track.album);
      for (final artist in track.featuredArtists) { if (relation == 'All connections' || relation == 'People') connect(track.title, artist); }
      for (final genre in track.genres) { if (relation == 'All connections' || relation == 'Genres') connect(track.title, genre); }
      for (final genre in track.subgenres) { if (relation == 'All connections' || relation == 'Genres') connect(track.title, genre); }
    }
    final names = nodes.keys.where((name) => query.trim().isEmpty || name.toLowerCase().contains(query.toLowerCase())).toList()..sort((a,b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Scaffold(appBar: AppBar(title: const UniversalText('Movie Knowledge Graph')), body: ListView(padding: const EdgeInsets.all(16), children: [
      const UniversalText('Connection graph generated from metadata already in your library. The graph does not invent missing credits or rely on unverified external claims.'),
      const SizedBox(height: 12),
      TextField(onChanged: (value) => setState(() => query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Find a title, person, genre or studio')),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(initialValue: relation, decoration: const InputDecoration(labelText: 'Relationship type'), items: const [DropdownMenuItem(value: 'All connections', child: Text('All connections')), DropdownMenuItem(value: 'People', child: Text('People')), DropdownMenuItem(value: 'Music', child: Text('Music / soundtrack')), DropdownMenuItem(value: 'Genres', child: Text('Genres')), DropdownMenuItem(value: 'Franchises', child: Text('Franchises')), DropdownMenuItem(value: 'Studios', child: Text('Studios'))], onChanged: (v) => setState(() => relation = v ?? relation)),
      const SizedBox(height: 10),
      Text('${nodes.length} connected entities generated from ${library.length} library items.', style: const TextStyle(color: Colors.white60)),
      if (names.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No matching connections. Add richer cast, studio, genre, franchise or soundtrack metadata.'))),
      for (final name in names.take(200)) Card(child: ExpansionTile(leading: const Icon(Icons.hub_rounded), title: Text(name), subtitle: Text('${nodes[name]?.length ?? 0} connection(s)'), children: [for (final linked in (nodes[name] ?? <String>{}).toList()..sort((a,b) => a.toLowerCase().compareTo(b.toLowerCase()))) ListTile(dense: true, leading: const Icon(Icons.link_rounded, size: 18), title: Text(linked), onTap: () => setState(() => query = linked))])),
    ]));
  }
}

class RecommendationTransparencyScreen extends StatefulWidget {
  const RecommendationTransparencyScreen({super.key});
  @override
  State<RecommendationTransparencyScreen> createState() => _RecommendationTransparencyScreenState();
}

class _RecommendationTransparencyScreenState extends State<RecommendationTransparencyScreen> {
  final Set<String> _busy = <String>{};
  String get _key => 'mos_recommendation_feedback_${AppController.instance.currentProfile?.id ?? 'local'}';
  Map<String, String> _localFeedback = <String, String>{};
  bool _loaded = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) { try { _localFeedback = Map<String, String>.from(jsonDecode(raw) as Map); } catch (_) {} }
    if (mounted) setState(() => _loaded = true);
  }

  String _explanation(MediaItem item) {
    final clues = <String>[];
    if (item.genres.isNotEmpty) clues.add('genres: ${item.genres.take(3).join(', ')}');
    if (item.franchiseName?.trim().isNotEmpty == true) clues.add('franchise: ${item.franchiseName}');
    if (item.actors.isNotEmpty) clues.add('cast: ${item.actors.take(2).join(', ')}');
    if (item.directors.isNotEmpty) clues.add('director: ${item.directors.first}');
    if (item.studios.isNotEmpty) clues.add('studio: ${item.studios.first}');
    if (item.releaseYear != null) clues.add('released in ${item.releaseYear}');
    if (clues.isEmpty) return 'There is not enough catalog metadata to explain a relationship yet. Add verified genres, credits, studio or franchise information.';
    return 'Available catalog clues: ${clues.join(' · ')}. These are metadata relationships, not proof of a personal inference or the exact reason a recommendation was served.';
  }

  Future<void> _feedback(MediaItem item, String signal) async {
    if (_busy.contains(item.id)) return;
    setState(() => _busy.add(item.id));
    _localFeedback[item.id] = signal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_localFeedback));
    try {
      await ExpandedPlatformRepository.instance.recordRecommendationFeedback(
        mediaKey: item.id,
        signal: signal,
        recommendationSource: 'entertainment_studio',
        explanation: _explanation(item),
      );
    } catch (_) {
      // The local profile preference is still saved if cloud feedback is offline.
    }
    if (!mounted) return;
    setState(() => _busy.remove(item.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved feedback: $signal')));
  }

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    return Scaffold(appBar: AppBar(title: const UniversalText('Recommendation Transparency')), body: !_loaded ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      const Card(child: Padding(padding: EdgeInsets.all(14), child: UniversalText('Review the visible catalog clues behind discovery and tell the platform what is useful. Feedback is optional, profile-scoped locally, and never used to infer sensitive traits.'))),
      if (library.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Import media to inspect discovery clues.'))),
      for (final item in library.take(100)) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        Text('${item.type}${item.releaseYear == null ? '' : ' · ${item.releaseYear}'}', style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 8),
        Text(_explanation(item)),
        if (_localFeedback[item.id] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Your feedback: ${_localFeedback[item.id]}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12))),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          OutlinedButton.icon(onPressed: _busy.contains(item.id) ? null : () => _feedback(item, 'like'), icon: const Icon(Icons.thumb_up_alt_outlined, size: 16), label: const Text('More like this')),
          OutlinedButton.icon(onPressed: _busy.contains(item.id) ? null : () => _feedback(item, 'not_for_me'), icon: const Icon(Icons.thumb_down_alt_outlined, size: 16), label: const Text('Not for me')),
          TextButton(onPressed: _busy.contains(item.id) ? null : () => _feedback(item, 'already_seen'), child: const Text('Already seen')),
        ]),
      ]))),
    ]));
  }
}

class _KnowledgePickerScreen extends StatelessWidget {
  const _KnowledgePickerScreen();
  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    return Scaffold(appBar: AppBar(title: const UniversalText('Media Knowledge')), body: ListView(padding: const EdgeInsets.all(16), children: [
      const UniversalText('Choose a library title to open its sourced facts and behind-the-scenes panel.'),
      for (final item in library.take(150)) Card(child: ListTile(title: Text(item.title), subtitle: Text(item.type), trailing: const Icon(Icons.auto_stories_rounded), onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => MediaKnowledgeScreen(mediaWorkId: item.id, mediaTitle: item.title)))),),
    ]));
  }
}

class CinemaRoomSettingsScreen extends StatefulWidget {
  const CinemaRoomSettingsScreen({super.key});
  @override
  State<CinemaRoomSettingsScreen> createState() => _CinemaRoomSettingsScreenState();
}

class _CinemaRoomSettingsScreenState extends State<CinemaRoomSettingsScreen> {
  String preset = 'Cinema';
  bool subtitles = false;
  bool reduceMotion = false;
  bool dimControls = true;
  bool audioDescription = false;
  bool volumeLimit = false;
  bool localAmbient = false;
  bool loading = true;
  String get _key => 'mos_cinema_room_${AppController.instance.currentProfile?.id ?? 'local'}';
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) { try { final j = jsonDecode(raw) as Map; preset = j['preset']?.toString() ?? preset; subtitles = j['subtitles'] == true; reduceMotion = j['reduceMotion'] == true; dimControls = j['dimControls'] != false; audioDescription = j['audioDescription'] == true; volumeLimit = j['volumeLimit'] == true; localAmbient = j['localAmbient'] == true; } catch (_) {} }
    if (mounted) setState(() => loading = false);
  }
  Future<void> _save() async { final prefs = await SharedPreferences.getInstance(); await prefs.setString(_key, jsonEncode({'preset': preset, 'subtitles': subtitles, 'reduceMotion': reduceMotion, 'dimControls': dimControls, 'audioDescription': audioDescription, 'volumeLimit': volumeLimit, 'localAmbient': localAmbient})); }
  void _apply(String value) { setState(() { preset = value; switch (value) { case 'Cinema': subtitles = false; reduceMotion = false; dimControls = true; volumeLimit = false; localAmbient = false; break; case 'Late Night': subtitles = true; volumeLimit = true; dimControls = true; reduceMotion = true; break; case 'Family': subtitles = true; volumeLimit = true; dimControls = false; reduceMotion = false; break; case 'Headphones': subtitles = false; volumeLimit = false; localAmbient = false; break; case 'Music Listening': subtitles = false; audioDescription = false; localAmbient = true; break; } }); _save(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const UniversalText('Cinema Room Mode')), body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
    const UniversalText('Save viewing preferences as presets. These settings are preferences only; device lighting and advanced audio processing require compatible integrations.'),
    const SizedBox(height: 12),
    for (final option in const [('Cinema', Icons.theaters_rounded), ('Late Night', Icons.nights_stay_rounded), ('Family', Icons.family_restroom_rounded), ('Headphones', Icons.headphones_rounded), ('Music Listening', Icons.music_note_rounded)]) Card(child: ListTile(leading: Icon(option.$2), title: Text(option.$1), trailing: Icon(preset == option.$1 ? Icons.check_circle_rounded : Icons.circle_outlined, color: preset == option.$1 ? Theme.of(context).colorScheme.primary : null), onTap: () => _apply(option.$1))),
    const Divider(height: 24),
    SwitchListTile(value: subtitles, title: const Text('Prefer subtitles'), onChanged: (v) { setState(() => subtitles = v); _save(); }),
    SwitchListTile(value: audioDescription, title: const Text('Prefer audio description'), onChanged: (v) { setState(() => audioDescription = v); _save(); }),
    SwitchListTile(value: volumeLimit, title: const Text('Use safe volume-limit preference'), onChanged: (v) { setState(() => volumeLimit = v); _save(); }),
    SwitchListTile(value: dimControls, title: const Text('Dim player controls when idle'), onChanged: (v) { setState(() => dimControls = v); _save(); }),
    SwitchListTile(value: reduceMotion, title: const Text('Reduce animations'), onChanged: (v) { setState(() => reduceMotion = v); _save(); }),
    SwitchListTile(value: localAmbient, title: const Text('Ambient audio preference'), subtitle: const Text('Preference only; ambient audio playback needs an installed/authorized sound source.'), onChanged: (v) { setState(() => localAmbient = v); _save(); }),
    const SizedBox(height: 8), FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const UniversalText('Save room preferences')),
  ]));
}
