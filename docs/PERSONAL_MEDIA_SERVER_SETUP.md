# MyOwnStreamingService Personal Media Server

## Purpose

The Personal Media Server page helps an account choose a host, a media-serving approach, basic library behavior, and a safe remote-access posture. It is intended to make self-hosting approachable without requiring a dedicated NAS on day one.

## Suggested rollout

1. **Start with existing hardware.** An old laptop or desktop can be a useful first host. Keep it patched, use a dedicated media folder, and plan for drive failure. A NAS can be added later for always-on storage and capacity.
2. **Choose the serving layer.** The built-in MyOwnStreamingService library is the in-product target. Jellyfin or Plex can provide a polished self-hosted catalogue, while DLNA is a simpler option for compatible televisions and players. Third-party installation and provider APIs are separate integrations.
3. **Organize the library.** Separate Movies, TV Shows, and Music. Use stable canonical media IDs and edition-aware metadata so duplicate titles and different releases do not collapse into one item.
4. **Test locally first.** Verify direct play, subtitles, audio tracks, seek/resume behavior, storage health, and backups before enabling remote access.
5. **Secure remote playback.** Prefer a private VPN or an authenticated HTTPS reverse proxy. Do not expose the raw application/backend port, NAS management UI, or storage credentials to the public internet. Use short-lived, scoped playback URLs from a trusted server-side gateway.

## Current implementation boundary

`lib/personal_media_server.dart` stores the user's selected host, playback-server preference, library-scan preference, transcoding preference, and remote-access posture in device-local SharedPreferences, scoped to the current profile when available. The Home Server screen links to this page.

Saving preferences does **not** install Plex/Jellyfin, configure a NAS, discover a server, enable remote access, or start a disc rip. Those actions require separately implemented and verified server-agent/provider integrations. The current home-server/ARM pipeline remains the actual import path.

## Copyright and disc import

Import and playback are intended for media the user is authorized to access. The application must not distribute pirated content or bypass DRM/access controls. Metadata, a barcode, or a disc title alone cannot prove authorization. Explicit trusted signals indicating unauthorized/counterfeit media should block import; uncertain cases should be held for review rather than represented as verified. Pre-rip prevention depends on the ARM worker enforcing the policy before extraction begins.

## Next integration milestones

- Add an authenticated server-agent capability probe for host health, storage, supported protocols, and available transcoding.
- Add a read-only library scan job with progress, cancellation, and duplicate reporting.
- Add provider-specific setup/health checks for Jellyfin, Plex, and DLNA rather than implying that a saved preference is a connection.
- Route all playback through authenticated server-side authorization and short-lived URLs; never put NAS credentials or filesystem paths in client-visible media records.
- Add automated tests for profile-scoped preference persistence and server-agent integration contracts.
