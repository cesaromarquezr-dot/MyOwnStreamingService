// FILE: `Backend/models/subscription.dart`.
// Purpose: Implements the subscription portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Subscription state represents entitlement/lifecycle information. Payment
// processing, checkout sessions, processor verification, and authorization
// belong to the payment/service layers rather than this model.

enum SubscriptionPlan {
  monthly,
  yearly,
}

extension SubscriptionPlanExtension on SubscriptionPlan {
  String get value => name;

  String get displayName {
    switch (this) {
      case SubscriptionPlan.monthly:
        return 'Monthly';
      case SubscriptionPlan.yearly:
        return 'Yearly';
    }
  }

  double get priceUsd {
    switch (this) {
      case SubscriptionPlan.monthly:
        return 8.00;
      case SubscriptionPlan.yearly:
        return 50.00;
    }
  }

  Duration get nominalDuration {
    switch (this) {
      case SubscriptionPlan.monthly:
        return const Duration(days: 30);
      case SubscriptionPlan.yearly:
        return const Duration(days: 365);
    }
  }

  static SubscriptionPlan fromValue(
    dynamic value, {
    SubscriptionPlan fallback = SubscriptionPlan.monthly,
  }) {
    if (value is SubscriptionPlan) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();

    switch (normalized) {
      case 'monthly':
      case 'month':
        return SubscriptionPlan.monthly;

      case 'yearly':
      case 'annual':
      case 'year':
        return SubscriptionPlan.yearly;

      default:
        return fallback;
    }
  }
}

class Subscription {
  final String id;
  final SubscriptionPlan plan;

  DateTime startedAt;
  DateTime expiresAt;
  bool active;

  Subscription({
    required this.id,
    required this.plan,
    required this.startedAt,
    required this.expiresAt,
    this.active = true,
  });

  double get priceUsd => plan.priceUsd;

  String get planName => plan.displayName;

  bool get isValid =>
      id.trim().isNotEmpty &&
      !expiresAt.isBefore(startedAt);

  bool get hasStarted =>
      !DateTime.now().isBefore(startedAt);

  bool get hasExpired =>
      DateTime.now().isAfter(expiresAt);

  bool get isCurrentlyActive =>
      active &&
      !hasExpired;

  bool get isPending =>
      active &&
      DateTime.now().isBefore(startedAt);

  bool get isCurrentOrPending =>
      active &&
      !hasExpired;

  Duration get remainingDuration {
    final now = DateTime.now();

    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }

    return expiresAt.difference(now);
  }

  /// Returns the nominal duration represented by the selected plan.
  ///
  /// This is informational. Actual entitlement dates are determined by
  /// `startedAt` and `expiresAt`, not by this duration.
  Duration get nominalDuration => plan.nominalDuration;

  /// Marks the subscription inactive when its entitlement period has ended.
  ///
  /// An optional [now] makes this deterministic for tests and backend jobs.
  void expireIfNeeded({DateTime? now}) {
    final current = now ?? DateTime.now();

    if (current.isAfter(expiresAt)) {
      active = false;
    }
  }

  /// Explicitly deactivates the subscription.
  void deactivate() {
    active = false;
  }

  /// Reactivates the subscription without changing its entitlement dates.
  ///
  /// Callers should verify that the subscription dates are still valid before
  /// using this operation. Payment/re-subscription flows should generally
  /// create or update entitlement dates in the service layer.
  void activate() {
    active = true;
  }

  Subscription copyWith({
    String? id,
    SubscriptionPlan? plan,
    DateTime? startedAt,
    DateTime? expiresAt,
    bool? active,
  }) {
    return Subscription(
      id: id ?? this.id,
      plan: plan ?? this.plan,
      startedAt: startedAt ?? this.startedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      active: active ?? this.active,
    );
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    return Subscription(
      id: _stringValue(json['id']),
      plan: SubscriptionPlanExtension.fromValue(
        json['plan'],
      ),
      startedAt:
          _dateTimeValue(json['startedAt']) ?? now,
      expiresAt:
          _dateTimeValue(json['expiresAt']) ?? now,
      active: _boolValue(
        json['active'],
        fallback: true,
      ),
    );
  }

  /// Performs `toJson` for this feature.
  ///
  /// `priceUsd`, `planName`, and `isCurrentlyActive` are derived values and
  /// are included for API/UI compatibility. The persisted entitlement state
  /// remains `plan`, `startedAt`, `expiresAt`, and `active`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan': plan.name,
      'planName': planName,
      'priceUsd': priceUsd,
      'startedAt': startedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'active': active,
      'isCurrentlyActive': isCurrentlyActive,
    };
  }

  @override
  String toString() {
    return 'Subscription('
        'id: $id, '
        'plan: ${plan.name}, '
        'startedAt: $startedAt, '
        'expiresAt: $expiresAt, '
        'active: $active, '
        'isCurrentlyActive: $isCurrentlyActive'
        ')';
  }
}

String _stringValue(
  dynamic value, {
  String fallback = '',
}) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

bool _boolValue(
  dynamic value, {
  bool fallback = false,
}) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'y':
        return true;

      case 'false':
      case '0':
      case 'no':
      case 'n':
        return false;
    }
  }

  return fallback;
}

DateTime? _dateTimeValue(dynamic value) {
  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}