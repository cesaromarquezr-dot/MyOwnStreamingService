import 'package:flutter/material.dart';

import '../app_core.dart';

/// Retained as a lightweight metadata type for existing catalog/search models.
/// Hover preview playback and pop-out cards have been removed from the UI.
class HoverPreviewSource {
  const HoverPreviewSource({
    required this.url,
    this.label = 'Preview',
    this.isAudioOnly = false,
    this.randomStart = false,
    this.spoilerSafe = true,
    this.lowQualityUrl,
  });

  final String url;
  final String label;
  final bool isAudioOnly;
  final bool randomStart;
  final bool spoilerSafe;
  final String? lowQualityUrl;

  HoverPreviewSource withUrl(String nextUrl) => HoverPreviewSource(
        url: nextUrl,
        label: label,
        isAudioOnly: isAudioOnly,
        randomStart: randomStart,
        spoilerSafe: spoilerSafe,
        lowQualityUrl: lowQualityUrl,
      );
}

/// Legacy compatibility shim. No card can claim preview playback ownership.
class HoverPreviewCoordinator {
  HoverPreviewCoordinator._();

  static final HoverPreviewCoordinator instance = HoverPreviewCoordinator._();

  String? get activeCardId => null;

  void activate(String id) {}

  void clear(String id) {}

  void clearAll() {}
}

/// Preview sources are no longer collected because hover previews are disabled.
/// Keep this function so existing metadata call sites remain source-compatible.
List<HoverPreviewSource> hoverPreviewSourcesForMedia(MediaItem media) =>
    const <HoverPreviewSource>[];

/// Compatibility wrapper for existing card call sites.
///
/// It now renders only the original child: no overlay, video/audio playback,
/// inline expansion, scale animation, focus preview, or long-press preview.
/// The original child continues to own its normal tap and keyboard behavior.
class HoverPreviewCard extends StatelessWidget {
  const HoverPreviewCard({
    super.key,
    required this.mediaId,
    required this.title,
    required this.child,
    required this.artworkBuilder,
    this.media,
    this.subtitle = '',
    this.kind = 'media',
    this.previewSources = const <HoverPreviewSource>[],
    this.pageId,
    this.previewSettingsPageId,
    this.onOpen,
    this.onPlay,
    this.enabled = true,
    this.allowPreviewPlayback = true,
    this.onHoverChanged,
    this.inlineExpansion = false,
    this.imageOnlyHover = false,
    this.collapsedWidth = 180,
    this.expandedWidth = 420,
  });

  final String mediaId;
  final String title;
  final String subtitle;
  final String kind;
  final Widget child;
  final WidgetBuilder artworkBuilder;
  final MediaItem? media;
  final List<HoverPreviewSource> previewSources;
  final String? pageId;
  final String? previewSettingsPageId;
  final VoidCallback? onOpen;
  final VoidCallback? onPlay;
  final bool enabled;
  final bool allowPreviewPlayback;
  final ValueChanged<bool>? onHoverChanged;
  final bool inlineExpansion;
  final bool imageOnlyHover;
  final double collapsedWidth;
  final double expandedWidth;

  @override
  Widget build(BuildContext context) => child;
}
