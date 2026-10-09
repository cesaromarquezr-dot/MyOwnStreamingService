import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import 'app_core.dart';

class FoodRestaurant {
  final String id;
  final String name;
  final String cuisine;
  final String address;
  final String description;
  final String phone;
  final String city;
  final String stateRegion;
  final String postalCode;
  final String countryCode;
  final String? website;
  final String openingHours;
  final String source;
  final bool isOrderable;
  final bool isOpenKnown;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final double rating;
  final int reviewCount;
  final int deliveryFeeCents;
  final int serviceFeeCents;
  final int taxRateBasisPoints;
  final int loyaltyPointsPerCurrency;
  final bool allowsDelivery;
  final bool allowsPickup;
  final int minimumOrderCents;
  final int etaMinMinutes;
  final int etaMaxMinutes;
  final bool isOpen;
  final String? heroImageUrl;
  final List<String> tags;
  final String currencyCode;

  const FoodRestaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.address,
    this.description = '',
    this.phone = '',
    this.city = '',
    this.stateRegion = '',
    this.postalCode = '',
    this.countryCode = '',
    this.website,
    this.openingHours = '',
    this.source = 'platform',
    this.isOrderable = true,
    this.isOpenKnown = true,
    required this.latitude,
    required this.longitude,
    this.distanceKm = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.deliveryFeeCents = 0,
    this.serviceFeeCents = 199,
    this.taxRateBasisPoints = 0,
    this.loyaltyPointsPerCurrency = 1,
    this.allowsDelivery = true,
    this.allowsPickup = true,
    this.minimumOrderCents = 0,
    this.etaMinMinutes = 30,
    this.etaMaxMinutes = 45,
    this.isOpen = true,
    this.heroImageUrl,
    this.tags = const <String>[],
    this.currencyCode = 'USD',
  });

  factory FoodRestaurant.fromJson(Map<String, dynamic> json) {
    return FoodRestaurant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Restaurant',
      cuisine: json['cuisine']?.toString() ?? 'Food',
      address: json['address']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      stateRegion: json['stateRegion']?.toString() ?? json['state_region']?.toString() ?? '',
      postalCode: json['postalCode']?.toString() ?? json['postal_code']?.toString() ?? '',
      countryCode: json['countryCode']?.toString() ?? json['country_code']?.toString() ?? '',
      website: _nullableString(json['website'] ?? json['contact:website']),
      openingHours: json['openingHours']?.toString() ?? json['opening_hours']?.toString() ?? '',
      source: json['source']?.toString() ?? 'platform',
      isOrderable: json['isOrderable'] == null && json['is_orderable'] == null
          ? true
          : (json['isOrderable'] ?? json['is_orderable']) == true,
      isOpenKnown: json['isOpenKnown'] == null && json['is_open_known'] == null
          ? true
          : (json['isOpenKnown'] ?? json['is_open_known']) == true,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      distanceKm: _toDouble(json['distanceKm'] ?? json['distance_km']),
      rating: _toDouble(json['rating']),
      reviewCount: _toInt(json['reviewCount'] ?? json['review_count']),
      deliveryFeeCents: _toInt(json['deliveryFeeCents'] ?? json['delivery_fee_cents']),
      serviceFeeCents: _toInt(json['serviceFeeCents'] ?? json['service_fee_cents'], fallback: 199),
      taxRateBasisPoints: _toInt(json['taxRateBasisPoints'] ?? json['tax_rate_basis_points']),
      loyaltyPointsPerCurrency: _toInt(json['loyaltyPointsPerCurrency'] ?? json['loyalty_points_per_currency'], fallback: 1),
      allowsDelivery: json['allowsDelivery'] == null && json['allows_delivery'] == null
          ? true
          : (json['allowsDelivery'] ?? json['allows_delivery']) == true,
      allowsPickup: json['allowsPickup'] == null && json['allows_pickup'] == null
          ? true
          : (json['allowsPickup'] ?? json['allows_pickup']) == true,
      minimumOrderCents: _toInt(json['minimumOrderCents'] ?? json['minimum_order_cents']),
      etaMinMinutes: _toInt(json['etaMinMinutes'] ?? json['eta_min_minutes'], fallback: 30),
      etaMaxMinutes: _toInt(json['etaMaxMinutes'] ?? json['eta_max_minutes'], fallback: 45),
      isOpen: json['isOpen'] == null && json['is_open'] == null
          ? true
          : (json['isOpen'] ?? json['is_open']) == true,
      heroImageUrl: _nullableString(json['heroImageUrl'] ?? json['hero_image_url']),
      tags: _stringList(json['tags']),
      currencyCode: json['currencyCode']?.toString() ?? json['currency_code']?.toString() ?? 'USD',
    );
  }
}

class FoodMenuItem {
  final String id;
  final String category;
  final String name;
  final String description;
  final int priceCents;
  final String? imageUrl;
  final bool available;
  final List<String> tags;
  final List<FoodModifierGroup> modifierGroups;

  const FoodMenuItem({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.priceCents,
    this.imageUrl,
    this.available = true,
    this.tags = const <String>[],
    this.modifierGroups = const <FoodModifierGroup>[],
  });

  factory FoodMenuItem.fromJson(Map<String, dynamic> json) {
    final groups = json['modifierGroups'] ?? json['modifier_groups'];
    return FoodMenuItem(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Menu',
      name: json['name']?.toString() ?? 'Item',
      description: json['description']?.toString() ?? '',
      priceCents: _toInt(json['priceCents'] ?? json['price_cents']),
      imageUrl: _nullableString(json['imageUrl'] ?? json['image_url']),
      available: json['available'] == null ? true : json['available'] == true,
      tags: _stringList(json['tags']),
      modifierGroups: groups is List
          ? groups
              .whereType<Map>()
              .map((e) => FoodModifierGroup.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const <FoodModifierGroup>[],
    );
  }
}

class FoodModifierGroup {
  final String id;
  final String name;
  final bool required;
  final int minSelections;
  final int maxSelections;
  final List<FoodModifierOption> options;

  const FoodModifierGroup({
    required this.id,
    required this.name,
    this.required = false,
    this.minSelections = 0,
    this.maxSelections = 1,
    this.options = const <FoodModifierOption>[],
  });

  factory FoodModifierGroup.fromJson(Map<String, dynamic> json) {
    final options = json['options'];
    return FoodModifierGroup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Options',
      required: json['required'] == true,
      minSelections: _toInt(json['minSelections'] ?? json['min_selections']),
      maxSelections: _toInt(json['maxSelections'] ?? json['max_selections'], fallback: 1),
      options: options is List
          ? options
              .whereType<Map>()
              .map((e) => FoodModifierOption.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const <FoodModifierOption>[],
    );
  }
}

class FoodModifierOption {
  final String id;
  final String name;
  final int priceDeltaCents;

  const FoodModifierOption({
    required this.id,
    required this.name,
    this.priceDeltaCents = 0,
  });

  factory FoodModifierOption.fromJson(Map<String, dynamic> json) {
    return FoodModifierOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Option',
      priceDeltaCents: _toInt(json['priceDeltaCents'] ?? json['price_delta_cents']),
    );
  }
}

class FoodCartItem {
  final FoodMenuItem item;
  final int quantity;
  final List<FoodModifierOption> modifiers;

  const FoodCartItem({
    required this.item,
    required this.quantity,
    this.modifiers = const <FoodModifierOption>[],
  });

  int get unitPriceCents =>
      item.priceCents + modifiers.fold<int>(0, (sum, option) => sum + option.priceDeltaCents);

  int get totalCents => unitPriceCents * quantity;
}

class FoodPaymentMethod {
  final String id;
  final String label;
  final String brand;
  final String last4;
  final bool preferred;

  const FoodPaymentMethod({
    required this.id,
    required this.label,
    required this.brand,
    required this.last4,
    this.preferred = false,
  });

  factory FoodPaymentMethod.fromJson(Map<String, dynamic> json) {
    return FoodPaymentMethod(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? json['type']?.toString() ?? 'Payment method',
      brand: json['brand']?.toString() ?? '',
      last4: json['last4']?.toString() ?? '',
      preferred: json['preferred'] == true || json['isDefault'] == true,
    );
  }

  String get displayName {
    if (brand.isNotEmpty && last4.isNotEmpty) return '$brand •••• $last4';
    return label;
  }
}

class FoodOrderResult {
  final String id;
  final String status;
  final String restaurantName;
  final DateTime? estimatedDeliveryAt;
  final int etaMinMinutes;
  final int etaMaxMinutes;
  final String currencyCode;
  final int subtotalCents;
  final int taxCents;
  final int deliveryFeeCents;
  final int serviceFeeCents;
  final int discountCents;
  final int totalCents;
  final String fulfillmentMethod;
  final String? couponCode;
  final int pointsEarned;

  const FoodOrderResult({
    required this.id,
    required this.status,
    required this.restaurantName,
    this.estimatedDeliveryAt,
    this.etaMinMinutes = 30,
    this.etaMaxMinutes = 45,
    this.currencyCode = 'USD',
    this.subtotalCents = 0,
    this.taxCents = 0,
    this.deliveryFeeCents = 0,
    this.serviceFeeCents = 0,
    this.discountCents = 0,
    this.totalCents = 0,
    this.fulfillmentMethod = 'delivery',
    this.couponCode,
    this.pointsEarned = 0,
  });

  factory FoodOrderResult.fromJson(Map<String, dynamic> json) {
    final eta = json['estimatedDeliveryAt'] ?? json['estimated_delivery_at'];
    return FoodOrderResult(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'placed',
      restaurantName: json['restaurantName']?.toString() ?? json['restaurant_name']?.toString() ?? 'Restaurant',
      estimatedDeliveryAt: eta == null ? null : DateTime.tryParse(eta.toString()),
      etaMinMinutes: _toInt(json['etaMinMinutes'] ?? json['eta_min_minutes'], fallback: 30),
      etaMaxMinutes: _toInt(json['etaMaxMinutes'] ?? json['eta_max_minutes'], fallback: 45),
      currencyCode: json['currencyCode']?.toString() ?? json['currency_code']?.toString() ?? 'USD',
      subtotalCents: _toInt(json['subtotalCents'] ?? json['subtotal_cents']),
      taxCents: _toInt(json['taxCents'] ?? json['tax_cents']),
      deliveryFeeCents: _toInt(json['deliveryFeeCents'] ?? json['delivery_fee_cents']),
      serviceFeeCents: _toInt(json['serviceFeeCents'] ?? json['service_fee_cents']),
      discountCents: _toInt(json['discountCents'] ?? json['discount_cents']),
      totalCents: _toInt(json['totalCents'] ?? json['total_cents']),
      fulfillmentMethod: json['fulfillmentMethod']?.toString() ?? json['fulfillment_method']?.toString() ?? 'delivery',
      couponCode: _nullableString(json['couponCode'] ?? json['coupon_code']),
      pointsEarned: _toInt(json['pointsEarned'] ?? json['points_earned']),
    );
  }
}

class FoodDeliveryApi {
  final String baseUrl;
  final String? token;

  const FoodDeliveryApi({required this.baseUrl, required this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<List<FoodRestaurant>> findRestaurants({
    required double latitude,
    required double longitude,
    String query = '',
    double radiusKm = 10,
  }) async {
    final uri = Uri.parse('$baseUrl/food/restaurants/nearby').replace(
      queryParameters: {
        'lat': '$latitude',
        'lon': '$longitude',
        'radiusKm': '$radiusKm',
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final response = await http.get(uri, headers: _headers);
    final data = _decode(response);
    final raw = data['restaurants'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! List) {
      throw Exception(data['error']?.toString() ?? 'Unable to load nearby restaurants.');
    }
    return raw
        .whereType<Map>()
        .map((row) => FoodRestaurant.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<FoodRestaurant> getRestaurant(String restaurantId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/food/restaurants/${Uri.encodeComponent(restaurantId)}'),
      headers: _headers,
    );
    final data = _decode(response);
    final restaurant = data['restaurant'];
    if (response.statusCode < 200 || response.statusCode >= 300 || restaurant is! Map) {
      throw Exception(data['error']?.toString() ?? 'Unable to load restaurant.');
    }
    return FoodRestaurant.fromJson(Map<String, dynamic>.from(restaurant));
  }

  Future<Map<String, dynamic>?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$baseUrl/location/reverse').replace(
      queryParameters: {
        'lat': '$latitude',
        'lon': '$longitude',
      },
    );
    final response = await http.get(uri, headers: _headers);
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final location = data['location'];
    return location is Map ? Map<String, dynamic>.from(location) : null;
  }

  Future<List<FoodMenuItem>> getMenu(String restaurantId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/food/restaurants/${Uri.encodeComponent(restaurantId)}/menu'),
      headers: _headers,
    );
    final data = _decode(response);
    final raw = data['items'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! List) {
      throw Exception(data['error']?.toString() ?? 'Unable to load menu.');
    }
    return raw
        .whereType<Map>()
        .map((row) => FoodMenuItem.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<FoodPaymentMethod>> getPaymentMethods({
    String countryCode = '*',
    String currencyCode = 'USD',
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/food/payment-methods').replace(
        queryParameters: {
          'country': countryCode,
          'currency': currencyCode,
        },
      ),
      headers: _headers,
    );
    final data = _decode(response);
    final raw = data['paymentMethods'] ?? data['payment_methods'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! List) {
      throw Exception(data['error']?.toString() ?? 'Unable to load payment methods.');
    }
    return raw
        .whereType<Map>()
        .map((row) => FoodPaymentMethod.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> searchAddressSuggestions(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 3) {
      throw ArgumentError('Enter at least three characters for the address or city search.');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/location/address-suggestions').replace(
        queryParameters: {'q': cleanQuery},
      ),
      headers: _headers,
    );
    final data = _decode(response);
    final raw = data['suggestions'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! List) {
      throw Exception(data['error']?.toString() ?? 'Unable to search for this address.');
    }
    return raw.whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  Future<List<FoodRestaurant>> getMerchantRestaurants() async {
    final response = await http.get(
      Uri.parse('$baseUrl/food/merchant/restaurants'),
      headers: _headers,
    );
    final data = _decode(response);
    final raw = data['restaurants'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! List) {
      throw Exception(data['error']?.toString() ?? 'Unable to load your restaurants.');
    }
    return raw.whereType<Map>()
        .map((entry) => FoodRestaurant.fromJson(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
  }

  Future<FoodRestaurant> createMerchantRestaurant(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/food/merchant/restaurants'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    final restaurant = data['restaurant'];
    if (response.statusCode < 200 || response.statusCode >= 300 || restaurant is! Map) {
      throw Exception(data['error']?.toString() ?? 'Unable to register the restaurant.');
    }
    return FoodRestaurant.fromJson(Map<String, dynamic>.from(restaurant));
  }

  Future<String> uploadMerchantPhoto({
    required String restaurantId,
    required Uint8List bytes,
    required String contentType,
    String? menuItemId,
  }) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw Exception('Choose an image smaller than 5 MB.');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/food/merchant/restaurants/${Uri.encodeComponent(restaurantId)}/photo'),
      headers: _headers,
      body: jsonEncode({
        'imageBase64': base64Encode(bytes),
        'contentType': contentType,
        if (menuItemId != null && menuItemId.trim().isNotEmpty) 'menuItemId': menuItemId.trim(),
      }),
    );
    final data = _decode(response);
    final url = data['imageUrl']?.toString();
    if (response.statusCode < 200 || response.statusCode >= 300 || url == null || url.isEmpty) {
      throw Exception(data['error']?.toString() ?? 'Unable to upload the photo.');
    }
    return url;
  }

  Future<FoodMenuItem> addMerchantMenuItem(String restaurantId, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/food/merchant/restaurants/${Uri.encodeComponent(restaurantId)}/menu'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    final item = data['item'];
    if (response.statusCode < 200 || response.statusCode >= 300 || item is! Map) {
      throw Exception(data['error']?.toString() ?? 'Unable to add the menu item.');
    }
    return FoodMenuItem.fromJson(Map<String, dynamic>.from(item));
  }

  Future<Map<String, dynamic>> createMerchantCoupon(String restaurantId, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/food/merchant/restaurants/${Uri.encodeComponent(restaurantId)}/coupons'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    final coupon = data['coupon'];
    if (response.statusCode < 200 || response.statusCode >= 300 || coupon is! Map) {
      throw Exception(data['error']?.toString() ?? 'Unable to create the coupon.');
    }
    return Map<String, dynamic>.from(coupon);
  }

  Future<Map<String, dynamic>> validateCoupon({
    required String restaurantId,
    required String code,
    required int subtotalCents,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/food/restaurants/${Uri.encodeComponent(restaurantId)}/coupons/validate')
          .replace(queryParameters: {'code': code.trim(), 'subtotalCents': '$subtotalCents'}),
      headers: _headers,
    );
    final data = _decode(response);
    final coupon = data['coupon'];
    if (response.statusCode < 200 || response.statusCode >= 300 || coupon is! Map) {
      throw Exception(data['error']?.toString() ?? 'This coupon could not be applied.');
    }
    return Map<String, dynamic>.from(coupon);
  }

  Future<List<Map<String, dynamic>>> getLoyaltyBalances() async {
    final response = await http.get(Uri.parse('$baseUrl/food/loyalty'), headers: _headers);
    final data = _decode(response);
    final raw = data['balances'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! List) {
      throw Exception(data['error']?.toString() ?? 'Unable to load food rewards.');
    }
    return raw.whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  Future<FoodOrderResult> placeOrder({
    required String profileId,
    required String restaurantId,
    required List<FoodCartItem> items,
    required Map<String, dynamic> deliveryAddress,
    required String paymentMethodId,
    String deliveryNotes = '',
    String? viewingContext,
    String fulfillmentMethod = 'delivery',
    String couponCode = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/food/orders'),
      headers: _headers,
      body: jsonEncode({
        'profileId': profileId,
        'restaurantId': restaurantId,
        'paymentMethodId': paymentMethodId,
        'deliveryAddress': deliveryAddress,
        'deliveryNotes': deliveryNotes,
        'fulfillmentMethod': fulfillmentMethod,
        if (couponCode.trim().isNotEmpty) 'couponCode': couponCode.trim(),
        if (viewingContext != null && viewingContext.trim().isNotEmpty)
          'viewingContext': viewingContext.trim(),
        'items': items
            .map(
              (cartItem) => {
                'menuItemId': cartItem.item.id,
                'quantity': cartItem.quantity,
                'modifierIds': cartItem.modifiers.map((m) => m.id).toList(growable: false),
              },
            )
            .toList(growable: false),
      }),
    );
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'Unable to place food order.');
    }
    final order = data['order'];
    if (order is! Map) throw Exception('The order response was incomplete.');
    return FoodOrderResult.fromJson(Map<String, dynamic>.from(order));
  }

  Future<FoodOrderResult> getOrder(String orderId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/food/orders/${Uri.encodeComponent(orderId)}'),
      headers: _headers,
    );
    final data = _decode(response);
    final order = data['order'];
    if (response.statusCode < 200 || response.statusCode >= 300 || order is! Map) {
      throw Exception(data['error']?.toString() ?? 'Unable to load order status.');
    }
    return FoodOrderResult.fromJson(Map<String, dynamic>.from(order));
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

class FoodLocationService {
  Future<Position> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are turned off.');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to find nearby restaurants.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}

class FoodOrderingScreen extends StatefulWidget {
  final FoodDeliveryApi? api;
  final String? viewingContext;

  const FoodOrderingScreen({
    super.key,
    this.api,
    this.viewingContext,
  });

  @override
  State<FoodOrderingScreen> createState() => _FoodOrderingScreenState();
}

class _FoodOrderingScreenState extends State<FoodOrderingScreen> {
  late final FoodDeliveryApi _api;
  final FoodLocationService _locationService = FoodLocationService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalController = TextEditingController();

  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _locationLabel;
  List<FoodRestaurant> _restaurants = const [];
  List<Map<String, dynamic>> _loyaltyBalances = const [];
  bool _loading = true;
  bool _manualSearchLoading = false;
  String? _error;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    final backend = AppController.instance.backendApi;
    _api = widget.api ?? FoodDeliveryApi(baseUrl: backend.baseUrl, token: backend.token);
    _loadNearby();
    _loadRewards();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addressController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  Future<void> _loadRewards() async {
    try {
      final balances = await _api.getLoyaltyBalances();
      if (mounted) setState(() => _loyaltyBalances = balances);
    } catch (_) {
      // Rewards are optional while the food database/payment adapter is being configured.
    }
  }

  Future<void> _loadNearby({
    String query = '',
    double? latitude,
    double? longitude,
    String? locationLabel,
    bool forceDeviceLocation = false,
    double radiusKm = 10,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      double lat;
      double lon;
      String label;
      Position? currentPosition;
      if (latitude != null && longitude != null) {
        lat = latitude;
        lon = longitude;
        label = locationLabel ?? _locationLabel ?? 'Selected address';
        _selectedLatitude = lat;
        _selectedLongitude = lon;
        _locationLabel = label;
      } else if (!forceDeviceLocation &&
          _selectedLatitude != null &&
          _selectedLongitude != null) {
        lat = _selectedLatitude!;
        lon = _selectedLongitude!;
        label = _locationLabel ?? 'Selected address';
      } else {
        currentPosition = await _locationService.currentPosition();
        lat = currentPosition.latitude;
        lon = currentPosition.longitude;
        label = 'Your current location';
        try {
          final reverse = await _api.reverseGeocode(latitude: lat, longitude: lon);
          final reverseLabel = reverse?['label']?.toString().trim() ?? '';
          if (reverseLabel.isNotEmpty) label = reverseLabel;
        } catch (_) {}
      }
      _selectedLatitude = lat;
      _selectedLongitude = lon;
      _locationLabel = label;
      final restaurants = await _api.findRestaurants(
        latitude: lat,
        longitude: lon,
        query: query,
        radiusKm: radiusKm,
      );
      if (!mounted) return;
      setState(() {
        if (currentPosition != null)  _restaurants = restaurants;
        _loading = false;
        _activeQuery = query;
        _locationLabel = label;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _searchManualLocation() async {
    final parts = <String>[
      _addressController.text.trim(),
      _cityController.text.trim(),
      _stateController.text.trim(),
      _postalController.text.trim(),
      _countryController.text.trim(),
    ].where((part) => part.isNotEmpty).toList();
    final query = parts.join(', ');
    if (query.length < 3) {
      setState(() => _error = 'Enter at least a city and country, or a full address.');
      return;
    }
    setState(() {
      _manualSearchLoading = true;
      _error = null;
    });
    try {
      final suggestions = await _api.searchAddressSuggestions(query);
      final places = suggestions.where((place) =>
          place['latitude'] is num && place['longitude'] is num).toList(growable: false);
      if (!mounted) return;
      if (places.isEmpty) {
        setState(() => _error = 'No matching address was found. Try including the city and country.');
        return;
      }
      Map<String, dynamic>? chosen;
      if (places.length == 1) {
        chosen = places.first;
      } else {
        chosen = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Choose the location'),
            content: SizedBox(
              width: 520,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final place in places)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(place['label']?.toString() ?? 'Address'),
                      subtitle: Text([place['city'], place['state'], place['postalCode'], place['country']]
                          .where((value) => value != null && value.toString().isNotEmpty)
                          .join(', ')),
                      onTap: () => Navigator.pop(dialogContext, place),
                    ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel'))],
          ),
        );
      }
      if (chosen == null || !mounted) return;
      _addressController.text = chosen['addressLine1']?.toString() ?? _addressController.text;
      if ((chosen['city']?.toString() ?? '').isNotEmpty) _cityController.text = chosen['city'].toString();
      if ((chosen['state']?.toString() ?? '').isNotEmpty) _stateController.text = chosen['state'].toString();
      if ((chosen['postalCode']?.toString() ?? '').isNotEmpty) _postalController.text = chosen['postalCode'].toString();
      if ((chosen['country']?.toString() ?? '').isNotEmpty) _countryController.text = chosen['country'].toString();
      final label = chosen['label']?.toString() ?? query;
      await _loadNearby(
        query: _activeQuery,
        latitude: _toDouble(chosen['latitude']),
        longitude: _toDouble(chosen['longitude']),
        locationLabel: label,
        radiusKm: 50,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _manualSearchLoading = false);
    }
  }

  Future<void> _showExternalRestaurantDetails(FoodRestaurant restaurant) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(restaurant.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(restaurant.cuisine),
              const SizedBox(height: 8),
              if (restaurant.address.isNotEmpty || restaurant.city.isNotEmpty)
                Text([
                  restaurant.address,
                  restaurant.city,
                  restaurant.stateRegion,
                  restaurant.postalCode,
                  restaurant.countryCode,
                ].where((part) => part.trim().isNotEmpty).join(', ')),
              if (restaurant.distanceKm > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${restaurant.distanceKm.toStringAsFixed(1)} km away'),
                ),
              if (restaurant.phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SelectableText('Phone: ${restaurant.phone}'),
                ),
              if (restaurant.openingHours.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Listed hours: ${restaurant.openingHours}'),
                ),
              if ((restaurant.website ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SelectableText('Website: ${restaurant.website}'),
                ),
              const SizedBox(height: 12),
              const Text(
                'This is a public directory listing, not a restaurant enrolled in Food & Delivery. Its live menu, item prices, tax rules, and delivery options have not been confirmed on this platform. The owner must register the restaurant and add a menu before in-app ordering can be enabled.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Directory data © OpenStreetMap contributors.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _search() {
    _loadNearby(query: _searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food & Delivery'),
        actions: [
          IconButton(
            tooltip: 'Restaurant owner center',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FoodMerchantCenterScreen(api: _api),
              ),
            ),
            icon: const Icon(Icons.storefront_rounded),
          ),
          IconButton(
            tooltip: 'Refresh nearby restaurants',
            onPressed: _loading ? null : () => _loadNearby(query: _activeQuery),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNearby(query: _activeQuery),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            if (widget.viewingContext != null && widget.viewingContext!.trim().isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.live_tv_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.viewingContext!,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'What are you craving?',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _locationLabel == null
                  ? 'Use your device location or enter a country, state, city, postal code, or full address.'
                  : 'Showing restaurants near $_locationLabel',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : () => _loadNearby(query: _activeQuery, forceDeviceLocation: true),
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Use my current location'),
              ),
            ),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.location_city_rounded),
                title: const Text('Enter location manually'),
                subtitle: const Text('Country, state, city, ZIP/postal code, and street address'),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                children: [
                  TextField(
                    controller: _countryController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Country or country code'),
                  ),
                  TextField(
                    controller: _stateController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'State / province / region'),
                  ),
                  TextField(
                    controller: _cityController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  TextField(
                    controller: _postalController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'ZIP / postal code'),
                  ),
                  TextField(
                    controller: _addressController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchManualLocation(),
                    decoration: const InputDecoration(labelText: 'Street address (optional for city search)'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _manualSearchLoading ? null : _searchManualLocation,
                      icon: _manualSearchLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search_rounded),
                      label: Text(_manualSearchLoading ? 'Searching addresses…' : 'Find restaurants in this location'),
                    ),
                  ),
                ],
              ),
            ),
            if (_loyaltyBalances.isNotEmpty) ...[
              const SizedBox(height: 10),
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.loyalty_rounded),
                  title: const Text('Restaurant rewards'),
                  subtitle: Text('${_loyaltyBalances.fold<int>(0, (sum, balance) => sum + _toInt(balance['points']))} points across participating restaurants'),
                  children: [
                    for (final balance in _loyaltyBalances)
                      ListTile(
                        dense: true,
                        title: Text(balance['restaurantName']?.toString() ?? 'Restaurant'),
                        trailing: Text('${_toInt(balance['points'])} pts', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Nearby search combines platform restaurants with public OpenStreetMap directory listings. Directory data can be incomplete or outdated. Only restaurants with a platform menu can accept in-app orders; external listings must be registered by the owner and given menu/pricing first. Data © OpenStreetMap contributors (openstreetmap.org/copyright).',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search sushi, tacos, ramen, pizza…',
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final suggestion in const ['Sushi', 'Pizza', 'Mexican', 'Burgers', 'Thai'])
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () {
                      _searchController.text = suggestion;
                      _loadNearby(query: suggestion);
                    },
                  ),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator()),
            ],
            if (!_loading && _error != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Icon(Icons.location_off_rounded, size: 44),
                      const SizedBox(height: 10),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _loadNearby(query: _activeQuery),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (!_loading && _error == null) ...[
              const SizedBox(height: 18),
              Text(
                _activeQuery.isEmpty
                    ? 'Restaurants near you'
                    : 'Results for “$_activeQuery”',
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (_restaurants.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Center(child: Text('No nearby restaurants matched that search.')),
                  ),
                )
              else
                ..._restaurants.map(
                  (restaurant) => _RestaurantCard(
                    restaurant: restaurant,
                    onTap: () {
                      if (!restaurant.isOrderable) {
                        _showExternalRestaurantDetails(restaurant);
                        return;
                      }
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RestaurantMenuScreen(
                            api: _api,
                            restaurant: restaurant,
                            viewingContext: widget.viewingContext,
                            initialDeliveryAddress: {
                              'addressLine1': _addressController.text.trim(),
                              'label': _locationLabel ?? '',
                              'city': _cityController.text.trim(),
                              'state': _stateController.text.trim(),
                              'postalCode': _postalController.text.trim(),
                              'country': _countryController.text.trim(),
                              if (_selectedLatitude != null) 'latitude': _selectedLatitude,
                              if (_selectedLongitude != null) 'longitude': _selectedLongitude,
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final FoodRestaurant restaurant;
  final VoidCallback onTap;

  const _RestaurantCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: restaurant.isOrderable
          ? (restaurant.isOpen && (restaurant.allowsDelivery || restaurant.allowsPickup) ? onTap : null)
          : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2.25,
              child: restaurant.heroImageUrl == null
                  ? const ColoredBox(
                      color: Color(0xFF222222),
                      child: Center(child: Icon(Icons.restaurant_rounded, size: 46)),
                    )
                  : Image.network(
                      restaurant.heroImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFF222222),
                        child: Center(child: Icon(Icons.restaurant_rounded, size: 46)),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (!restaurant.isOrderable)
                        const Chip(label: Text('Directory listing'))
                      else if (!restaurant.isOpen)
                        const Chip(label: Text('Closed'))
                      else
                        Text(
                          '${restaurant.etaMinMinutes}-${restaurant.etaMaxMinutes} min',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(restaurant.cuisine, style: const TextStyle(color: Colors.white70)),
                  if (restaurant.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(restaurant.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (restaurant.isOrderable) ...[
                        const Icon(Icons.star_rounded, size: 17),
                        const SizedBox(width: 4),
                        Text('${restaurant.rating.toStringAsFixed(1)} (${restaurant.reviewCount})'),
                        const Spacer(),
                        Text(restaurant.allowsDelivery
                            ? 'Delivery ${_money(restaurant.deliveryFeeCents, restaurant.currencyCode)}'
                            : (restaurant.allowsPickup ? 'Pickup only' : 'Not accepting orders')),
                      ] else ...[
                        const Icon(Icons.public_rounded, size: 16),
                        const SizedBox(width: 5),
                        const Expanded(child: Text('Menu not yet available on this platform', style: TextStyle(color: Colors.white60, fontSize: 12))),
                      ],
                    ],
                  ),
                  if (restaurant.distanceKm > 0) ...[
                    const SizedBox(height: 5),
                    Text('${restaurant.distanceKm.toStringAsFixed(1)} km away', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                  if (restaurant.address.isNotEmpty || restaurant.city.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text([restaurant.address, restaurant.city, restaurant.stateRegion, restaurant.postalCode, restaurant.countryCode]
                        .where((part) => part.trim().isNotEmpty).join(', '),
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
                  ],
                  if (restaurant.phone.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(children: [const Icon(Icons.call_outlined, size: 15), const SizedBox(width: 5), Expanded(child: SelectableText(restaurant.phone, style: const TextStyle(color: Colors.white70, fontSize: 12)))])
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FoodMerchantCenterScreen extends StatefulWidget {
  final FoodDeliveryApi api;

  const FoodMerchantCenterScreen({super.key, required this.api});

  @override
  State<FoodMerchantCenterScreen> createState() => _FoodMerchantCenterScreenState();
}

class _FoodMerchantCenterScreenState extends State<FoodMerchantCenterScreen> {
  final _name = TextEditingController();
  final _cuisine = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postal = TextEditingController();
  final _country = TextEditingController();
  final _heroImage = TextEditingController();
  final _currency = TextEditingController(text: 'USD');
  final _deliveryFee = TextEditingController(text: '0.00');
  final _taxRate = TextEditingController(text: '0');
  final _minimumOrder = TextEditingController(text: '0.00');
  List<FoodRestaurant> _restaurants = const [];
  double? _latitude;
  double? _longitude;
  bool _allowsDelivery = true;
  bool _allowsPickup = true;
  bool _saving = false;
  bool _resolvingAddress = false;
  bool _loading = true;
  String? _error;
  String? _resolvedLabel;
  XFile? _selectedHeroPhoto;

  String? _imageContentType(XFile file) {
    final extension = file.name.toLowerCase().split('.').last;
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  Future<void> _chooseRestaurantPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1600);
    if (file != null && mounted) setState(() => _selectedHeroPhoto = file);
  }

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  @override
  void dispose() {
    for (final controller in [
      _name, _cuisine, _description, _phone, _address, _city, _state,
      _postal, _country, _heroImage, _currency, _deliveryFee,
      _taxRate, _minimumOrder,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int _moneyCents(String value) => ((double.tryParse(value.trim()) ?? 0) * 100).round();

  Future<void> _loadRestaurants() async {
    try {
      final restaurants = await widget.api.getMerchantRestaurants();
      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resolveAddress() async {
    final query = [
      _address.text.trim(), _city.text.trim(), _state.text.trim(),
      _postal.text.trim(), _country.text.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    if (query.length < 3) {
      setState(() => _error = 'Enter the street address or city details first.');
      return;
    }
    setState(() {
      _resolvingAddress = true;
      _error = null;
    });
    try {
      final suggestions = await widget.api.searchAddressSuggestions(query);
      final places = suggestions.where((place) =>
          place['latitude'] is num && place['longitude'] is num).toList(growable: false);
      if (!mounted) return;
      if (places.isEmpty) {
        setState(() => _error = 'The address provider could not locate that restaurant. Check the city and country.');
        return;
      }
      Map<String, dynamic>? place;
      if (places.length == 1) {
        place = places.first;
      } else {
        place = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm restaurant location'),
            content: SizedBox(
              width: 520,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in places)
                    ListTile(
                      leading: const Icon(Icons.place_rounded),
                      title: Text(option['label']?.toString() ?? 'Location'),
                      subtitle: Text([option['city'], option['state'], option['postalCode'], option['country']]
                          .where((value) => value != null && value.toString().trim().isNotEmpty)
                          .join(', ')),
                      onTap: () => Navigator.pop(dialogContext, option),
                    ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel'))],
          ),
        );
      }
      final selectedPlace = place;
      if (selectedPlace == null || !mounted) return;
      setState(() {
        _latitude = _toDouble(selectedPlace['latitude']);
        _longitude = _toDouble(selectedPlace['longitude']);
        _resolvedLabel = selectedPlace['label']?.toString();
        if ((selectedPlace['addressLine1']?.toString() ?? '').isNotEmpty) _address.text = selectedPlace['addressLine1'].toString();
        if ((selectedPlace['city']?.toString() ?? '').isNotEmpty) _city.text = selectedPlace['city'].toString();
        if ((selectedPlace['state']?.toString() ?? '').isNotEmpty) _state.text = selectedPlace['state'].toString();
        if ((selectedPlace['postalCode']?.toString() ?? '').isNotEmpty) _postal.text = selectedPlace['postalCode'].toString();
        if ((selectedPlace['countryCode']?.toString() ?? '').isNotEmpty) _country.text = selectedPlace['countryCode'].toString();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _resolvingAddress = false);
    }
  }

  Future<void> _createRestaurant() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty || _cuisine.text.trim().isEmpty || _address.text.trim().isEmpty) {
      setState(() => _error = 'Restaurant name, cuisine, and street address are required.');
      return;
    }
    if (_latitude == null || _longitude == null) {
      setState(() => _error = 'Use “Resolve address” and choose a matching location before saving.');
      return;
    }
    if (!_allowsDelivery && !_allowsPickup) {
      setState(() => _error = 'Enable delivery, pickup, or both.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var restaurant = await widget.api.createMerchantRestaurant({
        'name': _name.text.trim(),
        'cuisine': _cuisine.text.trim(),
        'description': _description.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'stateRegion': _state.text.trim(),
        'postalCode': _postal.text.trim(),
        'countryCode': _country.text.trim().length == 2 ? _country.text.trim().toUpperCase() : '',
        'latitude': _latitude,
        'longitude': _longitude,
        'heroImageUrl': _heroImage.text.trim(),
        'currencyCode': _currency.text.trim().toUpperCase(),
        'deliveryFeeCents': _moneyCents(_deliveryFee.text),
        'taxRateBasisPoints': ((double.tryParse(_taxRate.text.trim()) ?? 0) * 100).round(),
        'minimumOrderCents': _moneyCents(_minimumOrder.text),
        'allowsDelivery': _allowsDelivery,
        'allowsPickup': _allowsPickup,
        'loyaltyPointsPerCurrency': 1,
      });
      String? photoWarning;
      final photo = _selectedHeroPhoto;
      if (photo != null && _heroImage.text.trim().isEmpty) {
        try {
          final mime = _imageContentType(photo);
          if (mime == null) throw Exception('Restaurant photos must be JPG, PNG, or WebP.');
          await widget.api.uploadMerchantPhoto(
            restaurantId: restaurant.id,
            bytes: await photo.readAsBytes(),
            contentType: mime,
          );
          final refreshed = await widget.api.getMerchantRestaurants();
          final updated = refreshed.where((entry) => entry.id == restaurant.id).toList();
          if (updated.isNotEmpty) restaurant = updated.first;
        } catch (error) {
          photoWarning = error.toString().replaceFirst('Exception: ', '');
        }
      }
      if (!mounted) return;
      setState(() {
        _restaurants = [restaurant, ..._restaurants.where((entry) => entry.id != restaurant.id)];
        _name.clear();
        _cuisine.clear();
        _description.clear();
        _phone.clear();
        _address.clear();
        _city.clear();
        _state.clear();
        _postal.clear();
        _heroImage.clear();
        _latitude = null;
        _longitude = null;
        _resolvedLabel = null;
        _selectedHeroPhoto = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(photoWarning == null
            ? 'Restaurant registered. Add menu items and coupons below.'
            : 'Restaurant saved, but the photo could not be uploaded: $photoWarning'),
      ));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addMenuItem(FoodRestaurant restaurant) async {
    final name = TextEditingController();
    final category = TextEditingController(text: 'Main');
    final description = TextEditingController();
    final price = TextEditingController();
    final imageUrl = TextEditingController();
    XFile? pickedPhoto;
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Add menu item · ${restaurant.name}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')),
                TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
                TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Price (${restaurant.currencyCode})')),
                TextField(controller: imageUrl, decoration: const InputDecoration(labelText: 'Photo URL (optional)')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1600);
                    if (file != null) setDialogState(() => pickedPhoto = file);
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(pickedPhoto == null ? 'Choose photo from device' : pickedPhoto!.name),
                ),
                const SizedBox(height: 4),
                const Text('Choose a local JPG, PNG, or WebP photo, or paste a publicly accessible image URL.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, {
              'name': name.text.trim(), 'category': category.text.trim(),
              'description': description.text.trim(), 'price': price.text.trim(),
              'imageUrl': imageUrl.text.trim(),
            }), child: const Text('Add item')),
          ],
        ),
      ),
    );
    name.dispose(); category.dispose(); description.dispose(); price.dispose(); imageUrl.dispose();
    if (values == null || values['name']!.isEmpty) return;
    final parsedPrice = double.tryParse(values['price'] ?? '');
    if (parsedPrice == null || parsedPrice < 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid item price.')));
      return;
    }
    try {
      final item = await widget.api.addMerchantMenuItem(restaurant.id, {
        'name': values['name'],
        'category': values['category']!.isEmpty ? 'Menu' : values['category'],
        'description': values['description'],
        'priceCents': (parsedPrice * 100).round(),
        'imageUrl': values['imageUrl'],
        'available': true,
      });
      final photo = pickedPhoto;
      if (photo != null && values['imageUrl']!.isEmpty) {
        final mime = _imageContentType(photo);
        if (mime == null) throw Exception('Menu photos must be JPG, PNG, or WebP.');
        await widget.api.uploadMerchantPhoto(
          restaurantId: restaurant.id,
          menuItemId: item.id,
          bytes: await photo.readAsBytes(),
          contentType: mime,
        );
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menu item added.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _addCoupon(FoodRestaurant restaurant) async {
    final code = TextEditingController();
    final percent = TextEditingController(text: '10');
    final description = TextEditingController(text: '10% off');
    final minimum = TextEditingController(text: '0');
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Create coupon · ${restaurant.name}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Coupon code', hintText: 'WELCOME10')),
              TextField(controller: percent, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount percent', suffixText: '%')),
              TextField(controller: description, decoration: const InputDecoration(labelText: 'Description shown to customers')),
              TextField(controller: minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Minimum order (${restaurant.currencyCode})')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, {
            'code': code.text.trim(), 'percent': percent.text.trim(),
            'description': description.text.trim(), 'minimum': minimum.text.trim(),
          }), child: const Text('Create coupon')),
        ],
      ),
    );
    code.dispose(); percent.dispose(); description.dispose(); minimum.dispose();
    if (values == null) return;
    final discount = int.tryParse(values['percent'] ?? '');
    final minimumOrder = double.tryParse(values['minimum'] ?? '0');
    if (discount == null || discount < 1 || discount > 100 || minimumOrder == null || minimumOrder < 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a discount from 1–100% and a valid minimum.')));
      return;
    }
    try {
      await widget.api.createMerchantCoupon(restaurant.id, {
        'code': values['code'],
        'discountPercent': discount,
        'description': values['description'],
        'minimumSubtotalCents': (minimumOrder * 100).round(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Coupon ${values['code']!.toUpperCase()} created.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Widget _field(TextEditingController controller, String label, {String? hint, TextInputType? keyboardType, int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Owner Center')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const Text('List your restaurant independently of your streaming server', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Each account can own restaurants in any city. Add your location, contact details, menu and photo links, set fees/tax configuration, and publish coupons.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Register a restaurant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _field(_name, 'Restaurant name'),
                _field(_cuisine, 'Cuisine / food type', hint: 'Mexican, pizza, sushi…'),
                _field(_description, 'Description', maxLines: 3),
                _field(_phone, 'Restaurant phone number', keyboardType: TextInputType.phone),
                _field(_address, 'Street address'),
                _field(_city, 'City'),
                _field(_state, 'State / province / region'),
                _field(_postal, 'ZIP / postal code'),
                _field(_country, 'Country or ISO-2 code', hint: 'US, MX, CA…'),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resolvingAddress ? null : _resolveAddress,
                    icon: _resolvingAddress ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.map_outlined),
                    label: Text(_resolvingAddress ? 'Resolving location…' : 'Resolve address and map location'),
                  ),
                ),
                if (_resolvedLabel != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Location confirmed: $_resolvedLabel', style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 12))),
                _field(_heroImage, 'Restaurant photo URL (HTTPS)'),
                OutlinedButton.icon(onPressed: _chooseRestaurantPhoto, icon: const Icon(Icons.photo_library_outlined), label: Text(_selectedHeroPhoto == null ? 'Choose restaurant photo from device' : _selectedHeroPhoto!.name)),
                if (_heroImage.text.trim().startsWith('http'))
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_heroImage.text.trim(), height: 140, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                _field(_currency, 'Currency code', hint: 'USD, MXN, CAD…'),
                _field(_deliveryFee, 'Delivery fee (0 for free)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('The platform service fee is set by MyOwnStreamingService and shown separately at checkout.', style: TextStyle(color: Colors.white60))),
                _field(_taxRate, 'Configured tax rate (%)', hint: 'Use the rate applicable to your jurisdiction', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                _field(_minimumOrder, 'Minimum order', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: _allowsDelivery, onChanged: (value) => setState(() => _allowsDelivery = value), title: const Text('Offer delivery')),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: _allowsPickup, onChanged: (value) => setState(() => _allowsPickup = value), title: const Text('Offer pickup'), subtitle: const Text('Pickup orders do not include a delivery fee.')),
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: const TextStyle(color: Colors.amber))),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: _saving ? null : _createRestaurant,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.storefront_rounded),
                  label: Text(_saving ? 'Saving restaurant…' : 'Save restaurant'),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Your restaurants', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (!_loading && _restaurants.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No restaurants registered to this account yet.'))),
          for (final restaurant in _restaurants)
            Card(
              child: ExpansionTile(
                leading: const CircleAvatar(child: Icon(Icons.restaurant_rounded)),
                title: Text(restaurant.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text([restaurant.cuisine, restaurant.city, restaurant.stateRegion].where((v) => v.isNotEmpty).join(' · ')),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: [
                  if (restaurant.phone.isNotEmpty) ListTile(leading: const Icon(Icons.call_outlined), title: Text(restaurant.phone), contentPadding: EdgeInsets.zero),
                  if (restaurant.address.isNotEmpty) ListTile(leading: const Icon(Icons.place_outlined), title: Text(restaurant.address), subtitle: Text([restaurant.city, restaurant.stateRegion, restaurant.postalCode, restaurant.countryCode].where((v) => v.isNotEmpty).join(', ')), contentPadding: EdgeInsets.zero),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Chip(label: Text('Delivery ${_money(restaurant.deliveryFeeCents, restaurant.currencyCode)}')),
                    Chip(label: Text('Service ${_money(restaurant.serviceFeeCents, restaurant.currencyCode)}')),
                    Chip(label: Text('Tax ${(restaurant.taxRateBasisPoints / 100).toStringAsFixed(2)}%')),
                    Chip(label: Text('Points ${restaurant.loyaltyPointsPerCurrency} / currency unit')),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _addMenuItem(restaurant), icon: const Icon(Icons.add_rounded), label: const Text('Add menu item'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _addCoupon(restaurant), icon: const Icon(Icons.discount_outlined), label: const Text('Create coupon'))),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


class RestaurantMenuScreen extends StatefulWidget {
  final FoodDeliveryApi api;
  final FoodRestaurant restaurant;
  final String? viewingContext;
  final Map<String, dynamic>? initialDeliveryAddress;

  const RestaurantMenuScreen({
    super.key,
    required this.api,
    required this.restaurant,
    this.viewingContext,
    this.initialDeliveryAddress,
  });

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  List<FoodMenuItem> _items = const [];
  final List<FoodCartItem> _cart = [];
  bool _loading = true;
  String? _error;
  String _category = 'All';

  int get _subtotalCents => _cart.fold<int>(0, (sum, item) => sum + item.totalCents);
  int get _deliveryCents => widget.restaurant.deliveryFeeCents;
  int get _totalCents => _subtotalCents + _deliveryCents;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final items = await widget.api.getMenu(widget.restaurant.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _add(FoodMenuItem item) {
    final existingIndex = _cart.indexWhere((entry) => entry.item.id == item.id && entry.modifiers.isEmpty);
    setState(() {
      if (existingIndex >= 0) {
        final existing = _cart[existingIndex];
        _cart[existingIndex] = FoodCartItem(item: item, quantity: existing.quantity + 1);
      } else {
        _cart.add(FoodCartItem(item: item, quantity: 1));
      }
    });
  }


  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FoodCheckoutScreen(
          api: widget.api,
          restaurant: widget.restaurant,
          cart: List<FoodCartItem>.from(_cart),
          viewingContext: widget.viewingContext,
          initialDeliveryAddress: widget.initialDeliveryAddress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{'All', ..._items.map((item) => item.category)}.toList();
    final visible = _category == 'All' ? _items : _items.where((item) => item.category == _category).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.restaurant.name)),
      bottomNavigationBar: _cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: FilledButton.icon(
                  onPressed: _checkout,
                  icon: const Icon(Icons.shopping_bag_rounded),
                  label: Text('View cart • ${_cart.fold<int>(0, (sum, e) => sum + e.quantity)} items • ${_money(_totalCents, widget.restaurant.currencyCode)}'),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [
                    if (widget.restaurant.heroImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(widget.restaurant.heroImageUrl!, height: 180, fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 12),
                    Text(widget.restaurant.cuisine, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.restaurant.etaMinMinutes}-${widget.restaurant.etaMaxMinutes} min delivery • ${_money(widget.restaurant.deliveryFeeCents, widget.restaurant.currencyCode)} delivery',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    if (widget.viewingContext != null) ...[
                      const SizedBox(height: 8),
                      Chip(avatar: const Icon(Icons.live_tv_rounded), label: Text(widget.viewingContext!)),
                    ],
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final category in categories)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(category),
                                selected: _category == category,
                                onSelected: (_) => setState(() => _category = category),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final item in visible)
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: item.imageUrl == null
                              ? const CircleAvatar(child: Icon(Icons.restaurant_menu_rounded))
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(item.imageUrl!, width: 68, height: 68, fit: BoxFit.cover),
                                ),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_money(item.priceCents, widget.restaurant.currencyCode), style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 5),
                              FilledButton(
                                onPressed: item.available ? () => _add(item) : null,
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class FoodCheckoutScreen extends StatefulWidget {
  final FoodDeliveryApi api;
  final FoodRestaurant restaurant;
  final List<FoodCartItem> cart;
  final String? viewingContext;
  final Map<String, dynamic>? initialDeliveryAddress;

  const FoodCheckoutScreen({
    super.key,
    required this.api,
    required this.restaurant,
    required this.cart,
    this.viewingContext,
    this.initialDeliveryAddress,
  });

  @override
  State<FoodCheckoutScreen> createState() => _FoodCheckoutScreenState();
}

class _FoodCheckoutScreenState extends State<FoodCheckoutScreen> {
  final FoodLocationService _locationService = FoodLocationService();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _postalController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  List<FoodPaymentMethod> _paymentMethods = const [];
  FoodPaymentMethod? _selectedPayment;
  Position? _position;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  bool _loading = true;
  bool _placing = false;
  bool _couponBusy = false;
  String? _error;
  String? _couponMessage;
  String _fulfillmentMethod = 'delivery';
  String? _appliedCouponCode;
  int _couponDiscountCents = 0;

  int get _subtotalCents => widget.cart.fold<int>(0, (sum, item) => sum + item.totalCents);
  int get _taxableSubtotalCents => math.max(0, _subtotalCents - _couponDiscountCents);
  int get _taxCents => (_taxableSubtotalCents * widget.restaurant.taxRateBasisPoints / 10000).round();
  int get _serviceFeeCents => math.max(0, widget.restaurant.serviceFeeCents);
  int get _deliveryFeeCents => _fulfillmentMethod == 'delivery' ? math.max(0, widget.restaurant.deliveryFeeCents) : 0;
  int get _totalCents => _taxableSubtotalCents + _taxCents + _serviceFeeCents + _deliveryFeeCents;
  int get _estimatedPoints => (_taxableSubtotalCents ~/ 100) * math.max(0, widget.restaurant.loyaltyPointsPerCurrency);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDeliveryAddress;
    if (initial != null) {
      _addressController.text = initial['addressLine1']?.toString() ?? initial['label']?.toString() ?? '';
      _cityController.text = initial['city']?.toString() ?? '';
      _stateController.text = initial['state']?.toString() ?? initial['stateRegion']?.toString() ?? '';
      _postalController.text = initial['postalCode']?.toString() ?? '';
      _countryController.text = initial['country']?.toString() ?? initial['countryCode']?.toString() ?? '';
      if (initial['latitude'] is num && initial['longitude'] is num) {
        _deliveryLatitude = (initial['latitude'] as num).toDouble();
        _deliveryLongitude = (initial['longitude'] as num).toDouble();
      }
    }
    _fulfillmentMethod = widget.restaurant.allowsDelivery ? 'delivery' : 'pickup';
    _loadCheckout();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalController.dispose();
    _countryController.dispose();
    _couponController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckout() async {
    Position? position;
    Map<String, dynamic>? location;
    final hasSelectedLocation = _deliveryLatitude != null || _addressController.text.trim().isNotEmpty;
    try {
      position = await _locationService.currentPosition();
      try {
        location = await widget.api.reverseGeocode(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (_countryController.text.trim().isEmpty) {
          _countryController.text = location?['country']?.toString() ?? location?['countryCode']?.toString() ?? '';
        }
        if (!hasSelectedLocation) {
          final label = location?['label']?.toString().trim() ?? '';
          if (label.isNotEmpty) {
            _addressController.text = label;
            _deliveryLatitude = position.latitude;
            _deliveryLongitude = position.longitude;
          }
        }
      } catch (_) {}
    } catch (_) {
      // GPS is optional: manual address entry and pickup must remain available.
    }

    try {
      final cc = widget.restaurant.countryCode.trim().toUpperCase();
      final methods = await widget.api.getPaymentMethods(
        countryCode: cc.isEmpty ? '*' : cc,
        currencyCode: widget.restaurant.currencyCode,
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _paymentMethods = methods;
        _selectedPayment = methods.firstWhere(
          (method) => method.preferred,
          orElse: () => methods.isEmpty
              ? const FoodPaymentMethod(id: '', label: '', brand: '', last4: '')
              : methods.first,
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _position = position;
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _couponMessage = 'Enter a coupon code first.';
        _couponDiscountCents = 0;
        _appliedCouponCode = null;
      });
      return;
    }
    setState(() {
      _couponBusy = true;
      _couponMessage = null;
      _error = null;
    });
    try {
      final coupon = await widget.api.validateCoupon(
        restaurantId: widget.restaurant.id,
        code: code,
        subtotalCents: _subtotalCents,
      );
      final percent = int.tryParse('${coupon['discountPercent'] ?? coupon['discount_percent'] ?? 0}') ?? 0;
      final discount = (_subtotalCents * percent / 100).round();
      if (!mounted) return;
      setState(() {
        _appliedCouponCode = code;
        _couponDiscountCents = discount;
        _couponMessage = '${coupon['description']?.toString().trim().isNotEmpty == true ? coupon['description'] : '$percent% off'} applied.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _appliedCouponCode = null;
        _couponDiscountCents = 0;
        _couponMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _couponBusy = false);
    }
  }

  Future<void> _placeOrder() async {
    final profileId = AppController.instance.currentProfile?.id;
    if (profileId == null || profileId.isEmpty) {
      setState(() => _error = 'Select a profile before placing a food order.');
      return;
    }
    final payment = _selectedPayment;
    if (payment == null || payment.id.isEmpty) {
      setState(() => _error = 'Select a saved payment method before placing the order.');
      return;
    }
    if (_fulfillmentMethod == 'delivery' && _addressController.text.trim().isEmpty) {
      setState(() => _error = 'Enter the house/building number and street address for delivery. GPS or a city selection alone is not a delivery address.');
      return;
    }

    setState(() {
      _placing = true;
      _error = null;
    });

    try {
      final address = <String, dynamic>{
        'label': [
          _addressController.text.trim(),
          _cityController.text.trim(),
          _stateController.text.trim(),
          _postalController.text.trim(),
          _countryController.text.trim(),
        ].where((part) => part.isNotEmpty).join(', '),
        if (_addressController.text.trim().isNotEmpty) 'addressLine1': _addressController.text.trim(),
        if (_cityController.text.trim().isNotEmpty) 'city': _cityController.text.trim(),
        if (_stateController.text.trim().isNotEmpty) 'state': _stateController.text.trim(),
        if (_postalController.text.trim().isNotEmpty) 'postalCode': _postalController.text.trim(),
        if (_countryController.text.trim().isNotEmpty) 'country': _countryController.text.trim(),
        if (_deliveryLatitude != null && _deliveryLongitude != null) ...{
          'latitude': _deliveryLatitude,
          'longitude': _deliveryLongitude,
        },
      };
      if (_fulfillmentMethod == 'pickup') {
        address['pickupRestaurantAddress'] = widget.restaurant.address;
        address['pickupRestaurantName'] = widget.restaurant.name;
      }
      final order = await widget.api.placeOrder(
        profileId: profileId,
        restaurantId: widget.restaurant.id,
        items: widget.cart,
        deliveryAddress: _fulfillmentMethod == 'delivery' ? address : <String, dynamic>{},
        paymentMethodId: payment.id,
        deliveryNotes: _notesController.text.trim(),
        viewingContext: widget.viewingContext,
        fulfillmentMethod: _fulfillmentMethod,
        couponCode: _appliedCouponCode ?? '',
      );
      if (!mounted) return;
      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(builder: (_) => FoodOrderStatusScreen(api: widget.api, order: order)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _placing = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _addressField(TextEditingController controller, String label, {String? hint, TextInputType? keyboardType}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final canDeliver = widget.restaurant.allowsDelivery;
    final canPickup = widget.restaurant.allowsPickup;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      bottomNavigationBar: _loading || (_error != null && _paymentMethods.isEmpty)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: FilledButton.icon(
                  onPressed: _placing ? null : _placeOrder,
                  icon: _placing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.lock_rounded),
                  label: Text('${_fulfillmentMethod == 'pickup' ? 'Place pickup order' : 'Pay'} ${_money(_totalCents, widget.restaurant.currencyCode)}'),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                Text(widget.restaurant.name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(widget.restaurant.address, style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 14),
                if (canDeliver && canPickup)
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(value: 'delivery', label: Text('Delivery'), icon: Icon(Icons.delivery_dining_rounded)),
                      ButtonSegment<String>(value: 'pickup', label: Text('Pickup'), icon: Icon(Icons.storefront_rounded)),
                    ],
                    selected: {_fulfillmentMethod},
                    onSelectionChanged: (selection) => setState(() {
                      _fulfillmentMethod = selection.first;
                      _couponMessage = null;
                    }),
                  ),
                if (_fulfillmentMethod == 'pickup')
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.storefront_rounded),
                      title: const Text('Pick up at the restaurant'),
                      subtitle: Text('${widget.restaurant.address}${widget.restaurant.city.isEmpty ? '' : ', ${widget.restaurant.city}'}${widget.restaurant.phone.isEmpty ? '' : '\n${widget.restaurant.phone}'}\nNo delivery fee is charged for pickup.'),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Delivery address', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        _addressField(_addressController, 'Street address', hint: 'House number and street'),
                        _addressField(_cityController, 'City'),
                        _addressField(_stateController, 'State / province / region'),
                        _addressField(_postalController, 'Postal / ZIP code'),
                        _addressField(_countryController, 'Country'),
                        Text(_position == null ? 'GPS unavailable — address entry still works.' : 'Device location available for delivery matching.', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 8),
                        TextField(controller: _notesController, maxLines: 2, decoration: const InputDecoration(prefixIcon: Icon(Icons.notes_rounded), hintText: 'Delivery instructions (optional)')),
                      ]),
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Restaurant coupon', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextField(controller: _couponController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Coupon code', hintText: 'WELCOME10'))),
                        const SizedBox(width: 8),
                        FilledButton.tonal(onPressed: _couponBusy ? null : _applyCoupon, child: _couponBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Apply')),
                      ]),
                      if (_couponMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_couponMessage!, style: TextStyle(color: _appliedCouponCode != null ? Colors.lightGreenAccent : Colors.amber))),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Payment', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      if (_paymentMethods.isEmpty)
                        const Text('No saved payment methods are available. Add one in account payment settings first.', style: TextStyle(color: Colors.white60))
                      else
                        RadioGroup<FoodPaymentMethod>(
                          groupValue: _selectedPayment,
                          onChanged: (value) => setState(() => _selectedPayment = value),
                          child: Column(children: [
                            for (final method in _paymentMethods)
                              RadioListTile<FoodPaymentMethod>(
                                value: method,
                                title: Text(method.displayName),
                                subtitle: method.preferred ? const Text('Preferred') : null,
                                contentPadding: EdgeInsets.zero,
                              ),
                          ]),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      for (final item in widget.cart)
                        _SummaryLine(label: '${item.quantity} × ${item.item.name}', value: _money(item.totalCents, widget.restaurant.currencyCode)),
                      const Divider(height: 22),
                      _SummaryLine(label: 'Restaurant subtotal', value: _money(_subtotalCents, widget.restaurant.currencyCode)),
                      if (_couponDiscountCents > 0)
                        _SummaryLine(label: 'Coupon ${_appliedCouponCode ?? ''}', value: '−${_money(_couponDiscountCents, widget.restaurant.currencyCode)}'),
                      _SummaryLine(label: 'Estimated tax', value: _money(_taxCents, widget.restaurant.currencyCode)),
                      _SummaryLine(label: 'Platform service fee', value: _money(_serviceFeeCents, widget.restaurant.currencyCode)),
                      if (_fulfillmentMethod == 'delivery') _SummaryLine(label: 'Delivery fee', value: _money(_deliveryFeeCents, widget.restaurant.currencyCode)),
                      const Divider(height: 16),
                      _SummaryLine(label: 'Total', value: _money(_totalCents, widget.restaurant.currencyCode), bold: true),
                      const SizedBox(height: 8),
                      Text('Estimated rewards: $_estimatedPoints points for this order', style: const TextStyle(color: Colors.lightGreenAccent)),
                      if (_fulfillmentMethod == 'delivery') Padding(padding: const EdgeInsets.only(top: 6), child: Text('${widget.restaurant.etaMinMinutes}-${widget.restaurant.etaMaxMinutes} min estimated delivery', style: const TextStyle(color: Colors.white60))),
                      if (widget.restaurant.minimumOrderCents > 0 && _subtotalCents < widget.restaurant.minimumOrderCents)
                        Padding(padding: const EdgeInsets.only(top: 8), child: Text('Minimum order: ${_money(widget.restaurant.minimumOrderCents, widget.restaurant.currencyCode)}', style: const TextStyle(color: Colors.amber))),
                    ]),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.amber)),
                ],
              ],
            ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryLine({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 17 : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class FoodOrderStatusScreen extends StatefulWidget {
  final FoodDeliveryApi api;
  final FoodOrderResult order;

  const FoodOrderStatusScreen({
    super.key,
    required this.api,
    required this.order,
  });

  @override
  State<FoodOrderStatusScreen> createState() => _FoodOrderStatusScreenState();
}

class _FoodOrderStatusScreenState extends State<FoodOrderStatusScreen> {
  late FoodOrderResult _order;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final order = await widget.api.getOrder(_order.id);
      if (!mounted) return;
      setState(() => _order = order);
    } catch (_) {
      // Keep the most recent known status visible when a refresh temporarily fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? get _eta => _order.estimatedDeliveryAt;

  @override
  Widget build(BuildContext context) {
    final etaLabel = _eta == null
        ? '${_order.etaMinMinutes}-${_order.etaMaxMinutes} min'
        : TimeOfDay.fromDateTime(_eta!.toLocal()).format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Order tracking')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
          children: [
            const Icon(Icons.delivery_dining_rounded, size: 74),
            const SizedBox(height: 12),
            Text(_order.restaurantName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Order #${_order.id}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Text('Estimated time:', style: TextStyle(color: Colors.white60)),
                    const SizedBox(height: 5),
                    Text(etaLabel, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    Text(_statusLabel(_order.status), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _TrackingStep(label: 'Order placed', active: _statusRank(_order.status) >= 1),
                    _TrackingStep(label: _order.fulfillmentMethod == 'pickup' ? 'Restaurant confirmed' : 'Restaurant confirmed', active: _statusRank(_order.status) >= 2),
                    _TrackingStep(label: 'Preparing your food', active: _statusRank(_order.status) >= 3),
                    if (_order.fulfillmentMethod == 'pickup')
                      _TrackingStep(label: 'Ready for pickup', active: _statusRank(_order.status) >= 4, last: true)
                    else ...[
                      _TrackingStep(label: 'Courier picked it up', active: _statusRank(_order.status) >= 4),
                      _TrackingStep(label: 'Arriving', active: _statusRank(_order.status) >= 5),
                      _TrackingStep(label: 'Delivered', active: _statusRank(_order.status) >= 6, last: true),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const Align(alignment: Alignment.centerLeft, child: Text('Order total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                  const SizedBox(height: 8),
                  _SummaryLine(label: 'Restaurant subtotal', value: _money(_order.subtotalCents, _order.currencyCode)),
                  if (_order.discountCents > 0) _SummaryLine(label: 'Coupon ${_order.couponCode ?? ''}', value: '−${_money(_order.discountCents, _order.currencyCode)}'),
                  _SummaryLine(label: 'Tax', value: _money(_order.taxCents, _order.currencyCode)),
                  _SummaryLine(label: 'Platform service fee', value: _money(_order.serviceFeeCents, _order.currencyCode)),
                  if (_order.fulfillmentMethod == 'delivery') _SummaryLine(label: 'Delivery fee', value: _money(_order.deliveryFeeCents, _order.currencyCode)),
                  const Divider(height: 20),
                  _SummaryLine(label: _order.fulfillmentMethod == 'pickup' ? 'Pickup total' : 'Total', value: _money(_order.totalCents, _order.currencyCode), bold: true),
                  if (_order.pointsEarned > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('You earned ${_order.pointsEarned} restaurant reward points.', style: const TextStyle(color: Colors.lightGreenAccent))),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _order.fulfillmentMethod == 'pickup'
                  ? 'We will update the order when it is ready for pickup.'
                  : 'Your movie marathon can keep going while the food is on the way.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : _refresh,
              icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded),
              label: const Text('Refresh status'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingStep extends StatelessWidget {
  final String label;
  final bool active;
  final bool last;

  const _TrackingStep({required this.label, required this.active, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 10,
              child: active ? const Icon(Icons.check_rounded, size: 13) : null,
            ),
            if (!last)
              Container(width: 2, height: 34, color: Colors.white12),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 18),
            child: Text(label, style: TextStyle(fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? Colors.white : Colors.white38)),
          ),
        ),
      ],
    );
  }
}

String _money(int cents, String currencyCode) {
  final code = currencyCode.toUpperCase();
  final symbol = switch (code) {
    'MXN' => 'MX\$',
    'CAD' => 'CA\$',
    'AUD' => 'A\$',
    'GBP' => '£',
    'EUR' => '€',
    'JPY' => '¥',
    'CNY' => '¥',
    _ => '\$',
  };
  final divisor = code == 'JPY' ? 1 : 100;
  final amount = cents / divisor;
  return '$symbol${amount.toStringAsFixed(code == 'JPY' ? 0 : 2)}';
}

String _statusLabel(String status) => switch (status) {
      'placed' => 'Order placed',
      'confirmed' => 'Restaurant confirmed',
      'preparing' => 'Preparing',
      'picked_up' => 'Courier picked it up',
      'arriving' => 'Arriving soon',
      'delivered' => 'Delivered',
      'ready_for_pickup' => 'Ready for pickup',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' '),
    };

int _statusRank(String status) => switch (status) {
      'placed' => 1,
      'confirmed' => 2,
      'preparing' => 3,
      'picked_up' => 4,
      'arriving' => 5,
      'delivered' => 6,
      'ready_for_pickup' => 4,
      _ => 0,
    };

String? _nullableString(dynamic value) {
  final result = value?.toString().trim();
  return result == null || result.isEmpty ? null : result;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList(growable: false);
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

// Keep the helper referenced by generated UI code without introducing an extra dependency.
// This is deliberately private to this module.
// ignore: unused_element
 double _distanceKm(double aLat, double aLon, double bLat, double bLon) {
  const radius = 6371.0;
  final dLat = (bLat - aLat) * math.pi / 180.0;
  final dLon = (bLon - aLon) * math.pi / 180.0;
  final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(aLat * math.pi / 180.0) *
          math.cos(bLat * math.pi / 180.0) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return radius * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
}
