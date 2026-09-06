import 'dart:async';

import 'package:flutter/material.dart';

import 'app_core.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem media;

  const PlayerScreen({
    super.key,
    required this.media,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double position = 0.0;

  bool videoFinished = false;
  bool creditsStarted = false;
  bool autoplayCancelled = false;

  int autoplaySeconds = 10;

  Timer? autoplayTimer;
  Timer? groupWatchTimer;

  String selectedAudio = '';
  bool subtitlesEnabled = false;
  String? selectedSubtitle;

  String? groupWatchSessionId;
  bool groupWatchActionInProgress = false;
  bool groupWatchSyncing = false;

  @override
  void initState() {
    super.initState();

    position = AppController.instance
        .getPlaybackProgress(widget.media.id)
        .clamp(0.0, 1.0)
        .toDouble();

    videoFinished = position >= 1.0;

    _initializeGroupWatch();
  }

  @override
  void dispose() {
    autoplayTimer?.cancel();
    groupWatchTimer?.cancel();
    super.dispose();
  }

  void _initializeGroupWatch() {
    final controller = AppController.instance;
    final activeSession = controller.activeGroupWatchSession;

    if (activeSession == null ||
        activeSession.mediaId != widget.media.id) {
      return;
    }

    groupWatchSessionId = activeSession.id;

    _startGroupWatchPolling();
  }

  void _startGroupWatchPolling() {
    groupWatchTimer?.cancel();

    groupWatchTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        _refreshGroupWatchState();
      },
    );

    _refreshGroupWatchState();
  }

  Future<void> _refreshGroupWatchState() async {
    if (!mounted ||
        groupWatchSessionId == null ||
        groupWatchSyncing) {
      return;
    }

    groupWatchSyncing = true;

    try {
      final controller = AppController.instance;

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

      /*
       * The backend stores Group Watch playbackPosition as
       * Duration. The current demo player represents progress
       * as a normalized 0.0 - 1.0 value.
       *
       * Until MediaItem contains an actual duration, use the
       * existing normalized representation by mapping the
       * backend's microseconds back into 0.0 - 1.0.
       */
      final sharedPosition =
          session.playbackPosition.inMicroseconds /
              1000000.0;

      final normalizedPosition =
          sharedPosition.clamp(0.0, 1.0).toDouble();

      if ((position - normalizedPosition).abs() >
          0.01) {
        setState(() {
          position = normalizedPosition;
          videoFinished = position >= 1.0;
        });

        controller.updatePlaybackProgress(
          widget.media.id,
          position,
        );
      }

      if (session.isEnded) {
        if (mounted) {
          setState(() {
            groupWatchSessionId = null;
          });
        }

        groupWatchTimer?.cancel();
      }
    } catch (_) {
      // Polling errors should not interrupt normal playback.
    } finally {
      groupWatchSyncing = false;
    }
  }

  void updatePosition(double value) {
    final newPosition =
        value.clamp(0.0, 1.0).toDouble();

    setState(() {
      position = newPosition;
    });

    final controller = AppController.instance;

    controller.updatePlaybackProgress(
      widget.media.id,
      newPosition,
    );

    if (groupWatchSessionId != null) {
      _sendGroupWatchPosition(newPosition);
    }

    if (newPosition >= 0.999) {
      finishVideo();
    }
  }

  Future<void> _sendGroupWatchPosition(
    double newPosition,
  ) async {
    final controller = AppController.instance;
    final profile = controller.currentProfile;

    if (groupWatchSessionId == null ||
        profile == null) {
      return;
    }

    try {
      await controller.updateGroupWatchPosition(
        sessionId: groupWatchSessionId!,
        profileId: profile.id,
        position: Duration(
          microseconds:
              (newPosition * 1000000).round(),
        ),
      );
    } catch (_) {
      // Do not interrupt playback for a synchronization failure.
    }
  }

  void finishVideo() {
    if (videoFinished) {
      return;
    }

    setState(() {
      position = 1.0;
      videoFinished = true;
      creditsStarted = true;
    });

    final controller = AppController.instance;

    controller.updatePlaybackProgress(
      widget.media.id,
      1.0,
    );

    if (groupWatchSessionId != null) {
      _sendGroupWatchPosition(1.0);
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
          playNextEpisode(nextEpisodeTitle);
          return;
        }

        setState(() {
          autoplaySeconds--;
        });
      },
    );
  }

  void cancelAutoplay() {
    autoplayTimer?.cancel();

    setState(() {
      autoplayCancelled = true;
    });
  }

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
        return AlertDialog(
          title: const Text('Up Next'),
          content: Text(
            nextEpisodeTitle,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  void openAudioSubtitleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      isScrollControlled: true,
      builder: (_) {
        return AudioSubtitleOptions(
          selectedAudio: selectedAudio,
          subtitlesEnabled: subtitlesEnabled,
          selectedSubtitle: selectedSubtitle,
          onAudioChanged: (value) {
            _changeAudioTrack(value);
          },
          onSubtitleChanged: (value) {
            _changeSubtitleTrack(value);
          },
        );
      },
    );
  }

  Future<void> _changeAudioTrack(
    String value,
  ) async {
    setState(() {
      selectedAudio = value;
    });

    final sessionId = groupWatchSessionId;
    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null || profile == null) {
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error.toString(),
          ),
        ),
      );
    }
  }

  Future<void> _changeSubtitleTrack(
    String? value,
  ) async {
    setState(() {
      selectedSubtitle = value;
      subtitlesEnabled = value != null;
    });

    final sessionId = groupWatchSessionId;
    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null || profile == null) {
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error.toString(),
          ),
        ),
      );
    }
  }

  Future<void> showGroupShare() async {
    final controller =
        AppController.instance;

    final currentProfile =
        controller.currentProfile;

    final account =
        controller.currentAccount;

    if (currentProfile == null ||
        account == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'No account or profile is selected.',
          ),
        ),
      );
      return;
    }

    final availableProfiles = account.profiles
        .where(
          (profile) =>
              profile.id != currentProfile.id,
        )
        .toList();

    if (availableProfiles.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'There are no other profiles available to invite.',
          ),
        ),
      );
      return;
    }

    final selectedProfileIds =
        await showDialog<Set<String>>(
      context: context,
      builder: (_) {
        return GroupWatchInviteDialog(
          profiles: availableProfiles,
        );
      },
    );

    if (!mounted ||
        selectedProfileIds == null ||
        selectedProfileIds.isEmpty) {
      return;
    }

    setState(() {
      groupWatchActionInProgress = true;
    });

    try {
      final session =
          await controller.createBackendGroupWatchSession(
        widget.media,
        profileId: currentProfile.id,
        invitedProfileIds: selectedProfileIds,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        groupWatchSessionId = session.id;
      });

      _startGroupWatchPolling();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Group watch session created for ${session.title}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          groupWatchActionInProgress = false;
        });
      }
    }
  }

  Future<void> _playGroupWatch() async {
    final sessionId = groupWatchSessionId;
    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null || profile == null) {
      return;
    }

    if (groupWatchActionInProgress) {
      return;
    }

    setState(() {
      groupWatchActionInProgress = true;
    });

    try {
      final controller = AppController.instance;
      final session =
          controller.getGroupWatchSession(
        sessionId,
      );

      if (session == null) {
        return;
      }

      if (session.isWaiting ||
          session.isReady) {
        await controller.startGroupWatchSession(
          sessionId: sessionId,
          profileId: profile.id,
        );
      } else {
        await controller.playGroupWatchSession(
          sessionId: sessionId,
          profileId: profile.id,
        );
      }

      await _refreshGroupWatchState();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          groupWatchActionInProgress = false;
        });
      }
    }
  }

  Future<void> _pauseGroupWatch() async {
    final sessionId = groupWatchSessionId;
    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null || profile == null) {
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
      groupWatchActionInProgress = true;
    });

    try {
      await AppController.instance
          .pauseGroupWatchSession(
        sessionId: sessionId,
        profileId: profile.id,
        reason: reason,
      );

      await _refreshGroupWatchState();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          groupWatchActionInProgress = false;
        });
      }
    }
  }

  Future<void> _resumeGroupWatch() async {
    final sessionId = groupWatchSessionId;
    final profile =
        AppController.instance.currentProfile;

    if (sessionId == null || profile == null) {
      return;
    }

    if (!AppController.instance
    .canResumeGroupWatchSession(
  sessionId,
  profileId: profile.id,
)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Only the person who paused the Group Watch can resume it.',
          ),
        ),
      );
      return;
    }

    if (groupWatchActionInProgress) {
      return;
    }

    setState(() {
      groupWatchActionInProgress = true;
    });

    try {
      await AppController.instance
          .resumeGroupWatchSession(
        sessionId: sessionId,
        profileId: profile.id,
      );

      await _refreshGroupWatchState();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          groupWatchActionInProgress = false;
        });
      }
    }
  }

  void showExtras() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (_) {
        return const SafeArea(
          child: SizedBox(
            height: 180,
            child: Center(
              child: Text(
                'No extras are available for this media item.',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        AppController.instance;

    final groupSession =
        groupWatchSessionId == null
            ? null
            : controller.getGroupWatchSession(
                groupWatchSessionId!,
              );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.media.title,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                openAudioSubtitleOptions,
            icon: const Icon(
              Icons.audiotrack,
            ),
            tooltip:
                'Audio & Subtitles',
          ),
        ],
      ),
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
                  Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: widget.media.imageUrl != null &&
                            widget.media.imageUrl!
                                .isNotEmpty
                        ? Image.network(
                            widget.media.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (_, __, ___) {
                              return const Center(
                                child: Icon(
                                  Icons.movie,
                                  color:
                                      Colors.white,
                                  size: 100,
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(
                              Icons.movie,
                              color: Colors.white,
                              size: 100,
                            ),
                          ),
                  ),
                  if (!videoFinished &&
                      groupSession?.isPaused != true)
                    Center(
                      child: IconButton(
                        onPressed:
                            groupSession != null
                                ? _playGroupWatch
                                : finishVideo,
                        iconSize: 80,
                        icon: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (groupSession?.isPaused == true)
                    _buildGroupWatchPausedOverlay(
                      groupSession!,
                    ),
                  if (videoFinished &&
                      creditsStarted)
                    const Center(
                      child: Text(
                        'Credits',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 24,
                        ),
                      ),
                    ),
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
                              next.trim().isEmpty) {
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

  Widget _buildGroupWatchBanner(
    GroupWatchSession session,
  ) {
    final profile =
        AppController.instance.currentProfile;

    final isPaused =
        session.isPaused;

    final canResume =
        profile != null &&
        session.canResume(profile.id);

    String text;

    if (session.invitationsExpired &&
        session.isWaiting) {
      text = 'This invite has expired';
    } else if (isPaused) {
      if (session.pauseReason != null &&
          session.pauseReason!.trim().isNotEmpty) {
        text =
            'Paused — ${session.pauseReason}';
      } else {
        text = 'Group Watch paused';
      }
    } else if (session.isPlaying) {
      text = 'Group Watch is playing';
    } else {
      text = 'Group Watch ready';
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFF202020),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.people,
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          if (isPaused && canResume)
            TextButton(
              onPressed:
                  groupWatchActionInProgress
                      ? null
                      : _resumeGroupWatch,
              child: const Text(
                'RESUME',
              ),
            ),
          if (isPaused && !canResume)
            const Text(
              'Waiting...',
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupWatchPausedOverlay(
    GroupWatchSession session,
  ) {
    final profile =
        AppController.instance.currentProfile;

    final canResume =
        profile != null &&
        session.canResume(profile.id);

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: 0.82,
          ),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.pause_circle_filled,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 12),
            const Text(
              'Group Watch Paused',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (session.pauseReason != null &&
                session.pauseReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                session.pauseReason!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            if (canResume)
              ElevatedButton(
                onPressed:
                    groupWatchActionInProgress
                        ? null
                        : _resumeGroupWatch,
                child: const Text(
                  'RESUME',
                ),
              )
            else
              const Text(
                'Waiting for the person who paused to resume.',
                style: TextStyle(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(
    GroupWatchSession? groupSession,
  ) {
    final isGroupPaused =
        groupSession?.isPaused == true;

    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12,
      ),
      child: Column(
        children: [
          Slider(
            value: position,
            min: 0,
            max: 1,
            onChanged:
                videoFinished || isGroupPaused
                    ? null
                    : updatePosition,
          ),
          Row(
            children: [
              IconButton(
                onPressed:
                    videoFinished || isGroupPaused
                        ? null
                        : () {
                            final newPosition =
                                (position - 0.05)
                                    .clamp(0.0, 1.0)
                                    .toDouble();

                            updatePosition(
                              newPosition,
                            );
                          },
                icon: const Icon(
                  Icons.replay_10,
                  color: Colors.white,
                ),
              ),
              if (groupSession != null)
                IconButton(
                  onPressed:
                      groupWatchActionInProgress
                          ? null
                          : groupSession.isPaused
                              ? null
                              : groupSession.isPlaying
                                  ? _pauseGroupWatch
                                  : _playGroupWatch,
                  icon: Icon(
                    groupSession.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                  ),
                )
              else
                IconButton(
                  onPressed: videoFinished
                      ? null
                      : finishVideo,
                  icon: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
              IconButton(
                onPressed:
                    videoFinished || isGroupPaused
                        ? null
                        : () {
                            final newPosition =
                                (position + 0.05)
                                    .clamp(0.0, 1.0)
                                    .toDouble();

                            updatePosition(
                              newPosition,
                            );
                          },
                icon: const Icon(
                  Icons.forward_10,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed:
                    openAudioSubtitleOptions,
                icon: const Icon(
                  Icons.subtitles,
                  color: Colors.white,
                ),
              ),
              if (groupSession == null)
                IconButton(
                  onPressed:
                      groupWatchActionInProgress
                          ? null
                          : showGroupShare,
                  icon: const Icon(
                    Icons.people,
                    color: Colors.white,
                  ),
                )
              else
                IconButton(
                  onPressed:
                      _showGroupWatchSessionInfo,
                  icon: const Icon(
                    Icons.people,
                    color: Colors.white,
                  ),
                ),
              IconButton(
                onPressed: showExtras,
                icon: const Icon(
                  Icons.movie_filter,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGroupWatchSessionInfo() {
    final sessionId = groupWatchSessionId;

    if (sessionId == null) {
      return;
    }

    final session =
        AppController.instance.getGroupWatchSession(
      sessionId,
    );

    if (session == null) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Group Watch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  session.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Status: ${_groupWatchStatusLabel(session)}',
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Participants: ${session.participants.length}',
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
                if (session.pauseReason != null &&
                    session.pauseReason!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    session.pauseReason!,
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'CLOSE',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
  State<GroupWatchInviteDialog> createState() =>
      _GroupWatchInviteDialogState();
}

class _GroupWatchInviteDialogState
    extends State<GroupWatchInviteDialog> {
  final Set<String> selectedProfileIds =
      <String>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Start Group Watch',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose who you want to invite.',
              ),
            ),
            const SizedBox(height: 12),
            ...widget.profiles.map(
              (profile) {
                final selected =
                    selectedProfileIds.contains(
                  profile.id,
                );

                return CheckboxListTile(
                  value: selected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedProfileIds.add(
                          profile.id,
                        );
                      } else {
                        selectedProfileIds.remove(
                          profile.id,
                        );
                      }
                    });
                  },
                  title: Text(
                    profile.name,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'CANCEL',
          ),
        ),
        ElevatedButton(
          onPressed:
              selectedProfileIds.isEmpty
                  ? null
                  : () {
                      Navigator.pop(
                        context,
                        Set<String>.from(
                          selectedProfileIds,
                        ),
                      );
                    },
          child: const Text(
            'INVITE',
          ),
        ),
      ],
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Why did you pause?',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Text(
              '🔋',
              style: TextStyle(fontSize: 24),
            ),
            title: const Text(
              'Voy a cargar',
            ),
            onTap: () {
              Navigator.pop(
                context,
                'Voy a cargar',
              );
            },
          ),
          ListTile(
            leading: const Text(
              '🍿',
              style: TextStyle(fontSize: 24),
            ),
            title: const Text(
              'Voy por un snack',
            ),
            onTap: () {
              Navigator.pop(
                context,
                'Voy por un snack',
              );
            },
          ),
          ListTile(
            leading: const Text(
              '💬',
              style: TextStyle(fontSize: 24),
            ),
            title: const Text(
              'Otro',
            ),
            onTap: () async {
              final reason =
                  await showDialog<String>(
                context: context,
                builder: (_) {
                  return const GroupWatchCustomPauseReasonDialog();
                },
              );

              if (!context.mounted ||
                  reason == null ||
                  reason.trim().isEmpty) {
                return;
              }

              Navigator.of(context).pop(reason.trim());
            },
          ),
        ],
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
    extends State<GroupWatchCustomPauseReasonDialog> {
  final TextEditingController controller =
      TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Why did you pause?',
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Enter a reason',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'CANCEL',
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final value =
                controller.text.trim();

            if (value.isEmpty) {
              return;
            }

            Navigator.pop(
              context,
              value,
            );
          },
          child: const Text(
            'DONE',
          ),
        ),
      ],
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
  Widget build(BuildContext context) {
    if (nextEpisodeTitle == null ||
        nextEpisodeTitle!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Up Next',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              nextEpisodeTitle!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              'Starts in $seconds',
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: const Text(
                    'CANCEL',
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onPlayNow,
                  child: const Text(
                    'PLAY NOW',
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
  State<AudioSubtitleOptions> createState() =>
      _AudioSubtitleOptionsState();
}

class _AudioSubtitleOptionsState
    extends State<AudioSubtitleOptions> {
  late String selectedAudio;
  late bool subtitlesEnabled;
  late String? selectedSubtitle;

  @override
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
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Audio & Subtitles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'AUDIO',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.info_outline,
                color: Colors.white70,
              ),
              title: Text(
                'Audio track metadata is not available for this media item.',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                'No track choices will be invented.',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SUBTITLES',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.info_outline,
                color: Colors.white70,
              ),
              title: Text(
                'Subtitle track metadata is not available for this media item.',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                'No subtitle choices will be invented.',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: subtitlesEnabled,
              onChanged: null,
              title: const Text(
                'Subtitles',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
              subtitle: const Text(
                'Unavailable until subtitle metadata is provided.',
                style: TextStyle(
                  color: Colors.white38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}