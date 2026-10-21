import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Friends' current media activity card for the social feed.
/// Activity is rendered only when the social API includes an explicit activity
/// object; this widget does not infer a friend's playback from their presence.
class FriendsMediaActivity extends StatefulWidget {
  final List<Map<String, dynamic>> friends;
  const FriendsMediaActivity({super.key, required this.friends});

  @override
  State<FriendsMediaActivity> createState() => _FriendsMediaActivityState();
}

class _FriendsMediaActivityState extends State<FriendsMediaActivity> {
  static const _sharingKey = 'friends_media_activity_sharing_enabled';
  bool _sharingEnabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sharingEnabled = prefs.getBool(_sharingKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _setSharing(bool value) async {
    setState(() => _sharingEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sharingKey, value);
  }

  String _name(Map<String, dynamic> friend) {
    for (final key in ['displayName', 'display_name', 'nickname', 'name', 'username']) {
      final value = friend[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'Friend';
  }

  Map<String, dynamic>? _mediaActivity(Map<String, dynamic> friend) {
    for (final key in ['mediaActivity', 'media_activity', 'currentlyPlaying', 'currently_playing']) {
      final value = friend[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    final watching = friend['watchingNow'] ?? friend['watching_now'];
    final listening = friend['listeningNow'] ?? friend['listening_now'];
    if (watching is Map) return {...Map<String, dynamic>.from(watching), 'kind': 'watching'};
    if (listening is Map) return {...Map<String, dynamic>.from(listening), 'kind': 'listening'};
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = <MapEntry<Map<String, dynamic>, Map<String, dynamic>>>[];
    for (final friend in widget.friends) {
      final activity = _mediaActivity(friend);
      if (activity != null) active.add(MapEntry(friend, activity));
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.graphic_eq_rounded, size: 26),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Listening & Watching', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text('See what your friends are enjoying right now', style: theme.textTheme.bodySmall),
            ])),
            const Icon(Icons.people_alt_outlined),
          ]),
          const SizedBox(height: 12),
          if (active.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Icon(Icons.headphones_rounded)),
              title: Text('No shared activity yet'),
              subtitle: Text('When friends choose to share what they play, it will appear here.'),
            )
          else
            ...active.take(8).map((entry) {
              final friend = entry.key;
              final activity = entry.value;
              final kind = (activity['kind'] ?? activity['type'] ?? activity['mediaType'] ?? activity['media_type'] ?? '').toString().toLowerCase();
              final watching = kind.contains('watch') || kind.contains('video') || kind.contains('movie') || kind.contains('tv');
              final title = (activity['title'] ?? activity['name'] ?? activity['trackTitle'] ?? activity['track_title'] ?? 'Unknown title').toString();
              final subtitle = (activity['artist'] ?? activity['seriesTitle'] ?? activity['series_title'] ?? activity['subtitle'] ?? activity['album'] ?? '').toString();
              final image = (activity['artworkUrl'] ?? activity['artwork_url'] ?? activity['posterUrl'] ?? activity['poster_url'] ?? '').toString();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: image.startsWith('http') ? NetworkImage(image) : null,
                  child: image.startsWith('http') ? null : Icon(watching ? Icons.play_circle_fill_rounded : Icons.music_note_rounded),
                ),
                title: Text('${_name(friend)} ${watching ? 'is watching' : 'is listening to'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(subtitle.isEmpty ? title : '$title · $subtitle', maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Icon(watching ? Icons.tv_rounded : Icons.headphones_rounded),
              );
            }),
          const Divider(height: 24),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _sharingEnabled,
            onChanged: _loaded ? _setSharing : null,
            title: const Text('Share my listening and watching'),
            subtitle: Text(_sharingEnabled
                ? 'Your sharing preference is on. Playback events must also be published by the service.'
                : 'Off by default. Turn on to opt in to sharing activity when supported.'),
          ),
        ]),
      ),
    );
  }
}
