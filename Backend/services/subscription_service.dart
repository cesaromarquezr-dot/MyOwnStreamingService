// FILE: `Backend/services/subscription_service.dart`.
// Purpose: Implements the subscription service portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:math';

import '../models/account.dart';
import '../models/subscription.dart';

class SubscriptionService {
  final Random _random = Random();

  /// Performs `_generateId` for this feature. Update this documentation when its contract changes.
  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    return 'sub_$timestamp${_random.nextInt(100000)}';
  }

  /// Creates a subscription in a pending/inactive state.
  ///
  /// The subscription is intentionally NOT activated here.
  /// Payment must be successfully verified before the account
  /// is allowed to log in.
  Subscription createSubscription(
    SubscriptionPlan plan,
  ) {
    final startedAt = DateTime.now();

    late DateTime expiresAt;

    switch (plan) {
      case SubscriptionPlan.monthly:
        expiresAt = DateTime(
          startedAt.year,
          startedAt.month + 1,
          startedAt.day,
          startedAt.hour,
          startedAt.minute,
          startedAt.second,
          startedAt.millisecond,
          startedAt.microsecond,
        );
        break;

      case SubscriptionPlan.yearly:
        expiresAt = DateTime(
          startedAt.year + 1,
          startedAt.month,
          startedAt.day,
          startedAt.hour,
          startedAt.minute,
          startedAt.second,
          startedAt.millisecond,
          startedAt.microsecond,
        );
        break;
    }

    return Subscription(
      id: _generateId(),
      plan: plan,
      startedAt: startedAt,
      expiresAt: expiresAt,
      active: false,
    );
  }

  /// Creates a subscription for an account.
  ///
  /// The subscription remains inactive until payment has been
  /// successfully verified by the payment service.
  void subscribe(
    Account account,
    SubscriptionPlan plan,
  ) {
    account.subscription = createSubscription(plan);
  }

  /// Activates a subscription after successful payment verification.
  ///
  /// This should only be called by the payment/subscription flow
  /// after the payment provider confirms the transaction.
  void activate(Account account) {
    final subscription = account.subscription;

    if (subscription == null) {
      throw Exception(
        'Account does not have a subscription.',
      );
    }

    final now = DateTime.now();

    subscription.startedAt = now;

    late DateTime newExpiration;

    switch (subscription.plan) {
      case SubscriptionPlan.monthly:
        newExpiration = DateTime(
          now.year,
          now.month + 1,
          now.day,
          now.hour,
          now.minute,
          now.second,
          now.millisecond,
          now.microsecond,
        );
        break;

      case SubscriptionPlan.yearly:
        newExpiration = DateTime(
          now.year + 1,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
          now.millisecond,
          now.microsecond,
        );
        break;
    }

    subscription.expiresAt = newExpiration;
    subscription.active = true;
  }

  /// Marks a subscription as inactive.
  void deactivate(Account account) {
    final subscription = account.subscription;

    if (subscription == null) {
      return;
    }

    subscription.active = false;
  }

  /// Renews an existing subscription after payment has been verified.
  ///
  /// This method does not perform payment verification itself.
  /// The payment service must verify the renewal payment first.
  void renew(Account account) {
    final existing = account.subscription;

    if (existing == null) {
      throw Exception(
        'Account does not have a subscription.',
      );
    }

    final now = DateTime.now();

    DateTime startFrom;

    if (existing.expiresAt.isAfter(now)) {
      startFrom = existing.expiresAt;
    } else {
      startFrom = now;
    }

    late DateTime newExpiration;

    switch (existing.plan) {
      case SubscriptionPlan.monthly:
        newExpiration = DateTime(
          startFrom.year,
          startFrom.month + 1,
          startFrom.day,
          startFrom.hour,
          startFrom.minute,
          startFrom.second,
          startFrom.millisecond,
          startFrom.microsecond,
        );
        break;

      case SubscriptionPlan.yearly:
        newExpiration = DateTime(
          startFrom.year + 1,
          startFrom.month,
          startFrom.day,
          startFrom.hour,
          startFrom.minute,
          startFrom.second,
          startFrom.millisecond,
          startFrom.microsecond,
        );
        break;
    }

    existing.startedAt = now;
    existing.expiresAt = newExpiration;
    existing.active = true;
  }

  /// Performs `cancel` for this feature. Update this documentation when its contract changes.
  void cancel(Account account) {
    final subscription = account.subscription;

    if (subscription == null) {
      return;
    }

    subscription.active = false;
  }

  /// Performs `canAccessContent` for this feature. Update this documentation when its contract changes.
  bool canAccessContent(Account account) {
    return account.hasActiveSubscription;
  }
}
