import 'package:flutter/material.dart';

/// Shared category-filter UI for liked songs, movies, TV shows and any future
/// typed library view. Filtering is supplied by the parent; this widget does
/// not own media data or create duplicate category systems.
class CategoryFilterChips extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const CategoryFilterChips({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final category in categories) ...[
            ChoiceChip(
              label: Text(category),
              selected: category == selectedCategory,
              onSelected: (_) => onSelected(category),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
