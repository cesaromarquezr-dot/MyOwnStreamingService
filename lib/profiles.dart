//at you can  FILE: `lib/profiles.dart`.
// Purpose: Implements the profiles portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'backend_api.dart';
import 'app_core.dart';
import 'music_achievements.dart';
import 'music.dart';
import 'profile_content_safety.dart';
import 'profile_administration.dart';
import 'localization.dart';
import 'profile_username.dart';
import 'artwork_selection_store.dart';
import 'core/services/cinematic_title_metadata_service.dart';
import 'energy_saver.dart';
import 'media_artwork_auto_resolver.dart';

class _AvatarOption {
  const _AvatarOption(this.label, {this.icon, this.symbol});

  final String label;
  final IconData? icon;
  final String? symbol;
}

const _avatarOptions = <_AvatarOption>[
  _AvatarOption('Person', icon: Icons.person),
  _AvatarOption('Face', icon: Icons.face),
  _AvatarOption('Star', icon: Icons.star),
  _AvatarOption('Heart', icon: Icons.favorite),
  _AvatarOption('Pet', icon: Icons.pets),
  _AvatarOption('Music', icon: Icons.music_note),
  _AvatarOption('Movie', icon: Icons.movie),
  _AvatarOption('Magic', icon: Icons.auto_awesome),
  _AvatarOption('Rocket', icon: Icons.rocket_launch),
  _AvatarOption('Smile', icon: Icons.emoji_emotions),
  _AvatarOption('World', icon: Icons.public),
  _AvatarOption('Web Hero', icon: Icons.web),
  _AvatarOption('Hero Alliance', icon: Icons.shield),
  _AvatarOption('Lightning Scar', icon: Icons.bolt),
  _AvatarOption('Mouse Ears', symbol: 'ears'),
  _AvatarOption('Light Saber', icon: Icons.flashlight_on),
  _AvatarOption('T-Rex', icon: Icons.pets),
  _AvatarOption('Pirate', icon: Icons.sailing),
  _AvatarOption('Monster G', symbol: 'G'),
  _AvatarOption('Agent 007', symbol: '007'),
];

int? _avatarIndexFromValue(String? value) {
  if (value == null || !value.startsWith('avatar:')) return null;
  final index = int.tryParse(value.substring('avatar:'.length));
  return index != null && index >= 0 && index < _avatarOptions.length
      ? index
      : null;
}


/// One image owned by a movie, show, or album that can be used as a profile picture.
class _ProfileMediaArtworkOption {
  const _ProfileMediaArtworkOption({
    required this.title,
    required this.kind,
    required this.imageSource,
    required this.identity,
  });

  final String title;
  final String kind;
  final String imageSource;
  final String identity;
}

String? _profileArtworkSource(String? raw, {String tmdbSize = 'w500'}) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  if (value.startsWith('https://') || value.startsWith('http://') ||
      value.startsWith('file://')) {
    return value;
  }
  // Keep a real local artwork file usable on this device, matching the
  // existing profile-photo behavior. Remote profile sync works best with URLs.
  try {
    if (File(value).existsSync()) return value;
  } catch (_) {
    // Invalid paths fall through to TMDB-path normalization below.
  }
  if (value.startsWith('/')) {
    return CinematicTitleMetadataService.imageUrl(value, size: tmdbSize);
  }
  return null;
}

bool _isRemoteProfileArtwork(String? value) {
  final source = value?.trim() ?? '';
  return source.startsWith('https://') || source.startsWith('http://');
}

/// ============================================================
/// PROFILE SELECTION SCREEN
/// ============================================================

class ProfileSelectionScreen extends StatefulWidget {
  final void Function(BuildContext context)? onProfileSelected;
  final VoidCallback? onOpened;

  const ProfileSelectionScreen({
    super.key,
    this.onProfileSelected,
    this.onOpened,
  });

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  int? _selectedBackdropIndex;
  List<_ProfileBackdropItem>? _cachedProfileBackdropItems;
  bool _contentRebuildScheduled = false;

  void _onContentChanged() {
    _cachedProfileBackdropItems = null;
    if (!mounted || _contentRebuildScheduled) return;
    // Library notifications can arrive while Flutter is building the profile
    // surface. Coalesce them into a post-frame rebuild instead of attempting
    // to mark a widget dirty from inside that build.
    _contentRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentRebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override

  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    AppController.instance.addListener(_onContentChanged);
    MusicLibraryStore.instance.addListener(_onContentChanged);
    // Defer the parent callback until after the first frame. The callback often
    // changes global navigation state; calling it synchronously from initState
    // can make an ancestor rebuild while it is still building this route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onOpened?.call();
      // Warm movie/show/album artwork after the profile surface has completed
      // its first build, without blocking the initial frame.
      for (final item in _profileBackdropItems()) {
        unawaited(
          precacheImage(NetworkImage(item.imageUrl), context)
              .catchError((_) {}),
        );
      }
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _animationController.forward();
  }

  @override

  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    AppController.instance.removeListener(_onContentChanged);
    MusicLibraryStore.instance.removeListener(_onContentChanged);
    _animationController.dispose();
    super.dispose();
  }

  /// Performs `_createProfile` for this feature. Update this documentation when its contract changes.
  Future<void> _createProfile() async {
    final controller = AppController.instance;
    final existingIds = (controller.currentAccount?.profiles ?? <Profile>[])
        .map((profile) => profile.id)
        .toSet();
    final returnedProfile = await showModalBottomSheet<Profile?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => const CreateProfileSheet(),
    );

    if (!mounted) return;
    setState(() {});

    // Prefer the exact profile returned by the save operation. The ID-diff
    // fallback supports older persisted profile creation responses.
    final profiles = controller.currentAccount?.profiles ?? <Profile>[];
    Profile? createdProfile = returnedProfile;
    if (createdProfile == null) {
      for (final profile in profiles.reversed) {
        if (!existingIds.contains(profile.id)) {
          createdProfile = profile;
          break;
        }
      }
    }
    if (createdProfile == null) return;

    // Saving a profile must not activate it or leave profile selection. The
    // user explicitly chooses which profile to enter after creation.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Profile "${createdProfile.name}" saved. Select a profile to continue.'),
        ),
      );
      setState(() {});
    }
  }

  /// Performs `_editProfile` for this feature. Update this documentation when its contract changes.
  Future<void> _editProfile(Profile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => EditProfileSheet(profile: profile),
    );

    if (!mounted) return;

    setState(() {});
  }

  /// Performs `_showStatistics` for this feature. Update this documentation when its contract changes.
  Future<void> _showStatistics(Profile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => ProfileStatisticsSheet(profile: profile),
    );

    if (!mounted) return;
  }

  /// Opens the unified Music, Movies, and Shows achievements for a profile.
  void _showAchievements(Profile profile) {
    AppController.instance.switchProfile(profile.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AchievementsScreen()),
    );
  }

  /// Performs `_selectProfile` for this feature. Update this documentation when its contract changes.
  Future<void> _selectProfile(Profile profile) async {
    final controller = AppController.instance;
    final previousProfile = controller.currentProfile;
    if (previousProfile != null &&
        previousProfile.id != profile.id &&
        controller.backendApi.isAuthenticated) {
      // Mark the profile we are leaving away before switching identities. This
      // prevents the Home activity strip from showing a stale green glow for
      // the old profile after the selection handoff.
      try {
        await controller.backendApi
            .setSocialProfilePresence(
              profileId: previousProfile.id,
              availability: 'away',
              clearActivity: true,
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // Presence must never prevent a profile from opening.
      }
    }
    controller.switchProfile(profile.id);
    if (controller.backendApi.isAuthenticated) {
      // The chosen profile is now the active app identity. Start a fresh
      // presence record without carrying over an old activity from its prior
      // session; playback can publish its own activity as it starts.
      unawaited(
        controller.backendApi
            .setSocialProfilePresence(
              profileId: profile.id,
              availability: 'active',
              clearActivity: true,
            )
            .then<void>((_) {}, onError: (_) {}),
      );
    }

    // Device registration is deliberately non-blocking. A selected profile is
    // enough to open Home; a slow/offline backend must not make selection look
    // like it did nothing.
    unawaited(controller.activateProfile(profile.id).catchError((_) {}));
    unawaited(
        LanguageController.instance.loadForCurrentProfile().catchError((_) {}));
    if (!mounted) return;
    _finishProfileSelection(context);
  }

  /// Performs `_finishProfileSelection` for this feature. Update this documentation when its contract changes.
  void _finishProfileSelection(BuildContext context) {
    if (widget.onProfileSelected != null) {
      widget.onProfileSelected!(context);
      return;
    }

    Navigator.of(context).pop(AppController.instance.currentProfile);
  }

  List<_ProfileBackdropItem> _profileBackdropItems() {
    final cached = _cachedProfileBackdropItems;
    if (cached != null) return cached;
    final items = <_ProfileBackdropItem>[];
    final seenUrls = <String>{};
    final controller = AppController.instance;

    for (final media in controller.library) {
      final type = media.type.trim().toLowerCase();
      final isScreenMedia = type.contains('movie') ||
          type.contains('show') ||
          type.contains('series') ||
          type == 'tv' ||
          type.contains('television');
      final url = (media.imageUrl ?? '').trim();
      if (!isScreenMedia || !_isUsableArtworkUrl(url) || !seenUrls.add(url)) {
        continue;
      }
      items.add(_ProfileBackdropItem(
        title: media.title,
        type: type.contains('movie') ? 'MOVIE' : 'SERIES',
        imageUrl: url,
      ));
    }

    for (final track in MusicLibraryStore.instance.tracks) {
      final url = (track.artworkUrl ?? '').trim();
      if (!_isUsableArtworkUrl(url) || !seenUrls.add(url)) continue;
      items.add(_ProfileBackdropItem(
        title: track.album.trim().isEmpty ? track.title : track.album,
        type: 'ALBUM',
        imageUrl: url,
      ));
    }

    // Mix movies, series and albums instead of showing long type-grouped runs.
    // Cache the shuffle so tapping a tile never changes which artwork its
    // selected index refers to during a normal rebuild.
    items.shuffle();
    _cachedProfileBackdropItems = List<_ProfileBackdropItem>.unmodifiable(items);
    return _cachedProfileBackdropItems!;
  }

  bool _isUsableArtworkUrl(String url) =>
      url.startsWith('https://') || url.startsWith('http://');

  Widget _buildArtworkSlider(
    List<_ProfileBackdropItem> artwork, {
    required double height,
    required double cardWidth,
  }) {
    final visibleCount = artwork.length;
    if (visibleCount == 0) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        itemCount: visibleCount,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = artwork[index];
          final selected = _selectedBackdropIndex == index;
          return SizedBox(
            width: cardWidth,
            child: Semantics(
              button: true,
              selected: selected,
              label: 'Show ${item.title} as the profile selection backdrop',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => setState(() => _selectedBackdropIndex = index),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? Colors.white : Colors.white24,
                        width: selected ? 2.5 : 1,
                      ),
                      boxShadow: selected
                          ? const <BoxShadow>[
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ]
                          : const <BoxShadow>[],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: const Color(0xFF080808),
                            child: Image.network(
                              item.imageUrl,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: Colors.black),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.black.withValues(alpha: .12),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: .92),
                                ],
                                stops: const <double>[0, .35, 1],
                              ),
                            ),
                          ),
                          if (selected)
                            const Positioned(
                              top: 8,
                              right: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 15,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 9,
                            right: 8,
                            bottom: 9,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  item.type,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    height: 1.15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCinematicLayout(
    BuildContext context,
    List<Profile> profiles,
    List<_ProfileBackdropItem> artwork,
  ) {
    final size = MediaQuery.sizeOf(context);
    final railWidth = (size.width * 0.29).clamp(270.0, 360.0).toDouble();
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeInOutCubic,
          width: railWidth,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            border: Border(
                right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ProfileLogo(),
                  const SizedBox(height: 30),
                  const UniversalText("Who's watching?",
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                  const SizedBox(height: 6),
                  Text('Choose a profile to continue',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.58),
                      )),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: [
                        for (final profile in profiles)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ProfileCard(
                              profile: profile,
                              compact: true,
                              onTap: () => _selectProfile(profile),
                              onEdit: () => _editProfile(profile),
                              onStatistics: () => _showStatistics(profile),
                              onAchievements: () => _showAchievements(profile),
                            ),
                          ),
                        if (profiles.length < 7)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _CreateProfileButton(onTap: _createProfile),
                          ),
                      ],
                    ),
                  ),
                  Text('${profiles.length} of 7 profiles',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      )),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 26, 32, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  const Text('YOUR ENTERTAINMENT,\nREADY WHEN YOU ARE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 20)
                        ],
                      )),
                  const SizedBox(height: 10),
                  Text('Movies, series and albums from your library',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 14,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 12)
                        ],
                      )),
                  const Spacer(),
                  _buildArtworkSlider(
                    artwork,
                    height: (size.height * 0.29)
                        .clamp(150.0, 260.0)
                        .toDouble(),
                    cardWidth: (size.width * 0.105)
                        .clamp(94.0, 150.0)
                        .toDouble(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final account = controller.currentAccount;
    final profiles = account?.profiles ?? <Profile>[];
    final artwork = _profileBackdropItems();

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: Stack(
        children: [
          if (artwork.isNotEmpty)
            _ProfileBackdropArtwork(
              items: artwork,
              selectedIndex: _selectedBackdropIndex,
            )
          else
            const ColoredBox(color: Colors.black),
          if (artwork.isNotEmpty && MediaQuery.sizeOf(context).width < 760)
            const ColoredBox(color: Color(0x99000000)),
          if (artwork.isNotEmpty && MediaQuery.sizeOf(context).width >= 760)
            _buildCinematicLayout(context, profiles, artwork)
          else
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 48,
                  ),
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final animation = CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.easeOutCubic,
                      );

                      return Opacity(
                        opacity: animation.value,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            30 * (1 - animation.value),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 1100,
                      ),
                      child: Column(
                        children: [
                          const _ProfileLogo(),
                          const SizedBox(height: 42),
                          const UniversalText(
                            "Who's watching?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          UniversalText(
                            'Choose a profile to continue',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          if (artwork.isNotEmpty) ...<Widget>[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _selectedBackdropIndex == null
                                    ? 'Choose artwork to preview the backdrop'
                                    : 'Backdrop preview: ${artwork[_selectedBackdropIndex!.clamp(0, artwork.length - 1).toInt()].title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .78),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            _buildArtworkSlider(
                              artwork,
                              height: 148,
                              cardWidth: (MediaQuery.sizeOf(context).width * .25)
                                  .clamp(90.0, 124.0)
                                  .toDouble(),
                            ),
                            const SizedBox(height: 26),
                          ] else
                            const SizedBox(height: 16),
                          if (profiles.isEmpty)
                            const _NoProfiles()
                          else
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 30,
                              runSpacing: 34,
                              children: [
                                ...profiles.map(
                                  (profile) => _ProfileCard(
                                    profile: profile,
                                    onTap: () {
                                      _selectProfile(profile);
                                    },
                                    onEdit: () {
                                      _editProfile(profile);
                                    },
                                    onStatistics: () {
                                      _showStatistics(profile);
                                    },
                                    onAchievements: () {
                                      _showAchievements(profile);
                                    },
                                  ),
                                ),
                                if (profiles.length < 7)
                                  _CreateProfileCard(
                                    onTap: _createProfile,
                                  ),
                              ],
                            ),
                          if (profiles.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 26,
                              ),
                              child: _CreateProfileButton(
                                onTap: _createProfile,
                              ),
                            ),
                          const SizedBox(height: 50),
                          UniversalText(
                            '${profiles.length} '
                            '${profiles.length == 1 ? 'profile' : 'profiles'}'
                            ' • Maximum 7',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ============================================================
/// PROFILE CARD
/// ============================================================

class _ProfileCard extends StatefulWidget {
  final Profile profile;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onStatistics;
  final VoidCallback onAchievements;
  final bool compact;

  const _ProfileCard({
    required this.profile,
    required this.onTap,
    required this.onEdit,
    required this.onStatistics,
    required this.onAchievements,
    this.compact = false,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _hovered = false;
  bool _pressed = false;

  /// Performs `_showProfileMenu` for this feature. Update this documentation when its contract changes.
  void _showProfileMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * .88;
        return Container(
          padding: const EdgeInsets.fromLTRB(
            22,
            12,
            22,
            28,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF151515),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _ProfileMenuButton(
                      icon: Icons.play_circle_outline,
                      title: tr('Use this profile'),
                      subtitle: 'Start watching as ${widget.profile.name}',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onTap();
                      },
                    ),
                    const SizedBox(height: 10),
                    _ProfileMenuButton(
                      icon: Icons.edit_outlined,
                      title: tr('Edit Profile'),
                      subtitle: tr('Change name or profile picture'),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onEdit();
                      },
                    ),
                    const SizedBox(height: 10),
                    _ProfileMenuButton(
                      icon: Icons.bar_chart_rounded,
                      title: tr('See Statistics'),
                      subtitle: tr("View this profile's watching activity"),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onStatistics();
                      },
                    ),
                    const SizedBox(height: 10),
                    _ProfileMenuButton(
                      icon: Icons.emoji_events_outlined,
                      title: tr('Achievements'),
                      subtitle: tr('View Music, Movies and Shows achievements'),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onAchievements();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    if (widget.compact) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : (_hovered ? 1.025 : 1),
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onTap,
              onLongPress: _showProfileMenu,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  children: [
                    _ProfileAvatar(profile: widget.profile, size: 62),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color:
                                      _hovered ? Colors.white : Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          if ((widget.profile.username).trim().isNotEmpty)
                            Text('@${widget.profile.username}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Manage profile',
                      onPressed: _showProfileMenu,
                      icon: const Icon(Icons.more_horiz, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
      },
      onExit: (_) {
        setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
        },
        onTapCancel: () {
          setState(() => _pressed = false);
        },
        onTap: widget.onTap,
        onLongPress: _showProfileMenu,
        child: AnimatedScale(
          scale: _pressed
              ? 0.94
              : _hovered
                  ? 1.045
                  : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 150,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 180,
                      ),
                      padding: EdgeInsets.all(
                        _hovered ? 2 : 0,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _hovered ? Colors.white38 : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: _ProfileAvatar(
                        profile: widget.profile,
                        size: 142,
                      ),
                    ),
                    Positioned(
                      right: -5,
                      top: -5,
                      child: AnimatedOpacity(
                        opacity: _hovered ? 1 : 0,
                        duration: const Duration(
                          milliseconds: 180,
                        ),
                        child: Material(
                          color: Colors.black.withValues(
                            alpha: 0.85,
                          ),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _showProfileMenu,
                            child: const Padding(
                              padding: EdgeInsets.all(9),
                              child: Icon(
                                Icons.more_horiz,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  widget.profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _hovered ? Colors.white : Colors.white70,
                  ),
                ),
                if ((widget.profile.username).trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '@${widget.profile.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
                const SizedBox(height: 7),
                AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: Colors.white54,
                      ),
                      SizedBox(width: 4),
                      UniversalText(
                        'Manage',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// PROFILE AVATAR
/// ============================================================

class _ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double size;

  const _ProfileAvatar({
    required this.profile,
    required this.size,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final avatarValue = profile.avatarUrl?.trim() ?? '';

    if (avatarValue.startsWith('avatar:')) {
      final index = _avatarIndexFromValue(avatarValue);
      if (index != null) {
        return _IconAvatar(
          option: _avatarOptions[index],
          size: size,
        );
      }
    }

    if (avatarValue.isNotEmpty) {
      final isNetwork = avatarValue.startsWith('http://') ||
          avatarValue.startsWith('https://');

      if (isNetwork) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(
            avatarValue,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return _FallbackAvatar(
                size: size,
                name: profile.name,
              );
            },
          ),
        );
      }

      final avatarUri = Uri.tryParse(avatarValue);
      final file = avatarUri?.scheme == 'file'
          ? File.fromUri(avatarUri!)
          : File(avatarValue);

      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return _FallbackAvatar(
                size: size,
                name: profile.name,
              );
            },
          ),
        );
      }
    }

    return _FallbackAvatar(
      size: size,
      name: profile.name,
    );
  }
}

/// ============================================================
/// ICON AVATAR
/// ============================================================

class _IconAvatar extends StatelessWidget {
  final _AvatarOption option;
  final double size;

  const _IconAvatar({
    required this.option,
    required this.size,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF343434),
            Color(0xFF151515),
          ],
        ),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      alignment: Alignment.center,
      child: option.symbol == 'ears'
          ? SizedBox(
              width: size * 0.54,
              height: size * 0.54,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: CircleAvatar(
                      radius: size * 0.14,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: CircleAvatar(
                      radius: size * 0.14,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: CircleAvatar(
                      radius: size * 0.19,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : option.symbol != null
              ? Text(
                  option.symbol!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * (option.symbol!.length > 1 ? 0.28 : 0.42),
                    fontWeight: FontWeight.w900,
                    letterSpacing: option.symbol == '007' ? -1 : 0,
                  ),
                )
              : Icon(
                  option.icon,
                  size: size * 0.38,
                  color: Colors.white,
                ),
    );
  }
}

/// ============================================================
/// FALLBACK AVATAR
/// ============================================================

class _FallbackAvatar extends StatelessWidget {
  final double size;
  final String name;

  const _FallbackAvatar({
    required this.size,
    required this.name,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final trimmedName = name.trim();

    final letter = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF343434),
            Color(0xFF151515),
          ],
        ),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// ============================================================
/// EDIT PROFILE SHEET
/// ============================================================

class EditProfileSheet extends StatefulWidget {
  final Profile profile;

  const EditProfileSheet({
    super.key,
    required this.profile,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;

  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedPhoto;
  int? _selectedAvatarIndex;
  String? _selectedMediaArtworkUrl;

  bool _saving = false;

  @override

  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.profile.name);
    _usernameController = TextEditingController(
      text: widget.profile.username,
    );
    _selectedAvatarIndex = _avatarIndexFromValue(widget.profile.avatarUrl);
    if (_selectedAvatarIndex == null &&
        _isRemoteProfileArtwork(widget.profile.avatarUrl)) {
      _selectedMediaArtworkUrl = widget.profile.avatarUrl!.trim();
    }
  }

  @override

  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  /// Performs `_takePhoto` for this feature. Update this documentation when its contract changes.
  Future<void> _takePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (photo == null || !mounted) return;

      setState(() {
        _selectedPhoto = photo;
        _selectedMediaArtworkUrl = null;
        _selectedAvatarIndex = null;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'Unable to take photo: $error',
          ),
        ),
      );
    }
  }

  /// Performs `_pickPhoto` for this feature. Update this documentation when its contract changes.
  Future<void> _pickPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (photo == null || !mounted) return;

      setState(() {
        _selectedPhoto = photo;
        _selectedMediaArtworkUrl = null;
        _selectedAvatarIndex = null;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'Unable to choose photo: $error',
          ),
        ),
      );
    }
  }

  /// Performs `_deleteProfile` for this feature. Update this documentation when its contract changes.
  Future<void> _deleteProfile() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const UniversalText('Delete profile?'),
            content: UniversalText(
              'Delete ${widget.profile.name}? '
              'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const UniversalText('CANCEL'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const UniversalText('DELETE'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() {
      _saving = true;
    });

    try {
      final controller = AppController.instance;

      if (controller.isBackendAuthenticated) {
        await controller.backendApi.removeProfile(
          widget.profile.id,
        );

        if (!mounted) return;
      }

      controller.removeProfile(widget.profile.id);

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText('Profile deleted.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ProfileUsername.userFacingError(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  /// Performs `_save` for this feature. Update this documentation when its contract changes.
  Future<void> _save() async {
    final name = _nameController.text.trim();
    final username = ProfileUsername.normalize(_usernameController.text);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'Please enter a profile name.',
          ),
        ),
      );
      return;
    }

    final usernameError = ProfileUsername.validationMessage(username);
    if (usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(usernameError)),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final avatarUrl = _selectedPhoto != null
          ? _selectedPhoto!.path
          : (_selectedMediaArtworkUrl?.trim().isNotEmpty == true)
              ? _selectedMediaArtworkUrl!.trim()
              : _selectedAvatarIndex == null
                  ? widget.profile.avatarUrl
                  : 'avatar:$_selectedAvatarIndex';

      final api = AppController.instance.backendApi;
      if (api.isAuthenticated) {
        await api.updateProfile(
          profileId: widget.profile.id,
          name: name,
          username: username,
          avatarUrl: avatarUrl,
        );
      }

      widget.profile.avatarUrl = avatarUrl;
      widget.profile.name = name;
      widget.profile.username = username;

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile "$name" updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ProfileUsername.userFacingError(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: const EdgeInsets.only(top: 50),
      padding: EdgeInsets.fromLTRB(
        26,
        18,
        26,
        26 + bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const UniversalText(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 7),
              UniversalText(
                'Update your profile information.',
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.55,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: _EditableProfileAvatar(
                  profile: widget.profile,
                  selectedPhoto: _selectedPhoto,
                  selectedAvatarIndex: _selectedAvatarIndex,
                  selectedMediaArtworkUrl: _selectedMediaArtworkUrl,
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  labelText: tr('Profile name'),
                  labelStyle: const TextStyle(
                    color: Colors.white60,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Colors.white54,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(
                    alpha: 0.06,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _usernameController,
                enabled: !_saving,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: 'Profile username',
                  prefixText: '@',
                  helperText: '3–32 letters, numbers, or underscores. Must be unique.',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const UniversalText(
                'Choose an avatar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              _AvatarOptionsGrid(
                selectedIndex: _selectedPhoto == null &&
                        _selectedMediaArtworkUrl == null
                    ? _selectedAvatarIndex
                    : null,
                enabled: !_saving,
                onSelected: (index) => setState(() {
                  _selectedPhoto = null;
                  _selectedMediaArtworkUrl = null;
                  _selectedAvatarIndex = index;
                }),
              ),
              const SizedBox(height: 24),
              const UniversalText(
                'Choose from your library',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              _OwnedMediaAvatarPicker(
                selectedUrl: _selectedMediaArtworkUrl,
                enabled: !_saving,
                onSelected: (option) => setState(() {
                  _selectedPhoto = null;
                  _selectedAvatarIndex = null;
                  _selectedMediaArtworkUrl = option.imageSource;
                }),
              ),
              const SizedBox(height: 22),
              const UniversalText(
                'Change profile picture',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _PictureButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Take photo',
                      onTap: _saving ? null : _takePhoto,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PictureButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Choose photo',
                      onTap: _saving ? null : _pickPhoto,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileContentSafetyScreen(
                                profile: widget.profile,
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.shield_outlined),
                  label: const UniversalText('CONTENT & SAFETY'),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileAdministrationScreen(
                                profile: widget.profile,
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const UniversalText('PROFILE ADMINISTRATION'),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _deleteProfile,
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                  label: const UniversalText('DELETE PROFILE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                      color: Colors.redAccent.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const UniversalText(
                          'SAVE CHANGES',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// EDITABLE PROFILE AVATAR
/// ============================================================

class _EditableProfileAvatar extends StatelessWidget {
  final Profile profile;
  final XFile? selectedPhoto;
  final int? selectedAvatarIndex;
  final String? selectedMediaArtworkUrl;

  const _EditableProfileAvatar({
    required this.profile,
    required this.selectedPhoto,
    required this.selectedAvatarIndex,
    required this.selectedMediaArtworkUrl,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    if (selectedPhoto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.file(
          File(selectedPhoto!.path),
          width: 130,
          height: 130,
          fit: BoxFit.cover,
        ),
      );
    }

    if (selectedMediaArtworkUrl?.trim().isNotEmpty == true) {
      return _ProfileArtworkAvatarPreview(
        imageSource: selectedMediaArtworkUrl!.trim(),
        size: 130,
      );
    }
    if (selectedAvatarIndex != null) {
      return _IconAvatar(
        option: _avatarOptions[selectedAvatarIndex!],
        size: 130,
      );
    }
    return _ProfileAvatar(profile: profile, size: 130);
  }
}

/// ============================================================
/// PROFILE STATISTICS
/// ============================================================

class ProfileStatisticsSheet extends StatelessWidget {
  final Profile profile;

  const ProfileStatisticsSheet({
    super.key,
    required this.profile,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      padding: const EdgeInsets.fromLTRB(
        24,
        18,
        24,
        30,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  _ProfileAvatar(
                    profile: profile,
                    size: 70,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const UniversalText(
                          'Statistics',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: _StatisticCard(
                      icon: Icons.movie_outlined,
                      title: tr('Movies'),
                      value: '—',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _StatisticCard(
                      icon: Icons.tv_outlined,
                      title: tr('Shows'),
                      value: '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatisticCard(
                      icon: Icons.schedule_outlined,
                      title: tr('Watch time'),
                      value: '—',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _StatisticCard(
                      icon: Icons.check_circle_outline,
                      title: tr('Completed'),
                      value: '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.045,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white10,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Colors.white70,
                          size: 20,
                        ),
                        SizedBox(width: 9),
                        UniversalText(
                          'Your watching profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    UniversalText(
                      'Detailed viewing statistics, '
                      'favorite genres, watch history, '
                      'and yearly Wrapped data will '
                      'appear here.',
                      style: TextStyle(
                        height: 1.5,
                        color: Colors.white.withValues(
                          alpha: 0.48,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// STATISTIC CARD
/// ============================================================

class _StatisticCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatisticCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.045,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.white54,
            size: 21,
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// PROFILE MENU BUTTON
/// ============================================================

class _ProfileMenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(
        alpha: 0.045,
      ),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.06,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// PICTURE BUTTON
/// ============================================================

class _PictureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _PictureButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(
        alpha: 0.045,
      ),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 10,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: Colors.white70,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// CREATE PROFILE SHEET
/// ============================================================

class CreateProfileSheet extends StatefulWidget {
  const CreateProfileSheet({
    super.key,
  });

  @override
  State<CreateProfileSheet> createState() => _CreateProfileSheetState();
}

class _CreateProfileSheetState extends State<CreateProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;

  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedPhoto;
  String? _selectedMediaArtworkUrl;

  bool _saving = false;

  int _selectedAvatarIndex = 0;

  @override

  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _usernameController = TextEditingController();
  }

  @override

  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  /// Performs `_takePhoto` for this feature. Update this documentation when its contract changes.
  Future<void> _takePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (photo == null || !mounted) return;

      setState(() {
        _selectedPhoto = photo;
        _selectedMediaArtworkUrl = null;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'Unable to take photo: $error',
          ),
        ),
      );
    }
  }

  /// Performs `_pickPhoto` for this feature. Update this documentation when its contract changes.
  Future<void> _pickPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (photo == null || !mounted) return;

      setState(() {
        _selectedPhoto = photo;
        _selectedMediaArtworkUrl = null;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'Unable to choose photo: $error',
          ),
        ),
      );
    }
  }

  /// Performs `_save` for this feature. Update this documentation when its contract changes.
  Future<void> _save() async {
    final name = _nameController.text.trim();
    final username = ProfileUsername.normalize(_usernameController.text);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'Please enter a profile name.',
          ),
        ),
      );
      return;
    }

    if (name.length > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UniversalText(
            'Profile name must be 30 characters or less.',
          ),
        ),
      );
      return;
    }

    final usernameError = ProfileUsername.validationMessage(username);
    if (usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(usernameError)),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final controller = AppController.instance;

      final avatarUrl = _selectedPhoto != null
          ? _selectedPhoto!.path
          : (_selectedMediaArtworkUrl?.trim().isNotEmpty == true)
              ? _selectedMediaArtworkUrl!.trim()
              : 'avatar:$_selectedAvatarIndex';
      Profile? savedProfile;

      if (controller.isBackendAuthenticated) {
        final result = await controller.backendApi.addProfile(
          name: name,
          username: username,
          avatarUrl: avatarUrl,
        );

        if (!mounted) return;
        final data = result['profile'];
        if (data is Map) {
          savedProfile = Profile.fromJson(Map<String, dynamic>.from(data));
          final account = controller.currentAccount;
          if (account != null &&
              !account.profiles.any((item) => item.id == savedProfile!.id)) {
            account.profiles.add(savedProfile);
          }
          controller.addNotification(
            action: 'created a new profile: ${savedProfile.name}',
          );
        }
      } else {
        savedProfile = controller.addProfile(
          name,
          username: username,
          avatarUrl: avatarUrl,
        );
      }

      if (!mounted) return;
      if (savedProfile == null) {
        throw StateError(
            'The profile was not returned after saving. Please try again.');
      }
      Navigator.of(context).pop(savedProfile);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile "$name" created.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ProfileUsername.userFacingError(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: const EdgeInsets.only(top: 50),
      padding: EdgeInsets.fromLTRB(
        26,
        18,
        26,
        26 + bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const UniversalText(
                'Create Profile',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 7),
              UniversalText(
                'Create a profile for your library.',
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.55,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: _CreateProfileAvatarPreview(
                  selectedPhoto: _selectedPhoto,
                  option: _avatarOptions[_selectedAvatarIndex],
                  selectedMediaArtworkUrl: _selectedMediaArtworkUrl,
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  labelText: tr('Profile name'),
                  labelStyle: const TextStyle(
                    color: Colors.white60,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Colors.white54,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(
                    alpha: 0.06,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _usernameController,
                enabled: !_saving,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: tr('Username'),
                  prefixText: '@',
                  helperText:
                      '3–32 letters, numbers, or underscores. Availability is checked by the server.',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const UniversalText(
                'Choose an avatar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              _AvatarOptionsGrid(
                selectedIndex: _selectedPhoto == null &&
                        _selectedMediaArtworkUrl == null
                    ? _selectedAvatarIndex
                    : null,
                enabled: !_saving,
                onSelected: (index) => setState(() {
                  _selectedPhoto = null;
                  _selectedMediaArtworkUrl = null;
                  _selectedAvatarIndex = index;
                }),
              ),
              const SizedBox(height: 24),
              const UniversalText(
                'Choose from your library',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              _OwnedMediaAvatarPicker(
                selectedUrl: _selectedMediaArtworkUrl,
                enabled: !_saving,
                onSelected: (option) => setState(() {
                  _selectedPhoto = null;
                  _selectedMediaArtworkUrl = option.imageSource;
                }),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _PictureButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Take photo',
                      onTap: _saving ? null : _takePhoto,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PictureButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Choose photo',
                      onTap: _saving ? null : _pickPhoto,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const UniversalText(
                          'CREATE PROFILE',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// CREATE PROFILE AVATAR PREVIEW
/// ============================================================

class _CreateProfileAvatarPreview extends StatelessWidget {
  final XFile? selectedPhoto;
  final _AvatarOption option;
  final String? selectedMediaArtworkUrl;

  const _CreateProfileAvatarPreview({
    required this.selectedPhoto,
    required this.option,
    required this.selectedMediaArtworkUrl,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    if (selectedPhoto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.file(
          File(selectedPhoto!.path),
          width: 130,
          height: 130,
          fit: BoxFit.cover,
        ),
      );
    }

    if (selectedMediaArtworkUrl?.trim().isNotEmpty == true) {
      return _ProfileArtworkAvatarPreview(
        imageSource: selectedMediaArtworkUrl!.trim(),
        size: 130,
      );
    }
    return _IconAvatar(option: option, size: 130);
  }
}

class _ProfileArtworkAvatarPreview extends StatelessWidget {
  const _ProfileArtworkAvatarPreview({
    required this.imageSource,
    required this.size,
  });

  final String imageSource;
  final double size;

  @override
  Widget build(BuildContext context) {
    final source = imageSource.trim();
    Widget fallback() => Container(
          width: size,
          height: size,
          color: const Color(0xFF202020),
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined,
              color: Colors.white54, size: 34),
        );

    Widget image;
    if (source.startsWith('https://') || source.startsWith('http://')) {
      image = Image.network(
        source,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    } else {
      try {
        final file = source.startsWith('file://')
            ? File.fromUri(Uri.parse(source))
            : File(source);
        image = Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        );
      } catch (_) {
        image = fallback();
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

class _AvatarOptionsGrid extends StatelessWidget {
  const _AvatarOptionsGrid({
    required this.selectedIndex,
    required this.enabled,
    required this.onSelected,
  });

  final int? selectedIndex;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _avatarOptions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: 88,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemBuilder: (context, index) {
          final option = _avatarOptions[index];
          final selected = index == selectedIndex;
          return Tooltip(
            message: option.label,
            child: InkWell(
              onTap: enabled ? () => onSelected(index) : null,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white12,
                    width: selected ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: _IconAvatar(option: option, size: 48),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

/// ============================================================
/// CREATE PROFILE CARD
/// ============================================================

class _CreateProfileCard extends StatefulWidget {
  final VoidCallback onTap;

  const _CreateProfileCard({
    required this.onTap,
  });

  @override
  State<_CreateProfileCard> createState() => _CreateProfileCardState();
}

class _CreateProfileCardState extends State<_CreateProfileCard> {
  bool _hovered = false;

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
      },
      onExit: (_) {
        setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.045 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 150,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 142,
                  height: 142,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withValues(
                      alpha: 0.035,
                    ),
                    border: Border.all(
                      color: _hovered ? Colors.white38 : Colors.white12,
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 42,
                    color: _hovered ? Colors.white : Colors.white54,
                  ),
                ),
                const SizedBox(height: 13),
                UniversalText(
                  'Add Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _hovered ? Colors.white : Colors.white70,
                  ),
                ),
                const SizedBox(height: 7),
                AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const UniversalText(
                    'Create new',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// CREATE PROFILE BUTTON
/// ============================================================

class _CreateProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateProfileButton({
    required this.onTap,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add),
        label: const UniversalText(
          'CREATE PROFILE',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// NO PROFILES
/// ============================================================

class _NoProfiles extends StatelessWidget {
  const _NoProfiles();

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.035,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(
                alpha: 0.05,
              ),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 32,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 18),
          const UniversalText(
            'No profiles yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          UniversalText(
            'Create your first profile to start '
            'using your personal streaming library.',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.5,
              color: Colors.white.withValues(
                alpha: 0.48,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// PROFILE LOGO
/// ============================================================

class _ProfileLogo extends StatelessWidget {
  const _ProfileLogo();

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF343434),
                Color(0xFF151515),
              ],
            ),
            border: Border.all(
              color: Colors.white12,
            ),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 38,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 15),
        const UniversalText(
          'MY STREAMING SERVICE',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

/// ============================================================
/// PROFILE BACKGROUND
/// ============================================================

/// Browsable choices from the active account's owned movie/show/album library.
/// Cached and imported art appears immediately; missing TMDB/album art is then
/// enriched asynchronously while the sheet remains open.
class _OwnedMediaAvatarPicker extends StatefulWidget {
  const _OwnedMediaAvatarPicker({
    required this.selectedUrl,
    required this.enabled,
    required this.onSelected,
  });

  final String? selectedUrl;
  final bool enabled;
  final ValueChanged<_ProfileMediaArtworkOption> onSelected;

  @override
  State<_OwnedMediaAvatarPicker> createState() => _OwnedMediaAvatarPickerState();
}

class _OwnedMediaAvatarPickerState extends State<_OwnedMediaAvatarPicker> {
  final List<_ProfileMediaArtworkOption> _options = <_ProfileMediaArtworkOption>[];
  final Set<String> _seenSources = <String>{};
  bool _loading = true;
  bool _enriching = false;
  bool _disposed = false;
  bool _rebuildScheduled = false;

  void _scheduleRebuild() {
    if (!mounted || _disposed || _rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted && !_disposed) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _seedImportedArtwork();
    unawaited(_loadCachedAndProviderArtwork());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<MediaItem> _ownedArtworkMedia() => AppController.instance.library
      .where((media) => MediaArtworkAutoResolver.isMovieOrShow(media) ||
          MediaArtworkAutoResolver.isAlbum(media))
      .toList(growable: false);

  void _seedImportedArtwork() {
    for (final media in _ownedArtworkMedia()) {
      if (MediaArtworkAutoResolver.isAlbum(media)) {
        _addOption(
          title: media.title,
          kind: 'ALBUM COVER',
          source: media.imageUrl,
          identity: '${media.id}:album:imported',
        );
      } else {
        _addOption(
          title: media.title,
          kind: media.isSeries ? 'SHOW POSTER' : 'MOVIE POSTER',
          source: media.imageUrl,
          identity: '${media.id}:poster:imported',
        );
      }
    }

    // Music tracks are also part of the owned music library. Use one cover per
    // album/artist instead of repeating the same artwork for every song.
    final seenAlbumKeys = <String>{};
    for (final track in MusicLibraryStore.instance.tracks) {
      final album = track.album.trim();
      if (album.isEmpty) continue;
      final albumKey = '${album.toLowerCase()}|${track.artist.trim().toLowerCase()}';
      if (!seenAlbumKeys.add(albumKey)) continue;
      _addOption(
        title: album,
        kind: 'ALBUM COVER',
        source: track.artworkUrl,
        identity: 'track-album:$albumKey',
      );
    }
  }

  void _addOption({
    required String title,
    required String kind,
    required String? source,
    required String identity,
    String tmdbSize = 'w500',
  }) {
    final normalized = _profileArtworkSource(source, tmdbSize: tmdbSize);
    if (normalized == null || normalized.isEmpty ||
        !_seenSources.add(normalized)) {
      return;
    }
    _options.add(_ProfileMediaArtworkOption(
      title: title.trim().isEmpty ? 'Library artwork' : title.trim(),
      kind: kind,
      imageSource: normalized,
      identity: identity,
    ));
  }

  Future<void> _loadCachedAndProviderArtwork() async {
    final controller = AppController.instance;
    final profileId = controller.currentProfile?.id ?? 'guest';
    final mediaItems = _ownedArtworkMedia();
    final energy = EnergySaverController.instance;
    // initState already schedules the first frame; set the flag directly here
    // instead of triggering an unnecessary re-entrant build.
    _enriching = true;

    for (var index = 0; index < mediaItems.length; index++) {
      if (!mounted || _disposed) return;
      final media = mediaItems[index];
      final isAlbum = MediaArtworkAutoResolver.isAlbum(media);
      final isScreen = MediaArtworkAutoResolver.isMovieOrShow(media);
      final paths = await Future.wait<String?>(<Future<String?>>[
        ArtworkSelectionStore.readPosterPath(
          profileId: profileId,
          mediaId: media.id,
        ),
        MediaArtworkAutoResolver.readAutoPosterUrl(media.id),
        if (isScreen)
          ArtworkSelectionStore.readBackdropPath(
            profileId: profileId,
            mediaId: media.id,
          )
        else
          Future<String?>.value(null),
        if (isScreen)
          MediaArtworkAutoResolver.readAutoBackdropPath(media.id)
        else
          Future<String?>.value(null),
      ]);

      final beforeCount = _options.length;
      _addOption(
        title: media.title,
        kind: isAlbum ? 'ALBUM COVER' : (media.isSeries ? 'SHOW POSTER' : 'MOVIE POSTER'),
        source: paths[0],
        identity: '${media.id}:poster:selected',
      );
      _addOption(
        title: media.title,
        kind: isAlbum ? 'ALBUM COVER' : (media.isSeries ? 'SHOW POSTER' : 'MOVIE POSTER'),
        source: paths[1],
        identity: '${media.id}:poster:auto',
      );
      if (isScreen) {
        _addOption(
          title: media.title,
          kind: media.isSeries ? 'SHOW BACKDROP' : 'MOVIE BACKDROP',
          source: paths[2],
          identity: '${media.id}:backdrop:selected',
          tmdbSize: 'w780',
        );
        _addOption(
          title: media.title,
          kind: media.isSeries ? 'SHOW BACKDROP' : 'MOVIE BACKDROP',
          source: paths[3],
          identity: '${media.id}:backdrop:auto',
          tmdbSize: 'w780',
        );
      }
      if (mounted && _options.length != beforeCount) _scheduleRebuild();

      final hasImportedPoster = (media.imageUrl?.trim().isNotEmpty ?? false) ||
          _profileArtworkSource(paths[0]) != null ||
          _profileArtworkSource(paths[1]) != null;
      final hasBackdrop = _profileArtworkSource(paths[2], tmdbSize: 'w780') != null ||
          _profileArtworkSource(paths[3], tmdbSize: 'w780') != null;
      final shouldResolve = isAlbum
          ? !hasImportedPoster
          : isScreen && (!hasImportedPoster || !hasBackdrop);
      if (shouldResolve && CinematicTitleMetadataService.isConfigured &&
          energy.canRunBackgroundWork(pageId: energy.activePage)) {
        final result = await MediaArtworkAutoResolver.resolveMedia(
          media,
          pageId: energy.activePage,
        );
        if (result != null) {
          await MediaArtworkAutoResolver.rememberResolvedArtwork(
            media,
            result,
            profileId: profileId,
            // Avatar browsing should cache artwork only; it should not
            // write a new metadata-credit payload for every title visited.
            persistMissingPoster: false,
          );
          final resolvedBefore = _options.length;
          _addOption(
            title: media.title,
            kind: isAlbum ? 'ALBUM COVER' : (media.isSeries ? 'SHOW POSTER' : 'MOVIE POSTER'),
            source: result.posterUrl,
            identity: '${media.id}:poster:resolved',
          );
          _addOption(
            title: media.title,
            kind: media.isSeries ? 'SHOW BACKDROP' : 'MOVIE BACKDROP',
            source: result.titleMetadata?.backdropUrl ??
                CinematicTitleMetadataService.imageUrl(
                  result.backdropPath,
                  size: 'w780',
                ),
            identity: '${media.id}:backdrop:resolved',
            tmdbSize: 'w780',
          );
          if (mounted && _options.length != resolvedBefore) _scheduleRebuild();
        }
      }

      // Yield between items. Artwork already available locally remains usable
      // and the profile sheet never waits for the entire provider scan.
      if (index % 8 == 7) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (mounted) _scheduleRebuild();
      }
    }

    // Fill album-cover gaps from owned music tracks if that album wasn't
    // represented by an album MediaItem in the main library.
    if (CinematicTitleMetadataService.isConfigured && mounted) {
      final attempted = <String>{};
      for (final track in MusicLibraryStore.instance.tracks) {
        if (!mounted || _disposed) return;
        if (!energy.canRunBackgroundWork(pageId: energy.activePage)) {
          energy.recordBackgroundTaskSkipped();
          break;
        }
        final album = track.album.trim();
        if (album.isEmpty || track.artworkUrl?.trim().isNotEmpty == true) continue;
        final key = '${album.toLowerCase()}|${track.artist.trim().toLowerCase()}';
        if (!attempted.add(key)) continue;
        final alreadyHasCover = _options.any((item) =>
            item.title.toLowerCase() == album.toLowerCase() &&
            item.kind == 'ALBUM COVER');
        if (alreadyHasCover) continue;
        final cover = await MediaArtworkAutoResolver.resolveAlbumCover(
          title: album,
          artist: track.artist,
        );
        if (cover != null) {
          final beforeCount = _options.length;
          _addOption(
            title: album,
            kind: 'ALBUM COVER',
            source: cover,
            identity: 'track-album:$key:resolved',
          );
          if (mounted && _options.length != beforeCount) _scheduleRebuild();
        }
      }
    }

    if (mounted) {
      _loading = false;
      _enriching = false;
      _scheduleRebuild();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_options.isEmpty && _loading) {
      return const SizedBox(
        height: 112,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Loading artwork from your library...',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    if (_options.isEmpty && !_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No artwork was found in your owned movies, shows, or albums yet.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_enriching)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                SizedBox(width: 7),
                Text('Finding missing posters and backdrops…',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        SizedBox(
          height: 280,
          child: GridView.builder(
            itemCount: _options.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 118,
              mainAxisExtent: 112,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final option = _options[index];
              final selected = widget.selectedUrl == option.imageSource;
              return Tooltip(
                message: '${option.title} · ${option.kind.toLowerCase()}',
                child: Material(
                  key: ValueKey<String>(option.identity),
                  color: Colors.white.withValues(alpha: .035),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: widget.enabled ? () => widget.onSelected(option) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white12,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          _ProfileArtworkImage(
                            imageSource: option.imageSource,
                            fit: BoxFit.cover,
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[Colors.transparent, Colors.black87],
                                stops: <double>[.35, 1],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 6,
                            right: 5,
                            bottom: 5,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  option.kind,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  option.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    height: 1.05,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Positioned(
                              top: 5,
                              right: 5,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.check_rounded,
                                    size: 13, color: Colors.black),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProfileArtworkImage extends StatelessWidget {
  const _ProfileArtworkImage({
    required this.imageSource,
    this.fit = BoxFit.cover,
  });

  final String imageSource;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => const ColoredBox(
          color: Color(0xFF202020),
          child: Center(
            child: Icon(Icons.image_not_supported_outlined,
                color: Colors.white38, size: 24),
          ),
        );
    if (imageSource.startsWith('https://') || imageSource.startsWith('http://')) {
      return Image.network(
        imageSource,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }
    try {
      final file = imageSource.startsWith('file://')
          ? File.fromUri(Uri.parse(imageSource))
          : File(imageSource);
      return Image.file(
        file,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback(),
      );
    } catch (_) {
      return fallback();
    }
  }
}

class _ProfileBackdropItem {
  final String title;
  final String type;
  final String imageUrl;

  const _ProfileBackdropItem(
      {required this.title, required this.type, required this.imageUrl});
}

/// Rotates through actual library artwork. With no valid artwork this widget
/// is not mounted, leaving the selection screen completely black.
class _ProfileBackdropArtwork extends StatefulWidget {
  final List<_ProfileBackdropItem> items;
  final int? selectedIndex;

  const _ProfileBackdropArtwork({
    required this.items,
    this.selectedIndex,
  });

  @override
  State<_ProfileBackdropArtwork> createState() =>
      _ProfileBackdropArtworkState();
}

class _ProfileBackdropArtworkState extends State<_ProfileBackdropArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _rotation =
        AnimationController(vsync: this, duration: const Duration(seconds: 7));
    _rotation.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          mounted &&
          widget.selectedIndex == null &&
          widget.items.length > 1) {
        setState(() => _index = (_index + 1) % widget.items.length);
        _rotation.forward(from: 0);
      }
    });
    _rotation.forward();
  }

  @override
  void didUpdateWidget(covariant _ProfileBackdropArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.isEmpty) {
      _index = 0;
    } else if (_index >= widget.items.length) {
      _index = 0;
    }
    if (oldWidget.items.length != widget.items.length &&
        widget.items.length > 1) {
      _rotation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const ColoredBox(color: Colors.black);
    final selectedIndex = widget.selectedIndex;
    final index = selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < widget.items.length
        ? selectedIndex
        : _index % widget.items.length;
    final item = widget.items[index];
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: SizedBox.expand(
              key: ValueKey<String>(item.imageUrl),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(item.imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black)),
                  Container(color: Colors.black.withValues(alpha: .38)),
                  Image.network(item.imageUrl, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black)),
                ],
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.48)),
          const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black,
              Color(0xDD000000),
              Color(0x33000000),
              Color(0xAA000000)
            ],
            stops: [0, 0.27, 0.68, 1],
          ))),
          const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
            stops: [0, 0.7],
          ))),
          Positioned(
            right: 34,
            top: 28,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Container(
                key: ValueKey<String>('label-${item.imageUrl}'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24)),
                child: Text(item.type,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
