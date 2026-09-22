// FILE: Backend/services/media_access_policy.dart.
//
// Purpose:
// Defines the application's personal-media availability contract.
//
// This policy deliberately separates content availability from network
// security telemetry. IP geolocation, VPN state, and physical-disc region
// metadata do not independently grant or revoke access to personal media.

import '../models/media.dart';

/// Performs media-availability policy decisions for a personal-media
/// application.
///
/// This class is intentionally policy-only. It does not perform network
/// requests, inspect IP addresses, validate VPN connections, or determine
/// whether a user owns a physical disc. Those concerns belong to their
/// respective services.
class MediaAccessPolicy {
  /// Stable policy version returned to clients and diagnostics.
  static const String policyVersion = '1';

  /// Returns true when a media item's disc-region metadata is informational
  /// only.
  ///
  /// `discRegion` describes the physical disc/release source. It is retained
  /// as provenance metadata and is not treated as a licensing geofence.
  bool discRegionIsMetadataOnly(Media media) {
    return true;
  }

  /// Returns whether VPN or network changes are allowed to alter catalog
  /// availability.
  ///
  /// A VPN is a transport/security mechanism, not a media licensing rule.
  bool vpnCanChangeCatalog() {
    return false;
  }

  /// Returns whether geographic/IP information can independently deny access
  /// to personal catalog media.
  ///
  /// Personal-media availability is determined by the application's
  /// authenticated ownership/access rules rather than IP-country filtering.
  bool geographicFilteringCanDenyPersonalMedia() {
    return false;
  }

  /// Returns whether physical-disc region metadata can independently deny
  /// playback.
  ///
  /// The region remains useful for provenance, diagnostics, metadata display,
  /// and future format-specific handling, but it is not itself an
  /// authorization decision.
  bool discRegionCanDenyAccess(Media media) {
    return false;
  }

  /// Returns whether VPN state can independently grant access to media.
  ///
  /// A VPN may be required by a separate self-hosting/security policy, but
  /// satisfying that network requirement does not itself authorize media.
  bool vpnCanGrantMediaAccess() {
    return false;
  }

  /// Describes the policy contract for authenticated access/playback
  /// responses.
  ///
  /// This metadata is diagnostic and declarative. It does not replace the
  /// application's actual authentication, account ownership, profile access,
  /// or media-permission checks.
  Map<String, dynamic> toJson({Media? media}) {
    return {
      'policyVersion': policyVersion,

      // Geographic network information is not a personal-media catalog
      // authorization mechanism.
      'geographicCatalogFiltering': false,
      'geographicFilteringCanDenyPersonalMedia': false,

      // VPN/network state is handled by transport/security policy rather than
      // media licensing policy.
      'vpnChangesMediaAvailability': false,
      'vpnCanChangeCatalog': false,
      'vpnCanGrantMediaAccess': false,

      // Physical disc region is retained as provenance metadata only.
      'discRegionIsMetadataOnly': true,
      'discRegionIsLicensingGeofence': false,
      'discRegionCanDenyAccess': false,

      // The actual authorization layer remains responsible for authenticated
      // account/profile access decisions.
      'authorizationRequiresAuthenticatedAccess': true,

      if (media != null) ...{
        'discRegion': media.discRegion,
        'mediaId': media.id,
        'mediaType': media.type,
        'isBonusContent': media.isBonusContent,
        'physicalReleaseId': media.physicalReleaseId,
        'physicalDiscId': media.physicalDiscId,
        'discContentId': media.discContentId,
      },
    };
  }
}