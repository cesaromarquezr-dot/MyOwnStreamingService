import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'app_customization.dart';
import 'localization.dart';

/// Human-readable descriptions and concrete preview tokens for every social style.
const Map<String, String> socialThemeDescriptions = <String, String>{
  'Light': 'Bright, paper-like surfaces, dark readable text, clear borders, and generous spacing. Best for long posts and high readability.',
  'Dark': 'Deep charcoal backgrounds, quiet secondary text, and luminous accent controls. Designed for comfortable viewing in dim rooms.',
  'Minimalist': 'Restrained color, open whitespace, light dividers, and small accent details. Content stays more prominent than decoration.',
  'Flat': 'Solid colors, crisp edges, and almost no shadows. A direct, fast-looking interface with strong labels and simple controls.',
  'Skeuomorphic': 'Layered surfaces, warm gradients, highlights, and raised controls that feel like crafted physical objects.',
  'Material': 'Clear visual hierarchy, tonal surfaces, rounded cards, and distinct action buttons with familiar depth and ripple feedback.',
  'Neumorphism': 'Softly raised panels on a similar-color canvas with gentle paired shadows. Subtle and tactile, with intentionally low visual noise.',
  'Glassmorphism': 'Frosted translucent panels over colored layers, fine outlines, and luminous accents. Creates a lightweight, floating-glass effect.',
  'High Contrast': 'Near-black and white surfaces, bright focus accents, and heavier outlines. Prioritizes separation and visual accessibility.',
  'Brand-Centric': 'One signature accent repeated across avatars, actions, links, and selected states for a consistent product identity.',
  'Cyberpunk': 'Near-black panels, neon cyan and magenta accents, angular framing, and glow effects for a futuristic night-time look.',
  'Retro Futurism': 'Space-age colors, warm amber and coral highlights, geometric rules, and a nostalgic future-tech atmosphere.',
  'Brutalism': 'Hard edges, thick outlines, oversized labels, and bold blocks of color. Deliberately direct rather than polished or soft.',
  'Compact': 'Tighter spacing, smaller cards, concise labels, and dense rows. Useful when fitting more conversations, friends, or posts on screen.',
  'Casual': 'Friendly rounded cards, relaxed spacing, approachable accents, and clear controls. A balanced default for everyday social use.',
};

class SocialThemeTokens {
  const SocialThemeTokens({
    required this.canvas,
    required this.surface,
    required this.accent,
    required this.text,
    required this.muted,
    required this.border,
    required this.brightness,
    required this.radius,
    this.borderWidth = 1,
  });

  final Color canvas;
  final Color surface;
  final Color accent;
  final Color text;
  final Color muted;
  final Color border;
  final Brightness brightness;
  final double radius;
  final double borderWidth;

  bool get isLight => brightness == Brightness.light;
}

SocialThemeTokens socialThemeTokensFor(String style) {
  switch (style) {
    case 'Light':
      return const SocialThemeTokens(canvas: Color(0xFFF3F6FA), surface: Color(0xFFFFFFFF), accent: Color(0xFF315E9B), text: Color(0xFF172235), muted: Color(0xFF637083), border: Color(0xFFD7DFEA), brightness: Brightness.light, radius: 16);
    case 'Dark':
      return const SocialThemeTokens(canvas: Color(0xFF101217), surface: Color(0xFF1C2028), accent: Color(0xFF91B9FF), text: Color(0xFFF5F7FC), muted: Color(0xFFADB5C3), border: Color(0xFF3B4351), brightness: Brightness.dark, radius: 16);
    case 'Minimalist':
      return const SocialThemeTokens(canvas: Color(0xFFFAFAF8), surface: Color(0xFFFFFFFF), accent: Color(0xFF52676B), text: Color(0xFF202829), muted: Color(0xFF707A7B), border: Color(0xFFE7EAE7), brightness: Brightness.light, radius: 8);
    case 'Flat':
      return const SocialThemeTokens(canvas: Color(0xFFF1F5F4), surface: Color(0xFFFFFFFF), accent: Color(0xFF00897B), text: Color(0xFF142725), muted: Color(0xFF536764), border: Color(0xFFD2E1DE), brightness: Brightness.light, radius: 4);
    case 'Skeuomorphic':
      return const SocialThemeTokens(canvas: Color(0xFFE6DED1), surface: Color(0xFFF7F0E5), accent: Color(0xFF795238), text: Color(0xFF35271D), muted: Color(0xFF716052), border: Color(0xFFC5B39D), brightness: Brightness.light, radius: 18);
    case 'Material':
      return const SocialThemeTokens(canvas: Color(0xFFEFF3FA), surface: Color(0xFFFFFFFF), accent: Color(0xFF465FA8), text: Color(0xFF18233A), muted: Color(0xFF5D6880), border: Color(0xFFD8DFEF), brightness: Brightness.light, radius: 18);
    case 'Neumorphism':
      return const SocialThemeTokens(canvas: Color(0xFFE4E7EF), surface: Color(0xFFE4E7EF), accent: Color(0xFF6D5AA8), text: Color(0xFF303449), muted: Color(0xFF686D7D), border: Color(0xFFD3D8E3), brightness: Brightness.light, radius: 22);
    case 'Glassmorphism':
      return const SocialThemeTokens(canvas: Color(0xFF14233A), surface: Color(0xAA30465F), accent: Color(0xFF72E8ED), text: Color(0xFFF4FDFF), muted: Color(0xFFB8CEDF), border: Color(0x997DEBF0), brightness: Brightness.dark, radius: 22);
    case 'High Contrast':
      return const SocialThemeTokens(canvas: Color(0xFF000000), surface: Color(0xFF080808), accent: Color(0xFFFFFF00), text: Color(0xFFFFFFFF), muted: Color(0xFFFFFFFF), border: Color(0xFFFFFFFF), brightness: Brightness.dark, radius: 4, borderWidth: 2.5);
    case 'Brand-Centric':
      return const SocialThemeTokens(canvas: Color(0xFF1B101A), surface: Color(0xFF2B1B2B), accent: Color(0xFFFF6485), text: Color(0xFFFFF4F8), muted: Color(0xFFC9ACBC), border: Color(0xFF63364E), brightness: Brightness.dark, radius: 18);
    case 'Cyberpunk':
      return const SocialThemeTokens(canvas: Color(0xFF090916), surface: Color(0xFF17152D), accent: Color(0xFFFF3CF7), text: Color(0xFFF7F5FF), muted: Color(0xFFB7ACD8), border: Color(0xFF00EAD4), brightness: Brightness.dark, radius: 8, borderWidth: 1.5);
    case 'Retro Futurism':
      return const SocialThemeTokens(canvas: Color(0xFF261A31), surface: Color(0xFF38263F), accent: Color(0xFFFFAD65), text: Color(0xFFFFF2E6), muted: Color(0xFFD7B8BD), border: Color(0xFFEC718F), brightness: Brightness.dark, radius: 12);
    case 'Brutalism':
      return const SocialThemeTokens(canvas: Color(0xFFF3EEDB), surface: Color(0xFFFFF9E8), accent: Color(0xFFFF5938), text: Color(0xFF111111), muted: Color(0xFF303030), border: Color(0xFF111111), brightness: Brightness.light, radius: 0, borderWidth: 3);
    case 'Compact':
      return const SocialThemeTokens(canvas: Color(0xFF111C1C), surface: Color(0xFF1A2A29), accent: Color(0xFF2DD4BF), text: Color(0xFFF1FFFD), muted: Color(0xFFADC4C2), border: Color(0xFF35514E), brightness: Brightness.dark, radius: 8);
    case 'Casual':
    default:
      return const SocialThemeTokens(canvas: Color(0xFF11131A), surface: Color(0xFF20232D), accent: Color(0xFFF1A1B7), text: Color(0xFFF8F8FC), muted: Color(0xFFB8BECA), border: Color(0xFF383E4B), brightness: Brightness.dark, radius: 18);
  }
}

class SocialThemePickerField extends StatelessWidget {
  const SocialThemePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = socialThemeStyles.contains(value) ? value : 'Casual';
    final tokens = socialThemeTokensFor(style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        SocialThemePreview(style: style, height: 132),
        const SizedBox(height: 6),
        Text(socialThemeDescriptions[style]!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .72))),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final selected = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (sheetContext) => _SocialThemeGallerySheet(selectedStyle: style),
              );
              if (selected != null) onChanged(selected);
            },
            icon: Icon(Icons.palette_outlined, color: tokens.accent),
            label: const UniversalText('Preview all 15 styles'),
          ),
        ),
      ],
    );
  }
}

class _SocialThemeGallerySheet extends StatelessWidget {
  const _SocialThemeGallerySheet({required this.selectedStyle});

  final String selectedStyle;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .92,
      minChildSize: .58,
      maxChildSize: .97,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF101116),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 12, 10),
              child: Row(
                children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [UniversalText('Social theme gallery', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), SizedBox(height: 3), UniversalText('Choose a style to see its sample and description.', style: TextStyle(color: Colors.white60, fontSize: 12))])),
                  IconButton(tooltip: 'Close gallery', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: socialThemeStyles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final style = socialThemeStyles[index];
                  final selected = style == selectedStyle;
                  return Material(
                    color: const Color(0xFF1A1C24),
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(style),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [Expanded(child: Text(style, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))), if (selected) const Chip(avatar: Icon(Icons.check_circle, size: 16), label: UniversalText('Current'))]),
                            Text(socialThemeDescriptions[style]!, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35)),
                            const SizedBox(height: 9),
                            SocialThemePreview(style: style, height: 124),
                            const SizedBox(height: 8),
                            Align(alignment: Alignment.centerRight, child: FilledButton.tonal(onPressed: () => Navigator.of(context).pop(style), child: Text('Use $style'))),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A miniature profile/feed card that demonstrates the layout, contrast, edges,
/// depth, accent color, and control treatment of the chosen style.
class SocialThemePreview extends StatelessWidget {
  const SocialThemePreview({super.key, required this.style, this.height = 124});

  final String style;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = socialThemeTokensFor(style);
    final isGlass = style == 'Glassmorphism';
    final isCyberpunk = style == 'Cyberpunk';
    final isRetro = style == 'Retro Futurism';
    final isSkeuo = style == 'Skeuomorphic';
    final isNeo = style == 'Neumorphism';
    final isBrutal = style == 'Brutalism';
    final isMinimal = style == 'Minimalist';
    final isCompact = style == 'Compact';
    final radius = BorderRadius.circular(t.radius);

    final decoration = BoxDecoration(
      color: t.canvas,
      gradient: isRetro
          ? LinearGradient(colors: [t.canvas, t.surface, t.canvas], begin: Alignment.topLeft, end: Alignment.bottomRight)
          : isCyberpunk
              ? LinearGradient(colors: [t.canvas, const Color(0xFF21102F), t.canvas], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : isSkeuo
                  ? LinearGradient(colors: [Colors.white, t.canvas, const Color(0xFFD7C7B2)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
      border: Border.all(color: t.border.withValues(alpha: isMinimal ? .65 : 1), width: t.borderWidth),
      borderRadius: radius,
      boxShadow: isSkeuo
          ? [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 8, offset: const Offset(0, 4)), const BoxShadow(color: Colors.white54, blurRadius: 3, offset: Offset(0, -1))]
          : isNeo
              ? [BoxShadow(color: Colors.white.withValues(alpha: .88), blurRadius: 9, offset: const Offset(-4, -4)), BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 9, offset: const Offset(4, 4))]
              : isCyberpunk
                  ? [BoxShadow(color: t.accent.withValues(alpha: .22), blurRadius: 12, spreadRadius: 1)]
                  : isBrutal
                      ? const [BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4))]
                      : null,
    );

    final inside = Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 8 : 11),
      decoration: BoxDecoration(
        color: isGlass ? t.surface.withValues(alpha: .72) : t.surface,
        borderRadius: BorderRadius.circular((t.radius - 3).clamp(0, 20).toDouble()),
        border: Border.all(color: t.border.withValues(alpha: isMinimal ? .5 : .8), width: isBrutal ? 2.5 : 1),
        gradient: isSkeuo ? LinearGradient(colors: [Colors.white.withValues(alpha: .68), t.surface, t.surface]) : null,
        boxShadow: isSkeuo
            ? [BoxShadow(color: Colors.black.withValues(alpha: .13), blurRadius: 4, offset: const Offset(0, 2))]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: isCompact ? 25 : 29,
              height: isCompact ? 25 : 29,
              decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle, boxShadow: isCyberpunk ? [BoxShadow(color: t.accent.withValues(alpha: .65), blurRadius: 8)] : null),
              child: Icon(Icons.person_rounded, size: isCompact ? 15 : 17, color: t.isLight ? Colors.white : const Color(0xFF13131A)),
            ),
            const SizedBox(width: 7),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              UniversalText('Alex Morgan', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.text, fontSize: isCompact ? 10 : 11, fontWeight: FontWeight.w900, letterSpacing: isBrutal ? .4 : 0)),
              UniversalText('Shared a new post', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.muted, fontSize: isCompact ? 8 : 9)),
            ])),
            if (style == 'High Contrast') Icon(Icons.circle, size: 11, color: t.accent),
            if (isRetro) Icon(Icons.auto_awesome, size: 15, color: t.accent),
            if (isCyberpunk) Icon(Icons.bolt, size: 15, color: t.border),
          ]),
          SizedBox(height: isCompact ? 5 : 8),
          UniversalText('A little inspiration for today.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.text, fontSize: isCompact ? 9 : 10, fontWeight: FontWeight.w600)),
          SizedBox(height: isCompact ? 5 : 7),
          Row(children: [
            _previewAction(t, Icons.favorite_border_rounded, 'Like', isCompact),
            const SizedBox(width: 6),
            _previewAction(t, Icons.chat_bubble_outline_rounded, 'Reply', isCompact),
            const Spacer(),
            Container(width: 33, height: 4, decoration: BoxDecoration(color: t.accent.withValues(alpha: .85), borderRadius: BorderRadius.circular(isBrutal ? 0 : 4))),
          ]),
        ],
      ),
    );

    Widget content = ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(7),
        decoration: decoration,
        child: inside,
      ),
    );

    if (isGlass) {
      content = ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Container(height: height, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF283C80), Color(0xFF5A2768), Color(0xFF144D60)]))),
            Positioned(left: -12, top: 8, child: Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFF72E8ED).withValues(alpha: .35), shape: BoxShape.circle))),
            Positioned(right: 8, bottom: 2, child: Container(width: 66, height: 66, decoration: BoxDecoration(color: const Color(0xFFFF3CF7).withValues(alpha: .26), shape: BoxShape.circle))),
            Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: Padding(padding: const EdgeInsets.all(7), child: inside))),
          ],
        ),
      );
    }

    return SizedBox(height: height, width: double.infinity, child: content);
  }

  Widget _previewAction(SocialThemeTokens t, IconData icon, String label, bool compact) {
    final radius = style == 'Brutalism' || style == 'Flat' ? 2.0 : style == 'Compact' ? 5.0 : 10.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(color: t.accent.withValues(alpha: t.isLight ? .12 : .18), borderRadius: BorderRadius.circular(radius), border: style == 'High Contrast' || style == 'Brutalism' ? Border.all(color: t.border, width: style == 'Brutalism' ? 2 : 1) : null),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: compact ? 10 : 11, color: t.accent), const SizedBox(width: 3), Text(label, style: TextStyle(fontSize: compact ? 8 : 9, color: t.text, fontWeight: FontWeight.w800))]),
    );
  }
}
