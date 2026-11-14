import 'package:material_ui/material_ui.dart';
import '../stores/collection_store.dart';
import '../widgets/collection_box.dart';
import 'collection_details_screen.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});
  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  @override
  void initState() {
    super.initState();
    CollectionStore.instance.addListener(_refresh);
    CollectionStore.instance.load();
  }

  @override
  void dispose() {
    CollectionStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final collections = CollectionStore.instance.collections;
    return Scaffold(
        appBar: AppBar(title: const Text('Collections & Editions')),
        body: collections.isEmpty
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Disc and box-set collections will appear here when multiple library titles share the same physical release or collection ID.',
                        textAlign: TextAlign.center)))
            : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: collections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => CollectionBox(
                    collection: collections[index],
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => CollectionDetailsScreen(
                                collection: collections[index]))))));
  }
}
