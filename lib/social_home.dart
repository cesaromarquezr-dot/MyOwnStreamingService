import 'package:flutter/material.dart';

import 'app_core.dart';
import 'profiles.dart';

/// Profile-scoped friends, account profiles, and community activity for Home.
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

  List<Map<String, dynamic>> _items(String key) =>
      (data?[key] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  Future<void> load() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null || !AppController.instance.backendApi.isAuthenticated) {
      if (mounted) {
        setState(() {
          data = null;
          error = 'Sign in to connect with friends and communities.';
        });
      }
      return;
    }
    try {
      final result = await AppController.instance.backendApi
          .getSocialHome(profileId: profile.id);
      if (mounted) {
        setState(() {
          data = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    final account = AppController.instance.currentAccount;
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();

    final profiles = account?.profiles ?? const <Profile>[];
    final friends = _items('friends');
    final requests = _items('requests');
    final suggestions = _items('suggestions');
    final posts = _items('posts');
    final stories = _items('stories');
    final communityStories = _items('communityStories');
    final communities = _items('communities');
    final matchingCommunities = communities.where((community) {
      final text =
          '${community['name']} ${community['description']}'.toLowerCase();
      return text.contains(communitySearch.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF15171D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: Color(0xFF76D6E8)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${data?['friendCount'] ?? '—'} friends',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: load,
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child:
                    Text(error!, style: const TextStyle(color: Colors.white60)),
              ),
            if (profiles.length >= 2) ...[
              Row(
                children: [
                  Expanded(child: _sectionHeading('Your account group')),
                  TextButton(
                    onPressed: _openAccountGroup,
                    child: const Text('Switch profile'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final member in profiles)
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: member.avatarUrl == null
                                  ? null
                                  : NetworkImage(member.avatarUrl!),
                              child: member.avatarUrl == null
                                  ? Text(_initial(member.name))
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              member.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: member.id == profile.id
                                    ? const Color(0xFF76D6E8)
                                    : Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (data != null) ...[
              ...[
                _sectionHeading('Friends’ stories'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 92,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _storyBubble(
                        {
                          'isComposer': true,
                          'author': {'display_name': 'Your story'},
                        },
                        onTap: _composeStory,
                      ),
                      ...stories.map(
                        (story) => _storyBubble(
                          story,
                          onTap: () => _showStory(story),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (communityStories.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionHeading('Community stories'),
                const SizedBox(height: 6),
                for (final group in _groupStories(communityStories))
                  _communityStoryRow(group),
              ],
              Row(
                children: [
                  Expanded(child: _sectionHeading('Friends’ posts')),
                  TextButton(
                    onPressed: () => _compose(profile.id),
                    child: const Text('Create post'),
                  ),
                ],
              ),
              if (posts.isEmpty)
                const Text(
                  'Posts from your friends will show up here.',
                  style: TextStyle(color: Colors.white54),
                )
              else
                ...posts.take(5).map(_postCard),
              if (friends.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionHeading('Your friends'),
                SizedBox(
                  height: 84,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: friends.map(_friendBubble).toList(),
                  ),
                ),
              ],
              if (requests.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sectionHeading('Friend requests'),
                ...requests.map((request) => _requestRow(profile.id, request)),
              ],
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sectionHeading('People you may know'),
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: suggestions.map(_suggestion).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _sectionHeading('Communities')),
                  TextButton(
                    onPressed: () => _createCommunity(profile.id),
                    child: const Text('Create'),
                  ),
                ],
              ),
              TextField(
                onChanged: (value) => setState(() => communitySearch = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search public communities',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (matchingCommunities.isEmpty)
                const Text(
                  'No matching public communities yet. Create one to get started.',
                  style: TextStyle(color: Colors.white54),
                )
              else
                ...matchingCommunities.take(6).map(
                      (community) => _communityRow(profile.id, community),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeading(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      );

  List<List<Map<String, dynamic>>> _groupStories(
    List<Map<String, dynamic>> stories,
  ) {
    final byCommunity = <String, List<Map<String, dynamic>>>{};
    for (final story in stories) {
      final id = story['community_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      byCommunity.putIfAbsent(id, () => []).add(story);
    }
    return byCommunity.values.toList();
  }

  Widget _communityStoryRow(List<Map<String, dynamic>> stories) {
    final communityName =
        stories.first['communityName']?.toString() ?? 'Community';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(communityName,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 5),
          SizedBox(
            height: 68,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: stories
                  .map(
                    (story) => _storyBubble(
                      story,
                      onTap: () => _showStory(story),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storyBubble(
    Map<String, dynamic> story, {
    required VoidCallback onTap,
  }) {
    final author = story['author'] is Map
        ? Map<String, dynamic>.from(story['author'] as Map)
        : <String, dynamic>{};
    final isComposer = story['isComposer'] == true;
    final name = isComposer
        ? 'Your story'
        : author['display_name']?.toString() ??
            author['username']?.toString() ??
            'Friend';
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: isComposer
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFF282D38),
              child: Icon(
                isComposer ? Icons.add_rounded : Icons.person_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _friendBubble(Map<String, dynamic> friend) {
    final name = friend['display_name']?.toString() ??
        friend['username']?.toString() ??
        'Friend';
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          CircleAvatar(child: Text(_initial(name))),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final author = post['author'] is Map
        ? Map<String, dynamic>.from(post['author'] as Map)
        : <String, dynamic>{};
    final reference = post['mediaReference'] is Map
        ? Map<String, dynamic>.from(post['mediaReference'] as Map)
        : <String, dynamic>{};
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            author['display_name']?.toString() ??
                post['author_profile_name']?.toString() ??
                'Friend',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          if (reference['type'] == 'review')
            Text(
              'Review · ${reference['mediaTitle'] ?? 'Media'} · ${reference['score'] ?? ''}/10',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          Text(post['body']?.toString() ?? '',
              style: const TextStyle(color: Colors.white)),
          if (reference['imageUrl'] != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                reference['imageUrl'].toString(),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(height: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _suggestion(Map<String, dynamic> person) => SizedBox(
        width: 165,
        child: Card(
          color: const Color(0xFF20232B),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    person['display_name']?.toString() ??
                        person['username']?.toString() ??
                        'Member',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _requestRow(String profileId, Map<String, dynamic> request) {
    final sender = request['sender'] is Map
        ? Map<String, dynamic>.from(request['sender'] as Map)
        : <String, dynamic>{};
    return Row(
      children: [
        Expanded(
          child: Text(
            sender['display_name']?.toString() ??
                sender['username']?.toString() ??
                'Someone',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        TextButton(
          onPressed: () => _act(
            () => AppController.instance.backendApi.respondFriendRequest(
              profileId: profileId,
              friendshipId: request['id'].toString(),
              action: 'accept',
            ),
          ),
          child: const Text('Accept'),
        ),
        TextButton(
          onPressed: () => _act(
            () => AppController.instance.backendApi.respondFriendRequest(
              profileId: profileId,
              friendshipId: request['id'].toString(),
              action: 'decline',
            ),
          ),
          child: const Text('Decline'),
        ),
      ],
    );
  }

  Widget _communityRow(String profileId, Map<String, dynamic> community) =>
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          community['name']?.toString() ?? '',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          community['description']?.toString() ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: community['joined'] == true
            ? const Icon(Icons.check_circle, color: Color(0xFF76D6E8))
            : TextButton(
                onPressed: () => _act(
                  () => AppController.instance.backendApi.joinSocialCommunity(
                    profileId: profileId,
                    communityId: community['id'].toString(),
                  ),
                ),
                child: const Text('Join'),
              ),
      );

  Future<void> _openAccountGroup() async {
    await Navigator.of(context).push<Profile?>(
      MaterialPageRoute<Profile?>(
        settings: const RouteSettings(name: '/app/profiles'),
        builder: (_) => const ProfileSelectionScreen(),
      ),
    );
    if (!mounted) return;
    setState(() {});
    await load();
  }

  Future<void> _compose(String profileId) async {
    final value = await _textDialog(
      'Create a post',
      'What are you watching or listening to?',
    );
    if (value == null || value.trim().isEmpty) return;
    await _act(
      () => AppController.instance.backendApi.createSocialPost(
        profileId: profileId,
        body: value.trim(),
      ),
    );
  }

  Future<void> _composeStory() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final controller = TextEditingController();
    var expiresInHours = 24;
    final value = await showDialog<(String, int)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Your story'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Share something with your friends',
                ),
              ),
              DropdownButtonFormField<int>(
                initialValue: expiresInHours,
                decoration: const InputDecoration(labelText: 'Story lifetime'),
                items: const [
                  DropdownMenuItem(value: 24, child: Text('24 hours')),
                  DropdownMenuItem(value: 48, child: Text('2 days')),
                  DropdownMenuItem(value: 72, child: Text('3 days')),
                  DropdownMenuItem(value: 168, child: Text('1 week')),
                ],
                onChanged: (value) =>
                    setDialogState(() => expiresInHours = value ?? 24),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                (controller.text, expiresInHours),
              ),
              child: const Text('Share'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null || value.$1.trim().isEmpty) return;
    await _act(
      () => AppController.instance.backendApi.createSocialStory(
        profileId: profile.id,
        body: value.$1.trim(),
        expiresInHours: value.$2,
      ),
    );
  }

  Future<void> _createCommunity(String profileId) async {
    final name = await _textDialog('Create community', 'Community name');
    if (name == null || name.trim().isEmpty) return;
    final description = await _textDialog(
          'Community description',
          'What is this community about?',
        ) ??
        '';
    await _act(
      () => AppController.instance.backendApi.createSocialCommunity(
        profileId: profileId,
        name: name.trim(),
        description: description.trim(),
      ),
    );
  }

  Future<String?> _textDialog(String title, String hint) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: title == 'Create a post' || title == 'Your story' ? 4 : 1,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  void _showStory(Map<String, dynamic> story) {
    final author = story['author'] is Map
        ? Map<String, dynamic>.from(story['author'] as Map)
        : <String, dynamic>{};
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          author['display_name']?.toString() ??
              story['communityName']?.toString() ??
              'Story',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(story['body']?.toString() ?? ''),
            if (story['mediaReference'] is Map &&
                (story['mediaReference'] as Map)['imageUrl'] != null) ...[
              const SizedBox(height: 12),
              Image.network(
                (story['mediaReference'] as Map)['imageUrl'].toString(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _initial(String value) =>
      value.trim().isEmpty ? '?' : value.trim().substring(0, 1).toUpperCase();
}
