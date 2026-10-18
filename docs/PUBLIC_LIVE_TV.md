# Public Live TV

## What it adds

Public Live TV is separate from My TV:

- **My TV** schedules a personalized channel from media in the user's own library.
- **Public Live TV** loads public M3U channel listings from the `iptv-org/iptv` directory and attempts to play individual network streams in the app.

Users can browse by country (Mexico is the initial selection), choose a genre/category playlist, search channel names and metadata, filter by directory group, save profile-scoped favorites, refresh a playlist, and retry a failing stream. The page also provides a copied playlist URL that can be pasted into VLC's **Media → Open Network Stream** workflow.

## Public playlist endpoints used

- Master playlist: `https://iptv-org.github.io/iptv/index.m3u`
- Country playlists: `https://iptv-org.github.io/iptv/countries/<country-code>.m3u`
- Category playlists: `https://iptv-org.github.io/iptv/categories/<category>.m3u`
- Directory project: `https://github.com/iptv-org/iptv`
- VLC official download page: `https://www.videolan.org/vlc/`

The app fetches the playlist at runtime, so the channel list can change without a release. Country and category playlists are used by default rather than fetching the global master list. The worldwide option can still be significantly larger and slower. Favorites are stored locally per profile on this device; their keys use channel name/group/host metadata rather than retaining the full URL query string, which can sometimes contain a short-lived token. Favorites are not synced across devices.

## Playback expectations

The app uses Flutter's existing `video_player` dependency to attempt direct playback. Native playback commonly supports HLS streams, but supported formats depend on the device/player implementation. A directory entry is not a guarantee that the stream is live, reachable, legal to view in every region, or playable in every client. Some streams will be down, blocked, or unsupported. The app does not rebroadcast, host, decrypt, or bypass access controls for the channels.

In-app buffering is controlled by the native playback stack and is not changed by VLC preferences. For VLC only, users can test **Tools → Preferences → Show settings: All → Input / Codecs → Network caching** and try **3000–4000 ms** for unstable public streams. This may improve resilience at the cost of additional startup delay; it is not a universal fix.

## Safety and rights

The directory is an address book, not the broadcaster and not a rights guarantee. Prefer streams published by the broadcaster itself, follow local copyright and viewing restrictions, and do not use the feature to access premium content without authorization. Users should not add unknown executable files, player mods, or untrusted third-party players.

## Verification

A parser unit test covers M3U metadata, HTTP(S)-only URL handling, and duplicate elimination. This environment did not have the Flutter/Dart SDK available, so the test suite and analyzer could not be executed here. Real streaming must still be tested on target platforms and networks.

## VLC quick-start guide

1. Install VLC from the official [VideoLAN VLC page](https://www.videolan.org/vlc/). Avoid third-party installers and modified player builds.
2. In MyOwnStreamingService, open **Public Live TV**, select **By country** or **By category**, then choose a country or genre. The app starts with Mexico and News selected; users can change both.
3. Select **Copy playlist for VLC**. Open VLC and choose **Media → Open Network Stream** (Ctrl+N on Windows/Linux; Cmd+N on macOS), paste the copied playlist URL, and press **Play**.
4. Open VLC's **View → Playlist** to browse channels. Double-click a channel to switch streams. If one fails, try another or refresh the playlist; public stream URLs can go offline or change without notice.
5. In MyOwnStreamingService, search channels, filter directory groups, and star favorites. Favorites are saved locally for the current profile. VLC's own playlist editing and saving are separate from the app's favorites.

### VLC buffering and troubleshooting

- If playback stutters, open **Tools → Preferences** (Ctrl+P), set **Show settings** to **All**, choose **Input / Codecs**, and try **Network caching** at **3000** or **4000 ms**. Save and restart VLC. This can reduce small network interruptions but increases startup delay and cannot fix a dead source, weak connection, or regional block.
- If video is black but audio works, check **Preferences → Video → Output** and try **Automatic**.
- If a playlist does not load, verify that the copied address is the raw `.m3u` playlist URL rather than a GitHub webpage URL, and check the network connection.
- If one channel stops working, refresh the playlist or try another entry. A directory is only a list of stream addresses; it cannot guarantee service uptime.

VLC caching preferences apply only to VLC. The in-app player uses the device's native playback stack and has separate buffering behavior. No application can guarantee that all public feeds will play smoothly on every network or device.
