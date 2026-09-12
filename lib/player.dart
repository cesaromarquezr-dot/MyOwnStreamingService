// FILE: `lib/player.dart`.
// Purpose: Implements the player portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'device_features.dart';
import 'app_core.dart';
import 'music.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem media;

  // Optional Group Watch session.
  //
  // Normal playback can continue using:
  // PlayerScreen(media: media)
  //
  // Group Watch playback can use:
  // PlayerScreen(
  //   media: media,
  //   groupWatchSessionId: session.id,
  // )
  final String? groupWatchSessionId;

  const PlayerScreen({
    super.key,
    required this.media,
    this.groupWatchSessionId,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double position = 0.0;

  bool videoFinished = false;
  bool creditsStarted = false;
  bool autoplayCancelled = false;
  bool controlsVisible = true;

  int autoplaySeconds = 10;

  Timer? autoplayTimer;
  Timer? groupWatchTimer;
  Timer? groupWatchPositionTimer;
  Timer? controlsTimer;

  String selectedAudio = '';
  bool subtitlesEnabled = false;
  String? selectedSubtitle;

  String? groupWatchSessionId;
  bool groupWatchActionInProgress = false;
  bool groupWatchSyncing = false;

  /// Prevents excessive position writes to the Group Watch backend.
  DateTime? _lastGroupWatchPositionSent;

  /// Prevents remote polling from fighting a local seek/playback update.
  DateTime? _lastLocalPlaybackAction;

  YoutubePlayerController? youtubeController;
  bool youtubePlayerReady = false;
  bool youtubeUrlInvalid = false;
  bool musicWasPlayingBeforeVideo = false;

  StreamSubscription<YoutubeVideoState>?
      youtubeVideoStateSubscription;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();
    musicWasPlayingBeforeVideo = MusicPlaybackController.instance.pauseForVideo();

    position = AppController.instance
        .getPlaybackProgress(widget.media.id)
        .clamp(0.0, 1.0)
        .toDouble();

    videoFinished = position >= 1.0;

    _initializeYoutubePlayer();
    _initializeGroupWatch();
    _startControlsTimer();
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
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        enableCaption: true,
        captionLanguage: 'en',
        color: 'red',
        playsInline: true,
      ),
    );

    youtubeController!.listen(
      _onYoutubePlayerChanged,
    );

    youtubeVideoStateSubscription =
        youtubeController!.videoStateStream.listen(
      _onYoutubeVideoStateChanged,
    );
  }

  String? _extractYoutubeVideoId(String url) {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      return null;
    }

    if (uri.host == 'youtu.be' ||
        uri.host == 'www.youtu.be') {
      final id = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : null;

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

      if (uri.pathSegments.length >= 2 &&
          uri.pathSegments.first == 'shorts') {
        return _cleanYoutubeVideoId(
          uri.pathSegments[1],
        );
      }

      if (uri.pathSegments.length >= 2 &&
          uri.pathSegments.first == 'embed') {
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

    final ready =
        value.playerState != PlayerState.unknown;

    if (ready && !youtubePlayerReady) {
      setState(() {
        youtubePlayerReady = true;
      });

      if (position > 0.0 && position < 1.0) {
        _seekYoutubeByNormalizedPosition(position);
      }
    }

    if (value.playerState == PlayerState.playing) {
      _startControlsTimer();
    }

    if (value.playerState == PlayerState.ended &&
        !videoFinished) {
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

    final duration =
        await youtubeController!.duration;

    if (duration <= 0) {
      return;
    }

    final normalizedPosition =
        (state.position.inMilliseconds /
                (duration * 1000))
            .clamp(0.0, 1.0)
            .toDouble();

    if ((position - normalizedPosition).abs() > 0.005) {
      position = normalizedPosition;

      AppController.instance.updatePlaybackProgress(
        widget.media.id,
        normalizedPosition,
      );

      if (mounted) {
        setState(() {});
      }
    }

    if (groupWatchSessionId != null) {
      _queueGroupWatchPositionSync(
        state.position.inMilliseconds / 1000.0,
      );
    }
  }

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    autoplayTimer?.cancel();
    groupWatchTimer?.cancel();
    groupWatchPositionTimer?.cancel();
    controlsTimer?.cancel();

    youtubeVideoStateSubscription?.cancel();
    youtubeController?.close();
    if (musicWasPlayingBeforeVideo) {
      MusicPlaybackController.instance.resumeAfterVideo();
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
            controller.value.playerState ==
                PlayerState.playing) {
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

    _lastLocalPlaybackAction = DateTime.now();

    controller.playVideo();
    _startControlsTimer();
  }

  /// Performs `_pauseYoutubeVideo` for this feature. Update this documentation when its contract changes.
  void _pauseYoutubeVideo() {
    _lastLocalPlaybackAction = DateTime.now();

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

    final seconds =
        (duration * normalizedPosition)
            .clamp(0.0, duration);

    _lastLocalPlaybackAction = DateTime.now();

    await controller.seekTo(
      seconds: seconds,
    );
  }

  /// Performs `_seekYoutubeBySeconds` for this feature. Update this documentation when its contract changes.
  Future<void> _seekYoutubeBySeconds(
    int seconds,
  ) async {
    final controller = youtubeController;

    if (controller == null) {
      return;
    }

    final current =
        await controller.currentTime;
    final duration =
        await controller.duration;

    var target = current + seconds;

    if (target < 0) {
      target = 0;
    }

    if (target > duration) {
      target = duration;
    }

    _lastLocalPlaybackAction = DateTime.now();

    await controller.seekTo(
      seconds: target,
    );

    _startControlsTimer();

    if (groupWatchSessionId != null) {
      await _sendGroupWatchActualPosition(
        target,
      );
    }
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
  // GROUP WATCH INITIALIZATION
  // ============================================================

  /// Performs `_initializeGroupWatch` for this feature. Update this documentation when its contract changes.
  void _initializeGroupWatch() {
    final controller = AppController.instance;

    String? sessionId =
        widget.groupWatchSessionId;

    sessionId ??=
        controller.activeGroupWatchSession?.id;

    if (sessionId == null ||
        sessionId.trim().isEmpty) {
      return;
    }

    final activeSession =
        controller.getGroupWatchSession(
      sessionId,
    );

    if (activeSession == null) {
      return;
    }

    if (activeSession.mediaId != widget.media.id) {
      return;
    }

    groupWatchSessionId =
        activeSession.id;

    _loadInitialGroupWatchState(
      activeSession,
    );

    _startGroupWatchPolling();
  }

  /// Performs `_loadInitialGroupWatchState` for this feature. Update this documentation when its contract changes.
  void _loadInitialGroupWatchState(
    GroupWatchSession session,
  ) {
    final controller = AppController.instance;

    final sharedSeconds =
        session.playbackPosition.inMilliseconds /
            1000.0;

    if (sharedSeconds > 0) {
      _applyGroupWatchPosition(
        sharedSeconds,
        seekPlayer: false,
      );
    }

    final profile =
        controller.currentProfile;

    if (profile != null) {
      final participant =
          session.participantForProfile(
        profile.id,
      );

      if (participant != null) {
        setState(() {
          selectedAudio =
              participant.audioTrackId ?? '';

          selectedSubtitle =
              participant.subtitleTrackId;

          subtitlesEnabled =
              participant.subtitleTrackId != null;
        });
      }
    }
  }

  /// Performs `_startGroupWatchPolling` for this feature. Update this documentation when its contract changes.
  void _startGroupWatchPolling() {
    groupWatchTimer?.cancel();
    groupWatchPositionTimer?.cancel();

    groupWatchTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        _refreshGroupWatchState();
      },
    );

    groupWatchPositionTimer =
        Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        _syncCurrentPositionToGroupWatch();
      },
    );

    _refreshGroupWatchState();
  }

  /// Performs `_refreshGroupWatchState` for this feature. Update this documentation when its contract changes.
  Future<void> _refreshGroupWatchState() async {
    if (!mounted ||
        groupWatchSessionId == null ||
        groupWatchSyncing) {
      return;
    }

    groupWatchSyncing = true;

    try {
      final controller =
          AppController.instance;

      final session =
          await controller.refreshGroupWatchSession(
        groupWatchSessionId!,
      );

      if (!mounted || session == null) {
        return;
      }

      if (session.mediaId != widget.media.id) {
        return;
      }

      _applyRemoteGroupWatchState(
        session,
      );
    } catch (_) {
      // Synchronization failures should never interrupt playback.
    } finally {
      groupWatchSyncing = false;
    }
  }

  /// Performs `_applyRemoteGroupWatchState` for this feature. Update this documentation when its contract changes.
  Future<void> _applyRemoteGroupWatchState(
    GroupWatchSession session,
  ) async {
    final youtube = youtubeController;

    if (youtube == null) {
      return;
    }

    final now = DateTime.now();

    // Give a local action a short amount of time to settle before
    // allowing polling to immediately override it.
    if (_lastLocalPlaybackAction != null &&
        now.difference(
              _lastLocalPlaybackAction!,
            ) <
            const Duration(milliseconds: 700)) {
      return;
    }

    final sharedSeconds =
        session.playbackPosition.inMilliseconds /
            1000.0;

    final currentSeconds =
        await youtube.currentTime;

    // Synchronize position only when the difference is meaningful.
    //
    // Small differences are ignored so normal playback does not
    // constantly seek back and forth.
    if ((currentSeconds - sharedSeconds).abs() >
        1.25) {
      await _seekYoutubeByAbsoluteSeconds(
        sharedSeconds,
      );
    }

    if (session.isPlaying) {
      if (youtube.value.playerState !=
          PlayerState.playing) {
        youtube.playVideo();
      }
    } else if (session.isPaused) {
      if (youtube.value.playerState ==
          PlayerState.playing) {
        youtube.pauseVideo();
      }
    }

    if (session.isEnded) {
      if (mounted) {
        setState(() {
          groupWatchSessionId = null;
        });
      }

      groupWatchTimer?.cancel();
      groupWatchPositionTimer?.cancel();
    }

    if (mounted) {
      setState(() {});
    }
  }

  /// Performs `_seekYoutubeByAbsoluteSeconds` for this feature. Update this documentation when its contract changes.
  Future<void> _seekYoutubeByAbsoluteSeconds(
    double seconds,
  ) async {
    final controller = youtubeController;

    if (controller == null) {
      return;
    }

    final duration =
        await controller.duration;

    if (duration <= 0) {
      return;
    }

    final target =
        seconds.clamp(0.0, duration);

    _lastLocalPlaybackAction = DateTime.now();

    await controller.seekTo(
      seconds: target,
    );
  }

  /// Performs `_applyGroupWatchPosition` for this feature. Update this documentation when its contract changes.
  void _applyGroupWatchPosition(
    double seconds, {
    bool seekPlayer = true,
  }) {
    final controller = youtubeController;

    if (controller == null) {
      return;
    }

    _getNormalizedPositionFromSeconds(
      seconds,
    ).then(
      (normalized) {
        if (!mounted) {
          return;
        }

        setState(() {
          position = normalized;
          videoFinished = normalized >= 1.0;
        });

        AppController.instance.updatePlaybackProgress(
          widget.media.id,
          normalized,
        );

        if (seekPlayer) {
          _seekYoutubeByAbsoluteSeconds(
            seconds,
          );
        }
      },
    );
  }

  /// Performs `_getNormalizedPositionFromSeconds` for this feature. Update this documentation when its contract changes.
  Future<double> _getNormalizedPositionFromSeconds(
    double seconds,
  ) async {
    final controller = youtubeController;

    if (controller == null) {
      return position;
    }

    final duration =
        await controller.duration;

    if (duration <= 0) {
      return position;
    }

    return (seconds / duration)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  // ============================================================
  // GROUP WATCH POSITION SYNCHRONIZATION
  // ============================================================

  /// Performs `_queueGroupWatchPositionSync` for this feature. Update this documentation when its contract changes.
  void _queueGroupWatchPositionSync(
    double seconds,
  ) {
    if (groupWatchSessionId == null) {
      return;
    }

    final now = DateTime.now();

    if (_lastGroupWatchPositionSent != null &&
        now.difference(
              _lastGroupWatchPositionSent!,
            ) <
            const Duration(seconds: 2)) {
      return;
    }

    _sendGroupWatchActualPosition(
      seconds,
    );
  }

  /// Performs `_syncCurrentPositionToGroupWatch` for this feature. Update this documentation when its contract changes.
  Future<void> _syncCurrentPositionToGroupWatch() async {
    final sessionId =
        groupWatchSessionId;

    final youtube = youtubeController;

    if (sessionId == null ||
        youtube == null ||
        !mounted) {
      return;
    }

    final state =
        youtube.value.playerState;

    if (state != PlayerState.playing) {
      return;
    }

    try {
      final current =
          await youtube.currentTime;

      await _sendGroupWatchActualPosition(
        current,
      );
    } catch (_) {
      // Ignore synchronization failures.
    }
  }

  /// Performs `_sendGroupWatchActualPosition` for this feature. Update this documentation when its contract changes.
  Future<void> _sendGroupWatchActualPosition(
    double seconds,
  ) async {
    final sessionId =
        groupWatchSessionId;

    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null ||
        profile == null) {
      return;
    }

    final now = DateTime.now();

    if (_lastGroupWatchPositionSent != null &&
        now.difference(
              _lastGroupWatchPositionSent!,
            ) <
            const Duration(milliseconds: 750)) {
      return;
    }

    _lastGroupWatchPositionSent = now;

    try {
      await AppController.instance
          .updateGroupWatchPosition(
        sessionId: sessionId,
        profileId: profile.id,
        position: Duration(
          milliseconds: (seconds * 1000).round(),
        ),
      );
    } catch (_) {
      // Do not interrupt playback for a synchronization failure.
    }
  }

  // ============================================================
  // NORMAL PLAYBACK POSITION
  // ============================================================

  /// Performs `updatePosition` for this feature. Update this documentation when its contract changes.
  void updatePosition(double value) {
    final newPosition =
        value.clamp(0.0, 1.0).toDouble();

    setState(() {
      position = newPosition;
    });

    final controller =
        AppController.instance;

    controller.updatePlaybackProgress(
      widget.media.id,
      newPosition,
    );

    _seekYoutubeByNormalizedPosition(
      newPosition,
    );

    if (groupWatchSessionId != null) {
      _sendNormalizedGroupWatchPosition(
        newPosition,
      );
    }

    if (newPosition >= 0.999) {
      finishVideo();
    }
  }

  /// Performs `_sendNormalizedGroupWatchPosition` for this feature. Update this documentation when its contract changes.
  Future<void> _sendNormalizedGroupWatchPosition(
    double normalizedPosition,
  ) async {
    final sessionId =
        groupWatchSessionId;

    final profile =
        AppController.instance.currentProfile;

    final youtube = youtubeController;

    if (sessionId == null ||
        profile == null ||
        youtube == null) {
      return;
    }

    try {
      final duration =
          await youtube.duration;

      if (duration <= 0) {
        return;
      }

      final seconds =
          duration * normalizedPosition;

      await _sendGroupWatchActualPosition(
        seconds,
      );
    } catch (_) {
      // Ignore synchronization failures.
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

    final controller =
        AppController.instance;

    controller.updatePlaybackProgress(
      widget.media.id,
      1.0,
    );

    if (groupWatchSessionId != null) {
      _sendGroupWatchActualPosition(
        0,
      );

      _sendGroupWatchFinishedPosition();
    }

    controller.finishWatching(
      widget.media,
    );

    final nextEpisodeTitle =
        controller.getNextEpisode(
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

  /// Performs `_sendGroupWatchFinishedPosition` for this feature. Update this documentation when its contract changes.
  Future<void> _sendGroupWatchFinishedPosition() async {
    final sessionId =
        groupWatchSessionId;

    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null ||
        profile == null) {
      return;
    }

    final youtube = youtubeController;

    if (youtube == null) {
      return;
    }

    try {
      final duration =
          await youtube.duration;

      if (duration <= 0) {
        return;
      }

      await AppController.instance
          .updateGroupWatchPosition(
        sessionId: sessionId,
        profileId: profile.id,
        position: Duration(
          milliseconds:
              (duration * 1000).round(),
        ),
      );
    } catch (_) {
      // Ignore synchronization failures.
    }
  }

  /// Performs `startAutoplayCountdown` for this feature. Update this documentation when its contract changes.
  void startAutoplayCountdown(
    String nextEpisodeTitle,
  ) {
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
          title: 'Up Next',
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
                  label: const Text('PLAY NOW'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
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
          selectedAudio: selectedAudio,
          subtitlesEnabled:
              subtitlesEnabled,
          selectedSubtitle:
              selectedSubtitle,
          onAudioChanged:
              _changeAudioTrack,
          onSubtitleChanged:
              _changeSubtitleTrack,
        );
      },
    );
  }

  /// Performs `_changeAudioTrack` for this feature. Update this documentation when its contract changes.
  Future<void> _changeAudioTrack(
    String value,
  ) async {
    setState(() {
      selectedAudio = value;
    });

    final sessionId =
        groupWatchSessionId;

    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null ||
        profile == null) {
      return;
    }

    try {
      await AppController.instance
          .setGroupWatchAudioTrack(
        sessionId: sessionId,
        profileId: profile.id,
        audioTrackId: value,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        error.toString(),
      );
    }
  }

  /// Performs `_changeSubtitleTrack` for this feature. Update this documentation when its contract changes.
  Future<void> _changeSubtitleTrack(
    String? value,
  ) async {
    setState(() {
      selectedSubtitle = value;
      subtitlesEnabled =
          value != null;
    });

    final sessionId =
        groupWatchSessionId;

    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null ||
        profile == null) {
      return;
    }

    try {
      await AppController.instance
          .setGroupWatchSubtitleTrack(
        sessionId: sessionId,
        profileId: profile.id,
        subtitleTrackId: value,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        error.toString(),
      );
    }
  }

  /// Performs `_showSnackBar` for this feature. Update this documentation when its contract changes.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              const Color(0xFF242424),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // GROUP WATCH CREATION FROM PLAYER
  // ============================================================

  /// Performs `showGroupShare` for this feature. Update this documentation when its contract changes.
  Future<void> showGroupShare() async {
    final controller =
        AppController.instance;

    final currentProfile =
        controller.currentProfile;

    final account =
        controller.currentAccount;

    if (currentProfile == null ||
        account == null) {
      _showSnackBar(
        'No account or profile is selected.',
      );
      return;
    }

    final availableProfiles =
        account.profiles
            .where(
              (profile) =>
                  profile.id !=
                  currentProfile.id,
            )
            .toList();

    if (availableProfiles.isEmpty) {
      _showSnackBar(
        'There are no other profiles available to invite.',
      );
      return;
    }

    final selectedProfileIds =
        await showDialog<Set<String>>(
      context: context,
      builder: (_) {
        return GroupWatchInviteDialog(
          profiles:
              availableProfiles,
        );
      },
    );

    if (!mounted ||
        selectedProfileIds == null ||
        selectedProfileIds.isEmpty) {
      return;
    }

    setState(() {
      groupWatchActionInProgress =
          true;
    });

    try {
      final session =
          await controller
              .createBackendGroupWatchSession(
        widget.media,
        profileId:
            currentProfile.id,
        invitedProfileIds:
            selectedProfileIds,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        groupWatchSessionId =
            session.id;
      });

      _startGroupWatchPolling();

      _showSnackBar(
        'Group Watch session created for ${session.title}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          groupWatchActionInProgress =
              false;
        });
      }
    }
  }

  // ============================================================
  // GROUP WATCH PLAY
  // ============================================================

  /// Performs `_playGroupWatch` for this feature. Update this documentation when its contract changes.
  Future<void> _playGroupWatch() async {
    final sessionId =
        groupWatchSessionId;

    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null ||
        profile == null) {
      return;
    }

    if (groupWatchActionInProgress) {
      return;
    }

    setState(() {
      groupWatchActionInProgress =
          true;
    });

    try {
      final controller =
          AppController.instance;

      final session =
          controller.getGroupWatchSession(
        sessionId,
      );

      if (session == null) {
        return;
      }

      if (session.invitationsExpired &&
          session.isWaiting) {
        _showSnackBar(
          'This invitation link is expired.',
        );
        return;
      }

      final currentYoutube =
          youtubeController;

      if (currentYoutube != null) {
        final currentSeconds =
            await currentYoutube.currentTime;

        await controller
            .updateGroupWatchPosition(
          sessionId: sessionId,
          profileId: profile.id,
          position: Duration(
            milliseconds:
                (currentSeconds * 1000)
                    .round(),
          ),
        );
      }

      if (session.isWaiting ||
          session.isReady) {
        await controller
            .startGroupWatchSession(
          sessionId: sessionId,
          profileId: profile.id,
        );
      } else {
        await controller
            .playGroupWatchSession(
          sessionId: sessionId,
          profileId: profile.id,
        );
      }

      _playYoutubeVideo();

      await _refreshGroupWatchState();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          groupWatchActionInProgress =
              false;
        });
      }
    }
  }

  // ============================================================
  // GROUP WATCH PAUSE
  // ============================================================

  /// Performs `_pauseGroupWatch` for this feature. Update this documentation when its contract changes.
  Future<void> _pauseGroupWatch() async {
    final sessionId =
        groupWatchSessionId;

    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null ||
        profile == null) {
      return;
    }

    if (groupWatchActionInProgress) {
      return;
    }

    final reason =
        await showDialog<String>(
      context: context,
      builder: (_) {
        return const GroupWatchPauseReasonDialog();
      },
    );

    if (!mounted ||
        reason == null ||
        reason.trim().isEmpty) {
      return;
    }

    setState(() {
      groupWatchActionInProgress =
          true;
    });

    try {
      final youtube =
          youtubeController;

      if (youtube != null) {
        final currentSeconds =
            await youtube.currentTime;

        await AppController.instance
            .updateGroupWatchPosition(
          sessionId: sessionId,
          profileId: profile.id,
          position: Duration(
            milliseconds:
                (currentSeconds * 1000)
                    .round(),
          ),
        );
      }

      await AppController.instance
          .pauseGroupWatchSession(
        sessionId: sessionId,
        profileId: profile.id,
        reason: reason,
      );

      _pauseYoutubeVideo();

      await _refreshGroupWatchState();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          groupWatchActionInProgress =
              false;
        });
      }
    }
  }

  // ============================================================
  // GROUP WATCH RESUME
  // ============================================================

  /// Performs `_resumeGroupWatch` for this feature. Update this documentation when its contract changes.
  Future<void> _resumeGroupWatch() async {
    final sessionId =
        groupWatchSessionId;

    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null ||
        profile == null) {
      return;
    }

    if (!AppController.instance
        .canResumeGroupWatchSession(
      sessionId,
      profileId: profile.id,
    )) {
      _showSnackBar(
        'Only the person who paused the Group Watch can resume it.',
      );
      return;
    }

    if (groupWatchActionInProgress) {
      return;
    }

    setState(() {
      groupWatchActionInProgress =
          true;
    });

    try {
      await AppController.instance
          .resumeGroupWatchSession(
        sessionId: sessionId,
        profileId: profile.id,
      );

      _playYoutubeVideo();

      await _refreshGroupWatchState();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          groupWatchActionInProgress =
              false;
        });
      }
    }
  }

  // ============================================================
  // EXTRAS
  // ============================================================

  /// Performs `showExtras` for this feature. Update this documentation when its contract changes.
  void showExtras() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return const SafeArea(
          child: _PremiumBottomSheet(
            icon:
                Icons.movie_filter_rounded,
            title: 'Extras',
            child: Padding(
              padding:
                  EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 25,
              ),
              child: Text(
                'No extras are available for this media item.',
                textAlign:
                    TextAlign.center,
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
  Widget _buildVideoArea(
    GroupWatchSession? groupSession,
  ) {
    final controller =
        youtubeController;

    if (youtubeUrlInvalid) {
      return const _PlayerMessage(
        icon: Icons.link_off_rounded,
        message:
            'The trailer URL is not a valid YouTube URL.',
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
      child: widget.media.imageUrl !=
                  null &&
              widget.media.imageUrl!
                  .isNotEmpty
          ? Image.network(
              widget.media.imageUrl!,
              fit: BoxFit.contain,
              errorBuilder:
                  (_, __, ___) {
                return const _PlayerMessage(
                  icon:
                      Icons.movie_rounded,
                  message:
                      'No preview available.',
                );
              },
            )
          : const _PlayerMessage(
              icon: Icons.movie_rounded,
              message:
                  'No preview available.',
            ),
    );
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    final controller =
        AppController.instance;

    final groupSession =
        groupWatchSessionId == null
            ? null
            : controller
                .getGroupWatchSession(
                groupWatchSessionId!,
              );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            if (groupSession != null)
              _buildGroupWatchBanner(
                groupSession,
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior:
                          HitTestBehavior
                              .opaque,
                      onTap:
                          _toggleControls,
                      child: Container(
                        color: Colors.black,
                        alignment:
                            Alignment.center,
                        child:
                            _buildVideoArea(
                          groupSession,
                        ),
                      ),
                    ),
                  ),

                  _buildTopBar(
                    groupSession,
                  ),

                  if (groupSession == null &&
                      youtubeController !=
                          null &&
                      !videoFinished)
                    _buildCenterPlayerControl(),

                  if (groupSession?.isPaused ==
                      true)
                    _buildGroupWatchPausedOverlay(
                      groupSession!,
                    ),

                  if (videoFinished &&
                      creditsStarted)
                    _buildCreditsOverlay(),

                  if (videoFinished &&
                      creditsStarted &&
                      !autoplayCancelled)
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child:
                          NextEpisodeCountdown(
                        seconds:
                            autoplaySeconds,
                        nextEpisodeTitle:
                            controller
                                .getNextEpisode(
                          widget.media.id,
                        ),
                        onCancel:
                            cancelAutoplay,
                        onPlayNow: () {
                          final next =
                              controller
                                  .getNextEpisode(
                            widget.media.id,
                          );

                          if (next == null ||
                              next
                                  .trim()
                                  .isEmpty) {
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
            _buildControls(
              groupSession,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  /// Performs `_buildTopBar` for this feature. Update this documentation when its contract changes.
  Widget _buildTopBar(
    GroupWatchSession? groupSession,
  ) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: AnimatedOpacity(
        opacity:
            controlsVisible ? 1 : 0,
        duration:
            const Duration(
          milliseconds: 200,
        ),
        child: Container(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            10,
            12,
            30,
          ),
          decoration:
              BoxDecoration(
            gradient:
                LinearGradient(
              begin:
                  Alignment.topCenter,
              end:
                  Alignment.bottomCenter,
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
                icon:
                    Icons.arrow_back_rounded,
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
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      widget.media.title,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    if (groupSession !=
                        null)
                      const Padding(
                        padding:
                            EdgeInsets.only(
                          top: 2,
                        ),
                        child: Text(
                          'GROUP WATCH',
                          style:
                              TextStyle(
                            color:
                                Colors.white60,
                            fontSize: 10,
                            fontWeight:
                                FontWeight
                                    .w700,
                            letterSpacing:
                                1.2,
                          ),
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
    final playing =
        youtubeController?.value
                .playerState ==
            PlayerState.playing;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring:
            !controlsVisible,
        child: AnimatedOpacity(
          opacity:
              controlsVisible ? 1 : 0,
          duration:
              const Duration(
            milliseconds: 180,
          ),
          child: Center(
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                _SeekButton(
                  icon:
                      Icons.replay_10_rounded,
                  onPressed:
                      youtubePlayerReady
                          ? () {
                              _seekYoutubeBySeconds(
                                -10,
                              );
                            }
                          : null,
                ),
                const SizedBox(
                  width: 18,
                ),
                GestureDetector(
                  onTap:
                      youtubePlayerReady
                          ? _handleMainPlayPause
                          : null,
                  child:
                      AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 180,
                    ),
                    width: 72,
                    height: 72,
                    decoration:
                        BoxDecoration(
                      color: Colors.black
                          .withValues(
                        alpha: 0.58,
                      ),
                      shape:
                          BoxShape.circle,
                      border: Border.all(
                        color: Colors.white
                            .withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    child: Icon(
                      playing
                          ? Icons
                              .pause_rounded
                          : Icons
                              .play_arrow_rounded,
                      color:
                          Colors.white,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 18,
                ),
                _SeekButton(
                  icon:
                      Icons.forward_10_rounded,
                  onPressed:
                      youtubePlayerReady
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
          alignment:
              Alignment.center,
          decoration:
              BoxDecoration(
            gradient:
                LinearGradient(
              begin:
                  Alignment.topCenter,
              end:
                  Alignment.bottomCenter,
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
            padding:
                EdgeInsets.only(
              bottom: 100,
            ),
            child: Text(
              'Credits',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 24,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GROUP WATCH BANNER
  // ============================================================

  /// Performs `_buildGroupWatchBanner` for this feature. Update this documentation when its contract changes.
  Widget _buildGroupWatchBanner(
    GroupWatchSession session,
  ) {
    final profile =
        AppController.instance.currentProfile;

    final isPaused =
        session.isPaused;

    final canResume =
        profile != null &&
            session.canResume(
              profile.id,
            );

    String text;

    if (session.invitationsExpired &&
        session.isWaiting) {
      text =
          'This invitation link is expired.';
    } else if (isPaused) {
      if (session.pauseReason != null &&
          session.pauseReason!
              .trim()
              .isNotEmpty) {
        text =
            'Paused — ${session.pauseReason}';
      } else {
        text =
            'Group Watch paused';
      }
    } else if (session.isPlaying) {
      text =
          'Group Watch is playing';
    } else if (session.isReady) {
      text =
          'Everyone is ready';
    } else {
      text =
          'Group Watch lobby';
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF151515),
        border: Border(
          bottom:
              BorderSide(
            color: Colors.white
                .withValues(
              alpha: 0.06,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: 0.08,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: const Icon(
              Icons
                  .people_alt_rounded,
              color:
                  Colors.white70,
              size: 17,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          if (isPaused &&
              canResume)
            TextButton(
              onPressed:
                  groupWatchActionInProgress
                      ? null
                      : _resumeGroupWatch,
              child:
                  const Text(
                'RESUME',
              ),
            ),
          if (isPaused &&
              !canResume)
            const Text(
              'Waiting...',
              style:
                  TextStyle(
                color:
                    Colors.white54,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // GROUP WATCH PAUSED OVERLAY
  // ============================================================

  /// Performs `_buildGroupWatchPausedOverlay` for this feature. Update this documentation when its contract changes.
  Widget _buildGroupWatchPausedOverlay(
    GroupWatchSession session,
  ) {
    final profile =
        AppController.instance.currentProfile;

    final canResume =
        profile != null &&
            session.canResume(
              profile.id,
            );

    return Positioned.fill(
      child: Container(
        color: Colors.black
            .withValues(
          alpha: 0.58,
        ),
        child: Center(
          child: Container(
            constraints:
                const BoxConstraints(
              maxWidth: 390,
            ),
            margin:
                const EdgeInsets.all(
              24,
            ),
            padding:
                const EdgeInsets.all(
              24,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFF171717),
              borderRadius:
                  BorderRadius.circular(
                22,
              ),
              border: Border.all(
                color: Colors.white
                    .withValues(
                  alpha: 0.10,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(
                    alpha: 0.5,
                  ),
                  blurRadius: 35,
                  offset:
                      const Offset(
                    0,
                    15,
                  ),
                ),
              ],
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withValues(
                      alpha: 0.08,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      const Icon(
                    Icons
                        .pause_rounded,
                    color:
                        Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                const Text(
                  'Group Watch Paused',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 22,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                if (session
                            .pauseReason !=
                        null &&
                    session
                        .pauseReason!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(
                    height: 9,
                  ),
                  Text(
                    session
                        .pauseReason!,
                    textAlign:
                        TextAlign
                            .center,
                    style:
                        const TextStyle(
                      color:
                          Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(
                  height: 20,
                ),
                if (canResume)
                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        ElevatedButton(
                      onPressed:
                          groupWatchActionInProgress
                              ? null
                              : _resumeGroupWatch,
                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            Colors.white,
                        foregroundColor:
                            Colors.black,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 14,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                      ),
                      child:
                          const Text(
                        'RESUME',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ),
                  )
                else
                  const Text(
                    'Waiting for the person who paused to resume.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM CONTROLS
  // ============================================================

  /// Performs `_buildControls` for this feature. Update this documentation when its contract changes.
  Widget _buildControls(
    GroupWatchSession? groupSession,
  ) {
    final isGroupPaused =
        groupSession?.isPaused ==
            true;

    final hasYoutube =
        youtubeController != null;

    final playing =
        youtubeController?.value
                .playerState ==
            PlayerState.playing;

    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds: 200,
      ),
      color:
          const Color(0xFF0A0A0A),
      padding:
          const EdgeInsets.fromLTRB(
        12,
        6,
        12,
        10,
      ),
      child: Column(
        children: [
          SliderTheme(
            data:
                SliderTheme.of(
              context,
            ).copyWith(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(
                enabledThumbRadius: 6,
              ),
              overlayShape:
                  const RoundSliderOverlayShape(
                overlayRadius: 15,
              ),
              activeTrackColor:
                  Colors.white,
              inactiveTrackColor:
                  Colors.white
                      .withValues(
                alpha: 0.18,
              ),
              thumbColor:
                  Colors.white,
              overlayColor:
                  Colors.white
                      .withValues(
                alpha: 0.10,
              ),
            ),
            child: Slider(
              value: position,
              min: 0,
              max: 1,
              onChanged:
                  videoFinished ||
                          isGroupPaused ||
                          !hasYoutube
                      ? null
                      : updatePosition,
            ),
          ),
          Row(
            children: [
              _BottomControlButton(
                icon:
                    Icons.replay_10_rounded,
                onPressed:
                    videoFinished ||
                            isGroupPaused ||
                            !hasYoutube
                        ? null
                        : () {
                            _seekYoutubeBySeconds(
                              -10,
                            );
                          },
              ),
              if (groupSession !=
                  null)
                _BottomControlButton(
                  icon:
                      groupSession.isPlaying
                          ? Icons
                              .pause_rounded
                          : Icons
                              .play_arrow_rounded,
                  onPressed:
                      groupWatchActionInProgress
                          ? null
                          : groupSession
                                  .isPaused
                              ? null
                              : groupSession
                                      .isPlaying
                                  ? _pauseGroupWatch
                                  : _playGroupWatch,
                  large: true,
                )
              else
                _BottomControlButton(
                  icon: playing
                      ? Icons.pause_rounded
                      : Icons
                          .play_arrow_rounded,
                  onPressed:
                      videoFinished
                          ? null
                          : hasYoutube
                              ? _handleMainPlayPause
                              : finishVideo,
                  large: true,
                ),
              _BottomControlButton(
                icon:
                    Icons.forward_10_rounded,
                onPressed:
                    videoFinished ||
                            isGroupPaused ||
                            !hasYoutube
                        ? null
                        : () {
                            _seekYoutubeBySeconds(
                              10,
                            );
                          },
              ),
              const Spacer(),
              _BottomControlButton(
                icon:
                    Icons.subtitles_rounded,
                onPressed:
                    openAudioSubtitleOptions,
              ),
              if (groupSession ==
                  null)
                _BottomControlButton(
                  icon: Icons
                      .people_alt_rounded,
                  onPressed:
                      groupWatchActionInProgress
                          ? null
                          : showGroupShare,
                )
              else
                _BottomControlButton(
                  icon: Icons
                      .people_alt_rounded,
                  onPressed:
                      _showGroupWatchSessionInfo,
                ),
              _BottomControlButton(
                icon: Icons
                    .movie_filter_rounded,
                onPressed:
                    showExtras,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GROUP WATCH INFO
  // ============================================================

  /// Performs `_showGroupWatchSessionInfo` for this feature. Update this documentation when its contract changes.
  void _showGroupWatchSessionInfo() {
    final sessionId =
        groupWatchSessionId;

    if (sessionId == null) {
      return;
    }

    final session =
        AppController.instance
            .getGroupWatchSession(
      sessionId,
    );

    if (session == null) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (_) {
        return _PremiumBottomSheet(
          icon:
              Icons.people_alt_rounded,
          title: 'Group Watch',
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              25,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  session.title,
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                _InfoRow(
                  label: 'Status',
                  value:
                      _groupWatchStatusLabel(
                    session,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                _InfoRow(
                  label:
                      'Participants',
                  value:
                      '${session.participants.length}',
                ),
                if (session
                            .pauseReason !=
                        null &&
                    session
                        .pauseReason!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(
                    height: 10,
                  ),
                  _InfoRow(
                    label: 'Reason',
                    value:
                        session.pauseReason!,
                  ),
                ],
                const SizedBox(
                  height: 20,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  child:
                      TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    child:
                        const Text(
                      'CLOSE',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Performs `_groupWatchStatusLabel` for this feature. Update this documentation when its contract changes.
  String _groupWatchStatusLabel(
    GroupWatchSession session,
  ) {
    if (session.isWaiting) {
      return 'Waiting';
    }

    if (session.isReady) {
      return 'Ready';
    }

    if (session.isPlaying) {
      return 'Playing';
    }

    if (session.isPaused) {
      return 'Paused';
    }

    if (session.isEnded) {
      return 'Ended';
    }

    return 'Unknown';
  }
}

// ============================================================
// REUSABLE PLAYER UI
// ============================================================

class _PlayerIconButton
    extends StatelessWidget {
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
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        child: Container(
          width: 44,
          height: 44,
          decoration:
              BoxDecoration(
            color: Colors.black
                .withValues(
              alpha: 0.42,
            ),
            borderRadius:
                BorderRadius.circular(
              13,
            ),
            border: Border.all(
              color: Colors.white
                  .withValues(
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

class _SeekButton
    extends StatelessWidget {
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
      color: Colors.black
          .withValues(
        alpha: 0.45,
      ),
      shape:
          const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder:
            const CircleBorder(),
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

class _BottomControlButton
    extends StatelessWidget {
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
      disabledColor:
          Colors.white24,
      tooltip: null,
    );
  }
}

class _PlayerMessage
    extends StatelessWidget {
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
        mainAxisSize:
            MainAxisSize.min,
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
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  Colors.white60,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumDialog
    extends StatelessWidget {
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
      backgroundColor:
          Colors.transparent,
      insetPadding:
          const EdgeInsets.all(
        24,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          24,
        ),
        decoration:
            BoxDecoration(
          color:
              const Color(0xFF171717),
          borderRadius:
              BorderRadius.circular(
            24,
          ),
          border: Border.all(
            color: Colors.white
                .withValues(
              alpha: 0.09,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(
                alpha: 0.55,
              ),
              blurRadius: 35,
              offset:
                  const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration:
                  BoxDecoration(
                color: Colors.white
                    .withValues(
                  alpha: 0.07,
                ),
                shape:
                    BoxShape.circle,
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
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight:
                    FontWeight.w800,
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

class _PremiumBottomSheet
    extends StatelessWidget {
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
      decoration:
          const BoxDecoration(
        color:
            Color(0xFF111111),
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(
            28,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const SizedBox(
              height: 10,
            ),
            Container(
              width: 42,
              height: 4,
              decoration:
                  BoxDecoration(
                color:
                    Colors.white24,
                borderRadius:
                    BorderRadius.circular(
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
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withValues(
                      alpha: 0.07,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color:
                        Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w800,
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

class _InfoRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white
            .withValues(
          alpha: 0.045,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style:
                const TextStyle(
              color:
                  Colors.white54,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 13,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// GROUP WATCH INVITE DIALOG
// ============================================================

class GroupWatchInviteDialog
    extends StatefulWidget {
  final List<Profile> profiles;

  const GroupWatchInviteDialog({
    super.key,
    required this.profiles,
  });

  @override
  State<GroupWatchInviteDialog>
      createState() =>
          _GroupWatchInviteDialogState();
}

class _GroupWatchInviteDialogState
    extends State<GroupWatchInviteDialog> {
  final Set<String>
      selectedProfileIds =
      <String>{};

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor:
          Colors.transparent,
      insetPadding:
          const EdgeInsets.all(
        20,
      ),
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 440,
          maxHeight: 600,
        ),
        padding:
            const EdgeInsets.all(
          22,
        ),
        decoration:
            BoxDecoration(
          color:
              const Color(0xFF171717),
          borderRadius:
              BorderRadius.circular(
            24,
          ),
          border: Border.all(
            color: Colors.white
                .withValues(
              alpha: 0.09,
            ),
          ),
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_alt_rounded,
              color: Colors.white,
              size: 34,
            ),
            const SizedBox(
              height: 12,
            ),
            const Text(
              'Start Group Watch',
              style:
                  TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 7,
            ),
            const Text(
              'Choose who you want to invite.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.white54,
                fontSize: 14,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: widget.profiles
                    .map(
                      (profile) {
                        final selected =
                            selectedProfileIds
                                .contains(
                          profile.id,
                        );

                        return AnimatedContainer(
                          duration:
                              const Duration(
                            milliseconds:
                                160,
                          ),
                          margin:
                              const EdgeInsets
                                  .only(
                            bottom: 8,
                          ),
                          decoration:
                              BoxDecoration(
                            color: selected
                                ? Colors.white
                                    .withValues(
                                    alpha:
                                        0.10,
                                  )
                                : Colors.white
                                    .withValues(
                                    alpha:
                                        0.035,
                                  ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                            border:
                                Border.all(
                              color: selected
                                  ? Colors
                                      .white
                                      .withValues(
                                      alpha:
                                          0.20,
                                    )
                                  : Colors
                                      .transparent,
                            ),
                          ),
                          child:
                              CheckboxListTile(
                            value:
                                selected,
                            onChanged:
                                (value) {
                              setState(() {
                                if (value ==
                                    true) {
                                  selectedProfileIds
                                      .add(
                                    profile.id,
                                  );
                                } else {
                                  selectedProfileIds
                                      .remove(
                                    profile.id,
                                  );
                                }
                              });
                            },
                            activeColor:
                                Colors
                                    .white,
                            checkColor:
                                Colors
                                    .black,
                            controlAffinity:
                                ListTileControlAffinity
                                    .trailing,
                            title: Text(
                              profile
                                  .name,
                              style:
                                  const TextStyle(
                                color:
                                    Colors
                                        .white,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                    .toList(),
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            Row(
              children: [
                Expanded(
                  child:
                      TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    child:
                        const Text(
                      'CANCEL',
                      style:
                          TextStyle(
                        color:
                            Colors.white60,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child:
                      ElevatedButton(
                    onPressed:
                        selectedProfileIds
                                .isEmpty
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                  Set<String>.from(
                                    selectedProfileIds,
                                  ),
                                );
                              },
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.white,
                      foregroundColor:
                          Colors.black,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 14,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          13,
                        ),
                      ),
                    ),
                    child:
                        const Text(
                      'INVITE',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// GROUP WATCH PAUSE REASON DIALOG
// ============================================================

class GroupWatchPauseReasonDialog
    extends StatelessWidget {
  const GroupWatchPauseReasonDialog({
    super.key,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor:
          Colors.transparent,
      insetPadding:
          const EdgeInsets.all(
        24,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          22,
        ),
        decoration:
            BoxDecoration(
          color:
              const Color(0xFF171717),
          borderRadius:
              BorderRadius.circular(
            24,
          ),
          border: Border.all(
            color: Colors.white
                .withValues(
              alpha: 0.09,
            ),
          ),
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .pause_circle_outline_rounded,
              color: Colors.white,
              size: 38,
            ),
            const SizedBox(
              height: 12,
            ),
            const Text(
              'Why did you pause?',
              style:
                  TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            _PauseReasonTile(
              emoji: '🔋',
              title:
                  'Voy a cargar',
              onTap: () {
                Navigator.pop(
                  context,
                  'Voy a cargar',
                );
              },
            ),
            _PauseReasonTile(
              emoji: '🍿',
              title:
                  'Voy por un snack',
              onTap: () {
                Navigator.pop(
                  context,
                  'Voy por un snack',
                );
              },
            ),
            _PauseReasonTile(
              emoji: '💬',
              title: 'Otro',
              onTap: () async {
                final reason =
                    await showDialog<
                        String>(
                  context: context,
                  builder: (_) {
                    return const GroupWatchCustomPauseReasonDialog();
                  },
                );

                if (!context.mounted ||
                    reason == null ||
                    reason
                        .trim()
                        .isEmpty) {
                  return;
                }

                Navigator.of(
                  context,
                ).pop(
                  reason.trim(),
                );
              },
            ),
            const SizedBox(
              height: 6,
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
                  const Text(
                'CANCEL',
                style:
                    TextStyle(
                  color:
                      Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PauseReasonTile
    extends StatelessWidget {
  final String emoji;
  final String title;
  final VoidCallback onTap;

  const _PauseReasonTile({
    required this.emoji,
    required this.title,
    required this.onTap,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: Material(
        color: Colors.white
            .withValues(
          alpha: 0.045,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          child: Padding(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 15,
              vertical: 13,
            ),
            child: Row(
              children: [
                Text(
                  emoji,
                  style:
                      const TextStyle(
                    fontSize: 23,
                  ),
                ),
                const SizedBox(
                  width: 13,
                ),
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                      Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GroupWatchCustomPauseReasonDialog
    extends StatefulWidget {
  const GroupWatchCustomPauseReasonDialog({
    super.key,
  });

  @override
  State<GroupWatchCustomPauseReasonDialog>
      createState() =>
          _GroupWatchCustomPauseReasonDialogState();
}

class _GroupWatchCustomPauseReasonDialogState
    extends State<
        GroupWatchCustomPauseReasonDialog> {
  final TextEditingController
      controller =
      TextEditingController();

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor:
          Colors.transparent,
      child: Container(
        padding:
            const EdgeInsets.all(
          22,
        ),
        decoration:
            BoxDecoration(
          color:
              const Color(0xFF171717),
          borderRadius:
              BorderRadius.circular(
            22,
          ),
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Text(
              'Why did you pause?',
              style:
                  TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            TextField(
              controller:
                  controller,
              autofocus: true,
              maxLines: 3,
              style:
                  const TextStyle(
                color: Colors.white,
              ),
              decoration:
                  InputDecoration(
                hintText:
                    'Enter a reason',
                hintStyle:
                    const TextStyle(
                  color:
                      Colors.white38,
                ),
                filled: true,
                fillColor:
                    Colors.white
                        .withValues(
                  alpha: 0.05,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Row(
              children: [
                Expanded(
                  child:
                      TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    child:
                        const Text(
                      'CANCEL',
                    ),
                  ),
                ),
                Expanded(
                  child:
                      ElevatedButton(
                    onPressed: () {
                      final value =
                          controller
                              .text
                              .trim();

                      if (value
                          .isEmpty) {
                        return;
                      }

                      Navigator.pop(
                        context,
                        value,
                      );
                    },
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          Colors.white,
                      foregroundColor:
                          Colors.black,
                    ),
                    child:
                        const Text(
                      'DONE',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NEXT EPISODE COUNTDOWN
// ============================================================

class NextEpisodeCountdown
    extends StatelessWidget {
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
    if (nextEpisodeTitle == null ||
        nextEpisodeTitle!
            .trim()
            .isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints:
          const BoxConstraints(
        maxWidth: 330,
      ),
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF171717)
                .withValues(
          alpha: 0.96,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: Colors.white
              .withValues(
            alpha: 0.10,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.5,
            ),
            blurRadius: 25,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.08,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .play_arrow_rounded,
                  color:
                      Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              const Expanded(
                child: Text(
                  'Up Next',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$seconds',
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w700,
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
            overflow:
                TextOverflow.ellipsis,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton(
                  onPressed:
                      onCancel,
                  style:
                      OutlinedButton
                          .styleFrom(
                    foregroundColor:
                        Colors.white70,
                    side:
                        BorderSide(
                      color: Colors
                          .white
                          .withValues(
                        alpha: 0.15,
                      ),
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                  ),
                  child:
                      const Text(
                    'CANCEL',
                  ),
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child:
                    ElevatedButton(
                  onPressed:
                      onPlayNow,
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors.white,
                    foregroundColor:
                        Colors.black,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                  ),
                  child:
                      const Text(
                    'PLAY NOW',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight
                              .w800,
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

class AudioSubtitleOptions
    extends StatefulWidget {
  final String selectedAudio;
  final bool subtitlesEnabled;
  final String? selectedSubtitle;

  final ValueChanged<String>
      onAudioChanged;

  final ValueChanged<String?>
      onSubtitleChanged;

  const AudioSubtitleOptions({
    super.key,
    required this.selectedAudio,
    required this.subtitlesEnabled,
    required this.selectedSubtitle,
    required this.onAudioChanged,
    required this.onSubtitleChanged,
  });

  @override
  State<AudioSubtitleOptions>
      createState() =>
          _AudioSubtitleOptionsState();
}

class _AudioSubtitleOptionsState
    extends State<
        AudioSubtitleOptions> {
  late String selectedAudio;
  late bool subtitlesEnabled;
  late String? selectedSubtitle;

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();

    selectedAudio =
        widget.selectedAudio;

    subtitlesEnabled =
        widget.subtitlesEnabled;

    selectedSubtitle =
        widget.selectedSubtitle;
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      decoration:
          const BoxDecoration(
        color:
            Color(0xFF111111),
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(
            28,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            24,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white24,
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              const Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color:
                        Colors.white,
                    size: 25,
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Text(
                    'Audio & Subtitles',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 23,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 24,
              ),
              const Text(
                'AUDIO',
                style:
                    TextStyle(
                  color:
                      Colors.white54,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing:
                      1.2,
                ),
              ),
              const SizedBox(
                height: 9,
              ),
              _OptionInfoCard(
                icon:
                    Icons.audiotrack_rounded,
                title:
                    'Audio track metadata is not available',
                subtitle:
                    'No track choices will be invented.',
              ),
              const SizedBox(
                height: 22,
              ),
              const Text(
                'SUBTITLES',
                style:
                    TextStyle(
                  color:
                      Colors.white54,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing:
                      1.2,
                ),
              ),
              const SizedBox(
                height: 9,
              ),
              _OptionInfoCard(
                icon:
                    Icons.subtitles_rounded,
                title:
                    'Subtitle track metadata is not available',
                subtitle:
                    'No subtitle choices will be invented.',
              ),
              const SizedBox(
                height: 10,
              ),
              Container(
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.035,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child:
                    SwitchListTile(
                  value:
                      subtitlesEnabled,
                  onChanged: null,
                  title:
                      const Text(
                    'Subtitles',
                    style:
                        TextStyle(
                      color:
                          Colors.white54,
                      fontWeight:
                          FontWeight
                              .w600,
                    ),
                  ),
                  subtitle:
                      const Text(
                    'Unavailable until subtitle metadata is provided.',
                    style:
                        TextStyle(
                      color:
                          Colors.white38,
                      fontSize: 12,
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

class _OptionInfoCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OptionInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white
            .withValues(
          alpha: 0.045,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: 0.07,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: Icon(
              icon,
              color:
                  Colors.white60,
              size: 20,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    color:
                        Colors.white38,
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
