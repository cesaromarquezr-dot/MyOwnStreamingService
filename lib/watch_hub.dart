import 'package:flutter/material.dart';

import 'my_tv.dart';
import 'navigation_hubs.dart';
import 'public_live_tv.dart';

/// Legacy route adapter retained for old deep links. The combined Live TV / My
/// TV landing page has been retired: each television destination now opens
/// directly, while the primary Watch destination resolves to the library.
enum WatchHubMode { combined, liveTv, myTv, library }

class WatchHubScreen extends StatelessWidget {
  final WatchHubMode initialMode;
  final bool standalone;

  const WatchHubScreen({
    super.key,
    this.initialMode = WatchHubMode.library,
    this.standalone = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (initialMode) {
      case WatchHubMode.liveTv:
        return const PublicLiveTvScreen();
      case WatchHubMode.myTv:
        return const MyTvScreen();
      case WatchHubMode.combined:
      case WatchHubMode.library:
        return const LibraryHubScreen();
    }
  }
}
