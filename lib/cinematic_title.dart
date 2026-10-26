// FILE: lib/cinematic_title.dart
// Purpose: Shared cinematic title presentation for Home hero and media details.
// Artwork is shown only when the selected source mode is explicit and the user
// has confirmed authorization. Trailer/movie stills are supplied assets; this
// widget does not silently scrape or copy frames from a video.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'app_core.dart';
import 'cinematic_title_fonts.dart';
import 'core/services/cinematic_title_metadata_service.dart';

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

  bool get _canDiscoverAutomaticLogo {
    if (!_artworkAuthorized ||
        _artworkUrl != null ||
        (_mode != 'auto' && _mode != 'logo')) {
      return false;
    }
    final kind = media.type.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final isTv = kind == 'tv' ||
        kind == 'tvshow' ||
        kind == 'series' ||
        kind == 'television' ||
        kind == 'tvseries';
    final isMovie = kind == 'movie' || kind == 'film' || kind == 'featurefilm';
    return (isTv || isMovie) && CinematicTitleMetadataService.isConfigured;
  }

  bool get _isTvMedia {
    final kind = media.type.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return kind == 'tv' ||
        kind == 'tvshow' ||
        kind == 'series' ||
        kind == 'television' ||
        kind == 'tvseries';
  }

  bool get _canUseCaseCover =>
      _mode == 'case_cover' &&
      _artworkAuthorized &&
      _safeImageUrl(media.imageUrl) != null;

  @override
  Widget build(BuildContext context) {
    if (!_canDiscoverAutomaticLogo) return _buildResolved(context, null);
    final future = CinematicTitleMetadataService.lookupTitleLogo(
      title: media.title,
      isTv: _isTvMedia,
      year: media.releaseYear ?? media.seriesStartYear,
    );
    return FutureBuilder<String?>(
      future: future,
      builder: (context, snapshot) => _buildResolved(context, snapshot.data),
    );
  }

  Widget _buildResolved(BuildContext context, String? detectedLogoUrl) {
    final effectiveArtworkUrl = _artworkUrl ?? _safeImageUrl(detectedLogoUrl);
    final canUseDetectedOrSavedLogo = _artworkAuthorized &&
        _mode != 'text' &&
        _mode != 'case_cover' &&
        effectiveArtworkUrl != null;
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
    final contentHeight = canUseDetectedOrSavedLogo && _isTitleCardMode
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
    } else if (canUseDetectedOrSavedLogo) {
      final url = effectiveArtworkUrl;
      content = Image.network(
        url,
        fit: BoxFit.contain,
        alignment: _alignment,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _fallback(context),
      );
      visualKey = '${media.id}:$_mode:$url:${placement.name}';
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
    final style = CinematicTitleFonts.resolveMedia(media);
    final customColor = _parseColor(media.titleFontColor) ??
        _parseColor(media.titleAccentColor);
    final color = customColor ?? style.color;
    final lengthScale = media.title.runes.length > 30
        ? .76
        : media.title.runes.length > 24
            ? .84
            : media.title.runes.length > 18
                ? .92
                : 1.0;
    final family = (media.titleFontFamily?.trim().isNotEmpty == true
        ? media.titleFontFamily!.trim()
        : style.fontFamily.trim());
    final fallbackFamily =
        (media.titleFontFallbackFamily?.trim().isNotEmpty == true
            ? media.titleFontFallbackFamily!.trim()
            : style.fallbackFamily);
    final fontWeight = _weightFromValue(media.titleFontWeight) ?? style.weight;
    final letterSpacing = media.titleFontLetterSpacing ?? style.letterSpacing;
    final fontSize = media.titleFontSize != null && media.titleFontSize! > 0
        ? baseSize * (media.titleFontSize! / 42.0).clamp(.6, 1.35)
        : baseSize * style.sizeScale;
    final customShadowColor = _parseColor(media.titleFontShadowColor);
    final shadowBlur = (media.titleFontShadowBlur ?? (style.glow ? 22.0 : 18.0))
        .clamp(0.0, 80.0)
        .toDouble();
    return Align(
      alignment: _alignment,
      child: Text(
        media.title,
        textAlign: textAlign,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontFamily: family.isEmpty ? null : family,
          fontFamilyFallback: <String>[
            fallbackFamily,
            if (fallbackFamily != 'sans-serif') 'sans-serif',
          ],
          fontSize: (fontSize * lengthScale)
              .clamp(hero ? 21.0 : 20.0, baseSize * 1.18)
              .toDouble(),
          fontWeight: fontWeight,
          fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
          letterSpacing: letterSpacing,
          height: .99,
          shadows: <Shadow>[
            Shadow(
              color: customShadowColor ?? Colors.black87,
              blurRadius: shadowBlur,
              offset: const Offset(0, 3),
            ),
            if (customShadowColor == null && style.glow)
              Shadow(
                  color: color.withValues(alpha: .5), blurRadius: shadowBlur),
          ],
        ),
      ),
    );
  }

  static FontWeight? _weightFromValue(int? value) {
    if (value == null) return null;
    if (value <= 100) return FontWeight.w100;
    if (value <= 200) return FontWeight.w200;
    if (value <= 300) return FontWeight.w300;
    if (value <= 400) return FontWeight.w400;
    if (value <= 500) return FontWeight.w500;
    if (value <= 600) return FontWeight.w600;
    if (value <= 700) return FontWeight.w700;
    if (value <= 800) return FontWeight.w800;
    return FontWeight.w900;
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
}
