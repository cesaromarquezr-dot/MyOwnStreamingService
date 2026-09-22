// FILE: Backend/services/subscription_service.dart.
// Purpose: Implements subscription lifecycle management for the streaming
// service.
//
// Subscription creation is intentionally separate from activation.
// A subscription remains inactive until the payment service has completed
// server-side payment verification.
//
// This service does not process or verify payments.

import 'dart:math';

import '../models/account.dart';
import '../models/subscription.dart';

class SubscriptionService {
  static const int _randomIdBytes = 24;

  final Random _random = Random.secure();

  /// Creates a cryptographically unpredictable subscription identifier.
  String _generateId() {
    final bytes = List<int>.generate(
      _randomIdBytes,
      (_) => _random.nextInt(256),
    );

    final suffix = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return 'sub_${DateTime.now().toUtc().microsecondsSinceEpoch}_$suffix';
  }

  /// Creates a subscription in an inactive/pending state.
  ///
  /// Payment verification is deliberately not performed here.
  Subscription createSubscription(
    SubscriptionPlan plan,
  ) {
    final now = DateTime.now().toUtc();

    return Subscription(
      id: _generateId(),
      plan: plan,
      startedAt: now,
      expiresAt: _addPlanDuration(now, plan),
      active: false,
    );
  }

  /// Replaces the account's current subscription with a new inactive
  /// subscription.
  ///
  /// The subscription is intentionally not activated. The payment service
  /// must complete server-side verification before calling [activate].
  void subscribe(
    Account account,
    SubscriptionPlan plan,
  ) {
    _validateAccount(account);
    account.subscription = createSubscription(plan);
  }

  /// Activates an existing subscription after successful payment verification.
  ///
  /// Activation starts from the current time rather than the original
  /// pending-subscription creation time. This prevents time spent waiting
  /// for payment from consuming the paid subscription period.
  ///
  /// Calling this method again is idempotent for an already-current
  /// subscription: it does not silently extend the subscription a second
  /// time.
  void activate(Account account) {
    _validateAccount(account);

    final subscription = account.subscription;

    if (subscription == null) {
      throw StateError(
        'Account does not have a subscription.',
      );
    }

    final now = DateTime.now().toUtc();

    if (subscription.active &&
        subscription.expiresAt.isAfter(now)) {
      return;
    }

    subscription.startedAt = now;
    subscription.expiresAt = _addPlanDuration(
      now,
      subscription.plan,
    );
    subscription.active = true;
  }

  /// Marks the current subscription inactive.
  ///
  /// Deactivation does not erase the expiration date so the account retains
  /// an auditable record of the subscription period.
  void deactivate(Account account) {
    _validateAccount(account);

    final subscription = account.subscription;

    if (subscription == null) {
      return;
    }

    subscription.active = false;
  }

  /// Renews an existing subscription after payment has been verified.
  ///
  /// If the current subscription is still active, the new period begins at
  /// its existing expiration time. If it has expired, the new period begins
  /// immediately.
  ///
  /// Renewal is not a payment operation and must never be called directly
  /// from an untrusted client request.
  void renew(Account account) {
    _validateAccount(account);

    final existing = account.subscription;

    if (existing == null) {
      throw StateError(
        'Account does not have a subscription.',
      );
    }

    final now = DateTime.now().toUtc();

    final currentExpiration = existing.expiresAt.toUtc();

    final startFrom = currentExpiration.isAfter(now)
        ? currentExpiration
        : now;

    existing.startedAt = now;
    existing.expiresAt = _addPlanDuration(
      startFrom,
      existing.plan,
    );
    existing.active = true;
  }

  /// Deactivates the account's current subscription.
  ///
  /// Kept as a separate public method for compatibility with callers that
  /// use "cancel" terminology.
  void cancel(Account account) {
    deactivate(account);
  }

  /// Returns whether the account currently has an active, unexpired
  /// subscription.
  ///
  /// The model's [hasActiveSubscription] flag is not trusted by itself:
  /// expiration is checked against the current UTC time as well.
  bool canAccessContent(Account account) {
    _validateAccount(account);

    final subscription = account.subscription;

    if (subscription == null || !subscription.active) {
      return false;
    }

    final now = DateTime.now().toUtc();

    return subscription.expiresAt.toUtc().isAfter(now);
  }

  /// Returns whether a subscription is active and unexpired.
  bool isActive(Account account) {
    return canAccessContent(account);
  }

  /// Returns the remaining subscription duration.
  Duration remaining(Account account) {
    _validateAccount(account);

    final subscription = account.subscription;

    if (subscription == null || !subscription.active) {
      return Duration.zero;
    }

    final now = DateTime.now().toUtc();
    final expiration = subscription.expiresAt.toUtc();

    if (!expiration.isAfter(now)) {
      return Duration.zero;
    }

    return expiration.difference(now);
  }

  /// Marks an expired subscription inactive.
  ///
  /// This is a state-normalization helper and does not grant or extend
  /// access.
  bool expireIfNeeded(Account account) {
    _validateAccount(account);

    final subscription = account.subscription;

    if (subscription == null || !subscription.active) {
      return false;
    }

    final now = DateTime.now().toUtc();

    if (subscription.expiresAt.toUtc().isAfter(now)) {
      return false;
    }

    subscription.active = false;
    return true;
  }

  DateTime _addPlanDuration(
    DateTime start,
    SubscriptionPlan plan,
  ) {
    final utc = start.toUtc();

    switch (plan) {
      case SubscriptionPlan.monthly:
        return _addCalendarMonths(utc, 1);

      case SubscriptionPlan.yearly:
        return _addCalendarYears(utc, 1);
    }
  }

  /// Adds calendar months while handling dates such as January 31 safely.
  ///
  /// Dart's DateTime constructor normalizes overflow, which could turn
  /// "January 31 + one month" into a date in March. For subscription
  /// billing periods we instead clamp to the final valid day of the target
  /// month.
  DateTime _addCalendarMonths(
    DateTime start,
    int months,
  ) {
    final targetMonthIndex = (start.month - 1) + months;
    final targetYear = start.year + targetMonthIndex ~/ 12;
    final targetMonth = (targetMonthIndex % 12) + 1;

    final lastDay = _daysInMonth(
      targetYear,
      targetMonth,
    );

    final day = start.day > lastDay ? lastDay : start.day;

    return DateTime.utc(
      targetYear,
      targetMonth,
      day,
      start.hour,
      start.minute,
      start.second,
      start.millisecond,
      start.microsecond,
    );
  }

  DateTime _addCalendarYears(
    DateTime start,
    int years,
  ) {
    final targetYear = start.year + years;

    final day = start.month == DateTime.february &&
            start.day == 29 &&
            !_isLeapYear(targetYear)
        ? 28
        : start.day;

    return DateTime.utc(
      targetYear,
      start.month,
      day,
      start.hour,
      start.minute,
      start.second,
      start.millisecond,
      start.microsecond,
    );
  }

  int _daysInMonth(
    int year,
    int month,
  ) {
    return DateTime.utc(
      year,
      month + 1,
      0,
    ).day;
  }

  bool _isLeapYear(int year) {
    if (year % 400 == 0) {
      return true;
    }

    if (year % 100 == 0) {
      return false;
    }

    return year % 4 == 0;
  }

  void _validateAccount(Account account) {
    if (account.id.trim().isEmpty) {
      throw ArgumentError('Account ID cannot be empty.');
    }
  }
}
