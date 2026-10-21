// FILE: Backend/routes/food_delivery_routes.dart
// Purpose: Authenticated restaurant, menu, payment-method, and food-order API.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../middleware/authentication.dart';
import '../services/food_delivery_service.dart';

class FoodDeliveryRoutes {
  final AuthenticationMiddleware authentication;
  final FoodDeliveryService service;

  FoodDeliveryRoutes({
    required this.authentication,
    required this.service,
  });

  Future<void> handle(HttpRequest request) async {
    _cors(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final account = authentication.authenticate(request);
    if (account == null) {
      await _json(request.response, HttpStatus.unauthorized, {
        'success': false,
        'error': 'Authentication required.',
      });
      return;
    }

    try {
      final path = request.uri.path;

      if (request.method == 'GET' && path == '/api/v1/food/restaurants/nearby') {
        final lat = double.tryParse(request.uri.queryParameters['lat'] ?? '');
        final lon = double.tryParse(request.uri.queryParameters['lon'] ?? '');
        final radius = double.tryParse(request.uri.queryParameters['radiusKm'] ?? '10');
        final query = request.uri.queryParameters['q'] ?? '';
        final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '50') ?? 50;
        if (lat == null || lon == null) throw FormatException('Valid coordinates are required.');
        final restaurants = await service.nearbyRestaurants(
          latitude: lat,
          longitude: lon,
          radiusKm: radius ?? 10,
          query: query,
          limit: limit,
        );
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'restaurants': restaurants,
        });
        return;
      }

      if (request.method == 'GET' && path == '/api/v1/food/merchant/restaurants') {
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'restaurants': await service.merchantRestaurants(account),
        });
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/food/merchant/restaurants') {
        final body = await _readJson(request);
        final restaurant = await service.createRestaurant(account: account, data: body);
        await _json(request.response, HttpStatus.created, {
          'success': true,
          'restaurant': restaurant,
        });
        return;
      }

      final merchantProfileMatch = RegExp(
        r'^/api/v1/food/merchant/restaurants/([^/]+)/profile$',
      ).firstMatch(path);
      if (request.method == 'PATCH' && merchantProfileMatch != null) {
        final body = await _readJson(request);
        final restaurant = await service.updateRestaurantProfile(
          account: account,
          restaurantId: Uri.decodeComponent(merchantProfileMatch.group(1)!),
          data: body,
        );
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'restaurant': restaurant,
        });
        return;
      }

      final merchantThemeMatch = RegExp(
        r'^/api/v1/food/merchant/restaurants/([^/]+)/themes$',
      ).firstMatch(path);
      if (request.method == 'POST' && merchantThemeMatch != null) {
        final body = await _readJson(request);
        final theme = await service.createMenuTheme(
          account: account,
          restaurantId: Uri.decodeComponent(merchantThemeMatch.group(1)!),
          data: body,
        );
        await _json(request.response, HttpStatus.created, {
          'success': true,
          'theme': theme,
        });
        return;
      }

      final merchantPhotoMatch = RegExp(
        r'^/api/v1/food/merchant/restaurants/([^/]+)/photo$',
      ).firstMatch(path);
      if (request.method == 'POST' && merchantPhotoMatch != null) {
        final body = await _readJson(request);
        final photo = await service.uploadRestaurantPhoto(
          account: account,
          restaurantId: Uri.decodeComponent(merchantPhotoMatch.group(1)!),
          data: body,
        );
        await _json(request.response, HttpStatus.created, {
          'success': true,
          ...photo,
        });
        return;
      }

      final merchantMenuMatch = RegExp(
        r'^/api/v1/food/merchant/restaurants/([^/]+)/menu$',
      ).firstMatch(path);
      if (request.method == 'POST' && merchantMenuMatch != null) {
        final body = await _readJson(request);
        final item = await service.createMenuItem(
          account: account,
          restaurantId: Uri.decodeComponent(merchantMenuMatch.group(1)!),
          data: body,
        );
        await _json(request.response, HttpStatus.created, {
          'success': true,
          'item': item,
        });
        return;
      }

      final merchantCouponMatch = RegExp(
        r'^/api/v1/food/merchant/restaurants/([^/]+)/coupons$',
      ).firstMatch(path);
      if (request.method == 'POST' && merchantCouponMatch != null) {
        final body = await _readJson(request);
        final coupon = await service.createCoupon(
          account: account,
          restaurantId: Uri.decodeComponent(merchantCouponMatch.group(1)!),
          data: body,
        );
        await _json(request.response, HttpStatus.created, {
          'success': true,
          'coupon': coupon,
        });
        return;
      }

      final couponValidationMatch = RegExp(
        r'^/api/v1/food/restaurants/([^/]+)/coupons/validate$',
      ).firstMatch(path);
      if (request.method == 'GET' && couponValidationMatch != null) {
        final code = request.uri.queryParameters['code'] ?? '';
        final subtotal = int.tryParse(request.uri.queryParameters['subtotalCents'] ?? '') ?? -1;
        if (subtotal < 0) throw FormatException('subtotalCents must be zero or greater.');
        final validation = await service.validateCoupon(
          restaurantId: Uri.decodeComponent(couponValidationMatch.group(1)!),
          code: code,
          subtotalCents: subtotal,
        );
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'coupon': validation,
        });
        return;
      }

      if (request.method == 'GET' && path == '/api/v1/food/loyalty') {
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'balances': await service.loyaltySummary(account),
        });
        return;
      }

      if (request.method == 'GET' && path == '/api/v1/food/conversations') {
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'conversations': await service.customerFoodConversations(account),
        });
        return;
      }

      if (request.method == 'GET' && path == '/api/v1/food/merchant/conversations') {
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'conversations': await service.merchantFoodConversations(
            account: account,
            restaurantId: request.uri.queryParameters['restaurantId'],
          ),
        });
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/food/conversations') {
        final body = await _readJson(request);
        final conversation = await service.createFoodConversation(
          account: account,
          data: body,
        );
        await _json(request.response, HttpStatus.created, {
          'success': true,
          'conversation': conversation,
        });
        return;
      }

      final messageMatch = RegExp(
        r'^/api/v1/food/conversations/([^/]+)/messages$',
      ).firstMatch(path);
      if (request.method == 'POST' && messageMatch != null) {
        final body = await _readJson(request);
        final conversation = await service.sendFoodConversationMessage(
          account: account,
          conversationId: Uri.decodeComponent(messageMatch.group(1)!),
          data: body,
        );
        await _json(request.response, HttpStatus.created, {
          'success': true,
          'conversation': conversation,
        });
        return;
      }

      final conversationMatch = RegExp(
        r'^/api/v1/food/conversations/([^/]+)$',
      ).firstMatch(path);
      if (request.method == 'GET' && conversationMatch != null) {
        final conversation = await service.foodConversation(
          account: account,
          conversationId: Uri.decodeComponent(conversationMatch.group(1)!),
        );
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'conversation': conversation,
        });
        return;
      }

      final restaurantReviewsMatch = RegExp(
        r'^/api/v1/food/restaurants/([^/]+)/reviews$',
      ).firstMatch(path);
      if (restaurantReviewsMatch != null && request.method == 'GET') {
        final reviews = await service.restaurantReviews(
          Uri.decodeComponent(restaurantReviewsMatch.group(1)!),
        );
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'reviews': reviews,
        });
        return;
      }
      if (restaurantReviewsMatch != null && request.method == 'POST') {
        final body = await _readJson(request);
        final rating = int.tryParse(body['rating']?.toString() ?? '') ?? 0;
        final review = await service.submitRestaurantReview(
          account: account,
          restaurantId: Uri.decodeComponent(restaurantReviewsMatch.group(1)!),
          rating: rating,
          title: body['title']?.toString() ?? '',
          body: body['body']?.toString() ?? '',
        );
        await _json(request.response, HttpStatus.created, {
          'success': true,
          'review': review,
        });
        return;
      }

      final restaurantThemesMatch = RegExp(
        r'^/api/v1/food/restaurants/([^/]+)/themes$',
      ).firstMatch(path);
      if (request.method == 'GET' && restaurantThemesMatch != null) {
        final themes = await service.menuThemes(
          Uri.decodeComponent(restaurantThemesMatch.group(1)!),
        );
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'themes': themes,
        });
        return;
      }

      final restaurantMatch = RegExp(r'^/api/v1/food/restaurants/([^/]+)$').firstMatch(path);
      if (request.method == 'GET' && restaurantMatch != null) {
        final restaurant = await service.restaurant(Uri.decodeComponent(restaurantMatch.group(1)!));
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'restaurant': restaurant,
        });
        return;
      }

      final menuMatch = RegExp(r'^/api/v1/food/restaurants/([^/]+)/menu$').firstMatch(path);
      if (request.method == 'GET' && menuMatch != null) {
        final query = request.uri.queryParameters['q'] ?? '';
        final items = await service.menu(Uri.decodeComponent(menuMatch.group(1)!), query: query);
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'items': items,
        });
        return;
      }

      if (request.method == 'GET' && path == '/api/v1/food/payment-methods') {
        final methods = service.paymentMethodCatalog(
          countryCode: request.uri.queryParameters['country']?.toUpperCase() ?? '*',
          currencyCode: request.uri.queryParameters['currency']?.toUpperCase() ?? 'USD',
        );
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'paymentMethods': methods,
        });
        return;
      }

      if (request.method == 'GET' && path == '/api/v1/food/orders') {
        final profileId = request.uri.queryParameters['profileId'] ?? '';
        final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '30') ?? 30;
        final orders = await service.listOrders(
          account: account,
          profileId: profileId,
          limit: limit,
        );
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'orders': orders,
        });
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/food/orders') {
        final body = await _readJson(request);
        final rawItems = body['items'];
        if (rawItems is! List) throw FormatException('items must be an array.');
        final items = rawItems
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
        final order = await service.createOrder(
          account: account,
          profileId: body['profileId']?.toString() ?? '',
          restaurantId: body['restaurantId']?.toString() ?? '',
          items: items,
          deliveryAddress: body['deliveryAddress'] is Map
              ? Map<String, dynamic>.from(body['deliveryAddress'] as Map)
              : const {},
          paymentMethodId: body['paymentMethodId']?.toString() ?? '',
          deliveryNotes: body['deliveryNotes']?.toString() ?? '',
          viewingContext: body['viewingContext']?.toString(),
          fulfillmentMethod: body['fulfillmentMethod']?.toString() ?? 'delivery',
          couponCode: body['couponCode']?.toString() ?? '',
        );
        await _json(request.response, HttpStatus.created, {
          'success': true,
          'order': order,
        });
        return;
      }

      final orderMatch = RegExp(r'^/api/v1/food/orders/([^/]+)$').firstMatch(path);
      if (request.method == 'GET' && orderMatch != null) {
        final order = await service.getOrder(
          account: account,
          orderId: Uri.decodeComponent(orderMatch.group(1)!),
        );
        await _json(request.response, HttpStatus.ok, {
          'success': true,
          'order': order,
        });
        return;
      }

      await _json(request.response, HttpStatus.notFound, {
        'success': false,
        'error': 'Food delivery route not found.',
      });
    } on ArgumentError catch (error) {
      await _json(request.response, HttpStatus.badRequest, {
        'success': false,
        'error': error.message?.toString() ?? 'Invalid food delivery request.',
      });
    } on FormatException catch (error) {
      await _json(request.response, HttpStatus.badRequest, {
        'success': false,
        'error': error.message,
      });
    } on StateError catch (error) {
      await _json(request.response, HttpStatus.unprocessableEntity, {
        'success': false,
        'error': error.message,
      });
    } catch (error, stackTrace) {
      developer.log(
        'Food delivery route failed.',
        name: 'FoodDeliveryRoutes',
        error: error,
        stackTrace: stackTrace,
      );
      await _json(request.response, HttpStatus.internalServerError, {
        'success': false,
        'error': 'Unable to process the food delivery request.',
      });
    }
  }

  static Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (body.trim().isEmpty) throw const FormatException('A JSON body is required.');
    final decoded = jsonDecode(body);
    if (decoded is! Map) throw const FormatException('A JSON object is required.');
    return Map<String, dynamic>.from(decoded);
  }

  static Future<void> _json(HttpResponse response, int status, Map<String, dynamic> data) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(jsonEncode(data));
    await response.close();
  }

  static void _cors(HttpResponse response) {
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Headers', 'Authorization, Content-Type')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  }
}
