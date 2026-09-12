// FILE: `lib/roadmap_features.dart`.
// Purpose: Implements the roadmap features portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';
import 'feature_center.dart';
import 'ultimate_features.dart';
import 'device_features.dart';
import 'remote_access.dart';
import 'main.dart' show CustomizeHomeScreen;
import 'details.dart';
import 'sports.dart';
import 'platform_expansion.dart';
import 'music.dart';
import 'reviews.dart';
import 'home_server.dart';
import 'storage_dashboard.dart';

class RoadmapFeaturesScreen extends StatelessWidget {
  const RoadmapFeaturesScreen({super.key});

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final features = <_RoadmapFeature>[
      _RoadmapFeature(1, 'Recommendation Voting', Icons.how_to_vote_rounded, 'Every normal profile can vote on every recommendation.', (_) => const RecommendationCompetitionScreen()),
      _RoadmapFeature(2, 'ListTile Layout Fix', Icons.view_list_rounded, 'Use constrained, scroll-safe list layouts across feature surfaces.', (_) => const RoadmapListLayoutScreen()),
      _RoadmapFeature(3, 'All Profiles Can Vote', Icons.groups_rounded, 'Recommendation eligibility includes every profile on the account.', (_) => const RecommendationCompetitionScreen()),
      _RoadmapFeature(4, 'One Vote Per Profile', Icons.rule_rounded, 'Duplicate votes are rejected and the current vote is shown.', (_) => const RecommendationCompetitionScreen()),
      _RoadmapFeature(5, 'Wishlist Behavior', Icons.favorite_border_rounded, 'Approved recommendations flow into the shared wishlist.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(6, 'Per-Profile Navigation', Icons.navigation_rounded, 'Navigation order and placement are profile-specific.', (_) => const CustomizeHomeScreen()),
      _RoadmapFeature(7, 'Home Screen Builder', Icons.dashboard_customize_rounded, 'Reorder and show or hide Home sections.', (_) => const CustomizeHomeScreen()),
      _RoadmapFeature(8, 'Details Screen Builder', Icons.article_outlined, 'Per-profile Details section visibility and ordering.', (_) => const CustomizeHomeScreen()),
      _RoadmapFeature(9, 'Themes & Accent Colors', Icons.palette_outlined, 'Personal visual preferences for each profile.', (_) => const CustomizeHomeScreen()),
      _RoadmapFeature(10, 'Layout Presets', Icons.grid_view_rounded, 'Poster/card sizes and compact or spacious presentation.', (_) => const CustomizeHomeScreen()),
      _RoadmapFeature(11, 'Drag-and-Drop UI Builder', Icons.open_with_rounded, 'Reorder Home widgets and dashboard elements.', (_) => const HomeWidgetsScreen()),
      _RoadmapFeature(12, 'Smart Recommendations', Icons.auto_awesome_rounded, 'Use watch behavior, metadata and profile signals.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(13, 'Smart Collections', Icons.auto_awesome_mosaic_rounded, 'Dynamic collections based on live library rules.', (_) => const SmartCollectionsScreen()),
      _RoadmapFeature(14, 'Advanced Search', Icons.manage_search_rounded, 'Search title, actor, director, genre, tags, year and watched state.', (_) => const AdvancedLibrarySearchScreen()),
      _RoadmapFeature(15, 'Actor & Franchise Pages', Icons.theaters_rounded, 'Explore catalog actors and related titles.', (_) => const ActorFranchiseRoadmapScreen()),
      _RoadmapFeature(16, 'Trailer Theater', Icons.movie_filter_rounded, 'Browse imported trailers as a dedicated theater.', (_) => const TrailerTheaterScreen()),
      _RoadmapFeature(17, 'Music Mode', Icons.music_note_rounded, 'Browse soundtrack and music metadata from your library.', (_) => const MusicModeScreen()),
      _RoadmapFeature(18, 'Recommendation Competition', Icons.emoji_events_rounded, 'Rank recommendations and identify the weekly winner.', (_) => const RecommendationCompetitionScreen()),
      _RoadmapFeature(19, 'Achievements', Icons.workspace_premium_rounded, 'Watching, voting and collection milestones.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(20, 'Personal Statistics', Icons.insights_rounded, 'Watching totals, genres, streaks and recaps.', (_) => const StatisticsScreen()),
      _RoadmapFeature(21, 'Reactions', Icons.favorite_rounded, 'Love, funny, scary, emotional and mind-blowing reactions.', (_) => const ReactionGuideScreen()),
      _RoadmapFeature(22, 'Watch Together 2.0', Icons.groups_rounded, 'Synchronized group watching, chat and host controls.', (_) => const GroupWatchRoadmapScreen()),
      _RoadmapFeature(23, 'Activity Center', Icons.notifications_active_outlined, 'Watching, recommendations, imports and party activity.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(24, 'ARM Disc Intelligence', Icons.album_rounded, 'Detect, extract, identify, enrich, review and approve discs.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(25, 'ARM Metadata', Icons.fact_check_outlined, 'Catalog resolution, codecs, audio, subtitles, chapters and extras.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(26, 'Poster & Trailer Fallbacks', Icons.image_search_rounded, 'Manual URLs remain available when a disc lacks artwork or trailer data.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(27, 'Audio / Subtitle / Chapters / Extras', Icons.closed_caption_rounded, 'Expose imported disc metadata throughout Details.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(28, 'Manual Library Approval', Icons.verified_outlined, 'ARM stops at Review and requires Add to Library.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(29, 'Real Email', Icons.email_outlined, 'Account email flows are ready for real provider integration.', (_) => const SecurityCenterScreen()),
      _RoadmapFeature(30, 'Verification', Icons.mark_email_read_outlined, 'Verification and security challenge surfaces.', (_) => const SecurityCenterScreen()),
      _RoadmapFeature(31, 'Suspicious Login Protection', Icons.gpp_maybe_rounded, 'Security-question challenge before access is granted.', (_) => const SecurityCenterScreen()),
      _RoadmapFeature(32, 'Device Management', Icons.devices_rounded, 'Trusted devices, pairing and device access controls.', (_) => const DeviceCenterScreen()),
      _RoadmapFeature(33, 'Remote Access', Icons.public_rounded, 'Trusted remote computers and remote imports.', (_) => const RemoteAccessScreen()),
      _RoadmapFeature(34, 'Backup & Restore', Icons.backup_rounded, 'Backup and recovery controls for account and library state.', (_) => const BackupScreen()),
      _RoadmapFeature(35, 'Global Live Sports Hub', Icons.sports_rounded, 'Global live sports discovery with sport, country, competition and game hierarchy.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(36, 'International Sports Search', Icons.public_rounded, 'Filter live games by sport and country.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(37, 'Live Game Detection', Icons.sensors_rounded, 'Detect games currently live and refresh their state.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(38, 'Live Sports Multiview', Icons.dashboard_rounded, 'Architecture for multiple authorized live games at once.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(39, 'Global Soccer Center', Icons.sports_soccer_rounded, 'International soccer leagues and competitions.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(40, 'Global Basketball Center', Icons.sports_basketball_rounded, 'International basketball leagues and competitions.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(41, 'Global Hockey Center', Icons.sports_hockey_rounded, 'International hockey games and competitions.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(42, 'Global Baseball Center', Icons.sports_baseball_rounded, 'International baseball games and competitions.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(43, 'Global American Football Center', Icons.sports_football_rounded, 'NFL and international American football coverage.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(44, 'Tennis & Motorsport Center', Icons.sports_motorsports_rounded, 'Tennis, racing and motorsport discovery.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(45, 'Live Scores & Play-by-Play', Icons.scoreboard_rounded, 'Live scores and event data alongside authorized broadcasts.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(46, 'Team Pages & Follow Teams', Icons.groups_rounded, 'Follow teams and open their live and upcoming games.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(47, 'Sports Notifications', Icons.notifications_active_rounded, 'Notify profiles when followed games go live.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(48, 'Game Replay & Condensed Game', Icons.replay_rounded, 'Replay and condensed-game surfaces when licensed.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(49, 'Alternate Broadcasts & Audio', Icons.headset_rounded, 'Select among authorized original and alternate broadcast feeds.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(50, 'Major Event Mode', Icons.emoji_events_rounded, 'Pregame, live event, halftime and postgame experiences when licensed.', (_) => const LiveSportsScreen()),
      _RoadmapFeature(51, 'ARM Canonical Title Resolution', Icons.language_rounded, 'Resolve localized disc titles to the canonical/original movie while preserving disc title, market and raw ARM region.', (_) => const UltimateFeaturesScreen()),
      _RoadmapFeature(52, 'Recommendation Feedback', Icons.feedback_outlined, 'Improve recommendations from explicit feedback.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(53, 'Recommendation Diversity', Icons.shuffle_rounded, 'Prevent recommendation feeds from becoming repetitive.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(54, 'Similar Titles', Icons.compare_arrows_rounded, 'Find titles similar to the current selection.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(55, 'Because You Watched', Icons.history_toggle_off_rounded, 'Generate recommendations from recent viewing.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(56, 'Continue Watching Intelligence', Icons.play_circle_outline_rounded, 'Prioritize unfinished titles and episodes intelligently.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(57, 'Franchise Progress', Icons.linear_scale_rounded, 'Show progress through franchise collections.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(58, 'Collection Completion', Icons.check_circle_outline_rounded, 'Track which franchise collections are complete.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(59, 'Collaborative Collections', Icons.group_work_rounded, 'Allow permitted profiles to contribute to shared collections.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(60, 'Collection Permissions', Icons.admin_panel_settings_outlined, 'Control who can view, add, remove or edit collections.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(61, 'Collection Posters', Icons.image_outlined, 'Build collection artwork from member posters.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(62, 'Collection Favorites', Icons.favorite_border_rounded, 'Like collections and surface favorites quickly.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(63, 'Collection Manual Ordering', Icons.reorder_rounded, 'Manually arrange titles inside a collection.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(64, 'Collection Release Order', Icons.sort_rounded, 'Automatically sort a collection by release order.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(65, 'Version Preference', Icons.movie_outlined, 'Prefer theatrical, extended, preferred or highest-quality versions.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(66, 'Auto Play Queue', Icons.queue_play_next_rounded, 'Build a playback queue from collection order.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(67, 'Credits Auto Advance', Icons.skip_next_rounded, 'Advance to the next eligible title around end credits.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(68, 'Episode Auto Advance', Icons.next_plan_rounded, 'Automatically continue to the next episode.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(69, 'Episode Progress', Icons.format_list_numbered_rounded, 'Track watched and partially watched episodes.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(70, 'Season Progress', Icons.playlist_play_rounded, 'Display completion progress for every season.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(71, 'Episode Ratings', Icons.star_border_rounded, 'Rate individual episodes independently.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(72, 'Watch-State Overrides', Icons.published_with_changes_rounded, 'Manually mark movies or episodes watched/unwatched.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(73, 'Duplicate Detection', Icons.content_copy_rounded, 'Detect duplicate library entries before approval.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(74, 'Metadata Conflict Review', Icons.difference_rounded, 'Compare conflicting metadata before saving.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(75, 'Metadata Locking', Icons.lock_outline_rounded, 'Protect manually corrected metadata from automatic replacement.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(76, 'Artwork Selection', Icons.photo_library_outlined, 'Choose among available posters and backdrops.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(77, 'Trailer Selection', Icons.ondemand_video_rounded, 'Choose the preferred trailer when multiple are available.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(78, 'Genre Management', Icons.category_outlined, 'Normalize and manage library genres.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(79, 'Tag Management', Icons.sell_outlined, 'Create and manage custom library tags.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(80, 'Actor Credits', Icons.person_search_rounded, 'Browse every library title associated with an actor.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(81, 'Director Credits', Icons.movie_creation_outlined, 'Browse every library title associated with a director.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(82, 'Writer Credits', Icons.edit_note_rounded, 'Browse every library title associated with a writer.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(83, 'Franchise Discovery', Icons.account_tree_rounded, 'Discover franchise relationships from imported metadata.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(84, 'Disc Title Review', Icons.fact_check_rounded, 'Review every detected ARM title before library approval.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(85, 'Disc Title Classification', Icons.label_important_outline_rounded, 'Classify films, extras, episodes and alternate cuts.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(86, 'Disc Confidence Scores', Icons.verified_user_outlined, 'Show ARM metadata confidence during review.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(87, 'Disc Collection Linking', Icons.link_rounded, 'Link separate library titles to their physical disc.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(88, 'Multi-Title Disc Import', Icons.library_add_rounded, 'Import multiple distinct movies from one physical disc.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(89, 'Import Approval Queue', Icons.playlist_add_check_rounded, 'Review pending imports before they enter the library.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(90, 'Import Rejection', Icons.block_outlined, 'Reject incorrect or unwanted ARM results.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(91, 'Import Job History', Icons.history_rounded, 'Review previous ARM scan and import jobs.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(92, 'Import Cancellation', Icons.cancel_outlined, 'Cancel eligible ARM jobs safely.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(93, 'Audio Track Browser', Icons.graphic_eq_rounded, 'Inspect imported audio tracks.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(94, 'Subtitle Browser', Icons.subtitles_outlined, 'Inspect available subtitle tracks.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(95, 'Chapter Browser', Icons.menu_book_rounded, 'Browse imported chapters.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(96, 'Extras Browser', Icons.video_library_outlined, 'Browse extras and bonus content separately.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(97, 'Kids Profile Mode', Icons.child_care_rounded, 'Create a simplified profile experience for children.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(98, 'Content Age Filters', Icons.filter_alt_outlined, 'Filter content by configurable age ratings.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(99, 'Profile PIN', Icons.pin_outlined, 'Protect selected profile actions with a PIN.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(100, 'Kids Safe Collections', Icons.family_restroom_rounded, 'Restrict collections available to child profiles.', (_) => const FeatureCenterScreen()),
      _RoadmapFeature(101, 'Account Security Center', Icons.security_rounded, 'Profile-scoped 2FA, suspicious-login alerts, new-device approval and session controls.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(102, 'Playback Experience Controls', Icons.play_circle_fill_rounded, 'Profile-scoped resume, autoplay, preload, picture-in-picture and track preferences.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(103, 'TV Experience Controls', Icons.tv_rounded, 'Series-first autoplay, preserved intros, specials and unfinished-season behavior.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(104, 'Notification Controls', Icons.notifications_active_rounded, 'Per-profile alerts for episodes, recommendations, sports and security events.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(105, 'Backup & Migration Controls', Icons.backup_rounded, 'Profile-scoped backup manifest coverage for settings, watch state, collections and layouts.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(106, 'Library Intelligence Controls', Icons.auto_awesome_rounded, 'Tune smart recommendations, diversity, explanations and franchise progress.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(107, 'Search & Discovery Controls', Icons.manage_search_rounded, 'Enable natural-language, localized-title, actor and crew discovery.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(108, 'Collection Studio Controls', Icons.collections_bookmark_rounded, 'Configure collection autoplay, release order, quality preference and credit advance.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(109, 'Live Sports Profile Controls', Icons.sports_soccer_rounded, 'Per-profile Home visibility, live-only behavior, alerts and multiview settings.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(110, 'Privacy & Profile Controls', Icons.privacy_tip_rounded, 'Control activity, reactions, watch-history sharing and profile PIN protection.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(111, 'Kids Safety Controls', Icons.child_care_rounded, 'Kids mode, age filters, safe collections and mature-content PIN protection.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(112, 'Performance Controls', Icons.speed_rounded, 'Tune animations, artwork preloading, reduced motion and fast Home mode.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(113, 'Legacy Movie Safety Review', Icons.history_edu_rounded, 'Apply extra kids-safety review to older movies whose historical ratings may not reflect modern parental expectations.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(114, 'Nudity Safety Detection', Icons.visibility_off_rounded, 'Flag nudity and partial nudity independently of the official age rating.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(115, 'Sexual Content Detection', Icons.no_adult_content_rounded, 'Flag sexual content, sexualized imagery and suggestive material for child profiles.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(116, 'Violence & Gore Safety', Icons.warning_amber_rounded, 'Apply additional violence and gore safeguards beyond the official rating.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(117, 'Profanity Safety', Icons.record_voice_over_rounded, 'Use profanity metadata as an independent kids-safety signal.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(118, 'Substance Use Safety', Icons.smoke_free_rounded, 'Flag alcohol, drugs and smoking independently of the official rating.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(119, 'Disturbing Content Safety', Icons.warning_rounded, 'Flag horror, frightening scenes and disturbing imagery for child profiles.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(120, 'Suggestive Themes Safety', Icons.forum_rounded, 'Flag mature jokes, suggestive dialogue and adult themes.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(121, 'Parent Content Warnings', Icons.info_outline_rounded, 'Show detected content categories to a parent before playback.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(122, 'Incomplete Metadata Protection', Icons.help_outline_rounded, 'Require parent review when content-safety metadata is missing or uncertain.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(123, 'Disc Rating Comparison', Icons.album_rounded, 'Compare the physical DVD/Blu-ray packaging rating with current catalog metadata.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(124, 'Parent Approval Queue', Icons.approval_rounded, 'Hold flagged child-profile titles for explicit parent approval.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(125, 'Per-Title Kids Overrides', Icons.rule_rounded, 'Allow a parent to approve or block individual titles regardless of general rules.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(126, 'Multi-Signal Kids Safety', Icons.shield_rounded, 'Combine age rating, content descriptors, legacy status, metadata confidence and parent rules instead of relying on a single rating.', (_) => const PlatformExpansionScreen()),
      _RoadmapFeature(127, 'Music Home', Icons.music_note_rounded, 'Dedicated Music home with artists, bands, albums and songs.', (_) => const MusicScreen()),
      _RoadmapFeature(128, 'Custom Music Playlists', Icons.queue_music_rounded, 'Create, delete and curate profile playlists.', (_) => const MusicScreen()),
      _RoadmapFeature(129, 'Background Music Player', Icons.headphones_rounded, 'Keep music playing while browsing and resume it after movie/TV playback.', (_) => const MusicScreen()),
      _RoadmapFeature(130, 'Music Visual Customization', Icons.palette_outlined, 'Customize music home and navigation colors, glow and item styling.', (_) => const MusicScreen()),
      _RoadmapFeature(131, 'Guess the Song', Icons.quiz_rounded, 'Music guessing game based on songs and soundtracks.', (_) => const MusicScreen()),
      _RoadmapFeature(132, 'Soundtrack Universe', Icons.album_rounded, 'Connect movies, shows, albums and songs into soundtrack experiences.', (_) => const MusicScreen()),
      _RoadmapFeature(133, 'Music Statistics', Icons.bar_chart_rounded, 'Track music songs, playlists and listening alongside movie/TV statistics.', (_) => const StatisticsScreen()),
      _RoadmapFeature(134, 'Music Achievements & Badges', Icons.emoji_events_rounded, 'Badges such as Cultured, Swiftie and Album Collector.', (_) => const MusicAchievementsScreen()),
      _RoadmapFeature(135, 'Profile Reviews', Icons.rate_review_outlined, 'Rate titles from 0-10 with a custom review label and text.', (_) => const ReviewsHubScreen()),
      _RoadmapFeature(136, 'Global Privacy-Safe Reviews', Icons.public_rounded, 'Publish reviews under a custom username without exposing email or account identity.', (_) => const ReviewsHubScreen()),
      _RoadmapFeature(137, 'Official vs Viewer Ratings', Icons.star_half_rounded, 'Show provider/critic rating separately from the community 10-point rating.', (_) => const ReviewsHubScreen()),
      _RoadmapFeature(138, 'Review Translation Toggle', Icons.translate_rounded, 'Offer a translation-enabled global review view without exposing private identity.', (_) => const ReviewsHubScreen()),
      _RoadmapFeature(139, 'Home Server Dashboard', Icons.dns_rounded, 'Monitor the home server, media root and ARM connection.', (_) => const HomeServerScreen()),
      _RoadmapFeature(140, 'ARM Media Scanner', Icons.disc_full_rounded, 'Scan completed ARM media and synchronize discovered files into Flutter.', (_) => const HomeServerScreen()),
      _RoadmapFeature(141, 'Server Storage Dashboard', Icons.storage_rounded, 'Display Movies, Series, Music and available storage with hover details.', (_) => const StorageDashboardScreen()),
      _RoadmapFeature(142, 'Custom Storage Visualization', Icons.color_lens_rounded, 'Customize storage category colors and progress visualization.', (_) => const StorageDashboardScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('142-Feature Roadmap')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '142 planned and implemented platform features',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: features.length,
        itemBuilder: (context, index) {
          final f = features[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(child: Text('${f.number}')),
              title: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(f.description),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => f.builder(context))),
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadmapFeature {
  final int number;
  final String title;
  final IconData icon;
  final String description;
  final Widget Function(BuildContext) builder;
  _RoadmapFeature(this.number, this.title, this.icon, this.description, this.builder);
}

List<MediaItem> _library() => AppController.instance.library;

class AskMyLibraryScreen extends StatefulWidget {
  const AskMyLibraryScreen({super.key});
  @override State<AskMyLibraryScreen> createState() => _AskMyLibraryScreenState();
}
class _AskMyLibraryScreenState extends State<AskMyLibraryScreen> {
  final query = TextEditingController();
  List<MediaItem> results = <MediaItem>[];
  String explanation = 'Ask about titles, actors, genres, years, watched state or your next watch.';

  /// Performs `ask` for this feature. Update this documentation when its contract changes.
  void ask() {
    final q = query.text.trim().toLowerCase();
    var filtered = List<MediaItem>.from(_library());
    if (q.contains('unwatched')) filtered = filtered.where((m) => !AppController.instance.isWatched(m.id)).toList();
    if (q.contains('watched')) filtered = filtered.where((m) => AppController.instance.isWatched(m.id)).toList();
    if (q.contains('movie')) filtered = filtered.where((m) => m.type == 'movie').toList();
    if (q.contains('show') || q.contains('series') || q.contains('tv')) filtered = filtered.where((m) => m.type != 'movie').toList();
    final year = RegExp(r'\b(19|20)\d{2}\b').firstMatch(q)?.group(0);
    if (year != null) filtered = filtered.where((m) => m.releaseYear == int.tryParse(year)).toList();
    for (final genre in const ['action','comedy','drama','horror','romance','thriller','animation','sci-fi']) {
      if (q.contains(genre)) filtered = filtered.where((m) => m.genres.any((g) => g.toLowerCase().contains(genre))).toList();
    }
    setState(() {
      results = filtered;
      explanation = results.isEmpty ? 'No matching titles were found in this profile library.' : 'Found ${results.length} matching title${results.length == 1 ? '' : 's'} from your library metadata.';
    });
  }
  @override void dispose() { query.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ask My Library')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(controller: query, onSubmitted: (_) => ask(), decoration: InputDecoration(hintText: 'e.g. unwatched action movies from the 2000s', suffixIcon: IconButton(onPressed: ask, icon: const Icon(Icons.search)))),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: Text(explanation, style: const TextStyle(color: Colors.white70))),
        const SizedBox(height: 12),
        Expanded(child: ListView.builder(itemCount: results.length, itemBuilder: (_, i) {
          final m = results[i];
          return Card(child: ListTile(title: Text(m.title), subtitle: Text('${m.releaseYear ?? ''} • ${m.type}'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: m)))));
        })),
      ]),
    ),
  );
}

class SmartCollectionsScreen extends StatefulWidget { const SmartCollectionsScreen({super.key}); @override State<SmartCollectionsScreen> createState() => _SmartCollectionsScreenState(); }
class _SmartCollectionsScreenState extends State<SmartCollectionsScreen> {
  String rule = 'Unwatched';
  List<MediaItem> get items { final l = _library(); switch (rule) { case 'Watched': return l.where((m) => AppController.instance.isWatched(m.id)).toList(); case 'Movies': return l.where((m) => m.type == 'movie').toList(); case 'TV Shows': return l.where((m) => m.type != 'movie').toList(); case 'Liked': return l.where((m) => AppController.instance.liked.any((x) => x.id == m.id)).toList(); default: return l.where((m) => !AppController.instance.isWatched(m.id)).toList(); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Smart Collections')), body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [DropdownButtonFormField<String>(initialValue: rule, items: const ['Unwatched','Watched','Movies','TV Shows','Liked'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => rule = v!)), const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: Text('${items.length} titles match this live rule')), const SizedBox(height: 12), Expanded(child: ListView(children: items.map((m) => ListTile(leading: const Icon(Icons.movie_outlined), title: Text(m.title), subtitle: Text('${m.releaseYear ?? ''} • ${m.type}'))).toList()))])));
}

class RecommendationCompetitionScreen extends StatelessWidget {
  const RecommendationCompetitionScreen({super.key});
  @override Widget build(BuildContext context) {
    final recs = [...AppController.instance.groupRecommendations];
    recs.sort((a, b) => _yes(b).compareTo(_yes(a)));
    return Scaffold(appBar: AppBar(title: const Text('Recommendation Competition')), body: ListView(padding: const EdgeInsets.all(16), children: [
      if (recs.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No active recommendations yet.'))),
      ...recs.asMap().entries.map((entry) { final r = entry.value; return Card(child: ListTile(leading: CircleAvatar(child: Text('${entry.key + 1}')), title: Text(r['title']?.toString() ?? 'Untitled'), subtitle: Text('YES ${r['yesVotes'] ?? 0} • NO ${r['noVotes'] ?? 0}'), trailing: entry.key == 0 ? const Icon(Icons.emoji_events_rounded) : null)); }),
    ]));
  }
  static int _yes(Map<String, dynamic> r) => int.tryParse(r['yesVotes']?.toString() ?? '0') ?? 0;
}

class WatchHistoryTimelineScreen extends StatelessWidget {
  const WatchHistoryTimelineScreen({super.key});
  @override Widget build(BuildContext context) { final watched = AppController.instance.watched; return Scaffold(appBar: AppBar(title: const Text('Watch History')), body: watched.isEmpty ? const Center(child: Text('Nothing watched yet.')) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: watched.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (_, i) { final m = watched[watched.length - 1 - i]; return ListTile(leading: CircleAvatar(child: Text('${i + 1}')), title: Text(m.title), subtitle: Text('${m.releaseYear ?? ''} • Watched by ${AppController.instance.currentProfile?.name ?? 'profile'}')); })); }
}

class MusicModeScreen extends StatelessWidget {
  const MusicModeScreen({super.key});
  @override Widget build(BuildContext context) { final grouped = <String, List<String>>{}; for (final m in _library()) { for (final item in m.music) { grouped.putIfAbsent(m.title, () => <String>[]).add(item); } } return Scaffold(appBar: AppBar(title: const Text('Music Mode')), body: grouped.isEmpty ? const Center(child: Text('No music metadata has been imported yet.')) : ListView(padding: const EdgeInsets.all(16), children: grouped.entries.expand((e) => [Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(e.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), ...e.value.map((x) => ListTile(leading: const Icon(Icons.music_note_rounded), title: Text(x)))]).toList())); }
}

class TrailerTheaterScreen extends StatelessWidget {
  const TrailerTheaterScreen({super.key});
  @override Widget build(BuildContext context) { final media = _library().where((m) => (m.trailerUrl ?? '').trim().isNotEmpty).toList(); return Scaffold(appBar: AppBar(title: const Text('Trailer Theater')), body: media.isEmpty ? const Center(child: Text('No trailers are available.')) : GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .75), itemCount: media.length, itemBuilder: (_, i) { final m = media[i]; return Card(child: InkWell(onTap: () async { final uri = Uri.tryParse(m.trailerUrl!); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: m.imageUrl == null ? const Center(child: Icon(Icons.movie_rounded, size: 48)) : Image.network(m.imageUrl!, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.movie_rounded, size: 48)))), Padding(padding: const EdgeInsets.all(10), child: Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),]))); })); }
}

class HomeWidgetsScreen extends StatefulWidget { const HomeWidgetsScreen({super.key}); @override State<HomeWidgetsScreen> createState() => _HomeWidgetsScreenState(); }
class _HomeWidgetsScreenState extends State<HomeWidgetsScreen> { final widgets = <String>['Continue Watching','Wishlist','Watch Streak','Recommendations','Recently Added','Storage']; @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Home Widgets')), body: ReorderableListView.builder(padding: const EdgeInsets.all(16), itemCount: widgets.length, onReorderItem: (a, b) => setState(() { final item = widgets.removeAt(a); widgets.insert(b, item); }), itemBuilder: (_, i) => Card(key: ValueKey(widgets[i]), child: ListTile(leading: const Icon(Icons.drag_handle_rounded), title: Text(widgets[i]), trailing: const Icon(Icons.widgets_rounded))))); }

class ProfileRelationshipsScreen extends StatefulWidget { const ProfileRelationshipsScreen({super.key}); @override State<ProfileRelationshipsScreen> createState() => _ProfileRelationshipsScreenState(); }
class _ProfileRelationshipsScreenState extends State<ProfileRelationshipsScreen> { final permissions = <String, bool>{'Watch': true, 'Recommend': true, 'Vote': true, 'Wishlist': true, 'Customize UI': true}; @override Widget build(BuildContext context) { final profiles = AppController.instance.currentAccount?.profiles ?? <Profile>[]; return Scaffold(appBar: AppBar(title: const Text('Profile Relationships')), body: ListView(padding: const EdgeInsets.all(16), children: profiles.map((p) => Card(child: ExpansionTile(title: Text(p.name), subtitle: const Text('Optional permissions'), children: permissions.keys.map((k) => SwitchListTile(title: Text(k), value: permissions[k]!, onChanged: (v) => setState(() => permissions[k] = v))).toList()))).toList())); } }

class ReactionGuideScreen extends StatelessWidget { const ReactionGuideScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Reactions')), body: ListView(padding: const EdgeInsets.all(16), children: const [ListTile(leading: Text('❤️', style: TextStyle(fontSize: 26)), title: Text('Love it')), ListTile(leading: Text('🔥', style: TextStyle(fontSize: 26)), title: Text('Amazing')), ListTile(leading: Text('😂', style: TextStyle(fontSize: 26)), title: Text('Funny')), ListTile(leading: Text('😱', style: TextStyle(fontSize: 26)), title: Text('Scary')), ListTile(leading: Text('😭', style: TextStyle(fontSize: 26)), title: Text('Emotional')), ListTile(leading: Text('🤯', style: TextStyle(fontSize: 26)), title: Text('Mind-blowing'))])); }

class AdvancedLibrarySearchScreen extends StatefulWidget { const AdvancedLibrarySearchScreen({super.key}); @override State<AdvancedLibrarySearchScreen> createState() => _AdvancedLibrarySearchScreenState(); }
class _AdvancedLibrarySearchScreenState extends State<AdvancedLibrarySearchScreen> { final q = TextEditingController(); String type = 'All'; bool unwatched = false; List<MediaItem> results = <MediaItem>[]; void search() { final term = q.text.toLowerCase(); final all = _library(); setState(() => results = all.where((m) => (term.isEmpty || m.title.toLowerCase().contains(term) || m.genres.any((x) => x.toLowerCase().contains(term)) || m.tags.any((x) => x.toLowerCase().contains(term)) || m.actors.any((x) => x.toLowerCase().contains(term)) || m.directors.any((x) => x.toLowerCase().contains(term))) && (type == 'All' || (type == 'Movies' ? m.type == 'movie' : m.type != 'movie')) && (!unwatched || !AppController.instance.isWatched(m.id))).toList()); } @override void dispose() { q.dispose(); super.dispose(); } @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Advanced Search')), body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [TextField(controller: q, onSubmitted: (_) => search(), decoration: const InputDecoration(labelText: 'Title, actor, director, genre or tag')), Row(children: [Expanded(child: DropdownButton<String>(value: type, isExpanded: true, items: const ['All','Movies','TV Shows'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => type = v!))), Switch(value: unwatched, onChanged: (v) => setState(() => unwatched = v)), const Text('Unwatched'), IconButton(onPressed: search, icon: const Icon(Icons.search))]), Expanded(child: ListView(children: results.map((m) => ListTile(title: Text(m.title), subtitle: Text('${m.releaseYear ?? ''} • ${m.type}'))).toList()))]))); }

class ActorFranchiseRoadmapScreen extends StatelessWidget { const ActorFranchiseRoadmapScreen({super.key}); @override Widget build(BuildContext context) { final actors = _library().expand((m) => m.actors).toSet().toList(); return Scaffold(appBar: AppBar(title: const Text('Actors & Franchises')), body: ListView(padding: const EdgeInsets.all(16), children: [const Text('Actors in your library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...actors.map((a) => ListTile(leading: const Icon(Icons.person_outline_rounded), title: Text(a)))])); } }

class GroupWatchRoadmapScreen extends StatelessWidget { const GroupWatchRoadmapScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Watch Together 2.0')), body: const Center(child: Text('Use Group Watch from the Home screen to start a synchronized party.'))); }

class RoadmapListLayoutScreen extends StatelessWidget {
  const RoadmapListLayoutScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('List Layouts')),
    body: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => Card(
        child: ListTile(
          dense: i.isEven,
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(i.isEven ? 'Compact ListTile' : 'Spacious ListTile'),
          subtitle: const Text('Constrained inside a scrolling ListView to prevent overflow.'),
        ),
      ),
    ),
  );
}

class ArchitectureScreen extends StatelessWidget { const ArchitectureScreen({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Architecture')), body: ListView(padding: const EdgeInsets.all(20), children: const [Text('Account-scoped data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('Library, subscription and shared media belong to the account.', style: TextStyle(color: Colors.white70)), SizedBox(height: 20), Text('Profile-scoped experience', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('Navigation, Home layout, Details layout, recommendations, history, wishlist and preferences belong to the selected profile.', style: TextStyle(color: Colors.white70)), SizedBox(height: 20), Text('Persistence boundary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('The local stores are isolated behind profile IDs so a Supabase repository can replace them without redesigning the UI.', style: TextStyle(color: Colors.white70))])); }
