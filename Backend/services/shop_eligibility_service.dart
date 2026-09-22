// FILE: Backend/services/shop_eligibility_service.dart.
// Purpose: Enforces the rule that a Shop/Merchandise action appears only when
// a real eligible merchant/product relationship exists.
//
// This service intentionally does not invent merchandise relationships.
// An item is eligible only when a concrete merchant offer exists and that
// offer satisfies the configured eligibility rules.

/// Minimal merchant offer representation consumed by the Shop eligibility
/// layer.
class MerchantOffer {
  final String productId;
  final String merchantId;
  final String mediaId;
  final bool active;
  final bool inStock;
  final String? purchaseUrl;

  const MerchantOffer({
    required this.productId,
    required this.merchantId,
    required this.mediaId,
    this.active = true,
    this.inStock = true,
    this.purchaseUrl,
  });
}

/// Determines whether an entertainment item has a genuine Shop relationship.
class ShopEligibilityService {
  static const int maxIdLength = 200;
  static const int maxPurchaseUrlLength = 2048;

  const ShopEligibilityService();

  /// Returns true only when at least one active, eligible offer exists.
  ///
  /// Eligibility requires:
  /// - a non-empty media ID;
  /// - an exact media relationship;
  /// - an active offer;
  /// - the offer being in stock;
  /// - a non-empty product ID;
  /// - a non-empty merchant ID;
  /// - a valid optional HTTPS purchase URL when one is supplied.
  ///
  /// The service does not consider a title, genre, actor, franchise, or other
  /// metadata relationship sufficient to create merchandise eligibility.
  bool hasEligibleMerchandise(
    Iterable<MerchantOffer> offers,
    String mediaId,
  ) {
    final id = _normalizeRequiredId(
      mediaId,
      field: 'Media ID',
    );

    if (id == null) {
      return false;
    }

    for (final offer in offers) {
      if (!_isEligibleOffer(offer, id)) {
        continue;
      }

      return true;
    }

    return false;
  }

  /// Returns all eligible offers for a media item.
  ///
  /// This is useful when the frontend needs to display multiple merchant
  /// options instead of merely deciding whether the Shop action is visible.
  List<MerchantOffer> eligibleOffers(
    Iterable<MerchantOffer> offers,
    String mediaId,
  ) {
    final id = _normalizeRequiredId(
      mediaId,
      field: 'Media ID',
    );

    if (id == null) {
      return const [];
    }

    final results = <MerchantOffer>[];

    for (final offer in offers) {
      if (_isEligibleOffer(offer, id)) {
        results.add(offer);
      }
    }

    return List<MerchantOffer>.unmodifiable(results);
  }

  /// Returns whether one offer satisfies the minimum merchant relationship
  /// requirements for the supplied media ID.
  bool isEligibleOffer(
    MerchantOffer offer,
    String mediaId,
  ) {
    final id = _normalizeRequiredId(
      mediaId,
      field: 'Media ID',
    );

    if (id == null) {
      return false;
    }

    return _isEligibleOffer(offer, id);
  }

  bool _isEligibleOffer(
    MerchantOffer offer,
    String normalizedMediaId,
  ) {
    if (!offer.active || !offer.inStock) {
      return false;
    }

    final productId = _normalizeRequiredId(
      offer.productId,
      field: 'Product ID',
    );

    if (productId == null) {
      return false;
    }

    final merchantId = _normalizeRequiredId(
      offer.merchantId,
      field: 'Merchant ID',
    );

    if (merchantId == null) {
      return false;
    }

    final offerMediaId = _normalizeRequiredId(
      offer.mediaId,
      field: 'Offer media ID',
    );

    if (offerMediaId == null || offerMediaId != normalizedMediaId) {
      return false;
    }

    if (!_isValidPurchaseUrl(offer.purchaseUrl)) {
      return false;
    }

    return true;
  }

  String? _normalizeRequiredId(
    String value, {
    required String field,
  }) {
    final normalized = value.trim();

    if (normalized.isEmpty ||
        normalized.length > maxIdLength ||
        _containsControlCharacter(normalized)) {
      return null;
    }

    return normalized;
  }

  bool _isValidPurchaseUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      // A merchant relationship does not necessarily require an external
      // purchase URL. The offer can still be eligible for an internal
      // checkout flow.
      return true;
    }

    final normalized = value.trim();

    if (normalized.length > maxPurchaseUrlLength ||
        _containsControlCharacter(normalized)) {
      return false;
    }

    final uri = Uri.tryParse(normalized);

    if (uri == null) {
      return false;
    }

    // Do not allow javascript:, data:, file:, or other executable/local
    // schemes to become an eligible external purchase destination.
    if (uri.scheme.toLowerCase() != 'https') {
      return false;
    }

    if (uri.host.trim().isEmpty) {
      return false;
    }

    return true;
  }

  bool _containsControlCharacter(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit == 0 ||
          (codeUnit < 32 && codeUnit != 9 && codeUnit != 10 && codeUnit != 13)) {
        return true;
      }
    }

    return false;
  }
}