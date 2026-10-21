import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'food_delivery.dart';
import 'shop.dart';

enum MarketplaceMode { all, shop, food }

/// Shared customer-facing entry point for product commerce and food delivery.
/// Existing Shop and Food ordering flows remain responsible for their distinct
/// carts, payment rules, seller processes and fulfillment lifecycles.
class MarketplaceHubScreen extends StatefulWidget {
  final MarketplaceMode initialMode;

  const MarketplaceHubScreen({super.key, this.initialMode = MarketplaceMode.all});

  @override
  State<MarketplaceHubScreen> createState() => _MarketplaceHubScreenState();
}

class _MarketplaceHubScreenState extends State<MarketplaceHubScreen> {
  late MarketplaceMode _mode = widget.initialMode;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = '';
  }

  @override
  void didUpdateWidget(covariant MarketplaceHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode) _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setMode(MarketplaceMode next) {
    if (_mode == next) return;
    setState(() => _mode = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Shop bag',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => ShopBagScreen(onHome: () => Navigator.of(context).pop())),
            ),
            icon: Badge(label: Text('${ShopCatalog.instance.bag.length}'), child: const Icon(Icons.shopping_bag_outlined)),
          ),
          IconButton(
            tooltip: 'Orders and delivery tracking',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const MarketplaceOrdersScreen()),
            ),
            icon: const Icon(Icons.receipt_long_rounded),
          ),
          IconButton(
            tooltip: 'Wishlist',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const ShopWishlistScreen()),
            ),
            icon: const Icon(Icons.favorite_border_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _MarketplaceModePicker(selected: _mode, onSelected: _setMode),
        ),
      ),
      body: switch (_mode) {
        MarketplaceMode.all => _buildAll(),
        MarketplaceMode.shop => ShopScreen(
            key: const PageStorageKey<String>('marketplace-shop-mode'),
            showAppBar: false,
            initialQuery: _query,
            onHome: () => _setMode(MarketplaceMode.all),
          ),
        MarketplaceMode.food => FoodOrderingScreen(
            key: const PageStorageKey<String>('marketplace-food-mode'),
            showAppBar: false,
            initialQuery: _query,
            viewingContext: 'Marketplace',
          ),
      },
    );
  }

  Widget _buildAll() {
    return AnimatedBuilder(
      animation: ShopCatalog.instance,
      builder: (context, _) {
        final catalog = ShopCatalog.instance;
        final matching = catalog.searchProducts(_query).take(8).toList(growable: false);
        final storeQuery = _query.trim().toLowerCase();
        final matchingStores = catalog.stores.where((store) {
          if (!store.active) return false;
          if (storeQuery.isEmpty) return true;
          return ('${store.name} ${store.description}').toLowerCase().contains(storeQuery);
        }).take(6).toList(growable: false);
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Theme.of(context).colorScheme.primary.withValues(alpha: .30),
                    Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .75),
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('One marketplace', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text('Discover products, stores, restaurants and food from the same front door. Your account and profile travel with you; order fulfillment stays specific to each service.', style: TextStyle(height: 1.45, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search products, stores or entertainment merch',
                suffixIcon: _query.isEmpty ? null : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () { _searchController.clear(); setState(() => _query = ''); },
                  icon: const Icon(Icons.close_rounded),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Browse by service', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Expanded(child: _MarketplaceEntryCard(
                icon: Icons.shopping_bag_rounded,
                title: 'Shop',
                subtitle: 'Products, seller stores, wishlist, bag and checkout.',
                action: 'Browse products',
                onTap: () => _setMode(MarketplaceMode.shop),
              )),
              const SizedBox(width: 10),
              Expanded(child: _MarketplaceEntryCard(
                icon: Icons.delivery_dining_rounded,
                title: 'Food',
                subtitle: 'Restaurants, menus, delivery and pickup orders.',
                action: 'Find food',
                onTap: () => _setMode(MarketplaceMode.food),
              )),
            ]),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_rounded, size: 30),
                title: const Text('Orders and delivery tracking', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('View food delivery orders from your active profile and locally saved Shop purchases in one timeline.'),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const MarketplaceOrdersScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: <Widget>[
              const Expanded(child: Text('Products and stores', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
              TextButton(onPressed: () => _setMode(MarketplaceMode.shop), child: const Text('View all')),
            ]),
            if (matching.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No local products match this search yet. Try another term or browse Food.')))
            else
              for (final product in matching)
                _MarketplaceProductRow(
                  product: product,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => ShopProductDetailsScreen(product: product)),
                  ),
                ),
            if (matchingStores.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Row(children: <Widget>[
                Expanded(child: Text(_query.trim().isEmpty ? 'Featured stores' : 'Matching stores', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
                TextButton(onPressed: () => _setMode(MarketplaceMode.shop), child: const Text('Browse Shop')),
              ]),
              for (final store in matchingStores)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (store.logoUrl?.startsWith('http://') == true || store.logoUrl?.startsWith('https://') == true)
                          ? NetworkImage(store.logoUrl!)
                          : null,
                      child: store.logoUrl == null || !(store.logoUrl!.startsWith('http://') || store.logoUrl!.startsWith('https://'))
                          ? const Icon(Icons.storefront_rounded)
                          : null,
                    ),
                    title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(store.description.isEmpty ? 'Browse products from this store' : store.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                      builder: (_) => ShopStoreScreen(store: store, onHome: () => Navigator.of(context).pop()),
                    )),
                  ),
                ),
            ],
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined, size: 30),
                title: const Text('Restaurant results use your chosen delivery location', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Open Food to use device location with permission or enter an address, city or postal code. The same search phrase is carried into the restaurant finder.'),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => _setMode(MarketplaceMode.food),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MarketplaceModePicker extends StatelessWidget {
  final MarketplaceMode selected;
  final ValueChanged<MarketplaceMode> onSelected;

  const _MarketplaceModePicker({required this.selected, required this.onSelected});

  static const _options = <({MarketplaceMode mode, String label, IconData icon})>[
    (mode: MarketplaceMode.all, label: 'All', icon: Icons.grid_view_rounded),
    (mode: MarketplaceMode.shop, label: 'Shop', icon: Icons.shopping_bag_outlined),
    (mode: MarketplaceMode.food, label: 'Food', icon: Icons.delivery_dining_rounded),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: <Widget>[
          for (final option in _options) ...<Widget>[
            ChoiceChip(
              selected: selected == option.mode,
              avatar: Icon(option.icon, size: 17),
              label: Text(option.label),
              onSelected: (_) => onSelected(option.mode),
            ),
            const SizedBox(width: 8),
          ],
        ]),
      );
}

class _MarketplaceEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  const _MarketplaceEntryCard({required this.icon, required this.title, required this.subtitle, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Icon(icon, size: 30),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.white60, height: 1.3, fontSize: 12)),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: onTap, child: Text(action))),
          ]),
        ),
      );
}

class _MarketplaceProductRow extends StatelessWidget {
  final ShopProduct product;
  final VoidCallback onTap;

  const _MarketplaceProductRow({required this.product, required this.onTap});

  Widget _image() {
    if (product.imageUrls.isEmpty) return const Icon(Icons.shopping_bag_outlined, size: 30);
    final source = product.imageUrls.first.trim();
    if (source.startsWith('data:image/')) {
      try {
        return Image.memory(base64Decode(source.substring(source.indexOf(',') + 1)), width: 64, height: 64, fit: BoxFit.cover);
      } catch (_) {
        return const Icon(Icons.shopping_bag_outlined, size: 30);
      }
    }
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      return Image.network(source, width: 64, height: 64, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 30));
    }
    return const Icon(Icons.shopping_bag_outlined, size: 30);
  }

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 64, height: 64, child: _image())),
          title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${product.category} · ${product.price.toStringAsFixed(2)} ${product.currency}\n${product.description}', maxLines: 2, overflow: TextOverflow.ellipsis),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}


class MarketplaceOrdersScreen extends StatefulWidget {
  const MarketplaceOrdersScreen({super.key});

  @override
  State<MarketplaceOrdersScreen> createState() => _MarketplaceOrdersScreenState();
}

class _MarketplaceOrdersScreenState extends State<MarketplaceOrdersScreen> {
  late final FoodDeliveryApi _foodApi;
  List<FoodOrderResult> _foodOrders = const <FoodOrderResult>[];
  List<ShopOrder> _shopOrders = const <ShopOrder>[];
  bool _loadingFood = true;
  String? _foodError;

  @override
  void initState() {
    super.initState();
    final backend = AppController.instance.backendApi;
    _foodApi = FoodDeliveryApi(baseUrl: backend.baseUrl, token: backend.token);
    _refreshLocalOrders();
    _loadFoodOrders();
  }

  void _refreshLocalOrders() {
    final currentProfile = AppController.instance.currentProfile;
    final orders = ShopCatalog.instance.orders
        .where((order) => order.profileId == null || order.profileId == currentProfile?.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) setState(() => _shopOrders = orders);
  }

  Future<void> _loadFoodOrders() async {
    final backend = AppController.instance.backendApi;
    final profile = AppController.instance.currentProfile;
    if (!backend.isAuthenticated || profile == null || profile.id.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadingFood = false;
        _foodError = 'Sign in and select a profile to load server-backed food orders. Your local Shop purchases remain visible below.';
      });
      return;
    }
    setState(() {
      _loadingFood = true;
      _foodError = null;
    });
    try {
      final orders = await _foodApi.getCustomerOrders(profileId: profile.id, limit: 50);
      if (!mounted) return;
      setState(() {
        _foodOrders = orders;
        _loadingFood = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingFood = false;
        _foodError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refresh() async {
    _refreshLocalOrders();
    await _loadFoodOrders();
  }

  @override
  Widget build(BuildContext context) {
    final entries = <({DateTime date, bool isFood, ShopOrder? shop, FoodOrderResult? food})>[];
    for (final order in _shopOrders) {
      entries.add((date: order.createdAt, isFood: false, shop: order, food: null));
    }
    for (final order in _foodOrders) {
      entries.add((date: order.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0), isFood: true, shop: null, food: order));
    }
    entries.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text('Orders and delivery')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  const Icon(Icons.receipt_long_rounded, size: 30),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text('One order timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    SizedBox(height: 5),
                    Text('Food delivery orders come from the authenticated backend. Shop orders are currently stored on this device and will only sync across devices when a marketplace order API is configured.', style: TextStyle(color: Colors.white60, height: 1.4)),
                  ])),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            if (_foodError != null)
              Card(child: ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Food order history unavailable', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(_foodError!),
                trailing: IconButton(tooltip: 'Retry', onPressed: _loadingFood ? null : _loadFoodOrders, icon: const Icon(Icons.refresh_rounded)),
              )),
            if (_loadingFood)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (entries.isEmpty && !_loadingFood)
              const Card(child: Padding(padding: EdgeInsets.all(22), child: Center(child: Text('No orders to show yet. Shop and Food orders will appear here when available.')))),
            for (final entry in entries)
              if (entry.isFood && entry.food != null)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.delivery_dining_rounded)),
                    title: Text(entry.food!.restaurantName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('Food order #${entry.food!.id}\n${entry.food!.status} · ${entry.food!.fulfillmentMethod} · ${_moneyFromCents(entry.food!.totalCents, entry.food!.currencyCode)} · ${_formatDate(entry.date)}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                      builder: (_) => FoodOrderStatusScreen(api: _foodApi, order: entry.food!),
                    )),
                  ),
                )
              else if (entry.shop != null)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.shopping_bag_outlined)),
                    title: Text('Shop order #${entry.shop!.id}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${_shopOrderDescription(entry.shop!)}\n${entry.shop!.total.toStringAsFixed(2)} USD · ${_formatDate(entry.date)} · ${entry.shop!.profileId == null ? 'Legacy unassigned local record' : 'Local profile order'}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.check_circle_outline_rounded),
                    onTap: () => showDialog<void>(context: context, builder: (_) => AlertDialog(
                      title: Text('Shop order #${entry.shop!.id}'),
                      content: Text('Transaction: ${entry.shop!.transactionId}\nItems: ${_shopOrderDescription(entry.shop!)}\nTotal recorded: ${entry.shop!.total.toStringAsFixed(2)} USD\nProfile: ${entry.shop!.profileId ?? 'Not recorded (legacy order)'}\n\nThis is the locally stored development checkout record.'),
                      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                    )),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _shopOrderDescription(ShopOrder order) {
    final catalog = ShopCatalog.instance;
    final names = order.lines.map((line) => catalog.productById(line.productId)?.name ?? 'Product ${line.productId}').toList();
    if (names.isEmpty) return 'Purchase';
    final count = order.lines.fold<int>(0, (total, line) => total + line.quantity);
    final label = names.take(2).join(', ');
    return count > 2 ? '$label and ${count - 2} more item(s)' : label;
  }

  String _formatDate(DateTime date) => date.toLocal().toString().split('.').first;

  String _moneyFromCents(int cents, String currency) => '${(cents / 100).toStringAsFixed(2)} $currency';
}
