import 'package:flutter/material.dart';

import 'performer_universe.dart';

/// Backwards-compatible entry point used by Library Hubs and Character Discovery.
/// The destination now presents the complete Performer Universe instead of an
/// acting-only timeline, while retaining existing call sites and local credits.
class PeopleCareerTimelineScreen extends StatelessWidget {
  const PeopleCareerTimelineScreen({
    super.key,
    required this.personName,
    this.localCredits = const <Map<String, dynamic>>[],
    this.allowCreateIfMissing = true,
  });

  final String personName;
  final List<Map<String, dynamic>> localCredits;
  final bool allowCreateIfMissing;

  @override
  Widget build(BuildContext context) => PerformerUniverseScreen(
        performerName: personName,
        localCredits: localCredits,
        allowCreateIfMissing: allowCreateIfMissing,
      );
}
