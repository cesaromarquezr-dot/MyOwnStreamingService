import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'app_core.dart';
import 'music.dart';


class StoryPlacementStore {
  static const _keyPrefix = 'story_placement_';

  static String forProfile(dynamic profile) {
    if (profile == null) return 'friends';
    return _cache[profile.id] ?? 'friends';
  }

  static final Map<String, String> _cache = <String, String>{};
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool showsOnHome(dynamic profile) => forProfile(profile) == 'home' || forProfile(profile) == 'both';
  static bool showsOnFriends(dynamic profile) => forProfile(profile) == 'friends' || forProfile(profile) == 'both';

  static Future<void> setForProfile(dynamic profile, String value) async {
    if (profile == null) return;
    final clean = {'none', 'home', 'friends', 'both'}.contains(value) ? value : 'friends';
    _cache[profile.id] = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix${profile.id}', clean);
    revision.value++;
  }

  static Future<void> load(dynamic profile) async {
    if (profile == null) return;
    final prefs = await SharedPreferences.getInstance();
    _cache[profile.id] = prefs.getString('$_keyPrefix${profile.id}') ?? 'friends';
    revision.value++;
  }
}

class FriendsStoriesStrip extends StatefulWidget {
  const FriendsStoriesStrip({super.key, required this.profileId});
  final String profileId;

  @override
  State<FriendsStoriesStrip> createState() => _FriendsStoriesStripState();
}

class _FriendsStoriesStripState extends State<FriendsStoriesStrip> {
  List<Map<String, dynamic>> stories = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AppController.instance.backendApi.getSocialHome(profileId: widget.profileId);
      final raw = data['stories'];
      if (!mounted || raw is! List) return;
      setState(() => stories = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 118,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final story = stories[index];
          final author = story['author'] is Map ? Map<String, dynamic>.from(story['author'] as Map) : <String, dynamic>{};
          final name = author['display_name']?.toString() ?? author['username']?.toString() ?? 'Friend';
          final reference = story['mediaReference'] is Map ? Map<String, dynamic>.from(story['mediaReference'] as Map) : <String, dynamic>{};
          final image = reference['coverUrl']?.toString() ?? reference['imageUrl']?.toString();
          return SizedBox(
            width: 82,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewerScreen(story: story))),
              child: Column(
                children: [
                  Container(
                    width: 70, height: 70, padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2)),
                    child: CircleAvatar(backgroundImage: image == null ? null : NetworkImage(image), child: image == null ? Text(name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase()) : null),
                  ),
                  const SizedBox(height: 5),
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class StoryDraft {
  const StoryDraft({
    required this.body,
    required this.expiresInHours,
    required this.storyData,
    this.media,
    this.mediaType,
  });

  final String body;
  final int expiresInHours;
  final Map<String, dynamic> storyData;
  final XFile? media;
  final String? mediaType;
}

class StoryComposerScreen extends StatefulWidget {
  const StoryComposerScreen({
    super.key,
    this.friends = const <Map<String, dynamic>>[],
    this.media = const <MediaItem>[],
  });

  final List<Map<String, dynamic>> friends;
  final List<MediaItem> media;

  @override
  State<StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _StoryComposerScreenState extends State<StoryComposerScreen> {
  final bodyController = TextEditingController();
  final locationController = TextEditingController();
  int expiresInHours = 24;
  XFile? selectedMedia;
  String? selectedMediaType;
  MusicTrack? selectedTrack;
  String musicMode = 'audio';
  final List<Map<String, dynamic>> mentions = <Map<String, dynamic>>[];
  Map<String, dynamic>? selectedPoll;
  Map<String, dynamic>? selectedMediaMention;
  double lyricsSize = 24;
  Color lyricsColor = Colors.white;
  Offset lyricsOffset = const Offset(0, 50);

  @override
  void dispose() {
    bodyController.dispose();
    locationController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(sheetContext, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () => Navigator.pop(sheetContext, 'video'),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final picker = ImagePicker();
    final file = kind == 'photo'
        ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1920)
        : await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
    if (!mounted || file == null) return;
    setState(() {
      selectedMedia = file;
      selectedMediaType = kind;
    });
  }

  Future<void> _pickMusic() async {
    final tracks = MusicLibraryStore.instance.tracks;
    if (tracks.isEmpty) {
      _notice('Your owned music library is empty.');
      return;
    }
    final track = await showModalBottomSheet<MusicTrack>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: tracks.length,
          itemBuilder: (_, index) {
            final item = tracks[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.music_note_rounded)),
              title: Text(item.title),
              subtitle: Text('${item.artist} • ${item.album}'),
              onTap: () => Navigator.pop(sheetContext, item),
            );
          },
        ),
      ),
    );
    if (!mounted || track == null) return;
    setState(() => selectedTrack = track);
  }

  Future<void> _pickPoll() async {
    final question = TextEditingController();
    final options = TextEditingController(text: 'Option 1\nOption 2');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Add a poll'),
        content: Column(
          children: [
            TextField(controller: question, decoration: const InputDecoration(labelText: 'Question')),
            const SizedBox(height: 10),
            TextField(
              controller: options,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Options', hintText: 'One option per line'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final values = options.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
              if (question.text.trim().isEmpty || values.length < 2) return;
              Navigator.pop(dialogContext, {'question': question.text.trim(), 'options': values.take(6).toList()});
            },
            child: const Text('Add poll'),
          ),
        ],
      ),
    );
    question.dispose();
    options.dispose();
    if (mounted && result != null) setState(() => selectedPoll = result);
  }

  Future<void> _pickFriendMentions() async {
    if (widget.friends.isEmpty) {
      _notice('No friends are available to mention.');
      return;
    }
    final selected = <String>{
      for (final item in mentions) item['profileId']?.toString() ?? '',
    }..remove('');
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Mention friends'), subtitle: Text('Select one or more friends.')),
              for (final friend in widget.friends)
                CheckboxListTile(
                  value: selected.contains(friend['profileId']?.toString()),
                  title: Text(friend['displayName']?.toString() ?? friend['username']?.toString() ?? 'Friend'),
                  subtitle: Text(friend['username']?.toString() == null ? '' : '@${friend['username']}'),
                  onChanged: (value) {
                    final id = friend['profileId']?.toString() ?? '';
                    setSheetState(() {
                      if (value == true && id.isNotEmpty) selected.add(id);
                      if (value != true) selected.remove(id);
                    });
                  },
                ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  widget.friends.where((friend) => selected.contains(friend['profileId']?.toString())).toList(),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      mentions
        ..clear()
        ..addAll(result.map((friend) => {
              'profileId': friend['profileId'],
              'username': friend['username'],
              'displayName': friend['displayName'] ?? friend['username'],
            }));
    });
  }

  Future<void> _pickMediaMention() async {
    final choices = widget.media.where((item) {
      final type = item.type.toLowerCase();
      return type.contains('movie') || type.contains('film') || type.contains('show') || type.contains('series') || type.contains('tv');
    }).toList();
    if (choices.isEmpty) {
      _notice('You do not have an owned movie or show available to mention.');
      return;
    }
    final result = await showModalBottomSheet<MediaItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => ListView.builder(
        shrinkWrap: true,
        itemCount: choices.length,
        itemBuilder: (_, index) {
          final item = choices[index];
          return ListTile(
            leading: CircleAvatar(child: Icon(item.type.toLowerCase().contains('show') ? Icons.tv_outlined : Icons.movie_outlined)),
            title: Text(item.title),
            subtitle: Text(item.type),
            onTap: () => Navigator.pop(sheetContext, item),
          );
        },
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      final type = result.type.toLowerCase().contains('show') || result.type.toLowerCase().contains('series') || result.type.toLowerCase().contains('tv') ? 'show' : 'movie';
      selectedMediaMention = {'id': result.id, 'title': result.title, 'type': type};
    });
  }

  Map<String, dynamic> _buildStoryData() {
    final data = <String, dynamic>{};
    final location = locationController.text.trim();
    if (location.isNotEmpty) data['location'] = {'name': location};
    if (selectedPoll != null) data['poll'] = selectedPoll;
    if (selectedMediaMention != null) data['mediaMention'] = selectedMediaMention;
    if (mentions.isNotEmpty) data['mentions'] = mentions;
    if (selectedTrack != null) {
      data['music'] = {
        'trackId': selectedTrack!.id,
        'title': selectedTrack!.title,
        'artist': selectedTrack!.artist,
        'album': selectedTrack!.album,
        'audioUrl': selectedTrack!.audioUrl,
        'mode': musicMode,
        if (musicMode == 'lyrics') ...{
          'lyrics': selectedTrack!.lyrics,
          'lyricsStyle': {
            'fontSize': lyricsSize,
            'color': '#${lyricsColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
            'x': lyricsOffset.dx,
            'y': lyricsOffset.dy,
          },
        },
      };
    }
    return data;
  }

  Widget _preview() {
    final size = MediaQuery.sizeOf(context).width.clamp(280.0, 520.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: size,
        height: size * 1.55,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (selectedMedia != null && selectedMediaType == 'photo')
              Image.file(File(selectedMedia!.path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.photo_outlined, size: 56)))
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF20202A), Color(0xFF070707)]),
                ),
              ),
            if (bodyController.text.trim().isNotEmpty)
              Positioned(left: 18, right: 18, bottom: 22, child: Text(bodyController.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
            if (selectedPoll != null)
              Positioned(left: 16, right: 16, top: 90, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(selectedPoll!['question'].toString(), style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 6), for (final option in (selectedPoll!['options'] as List).take(4)) Chip(label: Text(option.toString()))])))),
            if (selectedTrack != null && musicMode == 'lyrics' && selectedTrack!.lyrics.trim().isNotEmpty)
              Positioned.fill(
                child: GestureDetector(
                  onPanUpdate: (details) => setState(() => lyricsOffset += details.delta),
                  child: Align(
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: lyricsOffset,
                      child: Text(
                        selectedTrack!.lyrics.trim().split('\n').take(4).join('\n'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: lyricsSize, fontWeight: FontWeight.w900, color: lyricsColor, shadows: const [Shadow(blurRadius: 10)]),
                      ),
                    ),
                  ),
                ),
              ),
            if (locationController.text.trim().isNotEmpty)
              Positioned(top: 20, left: 20, child: Chip(avatar: const Icon(Icons.location_on_outlined, size: 18), label: Text(locationController.text.trim()))),
            if (selectedMediaMention != null)
              Positioned(top: 20, right: 20, child: Chip(avatar: const Icon(Icons.movie_outlined, size: 18), label: Text(selectedMediaMention!['title'].toString()))),
          ],
        ),
      ),
    );
  }

  void _notice(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Story')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final editor = ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
              children: [
                TextField(controller: bodyController, onChanged: (_) => setState(() {}), maxLines: 5, maxLength: 1000, decoration: const InputDecoration(labelText: 'Story text', hintText: 'Share something with your friends…', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: expiresInHours,
                  decoration: const InputDecoration(labelText: 'Story lifetime', border: OutlineInputBorder()),
                  items: const [DropdownMenuItem(value: 24, child: Text('24 hours')), DropdownMenuItem(value: 48, child: Text('2 days')), DropdownMenuItem(value: 72, child: Text('3 days')), DropdownMenuItem(value: 168, child: Text('1 week'))],
                  onChanged: (value) => setState(() => expiresInHours = value ?? 24),
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(onPressed: _pickMedia, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(selectedMedia == null ? 'Add photo/video' : 'Change media')),
                  OutlinedButton.icon(onPressed: _pickMusic, icon: const Icon(Icons.music_note_rounded), label: const Text('Music')),
                  OutlinedButton.icon(onPressed: _pickPoll, icon: const Icon(Icons.poll_outlined), label: const Text('Poll')),
                  OutlinedButton.icon(onPressed: _pickFriendMentions, icon: const Icon(Icons.alternate_email_rounded), label: const Text('Friends')),
                  OutlinedButton.icon(onPressed: _pickMediaMention, icon: const Icon(Icons.movie_filter_outlined), label: const Text('Movie / show')),
                ]),
                const SizedBox(height: 10),
                TextField(controller: locationController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined), labelText: 'Location', border: OutlineInputBorder())),
                if (selectedTrack != null) ...[
                  const SizedBox(height: 14),
                  Card(child: ListTile(leading: const Icon(Icons.music_note_rounded), title: Text(selectedTrack!.title), subtitle: Text('${selectedTrack!.artist} • ${selectedTrack!.album}'), trailing: DropdownButton<String>(value: musicMode, items: const [DropdownMenuItem(value: 'audio', child: Text('Audio only')), DropdownMenuItem(value: 'lyrics', child: Text('Show lyrics'))], onChanged: (value) => setState(() => musicMode = value ?? 'audio')))),
                  if (musicMode == 'lyrics') ...[
                    Row(children: [const Text('Lyric size'), Expanded(child: Slider(min: 14, max: 48, value: lyricsSize, onChanged: (value) => setState(() => lyricsSize = value)))]),
                    Wrap(spacing: 8, children: [for (final color in [Colors.white, Colors.black, Colors.redAccent, Colors.amber, Colors.lightBlueAccent, Colors.pinkAccent]) ChoiceChip(label: const Text(''), selected: lyricsColor == color, avatar: CircleAvatar(backgroundColor: color), onSelected: (_) => setState(() => lyricsColor = color))]),
                    const SizedBox(height: 6),
                    const Text('Drag the lyrics in the preview to move them.'),
                  ],
                ],
                if (mentions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 6, children: [for (final mention in mentions) Chip(label: Text('@${mention['username'] ?? mention['displayName'] ?? 'friend'}'))])),
                if (selectedPoll != null) Padding(padding: const EdgeInsets.only(top: 10), child: Card(child: ListTile(leading: const Icon(Icons.poll_rounded), title: Text(selectedPoll!['question'].toString()), subtitle: Text((selectedPoll!['options'] as List).join(' • '))))),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: () => Navigator.pop(context, StoryDraft(body: bodyController.text.trim().isEmpty ? 'Shared a story' : bodyController.text.trim(), expiresInHours: expiresInHours, storyData: _buildStoryData(), media: selectedMedia, mediaType: selectedMediaType)), icon: const Icon(Icons.send_rounded), label: const Text('Share Story')),
              ],
            );
            if (!wide) return Column(children: [Expanded(child: editor)]);
            return Row(children: [Expanded(child: editor), Padding(padding: const EdgeInsets.all(18), child: SingleChildScrollView(child: _preview()))]);
          },
        ),
      ),
    );
  }
}

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({super.key, required this.story});
  final Map<String, dynamic> story;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  bool liked = false;
  bool viewing = false;
  VideoPlayerController? videoController;
  bool videoLoading = false;
  String? videoError;

  Map<String, dynamic> get reference => widget.story['mediaReference'] is Map
      ? Map<String, dynamic>.from(widget.story['mediaReference'] as Map)
      : <String, dynamic>{};

  Map<String, dynamic> get storyData => reference['storyData'] is Map
      ? Map<String, dynamic>.from(reference['storyData'] as Map)
      : <String, dynamic>{};

  String get authorName {
    final author = widget.story['author'];
    if (author is Map) {
      return author['display_name']?.toString() ?? author['username']?.toString() ?? 'Friend';
    }
    return 'Friend';
  }

  String? get authorUsername {
    final author = widget.story['author'];
    return author is Map ? author['username']?.toString() : null;
  }

  @override
  void initState() {
    super.initState();
    liked = widget.story['myReaction']?.toString() == '❤️';
    _recordView();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    final url = reference['videoUrl']?.toString();
    if (url == null || url.isEmpty) return;
    setState(() => videoLoading = true);
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    videoController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (mounted) setState(() => videoLoading = false);
    } catch (error) {
      await controller.dispose();
      if (mounted) setState(() { videoLoading = false; videoError = error.toString(); });
    }
  }

  @override
  void dispose() {
    videoController?.dispose();
    super.dispose();
  }

  Future<void> _recordView() async {
    if (viewing) return;
    viewing = true;
    try {
      await AppController.instance.backendApi.recordSocialStoryView(
        profileId: AppController.instance.currentProfile!.id,
        storyId: widget.story['id'].toString(),
      );
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    try {
      await AppController.instance.backendApi.reactToSocialStory(
        profileId: AppController.instance.currentProfile!.id,
        storyId: widget.story['id'].toString(),
        reaction: liked ? 'remove' : '❤️',
      );
      if (mounted) setState(() => liked = !liked);
    } catch (error) {
      _notice(error.toString());
    }
  }

  Future<void> _reply() async {
    final username = authorUsername;
    final profile = AppController.instance.currentProfile;
    if (username == null || username.trim().isEmpty || profile == null) return;
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reply to Story'),
        content: TextField(controller: controller, maxLines: 4, autofocus: true, decoration: const InputDecoration(hintText: 'Write a reply…')),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Send'))],
      ),
    );
    controller.dispose();
    if (body == null || body.isEmpty) return;
    try {
      final conversation = await AppController.instance.backendApi.createSocialConversation(profileId: profile.id, username: username);
      final id = conversation['conversation'] is Map ? conversation['conversation']['id']?.toString() : conversation['id']?.toString();
      if (id == null || id.isEmpty) throw StateError('Conversation was not created.');
      await AppController.instance.backendApi.sendSocialMessage(
        profileId: profile.id,
        conversationId: id,
        body: body,
        messageType: 'story_reply',
        mediaReference: {'type': 'story', 'storyId': widget.story['id'].toString(), 'storyAuthor': authorName},
      );
      _notice('Story reply sent.');
    } catch (error) {
      _notice(error.toString());
    }
  }

  Future<void> _reshare() async {
    try {
      await AppController.instance.backendApi.reshareSocialStory(
        profileId: AppController.instance.currentProfile!.id,
        storyId: widget.story['id'].toString(),
        expiresInHours: 24,
      );
      _notice('Story added to your story.');
    } catch (error) {
      _notice(error.toString());
    }
  }

  Future<void> _vote(int index) async {
    try {
      await AppController.instance.backendApi.voteSocialStoryPoll(
        profileId: AppController.instance.currentProfile!.id,
        storyId: widget.story['id'].toString(),
        optionIndex: index,
      );
      _notice('Vote recorded.');
    } catch (error) {
      _notice(error.toString());
    }
  }

  Future<void> _openAudio() async {
    final music = storyData['music'];
    if (music is! Map) return;
    final id = music['trackId']?.toString();
    final track = id == null
        ? null
        : MusicLibraryStore.instance.tracks.cast<MusicTrack?>().firstWhere(
            (item) => item?.id == id,
            orElse: () => null,
          );
    if (track == null) {
      _notice('This owned track is no longer in the music library.');
      return;
    }
    MusicPlaybackController.instance.play(track);
  }

  void _openViews() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewsScreen(storyId: widget.story['id'].toString())));
  }

  void _notice(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.replaceFirst('Exception: ', ''))));
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.story['isMine'] == true;
    final poll = storyData['poll'] is Map ? Map<String, dynamic>.from(storyData['poll'] as Map) : null;
    final location = storyData['location'] is Map ? storyData['location']['name']?.toString() : null;
    final mediaMention = storyData['mediaMention'] is Map ? Map<String, dynamic>.from(storyData['mediaMention'] as Map) : null;
    final mentions = (storyData['mentions'] as List?)
        ?.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList() ?? const <Map<String, dynamic>>[];
    final music = storyData['music'] is Map
    ? Map<String, dynamic>.from(storyData['music'] as Map)
    : null;

final lyrics = music != null && music['mode'] == 'lyrics'
    ? music['lyrics']?.toString()
    : null;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(authorName),
        actions: [
          if (mine) IconButton(tooltip: 'Views', onPressed: _openViews, icon: const Icon(Icons.visibility_outlined)),
          if (!mine) IconButton(tooltip: 'Reshare', onPressed: _reshare, icon: const Icon(Icons.repeat_rounded)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (videoController != null && videoController!.value.isInitialized)
                        GestureDetector(
                          onTap: () async {
                            final controller = videoController!;
                            if (controller.value.isPlaying) {
                              await controller.pause();
                            } else {
                              await controller.play();
                            }
                            if (mounted) setState(() {});
                          },
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: videoController!.value.size.width,
                              height: videoController!.value.size.height,
                              child: VideoPlayer(videoController!),
                            ),
                          ),
                        )
                      else if (reference['imageUrl']?.toString().isNotEmpty == true)
                        Image.network(reference['imageUrl'].toString(), fit: BoxFit.contain)
                      else if (reference['coverUrl']?.toString().isNotEmpty == true)
                        Image.network(reference['coverUrl'].toString(), fit: BoxFit.contain)
                      else if (videoLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (videoError != null)
                        Center(child: Text('Unable to play Story video.')),
                      if (widget.story['body']?.toString().trim().isNotEmpty == true)
                        Positioned(left: 20, right: 20, bottom: 24, child: Text(widget.story['body'].toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 12)]))),
                      if (location != null && location.isNotEmpty) Positioned(top: 18, left: 18, child: Chip(avatar: const Icon(Icons.location_on_outlined), label: Text(location))),
                      if (mediaMention != null) Positioned(top: 18, right: 18, child: Chip(avatar: const Icon(Icons.movie_outlined), label: Text(mediaMention['title']?.toString() ?? 'Media'))),
                      if (mentions.isNotEmpty) Positioned(left: 18, top: 126, right: 18, child: Wrap(spacing: 6, runSpacing: 6, children: [for (final mention in mentions) Chip(avatar: const Icon(Icons.alternate_email_rounded, size: 16), label: Text('@${mention['username']?.toString() ?? mention['displayName']?.toString() ?? 'friend'}'))])),
                      if (music != null) Positioned(left: 18, top: 70, right: 18, child: Card(child: ListTile(leading: const Icon(Icons.music_note_rounded), title: Text(music['title']?.toString() ?? 'Music'), subtitle: Text(music['artist']?.toString() ?? ''), trailing: IconButton(onPressed: _openAudio, icon: const Icon(Icons.play_arrow_rounded))))),
                      if (lyrics != null && lyrics.trim().isNotEmpty) Positioned(left: 24, right: 24, top: 170, child: Text(lyrics, textAlign: TextAlign.center, style: TextStyle(fontSize: (music?['lyricsStyle'] is Map ? ((music!['lyricsStyle']['fontSize'] as num?)?.toDouble() ?? 24) : 24), fontWeight: FontWeight.w900, color: _colorFromHex(music?['lyricsStyle'] is Map ? music!['lyricsStyle']['color']?.toString() : null)))),
                      if (poll != null)
                        Positioned(left: 18, right: 18, bottom: 100, child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(poll['question']?.toString() ?? 'Poll', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8), for (var i = 0; i < ((poll['options'] as List?)?.length ?? 0); i++) FilledButton.tonal(onPressed: () => _vote(i), child: Text((poll['options'] as List)[i].toString()))])))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      IconButton.filledTonal(onPressed: _toggleLike, icon: Icon(liked ? Icons.favorite : Icons.favorite_border), tooltip: 'Like'),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton.icon(onPressed: _reply, icon: const Icon(Icons.reply_rounded), label: const Text('Reply'))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _colorFromHex(String? value) {
    if (value == null) return Colors.white;
    final clean = value.replaceFirst('#', '');
    final parsed = int.tryParse(clean, radix: 16);
    return parsed == null ? Colors.white : Color(0xFF000000 | parsed);
  }
}

class StoryViewsScreen extends StatefulWidget {
  const StoryViewsScreen({super.key, required this.storyId});
  final String storyId;

  @override
  State<StoryViewsScreen> createState() => _StoryViewsScreenState();
}

class _StoryViewsScreenState extends State<StoryViewsScreen> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await AppController.instance.backendApi.getSocialStoryInsights(
        profileId: AppController.instance.currentProfile!.id,
        storyId: widget.storyId,
      );
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewers = (data?['viewers'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Story Views')),
      body: error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)))
          : data == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      Card(child: ListTile(leading: const Icon(Icons.visibility_outlined), title: Text('${data!['totalViews'] ?? 0} total views'), subtitle: Text('${data!['uniqueViewers'] ?? 0} people • ${data!['likes'] ?? 0} likes'))),
                      const SizedBox(height: 12),
                      if (viewers.isEmpty) const Card(child: ListTile(title: Text('No views yet'), subtitle: Text('When friends watch your Story, their repeat-view count will appear here.'))),
                      for (final viewer in viewers)
                        Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Text(_initial(viewer['displayName']?.toString() ?? viewer['username']?.toString() ?? 'User'))),
                            title: Text(viewer['displayName']?.toString() ?? viewer['username']?.toString() ?? 'User'),
                            subtitle: Text('Has seen your Story ${viewer['viewCount'] ?? 0} time${(viewer['viewCount'] ?? 0) == 1 ? '' : 's'}'),
                            trailing: viewer['liked'] == true ? const Icon(Icons.favorite, color: Colors.redAccent) : null,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  String _initial(String value) => value.trim().isEmpty ? '?' : value.trim().substring(0, 1).toUpperCase();
}
