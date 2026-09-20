// FILE: Backend/services/shop_eligibility_service.dart.
// Purpose: Enforces the rule that a Shop/Merchandise action appears only when
// a real eligible merchant/product relationship exists.

/// Minimal merchant offer representation consumed by the Shop eligibility layer.
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
  const ShopEligibilityService();

  /// Returns true only when at least one active, eligible offer exists.
  bool hasEligibleMerchandise(Iterable<MerchantOffer> offers, String mediaId) {
    final id = mediaId.trim();
    if (id.isEmpty) return false;
    return offers.any((offer) =>
        offer.mediaId == id && offer.active && offer.inStock && offer.productId.isNotEmpty);
  }
}
