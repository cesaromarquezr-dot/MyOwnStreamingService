// FILE: Backend/services/payment_method_service.dart.
// Purpose: Extensible global marketplace payment-method registry.
//
// The registry is intentionally data-driven: adding another provider is a
// catalog/configuration change rather than a Flutter checkout rewrite.
// Provider APIs must still confirm transaction eligibility at payment time.

import '../models/account.dart';
import '../models/payment_method.dart';

class PaymentMethodService {
  PaymentMethodService() {
    _seedBuiltInRegistry();
  }

  final Map<String, PaymentMethodDefinition> _catalog =
      <String, PaymentMethodDefinition>{};

  final Map<String, Map<String, SellerPaymentMethodSelection>>
      _sellerSelections = <String, Map<String, SellerPaymentMethodSelection>>{};

  void _seedBuiltInRegistry() {
    final definitions = <PaymentMethodDefinition>[
      const PaymentMethodDefinition(
        id: 'card',
        providerKey: 'card_processor',
        displayName: 'Credit / Debit Card',
        methodType: 'card',
        globalFallback: true,
        priority: 10,
      ),
      const PaymentMethodDefinition(
        id: 'paypal',
        providerKey: 'paypal',
        displayName: 'PayPal',
        methodType: 'wallet',
        globalFallback: true,
        priority: 20,
      ),
      const PaymentMethodDefinition(
        id: 'apple_pay',
        providerKey: 'apple_pay',
        displayName: 'Apple Pay',
        methodType: 'wallet',
        globalFallback: true,
        priority: 30,
      ),
      const PaymentMethodDefinition(
        id: 'google_pay',
        providerKey: 'google_pay',
        displayName: 'Google Pay',
        methodType: 'wallet',
        globalFallback: true,
        priority: 31,
      ),
      const PaymentMethodDefinition(
        id: 'bank_transfer',
        providerKey: 'bank_transfer',
        displayName: 'Bank Transfer',
        methodType: 'bank_transfer',
        globalFallback: true,
        priority: 40,
      ),
      const PaymentMethodDefinition(
        id: 'mercado_pago',
        providerKey: 'mercado_pago',
        displayName: 'Mercado Pago',
        methodType: 'regional_wallet',
        supportedCountries: <String>{'AR', 'BR', 'CL', 'CO', 'MX', 'PE', 'UY'},
        priority: 50,
      ),
      const PaymentMethodDefinition(
        id: 'yape',
        providerKey: 'yape',
        displayName: 'Yape',
        methodType: 'regional_wallet',
        supportedCountries: <String>{'PE'},
        priority: 51,
      ),
      const PaymentMethodDefinition(
        id: 'upi',
        providerKey: 'upi',
        displayName: 'UPI',
        methodType: 'regional_wallet',
        supportedCountries: <String>{'IN'},
        priority: 52,
      ),
      const PaymentMethodDefinition(
        id: 'pix',
        providerKey: 'pix',
        displayName: 'Pix',
        methodType: 'bank_transfer',
        supportedCountries: <String>{'BR'},
        priority: 53,
      ),
      const PaymentMethodDefinition(
        id: 'ideal',
        providerKey: 'ideal',
        displayName: 'iDEAL',
        methodType: 'bank_transfer',
        supportedCountries: <String>{'NL'},
        priority: 54,
      ),
      const PaymentMethodDefinition(
        id: 'alipay',
        providerKey: 'alipay',
        displayName: 'Alipay',
        methodType: 'wallet',
        supportedCountries: <String>{'CN'},
        priority: 55,
      ),
      const PaymentMethodDefinition(
        id: 'wechat_pay',
        providerKey: 'wechat_pay',
        displayName: 'WeChat Pay',
        methodType: 'wallet',
        supportedCountries: <String>{'CN'},
        priority: 56,
      ),
    ];

    for (final definition in definitions) {
      _catalog[definition.id] = definition;
    }
  }

  List<PaymentMethodDefinition> get catalog => _catalog.values.toList()
    ..sort((a, b) => a.priority.compareTo(b.priority));

  PaymentMethodDefinition? byId(String id) => _catalog[id.trim()];

  void register(PaymentMethodDefinition definition) {
    final id = definition.id.trim();
    if (id.isEmpty) {
      throw ArgumentError('Payment method ID is required.');
    }
    _catalog[id] = definition;
  }

  SellerPaymentMethodSelection selectForSeller({
    required Account seller,
    required String paymentMethodId,
    required String countryCode,
    required String currencyCode,
    String? providerAccountReference,
    bool verified = false,
  }) {
    final method = byId(paymentMethodId);
    if (method == null) {
      throw StateError('Unknown payment method: $paymentMethodId');
    }
    if (!method.sellerSupported || !method.payoutSupported) {
      throw StateError('This payment method cannot be used for seller payouts.');
    }
    if (!method.supportsCountry(countryCode)) {
      throw StateError('This payment method is not configured for the seller country.');
    }
    if (!method.supportsCurrency(currencyCode)) {
      throw StateError('This payment method is not configured for the seller currency.');
    }

    final selection = SellerPaymentMethodSelection(
      sellerAccountId: seller.id,
      paymentMethodId: method.id,
      countryCode: countryCode.trim().toUpperCase(),
      currencyCode: currencyCode.trim().toUpperCase(),
      providerAccountReference: providerAccountReference?.trim().isEmpty == true
          ? null
          : providerAccountReference?.trim(),
      enabled: true,
      verified: verified,
    );

    final methods = _sellerSelections.putIfAbsent(
      seller.id,
      () => <String, SellerPaymentMethodSelection>{},
    );
    methods[method.id] = selection;
    return selection;
  }

  void disableSellerMethod({
    required String sellerAccountId,
    required String paymentMethodId,
  }) {
    final methods = _sellerSelections[sellerAccountId];
    final current = methods?[paymentMethodId];
    if (current == null) return;
    methods![paymentMethodId] = SellerPaymentMethodSelection(
      sellerAccountId: current.sellerAccountId,
      paymentMethodId: current.paymentMethodId,
      countryCode: current.countryCode,
      currencyCode: current.currencyCode,
      providerAccountReference: current.providerAccountReference,
      enabled: false,
      verified: current.verified,
    );
  }

  List<SellerPaymentMethodSelection> sellerMethods(String sellerAccountId) {
    return (_sellerSelections[sellerAccountId]?.values.toList() ?? const [])
        .where((method) => method.enabled)
        .toList();
  }

  /// Filters the seller's selected methods for a particular buyer.
  ///
  /// The country/currency registry is a first-pass filter. The final provider
  /// authorization check must still happen server-to-server at checkout.
  List<PaymentMethodDefinition> methodsForBuyer({
    required String sellerAccountId,
    required String buyerCountryCode,
    required String currencyCode,
    bool includeGlobalFallbacks = true,
  }) {
    final selected = sellerMethods(sellerAccountId);
    final results = <PaymentMethodDefinition>[];

    for (final selection in selected) {
      final definition = byId(selection.paymentMethodId);
      if (definition == null || !definition.buyerSupported) continue;
      if (!definition.supportsCountry(buyerCountryCode)) continue;
      if (!definition.supportsCurrency(currencyCode)) continue;
      results.add(definition);
    }

    if (results.isEmpty && includeGlobalFallbacks) {
      for (final definition in catalog) {
        if (!definition.globalFallback || !definition.buyerSupported) continue;
        if (!definition.supportsCountry(buyerCountryCode)) continue;
        if (!definition.supportsCurrency(currencyCode)) continue;
        results.add(definition);
      }
    }

    final byIdMap = <String, PaymentMethodDefinition>{
      for (final method in results) method.id: method,
    };

    return byIdMap.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  Map<String, dynamic> catalogJson() => {
        'methods': catalog.map((method) => method.toJson()).toList(),
      };
}
