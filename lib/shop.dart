// FILE: lib/shop.dart
// Purpose: Implements the streaming service marketplace, seller tools, bag,
// wishlist, and the two checkout flows.
//
// Security note:
// Card numbers, CVV values, or full payment credentials are never stored by
// this Flutter model. A production payment provider should replace the
// development gateway with provider-side tokenization/hosted checkout.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'localization.dart';

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
  bool customizable;
  bool allowColorSelection;
  List<String> availableColors;
  bool allowSizeSelection;
  List<String> availableSizes;
  bool allowCustomText;
  bool allowCustomImage;

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
    this.customizable = false,
    this.allowColorSelection = false,
    List<String>? availableColors,
    this.allowSizeSelection = false,
    List<String>? availableSizes,
    this.allowCustomText = false,
    this.allowCustomImage = false,
  })  : imageUrls = imageUrls ?? <String>[],
        associations = associations ?? <ShopAssociation>[],
        availableColors = availableColors ?? <String>[],
        availableSizes = availableSizes ?? <String>[];

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
        'customizable': customizable,
        'allowColorSelection': allowColorSelection,
        'availableColors': availableColors,
        'allowSizeSelection': allowSizeSelection,
        'availableSizes': availableSizes,
        'allowCustomText': allowCustomText,
        'allowCustomImage': allowCustomImage,
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
        customizable: json['customizable'] == true,
        allowColorSelection: json['allowColorSelection'] == true,
        availableColors: (json['availableColors'] as List?)?.map((e) => e.toString()).toList(),
        allowSizeSelection: json['allowSizeSelection'] == true,
        availableSizes: (json['availableSizes'] as List?)?.map((e) => e.toString()).toList(),
        allowCustomText: json['allowCustomText'] == true,
        allowCustomImage: json['allowCustomImage'] == true,
      );
}

/// Payment methods a seller can enable for marketplace checkout.
enum ShopPaymentOption {
  subscriptionCard,
  newCard,
  applePay,
  googlePay,
  paypal,
  shopPay,
}


/// Shipping carriers a seller can enable for marketplace orders.
enum ShopShippingCarrier {
  usps,
  dhl,
  jtExpress,
  correosDeMexico,
  ups,
  fedex,
  estafeta,
}

extension ShopShippingCarrierX on ShopShippingCarrier {
  String get label => switch (this) {
    ShopShippingCarrier.usps => 'USPS',
    ShopShippingCarrier.dhl => 'DHL',
    ShopShippingCarrier.jtExpress => 'J&T Express',
    ShopShippingCarrier.correosDeMexico => 'Correos de México',
    ShopShippingCarrier.ups => 'UPS',
    ShopShippingCarrier.fedex => 'FedEx',
    ShopShippingCarrier.estafeta => 'Estafeta',
  };
}

/// Buyer or seller shipping address used for delivery-rate calculation.
class ShopShippingAddress {
  final String country;
  final String stateProvince;
  final String city;
  final String postalCode;
  final String address;

  const ShopShippingAddress({
    required this.country,
    required this.stateProvince,
    required this.city,
    required this.postalCode,
    required this.address,
  });

  bool get isComplete => country.trim().isNotEmpty &&
      stateProvince.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      postalCode.trim().isNotEmpty &&
      address.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'country': country,
    'stateProvince': stateProvince,
    'city': city,
    'postalCode': postalCode,
    'address': address,
  };

  factory ShopShippingAddress.fromJson(Map<String, dynamic> json) => ShopShippingAddress(
    country: json['country']?.toString() ?? '',
    stateProvince: json['stateProvince']?.toString() ?? '',
    city: json['city']?.toString() ?? '',
    postalCode: json['postalCode']?.toString() ?? '',
    address: json['address']?.toString() ?? '',
  );
}

/// A carrier quote. Production should replace the development calculator with
/// live carrier APIs and verified seller/package information.
class ShopShippingQuote {
  final ShopShippingCarrier carrier;
  final double amount;
  final String currency;

  const ShopShippingQuote({required this.carrier, required this.amount, required this.currency});
}

/// Development shipping-rate calculator used until live carrier accounts/API
/// credentials are connected. It always chooses the cheapest enabled carrier.
class ShopShippingCalculator {
  static List<ShopShippingQuote> quotes({
    required ShopStore store,
    required ShopShippingAddress destination,
    required int itemCount,
  }) {
    if (!destination.isComplete || store.policy.shippingCarriers.isEmpty) return const [];
    final origin = store.policy.shippingOrigin;
    if (!origin.isComplete) return const [];

    final sameCountry = origin.country.trim().toLowerCase() == destination.country.trim().toLowerCase();
    final base = sameCountry ? 8.0 : 18.0;
    final distanceFactor = sameCountry
        ? ((origin.stateProvince.trim().toLowerCase() == destination.stateProvince.trim().toLowerCase()) ? 0.0 : 4.0)
        : 12.0;
    final quantityFactor = (itemCount.clamp(1, 20) - 1) * 1.25;
    final multipliers = <ShopShippingCarrier, double>{
      ShopShippingCarrier.usps: 1.00,
      ShopShippingCarrier.dhl: 1.18,
      ShopShippingCarrier.jtExpress: 0.92,
      ShopShippingCarrier.correosDeMexico: 0.88,
      ShopShippingCarrier.ups: 1.10,
      ShopShippingCarrier.fedex: 1.12,
      ShopShippingCarrier.estafeta: 0.95,
    };
    return store.policy.shippingCarriers.map((carrier) {
      final amount = (base + distanceFactor + quantityFactor) * (multipliers[carrier] ?? 1.0);
      return ShopShippingQuote(carrier: carrier, amount: double.parse(amount.toStringAsFixed(2)), currency: 'USD');
    }).toList()..sort((a, b) => a.amount.compareTo(b.amount));
  }
}

extension ShopPaymentOptionX on ShopPaymentOption {
  String get label {
    switch (this) {
      case ShopPaymentOption.subscriptionCard: return 'Card on file';
      case ShopPaymentOption.newCard: return 'Credit / debit card';
      case ShopPaymentOption.applePay: return 'Apple Pay';
      case ShopPaymentOption.googlePay: return 'Google Pay';
      case ShopPaymentOption.paypal: return 'PayPal';
      case ShopPaymentOption.shopPay: return 'Shop Pay';
    }
  }

  String get id => name;
}

/// Promotion types a seller can publish for their store.
enum ShopPromotionType { buyXGetY, couponPercent }

extension ShopPromotionTypeX on ShopPromotionType {
  String get label => this == ShopPromotionType.buyXGetY ? 'Buy X, get Y free' : 'Coupon percentage';
}

/// A seller-created promotion. Promotions are evaluated at checkout and never
/// alter the original product price.
class ShopPromotion {
  final String id;
  ShopPromotionType type;
  bool active;
  int buyQuantity;
  int freeQuantity;
  String code;
  double percentOff;
  String description;

  ShopPromotion({
    required this.id,
    required this.type,
    this.active = true,
    this.buyQuantity = 3,
    this.freeQuantity = 1,
    this.code = '',
    this.percentOff = 10,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type.name, 'active': active,
    'buyQuantity': buyQuantity, 'freeQuantity': freeQuantity,
    'code': code, 'percentOff': percentOff, 'description': description,
  };

  factory ShopPromotion.fromJson(Map<String, dynamic> json) => ShopPromotion(
    id: json['id']?.toString() ?? '',
    type: ShopPromotionType.values.firstWhere((v) => v.name == json['type']?.toString(), orElse: () => ShopPromotionType.couponPercent),
    active: json['active'] != false,
    buyQuantity: int.tryParse(json['buyQuantity']?.toString() ?? '') ?? 3,
    freeQuantity: int.tryParse(json['freeQuantity']?.toString() ?? '') ?? 1,
    code: json['code']?.toString() ?? '',
    percentOff: double.tryParse(json['percentOff']?.toString() ?? '') ?? 10,
    description: json['description']?.toString() ?? '',
  );
}

/// Seller-configurable marketplace payment, fee, shipping, and payout policy.
class ShopStorePolicy {
  final Set<ShopPaymentOption> enabledPaymentOptions;
  final Set<ShopShippingCarrier> shippingCarriers;
  ShopShippingAddress shippingOrigin;
  double platformCommissionPercent;
  double defaultShippingCost;
  final List<ShopPromotion> promotions;

  ShopStorePolicy({
    Set<ShopPaymentOption>? enabledPaymentOptions,
    Set<ShopShippingCarrier>? shippingCarriers,
    ShopShippingAddress? shippingOrigin,
    this.platformCommissionPercent = 5,
    this.defaultShippingCost = 0,
    List<ShopPromotion>? promotions,
  }) : promotions = promotions ?? <ShopPromotion>[],
       shippingCarriers = shippingCarriers ?? <ShopShippingCarrier>{ShopShippingCarrier.usps, ShopShippingCarrier.ups},
       shippingOrigin = shippingOrigin ?? const ShopShippingAddress(country: '', stateProvince: '', city: '', postalCode: '', address: ''),
       enabledPaymentOptions = enabledPaymentOptions ?? <ShopPaymentOption>{
          ShopPaymentOption.subscriptionCard,
          ShopPaymentOption.newCard,
          ShopPaymentOption.applePay,
          ShopPaymentOption.googlePay,
          ShopPaymentOption.paypal,
          ShopPaymentOption.shopPay,
        };
}

/// Development exchange-rate helper. Production should use a verified FX provider.
class ShopCurrencyConverter {
  static const Map<String, double> usdPerUnit = {
    'USD': 1,
    'MXN': 0.054,
    'EUR': 1.17,
    'GBP': 1.35,
    'CAD': 0.73,
    'AUD': 0.67,
    'JPY': 0.0067,
  };

  static double convert(double amount, String from, String to) {
    final source = usdPerUnit[from] ?? 1;
    final target = usdPerUnit[to] ?? 1;
    return amount * source / target;
  }
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
  ShopStorePolicy policy;

  ShopStore({
    required this.id,
    required this.ownerAccountId,
    required this.name,
    this.description = '',
    this.logoUrl,
    this.bannerUrl,
    this.active = true,
    ShopStorePolicy? policy,
  }) : policy = policy ?? ShopStorePolicy();

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerAccountId': ownerAccountId,
        'name': name,
        'description': description,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'active': active,
        'policy': {
          'enabledPaymentOptions': policy.enabledPaymentOptions.map((e) => e.id).toList(),
          'platformCommissionPercent': policy.platformCommissionPercent,
          'defaultShippingCost': policy.defaultShippingCost,
          'shippingCarriers': policy.shippingCarriers.map((e) => e.name).toList(),
          'shippingOrigin': policy.shippingOrigin.toJson(),
          'promotions': policy.promotions.map((p) => p.toJson()).toList(),
        },
      };

  factory ShopStore.fromJson(Map<String, dynamic> json) => ShopStore(
        id: json['id']?.toString() ?? '',
        ownerAccountId: json['ownerAccountId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        logoUrl: json['logoUrl']?.toString(),
        bannerUrl: json['bannerUrl']?.toString(),
        active: json['active'] != false,
        policy: ShopStorePolicy(
          enabledPaymentOptions: ((json['policy'] as Map?)?['enabledPaymentOptions'] as List?)
              ?.map((e) => ShopPaymentOption.values.firstWhere((v) => v.id == e.toString(), orElse: () => ShopPaymentOption.newCard))
              .toSet(),
          platformCommissionPercent: ((json['policy'] as Map?)?['platformCommissionPercent'] as num?)?.toDouble() ?? 5,
          defaultShippingCost: ((json['policy'] as Map?)?['defaultShippingCost'] as num?)?.toDouble() ?? 0,
          shippingCarriers: ((json['policy'] as Map?)?['shippingCarriers'] as List?)?.map((e) => ShopShippingCarrier.values.firstWhere((v) => v.name == e.toString(), orElse: () => ShopShippingCarrier.usps)).toSet(),
          shippingOrigin: ((json['policy'] as Map?)?['shippingOrigin'] as Map?) == null ? null : ShopShippingAddress.fromJson(Map<String, dynamic>.from(((json['policy'] as Map)['shippingOrigin'] as Map))),
          promotions: ((json['policy'] as Map?)?['promotions'] as List?)?.whereType<Map>().map((e) => ShopPromotion.fromJson(Map<String, dynamic>.from(e))).toList(),
        ),
      );
}

/// One bag/cart line.
class ShopBagLine {
  final String productId;
  int quantity;
  String? variantDetails;
  String? customizationDetails;
  String? customizationImageUrl;

  ShopBagLine({
    required this.productId,
    this.quantity = 1,
    this.variantDetails,
    this.customizationDetails,
    this.customizationImageUrl,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'variantDetails': variantDetails,
    'customizationDetails': customizationDetails,
    'customizationImageUrl': customizationImageUrl,
  };
}

/// Buyer-submitted product review after an order is delivered.
class ShopProductReview {
  final String id;
  final String orderId;
  final String productId;
  final String buyerName;
  final int stars;
  final String review;
  final List<String> photoUrls;
  final DateTime createdAt;

  ShopProductReview({
    required this.id, required this.orderId, required this.productId,
    required this.buyerName, required this.stars, required this.review,
    List<String>? photoUrls, DateTime? createdAt,
  }) : photoUrls = photoUrls ?? <String>[], createdAt = createdAt ?? DateTime.now();
}

/// Buyer question asking a seller whether a product is available.
class ShopProductInquiry {
  final String id;
  final String storeId;
  final String productId;
  final String buyerName;
  final String question;
  String? sellerReply;
  final DateTime createdAt;

  ShopProductInquiry({
    required this.id, required this.storeId, required this.productId,
    required this.buyerName, required this.question, this.sellerReply, DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
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
  final String buyerName;
  final double shippingTotal;
  final String currency;
  final ShopShippingAddress? shippingAddress;
  String status;
  String? trackingNumber;
  String? shippingCompany;

  ShopOrder({required this.id, required this.lines, required this.total, required this.transactionId, this.buyerName = 'Buyer', this.shippingTotal = 0, this.currency = 'USD', this.shippingAddress, this.status = 'paid', this.trackingNumber, this.shippingCompany, DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'lines': lines.map((l) => l.toJson()).toList(),
        'total': total,
        'transactionId': transactionId,
        'buyerName': buyerName,
        'shippingTotal': shippingTotal,
        'currency': currency,
        'shippingAddress': shippingAddress?.toJson(),
        'status': status,
        'trackingNumber': trackingNumber,
        'shippingCompany': shippingCompany,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ShopOrder.fromJson(Map<String, dynamic> json) => ShopOrder(
        id: json['id']?.toString() ?? '',
        lines: (json['lines'] as List?)?.whereType<Map>().map((item) {
          final map = Map<String, dynamic>.from(item);
          return ShopBagLine(productId: map['productId']?.toString() ?? '', quantity: int.tryParse(map['quantity']?.toString() ?? '') ?? 1, variantDetails: map['variantDetails']?.toString(), customizationDetails: map['customizationDetails']?.toString(), customizationImageUrl: map['customizationImageUrl']?.toString());
        }).toList() ?? <ShopBagLine>[],
        total: json['total'] is num ? (json['total'] as num).toDouble() : double.tryParse(json['total']?.toString() ?? '') ?? 0,
        transactionId: json['transactionId']?.toString() ?? '',
        buyerName: json['buyerName']?.toString() ?? 'Buyer',
        status: json['status']?.toString() ?? 'paid',
        shippingTotal: json['shippingTotal'] is num ? (json['shippingTotal'] as num).toDouble() : 0,
        currency: json['currency']?.toString() ?? 'USD',
        shippingAddress: ((json['shippingAddress'] as Map?) == null) ? null : ShopShippingAddress.fromJson(Map<String, dynamic>.from(json['shippingAddress'] as Map)),
        trackingNumber: json['trackingNumber']?.toString(),
        shippingCompany: json['shippingCompany']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

/// Notification generated for a seller after a successful buyer payment.
class ShopSellerNotification {
  final String id;
  final String storeId;
  final String orderId;
  final String buyerName;
  final String productSummary;
  final DateTime createdAt;

  ShopSellerNotification({required this.id, required this.storeId, required this.orderId, required this.buyerName, required this.productSummary, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
}

/// Buyer/seller shipping conversation message.
class ShopOrderMessage {
  final String orderId;
  final String sender;
  final String message;
  final DateTime createdAt;

  ShopOrderMessage({required this.orderId, required this.sender, required this.message, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
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
  final List<ShopSellerNotification> sellerNotifications = <ShopSellerNotification>[];
  final List<ShopOrderMessage> orderMessages = <ShopOrderMessage>[];
  final List<ShopProductReview> reviews = <ShopProductReview>[];
  final List<ShopProductInquiry> inquiries = <ShopProductInquiry>[];
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

  /// Adds or replaces a seller promotion.
  void savePromotion(ShopStore store, ShopPromotion promotion) {
    final existing = store.policy.promotions.indexWhere((p) => p.id == promotion.id);
    if (existing >= 0) {
      store.policy.promotions[existing] = promotion;
    } else {
      store.policy.promotions.add(promotion);
    }
    notifyListeners();
    _save();
  }

  /// Removes a seller promotion.
  void removePromotion(ShopStore store, String promotionId) {
    store.policy.promotions.removeWhere((p) => p.id == promotionId);
    notifyListeners();
    _save();
  }

  /// Updates payment methods, platform commission, and default shipping policy.
  void updateStorePolicy(ShopStore store, {Set<ShopPaymentOption>? enabledPaymentOptions, Set<ShopShippingCarrier>? shippingCarriers, ShopShippingAddress? shippingOrigin, double? platformCommissionPercent, double? defaultShippingCost}) {
    if (enabledPaymentOptions != null) {
      store.policy.enabledPaymentOptions
        ..clear()
        ..addAll(enabledPaymentOptions);
    }
    if (shippingCarriers != null) {
      store.policy.shippingCarriers
        ..clear()
        ..addAll(shippingCarriers);
    }
    if (shippingOrigin != null) {
      store.policy.shippingOrigin = shippingOrigin;
    }
    if (platformCommissionPercent != null) {
      store.policy.platformCommissionPercent = platformCommissionPercent.clamp(5, 100).toDouble();
    }
    if (defaultShippingCost != null) {
      store.policy.defaultShippingCost = defaultShippingCost.clamp(0, double.infinity).toDouble();
    }
    notifyListeners();
    _save();
  }

  /// Creates a seller store. The existence of the store is the seller source of truth.
  ShopStore createStore({
    required String name,
    String description = '',
    String? logoUrl,
    String? bannerUrl,
    Set<ShopShippingCarrier>? shippingCarriers,
    ShopShippingAddress? shippingOrigin,
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
      policy: ShopStorePolicy(
        shippingCarriers: shippingCarriers,
        shippingOrigin: shippingOrigin,
      ),
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
    bool customizable = false,
    bool allowColorSelection = false,
    List<String>? availableColors,
    bool allowSizeSelection = false,
    List<String>? availableSizes,
    bool allowCustomText = false,
    bool allowCustomImage = false,
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
      customizable: customizable,
      allowColorSelection: allowColorSelection,
      availableColors: availableColors,
      allowSizeSelection: allowSizeSelection,
      availableSizes: availableSizes,
      allowCustomText: allowCustomText,
      allowCustomImage: allowCustomImage,
    );
    products.add(product);
    notifyListeners();
    _save();
    return product;
  }

  /// Updates a seller-owned product.
  void updateProduct(ShopProduct product, {String? name, String? description, double? price, int? inventoryQuantity, bool? featured, bool? active, bool? customizable, bool? allowColorSelection, List<String>? availableColors, bool? allowSizeSelection, List<String>? availableSizes, bool? allowCustomText, bool? allowCustomImage}) {
    final accountId = AppController.instance.currentAccount?.id;
    final store = storeById(product.storeId);
    if (store == null || store.ownerAccountId != accountId) return;
    if (name != null && name.trim().isNotEmpty) product.name = name.trim();
    if (description != null) product.description = description.trim();
    if (price != null && price >= 0) product.price = price;
    if (inventoryQuantity != null && inventoryQuantity >= 0) product.inventoryQuantity = inventoryQuantity;
    if (featured != null) product.featured = featured;
    if (active != null) product.active = active;
    if (customizable != null) product.customizable = customizable;
    if (allowColorSelection != null) product.allowColorSelection = allowColorSelection;
    if (availableColors != null) product.availableColors = availableColors;
    if (allowSizeSelection != null) product.allowSizeSelection = allowSizeSelection;
    if (availableSizes != null) product.availableSizes = availableSizes;
    if (allowCustomText != null) product.allowCustomText = allowCustomText;
    if (allowCustomImage != null) product.allowCustomImage = allowCustomImage;
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

  void addToBag(String productId, {int quantity = 1, String? variantDetails, String? customizationDetails, String? customizationImageUrl}) {
    final product = productById(productId);
    if (product == null || !product.active || product.inventoryQuantity <= 0) return;
    final existing = bag.where((line) => line.productId == productId && line.variantDetails == variantDetails && line.customizationDetails == customizationDetails && line.customizationImageUrl == customizationImageUrl).toList();
    if (existing.isEmpty) {
      bag.add(ShopBagLine(productId: productId, quantity: quantity.clamp(1, product.inventoryQuantity).toInt(), variantDetails: variantDetails, customizationDetails: customizationDetails, customizationImageUrl: customizationImageUrl));
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
  void recordOrder({required Iterable<ShopBagLine> lines, required double total, required String transactionId, required String buyerName, required double shippingTotal, required String currency, ShopShippingAddress? shippingAddress, String? shippingCompany}) {
    final copiedLines = lines.map((line) => ShopBagLine(productId: line.productId, quantity: line.quantity, variantDetails: line.variantDetails, customizationDetails: line.customizationDetails, customizationImageUrl: line.customizationImageUrl)).toList();
    final order = ShopOrder(
      id: 'order_${DateTime.now().microsecondsSinceEpoch}',
      lines: copiedLines,
      total: total,
      transactionId: transactionId,
      buyerName: buyerName,
      shippingTotal: shippingTotal,
      currency: currency,
      shippingAddress: shippingAddress,
      shippingCompany: shippingCompany,
    );
    orders.insert(0, order);
    final byStore = <String, List<String>>{};
    for (final line in copiedLines) {
      final product = productById(line.productId);
      if (product == null) continue;
      final details = <String>['${product.name} × ${line.quantity}'];
      if ((line.variantDetails ?? '').trim().isNotEmpty) details.add('Options: ${line.variantDetails}');
      if ((line.customizationDetails ?? '').trim().isNotEmpty) details.add('Customization: ${line.customizationDetails}');
      if ((line.customizationImageUrl ?? '').trim().isNotEmpty) details.add('Customization image: ${line.customizationImageUrl}');
      byStore.putIfAbsent(product.storeId, () => <String>[]).add(details.join(' • '));
    }
    for (final entry in byStore.entries) {
      final store = storeById(entry.key);
      if (store == null) continue;
      sellerNotifications.insert(0, ShopSellerNotification(
        id: 'shop_note_${DateTime.now().microsecondsSinceEpoch}_${entry.key}',
        storeId: entry.key,
        orderId: order.id,
        buyerName: buyerName,
        productSummary: entry.value.join(', '),
      ));
    }
    if (orders.length > 500) orders.removeRange(500, orders.length);
    _save();
    notifyListeners();
  }

  /// Adds tracking details and a seller-to-buyer message to an order.
  void updateShippingAndMessage(ShopOrder order, {required String shippingCompany, required String trackingNumber, required String message}) {
    order.shippingCompany = shippingCompany.trim();
    order.trackingNumber = trackingNumber.trim();
    order.status = order.trackingNumber?.isNotEmpty == true ? 'shipped' : order.status;
    if (message.trim().isNotEmpty) {
      orderMessages.insert(0, ShopOrderMessage(orderId: order.id, sender: 'Seller', message: message.trim()));
    }
    notifyListeners();
    _save();
  }

  /// Removes purchased lines only after a successful checkout.
  /// Marks a shipped order delivered in development. Production should use carrier webhooks.
  void markDelivered(ShopOrder order) {
    order.status = 'completed';
    notifyListeners();
    _save();
  }

  /// Records a buyer availability question for a seller.
  void askSeller({required ShopProduct product, required String buyerName, required String question}) {
    inquiries.insert(0, ShopProductInquiry(id: 'inquiry_${DateTime.now().microsecondsSinceEpoch}', storeId: product.storeId, productId: product.id, buyerName: buyerName, question: question));
    notifyListeners();
    _save();
  }

  /// Adds or replaces a seller response to a buyer availability question.
  void replyToInquiry(ShopProductInquiry inquiry, String reply) {
    inquiry.sellerReply = reply.trim();
    notifyListeners();
    _save();
  }

  /// Adds a delivered-product review with 1-5 stars and optional photo URLs.
  void addReview({required ShopOrder order, required String productId, required int stars, required String review, List<String>? photoUrls}) {
    if (order.status != 'completed') return;
    reviews.removeWhere((r) => r.orderId == order.id && r.productId == productId);
    reviews.insert(0, ShopProductReview(id: 'review_${DateTime.now().microsecondsSinceEpoch}', orderId: order.id, productId: productId, buyerName: order.buyerName, stars: stars.clamp(1, 5).toInt(), review: review.trim(), photoUrls: photoUrls));
    notifyListeners();
    _save();
  }

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

/// Renders either an imported local data image or a normal remote product image.
///
/// Seller-uploaded photos are stored as data URLs in this development build so
/// they remain available across the local app model without exposing a local
/// computer file path to the marketplace UI. Production should upload these
/// bytes to managed object storage and persist the resulting URL instead.
Widget _shopProductImage(String source, {double? width, double? height, BoxFit fit = BoxFit.cover, Widget? error}) {
  if (source.startsWith('data:image/')) {
    try {
      final comma = source.indexOf(',');
      if (comma >= 0) {
        final bytes = base64Decode(source.substring(comma + 1));
        return Image.memory(bytes, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => error ?? const Icon(Icons.broken_image_outlined));
      }
    } catch (_) {
      return error ?? const Icon(Icons.broken_image_outlined);
    }
  }
  return Image.network(source, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => error ?? const Icon(Icons.broken_image_outlined));
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
              FilledButton(onPressed: product.inventoryQuantity <= 0 ? null : () async { final line = await showShopCustomizationDialog(context, product); if (line != null) catalog.addToBag(line.productId, quantity: line.quantity, variantDetails: line.variantDetails, customizationDetails: line.customizationDetails, customizationImageUrl: line.customizationImageUrl); }, child: const UniversalText('Add to Bag')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _productImage(ShopProduct product, {double size = 80}) {
    if (product.imageUrls.isEmpty) return Container(width: size, height: size, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.surfaceContainerHighest), child: const Icon(Icons.shopping_bag_outlined));
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: _shopProductImage(product.imageUrls.first, width: size, height: size, error: Container(width: size, height: size, color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.broken_image_outlined))));
  }

  Future<void> _createStore() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final logo = TextEditingController();
    final banner = TextEditingController();
    final country = TextEditingController();
    final stateProvince = TextEditingController();
    final city = TextEditingController();
    final postalCode = TextEditingController();
    final address = TextEditingController();
    final selectedCarriers = <ShopShippingCarrier>{
      ShopShippingCarrier.usps,
      ShopShippingCarrier.ups,
    };

    try {
      await showDialog<void>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const UniversalText('Create Store'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'Store name')),
                    TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
                    TextField(controller: logo, decoration: const InputDecoration(labelText: 'Logo URL (optional)')),
                    TextField(controller: banner, decoration: const InputDecoration(labelText: 'Banner URL (optional)')),
                    const SizedBox(height: 18),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Shipping origin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: UniversalText('This is the location the seller ships orders from. It is used to compare the selected carriers for each buyer destination.'),
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: country, decoration: const InputDecoration(labelText: 'Country')),
                    TextField(controller: stateProvince, decoration: const InputDecoration(labelText: 'State / Province')),
                    TextField(controller: city, decoration: const InputDecoration(labelText: 'City')),
                    TextField(controller: postalCode, decoration: const InputDecoration(labelText: 'ZIP / Postal code')),
                    TextField(controller: address, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Address')),
                    const SizedBox(height: 18),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Shipping companies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: UniversalText('Select the carriers this store is willing to use. Checkout compares these selected carriers and adds the cheapest available quote.'),
                    ),
                    const SizedBox(height: 6),
                    for (final carrier in ShopShippingCarrier.values)
                      CheckboxListTile(
                        dense: true,
                        value: selectedCarriers.contains(carrier),
                        title: Text(carrier.label),
                        onChanged: (value) => setDialogState(() {
                          if (value == true) {
                            selectedCarriers.add(carrier);
                          } else if (selectedCarriers.length > 1) {
                            selectedCarriers.remove(carrier);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const UniversalText('Cancel')),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty ||
                      country.text.trim().isEmpty ||
                      stateProvince.text.trim().isEmpty ||
                      city.text.trim().isEmpty ||
                      postalCode.text.trim().isEmpty ||
                      address.text.trim().isEmpty ||
                      selectedCarriers.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: UniversalText('Enter the store name, complete shipping origin, and at least one shipping company.')),
                    );
                    return;
                  }
                  try {
                    final store = catalog.createStore(
                      name: name.text,
                      description: description.text,
                      logoUrl: logo.text,
                      bannerUrl: banner.text,
                      shippingCarriers: selectedCarriers,
                      shippingOrigin: ShopShippingAddress(
                        country: country.text.trim(),
                        stateProvince: stateProvince.text.trim(),
                        city: city.text.trim(),
                        postalCode: postalCode.text.trim(),
                        address: address.text.trim(),
                      ),
                    );
                    Navigator.pop(dialogContext);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SellerDashboardScreen(store: store)));
                  } catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
                  }
                },
                child: const UniversalText('Create Store'),
              ),
            ],
          ),
        ),
      );
    } finally {
      name.dispose();
      description.dispose();
      logo.dispose();
      banner.dispose();
      country.dispose();
      stateProvince.dispose();
      city.dispose();
      postalCode.dispose();
      address.dispose();
    }
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

  Future<void> _askAvailability(BuildContext context, ShopProduct product) async {
    final question = TextEditingController(text: 'Do you have ${product.name} available?');
    final sent = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const UniversalText('Ask seller'), content: TextField(controller: question, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Question')), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const UniversalText('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const UniversalText('Send'))]));
    if (sent == true && question.text.trim().isNotEmpty) {
      final buyer = AppController.instance.currentProfile?.name ?? AppController.instance.currentAccount?.username ?? 'Buyer';
      ShopCatalog.instance.askSeller(product: product, buyerName: buyer, question: question.text);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Question sent to the seller.')));
    }
    question.dispose();
  }

  Widget _productRow(BuildContext context, ShopProduct product) {
    final catalog = ShopCatalog.instance;
    return Card(child: ListTile(
      leading: product.imageUrls.isEmpty ? const Icon(Icons.shopping_bag_outlined) : ClipRRect(borderRadius: BorderRadius.circular(8), child: _shopProductImage(product.imageUrls.first, width: 52, height: 52, error: const Icon(Icons.broken_image_outlined))),
      title: Text(product.name),
      subtitle: Text('${product.category} • ${product.price.toStringAsFixed(2)} ${product.currency} • ${product.inventoryQuantity} in stock'),
      trailing: Wrap(children: [IconButton(onPressed: () => catalog.toggleWishlist(product.id), icon: Icon(catalog.isWishlisted(product.id) ? Icons.favorite : Icons.favorite_border)), IconButton(tooltip: 'Ask seller about availability', onPressed: () => _askAvailability(context, product), icon: const Icon(Icons.question_answer_outlined)), OutlinedButton(onPressed: product.inventoryQuantity <= 0 ? null : () async { final line = await showShopCustomizationDialog(context, product); if (line != null && context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ShopCheckoutScreen(lines: [line], title: 'Checkout • ${store.name}', storeSpecific: true)));
          } }, child: const UniversalText('Buy Now')), const SizedBox(width: 6), FilledButton(onPressed: product.inventoryQuantity <= 0 ? null : () async { final line = await showShopCustomizationDialog(context, product); if (line != null) catalog.addToBag(line.productId, quantity: line.quantity, variantDetails: line.variantDetails, customizationDetails: line.customizationDetails, customizationImageUrl: line.customizationImageUrl); }, child: const UniversalText('Add'))]),
    ));
  }
}


/// Opens the buyer customization step. Non-customizable products skip the dialog.
Future<ShopBagLine?> showShopCustomizationDialog(BuildContext context, ShopProduct product) {
  if (!product.customizable) {
    return Future.value(ShopBagLine(productId: product.id));
  }
  return showDialog<ShopBagLine>(
    context: context,
    builder: (_) => ShopCustomizationDialog(product: product),
  );
}

class ShopCustomizationDialog extends StatefulWidget {
  final ShopProduct product;
  const ShopCustomizationDialog({super.key, required this.product});
  @override State<ShopCustomizationDialog> createState() => _ShopCustomizationDialogState();
}

class _ShopCustomizationDialogState extends State<ShopCustomizationDialog> {
  String? color;
  String? size;
  final text = TextEditingController();
  String? imageSource;
  int quantity = 1;

  @override
  void dispose() { text.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux) {
      // file_picker 13 uses static FilePicker methods. Use pickFile() because
      // customization only needs one image, and v13 removed withData.
      final result = await FilePicker.pickFile(type: FileType.image);
      if (result != null && result.path != null) {
        setState(() => imageSource = result.path);
      }
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(context: context, builder: (sheetContext) => SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const UniversalText('Take a photo'), onTap: () => Navigator.pop(sheetContext, ImageSource.camera)), ListTile(leading: const Icon(Icons.photo_library_outlined), title: const UniversalText('Choose from library'), onTap: () => Navigator.pop(sheetContext, ImageSource.gallery))])));
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked != null) setState(() => imageSource = picked.path);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return AlertDialog(
      title: Text('Customize ${p.name}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (p.allowColorSelection && p.availableColors.isNotEmpty) DropdownButtonFormField<String>(initialValue: color, decoration: const InputDecoration(labelText: 'Color', border: OutlineInputBorder()), items: p.availableColors.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => color = v)),
        if (p.allowSizeSelection && p.availableSizes.isNotEmpty) ...[const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: size, decoration: const InputDecoration(labelText: 'Size', border: OutlineInputBorder()), items: p.availableSizes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => size = v))],
        if (p.allowCustomText) ...[const SizedBox(height: 10), TextField(controller: text, maxLines: 3, decoration: const InputDecoration(labelText: 'Custom text', hintText: 'Enter the text to print on the product', border: OutlineInputBorder()))],
        if (p.allowCustomImage) ...[const SizedBox(height: 10), OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.add_a_photo_outlined), label: Text(kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux ? 'Import image from computer' : 'Take a photo or choose from library')), if (imageSource != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Image selected: ${imageSource!.split('/').last}'))],
        const SizedBox(height: 10), Row(children: [const Text('Quantity'), IconButton(onPressed: quantity > 1 ? () => setState(() => quantity--) : null, icon: const Icon(Icons.remove)), Text('$quantity'), IconButton(onPressed: quantity < p.inventoryQuantity ? () => setState(() => quantity++) : null, icon: const Icon(Icons.add))]),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const UniversalText('Cancel')), FilledButton(onPressed: () { final variants = [if (color != null) 'Color: $color', if (size != null) 'Size: $size']; final details = [if (text.text.trim().isNotEmpty) 'Text: ${text.text.trim()}']; Navigator.pop(context, ShopBagLine(productId: p.id, quantity: quantity, variantDetails: variants.isEmpty ? null : variants.join(' • '), customizationDetails: details.isEmpty ? null : details.join(' • '), customizationImageUrl: imageSource)); }, child: const UniversalText('Continue'))],
    );
  }
}

/// Seller dashboard. It is surfaced in navigation only when a store exists.
class SellerDashboardScreen extends StatelessWidget {
  final ShopStore? store;
  final VoidCallback? onHome;
  const SellerDashboardScreen({super.key, this.store, this.onHome});

  Future<void> _messageBuyer(BuildContext context, ShopSellerNotification note) async {
    final matchingOrders = ShopCatalog.instance.orders.where((o) => o.id == note.orderId);
    if (matchingOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: UniversalText('The order could not be found.')),
      );
      return;
    }
    final order = matchingOrders.first;

    final shippingCompany = TextEditingController(text: order.shippingCompany ?? '');
    final trackingNumber = TextEditingController(text: order.trackingNumber ?? '');
    final message = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Message ${note.buyerName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: shippingCompany,
                decoration: const InputDecoration(
                  labelText: 'Shipping company',
                  hintText: 'UPS, FedEx, DHL, etc.',
                ),
              ),
              TextField(
                controller: trackingNumber,
                decoration: const InputDecoration(labelText: 'Tracking number'),
              ),
              TextField(
                controller: message,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Message to buyer',
                  hintText: 'Your order has shipped...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const UniversalText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const UniversalText('Send Message'),
          ),
        ],
      ),
    );

    if (result == true) {
      ShopCatalog.instance.updateShippingAndMessage(
        order,
        shippingCompany: shippingCompany.text,
        trackingNumber: trackingNumber.text,
        message: message.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: UniversalText('Message sent to the buyer.')),
        );
      }
    }

    shippingCompany.dispose();
    trackingNumber.dispose();
    message.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final catalog = ShopCatalog.instance;
    final stores = catalog.currentAccountStores;
    final activeStore = store ?? (stores.isEmpty ? null : stores.first);
    return Scaffold(
      appBar: AppBar(leading: IconButton(tooltip: 'Back to Shop', icon: const Icon(Icons.arrow_back), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (onHome != null) { onHome!(); } else { Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ShopScreen())); } }), title: const UniversalText('Seller Dashboard')),
      body: activeStore == null
          ? const Center(child: UniversalText('Create a store to become a seller.'))
          : AnimatedBuilder(animation: catalog, builder: (_, __) {
              final products = catalog.productsForStore(activeStore.id);
              final featured = products.where((p) => p.featured).length;
              final inventory = products.fold<int>(0, (sum, p) => sum + p.inventoryQuantity);
              return ListView(padding: const EdgeInsets.all(18), children: [
                Card(child: ListTile(leading: const Icon(Icons.storefront), title: Text(activeStore.name, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: UniversalText('Store settings, appearance and featured products'))),
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
                const Text('New payment notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                for (final note in catalog.sellerNotifications.where((n) => n.storeId == activeStore.id).take(20))
                  Card(child: ListTile(leading: const Icon(Icons.notifications_active_outlined), title: Text('${note.buyerName} paid for ${note.productSummary}'), subtitle: Text(note.createdAt.toLocal().toString()), trailing: OutlinedButton(onPressed: () => _messageBuyer(context, note), child: const UniversalText('Message Buyer')))),
                const SizedBox(height: 14),
                const Text('Buyer questions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                for (final inquiry in catalog.inquiries.where((i) => i.storeId == activeStore.id).take(20))
                  Card(child: ListTile(title: Text('${inquiry.buyerName}: ${inquiry.question}'), subtitle: Text(inquiry.sellerReply ?? 'Awaiting seller reply'), trailing: OutlinedButton(onPressed: () => _replyToInquiry(context, inquiry), child: const UniversalText('Reply')))),
                const SizedBox(height: 14),
                const Text('Products', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                for (final product in products) Card(child: ListTile(title: Text(product.name), subtitle: Text('${product.category} • ${product.price.toStringAsFixed(2)} ${product.currency} • ${product.inventoryQuantity} in stock'), trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'edit') { _editProduct(context, product); } else if (value == 'delete') { catalog.deleteProduct(product.id); } else if (value == 'feature') { catalog.updateProduct(product, featured: !product.featured); } }, itemBuilder: (_) => [PopupMenuItem(value: 'edit', child: const UniversalText('Edit Product')), PopupMenuItem(value: 'feature', child: UniversalText(product.featured ? 'Remove Featured' : 'Make Featured')), const PopupMenuItem(value: 'delete', child: UniversalText('Delete Product'))]))),
              ]);
            }),
    );
  }

  Future<void> _replyToInquiry(BuildContext context, ShopProductInquiry inquiry) async {
    final reply = TextEditingController(text: inquiry.sellerReply ?? 'Yes, this product is currently available.');
    final sent = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const UniversalText('Reply to buyer'), content: TextField(controller: reply, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Reply')), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const UniversalText('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const UniversalText('Send'))]));
    if (sent == true) { ShopCatalog.instance.replyToInquiry(inquiry, reply.text); }
    reply.dispose();
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
  late final TextEditingController commission = TextEditingController(text: widget.store.policy.platformCommissionPercent.toStringAsFixed(0));
  late final TextEditingController shipping = TextEditingController(text: widget.store.policy.defaultShippingCost.toStringAsFixed(2));
  late final TextEditingController shippingCountry = TextEditingController(text: widget.store.policy.shippingOrigin.country);
  late final TextEditingController shippingState = TextEditingController(text: widget.store.policy.shippingOrigin.stateProvince);
  late final TextEditingController shippingCity = TextEditingController(text: widget.store.policy.shippingOrigin.city);
  late final TextEditingController shippingPostal = TextEditingController(text: widget.store.policy.shippingOrigin.postalCode);
  late final TextEditingController shippingAddress = TextEditingController(text: widget.store.policy.shippingOrigin.address);
  late Set<ShopPaymentOption> paymentOptions = {...widget.store.policy.enabledPaymentOptions};
  late Set<ShopShippingCarrier> shippingCarriers = {...widget.store.policy.shippingCarriers};

  @override
  void dispose() { name.dispose(); description.dispose(); logo.dispose(); banner.dispose(); commission.dispose(); shipping.dispose(); shippingCountry.dispose(); shippingState.dispose(); shippingCity.dispose(); shippingPostal.dispose(); shippingAddress.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const UniversalText('Store Settings & Appearance')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Store name', border: OutlineInputBorder())),
      const SizedBox(height: 10), TextField(controller: description, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
      const SizedBox(height: 10), TextField(controller: logo, decoration: const InputDecoration(labelText: 'Logo URL', border: OutlineInputBorder())),
      const SizedBox(height: 10), TextField(controller: banner, decoration: const InputDecoration(labelText: 'Banner URL', border: OutlineInputBorder())),
      const SizedBox(height: 18), const Text('Checkout & payout settings', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6), const UniversalText('Enable only the payment methods your store can accept. The platform commission cannot be set below 5%.'),
      for (final option in ShopPaymentOption.values)
        SwitchListTile(
          title: Text(option.label),
          value: paymentOptions.contains(option),
          onChanged: (enabled) => setState(() {
            if (enabled) {
              paymentOptions.add(option);
            } else {
              paymentOptions.remove(option);
            }
          }),
        ),
      const SizedBox(height: 8), TextField(controller: commission, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Platform commission (%)', helperText: 'Minimum 5%. Example: 5% means the platform receives 5% of the seller payout base.', border: OutlineInputBorder())),
      const SizedBox(height: 10), TextField(controller: shipping, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Default shipping cost', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      const Text('Shipping origin', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const UniversalText('Enter where orders are shipped from. Checkout uses this origin with the buyer destination to compare the selected carriers.'),
      const SizedBox(height: 8),
      TextField(controller: shippingCountry, decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: shippingState, decoration: const InputDecoration(labelText: 'State / Province', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: shippingCity, decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: shippingPostal, decoration: const InputDecoration(labelText: 'ZIP / Postal code', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: shippingAddress, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      const Text('Shipping companies', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      const UniversalText('Only selected carriers are considered at checkout. The buyer is automatically charged the cheapest available selected option for each store.'),
      for (final carrier in ShopShippingCarrier.values)
        CheckboxListTile(
          dense: true,
          value: shippingCarriers.contains(carrier),
          title: Text(carrier.label),
          onChanged: (value) => setState(() {
            if (value == true) {
              shippingCarriers.add(carrier);
            } else if (shippingCarriers.length > 1) {
              shippingCarriers.remove(carrier);
            }
          }),
        ),
      const SizedBox(height: 18),
      const Text('Sales & promotions', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const UniversalText('Create sales such as Buy 3, Get 1 Free or coupon codes such as HOLIDAY10 for 10% off.'),
      const SizedBox(height: 8),
      for (final promotion in widget.store.policy.promotions)
        Card(
          child: ListTile(
            title: Text(promotion.type == ShopPromotionType.buyXGetY
                ? 'Buy ${promotion.buyQuantity}, Get ${promotion.freeQuantity} Free'
                : '${promotion.code} • ${promotion.percentOff.toStringAsFixed(0)}% off'),
            subtitle: Text(promotion.description.isEmpty ? 'Seller promotion' : promotion.description),
            trailing: Wrap(
              spacing: 4,
              children: [
                Switch(value: promotion.active, onChanged: (value) => setState(() => promotion.active = value)),
                IconButton(onPressed: () => _editPromotion(promotion), icon: const Icon(Icons.edit_outlined)),
                IconButton(onPressed: () { ShopCatalog.instance.removePromotion(widget.store, promotion.id); setState(() {}); }, icon: const Icon(Icons.delete_outline)),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(onPressed: _newPromotion, icon: const Icon(Icons.local_offer_outlined), label: const UniversalText('Add Sale or Coupon')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const UniversalText('Save Store Settings')),
    ]),
  );

  void _save() {
    final parsedCommission = double.tryParse(commission.text.trim()) ?? 5;
    final parsedShipping = double.tryParse(shipping.text.trim()) ?? 0;
    ShopCatalog.instance.updateStore(widget.store, name: name.text, description: description.text, logoUrl: logo.text, bannerUrl: banner.text);
    ShopCatalog.instance.updateStorePolicy(widget.store, enabledPaymentOptions: paymentOptions, shippingCarriers: shippingCarriers, shippingOrigin: ShopShippingAddress(country: shippingCountry.text.trim(), stateProvince: shippingState.text.trim(), city: shippingCity.text.trim(), postalCode: shippingPostal.text.trim(), address: shippingAddress.text.trim()), platformCommissionPercent: parsedCommission < 5 ? 5 : parsedCommission, defaultShippingCost: parsedShipping < 0 ? 0 : parsedShipping);
    Navigator.pop(context);
  }

  Future<void> _newPromotion() async {
    final type = await showDialog<ShopPromotionType>(context: context, builder: (context) => SimpleDialog(title: const UniversalText('Choose promotion'), children: [
      SimpleDialogOption(onPressed: () => Navigator.pop(context, ShopPromotionType.buyXGetY), child: const UniversalText('Buy X, get Y free')),
      SimpleDialogOption(onPressed: () => Navigator.pop(context, ShopPromotionType.couponPercent), child: const UniversalText('Coupon percentage')),
    ]));
    if (type == null || !mounted) return;
    final promotion = ShopPromotion(id: 'promo_${DateTime.now().microsecondsSinceEpoch}', type: type);
    await _editPromotion(promotion);
  }

  Future<void> _editPromotion(ShopPromotion promotion) async {
    final buy = TextEditingController(text: promotion.buyQuantity.toString());
    final free = TextEditingController(text: promotion.freeQuantity.toString());
    final code = TextEditingController(text: promotion.code);
    final percent = TextEditingController(text: promotion.percentOff.toStringAsFixed(0));
    final description = TextEditingController(text: promotion.description);
    final result = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(promotion.type == ShopPromotionType.buyXGetY ? 'Buy X, get Y free' : 'Coupon percentage'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (promotion.type == ShopPromotionType.buyXGetY) ...[
          TextField(controller: buy, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Buy quantity', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: free, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Free quantity', border: OutlineInputBorder())),
        ] else ...[
          TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Checkout code', hintText: 'HOLIDAY10', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: percent, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Discount percentage', border: OutlineInputBorder())),
        ],
        const SizedBox(height: 10),
        TextField(controller: description, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Customer-facing description (optional)', border: OutlineInputBorder())),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const UniversalText('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const UniversalText('Save'))],
    ));
    if (result == true) {
      if (promotion.type == ShopPromotionType.buyXGetY) {
        promotion.buyQuantity = int.tryParse(buy.text) ?? 0; promotion.freeQuantity = int.tryParse(free.text) ?? 0;
      } else {
        promotion.code = code.text.trim().toUpperCase(); promotion.percentOff = double.tryParse(percent.text) ?? 0;
      }
      promotion.description = description.text.trim();
      final valid = promotion.type == ShopPromotionType.buyXGetY ? promotion.buyQuantity > 0 && promotion.freeQuantity > 0 : promotion.code.isNotEmpty && promotion.percentOff > 0 && promotion.percentOff <= 100;
      if (valid) { ShopCatalog.instance.savePromotion(widget.store, promotion); if (mounted) setState(() {}); }
    }
    buy.dispose(); free.dispose(); code.dispose(); percent.dispose(); description.dispose();
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
  final List<String> importedImageDataUrls = <String>[];
  final List<_AssociationDraft> associationDrafts = <_AssociationDraft>[_AssociationDraft()];
  String productType = 'Merchandise';
  String category = 'Other';
  bool featured = false;
  bool customizable = false;
  bool allowColorSelection = false;
  bool allowSizeSelection = false;
  bool allowCustomText = false;
  bool allowCustomImage = false;
  final colors = TextEditingController();
  final sizes = TextEditingController();

  static const productTypes = ['Merchandise', 'Collectible / Game', 'Physical Media', 'Poster', 'Book', 'Clothing', 'Toy', 'Accessory', 'Home Item', 'Other'];
  static const categories = ['Movies', 'Shows', 'Music', 'Franchise', 'Clothing', 'Collectibles', 'Physical Media', 'Posters', 'Books', 'Toys', 'Accessories', 'Home', 'Other'];
  static const associationTypes = ['movie', 'show', 'franchise', 'song', 'artist', 'album', 'playlist', 'collection'];

  /// Imports one or more product photos from the seller's device.
  ///
  /// Desktop/web uses the native file picker. Mobile also offers the camera
  /// or photo library. Imported bytes are represented as data URLs for this
  /// development build; production should upload them to object storage.
  Future<void> _importProductPhotos() async {
    final isDesktopOrWeb = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    try {
      if (isDesktopOrWeb) {
        final files = await FilePicker.pickFiles(type: FileType.image);
        if (files.isEmpty) return;
        final imported = <String>[];
        for (final file in files) {
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) continue;
          final extension = file.name.split('.').last.toLowerCase();
          final mime = extension == 'png'
              ? 'image/png'
              : extension == 'webp'
                  ? 'image/webp'
                  : extension == 'gif'
                      ? 'image/gif'
                      : 'image/jpeg';
          imported.add('data:$mime;base64,${base64Encode(bytes)}');
        }
        if (!mounted) return;
        setState(() => importedImageDataUrls.addAll(imported));
        return;
      }

      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const UniversalText('Take a product photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const UniversalText('Choose product photos from library'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;

      List<XFile> picked;
      if (source == ImageSource.gallery) {
        picked = await ImagePicker().pickMultiImage(imageQuality: 90);
      } else {
        final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
        picked = photo == null ? <XFile>[] : <XFile>[photo];
      }
      final imported = <String>[];
      for (final photo in picked) {
        final bytes = await photo.readAsBytes();
        if (bytes.isEmpty) continue;
        final extension = photo.name.split('.').last.toLowerCase();
        final mime = extension == 'png'
            ? 'image/png'
            : extension == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
        imported.add('data:$mime;base64,${base64Encode(bytes)}');
      }
      if (!mounted) return;
      setState(() => importedImageDataUrls.addAll(imported));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to import product photo: $error')),
      );
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    inventory.dispose();
    imageUrls.dispose();
    colors.dispose();
    sizes.dispose();
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
          TextField(controller: imageUrls, decoration: const InputDecoration(labelText: 'Product image URLs (comma separated)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _importProductPhotos, icon: const Icon(Icons.photo_library_outlined), label: const UniversalText('Import product photo(s)')),
          if (importedImageDataUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(height: 96, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: importedImageDataUrls.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (context, index) => Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: _shopProductImage(importedImageDataUrls[index], width: 96, height: 96)), Positioned(top: 2, right: 2, child: IconButton.filledTonal(onPressed: () => setState(() => importedImageDataUrls.removeAt(index)), icon: const Icon(Icons.close, size: 18)))]))),
          ],
          const SizedBox(height: 10),
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
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Customization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Choose whether buyers can customize this product. For example, Disney Loteria can stay non-customizable, while a blank shirt or mug can allow color, size, text, and/or image customization.'),
            SwitchListTile(value: customizable, onChanged: (v) => setState(() { customizable = v; if (!v) { allowColorSelection = false; allowSizeSelection = false; allowCustomText = false; allowCustomImage = false; } }), title: const UniversalText('This product is customizable')),
            if (customizable) ...[
              SwitchListTile(value: allowColorSelection, onChanged: (v) => setState(() => allowColorSelection = v), title: const UniversalText('Buyer can choose a color')),
              if (allowColorSelection) TextField(controller: colors, decoration: const InputDecoration(labelText: 'Available colors', hintText: 'White, Black, Red, Blue', border: OutlineInputBorder())),
              SwitchListTile(value: allowSizeSelection, onChanged: (v) => setState(() => allowSizeSelection = v), title: const UniversalText('Buyer can choose a size')),
              if (allowSizeSelection) TextField(controller: sizes, decoration: const InputDecoration(labelText: 'Available sizes', hintText: 'S, M, L, XL', border: OutlineInputBorder())),
              SwitchListTile(value: allowCustomText, onChanged: (v) => setState(() => allowCustomText = v), title: const UniversalText('Buyer can add custom text')),
              SwitchListTile(value: allowCustomImage, onChanged: (v) => setState(() => allowCustomImage = v), title: const UniversalText('Buyer can add an image')),
            ],
          ]))),
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
      imageUrls: [...importedImageDataUrls, ...imageUrls.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)],
      associations: associations,
      customizable: customizable,
      allowColorSelection: allowColorSelection,
      availableColors: colors.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      allowSizeSelection: allowSizeSelection,
      availableSizes: sizes.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      allowCustomText: allowCustomText,
      allowCustomImage: allowCustomImage,
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

/// Buyer order history, delivery tracking, and delivered-product reviews.
class ShopOrdersScreen extends StatelessWidget {
  const ShopOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: ShopCatalog.instance, builder: (_, __) {
    final catalog = ShopCatalog.instance;
    return Scaffold(appBar: AppBar(title: const UniversalText('My Shop Orders')), body: catalog.orders.isEmpty ? const Center(child: UniversalText('You have no Shop orders yet.')) : ListView(padding: const EdgeInsets.all(18), children: [
      for (final order in catalog.orders) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(order.id, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text('${order.status.toUpperCase()} • ${order.currency} ${order.total.toStringAsFixed(2)}'),
        if (order.shippingCompany?.isNotEmpty == true || order.trackingNumber?.isNotEmpty == true) Text('Shipping: ${order.shippingCompany ?? 'Carrier'} • ${order.trackingNumber ?? 'Tracking pending'}'),
        const SizedBox(height: 8),
        for (final line in order.lines) _orderLine(context, order, line),
        if (order.status == 'shipped') Align(alignment: Alignment.centerRight, child: OutlinedButton(onPressed: () { catalog.markDelivered(order); }, child: const UniversalText('Mark as delivered'))),
      ]))),
      ]),
      );
  });

  Widget _orderLine(BuildContext context, ShopOrder order, ShopBagLine line) {
    final product = ShopCatalog.instance.productById(line.productId);
    if (product == null) return const SizedBox.shrink();
    return ListTile(contentPadding: EdgeInsets.zero, title: Text(product.name), subtitle: Text([if ((line.variantDetails ?? '').isNotEmpty) line.variantDetails!, if ((line.customizationDetails ?? '').isNotEmpty) line.customizationDetails!, 'Quantity ${line.quantity}'].join(' • ')), trailing: order.status == 'completed' ? OutlinedButton(onPressed: () => _review(context, order, product), child: const UniversalText('Rate & Review')) : null);
  }

  Future<void> _review(BuildContext context, ShopOrder order, ShopProduct product) async {
    final review = TextEditingController();
    final photos = TextEditingController();
    int stars = 5;
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(title: Text('Review ${product.name}'), content: SingleChildScrollView(child: Column(children: [DropdownButtonFormField<int>(initialValue: stars, items: [1,2,3,4,5].map((v) => DropdownMenuItem(value: v, child: Text('$v stars'))).toList(), onChanged: (v) { if (v != null) setLocal(() => stars = v); }), TextField(controller: review, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Review')), TextField(controller: photos, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Product photo URLs (one per line)'))])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const UniversalText('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const UniversalText('Submit review'))])));
    if (saved == true) { ShopCatalog.instance.addReview(order: order, productId: product.id, stars: stars, review: review.text, photoUrls: photos.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()); }
    review.dispose(); photos.dispose();
  }
}

/// Checkout screen used by both the single-store and all-store bag flows.
class ShopCheckoutScreen extends StatefulWidget {
  final List<ShopBagLine> lines;
  final String title;
  final bool storeSpecific;
  const ShopCheckoutScreen({super.key, required this.lines, required this.title, required this.storeSpecific});
  @override State<ShopCheckoutScreen> createState() => _ShopCheckoutScreenState();
}

class _ShopCheckoutScreenState extends State<ShopCheckoutScreen> {
  ShopPaymentOption paymentChoice = ShopPaymentOption.subscriptionCard;
  String displayCurrency = 'USD';
  final cardholder = TextEditingController();
  final cardNumber = TextEditingController();
  final expiry = TextEditingController();
  final cvv = TextEditingController();
  final postal = TextEditingController();
  final country = TextEditingController();
  final stateProvince = TextEditingController();
  final city = TextEditingController();
  final address = TextEditingController();
  bool processing = false;
  final couponController = TextEditingController();
  String? appliedCoupon;

  @override
  void dispose() {
    cardholder.dispose();
    cardNumber.dispose();
    expiry.dispose();
    cvv.dispose();
    postal.dispose();
    country.dispose();
    stateProvince.dispose();
    city.dispose();
    address.dispose();
    couponController.dispose();
    super.dispose();
  }

  List<ShopStore> get stores {
    final ids = widget.lines
        .map((l) => ShopCatalog.instance.productById(l.productId)?.storeId)
        .whereType<String>()
        .toSet();
    return ids
        .map((id) => ShopCatalog.instance.storeById(id))
        .whereType<ShopStore>()
        .toList();
  }

  Set<ShopPaymentOption> get availablePaymentOptions {
    if (stores.isEmpty) return <ShopPaymentOption>{ShopPaymentOption.newCard};
    var result = <ShopPaymentOption>{...ShopPaymentOption.values};
    for (final store in stores) {
      result = result.intersection(store.policy.enabledPaymentOptions);
    }
    return result;
  }

  double get subtotal => ShopCatalog.instance.subtotal(widget.lines);

  double _storeSubtotal(ShopStore store) => ShopCatalog.instance.subtotal(
        widget.lines.where((line) =>
            ShopCatalog.instance.productById(line.productId)?.storeId == store.id),
      );

  double _buyXGetYDiscount(ShopStore store) {
    double discount = 0;
    for (final promotion in store.policy.promotions.where(
      (p) => p.active && p.type == ShopPromotionType.buyXGetY,
    )) {
      final group = promotion.buyQuantity + promotion.freeQuantity;
      if (group <= 0) continue;
      for (final line in widget.lines) {
        final product = ShopCatalog.instance.productById(line.productId);
        if (product == null || product.storeId != store.id) continue;
        final freeUnits = (line.quantity ~/ group) * promotion.freeQuantity +
            ((line.quantity % group) >= promotion.buyQuantity
                ? promotion.freeQuantity
                : 0);
        discount += freeUnits.clamp(0, line.quantity) * product.price;
      }
    }
    return discount;
  }

  double _couponDiscount(ShopStore store) {
    final code = appliedCoupon?.trim().toUpperCase();
    if (code == null || code.isEmpty) return 0;
    final promotion = store.policy.promotions.firstWhere(
      (p) => p.active &&
          p.type == ShopPromotionType.couponPercent &&
          p.code.toUpperCase() == code,
      orElse: () => ShopPromotion(
        id: '_none',
        type: ShopPromotionType.couponPercent,
        active: false,
      ),
    );
    if (!promotion.active) return 0;
    final base = (_storeSubtotal(store) - _buyXGetYDiscount(store))
        .clamp(0, double.infinity)
        .toDouble();
    return base * promotion.percentOff.clamp(0, 100) / 100;
  }

  double _storeDiscount(ShopStore store) =>
      _buyXGetYDiscount(store) + _couponDiscount(store);

  double get discounts => stores.fold<double>(
        0,
        (sum, store) => sum +
            ShopCurrencyConverter.convert(
              _storeDiscount(store),
              storesProductCurrency(store),
              displayCurrency,
            ),
      );

  double get discountedSubtotal =>
      (convertedSubtotal - discounts).clamp(0, double.infinity).toDouble();

  ShopShippingAddress get destination => ShopShippingAddress(
        country: country.text,
        stateProvince: stateProvince.text,
        city: city.text,
        postalCode: postal.text,
        address: address.text,
      );

  Map<String, ShopShippingQuote?> get cheapestShippingByStore {
    final result = <String, ShopShippingQuote?>{};
    for (final store in stores) {
      final itemCount = widget.lines
          .where((line) =>
              ShopCatalog.instance.productById(line.productId)?.storeId == store.id)
          .fold<int>(0, (sum, line) => sum + line.quantity);
      final quotes = ShopShippingCalculator.quotes(
        store: store,
        destination: destination,
        itemCount: itemCount,
      );
      result[store.id] = quotes.isEmpty ? null : quotes.first;
    }
    return result;
  }

  double get shipping => cheapestShippingByStore.values.fold<double>(
        0,
        (sum, quote) => quote == null
            ? sum
            : sum + ShopCurrencyConverter.convert(
                quote.amount,
                quote.currency,
                displayCurrency,
              ),
      );

  String get shippingCompanies => cheapestShippingByStore.values
      .whereType<ShopShippingQuote>()
      .map((quote) => quote.carrier.label)
      .join(' • ');

  bool get addressComplete => destination.isComplete;

  bool get shippingReady => stores.isNotEmpty &&
      stores.every((store) =>
          store.policy.shippingCarriers.isNotEmpty &&
          store.policy.shippingOrigin.isComplete &&
          cheapestShippingByStore[store.id] != null);

  double get platformFee => stores.fold<double>(0, (sum, store) {
    final discountedStoreAmount = ShopCurrencyConverter.convert(
      (_storeSubtotal(store) - _storeDiscount(store))
          .clamp(0, double.infinity)
          .toDouble(),
      storesProductCurrency(store),
      displayCurrency,
    );
    return sum +
        discountedStoreAmount * store.policy.platformCommissionPercent / 100;
  });

  String storesProductCurrency(ShopStore store) {
    final product = widget.lines
        .map((line) => ShopCatalog.instance.productById(line.productId))
        .whereType<ShopProduct>()
        .firstWhere(
          (p) => p.storeId == store.id,
          orElse: () => ShopProduct(
            id: '',
            storeId: store.id,
            name: '',
            currency: 'USD',
          ),
        );
    return product.currency;
  }

  double get convertedSubtotal => stores.fold<double>(
        0,
        (sum, store) => sum +
            ShopCurrencyConverter.convert(
              _storeSubtotal(store),
              storesProductCurrency(store),
              displayCurrency,
            ),
      );

  double get total => discountedSubtotal + shipping;

  @override
  Widget build(BuildContext context) {
    final methods = availablePaymentOptions;
    if (!methods.contains(paymentChoice)) {
      paymentChoice = methods.isNotEmpty
          ? methods.first
          : ShopPaymentOption.newCard;
    }
    final cheapest = cheapestShippingByStore;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.storeSpecific ? 'Store Checkout' : 'All Stores Checkout',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  for (final line in widget.lines) _summaryLine(line),
                  const Divider(),
                  _amountRow('Products', convertedSubtotal),
                  if (discounts > 0)
                    _amountRow('Promotions & discounts', -discounts),
                  _amountRow('Shipping', shipping),
                  _amountRow('Buyer total', total, bold: true),
                  const SizedBox(height: 6),
                  Text(
                    'Seller-funded platform service fee: ${_money(platformFee, displayCurrency)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Shipping address',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const UniversalText(
            'Enter the delivery location before paying. The checkout compares the shipping companies selected by each seller and adds the cheapest available quote for each store.',
          ),
          const SizedBox(height: 10),
          TextField(
            controller: country,
            enabled: !processing,
            decoration: const InputDecoration(
              labelText: 'Country',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: stateProvince,
            enabled: !processing,
            decoration: const InputDecoration(
              labelText: 'State / Province',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: city,
            enabled: !processing,
            decoration: const InputDecoration(
              labelText: 'City',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: postal,
            enabled: !processing,
            decoration: const InputDecoration(
              labelText: 'ZIP / Postal code',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: address,
            enabled: !processing,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: 'Street and number, apartment/unit, etc.',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (addressComplete && shippingReady)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cheapest selected shipping',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    for (final store in stores)
                      if (cheapest[store.id] != null)
                        Text(
                          '${store.name}: ${cheapest[store.id]!.carrier.label} • ${_money(ShopCurrencyConverter.convert(cheapest[store.id]!.amount, cheapest[store.id]!.currency, displayCurrency), displayCurrency)}',
                        ),
                    const SizedBox(height: 6),
                    const UniversalText(
                      'These are development estimates. Live carrier APIs will provide the final production shipping price based on package weight, dimensions, origin, destination, service level, and current carrier rates.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else if (addressComplete)
            Card(
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: UniversalText(
                  'Shipping is not available yet for one or more stores. Each seller must select at least one shipping company and enter a complete store shipping origin.',
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Display currency',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              DropdownButton<String>(
                value: displayCurrency,
                items: ShopCurrencyConverter.usdPerUnit.keys
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: processing
                    ? null
                    : (v) {
                        if (v != null) setState(() => displayCurrency = v);
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: couponController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Promo code',
                    hintText: 'HOLIDAY10',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: processing
                    ? null
                    : () {
                        final code = couponController.text.trim().toUpperCase();
                        final valid = stores.any((store) => store.policy.promotions.any(
                              (p) =>
                                  p.active &&
                                  p.type == ShopPromotionType.couponPercent &&
                                  p.code.toUpperCase() == code,
                            ));
                        setState(() => appliedCoupon = valid ? code : null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: UniversalText(
                              valid
                                  ? 'Promotion applied.'
                                  : 'That promotion code is not valid for this checkout.',
                            ),
                          ),
                        );
                      },
                child: const UniversalText('Apply'),
              ),
            ],
          ),
          if (discounts > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'You saved ${_money(discounts, displayCurrency)} with seller promotions.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Payment method',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          RadioGroup<ShopPaymentOption>(
            groupValue: paymentChoice,
            onChanged: processing
                ? (value) {}
                : (value) {
                    if (value != null) setState(() => paymentChoice = value);
                  },
            child: Column(
              children: [
                for (final option in methods)
                  RadioListTile<ShopPaymentOption>(
                    value: option,
                    title: Text(option.label),
                    subtitle: Text(_paymentSubtitle(option)),
                  ),
              ],
            ),
          ),
          if (paymentChoice == ShopPaymentOption.newCard) _newCardForm(),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: UniversalText(
                'Production payment providers should tokenize payment credentials on their hosted/SDK checkout. This development build does not charge real cards.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: processing ? null : _pay,
            icon: processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_outline),
            label: UniversalText(
              processing ? 'Processing…' : 'Place Order & Pay',
            ),
          ),
        ],
      ),
    );
  }

  String _paymentSubtitle(ShopPaymentOption option) => switch (option) {
        ShopPaymentOption.applePay => 'Use Apple Pay when supported on this device.',
        ShopPaymentOption.googlePay => 'Use Google Pay when supported on this device.',
        ShopPaymentOption.paypal => 'Continue through PayPal.',
        ShopPaymentOption.shopPay => 'Use Shop Pay.',
        ShopPaymentOption.subscriptionCard => 'Use your streaming-service card on file.',
        ShopPaymentOption.newCard => 'Enter a different card for this order.',
      };

  Widget _amountRow(String label, double value, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.normal)),
          Text(
            _money(value, displayCurrency),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
              fontSize: bold ? 21 : 15,
            ),
          ),
        ],
      );

  Widget _summaryLine(ShopBagLine line) {
    final product = ShopCatalog.instance.productById(line.productId);
    if (product == null) return const SizedBox.shrink();
    final value = product.price * line.quantity;
    final converted = ShopCurrencyConverter.convert(
      value,
      product.currency,
      displayCurrency,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(product.name)),
          Text('× ${line.quantity}'),
          const SizedBox(width: 14),
          Text(_money(converted, displayCurrency)),
        ],
      ),
    );
  }

  Widget _newCardForm() => Column(
        children: [
          TextField(
            controller: cardholder,
            decoration: const InputDecoration(
              labelText: 'Cardholder name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: cardNumber,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Card number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: expiry,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'MM/YY',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: cvv,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: postal,
            decoration: const InputDecoration(
              labelText: 'ZIP / Postal code',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );

  Future<void> _pay() async {
    if (widget.lines.isEmpty || total <= 0) return;
    if (!addressComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: UniversalText(
            'Enter your country, state/province, city, ZIP/postal code, and address before buying.',
          ),
        ),
      );
      return;
    }
    if (!shippingReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: UniversalText(
            'Shipping quotes are unavailable. Check that every seller has selected shipping companies and configured a shipping origin.',
          ),
        ),
      );
      return;
    }
    if (paymentChoice == ShopPaymentOption.newCard) {
      final digits = cardNumber.text.replaceAll(RegExp(r'\D'), '');
      if (cardholder.text.trim().isEmpty ||
          digits.length < 12 ||
          cvv.text.trim().length < 3 ||
          expiry.text.trim().isEmpty ||
          postal.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: UniversalText('Enter the required card and billing information.'),
          ),
        );
        return;
      }
    }
    setState(() => processing = true);
    try {
      final method = ShopPaymentMethod(
        id: paymentChoice.id,
        label: paymentChoice.label,
        subscriptionCard: paymentChoice == ShopPaymentOption.subscriptionCard,
      );
      final result = await const ShopPaymentGateway().pay(
        amount: total,
        method: method,
        cardNumber: paymentChoice == ShopPaymentOption.newCard
            ? cardNumber.text
            : null,
      );
      if (!mounted) return;
      final buyerName = AppController.instance.currentProfile?.name ??
          AppController.instance.currentAccount?.username ??
          'Buyer';
      ShopCatalog.instance.recordOrder(
        lines: widget.lines,
        total: total,
        transactionId: result.transactionId,
        buyerName: buyerName,
        shippingTotal: shipping,
        currency: displayCurrency,
        shippingAddress: destination,
        shippingCompany: shippingCompanies,
      );
      ShopCatalog.instance.completeCheckout(widget.lines);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const UniversalText('Order placed'),
          content: UniversalText(
            'Payment approved in development mode. The cheapest selected shipping option was added to the total.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const UniversalText('Done'),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ShopScreen()),
          (route) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  String _money(double value, String currency) =>
      '$currency ${value.toStringAsFixed(2)}';
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
    if (!hasProducts) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen(contextAssociationType: associationType, contextAssociationId: associationId, contextAssociationName: associationName))),
      icon: const Icon(Icons.storefront_outlined),
      label: const UniversalText('Shop Related Products'),
    );
  }

  /// Convenience helper for media details.
  static Widget forMedia(BuildContext context, MediaItem media) => ContextualShopButton(associationType: media.type == 'tvShow' ? 'show' : 'movie', associationId: media.id, associationName: media.title);

  /// Convenience helper for music entities.
  static Widget forMusic({required String type, required String id, required String name}) => ContextualShopButton(associationType: type, associationId: id, associationName: name);

  /// Convenience helper for collections.
  static Widget forCollection(MediaCollection collection) => ContextualShopButton(associationType: 'collection', associationId: collection.id, associationName: collection.name);
}
