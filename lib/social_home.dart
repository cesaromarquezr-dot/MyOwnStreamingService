import 'package:flutter/material.dart';

import 'app_core.dart';

/// Profile scoped friend activity and public community discovery for Home.
class SocialHomeSection extends StatefulWidget {
  const SocialHomeSection({super.key});

  @override
  State<SocialHomeSection> createState() => _SocialHomeSectionState();
}

class _SocialHomeSectionState extends State<SocialHomeSection> {
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;
  String communitySearch = '';

  Future<void> load() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null || !AppController.instance.backendApi.isAuthenticated) {
      if (mounted) setState(() { data = null; error = 'Sign in to connect with friends and communities.'; });
      return;
    }
    try {
      final result = await AppController.instance.backendApi.getSocialHome(profileId: profile.id);
      if (mounted) setState(() { data = result; error = null; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try { await action(); await load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext context) {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();
    (data?['friends'] as List? ?? const []).whereType<Map>().toList();
    final requests = (data?['requests'] as List? ?? const []).whereType<Map>().toList();
    final suggestions = (data?['suggestions'] as List? ?? const []).whereType<Map>().toList();
    final posts = (data?['posts'] as List? ?? const []).whereType<Map>().toList();
    final communities = (data?['communities'] as List? ?? const []).whereType<Map>().toList();
    final matchingCommunities = communities.where((c) => '${c['name']} ${c['description']}'.toLowerCase().contains(communitySearch.toLowerCase())).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF15171D), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.people_alt_outlined, color: Color(0xFF76D6E8)), const SizedBox(width: 9), Expanded(child: Text('${data?['friendCount'] ?? '—'} friends', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))), IconButton(onPressed: load, icon: const Icon(Icons.refresh, color: Colors.white70))]),
          if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(error!, style: const TextStyle(color: Colors.white60))),
          if (data != null) ...[
            Row(children: [Expanded(child: Text('Friends’ posts', style: _heading)), TextButton(onPressed: () => _compose(profile.id), child: const Text('Create post'))]),
            if (posts.isEmpty) const Text('Posts from friends will show up here.', style: TextStyle(color: Colors.white54)) else ...posts.take(5).map(_postCard),
            if (requests.isNotEmpty) ...[const SizedBox(height: 12), Text('Friend requests', style: _heading), ...requests.map((r) => _requestRow(profile.id, r))],
            if (suggestions.isNotEmpty) ...[const SizedBox(height: 12), Text('People you may know', style: _heading), SizedBox(height: 90, child: ListView(scrollDirection: Axis.horizontal, children: suggestions.map(_suggestion).toList()))],
            const SizedBox(height: 12), Row(children: [Expanded(child: Text('Communities', style: _heading)), TextButton(onPressed: () => _createCommunity(profile.id), child: const Text('Create'))]),
            TextField(onChanged: (value) => setState(() => communitySearch = value), style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Search public communities', hintStyle: const TextStyle(color: Colors.white38), prefixIcon: const Icon(Icons.search, color: Colors.white54), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none))),
            const SizedBox(height: 6),
            if (matchingCommunities.isEmpty) const Text('No matching public communities yet. Create one to get started.', style: TextStyle(color: Colors.white54)) else ...matchingCommunities.take(6).map((c) => _communityRow(profile.id, c)),
          ],
        ]),
      ),
    );
  }

  TextStyle get _heading => const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700);
  Widget _postCard(Map post) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((post['author'] as Map?)?['display_name']?.toString() ?? post['author_profile_name']?.toString() ?? 'Friend', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(post['body']?.toString() ?? '', style: const TextStyle(color: Colors.white))]));
  Widget _suggestion(Map person) => SizedBox(width: 165, child: Card(color: const Color(0xFF20232B), child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: Text(person['display_name']?.toString() ?? person['username']?.toString() ?? 'Member', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)))]))));
  Widget _requestRow(String profileId, Map request) { final sender = request['sender'] as Map? ?? const {}; return Row(children: [Expanded(child: Text(sender['display_name']?.toString() ?? sender['username']?.toString() ?? 'Someone', style: const TextStyle(color: Colors.white70))), TextButton(onPressed: () => act(() async { await AppController.instance.backendApi.respondFriendRequest(profileId: profileId, friendshipId: request['id'].toString(), action: 'accept'); }), child: const Text('Accept')), TextButton(onPressed: () => act(() async { await AppController.instance.backendApi.respondFriendRequest(profileId: profileId, friendshipId: request['id'].toString(), action: 'decline'); }), child: const Text('Decline'))]); }
  Widget _communityRow(String profileId, Map community) => Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(community['name']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
          subtitle: Text(community['description']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
          trailing: community['joined'] == true
              ? const Icon(Icons.check_circle, color: Color(0xFF76D6E8))
              : TextButton(onPressed: () => act(() async { await AppController.instance.backendApi.joinSocialCommunity(profileId: profileId, communityId: community['id'].toString()); }), child: const Text('Join')),
        ),
      );

  Future<void> _compose(String profileId) async { final value = await _textDialog('Create a post', 'What are you watching or listening to?'); if (value != null && value.trim().isNotEmpty) await act(() async { await AppController.instance.backendApi.createSocialPost(profileId: profileId, body: value.trim()); }); }
  Future<void> _createCommunity(String profileId) async { final name = await _textDialog('Create community', 'Community name'); if (name == null || name.trim().isEmpty) return; final description = await _textDialog('Community description', 'What is this community about?') ?? ''; await act(() async { await AppController.instance.backendApi.createSocialCommunity(profileId: profileId, name: name.trim(), description: description.trim()); }); }
  Future<String?> _textDialog(String title, String hint) async { final controller = TextEditingController(); final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: Text(title), content: TextField(controller: controller, autofocus: true, maxLines: title == 'Create a post' ? 4 : 1, decoration: InputDecoration(hintText: hint)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save'))])); controller.dispose(); return value; }
}
