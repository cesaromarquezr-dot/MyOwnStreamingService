import 'package:flutter/material.dart';

/// Shared ownership wording for every recommendation shelf.
String recommendationOwnershipLabel(bool isOwned) =>
    isOwned ? 'Owned' : 'Not owned';

/// Purchase links are only useful when the current profile does not already
/// have the recommended media in its accessible library.
bool shouldShowBuySectionForOwnership({required bool isOwned}) => !isOwned;

/// Compact, consistent status marker shown on recommendation cards.
class RecommendationOwnershipBadge extends StatelessWidget {
  const RecommendationOwnershipBadge({
    super.key,
    required this.isOwned,
    this.compact = false,
  });

  final bool isOwned;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = isOwned ? const Color(0xFF8BE3A1) : const Color(0xFFFFD27A);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xE817171D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOwned ? Icons.check_circle_rounded : Icons.shopping_bag_outlined,
            size: compact ? 10 : 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            recommendationOwnershipLabel(isOwned),
            style: TextStyle(
              color: color,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
