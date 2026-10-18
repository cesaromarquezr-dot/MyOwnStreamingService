import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';

import 'app_core.dart';
import 'localization.dart';
import 'page_customization_button.dart';

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
  final Map<String, dynamic> businessHours;
  final List<String> contactMethods;
  final String? contactEmail;
  final String? whatsappNumber;
  final String? imessageAddress;
  final String? smsNumber;
  final bool is24_7;
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
    this.businessHours = const <String, dynamic>{},
    this.contactMethods = const <String>['call'],
    this.contactEmail,
    this.whatsappNumber,
    this.imessageAddress,
    this.smsNumber,
    this.is24_7 = false,
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
      businessHours: _stringMap(json['businessHours'] ?? json['business_hours']),
      contactMethods: _stringList(json['contactMethods'] ?? json['contact_methods']).isEmpty
          ? <String>[(json['phone']?.toString().trim().isNotEmpty == true) ? 'call' : ''].where((item) => item.isNotEmpty).toList(growable: false)
          : _stringList(json['contactMethods'] ?? json['contact_methods']),
      contactEmail: _nullableString(json['contactEmail'] ?? json['contact_email']),
      whatsappNumber: _nullableString(json['whatsappNumber'] ?? json['whatsapp_number']),
      imessageAddress: _nullableString(json['imessageAddress'] ?? json['imessage_address']),
      smsNumber: _nullableString(json['smsNumber'] ?? json['sms_number']),
      is24_7: (json['is24_7'] ?? json['is_24_7']) == true,
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

class FoodRestaurantReview {
  final String id;
  final String reviewerName;
  final int rating;
  final String title;
  final String body;
  final bool verifiedOrder;
  final DateTime? createdAt;

  const FoodRestaurantReview({
    required this.id,
    required this.reviewerName,
    required this.rating,
    this.title = '',
    this.body = '',
    this.verifiedOrder = false,
    this.createdAt,
  });

  factory FoodRestaurantReview.fromJson(Map<String, dynamic> json) => FoodRestaurantReview(
    id: json['id']?.toString() ?? '',
    reviewerName: json['reviewerDisplayName']?.toString() ?? json['reviewer_display_name']?.toString() ?? 'Customer',
    rating: _toInt(json['rating']).clamp(1, 5).toInt(),
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    verifiedOrder: (json['verifiedOrder'] ?? json['verified_order']) == true,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? ''),
  );
}

class FoodMenuTheme {
  final String id;
  final String themeKey;
  final String name;
  final String description;
  final String inspiration;
  final String disclosure;
  final List<String> menuItemIds;

  const FoodMenuTheme({
    required this.id,
    required this.themeKey,
    required this.name,
    this.description = '',
    this.inspiration = '',
    this.disclosure = '',
    this.menuItemIds = const <String>[],
  });

  factory FoodMenuTheme.fromJson(Map<String, dynamic> json) => FoodMenuTheme(
    id: json['id']?.toString() ?? '',
    themeKey: json['themeKey']?.toString() ?? json['theme_key']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Themed menu',
    description: json['description']?.toString() ?? '',
    inspiration: json['inspiration']?.toString() ?? '',
    disclosure: json['disclosure']?.toString() ?? '',
    menuItemIds: _stringList(json['menuItemIds'] ?? json['menu_item_ids']),
  );
}

class FoodThemePreset {
  final String key;
  final String name;
  final String inspiration;
  final String description;
  final List<String> menuIdeas;
  const FoodThemePreset(this.key, this.name, this.inspiration, this.description, {this.menuIdeas = const <String>[]});
}

const foodThemePresets = <FoodThemePreset>[
  FoodThemePreset(
    'wizarding_fantasy', 'Wizarding Fantasy Marathon', 'Harry Potter-inspired',
    'British-inspired savory food, magical sweets, and warm or cold butterbeer-inspired drinks.',
    menuIdeas: <String>[
      'Pumpkin pasties', 'Cornish pasties', 'Shepherd’s pie', 'Steak-and-kidney pudding', 'Hagrid-inspired roast beef platter',
      'Butterbeer-inspired hot or cold non-alcoholic drink', 'Chocolate-frog-shaped treats',
      'Every-flavor jelly beans', 'Treacle tart', 'Golden-Snitch mac-and-cheese bites',
      'Pretzel-rod broomsticks', 'Honeydukes-inspired candy board', 'Pink-frosted birthday cake', 'Chocolate-covered gummies', 'Soft pretzels',
      'Middle films: Patronus-inspired sugar cookies, treacle tart, and Gillyweed-inspired fruit snacks',
      'Later films: Cauldron cakes, licorice wand treats, and foraged-mushroom-inspired dishes',
      'Early films: pink-frosted birthday cake, chocolate-covered gummies, and soft pretzels',
    ],
  ),
  FoodThemePreset(
    'superhero_marathon', 'Superhero Movie Marathon', 'Marvel-inspired',
    'Character-inspired comfort food, shareable snacks, bold colors, and cosmic non-alcoholic drinks.',
    menuIdeas: <String>[
      'Shawarma platter', 'Iron Man-inspired cheeseburgers and pepper-pot soup', 'Captain America-inspired apple pie',
      'Red-and-gold watermelon and pineapple skewers', 'Coney-style hot dogs', 'Hulk-green smash burgers or green smoothies',
      'Spider-Man-inspired New York-style pizza or spicy tacos', 'Black Panther-inspired piri-piri chicken or shisa nyama-style platter',
      'Black Widow-inspired pelmeni', 'Thor-inspired pretzel hammer treats and non-alcoholic mead-style drink',
      'Hawkeye bullseye hummus platter', 'Mjölnir pretzel-rod hammer treats or bacon-lollipop bites', 'Beer-cheese dip where suitable', 'Colorful infinity-stone gummies',
      'Avengers-inspired mixed-berry “assemble” pie', 'Red, green, and gold themed donuts', 'Galaxy-blue Tesseract mocktail',
      'Guardians-inspired tropical fruit and root-beer floats', 'Non-alcoholic themed frozen slushies',
    ],
  ),
  FoodThemePreset('horror_night', 'Horror Movie Night', 'Horror cinema', 'Dark-red mocktails, spicy snacks, themed desserts, popcorn flights, and late-night sharing platters.', menuIdeas: <String>['Popcorn flight', 'Spicy wings or cauliflower bites', 'Red-berry mocktail', 'Black-cocoa cupcakes', 'Late-night sharing platter']),
  FoodThemePreset('anime_watch_party', 'Anime Watch Party', 'Anime-inspired', 'Japanese comfort-food options, ramen, onigiri, bento boxes, mochi, and themed non-alcoholic drinks.', menuIdeas: <String>['Ramen bowls', 'Onigiri assortment', 'Bento box', 'Mochi selection', 'Japanese-style fruit soda']),
  FoodThemePreset('space_adventure', 'Space Adventure Night', 'Science-fiction cinema', 'Galaxy-colored mocktails, star-shaped snacks, cosmic desserts, and shareable trays.', menuIdeas: <String>['Galaxy mocktail', 'Star-shaped sandwiches', 'Cosmic cupcakes', 'Meteor meatballs or plant-based bites', 'Astronaut-style snack packs']),
  FoodThemePreset('holiday_marathon', 'Holiday Movie Marathon', 'Seasonal cinema', 'Cookies, warm drinks, comfort-food trays, festive desserts, and sharing platters.', menuIdeas: <String>['Cookie assortment', 'Warm spiced apple drink', 'Comfort-food platter', 'Festive brownies', 'Sharing snack board']),
];

class FoodMenuItem {
  final String id;
  final String category;
  final String name;
  final String description;
  final int priceCents;
  final String? imageUrl;
  final bool available;
  final List<String> tags;
  final List<String> themeKeys;
  final List<String> ingredients;
  final List<String> allergens;
  final List<String> removableIngredients;
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
    this.themeKeys = const <String>[],
    this.ingredients = const <String>[],
    this.allergens = const <String>[],
    this.removableIngredients = const <String>[],
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
      themeKeys: _stringList(json['themeKeys'] ?? json['theme_keys']),
      ingredients: _stringList(json['ingredients']),
      allergens: _stringList(json['allergens']),
      removableIngredients: _stringList(json['removableIngredients'] ?? json['removable_ingredients']),
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
  final String restaurantId;
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
    this.restaurantId = '',
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
      restaurantId: json['restaurantId']?.toString() ?? json['restaurant_id']?.toString() ?? '',
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

class FoodConversationMessage {
  final String id;
  final String senderExternalId;
  final String senderRole;
  final String messageType;
  final String body;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;

  const FoodConversationMessage({
    required this.id,
    required this.senderExternalId,
    required this.senderRole,
    required this.messageType,
    required this.body,
    this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  factory FoodConversationMessage.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return FoodConversationMessage(
      id: json['id']?.toString() ?? '',
      senderExternalId: json['senderExternalId']?.toString() ?? json['sender_external_id']?.toString() ?? '',
      senderRole: json['senderRole']?.toString() ?? json['sender_role']?.toString() ?? 'customer',
      messageType: json['messageType']?.toString() ?? json['message_type']?.toString() ?? 'text',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? ''),
      metadata: rawMetadata is Map ? Map<String, dynamic>.from(rawMetadata) : const <String, dynamic>{},
    );
  }
}

class FoodConversation {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String customerExternalId;
  final String customerDisplayName;
  final String? orderId;
  final String? relatedMenuItemId;
  final String relatedMenuItemName;
  final String topic;
  final String subject;
  final String status;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final String viewerRole;
  final List<FoodConversationMessage> messages;

  const FoodConversation({
    required this.id,
    required this.restaurantId,
    this.restaurantName = 'Restaurant',
    required this.customerExternalId,
    this.customerDisplayName = '',
    this.orderId,
    this.relatedMenuItemId,
    this.relatedMenuItemName = '',
    this.topic = 'general',
    this.subject = 'Restaurant question',
    this.status = 'open',
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.createdAt,
    this.viewerRole = 'customer',
    this.messages = const <FoodConversationMessage>[],
  });

  factory FoodConversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return FoodConversation(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? json['restaurant_id']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString() ?? json['restaurant_name']?.toString() ?? 'Restaurant',
      customerExternalId: json['customerExternalId']?.toString() ?? json['customer_external_id']?.toString() ?? '',
      customerDisplayName: json['customerDisplayName']?.toString() ?? json['customer_display_name']?.toString() ?? '',
      orderId: _nullableString(json['orderId'] ?? json['order_id']),
      relatedMenuItemId: _nullableString(json['relatedMenuItemId'] ?? json['related_menu_item_id']),
      relatedMenuItemName: json['relatedMenuItemName']?.toString() ?? json['related_menu_item_name']?.toString() ?? '',
      topic: json['topic']?.toString() ?? 'general',
      subject: json['subject']?.toString() ?? 'Restaurant question',
      status: json['status']?.toString() ?? 'open',
      lastMessagePreview: json['lastMessagePreview']?.toString() ?? json['last_message_preview']?.toString() ?? '',
      lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? json['last_message_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? ''),
      viewerRole: json['viewerRole']?.toString() ?? json['viewer_role']?.toString() ?? 'customer',
      messages: rawMessages is List
          ? rawMessages.whereType<Map>().map((item) => FoodConversationMessage.fromJson(Map<String, dynamic>.from(item))).toList(growable: false)
          : const <FoodConversationMessage>[],
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

  Future<List<FoodRestaurantReview>> getRestaurantReviews(String restaurantId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/food/restaurants/${Uri.encodeComponent(restaurantId)}/reviews'),
      headers: _headers,
    );
    final data = _decode(response);
    final raw = data['reviews'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! List) {
      throw Exception(data['error']?.toString() ?? 'Unable to load restaurant reviews.');
    }
    return raw.whereType<Map>()
        .map((row) => FoodRestaurantReview.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<FoodRestaurantReview> submitRestaurantReview({
    required String restaurantId,
    required int rating,
    String title = '',
    String body = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/food/restaurants/${Uri.encodeComponent(restaurantId)}/reviews'),
      headers: _headers,
      body: jsonEncode({'rating': rating, 'title': title.trim(), 'body': body.trim()}),
    );
    final data = _decode(response);
    final raw = data['review'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! Map) {
      throw Exception(data['error']?.toString() ?? 'Unable to submit your review.');
    }
    return FoodRestaurantReview.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<FoodRestaurant> updateMerchantRestaurantProfile(String restaurantId, Map<String, dynamic> payload) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/food/merchant/restaurants/${Uri.encodeComponent(restaurantId)}/profile'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    final restaurant = data['restaurant'];
    if (response.statusCode < 200 || response.statusCode >= 300 || restaurant is! Map) {
      throw Exception(data['error']?.toString() ?? 'Unable to update the restaurant profile.');
    }
    return FoodRestaurant.fromJson(Map<String, dynamic>.from(restaurant));
  }

  Future<List<FoodMenuTheme>> getFoodMenuThemes(String restaurantId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/food/restaurants/${Uri.encodeComponent(restaurantId)}/themes'),
      headers: _headers,
    );
    final data = _decode(response);
    final raw = data['themes'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! List) {
      throw Exception(data['error']?.toString() ?? 'Unable to load themed menus.');
    }
    return raw.whereType<Map>()
        .map((row) => FoodMenuTheme.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<FoodMenuTheme> createFoodMenuTheme(String restaurantId, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/food/merchant/restaurants/${Uri.encodeComponent(restaurantId)}/themes'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = _decode(response);
    final raw = data['theme'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! Map) {
      throw Exception(data['error']?.toString() ?? 'Unable to create themed menu.');
    }
    return FoodMenuTheme.fromJson(Map<String, dynamic>.from(raw));
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

  Future<List<FoodConversation>> getCustomerConversations() async {
    final response = await http.get(Uri.parse('$baseUrl/food/conversations'), headers: _headers);
    final data = _decode(response);
    final raw = data['conversations'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! List) {
      throw Exception(data['error']?.toString() ?? 'Unable to load your restaurant messages.');
    }
    return raw.whereType<Map>()
        .map((row) => FoodConversation.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<FoodConversation>> getMerchantConversations({String? restaurantId}) async {
    final uri = Uri.parse('$baseUrl/food/merchant/conversations').replace(
      queryParameters: restaurantId == null || restaurantId.trim().isEmpty
          ? null
          : {'restaurantId': restaurantId.trim()},
    );
    final response = await http.get(uri, headers: _headers);
    final data = _decode(response);
    final raw = data['conversations'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! List) {
      throw Exception(data['error']?.toString() ?? 'Unable to load customer messages.');
    }
    return raw.whereType<Map>()
        .map((row) => FoodConversation.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<FoodConversation> createFoodConversation({
    required String restaurantId,
    String topic = 'general',
    String subject = 'Restaurant question',
    String? relatedMenuItemId,
    String relatedMenuItemName = '',
    String? orderId,
    String? firstMessage,
    String? firstMessageType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/food/conversations'),
      headers: _headers,
      body: jsonEncode({
        'restaurantId': restaurantId,
        'topic': topic,
        'subject': subject,
        if (relatedMenuItemId != null && relatedMenuItemId.isNotEmpty) 'relatedMenuItemId': relatedMenuItemId,
        if (relatedMenuItemName.trim().isNotEmpty) 'relatedMenuItemName': relatedMenuItemName.trim(),
        if (orderId != null && orderId.trim().isNotEmpty) 'orderId': orderId.trim(),
        if (firstMessage != null && firstMessage.trim().isNotEmpty) 'firstMessage': firstMessage.trim(),
        if (firstMessageType != null && firstMessageType.isNotEmpty) 'firstMessageType': firstMessageType,
      }),
    );
    final data = _decode(response);
    final raw = data['conversation'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! Map) {
      throw Exception(data['error']?.toString() ?? 'Unable to start a conversation with this restaurant.');
    }
    return FoodConversation.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<FoodConversation> getFoodConversation(String conversationId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/food/conversations/${Uri.encodeComponent(conversationId)}'),
      headers: _headers,
    );
    final data = _decode(response);
    final raw = data['conversation'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! Map) {
      throw Exception(data['error']?.toString() ?? 'Unable to load this conversation.');
    }
    return FoodConversation.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<FoodConversation> sendFoodConversationMessage({
    required String conversationId,
    required String body,
    String messageType = 'text',
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/food/conversations/${Uri.encodeComponent(conversationId)}/messages'),
      headers: _headers,
      body: jsonEncode({'body': body, 'messageType': messageType, 'metadata': metadata}),
    );
    final data = _decode(response);
    final raw = data['conversation'];
    if (response.statusCode < 200 || response.statusCode >= 300 || raw is! Map) {
      throw Exception(data['error']?.toString() ?? 'Unable to send your message.');
    }
    return FoodConversation.fromJson(Map<String, dynamic>.from(raw));
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
    unawaited(_setProfileActivity('Ordering food'));
    _loadNearby();
    _loadRewards();
  }

  Future<void> _setProfileActivity(String? activity) async {
    final profile = AppController.instance.currentProfile;
    final api = AppController.instance.backendApi;
    if (profile == null || !api.isAuthenticated) return;
    try {
      if (activity == null) {
        await api.setSocialProfilePresence(
          profileId: profile.id,
          availability: 'active',
          clearActivity: true,
        );
      } else {
        await api.setSocialProfilePresence(
          profileId: profile.id,
          availability: 'active',
          activityType: 'ordering_food',
          activityText: activity,
        );
      }
    } catch (_) {
      // Activity is advisory; ordering must continue when presence is offline.
    }
  }

  @override
  void dispose() {
    unawaited(_setProfileActivity(null));
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
            title: const UniversalText('Choose the location'),
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
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const UniversalText('Cancel'))],
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
              const UniversalText('This is a public directory listing, not a restaurant enrolled in Food & Delivery. Its live menu, item prices, tax rules, and delivery options have not been confirmed on this platform. The owner must register the restaurant and add a menu before in-app ordering can be enabled.',
              ),
              const SizedBox(height: 8),
              const UniversalText('Directory data © OpenStreetMap contributors.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const UniversalText('Close'),
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
        title: const UniversalText('Food & Delivery'),
        actions: [
          const PageCustomizeButton(pageId: 'food-delivery'),
          IconButton(
            tooltip: 'Your restaurant messages',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FoodConversationInboxScreen(api: _api, isMerchant: false),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
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
            const UniversalText('What are you craving?',
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
                label: const UniversalText('Use my current location'),
              ),
            ),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.location_city_rounded),
                title: const UniversalText('Enter location manually'),
                subtitle: const UniversalText('Country, state, city, ZIP/postal code, and street address'),
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
                  title: const UniversalText('Restaurant rewards'),
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
            const UniversalText('Nearby search combines platform restaurants with public OpenStreetMap directory listings. Directory data can be incomplete or outdated. Only restaurants with a platform menu can accept in-app orders; external listings must be registered by the owner and given menu/pricing first. Data © OpenStreetMap contributors (openstreetmap.org/copyright).',
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
                        label: const UniversalText('Try again'),
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        const Icon(Icons.restaurant_outlined, size: 38),
                        const SizedBox(height: 10),
                        const UniversalText(
                          'No nearby restaurants matched that search.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const UniversalText(
                          'Try a different cuisine, expand the search area, or clear your search to see nearby options.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60),
                        ),
                        if (_activeQuery.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              _loadNearby(query: '');
                            },
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const UniversalText('Clear search'),
                          ),
                        ],
                      ],
                    ),
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
                        const Chip(label: UniversalText('Directory listing'))
                      else if (!restaurant.isOpen)
                        const Chip(label: UniversalText('Closed'))
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
                        for (var star = 1; star <= 5; star++)
                          Icon(star <= restaurant.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded, size: 13, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('${restaurant.rating.toStringAsFixed(1)} (${restaurant.reviewCount})', style: const TextStyle(fontSize: 12)),
                        const Spacer(),
                        Text(restaurant.allowsDelivery
                            ? 'Delivery ${_money(restaurant.deliveryFeeCents, restaurant.currencyCode)}'
                            : (restaurant.allowsPickup ? 'Pickup only' : 'Not accepting orders')),
                      ] else ...[
                        const Icon(Icons.public_rounded, size: 16),
                        const SizedBox(width: 5),
                        const Expanded(child: UniversalText('Menu not yet available on this platform', style: TextStyle(color: Colors.white60, fontSize: 12))),
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

class FoodRestaurantReviewsScreen extends StatefulWidget {
  final FoodDeliveryApi api;
  final FoodRestaurant restaurant;

  const FoodRestaurantReviewsScreen({super.key, required this.api, required this.restaurant});

  @override
  State<FoodRestaurantReviewsScreen> createState() => _FoodRestaurantReviewsScreenState();
}

class _FoodRestaurantReviewsScreenState extends State<FoodRestaurantReviewsScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  List<FoodRestaurantReview> _reviews = const <FoodRestaurantReview>[];
  int _rating = 5;
  double _averageRating = 0;
  int _reviewCount = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _averageRating = widget.restaurant.rating;
    _reviewCount = widget.restaurant.reviewCount;
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final reviews = await widget.api.getRestaurantReviews(widget.restaurant.id);
      double? freshAverage;
      int? freshCount;
      try {
        final fresh = await widget.api.getRestaurant(widget.restaurant.id);
        freshAverage = fresh.rating;
        freshCount = fresh.reviewCount;
      } catch (_) {
        // The review list remains useful even if the restaurant summary endpoint is temporarily unavailable.
      }
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        if (freshAverage != null) _averageRating = freshAverage;
        if (freshCount != null) _reviewCount = freshCount;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = error.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Add a review title or a few details first.')));
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await widget.api.submitRestaurantReview(
        restaurantId: widget.restaurant.id,
        rating: _rating,
        title: _title.text.trim(),
        body: _body.text.trim(),
      );
      _title.clear();
      _body.clear();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Your review has been saved.')));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _stars(int rating, {double size = 18}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [for (var i = 1; i <= 5; i++) Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: Colors.amber)],
  );

  @override
  Widget build(BuildContext context) {
    final average = _averageRating;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.restaurant.name} · Reviews')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${average.toStringAsFixed(1)} / 5', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            _stars(average.round(), size: 24),
            const SizedBox(height: 4),
            Text('$_reviewCount customer reviews', style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 10),
            const UniversalText('Rate your experience', style: TextStyle(fontWeight: FontWeight.w800)),
            Row(children: [
              for (var i = 1; i <= 5; i++) IconButton(
                tooltip: '$i ${i == 1 ? 'star' : 'stars'}',
                onPressed: () => setState(() => _rating = i),
                icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 30),
              ),
              const SizedBox(width: 6),
              Text('$_rating / 5'),
            ]),
            TextField(controller: _title, maxLength: 120, decoration: const InputDecoration(labelText: 'Review title (optional)')),
            const SizedBox(height: 8),
            TextField(controller: _body, minLines: 2, maxLines: 5, maxLength: 2000, decoration: const InputDecoration(labelText: 'How was your experience?', hintText: 'Food quality, accuracy, packaging, service…')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.rate_review_outlined),
              label: Text(_submitting ? 'Submitting…' : 'Submit review'),
            )),
            const SizedBox(height: 4),
            const UniversalText('One review per account per restaurant; submitting again updates your previous review. Verified-order status is based on the restaurant order records.', style: TextStyle(fontSize: 11, color: Colors.white54)),
          ]))),
          const SizedBox(height: 12),
          const UniversalText('Customer reviews', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (!_loading && _reviews.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: UniversalText('No reviews yet. Be the first to share your experience.'))),
          for (final review in _reviews)
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(review.reviewerName, style: const TextStyle(fontWeight: FontWeight.w800))), _stars(review.rating)]),
              if (review.verifiedOrder) const Padding(padding: EdgeInsets.only(top: 4), child: Chip(avatar: Icon(Icons.verified_rounded, size: 15), label: UniversalText('Verified order'))),
              if (review.title.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(review.title, style: const TextStyle(fontWeight: FontWeight.w800))),
              if (review.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text(review.body)),
              if (review.createdAt != null) Padding(padding: const EdgeInsets.only(top: 7), child: Text(review.createdAt!.toLocal().toString().split(' ').first, style: const TextStyle(fontSize: 11, color: Colors.white54))),
            ]))),
        ],
      ),
    );
  }
}

Future<void> _launchRestaurantContact(BuildContext context, FoodRestaurant restaurant, String method) async {
  String? rawTarget;
  Uri? uri;
  final phone = restaurant.phone.trim();
  switch (method) {
    case 'call':
      rawTarget = phone;
      if (rawTarget.isNotEmpty) uri = Uri(scheme: 'tel', path: rawTarget);
      break;
    case 'sms':
      rawTarget = (restaurant.smsNumber ?? phone).trim();
      if (rawTarget.isNotEmpty) uri = Uri(scheme: 'sms', path: rawTarget);
      break;
    case 'imessage':
      rawTarget = (restaurant.imessageAddress ?? '').trim();
      if (rawTarget.isNotEmpty) {
        // Use the platform Messages handler. On Apple devices, recipients with iMessage enabled can continue in iMessage.
      uri = Uri(scheme: 'sms', path: rawTarget);
      }
      break;
    case 'whatsapp':
      rawTarget = (restaurant.whatsappNumber ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      if (rawTarget.isNotEmpty) uri = Uri.parse('https://wa.me/$rawTarget');
      break;
    case 'email':
      rawTarget = (restaurant.contactEmail ?? '').trim();
      if (rawTarget.isNotEmpty) uri = Uri(scheme: 'mailto', path: rawTarget);
      break;
    case 'website':
      rawTarget = (restaurant.website ?? '').trim();
      if (rawTarget.isNotEmpty) {
        final candidate = Uri.tryParse(rawTarget.contains('://') ? rawTarget : 'https://$rawTarget');
        if (candidate != null && (candidate.scheme == 'https' || candidate.scheme == 'http')) uri = candidate;
      }
      break;
  }
  if (uri == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('This contact method has not been configured by the restaurant.')));
    return;
  }
  try {
    final launched = await launchUrl(uri, mode: method == 'website' || method == 'whatsapp' ? LaunchMode.externalApplication : LaunchMode.platformDefault);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('No compatible app or handler was found for this contact method.')));
    }
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Unable to open this contact method on this device.')));
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
  final _weekdayOpen = TextEditingController(text: '09:00');
  final _weekdayClose = TextEditingController(text: '17:00');
  final _weekendOpen = TextEditingController(text: '09:00');
  final _weekendClose = TextEditingController(text: '17:00');
  final _whatsapp = TextEditingController();
  final _imessage = TextEditingController();
  final _sms = TextEditingController();
  final _contactEmail = TextEditingController();
  final _website = TextEditingController();
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
  bool _open247 = false;
  bool _weekendsClosed = true;
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
      _name, _cuisine, _description, _phone,
      _weekdayOpen, _weekdayClose, _weekendOpen, _weekendClose,
      _whatsapp, _imessage, _sms, _contactEmail, _website,
      _address, _city, _state, _postal, _country, _heroImage, _currency,
      _deliveryFee, _taxRate, _minimumOrder,
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
            title: const UniversalText('Confirm restaurant location'),
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
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const UniversalText('Cancel'))],
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

  Map<String, dynamic> _businessHoursPayload() {
    final hours = <String, dynamic>{};
    const weekdays = ['mon', 'tue', 'wed', 'thu', 'fri'];
    const weekends = ['sat', 'sun'];
    if (_open247) {
      for (final day in [...weekdays, ...weekends]) {
        hours[day] = {'closed': false, 'allDay': true, 'open': '00:00', 'close': '23:59'};
      }
      return hours;
    }
    for (final day in weekdays) {
      hours[day] = {
        'closed': false,
        'allDay': false,
        'open': _weekdayOpen.text.trim(),
        'close': _weekdayClose.text.trim(),
      };
    }
    for (final day in weekends) {
      hours[day] = _weekendsClosed
          ? {'closed': true, 'allDay': false}
          : {
              'closed': false,
              'allDay': false,
              'open': _weekendOpen.text.trim(),
              'close': _weekendClose.text.trim(),
            };
    }
    return hours;
  }

  String _hoursSummary() {
    if (_open247) return '24/7';
    final weekday = 'Mon-Fri ${_displayTime(_weekdayOpen.text)}-${_displayTime(_weekdayClose.text)}';
    final weekend = _weekendsClosed
        ? 'Sat-Sun Closed'
        : 'Sat-Sun ${_displayTime(_weekendOpen.text)}-${_displayTime(_weekendClose.text)}';
    return '$weekday; $weekend';
  }

  List<String> _selectedContactMethods() => [
    if (_phone.text.trim().isNotEmpty) 'call',
    if (_sms.text.trim().isNotEmpty) 'sms',
    if (_imessage.text.trim().isNotEmpty) 'imessage',
    if (_whatsapp.text.trim().isNotEmpty) 'whatsapp',
    if (_contactEmail.text.trim().isNotEmpty) 'email',
    if (_website.text.trim().isNotEmpty) 'website',
  ];

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
        'openingHours': _open247 ? '24/7' : _hoursSummary(),
        'businessHours': _businessHoursPayload(),
        'is24_7': _open247,
        'contactMethods': _selectedContactMethods(),
        'contactEmail': _contactEmail.text.trim(),
        'whatsappNumber': _whatsapp.text.trim(),
        'imessageAddress': _imessage.text.trim(),
        'smsNumber': _sms.text.trim(),
        'website': _website.text.trim(),
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
    final ingredients = TextEditingController();
    final allergens = TextEditingController();
    final removableIngredients = TextEditingController();
    final themeKeys = TextEditingController(text: 'movie_night');
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
                TextField(controller: ingredients, maxLines: 2, decoration: const InputDecoration(labelText: 'Ingredients (comma-separated)', helperText: 'Use the current recipe, not assumptions.')),
                TextField(controller: allergens, maxLines: 2, decoration: const InputDecoration(labelText: 'Declared allergens (comma-separated)', helperText: 'List known recipe allergens; cross-contact needs separate confirmation.')),
                TextField(controller: removableIngredients, maxLines: 2, decoration: const InputDecoration(labelText: 'Ingredients that can be removed (comma-separated)')),
                TextField(controller: themeKeys, maxLines: 2, decoration: const InputDecoration(labelText: 'Theme keys (comma-separated)', helperText: 'Examples: wizarding_fantasy, superhero_marathon, horror_night, anime_watch_party, movie_night')),
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
                const UniversalText('Choose a local JPG, PNG, or WebP photo, or paste a publicly accessible image URL.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const UniversalText('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, {
              'name': name.text.trim(), 'category': category.text.trim(),
              'description': description.text.trim(), 'price': price.text.trim(),
              'ingredients': ingredients.text.trim(), 'allergens': allergens.text.trim(),
              'removableIngredients': removableIngredients.text.trim(),
              'themeKeys': themeKeys.text.trim(),
              'imageUrl': imageUrl.text.trim(),
            }), child: const UniversalText('Add item')),
          ],
        ),
      ),
    );
    name.dispose(); category.dispose(); description.dispose(); price.dispose(); imageUrl.dispose();
    ingredients.dispose(); allergens.dispose(); removableIngredients.dispose(); themeKeys.dispose();
    if (values == null || values['name']!.isEmpty) return;
    final parsedPrice = double.tryParse(values['price'] ?? '');
    if (parsedPrice == null || parsedPrice < 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Enter a valid item price.')));
      return;
    }
    try {
      final item = await widget.api.addMerchantMenuItem(restaurant.id, {
        'name': values['name'],
        'category': values['category']!.isEmpty ? 'Menu' : values['category'],
        'description': values['description'],
        'priceCents': (parsedPrice * 100).round(),
        'imageUrl': values['imageUrl'],
        'ingredients': _splitIngredientField(values['ingredients'] ?? ''),
        'allergens': _splitIngredientField(values['allergens'] ?? ''),
        'removableIngredients': _splitIngredientField(values['removableIngredients'] ?? ''),
        'themeKeys': _splitIngredientField(values['themeKeys'] ?? '').map((key) => key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')).where((key) => key.isNotEmpty).toList(growable: false),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Menu item added.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _createThemedMenu(FoodRestaurant restaurant) async {
    List<FoodMenuItem> items;
    try {
      items = await widget.api.getMenu(restaurant.id);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      return;
    }
    if (!mounted) return;
    if (items.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Add at least one menu item before creating a themed menu.')));
      return;
    }
    var selectedPreset = foodThemePresets.first;
    final name = TextEditingController(text: selectedPreset.name);
    final key = TextEditingController(text: selectedPreset.key);
    final description = TextEditingController(text: selectedPreset.description);
    final inspiration = TextEditingController(text: selectedPreset.inspiration);
    final selectedIds = <String>{};
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Create themed menu · ${restaurant.name}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedPreset.key,
                  decoration: const InputDecoration(labelText: 'Theme idea'),
                  items: [for (final preset in foodThemePresets) DropdownMenuItem(value: preset.key, child: Text(preset.name))],
                  onChanged: (value) {
                    final matches = foodThemePresets.where((preset) => preset.key == value);
                    if (matches.isEmpty) return;
                    setDialogState(() {
                      selectedPreset = matches.first;
                      name.text = selectedPreset.name;
                      key.text = selectedPreset.key;
                      description.text = selectedPreset.description;
                      inspiration.text = selectedPreset.inspiration;
                    });
                  },
                ),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Menu name')),
                TextField(controller: key, decoration: const InputDecoration(labelText: 'Unique theme key')),
                TextField(controller: inspiration, decoration: const InputDecoration(labelText: 'Inspiration / franchise / occasion')),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Menu description')),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: Text('Suggested food ideas · ${selectedPreset.name}', style: const TextStyle(fontWeight: FontWeight.w800))),
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerLeft, child: Text(selectedPreset.menuIdeas.join(' • '), style: const TextStyle(fontSize: 12, color: Colors.white70))),
                const SizedBox(height: 8),
                const Align(alignment: Alignment.centerLeft, child: UniversalText('First add any dishes you actually sell as menu items with real prices and ingredient/allergen details. Then select those items below.', style: TextStyle(fontSize: 12, color: Colors.amberAccent))),
                const SizedBox(height: 10),
                const Align(alignment: Alignment.centerLeft, child: UniversalText('Choose menu items for this collection', style: TextStyle(fontWeight: FontWeight.w800))),
                for (final item in items)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selectedIds.contains(item.id),
                    title: Text(item.name),
                    subtitle: Text('${item.category} · ${_money(item.priceCents, restaurant.currencyCode)}'),
                    onChanged: (selected) => setDialogState(() {
                      if (selected == true) { selectedIds.add(item.id); } else { selectedIds.remove(item.id); }
                    }),
                  ),
                const SizedBox(height: 6),
                const UniversalText('Fan-inspired concepts are not official or affiliated offerings unless the restaurant has the appropriate license. Use only artwork and branding you are authorized to use.', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const UniversalText('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, {
              'name': name.text.trim(), 'themeKey': key.text.trim(),
              'description': description.text.trim(), 'inspiration': inspiration.text.trim(),
              'menuItemIds': selectedIds.toList(growable: false),
            }), child: const UniversalText('Create themed menu')),
          ],
        ),
      ),
    );
    name.dispose(); key.dispose(); description.dispose(); inspiration.dispose();
    if (values == null) return;
    try {
      await widget.api.createFoodMenuTheme(restaurant.id, values);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Themed menu created.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _editRestaurantProfile(FoodRestaurant restaurant) async {
    Map<String, dynamic> day(String key) => _stringMap(restaurant.businessHours[key]);
    final mon = day('mon');
    final sat = day('sat');
    final sun = day('sun');
    final weekdayOpen = TextEditingController(text: mon['open']?.toString() ?? '09:00');
    final weekdayClose = TextEditingController(text: mon['close']?.toString() ?? '17:00');
    final weekendOpen = TextEditingController(text: sat['open']?.toString() ?? '09:00');
    final weekendClose = TextEditingController(text: sat['close']?.toString() ?? '17:00');
    final phone = TextEditingController(text: restaurant.phone);
    final whatsapp = TextEditingController(text: restaurant.whatsappNumber ?? '');
    final imessage = TextEditingController(text: restaurant.imessageAddress ?? '');
    final sms = TextEditingController(text: restaurant.smsNumber ?? '');
    final email = TextEditingController(text: restaurant.contactEmail ?? '');
    final website = TextEditingController(text: restaurant.website ?? '');
    var open247 = restaurant.is24_7 || restaurant.openingHours.trim().toLowerCase() == '24/7' || const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']
        .every((key) => (_stringMap(restaurant.businessHours[key])['allDay'] == true));
    var weekendsClosed = (sat['closed'] == true && sun['closed'] == true) ||
        (restaurant.businessHours.isEmpty && restaurant.openingHours.toLowerCase().contains('closed'));

    Map<String, dynamic> schedule() {
      const weekdays = ['mon', 'tue', 'wed', 'thu', 'fri'];
      const weekendDays = ['sat', 'sun'];
      if (open247) {
        return <String, dynamic>{
          for (final key in [...weekdays, ...weekendDays])
            key: <String, dynamic>{'closed': false, 'allDay': true, 'open': '00:00', 'close': '23:59'},
        };
      }
      return <String, dynamic>{
        for (final key in weekdays)
          key: <String, dynamic>{'closed': false, 'allDay': false, 'open': weekdayOpen.text.trim(), 'close': weekdayClose.text.trim()},
        for (final key in weekendDays)
          key: weekendsClosed
              ? <String, dynamic>{'closed': true, 'allDay': false}
              : <String, dynamic>{'closed': false, 'allDay': false, 'open': weekendOpen.text.trim(), 'close': weekendClose.text.trim()},
      };
    }

    String hoursSummary() {
      if (open247) return '24/7';
      final weekendSummary = weekendsClosed
          ? 'Sat-Sun Closed'
          : 'Sat-Sun ${_displayTime(weekendOpen.text)}-${_displayTime(weekendClose.text)}';
      return 'Mon-Fri ${_displayTime(weekdayOpen.text)}-${_displayTime(weekdayClose.text)}; $weekendSummary';
    }

    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Edit profile · ${restaurant.name}'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Align(alignment: Alignment.centerLeft, child: UniversalText('Business hours', style: TextStyle(fontWeight: FontWeight.w800))),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: open247,
                  onChanged: (value) => setDialogState(() => open247 = value),
                  title: const UniversalText('Open 24/7'),
                ),
                if (!open247) ...[
                  const Align(alignment: Alignment.centerLeft, child: UniversalText('Use 24-hour time, for example 09:00 and 17:00.', style: TextStyle(fontSize: 12, color: Colors.white60))),
                  Row(children: [
                    Expanded(child: TextField(controller: weekdayOpen, decoration: const InputDecoration(labelText: 'Weekdays open'), keyboardType: TextInputType.datetime, onChanged: (_) => setDialogState(() {}))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: weekdayClose, decoration: const InputDecoration(labelText: 'Weekdays close'), keyboardType: TextInputType.datetime, onChanged: (_) => setDialogState(() {}))),
                  ]),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: weekendsClosed,
                    onChanged: (value) => setDialogState(() => weekendsClosed = value),
                    title: const UniversalText('Closed on weekends'),
                  ),
                  if (!weekendsClosed) Row(children: [
                    Expanded(child: TextField(controller: weekendOpen, decoration: const InputDecoration(labelText: 'Weekend open'), keyboardType: TextInputType.datetime, onChanged: (_) => setDialogState(() {}))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: weekendClose, decoration: const InputDecoration(labelText: 'Weekend close'), keyboardType: TextInputType.datetime, onChanged: (_) => setDialogState(() {}))),
                  ]),
                ],
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Hours shown to customers'),
                  child: Align(alignment: Alignment.centerLeft, child: Text(hoursSummary())),
                ),
                const SizedBox(height: 10),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone for calls')),
                TextField(controller: sms, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'SMS number')),
                TextField(controller: imessage, decoration: const InputDecoration(labelText: 'iMessage address or phone')),
                TextField(controller: whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp number with country code')),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Support email')),
                TextField(controller: website, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Website (HTTPS)')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const UniversalText('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, <String, dynamic>{
              'openingHours': hoursSummary(),
              'businessHours': schedule(),
              'is24_7': open247,
              'phone': phone.text.trim(),
              'smsNumber': sms.text.trim(),
              'imessageAddress': imessage.text.trim(),
              'whatsappNumber': whatsapp.text.trim(),
              'contactEmail': email.text.trim(),
              'website': website.text.trim(),
            }), child: const UniversalText('Save changes')),
          ],
        ),
      ),
    );
    for (final controller in [weekdayOpen, weekdayClose, weekendOpen, weekendClose, phone, whatsapp, imessage, sms, email, website]) {
      controller.dispose();
    }
    if (values == null) return;
    try {
      final contactMethods = <String>[
        if ((values['phone'] as String? ?? '').isNotEmpty) 'call',
        if ((values['smsNumber'] as String? ?? '').isNotEmpty) 'sms',
        if ((values['imessageAddress'] as String? ?? '').isNotEmpty) 'imessage',
        if ((values['whatsappNumber'] as String? ?? '').isNotEmpty) 'whatsapp',
        if ((values['contactEmail'] as String? ?? '').isNotEmpty) 'email',
        if ((values['website'] as String? ?? '').isNotEmpty) 'website',
      ];
      await widget.api.updateMerchantRestaurantProfile(restaurant.id, {
        ...values,
        'contactMethods': contactMethods,
      });
      await _loadRestaurants();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Restaurant profile updated.')));
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const UniversalText('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, {
            'code': code.text.trim(), 'percent': percent.text.trim(),
            'description': description.text.trim(), 'minimum': minimum.text.trim(),
          }), child: const UniversalText('Create coupon')),
        ],
      ),
    );
    code.dispose(); percent.dispose(); description.dispose(); minimum.dispose();
    if (values == null) return;
    final discount = int.tryParse(values['percent'] ?? '');
    final minimumOrder = double.tryParse(values['minimum'] ?? '0');
    if (discount == null || discount < 1 || discount > 100 || minimumOrder == null || minimumOrder < 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Enter a discount from 1–100% and a valid minimum.')));
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
      appBar: AppBar(title: const UniversalText('Restaurant Owner Center')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const UniversalText('List your restaurant independently of your streaming server', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const UniversalText('Each account can own restaurants in any city. Add your location, contact details, menu and photo links, set fees/tax configuration, and publish coupons.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FoodConversationInboxScreen(api: widget.api, isMerchant: true),
              ),
            ),
            icon: const Icon(Icons.mark_unread_chat_alt_outlined),
            label: const UniversalText('Customer messages and support'),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const UniversalText('Register a restaurant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _field(_name, 'Restaurant name'),
                _field(_cuisine, 'Cuisine / food type', hint: 'Mexican, pizza, sushi…'),
                _field(_description, 'Description', maxLines: 3),
                _field(_phone, 'Phone number for calls', keyboardType: TextInputType.phone),
                _field(_sms, 'SMS / text number (optional)', keyboardType: TextInputType.phone),
                _field(_imessage, 'iMessage address or phone (optional)', hint: 'Available mainly on Apple devices'),
                _field(_whatsapp, 'WhatsApp number (include country code)', keyboardType: TextInputType.phone),
                _field(_contactEmail, 'Support email (optional)', keyboardType: TextInputType.emailAddress),
                _field(_website, 'Restaurant website (HTTPS URL)', keyboardType: TextInputType.url),
                const SizedBox(height: 8),
                const UniversalText('Business hours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: _open247, onChanged: (value) => setState(() {
                  _open247 = value;
                }), title: const UniversalText('Open 24/7')),
                if (!_open247) ...[
                  const UniversalText('Use 24-hour time, for example 09:00 and 17:00.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  Row(children: [Expanded(child: _field(_weekdayOpen, 'Weekdays open')), const SizedBox(width: 8), Expanded(child: _field(_weekdayClose, 'Weekdays close'))]),
                  SwitchListTile(contentPadding: EdgeInsets.zero, value: _weekendsClosed, onChanged: (value) => setState(() {
                    _weekendsClosed = value;
                  }), title: const UniversalText('Closed on weekends')),
                  if (!_weekendsClosed) Row(children: [Expanded(child: _field(_weekendOpen, 'Weekend open')), const SizedBox(width: 8), Expanded(child: _field(_weekendClose, 'Weekend close'))]),
                ],
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Hours shown to customers'),
                  child: Text(_hoursSummary()),
                ),
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
                const Padding(padding: EdgeInsets.only(bottom: 10), child: UniversalText('The platform service fee is set by MyOwnStreamingService and shown separately at checkout.', style: TextStyle(color: Colors.white60))),
                _field(_taxRate, 'Configured tax rate (%)', hint: 'Use the rate applicable to your jurisdiction', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                _field(_minimumOrder, 'Minimum order', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: _allowsDelivery, onChanged: (value) => setState(() => _allowsDelivery = value), title: const UniversalText('Offer delivery')),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: _allowsPickup, onChanged: (value) => setState(() => _allowsPickup = value), title: const UniversalText('Offer pickup'), subtitle: const UniversalText('Pickup orders do not include a delivery fee.')),
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
          const UniversalText('Your restaurants', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (!_loading && _restaurants.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: UniversalText('No restaurants registered to this account yet.'))),
          for (final restaurant in _restaurants)
            Card(
              child: ExpansionTile(
                leading: const CircleAvatar(child: Icon(Icons.restaurant_rounded)),
                title: Text(restaurant.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text([restaurant.cuisine, restaurant.city, restaurant.stateRegion].where((v) => v.isNotEmpty).join(' · ')),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: [
                  if (restaurant.rating > 0 || restaurant.reviewCount > 0)
                    ListTile(leading: const Icon(Icons.star_rounded), title: Text('${restaurant.rating.toStringAsFixed(1)} / 5 · ${restaurant.reviewCount} reviews'), contentPadding: EdgeInsets.zero),
                  if (restaurant.phone.isNotEmpty) ListTile(leading: const Icon(Icons.call_outlined), title: Text(restaurant.phone), subtitle: const UniversalText('Customer contact'), contentPadding: EdgeInsets.zero),
                  if (restaurant.openingHours.isNotEmpty) ListTile(leading: const Icon(Icons.schedule_rounded), title: const UniversalText('Business hours'), subtitle: Text(restaurant.openingHours), contentPadding: EdgeInsets.zero),
                  if (restaurant.address.isNotEmpty) ListTile(leading: const Icon(Icons.place_outlined), title: Text(restaurant.address), subtitle: Text([restaurant.city, restaurant.stateRegion, restaurant.postalCode, restaurant.countryCode].where((v) => v.isNotEmpty).join(', ')), contentPadding: EdgeInsets.zero),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (restaurant.contactMethods.contains('call') && restaurant.phone.isNotEmpty) ActionChip(avatar: const Icon(Icons.call, size: 16), label: const UniversalText('Call'), onPressed: () => _launchRestaurantContact(context, restaurant, 'call')),
                    if (restaurant.contactMethods.contains('sms') && (restaurant.smsNumber?.isNotEmpty ?? false)) ActionChip(avatar: const Icon(Icons.sms_outlined, size: 16), label: const UniversalText('SMS'), onPressed: () => _launchRestaurantContact(context, restaurant, 'sms')),
                    if (restaurant.contactMethods.contains('imessage') && (restaurant.imessageAddress?.isNotEmpty ?? false)) ActionChip(avatar: const Icon(Icons.chat_bubble_outline, size: 16), label: const UniversalText('iMessage'), onPressed: () => _launchRestaurantContact(context, restaurant, 'imessage')),
                    if (restaurant.contactMethods.contains('whatsapp') && (restaurant.whatsappNumber?.isNotEmpty ?? false)) ActionChip(avatar: const Icon(Icons.chat, size: 16), label: const UniversalText('WhatsApp'), onPressed: () => _launchRestaurantContact(context, restaurant, 'whatsapp')),
                    if (restaurant.contactMethods.contains('email') && (restaurant.contactEmail?.isNotEmpty ?? false)) ActionChip(avatar: const Icon(Icons.email_outlined, size: 16), label: const UniversalText('Email'), onPressed: () => _launchRestaurantContact(context, restaurant, 'email')),
                    if (restaurant.contactMethods.contains('website') && (restaurant.website?.isNotEmpty ?? false)) ActionChip(avatar: const Icon(Icons.language, size: 16), label: const UniversalText('Website'), onPressed: () => _launchRestaurantContact(context, restaurant, 'website')),
                  ]),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Chip(label: Text('Delivery ${_money(restaurant.deliveryFeeCents, restaurant.currencyCode)}')),
                    Chip(label: Text('Service ${_money(restaurant.serviceFeeCents, restaurant.currencyCode)}')),
                    Chip(label: Text('Tax ${(restaurant.taxRateBasisPoints / 100).toStringAsFixed(2)}%')),
                    Chip(label: Text('Points ${restaurant.loyaltyPointsPerCurrency} / currency unit')),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _addMenuItem(restaurant), icon: const Icon(Icons.add_rounded), label: const UniversalText('Add menu item'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _createThemedMenu(restaurant), icon: const Icon(Icons.movie_filter_outlined), label: const UniversalText('Create themed menu'))),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: () => _addCoupon(restaurant),
                    icon: const Icon(Icons.local_offer_outlined),
                    label: const UniversalText('Create coupon'),
                  )),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: () => _editRestaurantProfile(restaurant),
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const UniversalText('Edit hours and contact methods'),
                  )),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => FoodConversationInboxScreen(
                            api: widget.api,
                            isMerchant: true,
                            restaurantId: restaurant.id,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.forum_outlined),
                      label: const UniversalText('Open this restaurant’s inbox'),
                    ),
                  ),
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
  List<FoodMenuTheme> _themes = const [];
  final List<FoodCartItem> _cart = [];
  bool _loading = true;
  String? _error;
  String _category = 'All';
  String? _selectedThemeId;

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
      final themes = await widget.api.getFoodMenuThemes(widget.restaurant.id).catchError((_) => <FoodMenuTheme>[]);
      if (!mounted) return;
      setState(() {
        _items = items;
        _themes = themes;
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


  Future<void> _openRestaurantConversation({
    String topic = 'general',
    FoodMenuItem? item,
    String initialDraft = '',
  }) async {
    try {
      final conversation = await widget.api.createFoodConversation(
        restaurantId: widget.restaurant.id,
        topic: topic,
        subject: switch (topic) {
          'recommendation' => 'Food recommendation',
          'ingredient_question' => 'Ingredient and allergy question',
          'order_support' => 'Order support',
          _ => 'Question for ${widget.restaurant.name}',
        },
        relatedMenuItemId: item?.id,
        relatedMenuItemName: item?.name ?? '',
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => FoodConversationScreen(
            api: widget.api,
            conversation: conversation,
            isMerchant: false,
            initialDraft: initialDraft,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
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
    FoodMenuTheme? selectedTheme;
    for (final theme in _themes) {
      if (theme.id == _selectedThemeId) { selectedTheme = theme; break; }
    }
    final selectedThemeForFilter = selectedTheme;
    final visible = selectedThemeForFilter != null
        ? _items.where((item) => selectedThemeForFilter.menuItemIds.contains(item.id)).toList(growable: false)
        : (_category == 'All' ? _items : _items.where((item) => item.category == _category).toList());

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurant.name),
        actions: [
          IconButton(
            tooltip: 'Ask the restaurant for a recommendation',
            onPressed: () => _openRestaurantConversation(
              topic: 'recommendation',
              initialDraft: 'Hi! I’m not sure what to order. What do you recommend?',
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ],
      ),
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
                    if (widget.restaurant.address.isNotEmpty || widget.restaurant.city.isNotEmpty)
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.place_outlined, size: 18), const SizedBox(width: 6),
                        Expanded(child: Text([widget.restaurant.address, widget.restaurant.city, widget.restaurant.stateRegion, widget.restaurant.postalCode, widget.restaurant.countryCode].where((value) => value.trim().isNotEmpty).join(', '))),
                      ]),
                    if (widget.restaurant.openingHours.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.schedule_rounded, size: 18), const SizedBox(width: 6), Expanded(child: Text('Hours: ${widget.restaurant.openingHours}'))]),
                    ],
                    const SizedBox(height: 8),
                    Row(children: [
                      for (var star = 1; star <= 5; star++) Icon(star <= widget.restaurant.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text('${widget.restaurant.rating.toStringAsFixed(1)} / 5 (${widget.restaurant.reviewCount} reviews)'),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => FoodRestaurantReviewsScreen(api: widget.api, restaurant: widget.restaurant))), child: const UniversalText('Read / write reviews')),
                    ]),
                    Wrap(spacing: 7, runSpacing: 6, children: [
                      if (widget.restaurant.contactMethods.contains('call') && widget.restaurant.phone.isNotEmpty) ActionChip(avatar: const Icon(Icons.call, size: 16), label: const UniversalText('Call'), onPressed: () => _launchRestaurantContact(context, widget.restaurant, 'call')),
                      if (widget.restaurant.contactMethods.contains('sms') && (widget.restaurant.smsNumber?.isNotEmpty ?? false)) ActionChip(avatar: const Icon(Icons.sms_outlined, size: 16), label: const UniversalText('SMS'), onPressed: () => _launchRestaurantContact(context, widget.restaurant, 'sms')),
                      if (widget.restaurant.contactMethods.contains('imessage') && (widget.restaurant.imessageAddress?.isNotEmpty ?? false)) ActionChip(avatar: const Icon(Icons.chat_bubble_outline, size: 16), label: const UniversalText('iMessage'), onPressed: () => _launchRestaurantContact(context, widget.restaurant, 'imessage')),
                      if (widget.restaurant.contactMethods.contains('whatsapp') && (widget.restaurant.whatsappNumber?.isNotEmpty ?? false)) ActionChip(avatar: const Icon(Icons.chat, size: 16), label: const UniversalText('WhatsApp'), onPressed: () => _launchRestaurantContact(context, widget.restaurant, 'whatsapp')),
                      if (widget.restaurant.contactMethods.contains('email') && (widget.restaurant.contactEmail?.isNotEmpty ?? false)) ActionChip(avatar: const Icon(Icons.email_outlined, size: 16), label: const UniversalText('Email'), onPressed: () => _launchRestaurantContact(context, widget.restaurant, 'email')),
                      if (widget.restaurant.contactMethods.contains('website') && (widget.restaurant.website?.isNotEmpty ?? false)) ActionChip(avatar: const Icon(Icons.language, size: 16), label: const UniversalText('Website'), onPressed: () => _launchRestaurantContact(context, widget.restaurant, 'website')),
                    ]),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.restaurant.etaMinMinutes}-${widget.restaurant.etaMaxMinutes} min delivery • ${_money(widget.restaurant.deliveryFeeCents, widget.restaurant.currencyCode)} delivery',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    if (widget.viewingContext != null) ...[
                      const SizedBox(height: 8),
                      Chip(avatar: const Icon(Icons.live_tv_rounded), label: Text(widget.viewingContext!)),
                    ],
                    if (_themes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const UniversalText('Themed menus for your movie night', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 118,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final theme in _themes)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: SizedBox(
                                  width: 260,
                                  child: Card(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => setState(() {
                                        _selectedThemeId = _selectedThemeId == theme.id ? null : theme.id;
                                        _category = 'All';
                                      }),
                                      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [const Icon(Icons.movie_filter_outlined), const SizedBox(width: 6), Expanded(child: Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))), if (_selectedThemeId == theme.id) const Icon(Icons.check_circle_rounded, size: 18)]),
                                        const SizedBox(height: 5),
                                        Expanded(child: Text(theme.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white70))),
                                        Text('${theme.menuItemIds.length} menu items', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                      ])),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (selectedTheme != null && selectedTheme.disclosure.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text(selectedTheme.disclosure, style: const TextStyle(fontSize: 11, color: Colors.white54))),
                      if (_selectedThemeId != null)
                        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => _selectedThemeId = null), icon: const Icon(Icons.close), label: const UniversalText('Show full menu'))),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
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
                                    child: const UniversalText('Add'),
                                  ),
                                ],
                              ),
                            ),
                            if (item.ingredients.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Restaurant-listed ingredients: ${item.ingredients.join(', ')}',
                                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                                  ),
                                ),
                              ),
                            if (item.allergens.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      const Chip(label: UniversalText('Restaurant-declared allergens')),
                                      ...item.allergens.take(5).map((allergen) => Chip(label: Text(allergen))),
                                    ],
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _openRestaurantConversation(
                                    topic: 'ingredient_question',
                                    item: item,
                                    initialDraft: 'Hi, I have an ingredient/allergy question about ${item.name}. Does it contain [ingredient]? If it does, can it be removed? Please also confirm whether cross-contact is possible.',
                                  ),
                                  icon: const Icon(Icons.health_and_safety_outlined),
                                  label: const UniversalText('Ask about ingredients or allergies'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}

class FoodConversationInboxScreen extends StatefulWidget {
  final FoodDeliveryApi api;
  final bool isMerchant;
  final String? restaurantId;

  const FoodConversationInboxScreen({
    super.key,
    required this.api,
    required this.isMerchant,
    this.restaurantId,
  });

  @override
  State<FoodConversationInboxScreen> createState() => _FoodConversationInboxScreenState();
}

class _FoodConversationInboxScreenState extends State<FoodConversationInboxScreen> {
  List<FoodConversation> _conversations = const <FoodConversation>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading && mounted) setState(() => _error = null);
    try {
      final conversations = widget.isMerchant
          ? await widget.api.getMerchantConversations(restaurantId: widget.restaurantId)
          : await widget.api.getCustomerConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _status(String value) => switch (value) {
        'waiting_for_restaurant' => 'Waiting for restaurant',
        'waiting_for_customer' => 'Waiting for customer',
        'resolved' => 'Resolved',
        'closed' => 'Closed',
        _ => 'Open',
      };

  @override
  Widget build(BuildContext context) {
    final title = widget.isMerchant ? 'Customer messages and support' : 'Restaurant messages';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_off_outlined, size: 42),
                      const SizedBox(height: 10),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const UniversalText('Try again')),
                    ]),
                  ),
                )
              : _conversations.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Icon(widget.isMerchant ? Icons.mark_unread_chat_alt_outlined : Icons.chat_bubble_outline_rounded, size: 56),
                        const SizedBox(height: 12),
                        Text(
                          widget.isMerchant ? 'No customer messages yet' : 'No restaurant conversations yet',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isMerchant
                              ? 'Customers can ask for recommendations, ingredient details, allergy information, or order support.'
                              : 'Open a restaurant menu and choose Ask the restaurant or Ask about ingredients or allergies.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: _conversations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final conversation = _conversations[index];
                          final customerLabel = conversation.customerDisplayName.trim().isNotEmpty
                              ? conversation.customerDisplayName.trim()
                              : 'Customer';
                          final headline = widget.isMerchant
                              ? (conversation.relatedMenuItemName.isNotEmpty
                                  ? '$customerLabel · ${conversation.relatedMenuItemName}'
                                  : customerLabel)
                              : conversation.restaurantName;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(switch (conversation.topic) {
                                  'ingredient_question' => Icons.health_and_safety_outlined,
                                  'recommendation' => Icons.restaurant_menu_rounded,
                                  'order_support' => Icons.support_agent_rounded,
                                  _ => Icons.chat_bubble_outline_rounded,
                                }),
                              ),
                              title: Text(headline, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(conversation.subject),
                                    if (widget.isMerchant && conversation.restaurantName.isNotEmpty)
                                      Text(conversation.restaurantName, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                    if (conversation.lastMessagePreview.isNotEmpty)
                                      Text(conversation.lastMessagePreview, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 5),
                                    Wrap(spacing: 6, runSpacing: 4, children: [
                                      Chip(label: Text(_status(conversation.status)), visualDensity: VisualDensity.compact),
                                      if (conversation.topic == 'ingredient_question')
                                        const Chip(
                                          avatar: Icon(Icons.health_and_safety_outlined, size: 15),
                                          label: UniversalText('Ingredient safety'),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ]),
                                  ],
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => FoodConversationScreen(
                                      api: widget.api,
                                      conversation: conversation,
                                      isMerchant: widget.isMerchant,
                                    ),
                                  ),
                                );
                                if (mounted) _load();
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class FoodConversationScreen extends StatefulWidget {
  final FoodDeliveryApi api;
  final FoodConversation conversation;
  final bool isMerchant;
  final String initialDraft;

  const FoodConversationScreen({
    super.key,
    required this.api,
    required this.conversation,
    required this.isMerchant,
    this.initialDraft = '',
  });

  @override
  State<FoodConversationScreen> createState() => _FoodConversationScreenState();
}

class _FoodConversationScreenState extends State<FoodConversationScreen> {
  late final TextEditingController _composer;
  final FocusNode _composerFocus = FocusNode();
  final ScrollController _messagesScroll = ScrollController();
  FoodConversation? _conversation;
  List<FoodMenuItem> _menuItems = const <FoodMenuItem>[];
  Timer? _pollTimer;
  bool _loading = true;
  bool _sending = false;
  bool _menuLoaded = false;
  String? _error;
  String _draftMessageType = 'text';
  int _lastMessageCount = 0;

  bool get _isMerchant => widget.isMerchant;
  FoodConversation get _activeConversation => _conversation ?? widget.conversation;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _composer = TextEditingController(text: widget.initialDraft);
    _loadThread();
    if (_isMerchant) _loadMenuItems();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_sending) _loadThread(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _composer.dispose();
    _composerFocus.dispose();
    _messagesScroll.dispose();
    super.dispose();
  }

  Future<void> _loadThread({bool silent = false}) async {
    if (!silent && mounted) setState(() => _error = null);
    try {
      final updated = await widget.api.getFoodConversation(_activeConversation.id);
      if (!mounted) return;
      final count = updated.messages.length;
      final wasInitialLoad = _loading;
      final hasNewMessage = count > _lastMessageCount;
      setState(() {
        _conversation = updated;
        _loading = false;
        _error = null;
        _lastMessageCount = count;
      });
      if (hasNewMessage || wasInitialLoad) _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadMenuItems() async {
    if (_menuLoaded || _activeConversation.restaurantId.isEmpty) return;
    _menuLoaded = true;
    try {
      final items = await widget.api.getMenu(_activeConversation.restaurantId);
      if (mounted) setState(() => _menuItems = items.where((item) => item.available).toList(growable: false));
    } catch (_) {
      // Chat and ingredient replies still work if the menu request fails.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _messagesScroll.hasClients) {
        _messagesScroll.animateTo(
          _messagesScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _setDraft(String body, {String messageType = 'text'}) {
    setState(() {
      _composer.value = TextEditingValue(
        text: body,
        selection: TextSelection.collapsed(offset: body.length),
      );
      _draftMessageType = messageType;
    });
    _composerFocus.requestFocus();
  }

  Future<void> _send({String? messageType, Map<String, dynamic> metadata = const <String, dynamic>{}}) async {
    await _sendPrepared(_composer.text, messageType: messageType ?? _draftMessageType, metadata: metadata, clearComposer: true);
  }

  Future<void> _sendPrepared(
    String body, {
    required String messageType,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    bool clearComposer = false,
  }) async {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty || _sending) return;
    if (cleanBody.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('Messages must be 2000 characters or fewer.')));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final conversation = await widget.api.sendFoodConversationMessage(
        conversationId: _activeConversation.id,
        body: cleanBody,
        messageType: messageType,
        metadata: metadata,
      );
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _lastMessageCount = conversation.messages.length;
        _draftMessageType = 'text';
        if (clearComposer) _composer.clear();
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error!)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _recommendMenuItem() async {
    if (_menuItems.isEmpty) await _loadMenuItems();
    if (!mounted) return;
    if (_menuItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: UniversalText('No available menu items were found. You can still type a recommendation.')));
      return;
    }
    var selectedId = _menuItems.first.id;
    final reason = TextEditingController();
    final choice = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const UniversalText('Recommend a menu item'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Menu item'),
                items: _menuItems.map((item) => DropdownMenuItem<String>(value: item.id, child: Text(item.name, overflow: TextOverflow.ellipsis))).toList(growable: false),
                onChanged: (value) { if (value != null) setDialogState(() => selectedId = value); },
              ),
              const SizedBox(height: 10),
              TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Why do you recommend it? (optional)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const UniversalText('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, {'id': selectedId, 'reason': reason.text.trim()}), child: const UniversalText('Send recommendation')),
          ],
        ),
      ),
    );
    reason.dispose();
    if (choice == null) return;
    final item = _menuItems.firstWhere((value) => value.id == choice['id'], orElse: () => _menuItems.first);
    final why = choice['reason']?.trim() ?? '';
    final body = 'I recommend ${item.name}.${why.isEmpty ? '' : ' $why'}';
    await _sendPrepared(body, messageType: 'recommendation', clearComposer: true, metadata: {
      'recommendedMenuItemId': item.id,
      'recommendedMenuItemName': item.name,
    });
  }

  Future<void> _answerIngredientQuestion() async {
    final ingredient = TextEditingController();
    var presence = 'contains';
    var removal = 'cannot_remove';
    var crossContact = 'not_confirmed';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const UniversalText('Restaurant ingredient answer'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: ingredient,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(labelText: 'Ingredient the customer asked about'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: presence,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'What do your current recipe records say?'),
                  items: const [
                    DropdownMenuItem(value: 'contains', child: UniversalText('Confirmed: it contains this ingredient')),
                    DropdownMenuItem(value: 'not_listed', child: UniversalText('Not present in the current recipe records')),
                    DropdownMenuItem(value: 'cannot_confirm', child: UniversalText('Cannot confirm ingredients')),
                  ],
                  onChanged: (value) { if (value != null) setDialogState(() => presence = value); },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: removal,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Can the kitchen remove it?'),
                  items: const [
                    DropdownMenuItem(value: 'can_remove', child: UniversalText('Yes, kitchen confirms it can be removed')),
                    DropdownMenuItem(value: 'cannot_remove', child: UniversalText('No, it cannot be removed')),
                    DropdownMenuItem(value: 'not_confirmed', child: UniversalText('Removal has not been confirmed')),
                  ],
                  onChanged: (value) { if (value != null) setDialogState(() => removal = value); },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: crossContact,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cross-contact during preparation'),
                  items: const [
                    DropdownMenuItem(value: 'cannot_rule_out', child: UniversalText('Cannot be ruled out')),
                    DropdownMenuItem(value: 'controls_confirmed', child: UniversalText('Kitchen confirms separate precautions')),
                    DropdownMenuItem(value: 'not_confirmed', child: UniversalText('Not confirmed')),
                  ],
                  onChanged: (value) { if (value != null) setDialogState(() => crossContact = value); },
                ),
                const SizedBox(height: 8),
                const UniversalText('Only select answers you have checked with your current recipe and kitchen process. This response is not a medical guarantee.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const UniversalText('Cancel')),
            FilledButton(
              onPressed: ingredient.text.trim().isEmpty ? null : () => Navigator.pop(dialogContext, {
                'ingredient': ingredient.text.trim(),
                'presence': presence,
                'removal': removal,
                'crossContact': crossContact,
              }),
              child: const UniversalText('Send confirmed answer'),
            ),
          ],
        ),
      ),
    );
    ingredient.dispose();
    if (result == null) return;
    final name = result['ingredient']!;
    final itemName = _activeConversation.relatedMenuItemName.trim();
    final itemLabel = itemName.isEmpty ? 'this item' : '"$itemName"';
    final presenceAnswer = switch (result['presence']) {
      'contains' => 'The restaurant confirms that $itemLabel contains $name.',
      'not_listed' => 'According to the restaurant’s current recipe records, $name is not listed in $itemLabel. This does not rule out cross-contact.',
      _ => 'The restaurant cannot confirm whether $itemLabel contains $name.',
    };
    final removalAnswer = result['presence'] == 'contains'
        ? switch (result['removal']) {
            'can_remove' => 'The kitchen confirms that it can remove $name from $itemLabel on request.',
            'cannot_remove' => 'The kitchen confirms that it cannot remove $name from $itemLabel.',
            _ => 'Whether the kitchen can remove $name has not been confirmed.',
          }
        : result['presence'] == 'cannot_confirm'
            ? 'Because the ingredients have not been confirmed, removal of $name cannot be treated as confirmed either.'
            : '';
    final crossContactAnswer = switch (result['crossContact']) {
      'cannot_rule_out' => 'Cross-contact with $name cannot be ruled out.',
      'controls_confirmed' => 'The restaurant says the kitchen follows separate preparation precautions, but this is not a medical guarantee.',
      _ => 'The kitchen’s cross-contact handling has not been confirmed.',
    };
    await _sendPrepared(
      [presenceAnswer, removalAnswer, crossContactAnswer].where((part) => part.isNotEmpty).join('\n'),
      messageType: 'ingredient_answer',
      clearComposer: true,
      metadata: {
        'ingredient': name,
        'presence': result['presence'],
        'removal': result['removal'],
        'crossContact': result['crossContact'],
        'restaurantConfirmed': true,
      },
    );
  }

  String _messageTypeLabel(String type) => switch (type) {
        'recommendation_request' => 'Recommendation request',
        'recommendation' => 'Restaurant recommendation',
        'ingredient_question' => 'Ingredient / allergy question',
        'ingredient_answer' => 'Restaurant ingredient response · not a medical guarantee',
        'order_support' => 'Order support',
        'support_update' => 'Support update',
        _ => '',
      };

  String _timeLabel(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _activeConversation;
    final ingredientTopic = conversation.topic == 'ingredient_question' ||
        conversation.messages.any((message) => message.messageType == 'ingredient_question' || message.messageType == 'ingredient_answer');
    final ownRole = _isMerchant ? 'restaurant' : 'customer';
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _isMerchant
                ? (conversation.customerDisplayName.trim().isEmpty ? 'Customer' : conversation.customerDisplayName.trim())
                : conversation.restaurantName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(conversation.subject, style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          IconButton(tooltip: 'Refresh conversation', onPressed: _sending ? null : () => _loadThread(), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          if (conversation.relatedMenuItemName.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(children: [
                const Icon(Icons.restaurant_menu_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('About: ${conversation.relatedMenuItemName}', style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
          if (ingredientTopic)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.amber.withValues(alpha: 0.12),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.health_and_safety_outlined, color: Colors.amber),
                SizedBox(width: 9),
                Expanded(child: UniversalText('Allergy safety: wait for the restaurant’s explicit response. Menu details and chat are not a medical guarantee. If the kitchen cannot confirm ingredients or cross-contact handling, do not order the item if exposure could be unsafe.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                )),
              ]),
            ),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              leading: const Icon(Icons.error_outline_rounded),
              actions: [TextButton(onPressed: () => _loadThread(), child: const UniversalText('Retry'))],
            ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: conversation.messages.isEmpty && !_loading
                ? ListView(
                    controller: _messagesScroll,
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 24),
                      const Icon(Icons.forum_outlined, size: 54),
                      const SizedBox(height: 12),
                      Text(
                        _isMerchant ? 'Reply to your customer' : 'Ask the restaurant directly',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isMerchant
                            ? 'Use the suggested actions for recommendations and ingredient questions. Only send ingredient answers that the kitchen has confirmed.'
                            : 'Ask for a recommendation, check ingredients, or get help with your order. A restaurant staff member must confirm any allergy-related answer.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _messagesScroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                    itemCount: conversation.messages.length,
                    itemBuilder: (context, index) {
                      final message = conversation.messages[index];
                      final isOwn = message.senderRole == ownRole;
                      final isIngredientAnswer = message.messageType == 'ingredient_answer';
                      return Align(
                        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                            decoration: BoxDecoration(
                              color: isIngredientAnswer
                                  ? Colors.amber.withValues(alpha: 0.14)
                                  : isOwn
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              border: isIngredientAnswer ? Border.all(color: Colors.amber.withValues(alpha: 0.65)) : null,
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (_messageTypeLabel(message.messageType).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Text(
                                    _messageTypeLabel(message.messageType),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isIngredientAnswer ? Colors.amber : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)),
                                  ),
                                ),
                              SelectableText(message.body),
                              const SizedBox(height: 5),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(_timeLabel(message.createdAt), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!_isMerchant && conversation.messages.length < 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 6, runSpacing: 3, children: [
                  ActionChip(
                    avatar: const Icon(Icons.restaurant_menu_rounded, size: 16),
                    label: const UniversalText('What do you recommend?'),
                    onPressed: () => _setDraft('Hi! I’m not sure what to order. What do you recommend?', messageType: 'recommendation_request'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.health_and_safety_outlined, size: 16),
                    label: const UniversalText('Ingredient / allergy question'),
                    onPressed: () => _setDraft(
                      'Does [menu item] contain [ingredient]? I am allergic. If it contains it, can the kitchen remove it? Please also tell me whether cross-contact is possible.',
                      messageType: 'ingredient_question',
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.support_agent_rounded, size: 16),
                    label: const UniversalText('Order support'),
                    onPressed: () => _setDraft('Hi, I need help with an order. ', messageType: 'order_support'),
                  ),
                ]),
              ),
            ),
          if (_isMerchant)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 6, runSpacing: 3, children: [
                  ActionChip(
                    avatar: const Icon(Icons.restaurant_menu_rounded, size: 16),
                    label: const UniversalText('Recommend a menu item'),
                    onPressed: _sending ? null : _recommendMenuItem,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.health_and_safety_outlined, size: 16),
                    label: const UniversalText('Answer ingredient question'),
                    onPressed: _sending ? null : _answerIngredientQuestion,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.support_agent_rounded, size: 16),
                    label: const UniversalText('Order support reply'),
                    onPressed: () => _setDraft('Thanks for contacting us about your order. ', messageType: 'order_support'),
                  ),
                ]),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    controller: _composer,
                    focusNode: _composerFocus,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Write a message…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      counterText: '',
                    ),
                    onChanged: (_) {
                      if (_draftMessageType.isEmpty) _draftMessageType = 'text';
                    },
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: _sending || _activeConversation.status == 'closed' ? null : () => _send(),
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                ),
              ]),
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
      appBar: AppBar(title: const UniversalText('Checkout')),
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
                      ButtonSegment<String>(value: 'delivery', label: UniversalText('Delivery'), icon: Icon(Icons.delivery_dining_rounded)),
                      ButtonSegment<String>(value: 'pickup', label: UniversalText('Pickup'), icon: Icon(Icons.storefront_rounded)),
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
                      title: const UniversalText('Pick up at the restaurant'),
                      subtitle: Text('${widget.restaurant.address}${widget.restaurant.city.isEmpty ? '' : ', ${widget.restaurant.city}'}${widget.restaurant.phone.isEmpty ? '' : '\n${widget.restaurant.phone}'}\nNo delivery fee is charged for pickup.'),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const UniversalText('Delivery address', style: TextStyle(fontWeight: FontWeight.w900)),
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
                      const UniversalText('Restaurant coupon', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextField(controller: _couponController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Coupon code', hintText: 'WELCOME10'))),
                        const SizedBox(width: 8),
                        FilledButton.tonal(onPressed: _couponBusy ? null : _applyCoupon, child: _couponBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const UniversalText('Apply')),
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
                      const UniversalText('Payment', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      if (_paymentMethods.isEmpty)
                        const UniversalText('No saved payment methods are available. Add one in account payment settings first.', style: TextStyle(color: Colors.white60))
                      else
                        RadioGroup<FoodPaymentMethod>(
                          groupValue: _selectedPayment,
                          onChanged: (value) => setState(() => _selectedPayment = value),
                          child: Column(children: [
                            for (final method in _paymentMethods)
                              RadioListTile<FoodPaymentMethod>(
                                value: method,
                                title: Text(method.displayName),
                                subtitle: method.preferred ? const UniversalText('Preferred') : null,
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
      appBar: AppBar(title: const UniversalText('Order tracking')),
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
                    const UniversalText('Estimated time:', style: TextStyle(color: Colors.white60)),
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
                  const Align(alignment: Alignment.centerLeft, child: UniversalText('Order total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
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
              label: const UniversalText('Refresh status'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _order.restaurantId.isEmpty
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final conversation = await widget.api.createFoodConversation(
                          restaurantId: _order.restaurantId,
                          topic: 'order_support',
                          subject: 'Order support · #${_order.id.substring(0, math.min(8, _order.id.length))}',
                          orderId: _order.id,
                        );
                        if (!mounted) return;
                        await navigator.push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => FoodConversationScreen(
                              api: widget.api,
                              conversation: conversation,
                              isMerchant: false,
                              initialDraft: 'Hi, I have a question about order #${_order.id.substring(0, math.min(8, _order.id.length))}.',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.support_agent_rounded),
              label: const UniversalText('Message restaurant about this order'),
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

List<String> _splitIngredientField(String value) {
  final seen = <String>{};
  final result = <String>[];
  for (final part in value.split(RegExp(r'[,;\n]'))) {
    final ingredient = part.trim();
    if (ingredient.isEmpty || ingredient.length > 80) continue;
    if (seen.add(ingredient.toLowerCase())) result.add(ingredient);
    if (result.length == 80) break;
  }
  return result;
}

String _displayTime(String raw) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (match == null) return raw.trim();
  final hour = int.tryParse(match.group(1) ?? '') ?? 0;
  final minute = match.group(2) ?? '00';
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:$minute $suffix';
}

Map<String, dynamic> _stringMap(dynamic value) {
  if (value is! Map) return const <String, dynamic>{};
  return Map<String, dynamic>.from(value);
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
