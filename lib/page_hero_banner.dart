import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';

/// Page-specific carousel behavior configured from Customize App.
class PageHeroSettings {
  final bool enabled;
  final int itemCount;
  final bool audioEnabled;
  final int intervalSeconds;
  final String artworkMode;
  final double hoverScale;

  const PageHeroSettings({
    this.enabled = true,
    this.itemCount = 8,
    this.audioEnabled = true,
    this.intervalSeconds = 12,
    this.artworkMode = 'Both',
    this.hoverScale = 1.08,
  });

  PageHeroSettings copyWith({
    bool? enabled,
    int? itemCount,
    bool? audioEnabled,
    int? intervalSeconds,
    String? artworkMode,
    double? hoverScale,
  }) => PageHeroSettings(
        enabled: enabled ?? this.enabled,
        itemCount: itemCount ?? this.itemCount,
        audioEnabled: audioEnabled ?? this.audioEnabled,
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
        artworkMode: artworkMode ?? this.artworkMode,
        hoverScale: hoverScale ?? this.hoverScale,
      );
}

class PageHeroSettingsStore {
  PageHeroSettingsStore._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Future<PageHeroSettings> load(String pageId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'pageHero.$pageId.';
    final artworkMode = prefs.getString('${prefix}artworkMode') ?? 'Both';
    final hoverScale = prefs.getDouble('${prefix}hoverScale') ?? 1.08;
    return PageHeroSettings(
      enabled: prefs.getBool('${prefix}enabled') ?? true,
      itemCount: (prefs.getInt('${prefix}count') ?? 8).clamp(1, 40).toInt(),
      audioEnabled: prefs.getBool('${prefix}audioEnabled') ?? true,
      intervalSeconds: (prefs.getInt('${prefix}intervalSeconds') ?? 12)
          .clamp(3, 60)
          .toInt(),
      artworkMode: const {'Both', 'Backdrops only', 'Posters only', 'Both or previews'}
              .contains(artworkMode)
          ? artworkMode
          : 'Both',
      hoverScale: const <double>[1.03, 1.08, 1.15, 1.5, 2.0, 3.0]
              .contains(hoverScale)
          ? hoverScale
          : 1.08,
    );
  }

  static Future<void> save(String pageId, PageHeroSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'pageHero.$pageId.';
    await prefs.setBool('${prefix}enabled', settings.enabled);
    await prefs.setInt('${prefix}count', settings.itemCount.clamp(1, 40).toInt());
    await prefs.setBool('${prefix}audioEnabled', settings.audioEnabled);
    await prefs.setInt(
      '${prefix}intervalSeconds',
      settings.intervalSeconds.clamp(3, 60).toInt(),
    );
    await prefs.setString('${prefix}artworkMode', settings.artworkMode);
    await prefs.setDouble('${prefix}hoverScale', settings.hoverScale);
    revision.value++;
  }
}

/// Reusable controls shown inside the page's Customize App screen.
class PageHeroSettingsPanel extends StatelessWidget {
  const PageHeroSettingsPanel({
    super.key,
    required this.pageTitle,
    required this.settings,
    required this.onChanged,
  });

  final String pageTitle;
  final PageHeroSettings settings;
  final ValueChanged<PageHeroSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF141414),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.view_carousel_rounded, color: Colors.redAccent),
              const SizedBox(width: 9),
              Expanded(
                child: Text('$pageTitle hero banner',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable hero banner'),
              subtitle: const Text('Show the rotating featured banner on this page.'),
              value: settings.enabled,
              onChanged: (value) => onChanged(settings.copyWith(enabled: value)),
            ),
            DropdownButtonFormField<int>(
              initialValue: settings.itemCount.clamp(1, 40).toInt(),
              decoration: const InputDecoration(labelText: 'Number of featured items'),
              items: List<int>.generate(40, (index) => index + 1)
                  .map((value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value item${value == 1 ? '' : 's'}'),
                      ))
                  .toList(growable: false),
              onChanged: settings.enabled
                  ? (value) {
                      if (value != null) onChanged(settings.copyWith(itemCount: value));
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow hero preview audio'),
              subtitle: const Text('Previews still start muted; viewers can unmute when enabled.'),
              value: settings.audioEnabled,
              onChanged: (value) => onChanged(settings.copyWith(audioEnabled: value)),
            ),
            DropdownButtonFormField<int>(
              initialValue: settings.intervalSeconds.clamp(3, 60).toInt(),
              decoration: const InputDecoration(labelText: 'Time before the next item'),
              items: const [3, 5, 8, 10, 12, 15, 20, 30, 45, 60]
                  .map((value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value seconds'),
                      ))
                  .toList(growable: false),
              onChanged: settings.enabled
                  ? (value) {
                      if (value != null) onChanged(settings.copyWith(intervalSeconds: value));
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: settings.artworkMode,
              decoration: const InputDecoration(labelText: 'Hero artwork'),
              items: const [
                DropdownMenuItem(value: 'Both', child: Text('Poster + backdrop')),
                DropdownMenuItem(value: 'Both or previews', child: Text('Poster + backdrop or previews')),
                DropdownMenuItem(value: 'Backdrops only', child: Text('Backdrops only')),
                DropdownMenuItem(value: 'Posters only', child: Text('Posters only')),
              ],
              onChanged: settings.enabled
                  ? (value) {
                      if (value != null) onChanged(settings.copyWith(artworkMode: value));
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<double>(
              initialValue: settings.hoverScale,
              decoration: const InputDecoration(labelText: 'Artwork zoom on hover'),
              items: const [
                DropdownMenuItem(value: 1.03, child: Text('Slightly bigger (1.03×)')),
                DropdownMenuItem(value: 1.08, child: Text('Small (1.08×)')),
                DropdownMenuItem(value: 1.15, child: Text('Medium (1.15×)')),
                DropdownMenuItem(value: 1.5, child: Text('Large (1.5×)')),
                DropdownMenuItem(value: 2.0, child: Text('Twice as big (2×)')),
                DropdownMenuItem(value: 3.0, child: Text('Three times as big (3×)')),
              ],
              onChanged: settings.enabled
                  ? (value) {
                      if (value != null) onChanged(settings.copyWith(hoverScale: value));
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally swipeable hero banner shelf. The count is page-specific and
/// the source list contains only the media type belonging to the current page.
class PageHeroBannerCarousel extends StatefulWidget {
  final List<MediaItem> items;
  final int itemCount;
  final ValueChanged<MediaItem> onTap;

  const PageHeroBannerCarousel({
    super.key,
    required this.items,
    required this.itemCount,
    required this.onTap,
  });

  @override
  State<PageHeroBannerCarousel> createState() => _PageHeroBannerCarouselState();
}

class _PageHeroBannerCarouselState extends State<PageHeroBannerCarousel> {
  late final PageController _controller = PageController(viewportFraction: .92);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length < widget.itemCount
        ? widget.items.length
        : widget.itemCount;
    if (count == 0) return const SizedBox.shrink();
    return SizedBox(
      height: 294,
      child: PageView.builder(
        controller: _controller,
        itemCount: count,
        itemBuilder: (context, index) {
          final media = widget.items[index];
          final url = (media.imageUrl ?? '').trim();
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 18),
            child: Material(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => widget.onTap(media),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url.startsWith('http://') || url.startsWith('https://'))
                      Image.network(url, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xEE000000)],
                          stops: [.18, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      right: 22,
                      bottom: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('FEATURED', style: TextStyle(
                            color: Colors.white70, fontSize: 11,
                            fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                          const SizedBox(height: 7),
                          Text(media.title, maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white,
                              fontSize: 26, fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: Colors.black87, blurRadius: 12)])),
                          const SizedBox(height: 7),
                          Text([
                            if (media.releaseYear != null) '${media.releaseYear}',
                            if (media.genres.isNotEmpty) media.genres.take(2).join(' · '),
                          ].join('  •  '), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
