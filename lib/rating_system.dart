// FILE: `lib/rating_system.dart`.
// Purpose: Displays provider ratings and lets the current profile save a
// separate 0.5-5 star personal rating. Provider scores are never combined.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'localization.dart';

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
  double? userStars;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
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
      if (!mounted) return;
      final rawUser = result['userRating'];
      setState(() {
        data = result;
        loading = false;
        userStars = rawUser is Map && rawUser['stars'] is num
            ? (rawUser['stars'] as num).toDouble()
            : null;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _rate() async {
    final selected = await showDialog<double>(
      context: context,
      builder: (context) => _StarRatingDialog(initial: userStars),
    );
    if (selected == null || AppController.instance.currentProfile == null) {
      return;
    }try {
      await AppController.instance.backendApi.saveUserRating(
        mediaId: widget.mediaId,
        profileId: AppController.instance.currentProfile!.id,
        stars: selected,
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
                tooltip: tr('Refresh ratings'),
                onPressed: () => _load(refresh: true),
                icon: const Icon(Icons.refresh_rounded)),
          ]),
          const SizedBox(height: 8),
          if (ratings.isEmpty)
            const UniversalText(
                'No external ratings are configured or available for this title yet.',
                style: TextStyle(color: Colors.white60))
          else
            ...ratings.map(_ratingRow),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_rounded),
            title: Text(userStars == null
                ? tr('Your rating')
                : '${tr('Your rating')}: ${userStars!.toStringAsFixed(1)} / 5'),
            subtitle:
                const UniversalText('Rate this title in 0.5-star increments.'),
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
        Text(
            '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} / ${scale.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w900)),
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

class _StarRatingDialog extends StatefulWidget {
  final double? initial;
  const _StarRatingDialog({this.initial});
  @override
  State<_StarRatingDialog> createState() => _StarRatingDialogState();
}

class _StarRatingDialogState extends State<_StarRatingDialog> {
  late double value = widget.initial ?? 5;
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const UniversalText('Your rating'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${value.toStringAsFixed(1)} / 5'),
          Slider(
              value: value,
              min: 0.5,
              max: 5,
              divisions: 9,
              label: value.toStringAsFixed(1),
              onChanged: (v) => setState(() => value = v)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const UniversalText('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, value),
              child: const UniversalText('Save'))
        ],
      );
}
