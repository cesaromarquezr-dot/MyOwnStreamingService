import 'package:flutter/material.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'social_detail_pages.dart';
import 'social_story_experience.dart';

/// One shared friend story/activity surface used from Home, Friends and Messages.
class FriendStoryProfileViewer extends StatefulWidget {
  const FriendStoryProfileViewer({super.key, required this.friend});

  final Map<String, dynamic> friend;

  @override
  State<FriendStoryProfileViewer> createState() =>
      _FriendStoryProfileViewerState();
}

class _FriendStoryProfileViewerState extends State<FriendStoryProfileViewer> {
  List<Map<String, dynamic>> _stories = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  String _first(Map<String, dynamic> map, List<String> keys,
      {String fallback = ''}) {
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  Map<String, dynamic> get _friend => widget.friend;
  String get _profileId => _first(_friend, const [
        'profileId',
        'profile_id',
        'targetProfileId',
        'target_profile_id',
        'id'
      ]);
  String get _name =>
      _first(_friend, const ['display_name', 'displayName', 'name', 'username'],
          fallback: 'Friend');
  String get _avatar =>
      _first(_friend, const ['avatar_url', 'avatarUrl', 'avatar']);

  String? get _activity {
    final enabled = _friend['shareActivity'] ??
        _friend['share_activity'] ??
        _friend['activitySharingEnabled'] ??
        _friend['activity_sharing_enabled'];
    if (enabled == false) return null;
    final media = _friend['mediaActivity'] ??
        _friend['media_activity'] ??
        _friend['currentlyPlaying'] ??
        _friend['currently_playing'];
    if (media is Map) {
      final item = Map<String, dynamic>.from(media);
      final title =
          _first(item, const ['title', 'name', 'mediaTitle', 'media_title']);
      if (title.isEmpty) return null;
      final kind =
          _first(item, const ['type', 'mediaType', 'media_type', 'kind'])
              .toLowerCase();
      final listening = kind.contains('music') ||
          kind.contains('song') ||
          kind.contains('audio');
      return '${listening ? 'Listening to' : 'Watching'}: $title';
    }
    final watching = _first(_friend, const ['watchingNow', 'watching_now']);
    if (watching.isNotEmpty) return 'Watching: $watching';
    final listening = _first(_friend, const ['listeningNow', 'listening_now']);
    if (listening.isNotEmpty) return 'Listening to: $listening';
    // Presence activity is shown only when the backend explicitly supplies it.
    final status = _first(_friend, const ['activityText', 'activity_text']);
    return status.isEmpty ? null : status;
  }

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null || _profileId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }
    try {
      final response = await AppController.instance.backendApi
          .getSocialHome(profileId: profile.id);
      final raw = response['stories'];
      final stories = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((story) {
              final author = story['author'] is Map
                  ? Map<String, dynamic>.from(story['author'] as Map)
                  : <String, dynamic>{};
              final authorId =
                  _first(author, const ['profileId', 'profile_id', 'id']);
              return authorId == _profileId;
            }).toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _stories = stories;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _openProfile() {
    final accountId = _first(_friend, const ['accountId', 'account_id', 'id']);
    if (_profileId.isEmpty || accountId.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SocialProfileDetailScreen(
              targetAccountId: accountId,
              targetProfileId: _profileId,
              initialProfile: _friend,
            )));
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    return Scaffold(
      appBar: AppBar(title: Text(_name), actions: [
        IconButton(
            tooltip: 'View profile',
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline_rounded))
      ]),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
              child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 3)),
            child: CircleAvatar(
                radius: 43,
                backgroundImage: _avatar.isEmpty ? null : NetworkImage(_avatar),
                child: _avatar.isEmpty
                    ? Text(_name.isEmpty ? '?' : _name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 28))
                    : null),
          )),
          const SizedBox(height: 10),
          Center(
              child: Text(_name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800))),
          if (_first(_friend, const ['username']).isNotEmpty)
            Center(
                child: Text('@${_friend['username']}',
                    style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 18),
          if (activity != null)
            Card(
                child: ListTile(
              leading: Icon(activity.toLowerCase().startsWith('listening')
                  ? Icons.music_note_rounded
                  : Icons.live_tv_rounded),
              title: const Text('Listening / Watching now'),
              subtitle: Text(activity),
            )),
          const SizedBox(height: 12),
          Text('Stories',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator()))
          else if (_stories.isNotEmpty)
            ..._stories.map((story) {
              final reference = story['mediaReference'] is Map
                  ? Map<String, dynamic>.from(story['mediaReference'] as Map)
                  : <String, dynamic>{};
              final body = story['body']?.toString().trim() ?? '';
              final mediaTitle = _first(reference, const ['title', 'name']);
              return Card(
                  child: ListTile(
                leading: const CircleAvatar(
                    child: Icon(Icons.play_circle_outline_rounded)),
                title: Text(body.isNotEmpty
                    ? body
                    : (mediaTitle.isNotEmpty ? mediaTitle : 'View story')),
                subtitle: Text(_first(
                    story,
                    const [
                      'createdAt',
                      'created_at',
                      'expiresAt',
                      'expires_at'
                    ],
                    fallback: 'Friend story')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => StoryViewerScreen(story: story))),
              ));
            })
          else
            Text(
                _error == null
                    ? 'No active stories right now.'
                    : 'Stories could not be refreshed. ${_error!}',
                style: Theme.of(context).textTheme.bodyMedium),
          if (activity == null)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                    'This friend has not shared listening or watching activity.',
                    style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 18),
          OutlinedButton.icon(
              onPressed: _openProfile,
              icon: const Icon(Icons.person_outline_rounded),
              label: const Text('View full profile')),
        ],
      ),
    );
  }
}
