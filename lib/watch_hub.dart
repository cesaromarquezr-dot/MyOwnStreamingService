import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'marketplace_hub.dart';
import 'my_tv.dart';
import 'navigation_hubs.dart';
import 'public_live_tv.dart';

enum WatchHubMode { combined, liveTv, myTv, library }

/// One Watch destination that keeps public broadcasts, personal channels and
/// the on-demand library together without duplicating their existing screens.
class WatchHubScreen extends StatefulWidget {
  final WatchHubMode initialMode;
  final bool standalone;

  const WatchHubScreen({super.key, this.initialMode = WatchHubMode.combined, this.standalone = false});

  @override
  State<WatchHubScreen> createState() => _WatchHubScreenState();
}

class _WatchHubScreenState extends State<WatchHubScreen> {
  late WatchHubMode _mode = widget.initialMode;
  late final Set<WatchHubMode> _visitedModes = <WatchHubMode>{widget.initialMode};

  @override
  void didUpdateWidget(covariant WatchHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode) {
      _mode = widget.initialMode;
      _visitedModes.add(widget.initialMode);
    }
  }

  void _select(WatchHubMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _visitedModes.add(mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: <Widget>[
        _WatchModePicker(selected: _mode, onSelected: _select),
        Expanded(
          child: IndexedStack(
            index: _mode.index,
            children: <Widget>[
              _visitedModes.contains(WatchHubMode.combined)
                  ? _CombinedWatchOverview(onSelected: _select)
                  : const SizedBox.shrink(),
              _visitedModes.contains(WatchHubMode.liveTv)
                  ? const PublicLiveTvScreen(showAppBar: false)
                  : const SizedBox.shrink(),
              _visitedModes.contains(WatchHubMode.myTv)
                  ? const MyTvScreen(showAppBar: false)
                  : const SizedBox.shrink(),
              _visitedModes.contains(WatchHubMode.library)
                  ? const LibraryHubScreen()
                  : const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
    if (!widget.standalone) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Watch')),
      body: content,
    );
  }
}

class _WatchModePicker extends StatelessWidget {
  final WatchHubMode selected;
  final ValueChanged<WatchHubMode> onSelected;

  const _WatchModePicker({required this.selected, required this.onSelected});

  static const _options = <({WatchHubMode mode, String label, IconData icon})>[
    (mode: WatchHubMode.combined, label: 'Combined', icon: Icons.dashboard_rounded),
    (mode: WatchHubMode.liveTv, label: 'Live TV', icon: Icons.satellite_alt_rounded),
    (mode: WatchHubMode.myTv, label: 'My TV', icon: Icons.live_tv_rounded),
    (mode: WatchHubMode.library, label: 'Library', icon: Icons.video_library_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 58,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: <Widget>[
              for (final option in _options) ...<Widget>[
                ChoiceChip(
                  selected: selected == option.mode,
                  avatar: Icon(option.icon, size: 17),
                  label: Text(option.label),
                  onSelected: (_) => onSelected(option.mode),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: '/app/marketplace'),
                    builder: (_) => const MarketplaceHubScreen(),
                  ),
                ),
                icon: const Icon(Icons.storefront_outlined, size: 17),
                label: const Text('Marketplace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CombinedWatchOverview extends StatelessWidget {
  final ValueChanged<WatchHubMode> onSelected;

  const _CombinedWatchOverview({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final library = List<MediaItem>.from(
      controller.library.where((item) => item.isAccessibleTo(profile)),
    )..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final movies = library.where((item) => item.type.toLowerCase().contains('movie')).toList(growable: false);
    final shows = library.where((item) {
      final type = item.type.toLowerCase();
      return type.contains('tv') || type.contains('show') || type.contains('series');
    }).toList(growable: false);
    final music = library.where((item) {
      final type = item.type.toLowerCase();
      return type.contains('music') || type.contains('song') || type.contains('album') || type.contains('track');
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Theme.of(context).colorScheme.primary.withValues(alpha: .36),
                Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .75),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Everything you watch, together', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Switch between public live broadcasts, personal channels generated from your media, and movies, series and music in your library${profile == null ? '' : ' for ${profile.name}'}.',
                style: const TextStyle(height: 1.45, color: Colors.white70)),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: <Widget>[
                _CountPill(icon: Icons.video_library_rounded, label: '${library.length} library items'),
                _CountPill(icon: Icons.movie_rounded, label: '${movies.length} movies'),
                _CountPill(icon: Icons.tv_rounded, label: '${shows.length} shows'),
                _CountPill(icon: Icons.music_note_rounded, label: '${music.length} music items'),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Watch live or on demand', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _WatchDestinationCard(
          icon: Icons.satellite_alt_rounded,
          title: 'Live TV',
          subtitle: 'Browse public broadcasts by country and category, save favorite channels, and use fullscreen or the mini player.',
          actionLabel: 'Watch live',
          onTap: () => onSelected(WatchHubMode.liveTv),
        ),
        const SizedBox(height: 10),
        _WatchDestinationCard(
          icon: Icons.live_tv_rounded,
          title: 'My TV',
          subtitle: 'Build your own channels from your accessible movies, series and music, with personal schedules and favorites.',
          actionLabel: 'Open My TV',
          onTap: () => onSelected(WatchHubMode.myTv),
        ),
        const SizedBox(height: 10),
        _WatchDestinationCard(
          icon: Icons.video_library_rounded,
          title: 'My Library',
          subtitle: 'Browse your complete on-demand collection, favorites, collections and newly added media.',
          actionLabel: 'Browse library',
          onTap: () => onSelected(WatchHubMode.library),
        ),
        const SizedBox(height: 20),
        Row(children: <Widget>[
          const Expanded(child: Text('Recently added', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
          TextButton(onPressed: () => onSelected(WatchHubMode.library), child: const Text('Full library')),
        ]),
        if (library.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Your library is ready for media from your configured server or local catalog.')))
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: library.take(12).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _CombinedMediaCard(
                media: library[index],
                onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                  builder: (_) => MediaDetailsScreen(media: library[index]),
                )),
              ),
            ),
          ),
        if (movies.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _MediaShelfHeading(title: 'Movies', count: movies.length, onTap: () => onSelected(WatchHubMode.library)),
          SizedBox(
            height: 184,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: movies.take(10).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _CombinedMediaCard(
                media: movies[index],
                onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                  builder: (_) => MediaDetailsScreen(media: movies[index]),
                )),
              ),
            ),
          ),
        ],
        if (shows.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _MediaShelfHeading(title: 'TV and series', count: shows.length, onTap: () => onSelected(WatchHubMode.library)),
          SizedBox(
            height: 184,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shows.take(10).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _CombinedMediaCard(
                media: shows[index],
                onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                  builder: (_) => MediaDetailsScreen(media: shows[index]),
                )),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storefront_rounded, size: 30),
            title: const Text('Marketplace', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Shop entertainment merchandise and switch to Food Delivery from one shared storefront.'),
            trailing: const Icon(Icons.arrow_forward_rounded),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const MarketplaceHubScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaShelfHeading extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onTap;

  const _MediaShelfHeading({required this.title, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => Row(children: <Widget>[
    Expanded(child: Text('$title ($count)', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
    TextButton(onPressed: onTap, child: const Text('Browse')),
  ]);
}

class _CombinedMediaCard extends StatelessWidget {
  final MediaItem media;
  final VoidCallback onTap;

  const _CombinedMediaCard({required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = media.imageUrl?.trim() ?? '';
    return SizedBox(
      width: 126,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 126,
              height: 142,
              child: image.startsWith('http://') || image.startsWith('https://')
                  ? Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder(context))
                  : _placeholder(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          Text('${media.type}${media.releaseYear == null ? '' : ' · ${media.releaseYear}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ]),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: Icon(media.type.toLowerCase().contains('music') ? Icons.music_note_rounded : Icons.movie_outlined, size: 34),
  );
}

class _CountPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CountPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _WatchDestinationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _WatchDestinationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(subtitle, style: const TextStyle(color: Colors.white60, height: 1.35)),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: FilledButton.tonal(onPressed: onTap, child: Text(actionLabel))),
              ])),
            ],
          ),
        ),
      );
}
