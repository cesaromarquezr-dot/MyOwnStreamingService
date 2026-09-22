// FILE: Backend/services/payment_service.dart.
//
// Purpose:
// Implements the payment service portion of the streaming service.
//
// Security contract:
// - The backend determines subscription pricing.
// - Checkout tokens are temporary authorization credentials and are never
//   treated as login/session tokens.
// - Card numbers, CVVs, bank credentials, PINs, and passwords are never
//   accepted or stored here.
// - A client-supplied processor transaction ID is only a reference.
// - Subscription activation requires server-side payment-provider verification.
// - If no payment-provider verifier is configured, successful payment
//   verification fails closed rather than trusting the client.
//
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:math';

import '../database/database.dart';
import '../models/account.dart';
import '../models/payment_session.dart';
import '../models/subscription.dart';
import 'subscription_service.dart';

/// Result returned by a real payment-provider verification implementation.
///
/// The provider adapter must verify the transaction server-to-server and
/// return the facts required by the application. The PaymentService then
/// independently verifies those facts against its own payment session.
class PaymentVerificationResult {
  final bool succeeded;
  final String transactionId;
  final double amount;
  final String currency;
  final bool refunded;
  final bool voided;

  const PaymentVerificationResult({
    required this.succeeded,
    required this.transactionId,
    required this.amount,
    required this.currency,
    this.refunded = false,
    this.voided = false,
  });

  bool get usable => succeeded && !refunded && !voided;
}

/// Server-side payment-provider verification contract.
///
/// Implementations should call the configured payment provider using
/// server-side credentials. They must never trust payment data supplied by
/// the Flutter client as proof of payment.
typedef PaymentProcessorVerifier = Future<PaymentVerificationResult> Function(
  PaymentSession payment,
  String processorTransactionId,
);

class PaymentService {
  final Database database;
  final SubscriptionService subscriptionService;

  /// Optional server-side payment-provider verifier.
  ///
  /// When null, payment verification fails closed. This prevents a client
  /// from activating a subscription merely by submitting an arbitrary
  /// transaction ID.
  final PaymentProcessorVerifier? processorVerifier;

  final Random _random = Random.secure();

  PaymentService({
    required this.database,
    required this.subscriptionService,
    this.processorVerifier,
  });

  // ------------------------------------------------------------
  // PAYMENT ID
  // ------------------------------------------------------------

  String _generatePaymentId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(1 << 32).toRadixString(16);

    return 'pay_${timestamp}_$randomPart';
  }

  // ------------------------------------------------------------
  // CHECKOUT TOKEN
  // ------------------------------------------------------------

  String _generateCheckoutToken() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    final randomBytes = List<int>.generate(
      32,
      (_) => _random.nextInt(256),
    );

    final randomPart = base64UrlEncode(randomBytes).replaceAll('=', '');

    return 'checkout_${timestamp}_$randomPart';
  }

  // ------------------------------------------------------------
  // PAYMENT PRICING
  // ------------------------------------------------------------

  /// Returns the backend-controlled price for a subscription plan.
  ///
  /// The client must never be allowed to choose the amount.
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

  String getCurrency() => 'USD';

  // ------------------------------------------------------------
  // CREATE PAYMENT SESSION
  // ------------------------------------------------------------

  /// Creates a short-lived payment session for an account.
  ///
  /// No financial credentials are accepted or persisted.
  PaymentSession createPaymentSession({
    required Account account,
    required SubscriptionPlan plan,
  }) {
    _requireAccount(account);

    final existingSubscription = account.subscription;

    if (existingSubscription != null &&
        existingSubscription.active &&
        existingSubscription.expiresAt.isAfter(DateTime.now())) {
      throw StateError(
        'Account already has an active subscription.',
      );
    }

    final now = DateTime.now();

    // Signup checkout sessions are intentionally short-lived.
    final expiresAt = now.add(
      const Duration(minutes: 30),
    );

    final payment = PaymentSession(
      id: _generatePaymentId(),
      accountId: account.id,
      plan: plan,
      amount: getPrice(plan),
      currency: getCurrency(),
      status: PaymentStatus.pending,
      createdAt: now,
      expiresAt: expiresAt,
      checkoutToken: _generateCheckoutToken(),
    );

    database.savePayment(payment);

    return payment;
  }

  // ------------------------------------------------------------
  // GET PAYMENT
  // ------------------------------------------------------------

  PaymentSession? getPayment(
    String paymentId,
  ) {
    final normalizedId = paymentId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    return database.getPayment(normalizedId);
  }

  // ------------------------------------------------------------
  // PAYMENT OWNERSHIP
  // ------------------------------------------------------------

  bool paymentBelongsToAccount(
    PaymentSession payment,
    Account account,
  ) {
    return payment.accountId.trim() == account.id.trim();
  }

  // ------------------------------------------------------------
  // CHECKOUT AUTHORIZATION
  // ------------------------------------------------------------

  /// Returns true when the supplied checkout token authorizes the specified
  /// payment session.
  ///
  /// Checkout tokens cannot be used as authentication/session tokens.
  bool isValidCheckoutToken({
    required String paymentId,
    required String checkoutToken,
  }) {
    final payment = getPayment(paymentId);

    if (payment == null) {
      return false;
    }

    final token = checkoutToken.trim();

    if (token.isEmpty) {
      return false;
    }

    final storedToken = payment.checkoutToken?.trim();

    if (storedToken == null || storedToken.isEmpty) {
      return false;
    }

    if (!_constantTimeEquals(storedToken, token)) {
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
    final payment = getPayment(paymentId);

    if (payment == null) {
      throw StateError('Payment session not found.');
    }

    if (!isValidCheckoutToken(
      paymentId: paymentId,
      checkoutToken: checkoutToken,
    )) {
      throw StateError(
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
  /// This does not activate the subscription. Activation only occurs after
  /// successful server-side processor verification.
  PaymentSession markProcessing({
    required String paymentId,
    required Account account,
  }) {
    final payment = _getPaymentForAccount(
      paymentId,
      account,
    );

    _ensureNotExpired(payment);

    if (payment.status != PaymentStatus.pending) {
      throw StateError('Payment is no longer pending.');
    }

    final updated = payment.copyWith(
      status: PaymentStatus.processing,
    );

    database.savePayment(updated);

    return updated;
  }

  // ------------------------------------------------------------
  // VERIFY SIGNUP PAYMENT
  // ------------------------------------------------------------

  /// Verifies a successful payment for a newly created account.
  ///
  /// The checkout token identifies the pending payment session, but it does
  /// not prove that money was received. The processor verifier must perform
  /// the actual server-to-server verification.
  Future<PaymentSession> verifyCheckoutPayment({
    required String paymentId,
    required String checkoutToken,
    required Account account,
    required String processorTransactionId,
  }) async {
    final payment = getPaymentForCheckout(
      paymentId: paymentId,
      checkoutToken: checkoutToken,
    );

    if (!paymentBelongsToAccount(payment, account)) {
      throw StateError(
        'Payment does not belong to this account.',
      );
    }

    return _verifyAndCompletePayment(
      payment: payment,
      account: account,
      processorTransactionId: processorTransactionId,
      renewal: false,
    );
  }

  // ------------------------------------------------------------
  // VERIFY AUTHENTICATED PAYMENT
  // ------------------------------------------------------------

  /// Verifies a successful payment for an already authenticated account.
  ///
  /// Used for subscriptions such as renewals.
  Future<PaymentSession> verifySuccessfulPayment({
    required String paymentId,
    required Account account,
    required String processorTransactionId,
  }) async {
    final payment = _getPaymentForAccount(
      paymentId,
      account,
    );

    _ensureNotExpired(payment);

    return _verifyAndCompletePayment(
      payment: payment,
      account: account,
      processorTransactionId: processorTransactionId,
      renewal: false,
    );
  }

  // ------------------------------------------------------------
  // FAILED PAYMENT
  // ------------------------------------------------------------

  PaymentSession markFailed({
    required String paymentId,
    required Account account,
    String? reason,
  }) {
    final payment = _getPaymentForAccount(
      paymentId,
      account,
    );

    if (payment.status == PaymentStatus.succeeded) {
      throw StateError(
        'A successful payment cannot be marked as failed.',
      );
    }

    if (payment.status == PaymentStatus.cancelled) {
      throw StateError(
        'A cancelled payment cannot be marked as failed.',
      );
    }

    final failureReason = reason?.trim().isNotEmpty == true
        ? reason!.trim()
        : 'Payment failed.';

    final updated = payment.copyWith(
      status: PaymentStatus.failed,
      failureReason: _limitText(
        failureReason,
        1000,
      ),
    );

    database.savePayment(updated);

    return updated;
  }

  // ------------------------------------------------------------
  // CANCEL PAYMENT
  // ------------------------------------------------------------

  PaymentSession cancelPayment({
    required String paymentId,
    required Account account,
  }) {
    final payment = _getPaymentForAccount(
      paymentId,
      account,
    );

    if (payment.status == PaymentStatus.succeeded) {
      throw StateError(
        'A successful payment cannot be cancelled.',
      );
    }

    if (payment.status == PaymentStatus.cancelled) {
      return payment;
    }

    final updated = payment.copyWith(
      status: PaymentStatus.cancelled,
    );

    database.savePayment(updated);

    return updated;
  }

  // ------------------------------------------------------------
  // RENEW SUBSCRIPTION
  // ------------------------------------------------------------

  /// Renews an existing subscription after payment has been successfully
  /// verified by the configured payment processor.
  Future<PaymentSession> renewSubscription({
    required String paymentId,
    required Account account,
    required String processorTransactionId,
  }) async {
    final payment = _getPaymentForAccount(
      paymentId,
      account,
    );

    _ensureNotExpired(payment);

    if (payment.status == PaymentStatus.succeeded) {
      return payment;
    }

    if (payment.status != PaymentStatus.pending &&
        payment.status != PaymentStatus.processing) {
      throw StateError(
        'Payment cannot be used for renewal.',
      );
    }

    return _verifyAndCompletePayment(
      payment: payment,
      account: account,
      processorTransactionId: processorTransactionId,
      renewal: true,
    );
  }

  // ------------------------------------------------------------
  // PAYMENTS FOR ACCOUNT
  // ------------------------------------------------------------

  List<PaymentSession> getPaymentsForAccount(
    Account account,
  ) {
    _requireAccount(account);

    return database
        .getPaymentsForAccount(account.id)
        .toList(growable: false);
  }

  // ------------------------------------------------------------
  // INTERNAL ACCOUNT PAYMENT LOOKUP
  // ------------------------------------------------------------

  PaymentSession _getPaymentForAccount(
    String paymentId,
    Account account,
  ) {
    _requireAccount(account);

    final normalizedId = paymentId.trim();

    if (normalizedId.isEmpty) {
      throw StateError('Payment ID is required.');
    }

    final payment = database.getPayment(
      normalizedId,
    );

    if (payment == null) {
      throw StateError('Payment session not found.');
    }

    if (!paymentBelongsToAccount(
      payment,
      account,
    )) {
      throw StateError(
        'Payment does not belong to this account.',
      );
    }

    return payment;
  }

  // ------------------------------------------------------------
  // PAYMENT VERIFICATION
  // ------------------------------------------------------------

  Future<PaymentSession> _verifyAndCompletePayment({
    required PaymentSession payment,
    required Account account,
    required String processorTransactionId,
    required bool renewal,
  }) async {
    _requireAccount(account);

    _ensureNotExpired(payment);

    final transactionId = processorTransactionId.trim();

    if (transactionId.isEmpty) {
      throw StateError(
        'A payment processor transaction ID is required.',
      );
    }

    if (!_looksLikeProcessorTransactionId(transactionId)) {
      throw StateError(
        'Invalid payment processor transaction ID.',
      );
    }

    if (payment.status == PaymentStatus.succeeded) {
      return payment;
    }

    if (payment.status == PaymentStatus.cancelled) {
      throw StateError(
        'Payment has been cancelled.',
      );
    }

    if (payment.status == PaymentStatus.failed) {
      throw StateError(
        'Payment has already failed.',
      );
    }

    final verifier = processorVerifier;

    if (verifier == null) {
      throw StateError(
        'Payment processor verification is not configured. '
        'The subscription cannot be activated from a client-supplied '
        'transaction ID.',
      );
    }

    final verification = await verifier(
      payment,
      transactionId,
    );

    _validateProcessorVerification(
      payment: payment,
      requestedTransactionId: transactionId,
      verification: verification,
    );

    if (!verification.usable) {
      throw StateError(
        'Payment processor did not confirm a successful payment.',
      );
    }

    /*
     * The provider has now independently confirmed:
     *
     * - the transaction exists
     * - the transaction succeeded
     * - the transaction has not been refunded
     * - the transaction has not been voided
     *
     * _validateProcessorVerification also checks the application-controlled
     * amount and currency.
     *
     * Only after those checks does subscription activation occur.
     */

    if (renewal) {
      subscriptionService.renew(account);
    } else {
      subscriptionService.activate(account);
    }

    final completedAt = DateTime.now();

    final updated = payment.copyWith(
      status: PaymentStatus.succeeded,
      completedAt: completedAt,
      processorTransactionId: verification.transactionId,
    );

    database.savePayment(updated);
    database.saveAccount(account);

    return updated;
  }

  void _validateProcessorVerification({
    required PaymentSession payment,
    required String requestedTransactionId,
    required PaymentVerificationResult verification,
  }) {
    final verifiedTransactionId = verification.transactionId.trim();

    if (verifiedTransactionId.isEmpty) {
      throw StateError(
        'Payment provider returned an empty transaction ID.',
      );
    }

    if (!_constantTimeEquals(
      verifiedTransactionId,
      requestedTransactionId,
    )) {
      throw StateError(
        'Payment provider transaction ID does not match the requested payment.',
      );
    }

    final expectedAmount = payment.amount;
    final verifiedAmount = verification.amount;

    // Avoid relying on exact binary floating-point equality for currency.
    final expectedCents = (expectedAmount * 100).round();
    final verifiedCents = (verifiedAmount * 100).round();

    if (expectedCents != verifiedCents) {
      throw StateError(
        'Payment amount does not match the configured subscription price.',
      );
    }

    if (verification.currency.trim().toUpperCase() !=
        payment.currency.trim().toUpperCase()) {
      throw StateError(
        'Payment currency does not match the configured subscription currency.',
      );
    }

    if (!verification.usable) {
      throw StateError(
        'Payment provider did not confirm a usable successful transaction.',
      );
    }
  }

  // ------------------------------------------------------------
  // EXPIRATION
  // ------------------------------------------------------------

  bool _isCheckoutExpired(
    PaymentSession payment,
  ) {
    final expiresAt = payment.expiresAt;

    if (expiresAt == null) {
      return false;
    }

    return !expiresAt.isAfter(
      DateTime.now(),
    );
  }

  void _ensureNotExpired(
    PaymentSession payment,
  ) {
    if (_isCheckoutExpired(payment) &&
        payment.status != PaymentStatus.succeeded) {
      throw StateError(
        'Payment checkout session has expired.',
      );
    }
  }

  // ------------------------------------------------------------
  // PROCESSOR TRANSACTION VALIDATION
  // ------------------------------------------------------------

  /// Performs only basic shape validation.
  ///
  /// This is deliberately NOT payment verification. Real verification is
  /// performed by [processorVerifier].
  bool _looksLikeProcessorTransactionId(
    String transactionId,
  ) {
    if (transactionId.length < 6 || transactionId.length > 512) {
      return false;
    }

    // Transaction identifiers are opaque provider values. Reject control
    // characters and whitespace that could indicate malformed input while
    // allowing provider-specific punctuation.
    for (final codeUnit in transactionId.codeUnits) {
      if (codeUnit < 0x20 || codeUnit == 0x7f) {
        return false;
      }
    }

    return true;
  }

  // ------------------------------------------------------------
  // ACCOUNT VALIDATION
  // ------------------------------------------------------------

  void _requireAccount(Account account) {
    if (account.id.trim().isEmpty) {
      throw StateError('Account ID is required.');
    }
  }

  // ------------------------------------------------------------
  // CONSTANT-TIME STRING COMPARISON
  // ------------------------------------------------------------

  bool _constantTimeEquals(
    String a,
    String b,
  ) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);

    var difference = left.length ^ right.length;

    final length = min(left.length, right.length);

    for (var i = 0; i < length; i++) {
      difference |= left[i] ^ right[i];
    }

    // Continue touching the remaining bytes when lengths differ so that the
    // comparison does not return immediately on the first difference.
    for (var i = length; i < left.length; i++) {
      difference |= left[i] ^ 0;
    }

    for (var i = length; i < right.length; i++) {
      difference |= right[i] ^ 0;
    }

    return difference == 0;
  }

  String _limitText(
    String value,
    int maxLength,
  ) {
    if (value.length <= maxLength) {
      return value;
    }

    return value.substring(0, maxLength);
  }
}
