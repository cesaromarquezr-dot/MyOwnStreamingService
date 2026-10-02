// Production payment-provider capability/adapters.
// Credentials remain backend-only environment variables. The existing MOCK
// processor remains available for local Phase 1 development.

import 'dart:convert';
import 'dart:io';

class PaymentProviderCapability {
  final String id;
  final String displayName;
  final bool configured;
  final bool serverApi;
  final bool clientMerchantFlow;
  const PaymentProviderCapability(this.id, this.displayName,
      {required this.configured,
      this.serverApi = true,
      this.clientMerchantFlow = false});
  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'configured': configured,
        'serverApi': serverApi,
        'clientMerchantFlow': clientMerchantFlow
      };
}

class PaymentProviderService {
  List<PaymentProviderCapability> capabilities() => [
        PaymentProviderCapability('paypal', 'PayPal',
            configured: _env('PAYPAL_CLIENT_ID').isNotEmpty &&
                _env('PAYPAL_CLIENT_SECRET').isNotEmpty),
        PaymentProviderCapability('apple_pay', 'Apple Pay',
            configured: _env('APPLE_PAY_MERCHANT_ID').isNotEmpty,
            serverApi: false,
            clientMerchantFlow: true),
        PaymentProviderCapability('mercado_pago', 'Mercado Pago',
            configured: _env('MERCADO_PAGO_ACCESS_TOKEN').isNotEmpty),
      ];

  bool get anyRealProviderConfigured => capabilities().any((x) => x.configured);

  Future<String> createPayPalAccessToken() async {
    final clientId = _env('PAYPAL_CLIENT_ID');
    final secret = _env('PAYPAL_CLIENT_SECRET');
    if (clientId.isEmpty || secret.isEmpty)
      throw StateError('PayPal is not configured.');
    final base = (_env('PAYPAL_BASE_URL').isEmpty
        ? 'https://api-m.sandbox.paypal.com'
        : _env('PAYPAL_BASE_URL'));
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$base/v1/oauth2/token'));
      req.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${base64Encode(utf8.encode('$clientId:$secret'))}',
      );
      req.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      req.write('grant_type=client_credentials');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode >= 300)
        throw StateError('PayPal authentication failed (${res.statusCode}).');
      final json = jsonDecode(body);
      final token = json is Map ? json['access_token']?.toString() : null;
      if (token == null || token.isEmpty)
        throw StateError('PayPal did not return an access token.');
      return token;
    } finally {
      client.close(force: true);
    }
  }

  String _env(String key) => Platform.environment[key]?.trim() ?? '';
}
