import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';

/// Shared conversation tools. Local drafts are stored per profile; delivery and
/// recipient access still require the messaging/backend APIs.
class UniversalSharingHubScreen extends StatefulWidget {
  final List<Map<String, dynamic>> conversations;
  const UniversalSharingHubScreen({super.key, this.conversations = const []});

  @override
  State<UniversalSharingHubScreen> createState() => _UniversalSharingHubScreenState();
}

class _UniversalSharingHubScreenState extends State<UniversalSharingHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Set<String> _selectedMedia = {};
  final Set<String> _selectedCollections = {};
  final Set<String> _selectedConversationIds = {};
  final Set<String> _categories = {'Movies', 'Shows', 'Albums', 'Songs', 'Playlists', 'Collections', 'Products', 'Stores'};
  final TextEditingController _search = TextEditingController();
  final TextEditingController _pollQuestion = TextEditingController();
  final TextEditingController _pollOptions = TextEditingController(text: 'Option 1\nOption 2');
  final TextEditingController _plannerTitle = TextEditingController();
  final TextEditingController _plannerDate = TextEditingController();
  List<Map<String, dynamic>> _sharedItems = [];
  List<Map<String, dynamic>> _polls = [];
  List<Map<String, dynamic>> _plans = [];
  bool _allowReshare = true;
  bool _allowCollectionContributions = true;
  bool _showActivity = false;
  bool _expireLinks = false;
  bool _loading = true;

  String get _profileKey => AppController.instance.currentProfile?.id ?? 'default';
  String get _storagePrefix => 'universal_sharing_hub_$_profileKey';
  List<MediaItem> get _media => AppController.instance.library.where((item) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty && !item.title.toLowerCase().contains(q)) return false;
    final t = item.type.toLowerCase();
    if (_categories.contains('Movies') && (t.contains('movie') || t == 'film')) return true;
    if (_categories.contains('Shows') && (t.contains('show') || t.contains('tv') || t.contains('series') || t.contains('episode'))) return true;
    if (_categories.contains('Albums') && t.contains('album')) return true;
    if (_categories.contains('Songs') && (t.contains('song') || t.contains('track'))) return true;
    return false;
  }).toList();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    _pollQuestion.dispose();
    _pollOptions.dispose();
    _plannerTitle.dispose();
    _plannerDate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> readList(String key) {
      final raw = prefs.getString('$_storagePrefix.$key');
      if (raw == null) return [];
      try { return (jsonDecode(raw) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); }
      catch (_) { return []; }
    }
    if (!mounted) return;
    setState(() {
      _sharedItems = readList('items');
      _polls = readList('polls');
      _plans = readList('plans');
      _allowReshare = prefs.getBool('$_storagePrefix.allowReshare') ?? true;
      _allowCollectionContributions = prefs.getBool('$_storagePrefix.allowContributions') ?? true;
      _showActivity = prefs.getBool('$_storagePrefix.showActivity') ?? false;
      _expireLinks = prefs.getBool('$_storagePrefix.expireLinks') ?? false;
      _loading = false;
    });
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_storagePrefix.$key', jsonEncode(value));
  }

  Future<void> _shareSelected() async {
    if (_selectedMedia.isEmpty && _selectedCollections.isEmpty) {
      _snack('Choose at least one item to share.'); return;
    }
    if (widget.conversations.isNotEmpty && _selectedConversationIds.isEmpty) {
      _snack('Choose one or more conversations.'); return;
    }
    final selected = <Map<String, dynamic>>[];
    for (final item in AppController.instance.library.where((m) => _selectedMedia.contains(m.id))) {
      selected.add({'id': item.id, 'title': item.title, 'type': item.type, 'kind': 'media', 'ownedBySender': true, 'sharedAt': DateTime.now().toIso8601String()});
    }
    for (final c in AppController.instance.collections.where((c) => _selectedCollections.contains(c.id))) {
      selected.add({'id': c.id, 'title': c.name, 'type': 'collection', 'kind': 'collection', 'sharedAt': DateTime.now().toIso8601String()});
    }
    final conversations = widget.conversations.where((c) => _selectedConversationIds.contains((c['id'] ?? c['conversationId'] ?? c['roomId']).toString())).map((c) => (c['name'] ?? c['title'] ?? c['displayName'] ?? 'Conversation').toString()).toList();
    for (final item in selected) { item['conversationNames'] = conversations; }
    setState(() => _sharedItems = [...selected, ..._sharedItems]);
    await _saveList('items', _sharedItems);
    _snack(widget.conversations.isEmpty ? 'Added to your local shared-items log. Connect messaging to deliver to recipients.' : 'Saved share drafts for ${conversations.length} conversation(s). Backend delivery is not connected here.');
    setState(() { _selectedMedia.clear(); _selectedCollections.clear(); _selectedConversationIds.clear(); });
    _tabs.animateTo(1);
  }

  Future<void> _createPoll() async {
    final question = _pollQuestion.text.trim();
    final options = _pollOptions.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (question.isEmpty || options.length < 2) { _snack('Add a question and at least two options.'); return; }
    final poll = {'id': DateTime.now().microsecondsSinceEpoch.toString(), 'question': question, 'options': options, 'votes': <String, int>{}, 'createdAt': DateTime.now().toIso8601String()};
    setState(() { _polls = [poll, ..._polls]; _pollQuestion.clear(); _pollOptions.text = 'Option 1\nOption 2'; });
    await _saveList('polls', _polls);
    _snack('Poll draft saved locally. Connect the chat API to publish it to a group.');
  }

  Future<void> _createPlan() async {
    if (_plannerTitle.text.trim().isEmpty) { _snack('Enter a movie, show, or episode for the plan.'); return; }
    final plan = {'id': DateTime.now().microsecondsSinceEpoch.toString(), 'title': _plannerTitle.text.trim(), 'date': _plannerDate.text.trim(), 'status': 'Planning', 'createdAt': DateTime.now().toIso8601String()};
    setState(() { _plans = [plan, ..._plans]; _plannerTitle.clear(); _plannerDate.clear(); });
    await _saveList('plans', _plans);
    _snack('Watch Party plan saved locally. Invitations and synchronized playback need backend support.');
  }

  Future<void> _savePermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_storagePrefix.allowReshare', _allowReshare);
    await prefs.setBool('$_storagePrefix.allowContributions', _allowCollectionContributions);
    await prefs.setBool('$_storagePrefix.showActivity', _showActivity);
    await prefs.setBool('$_storagePrefix.expireLinks', _expireLinks);
    _snack('Sharing preferences saved for this profile on this device.');
  }

  void _snack(String message) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }

  @override
  Widget build(BuildContext context) {
    final collections = AppController.instance.collections;
    return Scaffold(
      appBar: AppBar(title: const Text('Hey Share · Universal Sharing'), bottom: TabBar(controller: _tabs, isScrollable: true, tabs: const [Tab(icon: Icon(Icons.ios_share), text: 'Share anything'), Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Shared items'), Tab(icon: Icon(Icons.poll_outlined), text: 'Polls'), Tab(icon: Icon(Icons.movie_filter_outlined), text: 'Watch Party planner'), Tab(icon: Icon(Icons.shield_outlined), text: 'Permissions')])),
      body: _loading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: _tabs, children: [
        _buildShareTab(collections), _buildSharedItemsTab(), _buildPollsTab(), _buildPlansTab(), _buildPermissionsTab(),
      ]),
    );
  }

  Widget _buildShareTab(List<MediaCollection> collections) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Share anything', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4), const Text('Select multiple items and conversations. Recipient ownership affects card emphasis and actions, never whether a shared item is visible.', style: TextStyle(color: Colors.white60)),
    const SizedBox(height: 14),
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: ['Movies', 'Shows', 'Albums', 'Songs', 'Playlists', 'Collections', 'Products', 'Stores']
          .map(
            (category) => FilterChip(
              label: Text(category),
              selected: _categories.contains(category),
              onSelected: (selected) => setState(() {
                if (selected) {
                  _categories.add(category);
                } else {
                  _categories.remove(category);
                }
              }),
            ),
          )
          .toList(),
    ),
    const SizedBox(height: 12),
    TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search your media library', border: OutlineInputBorder())),
    const SizedBox(height: 8),
    if (_media.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No matching catalog media. You can still share collections below or connect additional catalog providers.', style: TextStyle(color: Colors.white60))),
    ..._media.take(100).map((m) => CheckboxListTile(value: _selectedMedia.contains(m.id), onChanged: (v) => setState(() => v == true ? _selectedMedia.add(m.id) : _selectedMedia.remove(m.id)), title: Text(m.title), subtitle: Text('${m.type}${m.releaseYear == null ? '' : ' · ${m.releaseYear}'}'), secondary: const Icon(Icons.play_circle_outline), controlAffinity: ListTileControlAffinity.leading)),
    if (collections.isNotEmpty) ...[const Divider(), const Text('Collections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), ...collections.take(100).map((c) => CheckboxListTile(value: _selectedCollections.contains(c.id), onChanged: (v) => setState(() => v == true ? _selectedCollections.add(c.id) : _selectedCollections.remove(c.id)), title: Text(c.name), subtitle: Text('${c.mediaIds.length} items'), secondary: const Icon(Icons.collections_bookmark_outlined), controlAffinity: ListTileControlAffinity.leading))],
    if (widget.conversations.isNotEmpty) ...[const Divider(), const Text('Send to conversations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), ...widget.conversations.map((c) { final id = (c['id'] ?? c['conversationId'] ?? c['roomId'] ?? '').toString(); return CheckboxListTile(value: _selectedConversationIds.contains(id), onChanged: id.isEmpty ? null : (v) => setState(() => v == true ? _selectedConversationIds.add(id) : _selectedConversationIds.remove(id)), title: Text((c['name'] ?? c['title'] ?? c['displayName'] ?? 'Conversation').toString()), subtitle: Text((c['type'] ?? c['kind'] ?? 'Conversation').toString()), controlAffinity: ListTileControlAffinity.leading); })],
    const SizedBox(height: 12), FilledButton.icon(onPressed: _shareSelected, icon: const Icon(Icons.send_rounded), label: const Text('Create share draft')),
    const SizedBox(height: 6), const Text('Products and stores can be shared as links or catalog references when their provider integration is available.', style: TextStyle(color: Colors.white54, fontSize: 12)),
  ]);

  Widget _buildSharedItemsTab() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Shared items', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
    const Text('Local share history and drafts for this profile.', style: TextStyle(color: Colors.white60)), const SizedBox(height: 12),
    if (_sharedItems.isEmpty) const ListTile(leading: Icon(Icons.inventory_2_outlined), title: Text('Nothing shared yet'), subtitle: Text('Select items in Share anything to start a share draft.')),
    ..._sharedItems.map((item) { final owned = item['ownedBySender'] == true; return Card(color: owned ? null : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55), child: ListTile(leading: Icon(_iconFor(item['type']?.toString() ?? '')), title: Text(item['title']?.toString() ?? 'Shared item', style: TextStyle(color: owned ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: .68))), subtitle: Text('${item['type'] ?? 'Item'} · ${((item['conversationNames'] as List?) ?? const []).join(', ')}'), trailing: IconButton(tooltip: 'Remove local draft', icon: const Icon(Icons.close), onPressed: () async { setState(() => _sharedItems.remove(item)); await _saveList('items', _sharedItems); }))); }),
  ]);

  Widget _buildPollsTab() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Chat polls', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const Text('Create a vote for what your group should watch, listen to, or explore.', style: TextStyle(color: Colors.white60)), const SizedBox(height: 12),
    TextField(controller: _pollQuestion, decoration: const InputDecoration(labelText: 'Poll question', hintText: 'What should we watch tonight?')), const SizedBox(height: 8),
    TextField(controller: _pollOptions, minLines: 2, maxLines: 6, decoration: const InputDecoration(labelText: 'Options (one per line)')), const SizedBox(height: 10),
    FilledButton.icon(onPressed: _createPoll, icon: const Icon(Icons.add), label: const Text('Save poll draft')),
    const Divider(height: 28), if (_polls.isEmpty) const Text('No poll drafts yet.'), ..._polls.map((p) => Card(child: ListTile(leading: const Icon(Icons.poll), title: Text(p['question']?.toString() ?? ''), subtitle: Text(((p['options'] as List?) ?? const []).join('  •  ')), trailing: const Chip(label: Text('Draft'))))),
  ]);

  Widget _buildPlansTab() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Watch Party planner', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const Text('Plan a session before opening the Watch Party ready lobby.', style: TextStyle(color: Colors.white60)), const SizedBox(height: 12),
    TextField(controller: _plannerTitle, decoration: const InputDecoration(labelText: 'Movie, show, or episode')), const SizedBox(height: 8),
    TextField(controller: _plannerDate, decoration: const InputDecoration(labelText: 'Date and time (optional)', hintText: 'e.g. Friday at 8 PM')), const SizedBox(height: 10),
    FilledButton.icon(onPressed: _createPlan, icon: const Icon(Icons.event_available), label: const Text('Save plan')),
    const Divider(height: 28), if (_plans.isEmpty) const Text('No Watch Party plans yet.'), ..._plans.map((p) => Card(child: ListTile(leading: const Icon(Icons.movie_filter), title: Text(p['title']?.toString() ?? ''), subtitle: Text(p['date']?.toString().isNotEmpty == true ? p['date'].toString() : 'Time not set'), trailing: const Chip(label: Text('Planning'))))),
  ]);

  Widget _buildPermissionsTab() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Sharing permissions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const Text('These preferences are saved locally per profile. Backend authorization must enforce sharing, privacy, and expiry for all recipients.', style: TextStyle(color: Colors.white60)), const SizedBox(height: 12),
    SwitchListTile(value: _allowReshare, onChanged: (v) => setState(() => _allowReshare = v), title: const Text('Allow recipients to reshare my items'), subtitle: const Text('A preference for integrations that support reshare controls.')),
    SwitchListTile(value: _allowCollectionContributions, onChanged: (v) => setState(() => _allowCollectionContributions = v), title: const Text('Allow collaborative collection contributions')),
    SwitchListTile(value: _showActivity, onChanged: (v) => setState(() => _showActivity = v), title: const Text('Show my shared entertainment activity'), subtitle: const Text('Off by default. Server-side privacy checks are still required.')),
    SwitchListTile(value: _expireLinks, onChanged: (v) => setState(() => _expireLinks = v), title: const Text('Prefer expiring share links')),
    const SizedBox(height: 10), FilledButton.icon(onPressed: _savePermissions, icon: const Icon(Icons.save_outlined), label: const Text('Save preferences')),
  ]);

  IconData _iconFor(String type) { final t = type.toLowerCase(); if (t.contains('song') || t.contains('album') || t.contains('music')) return Icons.music_note; if (t.contains('collection') || t.contains('playlist')) return Icons.collections_bookmark_outlined; if (t.contains('product') || t.contains('store')) return Icons.shopping_bag_outlined; if (t.contains('show') || t.contains('tv') || t.contains('episode')) return Icons.tv; return Icons.movie_outlined; }
}
