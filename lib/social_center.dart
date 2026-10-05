import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'app_core.dart';
import 'music.dart';
import 'shop.dart';
import 'social_video_editor.dart';
import 'social_sharing.dart';
import 'social_reels.dart';

class _SocialPostDraft {
  const _SocialPostDraft({required this.body, this.photo});

  final String body;
  final XFile? photo;
}

String _socialInitial(String value) {
  final clean = value.trim();
  return clean.isEmpty ? '?' : clean.substring(0, 1).toUpperCase();
}

String _presenceState(Map<String, dynamic> member) {
  final status = member['presenceStatus']?.toString() ?? 'away';
  if (status == 'busy' || status == 'away') return status;
  final lastSeen = DateTime.tryParse(member['lastSeenAt']?.toString() ?? '');
  if (lastSeen == null ||
      DateTime.now().toUtc().difference(lastSeen.toUtc()) > const Duration(minutes: 5)) {
    return 'away';
  }
  return 'active';
}

Color _presenceGlowColor(Map<String, dynamic> member) {
  switch (_presenceState(member)) {
    case 'active':
      return Colors.greenAccent;
    case 'busy':
      return Colors.redAccent;
    default:
      return Colors.grey;
  }
}

Widget _presenceAvatar(
  Map<String, dynamic> member,
  String name, {
  double radius = 20,
}) {
  final glow = _presenceGlowColor(member);
  final avatarUrl = member['avatar_url']?.toString();
  return Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: glow.withValues(alpha: .8),
          blurRadius: 11,
          spreadRadius: 2,
        ),
      ],
    ),
    child: CircleAvatar(
      radius: radius,
      backgroundImage: avatarUrl == null || avatarUrl.isEmpty
          ? null
          : NetworkImage(avatarUrl),
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(_socialInitial(name))
          : null,
    ),
  );
}

Widget _memberNameLabel(Map<String, dynamic> member) {
  final name = member['display_name']?.toString() ??
      member['username']?.toString() ??
      'Member';
  final nickname = member['nickname']?.toString().trim() ?? '';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      if (nickname.isNotEmpty)
        Text(
          nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
    ],
  );
}

class _SocialReviewDraft {
  const _SocialReviewDraft({
    required this.media,
    required this.score,
    required this.body,
    required this.shareToPage,
    required this.communityIds,
  });

  final MediaItem media;
  final double score;
  final String body;
  final bool shareToPage;
  final List<String> communityIds;
}

/// Social center inspired by modern chat/feed products:
/// - stories at the top of the feed
/// - friend/community feed with lightweight reactions and comments
/// - message inbox with a desktop split-pane layout
/// - friend requests and community discovery
///
/// Social content contains references/metadata only. Media playback remains
/// owned by the existing home-server/media architecture.
class SocialCenterScreen extends StatefulWidget {
  const SocialCenterScreen({super.key});

  @override
  State<SocialCenterScreen> createState() => _SocialCenterScreenState();
}

class _SocialCenterScreenState extends State<SocialCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late List<String> _visibleTabSections;
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _visibleTabSections = _configuredTabSections;
    _tabs = TabController(length: _visibleTabSections.length, vsync: this);
    PageContentCustomizationStore.revision
        .addListener(_onPageCustomizationChanged);
    _load();
  }

  List<String> get _configuredTabSections {
    final sections =
        PageContentCustomizationStore.settingsFor('friends').visibleSections;
    return sections.isEmpty ? const ['feed'] : sections;
  }

  List<String> get _tabSections => _visibleTabSections;

  void _onPageCustomizationChanged() {
    if (!mounted) return;
    final oldSections = _visibleTabSections;
    final activeIndex = _tabs.index.clamp(0, oldSections.length - 1).toInt();
    final activeSection = oldSections[activeIndex];
    final sections = _configuredTabSections;
    final nextIndex =
        sections.indexOf(activeSection).clamp(0, sections.length - 1).toInt();
    final previous = _tabs;
    setState(() {
      _visibleTabSections = sections;
      _tabs = TabController(
        length: sections.length,
        vsync: this,
        initialIndex: nextIndex,
      );
    });
    previous.dispose();
  }

  @override
  void dispose() {
    PageContentCustomizationStore.revision
        .removeListener(_onPageCustomizationChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    if (profile == null || !controller.backendApi.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Select a profile and sign in to use social features.';
      });
      return;
    }

    try {
      final data =
          await controller.backendApi.getSocialCenter(profileId: profile.id);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> _list(String key) =>
      (_data?[key] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        _header(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: const Text('Social services unavailable'),
                subtitle: Text(_error!),
                trailing: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _tabSections.map(_pageForTab).toList(),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    final stories = _list('stories');
    final conversations = _list('conversations');
    final requests = _list('requests');

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, size: 30),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Friends & Community',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Watch together, talk about media, and share what you are enjoying.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
              FilledButton.icon(
                onPressed: _newMessage,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Message'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: _tabSections.map((section) {
              return switch (section) {
                'feed' => const Tab(
                    text: 'Feed',
                    icon: Icon(Icons.dynamic_feed_rounded),
                  ),
                'reels' => const Tab(
                    text: 'Reels',
                    icon: Icon(Icons.play_circle_outline_rounded),
                  ),
                'messages' => Tab(
                    text: conversations.isEmpty
                        ? 'Messages'
                        : 'Messages (${conversations.length})',
                    icon: const Icon(Icons.forum_rounded),
                  ),
                'friends' => Tab(
                    text: requests.isEmpty
                        ? 'Friends'
                        : 'Friends (${requests.length})',
                    icon: const Icon(Icons.people_outline_rounded),
                  ),
                'communities' => const Tab(
                    text: 'Communities',
                    icon: Icon(Icons.groups_rounded),
                  ),
                'my-page' => const Tab(
                    text: 'My Page',
                    icon: Icon(Icons.account_circle_outlined),
                  ),
                _ => const Tab(text: 'Social'),
              };
            }).toList(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _storyComposer(),
                ...stories.map(_storyBubble),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageForTab(String section) => switch (section) {
        'feed' => _feedTab(),
        'reels' => SocialReelsScreen(
              posts: <Map<String, dynamic>>[
                ..._list('posts'),
                ..._list('communityPosts'),
              ],
              onRefresh: _load,
            ),
        'messages' => _messagesTab(),
        'friends' => _friendsTab(),
        'communities' => _communitiesTab(),
        'my-page' => _myPageTab(),
        _ => const SizedBox.shrink(),
      };

  Widget _feedTab() {
    final posts = <Map<String, dynamic>>[
      ..._list('posts'),
      ..._list('communityPosts'),
    ]
      ..sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          _composerCard(profile.id),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.dynamic_feed_outlined),
                title: Text('Your social feed is quiet'),
                subtitle: Text(
                  'Add friends, join a community, or share a story to get started.',
                ),
              ),
            ),
          ...posts.map(_postCard),
        ],
      ),
    );
  }

  Widget _myPageTab() {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();
    final posts = _list('posts')
        .where(
          (post) => post['isMine'] == true && post['visibility'] == 'friends',
        )
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: profile.avatarUrl == null ||
                                profile.avatarUrl!.trim().isEmpty
                            ? null
                            : NetworkImage(profile.avatarUrl!),
                        child: profile.avatarUrl == null ||
                                profile.avatarUrl!.trim().isEmpty
                            ? Text(_initial(profile.name))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Friends-only profile • ${posts.length} posts',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit profile',
                        onPressed: _busy ? null : _editMyProfile,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Your page combines your social posts, media reviews, shorts, and community shares.',
                    style: TextStyle(color: Colors.white60, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _composePagePost,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Post or photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _composeReview,
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Write a review'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _createShort(),
                        icon: const Icon(Icons.movie_creation_outlined),
                        label: const Text('Create Short'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: Text('Your friends-only page is ready'),
                subtitle: Text(
                  'Share a post, a photo, or a media review to get started.',
                ),
              ),
            ),
          ...posts.map(_postCard),
        ],
      ),
    );
  }

  Future<void> _editMyProfile() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final nameController = TextEditingController(text: profile.name);
    final avatarController = TextEditingController(text: profile.avatarUrl ?? '');
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Profile name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            TextField(
              controller: avatarController,
              maxLength: 2048,
              decoration: const InputDecoration(
                labelText: 'Avatar URL (optional)',
                hintText: 'https://…',
                prefixIcon: Icon(Icons.image_outlined),
              ),
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
              (nameController.text.trim(),
                  avatarController.text.trim().isEmpty
                      ? null
                      : avatarController.text.trim()),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    avatarController.dispose();
    if (result == null || result.$1.isEmpty) return;
    await _act(() async {
      final response = await AppController.instance.backendApi.updateProfile(
        profileId: profile.id,
        name: result.$1,
        avatarUrl: result.$2,
      );
      final updated = response['profile'];
      if (updated is Map) {
        final values = Map<String, dynamic>.from(updated);
        profile.name = values['name']?.toString() ?? result.$1;
        profile.avatarUrl = values['avatarUrl']?.toString();
      } else {
        profile.name = result.$1;
        profile.avatarUrl = result.$2;
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _composePagePost() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final controller = TextEditingController();
    XFile? photo;
    final draft = await showDialog<_SocialPostDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Post to My Page'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                maxLength: 4000,
                decoration: const InputDecoration(
                  hintText: 'Share with your friends',
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1600,
                      imageQuality: 85,
                    );
                    if (picked != null) setDialogState(() => photo = picked);
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(photo?.name ?? 'Add a photo'),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Photos are private and shown only to authorized friends.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
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
                _SocialPostDraft(body: controller.text.trim(), photo: photo),
              ),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (draft == null) return;
    if (draft.body.isEmpty) {
      _showMessage('Add a caption before publishing your photo or post.');
      return;
    }

    await _act(() async {
      Map<String, dynamic>? mediaReference;
      if (draft.photo != null) {
        final extension = draft.photo!.name.split('.').last.toLowerCase();
        final contentType = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'jpg' || 'jpeg' => 'image/jpeg',
          _ => throw const FormatException(
              'Choose a JPEG, PNG, or WebP photo.',
            ),
        };
        final bytes = await draft.photo!.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          throw const FormatException('Photos must be 5 MB or smaller.');
        }
        final path =
            await AppController.instance.backendApi.uploadSocialAttachment(
          profileId: profile.id,
          bytes: bytes,
          contentType: contentType,
        );
        mediaReference = {'type': 'photo', 'photoPath': path};
      }
      await AppController.instance.backendApi.createSocialPost(
        profileId: profile.id,
        body: draft.body,
        mediaReference: mediaReference,
      );
    });
  }

  Future<void> _composeReview() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final media = AppController.instance.library;
    if (media.isEmpty) {
      _showMessage('Add media to your library before writing a review.');
      return;
    }
    final communities = _list('communities')
        .where((community) => community['joined'] == true)
        .toList();
    final draft = await _reviewDraftDialog(media, communities);
    if (draft == null || draft.body.trim().isEmpty) return;

    await _act(() async {
      final label = _reviewLabel(draft.score);
      final response = await AppController.instance.backendApi.submitReview(
        mediaId: draft.media.id,
        profileId: profile.id,
        score: draft.score,
        label: label,
        text: draft.body.trim(),
        globalUsername: '',
      );
      final review = response['review'] is Map
          ? Map<String, dynamic>.from(response['review'] as Map)
          : <String, dynamic>{};
      final reference = <String, dynamic>{
        'type': 'review',
        'reviewId': review['id']?.toString() ?? '',
        'mediaId': draft.media.id,
        'mediaTitle': draft.media.title,
        'score': draft.score,
        'label': label,
      };
      if (draft.shareToPage) {
        await AppController.instance.backendApi.createSocialPost(
          profileId: profile.id,
          body: draft.body.trim(),
          mediaReference: reference,
        );
      }
      if (draft.communityIds.isNotEmpty) {
        await AppController.instance.backendApi.createSocialPost(
          profileId: profile.id,
          body: draft.body.trim(),
          communityIds: draft.communityIds,
          mediaReference: reference,
        );
      }
    });
  }

  Future<_SocialReviewDraft?> _reviewDraftDialog(
    List<MediaItem> media,
    List<Map<String, dynamic>> communities,
  ) async {
    final controller = TextEditingController();
    var selectedMediaId = media.first.id;
    var score = 8.0;
    var shareToPage = true;
    final selectedCommunities = <String>{};
    final result = await showDialog<_SocialReviewDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Write a media review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedMediaId,
                decoration: const InputDecoration(labelText: 'Media'),
                items: media
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          item.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedMediaId = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              Text('Score: ${score.toStringAsFixed(1)}/10'),
              Slider(
                min: 0,
                max: 10,
                divisions: 20,
                value: score,
                label: score.toStringAsFixed(1),
                onChanged: (value) => setDialogState(() => score = value),
              ),
              TextField(
                controller: controller,
                maxLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Your review',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Share to My Page'),
                subtitle: const Text('Visible to your accepted friends'),
                value: shareToPage,
                onChanged: (value) => setDialogState(() => shareToPage = value),
              ),
              if (communities.isNotEmpty) ...[
                const Text(
                  'Also share to communities',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final community in communities)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(community['name']?.toString() ?? 'Community'),
                    value: selectedCommunities
                        .contains(community['id'].toString()),
                    onChanged: (selected) {
                      setDialogState(() {
                        final id = community['id'].toString();
                        if (selected == true) {
                          selectedCommunities.add(id);
                        } else {
                          selectedCommunities.remove(id);
                        }
                      });
                    },
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final selected = media.firstWhere(
                  (item) => item.id == selectedMediaId,
                );
                Navigator.pop(
                  dialogContext,
                  _SocialReviewDraft(
                    media: selected,
                    score: score,
                    body: controller.text,
                    shareToPage: shareToPage,
                    communityIds: selectedCommunities.toList(),
                  ),
                );
              },
              child: const Text('Save review'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result != null && !result.shareToPage && result.communityIds.isEmpty) {
      _showMessage('Choose My Page, at least one community, or both to share.');
      return null;
    }
    return result;
  }

  String _reviewLabel(double score) => switch (score) {
        >= 8.5 => 'Excellent',
        >= 7 => 'Good',
        >= 5 => 'Mixed',
        _ => 'Poor',
      };

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _composerCard(String profileId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person_rounded)),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _composePost(profileId),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'What are you watching, listening to, or collecting?',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Story',
              onPressed: _composeStory,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
            IconButton(
              tooltip: 'Create short video',
              onPressed: () => _createShort(),
              icon: const Icon(Icons.video_call_outlined),
            ),
            IconButton(
              tooltip: 'Create video story',
              onPressed: () => _createShort(asStory: true),
              icon: const Icon(Icons.add_a_photo_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final author = post['author'] is Map
        ? Map<String, dynamic>.from(post['author'] as Map)
        : <String, dynamic>{};
    final displayName = author['display_name']?.toString() ??
        post['author_profile_name']?.toString() ??
        'Friend';
    final username = author['username']?.toString();
    final reaction = post['myReaction']?.toString();
    final isCommunity = post['communityPost'] == true;
    final mediaReference = post['mediaReference'] is Map
        ? Map<String, dynamic>.from(post['mediaReference'] as Map)
        : post['media_reference'] is Map
            ? Map<String, dynamic>.from(post['media_reference'] as Map)
            : <String, dynamic>{};

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(_initial(displayName))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        [
                          if (username != null && username.isNotEmpty)
                            '@$username',
                          if (isCommunity) 'Community post',
                        ].join('  ·  '),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post['body']?.toString() ?? '',
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            if (mediaReference['type'] == 'review') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.rate_review_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${mediaReference['mediaTitle'] ?? 'Media'} · ${mediaReference['score'] ?? ''}/10',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (mediaReference['type'] == 'product') ...[
              const SizedBox(height: 10),
              _socialProductCard(mediaReference),
            ],
            if (mediaReference['imageUrl'] != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mediaReference['imageUrl'].toString(),
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
            if (mediaReference['type'] == 'video') ...[
              const SizedBox(height: 10),
              Text(
                'Related to ${mediaReference['relatedMediaTitle'] ?? 'library media'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (mediaReference['coverUrl'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: InkWell(
                    onTap: () {
                      final videoUrl = mediaReference['videoUrl']?.toString();
                      if (videoUrl != null) _playSocialVideo(videoUrl);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                              mediaReference['coverUrl'].toString(),
                              width: double.infinity,
                              height: 260,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(height: 160),
                          ),
                        ),
                        const CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.play_arrow_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${post['reactionCount'] ?? 0} reactions',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Text(
                  '${post['commentCount'] ?? 0} comments',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _reactToPost(
                      post['id']?.toString() ?? '',
                      reaction == '❤️' ? 'remove' : '❤️',
                    ),
                    icon: Icon(
                      reaction == '❤️'
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: reaction == '❤️' ? Colors.redAccent : null,
                    ),
                    label: const Text('Like'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _commentPost(post['id']?.toString() ?? ''),
                    icon: const Icon(Icons.mode_comment_outlined),
                    label: const Text('Comment'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _sharePost(post),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialProductCard(Map<String, dynamic> reference) {
    final productId = reference['productId']?.toString();
    final product = productId == null
        ? null
        : ShopCatalog.instance.productById(productId);
    final title = product?.name ?? reference['title']?.toString() ?? 'Product';
    final description = product?.description ??
        reference['description']?.toString() ??
        'Open the product page for details and purchasing.';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: product == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopProductDetailsScreen(product: product),
                  ),
                ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: product?.imageUrls.isNotEmpty == true
                  ? Image.network(product!.imageUrls.first, fit: BoxFit.cover)
                  : const Center(child: Icon(Icons.shopping_bag_outlined)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PRODUCT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product == null
                          ? description
                          : '${product.price.toStringAsFixed(2)} ${product.currency} • ${product.inventoryQuantity} in stock',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messagesTab() {
    final conversations = _list('conversations');
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.sizeOf(context).width >= 850
              ? 330
              : MediaQuery.sizeOf(context).width * .40,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white10)),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Messages',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Create group chat',
                        onPressed: _newGroupMessage,
                        icon: const Icon(Icons.group_add_outlined),
                      ),
                      IconButton(
                        tooltip: 'New direct message',
                        onPressed: _newMessage,
                        icon: const Icon(Icons.edit_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search messages',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: .04),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (conversations.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.forum_outlined),
                    title: Text('No conversations yet'),
                    subtitle: Text('Start one with a friend.'),
                  ),
                ...conversations.map(_conversationTile),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_rounded, size: 58, color: Colors.white24),
                SizedBox(height: 12),
                Text(
                  'Select a conversation',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Messages stay profile-scoped and never grant media playback access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _conversationTile(Map<String, dynamic> conversation) {
    final members = (conversation['members'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final other = members.firstWhere(
      (item) => item['isSelf'] != true,
      orElse: () => members.isNotEmpty ? members.first : <String, dynamic>{},
    );
    final name = conversation['kind'] == 'group'
        ? (conversation['title']?.toString().trim().isNotEmpty == true
            ? conversation['title'].toString()
            : 'Group chat')
        : other['display_name']?.toString() ??
            other['username']?.toString() ??
            'Conversation';
    final last = conversation['lastMessage'] is Map
        ? Map<String, dynamic>.from(conversation['lastMessage'] as Map)
        : <String, dynamic>{};
    final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;

    return ListTile(
      onTap: () => _openConversation(conversation['id']?.toString() ?? ''),
      leading: _presenceAvatar(other, name, radius: 23),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        last['body']?.toString() ?? 'Start a conversation',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54),
      ),
      trailing: unread > 0
          ? CircleAvatar(
              radius: 11,
              child: Text(
                '$unread',
                style: const TextStyle(fontSize: 10),
              ),
            )
          : null,
    );
  }

  Widget _friendsTab() {
    final friends = _list('friends');
    final requests = _list('requests');
    final suggestions = _list('suggestions');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your people',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                onPressed: _addFriend,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add Friend'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (friends.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.person_search_rounded),
                title: Text('No friends yet'),
                subtitle: Text('Use a unique @username to connect.'),
              ),
            ),
          ...friends.map(
            (friend) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    _initial(
                      friend['display_name']?.toString() ??
                          friend['username']?.toString() ??
                          'F',
                    ),
                  ),
                ),
                title: Text(
                  friend['display_name']?.toString() ?? 'Friend',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  friend['username'] == null
                      ? 'Friend'
                      : '@${friend['username']}',
                ),
                trailing: IconButton(
                  tooltip: 'Message',
                  onPressed: () => _startMessageFor(
                    friend['username']?.toString() ?? '',
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
            ),
          ),
          if (requests.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Friend requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...requests.map(_requestCard),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'People you may know',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            ...suggestions.map(_suggestionCard),
          ],
        ],
      ),
    );
  }

  Widget _communitiesTab() {
    final communities = _list('communities');
    final posts = _list('communityPosts');
    final stories = _list('communityStories');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Communities',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                onPressed: _createCommunity,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...communities.map(
            (community) {
              final communityId = community['id'].toString();
              final isJoined = community['joined'] == true;
              final communityPosts = posts.where((post) {
                final ids = (post['communityIds'] as List? ?? const [])
                    .map((id) => id.toString());
                return post['community_id']?.toString() == communityId ||
                    ids.contains(communityId);
              });
              final communityStories = stories.where(
                (story) => story['community_id']?.toString() == communityId,
              );
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.groups_rounded),
                        ),
                        title: Text(
                          community['name']?.toString() ?? 'Community',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          community['description']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isJoined
                            ? const Chip(label: Text('Joined'))
                            : FilledButton(
                                onPressed: () => _act(
                                  () => AppController.instance.backendApi
                                      .joinSocialCommunity(
                                    profileId: AppController
                                        .instance.currentProfile!.id,
                                    communityId: communityId,
                                  ),
                                ),
                                child: const Text('Join'),
                              ),
                      ),
                      if (isJoined) ...[
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => _composeCommunityPost(
                                communityId,
                              ),
                              icon: const Icon(Icons.post_add_rounded),
                              label: const Text('Post'),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _composeStory(communityId: communityId),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Story'),
                            ),
                          ],
                        ),
                        if (communityStories.isNotEmpty) ...[
                          const Text(
                            'Stories',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 92,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children:
                                  communityStories.map(_storyBubble).toList(),
                            ),
                          ),
                        ],
                        if (communityPosts.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Community posts',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          ...communityPosts.map(_postCard),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final sender = request['sender'] is Map
        ? Map<String, dynamic>.from(request['sender'] as Map)
        : <String, dynamic>{};
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_add_alt_1_rounded),
        title: Text(sender['display_name']?.toString() ?? 'Someone'),
        subtitle: Text('@${sender['username'] ?? ''}'),
        trailing: Wrap(
          children: [
            TextButton(
              onPressed: () => _act(
                () => AppController.instance.backendApi.respondFriendRequest(
                  profileId: profile.id,
                  friendshipId: request['id'].toString(),
                  action: 'decline',
                ),
              ),
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: () => _act(
                () => AppController.instance.backendApi.respondFriendRequest(
                  profileId: profile.id,
                  friendshipId: request['id'].toString(),
                  action: 'accept',
                ),
              ),
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionCard(Map<String, dynamic> person) {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();
    final username = person['username']?.toString() ?? '';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_search_rounded),
        title: Text(person['display_name']?.toString() ?? username),
        subtitle: Text('@$username'),
        trailing: IconButton(
          onPressed: username.isEmpty
              ? null
              : () => _act(
                    () => AppController.instance.backendApi.sendFriendRequest(
                      profileId: profile.id,
                      username: username,
                    ),
                  ),
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
      ),
    );
  }

  Widget _storyComposer() {
    return GestureDetector(
      onTap: _composeStory,
      child: Container(
        width: 78,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 29,
              child: Icon(Icons.add_rounded),
            ),
            const SizedBox(height: 5),
            const Text(
              'Your story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storyBubble(Map<String, dynamic> story) {
    final author = story['author'] is Map
        ? Map<String, dynamic>.from(story['author'] as Map)
        : <String, dynamic>{};
    final name = author['display_name']?.toString() ??
        author['username']?.toString() ??
        'Friend';
    return GestureDetector(
      onTap: () => _showStory(story),
      child: Container(
        width: 78,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 27,
                child: Text(_initial(name)),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _composePost(String profileId) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create post'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          maxLength: 4000,
          decoration: const InputDecoration(
            hintText: 'What are you watching, listening to, or collecting?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    await _act(
      () => AppController.instance.backendApi.createSocialPost(
        profileId: profileId,
        body: value.trim(),
      ),
    );
  }

  Future<void> _composeCommunityPost(String communityId) async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Post to community'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          maxLength: 4000,
          decoration: const InputDecoration(
            hintText: 'Share with members of this community',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    await _act(
      () => AppController.instance.backendApi.createSocialPost(
        profileId: profile.id,
        body: value.trim(),
        communityIds: [communityId],
      ),
    );
  }

  Future<void> _composeStory({String? communityId}) async {
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
        communityId: communityId,
        expiresInHours: value.$2,
      ),
    );
  }

  List<Map<String, String>> _shortContentLinks(Profile profile) {
    final links = <Map<String, String>>[];
    for (final media in AppController.instance.library.where(
      (item) => item.isAccessibleTo(profile),
    )) {
      final normalizedType = media.type.toLowerCase();
      final type = normalizedType.contains('show') ||
              normalizedType.contains('series') ||
              normalizedType.contains('tv')
          ? 'show'
          : normalizedType.contains('movie') || normalizedType.contains('film')
              ? 'movie'
              : null;
      if (type != null) {
        links.add({
          'id': media.id,
          'title': media.title,
          'type': type,
          'subtitle': type == 'show' ? 'TV show' : 'Movie',
        });
      }
    }
    for (final track in MusicLibraryStore.instance.tracks) {
      links.add({
        'id': track.id,
        'title': track.title,
        'type': 'song',
        'subtitle': 'Song · ${track.artist}',
      });
    }
    return links;
  }

  Future<Map<String, String>?> _chooseShortContentLink(
    List<Map<String, String>> links,
  ) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        Map<String, String>? selected;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Link to library content'),
            content: SizedBox(
              width: 440,
              child: links.isEmpty
                  ? const Text(
                      'Add a movie, show, or song to this profile’s library first.',
                    )
                  : RadioGroup<Map<String, String>>(
                      groupValue: selected,
                      onChanged: (value) =>
                          setDialogState(() => selected = value),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: links.length,
                        itemBuilder: (context, index) {
                          final link = links[index];
                          return RadioListTile<Map<String, String>>(
                            value: link,
                            title: Text(link['title']!),
                            subtitle: Text(link['subtitle']!),
                          );
                        },
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(dialogContext, selected),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<int?> _chooseStoryLifetime() => showDialog<int>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Choose story lifetime'),
          children: [
            for (final option in const {
              24: '24 hours',
              48: '2 days',
              72: '3 days',
              168: '1 week',
            }.entries)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, option.key),
                child: Text(option.value),
              ),
          ],
        ),
      );

  Future<String?> _chooseShortContentMode() => showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Choose Short format'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'short'),
              child: const ListTile(
                leading: Icon(Icons.flash_on_rounded),
                title: Text('Short'),
                subtitle: Text('Quick vertical clip tied to a movie, show, or song.'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'review'),
              child: const ListTile(
                leading: Icon(Icons.star_rate_rounded),
                title: Text('Video review'),
                subtitle: Text('Review a movie, show, or song in vertical format.'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'skit'),
              child: const ListTile(
                leading: Icon(Icons.theater_comedy_rounded),
                title: Text('Skit'),
                subtitle: Text('A scene, parody, or character skit inspired by media.'),
              ),
            ),
          ],
        ),
      );

  Future<void> _createShort({
    bool asStory = false,
    String? communityId,
  }) async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final links = _shortContentLinks(profile);
    final related = await _chooseShortContentLink(links);
    if (related == null || !mounted) return;
    final contentMode = await _chooseShortContentMode();
    if (contentMode == null || !mounted) return;
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final result = await Navigator.of(context).push<SocialVideoEditResult>(
      MaterialPageRoute(
        builder: (_) => SocialVideoEditorScreen(source: File(picked.path)),
      ),
    );
    if (result == null || !mounted) return;
    final videoBytes = await result.video.readAsBytes();
    if (videoBytes.length > 50 * 1024 * 1024 ||
        result.coverBytes.length > 50 * 1024 * 1024) {
      await result.video.delete();
      _showMessage('Each video and cover must be 50 MB or smaller.');
      return;
    }
    final expiresInHours = asStory ? await _chooseStoryLifetime() : null;
    if (asStory && expiresInHours == null) {
      await result.video.delete();
      return;
    }
    final api = AppController.instance.backendApi;
    final body = [
      if (result.caption.trim().isNotEmpty) result.caption.trim(),
      'Related to ${related['subtitle']}: ${related['title']}',
    ].join('\n');
    await _act(() async {
      final videoPath = await api.uploadSocialAttachment(
        profileId: profile.id,
        bytes: videoBytes,
        contentType: 'video/mp4',
      );
      final coverPath = await api.uploadSocialAttachment(
        profileId: profile.id,
        bytes: result.coverBytes,
        contentType: 'image/jpeg',
      );
      final mediaReference = <String, dynamic>{
        'type': 'video',
        'videoPath': videoPath,
        'coverPath': coverPath,
        'relatedMediaId': related['id'],
        'relatedMediaType': related['type'],
        'relatedMediaTitle': related['title'],
        'contentMode': contentMode,
      };
      if (asStory) {
        await api.createSocialStory(
          profileId: profile.id,
          body: body,
          communityId: communityId,
          expiresInHours: expiresInHours!,
          mediaReference: mediaReference,
        );
      } else {
        await api.createSocialPost(
          profileId: profile.id,
          body: body,
          mediaReference: mediaReference,
        );
      }
    });
    if (await result.video.exists()) await result.video.delete();
  }

  Future<void> _playSocialVideo(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          actions: [
            IconButton(
              onPressed: () => controller.value.isPlaying
                  ? controller.pause()
                  : controller.play(),
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showMessage('Unable to play this video: $error');
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _addFriend() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a friend'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '@username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    await _act(
      () => AppController.instance.backendApi.sendFriendRequest(
        profileId: profile.id,
        username: value.trim().replaceFirst('@', ''),
      ),
    );
  }

  Future<void> _createCommunity() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final name = await _prompt('Create community', 'Community name');
    if (name == null || name.trim().isEmpty) return;
    final description =
        await _prompt('Community description', 'Description') ?? '';
    await _act(
      () => AppController.instance.backendApi.createSocialCommunity(
        profileId: profile.id,
        name: name.trim(),
        description: description.trim(),
      ),
    );
  }

  Future<void> _newMessage() async {
    final username = await _prompt('New message', '@username of a friend');
    if (username == null || username.trim().isEmpty) return;
    await _startMessageFor(username.trim().replaceFirst('@', ''));
  }

  Future<void> _newGroupMessage() async {
    final titleController = TextEditingController();
    final friendsController = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create group chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Group name'),
            ),
            TextField(
              controller: friendsController,
              decoration: const InputDecoration(
                labelText: 'Friend usernames',
                hintText: 'alex, sam',
                helperText: 'Add at least two accepted friends.',
              ),
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
              (titleController.text, friendsController.text),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    titleController.dispose();
    friendsController.dispose();
    if (result == null) return;
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final usernames = result.$2
        .split(RegExp(r'[,;\s]+'))
        .map((name) => name.trim().replaceFirst('@', ''))
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    try {
      final response =
          await AppController.instance.backendApi.createSocialGroupConversation(
        profileId: profile.id,
        title: result.$1.trim(),
        usernames: usernames,
      );
      final conversation = response['conversation'] is Map
          ? Map<String, dynamic>.from(response['conversation'] as Map)
          : <String, dynamic>{};
      final id = conversation['id']?.toString();
      if (id == null || id.isEmpty || !mounted) return;
      await _load();
      final messagesIndex = _tabSections.indexOf('messages');
      if (messagesIndex >= 0) _tabs.animateTo(messagesIndex);
      await _openConversation(id);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _startMessageFor(String username) async {
    final profile = AppController.instance.currentProfile;
    if (profile == null || username.trim().isEmpty) return;
    try {
      final result =
          await AppController.instance.backendApi.createSocialConversation(
        profileId: profile.id,
        username: username,
      );
      final conversation =
          result['conversation'] is Map ? result['conversation'] as Map : null;
      final id = conversation?['id']?.toString();
      if (id == null || id.isEmpty) return;
      if (!mounted) return;
      final messagesIndex = _tabSections.indexOf('messages');
      if (messagesIndex >= 0) _tabs.animateTo(messagesIndex);
      await _openConversation(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _openConversation(String conversationId) async {
    if (conversationId.isEmpty) return;
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SocialConversationScreen(
          conversationId: conversationId,
          profileId: profile.id,
        ),
      ),
    );
    await _load();
  }

  Future<void> _reactToPost(String postId, String reaction) async {
    if (postId.isEmpty) return;
    if (reaction == 'remove') {
      final profile = AppController.instance.currentProfile;
      if (profile == null) return;
      await _act(
        () => AppController.instance.backendApi.reactToSocialPost(
          profileId: profile.id,
          postId: postId,
          reaction: 'remove',
        ),
      );
      return;
    }
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    await _act(
      () => AppController.instance.backendApi.reactToSocialPost(
        profileId: profile.id,
        postId: postId,
        reaction: reaction,
      ),
    );
  }

  Future<void> _commentPost(String postId) async {
    if (postId.isEmpty) return;
    final value = await _prompt('Comment', 'Write a comment');
    if (value == null || value.trim().isEmpty) return;
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    await _act(
      () => AppController.instance.backendApi.commentOnSocialPost(
        profileId: profile.id,
        postId: postId,
        body: value.trim(),
      ),
    );
  }

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final reference = post['mediaReference'] is Map
        ? Map<String, dynamic>.from(post['mediaReference'] as Map)
        : post['media_reference'] is Map
            ? Map<String, dynamic>.from(post['media_reference'] as Map)
            : <String, dynamic>{};
    final type = reference['type']?.toString();
    final title = reference['relatedMediaTitle']?.toString() ??
        reference['mediaTitle']?.toString() ??
        'post';
    final messageReference = <String, dynamic>{
      if (type == 'video') ...{
        'type': 'video',
        if (reference['videoPath'] != null)
          'attachmentPath': reference['videoPath'],
        'title': title,
        if (reference['relatedMediaId'] != null)
          'mediaId': reference['relatedMediaId'],
        if (reference['relatedMediaType'] != null)
          'mediaType': reference['relatedMediaType'],
      } else if (type == 'photo') ...{
        'type': 'photo',
        if (reference['photoPath'] != null)
          'attachmentPath': reference['photoPath'],
      } else ...{
        'type': 'recommendation',
        'title': title,
        if (reference['mediaId'] != null) 'mediaId': reference['mediaId'],
        if (reference['mediaType'] != null) 'mediaType': reference['mediaType'],
      },
    };
    await showSocialShareDialog(
      context,
      title: 'post',
      message: post['body']?.toString() ?? '',
      mediaReference: messageReference,
      sourcePostId:
          type == 'video' ? post['id']?.toString() : null,
    );
  }

  void _showStory(Map<String, dynamic> story) {
    final author = story['author'] is Map
        ? Map<String, dynamic>.from(story['author'] as Map)
        : <String, dynamic>{};
    final name = author['display_name']?.toString() ??
        author['username']?.toString() ??
        'Friend';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(story['body']?.toString() ?? ''),
            if (story['mediaReference'] is Map &&
                (story['mediaReference'] as Map)['coverUrl'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InkWell(
                  onTap: () {
                    final reference = story['mediaReference'] as Map;
                    final videoUrl = reference['videoUrl']?.toString();
                    if (videoUrl != null) _playSocialVideo(videoUrl);
                  },
                  child: Image.network(
                    (story['mediaReference'] as Map)['coverUrl'].toString(),
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (story['expires_at'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Expires ${DateTime.tryParse(story['expires_at'].toString())?.toLocal()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
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

  Future<String?> _prompt(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: title == 'Comment' || title == 'Create post' ? 4 : 1,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _initial(String value) {
    final clean = value.trim();
    return clean.isEmpty ? '?' : clean.substring(0, 1).toUpperCase();
  }
}

class SocialConversationScreen extends StatefulWidget {
  final String conversationId;
  final String profileId;

  const SocialConversationScreen({
    super.key,
    required this.conversationId,
    required this.profileId,
  });

  @override
  State<SocialConversationScreen> createState() =>
      _SocialConversationScreenState();
}

class _SocialConversationScreenState extends State<SocialConversationScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  bool sending = false;
  bool recording = false;
  bool viewOnceNext = false;
  Map<String, dynamic>? replyingTo;
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final AudioRecorder recorder = AudioRecorder();
  final ImagePicker picker = ImagePicker();
  Timer? _typingDebounce;
  Timer? _typingHeartbeat;
  Timer? _activityRefresh;
  bool _refreshingActivity = false;
  bool _activityErrorShown = false;
  bool _typingErrorShown = false;
  Map<String, dynamic> _textFormat = <String, dynamic>{};
  final Set<String> _revealedSpoilers = <String>{};

  static const _emojis = [
    '😀',
    '😂',
    '🥹',
    '😍',
    '😎',
    '🤔',
    '😭',
    '😡',
    '👏',
    '🙌',
    '👍',
    '👎',
    '❤️',
    '🔥',
    '🎉',
    '🍿',
    '👀',
    '💀',
    '⭐',
    '🤟',
  ];

  Future<String?> _prompt(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: title == 'Comment' || title == 'Create post' ? 4 : 1,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _setMyNickname() async {
    final nickname = await _prompt(
      'Set nickname',
      'Nickname shown below your name',
    );
    if (nickname == null) return;
    final clean = nickname.trim();
    if (clean.length > 48) {
      _showError('Nicknames must be 48 characters or fewer.');
      return;
    }
    try {
      await AppController.instance.backendApi.setSocialProfilePresence(
        profileId: widget.profileId,
        nickname: clean,
        clearNickname: clean.isEmpty,
      );
      await _load(scrollToBottom: false);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _setAvailability(String availability) async {
    try {
      await AppController.instance.backendApi.setSocialProfilePresence(
        profileId: widget.profileId,
        availability: availability,
      );
      await _load(scrollToBottom: false);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  void initState() {
    super.initState();
    messageController.addListener(_onMessageChanged);
    _load();
    _activityRefresh = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _load(incremental: true, scrollToBottom: false),
    );
  }

  void _onMessageChanged() {
    if (!mounted) return;
    setState(() {});
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_setTypingStatus(messageController.text.trim().isNotEmpty));
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingHeartbeat?.cancel();
    _activityRefresh?.cancel();
    messageController.removeListener(_onMessageChanged);
    messageController.dispose();
    scrollController.dispose();
    unawaited(recorder.dispose());
    super.dispose();
  }

  Future<void> _load({
    bool incremental = false,
    bool scrollToBottom = true,
  }) async {
    if (incremental && (_refreshingActivity || data == null)) return;
    if (incremental) _refreshingActivity = true;
    try {
      final currentMessages = (data?['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final after = incremental && currentMessages.isNotEmpty
          ? currentMessages.last['created_at']?.toString()
          : null;
      final result =
          await AppController.instance.backendApi.getSocialConversation(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        after: after,
      );
      if (!mounted) return;
      _activityErrorShown = false;
      if (incremental) {
        final knownIds =
            currentMessages.map((message) => message['id']?.toString()).toSet();
        final newMessages = (result['messages'] as List? ?? const [])
            .whereType<Map>()
            .map((message) => Map<String, dynamic>.from(message))
            .where((message) => !knownIds.contains(message['id']?.toString()));
        result['messages'] = [...currentMessages, ...newMessages];
      }
      setState(() {
        data = result;
        loading = false;
      });
      if (scrollToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.jumpTo(scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      if (incremental && _activityErrorShown) return;
      if (incremental) _activityErrorShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (incremental) _refreshingActivity = false;
    }
  }

  Future<void> _setTypingStatus(bool isTyping) async {
    if (isTyping) {
      _typingHeartbeat ??= Timer.periodic(
        const Duration(seconds: 4),
        (_) => unawaited(_setTypingStatus(true)),
      );
    } else {
      _typingHeartbeat?.cancel();
      _typingHeartbeat = null;
    }
    try {
      await AppController.instance.backendApi.setSocialConversationTyping(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        isTyping: isTyping,
      );
      _typingErrorShown = false;
    } catch (error) {
      if (isTyping) {
        _typingHeartbeat?.cancel();
        _typingHeartbeat = null;
      }
      if (!mounted || _typingErrorShown) return;
      _typingErrorShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _send() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending) return;
    await _sendMessage(
      body: text,
      messageType: 'text',
      replyToMessageId: replyingTo?['id']?.toString(),
      textFormat: _textFormat,
    );
  }

  Future<void> _sendMessage({
    required String body,
    required String messageType,
    Map<String, dynamic>? mediaReference,
    Map<String, dynamic>? textFormat,
    bool viewOnce = false,
    String? replyToMessageId,
  }) async {
    if (sending) return;
    if (!_canSend) {
      _showError('Only group admins can send messages in this chat.');
      return;
    }
    _typingDebounce?.cancel();
    unawaited(_setTypingStatus(false));
    setState(() => sending = true);
    try {
      await AppController.instance.backendApi.sendSocialMessage(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        body: body.isEmpty ? 'Attachment' : body,
        messageType: messageType,
        mediaReference: mediaReference,
        textFormat: textFormat,
        viewOnce: viewOnce,
        replyToMessageId: replyToMessageId ?? replyingTo?['id']?.toString(),
      );
      messageController.clear();
      setState(() {
        replyingTo = null;
        viewOnceNext = false;
        _textFormat = <String, dynamic>{};
      });
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _react(String messageId) async {
    final reaction = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final emoji in _emojis.take(16))
              SizedBox(
                width: 56,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, emoji),
                  icon: Text(emoji, style: const TextStyle(fontSize: 25)),
                ),
              ),
          ],
        ),
      ),
    );
    if (reaction == null) return;
    await AppController.instance.backendApi.reactToSocialMessage(
      profileId: widget.profileId,
      messageId: messageId,
      reaction: reaction,
    );
    await _load();
  }

  Future<void> _chooseAttachment() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            _actionTile(context, 'photo-video', Icons.photo_camera_outlined,
                'Photo or video'),
            _actionTile(
                context, 'voice', Icons.mic_none_rounded, 'Voice message'),
            _actionTile(context, 'recommendation', Icons.movie_filter_outlined,
                'Recommend media or song'),
            _actionTile(context, 'product', Icons.shopping_bag_outlined,
                'Share a Shop product'),
            _actionTile(
                context, 'link', Icons.link_rounded, 'Share a store link'),
            _actionTile(
                context, 'gif', Icons.gif_box_outlined, 'Share a GIF link'),
            _actionTile(context, 'sticker', Icons.emoji_emotions_outlined,
                'Send a sticker'),
            _actionTile(context, 'friend', Icons.person_add_alt_1_rounded,
                'Suggest a friend'),
            if (_isGroup)
              _actionTile(
                  context, 'poll', Icons.poll_outlined, 'Create a poll'),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'photo-video':
        await _pickPhotoOrVideo();
      case 'voice':
        await _toggleVoiceRecording();
      case 'recommendation':
        await _recommendMedia();
      case 'product':
        await _shareProduct();
      case 'link':
        await _shareLink();
      case 'gif':
        await _shareGif();
      case 'sticker':
        await _chooseSticker();
      case 'friend':
        await _suggestFriend();
      case 'poll':
        await _createPoll();
    }
  }

  Widget _actionTile(
    BuildContext context,
    String value,
    IconData icon,
    String label,
  ) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () => Navigator.pop(context, value),
      );

  Future<void> _pickPhotoOrVideo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Record with camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video (up to 2 minutes)'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (kind == null) return;
    final file = kind == 'photo'
        ? await picker.pickImage(
            source: source,
            maxWidth: 1920,
            imageQuality: 85,
          )
        : await picker.pickVideo(
            source: source,
            maxDuration: const Duration(minutes: 2),
          );
    if (file == null) return;
    final extension = file.name.split('.').last.toLowerCase();
    final mime = switch ((kind, extension)) {
      ('photo', 'jpg' || 'jpeg') => 'image/jpeg',
      ('photo', 'png') => 'image/png',
      ('photo', 'webp') => 'image/webp',
      ('video', 'mp4' || 'm4v') => 'video/mp4',
      ('video', 'mov') => 'video/quicktime',
      ('video', 'webm') => 'video/webm',
      _ => null,
    };
    if (mime == null) {
      _showError('Choose a JPEG, PNG, WebP, MP4, or WebM file.');
      return;
    }
    await _uploadAndSend(
      file: file,
      contentType: mime,
      mediaType: kind,
      messageType: kind,
    );
  }

  Future<void> _uploadAndSend({
    required XFile file,
    required String contentType,
    required String mediaType,
    required String messageType,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 50 * 1024 * 1024) {
      _showError('Attachments must be smaller than 50 MB.');
      return;
    }
    final path = await AppController.instance.backendApi.uploadSocialAttachment(
      profileId: widget.profileId,
      bytes: bytes,
      contentType: contentType,
    );
    await _sendMessage(
      body: '',
      messageType: messageType,
      viewOnce: viewOnceNext,
      mediaReference: {
        'type': mediaType,
        'attachmentPath': path,
        'fileName': file.name,
        'mimeType': contentType,
        if (viewOnceNext) 'viewOnce': true,
      },
    );
  }

  Future<void> _toggleVoiceRecording() async {
    if (recording) {
      try {
        final path = await recorder.stop();
        if (!mounted) return;
        setState(() => recording = false);
        if (path == null) {
          throw StateError('The voice recording was not saved.');
        }
        final file = XFile(path, name: 'voice-message.m4a');
        await _uploadAndSend(
          file: file,
          contentType: 'audio/mp4',
          mediaType: 'voice',
          messageType: 'voice',
        );
      } catch (error) {
        if (mounted) _showError(error.toString());
      }
      return;
    }
    try {
      if (!await recorder.hasPermission()) {
        _showError(
            'Microphone permission is required to record a voice message.');
        return;
      }
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}${Platform.pathSeparator}chat-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (mounted) setState(() => recording = true);
    } catch (error) {
      if (mounted) _showError('Unable to start voice recording: $error');
    }
  }

  Future<void> _recommendMedia() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.movie_outlined),
            title: const Text('Recommend a movie or show'),
            onTap: () => Navigator.pop(context, 'media'),
          ),
          ListTile(
            leading: const Icon(Icons.music_note_outlined),
            title: const Text('Recommend a song'),
            onTap: () => Navigator.pop(context, 'song'),
          ),
        ]),
      ),
    );
    if (!mounted || option == null) return;
    if (option == 'media') {
      final library = AppController.instance.library;
      if (library.isEmpty) {
        _showError('Your library has no movies or shows to recommend.');
        return;
      }
      final selected = await showDialog<MediaItem>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Choose a recommendation'),
          children: [
            for (final media in library)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, media),
                child: Text(media.title),
              ),
          ],
        ),
      );
      if (!mounted || selected == null) return;
      await _sendMessage(
        body: 'Recommended ${selected.title}',
        messageType: 'recommendation',
        mediaReference: {
          'type': 'recommendation',
          'mediaId': selected.id,
          'mediaType': selected.type,
          'title': selected.title,
        },
      );
      return;
    }
    final tracks = MusicLibraryStore.instance.tracks;
    if (tracks.isEmpty) {
      _showError('Your music library has no songs to recommend.');
      return;
    }
    final track = await showDialog<MusicTrack>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose a song'),
        children: [
          for (final item in tracks)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Text('${item.title} — ${item.artist}'),
            ),
        ],
      ),
    );
    if (!mounted || track == null) return;
    await _sendMessage(
      body: 'Recommended ${track.title} by ${track.artist}',
      messageType: 'recommendation',
      mediaReference: {
        'type': 'recommendation',
        'mediaType': 'song',
        'mediaId': track.id,
        'title': track.title,
        'description': track.artist,
      },
    );
  }

  Future<void> _shareProduct() async {
    final products = ShopCatalog.instance.products
        .where((product) => product.active)
        .toList();
    if (products.isEmpty) {
      _showError('There are no active Shop products to share.');
      return;
    }
    final product = await showDialog<ShopProduct>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Share a Shop product'),
        children: [
          for (final item in products)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Text(
                  '${item.name} · ${item.currency} ${item.price.toStringAsFixed(2)}'),
            ),
        ],
      ),
    );
    if (product == null) return;
    await _sendMessage(
      body: 'Shared Shop product: ${product.name}',
      messageType: 'product',
      mediaReference: {
        'type': 'product',
        'productId': product.id,
        'title': product.name,
        'description': product.description,
      },
    );
  }

  Future<String?> _askText(String title, String hint) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _shareLink() async {
    final value = await _askText('Share a store link', 'https://store.example');
    if (value == null || !_validHttpUrl(value)) {
      if (value != null) _showError('Enter a complete http or https link.');
      return;
    }
    await _sendMessage(
      body: value,
      messageType: 'link',
      mediaReference: {'type': 'link', 'url': value, 'title': 'Store link'},
    );
  }

  Future<void> _shareGif() async {
    final value = await _askText('Share a GIF URL', 'https://…/funny.gif');
    if (value == null || !_validHttpUrl(value)) {
      if (value != null) _showError('Enter a complete http or https GIF URL.');
      return;
    }
    await _sendMessage(
      body: 'GIF',
      messageType: 'gif',
      mediaReference: {'type': 'gif', 'url': value},
    );
  }

  bool _validHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Future<void> _chooseSticker() async {
    final sticker = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final emoji in const [
              '🍿',
              '🦖',
              '🦸',
              '🚀',
              '👻',
              '🎃',
              '🐉',
              '🪄',
              '🏴‍☠️',
              '💥',
              '🌟',
              '🦄',
              '🎬',
              '🎵',
              '🐈',
              '🤖',
            ])
              SizedBox(
                width: 60,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, emoji),
                  icon: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
          ],
        ),
      ),
    );
    if (sticker == null) return;
    await _sendMessage(
      body: sticker,
      messageType: 'sticker',
      mediaReference: {'type': 'sticker', 'emoji': sticker},
    );
  }

  Future<void> _suggestFriend() async {
    final username = AppController.instance.currentAccount?.username;
    if (username == null || username.trim().isEmpty) {
      _showError('Your account needs a username before you can suggest it.');
      return;
    }
    await _sendMessage(
      body: 'I’d like you to connect with me.',
      messageType: 'friend_invite',
      mediaReference: {'type': 'friend_invite', 'username': username},
    );
  }

  Future<void> _createPoll() async {
    final questionController = TextEditingController();
    final optionsController = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a group poll'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: questionController,
              decoration: const InputDecoration(labelText: 'Question'),
            ),
            TextField(
              controller: optionsController,
              decoration: const InputDecoration(
                labelText: 'Options',
                hintText: 'One option per line',
              ),
              minLines: 2,
              maxLines: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(
                    context,
                    (questionController.text, optionsController.text),
                  ),
              child: const Text('Create poll')),
        ],
      ),
    );
    questionController.dispose();
    optionsController.dispose();
    if (result == null) return;
    final options = result.$2
        .split(RegExp(r'[\n,;]'))
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();
    try {
      await AppController.instance.backendApi.createSocialChatPoll(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        question: result.$1.trim(),
        options: options,
      );
      await _load();
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  Future<void> _votePoll(Map<String, dynamic> poll, int optionIndex) async {
    try {
      await AppController.instance.backendApi.voteSocialChatPoll(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        pollId: poll['id'].toString(),
        optionIndex: optionIndex,
      );
      await _load();
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  Future<void> _openViewOnce(Map<String, dynamic> message) async {
    try {
      final response =
          await AppController.instance.backendApi.viewSocialOnceMessage(
        profileId: widget.profileId,
        messageId: message['id'].toString(),
      );
      if (!mounted) return;
      if (response['expired'] == true) {
        final reference = message['mediaReference'] is Map
            ? Map<String, dynamic>.from(message['mediaReference'] as Map)
            : <String, dynamic>{};
        reference
          ..['expired'] = true
          ..['requiresView'] = false;
        _replaceMessage(message, {'mediaReference': reference});
        return;
      }
      final viewed = response['message'];
      if (viewed is! Map) return;
      final viewedReference = viewed['mediaReference'];
      if (viewedReference is! Map) {
        _showError('The view-once attachment could not be opened.');
        return;
      }
      _replaceMessage(message, {
        'mediaReference': Map<String, dynamic>.from(viewedReference),
        'view_once_opened': true,
      });
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  void _replaceMessage(
    Map<String, dynamic> original,
    Map<String, dynamic> updates,
  ) {
    setState(() {
      final messages = (data?['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final index = messages.indexWhere(
        (item) => item['id']?.toString() == original['id']?.toString(),
      );
      if (index >= 0) {
        messages[index] = {...messages[index], ...updates};
      }
      data = {...?data, 'messages': messages};
    });
  }

  Future<void> _setGroupPolicy(String policy) async {
    try {
      final response =
          await AppController.instance.backendApi.setSocialGroupSendPolicy(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        sendPolicy: policy,
      );
      final conversation = response['conversation'];
      if (conversation is Map) {
        setState(() => data = {
              ...?data,
              'conversation': Map<String, dynamic>.from(conversation),
            });
      }
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.replaceFirst('Exception: ', ''))),
    );
  }

  bool get _isGroup =>
      (data?['conversation'] as Map?)?['kind']?.toString() == 'group';

  bool get _isGroupAdmin {
    final members = (data?['members'] as List? ?? const [])
        .whereType<Map>()
        .map((member) => Map<String, dynamic>.from(member));
    return members.any(
      (member) =>
          member['isSelf'] == true &&
          {'owner', 'moderator'}.contains(member['role']),
    );
  }

  bool get _canSend {
    final conversation = data?['conversation'] as Map? ?? const {};
    return !_isGroup ||
        conversation['send_policy'] != 'admins_only' ||
        _isGroupAdmin;
  }

  DateTime? _messageTime(Map<String, dynamic> message, String key) {
    final value = message[key]?.toString();
    return value == null ? null : DateTime.tryParse(value)?.toUtc();
  }

  bool _memberHasReceived(
    Map<String, dynamic> member,
    Map<String, dynamic> message,
    String timestampKey,
  ) {
    final messageTime = _messageTime(message, 'created_at');
    final statusTime = _messageTime(member, timestampKey);
    return messageTime != null &&
        statusTime != null &&
        !statusTime.isBefore(messageTime);
  }

  Future<void> _editTextFormat() async {
    const colors = <String, Color>{
      'White': Colors.white,
      'Black': Colors.black,
      'Red': Colors.red,
      'Blue': Colors.blue,
      'Green': Colors.green,
      'Yellow': Colors.yellow,
      'Purple': Colors.purple,
      'Pink': Colors.pink,
    };
    final next = Map<String, dynamic>.from(_textFormat);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Text style',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: next['fontFamily']?.toString() ?? 'Default',
                    decoration: const InputDecoration(labelText: 'Font'),
                    items: const [
                      'Default',
                      'Arial',
                      'Georgia',
                      'Courier New',
                      'Times New Roman',
                      'Verdana',
                    ]
                        .map(
                          (font) => DropdownMenuItem(
                            value: font,
                            child: Text(
                              font,
                              style: TextStyle(
                                fontFamily: font == 'Default' ? null : font,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (font) => setSheetState(() {
                      if (font == null || font == 'Default') {
                        next.remove('fontFamily');
                      } else {
                        next['fontFamily'] = font;
                      }
                    }),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final entry in const {
                        'bold': 'Bold',
                        'italic': 'Italic',
                        'underline': 'Underline',
                        'strikeThrough': 'Strike through',
                        'metallic': 'Metallic',
                        'spoiler': 'Mark as spoiler',
                      }.entries)
                        FilterChip(
                          label: Text(entry.value),
                          selected: next[entry.key] == true,
                          onSelected: (selected) => setSheetState(() {
                            if (selected) {
                              next[entry.key] = true;
                            } else {
                              next.remove(entry.key);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Character color'),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final entry in colors.entries)
                        Tooltip(
                          message: entry.key,
                          child: InkWell(
                            onTap: () => setSheetState(() {
                              next['color'] =
                                  '#${_hexColor(entry.value)}'
                                      .toUpperCase();
                            }),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: entry.value,
                                child: next['color'] ==
                                        '#${_hexColor(entry.value)}'
                                            .toUpperCase()
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: entry.value.computeLuminance() <
                                                .4
                                            ? Colors.white
                                            : Colors.black,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: () =>
                            setSheetState(() => next.remove('color')),
                        child: const Text('Default'),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _textFormat = next);
  }

  Future<void> _customizeChatBackground(
    List<Map<String, dynamic>> members,
  ) async {
    final self = members.firstWhere(
      (member) => member['isSelf'] == true,
      orElse: () => <String, dynamic>{},
    );
    final currentColor = self['chatBackgroundColor']
        ?.toString()
        .replaceFirst('#', '')
        .toUpperCase();
    final colors = <String, Color>{
      'Default': Theme.of(context).scaffoldBackgroundColor,
      'Midnight': const Color(0xFF101522),
      'Ocean': const Color(0xFF092B3A),
      'Forest': const Color(0xFF173327),
      'Plum': const Color(0xFF34213B),
      'Charcoal': const Color(0xFF292929),
    };
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat background',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [
                  for (final entry in colors.entries)
                    Tooltip(
                      message: entry.key,
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          final color =
                              '#${_hexColor(entry.value)}'
                                  .toUpperCase();
                          await _saveChatAppearance(
                            backgroundColor:
                                entry.key == 'Default' ? null : color,
                            clearBackgroundColor: entry.key == 'Default',
                            clearBackgroundImage: true,
                          );
                        },
                        borderRadius: BorderRadius.circular(28),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: entry.value,
                          child: currentColor == _hexColor(entry.value) ||
                              (entry.key == 'Default' && currentColor == null)
                              ? const Icon(Icons.check_rounded)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: const Text('Choose a background image'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickChatBackgroundImage();
                },
              ),
              if (self['chatBackgroundImagePath'] != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.hide_image_outlined),
                  title: const Text('Remove background image'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _saveChatAppearance(clearBackgroundImage: true);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickChatBackgroundImage() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 2000,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _showError('Chat background images must be 5 MB or smaller.');
        return;
      }
      final extension = image.name.split('.').last.toLowerCase();
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final path = await AppController.instance.backendApi
          .uploadSocialAttachment(
        profileId: widget.profileId,
        bytes: bytes,
        contentType: contentType,
      );
      await _saveChatAppearance(backgroundImagePath: path);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _saveChatAppearance({
    String? backgroundColor,
    String? backgroundImagePath,
    bool clearBackgroundColor = false,
    bool clearBackgroundImage = false,
  }) async {
    try {
      await AppController.instance.backendApi.setSocialConversationAppearance(
        profileId: widget.profileId,
        conversationId: widget.conversationId,
        backgroundColor: backgroundColor,
        backgroundImagePath: backgroundImagePath,
        clearBackgroundColor: clearBackgroundColor,
        clearBackgroundImage: clearBackgroundImage,
      );
      await _load(scrollToBottom: false);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _hexColor(Color color) =>
      color.toARGB32().toRadixString(16).substring(2).toUpperCase();

  Widget _messageDeliveryIndicator(
    Map<String, dynamic> message,
    List<Map<String, dynamic>> members,
  ) {
    final recipients = members.where((member) => member['isSelf'] != true);
    final recipientList = recipients.toList();
    final allDelivered = recipientList.isNotEmpty &&
        recipientList.every(
          (member) =>
              _memberHasReceived(member, message, 'lastDeliveredAt') ||
              _memberHasReceived(member, message, 'lastReadAt'),
        );
    final allRead = recipientList.isNotEmpty &&
        recipientList.every(
          (member) => _memberHasReceived(member, message, 'lastReadAt'),
        );
    final color =
        allRead ? Colors.lightBlueAccent : Colors.white.withValues(alpha: .72);
    return IconButton(
      tooltip: allRead
          ? 'Read by everyone. Tap for details'
          : allDelivered
              ? 'Delivered to everyone. Tap for details'
              : 'Sent. Tap for details',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: () => _showMessageReceipts(message, recipientList),
      icon: allDelivered
          ? Icon(Icons.done_all_rounded, size: 17, color: color)
          : Icon(Icons.check_rounded, size: 17, color: color),
    );
  }

  Future<void> _showMessageReceipts(
    Map<String, dynamic> message,
    List<Map<String, dynamic>> recipients,
  ) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Message info'),
          content: SizedBox(
            width: 360,
            child: recipients.isEmpty
                ? const Text('No recipients to show.')
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final member in recipients)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text(
                                _initial(
                                  member['display_name']?.toString() ??
                                      member['username']?.toString() ??
                                      '?',
                                ),
                              ),
                            ),
                            title: Text(
                              member['display_name']?.toString() ??
                                  member['username']?.toString() ??
                                  'Member',
                            ),
                            subtitle: Text(_receiptLabel(member, message)),
                          ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );

  String _receiptLabel(
    Map<String, dynamic> member,
    Map<String, dynamic> message,
  ) {
    if (_memberHasReceived(member, message, 'lastReadAt')) {
      final readAt = _messageTime(member, 'lastReadAt')?.toLocal();
      return readAt == null ? 'Read' : 'Read at ${_formatTime(readAt)}';
    }
    if (_memberHasReceived(member, message, 'lastDeliveredAt')) {
      return 'Delivered';
    }
    return 'Sent';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String? _typingLabel(List<Map<String, dynamic>> typists) {
    if (typists.isEmpty) return null;
    if (typists.length > 2) return 'Several people are typing…';
    final names = typists
        .map(
          (member) =>
              member['display_name']?.toString() ??
              member['username']?.toString() ??
              'Someone',
        )
        .toList();
    return names.length == 1
        ? '${names.first} is typing…'
        : '${names[0]} and ${names[1]} are typing…';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final messages = (data?['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final members = (data?['members'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final typingMembers = (data?['typingMembers'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final conversation = data?['conversation'] as Map? ?? const {};
    final self = members.firstWhere(
      (member) => member['isSelf'] == true,
      orElse: () => <String, dynamic>{},
    );
    final other = members.where((item) => item['isSelf'] != true).toList();
    final primaryMember = other.isEmpty ? self : other.first;
    final subtitleParts = conversation['kind'] == 'group'
        ? other
            .where((member) => _presenceState(member) == 'active')
            .map((member) => member['activityText']?.toString())
            .whereType<String>()
            .where((activity) => activity.isNotEmpty)
            .toList()
        : <String>[
            if (primaryMember['nickname']?.toString().trim().isNotEmpty == true)
              primaryMember['nickname'].toString().trim(),
            if (primaryMember['activityText']?.toString().trim().isNotEmpty ==
                true)
              primaryMember['activityText'].toString().trim(),
          ];
    final subtitle = subtitleParts.take(2).join(' · ');
    final title = conversation['kind'] == 'group'
        ? (conversation['title']?.toString().trim().isNotEmpty == true
            ? conversation['title'].toString()
            : other
                .map((item) => item['display_name'] ?? item['username'])
                .join(', '))
        : other.isEmpty
            ? 'Conversation'
            : other.first['display_name']?.toString() ??
                other.first['username']?.toString() ??
                'Conversation';
    final savedBackgroundColor =
        self['chatBackgroundColor']?.toString().replaceFirst('#', '');
    final backgroundColor = savedBackgroundColor != null &&
            RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(savedBackgroundColor)
        ? Color(int.parse(savedBackgroundColor, radix: 16) | 0xFF000000)
        : Theme.of(context).scaffoldBackgroundColor;
    final backgroundImageUrl = self['chatBackgroundImageUrl']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _presenceAvatar(primaryMember, title),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isGroup && _isGroupAdmin)
            PopupMenuButton<String>(
              tooltip: 'Group settings',
              onSelected: _setGroupPolicy,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'all_members',
                  child: Text('All members can send'),
                ),
                PopupMenuItem(
                  value: 'admins_only',
                  child: Text('Only admins can send'),
                ),
              ],
              icon: const Icon(Icons.settings_outlined),
            ),
          IconButton(
            tooltip: 'Customize chat background',
            onPressed: () => _customizeChatBackground(members),
            icon: const Icon(Icons.wallpaper_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Profile presence and nickname',
            onSelected: (value) {
              if (value == 'nickname') {
                _setMyNickname();
              } else {
                _setAvailability(value);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'active',
                child: ListTile(
                  leading: Icon(Icons.circle, color: Colors.greenAccent),
                  title: Text('Active'),
                ),
              ),
              PopupMenuItem(
                value: 'away',
                child: ListTile(
                  leading: Icon(Icons.circle, color: Colors.grey),
                  title: Text('Away'),
                ),
              ),
              PopupMenuItem(
                value: 'busy',
                child: ListTile(
                  leading: Icon(Icons.circle, color: Colors.redAccent),
                  title: Text('Busy'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'nickname',
                child: ListTile(
                  leading: Icon(Icons.badge_outlined),
                  title: Text('Set my nickname'),
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          image: backgroundImageUrl == null || backgroundImageUrl.isEmpty
              ? null
              : DecorationImage(
                  image: NetworkImage(backgroundImageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: .42),
                    BlendMode.darken,
                  ),
                ),
        ),
        child: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'Say hello 👋',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final message = messages[index];
                      final mine = message['isMine'] == true;
                      final mediaReference = message['mediaReference'] is Map
                          ? Map<String, dynamic>.from(
                              message['mediaReference'] as Map,
                            )
                          : message['media_reference'] is Map
                              ? Map<String, dynamic>.from(
                                  message['media_reference'] as Map,
                                )
                              : <String, dynamic>{};
                      final poll = message['poll'] is Map
                          ? Map<String, dynamic>.from(message['poll'] as Map)
                          : null;
                      final sender = members.firstWhere(
                        (member) =>
                            member['accountId']?.toString() ==
                                message['sender_account_id']?.toString() &&
                            member['profileId']?.toString() ==
                                message['sender_profile_id']?.toString(),
                        orElse: () => <String, dynamic>{},
                      );
                      final reactionSummary = message['reactionSummary'] is Map
                          ? Map<String, dynamic>.from(
                              message['reactionSummary'] as Map,
                            )
                          : <String, dynamic>{};
                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () =>
                              _react(message['id']?.toString() ?? ''),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * .72,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? const Color(0xFF005C4B)
                                  : const Color(0xFF202C33),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(mine ? 18 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 18),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isGroup && sender.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: _memberNameLabel(sender),
                                  ),
                                if (message['reply_to_message_id'] != null)
                                  _replyPreview(
                                    messages,
                                    message['reply_to_message_id'].toString(),
                                  ),
                                _messageContent(message, mediaReference, poll),
                                if (reactionSummary.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Wrap(
                                      spacing: 6,
                                      children: [
                                        for (final entry
                                            in reactionSummary.entries)
                                          Text(
                                            '${entry.key} ${entry.value}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (mine)
                                      _messageDeliveryIndicator(
                                        message,
                                        members,
                                      ),
                                    if (mediaReference['type'] == 'video')
                                      IconButton(
                                        tooltip: 'Share video to chats',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => showSocialShareDialog(
                                          context,
                                          title: mediaReference['title']
                                                  ?.toString() ??
                                              'video',
                                          message: message['body']?.toString() ??
                                              'Shared video',
                                          mediaReference: mediaReference,
                                          sourceMessageId:
                                              message['id']?.toString(),
                                        ),
                                        icon: const Icon(
                                          Icons.share_outlined,
                                          size: 18,
                                        ),
                                      ),
                                    TextButton(
                                      onPressed: () => setState(
                                        () => replyingTo = message,
                                      ),
                                      child: const Text('Reply'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_typingLabel(typingMembers) case final typingLabel?)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TypingDots(color: Colors.white.withValues(alpha: .7)),
                    const SizedBox(width: 8),
                    Text(
                      typingLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (replyingTo != null)
                    ListTile(
                      dense: true,
                      title: Text(
                        'Replying to: ${replyingTo!['body'] ?? 'attachment'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        onPressed: () => setState(() => replyingTo = null),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Attachments, polls, media, and sharing',
                        onPressed:
                            sending || !_canSend ? null : _chooseAttachment,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                      IconButton(
                        tooltip: 'Emoji',
                        onPressed:
                            sending || !_canSend ? null : () => _sendEmoji(),
                        icon: const Icon(Icons.emoji_emotions_outlined),
                      ),
                      if (!recording)
                        IconButton(
                          tooltip: viewOnceNext
                              ? 'View-once attachment enabled'
                              : 'Make next attachment view once',
                          onPressed: !_canSend
                              ? null
                              : () => setState(
                                    () => viewOnceNext = !viewOnceNext,
                                  ),
                          icon: Icon(
                            Icons.timer_outlined,
                            color: viewOnceNext ? Colors.amber : null,
                          ),
                        ),
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          minLines: 1,
                          maxLines: 5,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            prefixIcon: IconButton(
                              tooltip: 'Text style',
                              onPressed: sending || !_canSend
                                  ? null
                                  : _editTextFormat,
                              icon: Icon(
                                Icons.format_color_text_rounded,
                                color: _textFormat.isEmpty
                                    ? null
                                    : Theme.of(context)
                                        .colorScheme
                                        .secondary,
                              ),
                            ),
                            hintText: !_canSend
                                ? 'Only group admins can send'
                                : recording
                                    ? 'Recording voice message… tap mic to send'
                                    : 'Message $title',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: .06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            enabled: _canSend && !recording,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (recording)
                        IconButton(
                          onPressed: sending ? null : _toggleVoiceRecording,
                          icon: const Icon(Icons.stop_circle_outlined),
                          color: Colors.redAccent,
                        )
                      else if (messageController.text.trim().isNotEmpty)
                        IconButton(
                          onPressed: sending || !_canSend ? null : _send,
                          icon: const Icon(Icons.send_rounded),
                        )
                      else
                        IconButton(
                          tooltip: 'Record voice message',
                          onPressed: sending || !_canSend
                              ? null
                              : _toggleVoiceRecording,
                          icon: const Icon(Icons.mic_none_rounded),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
        ),
    );
  }

  Widget _replyPreview(List<Map<String, dynamic>> messages, String id) {
    final parent = messages.where((message) => message['id']?.toString() == id);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        parent.isEmpty ? 'Reply' : '↳ ${parent.first['body'] ?? 'Attachment'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _messageContent(
    Map<String, dynamic> message,
    Map<String, dynamic> reference,
    Map<String, dynamic>? poll,
  ) {
    final type = reference['type']?.toString() ??
        message['message_type']?.toString() ??
        'text';
    final format = message['text_format'] is Map
        ? Map<String, dynamic>.from(message['text_format'] as Map)
        : <String, dynamic>{};
    final messageId = message['id']?.toString() ?? '';
    if (format['spoiler'] == true &&
        messageId.isNotEmpty &&
        !_revealedSpoilers.contains(messageId)) {
      return InkWell(
        onTap: () => setState(() => _revealedSpoilers.add(messageId)),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off_outlined, size: 18),
              SizedBox(width: 8),
              Flexible(child: Text('Spoiler · tap to reveal')),
            ],
          ),
        ),
      );
    }
    if (reference['requiresView'] == true) {
      return TextButton.icon(
        onPressed: () => _openViewOnce(message),
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('Tap to view once'),
      );
    }
    if (reference['expired'] == true) {
      return const Text('This view-once attachment has expired.');
    }
    if (reference['viewOnce'] == true &&
        message['isMine'] != true &&
        message['view_once_opened'] != true) {
      return TextButton.icon(
        onPressed: () => _openViewOnce(message),
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('Tap to view once'),
      );
    }
    if (type == 'poll' && poll != null) return _pollCard(poll);
    if (type == 'sticker') {
      return Text(
        reference['emoji']?.toString() ?? message['body']?.toString() ?? '✨',
        style: const TextStyle(fontSize: 44),
      );
    }
    if (type == 'photo' || type == 'image' || type == 'gif') {
      final url = (reference['imageUrl'] ?? reference['url'])?.toString();
      if (url != null && url.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 250,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Text('Image unavailable'),
          ),
        );
      }
    }
    final videoUrl = reference['videoUrl']?.toString();
    if (type == 'video' && videoUrl != null) {
      return _ChatVideoPlayer(url: videoUrl);
    }
    final audioUrl = reference['audioUrl']?.toString();
    if ((type == 'voice' || type == 'audio') && audioUrl != null) {
      return _ChatVideoPlayer(url: audioUrl, audioOnly: true);
    }
    if (type == 'link') {
      final url =
          reference['url']?.toString() ?? message['body']?.toString() ?? '';
      return InkWell(
        onTap: () {
          final uri = Uri.tryParse(url);
          if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Text(
          '${reference['title'] ?? 'Link'}\n$url',
          style: const TextStyle(
            color: Colors.lightBlueAccent,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }
    if (type == 'friend_invite') {
      final username = reference['username']?.toString() ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message['body']?.toString() ?? 'Friend request suggestion'),
          if (username.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                try {
                  await AppController.instance.backendApi.sendFriendRequest(
                    profileId: widget.profileId,
                    username: username,
                  );
                  await _load();
                } catch (error) {
                  if (mounted) _showError(error.toString());
                }
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: Text('Send friend request to @$username'),
            ),
        ],
      );
    }
    if (type == 'product' || type == 'recommendation') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                type == 'product'
                    ? Icons.shopping_bag_outlined
                    : reference['mediaType'] == 'store'
                        ? Icons.storefront_outlined
                        : reference['mediaType'] == 'song'
                            ? Icons.music_note_outlined
                            : Icons.movie_outlined,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  reference['title']?.toString() ??
                      message['body']?.toString() ??
                      'Shared item',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (reference['description']?.toString().isNotEmpty == true)
            Text(reference['description'].toString()),
        ],
      );
    }
    final decorations = <TextDecoration>[
      if (format['underline'] == true) TextDecoration.underline,
      if (format['strikeThrough'] == true) TextDecoration.lineThrough,
    ];
    final rawColor = format['color']?.toString();
    final color = rawColor != null &&
            RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(rawColor)
        ? Color(int.parse(rawColor.substring(1), radix: 16) | 0xFF000000)
        : null;
    final text = Text(
      message['body']?.toString() ?? '',
      style: TextStyle(
        height: 1.3,
        color: format['metallic'] == true ? null : color,
        fontFamily: format['fontFamily']?.toString(),
        fontWeight:
            format['bold'] == true ? FontWeight.bold : FontWeight.normal,
        fontStyle:
            format['italic'] == true ? FontStyle.italic : FontStyle.normal,
        decoration: decorations.isEmpty
            ? TextDecoration.none
            : TextDecoration.combine(decorations),
      ),
    );
    return format['metallic'] == true
        ? ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF8A8A8A),
                Color(0xFFF9F9F9),
                Color(0xFF777777),
                Color(0xFFE5E5E5),
              ],
            ).createShader(bounds),
            child: text,
          )
        : text;
  }

  Widget _pollCard(Map<String, dynamic> poll) {
    final options = (poll['options'] as List? ?? const [])
        .map((option) => option.toString())
        .toList();
    final counts = (poll['voteCounts'] as List? ?? const [])
        .map((count) => count is num ? count.toInt() : 0)
        .toList();
    final myVote = (poll['myVote'] as num?)?.toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          poll['question']?.toString() ?? 'Group poll',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        for (var index = 0; index < options.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: OutlinedButton(
              onPressed: () => _votePoll(poll, index),
              child: Row(
                children: [
                  Expanded(child: Text(options[index])),
                  if (myVote == index) const Icon(Icons.check_rounded),
                  const SizedBox(width: 6),
                  Text('${index < counts.length ? counts[index] : 0}'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _sendEmoji() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final item in _emojis)
              SizedBox(
                width: 56,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, item),
                  icon: Text(item, style: const TextStyle(fontSize: 25)),
                ),
              ),
          ],
        ),
      ),
    );
    if (emoji != null) {
      await _sendMessage(body: emoji, messageType: 'emoji');
    }
  }

  String _initial(String value) {
    final clean = value.trim();
    return clean.isEmpty ? '?' : clean.substring(0, 1).toUpperCase();
  }
}

class _ChatVideoPlayer extends StatefulWidget {
  const _ChatVideoPlayer({required this.url, this.audioOnly = false});

  final String url;
  final bool audioOnly;

  @override
  State<_ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<_ChatVideoPlayer> {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox(
        width: 220,
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      width: widget.audioOnly ? 250 : 260,
      child: Column(
        children: [
          if (!widget.audioOnly)
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            )
          else
            const Icon(Icons.graphic_eq_rounded, size: 40),
          IconButton(
            onPressed: () {
              setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              });
            },
            icon: Icon(
              controller.value.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++)
              Opacity(
                opacity: .35 +
                    .65 *
                        ((1 - (_controller.value * 3 - index).abs())
                            .clamp(0.0, 1.0)),
                child: Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      );
}
