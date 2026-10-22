// FILE: lib/cinematic_title.dart
// Purpose: Authorized title-logo presentation with a readable, title-specific fallback.
// Logos are supplied as explicit catalog metadata; trailer frames are never scraped here.

import 'package:flutter/material.dart';

import 'app_core.dart';

enum CinematicTitlePlacement { hero, detail }

/// Displays the authorized logo artwork for a title, or a responsive stylized
/// text fallback when a logo is missing, unauthorized, or fails to load.
///
/// The metadata label remains accessible to screen readers even when the logo
/// is an image. OS reduced-motion settings override per-title animation.
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

  bool get _canUseLogo {
    if (!media.titleLogoAuthorized) return false;
    final raw = media.titleLogoUrl?.trim() ?? '';
    final uri = Uri.tryParse(raw);
    return uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                (uri.host == 'localhost' || uri.host == '127.0.0.1')));
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldAnimate = (animate ?? media.titleRevealAnimation) && !reduceMotion;
    final duration = shouldAnimate
        ? const Duration(milliseconds: 520)
        : Duration.zero;
    final contentHeight = height ??
        (placement == CinematicTitlePlacement.hero ? 106.0 : 98.0);
    final contentWidth = maxWidth ??
        (placement == CinematicTitlePlacement.hero ? 720.0 : 680.0);

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
                    CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                  ),
                  child: child,
                ),
              ),
              child: SizedBox.expand(
                key: ValueKey<String>(
                  '${media.id}:${_canUseLogo ? media.titleLogoUrl : 'text'}',
                ),
                child: _canUseLogo
                    ? Image.network(
                        media.titleLogoUrl!.trim(),
                        fit: BoxFit.contain,
                        alignment: _alignment,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => _fallback(context),
                      )
                    : _fallback(context),
              ),
            ),
          ),
        ),
      ),
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
    final baseSize = hero ? (width < 600 ? 31.0 : 45.0) : (width < 600 ? 30.0 : 38.0);
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
            const Shadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, 3)),
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
    if (value.startsWith('0x') || value.startsWith('0X')) value = value.substring(2);
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
    var key = (media.titleStyleKey ?? '').trim().toLowerCase().replaceAll('-', '');
    if (key.isEmpty) {
      final genres = <String>[...media.genres, ...media.tags]
          .map((value) => value.toLowerCase())
          .join(' ');
      if (genres.contains('horror')) {
        key = 'horror';
      } else if (genres.contains('science fiction') || genres.contains('sci-fi') || genres.contains('scifi')) {
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
      'horror' => const _CinematicStyle(Color(0xFFE6535D), FontWeight.w900, 1.4, false, true),
      'scifi' => const _CinematicStyle(Color(0xFF8CE8FF), FontWeight.w800, 1.8, false, true),
      'western' => const _CinematicStyle(Color(0xFFF0D08A), FontWeight.w900, .5, false, false),
      'romance' || 'elegant' => const _CinematicStyle(Color(0xFFF7DDEB), FontWeight.w700, .3, true, false),
      'fantasy' => const _CinematicStyle(Color(0xFFD4BCFF), FontWeight.w800, .6, false, true),
      'retro' => const _CinematicStyle(Color(0xFFFFC36A), FontWeight.w900, 2.0, false, true),
      'animation' => const _CinematicStyle(Color(0xFFFFE27A), FontWeight.w900, -.3, false, true),
      'thriller' => const _CinematicStyle(Color(0xFFF0F0F0), FontWeight.w900, 1.25, false, false),
      'comedy' => const _CinematicStyle(Color(0xFFFFE17E), FontWeight.w900, -.2, false, false),
      _ => const _CinematicStyle(Colors.white, FontWeight.w900, .1, false, false),
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
