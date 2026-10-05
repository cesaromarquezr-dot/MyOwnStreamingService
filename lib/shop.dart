// FILE: lib/shop.dart
// Purpose: Implements the streaming service marketplace, seller tools, bag,
// wishlist, and the two checkout flows.
//
// Security note:
// Card numbers, CVV values, or full payment credentials are never stored by
// this Flutter model. A production payment provider should replace the
// development gateway with provider-side tokenization/hosted checkout.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'localization.dart';
import 'worldwide_location.dart';
import 'live_shopping.dart';
import 'page_presentation.dart';
import 'social_sharing.dart';

/// A globally searchable entity that a seller can associate with a product.
///
/// The same picker can represent movies, shows, artists, albums, songs,
/// playlists, collections, genres, franchises, actors and directors.
class ShopEntity {
  final String type;
  final String id;
  final String name;
  final String subtitle;
  final String? accountExternalId;

  const ShopEntity({
    required this.type,
    required this.id,
    required this.name,
    this.subtitle = '',
    this.accountExternalId,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'accountExternalId': accountExternalId,
        'isPublic': true,
      };

  factory ShopEntity.fromJson(Map<String, dynamic> json) => ShopEntity(
        type: json['type']?.toString() ?? 'other',
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        accountExternalId: json['accountExternalId']?.toString(),
      );
}

/// A media/entity relationship attached to a shop product.
class ShopAssociation {
  final String type;
  final String id;
  final String name;

  /// Identifies the source account for account-scoped entities such as a
  /// user's collection or playlist. Global media can leave this null.
  final String? sourceAccountId;

  const ShopAssociation({
    required this.type,
    required this.id,
    required this.name,
    this.sourceAccountId,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'name': name,
        'sourceAccountId': sourceAccountId,
      };

  factory ShopAssociation.fromJson(Map<String, dynamic> json) =>
      ShopAssociation(
        type: json['type']?.toString() ?? 'other',
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        sourceAccountId: json['sourceAccountId']?.toString(),
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
        price: json['price'] is num
            ? (json['price'] as num).toDouble()
            : double.tryParse(json['price']?.toString() ?? '') ?? 0,
        currency: json['currency']?.toString() ?? 'USD',
        inventoryQuantity: json['inventoryQuantity'] is num
            ? (json['inventoryQuantity'] as num).toInt()
            : int.tryParse(json['inventoryQuantity']?.toString() ?? '') ?? 0,
        featured: json['featured'] == true,
        active: json['active'] != false,
        imageUrls:
            (json['imageUrls'] as List?)?.map((e) => e.toString()).toList(),
        associations: (json['associations'] as List?)
            ?.whereType<Map>()
            .map((e) => ShopAssociation.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Theme and storefront presentation settings shared by the seller editor and
/// public store renderer. Values are serialized with the existing store record.
class StorefrontDesign extends PagePresentation {
  String sectionBackgrounds;
  String productLayout;
  int mobileColumns;
  int desktopColumns;
  String imageRatio;
  String heroTitle;
  String heroSubtitle;
  String heroCtaLabel;
  String heroCtaTarget;
  String mobileBannerUrl;
  String bannerPosition;
  double bannerOverlay;
  List<String> sectionOrder;

  StorefrontDesign({
    super.presetTheme = 'Indigo',
    super.brightnessMode = 'system',
    super.primaryColor = 0xFF536DFE,
    super.secondaryColor = 0xFFFFB74D,
    super.backgroundColor = 0xFFF6F7FB,
    super.gradientEndColor = 0xFFE8EAF6,
    super.backgroundType = 'solid',
    super.backgroundImageUrl = '',
    this.sectionBackgrounds = '',
    super.fontFamily = 'Default',
    super.fontScale = 1,
    super.buttonRadius = 14,
    super.cardRadius = 18,
    this.productLayout = 'list',
    this.mobileColumns = 1,
    this.desktopColumns = 3,
    this.imageRatio = 'Square',
    this.heroTitle = '',
    this.heroSubtitle = '',
    this.heroCtaLabel = '',
    this.heroCtaTarget = 'products',
    this.mobileBannerUrl = '',
    this.bannerPosition = 'center',
    this.bannerOverlay = 0.25,
    List<String>? sectionOrder,
  }) : sectionOrder = sectionOrder ?? <String>['About', 'Featured', 'Products'];

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'sectionBackgrounds': sectionBackgrounds,
        'productLayout': productLayout,
        'mobileColumns': mobileColumns,
        'desktopColumns': desktopColumns,
        'imageRatio': imageRatio,
        'heroTitle': heroTitle,
        'heroSubtitle': heroSubtitle,
        'heroCtaLabel': heroCtaLabel,
        'heroCtaTarget': heroCtaTarget,
        'mobileBannerUrl': mobileBannerUrl,
        'bannerPosition': bannerPosition,
        'bannerOverlay': bannerOverlay,
        'sectionOrder': sectionOrder,
      };

  factory StorefrontDesign.fromJson(Map<String, dynamic> json) =>
      StorefrontDesign(
        presetTheme: json['presetTheme']?.toString() ?? 'Indigo',
        brightnessMode: json['brightnessMode']?.toString() ?? 'system',
        primaryColor: _designInt(json['primaryColor'], 0xFF536DFE),
        secondaryColor: _designInt(json['secondaryColor'], 0xFFFFB74D),
        backgroundColor: _designInt(json['backgroundColor'], 0xFFF6F7FB),
        gradientEndColor: _designInt(json['gradientEndColor'], 0xFFE8EAF6),
        backgroundType: json['backgroundType']?.toString() ?? 'solid',
        backgroundImageUrl: json['backgroundImageUrl']?.toString() ?? '',
        sectionBackgrounds: json['sectionBackgrounds']?.toString() ?? '',
        fontFamily: json['fontFamily']?.toString() ?? 'Default',
        fontScale:
            _designDouble(json['fontScale'], 1).clamp(0.8, 1.4).toDouble(),
        buttonRadius:
            _designDouble(json['buttonRadius'], 14).clamp(0, 32).toDouble(),
        cardRadius:
            _designDouble(json['cardRadius'], 18).clamp(0, 36).toDouble(),
        productLayout: json['productLayout']?.toString() ?? 'list',
        mobileColumns: _designInt(json['mobileColumns'], 1).clamp(1, 2),
        desktopColumns: _designInt(json['desktopColumns'], 3).clamp(2, 5),
        imageRatio: json['imageRatio']?.toString() ?? 'Square',
        heroTitle: json['heroTitle']?.toString() ?? '',
        heroSubtitle: json['heroSubtitle']?.toString() ?? '',
        heroCtaLabel: json['heroCtaLabel']?.toString() ?? '',
        heroCtaTarget: json['heroCtaTarget']?.toString() ?? 'products',
        mobileBannerUrl: json['mobileBannerUrl']?.toString() ?? '',
        bannerPosition: json['bannerPosition']?.toString() ?? 'center',
        bannerOverlay:
            _designDouble(json['bannerOverlay'], 0.25).clamp(0, 0.8).toDouble(),
        sectionOrder:
            (json['sectionOrder'] as List?)?.map((e) => e.toString()).toList(),
      );
}

int _designInt(dynamic value, int fallback) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;
double _designDouble(dynamic value, double fallback) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? fallback;
const _storefrontColorChoices = <String, int>{
  'Indigo blue': 0xFF536DFE,
  'Blue': 0xFF1565C0,
  'Sky blue': 0xFF42A5F5,
  'Cyan': 0xFF00BCD4,
  'Teal': 0xFF00897B,
  'Green': 0xFF2E7D32,
  'Lime': 0xFF9E9D24,
  'Yellow': 0xFFFBC02D,
  'Gold': 0xFFD4AF37,
  'Amber': 0xFFFFB74D,
  'Orange': 0xFFEF6C00,
  'Red': 0xFFD32F2F,
  'Wine': 0xFF722F37,
  'Pink': 0xFFEC407A,
  'Fuchsia': 0xFFD000C5,
  'Purple': 0xFF7B1FA2,
  'Indigo': 0xFF3949AB,
  'Navy': 0xFF172554,
  'Beige': 0xFFD7C4A3,
  'Brown': 0xFF795548,
  'Silver': 0xFF9E9E9E,
  'Gray': 0xFF616161,
  'Black': 0xFF111111,
  'White': 0xFFF9FAFB,
  'Soft white': 0xFFF6F7FB,
  'Lavender mist': 0xFFE8EAF6,
};

ThemeData _storefrontTheme(BuildContext context, PagePresentation design) {
  final brightness = design.brightnessMode == 'dark'
      ? Brightness.dark
      : design.brightnessMode == 'light'
          ? Brightness.light
          : Theme.of(context).brightness;
  final scheme = ColorScheme.fromSeed(
          seedColor: Color(design.primaryColor), brightness: brightness)
      .copyWith(
    secondary: Color(design.secondaryColor),
    surface: brightness == Brightness.dark
        ? const Color(0xFF17191F)
        : Color(design.backgroundColor),
  );
  final family = design.fontFamily == 'Default' ? null : design.fontFamily;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: Color(design.backgroundColor),
    fontFamily: family,
    textTheme: Theme.of(context)
        .textTheme
        .apply(fontFamily: family, fontSizeFactor: design.fontScale),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(design.buttonRadius)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(design.buttonRadius)))),
    inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(design.buttonRadius))),
  );
}

Decoration _storefrontBackground(PagePresentation design) {
  if (design.backgroundType == 'image' &&
      design.backgroundImageUrl.startsWith('https://')) {
    return BoxDecoration(
        color: Color(design.backgroundColor),
        image: DecorationImage(
            image: NetworkImage(design.backgroundImageUrl), fit: BoxFit.cover));
  }
  if (design.backgroundType == 'gradient') {
    return BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
          Color(design.backgroundColor),
          Color(design.gradientEndColor)
        ]));
  }
  return BoxDecoration(color: Color(design.backgroundColor));
}

Alignment _bannerAlignment(String position) => switch (position) {
      'left' => Alignment.centerLeft,
      'right' => Alignment.centerRight,
      _ => Alignment.center,
    };

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
  StorefrontDesign design;

  ShopStore({
    required this.id,
    required this.ownerAccountId,
    required this.name,
    this.description = '',
    this.logoUrl,
    this.bannerUrl,
    this.active = true,
    this.address,
    StorefrontDesign? design,
  }) : design = design ?? StorefrontDesign();

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerAccountId': ownerAccountId,
        'name': name,
        'description': description,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'active': active,
        'address': address?.toJson(),
        'design': design.toJson(),
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
            ? WorldwideAddress.fromJson(
                Map<String, dynamic>.from(json['address'] as Map))
            : null,
        design: json['design'] is Map
            ? StorefrontDesign.fromJson(
                Map<String, dynamic>.from(json['design'] as Map))
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

  ShopOrder(
      {required this.id,
      required this.lines,
      required this.total,
      required this.transactionId,
      DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'lines': lines
            .map((l) => {'productId': l.productId, 'quantity': l.quantity})
            .toList(),
        'total': total,
        'transactionId': transactionId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ShopOrder.fromJson(Map<String, dynamic> json) => ShopOrder(
        id: json['id']?.toString() ?? '',
        lines: (json['lines'] as List?)?.whereType<Map>().map((item) {
              final map = Map<String, dynamic>.from(item);
              return ShopBagLine(
                  productId: map['productId']?.toString() ?? '',
                  quantity:
                      int.tryParse(map['quantity']?.toString() ?? '') ?? 1);
            }).toList() ??
            <ShopBagLine>[],
        total: json['total'] is num
            ? (json['total'] as num).toDouble()
            : double.tryParse(json['total']?.toString() ?? '') ?? 0,
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
  final List<String> savedForLaterProductIds = <String>[];
  final Set<String> compareProductIds = <String>{};
  final List<ShopBagLine> bag = <ShopBagLine>[];
  final List<ShopOrder> orders = <ShopOrder>[];
  final Map<String, ShopEntity> _externalEntities = <String, ShopEntity>{};
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
      final rawSavedForLater = _prefs!.getString('shop_saved_for_later');
      if (rawStores != null) {
        final decoded = jsonDecode(rawStores);
        if (decoded is List) {
          stores.addAll(decoded
              .whereType<Map>()
              .map((e) => ShopStore.fromJson(Map<String, dynamic>.from(e))));
        }
      }
      if (rawProducts != null) {
        final decoded = jsonDecode(rawProducts);
        if (decoded is List) {
          products.addAll(decoded
              .whereType<Map>()
              .map((e) => ShopProduct.fromJson(Map<String, dynamic>.from(e))));
        }
      }
      if (rawWishlist != null) {
        final decoded = jsonDecode(rawWishlist);
        if (decoded is List) {
          wishlistProductIds.addAll(decoded.map((e) => e.toString()));
        }
      }
      if (rawSavedForLater != null) {
        final decoded = jsonDecode(rawSavedForLater);
        if (decoded is List) {
          savedForLaterProductIds.addAll(decoded.map((e) => e.toString()));
        }
      }
      if (rawOrders != null) {
        final decoded = jsonDecode(rawOrders);
        if (decoded is List) {
          orders.addAll(decoded
              .whereType<Map>()
              .map((e) => ShopOrder.fromJson(Map<String, dynamic>.from(e))));
        }
      }
      if (rawBag != null) {
        final decoded = jsonDecode(rawBag);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            final map = Map<String, dynamic>.from(item);
            bag.add(ShopBagLine(
                productId: map['productId']?.toString() ?? '',
                quantity:
                    int.tryParse(map['quantity']?.toString() ?? '') ?? 1));
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
    await prefs.setString(
        'shop_stores', jsonEncode(stores.map((s) => s.toJson()).toList()));
    await prefs.setString(
        'shop_products', jsonEncode(products.map((p) => p.toJson()).toList()));
    await prefs.setString('shop_wishlist', jsonEncode(wishlistProductIds));
    await prefs.setString(
        'shop_saved_for_later', jsonEncode(savedForLaterProductIds));
    await prefs.setString(
        'shop_bag',
        jsonEncode(bag
            .map((line) =>
                {'productId': line.productId, 'quantity': line.quantity})
            .toList()));
    await prefs.setString('shop_orders',
        jsonEncode(orders.map((order) => order.toJson()).toList()));
  }

  /// Returns stores owned by the current account.
  List<ShopStore> get currentAccountStores {
    final accountId = AppController.instance.currentAccount?.id;
    if (accountId == null || accountId.isEmpty) return <ShopStore>[];
    return stores
        .where((s) => s.ownerAccountId == accountId && s.active)
        .toList();
  }

  bool get hasCurrentAccountStore => currentAccountStores.isNotEmpty;

  List<ShopProduct> productsForStore(String storeId) =>
      products.where((p) => p.storeId == storeId && p.active).toList();

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

  /// Registers entities supplied by music, playlist and other feature modules.
  /// The Shop association picker then treats them exactly like media entities.
  void registerExternalEntities(Iterable<ShopEntity> entities) {
    for (final entity in entities) {
      if (entity.id.trim().isEmpty || entity.name.trim().isEmpty) continue;
      _externalEntities['${entity.type}:${entity.id}'.toLowerCase()] = entity;
    }
    notifyListeners();
  }

  List<ShopEntity> get localShopEntities {
    final controller = AppController.instance;
    final result = <String, ShopEntity>{};

    void add(ShopEntity entity) {
      if (entity.id.trim().isEmpty || entity.name.trim().isEmpty) return;
      result['${entity.type}:${entity.id}'.toLowerCase()] = entity;
    }

    for (final media in controller.library) {
      final type = media.type.toLowerCase().contains('show') ||
              media.type.toLowerCase().contains('series')
          ? 'show'
          : 'movie';
      add(ShopEntity(
          type: type,
          id: media.id,
          name: media.title,
          subtitle:
              '${type == 'movie' ? 'Movie' : 'TV show'}${media.releaseYear == null ? '' : ' • ${media.releaseYear}'}'));
      if (media.franchiseId != null && media.franchiseName != null) {
        add(ShopEntity(
            type: 'franchise',
            id: media.franchiseId!,
            name: media.franchiseName!,
            subtitle: 'Franchise'));
      }
      for (final value in media.genres) {
        add(ShopEntity(
            type: 'genre',
            id: 'genre:${value.toLowerCase()}',
            name: value,
            subtitle: 'Genre'));
      }
      for (final value in media.tags) {
        add(ShopEntity(
            type: 'tag',
            id: 'tag:${value.toLowerCase()}',
            name: value,
            subtitle: 'Tag'));
      }
      for (final value in media.actors) {
        add(ShopEntity(
            type: 'actor',
            id: 'actor:${value.toLowerCase()}',
            name: value,
            subtitle: 'Actor'));
      }
      for (final value in media.directors) {
        add(ShopEntity(
            type: 'director',
            id: 'director:${value.toLowerCase()}',
            name: value,
            subtitle: 'Director'));
      }
      for (final value in media.music) {
        add(ShopEntity(
            type: 'artist',
            id: 'artist:${value.toLowerCase()}',
            name: value,
            subtitle: 'Artist / Music'));
      }
    }
    for (final collection in controller.collections) {
      add(ShopEntity(
        type: 'collection',
        id: collection.id,
        name: collection.name,
        subtitle: 'Collection',
      ));
    }
    result.addAll({
      for (final e in _externalEntities.values)
        '${e.type}:${e.id}'.toLowerCase(): e
    });
    return result.values.toList();
  }

  Future<List<ShopEntity>> searchAssociationEntities(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return <ShopEntity>[];
    final merged = <String, ShopEntity>{};
    for (final entity in localShopEntities) {
      if ('${entity.name} ${entity.type} ${entity.subtitle}'
          .toLowerCase()
          .contains(q)) {
        merged['${entity.type}:${entity.id}'.toLowerCase()] = entity;
      }
    }
    try {
      if (AppController.instance.backendApi.isAuthenticated) {
        final queries = <String>{query};
        if (query.endsWith('s') && query.length > 3) {
          queries.add(query.substring(0, query.length - 1));
        }
        for (final remoteQuery in queries) {
          final remote =
              await AppController.instance.backendApi.searchShopEntities(
            remoteQuery,
            50,
          );
          final rawEntities = remote['entities'];
          if (rawEntities is List) {
            for (final raw in rawEntities) {
              if (raw is! Map) continue;
              final entity = ShopEntity.fromJson(
                Map<String, dynamic>.from(raw),
              );
              if (entity.id.isNotEmpty && entity.name.isNotEmpty) {
                merged['${entity.type}:${entity.id}'.toLowerCase()] = entity;
              }
            }
          }
        }
      }
    } catch (_) {
      // Local entities remain usable when the global index is temporarily unavailable.
    }
    final values = merged.values.toList()
      ..sort((a, b) {
        final aa = a.name.toLowerCase();
        final bb = b.name.toLowerCase();
        final ar = aa == q
            ? 0
            : aa.startsWith(q)
                ? 1
                : 2;
        final br = bb == q
            ? 0
            : bb.startsWith(q)
                ? 1
                : 2;
        final rank = ar.compareTo(br);
        return rank != 0 ? rank : aa.compareTo(bb);
      });
    return values.take(50).toList();
  }

  Future<void> syncShopEntityIndex() async {
    if (!AppController.instance.backendApi.isAuthenticated) return;
    final entities = localShopEntities;
    if (entities.isEmpty) return;
    try {
      await AppController.instance.backendApi.syncShopEntities(
        entities.map((e) => e.toJson()).toList(),
      );
    } catch (_) {
      // Shop discovery must never block normal browsing.
    }
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
  void updateStore(ShopStore store,
      {String? name,
      String? description,
      String? logoUrl,
      String? bannerUrl,
      StorefrontDesign? design}) {
    final accountId = AppController.instance.currentAccount?.id;
    if (store.ownerAccountId != accountId) return;
    if (name != null && name.trim().isNotEmpty) store.name = name.trim();
    if (description != null) store.description = description.trim();
    store.logoUrl = logoUrl?.trim().isEmpty == true ? null : logoUrl?.trim();
    store.bannerUrl =
        bannerUrl?.trim().isEmpty == true ? null : bannerUrl?.trim();
    if (design != null) store.design = design;
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
  void updateProduct(ShopProduct product,
      {String? name,
      String? description,
      double? price,
      int? inventoryQuantity,
      bool? featured,
      bool? active}) {
    final accountId = AppController.instance.currentAccount?.id;
    final store = storeById(product.storeId);
    if (store == null || store.ownerAccountId != accountId) return;
    if (name != null && name.trim().isNotEmpty) product.name = name.trim();
    if (description != null) product.description = description.trim();
    if (price != null && price >= 0) product.price = price;
    if (inventoryQuantity != null && inventoryQuantity >= 0) {
      product.inventoryQuantity = inventoryQuantity;
    }
    if (featured != null) product.featured = featured;
    if (active != null) product.active = active;
    notifyListeners();
    _save();
  }

  /// Deletes a seller-owned product and removes it from wishlist/bag.
  void deleteProduct(String productId) {
    final product = productById(productId);
    final accountId = AppController.instance.currentAccount?.id;
    if (product == null ||
        storeById(product.storeId)?.ownerAccountId != accountId) {
      return;
    }
    products.remove(product);
    wishlistProductIds.remove(productId);
    bag.removeWhere((line) => line.productId == productId);
    notifyListeners();
    _save();
  }

  /// Returns products directly associated with an entertainment entity.
  List<ShopProduct> productsForAssociation(String type, String id,
      {String? name}) {
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

  /// Scores products against the current profile's library and media graph.
  /// Direct title/artist associations outrank broader genre/tag relationships.
  List<ShopProduct> personalizedProducts({int limit = 12}) {
    final controller = AppController.instance;
    final signals = <String, int>{};
    void signal(String value, int weight) {
      final clean = value.trim().toLowerCase();
      if (clean.isEmpty) return;
      signals[clean] = (signals[clean] ?? 0) + weight;
    }

    for (final media in controller.library) {
      signal(media.id, 100);
      signal(media.title, 100);
      signal(media.canonicalTitle ?? '', 90);
      signal(media.originalTitle ?? '', 70);
      signal(media.franchiseId ?? '', 90);
      signal(media.franchiseName ?? '', 90);
      for (final value in media.genres) {
        signal(value, 45);
      }
      for (final value in media.tags) {
        signal(value, 30);
      }
      for (final value in media.actors) {
        signal(value, 25);
      }
      for (final value in media.directors) {
        signal(value, 20);
      }
      for (final value in media.music) {
        signal(value, 35);
      }
    }
    for (final collection in controller.collections) {
      signal(collection.name, 60);
      signal(collection.description, 15);
    }
    for (final entity in _externalEntities.values) {
      signal(entity.name, 55);
      signal(entity.type, 8);
    }
    final scored = <({ShopProduct product, int score})>[];
    for (final product in products.where((p) => p.active)) {
      var score = product.featured ? 5 : 0;
      for (final association in product.associations) {
        final direct = signals[association.id.toLowerCase()] ?? 0;
        final named = signals[association.name.toLowerCase()] ?? 0;
        score += direct > named ? direct : named;
      }
      if (score > 0) scored.add((product: product, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((entry) => entry.product).toList();
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

  Widget _productImageForDialog(ShopProduct product, BuildContext context) {
    if (product.imageUrls.isEmpty) {
      return const Icon(Icons.shopping_bag_outlined);
    }
    final source = product.imageUrls.first;
    if (source.startsWith('data:image/')) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
              base64Decode(source.substring(source.indexOf(',') + 1)),
              width: 52,
              height: 52,
              fit: BoxFit.cover));
    }
    return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(source,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image_outlined)));
  }

  bool isWishlisted(String productId) => wishlistProductIds.contains(productId);

  void toggleCompare(String productId) {
    if (compareProductIds.contains(productId)) {
      compareProductIds.remove(productId);
    } else if (compareProductIds.length < 4) {
      compareProductIds.add(productId);
    }
    notifyListeners();
  }

  void saveForLater(String productId) {
    if (!savedForLaterProductIds.contains(productId)) {
      savedForLaterProductIds.add(productId);
    }
    bag.removeWhere((line) => line.productId == productId);
    notifyListeners();
    _save();
  }

  void moveSavedToBag(String productId) {
    savedForLaterProductIds.remove(productId);
    addToBag(productId);
    _save();
  }

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
    if (product == null || !product.active || product.inventoryQuantity <= 0) {
      return;
    }
    final existing = bag.where((line) => line.productId == productId).toList();
    if (existing.isEmpty) {
      bag.add(ShopBagLine(
          productId: productId,
          quantity: quantity.clamp(1, product.inventoryQuantity).toInt()));
    } else {
      existing.first.quantity = (existing.first.quantity + quantity)
          .clamp(1, product.inventoryQuantity)
          .toInt();
    }
    notifyListeners();
    _save();
  }

  void changeQuantity(String productId, int delta) {
    final line = bag.where((x) => x.productId == productId).isEmpty
        ? null
        : bag.where((x) => x.productId == productId).first;
    final product = productById(productId);
    if (line == null || product == null) return;
    line.quantity += delta;
    if (line.quantity <= 0) {
      bag.remove(line);
    } else {
      line.quantity =
          line.quantity.clamp(1, product.inventoryQuantity).toInt().toInt();
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
      .map((line) =>
          ShopBagLine(productId: line.productId, quantity: line.quantity))
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
  void recordOrder(
      {required Iterable<ShopBagLine> lines,
      required double total,
      required String transactionId}) {
    orders.insert(
        0,
        ShopOrder(
          id: 'order_${DateTime.now().microsecondsSinceEpoch}',
          lines: lines
              .map((line) => ShopBagLine(
                  productId: line.productId, quantity: line.quantity))
              .toList(),
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
        product.inventoryQuantity =
            (product.inventoryQuantity - purchased.quantity)
                .clamp(0, product.inventoryQuantity)
                .toInt();
      }
      final line = bag.where((x) => x.productId == purchased.productId).isEmpty
          ? null
          : bag.where((x) => x.productId == purchased.productId).first;
      if (line == null) continue;
      line.quantity -= purchased.quantity;
      if (line.quantity <= 0) bag.remove(line);
    }
    notifyListeners();
  }
}

/// Customer-facing product details page used by shop cards, social shares,
/// and live-shopping featured products.
class ShopProductDetailsScreen extends StatelessWidget {
  const ShopProductDetailsScreen({super.key, required this.product, this.onHome});

  final ShopProduct product;
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    final catalog = ShopCatalog.instance;
    final matchingStores = catalog.stores.where((item) => item.id == product.storeId);
    final store = matchingStores.isEmpty ? null : matchingStores.first;
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Product'),
        actions: [
          IconButton(
            tooltip: 'Share product',
            onPressed: () => showSocialShareDialog(
              context,
              title: product.name,
              message:
                  'Product: ${product.name} · ${product.price.toStringAsFixed(2)} ${product.currency}',
              mediaReference: {
                'type': 'product',
                'productId': product.id,
                'title': product.name,
                'description': product.description,
              },
            ),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Wishlist',
            onPressed: () => catalog.toggleWishlist(product.id),
            icon: Icon(
              catalog.isWishlisted(product.id)
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          if (product.imageUrls.isNotEmpty)
            SizedBox(
              height: MediaQuery.sizeOf(context).height * .38,
              child: PageView.builder(
                itemCount: product.imageUrls.length,
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    product.imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 54),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(Icons.shopping_bag_outlined, size: 64),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            product.name,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '${product.price.toStringAsFixed(2)} ${product.currency}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (store != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: store.logoUrl?.isNotEmpty == true
                      ? NetworkImage(store.logoUrl!)
                      : null,
                  child: store.logoUrl?.isNotEmpty == true
                      ? null
                      : Text(store.name.isEmpty ? '?' : store.name[0].toUpperCase()),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    store.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(product.category)),
              Chip(label: Text(product.productType)),
              Chip(
                avatar: Icon(
                  product.inventoryQuantity > 0
                      ? Icons.check_circle_outline
                      : Icons.remove_circle_outline,
                  size: 18,
                ),
                label: Text(
                  product.inventoryQuantity > 0
                      ? '${product.inventoryQuantity} in stock'
                      : 'Sold out',
                ),
              ),
            ],
          ),
          if (product.description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('About this product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(product.description, style: const TextStyle(height: 1.45)),
          ],
          if (product.associations.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Related to', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final association in product.associations)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link_outlined),
                title: Text(association.name),
                subtitle: Text(association.type),
              ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: product.inventoryQuantity <= 0
                      ? null
                      : () {
                          catalog.addToBag(product.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Added to bag')),
                          );
                        },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const UniversalText('Add to bag'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: product.inventoryQuantity <= 0
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShopCheckoutScreen(
                                lines: [ShopBagLine(productId: product.id)],
                                title: 'Checkout • ${product.name}',
                                storeSpecific: false,
                                onHome: onHome,
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.bolt_rounded),
                  label: const UniversalText('Buy now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
  String categoryFilter = 'All';
  String sortMode = 'Relevance';

  ShopCatalog get catalog => ShopCatalog.instance;

  @override
  void initState() {
    super.initState();
    catalog.syncShopEntityIndex();
  }

  List<ShopProduct> get visibleProducts {
    List<ShopProduct> result;
    if (widget.contextAssociationType != null &&
        widget.contextAssociationId != null) {
      result = catalog.productsForAssociation(
        widget.contextAssociationType!,
        widget.contextAssociationId!,
        name: widget.contextAssociationName,
      );
    } else {
      result = catalog.searchProducts(search);
    }
    if (categoryFilter != 'All') {
      result = result.where((p) => p.category == categoryFilter).toList();
    }
    if (sortMode == 'Price: low to high') {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (sortMode == 'Price: high to low') {
      result.sort((a, b) => b.price.compareTo(a.price));
    } else if (sortMode == 'Newest') {
      result = result.reversed.toList();
    }
    return result;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<ShopProduct> get featuredProducts =>
      catalog.products.where((p) => p.active && p.featured).take(8).toList();

  List<ShopProduct> get libraryRelatedProducts =>
      catalog.personalizedProducts(limit: 8);

  List<MediaItem> get mediaMatches {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return const <MediaItem>[];
    return AppController.instance.library
        .where((media) {
          final haystack = [
            media.title,
            media.franchiseName ?? '',
            media.originalTitle ?? '',
            media.canonicalTitle ?? '',
            ...media.genres,
            ...media.tags,
          ].join(' ').toLowerCase();
          return haystack.contains(q);
        })
        .take(12)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        catalog,
        PageContentCustomizationStore.revision,
      ]),
      builder: (context, _) {
        final products = visibleProducts;
        final visibleSections =
            PageContentCustomizationStore.settingsFor('shop').visibleSections;
        final stores = catalog.stores
            .where((s) =>
                s.active &&
                (search.isEmpty ||
                    s.name.toLowerCase().contains(search.toLowerCase()) ||
                    s.description.toLowerCase().contains(search.toLowerCase())))
            .toList();
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: UniversalText(widget.contextAssociationName == null
                ? 'Shop'
                : 'Shop • ${widget.contextAssociationName}'),
            actions: [
              IconButton(
                tooltip: 'Wishlist',
                icon: const Icon(Icons.favorite_border_rounded),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ShopWishlistScreen())),
              ),
              IconButton(
                tooltip: 'Compare selected products',
                onPressed: catalog.compareProductIds.isEmpty
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const ShopProductComparisonScreen())),
                icon: Badge(
                    label: Text('${catalog.compareProductIds.length}'),
                    child: const Icon(Icons.compare_arrows)),
              ),
              _BagButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ShopBagScreen(onHome: widget.onHome)))),
              const LanguagePicker(),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  Text(
                      widget.contextAssociationName == null
                          ? 'Marketplace'
                          : 'Related products',
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w900)),
                  if (widget.contextAssociationName == null)
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(
                          onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => const _AskShopAssistantDialog()),
                          icon: const Icon(Icons.auto_awesome),
                          label: const UniversalText('Ask Shop')),
                      if (!catalog.hasCurrentAccountStore)
                        OutlinedButton.icon(
                            onPressed: _createStore,
                            icon: const Icon(Icons.storefront_outlined),
                            label: const UniversalText('Create Store')),
                      if (catalog.currentAccountStores.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                name: '/app/page/seller-dashboard',
                              ),
                              builder: (_) => SellerDashboardScreen(
                                onHome: widget.onHome,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.dashboard_outlined),
                          label: const UniversalText('Seller Dashboard'),
                        ),
                      OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LiveShoppingScreen())),
                          icon: const Icon(Icons.live_tv_outlined),
                          label: const UniversalText('Live Shopping')),
                    ]),
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
                    suffixIcon: search.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              searchController.clear();
                              setState(() => search = '');
                            },
                            icon: const Icon(Icons.clear)),
                    border: const OutlineInputBorder(),
                  ),
                ),
              if (widget.contextAssociationName == null) ...[
                const SizedBox(height: 10),
                _shopCategoryRow(),
                for (final section in visibleSections)
                  if (section == 'featured' &&
                      search.isEmpty &&
                      featuredProducts.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(
                      'Featured Products',
                      Icons.star_outline_rounded,
                    ),
                    const SizedBox(height: 8),
                    for (final product in featuredProducts)
                      _productCard(context, product),
                  ] else if (section == 'related' &&
                      search.isEmpty &&
                      libraryRelatedProducts.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(
                      'Related to Your Library',
                      Icons.library_music_outlined,
                    ),
                    const SizedBox(height: 8),
                    for (final product in libraryRelatedProducts)
                      _productCard(context, product),
                  ] else if (section == 'stores') ...[
                    const SizedBox(height: 20),
                    _sectionTitle('Stores', Icons.storefront_outlined),
                    const SizedBox(height: 8),
                    if (stores.isEmpty)
                      _empty('No stores match this search yet.'),
                    for (final store in stores.take(8))
                      _storeTile(context, store),
                  ] else if (section == 'media' &&
                      search.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _sectionTitle('Media', Icons.movie_filter_outlined),
                    const SizedBox(height: 8),
                    if (mediaMatches.isEmpty)
                      _empty('No library media matches this search.'),
                    for (final media in mediaMatches)
                      Card(
                        child: ListTile(
                          title: Text(media.title),
                          subtitle: Text(media.franchiseName == null
                              ? media.type
                              : '${media.type} • ${media.franchiseName}'),
                          trailing:
                              ContextualShopButton.forMedia(context, media),
                        ),
                      ),
                  ],
              ],
              if (visibleSections.contains('products')) ...[
                const SizedBox(height: 20),
                _sectionTitle(
                  widget.contextAssociationName == null
                      ? 'Products'
                      : 'Shop this title',
                  Icons.shopping_bag_outlined,
                ),
                const SizedBox(height: 8),
                if (products.isEmpty)
                  _empty(widget.contextAssociationName == null
                      ? 'No real seller products are listed yet.'
                      : 'No seller product is currently associated with this title.'),
                for (final product in products) _productCard(context, product),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _shopCategoryRow() {
    const categories = <String>[
      'All',
      'Movies',
      'Shows',
      'Music',
      'Franchise',
      'Clothing',
      'Collectibles',
      'Physical Media',
      'Posters',
      'Books',
      'Toys',
      'Accessories',
      'Home',
    ];
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: categoryFilter == category,
                      onSelected: (_) =>
                          setState(() => categoryFilter = category),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: sortMode,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'Relevance', child: Text('Relevance')),
            DropdownMenuItem(value: 'Newest', child: Text('Newest')),
            DropdownMenuItem(
                value: 'Price: low to high', child: Text('Price ↑')),
            DropdownMenuItem(
                value: 'Price: high to low', child: Text('Price ↓')),
          ],
          onChanged: (value) => setState(() => sortMode = value ?? 'Relevance'),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(children: [
        Icon(icon),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))
      ]);

  Widget _empty(String text) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: UniversalText(text, textAlign: TextAlign.center)));

  Widget _storeTile(BuildContext context, ShopStore store) => Card(
        child: ListTile(
          leading: CircleAvatar(
              child: Text(store.name.isEmpty
                  ? '?'
                  : store.name.isEmpty
                      ? '?'
                      : store.name.substring(0, 1).toUpperCase())),
          title: Text(store.name),
          subtitle: Text(
              '${catalog.productsForStore(store.id).length} active product(s)${store.description.isEmpty ? '' : ' • ${store.description}'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Share store to chats',
                onPressed: () => showSocialShareDialog(
                  context,
                  title: store.name,
                  message: 'Store: ${store.name}',
                  mediaReference: {
                    'type': 'recommendation',
                    'title': store.name,
                    'description': store.description,
                    'mediaId': store.id,
                    'mediaType': 'store',
                  },
                ),
                icon: const Icon(Icons.share_outlined),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ShopStoreScreen(store: store, onHome: widget.onHome))),
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
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                      '${product.productType} • ${product.category} • ${store?.name ?? 'Store'}',
                      style: const TextStyle(fontSize: 12)),
                  if (product.associations.isNotEmpty)
                    Text(product.associations.map((a) => a.name).join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(_money(product.price, product.currency),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  Text('${product.inventoryQuantity} in stock',
                      style: const TextStyle(fontSize: 12)),
                ])),
            Column(children: [
              IconButton(
                  onPressed: () => catalog.toggleWishlist(product.id),
                  icon: Icon(catalog.isWishlisted(product.id)
                      ? Icons.favorite
                      : Icons.favorite_border)),
              IconButton(
                  tooltip: catalog.compareProductIds.contains(product.id)
                      ? 'Remove from comparison'
                      : 'Compare',
                  onPressed: () => catalog.toggleCompare(product.id),
                  icon: Icon(catalog.compareProductIds.contains(product.id)
                      ? Icons.check_box
                      : Icons.compare_arrows)),
              FilledButton(
                  onPressed: product.inventoryQuantity <= 0
                      ? null
                      : () => catalog.addToBag(product.id),
                  child: const UniversalText('Add to Bag')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _productImage(ShopProduct product, {double size = 80}) {
    if (product.imageUrls.isEmpty) {
      return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest),
          child: const Icon(Icons.shopping_bag_outlined));
    }
    final source = product.imageUrls.first;
    final image = source.startsWith('data:image/')
        ? Image.memory(base64Decode(source.substring(source.indexOf(',') + 1)),
            width: size, height: size, fit: BoxFit.cover)
        : Image.network(source,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                width: size,
                height: size,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined)));
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
  }

  Future<void> _createStore() async {
    final store = await showDialog<ShopStore>(
      context: context,
      builder: (_) => const _CreateStoreDialog(),
    );
    if (store == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/page/seller-dashboard'),
        builder: (_) => SellerDashboardScreen(
          store: store,
          onHome: widget.onHome,
        ),
      ),
    );
  }

  String _money(double value, String currency) =>
      '${currency == 'USD' ? '\$' : currency} ${value.toStringAsFixed(2)}';
}

class _CreateStoreDialog extends StatefulWidget {
  const _CreateStoreDialog();

  @override
  State<_CreateStoreDialog> createState() => _CreateStoreDialogState();
}

class _CreateStoreDialogState extends State<_CreateStoreDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _logo = TextEditingController();
  final _banner = TextEditingController();
  WorldwideAddress? _address;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _logo.dispose();
    _banner.dispose();
    super.dispose();
  }

  void _create() {
    final address = _address;
    if (address == null ||
        !address.isComplete ||
        address.addressLine1.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the complete store address, including country, city and postal/ZIP code.',
          ),
        ),
      );
      return;
    }

    final store = ShopCatalog.instance.createStore(
      name: _name.text,
      description: _description.text,
      logoUrl: _logo.text,
      bannerUrl: _banner.text,
      address: address,
    );
    Navigator.of(context).pop<ShopStore>(store);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const UniversalText('Create Store'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Store name'),
              ),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: _logo,
                decoration:
                    const InputDecoration(labelText: 'Logo URL (optional)'),
              ),
              TextField(
                controller: _banner,
                decoration:
                    const InputDecoration(labelText: 'Banner URL (optional)'),
              ),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: UniversalText(
                  'Store address',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              WorldwideAddressForm(
                requireStreet: true,
                onChanged: (value) => setState(() => _address = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: _create,
            child: const UniversalText('Create Store'),
          ),
        ],
      );
}

/// Target-inspired Shop assistant. It is deliberately transparent: the first
/// version uses the marketplace search/index rather than inventing product facts.
class _AskShopAssistantDialog extends StatefulWidget {
  const _AskShopAssistantDialog();
  @override
  State<_AskShopAssistantDialog> createState() =>
      _AskShopAssistantDialogState();
}

class _AskShopAssistantDialogState extends State<_AskShopAssistantDialog> {
  final controller = TextEditingController();
  bool loading = false;
  List<ShopProduct> results = <ShopProduct>[];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = controller.text.trim();
    if (question.isEmpty) return;
    setState(() => loading = true);
    final catalog = ShopCatalog.instance;
    final tokens = question
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((v) => v.length >= 2)
        .toSet();
    final budgetMatch =
        RegExp(r'(?:under|below|less than)\s*\$?\s*(\d+(?:\.\d+)?)')
            .firstMatch(question.toLowerCase());
    final budget =
        budgetMatch == null ? null : double.tryParse(budgetMatch.group(1)!);
    final scored = <({ShopProduct product, int score})>[];
    for (final product in catalog.products.where((p) => p.active)) {
      if (budget != null && product.price > budget) continue;
      final haystack = [
        product.name,
        product.description,
        product.category,
        product.productType,
        ...product.associations.map((a) => '${a.name} ${a.type}'),
      ].join(' ').toLowerCase();
      var score = 0;
      for (final token in tokens) {
        if (haystack.contains(token)) score += 10;
      }
      if (score > 0) scored.add((product: product, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    if (!mounted) return;
    setState(() {
      results = scored.take(8).map((e) => e.product).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.auto_awesome),
          SizedBox(width: 8),
          UniversalText('Ask Shop')
        ]),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const UniversalText(
                      'Ask naturally about products, media, artists, collections, genres or budgets.'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onSubmitted: (_) => _ask(),
                    decoration: const InputDecoration(
                      labelText: 'What are you looking for?',
                      hintText: 'KISS merchandise under 50 dollars',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [
                    for (final example in const [
                      'KISS merchandise',
                      'Marvel posters',
                      '80s music gifts',
                      'movies under 50'
                    ])
                      ActionChip(
                          label: Text(example),
                          onPressed: () {
                            controller.text = example;
                            _ask();
                          }),
                  ]),
                  const SizedBox(height: 14),
                  if (loading) const Center(child: CircularProgressIndicator()),
                  if (!loading &&
                      controller.text.trim().isNotEmpty &&
                      results.isEmpty)
                    const UniversalText(
                        'No matching products were found. Try an artist, movie, collection, genre, or a broader description.'),
                  for (final product in results)
                    Card(
                      child: ListTile(
                        leading: ShopCatalog.instance
                            ._productImageForDialog(product, context),
                        title: Text(product.name),
                        subtitle: Text(
                            '${product.category} • ${product.price.toStringAsFixed(2)} ${product.currency}'),
                        trailing: FilledButton(
                            onPressed: product.inventoryQuantity <= 0
                                ? null
                                : () {
                                    ShopCatalog.instance.addToBag(product.id);
                                    Navigator.pop(context);
                                  },
                            child: const UniversalText('Add')),
                      ),
                    ),
                ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const UniversalText('Close')),
          FilledButton.icon(
              onPressed: loading ? null : _ask,
              icon: const Icon(Icons.auto_awesome),
              label: const UniversalText('Ask'))
        ],
      );
}

/// Seller's storefront page.
class ShopStoreScreen extends StatelessWidget {
  final ShopStore store;
  final VoidCallback? onHome;
  final GlobalKey _productsSectionKey = GlobalKey();
  ShopStoreScreen({super.key, required this.store, this.onHome});

  @override
  Widget build(BuildContext context) {
    final catalog = ShopCatalog.instance;
    return AnimatedBuilder(
        animation: catalog,
        builder: (_, __) {
          final products = catalog.productsForStore(store.id);
          final lines = catalog.linesForStore(store.id);
          final design = store.design;
          final sections = <String, Widget>{
            if (store.description.isNotEmpty)
              'About': Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(store.description,
                      style: Theme.of(context).textTheme.bodyLarge)),
            if (products.any((p) => p.featured))
              'Featured': Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Featured',
                        style: TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    for (final product in products.where((p) => p.featured))
                      _productRow(context, product)
                  ]),
            'Products': Column(
                key: _productsSectionKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('All Products',
                      style:
                          TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (design.productLayout == 'grid')
                    _productGrid(context, products, design)
                  else
                    for (final product in products)
                      _productRow(context, product)
                ]),
          };
          final heroImageUrl = MediaQuery.sizeOf(context).width < 600 &&
                  design.mobileBannerUrl.isNotEmpty
              ? design.mobileBannerUrl
              : store.bannerUrl;
          return Theme(
              data: _storefrontTheme(context, design),
              child: Scaffold(
                appBar: AppBar(title: Text(store.name), actions: [
                  IconButton(
                    tooltip: 'Share store to chats',
                    onPressed: () => showSocialShareDialog(
                      context,
                      title: store.name,
                      message: 'Store: ${store.name}',
                      mediaReference: {
                        'type': 'recommendation',
                        'title': store.name,
                        'description': store.description,
                        'mediaId': store.id,
                        'mediaType': 'store',
                      },
                    ),
                    icon: const Icon(Icons.share_outlined),
                  ),
                  _BagButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ShopBagScreen(onHome: onHome)))),
                ]),
                body: Container(
                    decoration: _storefrontBackground(design),
                    child:
                        ListView(padding: const EdgeInsets.all(18), children: [
                      Container(
                          height: 190,
                          decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(design.cardRadius),
                              color: Color(design.backgroundColor),
                              gradient: design.backgroundType == 'gradient'
                                  ? LinearGradient(colors: [
                                      Color(design.backgroundColor),
                                      Color(design.gradientEndColor)
                                    ])
                                  : null,
                              image: heroImageUrl?.isNotEmpty == true
                                  ? DecorationImage(
                                      image: NetworkImage(heroImageUrl!),
                                      fit: BoxFit.cover,
                                      alignment: _bannerAlignment(
                                          design.bannerPosition),
                                      colorFilter: ColorFilter.mode(
                                          Colors.black.withValues(
                                              alpha: design.bannerOverlay),
                                          BlendMode.darken))
                                  : null),
                          child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (design.heroTitle.isNotEmpty)
                                          Text(design.heroTitle,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w900)),
                                        if (design.heroSubtitle.isNotEmpty)
                                          Text(design.heroSubtitle,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16)),
                                        if (design.heroCtaLabel.isNotEmpty)
                                          Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 8),
                                              child: FilledButton(
                                                  onPressed: () {
                                                    final target =
                                                        _productsSectionKey
                                                            .currentContext;
                                                    if (target != null) {
                                                      Scrollable.ensureVisible(
                                                          target,
                                                          duration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      350),
                                                          alignment: 0.08);
                                                    }
                                                  },
                                                  child: Text(
                                                      design.heroCtaLabel)))
                                      ])))),
                      const SizedBox(height: 14),
                      Row(children: [
                        CircleAvatar(
                            radius: 30,
                            backgroundImage: store.logoUrl?.isNotEmpty == true
                                ? NetworkImage(store.logoUrl!)
                                : null,
                            child: store.logoUrl?.isNotEmpty == true
                                ? null
                                : Text(store.name.isEmpty
                                    ? '?'
                                    : store.name
                                        .substring(0, 1)
                                        .toUpperCase())),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(store.name,
                                  style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900)),
                              if (store.description.isNotEmpty)
                                Text(store.description)
                            ]))
                      ]),
                      const SizedBox(height: 18),
                      if (lines.isNotEmpty)
                        FilledButton.icon(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ShopCheckoutScreen(
                                        lines: lines,
                                        title: 'Checkout • ${store.name}',
                                        storeSpecific: true,
                                        onHome: onHome))),
                            icon: const Icon(Icons.lock_outline),
                            label: const UniversalText('Checkout this Store')),
                      const SizedBox(height: 16),
                      for (final section in design.sectionOrder)
                        if (sections[section] != null)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: sections[section]!),
                    ])),
              ));
        });
  }

  Widget _productGrid(BuildContext context, List<ShopProduct> products,
      StorefrontDesign design) {
    final width = MediaQuery.sizeOf(context).width;
    final count = width < 600 ? design.mobileColumns : design.desktopColumns;
    return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: count,
        childAspectRatio: design.imageRatio == 'Portrait'
            ? 0.72
            : design.imageRatio == 'Landscape'
                ? 1.35
                : 0.92,
        children: [
          for (final product in products)
            Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(design.cardRadius)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: product.imageUrls.isEmpty
                              ? const Center(
                                  child: Icon(Icons.shopping_bag_outlined))
                              : Image.network(product.imageUrls.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image_outlined))),
                      Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    '${product.price.toStringAsFixed(2)} ${product.currency}'),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton(
                                        onPressed:
                                            product.inventoryQuantity <= 0
                                                ? null
                                                : () => ShopCatalog.instance
                                                    .addToBag(product.id),
                                        child: const Text('Add'),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Share product to chats',
                                      onPressed: () => showSocialShareDialog(
                                        context,
                                        title: product.name,
                                        message:
                                            'Product: ${product.name} · ${product.price.toStringAsFixed(2)} ${product.currency}',
                                        mediaReference: {
                                          'type': 'product',
                                          'title': product.name,
                                          'description': product.description,
                                          'productId': product.id,
                                        },
                                      ),
                                      icon: const Icon(Icons.share_outlined),
                                    ),
                                  ],
                                )
                              ]))
                    ])),
        ]);
  }

  Widget _productRow(BuildContext context, ShopProduct product) {
    final catalog = ShopCatalog.instance;
    return Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(store.design.cardRadius)),
        child: ListTile(
          leading: product.imageUrls.isEmpty
              ? const Icon(Icons.shopping_bag_outlined)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(product.imageUrls.first,
                      width: 52, height: 52, fit: BoxFit.cover)),
          title: Text(product.name),
          subtitle: Text(
              '${product.category} • ${product.price.toStringAsFixed(2)} ${product.currency} • ${product.inventoryQuantity} in stock'),
          trailing: Wrap(children: [
            IconButton(
                tooltip: 'Share product to chats',
                onPressed: () => showSocialShareDialog(
                      context,
                      title: product.name,
                      message:
                          'Product: ${product.name} · ${product.price.toStringAsFixed(2)} ${product.currency}',
                      mediaReference: {
                        'type': 'product',
                        'title': product.name,
                        'description': product.description,
                        'productId': product.id,
                      },
                    ),
                icon: const Icon(Icons.share_outlined)),
            IconButton(
                onPressed: () => catalog.toggleWishlist(product.id),
                icon: Icon(catalog.isWishlisted(product.id)
                    ? Icons.favorite
                    : Icons.favorite_border)),
            OutlinedButton(
                onPressed: product.inventoryQuantity <= 0
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ShopCheckoutScreen(
                                lines: [ShopBagLine(productId: product.id)],
                                title: 'Checkout • ${store.name}',
                                storeSpecific: true,
                                onHome: onHome))),
                child: const UniversalText('Buy Now')),
            const SizedBox(width: 6),
            FilledButton(
                onPressed: product.inventoryQuantity <= 0
                    ? null
                    : () => catalog.addToBag(product.id),
                child: const UniversalText('Add'))
          ]),
        ));
  }
}

/// Seller dashboard. It is surfaced in navigation only when a store exists.
class SellerDashboardScreen extends StatelessWidget {
  final ShopStore? store;
  final VoidCallback? onHome;
  const SellerDashboardScreen({super.key, this.store, this.onHome});

  @override
  Widget build(BuildContext context) {
    final catalog = ShopCatalog.instance;
    final stores = catalog.currentAccountStores;
    final activeStore = store ?? (stores.isEmpty ? null : stores.first);
    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const UniversalText('Seller Dashboard')),
      body: activeStore == null
          ? const Center(
              child: UniversalText('Create a store to become a seller.'))
          : AnimatedBuilder(
              animation: catalog,
              builder: (_, __) {
                final products = catalog.productsForStore(activeStore.id);
                final featured = products.where((p) => p.featured).length;
                final inventory = products.fold<int>(
                    0, (sum, p) => sum + p.inventoryQuantity);
                final storeOrders = catalog.orders
                    .where((o) => o.lines.any((line) =>
                        catalog.productById(line.productId)?.storeId ==
                        activeStore.id))
                    .toList();
                final salesByCurrency = <String, double>{};
                for (final order in storeOrders) {
                  for (final line in order.lines) {
                    final product = catalog.productById(line.productId);
                    if (product != null && product.storeId == activeStore.id) {
                      salesByCurrency[product.currency] =
                          (salesByCurrency[product.currency] ?? 0) +
                              product.price * line.quantity;
                    }
                  }
                }
                final salesLabel = salesByCurrency.isEmpty
                    ? '0'
                    : salesByCurrency.length == 1
                        ? '${salesByCurrency.values.single.toStringAsFixed(2)} ${salesByCurrency.keys.single}'
                        : '${salesByCurrency.length} currencies';
                return ListView(padding: const EdgeInsets.all(18), children: [
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.storefront),
                          title: Text(activeStore.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: UniversalText(activeStore
                                  .address?.summary ??
                              'Store settings, appearance and featured products'))),
                  GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount:
                          MediaQuery.sizeOf(context).width > 800 ? 4 : 2,
                      childAspectRatio: 1.8,
                      children: [
                        _metric('Products', '${products.length}',
                            Icons.inventory_2_outlined),
                        _metric('Featured', '$featured', Icons.star_outline),
                        _metric('Inventory', '$inventory',
                            Icons.warehouse_outlined),
                        _metric('Recorded sales', salesLabel,
                            Icons.payments_outlined),
                        _metric('Orders', '${storeOrders.length}',
                            Icons.receipt_long_outlined),
                      ]),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AddShopProductScreen(store: activeStore))),
                      icon: const Icon(Icons.add_box_outlined),
                      label: const UniversalText('Add Product')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ShopStoreScreen(
                                  store: activeStore, onHome: onHome))),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const UniversalText('View Store')),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.account_balance_wallet_outlined),
                      title: const UniversalText(
                          'Seller payment & payout methods'),
                      subtitle: const UniversalText(
                          'Manage accepted payment methods and where your seller earnings are paid.'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ShopStoreSettingsScreen(store: activeStore),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                      child: ListTile(
                    leading: const Icon(Icons.live_tv_outlined),
                    title:
                        const UniversalText('Live shopping & product videos'),
                    subtitle: const UniversalText(
                        'Schedule demonstrations, manage live events, feature products, polls, and replay links.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SellerLiveShoppingScreen(store: activeStore))),
                  )),
                  OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ShopStoreSettingsScreen(
                                  store: activeStore, designerOnly: true))),
                      icon: const Icon(Icons.palette_outlined),
                      label: const UniversalText('Storefront Designer')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ShopStoreSettingsScreen(store: activeStore))),
                      icon: const Icon(Icons.settings_outlined),
                      label: const UniversalText('Store Settings & Payouts')),
                  const SizedBox(height: 14),
                  const Text('Orders',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  for (final order in storeOrders.take(20))
                    Card(
                        child: ListTile(
                            title: Text(order.id),
                            subtitle: Text(
                                '${order.createdAt} • ${order.total.toStringAsFixed(2)} USD'),
                            trailing: const Icon(Icons.receipt_long_outlined))),
                  const SizedBox(height: 14),
                  const Text('Products',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  for (final product in products)
                    Card(
                        child: ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                                '${product.category} • ${product.price.toStringAsFixed(2)} ${product.currency} • ${product.inventoryQuantity} in stock'),
                            trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editProduct(context, product);
                                  } else if (value == 'delete') {
                                    catalog.deleteProduct(product.id);
                                  } else if (value == 'feature') {
                                    catalog.updateProduct(product,
                                        featured: !product.featured);
                                  }
                                },
                                itemBuilder: (_) => [
                                      PopupMenuItem(
                                          value: 'edit',
                                          child: const UniversalText(
                                              'Edit Product')),
                                      PopupMenuItem(
                                          value: 'feature',
                                          child: UniversalText(product.featured
                                              ? 'Remove Featured'
                                              : 'Make Featured')),
                                      const PopupMenuItem(
                                          value: 'delete',
                                          child:
                                              UniversalText('Delete Product'))
                                    ]))),
                ]);
              }),
    );
  }

  Future<void> _editProduct(BuildContext context, ShopProduct product) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditShopProductDialog(product: product),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon),
            const Spacer(),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            UniversalText(label)
          ])));
}

class _EditShopProductDialog extends StatefulWidget {
  final ShopProduct product;

  const _EditShopProductDialog({required this.product});

  @override
  State<_EditShopProductDialog> createState() => _EditShopProductDialogState();
}

class _EditShopProductDialogState extends State<_EditShopProductDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.product.name);
  late final TextEditingController _description =
      TextEditingController(text: widget.product.description);
  late final TextEditingController _price = TextEditingController(
    text: widget.product.price.toStringAsFixed(2),
  );
  late final TextEditingController _inventory = TextEditingController(
    text: widget.product.inventoryQuantity.toString(),
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _inventory.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const UniversalText('Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              TextField(
                controller: _inventory,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Inventory'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ShopCatalog.instance.updateProduct(
                widget.product,
                name: _name.text,
                description: _description.text,
                price: double.tryParse(_price.text),
                inventoryQuantity: int.tryParse(_inventory.text),
              );
              Navigator.of(context).pop();
            },
            child: const UniversalText('Save'),
          ),
        ],
      );
}

class _AddPayoutDestinationDialog extends StatefulWidget {
  const _AddPayoutDestinationDialog();

  @override
  State<_AddPayoutDestinationDialog> createState() =>
      _AddPayoutDestinationDialogState();
}

class _AddPayoutDestinationDialogState
    extends State<_AddPayoutDestinationDialog> {
  final _provider = TextEditingController();
  final _method = TextEditingController();
  final _display = TextEditingController();
  final _reference = TextEditingController();
  final _masked = TextEditingController();

  @override
  void dispose() {
    _provider.dispose();
    _method.dispose();
    _display.dispose();
    _reference.dispose();
    _masked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const UniversalText('Add Payout Method'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _provider,
                decoration: const InputDecoration(
                  labelText: 'Provider key',
                  hintText: 'paypal / mercado_pago / bank',
                ),
              ),
              TextField(
                controller: _method,
                decoration: const InputDecoration(
                  labelText: 'Method type',
                  hintText: 'wallet / bank_account',
                ),
              ),
              TextField(
                controller: _display,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'My PayPal',
                ),
              ),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                    labelText: 'Provider account reference'),
              ),
              TextField(
                controller: _masked,
                decoration: const InputDecoration(
                  labelText: 'Masked identifier',
                  hintText: 'email or ••••4821',
                ),
              ),
              const SizedBox(height: 8),
              const UniversalText(
                'Provider references are stored instead of raw financial credentials.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(<String>[
              _provider.text.trim(),
              _method.text.trim(),
              _display.text.trim(),
              _reference.text.trim(),
              _masked.text.trim(),
            ]),
            child: const UniversalText('Save'),
          ),
        ],
      );
}

/// Seller store settings and appearance editor.
class ShopStoreSettingsScreen extends StatefulWidget {
  final ShopStore store;
  final bool designerOnly;
  const ShopStoreSettingsScreen(
      {super.key, required this.store, this.designerOnly = false});
  @override
  State<ShopStoreSettingsScreen> createState() =>
      _ShopStoreSettingsScreenState();
}

class _ShopStoreSettingsScreenState extends State<ShopStoreSettingsScreen> {
  late final TextEditingController name =
      TextEditingController(text: widget.store.name);
  late final TextEditingController description =
      TextEditingController(text: widget.store.description);
  late final TextEditingController logo =
      TextEditingController(text: widget.store.logoUrl ?? '');
  late final TextEditingController banner =
      TextEditingController(text: widget.store.bannerUrl ?? '');
  late final TextEditingController paymentCountry =
      TextEditingController(text: widget.store.address?.countryCode ?? '');
  late final TextEditingController paymentCurrency =
      TextEditingController(text: 'USD');
  late final StorefrontDesign designDraft =
      StorefrontDesign.fromJson(widget.store.design.toJson());
  late final TextEditingController backgroundUrl =
      TextEditingController(text: widget.store.design.backgroundImageUrl);
  late final TextEditingController mobileBanner =
      TextEditingController(text: widget.store.design.mobileBannerUrl);
  late final TextEditingController heroTitle =
      TextEditingController(text: widget.store.design.heroTitle);
  late final TextEditingController heroSubtitle =
      TextEditingController(text: widget.store.design.heroSubtitle);
  late final TextEditingController heroCta =
      TextEditingController(text: widget.store.design.heroCtaLabel);

  bool loadingPaymentRegistry = true;
  bool savingPaymentMethods = false;
  List<Map<String, dynamic>> paymentRegistry = <Map<String, dynamic>>[];
  final Set<String> selectedPaymentMethodIds = <String>{};
  List<Map<String, dynamic>> payoutDestinations = <Map<String, dynamic>>[];
  bool loadingPayouts = true;
  bool savingPayout = false;

  @override
  void initState() {
    super.initState();
    if (!widget.designerOnly) {
      _loadSellerPaymentMethods();
      _loadPayoutDestinations();
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    logo.dispose();
    banner.dispose();
    paymentCountry.dispose();
    paymentCurrency.dispose();
    backgroundUrl.dispose();
    mobileBanner.dispose();
    heroTitle.dispose();
    heroSubtitle.dispose();
    heroCta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: UniversalText(widget.designerOnly
                ? 'Storefront Designer'
                : 'Store Settings & Appearance')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          if (!widget.designerOnly) ...[
            TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'Store name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: description,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder())),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 22),
          const Text('Storefront Designer',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const Text(
              'Preview changes on the public Store page after saving. Commerce behavior remains shared across storefront themes.'),
          const SizedBox(height: 12),
          TextField(
              controller: logo,
              decoration: const InputDecoration(
                  labelText: 'Store logo URL', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
              controller: banner,
              decoration: const InputDecoration(
                  labelText: 'Desktop hero/banner image URL',
                  border: OutlineInputBorder())),
          DropdownButtonFormField<String>(
              initialValue: designDraft.presetTheme,
              decoration: const InputDecoration(
                  labelText: 'Theme preset', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Indigo', child: Text('Indigo')),
                DropdownMenuItem(value: 'Ocean', child: Text('Ocean')),
                DropdownMenuItem(value: 'Forest', child: Text('Forest')),
                DropdownMenuItem(value: 'Sunset', child: Text('Sunset')),
                DropdownMenuItem(value: 'Custom', child: Text('Custom'))
              ],
              onChanged: (value) => _applyThemePreset(value)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
              initialValue: designDraft.brightnessMode,
              decoration: const InputDecoration(
                  labelText: 'Light / dark appearance',
                  border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'system', child: Text('Auto (follow device)')),
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'dark', child: Text('Dark'))
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => designDraft.brightnessMode = value);
                }
              }),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _colorPicker(
                    'Brand primary color',
                    designDraft.primaryColor,
                    (color) => designDraft.primaryColor = color)),
            const SizedBox(width: 8),
            Expanded(
                child: _colorPicker(
                    'Brand accent color',
                    designDraft.secondaryColor,
                    (color) => designDraft.secondaryColor = color)),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
              initialValue: designDraft.backgroundType,
              decoration: const InputDecoration(
                  labelText: 'Store background', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'solid', child: Text('Solid color')),
                DropdownMenuItem(value: 'gradient', child: Text('Gradient')),
                DropdownMenuItem(value: 'image', child: Text('Image'))
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => designDraft.backgroundType = value);
                }
              }),
          if (designDraft.backgroundType == 'solid' ||
              designDraft.backgroundType == 'gradient') ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _colorPicker(
                      'Background color',
                      designDraft.backgroundColor,
                      (color) => designDraft.backgroundColor = color)),
              if (designDraft.backgroundType == 'gradient') ...[
                const SizedBox(width: 8),
                Expanded(
                    child: _colorPicker(
                        'Gradient end',
                        designDraft.gradientEndColor,
                        (color) => designDraft.gradientEndColor = color)),
              ],
            ]),
          ],
          if (designDraft.backgroundType == 'image') ...[
            const SizedBox(height: 10),
            TextField(
                controller: backgroundUrl,
                decoration:
                    const InputDecoration(labelText: 'Background image URL'))
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: mobileBanner,
                    decoration: const InputDecoration(
                        labelText: 'Mobile hero image URL'))),
            const SizedBox(width: 8),
            Expanded(
                child: DropdownButtonFormField<String>(
                    initialValue: designDraft.bannerPosition,
                    decoration:
                        const InputDecoration(labelText: 'Hero image position'),
                    items: const [
                      DropdownMenuItem(value: 'left', child: Text('Left')),
                      DropdownMenuItem(value: 'center', child: Text('Center')),
                      DropdownMenuItem(value: 'right', child: Text('Right'))
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => designDraft.bannerPosition = value);
                      }
                    }))
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: heroTitle,
              decoration: const InputDecoration(labelText: 'Hero headline')),
          TextField(
              controller: heroSubtitle,
              decoration:
                  const InputDecoration(labelText: 'Hero supporting text')),
          TextField(
              controller: heroCta,
              decoration: const InputDecoration(
                  labelText: 'Hero call-to-action label')),
          const SizedBox(height: 8),
          Text(
              'Hero overlay strength: ${designDraft.bannerOverlay.toStringAsFixed(2)}'),
          Slider(
              value: designDraft.bannerOverlay,
              min: 0,
              max: 0.8,
              onChanged: (value) =>
                  setState(() => designDraft.bannerOverlay = value)),
          DropdownButtonFormField<String>(
              initialValue: designDraft.fontFamily,
              decoration: const InputDecoration(labelText: 'Typography'),
              items: const [
                DropdownMenuItem(value: 'Default', child: Text('System')),
                DropdownMenuItem(value: 'Serif', child: Text('Serif')),
                DropdownMenuItem(value: 'Monospace', child: Text('Monospace'))
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => designDraft.fontFamily = value);
                }
              }),
          Text('Text size: ${(designDraft.fontScale * 100).round()}%'),
          Slider(
              value: designDraft.fontScale,
              min: 0.8,
              max: 1.4,
              onChanged: (value) =>
                  setState(() => designDraft.fontScale = value)),
          Text('Button corner radius: ${designDraft.buttonRadius.round()}'),
          Slider(
              value: designDraft.buttonRadius,
              min: 0,
              max: 32,
              onChanged: (value) =>
                  setState(() => designDraft.buttonRadius = value)),
          Text('Card corner radius: ${designDraft.cardRadius.round()}'),
          Slider(
              value: designDraft.cardRadius,
              min: 0,
              max: 36,
              onChanged: (value) =>
                  setState(() => designDraft.cardRadius = value)),
          DropdownButtonFormField<String>(
              initialValue: designDraft.productLayout,
              decoration:
                  const InputDecoration(labelText: 'Product presentation'),
              items: const [
                DropdownMenuItem(value: 'list', child: Text('Compact list')),
                DropdownMenuItem(value: 'grid', child: Text('Product grid'))
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => designDraft.productLayout = value);
                }
              }),
          if (designDraft.productLayout == 'grid') ...[
            DropdownButtonFormField<int>(
                initialValue: designDraft.mobileColumns,
                decoration:
                    const InputDecoration(labelText: 'Mobile grid columns'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 column')),
                  DropdownMenuItem(value: 2, child: Text('2 columns'))
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => designDraft.mobileColumns = value);
                  }
                }),
            DropdownButtonFormField<int>(
                initialValue: designDraft.desktopColumns,
                decoration:
                    const InputDecoration(labelText: 'Desktop grid columns'),
                items: [
                  for (var i = 2; i <= 5; i++)
                    DropdownMenuItem(value: i, child: Text('$i columns'))
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => designDraft.desktopColumns = value);
                  }
                }),
          ],
          DropdownButtonFormField<String>(
              initialValue: designDraft.imageRatio,
              decoration:
                  const InputDecoration(labelText: 'Product image ratio'),
              items: const [
                DropdownMenuItem(value: 'Square', child: Text('Square')),
                DropdownMenuItem(value: 'Portrait', child: Text('Portrait')),
                DropdownMenuItem(value: 'Landscape', child: Text('Landscape'))
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => designDraft.imageRatio = value);
                }
              }),
          const SizedBox(height: 10),
          const Text('Store section order',
              style: TextStyle(fontWeight: FontWeight.bold)),
          for (var index = 0; index < designDraft.sectionOrder.length; index++)
            ListTile(
                dense: true,
                title: Text(designDraft.sectionOrder[index]),
                trailing: Wrap(children: [
                  IconButton(
                      onPressed: index == 0
                          ? null
                          : () => _moveSection(index, index - 1),
                      icon: const Icon(Icons.arrow_upward)),
                  IconButton(
                      onPressed: index == designDraft.sectionOrder.length - 1
                          ? null
                          : () => _moveSection(index, index + 1),
                      icon: const Icon(Icons.arrow_downward))
                ])),
          const SizedBox(height: 14),
          StorefrontDevicePreview(
              design: designDraft,
              storeName: name.text,
              products: ShopCatalog.instance.productsForStore(widget.store.id)),
          const SizedBox(height: 18),
          if (!widget.designerOnly) ...[
            const UniversalText('Seller payment & payout methods',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const UniversalText(
                'Choose any supported providers. The buyer checkout filters these methods by buyer country, currency, and provider eligibility. The registry is extensible; these entries are not the complete worldwide list.'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: paymentCountry,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'Seller country',
                          hintText: 'MX',
                          border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: paymentCurrency,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'Settlement currency',
                          hintText: 'USD',
                          border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 10),
            if (loadingPaymentRegistry)
              const LinearProgressIndicator()
            else
              ...paymentRegistry.map((method) {
                final id = method['id']?.toString() ?? '';
                return CheckboxListTile(
                  value: selectedPaymentMethodIds.contains(id),
                  onChanged: savingPaymentMethods
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              selectedPaymentMethodIds.add(id);
                            } else {
                              selectedPaymentMethodIds.remove(id);
                            }
                          });
                        },
                  title: Text(method['displayName']?.toString() ?? id),
                  subtitle: Text(method['methodType']?.toString() ?? 'payment'),
                );
              }),
            const SizedBox(height: 8),
            FilledButton.icon(
                onPressed: savingPaymentMethods ? null : _savePaymentMethods,
                icon: savingPaymentMethods
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.payments_outlined),
                label: UniversalText(savingPaymentMethods
                    ? 'Saving payment methods…'
                    : 'Save Payment Methods')),
            const SizedBox(height: 20),
            const UniversalText('Seller payout destinations',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const UniversalText(
                'Add where marketplace earnings should be paid. Use provider account references or masked identifiers; never enter bank passwords, card numbers, CVV, or equivalent secrets.'),
            const SizedBox(height: 10),
            if (loadingPayouts)
              const LinearProgressIndicator()
            else if (payoutDestinations.isEmpty)
              const Card(
                  child: ListTile(
                      title:
                          UniversalText('No payout destinations added yet.')))
            else
              for (final destination in payoutDestinations)
                Card(
                    child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(destination['displayName']?.toString() ??
                      destination['providerKey']?.toString() ??
                      'Payout destination'),
                  subtitle: Text(
                      '${destination['methodType'] ?? 'payout'}${destination['maskedIdentifier'] == null ? '' : ' • ${destination['maskedIdentifier']}'}${destination['verified'] == true ? ' • Verified' : ' • Pending verification'}'),
                  trailing: IconButton(
                    tooltip: 'Remove payout destination',
                    onPressed: savingPayout
                        ? null
                        : () => _deletePayoutDestination(
                            destination['id']?.toString() ?? ''),
                    icon: const Icon(Icons.delete_outline),
                  ),
                )),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: savingPayout ? null : _addPayoutDestination,
              icon: savingPayout
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_card_outlined),
              label: const UniversalText('Add Payout Method'),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: UniversalText(widget.designerOnly
                  ? 'Save Storefront Design'
                  : 'Save Store Settings')),
        ]),
      );

  Future<void> _loadSellerPaymentMethods() async {
    try {
      final api = AppController.instance.backendApi;
      final registry = await api.getPaymentMethodCatalog();
      final selected =
          await api.getAppRecords(recordType: 'seller_payment_method');
      if (!mounted) return;
      setState(() {
        paymentRegistry = registry;
        for (final record in selected) {
          final data = record['data'];
          if (data is Map && data['enabled'] != false) {
            selectedPaymentMethodIds
                .add(data['paymentMethodId']?.toString() ?? '');
          }
        }
        loadingPaymentRegistry = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingPaymentRegistry = false);
    }
  }

  Future<void> _loadPayoutDestinations() async {
    try {
      final values =
          await AppController.instance.backendApi.getSellerPayoutDestinations();
      if (mounted) {
        setState(() {
          payoutDestinations = values;
          loadingPayouts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadingPayouts = false);
    }
  }

  Future<void> _addPayoutDestination() async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _AddPayoutDestinationDialog(),
    );
    if (values == null ||
        values[0].isEmpty ||
        values[1].isEmpty ||
        values[2].isEmpty) {
      return;
    }
    setState(() => savingPayout = true);
    try {
      await AppController.instance.backendApi.saveSellerPayoutDestination(
        providerKey: values[0],
        methodType: values[1],
        displayName: values[2],
        providerAccountReference: values[3].isEmpty ? null : values[3],
        maskedIdentifier: values[4].isEmpty ? null : values[4],
      );
      await _loadPayoutDestinations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: UniversalText('Payout destination saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to save payout destination: $e')));
      }
    } finally {
      if (mounted) setState(() => savingPayout = false);
    }
  }

  Future<void> _deletePayoutDestination(String id) async {
    if (id.isEmpty) return;
    setState(() => savingPayout = true);
    try {
      await AppController.instance.backendApi.deleteSellerPayoutDestination(id);
      await _loadPayoutDestinations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to remove payout destination: $e')));
      }
    } finally {
      if (mounted) setState(() => savingPayout = false);
    }
  }

  Future<void> _savePaymentMethods() async {
    final country = paymentCountry.text.trim().toUpperCase();
    final currency = paymentCurrency.text.trim().toUpperCase();
    if (country.isEmpty || currency.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: UniversalText(
              'Enter the seller country and settlement currency first.')));
      return;
    }
    setState(() => savingPaymentMethods = true);
    try {
      for (final methodId
          in selectedPaymentMethodIds.where((id) => id.trim().isNotEmpty)) {
        await AppController.instance.backendApi.saveSellerPaymentMethod(
          paymentMethodId: methodId,
          countryCode: country,
          currencyCode: currency,
          verified: false,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: UniversalText(
                'Seller payment methods saved. Provider verification still occurs server-side.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to save payment methods: $e')));
      }
    } finally {
      if (mounted) setState(() => savingPaymentMethods = false);
    }
  }

  void _applyThemePreset(String? value) {
    if (value == null) return;
    const presets = <String, (int, int)>{
      'Indigo': (0xFF536DFE, 0xFFFFB74D),
      'Ocean': (0xFF007C91, 0xFF80CBC4),
      'Forest': (0xFF2E7D32, 0xFFAED581),
      'Sunset': (0xFFE65100, 0xFFFFCA28),
    };
    setState(() {
      designDraft.presetTheme = value;
      final colors = presets[value];
      if (colors != null) {
        designDraft.primaryColor = colors.$1;
        designDraft.secondaryColor = colors.$2;
      }
    });
  }

  Widget _colorPicker(
      String label, int selectedColor, void Function(int) apply) {
    Widget swatch(int color) => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Color(color),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26),
          ),
        );

    return DropdownButtonFormField<int>(
      initialValue: selectedColor,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        if (!_storefrontColorChoices.values.contains(selectedColor))
          DropdownMenuItem<int>(
            value: selectedColor,
            child: Row(children: [
              swatch(selectedColor),
              const SizedBox(width: 10),
              const Text('Saved custom color')
            ]),
          ),
        ..._storefrontColorChoices.entries.map((entry) => DropdownMenuItem<int>(
              value: entry.value,
              child: Row(children: [
                swatch(entry.value),
                const SizedBox(width: 10),
                Text(entry.key)
              ]),
            )),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          designDraft.presetTheme = 'Custom';
          apply(value);
        });
      },
    );
  }

  void _moveSection(int from, int to) {
    setState(() {
      final moved = designDraft.sectionOrder.removeAt(from);
      designDraft.sectionOrder.insert(to, moved);
    });
  }

  void _save() {
    designDraft.backgroundImageUrl = backgroundUrl.text.trim();
    designDraft.mobileBannerUrl = mobileBanner.text.trim();
    designDraft.heroTitle = heroTitle.text.trim();
    designDraft.heroSubtitle = heroSubtitle.text.trim();
    designDraft.heroCtaLabel = heroCta.text.trim();
    ShopCatalog.instance.updateStore(
      widget.store,
      name: name.text,
      description: description.text,
      logoUrl: logo.text,
      bannerUrl: banner.text,
      design: designDraft,
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

/// Global, multi-select association picker used by sellers.
class _ShopAssociationPicker extends StatefulWidget {
  final List<ShopAssociation> selected;
  final ValueChanged<ShopAssociation> onSelected;
  final ValueChanged<ShopAssociation> onRemoved;

  const _ShopAssociationPicker({
    required this.selected,
    required this.onSelected,
    required this.onRemoved,
  });

  @override
  State<_ShopAssociationPicker> createState() => _ShopAssociationPickerState();
}

class _ShopAssociationPickerState extends State<_ShopAssociationPicker> {
  final TextEditingController queryController = TextEditingController();
  List<ShopEntity> options = <ShopEntity>[];
  bool loading = false;
  int _requestId = 0;

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    final requestId = ++_requestId;
    if (query.length < 2) {
      if (mounted) {
        setState(() => options = <ShopEntity>[]);
      }
      return;
    }

    setState(() => loading = true);
    final found = await ShopCatalog.instance.searchAssociationEntities(query);
    if (!mounted || requestId != _requestId) return;

    final selectedKeys = widget.selected
        .map((association) =>
            '${association.type}:${association.id}'.toLowerCase())
        .toSet();

    setState(() {
      options = found
          .where((entity) => !selectedKeys
              .contains('${entity.type}:${entity.id}'.toLowerCase()))
          .toList();
      loading = false;
    });
  }

  void _select(ShopEntity entity) {
    widget.onSelected(
      ShopAssociation(
        type: entity.type,
        id: entity.id,
        name: entity.name,
        sourceAccountId: entity.accountExternalId,
      ),
    );
    queryController.clear();
    setState(() => options = <ShopEntity>[]);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: queryController,
            onChanged: _search,
            decoration: InputDecoration(
              labelText:
                  'Search movies, shows, songs, artists, albums, playlists, collections…',
              hintText: 'Taylor Swift, Marvel, Pop, Heavy Metal…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
          if (options.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 6),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final entity = options[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(_associationIcon(entity.type)),
                      ),
                      title: Text(
                        entity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        entity.subtitle.isEmpty
                            ? _associationLabel(entity.type)
                            : entity.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.add_circle_outline_rounded),
                      onTap: () => _select(entity),
                    );
                  },
                ),
              ),
            ),
          if (widget.selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final association in widget.selected)
                  InputChip(
                    avatar: Icon(
                      _associationIcon(association.type),
                      size: 17,
                    ),
                    label: Text(
                      '${association.name} • ${_associationLabel(association.type)}',
                    ),
                    onDeleted: () => widget.onRemoved(association),
                  ),
              ],
            ),
          ],
        ],
      );

  static IconData _associationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'movie':
        return Icons.movie_outlined;
      case 'show':
      case 'tv_show':
        return Icons.tv_outlined;
      case 'song':
        return Icons.music_note_outlined;
      case 'artist':
        return Icons.person_outline_rounded;
      case 'album':
        return Icons.album_outlined;
      case 'playlist':
        return Icons.queue_music_rounded;
      case 'collection':
        return Icons.collections_bookmark_outlined;
      case 'franchise':
        return Icons.account_tree_outlined;
      case 'actor':
        return Icons.people_outline_rounded;
      case 'director':
        return Icons.videocam_outlined;
      case 'genre':
        return Icons.category_outlined;
      default:
        return Icons.sell_outlined;
    }
  }

  static String _associationLabel(String type) => type
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _AddShopProductScreenState extends State<AddShopProductScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final inventory = TextEditingController();
  final List<String> imageDataUris = <String>[];
  final List<ShopAssociation> associations = <ShopAssociation>[];
  String productType = 'Merchandise';
  String category = 'Other';
  bool featured = false;
  bool importingImages = false;

  static const productTypes = [
    'Merchandise',
    'Collectible / Game',
    'Physical Media',
    'Poster',
    'Book',
    'Clothing',
    'Toy',
    'Accessory',
    'Home Item',
    'Other',
  ];

  static const categories = [
    'Movies',
    'Shows',
    'Music',
    'Franchise',
    'Clothing',
    'Collectibles',
    'Physical Media',
    'Posters',
    'Books',
    'Toys',
    'Accessories',
    'Home',
    'Other',
  ];

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    inventory.dispose();
    super.dispose();
  }

  Future<void> _importImages() async {
    setState(() => importingImages = true);
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(
        imageQuality: 88,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        final mime = file.mimeType ?? _mimeForName(file.name);
        imageDataUris.add('data:$mime;base64,${base64Encode(bytes)}');
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to import product image: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => importingImages = false);
    }
  }

  String _mimeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  void _removeAssociation(ShopAssociation association) {
    setState(() {
      associations.removeWhere(
        (value) => value.type == association.type && value.id == association.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const UniversalText('Add Product')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Product name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: productType,
              decoration: const InputDecoration(
                labelText: 'Product type',
                border: OutlineInputBorder(),
              ),
              items: productTypes
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => productType = value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => category = value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price (USD)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: inventory,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Inventory',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const UniversalText(
              'Product images',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const UniversalText(
              'Import images from the device instead of entering image URLs.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: importingImages ? null : _importImages,
              icon: importingImages
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_upload_outlined),
              label: UniversalText(
                importingImages ? 'Importing…' : 'Import Product Image(s)',
              ),
            ),
            if (imageDataUris.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageDataUris.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(
                            imageDataUris[index].substring(
                              imageDataUris[index].indexOf(',') + 1,
                            ),
                          ),
                          width: 108,
                          height: 108,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 3,
                        right: 3,
                        child: IconButton.filledTonal(
                          onPressed: () =>
                              setState(() => imageDataUris.removeAt(index)),
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Remove image',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const UniversalText(
              'Associated with',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const UniversalText(
              'Search the global media/entity index. You can select as many movies, shows, songs, artists, albums, playlists, collections, franchises, genres, actors or directors as apply to the product.',
            ),
            const SizedBox(height: 10),
            _ShopAssociationPicker(
              selected: associations,
              onSelected: (value) {
                setState(() {
                  if (!associations.any(
                    (association) =>
                        association.type == value.type &&
                        association.id == value.id,
                  )) {
                    associations.add(value);
                  }
                });
              },
              onRemoved: _removeAssociation,
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: featured,
              onChanged: (value) => setState(() => featured = value),
              title: const UniversalText('Featured product'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const UniversalText('Create Product'),
            ),
          ],
        ),
      );

  void _save() {
    final cleanName = name.text.trim();
    final parsedPrice = double.tryParse(price.text.trim());
    final quantity = int.tryParse(inventory.text.trim());
    if (cleanName.isEmpty ||
        parsedPrice == null ||
        parsedPrice < 0 ||
        quantity == null ||
        quantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: UniversalText(
            'Enter a product name, valid price, and inventory quantity.',
          ),
        ),
      );
      return;
    }

    ShopCatalog.instance.createProduct(
      storeId: widget.store.id,
      name: cleanName,
      description: description.text,
      productType: productType,
      category: category,
      price: parsedPrice,
      inventoryQuantity: quantity,
      featured: featured,
      imageUrls: imageDataUris,
      associations: associations,
    );
    Navigator.pop(context);
  }
}

class ShopBagScreen extends StatelessWidget {
  final VoidCallback? onHome;
  const ShopBagScreen({super.key, this.onHome});

  @override
  Widget build(BuildContext context) {
    final catalog = ShopCatalog.instance;
    return AnimatedBuilder(
        animation: catalog,
        builder: (_, __) {
          final lines = catalog.bag;
          final byStore = <String, List<ShopBagLine>>{};
          for (final line in lines) {
            final product = catalog.productById(line.productId);
            if (product == null) continue;
            byStore
                .putIfAbsent(product.storeId, () => <ShopBagLine>[])
                .add(line);
          }
          return Scaffold(
            appBar: AppBar(title: const UniversalText('Shopping Bag')),
            body: ListView(padding: const EdgeInsets.all(18), children: [
              if (lines.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Center(child: UniversalText('Your bag is empty.'))),
              if (lines.isNotEmpty) ...[
                for (final entry in byStore.entries) ...[
                  Text(catalog.storeById(entry.key)?.name ?? 'Store',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  for (final line in entry.value) _bagLine(context, line),
                  const SizedBox(height: 8),
                ],
                Card(
                    child: ListTile(
                        title: const UniversalText('Bag total'),
                        trailing: Text(_money(catalog.subtotal(), 'USD'),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900)))),
                const SizedBox(height: 10),
                FilledButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ShopCheckoutScreen(
                                lines: List<ShopBagLine>.from(lines),
                                title: 'Checkout • All Stores',
                                storeSpecific: false,
                                onHome: onHome))),
                    icon: const Icon(Icons.lock_outline),
                    label: const UniversalText('Checkout All Stores')),
              ],
              if (catalog.savedForLaterProductIds.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Text('Saved for later',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                for (final product in catalog.savedForLaterProductIds
                    .map(catalog.productById)
                    .whereType<ShopProduct>())
                  Card(
                      child: ListTile(
                          title: Text(product.name),
                          subtitle: Text(
                              '${product.price.toStringAsFixed(2)} ${product.currency}'),
                          trailing: TextButton(
                              onPressed: () =>
                                  catalog.moveSavedToBag(product.id),
                              child: const Text('Move to bag')))),
              ],
            ]),
          );
        });
  }

  Widget _bagLine(BuildContext context, ShopBagLine line) {
    final catalog = ShopCatalog.instance;
    final product = catalog.productById(line.productId);
    if (product == null) return const SizedBox.shrink();
    return Card(
        child: ListTile(
      title: Text(product.name),
      subtitle: Text('${product.price.toStringAsFixed(2)} ${product.currency}'),
      trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        IconButton(
            onPressed: () => catalog.changeQuantity(product.id, -1),
            icon: const Icon(Icons.remove_circle_outline)),
        Text('${line.quantity}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        IconButton(
            onPressed: () => catalog.changeQuantity(product.id, 1),
            icon: const Icon(Icons.add_circle_outline)),
        IconButton(
            tooltip: 'Save for later',
            onPressed: () => catalog.saveForLater(product.id),
            icon: const Icon(Icons.bookmark_add_outlined)),
        IconButton(
            onPressed: () => catalog.removeFromBag(product.id),
            icon: const Icon(Icons.delete_outline)),
      ]),
    ));
  }

  static String _money(double value, String currency) =>
      '${currency == 'USD' ? '\$' : currency} ${value.toStringAsFixed(2)}';
}

/// Side-by-side view of up to four products selected from marketplace cards.
class ShopProductComparisonScreen extends StatelessWidget {
  const ShopProductComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: ShopCatalog.instance,
        builder: (context, _) {
          final catalog = ShopCatalog.instance;
          final products = catalog.compareProductIds
              .map(catalog.productById)
              .whereType<ShopProduct>()
              .toList();
          return Scaffold(
              appBar: AppBar(title: const Text('Compare products')),
              body: products.isEmpty
                  ? const Center(
                      child: Text(
                          'Select products from the marketplace to compare them.'))
                  : ListView(padding: const EdgeInsets.all(16), children: [
                      for (final product in products)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(product.name,
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        IconButton(
                                            onPressed: () => catalog
                                                .toggleCompare(product.id),
                                            icon: const Icon(Icons.close))
                                      ]),
                                      Text(
                                          '${product.price.toStringAsFixed(2)} ${product.currency}'),
                                      Text('Category: ${product.category}'),
                                      Text('Type: ${product.productType}'),
                                      Text(
                                          'Availability: ${product.inventoryQuantity > 0 ? '${product.inventoryQuantity} in stock' : 'Out of stock'}'),
                                      Text(
                                          'Store: ${catalog.storeById(product.storeId)?.name ?? 'Store'}'),
                                      if (product.description.isNotEmpty)
                                        Text(product.description),
                                      if (product.associations.isNotEmpty)
                                        Text(
                                            'Related: ${product.associations.map((a) => a.name).join(', ')}'),
                                      Align(
                                          alignment: Alignment.centerRight,
                                          child: FilledButton(
                                              onPressed:
                                                  product.inventoryQuantity <= 0
                                                      ? null
                                                      : () => catalog
                                                          .addToBag(product.id),
                                              child: const Text('Add to bag'))),
                                    ]))),
                    ]));
        },
      );
}

/// Wishlist page.
class ShopWishlistScreen extends StatelessWidget {
  const ShopWishlistScreen({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: ShopCatalog.instance,
      builder: (_, __) {
        final catalog = ShopCatalog.instance;
        final products = catalog.wishlistProductIds
            .map(catalog.productById)
            .whereType<ShopProduct>()
            .toList();
        return Scaffold(
            appBar: AppBar(title: const UniversalText('Shop Wishlist')),
            body: products.isEmpty
                ? const Center(
                    child: UniversalText('Your Shop wishlist is empty.'))
                : ListView(padding: const EdgeInsets.all(18), children: [
                    for (final p in products)
                      Card(
                          child: ListTile(
                              title: Text(p.name),
                              subtitle: Text(
                                  '${p.price.toStringAsFixed(2)} ${p.currency}'),
                              trailing: FilledButton(
                                  onPressed: p.inventoryQuantity <= 0
                                      ? null
                                      : () => catalog.addToBag(p.id),
                                  child: const UniversalText('Add to Bag'))))
                  ]));
      });
}

/// Checkout screen used by both the single-store and all-store bag flows.
class ShopCheckoutScreen extends StatefulWidget {
  final List<ShopBagLine> lines;
  final String title;
  final bool storeSpecific;
  final VoidCallback? onHome;

  const ShopCheckoutScreen(
      {super.key,
      required this.lines,
      required this.title,
      required this.storeSpecific,
      this.onHome});

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
  bool addressConfirmed = false;
  bool processing = false;
  bool loadingPaymentMethods = false;
  List<Map<String, dynamic>> compatiblePaymentMethods =
      <Map<String, dynamic>>[];
  String? selectedProviderMethodId;

  static const savedSubscriptionCard = ShopPaymentMethod(
      id: 'subscription_card',
      label: 'Card on file for your streaming subscription',
      subscriptionCard: true);

  @override
  void dispose() {
    cardholder.dispose();
    cardNumber.dispose();
    expiry.dispose();
    cvv.dispose();
    postal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ShopCatalog.instance;
    final subtotal = catalog.subtotal(widget.lines);
    final storeCount = widget.lines
        .map((line) => catalog.productById(line.productId)?.storeId)
        .whereType<String>()
        .toSet()
        .length;
    final shippingFee = storeCount * 5.99;
    final serviceFee = subtotal * 0.05;
    final total = subtotal + shippingFee + serviceFee;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        if (!addressConfirmed) ...[
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Delivery address',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        const UniversalText(
                            'Enter where you want your order delivered. We’ll show the full order total and payment options next.'),
                      ]))),
          const SizedBox(height: 14),
          WorldwideAddressForm(
            requireStreet: true,
            onChanged: (value) {
              setState(() => shippingAddress = value);
              _refreshCompatiblePaymentMethods(value);
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _continueToPayment,
                icon: const Icon(Icons.arrow_forward),
                label: const UniversalText('Continue to payment'),
              )),
        ] else ...[
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: processing
                    ? null
                    : () => setState(() => addressConfirmed = false),
                icon: const Icon(Icons.arrow_back),
                label: const UniversalText('Edit address'),
              )),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            widget.storeSpecific
                                ? 'Store Checkout'
                                : 'All Stores Checkout',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        UniversalText(widget.storeSpecific
                            ? 'Only items from this store are included.'
                            : 'Every item currently in your bag is included, grouped into one checkout.'),
                        const SizedBox(height: 14),
                        for (final line in widget.lines) _summaryLine(line),
                        const Divider(),
                        _feeRow('Items subtotal', subtotal),
                        const SizedBox(height: 6),
                        _feeRow(r'Shipping ($5.99 per store estimate)',
                            shippingFee),
                        const SizedBox(height: 6),
                        _feeRow('Service fee (5%)', serviceFee),
                        const Divider(height: 24),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const UniversalText('Total',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                              Text(_money(total),
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900))
                            ]),
                      ]))),
          const SizedBox(height: 14),
          const Text('Payment method',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          _paymentProviderOptions(),
          const SizedBox(height: 8),
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
                  subtitle: const UniversalText(
                      'Use the payment method already associated with your streaming service.'),
                ),
                RadioListTile<int>(
                  value: 1,
                  title: const UniversalText('Choose another payment option'),
                  subtitle: const UniversalText(
                      'Select a card, wallet, or regional payment provider below.'),
                ),
              ],
            ),
          ),
          if (paymentChoice == 1 &&
              (selectedProviderMethodId == null ||
                  selectedProviderMethodId == 'card_processor'))
            _newCardForm(),
          if (paymentChoice == 1 &&
              selectedProviderMethodId != null &&
              selectedProviderMethodId != 'card_processor')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: UniversalText(
                    'The selected provider will use its own secure checkout/authorization flow. Sensitive wallet or bank credentials are never collected into this app database.'),
              ),
            ),
          const SizedBox(height: 12),
          Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: UniversalText(
                      'Security: the current development gateway does not charge a real card. It returns a test transaction token. For production, connect this screen to a PCI-compliant payment processor or hosted wallet/bank checkout that tokenizes or authorizes credentials before they reach your backend.'))),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: processing ? null : () => _pay(total),
              icon: processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.credit_card),
              label: UniversalText(
                  processing ? 'Processing…' : 'Place Order & Pay')),
        ],
      ]),
    );
  }

  Widget _feeRow(String label, double amount) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(_money(amount))],
      );

  void _continueToPayment() {
    final address = shippingAddress;
    if (address == null ||
        !address.isComplete ||
        address.addressLine1.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: UniversalText(
            'Enter a complete delivery address, including postal/ZIP code.'),
      ));
      return;
    }
    setState(() => addressConfirmed = true);
  }

  Widget _paymentProviderOptions() {
    if (loadingPaymentMethods) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: LinearProgressIndicator(),
      );
    }
    if (compatiblePaymentMethods.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: UniversalText(
              'Enter your billing/shipping country to see payment providers compatible with both you and the seller(s).'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const UniversalText('Available payment providers',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const UniversalText(
                'Providers vary by country, currency, seller configuration, and provider eligibility. Unsupported regional methods are filtered out automatically.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: compatiblePaymentMethods.map((method) {
                final id = method['id']?.toString() ?? '';
                final label = method['displayName']?.toString() ??
                    method['provider']?.toString() ??
                    id;
                final selected = selectedProviderMethodId == id;
                return ChoiceChip(
                  avatar: Icon(_paymentMethodIcon(id), size: 18),
                  label: Text(label),
                  selected: selected,
                  onSelected: processing
                      ? null
                      : (value) {
                          if (!value) return;
                          setState(() {
                            selectedProviderMethodId = id;
                            paymentChoice = 1;
                          });
                        },
                  labelStyle: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _paymentMethodIcon(String id) {
    switch (id.toLowerCase()) {
      case 'paypal':
        return Icons.account_balance_wallet_outlined;
      case 'apple_pay':
      case 'google_pay':
      case 'card':
      case 'credit_card':
        return Icons.credit_card_outlined;
      case 'mercado_pago':
        return Icons.shopping_bag_outlined;
      case 'bank_transfer':
      case 'pix':
      case 'ideal':
        return Icons.account_balance_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  Future<void> _refreshCompatiblePaymentMethods(
      WorldwideAddress? address) async {
    final country = address?.countryCode.trim().toUpperCase();
    if (country == null || country.isEmpty) {
      if (mounted) {
        setState(() {
          compatiblePaymentMethods = <Map<String, dynamic>>[];
          selectedProviderMethodId = null;
        });
      }
      return;
    }
    final sellerIds = widget.lines
        .map((line) => ShopCatalog.instance.productById(line.productId))
        .whereType<ShopProduct>()
        .map((product) =>
            ShopCatalog.instance.storeById(product.storeId)?.ownerAccountId ??
            '')
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    if (sellerIds.isEmpty) return;
    setState(() => loadingPaymentMethods = true);
    try {
      final currency = widget.lines
          .map((line) => ShopCatalog.instance.productById(line.productId))
          .whereType<ShopProduct>()
          .map((p) => p.currency.trim().toUpperCase())
          .where((c) => c.isNotEmpty)
          .toSet();
      final settlementCurrency = currency.length == 1 ? currency.first : 'USD';
      List<Map<String, dynamic>>? intersection;
      for (final sellerId in sellerIds) {
        final methods = await AppController.instance.backendApi
            .filterPaymentMethodsForBuyer(
          sellerAccountId: sellerId,
          buyerCountryCode: country,
          currencyCode: settlementCurrency,
        );
        if (intersection == null) {
          intersection = methods;
        } else {
          final ids = methods
              .map((m) => m['id']?.toString())
              .whereType<String>()
              .toSet();
          intersection = intersection
              .where((m) => ids.contains(m['id']?.toString()))
              .toList();
        }
      }
      final values = intersection ?? <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        compatiblePaymentMethods = values;
        if (selectedProviderMethodId == null ||
            !values
                .any((m) => m['id']?.toString() == selectedProviderMethodId)) {
          selectedProviderMethodId =
              values.isEmpty ? null : values.first['id']?.toString();
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Unable to load compatible payment methods: $error')));
        setState(() => compatiblePaymentMethods = <Map<String, dynamic>>[]);
      }
    } finally {
      if (mounted) setState(() => loadingPaymentMethods = false);
    }
  }

  Widget _summaryLine(ShopBagLine line) {
    final product = ShopCatalog.instance.productById(line.productId);
    if (product == null) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: Text(product.name)),
          Text('× ${line.quantity}'),
          const SizedBox(width: 14),
          Text(
              '${(product.price * line.quantity).toStringAsFixed(2)} ${product.currency}')
        ]));
  }

  Widget _newCardForm() => Column(children: [
        TextField(
            controller: cardholder,
            decoration: const InputDecoration(
                labelText: 'Cardholder name', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(
            controller: cardNumber,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Card number',
                hintText: 'Enter card number securely',
                border: OutlineInputBorder())),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: expiry,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                      labelText: 'MM/YY', border: OutlineInputBorder()))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: cvv,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'CVV', border: OutlineInputBorder())))
        ]),
        const SizedBox(height: 10),
        TextField(
            controller: postal,
            decoration: const InputDecoration(
                labelText: 'Billing postal code',
                border: OutlineInputBorder())),
      ]);

  Future<void> _pay(double total) async {
    if (widget.lines.isEmpty || total <= 0) return;
    if (shippingAddress == null ||
        !shippingAddress!.isComplete ||
        shippingAddress!.addressLine1.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: UniversalText(
              'Enter a complete shipping / billing address, including postal/ZIP code.')));
      return;
    }
    if (paymentChoice == 1 &&
        (selectedProviderMethodId == null ||
            selectedProviderMethodId == 'card_processor')) {
      final digits = cardNumber.text.replaceAll(RegExp(r'\D'), '');
      if (cardholder.text.trim().isEmpty ||
          digits.length < 12 ||
          cvv.text.trim().length < 3 ||
          expiry.text.trim().isEmpty ||
          postal.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: UniversalText(
                'Enter the required card and billing information.')));
        return;
      }
    }
    setState(() => processing = true);
    try {
      final result = await const ShopPaymentGateway().pay(
        amount: total,
        method: paymentChoice == 0
            ? savedSubscriptionCard
            : ShopPaymentMethod(
                id: selectedProviderMethodId ?? 'one_time_card',
                label: compatiblePaymentMethods
                        .firstWhere(
                          (m) =>
                              m['id']?.toString() == selectedProviderMethodId,
                          orElse: () => const <String, dynamic>{},
                        )['displayName']
                        ?.toString() ??
                    'Selected payment method',
              ),
        cardNumber: paymentChoice == 1 &&
                (selectedProviderMethodId == null ||
                    selectedProviderMethodId == 'card_processor')
            ? cardNumber.text
            : null,
      );
      if (!mounted) return;
      ShopCatalog.instance.recordOrder(
          lines: widget.lines,
          total: total,
          transactionId: result.transactionId);
      ShopCatalog.instance.completeCheckout(widget.lines);
      await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
                  title: const UniversalText('Order placed'),
                  content: UniversalText(
                      'Payment approved in development mode. Transaction: ${result.transactionId}${result.last4 == null ? '' : ' • Card ending ${result.last4}'}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const UniversalText('Done'))
                  ]));
      if (mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        final onHome = widget.onHome;
        navigator.pop();
        if (onHome != null) {
          onHome();
        } else {
          navigator.popUntil(
            (route) => route.settings.name == '/main' || route.isFirst,
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', ''))));
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
  Widget build(BuildContext context) => Stack(children: [
        IconButton(
            tooltip: 'Shopping bag',
            onPressed: onPressed,
            icon: const Icon(Icons.shopping_bag_outlined)),
        if (ShopCatalog.instance.bagCount > 0)
          Positioned(
              right: 4,
              top: 4,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${ShopCatalog.instance.bagCount}',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w900))))
      ]);
}

/// Builds a Shop button for a specific entertainment entity.
class ContextualShopButton extends StatelessWidget {
  final String associationType;
  final String associationId;
  final String associationName;

  const ContextualShopButton(
      {super.key,
      required this.associationType,
      required this.associationId,
      required this.associationName});

  @override
  Widget build(BuildContext context) {
    final hasProducts = ShopCatalog.instance
        .productsForAssociation(associationType, associationId,
            name: associationName)
        .isNotEmpty;
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/app/shop'),
          builder: (_) => ShopScreen(
            contextAssociationType: associationType,
            contextAssociationId: associationId,
            contextAssociationName: associationName,
          ),
        ),
      ),
      icon: const Icon(Icons.storefront_outlined),
      label: UniversalText(hasProducts ? 'Shop Related Products' : 'Shop'),
    );
  }

  /// Convenience helper for media details.
  static Widget forMedia(BuildContext context, MediaItem media) =>
      ContextualShopButton(
          associationType: (media.type.toLowerCase() == 'tvshow' ||
                  media.type.toLowerCase() == 'tv_show' ||
                  media.type.toLowerCase() == 'tv show')
              ? 'show'
              : 'movie',
          associationId: media.id,
          associationName: media.title);

  /// Convenience helper for music entities.
  static Widget forMusic(
          {required String type, required String id, required String name}) =>
      ContextualShopButton(
          associationType: type, associationId: id, associationName: name);

  /// Convenience helper for collections.
  static Widget forCollection(MediaCollection collection) =>
      ContextualShopButton(
          associationType: 'collection',
          associationId: collection.id,
          associationName: collection.name);
}

/// Reusable storefront device preview used by Storefront Designer.
class StorefrontDevicePreview extends StatefulWidget {
  final StorefrontDesign design;
  final String storeName;
  final List<ShopProduct> products;

  const StorefrontDevicePreview({
    super.key,
    required this.design,
    required this.storeName,
    required this.products,
  });

  @override
  State<StorefrontDevicePreview> createState() =>
      _StorefrontDevicePreviewState();
}

class _StorefrontDevicePreviewState extends State<StorefrontDevicePreview> {
  String device = 'Phone';
  bool landscape = false;

  @override
  Widget build(BuildContext context) {
    final size = switch (device) {
      'Phone' => landscape ? const Size(844, 390) : const Size(390, 844),
      'Tablet' => landscape ? const Size(1024, 768) : const Size(768, 1024),
      'Desktop' => const Size(1100, 680),
      _ => const Size(1280, 720),
    };

    final previewWidth = size.width.clamp(260.0, 1100.0).toDouble();
    final previewHeight = size.height.clamp(300.0, 620.0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Preview',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in const ['Phone', 'Tablet', 'Desktop', 'TV'])
                  ChoiceChip(
                    label: Text(value),
                    selected: device == value,
                    onSelected: (_) => setState(() => device = value),
                  ),
                if (device == 'Phone' || device == 'Tablet')
                  FilterChip(
                    label: const Text('Landscape'),
                    selected: landscape,
                    onSelected: (value) => setState(() => landscape = value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: previewWidth,
                height: previewHeight,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(width: 4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _preview(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preview frame: $device${(device == 'Phone' || device == 'Tablet') && landscape ? ' • Landscape' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    final isPhone = device == 'Phone';
    final int columns = isPhone
        ? widget.design.mobileColumns.clamp(1, 3).toInt()
        : widget.design.desktopColumns.clamp(2, 5).toInt();

    return Container(
      decoration: BoxDecoration(
        color: Color(widget.design.backgroundColor),
      ),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            widget.storeName.isEmpty ? 'Store' : widget.storeName,
            style: TextStyle(
              fontSize: isPhone ? 22 : 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: isPhone ? 100 : 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.design.cardRadius),
              color: Color(widget.design.primaryColor),
            ),
            padding: const EdgeInsets.all(14),
            alignment: Alignment.bottomLeft,
            child: Text(
              widget.design.heroTitle.isEmpty
                  ? 'Storefront Preview'
                  : widget.design.heroTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (widget.design.heroSubtitle.isNotEmpty)
            Text(widget.design.heroSubtitle, maxLines: 2),
          const SizedBox(height: 14),
          if (widget.design.productLayout == 'grid')
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              childAspectRatio: .85,
              children: [
                for (final product in widget.products.take(6))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: product.imageUrls.isEmpty
                                ? const Center(
                                    child: Icon(Icons.shopping_bag_outlined),
                                  )
                                : Image.network(
                                    product.imageUrls.first,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${product.price.toStringAsFixed(2)} ${product.currency}',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          else
            Column(
              children: [
                for (final product in widget.products.take(4))
                  ListTile(
                    title: Text(product.name),
                    subtitle: Text(
                      '${product.price.toStringAsFixed(2)} ${product.currency}',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
