// FILE: Backend/models/platform_capabilities.dart.
// Purpose: Provides a single capability manifest so clients can discover which
// shared-platform systems are available without creating feature-specific flags.

/// Platform-wide capability manifest shared by Flutter, server, and admin clients.
class PlatformCapabilities {
  final Map<String, bool> features;

  const PlatformCapabilities({this.features = const {}});

  /// Returns whether a named capability is enabled by the current platform build.
  bool supports(String key) => features[key] == true;

  /// Serializes the capability registry for `/api/v1/platform/capabilities`.
  Map<String, dynamic> toJson() => {
        'features': Map<String, bool>.from(features),
      };
}
