/// Runtime-friendly summary of the Master Product Architecture.
///
/// This is intentionally metadata-only: domains own behavior in their feature
/// modules, while this catalog gives navigation, AI, analytics and diagnostics
/// one consistent vocabulary.
enum ProductDomain {
  identity,
  experience,
  media,
  playback,
  live,
  social,
  commerce,
  server,
  importPlatform,
  intelligence,
  notifications,
  themes,
}

class ProductCapability {
  final String key;
  final ProductDomain domain;
  final String label;
  final bool longRunning;
  final bool destructive;
  final bool requiresConfirmation;

  const ProductCapability({
    required this.key,
    required this.domain,
    required this.label,
    this.longRunning = false,
    this.destructive = false,
    this.requiresConfirmation = false,
  });
}

abstract final class MasterProductCapabilities {
  static const List<ProductCapability> all = <ProductCapability>[
    ProductCapability(key: 'home', domain: ProductDomain.experience, label: 'Home'),
    ProductCapability(key: 'library', domain: ProductDomain.media, label: 'Library'),
    ProductCapability(key: 'live', domain: ProductDomain.live, label: 'Live'),
    ProductCapability(key: 'music', domain: ProductDomain.media, label: 'Music'),
    ProductCapability(key: 'friends', domain: ProductDomain.social, label: 'Friends'),
    ProductCapability(key: 'community', domain: ProductDomain.social, label: 'Community'),
    ProductCapability(key: 'marketplace', domain: ProductDomain.commerce, label: 'Marketplace'),
    ProductCapability(key: 'profiles', domain: ProductDomain.identity, label: 'Profiles'),
    ProductCapability(key: 'search', domain: ProductDomain.experience, label: 'Search'),
    ProductCapability(key: 'hey_media', domain: ProductDomain.intelligence, label: 'Hey Media'),
    ProductCapability(key: 'player', domain: ProductDomain.playback, label: 'Player'),
    ProductCapability(key: 'xray', domain: ProductDomain.playback, label: 'X-Ray'),
    ProductCapability(key: 'themes', domain: ProductDomain.themes, label: 'Themes'),
    ProductCapability(key: 'social', domain: ProductDomain.social, label: 'Social'),
    ProductCapability(key: 'servers', domain: ProductDomain.server, label: 'Servers'),
    ProductCapability(key: 'nas', domain: ProductDomain.server, label: 'NAS'),
    ProductCapability(key: 'import_ripping', domain: ProductDomain.importPlatform, label: 'Import / Ripping', longRunning: true),
    ProductCapability(key: 'collections', domain: ProductDomain.experience, label: 'Collections'),
    ProductCapability(key: 'playlists', domain: ProductDomain.experience, label: 'Playlists'),
    ProductCapability(key: 'checkout', domain: ProductDomain.commerce, label: 'Checkout', requiresConfirmation: true),
    ProductCapability(key: 'store_management', domain: ProductDomain.commerce, label: 'Store Management'),
    ProductCapability(key: 'notifications', domain: ProductDomain.notifications, label: 'Notifications'),
    ProductCapability(key: 'permissions', domain: ProductDomain.identity, label: 'Permissions'),
    ProductCapability(key: 'ai', domain: ProductDomain.intelligence, label: 'AI'),
    ProductCapability(key: 'settings', domain: ProductDomain.identity, label: 'Settings'),
    ProductCapability(key: 'delete_media', domain: ProductDomain.media, label: 'Delete Media', destructive: true, requiresConfirmation: true),
    ProductCapability(key: 'server_migration', domain: ProductDomain.server, label: 'Server Migration', longRunning: true, requiresConfirmation: true),
  ];
}
