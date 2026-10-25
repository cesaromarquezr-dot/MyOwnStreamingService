import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// External commerce discovery. Mercado Libre search uses its public catalog
/// endpoint; other providers open their official search pages until the owner
/// has approved API credentials for those partner-only integrations.
class ExternalMarketplaceScreen extends StatefulWidget {
  const ExternalMarketplaceScreen({super.key});

  @override
  State<ExternalMarketplaceScreen> createState() => _ExternalMarketplaceScreenState();
}

class _ExternalMarketplaceScreenState extends State<ExternalMarketplaceScreen> {
  final TextEditingController _search = TextEditingController();
  final http.Client _client = http.Client();
  List<_ExternalProduct> _products = const [];
  bool _loading = false;
  String? _error;
  String _site = 'MLM';
  String _query = '';

  static const Map<String, String> _sites = {
    'MLM': 'Mexico',
    'MLA': 'Argentina',
    'MLB': 'Brazil',
    'MCO': 'Colombia',
    'MCL': 'Chile',
  };

  @override
  void dispose() {
    _search.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _runSearch([String? value]) async {
    final query = (value ?? _search.text).trim();
    setState(() {
      _query = query;
      _loading = query.isNotEmpty;
      _error = null;
      _products = const [];
    });
    if (query.isEmpty) return;
    try {
      final uri = Uri.https('api.mercadolibre.com', '/sites/$_site/search', {
        'q': query,
        'limit': '30',
      });
      final response = await _client.get(uri, headers: const {
        'Accept': 'application/json',
        'User-Agent': 'MyOwnStreamingService/1.0',
      }).timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Mercado Libre returned HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['results'] is! List) {
        throw const FormatException('Unexpected product-search response.');
      }
      final products = (decoded['results'] as List)
          .whereType<Map>()
          .map((item) => _ExternalProduct.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.title.isNotEmpty && item.url.isNotEmpty)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
        if (products.isEmpty) _error = 'No listings found. Try another search or marketplace.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load Mercado Libre results. ${error.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _openProvider(String provider) async {
    final q = _query.isEmpty ? _search.text.trim() : _query;
    final encoded = Uri.encodeQueryComponent(q);
    final urls = <String, String>{
      'Amazon': 'https://www.amazon.com.mx/s?k=$encoded',
      'eBay': 'https://www.ebay.com/sch/i.html?_nkw=$encoded',
      'Uber Eats': 'https://www.ubereats.com/search?q=$encoded',
      'Rappi': 'https://www.rappi.com.mx/search?query=$encoded',
    };
    final raw = urls[provider];
    if (raw == null) return;
    final uri = Uri.parse(raw);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $provider.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('External Food & Marketplace')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Search across marketplaces', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Search Mercado Libre listings here, or open a provider’s official search page. Checkout and payments remain with each provider.', style: TextStyle(height: 1.4)),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
                decoration: InputDecoration(
                  hintText: 'Search food, electronics, clothing…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _runSearch),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Expanded(child: Text('Mercado Libre country', style: TextStyle(fontWeight: FontWeight.w700))),
                DropdownButton<String>(value: _site, items: _sites.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (value) {
                  if (value == null) return;
                  setState(() => _site = value);
                  if (_query.isNotEmpty) _runSearch(_query);
                }),
              ]),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _loading ? null : _runSearch, icon: const Icon(Icons.travel_explore), label: const Text('Search Mercado Libre'))),
            ]),
          )),
          const SizedBox(height: 8),
          const Text('Provider shortcuts', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _ProviderTile(icon: Icons.shopping_bag_outlined, name: 'Amazon', description: 'Open Amazon Mexico product search. Creators API access requires an accepted Associates account and API credentials.', status: 'Search link available · API approval required', onTap: () => _openProvider('Amazon')),
          _ProviderTile(icon: Icons.storefront_outlined, name: 'eBay', description: 'Open eBay product search. Production Buy API access is partner-restricted; the app does not pretend to have checkout access.', status: 'Search link available · production API approval required', onTap: () => _openProvider('eBay')),
          _ProviderTile(icon: Icons.delivery_dining_rounded, name: 'Uber Eats', description: 'Open Uber Eats search. Marketplace APIs are designed for approved partner/merchant integrations and may require written approval.', status: 'Search link available · partner access required', onTap: () => _openProvider('Uber Eats')),
          _ProviderTile(icon: Icons.shopping_cart_outlined, name: 'Mercado Libre', description: 'Live product search through the public catalog endpoint for the selected country. Purchases open on Mercado Libre.', status: 'Catalog search enabled', onTap: () => _runSearch()),
          _ProviderTile(icon: Icons.restaurant_outlined, name: 'Rappi', description: 'Open Rappi search in the browser/app where available. No private Rappi API is called.', status: 'Search link available · no API credentials configured', onTap: () => _openProvider('Rappi')),
          const SizedBox(height: 12),
          if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Card(child: ListTile(leading: const Icon(Icons.info_outline), title: const Text('Search status'), subtitle: Text(_error!))),
          if (!_loading && _products.isNotEmpty) ...[
            Text('Mercado Libre results (${_products.length})', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final product in _products) _ProductTile(product: product),
          ],
          const SizedBox(height: 8),
          const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Security note: provider API secrets must be stored on the backend, never in Flutter source or the mobile app. API access, catalog coverage, affiliate rules and order placement depend on each provider’s current terms and approval.', style: TextStyle(height: 1.45)))),
        ],
      ),
    );
  }
}

class _ExternalProduct {
  final String title;
  final String url;
  final String image;
  final String price;
  final String currency;
  final String condition;
  final String seller;

  const _ExternalProduct({required this.title, required this.url, required this.image, required this.price, required this.currency, required this.condition, required this.seller});

  factory _ExternalProduct.fromJson(Map<String, dynamic> json) {
    final price = json['price'];
    final amount = price is num ? price.toStringAsFixed(2) : '';
    return _ExternalProduct(
      title: json['title']?.toString() ?? '',
      url: json['permalink']?.toString() ?? '',
      image: json['thumbnail']?.toString().replaceFirst('http://', 'https://') ?? '',
      price: amount,
      currency: json['currency_id']?.toString() ?? '',
      condition: json['condition']?.toString() ?? '',
      seller: (json['seller'] is Map ? (json['seller'] as Map)['nickname'] : null)?.toString() ?? '',
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final String status;
  final VoidCallback onTap;

  const _ProviderTile({required this.icon, required this.name, required this.description, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    leading: CircleAvatar(child: Icon(icon)),
    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(description), const SizedBox(height: 5), Text(status, style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w700, fontSize: 12))])),
    isThreeLine: true,
    trailing: const Icon(Icons.open_in_new_rounded),
    onTap: onTap,
  ));
}

class _ProductTile extends StatelessWidget {
  final _ExternalProduct product;
  const _ProductTile({required this.product});

  Future<void> _open() async {
    final uri = Uri.tryParse(product.url);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    leading: SizedBox(width: 64, height: 64, child: product.image.isEmpty ? const Icon(Icons.shopping_bag_outlined) : Image.network(product.image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined))),
    title: Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text('${product.price.isEmpty ? 'Price unavailable' : '${product.price} ${product.currency}'}${product.condition.isEmpty ? '' : ' · ${product.condition}'}${product.seller.isEmpty ? '' : '\nSeller: ${product.seller}'}', maxLines: 2, overflow: TextOverflow.ellipsis),
    isThreeLine: true,
    trailing: const Icon(Icons.open_in_new_rounded),
    onTap: _open,
  ));
}
