// FILE: Backend/services/food_delivery_service.dart
// Purpose: Restaurant discovery, menu retrieval, secure order creation, and ETA.
// Payment credentials remain in the backend/provider layer.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../models/account.dart';
import '../services/payment_method_service.dart';
import '../supabase_store.dart';
import 'food_directory_provider.dart';

class FoodDeliveryService {
  static const int defaultLimit = 50;
  static const int maxLimit = 100;
  static const double defaultRadiusKm = 10;
  static const double maxRadiusKm = 50;
  static const int maxOrderItems = 100;
  static const int maxQuantityPerLine = 50;

  final PaymentMethodService paymentMethods;

  FoodDeliveryService({
    required this.paymentMethods,
  });

  /// Platform-owned fee. Merchants cannot override the platform's service fee.
  /// Set FOOD_PLATFORM_SERVICE_FEE_CENTS in the backend environment to change it.
  int get platformServiceFeeCents {
    final configured = int.tryParse(
      (Platform.environment['FOOD_PLATFORM_SERVICE_FEE_CENTS'] ?? '').trim(),
    );
    return (configured ?? 199).clamp(0, 1000000).toInt();
  }

  Future<List<Map<String, dynamic>>> nearbyRestaurants({
    required double latitude,
    required double longitude,
    String query = '',
    double radiusKm = defaultRadiusKm,
    int limit = defaultLimit,
  }) async {
    _validateCoordinates(latitude, longitude);
    final radius = radiusKm.clamp(0.5, maxRadiusKm).toDouble();
    final safeLimit = limit.clamp(1, maxLimit).toInt();

    final rows = await SupabaseStore.instance.searchFoodRestaurants(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radius,
      query: query.trim(),
      // Fetch a broad candidate set before exact radial filtering; bounding-box
      // searches can include nearby corner results outside the requested radius.
      limit: maxLimit,
    );

    final results = rows.map((row) {
      final lat = _toDouble(row['latitude']);
      final lon = _toDouble(row['longitude']);
      final distance = _distanceKm(latitude, longitude, lat, lon);
      final output = Map<String, dynamic>.from(row);
      output['distanceKm'] = double.parse(distance.toStringAsFixed(2));
      output['isOrderable'] = true;
      output['isOpenKnown'] = true;
      output['serviceFeeCents'] = platformServiceFeeCents;
      output['service_fee_cents'] = platformServiceFeeCents;
      return output;
    }).where((row) => _toDouble(row['distanceKm']) <= radius).toList();

    // Merge a public, OSM-backed directory lookup with platform merchants. An
    // external directory result is informational only until its owner registers
    // the restaurant and creates a platform menu. Keep actual merchants first.
    final externalRows = await FoodDirectoryProvider.instance.nearby(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radius,
      limit: safeLimit,
    );
    final registeredKeys = results.map(_restaurantDedupKey).toSet();
    final q = query.trim().toLowerCase();
    for (final external in externalRows) {
      external['serviceFeeCents'] = platformServiceFeeCents;
      external['service_fee_cents'] = platformServiceFeeCents;
      if (q.isNotEmpty) {
        final searchable = [
          external['name'], external['cuisine'], external['address'],
          external['city'], external['stateRegion'], external['postalCode'],
        ].whereType<Object>().join(' ').toLowerCase();
        if (!searchable.contains(q)) continue;
      }
      final key = _restaurantDedupKey(external);
      if (registeredKeys.contains(key)) continue;
      final externalName = _restaurantNameKey(external);
      final externalDistance = _toDouble(external['distanceKm']);
      final likelyDuplicate = results.any((registered) =>
          _restaurantNameKey(registered) == externalName &&
          (_toDouble(registered['distanceKm']) - externalDistance).abs() < 0.5);
      if (likelyDuplicate) continue;
      results.add(external);
    }

    results.sort((a, b) {
      final aPlatform = a['isOrderable'] != false;
      final bPlatform = b['isOrderable'] != false;
      if (aPlatform != bPlatform) return aPlatform ? -1 : 1;
      final aKnownOpen = a['isOpenKnown'] != false;
      final bKnownOpen = b['isOpenKnown'] != false;
      if (aKnownOpen != bKnownOpen) return aKnownOpen ? -1 : 1;
      final aOpen = a['is_open'] != false && a['isOpen'] != false;
      final bOpen = b['is_open'] != false && b['isOpen'] != false;
      if (aKnownOpen && bKnownOpen && aOpen != bOpen) return aOpen ? -1 : 1;
      return _toDouble(a['distanceKm']).compareTo(_toDouble(b['distanceKm']));
    });

    return results.take(safeLimit).toList(growable: false);
  }

  String _restaurantNameKey(Map<String, dynamic> row) =>
      (row['name']?.toString() ?? '').trim().toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  String _restaurantDedupKey(Map<String, dynamic> row) {
    final name = (row['name']?.toString() ?? '').trim().toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final address = (row['address']?.toString() ?? '').trim().toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '$name|$address';
  }

  Future<Map<String, dynamic>> restaurant(String restaurantId) async {
    final cleanId = _required(restaurantId, 'restaurantId', 256);
    final row = await SupabaseStore.instance.getFoodRestaurant(cleanId);
    if (row == null) throw StateError('Restaurant not found.');
    return {
      ...row,
      'serviceFeeCents': platformServiceFeeCents,
      'service_fee_cents': platformServiceFeeCents,
    };
  }

  Future<List<Map<String, dynamic>>> restaurantReviews(String restaurantId) async {
    final cleanId = _required(restaurantId, 'restaurantId', 256);
    if (await SupabaseStore.instance.getFoodRestaurant(cleanId) == null) {
      throw StateError('Restaurant not found.');
    }
    return SupabaseStore.instance.getFoodRestaurantReviews(cleanId);
  }

  Future<Map<String, dynamic>> submitRestaurantReview({
    required Account account,
    required String restaurantId,
    required int rating,
    String title = '',
    String body = '',
  }) async {
    final cleanId = _required(restaurantId, 'restaurantId', 256);
    if (rating < 1 || rating > 5) throw ArgumentError('Choose a rating from 1 to 5 stars.');
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.length > 120 || cleanBody.length > 2000) {
      throw ArgumentError('Review title must be 120 characters or fewer and review text 2,000 or fewer.');
    }
    if (cleanTitle.isEmpty && cleanBody.isEmpty) {
      throw ArgumentError('Add a short review or a title before submitting.');
    }
    if (await SupabaseStore.instance.getFoodRestaurant(cleanId) == null) {
      throw StateError('Restaurant not found.');
    }
    return SupabaseStore.instance.upsertFoodRestaurantReview(
      restaurantId: cleanId,
      accountExternalId: account.id,
      rating: rating,
      title: cleanTitle,
      body: cleanBody,
    );
  }

  Future<Map<String, dynamic>> updateRestaurantProfile({
    required Account account,
    required String restaurantId,
    required Map<String, dynamic> data,
  }) async {
    final cleanId = _required(restaurantId, 'restaurantId', 256);
    if (!await SupabaseStore.instance.ownsFoodRestaurant(
      accountExternalId: account.id,
      restaurantId: cleanId,
    )) {
      throw StateError('You do not have permission to edit this restaurant.');
    }
    final fields = <String, dynamic>{};
    if (data.containsKey('openingHours')) {
      fields['openingHours'] = _required(data['openingHours'], 'openingHours', 300);
    }
    if (data.containsKey('businessHours')) {
      if (data['businessHours'] is! Map) throw ArgumentError('businessHours must be a weekday schedule object.');
      fields['businessHours'] = _normalizeBusinessHours(data['businessHours']);
    }
    if (data.containsKey('contactMethods')) {
      final methods = _cleanStringList(data['contactMethods']).toSet();
      const allowed = {'call','sms','imessage','whatsapp','email','website'};
      if (!allowed.containsAll(methods)) throw ArgumentError('One or more restaurant contact methods are not supported.');
      fields['contactMethods'] = methods.toList(growable: false);
    }
    if (data.containsKey('phone')) fields['phone'] = _cleanOptionalContact(data['phone'], 'phone', 40) ?? '';
    for (final field in ['contactEmail','whatsappNumber','imessageAddress','smsNumber']) {
      if (data.containsKey(field)) fields[field] = _cleanOptionalContact(data[field], field, field == 'contactEmail' || field == 'imessageAddress' ? 254 : 40);
    }
    if (data.containsKey('website')) fields['website'] = _safeOptionalUrl(data['website']);
    if (data.containsKey('is24_7')) fields['is24_7'] = data['is24_7'] == true;
    if (fields.isEmpty) throw ArgumentError('No restaurant profile changes were provided.');
    return SupabaseStore.instance.updateFoodRestaurantProfile(restaurantId: cleanId, fields: fields);
  }

  Future<List<Map<String, dynamic>>> menuThemes(String restaurantId) async {
    final cleanId = _required(restaurantId, 'restaurantId', 256);
    if (await SupabaseStore.instance.getFoodRestaurant(cleanId) == null) {
      throw StateError('Restaurant not found.');
    }
    return SupabaseStore.instance.getFoodMenuThemes(cleanId);
  }

  Future<Map<String, dynamic>> createMenuTheme({
    required Account account,
    required String restaurantId,
    required Map<String, dynamic> data,
  }) async {
    final cleanId = _required(restaurantId, 'restaurantId', 256);
    if (!await SupabaseStore.instance.ownsFoodRestaurant(accountExternalId: account.id, restaurantId: cleanId)) {
      throw StateError('You do not have permission to manage this restaurant.');
    }
    final name = _required(data['name'], 'name', 120);
    final keyInput = (data['themeKey']?.toString() ?? name).trim().toLowerCase();
    final themeKey = keyInput.replaceAll(RegExp(r'[^a-z0-9_-]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (themeKey.length < 2 || themeKey.length > 64) throw ArgumentError('Theme key must be 2–64 letters, numbers, dashes, or underscores.');
    final menuItemIds = _cleanStringList(data['menuItemIds']).toSet().toList(growable: false);
    if (menuItemIds.isEmpty) throw ArgumentError('Select at least one menu item for the themed menu.');
    final description = (data['description']?.toString() ?? '').trim();
    final inspiration = (data['inspiration']?.toString() ?? '').trim();
    if (description.length > 1200 || inspiration.length > 120) throw ArgumentError('The themed-menu description or inspiration is too long.');
    final validItems = await SupabaseStore.instance.getFoodMenu(cleanId);
    final validIds = validItems.map((item) => item['id']?.toString() ?? '').toSet();
    if (menuItemIds.any((id) => !validIds.contains(id))) throw ArgumentError('The selected menu contains an item that is not part of this restaurant.');
    return SupabaseStore.instance.createFoodMenuTheme(
      restaurantId: cleanId,
      theme: {
        'themeKey': themeKey,
        'name': name,
        'description': description,
        'inspiration': inspiration,
        'disclosure': (data['disclosure']?.toString() ?? '').trim().isEmpty
            ? 'Fan-inspired menu concept; not an official or affiliated offering unless expressly licensed.'
            : (data['disclosure']?.toString() ?? '').trim(),
      },
      menuItemIds: menuItemIds,
    );
  }

  Future<List<Map<String, dynamic>>> menu(String restaurantId, {String query = ''}) async {
    final cleanId = _required(restaurantId, 'restaurantId', 256);
    final rows = await SupabaseStore.instance.getFoodMenu(cleanId);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((row) {
      final fields = [
        row['name']?.toString() ?? '',
        row['description']?.toString() ?? '',
        row['category']?.toString() ?? '',
        if (row['tags'] is List) ...(row['tags'] as List).map((e) => e.toString()),
      ].join(' ').toLowerCase();
      return fields.contains(q);
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> paymentMethodCatalog({
    required String countryCode,
    required String currencyCode,
  }) {
    return paymentMethods.catalog
        .where((method) =>
            method.buyerSupported &&
            method.supportsCountry(countryCode) &&
            method.supportsCurrency(currencyCode))
        .map((method) => method.toJson())
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createOrder({
    required Account account,
    required String profileId,
    required String restaurantId,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> deliveryAddress,
    required String paymentMethodId,
    String deliveryNotes = '',
    String? viewingContext,
    String fulfillmentMethod = 'delivery',
    String couponCode = '',
  }) async {
    final cleanRestaurantId = _required(restaurantId, 'restaurantId', 256);
    final cleanProfileId = _required(profileId, 'profileId', 256);
    if (items.isEmpty || items.length > maxOrderItems) {
      throw ArgumentError('The order must contain between 1 and $maxOrderItems lines.');
    }
    final fulfillment = fulfillmentMethod.trim().toLowerCase();
    if (fulfillment != 'delivery' && fulfillment != 'pickup') {
      throw ArgumentError('fulfillmentMethod must be delivery or pickup.');
    }
    if (fulfillment == 'delivery' && deliveryAddress.isEmpty) {
      throw ArgumentError('A delivery address is required for delivery orders.');
    }
    if (fulfillment == 'delivery' &&
        (deliveryAddress['addressLine1']?.toString().trim().isEmpty ?? true)) {
      throw ArgumentError('A house/building number and street address are required for delivery.');
    }

    final restaurant = await SupabaseStore.instance.getFoodRestaurant(cleanRestaurantId);
    if (restaurant == null) throw StateError('Restaurant not found.');
    if (restaurant['is_open'] == false) throw StateError('This restaurant is currently closed.');
    if (fulfillment == 'delivery' && restaurant['allows_delivery'] == false) {
      throw StateError('This restaurant does not offer delivery.');
    }
    if (fulfillment == 'pickup' && restaurant['allows_pickup'] == false) {
      throw StateError('This restaurant does not offer pickup.');
    }

    final menuRows = await SupabaseStore.instance.getFoodMenu(cleanRestaurantId);
    final menuById = <String, Map<String, dynamic>>{
      for (final row in menuRows) row['id']?.toString() ?? '': row,
    }..remove('');

    var subtotalCents = 0;
    final orderLines = <Map<String, dynamic>>[];

    for (final raw in items) {
      final menuItemId = _required(raw['menuItemId'], 'menuItemId', 256);
      final quantity = _toInt(raw['quantity']);
      if (quantity < 1 || quantity > maxQuantityPerLine) {
        throw ArgumentError('Each food item quantity must be between 1 and $maxQuantityPerLine.');
      }
      final menuItem = menuById[menuItemId];
      if (menuItem == null || menuItem['available'] == false) {
        throw StateError('A selected menu item is unavailable. Refresh the menu and try again.');
      }

      final basePrice = _toInt(menuItem['price_cents']);
      final modifiers = raw['modifierIds'] is List
          ? List<String>.from((raw['modifierIds'] as List).map((e) => e.toString()))
          : const <String>[];
      final modifierDelta = _modifierDelta(menuItem, modifiers);
      final unit = basePrice + modifierDelta;
      final lineTotal = unit * quantity;
      subtotalCents += lineTotal;
      orderLines.add({
        'menuItemId': menuItemId,
        'itemName': menuItem['name']?.toString() ?? 'Item',
        'quantity': quantity,
        'unitPriceCents': unit,
        'modifiers': modifiers,
        'lineTotalCents': lineTotal,
      });
    }

    final minimum = _toInt(restaurant['minimum_order_cents']);
    if (subtotalCents < minimum) {
      throw StateError('This restaurant has a minimum order of $minimum cents.');
    }

    final coupon = couponCode.trim().toUpperCase();
    var discountCents = 0;
    Map<String, dynamic>? appliedCoupon;
    if (coupon.isNotEmpty) {
      appliedCoupon = await _validatedCoupon(
        restaurantId: cleanRestaurantId,
        code: coupon,
        subtotalCents: subtotalCents,
      );
      final percent = _toInt(appliedCoupon['discount_percent']);
      discountCents = (subtotalCents * percent / 100).round();
    }
    final taxableSubtotal = max(0, subtotalCents - discountCents);
    final taxRateBps = _toInt(restaurant['tax_rate_basis_points']);
    final taxCents = (taxableSubtotal * taxRateBps / 10000).round();
    final serviceFee = platformServiceFeeCents;
    final deliveryFee = fulfillment == 'delivery'
        ? max(0, _toInt(restaurant['delivery_fee_cents']))
        : 0;
    final total = taxableSubtotal + taxCents + serviceFee + deliveryFee;
    final pointsRate = max(0, _toInt(restaurant['loyalty_points_per_currency'], fallback: 1));
    final pointsEarned = (taxableSubtotal ~/ 100) * pointsRate;
    final currency =
        (restaurant['currency_code']?.toString() ?? 'USD').toUpperCase();

    final method = paymentMethods.byId(paymentMethodId.trim());
    if (method == null || !method.buyerSupported) {
      throw StateError('The selected payment method is not available for food delivery.');
    }
    if (!method.supportsCurrency(currency)) {
      throw StateError('The selected payment method does not support this restaurant currency.');
    }

    // Production payment processing is intentionally explicit. Set
    // FOOD_PAYMENT_MOCK=true only for local development. Real deployments must
    // configure a payment-provider adapter before orders can be marked paid.
    final mockPayment =
        (Platform.environment['FOOD_PAYMENT_MOCK'] ?? '')
                .trim()
                .toLowerCase() ==
            'true';
    if (!mockPayment) {
      throw StateError(
        'Food-order payment is not enabled yet. Configure a food-order payment adapter; '
        'FOOD_PAYMENT_MOCK=true is available only for local development.',
      );
    }

    final now = DateTime.now().toUtc();
    final etaMin = max(15, _toInt(restaurant['eta_min_minutes'], fallback: 30));
    final etaMax = max(etaMin, _toInt(restaurant['eta_max_minutes'], fallback: etaMin + 15));
    final etaAt = now.add(Duration(minutes: etaMax));

    final order = await SupabaseStore.instance.createFoodOrder(
      accountExternalId: account.id,
      profileId: cleanProfileId,
      restaurantId: cleanRestaurantId,
      paymentMethodId: method.id,
      status: 'placed',
      paymentStatus: mockPayment ? 'succeeded' : 'authorized',
      subtotalCents: subtotalCents,
      deliveryFeeCents: deliveryFee,
      taxCents: taxCents,
      serviceFeeCents: serviceFee,
      discountCents: discountCents,
      couponCode: appliedCoupon == null ? null : coupon,
      fulfillmentMethod: fulfillment,
      pointsEarned: pointsEarned,
      totalCents: total,
      currencyCode: currency,
      deliveryAddress: deliveryAddress,
      deliveryNotes: deliveryNotes.trim(),
      viewingContext: viewingContext?.trim(),
      estimatedDeliveryAt: etaAt,
      items: orderLines,
    );

    if (appliedCoupon != null && appliedCoupon['id'] != null) {
      await SupabaseStore.instance.incrementFoodCouponRedemption(
        appliedCoupon['id'].toString(),
      );
    }

    return {
      ...order,
      'restaurantName': restaurant['name']?.toString() ?? 'Restaurant',
      'etaMinMinutes': etaMin,
      'etaMaxMinutes': etaMax,
      'currencyCode': currency,
      'subtotalCents': subtotalCents,
      'taxCents': taxCents,
      'deliveryFeeCents': deliveryFee,
      'serviceFeeCents': serviceFee,
      'discountCents': discountCents,
      'couponCode': appliedCoupon == null ? null : coupon,
      'fulfillmentMethod': fulfillment,
      'pointsEarned': pointsEarned,
      'totalCents': total,
    };
  }

  Future<List<Map<String, dynamic>>> merchantRestaurants(Account account) async {
    final rows = await SupabaseStore.instance.getOwnedFoodRestaurants(account.id);
    return rows.map((row) => {
      ...row,
      'serviceFeeCents': platformServiceFeeCents,
      'service_fee_cents': platformServiceFeeCents,
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>> createRestaurant({
    required Account account,
    required Map<String, dynamic> data,
  }) async {
    final name = _required(data['name'], 'name', 120);
    final cuisine = _required(data['cuisine'], 'cuisine', 80);
    final address = _required(data['address'], 'address', 240);
    final lat = _toDouble(data['latitude']);
    final lon = _toDouble(data['longitude']);
    _validateCoordinates(lat, lon);
    final countryCode = (data['countryCode']?.toString() ?? '').trim().toUpperCase();
    if (countryCode.isNotEmpty && !RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) {
      throw ArgumentError('countryCode must be a two-letter country code.');
    }
    return SupabaseStore.instance.createFoodRestaurant(
      accountExternalId: account.id,
      restaurant: {
        'name': name,
        'cuisine': cuisine,
        'description': (data['description']?.toString() ?? '').trim(),
        'phone': (data['phone']?.toString() ?? '').trim(),
        'openingHours': (data['openingHours']?.toString() ?? 'Hours not provided').trim(),
        'businessHours': _normalizeBusinessHours(data['businessHours']),
        'contactMethods': _cleanStringList(data['contactMethods']).where((method) => {'call','sms','imessage','whatsapp','email','website'}.contains(method)).toList(growable: false),
        'contactEmail': _cleanOptionalContact(data['contactEmail'], 'contactEmail', 254),
        'whatsappNumber': _cleanOptionalContact(data['whatsappNumber'], 'whatsappNumber', 40),
        'imessageAddress': _cleanOptionalContact(data['imessageAddress'], 'imessageAddress', 254),
        'smsNumber': _cleanOptionalContact(data['smsNumber'], 'smsNumber', 40),
        'website': _safeOptionalUrl(data['website']),
        'is24_7': data['is24_7'] == true || (data['openingHours']?.toString().trim().toLowerCase() == '24/7'),
        'address': address,
        'city': (data['city']?.toString() ?? '').trim(),
        'stateRegion': (data['stateRegion']?.toString() ?? '').trim(),
        'postalCode': (data['postalCode']?.toString() ?? '').trim(),
        'countryCode': countryCode,
        'latitude': lat,
        'longitude': lon,
        'heroImageUrl': _safeOptionalUrl(data['heroImageUrl']),
        'deliveryFeeCents': _boundedInt(data['deliveryFeeCents'], 0, 1000000, 'deliveryFeeCents'),
        'serviceFeeCents': platformServiceFeeCents,
        'taxRateBasisPoints': _boundedInt(data['taxRateBasisPoints'], 0, 30000, 'taxRateBasisPoints'),
        'minimumOrderCents': _boundedInt(data['minimumOrderCents'], 0, 10000000, 'minimumOrderCents'),
        'allowsDelivery': data['allowsDelivery'] != false,
        'allowsPickup': data['allowsPickup'] != false,
        'loyaltyPointsPerCurrency': _boundedInt(data['loyaltyPointsPerCurrency'], 1, 100, 'loyaltyPointsPerCurrency'),
        'currencyCode': (data['currencyCode']?.toString() ?? 'USD').trim().toUpperCase(),
      },
    );
  }

  Future<Map<String, dynamic>> uploadRestaurantPhoto({
    required Account account,
    required String restaurantId,
    required Map<String, dynamic> data,
  }) async {
    final cleanId = _required(restaurantId, 'restaurantId', 256);
    if (!await SupabaseStore.instance.ownsFoodRestaurant(
      accountExternalId: account.id,
      restaurantId: cleanId,
    )) {
      throw StateError('You do not have permission to manage this restaurant.');
    }
    final contentType = (data['contentType']?.toString() ?? '').trim().toLowerCase();
    final fileSpec = switch (contentType) {
      'image/jpeg' => ('jpg', 'image/jpeg'),
      'image/png' => ('png', 'image/png'),
      'image/webp' => ('webp', 'image/webp'),
      _ => null,
    };
    if (fileSpec == null) {
      throw ArgumentError('Restaurant photos must be JPG, PNG, or WebP images.');
    }
    final encoded = _required(data['imageBase64'], 'imageBase64', 7 * 1024 * 1024);
    late final List<int> bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException {
      throw ArgumentError('The uploaded image data is invalid.');
    }
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Choose an image smaller than 5 MB.');
    }
    final imageUrl = await SupabaseStore.instance.uploadFoodRestaurantImage(
      restaurantId: cleanId,
      bytes: Uint8List.fromList(bytes),
      extension: fileSpec.$1,
      contentType: fileSpec.$2,
    );
    final menuItemId = data['menuItemId']?.toString().trim() ?? '';
    if (menuItemId.isEmpty) {
      await SupabaseStore.instance.setFoodRestaurantHeroImage(
        restaurantId: cleanId,
        imageUrl: imageUrl,
      );
    } else {
      await SupabaseStore.instance.setFoodMenuItemImage(
        restaurantId: cleanId,
        menuItemId: _required(menuItemId, 'menuItemId', 256),
        imageUrl: imageUrl,
      );
    }
    return {'imageUrl': imageUrl};
  }

  Future<Map<String, dynamic>> createMenuItem({
    required Account account,
    required String restaurantId,
    required Map<String, dynamic> data,
  }) async {
    final cleanId = _required(restaurantId, 'restaurantId', 256);
    if (!await SupabaseStore.instance.ownsFoodRestaurant(
      accountExternalId: account.id,
      restaurantId: cleanId,
    )) {
      throw StateError('You do not have permission to manage this restaurant.');
    }
    final name = _required(data['name'], 'name', 120);
    final cents = _boundedInt(data['priceCents'], -1, 10000000, 'priceCents');
    if (cents < 0) throw ArgumentError('priceCents must be zero or greater.');
    return SupabaseStore.instance.createFoodMenuItem(
      restaurantId: cleanId,
      item: {
        'name': name,
        'category': (data['category']?.toString() ?? 'Menu').trim(),
        'description': (data['description']?.toString() ?? '').trim(),
        'priceCents': cents,
        'imageUrl': _safeOptionalUrl(data['imageUrl']),
        'available': data['available'] != false,
        'tags': data['tags'] is List ? data['tags'] : const <String>[],
        'themeKeys': _cleanStringList(data['themeKeys']),
        'ingredients': _cleanStringList(data['ingredients']),
        'allergens': _cleanStringList(data['allergens']),
        'removableIngredients': _cleanStringList(data['removableIngredients']),
        'modifierGroups': const <Map<String, dynamic>>[],
      },
    );
  }

  Future<Map<String, dynamic>> createCoupon({
    required Account account,
    required String restaurantId,
    required Map<String, dynamic> data,
  }) async {
    final cleanId = _required(restaurantId, 'restaurantId', 256);
    if (!await SupabaseStore.instance.ownsFoodRestaurant(
      accountExternalId: account.id,
      restaurantId: cleanId,
    )) {
      throw StateError('You do not have permission to manage this restaurant.');
    }
    final code = _required(data['code'], 'code', 32).toUpperCase();
    if (!RegExp(r'^[A-Z0-9_-]{3,32}$').hasMatch(code)) {
      throw ArgumentError('Coupon codes must use 3-32 letters, numbers, underscores, or hyphens.');
    }
    final percent = _boundedInt(data['discountPercent'], 1, 100, 'discountPercent');
    final minSubtotal = _boundedInt(data['minimumSubtotalCents'], 0, 10000000, 'minimumSubtotalCents');
    final maximumUses = data['maxRedemptions'] == null
        ? null
        : _boundedInt(data['maxRedemptions'], 1, 10000000, 'maxRedemptions');
    return SupabaseStore.instance.createFoodCoupon(
      restaurantId: cleanId,
      coupon: {
        'code': code,
        'description': (data['description']?.toString() ?? '').trim(),
        'discountPercent': percent,
        'minimumSubtotalCents': minSubtotal,
        'maxRedemptions': maximumUses,
        'startsAt': data['startsAt'],
        'expiresAt': data['expiresAt'],
        'active': true,
      },
    );
  }

  Future<Map<String, dynamic>> validateCoupon({
    required String restaurantId,
    required String code,
    required int subtotalCents,
  }) async {
    final cleanCode = _required(code, 'couponCode', 32).toUpperCase();
    final coupon = await _validatedCoupon(
      restaurantId: _required(restaurantId, 'restaurantId', 256),
      code: cleanCode,
      subtotalCents: subtotalCents,
    );
    final percent = _toInt(coupon['discount_percent']);
    return {
      'valid': true,
      'code': cleanCode,
      'discountPercent': percent,
      'discountCents': (subtotalCents * percent / 100).round(),
      'description': coupon['description']?.toString() ?? '',
    };
  }

  Future<List<Map<String, dynamic>>> loyaltySummary(Account account) async {
    final rows = await SupabaseStore.instance.getFoodLoyaltyLedger(account.id);
    final balances = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final restaurantId = row['restaurant_id']?.toString() ?? '';
      if (restaurantId.isEmpty) continue;
      final entry = balances.putIfAbsent(restaurantId, () => {
        'restaurantId': restaurantId,
        'restaurantName': (row['food_restaurants'] is Map)
            ? (row['food_restaurants'] as Map)['name']?.toString() ?? 'Restaurant'
            : 'Restaurant',
        'points': 0,
      });
      entry['points'] = (entry['points'] as int) + _toInt(row['points_delta']);
    }
    return balances.values.toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // CUSTOMER / RESTAURANT CONVERSATIONS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> customerFoodConversations(Account account) {
    return SupabaseStore.instance.listCustomerFoodConversations(account.id);
  }

  Future<List<Map<String, dynamic>>> merchantFoodConversations({
    required Account account,
    String? restaurantId,
  }) async {
    final cleanRestaurantId = restaurantId?.trim() ?? '';
    if (cleanRestaurantId.isNotEmpty &&
        !await SupabaseStore.instance.ownsFoodRestaurant(
          accountExternalId: account.id,
          restaurantId: cleanRestaurantId,
        )) {
      throw StateError('You do not have permission to view this restaurant inbox.');
    }
    return SupabaseStore.instance.listMerchantFoodConversations(
      accountExternalId: account.id,
      restaurantId: cleanRestaurantId.isEmpty ? null : cleanRestaurantId,
    );
  }

  Future<Map<String, dynamic>> createFoodConversation({
    required Account account,
    required Map<String, dynamic> data,
  }) async {
    final restaurantId = _required(data['restaurantId'], 'restaurantId', 256);
    final requestedTopic = (data['topic']?.toString() ?? 'general').trim().toLowerCase();
    const topics = {'general', 'recommendation', 'ingredient_question', 'order_support'};
    if (!topics.contains(requestedTopic)) {
      throw ArgumentError('topic must be general, recommendation, ingredient_question, or order_support.');
    }
    final relatedMenuItemId = data['relatedMenuItemId']?.toString().trim() ?? '';
    final relatedMenuItemName = data['relatedMenuItemName']?.toString().trim() ?? '';
    final orderId = data['orderId']?.toString().trim() ?? '';
    final subject = _required(
      data['subject'] ?? switch (requestedTopic) {
        'recommendation' => 'Food recommendation',
        'ingredient_question' => 'Ingredient and allergy question',
        'order_support' => 'Order support',
        _ => 'Restaurant question',
      },
      'subject',
      160,
    );
    final firstMessage = data['firstMessage']?.toString().trim() ?? '';
    if (firstMessage.length > 2000) {
      throw ArgumentError('Messages must be 2000 characters or fewer.');
    }

    final created = await SupabaseStore.instance.createFoodConversation(
      customerExternalId: account.id,
      restaurantId: restaurantId,
      topic: requestedTopic,
      subject: subject,
      relatedMenuItemId: relatedMenuItemId.isEmpty ? null : relatedMenuItemId,
      relatedMenuItemName: relatedMenuItemName,
      orderId: orderId.isEmpty ? null : orderId,
    );
    final conversationId = created['id']?.toString() ?? '';
    if (conversationId.isEmpty) throw StateError('The conversation could not be created.');

    if (firstMessage.isNotEmpty) {
      await SupabaseStore.instance.createFoodConversationMessage(
        conversationId: conversationId,
        senderExternalId: account.id,
        senderRole: 'customer',
        messageType: _customerMessageType(requestedTopic, data['firstMessageType']?.toString()),
        body: firstMessage,
      );
    }
    return (await foodConversation(account: account, conversationId: conversationId));
  }

  Future<Map<String, dynamic>> foodConversation({
    required Account account,
    required String conversationId,
  }) async {
    final cleanId = _required(conversationId, 'conversationId', 256);
    final record = await SupabaseStore.instance.getFoodConversationRecord(cleanId);
    if (record == null) throw StateError('Conversation not found.');
    final customerExternalId = record['customer_external_id']?.toString() ?? '';
    final restaurantId = record['restaurant_id']?.toString() ?? '';
    final isCustomer = customerExternalId == account.id;
    final isMerchant = await SupabaseStore.instance.ownsFoodRestaurant(
      accountExternalId: account.id,
      restaurantId: restaurantId,
    );
    if (!isCustomer && !isMerchant) {
      throw StateError('You do not have permission to view this conversation.');
    }
    final details = await SupabaseStore.instance.getFoodConversationDetails(cleanId);
    if (details == null) throw StateError('Conversation not found.');
    return {
      ...details,
      'viewerRole': isMerchant && !isCustomer ? 'restaurant' : 'customer',
    };
  }

  Future<Map<String, dynamic>> sendFoodConversationMessage({
    required Account account,
    required String conversationId,
    required Map<String, dynamic> data,
  }) async {
    final cleanId = _required(conversationId, 'conversationId', 256);
    final body = _required(data['body'], 'body', 2000);
    final record = await SupabaseStore.instance.getFoodConversationRecord(cleanId);
    if (record == null) throw StateError('Conversation not found.');
    if ((record['status']?.toString() ?? '') == 'closed') {
      throw StateError('This conversation is closed. Start a new conversation for more help.');
    }

    final customerExternalId = record['customer_external_id']?.toString() ?? '';
    final restaurantId = record['restaurant_id']?.toString() ?? '';
    final isCustomer = customerExternalId == account.id;
    final isMerchant = await SupabaseStore.instance.ownsFoodRestaurant(
      accountExternalId: account.id,
      restaurantId: restaurantId,
    );
    if (!isCustomer && !isMerchant) {
      throw StateError('You do not have permission to reply to this conversation.');
    }
    final senderRole = isMerchant && !isCustomer ? 'restaurant' : 'customer';
    final requestedType = data['messageType']?.toString();
    final topic = record['topic']?.toString() ?? 'general';
    final messageType = senderRole == 'customer'
        ? _customerMessageType(topic, requestedType)
        : _restaurantMessageType(requestedType, topic);
    final rawMetadata = data['metadata'];
    final metadata = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : const <String, dynamic>{};
    if (jsonEncode(metadata).length > 4096) {
      throw ArgumentError('Message metadata must be 4 KB or smaller.');
    }
    await SupabaseStore.instance.createFoodConversationMessage(
      conversationId: cleanId,
      senderExternalId: account.id,
      senderRole: senderRole,
      messageType: messageType,
      body: body,
      metadata: metadata,
    );
    return foodConversation(account: account, conversationId: cleanId);
  }

  String _customerMessageType(String topic, String? requested) {
    if (requested == 'ingredient_question' || topic == 'ingredient_question') {
      return 'ingredient_question';
    }
    if (requested == 'recommendation_request' || topic == 'recommendation') {
      return 'recommendation_request';
    }
    if (requested == 'order_support' || topic == 'order_support') return 'order_support';
    return 'text';
  }

  String _restaurantMessageType(String? requested, String topic) {
    switch (requested) {
      case 'recommendation':
        return 'recommendation';
      case 'ingredient_answer':
        return 'ingredient_answer';
      case 'order_support':
        return 'order_support';
      case 'support_update':
        return 'support_update';
      default:
        if (topic == 'order_support') return 'order_support';
        return 'text';
    }
  }

  Future<Map<String, dynamic>> _validatedCoupon({
    required String restaurantId,
    required String code,
    required int subtotalCents,
  }) async {
    final coupon = await SupabaseStore.instance.getFoodCoupon(
      restaurantId: restaurantId,
      code: code,
    );
    if (coupon == null || coupon['active'] != true) {
      throw StateError('That coupon is not valid for this restaurant.');
    }
    final now = DateTime.now().toUtc();
    final starts = DateTime.tryParse(coupon['starts_at']?.toString() ?? '');
    final expires = DateTime.tryParse(coupon['expires_at']?.toString() ?? '');
    if (starts != null && now.isBefore(starts.toUtc())) {
      throw StateError('That coupon is not active yet.');
    }
    if (expires != null && now.isAfter(expires.toUtc())) {
      throw StateError('That coupon has expired.');
    }
    final maximum = coupon['max_redemptions'] is num
        ? (coupon['max_redemptions'] as num).toInt()
        : int.tryParse(coupon['max_redemptions']?.toString() ?? '');
    final count = _toInt(coupon['redemption_count']);
    if (maximum != null && count >= maximum) {
      throw StateError('That coupon has reached its redemption limit.');
    }
    final minimum = _toInt(coupon['minimum_subtotal_cents']);
    if (subtotalCents < minimum) {
      throw StateError('The order does not meet the minimum subtotal for that coupon.');
    }
    return coupon;
  }

  Map<String, dynamic> _normalizeBusinessHours(dynamic raw) {
    if (raw == null) return <String, dynamic>{};
    if (raw is! Map) throw ArgumentError('businessHours must be a weekday schedule object.');
    const days = {'mon','tue','wed','thu','fri','sat','sun'};
    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      final day = entry.key.toString().toLowerCase();
      if (!days.contains(day) || entry.value is! Map) continue;
      final value = Map<String, dynamic>.from(entry.value as Map);
      final closed = value['closed'] == true;
      final allDay = value['allDay'] == true || value['all_day'] == true;
      if (closed) {
        result[day] = {'closed': true, 'allDay': false};
        continue;
      }
      if (allDay) {
        result[day] = {'closed': false, 'allDay': true, 'open': '00:00', 'close': '23:59'};
        continue;
      }
      final open = (value['open']?.toString() ?? '').trim();
      final close = (value['close']?.toString() ?? '').trim();
      final timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
      if (!timePattern.hasMatch(open) || !timePattern.hasMatch(close)) {
        throw ArgumentError('Business hours for $day must use 24-hour HH:MM values.');
      }
      result[day] = {'closed': false, 'allDay': false, 'open': open, 'close': close};
    }
    return result;
  }

  String? _cleanOptionalContact(dynamic value, String field, int maxLength) {
    final result = value?.toString().trim() ?? '';
    if (result.isEmpty) return null;
    if (result.length > maxLength || result.contains(RegExp(r'[\r\n]'))) {
      throw ArgumentError('$field is too long or contains invalid characters.');
    }
    return result;
  }

  String? _safeOptionalUrl(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.isAbsolute || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw ArgumentError('Image URLs must use HTTP or HTTPS.');
    }
    return uri.toString();
  }

  List<String> _cleanStringList(dynamic raw) {
    if (raw is! List) return const <String>[];
    final seen = <String>{};
    final result = <String>[];
    for (final entry in raw) {
      final value = entry.toString().trim();
      if (value.isEmpty || value.length > 80) continue;
      final key = value.toLowerCase();
      if (seen.add(key)) result.add(value);
      if (result.length >= 80) break;
    }
    return result;
  }

  int _boundedInt(dynamic value, int minimum, int maximum, String field) {
    final parsed = _toInt(value, fallback: minimum);
    if (parsed < minimum || parsed > maximum) {
      throw ArgumentError('$field must be between $minimum and $maximum.');
    }
    return parsed;
  }

  Future<List<Map<String, dynamic>>> listOrders({
    required Account account,
    required String profileId,
    int limit = 30,
  }) async {
    final cleanProfileId = _required(profileId, 'profileId', 256);
    final safeLimit = limit.clamp(1, 100).toInt();
    final rows = await SupabaseStore.instance.listFoodOrders(
      accountExternalId: account.id,
      profileId: cleanProfileId,
      limit: safeLimit,
    );
    final results = <Map<String, dynamic>>[];
    for (final row in rows) {
      final result = Map<String, dynamic>.from(row);
      final restaurantId = row['restaurant_id']?.toString() ?? '';
      final restaurant = restaurantId.isEmpty
          ? null
          : await SupabaseStore.instance.getFoodRestaurant(restaurantId);
      if (restaurant != null) {
        result['restaurantName'] = restaurant['name']?.toString() ?? 'Restaurant';
        result['etaMinMinutes'] = max(15, _toInt(restaurant['eta_min_minutes'], fallback: 30));
        result['etaMaxMinutes'] = max(
          result['etaMinMinutes'] as int,
          _toInt(restaurant['eta_max_minutes'], fallback: 45),
        );
        result['currencyCode'] = restaurant['currency_code']?.toString() ?? row['currency_code']?.toString() ?? 'USD';
      } else {
        result['restaurantName'] = 'Restaurant';
        result['currencyCode'] = row['currency_code']?.toString() ?? 'USD';
      }
      results.add(result);
    }
    return results;
  }

  Future<Map<String, dynamic>> getOrder({
    required Account account,
    required String orderId,
  }) async {
    final cleanId = _required(orderId, 'orderId', 256);
    final order = await SupabaseStore.instance.getFoodOrder(
      accountExternalId: account.id,
      orderId: cleanId,
    );
    if (order == null) throw StateError('Order not found.');
    final restaurant = await SupabaseStore.instance.getFoodRestaurant(
      order['restaurant_id']?.toString() ?? '',
    );
    final result = Map<String, dynamic>.from(order);
    if (restaurant != null) {
      result['restaurantName'] = restaurant['name']?.toString() ?? 'Restaurant';
      result['etaMinMinutes'] = max(15, _toInt(restaurant['eta_min_minutes'], fallback: 30));
      result['etaMaxMinutes'] = max(
        result['etaMinMinutes'] as int,
        _toInt(restaurant['eta_max_minutes'], fallback: 45),
      );
      result['currencyCode'] = restaurant['currency_code']?.toString() ?? 'USD';
    }
    return result;
  }

  int _modifierDelta(Map<String, dynamic> menuItem, List<String> selectedIds) {
    if (selectedIds.isEmpty) return 0;
    final groups = menuItem['modifier_groups'];
    if (groups is! List) return 0;
    var delta = 0;
    for (final rawGroup in groups) {
      if (rawGroup is! Map) continue;
      final options = rawGroup['options'];
      if (options is! List) continue;
      for (final rawOption in options) {
        if (rawOption is! Map) continue;
        final id = rawOption['id']?.toString() ?? '';
        if (selectedIds.contains(id)) {
          delta += _toInt(rawOption['priceDeltaCents'] ?? rawOption['price_delta_cents']);
        }
      }
    }
    return delta;
  }

  static String _required(dynamic value, String field, int maxLength) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.length > maxLength) {
      throw ArgumentError('$field is required.');
    }
    return text;
  }

  static void _validateCoordinates(double lat, double lon) {
    if (!lat.isFinite || !lon.isFinite || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      throw ArgumentError('Valid latitude and longitude are required.');
    }
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earth = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    return earth * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
