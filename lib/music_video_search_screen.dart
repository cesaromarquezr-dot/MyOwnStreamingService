// FILE: `lib/music_video_search_screen.dart`.
// Purpose: Find embeddable YouTube music videos using song/artist metadata
// while keeping the YouTube API key on the authenticated backend.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'app_core.dart';

class MusicVideoSearchScreen extends StatefulWidget {
  const MusicVideoSearchScreen({
    super.key,
    required this.title,
    required this.artist,
    this.initialVideo,
  });

  final String title;
  final String artist;
  final Map<String, dynamic>? initialVideo;

  @override
  State<MusicVideoSearchScreen> createState() => _MusicVideoSearchScreenState();
}

class _MusicVideoSearchScreenState extends State<MusicVideoSearchScreen> {
  late final TextEditingController _queryController;
  final List<Map<String, dynamic>> _videos = <Map<String, dynamic>>[];
  YoutubePlayerController? _playerController;
  String? _selectedVideoId;
  String? _error;
  String? _message;
  bool? _providerConfigured;
  bool _loading = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    final artist = widget.artist.trim();
    final title = widget.title.trim();
    _queryController = TextEditingController(
      text: <String>[
        if (artist.isNotEmpty) artist,
        if (title.isNotEmpty) title,
        'official music video',
      ].join(' '),
    );
    final initialVideo = widget.initialVideo;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (initialVideo != null &&
          RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(initialVideo['videoId']?.toString() ?? '')) {
        setState(() {
          _providerConfigured = true;
          _videos.add(Map<String, dynamic>.from(initialVideo));
          _message = 'Video match found for this imported track.';
        });
        _playVideo(initialVideo, autoPlay: true);
      } else {
        _searchVideos();
      }
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _playerController?.close();
    super.dispose();
  }

  Future<void> _searchVideos() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _error = 'Enter a song or artist to search for a music video.';
        _videos.clear();
      });
      return;
    }

    if (!AppController.instance.isBackendAuthenticated) {
      setState(() {
        _providerConfigured = false;
        _message = 'Sign in to the MyOwnStreamingService backend to load video matches inside the app. You can still search YouTube directly.';
        _error = null;
        _videos.clear();
      });
      return;
    }

    final requestId = ++_requestId;
    _playerController?.close();
    _playerController = null;
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
      _selectedVideoId = null;
      _providerConfigured = null;
      _videos.clear();
    });

    try {
      final payload = await AppController.instance.backendApi.searchMusicVideos(
        query,
        limit: 8,
      );
      if (!mounted || requestId != _requestId) return;
      final rawItems = payload['items'];
      final items = rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) =>
                  (item['videoId']?.toString() ?? '').isNotEmpty &&
                  (item['watchUrl']?.toString() ?? '').startsWith('https://'))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      setState(() {
        _providerConfigured = payload['configured'] == true;
        _message = (payload['message']?.toString() ?? '').trim();
        _videos
          ..clear()
          ..addAll(items);
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error
            .toString()
            .replaceFirst('BackendApiException: ', '');
        _message = null;
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  void _playVideo(Map<String, dynamic> video, {bool autoPlay = false}) {
    final videoId = video['videoId']?.toString() ?? '';
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) return;
    _playerController?.close();
    setState(() {
      _selectedVideoId = videoId;
      _playerController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: autoPlay,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: true,
          playsInline: true,
        ),
      );
    });
  }

  Future<void> _openYouTubeSearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    final uri = Uri.https('www.youtube.com', '/results', <String, String>{
      'search_query': query,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openVideoUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https' || uri.host != 'www.youtube.com') {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        title: const Text(
          'Music Videos',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          Text(
            '${widget.artist.trim().isEmpty ? 'Song' : widget.artist.trim()}${widget.title.trim().isEmpty ? '' : ' · ${widget.title.trim()}'}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchVideos(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Song, artist, or music video',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white.withValues(alpha: .06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: _loading ? null : _searchVideos,
              icon: _loading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore_rounded),
              label: Text(_loading ? 'Searching videos…' : 'Find music videos'),
            ),
          ),
          if (_playerController != null) ...<Widget>[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: YoutubePlayer(
                controller: _playerController!,
                aspectRatio: 16 / 9,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Video playback is provided by YouTube. Some videos may be restricted or removed by their uploader.',
              style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
            ),
          ],
          if (_loading) ...<Widget>[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            _notice('Video search failed', _error!),
          ],
          if (_providerConfigured == false) ...<Widget>[
            const SizedBox(height: 14),
            _notice(
              'YouTube API setup needed',
              _message ?? 'Set YOUTUBE_API_KEY in Backend/.env to show matching videos here. Spotify supplies song metadata; YouTube supplies the video search results.',
            ),
          ] else if (_message != null && _message!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _notice('Video search note', _message!),
          ],
          if (_videos.isNotEmpty) ...<Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 8),
              child: Text(
                'Matching YouTube videos',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            for (final video in _videos) _videoTile(video),
          ] else if (!_loading && _error == null) ...<Widget>[
            const SizedBox(height: 14),
            const Text(
              'No in-app video matches are available for this search yet. You can still open the YouTube search results.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _openYouTubeSearch,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Search directly on YouTube'),
          ),
        ],
      ),
    );
  }

  Widget _videoTile(Map<String, dynamic> video) {
    final videoId = video['videoId']?.toString() ?? '';
    final thumbnailUrl = video['thumbnailUrl']?.toString() ?? '';
    final channel = video['channelTitle']?.toString().trim() ?? '';
    final publishedAt = video['publishedAt']?.toString() ?? '';
    final publishedYear = publishedAt.length >= 4 ? publishedAt.substring(0, 4) : '';
    final selected = videoId == _selectedVideoId;
    final subtitle = <String>[
      if (channel.isNotEmpty) channel,
      if (publishedYear.isNotEmpty) publishedYear,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF26352D)
            : Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: selected ? Colors.greenAccent.withValues(alpha: .4) : Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: thumbnailUrl.startsWith('https://')
              ? Image.network(
                  thumbnailUrl,
                  width: 100,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _thumbnailPlaceholder(),
                )
              : _thumbnailPlaceholder(),
        ),
        title: Text(
          (video['title'] ?? 'Untitled video').toString(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: subtitle.isEmpty
            ? null
            : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
        trailing: Wrap(
          spacing: -8,
          children: <Widget>[
            IconButton(
              tooltip: selected ? 'Selected video' : 'Play video in app',
              onPressed: () => _playVideo(video),
              icon: Icon(
                selected ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded,
                color: selected ? Colors.lightGreenAccent : Colors.white,
                size: 28,
              ),
            ),
            IconButton(
              tooltip: 'Open on YouTube',
              onPressed: () => _openVideoUrl(video['watchUrl']?.toString() ?? ''),
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
            ),
          ],
        ),
        onTap: () => _playVideo(video),
      ),
    );
  }

  Widget _thumbnailPlaceholder() => Container(
        width: 100,
        height: 60,
        color: Colors.white10,
        alignment: Alignment.center,
        child: const Icon(Icons.music_video_rounded, color: Colors.white54),
      );

  Widget _notice(String title, String body) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: Colors.white70, height: 1.4)),
          ],
        ),
      );
}
