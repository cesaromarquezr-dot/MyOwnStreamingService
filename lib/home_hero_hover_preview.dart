import 'package:flutter/widgets.dart';

import 'app_core.dart';

/// Shared preview selection consumed by the Home/Movies/Shows hero banners.
/// Cards from any discovery shelf publish a MediaItem here while hovered.
class HomeHoverPreviewStore {
  HomeHoverPreviewStore._();

  static final ValueNotifier<MediaItem?> current =
      ValueNotifier<MediaItem?>(null);

  static void show(MediaItem item) => current.value = item;

  static void clear(String mediaId) {
    if (current.value?.id == mediaId) current.value = null;
  }
}

/// Adds hero-preview hover behavior to custom cards that do not use MediaCard.
/// Existing tap behavior and child layout are preserved.
class HomeHeroHoverPreviewRegion extends StatelessWidget {
  const HomeHeroHoverPreviewRegion({
    super.key,
    required this.media,
    required this.child,
    this.onHoverChanged,
  });

  final MediaItem media;
  final Widget child;
  final ValueChanged<bool>? onHoverChanged;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          HomeHoverPreviewStore.show(media);
          onHoverChanged?.call(true);
        },
        onExit: (_) {
          onHoverChanged?.call(false);
          HomeHoverPreviewStore.clear(media.id);
        },
        child: child,
      );
}
