// FILE: lib/shop.dart
// Purpose: Provides the top-level Shop destination for the streaming service.
// Shop uses only real merchant relationships exposed by the shared media model.

import 'package:flutter/material.dart';
import 'app_core.dart';
import 'localization.dart';

/// Implements the top-level marketplace screen.
///
/// The screen intentionally does not invent products. A title appears here only
/// when its media record contains an eligible merchant/product relationship.
class ShopScreen extends StatelessWidget {
  final VoidCallback? onHome;

  const ShopScreen({super.key, this.onHome});

  /// Builds the marketplace destination using the shared library and eligibility model.
  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final eligible = controller.library
        .where((media) =>
            media.isAccessibleTo(controller.currentProfile) &&
            media.hasEligibleMerchandise)
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Always return the user to the Home destination instead of
            // leaving them on a previous nested feature route.
            if (onHome != null) {
              onHome!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const UniversalText('Shop'),
        actions: const [LanguagePicker()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Text(
            'Shop',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          UniversalText(
            'Browse real products connected to the entertainment in your library.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .68),
            ),
          ),
          const SizedBox(height: 18),
          if (eligible.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 58),
                    const SizedBox(height: 14),
                    const UniversalText(
                      'No eligible products yet',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    UniversalText(
                      'When a verified merchant offers a product related to media you can access, it will appear here. The platform will not create a Shop button or product listing without a real eligible relationship.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .68),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const UniversalText(
              'From Your Library',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final media in eligible)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: media.imageUrl != null && media.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            media.imageUrl!,
                            width: 48,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.movie_outlined),
                          ),
                        )
                      : const Icon(Icons.movie_outlined),
                  title: Text(media.title),
                  subtitle: UniversalText(
                    '${media.eligibleMerchandiseProductIds.length} eligible product${media.eligibleMerchandiseProductIds.length == 1 ? '' : 's'}',
                  ),
                  trailing: FilledButton.icon(
                    onPressed: () => _showProducts(context, media),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const UniversalText('Shop'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Shows the real product IDs linked to a media item without fabricating product details.
  void _showProducts(BuildContext context, MediaItem media) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(media.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const UniversalText('Eligible merchant products are linked by stable product IDs. Product details and checkout are supplied by the commerce layer.'),
              const SizedBox(height: 12),
              for (final productId in media.eligibleMerchandiseProductIds)
                ListTile(
                  leading: const Icon(Icons.local_offer_outlined),
                  title: Text('Product $productId'),
                  subtitle: const UniversalText('Eligible merchant relationship'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
