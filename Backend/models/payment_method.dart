// FILE: Backend/models/payment_method.dart.
// Purpose: Global, extensible marketplace payment-method models.
// Sensitive payment credentials are intentionally represented by provider
// references/tokens only. Raw card PAN/CVV/bank credentials never belong here.

class PaymentMethodDefinition {
  final String id;
  final String providerKey;
  final String displayName;
  final String methodType;
  final Set<String> supportedCountries;
  final Set<String> supportedCurrencies;
  final bool buyerSupported;
  final bool sellerSupported;
  final bool payoutSupported;
  final bool globalFallback;
  final int priority;

  const PaymentMethodDefinition({
    required this.id,
    required this.providerKey,
    required this.displayName,
    required this.methodType,
    this.supportedCountries = const <String>{'*'},
    this.supportedCurrencies = const <String>{'*'},
    this.buyerSupported = true,
    this.sellerSupported = true,
    this.payoutSupported = true,
    this.globalFallback = false,
    this.priority = 100,
  });

  bool supportsCountry(String countryCode) {
    final country = countryCode.trim().toUpperCase();
    return supportedCountries.contains('*') || supportedCountries.contains(country);
  }

  bool supportsCurrency(String currencyCode) {
    final currency = currencyCode.trim().toUpperCase();
    return supportedCurrencies.contains('*') || supportedCurrencies.contains(currency);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerKey': providerKey,
        'displayName': displayName,
        'methodType': methodType,
        'supportedCountries': supportedCountries.toList()..sort(),
        'supportedCurrencies': supportedCurrencies.toList()..sort(),
        'buyerSupported': buyerSupported,
        'sellerSupported': sellerSupported,
        'payoutSupported': payoutSupported,
        'globalFallback': globalFallback,
        'priority': priority,
      };
}

class SellerPaymentMethodSelection {
  final String sellerAccountId;
  final String paymentMethodId;
  final String countryCode;
  final String currencyCode;
  final String? providerAccountReference;
  final bool enabled;
  final bool verified;

  const SellerPaymentMethodSelection({
    required this.sellerAccountId,
    required this.paymentMethodId,
    required this.countryCode,
    required this.currencyCode,
    this.providerAccountReference,
    this.enabled = true,
    this.verified = false,
  });

  Map<String, dynamic> toJson() => {
        'sellerAccountId': sellerAccountId,
        'paymentMethodId': paymentMethodId,
        'countryCode': countryCode,
        'currencyCode': currencyCode,
        'providerAccountReference': providerAccountReference,
        'enabled': enabled,
        'verified': verified,
      };
}
