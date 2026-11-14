import 'package:material_ui/material_ui.dart';
import '../data/kiosk_repository.dart';
import '../models/kiosk_models.dart';
import '../widgets/kiosk_movie_card.dart';
import 'kiosk_movie_screen.dart';

class KioskCatalogScreen extends StatefulWidget {
  const KioskCatalogScreen(
      {super.key, this.initialCategory = KioskCategory.all});
  final KioskCategory initialCategory;
  @override
  State<KioskCatalogScreen> createState() => _KioskCatalogScreenState();
}

class _KioskCatalogScreenState extends State<KioskCatalogScreen> {
  final _repository = const KioskRepository();
  final _search = TextEditingController();
  late KioskCategory _category = widget.initialCategory;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final items = _repository
        .catalog(category: _category)
        .where((e) => q.isEmpty || e.title.toLowerCase().contains(q))
        .toList(growable: false);
    return Scaffold(
        appBar: AppBar(title: const Text('Browse Owned Media')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search your library',
                      border: OutlineInputBorder()))),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                for (final item in const [
                  (KioskCategory.all, 'All'),
                  (KioskCategory.movies, 'Movies'),
                  (KioskCategory.television, 'TV'),
                  (KioskCategory.specials, 'Specials'),
                  (KioskCategory.music, 'Music')
                ])
                  Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                          label: Text(item.$2),
                          selected: _category == item.$1,
                          onSelected: (_) =>
                              setState(() => _category = item.$1)))
              ])),
          Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('No owned titles match this category yet.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 190,
                              childAspectRatio: .70,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8),
                      itemCount: items.length,
                      itemBuilder: (context, index) => KioskMovieCard(
                          media: items[index].media,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) => KioskMovieScreen(
                                      media: items[index].media))))))
        ]));
  }
}
