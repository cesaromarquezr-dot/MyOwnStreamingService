import 'dart:math';

import '../models/account.dart';
import '../models/subscription.dart';

class SubscriptionService {
  final Random _random = Random();

  String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    return 'sub_$timestamp${_random.nextInt(100000)}';
  }

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
      active: true,
    );
  }

  void subscribe(
    Account account,
    SubscriptionPlan plan,
  ) {
    account.subscription = createSubscription(plan);
  }

  void renew(Account account) {
    final existing = account.subscription;

    if (existing == null) {
      throw Exception('Account does not have a subscription.');
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

  void cancel(Account account) {
    final subscription = account.subscription;

    if (subscription == null) {
      return;
    }

    subscription.active = false;
  }

  bool canAccessContent(Account account) {
    return account.hasActiveSubscription;
  }
}