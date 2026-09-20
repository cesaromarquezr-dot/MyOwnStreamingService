// FILE: `Backend/models/payment_session.dart`.
// Purpose: Defines durable payment-session data used by the backend payment
// service and Supabase persistence layer.
// This file is part of the documented Flutter/home-server architecture.

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
      failureReason: failureReason ?? this.failureReason,
      checkoutToken: checkoutToken ?? this.checkoutToken,
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
      if (includeCheckoutToken) 'checkoutToken': checkoutToken,
    };
  }
}
