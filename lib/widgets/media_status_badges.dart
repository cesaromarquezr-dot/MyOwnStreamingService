import 'package:material_ui/material_ui.dart';

import '../app_core.dart';

enum MediaStatusKind {
  newEpisode,
  newlyAdded,
  recentlyAdded,
  continueWatching,
  unwatched,
  finished,
}

class MediaStatusFlag {
  const MediaStatusFlag(this.kind, this.label, this.color);

  final MediaStatusKind kind;
  final String label;
  final Color color;
}

/// Derives display-only streaming status labels from library metadata and the
/// active profile's local watch state. It never modifies playback history.
class MediaStatusBadgeEngine {
  MediaStatusBadgeEngine._();

  static const Duration newEpisodeWindow = Duration(days: 14);
  static const Duration newItemWindow = Duration(days: 7);
  static const Duration recentlyAddedWindow = Duration(days: 30);

  static List<MediaStatusFlag> statusesFor({
    required MediaItem media,
    required bool watched,
    required double progress,
    DateTime? now,
    int maxStatuses = 2,
  }) {
    final current = now ?? DateTime.now();
    final statuses = <MediaStatusFlag>[];

    if (media.isSeries && _hasRecentlyAiredEpisode(media, current)) {
      statuses.add(const MediaStatusFlag(
        MediaStatusKind.newEpisode,
        'NEW EPISODE',
        Color(0xFFB7F36B),
      ));
    }

    final age = current.difference(media.addedAt);
    if (!age.isNegative && age <= newItemWindow) {
      statuses.add(const MediaStatusFlag(
        MediaStatusKind.newlyAdded,
        'NEW',
        Color(0xFF4DD0E1),
      ));
    } else if (!age.isNegative && age <= recentlyAddedWindow) {
      statuses.add(const MediaStatusFlag(
        MediaStatusKind.recentlyAdded,
        'RECENTLY ADDED',
        Color(0xFF80CBC4),
      ));
    }

    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
    final isMusic = _isMusic(media);
    if (watched || normalizedProgress >= 0.95) {
      statuses.add(MediaStatusFlag(
        MediaStatusKind.finished,
        isMusic ? 'LISTENED' : 'FINISHED',
        const Color(0xFF90CAF9),
      ));
    } else if (normalizedProgress > 0.01) {
      statuses.add(MediaStatusFlag(
        MediaStatusKind.continueWatching,
        isMusic ? 'CONTINUE LISTENING' : 'CONTINUE',
        const Color(0xFFFFD180),
      ));
    } else {
      statuses.add(MediaStatusFlag(
        MediaStatusKind.unwatched,
        isMusic ? 'UNLISTENED' : 'UNWATCHED',
        const Color(0xFFE0E0E0),
      ));
    }

    return statuses
        .take(maxStatuses < 0 ? 0 : maxStatuses)
        .toList(growable: false);
  }

  static bool _isMusic(MediaItem media) {
    final type = media.type.toLowerCase().replaceAll('_', ' ');
    return type.contains('music') ||
        type.contains('album') ||
        type.contains('song') ||
        type.contains('track') ||
        type.contains('audio');
  }

  static bool _hasRecentlyAiredEpisode(MediaItem media, DateTime now) {
    for (final season in media.seasons) {
      final episodes = season['episodes'];
      if (episodes is! List) continue;
      for (final rawEpisode in episodes.whereType<Map>()) {
        final episode = Map<String, dynamic>.from(rawEpisode);
        final rawDate = episode['airDate'] ??
            episode['air_date'] ??
            episode['releaseDate'] ??
            episode['release_date'];
        final date = DateTime.tryParse(rawDate?.toString() ?? '');
        if (date == null) continue;
        final age = now.difference(date);
        if (!age.isNegative && age <= newEpisodeWindow) return true;
      }
    }
    return false;
  }
}

/// Compact labels used on poster/case cards across Classic, Kiosk, Theater,
/// and the profile media hub.
class MediaStatusBadgeRow extends StatelessWidget {
  const MediaStatusBadgeRow({
    super.key,
    required this.media,
    this.dense = true,
    this.maxStatuses = 2,
  });

  final MediaItem media;
  final bool dense;
  final int maxStatuses;

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final statuses = MediaStatusBadgeEngine.statusesFor(
      media: media,
      watched: controller.isWatched(media.id),
      progress: controller.getPlaybackProgress(media.id),
      maxStatuses: maxStatuses,
    );
    if (statuses.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.end,
        children: statuses.map((status) {
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 6 : 8,
              vertical: dense ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xE8141720),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: status.color.withValues(alpha: .78)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                    color: Colors.black54, blurRadius: 5, offset: Offset(0, 1)),
              ],
            ),
            child: Text(
              status.label,
              maxLines: 1,
              style: TextStyle(
                color: status.color,
                fontSize: dense ? 8 : 10,
                letterSpacing: .35,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
