// FILE: lib/connected_experience.dart
// Purpose: Shared connected-context presentation for major platform pages.
//
// This widget deliberately does not own navigation or domain behavior. Each
// callback routes to the canonical capability owner for that destination.

import 'package:flutter/material.dart';

class ConnectedDestination {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const ConnectedDestination({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class ConnectedExperienceBar extends StatelessWidget {
  final String? title;
  final List<ConnectedDestination> destinations;

  const ConnectedExperienceBar({
    super.key,
    this.title,
    this.destinations = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title!.trim().isNotEmpty) ...[
          Text(
            title!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: destinations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final destination = destinations[index];
              return ActionChip(
                avatar: Icon(destination.icon, size: 17),
                label: Text(destination.label),
                onPressed: destination.onTap,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
