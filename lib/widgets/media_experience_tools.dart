import 'package:material_ui/material_ui.dart';

import '../app_core.dart';
import '../coming_soon_release_screen.dart';
import '../dialogue_search.dart';
import '../entertainment_extensions.dart';
import '../models/media_case_style.dart';
import '../song_identification_screen.dart';

/// Shared entry points surfaced in the Store, Kiosk and private Theater.
/// These are personal discovery tools, not shopping or ticketing actions.
class MediaExperienceTools extends StatelessWidget {
  const MediaExperienceTools({
    super.key,
    this.compact = false,
    this.showHeading = true,
  });

  final bool compact;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    final actions = <_ExperienceAction>[
      _ExperienceAction(
        title: 'Coming Soon',
        subtitle: 'Upcoming movies, shows and music releases',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF4C83C3),
        page: const ComingSoonReleaseScreen(),
      ),
      _ExperienceAction(
        title: 'Entertainment Wrapped',
        subtitle: 'Your listening and viewing highlights',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF8A5BC4),
        page: const MediaWrappedCollectionsScreen(),
      ),
      _ExperienceAction(
        title: 'Identify Music by Audio',
        subtitle: 'Record a short sample to recognize a song',
        icon: Icons.graphic_eq_rounded,
        color: const Color(0xFF258E86),
        page: const SongIdentificationScreen(),
      ),
      _ExperienceAction(
        title: 'Identify Movie / Show',
        subtitle: 'Remembered dialogue, scenes or descriptions',
        icon: Icons.movie_filter_rounded,
        color: const Color(0xFFB36F40),
        page: const DialogueSearchScreen(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text(
            'DISCOVER & IDENTIFY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 9),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final action in actions)
                  SizedBox(
                    width: width,
                    child: _ExperienceActionCard(
                      action: action,
                      compact: compact,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => action.page),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ExperienceAction {
  const _ExperienceAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.page,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;
}

class _ExperienceActionCard extends StatelessWidget {
  const _ExperienceActionCard({
    required this.action,
    required this.compact,
    required this.onTap,
  });

  final _ExperienceAction action;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 12),
            child: Row(
              children: [
                Container(
                  width: compact ? 34 : 40,
                  height: compact ? 34 : 40,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(action.icon,
                      color: action.color, size: compact ? 19 : 22),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        action.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action.subtitle,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ),
      );
}

/// Browse shortcuts based on actual media metadata. Unknown formats are never
/// silently counted as DVD, Blu-ray, 4K or CD.
class MediaFormatBrowseSection extends StatelessWidget {
  const MediaFormatBrowseSection({
    super.key,
    required this.items,
    required this.onSelect,
    this.title = 'Browse your collection',
  });

  final List<MediaItem> items;
  final String title;
  final void Function(String label, List<MediaItem> matches) onSelect;

  bool _isMusic(MediaItem media) {
    final type = media.type.toLowerCase().replaceAll('_', ' ');
    return type.contains('music') ||
        type.contains('album') ||
        type.contains('song') ||
        type.contains('track') ||
        type.contains('audio');
  }

  bool _isShow(MediaItem media) {
    final type = media.type.toLowerCase().replaceAll('_', ' ');
    return type.contains('tv') ||
        type.contains('show') ||
        type.contains('series') ||
        type.contains('episode') ||
        type.contains('special');
  }

  List<_FormatShortcut> _shortcuts() {
    List<MediaItem> format(String value) => items
        .where((media) =>
            MediaCaseStyle.canonicalFormat(media.displayCaseFormat) == value)
        .toList(growable: false);
    final music = items.where(_isMusic).toList(growable: false);
    final movies = items
        .where((media) => !_isMusic(media) && !_isShow(media))
        .toList(growable: false);
    final shows = items.where(_isShow).toList(growable: false);
    return <_FormatShortcut>[
      _FormatShortcut('DVD', Icons.album_outlined, format('DVD')),
      _FormatShortcut('Blu-ray', Icons.album_rounded, format('Blu-ray')),
      _FormatShortcut(
          '4K Ultra HD', Icons.high_quality_rounded, format('4K Ultra HD')),
      _FormatShortcut('CD', Icons.disc_full_rounded, format('Audio CD')),
      _FormatShortcut('Music', Icons.library_music_rounded, music),
      _FormatShortcut('Movies', Icons.movie_rounded, movies),
      _FormatShortcut('Shows', Icons.live_tv_rounded, shows),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = _shortcuts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final shortcut in shortcuts)
              ActionChip(
                avatar: Icon(shortcut.icon, size: 17),
                label: Text('${shortcut.label} · ${shortcut.items.length}'),
                onPressed: () => onSelect(shortcut.label, shortcut.items),
              ),
          ],
        ),
      ],
    );
  }
}

class _FormatShortcut {
  const _FormatShortcut(this.label, this.icon, this.items);
  final String label;
  final IconData icon;
  final List<MediaItem> items;
}
