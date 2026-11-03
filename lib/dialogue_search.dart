import 'package:flutter/material.dart';

import 'app_core.dart';
import 'backend_api.dart';
import 'player.dart';
import 'core/services/tv_programming_service.dart';

const _dialogueAccent = Color(0xFF8B7CFF);

class DialogueSearchScreen extends StatefulWidget {
  const DialogueSearchScreen({super.key});

  @override
  State<DialogueSearchScreen> createState() => _DialogueSearchScreenState();
}

class _DialogueSearchScreenState extends State<DialogueSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  List<Map<String, dynamic>> _matches = <Map<String, dynamic>>[];
  Map<String, dynamic>? _indexSummary;
  String? _error;
  bool _hasMore = false;
  bool _hasSearched = false;
  bool _indexing = false;
  bool _searching = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _indexSubtitles() async {
    if (_searching) return;
    setState(() {
      _indexing = true;
      _error = null;
      _indexSummary = null;
      _matches = <Map<String, dynamic>>[];
      _hasSearched = false;
    });
    try {
      final controller = AppController.instance;
      await controller.syncHomeServerLibrary();
      final summary = await controller.backendApi.indexLibrarySubtitles();
      if (!mounted) return;
      setState(() {
        _indexSummary = summary;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) setState(() => _indexing = false);
    }
  }

  Future<void> _search() async {
    if (_indexing || _searching) return;
    final query = _queryController.text.trim();
    if (query.length < 2 || query.length > 160) {
      setState(() {
        _error = 'Enter between 2 and 160 characters to search.';
        _matches = <Map<String, dynamic>>[];
        _hasSearched = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _hasMore = false;
      _hasSearched = false;
    });
    try {
      final result =
          await AppController.instance.backendApi.searchLibrarySubtitles(query);
      if (!mounted) return;
      setState(() {
        final rawMatches = result['matches'];
        _matches = rawMatches is List
            ? rawMatches
                .whereType<Map>()
                .map((match) => Map<String, dynamic>.from(match))
                .toList(growable: false)
            : <Map<String, dynamic>>[];
        _hasMore = result['hasMore'] == true;
        _hasSearched = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _matches = <Map<String, dynamic>>[];
        _hasMore = false;
        _hasSearched = false;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final accessibleItems = <String, MediaItem>{
      for (final item in controller.library)
        if (item.isAccessibleTo(profile) &&
            TvProgrammingService.eligibleForProfile(item, profile))
          item.id: item,
    };
    final playableMatches = _matches
        .map((match) => _DialogueMatch.fromJson(match, accessibleItems))
        .whereType<_DialogueMatch>()
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        title: const Text('Search dialogue'),
        backgroundColor: const Color(0xFF11111A),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Find a line across your home-server movies and episodes.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          const Text(
            'Index .srt or .vtt subtitle files stored beside their video files. '
            'The server keeps this index in memory; rebuild it after a server restart.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _queryController,
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {
              _hasSearched = false;
              _matches = <Map<String, dynamic>>[];
              _error = null;
            }),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search dialogue',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Search dialogue',
                onPressed: _searching || _indexing ? null : _search,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _indexing || _searching ? null : _indexSubtitles,
              icon: _indexing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.subtitles_rounded),
              label:
                  Text(_indexing ? 'Indexing subtitles…' : 'Index / refresh'),
            ),
          ),
          if (_indexSummary != null) ...[
            const SizedBox(height: 12),
            _IndexSummaryCard(summary: _indexSummary!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_matches.isNotEmpty && playableMatches.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                'Matches were found, but their media is not available to the selected profile. Scan the home-server library and check profile access.',
                style: TextStyle(color: Colors.white60),
              ),
            )
          else if (_matches.isNotEmpty) ...<Widget>[
            ...playableMatches.map(
              (match) => Card(
                color: const Color(0xFF171722),
                child: ListTile(
                  leading: const Icon(
                    Icons.play_circle_outline,
                    color: _dialogueAccent,
                  ),
                  title: Text(
                    '${match.media.title}  ·  ${_formatTimestamp(match.startMs)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    match.text,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PlayerScreen(
                        media: match.media,
                        initialPositionSeconds: match.startMs ~/ 1000,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_hasMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Showing the first 100 matches. Refine your search to see fewer, more relevant results.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
          ] else if (_hasSearched && _error == null)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                'No dialogue matches. Try another phrase or refresh the subtitle index.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatTimestamp(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    final time = '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
    return hours > 0 ? '$hours:$time' : time;
  }
}

class _DialogueMatch {
  const _DialogueMatch({
    required this.media,
    required this.startMs,
    required this.text,
  });

  final MediaItem media;
  final int startMs;
  final String text;

  static _DialogueMatch? fromJson(
    Map<String, dynamic> json,
    Map<String, MediaItem> accessibleItems,
  ) {
    final mediaId = json['mediaId']?.toString();
    final media = mediaId == null ? null : accessibleItems[mediaId];
    if (media == null) return null;
    final startMs = (json['startMs'] as num?)?.toInt();
    final text = json['text']?.toString().trim() ?? '';
    final playbackUrl = media.playbackUrl?.trim() ?? '';
    final playbackUri = playbackUrl.isEmpty ? null : Uri.tryParse(playbackUrl);
    if (startMs == null ||
        startMs < 0 ||
        text.isEmpty ||
        playbackUri == null ||
        !playbackUri.hasAuthority ||
        (playbackUri.scheme != 'http' && playbackUri.scheme != 'https')) {
      return null;
    }
    return _DialogueMatch(media: media, startMs: startMs, text: text);
  }
}

class _IndexSummaryCard extends StatelessWidget {
  const _IndexSummaryCard({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final files = (summary['indexedFiles'] as num?)?.toInt() ?? 0;
    final cues = (summary['indexedCues'] as num?)?.toInt() ?? 0;
    final skipped = (summary['skippedFiles'] as num?)?.toInt() ?? 0;
    final warnings = summary['warnings'] is List
        ? (summary['warnings'] as List)
            .map((warning) => warning.toString())
            .toList(growable: false)
        : const <String>[];
    return Card(
      color: const Color(0xFF171722),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indexed $files subtitle files and $cues dialogue lines'
              '${skipped == 0 ? '.' : ' ($skipped skipped).'}',
              style: const TextStyle(color: Colors.white70),
            ),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  warning,
                  style: const TextStyle(color: Colors.amberAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
