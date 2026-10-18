/// Policy gate for explicit, trusted rights-screening signals attached by an
/// ARM adapter or rights-review service. This is not a piracy classifier:
/// disc metadata alone cannot establish that a physical disc is counterfeit.
///
/// Only adapters that have verified a signal's provenance should populate
/// these fields. Missing signals mean "unknown", not "authorized".
class MediaRightsPolicy {
  const MediaRightsPolicy._();

  static const Set<String> _blockedStatuses = <String>{
    'pirated',
    'piracy_confirmed',
    'known_pirated',
    'unauthorized',
    'counterfeit',
    'infringing',
    'blocked',
  };

  static const Set<String> _statusKeys = <String>{
    'rightsStatus',
    'rights_status',
    'sourceLegitimacy',
    'source_legitimacy',
    'copyrightStatus',
    'copyright_status',
    'contentRightsStatus',
    'content_rights_status',
  };

  static const Set<String> _flagKeys = <String>{
    'piracyDetected',
    'piracy_detected',
    'knownPirated',
    'known_pirated',
    'counterfeitDisc',
    'counterfeit_disc',
    'unauthorizedSource',
    'unauthorized_source',
  };

  /// Returns a user-safe reason when explicit blocked signals are present.
  /// Returns null when no explicit blocked signal is present; this does not
  /// certify the disc as legitimate.
  static String? blockReason(Map<String, dynamic> source) {
    for (final entry in source.entries) {
      final key = entry.key;
      final value = entry.value;
      if (_flagKeys.contains(key) && value == true) {
        return 'A trusted rights signal marked this disc/source as pirated or unauthorized.';
      }
      if (_statusKeys.contains(key) &&
          _blockedStatuses.contains(value.toString().trim().toLowerCase())) {
        return 'A trusted rights signal marked this disc/source as ${value.toString()}.';
      }
      if (value is Map) {
        final nested = blockReason(Map<String, dynamic>.from(value));
        if (nested != null) return nested;
      } else if (value is List) {
        for (final item in value) {
          if (item is Map) {
            final nested = blockReason(Map<String, dynamic>.from(item));
            if (nested != null) return nested;
          }
        }
      }
    }
    return null;
  }
}
