// FILE: `lib/media_universe.dart`.
// Purpose: Provides the unified Media Universe, intelligence dashboards,
// Surprise Me, session management, library health, artwork and exploration UI.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'details.dart';
import 'entertainment_studio.dart';
import 'localization.dart';
import 'media_text_localizer.dart';
import 'media_artwork_auto_resolver.dart';
import 'energy_saver.dart';
import 'entertainment_passport.dart';
import 'media_health_screen.dart';
import 'screens/virtual_store_screen.dart';
import 'screens/theater_home_screen.dart';
import 'screens/kiosk_home_screen.dart';
import 'screens/group_watch_library_picker_screen.dart';
import 'smart_search.dart';
import 'feature_center.dart';
import 'dialogue_search.dart';

class MediaUniverseScreen extends StatefulWidget {
  const MediaUniverseScreen({super.key});

  @override
  State<MediaUniverseScreen> createState() => _MediaUniverseScreenState();
}

class _MediaUniverseScreenState extends State<MediaUniverseScreen> {
  String query = '';

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final filtered = library
        .where((item) =>
            query.trim().isEmpty ||
            item.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const UniversalText('Media Universe')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Explore your entire media universe'),
          ),
          const SizedBox(height: 18),
          _heroCard(),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _tile('Surprise Me', Icons.shuffle_rounded,
                  () => _open(context, const SurpriseMeScreen())),
              _tile('Devices & Sessions', Icons.devices_rounded,
                  () => _open(context, const MediaSessionsScreen())),
              _tile('Library Health & Repair', Icons.health_and_safety_outlined,
                  () => _open(context, const MediaHealthScreen())),
              _tile('Entertainment Studio', Icons.auto_awesome_rounded,
                  () => _open(context, const EntertainmentStudioScreen())),
              _tile('Knowledge Graph', Icons.hub_rounded,
                  () => _open(context, const MediaConnectionGraphScreen())),
              _tile('Artwork Library', Icons.photo_library_outlined,
                  () => _open(context, const MediaArtworkScreen())),
              _tile('Entertainment Passport', Icons.badge_outlined,
                  () => _open(context, const EntertainmentPassportScreen())),
              _tile('Smart Search', Icons.search_rounded,
                  () => _open(context, const SmartSearchScreen())),
              _tile('Identify a Movie or Show', Icons.movie_filter_outlined,
                  () => _open(context, const DialogueSearchScreen())),
              _tile('Group Watch', Icons.groups_rounded,
                  () => _open(context, const GroupWatchLibraryPickerScreen())),
              _tile('Virtual Store', Icons.storefront_outlined,
                  () => _open(context, const VirtualStoreScreen())),
              _tile('Virtual Kiosk', Icons.local_movies_outlined,
                  () => _open(context, const KioskHomeScreen())),
              _tile('Virtual Theater', Icons.theaters_outlined,
                  () => _open(context, const TheaterHomeScreen())),
              _tile('Wrapped & Recaps', Icons.auto_awesome_rounded,
                  () => _open(context, const FeatureCenterScreen())),
            ],
          ),
          const SizedBox(height: 24),
          const UniversalText('Explore Media',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            const _EmptyUniverse()
          else
            ...filtered.take(20).map((item) => _MediaUniverseCard(item: item)),
        ],
      ),
    );
  }

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(colors: [
            Colors.red.withValues(alpha: .30),
            Colors.purple.withValues(alpha: .18)
          ]),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hub_rounded, size: 42),
              SizedBox(height: 12),
              UniversalText('Your Media Universe',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              SizedBox(height: 7),
              UniversalText(
                  'Movies, shows, songs, albums, people, characters, franchises, extras, artwork and your personal history connected in one place.',
                  style: TextStyle(color: Colors.white70, height: 1.4)),
            ]),
      );

  Widget _tile(String title, IconData icon, VoidCallback onTap) => ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(title),
        onPressed: onTap,
      );
}

class _MediaUniverseCard extends StatelessWidget {
  final MediaItem item;
  const _MediaUniverseCard({required this.item});
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: _Artwork(imageUrl: item.imageUrl),
          title: LocalizedMediaText(item.title, preserveOriginal: true),
          subtitle: Text(
              '${item.type}${item.releaseYear == null ? '' : ' • ${item.releaseYear}'}'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => MediaPassportItemScreen(item: item))),
        ),
      );
}

class SurpriseMeScreen extends StatefulWidget {
  const SurpriseMeScreen({super.key});

  @override
  State<SurpriseMeScreen> createState() => _SurpriseMeScreenState();
}

class _SurpriseMeScreenState extends State<SurpriseMeScreen>
    with SingleTickerProviderStateMixin {
  final Random random = Random();
  late final AnimationController _spinController;
  Timer? _reelTimer;
  Animation<double>? _wheelRotation;

  MediaItem? selected;
  MediaItem? _pendingSelection;
  String mode = 'Random Everything';
  String animationStyle = 'Slot Machine';
  bool _isSpinning = false;
  List<MediaItem?> _reels = List<MediaItem?>.filled(3, null);
  List<MediaItem> _wheelEntries = <MediaItem>[];
  int _wheelWinnerIndex = 0;
  double _wheelTurns = 6;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..addStatusListener(_handleSpinStatus);
  }

  @override
  void dispose() {
    _reelTimer?.cancel();
    _spinController
      ..removeStatusListener(_handleSpinStatus)
      ..dispose();
    super.dispose();
  }

  List<MediaItem> _eligibleItems() {
    final app = AppController.instance;
    final profile = app.currentProfile;
    final library = app.library
        .where((media) => media.isAccessibleTo(profile))
        .toList(growable: false);
    if (mode == 'Random Everything') return library;
    final matching = library.where((item) => _matches(item, mode)).toList();
    return matching;
  }

  void pick() {
    if (_isSpinning) return;
    final candidates = _eligibleItems();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No accessible items found for "$mode".')),
      );
      return;
    }

    final winner = candidates[random.nextInt(candidates.length)];
    _pendingSelection = winner;
    setState(() {
      selected = null;
      _isSpinning = true;
      _reels = List<MediaItem?>.generate(
        3,
        (_) => candidates[random.nextInt(candidates.length)],
      );
      _wheelEntries = _makeWheelEntries(candidates, winner);
      _wheelWinnerIndex = _wheelEntries.indexWhere((item) => item.id == winner.id);
    });

    _spinController.reset();
    if (animationStyle == 'Roulette') {
      _prepareWheelAnimation();
    } else {
      _startSlotReels(candidates);
      _wheelRotation = null;
    }
    _spinController.forward();
  }

  List<MediaItem> _makeWheelEntries(
    List<MediaItem> candidates,
    MediaItem winner,
  ) {
    final shuffled = List<MediaItem>.from(candidates)..shuffle(random);
    final entries = shuffled.take(8).toList(growable: true);
    if (!entries.any((item) => item.id == winner.id)) {
      if (entries.isEmpty) {
        entries.add(winner);
      } else {
        entries[random.nextInt(entries.length)] = winner;
      }
    }
    return entries;
  }

  void _prepareWheelAnimation() {
    final count = _wheelEntries.length.clamp(1, 8);
    final sweep = (2 * pi) / count;
    final centerAngle = -pi / 2 + ((_wheelWinnerIndex + .5) * sweep);
    var targetAngle = (-pi / 2 - centerAngle) % (2 * pi);
    if (targetAngle < 0) targetAngle += 2 * pi;
    _wheelTurns = 6 + (targetAngle / (2 * pi));
    _wheelRotation = Tween<double>(begin: 0, end: _wheelTurns).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutQuart),
    );
  }

  void _startSlotReels(List<MediaItem> candidates) {
    _reelTimer?.cancel();
    const reelStopProgress = <double>[.58, .76, .92];
    _reelTimer = Timer.periodic(const Duration(milliseconds: 85), (_) {
      if (!mounted || !_isSpinning || candidates.isEmpty) return;
      final progress = _spinController.value;
      setState(() {
        _reels = List<MediaItem?>.generate(3, (index) {
          // Each reel slows and stops in sequence, like a physical slot machine.
          if (progress >= reelStopProgress[index]) return _reels[index];
          return candidates[random.nextInt(candidates.length)];
        });
      });
    });
  }

  void _handleSpinStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _reelTimer?.cancel();
    final winner = _pendingSelection;
    setState(() {
      _isSpinning = false;
      selected = winner;
      _reels = List<MediaItem?>.filled(3, winner);
    });
  }

  bool _matches(MediaItem media, String value) {
    final type = media.type.toLowerCase();
    if (value == 'Movies') {
      return type.contains('movie') || type.contains('film');
    }
    if (value == 'TV Episodes') {
      return type.contains('episode') || type.contains('series') ||
          media.seasons.isNotEmpty;
    }
    if (value == 'Music') {
      return ['song', 'album', 'music', 'track', 'concert']
          .any(type.contains);
    }
    if (value == 'Specials & Events') {
      return ['special', 'event', 'concert', 'bonus', 'extra', 'performance']
          .any(type.contains) ||
          media.isBonusContent;
    }
    if (value == 'Physical') {
      return media.discType != null || media.discCollectionId != null;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final wheelItems = _wheelEntries.isEmpty
        ? _eligibleItems().take(8).toList(growable: false)
        : _wheelEntries;
    return Scaffold(
      appBar: AppBar(title: const UniversalText('Surprise Me')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const UniversalText(
            'True Random',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const UniversalText(
            'Let the slot machine or roulette choose something from your accessible library. Movies, episodes, specials, music and physical editions can all be included.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: mode,
            items: const [
              DropdownMenuItem(
                value: 'Random Everything',
                child: UniversalText('Random Everything'),
              ),
              DropdownMenuItem(
                value: 'Movies',
                child: UniversalText('Movies'),
              ),
              DropdownMenuItem(
                value: 'TV Episodes',
                child: UniversalText('TV Shows & Episodes'),
              ),
              DropdownMenuItem(
                value: 'Specials & Events',
                child: UniversalText('Specials & Events'),
              ),
              DropdownMenuItem(
                value: 'Music',
                child: UniversalText('Music & Concerts'),
              ),
              DropdownMenuItem(
                value: 'Physical',
                child: UniversalText('Something I Own Physically'),
              ),
            ],
            onChanged: _isSpinning ? null : (value) => setState(() => mode = value ?? mode),
            decoration: const InputDecoration(labelText: 'Choose what can be selected'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: animationStyle,
            items: const [
              DropdownMenuItem(
                value: 'Slot Machine',
                child: UniversalText('Slot Machine Animation'),
              ),
              DropdownMenuItem(
                value: 'Roulette',
                child: UniversalText('Roulette Wheel Animation'),
              ),
            ],
            onChanged: _isSpinning
                ? null
                : (value) => setState(() => animationStyle = value ?? animationStyle),
            decoration: const InputDecoration(labelText: 'Surprise animation'),
          ),
          const SizedBox(height: 18),
          if (animationStyle == 'Roulette')
            _buildRoulette(wheelItems)
          else
            _buildSlotMachine(),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isSpinning ? null : pick,
            icon: Icon(_isSpinning ? Icons.hourglass_top_rounded : Icons.casino_rounded),
            label: UniversalText(_isSpinning ? 'SPINNING…' : 'SURPRISE ME'),
          ),
          if (selected != null && !_isSpinning) ...[
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _Artwork(imageUrl: selected!.imageUrl, size: 180),
                    const SizedBox(height: 14),
                    Text(
                      selected!.title,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                    Text(selected!.type, style: const TextStyle(color: Colors.white60)),
                    const SizedBox(height: 12),
                    const UniversalText(
                      'Your pick was selected randomly from the eligible items in your library.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MediaDetailsScreen(media: selected!),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const UniversalText('VIEW / PLAY'),
                        ),
                        OutlinedButton.icon(
                          onPressed: pick,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const UniversalText('SPIN AGAIN'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotMachine() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF19131F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.amber.withValues(alpha: .45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: _isSpinning ? .18 : .07),
            blurRadius: _isSpinning ? 28 : 12,
            spreadRadius: _isSpinning ? 2 : 0,
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stars_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('THE ENTERTAINMENT JACKPOT',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              SizedBox(width: 8),
              Icon(Icons.stars_rounded, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List<Widget>.generate(3, (index) {
              final item = _reels[index];
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: index == 0 ? 0 : 6),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF08080B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: .35)),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 112,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 100),
                          transitionBuilder: (child, animation) => SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -1),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(opacity: animation, child: child),
                          ),
                          child: item == null
                              ? _slotPlaceholder()
                              : KeyedSubtree(
                                  key: ValueKey('${item.id}-$index'),
                                  child: _Artwork(
                                    imageUrl: item.imageUrl,
                                    size: 112,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item?.title ?? '???',
                        key: ValueKey('slot-title-${item?.id}-$index'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            _isSpinning ? 'SPINNING FOR YOUR NEXT PICK…' : 'MATCH THREE FOR YOUR NEXT WATCH',
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _slotPlaceholder() => Container(
        key: const ValueKey('slot-placeholder'),
        width: double.infinity,
        color: const Color(0xFF28202E),
        alignment: Alignment.center,
        child: const Icon(Icons.movie_filter_rounded, size: 42, color: Colors.amber),
      );

  Widget _buildRoulette(List<MediaItem> entries) {
    final rotation = _wheelRotation;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF111923),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          const Text('ENTERTAINMENT ROULETTE',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (entries.isNotEmpty)
                  AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) => Transform.rotate(
                      angle: (rotation?.value ?? 0) * 2 * pi,
                      child: child,
                    ),
                    child: CustomPaint(
                      size: const Size.square(300),
                      painter: _SurpriseWheelPainter(
                        labels: entries.map((item) => item.title).toList(),
                      ),
                    ),
                  )
                else
                  const Icon(Icons.casino_rounded, size: 150, color: Colors.white30),
                Positioned(
                  top: -4,
                  child: Icon(Icons.arrow_drop_down_rounded,
                      size: 54, color: Colors.amber.shade300),
                ),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF121A25),
                    border: Border.all(color: Colors.amber, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSpinning ? 'THE WHEEL IS DECIDING…' : 'SPIN TO REVEAL A TITLE',
            style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w900),
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${entries.length} eligible titles on the wheel',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _SurpriseWheelPainter extends CustomPainter {
  const _SurpriseWheelPainter({required this.labels});

  final List<String> labels;

  static const List<Color> _colors = <Color>[
    Color(0xFF7E57C2),
    Color(0xFF1565C0),
    Color(0xFF00897B),
    Color(0xFFEF6C00),
    Color(0xFFC62828),
    Color(0xFF6D4C41),
    Color(0xFF3949AB),
    Color(0xFFAD1457),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 5;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = (2 * pi) / labels.length;
    final fill = Paint()..style = PaintingStyle.fill;
    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: .8);

    for (var index = 0; index < labels.length; index++) {
      final start = -pi / 2 + index * sweep;
      fill.color = _colors[index % _colors.length];
      canvas.drawArc(rect, start, sweep, true, fill);
      canvas.drawArc(rect, start, sweep, true, divider);

      final label = labels[index].length > 18
          ? '${labels[index].substring(0, 16)}…'
          : labels[index];
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            shadows: <Shadow>[Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: radius * .46);
      final angle = start + sweep / 2;
      final labelRadius = radius * .66;
      final position = Offset(
        center.dx + cos(angle) * labelRadius - text.width / 2,
        center.dy + sin(angle) * labelRadius - text.height / 2,
      );
      text.paint(canvas, position);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.amber,
    );
  }

  @override
  bool shouldRepaint(covariant _SurpriseWheelPainter oldDelegate) =>
      oldDelegate.labels != labels;
}

class MediaSessionsScreen extends StatelessWidget {
  const MediaSessionsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const UniversalText('Devices & Sessions')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          _sessionCard('Living Room TV', 'TV', 'Playing Jurassic Park', true),
          _sessionCard('Phone', 'Phone', 'Listening to music', true),
          _sessionCard('Bedroom PC', 'Desktop', 'Browsing library', false),
          const SizedBox(height: 18),
          const UniversalText(
              'A profile can have multiple independent sessions. Starting playback on one device does not hijack another session.',
              style: TextStyle(color: Colors.white60)),
        ]),
      );
  Widget _sessionCard(String name, String type, String activity, bool active) =>
      Card(
          child: ListTile(
        leading: Icon(type == 'TV'
            ? Icons.tv
            : type == 'Phone'
                ? Icons.phone_android
                : Icons.computer),
        title: Text(name),
        subtitle: Text(activity),
        trailing: Icon(active ? Icons.circle : Icons.circle_outlined, size: 12),
      ));
}

class LibraryHealthScreen extends StatefulWidget {
  const LibraryHealthScreen({super.key});

  @override
  State<LibraryHealthScreen> createState() => _LibraryHealthScreenState();
}

class _LibraryHealthScreenState extends State<LibraryHealthScreen> {
  bool _repairingArtwork = false;
  String? _repairMessage;

  String _normalizeTitle(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _repairMissingArtwork(List<MediaItem> missing) async {
    if (_repairingArtwork || missing.isEmpty) return;
    setState(() {
      _repairingArtwork = true;
      _repairMessage = null;
    });
    try {
      await MediaArtworkAutoResolver.warmLibrary(
        items: missing,
        pageId: EnergySaverController.instance.activePage,
        maxItems: missing.length,
      );
      if (!mounted) return;
      setState(() {
        _repairMessage = AppController.instance.isBackendAuthenticated
            ? 'Artwork lookups were queued. Resolved images are cached and do not replace manual artwork.'
            : 'Start the backend and sign in to resolve missing artwork. Existing artwork was not changed.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(
          () => _repairMessage = 'Artwork repair could not finish: $error');
    } finally {
      if (mounted) setState(() => _repairingArtwork = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppController.instance,
      builder: (context, _) {
        final library = AppController.instance.library.toList(growable: false);
        final missingArtwork = library
            .where((media) =>
                (media.imageUrl?.trim().isNotEmpty != true) &&
                (MediaArtworkAutoResolver.isMovieOrShow(media) ||
                    MediaArtworkAutoResolver.isAlbum(media)))
            .toList(growable: false);
        final physical =
            library.where((media) => media.discType != null).length;
        final duplicateGroups = <String, List<MediaItem>>{};
        for (final media in library) {
          final normalized = _normalizeTitle(media.title);
          if (normalized.isEmpty) continue;
          duplicateGroups
              .putIfAbsent('${media.type.toLowerCase()}|$normalized',
                  () => <MediaItem>[])
              .add(media);
        }
        final duplicateCount = duplicateGroups.values
            .where((items) => items.length > 1)
            .fold<int>(0, (sum, items) => sum + items.length - 1);
        final series = library
            .where((media) =>
                media.isSeries ||
                const <String>{
                  'show',
                  'tvshow',
                  'tv show',
                  'series',
                  'television'
                }.contains(media.type.toLowerCase().trim()))
            .toList(growable: false);
        final seriesWithoutEpisodes = series.where((media) {
          if (media.seasons.isEmpty) return true;
          return !media.seasons.any((season) =>
              season['episodes'] is List &&
              (season['episodes'] as List).isNotEmpty);
        }).length;
        final thinMetadata = library
            .where((media) =>
                (media.description?.trim().isNotEmpty != true) &&
                media.genres.isEmpty &&
                media.tags.isEmpty)
            .length;
        return Scaffold(
          appBar: AppBar(title: const UniversalText('Library Health')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const UniversalText(
                'Library health checks',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const UniversalText(
                'Find repairable catalogue gaps without removing files or automatically deleting duplicate entries.',
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 16),
              _metric('Media items', '${library.length}',
                  Icons.video_library_outlined),
              _metric('Missing poster/cover', '${missingArtwork.length}',
                  Icons.image_not_supported_outlined),
              _metric('Potential duplicate entries', '$duplicateCount',
                  Icons.content_copy_rounded),
              _metric('Shows without episode metadata',
                  '$seriesWithoutEpisodes', Icons.live_tv_outlined),
              _metric('Titles with sparse metadata', '$thinMetadata',
                  Icons.info_outline_rounded),
              _metric('Physical imports', '$physical', Icons.album_outlined),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _repairingArtwork || missingArtwork.isEmpty
                    ? null
                    : () => unawaited(_repairMissingArtwork(missingArtwork)),
                icon: _repairingArtwork
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_fix_high_rounded),
                label: Text(_repairingArtwork
                    ? 'Queueing artwork repair…'
                    : missingArtwork.isEmpty
                        ? 'No missing poster/cover detected'
                        : 'Find artwork for ${missingArtwork.length} items'),
              ),
              if (_repairMessage != null) ...[
                const SizedBox(height: 10),
                Text(_repairMessage!,
                    style: const TextStyle(color: Colors.white70, height: 1.4)),
              ],
              const SizedBox(height: 20),
              const UniversalText('What the checks mean',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const UniversalText(
                'Potential duplicates are suggestions only: different cuts, editions, releases or language versions may be legitimate. Shows without episode metadata need a season/episode refresh before exact themed-episode playback can work. Artwork repair caches matches and keeps manual artwork selections as the higher-priority source.',
                style: TextStyle(color: Colors.white60, height: 1.45),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metric(String title, String value, IconData icon) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing:
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
}

class MediaArtworkScreen extends StatefulWidget {
  const MediaArtworkScreen({super.key});
  @override
  State<MediaArtworkScreen> createState() => _MediaArtworkScreenState();
}

class _MediaArtworkScreenState extends State<MediaArtworkScreen> {
  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library
        .where((m) => m.imageUrl != null && m.imageUrl!.isNotEmpty)
        .toList();
    final profile = AppController.instance.currentProfile;
    return Scaffold(
        appBar: AppBar(title: const UniversalText('My Artwork')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          const UniversalText('Artwork from your media',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const UniversalText(
              'ARM can classify disc/poster/booklet artwork and make approved images available for profile pictures.'),
          const SizedBox(height: 18),
          ...library.map((media) => Card(
                  child: ListTile(
                leading: _Artwork(imageUrl: media.imageUrl),
                title: LocalizedMediaText(media.title, preserveOriginal: true),
                subtitle: Text(media.discType == null
                    ? 'Library artwork'
                    : 'Disc artwork candidate'),
                trailing: FilledButton(
                  onPressed: profile == null
                      ? null
                      : () async {
                          profile.avatarUrl = media.imageUrl;

                          if (AppController.instance.isBackendAuthenticated) {
                            try {
                              await AppController.instance.backendApi
                                  .updateProfile(
                                profileId: profile.id,
                                name: profile.name,
                                avatarUrl: media.imageUrl,
                              );
                            } catch (_) {}
                          }

                          if (mounted) {
                            setState(() {});
                          }
                        },
                  child: const UniversalText('USE'),
                ),
              ))),
        ]));
  }
}

class MediaPassportScreen extends StatelessWidget {
  const MediaPassportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppController.instance;
    return Scaffold(
        appBar: AppBar(title: const UniversalText('My Media Passport')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          const UniversalText('Your relationship with media',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _row('Library items', '${c.library.length}'),
          _row('Watched', '${c.watched.length}'),
          _row('Liked', '${c.liked.length}'),
          _row('Collections', '${c.collections.length}'),
          _row('Profiles', '${c.currentAccount?.profiles.length ?? 0}'),
          const SizedBox(height: 20),
          const UniversalText(
              'This is private personal history. Importing, watching and listening remain separate events.'),
        ]));
  }

  Widget _row(String a, String b) => Card(
      child: ListTile(
          title: Text(a),
          trailing:
              Text(b, style: const TextStyle(fontWeight: FontWeight.w800))));
}

class MediaPassportItemScreen extends StatelessWidget {
  final MediaItem item;
  const MediaPassportItemScreen({super.key, required this.item});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: LocalizedMediaText(item.title, preserveOriginal: true)),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Center(child: _Artwork(imageUrl: item.imageUrl, size: 220)),
            const SizedBox(height: 16),
            LocalizedMediaText(item.title,
                preserveOriginal: true,
                style:
                    const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            Text(item.type),
            const SizedBox(height: 18),
            _info('Imported', item.addedAt.toLocal().toString()),
            _info('Physical source', item.discType ?? 'Not recorded'),
            _info(
                'Country association', item.countryOfOrigin ?? 'Not recorded'),
            _info('Original language', item.originalLanguage ?? 'Not recorded'),
            _info('Music connections', '${item.music.length}'),
            _info('Extras', '${item.extras.length}'),
            _info('Actors', '${item.actors.length}'),
          ],
        ),
      );

  Widget _info(String a, String b) =>
      Card(child: ListTile(title: Text(a), subtitle: Text(b)));
}

class _Artwork extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const _Artwork({this.imageUrl, this.size = 52});
  @override
  Widget build(BuildContext context) {
    final value = imageUrl;
    if (value != null && value.startsWith('http')) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(value,
              width: size, height: size, fit: BoxFit.cover));
    }
    if (value != null && value.isNotEmpty && File(value).existsSync()) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(value),
              width: size, height: size, fit: BoxFit.cover));
    }
    return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: Colors.white10, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.image_outlined));
  }
}

class _EmptyUniverse extends StatelessWidget {
  const _EmptyUniverse();
  @override
  Widget build(BuildContext context) => const Card(
      child: Padding(
          padding: EdgeInsets.all(24),
          child: UniversalText(
              'Your Media Universe will populate as media is imported or added to the library.')));
}
