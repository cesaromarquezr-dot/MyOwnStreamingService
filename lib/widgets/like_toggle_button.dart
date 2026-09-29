import 'package:flutter/material.dart';

/// Reusable presentation for the canonical Universal Likes capability.
/// The caller owns persistence; this widget only manages the interaction and
/// animated visual state.
class LikeToggleButton extends StatelessWidget {
  final bool liked;
  final VoidCallback onPressed;
  final bool showLabel;
  final bool compact;

  const LikeToggleButton({
    super.key,
    required this.liked,
    required this.onPressed,
    this.showLabel = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: child,
      ),
      child: Icon(
        liked ? Icons.favorite : Icons.favorite_border,
        key: ValueKey(liked),
      ),
    );

    if (!showLabel) {
      return IconButton(
        tooltip: liked ? 'Liked' : 'Like',
        padding: compact ? EdgeInsets.zero : null,
        onPressed: onPressed,
        icon: icon,
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: Text(
          liked ? 'Liked' : 'Like',
          key: ValueKey(liked),
        ),
      ),
    );
  }
}
