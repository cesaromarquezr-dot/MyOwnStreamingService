// FILE: `Backend/models/payment_session.dart`.
// Purpose: Defines durable payment-session data used by the backend payment
// service and Supabase persistence layer.
// This file is part of the documented Flutter/home-server architecture.
//
// Security notes:
// - checkoutToken is a temporary pre-login checkout secret.
// - checkoutToken is never serialized unless explicitly requested.
// - checkoutToken is not an authentication credential.
// - processorTransactionId is retained as payment-provider provenance and
//   should not be treated as a secret or authentication credential.
// - Payment state transitions should ultimately be enforced by the payment
//   service/persistence layer, not by client-provided JSON alone.

import 'subscription.dart';

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
  //
  // It is deliberately omitted from normal JSON serialization.
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

  /// True when the payment session has reached a terminal state.
  bool get isTerminal =>
      status == PaymentStatus.succeeded ||
      status == PaymentStatus.failed ||
      status == PaymentStatus.cancelled;

  /// True when the payment session is still awaiting completion.
  bool get isPending =>
      status == PaymentStatus.pending ||
      status == PaymentStatus.processing;

  /// True when this session has passed its explicit expiration time.
  ///
  /// Completed sessions are not considered expired merely because their
  /// expiration timestamp has passed.
  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null || status == PaymentStatus.succeeded) {
      return false;
    }
    return DateTime.now().isAfter(expiry);
  }

  /// True when the payment completed successfully.
  bool get isSuccessful => status == PaymentStatus.succeeded;

  /// True when this session has a non-empty processor transaction ID.
  bool get hasProcessorTransaction =>
      processorTransactionId?.trim().isNotEmpty ?? false;

  /// True when this session has a non-empty failure reason.
  bool get hasFailureReason => failureReason?.trim().isNotEmpty ?? false;

  /// True when a temporary checkout secret is present.
  bool get hasCheckoutToken => checkoutToken?.trim().isNotEmpty ?? false;

  /// Normalized currency code for comparisons and persistence helpers.
  String get normalizedCurrency => currency.trim().toUpperCase();

  /// Performs basic model validation without making assumptions about the
  /// payment processor's own rules.
  bool get isValid {
    if (id.trim().isEmpty || accountId.trim().isEmpty) {
      return false;
    }

    if (amount < 0 || !amount.isFinite) {
      return false;
    }

    if (normalizedCurrency.length != 3) {
      return false;
    }

    if (expiresAt != null && expiresAt!.isBefore(createdAt)) {
      return false;
    }

    if (completedAt != null && completedAt!.isBefore(createdAt)) {
      return false;
    }

    return true;
  }

  PaymentSession copyWith({
    PaymentStatus? status,
    DateTime? expiresAt,
    DateTime? completedAt,
    String? processorTransactionId,
    String? failureReason,
    String? checkoutToken,
    bool clearExpiresAt = false,
    bool clearCompletedAt = false,
    bool clearProcessorTransactionId = false,
    bool clearFailureReason = false,
    bool clearCheckoutToken = false,
  }) {
    return PaymentSession(
      id: id,
      accountId: accountId,
      plan: plan,
      amount: amount,
      currency: currency,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      processorTransactionId: clearProcessorTransactionId
          ? null
          : (processorTransactionId ?? this.processorTransactionId),
      failureReason:
          clearFailureReason ? null : (failureReason ?? this.failureReason),
      checkoutToken:
          clearCheckoutToken ? null : (checkoutToken ?? this.checkoutToken),
    );
  }

  /// Creates a payment session from persisted JSON.
  ///
  /// Unknown payment status values are rejected rather than silently mapped
  /// to a different state.
  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    final id = _stringValue(json['id']);
    final accountId = _stringValue(json['accountId']);
    final plan = _parsePlan(json['plan']);
    final status = _parseStatus(json['status']);
    final amount = _doubleValue(json['amount']);
    final currency = _stringValue(json['currency']);
    final createdAt = _dateTimeValue(json['createdAt']);

    if (id == null ||
        accountId == null ||
        plan == null ||
        status == null ||
        amount == null ||
        currency == null ||
        createdAt == null) {
      throw const FormatException(
        'Invalid payment session: required fields are missing or malformed.',
      );
    }

    return PaymentSession(
      id: id,
      accountId: accountId,
      plan: plan,
      amount: amount,
      currency: currency,
      status: status,
      createdAt: createdAt,
      expiresAt: _dateTimeValue(json['expiresAt']),
      completedAt: _dateTimeValue(json['completedAt']),
      processorTransactionId: _nullableString(
        json['processorTransactionId'],
      ),
      failureReason: _nullableString(json['failureReason']),
      checkoutToken: _nullableString(json['checkoutToken']),
    );
  }

  /// Performs `toJson` for this feature.
  ///
  /// The checkout token is intentionally excluded unless explicitly
  /// requested by trusted backend code.
  Map<String, dynamic> toJson({
    bool includeCheckoutToken = false,
  }) {
    return {
      'id': id,
      'accountId': accountId,
      'plan': plan.name,
      'amount': amount,
      'currency': normalizedCurrency,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'processorTransactionId': processorTransactionId,
      'failureReason': failureReason,
      if (includeCheckoutToken) 'checkoutToken': checkoutToken,
    };
  }

  @override
  String toString() {
    return 'PaymentSession('
        'id: $id, '
        'accountId: $accountId, '
        'plan: ${plan.name}, '
        'amount: $amount, '
        'currency: $normalizedCurrency, '
        'status: ${status.name}, '
        'createdAt: $createdAt, '
        'expiresAt: $expiresAt, '
        'completedAt: $completedAt, '
        'processorTransactionId: ${hasProcessorTransaction ? '[present]' : '[none]'}, '
        'checkoutToken: ${hasCheckoutToken ? '[present]' : '[none]'}'
        ')';
  }
}

SubscriptionPlan? _parsePlan(Object? value) {
  if (value is SubscriptionPlan) {
    return value;
  }

  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }

  for (final plan in SubscriptionPlan.values) {
    if (plan.name.toLowerCase() == raw.toLowerCase()) {
      return plan;
    }
  }

  return null;
}

PaymentStatus? _parseStatus(Object? value) {
  if (value is PaymentStatus) {
    return value;
  }

  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }

  for (final status in PaymentStatus.values) {
    if (status.name.toLowerCase() == raw.toLowerCase()) {
      return status;
    }
  }

  return null;
}

String? _stringValue(Object? value) {
  if (value is String) {
    final result = value.trim();
    return result.isEmpty ? null : result;
  }

  return null;
}

String? _nullableString(Object? value) {
  return _stringValue(value);
}

double? _doubleValue(Object? value) {
  if (value is num) {
    final result = value.toDouble();
    return result.isFinite ? result : null;
  }

  if (value is String) {
    final result = double.tryParse(value.trim());
    return result?.isFinite == true ? result : null;
  }

  return null;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value.trim());
  }

  return null;
}
