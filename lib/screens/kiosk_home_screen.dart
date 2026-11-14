import 'package:material_ui/material_ui.dart';
import '../app_core.dart';
import '../data/kiosk_repository.dart';
import '../models/kiosk_models.dart';
import '../stores/kiosk_store.dart';
import '../presence/account_profile_presence_service.dart';
import '../widgets/account_profile_presence_strip.dart';
import '../widgets/kiosk_primary_action.dart';
import 'kiosk_catalog_screen.dart';

class KioskHomeScreen extends StatefulWidget {
  const KioskHomeScreen({super.key});
  @override
  State<KioskHomeScreen> createState() => _KioskHomeScreenState();
}

class _KioskHomeScreenState extends State<KioskHomeScreen> {
  final _repository = const KioskRepository();
  final _store = KioskStore.instance;
  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    _store.load(AppController.instance.currentProfile?.id);
    final profile = AppController.instance.currentProfile;
    if (profile != null) {
      AccountProfilePresenceService.instance.start(
          profileId: profile.id,
          activityType: 'browsing',
          activityText: 'Kiosk');
    }
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = _repository.catalog();
    return Scaffold(
        appBar: AppBar(title: const Text('Virtual Kiosk')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          const AccountProfilePresenceStrip(),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your collection, ready to play',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        const Text(
                            'A self-service browsing interface for movies, TV, specials and music already in your library. No rentals, checkout, or payments.'),
                        const SizedBox(height: 16),
                        KioskPrimaryAction(
                            title: 'Browse my library',
                            subtitle:
                                'Explore owned movies, shows, specials and albums',
                            icon: Icons.local_movies_rounded,
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const KioskCatalogScreen())))
                      ]))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _stat(context, 'Owned titles', items.length)),
            const SizedBox(width: 10),
            Expanded(
                child: _stat(context, 'Favorites', _store.favorites.length))
          ]),
          const SizedBox(height: 14),
          Text('Quick categories',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in const [
              (KioskCategory.movies, 'Movies', Icons.movie_outlined),
              (KioskCategory.television, 'TV Shows', Icons.tv_outlined),
              (KioskCategory.specials, 'TV Specials', Icons.live_tv_outlined),
              (KioskCategory.music, 'Music', Icons.album_outlined)
            ])
              ActionChip(
                  avatar: Icon(entry.$3),
                  label: Text(entry.$2),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              KioskCatalogScreen(initialCategory: entry.$1))))
          ]),
          const SizedBox(height: 18),
          const Text(
              'This kiosk is a personal library interface. It does not create rentals, purchases, return orders, paid tickets, or payment records.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]));
  }

  Widget _stat(BuildContext context, String label, int value) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            Text(label)
          ])));
}
