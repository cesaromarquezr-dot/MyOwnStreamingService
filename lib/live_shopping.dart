import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app_core.dart';
import 'shop.dart';

/// Buyer discovery and interaction surface for scheduled, live, and replayed
/// seller product demonstrations.
class LiveShoppingScreen extends StatefulWidget {
  const LiveShoppingScreen({super.key});

  @override
  State<LiveShoppingScreen> createState() => _LiveShoppingScreenState();
}

class _LiveShoppingScreenState extends State<LiveShoppingScreen> {
  List<Map<String, dynamic>> events = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final result = await AppController.instance.backendApi.getShopLiveEvents();
      if (mounted) setState(() { events = result; loading = false; error = null; });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Live Shopping'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator()) : error != null
      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Unable to load events: $error')))
      : RefreshIndicator(onRefresh: _load, child: events.isEmpty
        ? ListView(children: const [SizedBox(height: 180), Center(child: Text('No live shopping events right now.'))])
        : ListView.builder(padding: const EdgeInsets.all(16), itemCount: events.length, itemBuilder: (context, index) => _eventCard(context, events[index]))),
  );

  Widget _eventCard(BuildContext context, Map<String, dynamic> event) {
    final status = event['status']?.toString() ?? 'scheduled';
    final products = (event['productIds'] as List? ?? const []).map((id) => ShopCatalog.instance.productById(id.toString())).whereType<ShopProduct>().toList();
    final poll = event['poll'] is Map ? Map<String, dynamic>.from(event['poll'] as Map) : null;
    final questions = (event['questions'] as List? ?? const []).whereType<Map>().where((q) => q['moderationStatus'] == 'approved').toList();
    return Card(margin: const EdgeInsets.only(bottom: 16), clipBehavior: Clip.antiAlias, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(event['storeName']?.toString() ?? 'Store', style: Theme.of(context).textTheme.titleMedium)), Chip(label: Text(status.toUpperCase()), avatar: Icon(status == 'live' ? Icons.circle : Icons.schedule, size: 14))]),
      Text(event['title']?.toString() ?? 'Product event', style: Theme.of(context).textTheme.headlineSmall),
      if ((event['description']?.toString() ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(event['description'].toString())),
      if (status == 'live' && event['streamUrl'] is String) _EventVideo(url: event['streamUrl'].toString()),
      if (status == 'ended' && event['replayUrl'] is String) _EventVideo(url: event['replayUrl'].toString()),
      if (status == 'scheduled' && event['scheduledAt'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Starts ${event['scheduledAt']}')),
      if (products.isNotEmpty) ...[
        const SizedBox(height: 12), const Text('Products', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final product in products) Card(child: ListTile(leading: product.imageUrls.isEmpty ? const Icon(Icons.shopping_bag_outlined) : Image.network(product.imageUrls.first, width: 48, height: 48, fit: BoxFit.cover), title: Text(product.name), subtitle: Text('${product.price.toStringAsFixed(2)} ${product.currency} • ${product.inventoryQuantity} in stock'), trailing: product.inventoryQuantity > 0 ? IconButton(tooltip: 'Add to bag', onPressed: () { ShopCatalog.instance.addToBag(product.id); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to bag'))); }, icon: const Icon(Icons.add_shopping_cart)) : const Text('Sold out'))),
      ],
      if (status == 'live') ...[
        if (poll != null) _pollWidget(event, poll),
        if (questions.isNotEmpty) ...[const SizedBox(height: 8), const Text('Answered questions', style: TextStyle(fontWeight: FontWeight.bold)), for (final q in questions) ListTile(dense: true, title: Text(q['text']?.toString() ?? ''), subtitle: Text(q['profileName']?.toString() ?? 'Buyer'))],
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _ask(context, event), icon: const Icon(Icons.help_outline), label: const Text('Ask a question'))),
      ],
    ])));
  }

  Widget _pollWidget(Map<String, dynamic> event, Map<String, dynamic> poll) {
    final options = (poll['options'] as List? ?? const []).map((e) => e.toString()).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 10), Text(poll['question']?.toString() ?? 'Poll', style: const TextStyle(fontWeight: FontWeight.bold)), Wrap(children: [for (var i = 0; i < options.length; i++) Padding(padding: const EdgeInsets.only(right: 6), child: OutlinedButton(onPressed: () async { final profile = AppController.instance.currentProfile; if (profile == null) return; try { await AppController.instance.backendApi.voteShopLivePoll(eventId: event['id'].toString(), profileId: profile.id, optionIndex: i); await _load(); } catch (e) { _notice(e.toString()); } }, child: Text(options[i])))] )]);
  }

  Future<void> _ask(BuildContext context, Map<String, dynamic> event) async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) { _notice('Select a profile before asking a question.'); return; }
    final controller = TextEditingController();
    final text = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Ask the seller'), content: TextField(controller: controller, maxLength: 1000, autofocus: true, decoration: const InputDecoration(hintText: 'Write your question')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Send'))]));
    controller.dispose();
    if (text == null || text.isEmpty) return;
    try { await AppController.instance.backendApi.askShopLiveQuestion(eventId: event['id'].toString(), profileId: profile.id, text: text); _notice('Question sent for seller review.'); await _load(); } catch (e) { _notice(e.toString()); }
  }

  void _notice(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
}

/// Seller controls for scheduling, starting, and ending a store live event.
class SellerLiveShoppingScreen extends StatefulWidget {
  final ShopStore store;
  const SellerLiveShoppingScreen({super.key, required this.store});
  @override
  State<SellerLiveShoppingScreen> createState() => _SellerLiveShoppingScreenState();
}

class _SellerLiveShoppingScreenState extends State<SellerLiveShoppingScreen> {
  List<Map<String, dynamic>> events = [];
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final all = await AppController.instance.backendApi.getShopLiveEvents(); if (mounted) setState(() { events = all.where((e) => e['storeId'] == widget.store.id).toList(); loading = false; }); }
    catch (e) { if (mounted) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Live Shopping & Videos')), floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Schedule event')), body: loading ? const Center(child: CircularProgressIndicator()) : events.isEmpty ? const Center(child: Text('Schedule a product demonstration or live event.')) : ListView(children: [for (final event in events) _sellerEvent(event)]));

  Widget _sellerEvent(Map<String, dynamic> event) {
    final status = event['status']?.toString() ?? 'scheduled';
    return Card(margin: const EdgeInsets.all(12), child: ListTile(title: Text(event['title']?.toString() ?? 'Live event'), subtitle: Text('$status • ${event['scheduledAt'] ?? 'No start time'}'), isThreeLine: true, trailing: PopupMenuButton<String>(onSelected: (action) => _manage(event, action), itemBuilder: (_) => [if (status == 'scheduled') const PopupMenuItem(value: 'start', child: Text('Start stream')), if (status == 'live') const PopupMenuItem(value: 'end', child: Text('End stream')), const PopupMenuItem(value: 'pin', child: Text('Feature a product')), const PopupMenuItem(value: 'poll', child: Text('Create a poll'))])));
  }

  Future<void> _create() async {
    final title = TextEditingController(); final description = TextEditingController(); final url = TextEditingController(); final ids = TextEditingController(text: ShopCatalog.instance.productsForStore(widget.store.id).map((p) => p.id).join(', '));
    var rewards = false;
    final values = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(title: const Text('Schedule a live event'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'Event title')), TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')), TextField(controller: url, decoration: const InputDecoration(labelText: 'HTTPS stream URL (optional)')), TextField(controller: ids, decoration: const InputDecoration(labelText: 'Product IDs (comma separated)')), CheckboxListTile(value: rewards, onChanged: (v) => setDialog(() => rewards = v ?? false), title: const Text('Enable randomized seller rewards'))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {'title': title.text.trim(), 'description': description.text.trim(), 'url': url.text.trim(), 'ids': ids.text.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(), 'rewards': rewards}), child: const Text('Create'))])));
    title.dispose(); description.dispose(); url.dispose(); ids.dispose();
    if (values == null || (values['title'] as String).isEmpty) return;
    try { await AppController.instance.backendApi.createShopLiveEvent(storeId: widget.store.id, storeName: widget.store.name, title: values['title'] as String, description: values['description'] as String, streamUrl: (values['url'] as String).isEmpty ? null : values['url'] as String, productIds: (values['ids'] as List).cast<String>(), randomizedRewardsEnabled: values['rewards'] as bool); await _load(); }
    catch (e) { _notice(e.toString()); }
  }

  Future<void> _manage(Map<String, dynamic> event, String action) async {
    try {
      if (action == 'start' || action == 'end') {
        final controller = TextEditingController();
        final url = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: Text(action == 'start' ? 'Start live stream' : 'End stream'), content: TextField(controller: controller, decoration: InputDecoration(labelText: action == 'start' ? 'HTTPS stream URL' : 'HTTPS replay URL (optional)')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(action == 'start' ? 'Start' : 'End'))])); controller.dispose();
        if (url == null) return;
        await AppController.instance.backendApi.updateShopLiveEvent(eventId: event['id'].toString(), status: action == 'start' ? 'live' : 'ended', streamUrl: action == 'start' ? url : null, replayUrl: action == 'end' && url.isNotEmpty ? url : null);
      } else if (action == 'pin') {
        final ids = (event['productIds'] as List? ?? const []).map((v) => v.toString()).toList();
        if (ids.isEmpty) { _notice('Add products when creating the event first.'); return; }
        final id = await showDialog<String>(context: context, builder: (context) => SimpleDialog(title: const Text('Feature product'), children: [for (final productId in ids) SimpleDialogOption(onPressed: () => Navigator.pop(context, productId), child: Text(ShopCatalog.instance.productById(productId)?.name ?? productId))]));
        if (id != null) await AppController.instance.backendApi.updateShopLiveEvent(eventId: event['id'].toString(), pinnedProductId: id);
      } else if (action == 'poll') { await _createPoll(event); }
      await _load();
    } catch (e) { _notice(e.toString()); }
  }

  Future<void> _createPoll(Map<String, dynamic> event) async {
    final question = TextEditingController(); final choices = TextEditingController();
    final values = await showDialog<List<String>>(context: context, builder: (context) => AlertDialog(title: const Text('Create live poll'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: question, decoration: const InputDecoration(labelText: 'Question')), TextField(controller: choices, decoration: const InputDecoration(labelText: 'Options, separated by commas'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, [question.text.trim(), ...choices.text.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty)]), child: const Text('Create poll'))]));
    if (values == null || values.length < 3) return;
    await AppController.instance.backendApi.updateShopLiveEvent(eventId: event['id'].toString(), poll: {'question': values.first, 'options': values.skip(1).take(6).toList()});
    question.dispose(); choices.dispose();
  }

  void _notice(String value) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value))); }
}

class _EventVideo extends StatefulWidget {
  final String url;
  const _EventVideo({required this.url});
  @override
  State<_EventVideo> createState() => _EventVideoState();
}

class _EventVideoState extends State<_EventVideo> {
  VideoPlayerController? controller;
  @override
  void initState() { super.initState(); controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))..initialize().then((_) { if (mounted) setState(() {}); }).catchError((_) {}); }
  @override
  void dispose() { controller?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final value = controller;
    if (value == null || !value.value.isInitialized) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    return AspectRatio(aspectRatio: value.value.aspectRatio, child: Stack(alignment: Alignment.bottomCenter, children: [VideoPlayer(value), VideoProgressIndicator(value, allowScrubbing: true), Align(alignment: Alignment.center, child: IconButton.filled(onPressed: () => setState(() => value.value.isPlaying ? value.pause() : value.play()), icon: Icon(value.value.isPlaying ? Icons.pause : Icons.play_arrow)))]));
  }
}
