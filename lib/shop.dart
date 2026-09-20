// FILE: lib/shop.dart
// Purpose: Implements the streaming service marketplace, seller tools, bag,
// wishlist, and the two checkout flows.
//
// Security note:
// Card numbers, CVV values, or full payment credentials are never stored by
// this Flutter model. A production payment provider should replace the
// development gateway with provider-side tokenization/hosted checkout.

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'localization.dart';
import 'worldwide_location.dart';

/// A media/entity relationship attached to a shop product.
class ShopAssociation {
  final String type;
  final String id;
  final String name;

  const ShopAssociation({required this.type, required this.id, required this.name});

  Map<String, dynamic> toJson() => {'type': type, 'id': id, 'name': name};

  factory ShopAssociation.fromJson(Map<String, dynamic> json) => ShopAssociation(
        type: json['type']?.toString() ?? 'other',
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
}

/// A seller-created marketplace product.
class ShopProduct {
  final String id;
  final String storeId;
  String name;
  String description;
  String productType;
  String category;
  double price;
  String currency;
  int inventoryQuantity;
  bool featured;
  bool active;
  List<String> imageUrls;
  List<ShopAssociation> associations;

  ShopProduct({
    required this.id,
    required this.storeId,
    required this.name,
    this.description = '',
    this.productType = 'Merchandise',
    this.category = 'Other',
    this.price = 0,
    this.currency = 'USD',
    this.inventoryQuantity = 0,
    this.featured = false,
    this.active = true,
    List<String>? imageUrls,
    List<ShopAssociation>? associations,
  })  : imageUrls = imageUrls ?? <String>[],
        associations = associations ?? <ShopAssociation>[];

  Map<String, dynamic> toJson() => {
        'id': id,
        'storeId': storeId,
        'name': name,
        'description': description,
        'productType': productType,
        'category': category,
        'price': price,
        'currency': currency,
        'inventoryQuantity': inventoryQuantity,
        'featured': featured,
        'active': active,
        'imageUrls': imageUrls,
        'associations': associations.map((a) => a.toJson()).toList(),
      };

  factory ShopProduct.fromJson(Map<String, dynamic> json) => ShopProduct(
        id: json['id']?.toString() ?? '',
        storeId: json['storeId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        productType: json['productType']?.toString() ?? 'Merchandise',
        category: json['category']?.toString() ?? 'Other',
        price: json['price'] is num ? (json['price'] as num).toDouble() : double.tryParse(json['price']?.toString() ?? '') ?? 0,
        currency: json['currency']?.toString() ?? 'USD',
        inventoryQuantity: json['inventoryQuantity'] is num ? (json['inventoryQuantity'] as num).toInt() : int.tryParse(json['inventoryQuantity']?.toString() ?? '') ?? 0,
        featured: json['featured'] == true,
        active: json['active'] != false,
        imageUrls: (json['imageUrls'] as List?)?.map((e) => e.toString()).toList(),
        associations: (json['associations'] as List?)?.whereType<Map>().map((e) => ShopAssociation.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
}

/// A marketplace store owned by an account.
class ShopStore {
  final String id;
  final String ownerAccountId;
  String name;
  String description;
  String? logoUrl;
  String? bannerUrl;
  bool active;
  WorldwideAddress? address;

  ShopStore({
    required this.id,
    required this.ownerAccountId,
    required this.name,
    this.description = '',
    this.logoUrl,
    this.bannerUrl,
    this.active = true,
    this.address,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerAccountId': ownerAccountId,
        'name': name,
        'description': description,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'active': active,
        'address': address?.toJson(),
      };

  factory ShopStore.fromJson(Map<String, dynamic> json) => ShopStore(
        id: json['id']?.toString() ?? '',
        ownerAccountId: json['ownerAccountId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        logoUrl: json['logoUrl']?.toString(),
        bannerUrl: json['bannerUrl']?.toString(),
        active: json['active'] != false,
        address: json['address'] is Map
            ? WorldwideAddress.fromJson(Map<String, dynamic>.from(json['address'] as Map))
            : null,
      );
}

/// One bag/cart line.
class ShopBagLine {
  final String productId;
  int quantity;

  ShopBagLine({required this.productId, this.quantity = 1});
}
/// A saved payment-method summary. Sensitive card data is intentionally absent.
class ShopPaymentMethod {
  final String id;
  final String label;
  final String? last4;
  final bool subscriptionCard;

  const ShopPaymentMethod({
    required this.id,
    required this.label,
    this.last4,
    this.subscriptionCard = false,
  });
}

/// Development marketplace payment result. A real processor must replace this.
class ShopPaymentResult {
  final bool success;
  final String transactionId;
  final String? last4;

  const ShopPaymentResult({
    required this.success,
    required this.transactionId,
    this.last4,
  });
}

/// Local development payment gateway.
///
/// It deliberately keeps only a token-like identifier and last four digits.
/// It does NOT charge a real card. Production checkout should call a real
/// processor from the backend and never send raw card credentials to Dart API
/// storage.
class ShopPaymentGateway {
  const ShopPaymentGateway();

  Future<ShopPaymentResult> pay({
    required double amount,
    required ShopPaymentMethod method,
    String? cardNumber,
  }) async {
    if (amount <= 0) {
      throw Exception('Checkout total must be greater than zero.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final digits = cardNumber?.replaceAll(RegExp(r'\D'), '') ?? method.last4;
    final last4 = digits != null && digits.length >= 4
        ? digits.substring(digits.length - 4)
        : null;
    return ShopPaymentResult(
      success: true,
      transactionId: 'dev_tx_${DateTime.now().microsecondsSinceEpoch}',
      last4: last4,
    );
  }
}

/// Completed marketplace order. Card credentials are never stored.
class ShopOrder {
  final String id;
  final List<ShopBagLine> lines;
  final double total;
  final String transactionId;
  final DateTime createdAt;

  ShopOrder({required this.id, required this.lines, required this.total, required this.transactionId, DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'lines': lines.map((l) => {'productId': l.productId, 'quantity': l.quantity}).toList(),
        'total': total,
        'transactionId': transactionId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ShopOrder.fromJson(Map<String, dynamic> json) => ShopOrder(
        id: json['id']?.toString() ?? '',
        lines: (json['lines'] as List?)?.whereType<Map>().map((item) {
          final map = Map<String, dynamic>.from(item);
          return ShopBagLine(productId: map['productId']?.toString() ?? '', quantity: int.tryParse(map['quantity']?.toString() ?? '') ?? 1);
        }).toList() ?? <ShopBagLine>[],
        total: json['total'] is num ? (json['total'] as num).toDouble() : double.tryParse(json['total']?.toString() ?? '') ?? 0,
        transactionId: json['transactionId']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

/// Owns marketplace catalog, seller stores, wishlist, and the global bag.
class ShopCatalog extends ChangeNotifier {
  ShopCatalog._();
  static final ShopCatalog instance = ShopCatalog._();

  final List<ShopStore> stores = <ShopStore>[];
  final List<ShopProduct> products = <ShopProduct>[];
  final List<String> wishlistProductIds = <String>[];
  final List<ShopBagLine> bag = <ShopBagLine>[];
  final List<ShopOrder> orders = <ShopOrder>[];
  bool _initialized = false;
  SharedPreferences? _prefs;

  /// Loads seller catalog, wishlist, and bag state from local device storage.
  /// No card credentials are persisted here.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _prefs = await SharedPreferences.getInstance();
      final rawStores = _prefs!.getString('shop_stores');
      final rawProducts = _prefs!.getString('shop_products');
      final rawWishlist = _prefs!.getString('shop_wishlist');
      final rawBag = _prefs!.getString('shop_bag');
      final rawOrders = _prefs!.getString('shop_orders');
      if (rawStores != null) {
        final decoded = jsonDecode(rawStores);
        if (decoded is List) stores.addAll(decoded.whereType<Map>().map((e) => ShopStore.fromJson(Map<String, dynamic>.from(e))));
      }
      if (rawProducts != null) {
        final decoded = jsonDecode(rawProducts);
        if (decoded is List) products.addAll(decoded.whereType<Map>().map((e) => ShopProduct.fromJson(Map<String, dynamic>.from(e))));
      }
      if (rawWishlist != null) {
        final decoded = jsonDecode(rawWishlist);
        if (decoded is List) wishlistProductIds.addAll(decoded.map((e) => e.toString()));
      }
      if (rawOrders != null) {
        final decoded = jsonDecode(rawOrders);
        if (decoded is List) orders.addAll(decoded.whereType<Map>().map((e) => ShopOrder.fromJson(Map<String, dynamic>.from(e))));
      }
      if (rawBag != null) {
        final decoded = jsonDecode(rawBag);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            final map = Map<String, dynamic>.from(item);
            bag.add(ShopBagLine(productId: map['productId']?.toString() ?? '', quantity: int.tryParse(map['quantity']?.toString() ?? '') ?? 1));
          }
        }
      }
      notifyListeners();
    } catch (_) {
      // Corrupt optional Shop cache must never prevent the streaming app from starting.
    }
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString('shop_stores', jsonEncode(stores.map((s) => s.toJson()).toList()));
    await prefs.setString('shop_products', jsonEncode(products.map((p) => p.toJson()).toList()));
    await prefs.setString('shop_wishlist', jsonEncode(wishlistProductIds));
    await prefs.setString('shop_bag', jsonEncode(bag.map((line) => {'productId': line.productId, 'quantity': line.quantity}).toList()));
    await prefs.setString('shop_orders', jsonEncode(orders.map((order) => order.toJson()).toList()));
  }

  /// Returns stores owned by the current account.
  List<ShopStore> get currentAccountStores {
    final accountId = AppController.instance.currentAccount?.id;
    if (accountId == null || accountId.isEmpty) return <ShopStore>[];
    return stores.where((s) => s.ownerAccountId == accountId && s.active).toList();
  }

  bool get hasCurrentAccountStore => currentAccountStores.isNotEmpty;

  List<ShopProduct> productsForStore(String storeId) => products
      .where((p) => p.storeId == storeId && p.active)
      .toList();

  ShopProduct? productById(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  ShopStore? storeById(String id) {
    for (final store in stores) {
      if (store.id == id) return store;
    }
    return null;
  }

  /// Creates a seller store. The existence of the store is the seller source of truth.
  ShopStore createStore({
    required String name,
    String description = '',
    String? logoUrl,
    String? bannerUrl,
    WorldwideAddress? address,
  }) {
    final accountId = AppController.instance.currentAccount?.id;
    if (accountId == null || accountId.isEmpty) {
      throw Exception('Sign in to create a store.');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw Exception('Store name is required.');
    final store = ShopStore(
      id: 'store_${DateTime.now().microsecondsSinceEpoch}',
      ownerAccountId: accountId,
      name: cleanName,
      description: description.trim(),
      logoUrl: logoUrl?.trim().isEmpty == true ? null : logoUrl?.trim(),
      bannerUrl: bannerUrl?.trim().isEmpty == true ? null : bannerUrl?.trim(),
      address: address,
    );
    stores.add(store);
    notifyListeners();
    _save();
    return store;
  }

  /// Updates a seller-owned store's public profile and appearance.
  void updateStore(ShopStore store, {String? name, String? description, String? logoUrl, String? bannerUrl}) {
    final accountId = AppController.instance.currentAccount?.id;
    if (store.ownerAccountId != accountId) return;
    if (name != null && name.trim().isNotEmpty) store.name = name.trim();
    if (description != null) store.description = description.trim();
    store.logoUrl = logoUrl?.trim().isEmpty == true ? null : logoUrl?.trim();
    store.bannerUrl = bannerUrl?.trim().isEmpty == true ? null : bannerUrl?.trim();
    notifyListeners();
    _save();
  }

  /// Creates a seller product with media/franchise/music relationships.
  ShopProduct createProduct({
    required String storeId,
    required String name,
    String description = '',
    String productType = 'Merchandise',
    String category = 'Other',
    double price = 0,
    int inventoryQuantity = 0,
    bool featured = false,
    List<String>? imageUrls,
    List<ShopAssociation>? associations,
  }) {
    final store = storeById(storeId);
    if (store == null) throw Exception('Store not found.');
    final accountId = AppController.instance.currentAccount?.id;
    if (store.ownerAccountId != accountId) {
      throw Exception('You can only add products to your own store.');
    }
    final product = ShopProduct(
      id: 'product_${DateTime.now().microsecondsSinceEpoch}',
      storeId: storeId,
      name: name.trim(),
      description: description.trim(),
      productType: productType,
      category: category,
      price: price,
      inventoryQuantity: inventoryQuantity,
      featured: featured,
      imageUrls: imageUrls,
      associations: associations,
    );
    products.add(product);
    notifyListeners();
    _save();
    return product;
  }

  /// Updates a seller-owned product.
  void updateProduct(ShopProduct product, {String? name, String? description, double? price, int? inventoryQuantity, bool? featured, bool? active}) {
    final accountId = AppController.instance.currentAccount?.id;
    final store = storeById(product.storeId);
    if (store == null || store.ownerAccountId != accountId) return;
    if (name != null && name.trim().isNotEmpty) product.name = name.trim();
    if (description != null) product.description = description.trim();
    if (price != null && price >= 0) product.price = price;
    if (inventoryQuantity != null && inventoryQuantity >= 0) product.inventoryQuantity = inventoryQuantity;
    if (featured != null) product.featured = featured;
    if (active != null) product.active = active;
    notifyListeners();
    _save();
  }

  /// Deletes a seller-owned product and removes it from wishlist/bag.
  void deleteProduct(String productId) {
    final product = productById(productId);
    final accountId = AppController.instance.currentAccount?.id;
    if (product == null || storeById(product.storeId)?.ownerAccountId != accountId) return;
    products.remove(product);
    wishlistProductIds.remove(productId);
    bag.removeWhere((line) => line.productId == productId);
    notifyListeners();
    _save();
  }

  /// Returns products related to an entertainment entity.
  List<ShopProduct> productsForAssociation(String type, String id, {String? name}) {
    final cleanId = id.trim().toLowerCase();
    final cleanName = name?.trim().toLowerCase();
    return products.where((product) {
      if (!product.active) return false;
      return product.associations.any((a) =>
          a.type.toLowerCase() == type.toLowerCase() &&
          (a.id.trim().toLowerCase() == cleanId ||
              (cleanName != null && a.name.trim().toLowerCase() == cleanName)));
    }).toList();
  }

  /// Searches the global marketplace across products, stores, and media.
  List<ShopProduct> searchProducts(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return products.where((p) => p.active).toList();
    return products.where((p) {
      if (!p.active) return false;
      final store = storeById(p.storeId);
      final haystack = [
        p.name,
        p.description,
        p.productType,
        p.category,
        store?.name ?? '',
        ...p.associations.map((a) => '${a.type} ${a.name} ${a.id}'),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  bool isWishlisted(String productId) => wishlistProductIds.contains(productId);

  void toggleWishlist(String productId) {
    if (wishlistProductIds.contains(productId)) {
      wishlistProductIds.remove(productId);
    } else {
      wishlistProductIds.add(productId);
    }
    notifyListeners();
    _save();
  }

  int quantityFor(String productId) {
    for (final line in bag) {
      if (line.productId == productId) return line.quantity;
    }
    return 0;
  }

  void addToBag(String productId, {int quantity = 1}) {
    final product = productById(productId);
    if (product == null || !product.active || product.inventoryQuantity <= 0) return;
    final existing = bag.where((line) => line.productId == productId).toList();
    if (existing.isEmpty) {
      bag.add(ShopBagLine(productId: productId, quantity: quantity.clamp(1, product.inventoryQuantity).toInt()));
    } else {
      existing.first.quantity = (existing.first.quantity + quantity).clamp(1, product.inventoryQuantity).toInt();
    }
    notifyListeners();
    _save();
  }

  void changeQuantity(String productId, int delta) {
    final line = bag.where((x) => x.productId == productId).isEmpty ? null : bag.where((x) => x.productId == productId).first;
    final product = productById(productId);
    if (line == null || product == null) return;
    line.quantity += delta;
    if (line.quantity <= 0) {
      bag.remove(line);
    } else {
      line.quantity = line.quantity.clamp(1, product.inventoryQuantity).toInt().toInt();
    }
    notifyListeners();
    _save();
  }

  void removeFromBag(String productId) {
    bag.removeWhere((line) => line.productId == productId);
    notifyListeners();
    _save();
  }

  List<ShopBagLine> linesForStore(String storeId) => bag
      .where((line) => productById(line.productId)?.storeId == storeId)
      .map((line) => ShopBagLine(productId: line.productId, quantity: line.quantity))
      .toList();

  double subtotal([Iterable<ShopBagLine>? lines]) {
    final source = lines ?? bag;
    return source.fold<double>(0, (total, line) {
      final product = productById(line.productId);
      return total + (product?.price ?? 0) * line.quantity;
    });
  }

  int get bagCount => bag.fold<int>(0, (sum, line) => sum + line.quantity);

  /// Records a completed order after payment succeeds.
  void recordOrder({required Iterable<ShopBagLine> lines, required double total, required String transactionId}) {
    orders.insert(0, ShopOrder(
      id: 'order_${DateTime.now().microsecondsSinceEpoch}',
      lines: lines.map((line) => ShopBagLine(productId: line.productId, quantity: line.quantity)).toList(),
      total: total,
      transactionId: transactionId,
    ));
    if (orders.length > 500) orders.removeRange(500, orders.length);
    _save();
    notifyListeners();
  }

  /// Removes purchased lines only after a successful checkout.
  void completeCheckout(Iterable<ShopBagLine> purchasedLines) {
    for (final purchased in purchasedLines) {
      final product = productById(purchased.productId);
      if (product != null) {
        product.inventoryQuantity = (product.inventoryQuantity - purchased.quantity).clamp(0, product.inventoryQuantity).toInt();
      }
      final line = bag.where((x) => x.productId == purchased.productId).isEmpty ? null : bag.where((x) => x.productId == purchased.productId).first;
      if (line == null) continue;
      line.quantity -= purchased.quantity;
      if (line.quantity <= 0) bag.remove(line);
    }
    notifyListeners();
  }
}

/// Top-level marketplace. Search covers products, stores, and entertainment relationships.
class ShopScreen extends StatefulWidget {
  final VoidCallback? onHome;
  final String? contextAssociationType;
  final String? contextAssociationId;
  final String? contextAssociationName;

  const ShopScreen({
    super.key,
    this.onHome,
    this.contextAssociationType,
    this.contextAssociationId,
    this.contextAssociationName,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final TextEditingController searchController = TextEditingController();
  String search = '';

  ShopCatalog get catalog => ShopCatalog.instance;

  List<ShopProduct> get visibleProducts {
    if (widget.contextAssociationType != null && widget.contextAssociationId != null) {
      return catalog.productsForAssociation(
        widget.contextAssociationType!,
        widget.contextAssociationId!,
        name: widget.contextAssociationName,
      );
    }
    return catalog.searchProducts(search);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<ShopProduct> get featuredProducts => catalog.products.where((p) => p.active && p.featured).take(8).toList();

  List<ShopProduct> get libraryRelatedProducts {
    final media = AppController.instance.library;
    if (media.isEmpty) return const <ShopProduct>[];
    final ids = <String>{};
    final names = <String>{};
    for (final item in media) {
      ids.add(item.id.toLowerCase());
      names.add(item.title.toLowerCase());
      if (item.franchiseId != null) ids.add(item.franchiseId!.toLowerCase());
      if (item.franchiseName != null) names.add(item.franchiseName!.toLowerCase());
    }
    return catalog.products.where((p) => p.active && p.associations.any((a) => ids.contains(a.id.toLowerCase()) || names.contains(a.name.toLowerCase()))).take(8).toList();
  }

  List<MediaItem> get mediaMatches {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return const <MediaItem>[];
    return AppController.instance.library.where((media) {
      final haystack = [
        media.title,
        media.franchiseName ?? '',
        media.originalTitle ?? '',
        media.canonicalTitle ?? '',
        ...media.genres,
        ...media.tags,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).take(12).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: catalog,
      builder: (context, _) {
        final products = visibleProducts;
        final stores = catalog.stores.where((s) => s.active &&
            (search.isEmpty || s.name.toLowerCase().contains(search.toLowerCase()) || s.description.toLowerCase().contains(search.toLowerCase()))).toList();
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Home',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (widget.onHome != null) {
                  widget.onHome!();
                } else if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
            title: UniversalText(widget.contextAssociationName == null ? 'Shop' : 'Shop • ${widget.contextAssociationName}'),
            actions: [
              IconButton(
                tooltip: 'Wishlist',
                icon: const Icon(Icons.favorite_border_rounded),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopWishlistScreen())),
              ),
              _BagButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopBagScreen()))),
              const LanguagePicker(),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
            children: [
              Row(
                children: [
                  Expanded(child: Text(widget.contextAssociationName == null ? 'Marketplace' : 'Related products', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900))),
                  if (widget.contextAssociationName == null)
                    FilledButton.icon(onPressed: _createStore, icon: const Icon(Icons.storefront_outlined), label: const UniversalText('Create Store')),
                ],
              ),
              const SizedBox(height: 8),
              UniversalText(widget.contextAssociationName == null
                  ? 'Search products, stores, movies, shows, franchises, songs, artists, albums, playlists, and collections.'
                  : 'Only products actually associated with this entertainment entity are shown.'),
              const SizedBox(height: 14),
              if (widget.contextAssociationName == null)
                TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => search = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: tr('Search the Shop'),
                    suffixIcon: search.isEmpty ? null : IconButton(onPressed: () { searchController.clear(); setState(() => search = ''); }, icon: const Icon(Icons.clear)),
                    border: const OutlineInputBorder(),
                  ),
                ),
              if (widget.contextAssociationName == null) ...[
                if (search.isEmpty && featuredProducts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionTitle('Featured Products', Icons.star_outline_rounded),
                  const SizedBox(height: 8),
                  for (final product in featuredProducts) _productCard(context, product),
                ],
                if (search.isEmpty && libraryRelatedProducts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionTitle('Related to Your Library', Icons.library_music_outlined),
                  const SizedBox(height: 8),
                  for (final product in libraryRelatedProducts) _productCard(context, product),
                ],
                const SizedBox(height: 20),
                _sectionTitle('Stores', Icons.storefront_outlined),
                const SizedBox(height: 8),
                if (stores.isEmpty) _empty('No stores match this search yet.'),
                for (final store in stores.take(8)) _storeTile(context, store),
                if (search.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _sectionTitle('Media', Icons.movie_filter_outlined),
                  const SizedBox(height: 8),
                  if (mediaMatches.isEmpty) _empty('No library media matches this search.'),
                  for (final media in mediaMatches)
                    Card(
                      child: ListTile(
                        title: Text(media.title),
                        subtitle: Text(media.franchiseName == null ? media.type : '${media.type} • ${media.franchiseName}'),
                        trailing: ContextualShopButton.forMedia(context, media),
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 20),
              _sectionTitle(widget.contextAssociationName == null ? 'Products' : 'Shop this title', Icons.shopping_bag_outlined),
              const SizedBox(height: 8),
              if (products.isEmpty)
                _empty(widget.contextAssociationName == null
                    ? 'No real seller products are listed yet.'
                    : 'No seller product is currently associated with this title.'),
              for (final product in products) _productCard(context, product),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))]);

  Widget _empty(String text) => Card(child: Padding(padding: const EdgeInsets.all(20), child: UniversalText(text, textAlign: TextAlign.center)));

  Widget _storeTile(BuildContext context, ShopStore store) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Text(store.name.isEmpty ? '?' : store.name.isEmpty ? '?' : store.name.substring(0, 1).toUpperCase())),
          title: Text(store.name),
          subtitle: Text('${catalog.productsForStore(store.id).length} active product(s)${store.description.isEmpty ? '' : ' • ${store.description}'}', maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopStoreScreen(store: store))),
        ),
      );

  Widget _productCard(BuildContext context, ShopProduct product) {
    final store = catalog.storeById(product.storeId);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _productImage(product, size: 92),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('${product.productType} • ${product.category} • ${store?.name ?? 'Store'}', style: const TextStyle(fontSize: 12)),
              if (product.associations.isNotEmpty) Text(product.associations.map((a) => a.name).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Text(_money(product.price, product.currency), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text('${product.inventoryQuantity} in stock', style: const TextStyle(fontSize: 12)),
            ])),
            Column(children: [
              IconButton(onPressed: () => catalog.toggleWishlist(product.id), icon: Icon(catalog.isWishlisted(product.id) ? Icons.favorite : Icons.favorite_border)),
              FilledButton(onPressed: product.inventoryQuantity <= 0 ? null : () => catalog.addToBag(product.id), child: const UniversalText('Add to Bag')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _productImage(ShopProduct product, {double size = 80}) {
    if (product.imageUrls.isEmpty) return Container(width: size, height: size, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.surfaceContainerHighest), child: const Icon(Icons.shopping_bag_outlined));
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(product.imageUrls.first, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: size, height: size, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.broken_image_outlined))));
  }

  Future<void> _createStore() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final logo = TextEditingController();
    final banner = TextEditingController();
    WorldwideAddress? address;
    await showDialog<void>(context: context, builder: (_) => AlertDialog(
      title: const UniversalText('Create Store'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Store name')),
        TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
        TextField(controller: logo, decoration: const InputDecoration(labelText: 'Logo URL (optional)')),
        TextField(controller: banner, decoration: const InputDecoration(labelText: 'Banner URL (optional)')),
        const SizedBox(height: 14),
        const Align(alignment: Alignment.centerLeft, child: UniversalText('Store address', style: TextStyle(fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        StatefulBuilder(builder: (context, setAddressState) => WorldwideAddressForm(
          requireStreet: true,
          onChanged: (value) {
            address = value;
            setAddressState(() {});
          },
        )),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const UniversalText('Cancel')),
        FilledButton(onPressed: () {
          try {
            if (address == null || !address!.isComplete || address!.addressLine1.trim().isEmpty) {
              throw Exception('Enter the complete store address, including country, city and postal/ZIP code.');
            }
            final store = catalog.createStore(name: name.text, description: description.text, logoUrl: logo.text, bannerUrl: banner.text, address: address);
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => SellerDashboardScreen(store: store)));
          } catch (error) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
          }
        }, child: const UniversalText('Create Store')),
      ],
    ));
    name.dispose(); description.dispose(); logo.dispose(); banner.dispose();
  }

  String _money(double value, String currency) => '${currency == 'USD' ? '\$' : currency} ${value.toStringAsFixed(2)}';
}

/// Seller's storefront page.
class ShopStoreScreen extends StatelessWidget {
  final ShopStore store;
  const ShopStoreScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final catalog = ShopCatalog.instance;
    return AnimatedBuilder(animation: catalog, builder: (_, __) {
      final products = catalog.productsForStore(store.id);
      final lines = catalog.linesForStore(store.id);
      return Scaffold(
        appBar: AppBar(title: Text(store.name), actions: [
          _BagButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopBagScreen()))),
        ]),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Container(height: 150, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), image: store.bannerUrl?.isNotEmpty == true ? DecorationImage(image: NetworkImage(store.bannerUrl!), fit: BoxFit.cover) : null, color: Theme.of(context).colorScheme.surfaceContainerHighest)),
          const SizedBox(height: 14),
          Row(children: [CircleAvatar(radius: 30, backgroundImage: store.logoUrl?.isNotEmpty == true ? NetworkImage(store.logoUrl!) : null, child: store.logoUrl?.isNotEmpty == true ? null : Text(store.name.isEmpty ? '?' : store.name.substring(0, 1).toUpperCase())), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store.name, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), if (store.description.isNotEmpty) Text(store.description)]))]),
          const SizedBox(height: 18),
          if (lines.isNotEmpty) FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopCheckoutScreen(lines: lines, title: 'Checkout • ${store.name}', storeSpecific: true))), icon: const Icon(Icons.lock_outline), label: const UniversalText('Checkout this Store')),
          const SizedBox(height: 16),
          const Text('Featured', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final product in products.where((p) => p.featured)) _productRow(context, product),
          const SizedBox(height: 14),
          const Text('All Products', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          for (final product in products) _productRow(context, product),
        ]),
      );
    });
  }

  Widget _productRow(BuildContext context, ShopProduct product) {
    final catalog = ShopCatalog.instance;
    return Card(child: ListTile(
      leading: product.imageUrls.isEmpty ? const Icon(Icons.shopping_bag_outlined) : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(product.imageUrls.first, width: 52, height: 52, fit: BoxFit.cover)),
      title: Text(product.name),
      subtitle: Text('${product.category} • ${product.price.toStringAsFixed(2)} ${product.currency} • ${product.inventoryQuantity} in stock'),
      trailing: Wrap(children: [IconButton(onPressed: () => catalog.toggleWishlist(product.id), icon: Icon(catalog.isWishlisted(product.id) ? Icons.favorite : Icons.favorite_border)), OutlinedButton(onPressed: product.inventoryQuantity <= 0 ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopCheckoutScreen(lines: [ShopBagLine(productId: product.id)], title: 'Checkout • ${store.name}', storeSpecific: true))), child: const UniversalText('Buy Now')), const SizedBox(width: 6), FilledButton(onPressed: product.inventoryQuantity <= 0 ? null : () => catalog.addToBag(product.id), child: const UniversalText('Add'))]),
    ));
  }
}

/// Seller dashboard. It is surfaced in navigation only when a store exists.
class SellerDashboardScreen extends StatelessWidget {
  final ShopStore? store;
  const SellerDashboardScreen({super.key, this.store});

  @override
  Widget build(BuildContext context) {
    final catalog = ShopCatalog.instance;
    final stores = catalog.currentAccountStores;
    final activeStore = store ?? (stores.isEmpty ? null : stores.first);
    return Scaffold(
      appBar: AppBar(title: const UniversalText('Seller Dashboard')),
      body: activeStore == null
          ? const Center(child: UniversalText('Create a store to become a seller.'))
          : AnimatedBuilder(animation: catalog, builder: (_, __) {
              final products = catalog.productsForStore(activeStore.id);
              final featured = products.where((p) => p.featured).length;
              final inventory = products.fold<int>(0, (sum, p) => sum + p.inventoryQuantity);
              return ListView(padding: const EdgeInsets.all(18), children: [
                Card(child: ListTile(leading: const Icon(Icons.storefront), title: Text(activeStore.name, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: UniversalText(activeStore.address?.summary ?? 'Store settings, appearance and featured products'))),
                GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: MediaQuery.sizeOf(context).width > 800 ? 4 : 2, childAspectRatio: 1.8, children: [
                  _metric('Products', '${products.length}', Icons.inventory_2_outlined),
                  _metric('Featured', '$featured', Icons.star_outline),
                  _metric('Inventory', '$inventory', Icons.warehouse_outlined),
                  _metric('Orders', '${catalog.orders.where((o) => o.lines.any((line) => catalog.productById(line.productId)?.storeId == activeStore.id)).length}', Icons.receipt_long_outlined),
                ]),
                const SizedBox(height: 14),
                FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddShopProductScreen(store: activeStore))), icon: const Icon(Icons.add_box_outlined), label: const UniversalText('Add Product')),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopStoreScreen(store: activeStore))), icon: const Icon(Icons.storefront_outlined), label: const UniversalText('View Store')),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopStoreSettingsScreen(store: activeStore))), icon: const Icon(Icons.settings_outlined), label: const UniversalText('Store Settings & Appearance')),
                const SizedBox(height: 14),
                const Text('Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                for (final order in catalog.orders.where((o) => o.lines.any((line) => catalog.productById(line.productId)?.storeId == activeStore.id)).take(20))
                  Card(child: ListTile(title: Text(order.id), subtitle: Text('${order.createdAt} • ${order.total.toStringAsFixed(2)} USD'), trailing: const Icon(Icons.receipt_long_outlined))),
                const SizedBox(height: 14),
                const Text('Products', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                for (final product in products) Card(child: ListTile(title: Text(product.name), subtitle: Text('${product.category} • ${product.price.toStringAsFixed(2)} ${product.currency} • ${product.inventoryQuantity} in stock'), trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'edit') { _editProduct(context, product); } else if (value == 'delete') { catalog.deleteProduct(product.id); } else if (value == 'feature') { catalog.updateProduct(product, featured: !product.featured); } }, itemBuilder: (_) => [PopupMenuItem(value: 'edit', child: const UniversalText('Edit Product')), PopupMenuItem(value: 'feature', child: UniversalText(product.featured ? 'Remove Featured' : 'Make Featured')), const PopupMenuItem(value: 'delete', child: UniversalText('Delete Product'))]))),
              ]);
            }),
    );
  }

  Future<void> _editProduct(BuildContext context, ShopProduct product) async {
    final name = TextEditingController(text: product.name);
    final description = TextEditingController(text: product.description);
    final price = TextEditingController(text: product.price.toStringAsFixed(2));
    final inventory = TextEditingController(text: product.inventoryQuantity.toString());
    await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const UniversalText('Edit Product'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')), TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price')), TextField(controller: inventory, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Inventory'))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const UniversalText('Cancel')), FilledButton(onPressed: () { ShopCatalog.instance.updateProduct(product, name: name.text, description: description.text, price: double.tryParse(price.text), inventoryQuantity: int.tryParse(inventory.text)); Navigator.pop(context); }, child: const UniversalText('Save'))]));
    name.dispose(); description.dispose(); price.dispose(); inventory.dispose();
  }

  Widget _metric(String label, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const Spacer(), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), UniversalText(label)])));
}

/// Seller store settings and appearance editor.
class ShopStoreSettingsScreen extends StatefulWidget {
  final ShopStore store;
  const ShopStoreSettingsScreen({super.key, required this.store});
  @override
  State<ShopStoreSettingsScreen> createState() => _ShopStoreSettingsScreenState();
}

class _ShopStoreSettingsScreenState extends State<ShopStoreSettingsScreen> {
  late final TextEditingController name = TextEditingController(text: widget.store.name);
  late final TextEditingController description = TextEditingController(text: widget.store.description);
  late final TextEditingController logo = TextEditingController(text: widget.store.logoUrl ?? '');
  late final TextEditingController banner = TextEditingController(text: widget.store.bannerUrl ?? '');

  @override
  void dispose() { name.dispose(); description.dispose(); logo.dispose(); banner.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const UniversalText('Store Settings & Appearance')), body: ListView(padding: const EdgeInsets.all(18), children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Store name', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: description, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: logo, decoration: const InputDecoration(labelText: 'Logo URL', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: banner, decoration: const InputDecoration(labelText: 'Banner URL', border: OutlineInputBorder())), const SizedBox(height: 12), FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const UniversalText('Save Store Settings'))]));

  void _save() {
    ShopCatalog.instance.updateStore(
      widget.store,
      name: name.text,
      description: description.text,
      logoUrl: logo.text,
      bannerUrl: banner.text,
    );
    Navigator.pop(context);
  }
}

/// Seller product creation page.
class AddShopProductScreen extends StatefulWidget {
  final ShopStore store;
  const AddShopProductScreen({super.key, required this.store});
  @override
  State<AddShopProductScreen> createState() => _AddShopProductScreenState();
}

class _AssociationDraft {
  String type = 'movie';
  final TextEditingController name = TextEditingController();
  void dispose() => name.dispose();
}

class _AddShopProductScreenState extends State<AddShopProductScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final inventory = TextEditingController();
  final imageUrls = TextEditingController();
  final List<_AssociationDraft> associationDrafts = <_AssociationDraft>[_AssociationDraft()];
  String productType = 'Merchandise';
  String category = 'Other';
  bool featured = false;

  static const productTypes = ['Merchandise', 'Collectible / Game', 'Physical Media', 'Poster', 'Book', 'Clothing', 'Toy', 'Accessory', 'Home Item', 'Other'];
  static const categories = ['Movies', 'Shows', 'Music', 'Franchise', 'Clothing', 'Collectibles', 'Physical Media', 'Posters', 'Books', 'Toys', 'Accessories', 'Home', 'Other'];
  static const associationTypes = ['movie', 'show', 'franchise', 'song', 'artist', 'album', 'playlist', 'collection'];

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    inventory.dispose();
    imageUrls.dispose();
    for (final draft in associationDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const UniversalText('Add Product')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Product name', border: OutlineInputBorder())), const SizedBox(height: 10),
          TextField(controller: description, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())), const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: productType, decoration: const InputDecoration(labelText: 'Product type', border: OutlineInputBorder()), items: productTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => productType = v!)), const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()), items: categories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => category = v!)), const SizedBox(height: 10),
          TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (USD)', border: OutlineInputBorder())), const SizedBox(height: 10),
          TextField(controller: inventory, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Inventory', border: OutlineInputBorder())), const SizedBox(height: 10),
          TextField(controller: imageUrls, decoration: const InputDecoration(labelText: 'Product image URLs (comma separated)', border: OutlineInputBorder())), const SizedBox(height: 10),
          const Text('Media associations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 6),
          Text('Associate the product with every actual entertainment entity it belongs to. Example: a Puss in Boots: The Last Wish Blu-ray can be associated with the movie and the Shrek franchise.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .7))), const SizedBox(height: 8),
          for (var i = 0; i < associationDrafts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: DropdownButtonFormField<String>(initialValue: associationDrafts[i].type, decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()), items: associationTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) setState(() => associationDrafts[i].type = v); })),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextField(controller: associationDrafts[i].name, decoration: const InputDecoration(labelText: 'Entity name or ID', border: OutlineInputBorder()))),
                IconButton(onPressed: associationDrafts.length == 1 ? null : () { final draft = associationDrafts.removeAt(i); draft.dispose(); setState(() {}); }, icon: const Icon(Icons.remove_circle_outline)),
              ]),
            ),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => associationDrafts.add(_AssociationDraft())), icon: const Icon(Icons.add), label: const UniversalText('Add another association'))),
          SwitchListTile(value: featured, onChanged: (v) => setState(() => featured = v), title: const UniversalText('Featured product')),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const UniversalText('Create Product')),
        ]),
      );

  void _save() {
    final cleanName = name.text.trim();
    final p = double.tryParse(price.text.trim());
    final qty = int.tryParse(inventory.text.trim());
    if (cleanName.isEmpty || p == null || p < 0 || qty == null || qty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Enter a product name, valid price, and inventory quantity.')));
      return;
    }
    final associations = associationDrafts
        .map((draft) {
          final value = draft.name.text.trim();
          if (value.isEmpty) return null;
          return ShopAssociation(type: draft.type, id: value, name: value);
        })
        .whereType<ShopAssociation>()
        .toList();
    ShopCatalog.instance.createProduct(
      storeId: widget.store.id,
      name: cleanName,
      description: description.text,
      productType: productType,
      category: category,
      price: p,
      inventoryQuantity: qty,
      featured: featured,
      imageUrls: imageUrls.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      associations: associations,
    );
    Navigator.pop(context);
  }
}

/// Global bag containing products from any number of stores.
class ShopBagScreen extends StatelessWidget {
  const ShopBagScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = ShopCatalog.instance;
    return AnimatedBuilder(animation: catalog, builder: (_, __) {
      final lines = catalog.bag;
      final byStore = <String, List<ShopBagLine>>{};
      for (final line in lines) {
        final product = catalog.productById(line.productId);
        if (product == null) continue;
        byStore.putIfAbsent(product.storeId, () => <ShopBagLine>[]).add(line);
      }
      return Scaffold(
        appBar: AppBar(title: const UniversalText('Shopping Bag')),
        body: lines.isEmpty
            ? const Center(child: UniversalText('Your bag is empty.'))
            : ListView(padding: const EdgeInsets.all(18), children: [
                for (final entry in byStore.entries) ...[
                  Text(catalog.storeById(entry.key)?.name ?? 'Store', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  for (final line in entry.value) _bagLine(context, line),
                  const SizedBox(height: 8),
                ],
                Card(child: ListTile(title: const UniversalText('Bag total'), trailing: Text(_money(catalog.subtotal(), 'USD'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)))),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopCheckoutScreen(lines: List<ShopBagLine>.from(lines), title: 'Checkout • All Stores', storeSpecific: false))), icon: const Icon(Icons.lock_outline), label: const UniversalText('Checkout All Stores')),
              ]),
      );
    });
  }

  Widget _bagLine(BuildContext context, ShopBagLine line) {
    final catalog = ShopCatalog.instance;
    final product = catalog.productById(line.productId);
    if (product == null) return const SizedBox.shrink();
    return Card(child: ListTile(
      title: Text(product.name),
      subtitle: Text('${product.price.toStringAsFixed(2)} ${product.currency}'),
      trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        IconButton(onPressed: () => catalog.changeQuantity(product.id, -1), icon: const Icon(Icons.remove_circle_outline)),
        Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
        IconButton(onPressed: () => catalog.changeQuantity(product.id, 1), icon: const Icon(Icons.add_circle_outline)),
        IconButton(onPressed: () => catalog.removeFromBag(product.id), icon: const Icon(Icons.delete_outline)),
      ]),
    ));
  }

  static String _money(double value, String currency) => '${currency == 'USD' ? '\$' : currency} ${value.toStringAsFixed(2)}';
}

/// Wishlist page.
class ShopWishlistScreen extends StatelessWidget {
  const ShopWishlistScreen({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: ShopCatalog.instance, builder: (_, __) {
        final catalog = ShopCatalog.instance;
        final products = catalog.wishlistProductIds.map(catalog.productById).whereType<ShopProduct>().toList();
        return Scaffold(appBar: AppBar(title: const UniversalText('Shop Wishlist')), body: products.isEmpty ? const Center(child: UniversalText('Your Shop wishlist is empty.')) : ListView(padding: const EdgeInsets.all(18), children: [for (final p in products) Card(child: ListTile(title: Text(p.name), subtitle: Text('${p.price.toStringAsFixed(2)} ${p.currency}'), trailing: FilledButton(onPressed: p.inventoryQuantity <= 0 ? null : () => catalog.addToBag(p.id), child: const UniversalText('Add to Bag'))))]));
      });
}

/// Checkout screen used by both the single-store and all-store bag flows.
class ShopCheckoutScreen extends StatefulWidget {
  final List<ShopBagLine> lines;
  final String title;
  final bool storeSpecific;

  const ShopCheckoutScreen({super.key, required this.lines, required this.title, required this.storeSpecific});

  @override
  State<ShopCheckoutScreen> createState() => _ShopCheckoutScreenState();
}

class _ShopCheckoutScreenState extends State<ShopCheckoutScreen> {
  int paymentChoice = 0;
  final cardholder = TextEditingController();
  final cardNumber = TextEditingController();
  final expiry = TextEditingController();
  final cvv = TextEditingController();
  final postal = TextEditingController();
  WorldwideAddress? shippingAddress;
  bool processing = false;

  static const savedSubscriptionCard = ShopPaymentMethod(id: 'subscription_card', label: 'Card on file for your streaming subscription', subscriptionCard: true);

  @override
  void dispose() { cardholder.dispose(); cardNumber.dispose(); expiry.dispose(); cvv.dispose(); postal.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final catalog = ShopCatalog.instance;
    final total = catalog.subtotal(widget.lines);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.storeSpecific ? 'Store Checkout' : 'All Stores Checkout', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          UniversalText(widget.storeSpecific ? 'Only items from this store are included.' : 'Every item currently in your bag is included, grouped into one checkout.'),
          const SizedBox(height: 14),
          for (final line in widget.lines) _summaryLine(line),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const UniversalText('Total', style: TextStyle(fontWeight: FontWeight.w900)), Text(_money(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))]),
        ]))),
        const SizedBox(height: 14),
        const Text('Shipping / billing address', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        WorldwideAddressForm(
          requireStreet: true,
          onChanged: (value) => shippingAddress = value,
        ),
        const SizedBox(height: 14),
        const Text('Payment method', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        RadioGroup<int>(
          groupValue: paymentChoice,
          onChanged: (value) {
            if (processing || value == null) return;
            setState(() => paymentChoice = value);
          },
          child: Column(
            children: [
              RadioListTile<int>(
                value: 0,
                title: Text(savedSubscriptionCard.label),
                subtitle: const UniversalText('Use the payment method already associated with your streaming service.'),
              ),
              RadioListTile<int>(
                value: 1,
                title: const UniversalText('Use a different card'),
                subtitle: const UniversalText('Card details are used for this checkout and are not stored by this app.'),
              ),
            ],
          ),
        ),
        if (paymentChoice == 1) _newCardForm(),
        const SizedBox(height: 12),
        Card(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Padding(padding: EdgeInsets.all(14), child: UniversalText('Security: the current development gateway does not charge a real card. It returns a test transaction token. For production, connect this screen to a PCI-compliant payment processor that tokenizes the card before it reaches your backend.'))),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: processing ? null : () => _pay(total), icon: processing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.credit_card), label: UniversalText(processing ? 'Processing…' : 'Place Order & Pay')),
      ]),
    );
  }

  Widget _summaryLine(ShopBagLine line) {
    final product = ShopCatalog.instance.productById(line.productId);
    if (product == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: Text(product.name)), Text('× ${line.quantity}'), const SizedBox(width: 14), Text('${(product.price * line.quantity).toStringAsFixed(2)} ${product.currency}')]));
  }

  Widget _newCardForm() => Column(children: [
        TextField(controller: cardholder, decoration: const InputDecoration(labelText: 'Cardholder name', border: OutlineInputBorder())), const SizedBox(height: 10),
        TextField(controller: cardNumber, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: 'Card number', hintText: 'Enter card number securely', border: OutlineInputBorder())), const SizedBox(height: 10),
        Row(children: [Expanded(child: TextField(controller: expiry, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: 'MM/YY', border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(controller: cvv, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: 'CVV', border: OutlineInputBorder())))]), const SizedBox(height: 10),
        TextField(controller: postal, decoration: const InputDecoration(labelText: 'Billing postal code', border: OutlineInputBorder())),
      ]);

  Future<void> _pay(double total) async {
    if (widget.lines.isEmpty || total <= 0) return;
    if (shippingAddress == null || !shippingAddress!.isComplete || shippingAddress!.addressLine1.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Enter a complete shipping / billing address, including postal/ZIP code.')));
      return;
    }
    if (paymentChoice == 1) {
      final digits = cardNumber.text.replaceAll(RegExp(r'\D'), '');
      if (cardholder.text.trim().isEmpty || digits.length < 12 || cvv.text.trim().length < 3 || expiry.text.trim().isEmpty || postal.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Enter the required card and billing information.')));
        return;
      }
    }
    setState(() => processing = true);
    try {
      final result = await const ShopPaymentGateway().pay(
        amount: total,
        method: paymentChoice == 0 ? savedSubscriptionCard : ShopPaymentMethod(id: 'one_time_card', label: 'New card'),
        cardNumber: paymentChoice == 1 ? cardNumber.text : null,
      );
      if (!mounted) return;
      ShopCatalog.instance.recordOrder(lines: widget.lines, total: total, transactionId: result.transactionId);
      ShopCatalog.instance.completeCheckout(widget.lines);
      await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const UniversalText('Order placed'), content: UniversalText('Payment approved in development mode. Transaction: ${result.transactionId}${result.last4 == null ? '' : ' • Card ending ${result.last4}'}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const UniversalText('Done'))]));
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}

/// Compact bag icon used throughout Shop pages.
class _BagButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _BagButton({required this.onPressed});
  @override
  Widget build(BuildContext context) => Stack(children: [IconButton(tooltip: 'Shopping bag', onPressed: onPressed, icon: const Icon(Icons.shopping_bag_outlined)), if (ShopCatalog.instance.bagCount > 0) Positioned(right: 4, top: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(10)), child: Text('${ShopCatalog.instance.bagCount}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))))]);
}

/// Builds a Shop button for a specific entertainment entity.
class ContextualShopButton extends StatelessWidget {
  final String associationType;
  final String associationId;
  final String associationName;

  const ContextualShopButton({super.key, required this.associationType, required this.associationId, required this.associationName});

  @override
  Widget build(BuildContext context) {
    final hasProducts = ShopCatalog.instance.productsForAssociation(associationType, associationId, name: associationName).isNotEmpty;
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen(contextAssociationType: associationType, contextAssociationId: associationId, contextAssociationName: associationName))),
      icon: const Icon(Icons.storefront_outlined),
      label: UniversalText(hasProducts ? 'Shop Related Products' : 'Shop'),
    );
  }

  /// Convenience helper for media details.
  static Widget forMedia(BuildContext context, MediaItem media) => ContextualShopButton(associationType: (media.type.toLowerCase() == 'tvshow' || media.type.toLowerCase() == 'tv_show' || media.type.toLowerCase() == 'tv show') ? 'show' : 'movie', associationId: media.id, associationName: media.title);

  /// Convenience helper for music entities.
  static Widget forMusic({required String type, required String id, required String name}) => ContextualShopButton(associationType: type, associationId: id, associationName: name);

  /// Convenience helper for collections.
  static Widget forCollection(MediaCollection collection) => ContextualShopButton(associationType: 'collection', associationId: collection.id, associationName: collection.name);
}
