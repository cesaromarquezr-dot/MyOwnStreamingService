// FILE: `Backend/routes/payment_routes.dart`.
// Purpose: Implements the payment routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Security notes:
// - Checkout status/verification use a payment-specific checkout token and
//   do not create an authentication session.
// - Authenticated payment operations are scoped through PaymentService.
// - Raw card/bank credentials are never accepted by this route.
// - Processor transaction/reference IDs are treated as opaque values.
// - Payment responses are explicitly marked no-store.
// - Internal exceptions are logged server-side and are not returned to the
//   client.
// - Request bodies are bounded to prevent unnecessarily large JSON payloads.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import '../database/database.dart';
import '../middleware/authentication.dart';
import '../models/account.dart';
import '../models/subscription.dart';
import '../services/payment_service.dart';
import '../services/payment_method_service.dart';
import '../supabase_store.dart';

class PaymentRoutes {
  static const String _paymentPrefix = '/api/v1/payment';

  static const int _maxBodyBytes = 64 * 1024;
  static const int _maxPaymentIdLength = 256;
  static const int _maxTransactionIdLength = 512;
  static const int _maxFailureReasonLength = 1000;

  final AuthenticationMiddleware authenticationMiddleware;
  final PaymentService paymentService;
  final Database database;
  final PaymentMethodService paymentMethods;
  final Map<String, List<Map<String, dynamic>>> _memoryDestinations = {};

  PaymentRoutes({
    required this.authenticationMiddleware,
    required this.paymentService,
    required this.database,
    required this.paymentMethods,
  });

  /// Handles all payment routes.
  Future<void> handle(HttpRequest request) async {
    _applyCors(request);

    if (request.method == 'OPTIONS') {
      await _empty(request, HttpStatus.noContent);
      return;
    }

    try {
      final path = request.uri.path;

      if (path == '/api/v1/seller/payout-destinations' ||
          path.startsWith('/api/v1/phase2/payment-methods')) {
        await _handlePaymentAdministration(request, path);
        return;
      }

      /*
       * ---------------------------------------------------------
       * PRE-LOGIN CHECKOUT ROUTES
       * ---------------------------------------------------------
       *
       * These routes are intentionally available without a normal
       * authentication token. Access is granted only through the
       * checkout token associated with the specific payment session.
       */

      if (request.method == 'GET' &&
          path.startsWith('$_paymentPrefix/checkout/status/')) {
        await _getCheckoutPaymentStatus(request);
        return;
      }

      if (request.method == 'POST' &&
          path.startsWith('$_paymentPrefix/checkout/verify/')) {
        await _verifyCheckoutPayment(request);
        return;
      }

      /*
       * ---------------------------------------------------------
       * NORMAL AUTHENTICATED PAYMENT ROUTES
       * ---------------------------------------------------------
       */

      final account =
          authenticationMiddleware.authenticate(request);

      if (account == null) {
        await _sendJson(
          request.response,
          HttpStatus.unauthorized,
          {
            'success': false,
            'error': 'Authentication required.',
          },
        );
        return;
      }

      if (request.method == 'POST' &&
          path == '$_paymentPrefix/create') {
        await _createPayment(request, account);
        return;
      }

      if (request.method == 'GET' &&
          path.startsWith('$_paymentPrefix/status/')) {
        await _getPaymentStatus(request, account);
        return;
      }

      if (request.method == 'POST' &&
          path.startsWith('$_paymentPrefix/verify/')) {
        await _verifyPayment(request, account);
        return;
      }

      if (request.method == 'POST' &&
          path.startsWith('$_paymentPrefix/fail/')) {
        await _failPayment(request, account);
        return;
      }

      if (request.method == 'POST' &&
          path.startsWith('$_paymentPrefix/cancel/')) {
        await _cancelPayment(request, account);
        return;
      }

      await _sendJson(
        request.response,
        HttpStatus.notFound,
        {
          'success': false,
          'error': 'Payment endpoint not found.',
        },
      );
    } catch (error, stackTrace) {
      print('================================================');
      print('[PaymentRoutes] PAYMENT REQUEST ERROR');
      print('[PaymentRoutes] Error: $error');
      print('[PaymentRoutes] StackTrace:');
      print(stackTrace);
      print('================================================');

      developer.log(
        'Payment request error.',
        name: 'PaymentRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      try {
        await _sendJson(
          request.response,
          HttpStatus.internalServerError,
          {
            'success': false,
            'error': 'Payment request failed.',
          },
        );
      } catch (responseError, responseStackTrace) {
        print('================================================');
        print('[PaymentRoutes] UNABLE TO SEND ERROR RESPONSE');
        print('[PaymentRoutes] Error: $responseError');
        print('[PaymentRoutes] StackTrace:');
        print(responseStackTrace);
        print('================================================');

        developer.log(
          'Unable to send payment error response.',
          name: 'PaymentRoutes',
          error: responseError,
          stackTrace: responseStackTrace,
        );
      }
    }
  }

  Future<void> _handlePaymentAdministration(HttpRequest request, String path) async {
    if (request.method == 'OPTIONS') {
      await _empty(request, HttpStatus.noContent);
      return;
    }
    final account = authenticationMiddleware.authenticate(request);
    if (account == null) {
      await _sendJson(request.response, HttpStatus.unauthorized,
          {'success': false, 'error': 'Authentication required.'});
      return;
    }
    if (path == '/api/v1/phase2/payment-methods' && request.method == 'GET') {
      await _sendJson(request.response, HttpStatus.ok,
          {'success': true, ...paymentMethods.catalogJson()});
      return;
    }
    if (path == '/api/v1/phase2/payment-methods/seller' && request.method == 'POST') {
      final body = await _readJson(request);
      final selection = paymentMethods.selectForSeller(
        seller: account,
        paymentMethodId: _bounded(body, 'paymentMethodId', 100),
        countryCode: _bounded(body, 'countryCode', 3),
        currencyCode: _bounded(body, 'currencyCode', 3),
        providerAccountReference: _optionalBounded(body, 'providerAccountReference', 512),
        verified: false,
      );
      await _sendJson(request.response, HttpStatus.ok,
          {'success': true, 'selection': selection.toJson()});
      return;
    }
    if (path == '/api/v1/phase2/payment-methods/filter' && request.method == 'POST') {
      final body = await _readJson(request);
      final methods = paymentMethods.methodsForBuyer(
        sellerAccountId: _bounded(body, 'sellerAccountId', 256),
        buyerCountryCode: _bounded(body, 'buyerCountryCode', 3),
        currencyCode: _bounded(body, 'currencyCode', 3),
      );
      await _sendJson(request.response, HttpStatus.ok, {
        'success': true,
        'methods': methods.map((method) => method.toJson()).toList(),
      });
      return;
    }
    const payoutPath = '/api/v1/seller/payout-destinations';
    if (path == payoutPath) {
      if (request.method == 'GET') {
        final rows = await SupabaseStore.instance.loadSellerPayoutDestinations(accountExternalId: account.id);
        final merged = <String, Map<String, dynamic>>{
          for (final row in rows) row['id']?.toString() ?? '': row,
          for (final row in _memoryDestinations[account.id] ?? const []) row['id']?.toString() ?? '': row,
        }..remove('');
        await _sendJson(request.response, HttpStatus.ok, {'success': true, 'destinations': merged.values.toList()});
        return;
      }
      if (request.method == 'POST') {
        final body = await _readJson(request);
        const forbidden = {'accountNumber', 'routingNumber', 'iban', 'swift', 'cardNumber', 'cvv', 'password', 'bankAccount'};
        if (body.keys.any(forbidden.contains)) throw const FormatException('Raw financial credentials are not accepted by this endpoint.');
        final destination = <String, dynamic>{
          'id': _uuid(), 'sellerAccountId': account.id,
          'providerKey': _bounded(body, 'providerKey', 100),
          'methodType': _bounded(body, 'methodType', 100),
          'displayName': _bounded(body, 'displayName', 240),
          'providerAccountReference': _optionalBounded(body, 'providerAccountReference', 512),
          'maskedIdentifier': _optionalBounded(body, 'maskedIdentifier', 80),
          'enabled': body['enabled'] != false, 'verified': false,
          'metadata': <String, dynamic>{}, 'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
        await SupabaseStore.instance.upsertSellerPayoutDestination(accountExternalId: account.id, destination: destination);
        _memoryDestinations.putIfAbsent(account.id, () => []).insert(0, destination);
        await _sendJson(request.response, HttpStatus.ok, {'success': true, 'destination': destination});
        return;
      }
      if (request.method == 'DELETE') {
        final id = request.uri.queryParameters['id']?.trim() ?? '';
        if (id.isEmpty || id.length > 256) throw const FormatException('A valid destination id is required.');
        await SupabaseStore.instance.deleteSellerPayoutDestination(accountExternalId: account.id, destinationId: id);
        _memoryDestinations[account.id]?.removeWhere((item) => item['id'] == id);
        await _sendJson(request.response, HttpStatus.ok, {'success': true});
        return;
      }
    }
    await _sendJson(request.response, HttpStatus.notFound,
        {'success': false, 'error': 'Payment endpoint not found.'});
  }

  String _bounded(Map<String, dynamic> body, String key, int max) {
    final value = _stringValue(body[key]);
    if (value.isEmpty || value.length > max || value.contains('\u0000')) {
      throw FormatException('$key is required and must be at most $max characters.');
    }
    return value;
  }

  String? _optionalBounded(Map<String, dynamic> body, String key, int max) {
    final value = _stringValue(body[key]);
    if (value.isEmpty) return null;
    if (value.length > max || value.contains('\u0000')) throw FormatException('$key must be at most $max characters.');
    return value;
  }

  String _uuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /*
   * ============================================================
   * PRE-LOGIN CHECKOUT
   * ============================================================
   */

  Future<void> _getCheckoutPaymentStatus(
    HttpRequest request,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
      marker: 'checkout/status',
    );

    if (paymentId == null) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Payment ID is required.',
        },
      );
      return;
    }

    final checkoutToken =
        request.uri.queryParameters['checkoutToken']
                ?.trim() ??
            '';

    if (checkoutToken.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.unauthorized,
        {
          'success': false,
          'error': 'Checkout authorization is required.',
        },
      );
      return;
    }

    final payment =
        paymentService.getPaymentForCheckout(
      paymentId: paymentId,
      checkoutToken: checkoutToken,
    );

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'payment': payment.toJson(),
      },
    );
  }

  Future<void> _verifyCheckoutPayment(
    HttpRequest request,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
      marker: 'checkout/verify',
    );

    if (paymentId == null) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Payment ID is required.',
        },
      );
      return;
    }

    final body = await _readJson(request);

    final checkoutToken =
        _stringValue(body['checkoutToken']);

    if (checkoutToken.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.unauthorized,
        {
          'success': false,
          'error': 'Checkout authorization is required.',
        },
      );
      return;
    }

    final processorTransactionId =
        _stringValue(body['processorTransactionId']);

    if (processorTransactionId.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'A payment processor transaction ID is required.',
        },
      );
      return;
    }

    if (processorTransactionId.length >
        _maxTransactionIdLength) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Payment transaction ID is too long.',
        },
      );
      return;
    }

    /*
     * The route intentionally accepts only the processor reference.
     *
     * Never accept:
     * - card number
     * - CVV
     * - expiration date
     * - PIN
     * - bank account number
     * - bank password
     */

    final payment =
        paymentService.getPaymentForCheckout(
      paymentId: paymentId,
      checkoutToken: checkoutToken,
    );

    final account =
        database.getAccountById(payment.accountId);

    if (account == null) {
      await _sendJson(
        request.response,
        HttpStatus.notFound,
        {
          'success': false,
          'error':
              'Account associated with payment could not be found.',
        },
      );
      return;
    }

    final verifiedPayment =
        await paymentService.verifyCheckoutPayment(
      paymentId: paymentId,
      checkoutToken: checkoutToken,
      account: account,
      processorTransactionId:
          processorTransactionId,
    );

    /*
     * No authentication token is created here.
     *
     * Payment verification activates the subscription. The client
     * must subsequently perform the normal login flow.
     */

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'payment': verifiedPayment.toJson(),
        'subscription':
            account.subscription?.toJson(),
        'account':
            account.toJson(),
        'paymentRequired': false,
        'message':
            'Payment verified and subscription activated. You can now log in.',
      },
    );
  }

  /*
   * ============================================================
   * AUTHENTICATED PAYMENT CREATION
   * ============================================================
   */

  Future<void> _createPayment(
    HttpRequest request,
    Account account,
  ) async {
    final body = await _readJson(request);

    final planValue =
        _stringValue(body['plan']).toLowerCase();

    if (planValue.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'A subscription plan is required.',
        },
      );
      return;
    }

    final plan = _parsePlan(planValue);

    if (plan == null) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'Invalid subscription plan. Use monthly or yearly.',
        },
      );
      return;
    }

    final payment =
        paymentService.createPaymentSession(
      account: account,
      plan: plan,
    );

    await _sendJson(
      request.response,
      HttpStatus.created,
      {
        'success': true,
        'payment': payment.toJson(),
        'message':
            'Payment session created. Complete payment with the payment provider.',
      },
    );
  }

  /*
   * ============================================================
   * AUTHENTICATED PAYMENT STATUS
   * ============================================================
   */

  Future<void> _getPaymentStatus(
    HttpRequest request,
    Account account,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
      marker: 'status',
    );

    if (paymentId == null) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Payment ID is required.',
        },
      );
      return;
    }

    final payment =
        paymentService.getPayment(paymentId);

    if (payment == null) {
      await _sendJson(
        request.response,
        HttpStatus.notFound,
        {
          'success': false,
          'error': 'Payment session not found.',
        },
      );
      return;
    }

    if (!paymentService.paymentBelongsToAccount(
      payment,
      account,
    )) {
      /*
       * Do not expose whether a payment ID exists for another
       * account through a different response.
       */
      await _sendJson(
        request.response,
        HttpStatus.forbidden,
        {
          'success': false,
          'error': 'You do not have access to this payment.',
        },
      );
      return;
    }

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'payment': payment.toJson(),
      },
    );
  }

  /*
   * ============================================================
   * AUTHENTICATED PAYMENT VERIFICATION
   * ============================================================
   */

  Future<void> _verifyPayment(
    HttpRequest request,
    Account account,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
      marker: 'verify',
    );

    if (paymentId == null) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Payment ID is required.',
        },
      );
      return;
    }

    final body = await _readJson(request);

    final processorTransactionId =
        _stringValue(body['processorTransactionId']);

    if (processorTransactionId.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'A payment processor transaction ID is required.',
        },
      );
      return;
    }

    if (processorTransactionId.length >
        _maxTransactionIdLength) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Payment transaction ID is too long.',
        },
      );
      return;
    }

    /*
     * Only the payment processor's transaction/reference ID belongs
     * in this request. Raw financial credentials must never reach
     * this backend.
     */

    final payment =
        await paymentService.verifySuccessfulPayment(
      paymentId: paymentId,
      account: account,
      processorTransactionId:
          processorTransactionId,
    );

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'payment': payment.toJson(),
        'subscription':
            account.subscription?.toJson(),
        'account':
            account.toJson(),
        'message':
            'Payment verified and subscription activated.',
      },
    );
  }

  /*
   * ============================================================
   * PAYMENT FAILURE
   * ============================================================
   */

  Future<void> _failPayment(
    HttpRequest request,
    Account account,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
      marker: 'fail',
    );

    if (paymentId == null) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Payment ID is required.',
        },
      );
      return;
    }

    final body = await _readJson(request);

    final reason =
        _stringValue(body['reason']);

    if (reason.length > _maxFailureReasonLength) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Payment failure reason is too long.',
        },
      );
      return;
    }

    final payment =
        paymentService.markFailed(
      paymentId: paymentId,
      account: account,
      reason: reason.isEmpty ? null : reason,
    );

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'payment': payment.toJson(),
        'message': 'Payment marked as failed.',
      },
    );
  }

  /*
   * ============================================================
   * PAYMENT CANCELLATION
   * ============================================================
   */

  Future<void> _cancelPayment(
    HttpRequest request,
    Account account,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
      marker: 'cancel',
    );

    if (paymentId == null) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error': 'Payment ID is required.',
        },
      );
      return;
    }

    final payment =
        paymentService.cancelPayment(
      paymentId: paymentId,
      account: account,
    );

    await _sendJson(
      request.response,
      HttpStatus.ok,
      {
        'success': true,
        'payment': payment.toJson(),
        'message': 'Payment cancelled.',
      },
    );
  }

  /*
   * ============================================================
   * HELPERS
   * ============================================================
   */

  SubscriptionPlan? _parsePlan(
    String value,
  ) {
    switch (value) {
      case 'monthly':
        return SubscriptionPlan.monthly;

      case 'yearly':
        return SubscriptionPlan.yearly;

      default:
        return null;
    }
  }

  String? _getIdFromPath(
    String path, {
    required String marker,
  }) {
    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    final markerSegments = marker
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (markerSegments.isEmpty) {
      return null;
    }

    if (segments.length <
        markerSegments.length + 1) {
      return null;
    }

    for (var index = 0;
        index <=
            segments.length -
                markerSegments.length -
                1;
        index++) {
      var matches = true;

      for (var offset = 0;
          offset < markerSegments.length;
          offset++) {
        if (segments[index + offset] !=
            markerSegments[offset]) {
          matches = false;
          break;
        }
      }

      if (!matches) {
        continue;
      }

      final idIndex =
          index + markerSegments.length;

      if (idIndex >= segments.length) {
        return null;
      }

      final id = Uri.decodeComponent(
        segments[idIndex],
      ).trim();

      if (id.isEmpty ||
          id.length > _maxPaymentIdLength) {
        return null;
      }

      if (id.contains('/') ||
          id.contains('\\') ||
          id.contains('\u0000')) {
        return null;
      }

      return id;
    }

    return null;
  }

  Future<Map<String, dynamic>> _readJson(
    HttpRequest request,
  ) async {
    if (request.contentLength > _maxBodyBytes) {
      throw const FormatException(
        'Request body is too large.',
      );
    }

    List<int> bytes;

    try {
      bytes = await request
          .fold<List<int>>(
            <int>[],
            (buffer, chunk) {
              if (buffer.length + chunk.length >
                  _maxBodyBytes) {
                throw const FormatException(
                  'Request body is too large.',
                );
              }

              buffer.addAll(chunk);
              return buffer;
            },
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw const FormatException(
              'Request body could not be read completely.',
            ),
          );
    } on FormatException {
      rethrow;
    } on TimeoutException {
      throw const FormatException(
        'Request body could not be read completely.',
      );
    }

    if (bytes.isEmpty) {
      return <String, dynamic>{};
    }

    final contents = utf8.decode(bytes);

    try {
      final decoded = jsonDecode(contents);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      throw const FormatException(
        'JSON request body must be an object.',
      );
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException(
        'Invalid JSON request body: $error',
      );
    }
  }

  String _stringValue(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  void _applyCors(HttpRequest request) {
    final headers = request.response.headers;

    headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );
    headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, DELETE, OPTIONS',
    );
    headers.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type',
    );
    headers.set(
      'Access-Control-Expose-Headers',
      'Content-Type',
    );
  }

  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> data,
  ) async {
    response.statusCode = statusCode;

    response.headers.contentType = ContentType.json;

    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set(
      'Pragma',
      'no-cache',
    );
    response.headers.set(
      'X-Content-Type-Options',
      'nosniff',
    );

    response.write(jsonEncode(data));
    await response.close();
  }

  Future<void> _empty(
    HttpRequest request,
    int statusCode,
  ) async {
    final response = request.response;

    response.statusCode = statusCode;

    response.headers.set(
      'Cache-Control',
      'no-store, no-cache, must-revalidate',
    );
    response.headers.set(
      'Pragma',
      'no-cache',
    );

    await response.close();
  }
}
