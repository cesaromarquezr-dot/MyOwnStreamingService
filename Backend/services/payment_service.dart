// FILE: `Backend/services/payment_service.dart`.
// Purpose: Implements the payment service portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:math';

import '../database/database.dart';
import '../models/account.dart';
import '../models/subscription.dart';
import 'subscription_service.dart';

enum PaymentStatus {
  pending,
  processing,
  succeeded,
  failed,
  cancelled,
}

class PaymentSession {
  final String id;
  final String accountId;
  final SubscriptionPlan plan;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? completedAt;
  final String? processorTransactionId;
  final String? failureReason;

  // Temporary secret used only during the pre-login signup
  // checkout flow.
  //
  // This is NOT an authentication token and must never be used
  // to access the account.
  final String? checkoutToken;

  PaymentSession({
    required this.id,
    required this.accountId,
    required this.plan,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.completedAt,
    this.processorTransactionId,
    this.failureReason,
    this.checkoutToken,
  });

  PaymentSession copyWith({
    PaymentStatus? status,
    DateTime? expiresAt,
    DateTime? completedAt,
    String? processorTransactionId,
    String? failureReason,
    String? checkoutToken,
  }) {
    return PaymentSession(
      id: id,
      accountId: accountId,
      plan: plan,
      amount: amount,
      currency: currency,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      completedAt: completedAt ?? this.completedAt,
      processorTransactionId:
          processorTransactionId ?? this.processorTransactionId,
      failureReason:
          failureReason ?? this.failureReason,
      checkoutToken:
          checkoutToken ?? this.checkoutToken,
    );
  }

  /// Performs `toJson` for this feature. Update this documentation when its contract changes.
  Map<String, dynamic> toJson({
    bool includeCheckoutToken = false,
  }) {
    return {
      'id': id,
      'accountId': accountId,
      'plan': plan.name,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'processorTransactionId': processorTransactionId,
      'failureReason': failureReason,
      if (includeCheckoutToken)
        'checkoutToken': checkoutToken,
    };
  }
}

class PaymentService {
  final Database database;
  final SubscriptionService subscriptionService;

  final Random _random = Random();

  final Map<String, PaymentSession> _payments =
      <String, PaymentSession>{};

  PaymentService({
    required this.database,
    required this.subscriptionService,
  });

  // ------------------------------------------------------------
  // PAYMENT ID
  // ------------------------------------------------------------

  /// Performs `_generatePaymentId` for this feature. Update this documentation when its contract changes.
  String _generatePaymentId() {
    final timestamp =
        DateTime.now().microsecondsSinceEpoch;

    return 'pay_$timestamp${_random.nextInt(100000)}';
  }

  // ------------------------------------------------------------
  // CHECKOUT TOKEN
  // ------------------------------------------------------------

  /// Performs `_generateCheckoutToken` for this feature. Update this documentation when its contract changes.
  String _generateCheckoutToken() {
    final timestamp =
        DateTime.now().microsecondsSinceEpoch;

    final randomPart =
        List.generate(
          4,
          (_) => _random.nextInt(1000000),
        ).join();

    return 'checkout_$timestamp$randomPart';
  }

  // ------------------------------------------------------------
  // PAYMENT PRICING
  // ------------------------------------------------------------

  /// Returns the price for the selected subscription plan.
  ///
  /// The client must never be allowed to choose the amount.
  /// The backend determines the amount from the selected plan.
  double getPrice(
    SubscriptionPlan plan,
  ) {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return 9.99;

      case SubscriptionPlan.yearly:
        return 99.99;
    }
  }

  /// Performs `getCurrency` for this feature. Update this documentation when its contract changes.
  String getCurrency() {
    return 'USD';
  }

  // ------------------------------------------------------------
  // CREATE PAYMENT SESSION
  // ------------------------------------------------------------

  /// Creates a payment session for an account.
  ///
  /// A checkout token is generated for accounts that have not
  /// authenticated yet.
  ///
  /// No card number, CVV, bank account number, PIN, password,
  /// or other sensitive financial information is accepted or
  /// stored here.
  PaymentSession createPaymentSession({
    required Account account,
    required SubscriptionPlan plan,
  }) {
    if (account.id.trim().isEmpty) {
      throw Exception(
        'Account ID is required.',
      );
    }

    final existingSubscription =
        account.subscription;

    if (existingSubscription != null &&
        existingSubscription.active &&
        existingSubscription.expiresAt
            .isAfter(DateTime.now())) {
      throw Exception(
        'Account already has an active subscription.',
      );
    }

    final now = DateTime.now();

    // Signup checkout sessions are intentionally short-lived.
    final expiresAt =
        now.add(const Duration(minutes: 30));

    final paymentId =
        _generatePaymentId();

    final checkoutToken =
        _generateCheckoutToken();

    final payment = PaymentSession(
      id: paymentId,
      accountId: account.id,
      plan: plan,
      amount: getPrice(plan),
      currency: getCurrency(),
      status: PaymentStatus.pending,
      createdAt: now,
      expiresAt: expiresAt,
      checkoutToken: checkoutToken,
    );

    _payments[paymentId] = payment;

    return payment;
  }

  // ------------------------------------------------------------
  // GET PAYMENT
  // ------------------------------------------------------------

  PaymentSession? getPayment(
    String paymentId,
  ) {
    final normalizedId =
        paymentId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    return _payments[normalizedId];
  }

  // ------------------------------------------------------------
  // PAYMENT OWNERSHIP
  // ------------------------------------------------------------

  /// Performs `paymentBelongsToAccount` for this feature. Update this documentation when its contract changes.
  bool paymentBelongsToAccount(
    PaymentSession payment,
    Account account,
  ) {
    return payment.accountId ==
        account.id;
  }

  // ------------------------------------------------------------
  // CHECKOUT AUTHORIZATION
  // ------------------------------------------------------------

  /// Returns true when the supplied checkout token is valid for
  /// the specified payment.
  ///
  /// This is intentionally separate from normal authentication.
  /// A checkout token cannot be used as a login/session token.
  bool isValidCheckoutToken({
    required String paymentId,
    required String checkoutToken,
  }) {
    final payment =
        getPayment(paymentId);

    if (payment == null) {
      return false;
    }

    final token =
        checkoutToken.trim();

    if (token.isEmpty) {
      return false;
    }

    if (payment.checkoutToken == null ||
        payment.checkoutToken!.isEmpty) {
      return false;
    }

    if (payment.checkoutToken != token) {
      return false;
    }

    if (_isCheckoutExpired(payment)) {
      return false;
    }

    return true;
  }

  /// Retrieves a payment using its temporary checkout token.
  PaymentSession getPaymentForCheckout({
    required String paymentId,
    required String checkoutToken,
  }) {
    final payment =
        getPayment(paymentId);

    if (payment == null) {
      throw Exception(
        'Payment session not found.',
      );
    }

    if (!isValidCheckoutToken(
      paymentId: paymentId,
      checkoutToken: checkoutToken,
    )) {
      throw Exception(
        'Invalid or expired checkout authorization.',
      );
    }

    return payment;
  }

  // ------------------------------------------------------------
  // PROCESSING
  // ------------------------------------------------------------

  /// Marks a payment as processing.
  ///
  /// Used after the configured payment processor has accepted
  /// the transaction but before final confirmation.
  PaymentSession markProcessing({
    required String paymentId,
    required Account account,
  }) {
    final payment =
        _getPaymentForAccount(
      paymentId,
      account,
    );

    _ensureNotExpired(payment);

    if (payment.status !=
        PaymentStatus.pending) {
      throw Exception(
        'Payment is no longer pending.',
      );
    }

    final updated =
        payment.copyWith(
      status:
          PaymentStatus.processing,
    );

    _payments[payment.id] =
        updated;

    return updated;
  }

  // ------------------------------------------------------------
  // VERIFY SIGNUP PAYMENT
  // ------------------------------------------------------------

  /// Verifies a successful payment for a newly created account.
  ///
  /// This version is designed for the pre-login signup flow.
  ///
  /// The checkout token proves that the caller is authorized to
  /// operate on this particular pending payment session.
  ///
  /// The processor transaction ID is only a reference supplied
  /// by the real payment provider. It is NOT financial information.
  PaymentSession verifyCheckoutPayment({
    required String paymentId,
    required String checkoutToken,
    required Account account,
    required String processorTransactionId,
  }) {
    final payment =
        getPaymentForCheckout(
      paymentId: paymentId,
      checkoutToken: checkoutToken,
    );

    if (!paymentBelongsToAccount(
      payment,
      account,
    )) {
      throw Exception(
        'Payment does not belong to this account.',
      );
    }

    final transactionId =
        processorTransactionId.trim();

    if (transactionId.isEmpty) {
      throw Exception(
        'A payment processor transaction ID is required.',
      );
    }

    if (payment.status ==
        PaymentStatus.succeeded) {
      return payment;
    }

    if (payment.status ==
        PaymentStatus.cancelled) {
      throw Exception(
        'Payment has been cancelled.',
      );
    }

    if (payment.status ==
        PaymentStatus.failed) {
      throw Exception(
        'Payment has already failed.',
      );
    }

    /*
     * REAL PAYMENT PROCESSOR VERIFICATION
     *
     * Before activating the subscription in production,
     * the backend must verify the transaction with the
     * configured payment provider.
     *
     * The provider verification must confirm:
     *
     * - transaction exists
     * - transaction belongs to this checkout/customer
     * - transaction succeeded
     * - amount matches the backend price
     * - currency matches the backend currency
     * - transaction has not been refunded
     * - transaction has not been voided
     * - transaction has not already been used
     *
     * Never trust a client simply because it supplied a
     * transaction ID.
     */

    if (!_looksLikeProcessorTransactionId(
      transactionId,
    )) {
      throw Exception(
        'Invalid payment processor transaction ID.',
      );
    }

    // Payment has now passed the current prototype's
    // verification boundary.
    //
    // In production this line must only execute after the
    // real processor confirms the payment.
    subscriptionService.activate(
      account,
    );

    final completedAt =
        DateTime.now();

    final updated =
        payment.copyWith(
      status:
          PaymentStatus.succeeded,
      completedAt:
          completedAt,
      processorTransactionId:
          transactionId,
    );

    _payments[payment.id] =
        updated;

    database.saveAccount(
      account,
    );

    return updated;
  }

  // ------------------------------------------------------------
  // VERIFY AUTHENTICATED PAYMENT
  // ------------------------------------------------------------

  /// Verifies a successful payment for an already authenticated
  /// account.
  ///
  /// Used for subscriptions such as renewals.
  PaymentSession verifySuccessfulPayment({
    required String paymentId,
    required Account account,
    required String processorTransactionId,
  }) {
    final payment =
        _getPaymentForAccount(
      paymentId,
      account,
    );

    _ensureNotExpired(payment);

    final transactionId =
        processorTransactionId.trim();

    if (transactionId.isEmpty) {
      throw Exception(
        'A payment processor transaction ID is required.',
      );
    }

    if (payment.status ==
        PaymentStatus.succeeded) {
      return payment;
    }

    if (payment.status ==
        PaymentStatus.cancelled) {
      throw Exception(
        'Payment has been cancelled.',
      );
    }

    if (payment.status ==
        PaymentStatus.failed) {
      throw Exception(
        'Payment has already failed.',
      );
    }

    /*
     * Production payment-provider verification belongs here.
     */

    if (!_looksLikeProcessorTransactionId(
      transactionId,
    )) {
      throw Exception(
        'Invalid payment processor transaction ID.',
      );
    }

    subscriptionService.activate(
      account,
    );

    final completedAt =
        DateTime.now();

    final updated =
        payment.copyWith(
      status:
          PaymentStatus.succeeded,
      completedAt:
          completedAt,
      processorTransactionId:
          transactionId,
    );

    _payments[payment.id] =
        updated;

    database.saveAccount(
      account,
    );

    return updated;
  }

  // ------------------------------------------------------------
  // FAILED PAYMENT
  // ------------------------------------------------------------

  PaymentSession markFailed({
    required String paymentId,
    required Account account,
    String? reason,
  }) {
    final payment =
        _getPaymentForAccount(
      paymentId,
      account,
    );

    if (payment.status ==
        PaymentStatus.succeeded) {
      throw Exception(
        'A successful payment cannot be marked as failed.',
      );
    }

    final failureReason =
        reason?.trim().isNotEmpty == true
            ? reason!.trim()
            : 'Payment failed.';

    final updated =
        payment.copyWith(
      status:
          PaymentStatus.failed,
      failureReason:
          failureReason,
    );

    _payments[payment.id] =
        updated;

    return updated;
  }

  // ------------------------------------------------------------
  // CANCEL PAYMENT
  // ------------------------------------------------------------

  PaymentSession cancelPayment({
    required String paymentId,
    required Account account,
  }) {
    final payment =
        _getPaymentForAccount(
      paymentId,
      account,
    );

    if (payment.status ==
        PaymentStatus.succeeded) {
      throw Exception(
        'A successful payment cannot be cancelled.',
      );
    }

    final updated =
        payment.copyWith(
      status:
          PaymentStatus.cancelled,
    );

    _payments[payment.id] =
        updated;

    return updated;
  }

  // ------------------------------------------------------------
  // RENEW SUBSCRIPTION
  // ------------------------------------------------------------

  /// Renews an existing subscription after payment has been
  /// successfully verified.
  PaymentSession renewSubscription({
    required String paymentId,
    required Account account,
    required String processorTransactionId,
  }) {
    final payment =
        _getPaymentForAccount(
      paymentId,
      account,
    );

    _ensureNotExpired(payment);

    final transactionId =
        processorTransactionId.trim();

    if (transactionId.isEmpty) {
      throw Exception(
        'A payment processor transaction ID is required.',
      );
    }

    if (!_looksLikeProcessorTransactionId(
      transactionId,
    )) {
      throw Exception(
        'Invalid payment processor transaction ID.',
      );
    }

    if (payment.status ==
        PaymentStatus.succeeded) {
      return payment;
    }

    if (payment.status !=
            PaymentStatus.pending &&
        payment.status !=
            PaymentStatus.processing) {
      throw Exception(
        'Payment cannot be used for renewal.',
      );
    }

    /*
     * Production implementation must verify the transaction
     * with the payment provider before this point.
     */

    subscriptionService.renew(
      account,
    );

    final completedAt =
        DateTime.now();

    final updated =
        payment.copyWith(
      status:
          PaymentStatus.succeeded,
      completedAt:
          completedAt,
      processorTransactionId:
          transactionId,
    );

    _payments[payment.id] =
        updated;

    database.saveAccount(
      account,
    );

    return updated;
  }

  // ------------------------------------------------------------
  // PAYMENTS FOR ACCOUNT
  // ------------------------------------------------------------

  List<PaymentSession>
      getPaymentsForAccount(
    Account account,
  ) {
    return _payments.values
        .where(
          (payment) =>
              payment.accountId ==
              account.id,
        )
        .toList();
  }

  // ------------------------------------------------------------
  // INTERNAL ACCOUNT PAYMENT LOOKUP
  // ------------------------------------------------------------

  PaymentSession _getPaymentForAccount(
    String paymentId,
    Account account,
  ) {
    final normalizedId =
        paymentId.trim();

    if (normalizedId.isEmpty) {
      throw Exception(
        'Payment ID is required.',
      );
    }

    final payment =
        _payments[normalizedId];

    if (payment == null) {
      throw Exception(
        'Payment session not found.',
      );
    }

    if (!paymentBelongsToAccount(
      payment,
      account,
    )) {
      throw Exception(
        'Payment does not belong to this account.',
      );
    }

    return payment;
  }

  // ------------------------------------------------------------
  // EXPIRATION
  // ------------------------------------------------------------

  /// Performs `_isCheckoutExpired` for this feature. Update this documentation when its contract changes.
  bool _isCheckoutExpired(
    PaymentSession payment,
  ) {
    final expiresAt =
        payment.expiresAt;

    if (expiresAt == null) {
      return false;
    }

    return !expiresAt.isAfter(
      DateTime.now(),
    );
  }

  /// Performs `_ensureNotExpired` for this feature. Update this documentation when its contract changes.
  void _ensureNotExpired(
    PaymentSession payment,
  ) {
    if (_isCheckoutExpired(payment) &&
        payment.status !=
            PaymentStatus.succeeded) {
      throw Exception(
        'Payment checkout session has expired.',
      );
    }
  }

  // ------------------------------------------------------------
  // PROCESSOR TRANSACTION VALIDATION
  // ------------------------------------------------------------

  /// Performs `_looksLikeProcessorTransactionId` for this feature. Update this documentation when its contract changes.
  bool _looksLikeProcessorTransactionId(
    String transactionId,
  ) {
    /*
     * This deliberately does NOT validate:
     *
     * - card numbers
     * - CVV
     * - bank accounts
     * - PINs
     * - passwords
     *
     * A real payment provider will supply its own transaction
     * identifier.
     *
     * This prototype only requires a non-trivial reference.
     * Replace this with real server-side provider verification
     * before accepting real payments.
     */
    return transactionId.length >= 6;
  }
}
