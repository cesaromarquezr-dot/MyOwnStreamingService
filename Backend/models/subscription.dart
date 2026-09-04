enum SubscriptionPlan {
  monthly,
  yearly,
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

  double get priceUsd {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return 8.00;

      case SubscriptionPlan.yearly:
        return 50.00;
    }
  }

  String get planName {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return 'Monthly';

      case SubscriptionPlan.yearly:
        return 'Yearly';
    }
  }

  bool get isCurrentlyActive {
    if (!active) {
      return false;
    }

    if (DateTime.now().isAfter(expiresAt)) {
      return false;
    }

    return true;
  }

  void expireIfNeeded() {
    if (DateTime.now().isAfter(expiresAt)) {
      active = false;
    }
  }

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
}