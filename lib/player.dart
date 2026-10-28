// FILE: `lib/player.dart`.
// Purpose: Implements the player portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:async';
import 'backend_api.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'device_features.dart';
import 'app_core.dart';
import 'music.dart';
import 'xray.dart';
import 'localization.dart';
import 'streaming_experience.dart';
import 'innovation_features.dart';
import 'playback_interruption_bridge.dart';
import 'core/services/original_language_defaults.dart';


class PlayerScreen extends StatefulWidget {
  final MediaItem media;

  /// Optional, richer presence label supplied by episodes, collections or TV channels.
  final String? activityLabel;

  /// Optional absolute start offset used when tuning into a scheduled My TV program.
  final int? initialPositionSeconds;

  const PlayerScreen({
    super.key,
    required this.media,
    this.activityLabel,
    this.initialPositionSeconds,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double position = 0.0;
  final ValueNotifier<Duration> xrayPlaybackPosition =
      ValueNotifier<Duration>(Duration.zero);

  bool videoFinished = false;
  bool creditsStarted = false;
  bool autoplayCancelled = false;
  bool controlsVisible = true;

  int autoplaySeconds = 10;

  Timer? autoplayTimer;
  Timer? controlsTimer;
  Timer? _socialActivityHeartbeat;

  String selectedAudio = '';
  bool subtitlesEnabled = false;
  String? selectedSubtitle;

  String? _playbackSessionId;
  YoutubePlayerController? youtubeController;
  bool youtubePlayerReady = false;
  bool youtubeUrlInvalid = false;
  bool musicWasPlayingBeforeVideo = false;
  bool _autoplayNextEnabled = true;
  late final String _qoeSessionId =
      '${widget.media.id}_${DateTime.now().microsecondsSinceEpoch}';
  final DateTime _qoeStartedAt = DateTime.now();
  bool _qoeReadyLogged = false;
  bool _initialScheduledSeekApplied = false;

  bool get _usesAdaptivePlayback {
    final value = widget.media.playbackUrl?.trim() ?? '';
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasAuthority &&
        uri.userInfo.isEmpty &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }

  StreamSubscription<YoutubeVideoState>? youtubeVideoStateSubscription;

  @override

  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    musicWasPlayingBeforeVideo =
        MusicPlaybackController.instance.pauseForVideo();

    position = widget.initialPositionSeconds != null
        ? 0.0
        : AppController.instance
            .getPlaybackProgress(widget.media.id)
            .clamp(0.0, 1.0)
            .toDouble();

    videoFinished = position >= 1.0;

    if (!_usesAdaptivePlayback) {
      _initializeYoutubePlayer();
      if (youtubeController != null) {
        PlaybackInterruptionBridge.attach(
          owner: this,
          title: widget.media.title,
          pause: _pauseYoutubeVideo,
          resume: _playYoutubeVideo,
          savePosition: () {
            AppController.instance.updatePlaybackProgress(widget.media.id, position);
            unawaited(_syncIndependentPlaybackSession());
          },
        );
      }
      unawaited(_startIndependentPlaybackSession());
      unawaited(_recordQoe('play_requested'));
    }
    unawaited(_loadStreamingExperiencePreferences());
    _startControlsTimer();
    unawaited(_setSocialWatchActivity(_activityText));
  }

  Future<void> _recordQoe(String event, {int? valueMs}) =>
      PlaybackQoeTelemetry.record(
        event: event,
        mediaId: widget.media.id,
        sessionId: _qoeSessionId,
        profileId: AppController.instance.currentProfile?.id,
        valueMs: valueMs,
      );

  Future<void> _loadStreamingExperiencePreferences() async {
    final preferences = await StreamingExperiencePreferences.load(
      profileId: AppController.instance.currentProfile?.id,
    );
    if (!mounted) return;

    final originalLanguage =
        OriginalLanguageDefaults.resolveForMedia(widget.media);
    final audioTracks = widget.media.audioTracks;
    final subtitleTracks = widget.media.subtitles;
    final selectedAudio = OriginalLanguageDefaults.bestTrack(
          audioTracks,
          targetLanguage: preferences.preferOriginalLanguageTracks
              ? originalLanguage
              : null,
          preferAudioDescription: preferences.audioDescriptions,
        ) ??
        '';
    final selectedSubtitle = !preferences.subtitlesEnabled
        ? null
        : OriginalLanguageDefaults.bestTrack(
            subtitleTracks,
            targetLanguage: preferences.preferOriginalLanguageTracks
                ? originalLanguage
                : null,
            subtitles: true,
          );

    setState(() {
      _autoplayNextEnabled = preferences.autoplayNext;
      subtitlesEnabled = preferences.subtitlesEnabled;
      this.selectedAudio = selectedAudio;
      this.selectedSubtitle = selectedSubtitle;
    });
  }

  Future<void> _startIndependentPlaybackSession() async {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final api = controller.backendApi;
    if (profile == null || !api.isAuthenticated) return;
    try {
      final deviceId = await controller.ensureDeviceId();
      final result = await api.createPlaybackSession(
        profileId: profile.id,
        deviceId: deviceId,
        mediaId: widget.media.id,
        state: 'playing',
        positionSeconds: 0,
      );
      _playbackSessionId = result['session'] is Map
          ? (result['session'] as Map)['id']?.toString()
          : null;
      await _syncIndependentPlaybackSession(state: 'playing');
    } catch (_) {
      // Playback remains local if the optional session telemetry is unavailable.
    }
  }

  Future<void> _syncIndependentPlaybackSession({String? state}) async {
    final sessionId = _playbackSessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    final duration =
        youtubeController == null ? 0.0 : await youtubeController!.duration;
    final seconds =
        duration > 0 ? (position * duration).clamp(0.0, duration) : 0.0;
    try {
      await AppController.instance.backendApi.updatePlaybackSession(
        sessionId: sessionId,
        mediaId: widget.media.id,
        state: state,
        positionSeconds: seconds,
      );
    } catch (_) {}
  }

  String get _activityText {
    final custom = widget.activityLabel?.trim();
    final value = custom == null || custom.isEmpty
        ? 'Watching ${widget.media.title}'
        : custom;
    return value.length <= 160 ? value : '${value.substring(0, 157)}...';
  }

  Future<void> _setSocialWatchActivity(String? activity) async {
    final profile = AppController.instance.currentProfile;
    final api = AppController.instance.backendApi;
    _socialActivityHeartbeat?.cancel();
    _socialActivityHeartbeat = null;
    if (profile == null || !api.isAuthenticated) return;
    try {
      if (activity == null) {
        await api.setSocialProfilePresence(
          profileId: profile.id,
          availability: 'active',
          clearActivity: true,
        );
      } else {
        await api.setSocialProfilePresence(
          profileId: profile.id,
          availability: 'busy',
          activityType: 'watching',
          activityText: activity,
        );
        _socialActivityHeartbeat = Timer.periodic(
          const Duration(minutes: 1),
          (_) => unawaited(_setSocialWatchActivity(activity)),
        );
      }
    } catch (error) {
      debugPrint(
        'Unable to update viewing presence: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  /// Performs `_initializeYoutubePlayer` for this feature. Update this documentation when its contract changes.
  void _initializeYoutubePlayer() {
    final trailerUrl = widget.media.trailerUrl?.trim();

    if (trailerUrl == null || trailerUrl.isEmpty) {
      return;
    }

    final videoId = _extractYoutubeVideoId(trailerUrl);

    if (videoId == null || videoId.isEmpty) {
      youtubeUrlInvalid = true;
      return;
    }

    youtubeController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        enableCaption: true,
        captionLanguage:
            OriginalLanguageDefaults.resolveForMedia(widget.media) ?? 'en',
        color: 'red',
        playsInline: true,
      ),
    );

    youtubeController!.listen(
      _onYoutubePlayerChanged,
    );

    youtubeVideoStateSubscription = youtubeController!.videoStateStream.listen(
      _onYoutubeVideoStateChanged,
    );
  }

  String? _extractYoutubeVideoId(String url) {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      return null;
    }

    if (uri.host == 'youtu.be' || uri.host == 'www.youtu.be') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;

      return _cleanYoutubeVideoId(id);
    }

    if (uri.host == 'youtube.com' ||
        uri.host == 'www.youtube.com' ||
        uri.host == 'm.youtube.com') {
      if (uri.path == '/watch') {
        return _cleanYoutubeVideoId(
          uri.queryParameters['v'],
        );
      }

      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'shorts') {
        return _cleanYoutubeVideoId(
          uri.pathSegments[1],
        );
      }

      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'embed') {
        return _cleanYoutubeVideoId(
          uri.pathSegments[1],
        );
      }
    }

    return null;
  }

  String? _cleanYoutubeVideoId(String? value) {
    if (value == null) {
      return null;
    }

    final id = value.trim();

    if (id.isEmpty || id.length != 11) {
      return null;
    }

    final valid = RegExp(r'^[A-Za-z0-9_-]{11}$');

    if (!valid.hasMatch(id)) {
      return null;
    }

    return id;
  }

  // Performs `_onYoutubePlayerChanged` for this feature. Update this documentation when its contract changes.
  void _onYoutubePlayerChanged(
    YoutubePlayerValue value,
  ) {
    if (!mounted) {
      return;
    }

    final ready = value.playerState != PlayerState.unknown;

    if (ready && !youtubePlayerReady) {
      setState(() {
        youtubePlayerReady = true;
      });
      if (!_qoeReadyLogged) {
        _qoeReadyLogged = true;
        unawaited(_recordQoe('player_ready',
            valueMs: DateTime.now().difference(_qoeStartedAt).inMilliseconds));
      }

      if (widget.initialPositionSeconds != null && !_initialScheduledSeekApplied) {
        _initialScheduledSeekApplied = true;
        unawaited(_seekYoutubeBySeconds(widget.initialPositionSeconds!.clamp(0, 24 * 60 * 60)));
      } else if (position > 0.0 && position < 1.0) {
        _seekYoutubeByNormalizedPosition(position);
      }
    }

    if (value.playerState == PlayerState.playing) {
      _startControlsTimer();
    }

    if (value.playerState == PlayerState.ended && !videoFinished) {
      unawaited(_recordQoe('completed'));
      finishVideo();
    }
  }

  /// Performs `_onYoutubeVideoStateChanged` for this feature. Update this documentation when its contract changes.
  Future<void> _onYoutubeVideoStateChanged(
    YoutubeVideoState state,
  ) async {
    if (!mounted || youtubeController == null) {
      return;
    }

    final duration = await youtubeController!.duration;

    if (duration <= 0) {
      return;
    }

    final normalizedPosition =
        (state.position.inMilliseconds / (duration * 1000))
            .clamp(0.0, 1.0)
            .toDouble();

    xrayPlaybackPosition.value = state.position;

    if ((position - normalizedPosition).abs() > 0.005) {
      position = normalizedPosition;

      AppController.instance.updatePlaybackProgress(
        widget.media.id,
        normalizedPosition,
      );
      unawaited(_syncIndependentPlaybackSession());

      if (mounted) {
        setState(() {});
      }
    }
  }

  @override

  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    autoplayTimer?.cancel();
    controlsTimer?.cancel();
    _socialActivityHeartbeat?.cancel();
    _socialActivityHeartbeat = null;
    PlaybackInterruptionBridge.detach(this);

    unawaited(_syncIndependentPlaybackSession(state: 'stopped'));
    _playbackSessionId = null;

    youtubeVideoStateSubscription?.cancel();
    youtubeController?.close();
    xrayPlaybackPosition.dispose();
    if (musicWasPlayingBeforeVideo) {
      MusicPlaybackController.instance.resumeAfterVideo();
    } else {
      unawaited(_setSocialWatchActivity(null));
    }

    super.dispose();
  }

  /// Performs `_startControlsTimer` for this feature. Update this documentation when its contract changes.
  void _startControlsTimer() {
    controlsTimer?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      controlsVisible = true;
    });

    controlsTimer = Timer(
      const Duration(seconds: 4),
      () {
        if (!mounted) {
          return;
        }

        final controller = youtubeController;

        if (controller != null &&
            controller.value.playerState == PlayerState.playing) {
          setState(() {
            controlsVisible = false;
          });
        }
      },
    );
  }

  /// Performs `_toggleControls` for this feature. Update this documentation when its contract changes.
  void _toggleControls() {
    if (!mounted) {
      return;
    }

    if (!controlsVisible) {
      _startControlsTimer();
      return;
    }

    setState(() {
      controlsVisible = false;
    });

    controlsTimer?.cancel();
  }

  /// Performs `_playYoutubeVideo` for this feature. Update this documentation when its contract changes.
  void _playYoutubeVideo() {
    final controller = youtubeController;

    if (controller == null) {
      finishVideo();
      return;
    }

    controller.playVideo();
    _startControlsTimer();
  }

  /// Performs `_pauseYoutubeVideo` for this feature. Update this documentation when its contract changes.
  void _pauseYoutubeVideo() {

    youtubeController?.pauseVideo();

    if (mounted) {
      setState(() {
        controlsVisible = true;
      });
    }

    controlsTimer?.cancel();
  }

  /// Performs `_seekYoutubeByNormalizedPosition` for this feature. Update this documentation when its contract changes.
  Future<void> _seekYoutubeByNormalizedPosition(
    double normalizedPosition,
  ) async {
    final controller = youtubeController;

    if (controller == null) {
      return;
    }

    final duration = await controller.duration;

    if (duration <= 0) {
      return;
    }

    final seconds = (duration * normalizedPosition).clamp(0.0, duration);

    await controller.seekTo(
      seconds: seconds,
    );
    unawaited(_recordQoe('seek', valueMs: (seconds * 1000).round()));
  }

  /// Performs `_seekYoutubeBySeconds` for this feature. Update this documentation when its contract changes.
  Future<void> _seekYoutubeBySeconds(
    int seconds,
  ) async {
    final controller = youtubeController;

    if (controller == null) {
      return;
    }

    final current = await controller.currentTime;
    final duration = await controller.duration;

    var target = current + seconds;

    if (target < 0) {
      target = 0;
    }

    if (target > duration) {
      target = duration;
    }

    await controller.seekTo(
      seconds: target,
    );

    _startControlsTimer();

  }

  /// Performs `_handleMainPlayPause` for this feature. Update this documentation when its contract changes.
  void _handleMainPlayPause() {
    final controller = youtubeController;

    if (controller == null) {
      finishVideo();
      return;
    }

    final state = controller.value.playerState;

    if (state == PlayerState.playing) {
      _pauseYoutubeVideo();
    } else {
      _playYoutubeVideo();
    }
  }

  // ============================================================
  // NORMAL PLAYBACK POSITION
  // ============================================================

  /// Performs `updatePosition` for this feature. Update this documentation when its contract changes.
  void updatePosition(double value) {
    final newPosition = value.clamp(0.0, 1.0).toDouble();

    setState(() {
      position = newPosition;
    });

    final controller = AppController.instance;

    controller.updatePlaybackProgress(
      widget.media.id,
      newPosition,
    );
    unawaited(_syncIndependentPlaybackSession());

    _seekYoutubeByNormalizedPosition(
      newPosition,
    );

    if (newPosition >= 0.999) {
      finishVideo();
    }
  }

  // ============================================================
  // VIDEO FINISH / AUTOPLAY
  // ============================================================

  /// Performs `finishVideo` for this feature. Update this documentation when its contract changes.
  void finishVideo() {
    if (videoFinished) {
      return;
    }

    youtubeController?.pauseVideo();

    setState(() {
      position = 1.0;
      videoFinished = true;
      creditsStarted = true;
      controlsVisible = true;
    });

    final controller = AppController.instance;

    controller.updatePlaybackProgress(
      widget.media.id,
      1.0,
    );
    unawaited(_syncIndependentPlaybackSession(state: 'completed'));

    controller.finishWatching(
      widget.media,
    );

    final nextEpisodeTitle = controller.getNextEpisode(
      widget.media.id,
    );

    if (nextEpisodeTitle == null ||
        nextEpisodeTitle.trim().isEmpty ||
        autoplayCancelled) {
      return;
    }

    startAutoplayCountdown(
      nextEpisodeTitle,
    );
  }

  /// Performs `startAutoplayCountdown` for this feature. Update this documentation when its contract changes.
  void startAutoplayCountdown(
    String nextEpisodeTitle,
  ) {
    if (!_autoplayNextEnabled) return;
    autoplayTimer?.cancel();

    setState(() {
      autoplaySeconds = 10;
      autoplayCancelled = false;
    });

    autoplayTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (autoplayCancelled) {
          timer.cancel();
          return;
        }

        if (autoplaySeconds <= 1) {
          timer.cancel();

          playNextEpisode(
            nextEpisodeTitle,
          );

          return;
        }

        setState(() {
          autoplaySeconds--;
        });
      },
    );
  }

  /// Performs `cancelAutoplay` for this feature. Update this documentation when its contract changes.
  void cancelAutoplay() {
    autoplayTimer?.cancel();

    setState(() {
      autoplayCancelled = true;
    });
  }

  /// Performs `playNextEpisode` for this feature. Update this documentation when its contract changes.
  void playNextEpisode(
    String nextEpisodeTitle,
  ) {
    autoplayTimer?.cancel();

    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (_) {
        return _PremiumDialog(
          title: tr('Up Next'),
          icon: Icons.play_circle_fill_rounded,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nextEpisodeTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                  ),
                  label: const UniversalText('PLAY NOW'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const UniversalText(
                  'CLOSE',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // AUDIO / SUBTITLES
  // ============================================================

  /// Performs `openAudioSubtitleOptions` for this feature. Update this documentation when its contract changes.
  void openAudioSubtitleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return AudioSubtitleOptions(
          audioOptions: widget.media.audioTracks,
          subtitleOptions: widget.media.subtitles,
          selectedAudio: selectedAudio,
          subtitlesEnabled: subtitlesEnabled,
          selectedSubtitle: selectedSubtitle,
          onAudioChanged: _changeAudioTrack,
          onSubtitleChanged: _changeSubtitleTrack,
        );
      },
    );
  }

  /// Stores the selected audio track for this local playback session.
  Future<void> _changeAudioTrack(String value) async {
    if (!mounted) return;
    setState(() => selectedAudio = value);
  }

  /// Stores the selected subtitle track for this local playback session.
  Future<void> _changeSubtitleTrack(String? value) async {
    if (!mounted) return;
    setState(() {
      selectedSubtitle = value;
      subtitlesEnabled = value != null;
    });
  }

  /// Performs `_showSnackBar` for this feature. Update this documentation when its contract changes.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF242424),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(message),
        ),
      );
  }

  /// Opens the contextual X-Ray screen at the current playback position.
  void showXRay() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => XRayScreen(
          media: widget.media,
          playbackPosition: xrayPlaybackPosition,
        ),
      ),
    );
  }

  // ============================================================
  // EXTRAS
  // ============================================================

  /// Performs `showExtras` for this feature. Update this documentation when its contract changes.
  void showExtras() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: _PremiumBottomSheet(
            icon: Icons.movie_filter_rounded,
            title: tr('Extras'),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 25,
              ),
              child: UniversalText(
                'No extras are available for this media item.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // VIDEO AREA
  // ============================================================

  /// Performs `_buildVideoArea` for this feature. Update this documentation when its contract changes.
  Widget _buildVideoArea() {
    final controller = youtubeController;

    if (youtubeUrlInvalid) {
      return _PlayerMessage(
        icon: Icons.link_off_rounded,
        message: tr('The trailer URL is not a valid YouTube URL.'),
      );
    }

    if (controller != null) {
      return YoutubePlayer(
        controller: controller,
        aspectRatio: 16 / 9,
      );
    }

    return Container(
      width: double.infinity,
      color: Colors.black,
      child: widget.media.imageUrl != null && widget.media.imageUrl!.isNotEmpty
          ? Image.network(
              widget.media.imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return _PlayerMessage(
                  icon: Icons.movie_rounded,
                  message: tr('No preview available.'),
                );
              },
            )
          : _PlayerMessage(
              icon: Icons.movie_rounded,
              message: tr('No preview available.'),
            ),
    );
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    if (_usesAdaptivePlayback) {
      return AdaptiveStreamingPlayer(
        media: widget.media,
        activityLabel: widget.activityLabel,
        initialPositionSeconds: widget.initialPositionSeconds,
      );
    }
    final controller = AppController.instance;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      child: Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: _buildVideoArea(),
                      ),
                    ),
                  ),
                  _buildTopBar(),
                  if (youtubeController != null && !videoFinished)
                    _buildCenterPlayerControl(),
                  if (videoFinished && creditsStarted) _buildCreditsOverlay(),
                  if (videoFinished && creditsStarted && !autoplayCancelled)
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child: NextEpisodeCountdown(
                        seconds: autoplaySeconds,
                        nextEpisodeTitle: controller.getNextEpisode(
                          widget.media.id,
                        ),
                        onCancel: cancelAutoplay,
                        onPlayNow: () {
                          final next = controller.getNextEpisode(
                            widget.media.id,
                          );

                          if (next == null || next.trim().isEmpty) {
                            return;
                          }

                          playNextEpisode(
                            next,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  /// Performs `_buildTopBar` for this feature. Update this documentation when its contract changes.
  Widget _buildTopBar() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: AnimatedOpacity(
        opacity: controlsVisible ? 1 : 0,
        duration: const Duration(
          milliseconds: 200,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            12,
            10,
            12,
            30,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(
                  alpha: 0.78,
                ),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              _PlayerIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop();
                },
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.media.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _PlayerIconButton(
                icon: Icons.cast_rounded,
                onPressed: _openCastMenu,
              ),
              _PlayerIconButton(
                icon: Icons.audiotrack_rounded,
                onPressed: openAudioSubtitleOptions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Performs `_openCastMenu` for this feature. Update this documentation when its contract changes.
  void _openCastMenu() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeviceCenterScreen()),
    );
  }

  // ============================================================
  // CENTER CONTROLS
  // ============================================================

  /// Performs `_buildCenterPlayerControl` for this feature. Update this documentation when its contract changes.
  Widget _buildCenterPlayerControl() {
    final playing = youtubeController?.value.playerState == PlayerState.playing;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !controlsVisible,
        child: AnimatedOpacity(
          opacity: controlsVisible ? 1 : 0,
          duration: const Duration(
            milliseconds: 180,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SeekButton(
                  icon: Icons.replay_5_rounded,
                  onPressed: youtubePlayerReady
                      ? () {
                          _seekYoutubeBySeconds(
                            -5,
                          );
                        }
                      : null,
                ),
                const SizedBox(
                  width: 18,
                ),
                GestureDetector(
                  onTap: youtubePlayerReady ? _handleMainPlayPause : null,
                  child: AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: 0.58,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 18,
                ),
                _SeekButton(
                  icon: Icons.forward_10_rounded,
                  onPressed: youtubePlayerReady
                      ? () {
                          _seekYoutubeBySeconds(
                            10,
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Performs `_buildCreditsOverlay` for this feature. Update this documentation when its contract changes.
  Widget _buildCreditsOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(
                  alpha: 0.15,
                ),
                Colors.black.withValues(
                  alpha: 0.75,
                ),
              ],
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.only(
              bottom: 100,
            ),
            child: UniversalText(
              'Credits',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM CONTROLS
  // ============================================================

  String _bookmarkTimestamp(int positionMs) {
    final duration = Duration(milliseconds: positionMs < 0 ? 0 : positionMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:$minutes:$seconds'
        : '${duration.inMinutes}:$seconds';
  }

  Future<void> _addSceneBookmark() async {
    final controller = youtubeController;
    if (controller == null) {
      _showSnackBar(
          'Scene bookmarks are available when timestamped playback is connected.');
      return;
    }
    if (!ExpandedPlatformRepository.instance.isAvailable) {
      _showSnackBar('Configure Supabase and sign in to save scene bookmarks.');
      return;
    }

    double seconds;
    try {
      seconds = await controller.currentTime;
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('The current playback position is not available yet.');
      return;
    }
    if (!mounted) return;
    final positionMs = (seconds.clamp(0.0, 24 * 60 * 60) * 1000).round();
    final labelController = TextEditingController(
      text: 'Scene at ${_bookmarkTimestamp(positionMs)}',
    );
    final noteController = TextEditingController();
    final values = await showDialog<Map<String, String?>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bookmark this scene'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                'Save ${_bookmarkTimestamp(positionMs)} in “${widget.media.title}”.'),
            const SizedBox(height: 12),
            TextField(
              controller: labelController,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Scene label'),
            ),
            TextField(
              controller: noteController,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Optional note'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              'label': labelController.text.trim(),
              'note': noteController.text.trim(),
            }),
            child: const Text('Save bookmark'),
          ),
        ],
      ),
    );
    labelController.dispose();
    noteController.dispose();
    if (values == null) return;

    try {
      final saved = await ExpandedPlatformRepository.instance.addSceneBookmark(
        mediaKey: widget.media.id,
        positionMs: positionMs,
        label: values['label'],
        note: values['note'],
      );
      if (!mounted) return;
      if (saved == null) {
        _showSnackBar('Sign in to save scene bookmarks.');
      } else {
        _showSnackBar('Scene bookmarked at ${_bookmarkTimestamp(positionMs)}.');
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _showSceneBookmarks() async {
    final repository = ExpandedPlatformRepository.instance;
    if (!repository.isAvailable) {
      _showSnackBar('Configure Supabase and sign in to use scene bookmarks.');
      return;
    }
    try {
      final bookmarks = await repository.sceneBookmarks(widget.media.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF171717),
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.60,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
                child: Row(children: [
                  const Icon(Icons.bookmarks_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Scenes · ${widget.media.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800))),
                  IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              const Divider(height: 1),
              if (bookmarks.isEmpty)
                const Expanded(
                    child: _PlayerMessage(
                        icon: Icons.bookmark_border_rounded,
                        message:
                            'No saved scenes yet. Add a bookmark while watching.'))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final bookmark = bookmarks[index];
                      return ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.play_arrow_rounded)),
                        title: Text(bookmark.label?.trim().isNotEmpty == true
                            ? bookmark.label!.trim()
                            : 'Scene at ${_bookmarkTimestamp(bookmark.positionMs)}'),
                        subtitle: Text(
                            [
                              _bookmarkTimestamp(bookmark.positionMs),
                              if (bookmark.note?.trim().isNotEmpty == true)
                                bookmark.note!.trim(),
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          final target = bookmark.positionMs / 1000.0;
                          final current =
                              await youtubeController?.currentTime ?? target;
                          await _seekYoutubeBySeconds(
                              (target - current).round());
                          _startControlsTimer();
                        },
                      );
                    },
                  ),
                ),
            ]),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  /// Performs `_buildControls` for this feature. Update this documentation when its contract changes.
  Widget _buildControls() {
    final hasYoutube = youtubeController != null;

    final playing = youtubeController?.value.playerState == PlayerState.playing;

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 200,
      ),
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.fromLTRB(
        12,
        6,
        12,
        10,
      ),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(
              context,
            ).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 15,
              ),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(
                alpha: 0.18,
              ),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(
                alpha: 0.10,
              ),
            ),
            child: Slider(
              value: position,
              min: 0,
              max: 1,
              onChanged: videoFinished || !hasYoutube
                  ? null
                  : updatePosition,
            ),
          ),
          Row(
            children: [
              _BottomControlButton(
                icon: Icons.replay_5_rounded,
                onPressed: videoFinished || !hasYoutube
                    ? null
                    : () {
                        _seekYoutubeBySeconds(
                          -5,
                        );
                      },
              ),
              _BottomControlButton(
                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onPressed: videoFinished
                    ? null
                    : hasYoutube
                        ? _handleMainPlayPause
                        : finishVideo,
                large: true,
              ),
              _BottomControlButton(
                icon: Icons.forward_10_rounded,
                onPressed: videoFinished || !hasYoutube
                    ? null
                    : () {
                        _seekYoutubeBySeconds(
                          10,
                        );
                      },
              ),
              const Spacer(),
              _BottomControlButton(
                icon: Icons.subtitles_rounded,
                onPressed: openAudioSubtitleOptions,
              ),
              _BottomControlButton(
                icon: Icons.bookmark_add_outlined,
                onPressed: hasYoutube ? _addSceneBookmark : null,
              ),
              _BottomControlButton(
                icon: Icons.bookmarks_outlined,
                onPressed: _showSceneBookmarks,
              ),
              _BottomControlButton(
                icon: Icons.people_alt_outlined,
                onPressed: showXRay,
              ),
              _BottomControlButton(
                icon: Icons.movie_filter_rounded,
                onPressed: showExtras,
              ),
            ],
          ),
        ],
      ),
    );
  }

}

// ============================================================
// REUSABLE PLAYER UI
// ============================================================

class _PlayerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _PlayerIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(
          13,
        ),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: 0.42,
            ),
            borderRadius: BorderRadius.circular(
              13,
            ),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.10,
              ),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _SeekButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _SeekButton({
    required this.icon,
    required this.onPressed,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(
        alpha: 0.45,
      ),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            color: Colors.white,
            size: 27,
          ),
        ),
      ),
    );
  }
}

class _BottomControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool large;

  const _BottomControlButton({
    required this.icon,
    required this.onPressed,
    this.large = false,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: large ? 28 : 23,
      ),
      color: Colors.white,
      disabledColor: Colors.white24,
      tooltip: null,
    );
  }
}

class _PlayerMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _PlayerMessage({
    required this.icon,
    required this.message,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white30,
            size: 64,
          ),
          const SizedBox(
            height: 14,
          ),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _PremiumDialog({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(
        24,
      ),
      child: Container(
        padding: const EdgeInsets.all(
          24,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(
            24,
          ),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: 0.09,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.55,
              ),
              blurRadius: 35,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.07,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _PremiumBottomSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _PremiumBottomSheet({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            28,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 10,
            ),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(
                  10,
                ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Row(
              children: [
                const SizedBox(
                  width: 20,
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.07,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NEXT EPISODE COUNTDOWN
// ============================================================

class NextEpisodeCountdown extends StatelessWidget {
  final int seconds;
  final String? nextEpisodeTitle;
  final VoidCallback onCancel;
  final VoidCallback onPlayNow;

  const NextEpisodeCountdown({
    super.key,
    required this.seconds,
    required this.nextEpisodeTitle,
    required this.onCancel,
    required this.onPlayNow,
  });

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    if (nextEpisodeTitle == null || nextEpisodeTitle!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 330,
      ),
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF171717).withValues(
          alpha: 0.96,
        ),
        borderRadius: BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.10,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.5,
            ),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.08,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              const Expanded(
                child: UniversalText(
                  'Up Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              UniversalText(
                '$seconds',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            nextEpisodeTitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(
                      color: Colors.white.withValues(
                        alpha: 0.15,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child: const UniversalText(
                    'CANCEL',
                  ),
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: onPlayNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child: const UniversalText(
                    'PLAY NOW',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AUDIO / SUBTITLE OPTIONS
// ============================================================

class AudioSubtitleOptions extends StatefulWidget {
  final List<String> audioOptions;
  final List<String> subtitleOptions;
  final String selectedAudio;
  final bool subtitlesEnabled;
  final String? selectedSubtitle;

  final ValueChanged<String> onAudioChanged;

  final ValueChanged<String?> onSubtitleChanged;

  const AudioSubtitleOptions({
    super.key,
    required this.audioOptions,
    required this.subtitleOptions,
    required this.selectedAudio,
    required this.subtitlesEnabled,
    required this.selectedSubtitle,
    required this.onAudioChanged,
    required this.onSubtitleChanged,
  });

  @override
  State<AudioSubtitleOptions> createState() => _AudioSubtitleOptionsState();
}

class _AudioSubtitleOptionsState extends State<AudioSubtitleOptions> {
  late String selectedAudio;
  late bool subtitlesEnabled;
  late String? selectedSubtitle;

  @override

  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();

    selectedAudio = widget.selectedAudio;

    subtitlesEnabled = widget.subtitlesEnabled;

    selectedSubtitle = widget.selectedSubtitle;
  }

  @override

  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final audioOptions =
        widget.audioOptions.where((track) => track.trim().isNotEmpty).toList();

    final subtitleOptions = widget.subtitleOptions
        .where((track) => track.trim().isNotEmpty)
        .toList();

    final hasAudio = audioOptions.isNotEmpty;
    final hasSubtitles = subtitleOptions.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.white, size: 25),
                  SizedBox(width: 10),
                  UniversalText(
                    'Playback options',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (hasAudio)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: DropdownButtonFormField<String>(
                      initialValue: audioOptions.contains(selectedAudio)
                          ? selectedAudio
                          : audioOptions.first,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1B1B1B),
                      decoration: const InputDecoration(
                        labelText: 'Audio',
                        border: InputBorder.none,
                        floatingLabelStyle: TextStyle(color: Colors.white70),
                      ),
                      icon: const Icon(Icons.expand_more_rounded),
                      items: audioOptions
                          .map((option) => DropdownMenuItem(
                              value: option, child: Text(option)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selectedAudio = value);
                        widget.onAudioChanged(value);
                      },
                    ),
                  ),
                )
              else
                const _MediaOptionPlaceholder(
                  icon: Icons.audiotrack_rounded,
                  title: 'No audio tracks available',
                  subtitle:
                      'This imported disc does not include audio metadata yet.',
                ),
              if (hasAudio) const SizedBox(height: 14),
              if (hasSubtitles)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: DropdownButtonFormField<String?>(
                      initialValue: subtitleOptions.contains(selectedSubtitle)
                          ? selectedSubtitle
                          : null,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1B1B1B),
                      decoration: const InputDecoration(
                        labelText: 'Subtitles',
                        border: InputBorder.none,
                        floatingLabelStyle: TextStyle(color: Colors.white70),
                      ),
                      icon: const Icon(Icons.expand_more_rounded),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: UniversalText('Off')),
                        ...subtitleOptions.map(
                          (option) => DropdownMenuItem<String?>(
                              value: option, child: Text(option)),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedSubtitle = value;
                          subtitlesEnabled = value != null;
                        });
                        widget.onSubtitleChanged(value);
                      },
                    ),
                  ),
                )
              else
                const _MediaOptionPlaceholder(
                  icon: Icons.subtitles_rounded,
                  title: 'No subtitle tracks available',
                  subtitle:
                      'This import does not include subtitle metadata yet.',
                ),
              const SizedBox(height: 18),
              const UniversalText(
                'X-Ray is separate and stays in the cast panel.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaOptionPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MediaOptionPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white60, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
