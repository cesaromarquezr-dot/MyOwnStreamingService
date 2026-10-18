import 'package:flutter/material.dart';

import 'app_core.dart';

/// Canonical community detail page. Data, counts, and membership are retrieved
/// from the authenticated API instead of trusting counters sent by a list tile.
class SocialCommunityDetailScreen extends StatefulWidget {
  const SocialCommunityDetailScreen({super.key, required this.community});

  final Map<String, dynamic> community;

  @override
  State<SocialCommunityDetailScreen> createState() =>
      _SocialCommunityDetailScreenState();
}

class _SocialCommunityDetailScreenState
    extends State<SocialCommunityDetailScreen> {
  Map<String, dynamic>? _community;
  List<Map<String, dynamic>> _posts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _members = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _section = 'Posts';

  String get _communityId => widget.community['id']?.toString() ?? '';

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
      : <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null || _communityId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Select a profile to view this community.';
        });
      }
      return;
    }
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await AppController.instance.backendApi.getSocialCommunityDetail(
        profileId: profile.id,
        communityId: _communityId,
      );
      if (!mounted) return;
      setState(() {
        _community = result['community'] is Map
            ? Map<String, dynamic>.from(result['community'] as Map)
            : Map<String, dynamic>.from(widget.community);
        _posts = _maps(result['posts']);
        _members = _maps(result['members']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
        // Do not use a cached private-community name or description as a
        // fallback when server authorization failed or could not be checked.
        final cached = Map<String, dynamic>.from(widget.community);
        final privateUnavailable = cached['visibility'] == 'private' &&
            cached['joined'] != true;
        if (privateUnavailable) {
          _community = <String, dynamic>{
            'id': _communityId,
            'name': 'Private community',
            'visibility': 'private',
            'joined': false,
          };
          _posts = <Map<String, dynamic>>[];
          _members = <Map<String, dynamic>>[];
        } else {
          _community ??= cached;
        }
      });
    }
  }

  Future<void> _membershipAction({required bool join}) async {
    final profile = AppController.instance.currentProfile;
    if (profile == null || _busy) return;
    if (!join && _community?['isOwner'] == true) {
      _notice('Transfer community ownership before leaving.');
      return;
    }
    if (!join) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave this community?'),
          content: const Text(
            'You will lose access to member-only posts and stories. You can rejoin later if the community remains available.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep me in')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave community')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      if (join) {
        await AppController.instance.backendApi.joinSocialCommunity(
          profileId: profile.id,
          communityId: _communityId,
        );
      } else {
        await AppController.instance.backendApi.leaveSocialCommunity(
          profileId: profile.id,
          communityId: _communityId,
        );
      }
      await _load();
      if (mounted) _notice(join ? 'You joined the community.' : 'You left the community.');
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createPost() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null || _busy || _community?['joined'] != true) return;
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Post to this community'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          maxLength: 4000,
          decoration: const InputDecoration(hintText: 'Start a conversation…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Publish')),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await AppController.instance.backendApi.createSocialPost(
        profileId: profile.id,
        body: body.trim(),
        communityId: _communityId,
      );
      await _load();
      if (mounted) _notice('Post published.');
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createStory() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null || _busy || _community?['joined'] != true) return;
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a community story'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          decoration: const InputDecoration(hintText: 'What is happening?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Share story')),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await AppController.instance.backendApi.createSocialStory(
        profileId: profile.id,
        body: body.trim(),
        communityId: _communityId,
        expiresInHours: 24,
      );
      await _load();
      if (mounted) _notice('Story shared for 24 hours.');
    } catch (error) {
      if (mounted) _notice(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final community = _community ?? widget.community;
    final name = community['name']?.toString() ?? 'Community';
    final description = community['description']?.toString().trim() ?? '';
    final category = (community['category'] ?? 'general').toString();
    final joined = community['joined'] == true;
    final isPrivate = community['visibility'] == 'private';
    final isOwner = community['isOwner'] == true || community['memberRole'] == 'owner';
    final memberCount = (community['memberCount'] as num?)?.toInt() ?? 0;
    final postCount = (community['postCount'] as num?)?.toInt() ?? 0;
    final icon = switch (category.toLowerCase()) {
      'movies' => Icons.movie_creation_outlined,
      'shows' => Icons.live_tv_rounded,
      'music' => Icons.music_note_rounded,
      _ => Icons.groups_rounded,
    };

    return Scaffold(
      appBar: AppBar(title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis), actions: [
        IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: _loading && _community == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF302156), Color(0xFF64419A), Color(0xFF17213B)],
                      ),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(radius: 28, backgroundColor: Colors.white.withValues(alpha: .16), child: Icon(icon, size: 30, color: Colors.white)),
                      const SizedBox(height: 12),
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 25)),
                      const SizedBox(height: 5),
                      Text('${_titleCase(category)} community · ${community['visibility'] == 'private' ? 'Private' : 'Public'}', style: const TextStyle(color: Colors.white70)),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(description, style: const TextStyle(color: Colors.white, height: 1.35)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _StatTile(icon: Icons.people_alt_outlined, value: _compactCount(memberCount), label: 'Members')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatTile(icon: Icons.article_outlined, value: _compactCount(postCount), label: 'Posts')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatTile(icon: Icons.shield_outlined, value: isOwner ? 'Owner' : joined ? 'Member' : 'Open', label: 'Your status')),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: joined
                        ? OutlinedButton.icon(
                            onPressed: _busy || isOwner ? null : () => _membershipAction(join: false),
                            icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline_rounded),
                            label: Text(isOwner ? 'Community owner' : 'Joined · Leave community'),
                          )
                        : FilledButton.icon(
                            onPressed: _busy || isPrivate ? null : () => _membershipAction(join: true),
                            icon: _busy
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(isPrivate ? Icons.lock_outline_rounded : Icons.group_add_rounded),
                            label: Text(isPrivate ? 'Private · Invite required' : 'Join community'),
                          ),
                  ),
                  if (joined) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _createPost, icon: const Icon(Icons.post_add_rounded), label: const Text('Create post'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _createStory, icon: const Icon(Icons.add_circle_outline_rounded), label: const Text('Add story'))),
                    ]),
                  ],
                  if (_error != null) Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Card(child: ListTile(leading: const Icon(Icons.cloud_off_rounded), title: const Text('Could not refresh community'), subtitle: Text(_error!), trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)))),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Posts', label: Text('Posts'), icon: Icon(Icons.forum_outlined)),
                      ButtonSegment(value: 'Members', label: Text('Members'), icon: Icon(Icons.people_alt_outlined)),
                      ButtonSegment(value: 'About', label: Text('About'), icon: Icon(Icons.info_outline_rounded)),
                    ],
                    selected: {_section},
                    onSelectionChanged: (selection) => setState(() => _section = selection.first),
                  ),
                  const SizedBox(height: 12),
                  if (_section == 'About')
                    _aboutCard(community, category)
                  else if (_section == 'Members')
                    if (!joined)
                      const _EmptyPanel(icon: Icons.lock_outline_rounded, title: 'Join to browse members', subtitle: 'The member list is available to community members.')
                    else if (_members.isEmpty)
                      const _EmptyPanel(icon: Icons.people_outline_rounded, title: 'No members to show', subtitle: 'Refresh to check the member list.')
                    else
                      ..._members.map(_memberTile)
                  else if (!joined)
                    const _EmptyPanel(icon: Icons.lock_outline_rounded, title: 'Join the conversation', subtitle: 'Join this community to view its posts, react, and publish your own discussions.')
                  else if (_posts.isEmpty)
                    const _EmptyPanel(icon: Icons.forum_outlined, title: 'No posts yet', subtitle: 'Start the first discussion in this community.')
                  else
                    ..._posts.map(_postTile),
                ],
              ),
            ),
    );
  }

  Widget _aboutCard(Map<String, dynamic> community, String category) {
    final created = DateTime.tryParse((community['created_at'] ?? '').toString());
    final creator = community['created_by_profile_id']?.toString();
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('About this community', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      _InfoRow(icon: Icons.category_outlined, label: 'Category', value: _titleCase(category)),
      _InfoRow(icon: Icons.public_outlined, label: 'Visibility', value: _titleCase((community['visibility'] ?? 'public').toString())),
      _InfoRow(icon: Icons.calendar_month_outlined, label: 'Created', value: created == null ? 'Date unavailable' : '${created.day}/${created.month}/${created.year}'),
      if (creator != null && creator.isNotEmpty) _InfoRow(icon: Icons.verified_user_outlined, label: 'Creator profile ID', value: creator),
      const Divider(height: 24),
      const Text('Community guidelines', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Keep discussions respectful, credit original creators, avoid spoilers without warnings, and report content that breaks the rules.'),
    ])));
  }

  Widget _memberTile(Map<String, dynamic> member) {
    final name = member['profileName']?.toString() ?? member['display_name']?.toString() ?? 'Member';
    final accountId = member['id']?.toString() ?? '';
    final profileId = member['profileId']?.toString() ?? '';
    final avatar = member['avatar_url']?.toString();
    return Card(child: ListTile(
      leading: CircleAvatar(backgroundImage: avatar == null || avatar.isEmpty ? null : NetworkImage(avatar), child: avatar == null || avatar.isEmpty ? Text(_initial(name)) : null),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('@${member['username'] ?? ''}${member['role'] == 'owner' ? ' · Owner' : ''}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: accountId.isEmpty || profileId.isEmpty ? null : () => _openProfile(accountId, profileId, member),
    ));
  }

  Widget _postTile(Map<String, dynamic> post) {
    final author = post['author'] is Map ? Map<String, dynamic>.from(post['author'] as Map) : <String, dynamic>{};
    final name = author['profileName']?.toString() ?? author['display_name']?.toString() ?? post['author_profile_name']?.toString() ?? 'Member';
    final created = DateTime.tryParse((post['created_at'] ?? '').toString());
    final rawMedia = post['mediaReference'] ?? post['media_reference'];
    final media = rawMedia is Map ? Map<String, dynamic>.from(rawMedia) : <String, dynamic>{};
    return Card(child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openPost(post),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 18, child: Text(_initial(name))),
          const SizedBox(width: 9),
          Expanded(child: InkWell(
            onTap: () => _openProfile(author['id']?.toString() ?? '', author['profileId']?.toString() ?? '', author),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(created == null ? 'Community post' : _relativeDate(created), style: Theme.of(context).textTheme.bodySmall),
            ]),
          )),
          const Icon(Icons.open_in_new_rounded, size: 18),
        ]),
        const SizedBox(height: 10),
        Text(post['body']?.toString() ?? '', maxLines: 8, overflow: TextOverflow.ellipsis),
        if (media['imageUrl'] != null) ...[
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(media['imageUrl'].toString(), height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
        ],
        const SizedBox(height: 10),
        Row(children: [Text('${post['reactionCount'] ?? 0} reactions', style: Theme.of(context).textTheme.bodySmall), const SizedBox(width: 12), Text('${post['commentCount'] ?? 0} comments', style: Theme.of(context).textTheme.bodySmall), const Spacer(), const Text('Open discussion', style: TextStyle(fontWeight: FontWeight.w700))]),
      ])),
    ));
  }

  Future<void> _openPost(Map<String, dynamic> post) async {
    final id = post['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SocialPostDetailScreen(postId: id, initialPost: post)));
  }

  Future<void> _openProfile(String accountId, String profileId, Map<String, dynamic> member) async {
    if (accountId.isEmpty || profileId.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SocialProfileDetailScreen(targetAccountId: accountId, targetProfileId: profileId, initialProfile: member)));
  }

  String _initial(String value) => value.trim().isEmpty ? '?' : value.trim().substring(0, 1).toUpperCase();
  String _titleCase(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
  String _compactCount(int value) => value >= 1000000 ? '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M' : value >= 1000 ? '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K' : '$value';
  String _relativeDate(DateTime date) { final age = DateTime.now().difference(date.toLocal()); if (age.inMinutes < 1) return 'Just now'; if (age.inHours < 1) return '${age.inMinutes}m ago'; if (age.inDays < 1) return '${age.inHours}h ago'; if (age.inDays < 7) return '${age.inDays}d ago'; return '${date.day}/${date.month}/${date.year}'; }
}

/// One post and its discussion, with server-verified visibility and persisted
/// reactions/comments. This page is used from both community and feed cards.
class SocialPostDetailScreen extends StatefulWidget {
  const SocialPostDetailScreen({super.key, required this.postId, this.initialPost});
  final String postId;
  final Map<String, dynamic>? initialPost;

  @override
  State<SocialPostDetailScreen> createState() => _SocialPostDetailScreenState();
}

class _SocialPostDetailScreenState extends State<SocialPostDetailScreen> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final TextEditingController _commentController = TextEditingController();

  List<Map<String, dynamic>> _maps(dynamic value) => value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

  @override
  void initState() { super.initState(); _post = widget.initialPost == null ? null : Map<String, dynamic>.from(widget.initialPost!); _load(); }
  @override
  void dispose() { _commentController.dispose(); super.dispose(); }

  Future<void> _load() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) { if (mounted) setState(() { _loading = false; _error = 'Select a profile to view this post.'; }); return; }
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await AppController.instance.backendApi.getSocialPostDetail(profileId: profile.id, postId: widget.postId);
      if (!mounted) return;
      setState(() { _post = result['post'] is Map ? Map<String, dynamic>.from(result['post'] as Map) : null; _comments = _maps(result['comments']); _loading = false; });
    } catch (error) { if (!mounted) return; setState(() { _post = null; _comments = <Map<String, dynamic>>[]; _loading = false; _error = error.toString().replaceFirst('Exception: ', ''); }); }
  }

  Future<void> _react() async {
    final profile = AppController.instance.currentProfile;
    final post = _post;
    if (profile == null || post == null || _busy) return;
    final current = post['myReaction']?.toString();
    setState(() => _busy = true);
    try {
      await AppController.instance.backendApi.reactToSocialPost(profileId: profile.id, postId: widget.postId, reaction: current == '❤️' ? 'remove' : '❤️');
      await _load();
    } catch (error) { if (mounted) _notice(error.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _submitComment() async {
    final profile = AppController.instance.currentProfile;
    final body = _commentController.text.trim();
    if (profile == null || body.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await AppController.instance.backendApi.commentOnSocialPost(profileId: profile.id, postId: widget.postId, body: body);
      _commentController.clear();
      await _load();
    } catch (error) { if (mounted) _notice(error.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _notice(String message) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final author = post?['author'] is Map ? Map<String, dynamic>.from(post!['author'] as Map) : <String, dynamic>{};
    final authorName = author['profileName']?.toString() ?? author['display_name']?.toString() ?? post?['author_profile_name']?.toString() ?? 'Member';
    final rawMedia = post?['mediaReference'] ?? post?['media_reference'];
    final media = rawMedia is Map ? Map<String, dynamic>.from(rawMedia) : <String, dynamic>{};
    final liked = post?['myReaction']?.toString() == '❤️';
    return Scaffold(
      appBar: AppBar(title: const Text('Post'), actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 20), children: [
          if (_error != null) Card(child: ListTile(leading: const Icon(Icons.lock_outline_rounded), title: const Text('Post unavailable'), subtitle: Text(_error!))),
          if (post != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(child: Text(_initial(authorName))),
              const SizedBox(width: 10),
              Expanded(child: InkWell(
                onTap: () => _openAuthorProfile(author),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(authorName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(_relativeDate(DateTime.tryParse((post['created_at'] ?? '').toString())), style: Theme.of(context).textTheme.bodySmall),
                ]),
              )),
              if (post['communityPost'] == true) const Chip(label: Text('Community')),
            ]),
            const SizedBox(height: 12),
            Text(post['body']?.toString() ?? '', style: const TextStyle(fontSize: 16, height: 1.45)),
            if (media['type'] == 'review') ...[const SizedBox(height: 10), ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.rate_review_outlined), title: Text(media['mediaTitle']?.toString() ?? 'Media review'), subtitle: Text('${media['score'] ?? '—'}/10'))],
            if (media['imageUrl'] != null) ...[const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(media['imageUrl'].toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()))],
            const Divider(height: 26),
            Row(children: [Text('${post['reactionCount'] ?? 0} reactions'), const SizedBox(width: 16), Text('${post['commentCount'] ?? _comments.length} comments'), const Spacer(), IconButton(onPressed: _busy ? null : _react, icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? Colors.redAccent : null)), TextButton(onPressed: _busy ? null : _react, child: Text(liked ? 'Liked' : 'Like'))]),
          ]))),
          const SizedBox(height: 8),
          Text('Discussion (${_comments.length})', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (_comments.isEmpty) const _EmptyPanel(icon: Icons.mode_comment_outlined, title: 'Be the first to comment', subtitle: 'Keep it kind and on topic.'),
          ..._comments.map(_commentTile),
        ]),
      ),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: TextField(controller: _commentController, minLines: 1, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(hintText: 'Write a comment…', counterText: '', border: OutlineInputBorder()))), const SizedBox(width: 8), IconButton.filled(onPressed: _busy ? null : _submitComment, tooltip: 'Send comment', icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded))]))),
    );
  }

  void _openAuthorProfile(Map<String, dynamic> author) {
    final accountId = author['id']?.toString() ?? '';
    final profileId = author['profileId']?.toString() ?? '';
    if (accountId.isEmpty || profileId.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SocialProfileDetailScreen(
        targetAccountId: accountId,
        targetProfileId: profileId,
        initialProfile: author,
      ),
    ));
  }

  Widget _commentTile(Map<String, dynamic> comment) {
    final author = comment['author'] is Map ? Map<String, dynamic>.from(comment['author'] as Map) : <String, dynamic>{};
    final name = author['profileName']?.toString() ?? author['display_name']?.toString() ?? 'Member';
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 17, child: Text(_initial(name))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(onTap: () => _openAuthorProfile(author), child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
        Text(comment['body']?.toString() ?? '', style: const TextStyle(height: 1.35)),
        const SizedBox(height: 5),
        Text(_relativeDate(DateTime.tryParse((comment['created_at'] ?? '').toString())), style: Theme.of(context).textTheme.bodySmall),
      ])),
    ])));
  }

  String _initial(String name) => name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
  String _relativeDate(DateTime? date) { if (date == null) return 'Date unavailable'; final age = DateTime.now().difference(date.toLocal()); if (age.inMinutes < 1) return 'Just now'; if (age.inHours < 1) return '${age.inMinutes}m ago'; if (age.inDays < 1) return '${age.inHours}h ago'; if (age.inDays < 7) return '${age.inDays}d ago'; return '${date.day}/${date.month}/${date.year}'; }
}

/// A complete profile page for a friend, including their visible posts, friend
/// graph, followed stores/creators, and communities. Privacy is server-owned.
class SocialProfileDetailScreen extends StatefulWidget {
  const SocialProfileDetailScreen({super.key, required this.targetAccountId, required this.targetProfileId, this.initialProfile});
  final String targetAccountId;
  final String targetProfileId;
  final Map<String, dynamic>? initialProfile;

  @override
  State<SocialProfileDetailScreen> createState() => _SocialProfileDetailScreenState();
}

class _SocialProfileDetailScreenState extends State<SocialProfileDetailScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _socialData;
  List<Map<String, dynamic>> _posts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _friends = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _following = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _communities = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _section = 'Posts';

  List<Map<String, dynamic>> _maps(dynamic value) => value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final viewer = AppController.instance.currentProfile;
    if (viewer == null) { if (mounted) setState(() { _loading = false; _error = 'Select a profile to continue.'; }); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await AppController.instance.backendApi.getSocialProfile(profileId: viewer.id, targetAccountId: widget.targetAccountId, targetProfileId: widget.targetProfileId);
      if (!mounted) return;
      setState(() {
        _socialData = Map<String, dynamic>.from(result);
        _profile = result['profile'] is Map ? Map<String, dynamic>.from(result['profile'] as Map) : widget.initialProfile;
        _posts = _maps(result['posts']); _friends = _maps(result['friends']); _following = _maps(result['following']); _communities = _maps(result['communities']); _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
        // Clear any cached private lists after a refresh/auth failure.
        _socialData = null;
        _posts = <Map<String, dynamic>>[];
        _friends = <Map<String, dynamic>>[];
        _following = <Map<String, dynamic>>[];
        _communities = <Map<String, dynamic>>[];
      });
    }
  }

  Future<void> _relationshipAction() async {
    final viewer = AppController.instance.currentProfile;
    final profile = _profile;
    if (viewer == null || profile == null || _busy) return;
    final status = profile['relationshipStatus']?.toString() ??
        (_socialData == null ? 'unknown' : 'none');
    setState(() => _busy = true);
    try {
      if (status == 'request_received') {
        final friendshipId = profile['friendshipId']?.toString() ?? '';
        if (friendshipId.isEmpty) throw StateError('Friend request could not be identified.');
        await AppController.instance.backendApi.respondFriendRequest(profileId: viewer.id, friendshipId: friendshipId, action: 'accept');
      } else if (status == 'none') {
        final username = profile['username']?.toString().trim() ?? '';
        if (username.isEmpty) throw StateError('This user does not have a searchable username yet.');
        await AppController.instance.backendApi.sendFriendRequest(profileId: viewer.id, username: username, targetProfileId: widget.targetProfileId);
      } else {
        return;
      }
      await _load();
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', '')))); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile ?? widget.initialProfile ?? <String, dynamic>{};
    final name = profile['profileName']?.toString() ?? profile['profile_name']?.toString() ?? profile['display_name']?.toString() ?? 'Profile';
    final username = profile['username']?.toString() ?? '';
    final avatar = (profile['profileAvatarUrl'] ?? profile['avatar_url'])?.toString();
    // Fail closed until the server has evaluated the target profile's
    // privacy settings. The cached person row is only a display hint.
    final canView = _socialData != null && profile['canViewProfile'] != false;
    final canViewFriends = _socialData?['canViewFriendsList'] == true;
    final canViewFollowing = _socialData?['canViewFollowingList'] == true;
    final canViewCommunities = _socialData?['canViewCommunitiesList'] == true;
    final status = profile['relationshipStatus']?.toString() ??
        (_socialData == null ? 'unknown' : 'none');
    final friendCount = _socialData?['friendCount'];
    final followingCount = _socialData?['followingCount'];
    final communityCount = _socialData?['communityCount'];
    final postCount = _socialData?['postCount'];
    final sections = <String>[
      'Posts',
      if (canViewFriends) 'Friends',
      if (canViewFollowing) 'Following',
      if (canViewCommunities) 'Communities',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis), actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: _loading && _socialData == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 26), children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
          CircleAvatar(radius: 42, backgroundImage: avatar == null || avatar.isEmpty ? null : NetworkImage(avatar), child: avatar == null || avatar.isEmpty ? Text(_initial(name), style: const TextStyle(fontSize: 28)) : null),
          const SizedBox(height: 10), Text(name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          if (username.isNotEmpty) Text('@$username', style: Theme.of(context).textTheme.bodyMedium),
          if (profile['profileBio'] != null && profile['profileBio'].toString().trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(profile['profileBio'].toString(), textAlign: TextAlign.center)),
          const SizedBox(height: 15),
          if (canView) Row(children: [
            Expanded(child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _section = 'Posts'),
              child: _StatTile(icon: Icons.article_outlined, value: postCount == null ? 'Private' : '$postCount', label: 'Posts'),
            )),
            const SizedBox(width: 6),
            Expanded(child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: canViewFriends ? () => setState(() => _section = 'Friends') : null,
              child: _StatTile(icon: Icons.people_alt_outlined, value: friendCount == null ? 'Private' : '$friendCount', label: 'Friends'),
            )),
            const SizedBox(width: 6),
            Expanded(child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: canViewFollowing ? () => setState(() => _section = 'Following') : null,
              child: _StatTile(icon: Icons.storefront_outlined, value: followingCount == null ? 'Private' : '$followingCount', label: 'Following'),
            )),
            const SizedBox(width: 6),
            Expanded(child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: canViewCommunities ? () => setState(() => _section = 'Communities') : null,
              child: _StatTile(icon: Icons.groups_outlined, value: communityCount == null ? 'Private' : '$communityCount', label: 'Communities'),
            )),
          ]),
          const SizedBox(height: 14),
          if (status == 'self') const Chip(label: Text('Your profile'))
          else if (status == 'friends') const SizedBox(width: double.infinity, child: Chip(avatar: Icon(Icons.check_circle_rounded, size: 18), label: Text('Friends ✓')))
          else if (status == 'request_sent') const SizedBox(width: double.infinity, child: Chip(avatar: Icon(Icons.schedule_rounded, size: 18), label: Text('Request pending')))
          else SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy || _socialData == null ? null : _relationshipAction, icon: Icon(status == 'request_received' ? Icons.person_add_alt_1_rounded : Icons.person_add_alt), label: Text(status == 'request_received' ? 'Accept friend request' : status == 'unknown' ? 'Friend status unavailable' : 'Add Friend'))),
        ]))),
        if (_error != null) Card(child: ListTile(leading: const Icon(Icons.info_outline_rounded), title: const Text('Profile could not be refreshed'), subtitle: Text(_error!), trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)))),
        if (!canView) _EmptyPanel(
          icon: _socialData == null ? Icons.cloud_off_rounded : Icons.lock_outline_rounded,
          title: _socialData == null ? 'Profile details unavailable' : 'This profile is private',
          subtitle: _socialData == null
              ? 'We could not verify this profile’s privacy settings. Refresh to try again.'
              : 'You can see more when the owner allows it or accepts your friend request.',
        ),
        if (canView) ...[
          const SizedBox(height: 8),
          SegmentedButton<String>(segments: sections.map((section) => ButtonSegment(value: section, label: Text(section), icon: Icon(switch (section) { 'Posts' => Icons.article_outlined, 'Friends' => Icons.people_outline_rounded, 'Following' => Icons.storefront_outlined, _ => Icons.groups_outlined }))).toList(), selected: {_section}, onSelectionChanged: (selection) => setState(() => _section = selection.first)),
          const SizedBox(height: 12),
          if (_section == 'Posts') ..._posts.map(_postTile)
          else if (_section == 'Friends') ..._friends.map(_friendTile)
          else if (_section == 'Following') ..._following.map(_followingTile)
          else ..._communities.map(_communityTile),
          if ((_section == 'Posts' && _posts.isEmpty) || (_section == 'Friends' && _friends.isEmpty) || (_section == 'Following' && _following.isEmpty) || (_section == 'Communities' && _communities.isEmpty))
            _EmptyPanel(icon: switch (_section) { 'Posts' => Icons.article_outlined, 'Friends' => Icons.people_outline_rounded, 'Following' => Icons.storefront_outlined, _ => Icons.groups_outlined }, title: 'Nothing to show yet', subtitle: 'This section is empty or has no visible items.'),
        ],
      ])),
    );
  }

  Widget _postTile(Map<String, dynamic> post) {
    final body = post['body']?.toString() ?? '';
    final created = DateTime.tryParse((post['created_at'] ?? '').toString());
    return Card(child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SocialPostDetailScreen(postId: post['id']?.toString() ?? '', initialPost: post))), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(body, maxLines: 7, overflow: TextOverflow.ellipsis), const SizedBox(height: 8), Row(children: [Text(created == null ? 'Post' : _relativeDate(created), style: Theme.of(context).textTheme.bodySmall), const Spacer(), Text('${post['commentCount'] ?? 0} comments', style: Theme.of(context).textTheme.bodySmall), const Icon(Icons.chevron_right_rounded)])]))));
  }

  Widget _friendTile(Map<String, dynamic> friend) {
    final name = friend['profileName']?.toString() ?? friend['display_name']?.toString() ?? 'Friend';
    final accountId = friend['id']?.toString() ?? '';
    final profileId = friend['profileId']?.toString() ?? '';
    final avatar = friend['avatar_url']?.toString();
    return Card(child: ListTile(leading: CircleAvatar(backgroundImage: avatar == null || avatar.isEmpty ? null : NetworkImage(avatar), child: avatar == null || avatar.isEmpty ? Text(_initial(name)) : null), title: Text(name), subtitle: Text('@${friend['username'] ?? ''}'), trailing: const Icon(Icons.chevron_right_rounded), onTap: accountId.isEmpty || profileId.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SocialProfileDetailScreen(targetAccountId: accountId, targetProfileId: profileId, initialProfile: friend)))));
  }

  Widget _followingTile(Map<String, dynamic> item) {
    final name = item['target_name']?.toString() ?? 'Followed account';
    final subtitle = item['target_subtitle']?.toString() ?? item['target_type']?.toString() ?? 'Following';
    final avatar = item['target_avatar_url']?.toString();
    return Card(child: ListTile(leading: CircleAvatar(backgroundImage: avatar == null || avatar.isEmpty ? null : NetworkImage(avatar), child: avatar == null || avatar.isEmpty ? const Icon(Icons.storefront_outlined) : null), title: Text(name), subtitle: Text(subtitle), trailing: const Icon(Icons.verified_outlined)));
  }

  Widget _communityTile(Map<String, dynamic> community) {
    final name = community['name']?.toString() ?? 'Community';
    final id = community['id']?.toString() ?? '';
    return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.groups_rounded)), title: Text(name), subtitle: Text('${community['memberCount'] ?? '—'} members · ${community['postCount'] ?? '—'} posts'), trailing: const Icon(Icons.chevron_right_rounded), onTap: id.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SocialCommunityDetailScreen(community: community)))));
  }

  String _initial(String name) => name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
  String _relativeDate(DateTime date) { final age = DateTime.now().difference(date.toLocal()); if (age.inMinutes < 1) return 'Just now'; if (age.inHours < 1) return '${age.inMinutes}m ago'; if (age.inDays < 1) return '${age.inHours}h ago'; if (age.inDays < 7) return '${age.inDays}d ago'; return '${date.day}/${date.month}/${date.year}'; }
}

/// A convenient route from the current profile to its full Friends, Following,
/// and Communities lists. Follows intentionally remain separate from friends.
class SocialConnectionsScreen extends StatefulWidget {
  const SocialConnectionsScreen({super.key, this.initialSection = 'Friends'});
  final String initialSection;

  @override
  State<SocialConnectionsScreen> createState() => _SocialConnectionsScreenState();
}

class _SocialConnectionsScreenState extends State<SocialConnectionsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String _section = 'Friends';
  String _query = '';

  List<Map<String, dynamic>> _maps(String key) { final value = _data?[key]; return value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[]; }

  @override
  void initState() { super.initState(); _section = widget.initialSection; _load(); }
  Future<void> _load() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) { if (mounted) setState(() { _loading = false; _error = 'Select a profile to continue.'; }); return; }
    setState(() { _loading = true; _error = null; });
    try { final data = await AppController.instance.backendApi.getSocialCenter(profileId: profile.id); if (mounted) setState(() { _data = data; _loading = false; }); }
    catch (error) { if (mounted) setState(() { _loading = false; _error = error.toString().replaceFirst('Exception: ', ''); }); }
  }

  @override
  Widget build(BuildContext context) {
    final friends = _maps('friends');
    final following = _maps('following');
    final communities = _maps('communities');
    final suggestions = _maps('suggestions').where((x) =>
      '${x['profileName'] ?? x['display_name'] ?? ''} ${x['username'] ?? ''}'.toLowerCase().contains(_query.toLowerCase())
    ).toList();
    List<Map<String, dynamic>> visible;
    if (_section == 'Friends') {
      visible = friends.where((x) => '${x['display_name'] ?? ''} ${x['username'] ?? ''}'.toLowerCase().contains(_query.toLowerCase())).toList();
    } else if (_section == 'Following') {
      visible = following.where((x) => '${x['target_name'] ?? ''} ${x['target_subtitle'] ?? ''}'.toLowerCase().contains(_query.toLowerCase())).toList();
    } else {
      visible = communities.where((x) => '${x['name'] ?? ''} ${x['description'] ?? ''}'.toLowerCase().contains(_query.toLowerCase())).toList();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Your connections'), actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))]),
      body: _loading && _data == null ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: _StatTile(icon: Icons.people_alt_outlined, value: '${_data?['friendCount'] ?? friends.length}', label: 'Friends')),
          const SizedBox(width: 8),
          Expanded(child: _StatTile(icon: Icons.storefront_outlined, value: '${_data?['followingCount'] ?? following.length}', label: 'Following')),
          const SizedBox(width: 8),
          Expanded(child: _StatTile(icon: Icons.groups_outlined, value: '${_data?['communityCount'] ?? communities.where((c) => c['joined'] == true).length}', label: 'Communities')),
        ]),
        const SizedBox(height: 14),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'Friends', label: Text('Friends')), ButtonSegment(value: 'Following', label: Text('Following')), ButtonSegment(value: 'Communities', label: Text('Communities'))], selected: {_section}, onSelectionChanged: (value) => setState(() => _section = value.first)),
        const SizedBox(height: 12),
        TextField(onChanged: (value) => setState(() => _query = value), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Search ${_section.toLowerCase()}', border: const OutlineInputBorder())),
        if (_error != null) Card(child: ListTile(leading: const Icon(Icons.cloud_off_rounded), title: const Text('Could not refresh connections'), subtitle: Text(_error!))),
        const SizedBox(height: 8),
        if (_section == 'Friends') ...[
          if (visible.isEmpty) _EmptyPanel(icon: Icons.people_outline_rounded, title: 'No friends found', subtitle: 'Try another search or discover people to connect with.'),
          ...visible.map(_friendTile),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('People you may know', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ...suggestions.map(_suggestionTile),
          ],
        ] else if (visible.isEmpty)
          _EmptyPanel(icon: _section == 'Following' ? Icons.storefront_outlined : Icons.groups_outlined, title: 'No ${_section.toLowerCase()} found', subtitle: 'Try another search or refresh the list.')
        else if (_section == 'Following') ...visible.map(_followingTile)
        else ...visible.map(_communityTile),
      ])),
    );
  }

  Widget _friendTile(Map<String, dynamic> friend) {
    final name = friend['display_name']?.toString() ?? 'Friend';
    final avatar = friend['avatar_url']?.toString();
    final accountId = friend['id']?.toString() ?? '';
    final profileId = friend['profileId']?.toString() ?? '';
    return Card(child: ListTile(leading: CircleAvatar(backgroundImage: avatar == null || avatar.isEmpty ? null : NetworkImage(avatar), child: avatar == null || avatar.isEmpty ? Text(_initial(name)) : null), title: Text(name), subtitle: Text('@${friend['username'] ?? ''}'), trailing: const Chip(label: Text('Friends ✓')), onTap: accountId.isEmpty || profileId.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SocialProfileDetailScreen(targetAccountId: accountId, targetProfileId: profileId, initialProfile: friend)))));
  }
  Widget _suggestionTile(Map<String, dynamic> person) {
    final name = person['profileName']?.toString() ?? person['display_name']?.toString() ?? 'Person';
    final avatar = person['avatar_url']?.toString();
    final username = person['username']?.toString() ?? '';
    final personProfileId = person['profileId']?.toString() ?? '';
    return Card(child: ListTile(
      leading: CircleAvatar(backgroundImage: avatar == null || avatar.isEmpty ? null : NetworkImage(avatar), child: avatar == null || avatar.isEmpty ? Text(_initial(name)) : null),
      title: Text(name),
      subtitle: Text('@$username · Suggested for you'),
      trailing: FilledButton.tonalIcon(onPressed: username.isEmpty || personProfileId.isEmpty ? null : () => _addFriend(username, personProfileId), icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('Add Friend')),
    ));
  }

  Future<void> _addFriend(String username, String personProfileId) async {
    final profile = AppController.instance.currentProfile;
    if (profile == null || _loading) return;
    setState(() => _loading = true);
    try {
      await AppController.instance.backendApi.sendFriendRequest(profileId: profile.id, username: username, targetProfileId: personProfileId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Friend request sent to @$username.')));
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _followingTile(Map<String, dynamic> item) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)), title: Text(item['target_name']?.toString() ?? 'Followed account'), subtitle: Text('${item['target_type'] ?? 'account'}${item['target_subtitle'] == null ? '' : ' · ${item['target_subtitle']}'}')));
  Widget _communityTile(Map<String, dynamic> item) { final id = item['id']?.toString() ?? ''; return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.groups_rounded)), title: Text(item['name']?.toString() ?? 'Community'), subtitle: Text('${item['memberCount'] ?? 0} members · ${item['postCount'] ?? 0} posts'), trailing: item['joined'] == true ? const Chip(label: Text('Joined')) : const Text('Explore'), onTap: id.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SocialCommunityDetailScreen(community: item))))); }
  String _initial(String value) => value.trim().isEmpty ? '?' : value.trim().substring(0, 1).toUpperCase();
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5), child: Column(children: [Icon(icon, size: 19), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)])));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 19), const SizedBox(width: 10), SizedBox(width: 90, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), Expanded(child: Text(value))]));
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16), textAlign: TextAlign.center), const SizedBox(height: 5), Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: .72)), textAlign: TextAlign.center)])));
}
