// FILE: `Backend/routes/payment_routes.dart`.
// Purpose: Implements the payment routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../database/database.dart';
import '../middleware/authentication.dart';
import '../models/account.dart';
import '../models/subscription.dart';
import '../services/payment_service.dart';

class PaymentRoutes {
  final AuthenticationMiddleware authenticationMiddleware;
  final PaymentService paymentService;
  final Database database;

  PaymentRoutes({
    required this.authenticationMiddleware,
    required this.paymentService,
    required this.database,
  });

  /// Performs `handle` for this feature. Update this documentation when its contract changes.
  Future<void> handle(HttpRequest request) async {
    try {
      final path = request.uri.path;

      /*
       * ---------------------------------------------------------
       * PRE-LOGIN CHECKOUT ROUTES
       * ---------------------------------------------------------
       *
       * These routes are used immediately after signup.
       *
       * The user does NOT have a normal authentication token yet.
       * Instead, the payment session has a temporary checkout token.
       *
       * The checkout token:
       * - only grants access to that specific payment session
       * - cannot be used as a normal login token
       * - is never returned by normal payment status endpoints
       * - is required to verify the payment before login is allowed
       */

      if (request.method == 'GET' &&
          path.startsWith('/api/v1/payment/checkout/status/')) {
        await _getCheckoutPaymentStatus(request);
        return;
      }

      if (request.method == 'POST' &&
          path.startsWith('/api/v1/payment/checkout/verify/')) {
        await _verifyCheckoutPayment(request);
        return;
      }

      /*
       * ---------------------------------------------------------
       * NORMAL AUTHENTICATED PAYMENT ROUTES
       * ---------------------------------------------------------
       *
       * These routes are used after the account is authenticated.
       */

      final account = authenticationMiddleware.authenticate(request);

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
          path == '/api/v1/payment/create') {
        await _createPayment(
          request,
          account,
        );
        return;
      }

      if (request.method == 'GET' &&
          path.startsWith('/api/v1/payment/status/')) {
        await _getPaymentStatus(
          request,
          account,
        );
        return;
      }

      if (request.method == 'POST' &&
          path.startsWith('/api/v1/payment/verify/')) {
        await _verifyPayment(
          request,
          account,
        );
        return;
      }

      if (request.method == 'POST' &&
          path.startsWith('/api/v1/payment/fail/')) {
        await _failPayment(
          request,
          account,
        );
        return;
      }

      if (request.method == 'POST' &&
          path.startsWith('/api/v1/payment/cancel/')) {
        await _cancelPayment(
          request,
          account,
        );
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
    } catch (error) {
      developer.log(
        'Payment request error: $error',
        name: 'PaymentRoutes',
      );

      if (!request.response.headers.contentType
          .toString()
          .contains('json')) {
        await _sendJson(
          request.response,
          HttpStatus.internalServerError,
          {
            'success': false,
            'error': _cleanError(error),
          },
        );
      }
    }
  }

  /*
   * ============================================================
   * PRE-LOGIN CHECKOUT
   * ============================================================
   */

  /// Performs `_getCheckoutPaymentStatus` for this feature. Update this documentation when its contract changes.
  Future<void> _getCheckoutPaymentStatus(
    HttpRequest request,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
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
          'error':
              'Checkout authorization is required.',
        },
      );
      return;
    }

    /*
     * getPaymentForCheckout() already guarantees a valid
     * PaymentSession or throws an exception.
     *
     * Therefore, there must NOT be a "payment == null" check here.
     */

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

  /// Performs `_verifyCheckoutPayment` for this feature. Update this documentation when its contract changes.
  Future<void> _verifyCheckoutPayment(
    HttpRequest request,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
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
        body['checkoutToken']
                ?.toString()
                .trim() ??
            '';

    if (checkoutToken.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.unauthorized,
        {
          'success': false,
          'error':
              'Checkout authorization is required.',
        },
      );
      return;
    }

    final processorTransactionId =
        body['processorTransactionId']
                ?.toString()
                .trim() ??
            '';

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

    /*
     * IMPORTANT:
     *
     * The frontend must NEVER send raw financial credentials.
     *
     * Do NOT accept:
     *
     * - card number
     * - CVV
     * - expiration date
     * - PIN
     * - bank account number
     * - bank password
     * - online banking credentials
     *
     * Only the payment processor's transaction/reference ID
     * belongs in this request.
     */

    /*
     * getPaymentForCheckout() returns a non-null PaymentSession.
     * It throws if the checkout session is invalid or expired.
     */

    final payment =
        paymentService.getPaymentForCheckout(
      paymentId: paymentId,
      checkoutToken: checkoutToken,
    );

    /*
     * Retrieve the account associated with this payment session.
     *
     * This is safe because the checkout token was already validated
     * against the payment session.
     */

    final account =
        database.getAccountById(
      payment.accountId,
    );

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
        paymentService.verifyCheckoutPayment(
      paymentId: paymentId,
      checkoutToken: checkoutToken,
      account: account,
      processorTransactionId:
          processorTransactionId,
    );

    /*
     * IMPORTANT:
     *
     * No authentication token is created here.
     *
     * The account is now activated, so the frontend can perform
     * the normal login request using the user's username/email
     * and password.
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

  /// Performs `_createPayment` for this feature. Update this documentation when its contract changes.
  Future<void> _createPayment(
    HttpRequest request,
    Account account,
  ) async {
    final body = await _readJson(request);

    final planValue =
        body['plan']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    if (planValue.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'A subscription plan is required.',
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

  /// Performs `_getPaymentStatus` for this feature. Update this documentation when its contract changes.
  Future<void> _getPaymentStatus(
    HttpRequest request,
    Account account,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
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

    /*
     * getPayment() returns PaymentSession?, so this null check
     * IS required here.
     */

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
      await _sendJson(
        request.response,
        HttpStatus.forbidden,
        {
          'success': false,
          'error':
              'You do not have access to this payment.',
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

  /// Performs `_verifyPayment` for this feature. Update this documentation when its contract changes.
  Future<void> _verifyPayment(
    HttpRequest request,
    Account account,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
    );

    if (paymentId == null) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'Payment ID is required.',
        },
      );
      return;
    }

    final body = await _readJson(request);

    final processorTransactionId =
        body['processorTransactionId']
                ?.toString()
                .trim() ??
            '';

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

    /*
     * The client must NEVER send:
     *
     * - card number
     * - CVV
     * - PIN
     * - bank account number
     * - bank password
     *
     * Only the processor's transaction/reference ID belongs here.
     */

    final payment =
        paymentService.verifySuccessfulPayment(
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

  /// Performs `_failPayment` for this feature. Update this documentation when its contract changes.
  Future<void> _failPayment(
    HttpRequest request,
    Account account,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
    );

    if (paymentId == null) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'Payment ID is required.',
        },
      );
      return;
    }

    final body = await _readJson(request);

    final reason =
        body['reason']
                ?.toString()
                .trim() ??
            '';

    /*
     * markFailed() returns a non-null PaymentSession.
     */

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
        'message':
            'Payment marked as failed.',
      },
    );
  }

  /*
   * ============================================================
   * PAYMENT CANCELLATION
   * ============================================================
   */

  /// Performs `_cancelPayment` for this feature. Update this documentation when its contract changes.
  Future<void> _cancelPayment(
    HttpRequest request,
    Account account,
  ) async {
    final paymentId = _getIdFromPath(
      request.uri.path,
    );

    if (paymentId == null) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        {
          'success': false,
          'error':
              'Payment ID is required.',
        },
      );
      return;
    }

    /*
     * cancelPayment() returns a non-null PaymentSession.
     */

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
        'message':
            'Payment cancelled.',
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
    String path,
  ) {
    final segments = path.split('/');

    if (segments.length < 5) {
      return null;
    }

    final id = segments.last.trim();

    if (id.isEmpty) {
      return null;
    }

    return id;
  }

  Future<Map<String, dynamic>> _readJson(
    HttpRequest request,
  ) async {
    final contents =
        await utf8.decoder
            .bind(request)
            .join();

    if (contents.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(contents);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {};
    } catch (_) {
      throw Exception(
        'Invalid JSON request body.',
      );
    }
  }

  /// Performs `_sendJson` for this feature. Update this documentation when its contract changes.
  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> data,
  ) async {
    response.statusCode = statusCode;

    response.headers.contentType =
        ContentType.json;

    response.write(
      jsonEncode(data),
    );

    await response.close();
  }

  /// Performs `_cleanError` for this feature. Update this documentation when its contract changes.
  String _cleanError(
    Object error,
  ) {
    final message = error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(11);
    }

    return message;
  }
}
