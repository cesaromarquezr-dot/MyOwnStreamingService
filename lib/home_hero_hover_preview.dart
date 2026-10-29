import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

import 'app_core.dart';

/// Shared preview selection consumed by the Home/Movies/Shows hero banners.
/// Cards from any discovery shelf publish a MediaItem here while hovered.
class HomeHoverPreviewStore {
  HomeHoverPreviewStore._();

  static final ValueNotifier<MediaItem?> current = ValueNotifier<MediaItem?>(null);
  static int _mutationRevision = 0;
  static bool _hasPendingMutation = false;
  static String? _pendingMediaId;

  static bool get _isBuildingFrame {
    final phase = SchedulerBinding.instance.schedulerPhase;
    return phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
  }

  /// ValueNotifier notifies listeners synchronously. A route's initState can
  /// clear a hover preview while Navigator is building the incoming route;
  /// that can make the still-mounted outgoing hero call setState during build.
  /// Coalesce those writes until post-frame, while keeping mouse-event writes
  /// immediate when Flutter is not building the tree.
  static void _mutate(String? pendingMediaId, VoidCallback mutation) {
    if (!_isBuildingFrame) {
      _mutationRevision++;
      _hasPendingMutation = false;
      _pendingMediaId = null;
      mutation();
      return;
    }

    final revision = ++_mutationRevision;
    _hasPendingMutation = true;
    _pendingMediaId = pendingMediaId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (revision != _mutationRevision) return;
      _hasPendingMutation = false;
      _pendingMediaId = null;
      mutation();
    });
  }

  static void show(MediaItem item) {
    if (current.value?.id == item.id && !_hasPendingMutation) return;
    _mutate(item.id, () {
      if (current.value?.id != item.id) current.value = item;
    });
  }

  static void clear(String mediaId) {
    if (current.value?.id != mediaId && _pendingMediaId != mediaId) return;
    _mutate(null, () {
      if (current.value?.id == mediaId) current.value = null;
    });
  }

  static void clearCurrent() {
    if (current.value == null && !_hasPendingMutation) return;
    _mutate(null, () {
      if (current.value != null) current.value = null;
    });
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
