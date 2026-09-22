// FILE: Backend/models/platform_capabilities.dart.
// Purpose: Provides a single capability manifest so clients can discover which
// shared-platform systems are available without creating feature-specific flags.
// This file is part of the documented Flutter/home-server architecture.
//
// Design notes:
// - Capability names remain strings so new platform capabilities can be added
//   without requiring synchronized enum changes across every client.
// - The manifest describes platform availability, not user permissions.
// - Authorization must still be enforced by backend routes/services.
// - Unknown capability names are treated as unsupported.
// - The serialized representation is intentionally stable for API clients.

/// Platform-wide capability manifest shared by Flutter, server, and admin clients.
class PlatformCapabilities {
  final Map<String, bool> features;

  const PlatformCapabilities({
    this.features = const {},
  });

  /// Returns whether a named capability is enabled by the current platform
  /// build.
  ///
  /// Unknown or blank capability names return false.
  bool supports(String key) {
    final normalizedKey = _normalizeKey(key);
    if (normalizedKey == null) {
      return false;
    }

    return features[normalizedKey] == true;
  }

  /// Returns whether at least one capability is enabled.
  bool get hasEnabledFeatures => features.values.any((enabled) => enabled);

  /// Returns the number of enabled capabilities.
  int get enabledFeatureCount =>
      features.values.where((enabled) => enabled).length;

  /// Returns the number of registered capabilities.
  int get featureCount => features.length;

  /// Returns a normalized immutable-style copy of the capability registry.
  ///
  /// The model itself remains compatible with the existing mutable-map API,
  /// while callers receive a new map rather than the internal map instance.
  Map<String, bool> get featureMap => Map<String, bool>.from(features);

  /// Returns the enabled capability names.
  List<String> get enabledFeatures => features.entries
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList(growable: false);

  /// Returns the disabled capability names.
  List<String> get disabledFeatures => features.entries
      .where((entry) => !entry.value)
      .map((entry) => entry.key)
      .toList(growable: false);

  /// Creates a copy with optional capability changes.
  ///
  /// Set [clearFeatures] to true when a caller needs to replace the entire
  /// capability registry with [features].
  PlatformCapabilities copyWith({
    Map<String, bool>? features,
    Map<String, bool> additionalFeatures = const {},
    Iterable<String> removeFeatures = const <String>[],
    bool clearFeatures = false,
  }) {
    final next = clearFeatures
        ? <String, bool>{}
        : Map<String, bool>.from(this.features);

    if (features != null) {
      next.addAll(_normalizeFeatures(features));
    }

    next.addAll(_normalizeFeatures(additionalFeatures));

    for (final key in removeFeatures) {
      final normalizedKey = _normalizeKey(key);
      if (normalizedKey != null) {
        next.remove(normalizedKey);
      }
    }

    return PlatformCapabilities(features: next);
  }

  /// Enables a capability in a new manifest.
  PlatformCapabilities enable(String key) {
    final normalizedKey = _normalizeKey(key);
    if (normalizedKey == null) {
      return this;
    }

    return copyWith(
      additionalFeatures: <String, bool>{
        normalizedKey: true,
      },
    );
  }

  /// Disables a capability in a new manifest.
  PlatformCapabilities disable(String key) {
    final normalizedKey = _normalizeKey(key);
    if (normalizedKey == null) {
      return this;
    }

    return copyWith(
      additionalFeatures: <String, bool>{
        normalizedKey: false,
      },
    );
  }

  /// Removes a capability entirely from a new manifest.
  PlatformCapabilities remove(String key) {
    return copyWith(removeFeatures: <String>[key]);
  }

  /// Performs basic model validation.
  ///
  /// Capability names must be non-empty and may not contain surrounding
  /// whitespace. Boolean values are enforced by the strongly typed model.
  bool get isValid {
    for (final key in features.keys) {
      if (key.trim().isEmpty || key != key.trim()) {
        return false;
      }
    }

    return true;
  }

  /// Creates a capability manifest from persisted/API JSON.
  ///
  /// Malformed or non-boolean feature values are ignored rather than being
  /// interpreted as enabled. This prevents a malformed payload from
  /// accidentally granting feature availability.
  factory PlatformCapabilities.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];

    if (rawFeatures is! Map) {
      return const PlatformCapabilities();
    }

    final parsed = <String, bool>{};

    rawFeatures.forEach((key, value) {
      final normalizedKey = _normalizeKey(key);
      if (normalizedKey == null) {
        return;
      }

      if (value is bool) {
        parsed[normalizedKey] = value;
      }
    });

    return PlatformCapabilities(features: parsed);
  }

  /// Serializes the capability registry for
  /// `/api/v1/platform/capabilities`.
  Map<String, dynamic> toJson() => {
        'features': Map<String, bool>.from(features),
      };

  @override
  String toString() {
    return 'PlatformCapabilities('
        'featureCount: $featureCount, '
        'enabledFeatureCount: $enabledFeatureCount, '
        'features: $features'
        ')';
  }
}

String? _normalizeKey(Object? value) {
  if (value is! String) {
    return null;
  }

  final key = value.trim();
  return key.isEmpty ? null : key;
}

Map<String, bool> _normalizeFeatures(Map<String, bool> source) {
  final result = <String, bool>{};

  source.forEach((key, value) {
    final normalizedKey = _normalizeKey(key);
    if (normalizedKey == null) {
      return;
    }

    result[normalizedKey] = value;
  });

  return result;
}