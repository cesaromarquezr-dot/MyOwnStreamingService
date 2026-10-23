// FILE: lib/cinematic_title.dart
// Purpose: Shared cinematic title presentation for Home hero and media details.
// Artwork is shown only when the selected source mode is explicit and the user
// has confirmed authorization. Trailer/movie stills are supplied assets; this
// widget does not silently scrape or copy frames from a video.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'app_core.dart';

enum CinematicTitlePlacement { hero, detail }

/// Stable presentation modes serialized in MediaItem.titleArtworkMode.
/// Keep these values in sync with the import/editor dropdown and SQL migration.
const Set<String> cinematicTitleArtworkModes = <String>{
  'auto',
  'text',
  'logo',
  'trailer_title_card',
  'movie_title_card',
  'case_cover',
};

String normalizeTitleArtworkMode(String? value) {
  final mode = (value ?? '').trim().toLowerCase();
  return cinematicTitleArtworkModes.contains(mode) ? mode : 'auto';
}

/// Per-surface override values include `inherit`, which preserves older records
/// that only have the shared `titleArtworkMode` / `titleLogoUrl` fields.
const Set<String> cinematicScreenTitleArtworkModes = <String>{
  'inherit',
  ...cinematicTitleArtworkModes,
};

String normalizeScreenTitleArtworkMode(String? value) {
  final mode = (value ?? '').trim().toLowerCase();
  return cinematicScreenTitleArtworkModes.contains(mode) ? mode : 'inherit';
}

/// Displays a selected authorized title logo, title-card still, or physical
/// case cover, then falls back to a readable genre-aware text title.
///
/// Legacy `titleLogoUrl`/`titleArtworkMode` are used when the selected screen
/// is set to `inherit`. An explicit screen choice uses that screen's own URL and
/// authorization flag, so a trailer title card can be used in Home while a
/// movie/show title-card frame is used on Details. `imageUrl` supplies case art.
/// Screen readers always receive the real `media.title`.
class CinematicTitle extends StatelessWidget {
  final MediaItem media;
  final CinematicTitlePlacement placement;
  final TextAlign textAlign;
  final double? maxWidth;
  final double? height;
  final bool? animate;

  const CinematicTitle({
    super.key,
    required this.media,
    this.placement = CinematicTitlePlacement.detail,
    this.textAlign = TextAlign.start,
    this.maxWidth,
    this.height,
    this.animate,
  });

  String get _screenMode => normalizeScreenTitleArtworkMode(
        placement == CinematicTitlePlacement.hero
            ? media.heroTitleArtworkMode
            : media.detailTitleArtworkMode,
      );

  String get _mode => _screenMode == 'inherit'
      ? normalizeTitleArtworkMode(media.titleArtworkMode)
      : normalizeTitleArtworkMode(_screenMode);

  bool get _usesLegacyArtwork {
    if (_screenMode == 'inherit') return true;
    final perScreenUrl = placement == CinematicTitlePlacement.hero
        ? media.heroTitleArtworkUrl
        : media.detailTitleArtworkUrl;
    // If the override mode matches the shared mode and no dedicated URL was
    // entered, the existing shared asset remains a compatible fallback.
    return (perScreenUrl?.trim().isEmpty ?? true) &&
        _mode == normalizeTitleArtworkMode(media.titleArtworkMode);
  }

  String? get _rawArtworkUrl {
    if (_usesLegacyArtwork) return media.titleLogoUrl;
    return placement == CinematicTitlePlacement.hero
        ? media.heroTitleArtworkUrl
        : media.detailTitleArtworkUrl;
  }

  bool get _artworkAuthorized {
    if (_screenMode == 'inherit') return media.titleLogoAuthorized;
    if (_mode == 'case_cover') {
      return placement == CinematicTitlePlacement.hero
          ? media.heroTitleArtworkAuthorized
          : media.detailTitleArtworkAuthorized;
    }
    return _usesLegacyArtwork
        ? media.titleLogoAuthorized
        : placement == CinematicTitlePlacement.hero
            ? media.heroTitleArtworkAuthorized
            : media.detailTitleArtworkAuthorized;
  }

  String? get _artworkUrl => _safeImageUrl(_rawArtworkUrl);

  String? _safeImageUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme == 'https') return value;
    if (uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      return value;
    }
    return null;
  }

  bool get _isTitleCardMode =>
      _mode == 'trailer_title_card' || _mode == 'movie_title_card';

  bool get _canUseDedicatedAsset =>
      _artworkAuthorized &&
      _mode != 'text' &&
      _mode != 'case_cover' &&
      _artworkUrl != null;

  bool get _canUseCaseCover =>
      _mode == 'case_cover' &&
      _artworkAuthorized &&
      _safeImageUrl(media.imageUrl) != null;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldAnimate =
        (animate ?? media.titleRevealAnimation) && !reduceMotion;
    final duration =
        shouldAnimate ? const Duration(milliseconds: 520) : Duration.zero;
    final baseHeight =
        height ?? (placement == CinematicTitlePlacement.hero ? 106.0 : 98.0);
    final contentWidth =
        maxWidth ?? (placement == CinematicTitlePlacement.hero ? 720.0 : 680.0);
    // Title-card frames contain more visual information than a transparent
    // logo, so provide a larger landscape viewing area without cropping them.
    final contentHeight = _canUseDedicatedAsset && _isTitleCardMode
        ? math
            .max(baseHeight,
                placement == CinematicTitlePlacement.hero ? 190.0 : 150.0)
            .toDouble()
        : baseHeight;

    final Widget content;
    final String visualKey;
    if (_canUseCaseCover) {
      content = _caseCoverAndText(context, contentHeight);
      visualKey = '${media.id}:case-cover:${media.imageUrl}:${placement.name}';
    } else if (_canUseDedicatedAsset) {
      final url = _artworkUrl!;
      content = Image.network(
        url,
        fit: BoxFit.contain,
        alignment: _alignment,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _fallback(context),
      );
      visualKey = '${media.id}:$_mode:$url';
    } else {
      content = _fallback(context);
      visualKey = '${media.id}:text:${media.title}:${placement.name}:$_mode';
    }

    return Semantics(
      header: true,
      label: media.title,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentWidth),
          child: SizedBox(
            width: double.infinity,
            height: contentHeight,
            child: AnimatedSwitcher(
              duration: duration,
              reverseDuration: duration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: .975, end: 1).animate(
                    CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic),
                  ),
                  child: child,
                ),
              ),
              child: SizedBox.expand(
                key: ValueKey<String>(visualKey),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _caseCoverAndText(BuildContext context, double contentHeight) {
    final url = _safeImageUrl(media.imageUrl);
    if (url == null) return _fallback(context);
    final coverWidth = math.min(contentHeight * .66, 118.0).toDouble();
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: coverWidth,
            height: contentHeight,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A1A1A),
                alignment: Alignment.center,
                child: const Icon(Icons.movie_outlined, color: Colors.white54),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: _fallback(context)),
      ],
    );
  }

  Alignment get _alignment => switch (textAlign) {
        TextAlign.center => Alignment.center,
        TextAlign.right || TextAlign.end => Alignment.centerRight,
        _ => Alignment.centerLeft,
      };

  Widget _fallback(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hero = placement == CinematicTitlePlacement.hero;
    final baseSize =
        hero ? (width < 600 ? 31.0 : 45.0) : (width < 600 ? 30.0 : 38.0);
    final style = _styleFor(media);
    final customColor = _parseColor(media.titleAccentColor);
    final color = customColor ?? style.color;
    return Align(
      alignment: _alignment,
      child: Text(
        media.title,
        textAlign: textAlign,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: baseSize,
          fontWeight: style.weight,
          fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
          letterSpacing: style.letterSpacing,
          height: .99,
          shadows: <Shadow>[
            const Shadow(
                color: Colors.black87, blurRadius: 18, offset: Offset(0, 3)),
            if (style.glow)
              Shadow(color: color.withValues(alpha: .5), blurRadius: 22),
          ],
        ),
      ),
    );
  }

  static Color? _parseColor(String? raw) {
    var value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('#')) value = value.substring(1);
    if (value.startsWith('0x') || value.startsWith('0X')) {
      value = value.substring(2);
    }
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8 || !RegExp(r'^[0-9A-Fa-f]{8}$').hasMatch(value)) {
      return null;
    }
    try {
      return Color(int.parse(value, radix: 16));
    } on FormatException {
      return null;
    }
  }

  static _CinematicStyle _styleFor(MediaItem media) {
    var key =
        (media.titleStyleKey ?? '').trim().toLowerCase().replaceAll('-', '');
    if (key.isEmpty) {
      final genres = <String>[...media.genres, ...media.tags]
          .map((value) => value.toLowerCase())
          .join(' ');
      if (genres.contains('horror')) {
        key = 'horror';
      } else if (genres.contains('science fiction') ||
          genres.contains('sci-fi') ||
          genres.contains('scifi')) {
        key = 'scifi';
      } else if (genres.contains('western')) {
        key = 'western';
      } else if (genres.contains('romance') || genres.contains('romantic')) {
        key = 'romance';
      } else if (genres.contains('fantasy')) {
        key = 'fantasy';
      } else if (genres.contains('animation') || genres.contains('animated')) {
        key = 'animation';
      } else if (genres.contains('thriller')) {
        key = 'thriller';
      } else if (genres.contains('comedy')) {
        key = 'comedy';
      }
    }

    return switch (key) {
      'horror' => const _CinematicStyle(
          Color(0xFFE6535D), FontWeight.w900, 1.4, false, true),
      'scifi' => const _CinematicStyle(
          Color(0xFF8CE8FF), FontWeight.w800, 1.8, false, true),
      'western' => const _CinematicStyle(
          Color(0xFFF0D08A), FontWeight.w900, .5, false, false),
      'romance' || 'elegant' => const _CinematicStyle(
          Color(0xFFF7DDEB), FontWeight.w700, .3, true, false),
      'fantasy' => const _CinematicStyle(
          Color(0xFFD4BCFF), FontWeight.w800, .6, false, true),
      'retro' => const _CinematicStyle(
          Color(0xFFFFC36A), FontWeight.w900, 2.0, false, true),
      'animation' => const _CinematicStyle(
          Color(0xFFFFE27A), FontWeight.w900, -.3, false, true),
      'thriller' => const _CinematicStyle(
          Color(0xFFF0F0F0), FontWeight.w900, 1.25, false, false),
      'comedy' => const _CinematicStyle(
          Color(0xFFFFE17E), FontWeight.w900, -.2, false, false),
      _ =>
        const _CinematicStyle(Colors.white, FontWeight.w900, .1, false, false),
    };
  }
}

class _CinematicStyle {
  final Color color;
  final FontWeight weight;
  final double letterSpacing;
  final bool italic;
  final bool glow;

  const _CinematicStyle(
    this.color,
    this.weight,
    this.letterSpacing,
    this.italic,
    this.glow,
  );
}
