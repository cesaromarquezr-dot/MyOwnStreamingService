import 'package:material_ui/material_ui.dart';

import 'my_tv.dart';
import 'navigation_hubs.dart';

/// Legacy route adapter retained for old deep links. My TV opens directly,
/// while the primary Watch destination resolves to the library.
enum WatchHubMode { combined, myTv, library }

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
      case WatchHubMode.myTv:
        return const MyTvScreen();
      case WatchHubMode.combined:
      case WatchHubMode.library:
        return const LibraryHubScreen();
    }
  }
}
