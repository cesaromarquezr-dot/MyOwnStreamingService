// FILE: `Backend/services/media_access_policy.dart`.
// Purpose: Defines the application's personal-media availability contract.
// This policy deliberately separates security telemetry from content availability.

import '../models/media.dart';

/// Performs media-availability policy decisions without applying IP-country
/// or VPN-based catalog geoblocking.
class MediaAccessPolicy {
  /// Returns true when a media item's region metadata is informational only.
  ///
  /// `discRegion` describes the physical disc/release source and is never a
  /// licensing geofence in this personal-media application.
  bool discRegionIsMetadataOnly(Media media) {
    return true;
  }

  /// Returns whether a VPN/network change is allowed to alter catalog access.
  ///
  /// A VPN is a transport/security mechanism, not a media licensing rule.
  bool vpnCanChangeCatalog() => false;

  /// Returns the policy metadata that can be included in authenticated
  /// playback/access responses for diagnostics and future feature safety.
  Map<String, dynamic> toJson({Media? media}) {
    return {
      'geographicCatalogFiltering': false,
      'vpnChangesMediaAvailability': false,
      'discRegionIsLicensingGeofence': false,
      if (media != null) 'discRegion': media.discRegion,
    };
  }
}
