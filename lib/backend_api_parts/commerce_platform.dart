// Domain API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiCommercePlatformMethods on BackendApi {
  Future<List<Map<String, dynamic>>> getPaymentMethodCatalog() async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await _networkClient.get(
        Uri.parse('$baseUrl/payment-methods'),
        headers: _headers,
      ),
      'Unable to load payment methods.',
    );
    return (data['methods'] is List)
        ? (data['methods'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> saveSellerPaymentMethod({
    required String paymentMethodId,
    required String countryCode,
    required String currencyCode,
    String? providerAccountReference,
    bool verified = false,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/payment-methods/seller'),
        headers: _headers,
        body: jsonEncode({
          'paymentMethodId': paymentMethodId,
          'countryCode': countryCode,
          'currencyCode': currencyCode,
          'providerAccountReference': providerAccountReference,
          'verified': verified,
        }),
      ),
      'Unable to save seller payment method.',
    );
  }

  Future<List<Map<String, dynamic>>> getSellerPayoutDestinations() async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await _networkClient.get(
        Uri.parse('$baseUrl/seller/payout-destinations'),
        headers: _headers,
      ),
      'Unable to load seller payout destinations.',
    );
    return (data['destinations'] is List)
        ? (data['destinations'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> saveSellerPayoutDestination({
    required String providerKey,
    required String methodType,
    required String displayName,
    String? providerAccountReference,
    String? maskedIdentifier,
    bool enabled = true,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/seller/payout-destinations'),
        headers: _headers,
        body: jsonEncode({
          'providerKey': providerKey,
          'methodType': methodType,
          'displayName': displayName,
          'providerAccountReference': providerAccountReference,
          'maskedIdentifier': maskedIdentifier,
          'enabled': enabled,
        }),
      ),
      'Unable to save seller payout destination.',
    );
  }

  Future<void> deleteSellerPayoutDestination(String id) async {
    _requireAuthentication();
    await _requireSuccess(
      await _networkClient.delete(
        Uri.parse('$baseUrl/seller/payout-destinations')
            .replace(queryParameters: {'id': id}),
        headers: _headers,
      ),
      'Unable to delete seller payout destination.',
    );
  }

  Future<List<Map<String, dynamic>>> getShopLiveEvents() async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await _networkClient.get(Uri.parse('$baseUrl/shop/live-events'), headers: _headers),
      'Unable to load live shopping events.',
    );
    return (data['events'] is List)
        ? (data['events'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createShopLiveEvent({
    required String storeId,
    required String storeName,
    required String title,
    required String description,
    required List<String> productIds,
    String? streamUrl,
    String? pinnedProductId,
    DateTime? scheduledAt,
    bool randomizedRewardsEnabled = false,
  }) async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await _networkClient.post(Uri.parse('$baseUrl/shop/live-events'),
          headers: _headers,
          body: jsonEncode({
            'storeId': storeId,
            'storeName': storeName,
            'title': title,
            'description': description,
            'productIds': productIds,
            'streamUrl': streamUrl,
            'pinnedProductId': pinnedProductId,
            'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
            'randomizedRewardsEnabled': randomizedRewardsEnabled,
          })),
      'Unable to create the live shopping event.',
    );
    return Map<String, dynamic>.from(data['event'] as Map);
  }

  Future<Map<String, dynamic>> updateShopLiveEvent({
    required String eventId,
    String? status,
    String? streamUrl,
    String? replayUrl,
    String? pinnedProductId,
    Map<String, dynamic>? poll,
    bool? randomizedRewardsEnabled,
  }) async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await _networkClient.patch(
          Uri.parse(
              '$baseUrl/shop/live-events/${Uri.encodeComponent(eventId)}'),
          headers: _headers,
          body: jsonEncode({
            if (status != null) 'status': status,
            if (streamUrl != null) 'streamUrl': streamUrl,
            if (replayUrl != null) 'replayUrl': replayUrl,
            if (pinnedProductId != null) 'pinnedProductId': pinnedProductId,
            if (poll != null) 'poll': poll,
            if (randomizedRewardsEnabled != null)
              'randomizedRewardsEnabled': randomizedRewardsEnabled,
          })),
      'Unable to update the live shopping event.',
    );
    return Map<String, dynamic>.from(data['event'] as Map);
  }

  Future<Map<String, dynamic>> askShopLiveQuestion(
      {required String eventId,
      required String profileId,
      required String text}) async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await _networkClient.post(
          Uri.parse(
              '$baseUrl/shop/live-events/${Uri.encodeComponent(eventId)}/questions'),
          headers: _headers,
          body: jsonEncode({'profileId': profileId, 'question': text})),
      'Unable to send your question.',
    );
    return Map<String, dynamic>.from(data['event'] as Map);
  }

  Future<Map<String, dynamic>> voteShopLivePoll(
      {required String eventId,
      required String profileId,
      required int optionIndex}) async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await _networkClient.post(
          Uri.parse(
              '$baseUrl/shop/live-events/${Uri.encodeComponent(eventId)}/vote'),
          headers: _headers,
          body:
              jsonEncode({'profileId': profileId, 'optionIndex': optionIndex})),
      'Unable to submit your poll vote.',
    );
    return Map<String, dynamic>.from(data['event'] as Map);
  }

  Future<List<Map<String, dynamic>>> filterPaymentMethodsForBuyer({
    required String sellerAccountId,
    required String buyerCountryCode,
    required String currencyCode,
  }) async {
    _requireAuthentication();
    final data = await _requireSuccess(
      await _networkClient.post(
        Uri.parse('$baseUrl/payment-methods/filter'),
        headers: _headers,
        body: jsonEncode({
          'sellerAccountId': sellerAccountId,
          'buyerCountryCode': buyerCountryCode,
          'currencyCode': currencyCode,
        }),
      ),
      'Unable to filter payment methods.',
    );
    return (data['methods'] is List)
        ? (data['methods'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
  }


}
