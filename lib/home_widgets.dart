// Home widgets for live scores and customizable server-storage visualization.
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'music.dart';

class HomeLiveSportsWidget extends StatefulWidget {
  const HomeLiveSportsWidget({super.key});
  @override
  State<HomeLiveSportsWidget> createState() => _HomeLiveSportsWidgetState();
}

class _HomeLiveSportsWidgetState extends State<HomeLiveSportsWidget> {
  List<Map<String, dynamic>> games = <Map<String, dynamic>>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AppController.instance.backendApi.getLiveSports();
      final raw = data['games'];
      final next = raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
      if (mounted) setState(() => games = next.take(6).toList());
    } catch (_) {
      if (mounted) setState(() => games = <Map<String, dynamic>>[]);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.sports_score_rounded), const SizedBox(width: 8), const Expanded(child: Text('Live Sports', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (!loading && games.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No live scores are available right now.')),
          for (final game in games) _game(game),
        ]),
      ),
    );
  }

  Widget _game(Map<String, dynamic> game) {
    final home = game['homeTeam']?.toString() ?? game['home']?.toString() ?? 'Home';
    final away = game['awayTeam']?.toString() ?? game['away']?.toString() ?? 'Away';
    final hs = game['homeScore']?.toString() ?? game['home_score']?.toString() ?? '-';
    final as = game['awayScore']?.toString() ?? game['away_score']?.toString() ?? '-';
    final status = game['status']?.toString() ?? game['state']?.toString() ?? 'Live';
    return ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('$home  $hs  –  $as  $away', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(status), leading: const Icon(Icons.circle, size: 9, color: Colors.redAccent));
  }
}

class HomeStorageProgressBar extends StatelessWidget {
  final double thickness;
  final Axis axis;
  const HomeStorageProgressBar({super.key, required this.thickness, required this.axis});

  @override
  Widget build(BuildContext context) {
    final account = AppController.instance.currentAccount;
    final total = (account?.storageLimitBytes ?? 1000000000000).toDouble();
    final used = (account?.storageUsedBytes ?? 0).toDouble().clamp(0, total).toDouble();
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
      labels.add(Expanded(flex: (fraction * 1000).round().clamp(1, 1000), child: Tooltip(message: '${entry.key}: ${(entry.value / total * 100).toStringAsFixed(1)}%', child: Container(margin: const EdgeInsets.symmetric(horizontal: .5), height: thickness, decoration: BoxDecoration(color: _categoryColor(entry.key))))));
    }
    final bar = ClipRRect(borderRadius: BorderRadius.circular(thickness), child: axis == Axis.horizontal ? Row(children: labels) : Column(children: labels));
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
  final String liveSportsPosition;
  final double storageThickness;
  final bool showLiveSports;
  final Widget child;

  const HomePositionedLayout({super.key, required this.navbarPosition, required this.storagePosition, required this.liveSportsPosition, required this.storageThickness, required this.showLiveSports, required this.child});

  @override
  Widget build(BuildContext context) {
    final blocked = <String>{navbarPosition};
    var effectiveStorage = storagePosition;
    if (effectiveStorage != 'Hidden' && blocked.contains(effectiveStorage)) effectiveStorage = 'Hidden';
    if (effectiveStorage != 'Hidden') blocked.add(effectiveStorage);
    var effectiveSports = liveSportsPosition;
    if (blocked.contains(effectiveSports)) {
      effectiveSports = <String>['Top', 'Bottom', 'Left', 'Right'].firstWhere((p) => !blocked.contains(p), orElse: () => 'Top');
    }
    final storage = effectiveStorage == 'Hidden' ? null : HomeStorageProgressBar(thickness: storageThickness, axis: effectiveStorage == 'Left' || effectiveStorage == 'Right' ? Axis.vertical : Axis.horizontal);
    final sports = showLiveSports ? const HomeLiveSportsWidget() : null;
    Widget main = child;
    if (effectiveStorage == 'Top' && storage != null) main = Column(children: [storage, Expanded(child: main)]);
    if (effectiveStorage == 'Bottom' && storage != null) main = Column(children: [Expanded(child: main), storage]);
    if (effectiveStorage == 'Left' && storage != null) main = Row(children: [SizedBox(width: 220, child: storage), Expanded(child: main)]);
    if (effectiveStorage == 'Right' && storage != null) main = Row(children: [Expanded(child: main), SizedBox(width: 220, child: storage)]);
    if (effectiveSports == 'Top' && sports != null) main = Column(children: [sports, Expanded(child: main)]);
    if (effectiveSports == 'Bottom' && sports != null) main = Column(children: [Expanded(child: main), sports]);
    if (effectiveSports == 'Left' && sports != null) main = Row(children: [SizedBox(width: 280, child: sports), Expanded(child: main)]);
    if (effectiveSports == 'Right' && sports != null) main = Row(children: [Expanded(child: main), SizedBox(width: 280, child: sports)]);
    return main;
  }
}

class MusicStorageCount {
  static double get value => MusicLibraryStore.instance.tracks.length.toDouble();
}
