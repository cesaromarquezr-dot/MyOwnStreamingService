import 'dart:async';

// FILE: `lib/rating_system.dart`.
// Purpose: Displays provider ratings and profile-private 0–100 personal scores.
// Provider scores and personal scores are never combined.

import 'package:material_ui/material_ui.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'localization.dart';
import 'user_rating_store.dart';
import 'core/services/cinematic_title_metadata_service.dart';

/// Caches verified TMDB audience ratings for compact library cards and sorting.
/// Missing matches are cached for this app session; failed requests remain retryable.
class TmdbMediaRatingStore {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final Map<String, Map<String, dynamic>?> _cache =
      <String, Map<String, dynamic>?>{};
  static final Map<String, Future<Map<String, dynamic>?>> _inFlight =
      <String, Future<Map<String, dynamic>?>>{};
  static final List<Completer<void>> _slotWaiters = <Completer<void>>[];
  static int _activeRequests = 0;

  static Future<void> _acquireRequestSlot() async {
    if (_activeRequests < 3) {
      _activeRequests++;
      return;
    }
    final waiter = Completer<void>();
    _slotWaiters.add(waiter);
    await waiter.future;
  }

  static void _releaseRequestSlot() {
    if (_slotWaiters.isNotEmpty) {
      _slotWaiters.removeAt(0).complete();
    } else {
      _activeRequests = (_activeRequests - 1).clamp(0, 3).toInt();
    }
  }

  static String _key(String title, bool isTv, int? year) =>
      '${isTv ? 'tv' : 'movie'}|${title.trim().toLowerCase()}|${year ?? ''}';

  static Future<Map<String, dynamic>?> ratingFor({
    required String title,
    required bool isTv,
    int? year,
  }) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || !CinematicTitleMetadataService.isConfigured) {
      return Future<Map<String, dynamic>?>.value(null);
    }
    final key = _key(cleanTitle, isTv, year);
    if (_cache.containsKey(key)) {
      return Future<Map<String, dynamic>?>.value(_cache[key]);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final request = () async {
      await _acquireRequestSlot();
      try {
        final metadata = await CinematicTitleMetadataService.lookupHomeMetadata(
          title: cleanTitle,
          isTv: isTv,
          year: year,
        );
        final rawScore = metadata?['tmdbVoteAverage'];
        final score = rawScore is num
            ? rawScore.toDouble()
            : double.tryParse(rawScore?.toString() ?? '');
        final votes = metadata?['tmdbVoteCount'];
        final normalized = score != null && score > 0
            ? <String, dynamic>{
                'score': score.clamp(0, 10).toDouble(),
                'voteCount': votes is num ? votes.toInt() : 0,
              }
            : null;
        _cache[key] = normalized;
        return normalized;
      } catch (_) {
        // Allow a future request to retry if the backend is temporarily offline.
        return null;
      } finally {
        _releaseRequestSlot();
        _inFlight.remove(key);
        revision.value++;
      }
    }();
    _inFlight[key] = request;
    return request;
  }

  static Future<void> prefetch(
    Iterable<MediaItem> items, {
    required bool isTv,
  }) async {
    await Future.wait<void>(items.map((media) async {
      await ratingFor(
        title: media.title,
        isTv: isTv,
        year: isTv
            ? (media.seriesStartYear ?? media.releaseYear)
            : media.releaseYear,
      );
    }));
  }

  static double? scoreFor({
    required String title,
    required bool isTv,
    int? year,
  }) {
    final entry = _cache[_key(title, isTv, year)];
    final score = entry?['score'];
    return score is num ? score.toDouble() : null;
  }

  static int? percentFor({
    required String title,
    required bool isTv,
    int? year,
  }) {
    final score = scoreFor(title: title, isTv: isTv, year: year);
    return score == null ? null : (score * 10).round().clamp(0, 100).toInt();
  }
}

/// TMDB's community average displayed on movie/show cards as both `/10` and `%`.
class TmdbMediaRatingBadge extends StatefulWidget {
  const TmdbMediaRatingBadge({
    super.key,
    required this.title,
    required this.isTv,
    this.year,
    this.compact = true,
  });

  final String title;
  final bool isTv;
  final int? year;
  final bool compact;

  @override
  State<TmdbMediaRatingBadge> createState() => _TmdbMediaRatingBadgeState();
}

class _TmdbMediaRatingBadgeState extends State<TmdbMediaRatingBadge> {
  late Future<Map<String, dynamic>?> _ratingFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TmdbMediaRatingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.isTv != widget.isTv ||
        oldWidget.year != widget.year) {
      _load();
    }
  }

  void _load() {
    _ratingFuture = TmdbMediaRatingStore.ratingFor(
      title: widget.title,
      isTv: widget.isTv,
      year: widget.year,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!CinematicTitleMetadataService.isConfigured) {
      return const SizedBox.shrink();
    }
    // The same profile palette used by personal score badges also controls
    // provider-rating labels. Listen for palette changes so Home, Movies,
    // Shows, and Details update immediately after the user saves new colors.
    return ValueListenableBuilder<int>(
      valueListenable: UserMediaRatingStore.changes,
      builder: (context, paletteRevision, child) {
        final palette = UserMediaRatingStore.paletteFor(
          AppController.instance.currentProfile?.id,
        );
        return FutureBuilder<Map<String, dynamic>?>(
          future: _ratingFuture,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final raw = data?['score'];
            if (raw is! num || raw <= 0) return const SizedBox.shrink();
            final score = raw.toDouble();
            final percent = (score * 10).round().clamp(0, 100);
            final ratingColor = palette.colorFor(percent.toDouble());
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 6 : 9,
                vertical: widget.compact ? 3 : 5,
              ),
              decoration: BoxDecoration(
                color: ratingColor.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: ratingColor.withValues(alpha: .62),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: widget.compact ? 12 : 15,
                    color: ratingColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'TMDB ${score.toStringAsFixed(1)}/10 · $percent%',
                    style: TextStyle(
                      color: ratingColor,
                      fontSize: widget.compact ? 9.5 : 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class MediaRatingsPanel extends StatefulWidget {
  final String mediaId;
  final String title;
  final int? year;
  final String mediaType;
  final String? tmdbId;
  final String? musicBrainzId;

  const MediaRatingsPanel({
    super.key,
    required this.mediaId,
    required this.title,
    this.year,
    this.mediaType = 'movie',
    this.tmdbId,
    this.musicBrainzId,
  });

  @override
  State<MediaRatingsPanel> createState() => _MediaRatingsPanelState();
}

class _MediaRatingsPanelState extends State<MediaRatingsPanel> {
  Map<String, dynamic>? data;
  bool loading = true;
  double? userScore;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(UserMediaRatingStore.initializeForProfile(
      AppController.instance.currentProfile?.id,
    ));
    _load();
  }

  @override
  void didUpdateWidget(covariant MediaRatingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId ||
        oldWidget.title != widget.title ||
        oldWidget.year != widget.year ||
        oldWidget.mediaType != widget.mediaType ||
        oldWidget.tmdbId != widget.tmdbId) {
      _load();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    final generation = ++_loadGeneration;
    try {
      final result = await AppController.instance.backendApi.getRatings(
        mediaId: widget.mediaId,
        title: widget.title,
        year: widget.year,
        mediaType: widget.mediaType,
        tmdbId: widget.tmdbId,
        musicBrainzId: widget.musicBrainzId,
        profileId: AppController.instance.currentProfile?.id,
        refresh: refresh,
      );
      if (!mounted || generation != _loadGeneration) return;
      final rawUser = result['userRating'];
      final remoteScore = rawUser is Map && rawUser['score'] is num
          ? (rawUser['score'] as num).toDouble()
          : rawUser is Map && rawUser['stars'] is num
              ? (rawUser['stars'] as num).toDouble() * 20
              : null;
      final parsedScore = remoteScore ??
          UserMediaRatingStore.scoreFor(
            AppController.instance.currentProfile?.id,
            widget.mediaId,
          );
      if (parsedScore != null) {
        await UserMediaRatingStore.rememberScore(
          profileId: AppController.instance.currentProfile?.id,
          mediaId: widget.mediaId,
          score: parsedScore,
        );
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        data = result;
        loading = false;
        userScore = parsedScore;
      });
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          loading = false;
          userScore = UserMediaRatingStore.scoreFor(
            AppController.instance.currentProfile?.id,
            widget.mediaId,
          );
        });
      }
    }
  }

  Future<void> _rate() async {
    final selected = await showMediaScoreDialog(context, initial: userScore);
    if (selected == null || AppController.instance.currentProfile == null) {
      return;
    }
    try {
      await AppController.instance.backendApi.saveUserScore(
        mediaId: widget.mediaId,
        profileId: AppController.instance.currentProfile!.id,
        score: selected,
      );
      await UserMediaRatingStore.rememberScore(
        profileId: AppController.instance.currentProfile!.id,
        mediaId: widget.mediaId,
        score: selected,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
          padding: EdgeInsets.all(8), child: LinearProgressIndicator());
    }
    final raw = data?['ratings'];
    final ratings = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final normalizedMediaType = widget.mediaType.toLowerCase();
    final isMusic = normalizedMediaType.contains('music') ||
        normalizedMediaType.contains('album') ||
        normalizedMediaType.contains('song') ||
        normalizedMediaType.contains('track') ||
        normalizedMediaType.contains('artist') ||
        normalizedMediaType.contains('soundtrack');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.star_half_rounded),
            const SizedBox(width: 8),
            const Expanded(
                child: UniversalText('Ratings & Reviews',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            IconButton(
                tooltip: 'Customize personal rating colors',
                onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const RatingColorSettingsScreen(),
                      ),
                    ),
                icon: const Icon(Icons.palette_outlined)),
            IconButton(
                tooltip: tr('Refresh ratings'),
                onPressed: () => _load(refresh: true),
                icon: const Icon(Icons.refresh_rounded)),
          ]),
          const SizedBox(height: 8),
          if (ratings.isEmpty)
            UniversalText(
                isMusic
                    ? 'No external music-rating provider is configured. Music ratings are your personal score for this profile.'
                    : 'No external ratings are configured or available for this title yet.',
                style: const TextStyle(color: Colors.white60))
          else
            ...ratings.map(_ratingRow),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_rounded),
            title: Text(userScore == null
                ? tr('Your rating')
                : '${tr('Your rating')}: ${userScore!.toStringAsFixed(userScore!.truncateToDouble() == userScore ? 0 : 1)}% (${(userScore! / 10).toStringAsFixed(1)}/10)'),
            subtitle: userScore == null
                ? const UniversalText('Set your personal score from 0 to 100%.')
                : Row(children: [
                    UserScoreBadge(
                      score: userScore!.round(),
                      palette: UserMediaRatingStore.paletteFor(
                        AppController.instance.currentProfile?.id,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: UniversalText(
                            'Your personal score is private to this profile.')),
                  ]),
            trailing: OutlinedButton.icon(
                onPressed: _rate,
                icon: const Icon(Icons.star_rounded),
                label: const UniversalText('Rate')),
          ),
        ]),
      ),
    );
  }

  Widget _ratingRow(Map<String, dynamic> rating) {
    final provider = rating['provider']?.toString() ?? 'provider';
    final kind = rating['kind']?.toString() ?? 'audience';
    final value = rating['value'] is num
        ? (rating['value'] as num).toDouble()
        : double.tryParse(rating['value']?.toString() ?? '') ?? 0;
    final scale =
        rating['scale'] is num ? (rating['scale'] as num).toDouble() : 10;
    final votes = rating['voteCount'];
    final isTmdbTenPoint =
        provider.toLowerCase() == 'tmdb' && (scale - 10).abs() < 0.0001;
    final scoreText = isTmdbTenPoint
        ? '${value.toStringAsFixed(1)} / 10 · ${(value * 10).round().clamp(0, 100)}%'
        : '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} / ${scale.toStringAsFixed(0)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
            child: Text(_providerName(provider) +
                (kind == 'critic'
                    ? ' Critics'
                    : kind == 'community'
                        ? ' Community'
                        : ''))),
        Text(scoreText, style: const TextStyle(fontWeight: FontWeight.w900)),
        if (votes != null) ...[
          const SizedBox(width: 8),
          Text('($votes)', style: const TextStyle(color: Colors.white54))
        ],
      ]),
    );
  }

  String _providerName(String value) {
    switch (value) {
      case 'tmdb':
        return 'TMDB';
      case 'imdb':
        return 'IMDb';
      case 'rottenTomatoes':
        return 'Rotten Tomatoes';
      case 'musicBrainz':
        return 'MusicBrainz';
      default:
        return value;
    }
  }
}

/// Shared percentage-score dialog used by movies, shows, albums, and tracks.
Future<double?> showMediaScoreDialog(
  BuildContext context, {
  double? initial,
}) =>
    showDialog<double>(
        context: context,
        builder: (context) => _PercentRatingDialog(initial: initial));

class _PercentRatingDialog extends StatefulWidget {
  final double? initial;
  const _PercentRatingDialog({this.initial});

  @override
  State<_PercentRatingDialog> createState() => _PercentRatingDialogState();
}

class _PercentRatingDialogState extends State<_PercentRatingDialog> {
  late double value;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    value = (widget.initial ?? 80).clamp(0, 100).toDouble();
    _valueController = TextEditingController(text: value.round().toString());
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _update(double next) {
    final normalized = next.clamp(0, 100).toDouble();
    setState(() {
      value = normalized;
      _valueController.text = normalized.round().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = UserMediaRatingStore.paletteFor(
      AppController.instance.currentProfile?.id,
    );
    return AlertDialog(
      title: const Text('Your personal score'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserScoreBadge(score: value, palette: palette),
          const SizedBox(height: 14),
          Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${value.round()}%',
            onChanged: _update,
          ),
          TextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Score', suffixText: '%'),
            onChanged: (raw) {
              final parsed = double.tryParse(raw);
              if (parsed != null && parsed >= 0 && parsed <= 100) {
                setState(() => value = parsed);
              }
            },
          ),
          const SizedBox(height: 8),
          const Text(
              'This score is private to your selected profile and does not change provider or critic ratings.',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(value.clamp(0, 100).toDouble()),
          child: const Text('Save score'),
        ),
      ],
    );
  }
}
