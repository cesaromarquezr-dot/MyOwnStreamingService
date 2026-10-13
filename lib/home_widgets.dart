// Home dashboard storage visualization and layout helpers.
import 'package:flutter/material.dart';

import 'app_core.dart';
import 'music.dart';

class HomeStorageProgressBar extends StatelessWidget {
  final double thickness;
  final Axis axis;
  final bool compact;
  const HomeStorageProgressBar({super.key, required this.thickness, required this.axis, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final account = AppController.instance.currentAccount;
    final total = (account?.storageLimitBytes ?? 1000000000000).toDouble();
    final used = (account?.storageUsedBytes ?? 0).toDouble().clamp(0.0, total).toDouble();
    final media = AppController.instance.library;
    final movies = media.where((m) => m.type.toLowerCase() == 'movie').length.toDouble();
    final series = media.where((m) => m.type.toLowerCase().contains('tv') || m.type.toLowerCase().contains('series') || m.type.toLowerCase().contains('show')).length.toDouble();
    final music = MusicStorageCount.value;
    final contentUnits = movies + series + music;
    final available = (total - used).clamp(0, total).toDouble();
    final portions = <String, double>{
      'Movies': contentUnits == 0 ? 0 : used * (movies / contentUnits),
      'Series': contentUnits == 0 ? 0 : used * (series / contentUnits),
      'Music': contentUnits == 0 ? 0 : used * (music / contentUnits),
      'Available': available,
    };
    final labels = <Widget>[];
    for (final entry in portions.entries) {
      final fraction = entry.value / total;
      labels.add(Expanded(flex: (fraction * 1000).round().clamp(1, 1000).toInt(), child: Tooltip(message: '${entry.key}: ${(entry.value / total * 100).toStringAsFixed(1)}%', child: Container(margin: const EdgeInsets.symmetric(horizontal: .5), height: thickness, decoration: BoxDecoration(color: _categoryColor(entry.key))))));
    }
    final bar = ClipRRect(borderRadius: BorderRadius.circular(thickness), child: axis == Axis.horizontal ? Row(children: labels) : Column(children: labels));
    if (compact) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), child: axis == Axis.horizontal
          ? bar
          : SizedBox(width: thickness, height: 70, child: bar));
    }
    final legend = <Widget>[];
    for (final entry in portions.entries) {
      legend.add(Expanded(child: Text(entry.key, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white60))));
    }
    return Padding(padding: const EdgeInsets.all(10), child: axis == Axis.horizontal ? Column(children: [bar, const SizedBox(height: 5), Row(children: legend)]) : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [SizedBox(width: thickness, height: 210, child: bar), const SizedBox(width: 7), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: legend))]));
  }

  Color _categoryColor(String key) => switch (key) { 'Movies' => Colors.redAccent, 'Series' => Colors.blueAccent, 'Music' => Colors.purpleAccent, _ => Colors.greenAccent };
}


class HomePositionedLayout extends StatelessWidget {
  final String navbarPosition;
  final String storagePosition;
  final double storageThickness;
  final Widget navbar;
  final Widget child;

  const HomePositionedLayout({
    super.key,
    required this.navbarPosition,
    required this.storagePosition,
    required this.storageThickness,
    required this.navbar,
    required this.child,
  });

  static const _sides = <String>['Top', 'Bottom', 'Left', 'Right'];

  @override
  Widget build(BuildContext context) {
    final bySide = <String, List<int>>{for (final side in _sides) side: <int>[]};
    if (_sides.contains(navbarPosition)) bySide[navbarPosition]!.add(0);
    if (_sides.contains(storagePosition)) bySide[storagePosition]!.add(1);

    final top = _edgeSize(bySide['Top']!, horizontal: true);
    final bottom = _edgeSize(bySide['Bottom']!, horizontal: true);
    final left = _edgeSize(bySide['Left']!, horizontal: false);
    final right = _edgeSize(bySide['Right']!, horizontal: false);

    Widget item(int index, int count) {
      final side = _itemSide(index, bySide);
      // Left/right edges use compact controls to prevent vertical overflow.
      final compact = count > 1 || side == 'Left' || side == 'Right';
      if (index == 0) return navbar;
      if (index == 1) {
        return HomeStorageProgressBar(
          thickness: storageThickness,
          axis: side == 'Left' || side == 'Right' ? Axis.vertical : Axis.horizontal,
          compact: compact,
        );
      }
      return const SizedBox.shrink();
    }

    Widget edge(String side) {
      final indexes = bySide[side]!;
      if (indexes.isEmpty) return const SizedBox.shrink();
      final horizontal = side == 'Top' || side == 'Bottom';
      final count = indexes.length;
      if (horizontal) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final index in indexes) Expanded(child: Center(child: item(index, count)))],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final index in indexes) Expanded(child: Center(child: item(index, count)))],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(padding: EdgeInsets.only(top: top, bottom: bottom, left: left, right: right), child: child),
        if (bySide['Top']!.isNotEmpty) Positioned(top: 0, left: 0, right: 0, height: top, child: SafeArea(bottom: false, child: edge('Top'))),
        if (bySide['Bottom']!.isNotEmpty) Positioned(bottom: 0, left: 0, right: 0, height: bottom, child: SafeArea(top: false, child: edge('Bottom'))),
        if (bySide['Left']!.isNotEmpty) Positioned(top: 0, bottom: 0, left: 0, width: left, child: SafeArea(right: false, child: edge('Left'))),
        if (bySide['Right']!.isNotEmpty) Positioned(top: 0, bottom: 0, right: 0, width: right, child: SafeArea(left: false, child: edge('Right'))),
        if (navbarPosition == 'Floating') Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(top: false, child: Center(child: navbar))),
      ],
    );
  }

  String _itemSide(int index, Map<String, List<int>> bySide) {
    for (final entry in bySide.entries) {
      if (entry.value.contains(index)) return entry.key;
    }
    return 'Bottom';
  }

  double _edgeSize(List<int> indexes, {required bool horizontal}) {
    if (indexes.isEmpty) return 0;
    final count = indexes.length;
    if (count == 1) {
      if (indexes.first == 0) return horizontal ? 84 : 104;
      if (indexes.first == 1) return horizontal ? 76 : 230;
      return horizontal ? 235 : 325;
    }
    // Multiple controls share the same edge. Each receives a slot, so the edge
    // only needs to be tall/wide enough for compact controls.
    return horizontal ? 86 : 92;
  }
}

class MusicStorageCount {
  static double get value => MusicLibraryStore.instance.tracks.length.toDouble();
}
