import 'package:flutter/material.dart';

import 'app_core.dart';
import 'catalog_poster_image.dart';
import 'details.dart';
import 'player.dart';
import 'smart_search.dart';
import 'core/services/tv_programming_service.dart';
import 'backend_api.dart';

const _identifierAccent = Color(0xFF8B7CFF);

enum _IdentifierMode { quote, scene, description }

/// The former dialogue-search destination now provides all three media
/// identification methods while keeping the old widget name as a route
/// compatibility alias for existing navigation and deep links.
class DialogueSearchScreen extends StatefulWidget {
  const DialogueSearchScreen({super.key});

  @override
  State<DialogueSearchScreen> createState() => _DialogueSearchScreenState();
}

class _DialogueSearchScreenState extends State<DialogueSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  _IdentifierMode _mode = _IdentifierMode.quote;
  List<_IdentifierMatch> _matches = <_IdentifierMatch>[];
  Map<String, dynamic>? _indexSummary;
  String? _error;
  String? _notice;
  bool _hasMore = false;
  bool _hasSearched = false;
  bool _indexing = false;
  bool _searching = false;
  String? _externalSubtitleLookupId;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _indexSubtitles() async {
    if (_searching || _indexing) return;
    setState(() {
      _indexing = true;
      _error = null;
      _notice = null;
      _indexSummary = null;
      _matches = <_IdentifierMatch>[];
      _hasSearched = false;
    });
    try {
      final controller = AppController.instance;
      await controller.syncHomeServerLibrary();
      final summary = await controller.backendApi.indexLibrarySubtitles();
      if (!mounted) return;
      setState(() => _indexSummary = summary);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _indexing = false);
    }
  }

  Future<void> _findOpenSubtitlesUploads(MediaItem media) async {
    if (_externalSubtitleLookupId != null) return;
    final isSeries = _isSeriesMedia(media);
    final type = isSeries ? 'all' : 'movie';
    setState(() => _externalSubtitleLookupId = media.id);
    try {
      final response =
          await AppController.instance.backendApi.searchOpenSubtitles(
        query: media.title,
        type: type,
        languages: 'en,es',
        year: isSeries ? null : media.releaseYear,
      );
      final raw = response['results'];
      final results = raw is List
          ? raw
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                  child: Text('OpenSubtitles · ${media.title}',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: Text(
                    'These are subtitle uploads listed for this title. OpenSubtitles does not search the full text of every subtitle for a remembered quote.',
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                ),
                if (results.isEmpty)
                  Expanded(
                      child: Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(response['message']?.toString() ??
                                  'No subtitle uploads found.'))))
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = results[index];
                        final title = result['title']?.toString().trim();
                        final language =
                            result['language']?.toString().trim() ?? '';
                        final release =
                            result['release']?.toString().trim() ?? '';
                        final count =
                            result['downloadCount']?.toString() ?? '0';
                        final year = result['year']?.toString().trim() ?? '';
                        final episodeTitle =
                            result['episodeTitle']?.toString().trim() ?? '';
                        final season =
                            result['seasonNumber']?.toString().trim() ?? '';
                        final episode =
                            result['episodeNumber']?.toString().trim() ?? '';
                        final meta = <String>[
                          if (episodeTitle.isNotEmpty && episodeTitle != title)
                            episodeTitle,
                          if (season.isNotEmpty || episode.isNotEmpty)
                            'S${season.padLeft(2, '0')}E${episode.padLeft(2, '0')}',
                          if (language.isNotEmpty) language.toUpperCase(),
                          if (year.isNotEmpty) year,
                          if (release.isNotEmpty) release,
                          '$count downloads',
                          if (result['trustedUploader'] == true)
                            'Trusted uploader',
                          if (result['aiTranslated'] == true ||
                              result['machineTranslated'] == true)
                            'Machine/AI translated',
                        ].join(' · ');
                        return ListTile(
                          leading: Icon(
                              result['trustedUploader'] == true
                                  ? Icons.verified_rounded
                                  : Icons.subtitles_rounded,
                              color: const Color(0xFF8B7CFF)),
                          title: Text(
                              (title == null || title.isEmpty)
                                  ? 'Subtitle upload'
                                  : title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(meta,
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                error.toString().replaceFirst('BackendApiException: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _externalSubtitleLookupId = null);
    }
  }

  bool _isSeriesMedia(MediaItem media) {
    final type = media.type.toLowerCase();
    return type.contains('tv') ||
        type.contains('series') ||
        type.contains('show') ||
        type.contains('episode') ||
        type.contains('special');
  }

  Future<void> _search() async {
    if (_indexing || _searching) return;
    final query = _queryController.text.trim();
    if (query.length < 2 || query.length > 500) {
      setState(() {
        _error = 'Enter between 2 and 500 characters.';
        _matches = <_IdentifierMatch>[];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
      _notice = null;
      _hasMore = false;
      _hasSearched = false;
      _matches = <_IdentifierMatch>[];
    });

    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final accessibleItems = <String, MediaItem>{
      for (final item in controller.library)
        if (item.isAccessibleTo(profile) &&
            TvProgrammingService.eligibleForProfile(item, profile))
          item.id: item,
    };
    // Scene and premise searches can also use catalog recommendations already
    // loaded by the app. These are still profile-filtered; a catalog-only hit
    // is labeled as a suggestion and never receives a local playback action.
    final accessibleCatalogItems = <String, MediaItem>{...accessibleItems};
    for (final item in controller.recommendations) {
      if (item.isAccessibleTo(profile) &&
          TvProgrammingService.eligibleForProfile(item, profile)) {
        accessibleCatalogItems.putIfAbsent(item.id, () => item);
      }
    }

    final results = <_IdentifierMatch>[];
    var transcriptSearchFailed = false;
    String? transcriptError;

    try {
      if (_mode == _IdentifierMode.quote || _mode == _IdentifierMode.scene) {
        try {
          // In Scene mode, a quoted remembered line is searched independently
          // from the surrounding context. This preserves exact timestamps
          // while the unquoted context is used below for title disambiguation.
          for (final subtitleQuery in _subtitleQueries(query)) {
            final response = await controller.backendApi
                .searchLibrarySubtitles(subtitleQuery);
            final rawMatches = response['matches'];
            if (rawMatches is List) {
              for (final raw in rawMatches.whereType<Map>()) {
                final match = Map<String, dynamic>.from(raw);
                final mediaId = match['mediaId']?.toString();
                final media = mediaId == null ? null : accessibleItems[mediaId];
                final startMs = (match['startMs'] as num?)?.toInt();
                final evidence = match['text']?.toString().trim() ?? '';
                if (media == null || startMs == null || startMs < 0) continue;
                final isDuplicate = results.any((entry) =>
                    entry.media.id == media.id && entry.startMs == startMs);
                if (isDuplicate) continue;
                results.add(_IdentifierMatch(
                  media: media,
                  evidence: evidence,
                  sourceLabel: 'Subtitle dialogue match',
                  startMs: startMs,
                  score: 1.0,
                ));
              }
            }
            _hasMore = _hasMore || response['hasMore'] == true;
          }
        } catch (error) {
          transcriptSearchFailed = true;
          transcriptError = error.toString();
        }
      }

      if (_mode == _IdentifierMode.scene ||
          _mode == _IdentifierMode.description) {
        final metadataResults =
            _searchMetadata(query, accessibleCatalogItems.values);
        for (var index = 0; index < metadataResults.length; index++) {
          final media = metadataResults[index];
          final isOwnedLibraryItem = accessibleItems.containsKey(media.id);
          final existingIndex =
              results.indexWhere((entry) => entry.media.id == media.id);
          final evidence = _metadataEvidence(media, query);
          final metadataMatch = _IdentifierMatch(
            media: media,
            evidence: evidence,
            sourceLabel: isOwnedLibraryItem
                ? 'Library metadata match'
                : 'Catalog suggestion — not in your library',
            score: 0.72 - (index * 0.005),
          );
          if (existingIndex >= 0) {
            final previous = results[existingIndex];
            results[existingIndex] = _IdentifierMatch(
              media: previous.media,
              evidence: previous.evidence,
              sourceLabel: 'Subtitle + library metadata match',
              startMs: previous.startMs,
              score: previous.score + 0.35,
            );
          } else {
            results.add(metadataMatch);
          }
        }
      }

      results.sort((left, right) => right.score.compareTo(left.score));
      if (!mounted) return;
      setState(() {
        _hasMore = _hasMore || results.length > 50;
        _matches = results.take(50).toList(growable: false);
        _hasSearched = true;
        if (transcriptSearchFailed && _mode == _IdentifierMode.scene) {
          _notice =
              'Subtitle search was unavailable. These scene suggestions use profile-accessible library/catalog metadata only; index subtitles to find exact dialogue and timestamps.';
        } else if (transcriptSearchFailed &&
            _mode == _IdentifierMode.quote &&
            _matches.isEmpty) {
          _error = transcriptError ??
              'Subtitle search is not ready. Index your subtitle files first.';
        } else if (_mode == _IdentifierMode.scene &&
            _matches.isNotEmpty &&
            _matches.every((match) => match.startMs == null)) {
          _notice =
              'No subtitle timestamp matched this scene description. These are title suggestions based on profile-accessible metadata, not verified scene identifications.';
        } else if (_mode == _IdentifierMode.description) {
          _notice =
              'Description matches are ranked from profile-accessible library and catalog metadata already loaded by the app. Results are suggestions, not guaranteed identifications.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _hasSearched = false;
        _matches = <_IdentifierMatch>[];
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  List<String> _subtitleQueries(String query) {
    if (_mode != _IdentifierMode.scene) return <String>[query];
    final quotedPhrases = RegExp(r'["“]([^"”]{2,500})["”]')
        .allMatches(query)
        .map((match) => match.group(1)?.trim() ?? '')
        .where((phrase) => phrase.length >= 2)
        .take(3)
        .toList(growable: false);
    return quotedPhrases.isEmpty ? <String>[query] : quotedPhrases;
  }

  List<MediaItem> _searchMetadata(
    String query,
    Iterable<MediaItem> accessibleItems,
  ) {
    final allowed = <String, MediaItem>{
      for (final item in accessibleItems) item.id: item,
    };
    if (allowed.isEmpty) return <MediaItem>[];

    // SmartSearch already combines title, synopsis, genre, themes, tags,
    // characters, franchise, country and curated plot aliases. Restrict its
    // output back to the selected profile's accessible library/catalog records.
    return SmartSearch.search(query, allowed.values.toList(growable: false))
        .where((item) => allowed.containsKey(item.id))
        .toSet()
        .take(30)
        .toList(growable: false);
  }

  String _metadataEvidence(MediaItem media, String query) {
    final normalizedQuery = _normalize(query);
    final fields = <String>[
      if ((media.description ?? '').trim().isNotEmpty)
        'Description: ${media.description}',
      if (media.genres.isNotEmpty) 'Genres: ${media.genres.join(', ')}',
      if (media.themes.isNotEmpty) 'Themes: ${media.themes.join(', ')}',
      if (media.tones.isNotEmpty) 'Tone: ${media.tones.join(', ')}',
      if (media.tags.isNotEmpty) 'Tags: ${media.tags.join(', ')}',
      if (media.culturalSettings.isNotEmpty)
        'Setting: ${media.culturalSettings.join(', ')}',
      if (media.culturalInspirations.isNotEmpty)
        'Cultural context: ${media.culturalInspirations.join(', ')}',
      if ((media.countryOfOrigin ?? '').trim().isNotEmpty)
        'Origin: ${media.countryOfOrigin}',
      if ((media.originalLanguage ?? '').trim().isNotEmpty)
        'Original language: ${media.originalLanguage}',
      if (media.characters.isNotEmpty)
        'Characters: ${media.characters.join(', ')}',
    ];
    for (final field in fields) {
      final normalizedField = _normalize(field);
      final terms = normalizedQuery
          .split(' ')
          .where((word) => word.length > 2)
          .toList(growable: false);
      if (terms.any(normalizedField.contains)) {
        return field.length > 260 ? '${field.substring(0, 257)}…' : field;
      }
    }
    return fields.isEmpty
        ? 'Matched a related title or plot clue in your catalog.'
        : (fields.first.length > 260
            ? '${fields.first.substring(0, 257)}…'
            : fields.first);
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  @override
  Widget build(BuildContext context) {
    final modeDescription = switch (_mode) {
      _IdentifierMode.quote =>
        'Enter dialogue you remember. Search works across indexed .srt and .vtt subtitle files and can find a quote split over neighboring caption lines.',
      _IdentifierMode.scene =>
        'Describe what happens, who is there, or what happens before or after the scene. Put any remembered line in quotation marks so we can search it separately and retain its timestamp.',
      _IdentifierMode.description =>
        'Describe the premise, setting, characters, genre, or anything else you remember. Results are ranked from metadata already loaded for your profile.',
    };
    final hint = switch (_mode) {
      _IdentifierMode.quote => 'Example: Avengers assemble',
      _IdentifierMode.scene =>
        'Example: “Avengers assemble” after Hulk snaps his fingers and the heroes return',
      _IdentifierMode.description =>
        'Example: British supernatural show about teenagers who are werewolves',
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(
        title: const Text('Identify Movie or Show'),
        backgroundColor: const Color(0xFF11111A),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Row(
            children: [
              Icon(Icons.movie_filter_rounded,
                  color: _identifierAccent, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'What do you remember?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Find a movie, series, or a specific moment from a line, scene, or description.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFF171722),
              borderRadius: BorderRadius.circular(11),
              border:
                  Border.all(color: _identifierAccent.withValues(alpha: .35)),
            ),
            child: const Text(
              'Dialogue matching searches subtitle files indexed from your own library. OpenSubtitles can discover subtitle uploads for a known title, but it does not offer a global search across every subtitle transcript by remembered quote.',
              style:
                  TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
            ),
          ),
          const SizedBox(height: 18),
          SegmentedButton<_IdentifierMode>(
            segments: const <ButtonSegment<_IdentifierMode>>[
              ButtonSegment<_IdentifierMode>(
                value: _IdentifierMode.quote,
                label: Text('Quote'),
                icon: Icon(Icons.format_quote_rounded),
              ),
              ButtonSegment<_IdentifierMode>(
                value: _IdentifierMode.scene,
                label: Text('Scene'),
                icon: Icon(Icons.movie_creation_outlined),
              ),
              ButtonSegment<_IdentifierMode>(
                value: _IdentifierMode.description,
                label: Text('Description'),
                icon: Icon(Icons.notes_rounded),
              ),
            ],
            selected: <_IdentifierMode>{_mode},
            onSelectionChanged: (selection) {
              setState(() {
                _mode = selection.first;
                _matches = <_IdentifierMatch>[];
                _error = null;
                _notice = null;
                _hasSearched = false;
                _hasMore = false;
              });
            },
            showSelectedIcon: false,
          ),
          const SizedBox(height: 14),
          Text(
            modeDescription,
            style: const TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _queryController,
            minLines: 3,
            maxLines: 7,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {
              _hasSearched = false;
              _matches = <_IdentifierMatch>[];
              _error = null;
              _notice = null;
            }),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintMaxLines: 3,
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 54),
                child: Icon(Icons.search_rounded),
              ),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Identify',
                onPressed: _searching || _indexing ? null : _search,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _searching || _indexing ? null : _search,
                  icon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_searching ? 'Identifying…' : 'Identify'),
                ),
              ),
              if (_mode != _IdentifierMode.description) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _indexing || _searching ? null : _indexSubtitles,
                  icon: _indexing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.subtitles_rounded),
                  label: Text(_indexing ? 'Indexing…' : 'Index subtitles'),
                ),
              ],
            ],
          ),
          if (_indexSummary != null) ...[
            const SizedBox(height: 12),
            _IndexSummaryCard(summary: _indexSummary!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _MessageCard(message: _error!, isError: true),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 12),
            _MessageCard(message: _notice!),
          ],
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_hasSearched && _matches.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 28),
              child: Text(
                'No confident matches were found in the accessible library. Try another phrase, add more scene details, or check that the title has useful metadata and subtitles.',
                style: TextStyle(color: Colors.white60, height: 1.45),
              ),
            )
          else if (_matches.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              _mode == _IdentifierMode.quote
                  ? 'Dialogue matches'
                  : _mode == _IdentifierMode.scene
                      ? 'Scene and story matches'
                      : 'Best description matches',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final match in _matches) _buildMatchCard(context, match),
            if (_hasMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'More dialogue matches exist. Refine the quote to narrow the results.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, _IdentifierMatch match) {
    final media = match.media;
    final time =
        match.startMs == null ? null : _formatTimestamp(match.startMs!);
    final typeLabel = _isSeriesMedia(media) ? 'Series' : 'Movie';
    final yearLabel =
        media.releaseYear == null ? '' : ' · ${media.releaseYear}';
    final isLookingUp = _externalSubtitleLookupId == media.id;
    return Card(
      color: const Color(0xFF171722),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 58,
                height: 86,
                child: CatalogPosterImage(
                    media: media, width: 58, height: 86, forcePosterOnly: true),
              ),
            ),
            title: Text(media.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                <String>[
                  '$typeLabel$yearLabel',
                  if (time != null) 'Scene at $time',
                  match.sourceLabel,
                  match.evidence,
                ].join('\n'),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
            ),
            trailing: match.startMs != null &&
                    (media.playbackUrl?.trim().isNotEmpty ?? false)
                ? IconButton(
                    tooltip: 'Jump to matching scene',
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => PlayerScreen(
                                media: media,
                                initialPositionSeconds:
                                    match.startMs! ~/ 1000))),
                    icon: const Icon(Icons.play_circle_fill_rounded,
                        color: _identifierAccent, size: 30),
                  )
                : const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => MediaDetailsScreen(media: media))),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 10, 7),
              child: TextButton.icon(
                onPressed: _externalSubtitleLookupId != null
                    ? null
                    : () => _findOpenSubtitlesUploads(media),
                icon: isLookingUp
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.subtitles_rounded, size: 17),
                label: Text(isLookingUp
                    ? 'Searching OpenSubtitles…'
                    : 'Find subtitle uploads'),
              ),
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

class _IdentifierMatch {
  const _IdentifierMatch({
    required this.media,
    required this.evidence,
    required this.sourceLabel,
    required this.score,
    this.startMs,
  });

  final MediaItem media;
  final String evidence;
  final String sourceLabel;
  final double score;
  final int? startMs;
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.isError = false});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF171722),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            style: TextStyle(
              color: isError ? Colors.redAccent : Colors.white70,
              height: 1.4,
            ),
          ),
        ),
      );
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
