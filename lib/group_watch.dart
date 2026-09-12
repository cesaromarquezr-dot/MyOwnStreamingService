// FILE: `lib/group_watch.dart`.
// Purpose: Implements the group watch portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:async';

import 'package:flutter/material.dart';

import 'app_core.dart';

class GroupWatchScreen extends StatefulWidget {
  final MediaItem media;
  final String? sessionId;

  const GroupWatchScreen({
    super.key,
    required this.media,
    this.sessionId,
  });

  @override
  State<GroupWatchScreen> createState() => _GroupWatchScreenState();
}

class _GroupWatchScreenState extends State<GroupWatchScreen>
    with SingleTickerProviderStateMixin {
  final AppController controller = AppController.instance;

  late final AnimationController _animationController;

  Timer? _pollTimer;

  bool _loading = true;
  bool _working = false;
  String? _errorMessage;

  String? _localAudioTrackId;
  String? _localSubtitleTrackId;

  static const List<_Track> _audioTracks = [
    _Track(
      id: 'english',
      label: 'English',
      description: 'English',
      icon: Icons.language_rounded,
    ),
    _Track(
      id: 'spanish',
      label: 'Spanish',
      description: 'Español',
      icon: Icons.language_rounded,
    ),
    _Track(
      id: 'french',
      label: 'French',
      description: 'Français',
      icon: Icons.language_rounded,
    ),
    _Track(
      id: 'japanese',
      label: 'Japanese',
      description: '日本語',
      icon: Icons.language_rounded,
    ),
  ];

  static const List<_Track> _subtitleTracks = [
    _Track(
      id: 'none',
      label: 'No subtitles',
      description: 'Off',
      icon: Icons.subtitles_off_outlined,
    ),
    _Track(
      id: 'english',
      label: 'English',
      description: 'English',
      icon: Icons.subtitles_outlined,
    ),
    _Track(
      id: 'spanish',
      label: 'Spanish',
      description: 'Español',
      icon: Icons.subtitles_outlined,
    ),
    _Track(
      id: 'french',
      label: 'French',
      description: 'Français',
      icon: Icons.subtitles_outlined,
    ),
  ];

  @override
  /// Performs `initState` for this feature. Update this documentation when its contract changes.
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _initialize();
  }

  @override
  /// Performs `dispose` for this feature. Update this documentation when its contract changes.
  void dispose() {
    _pollTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// Performs `_initialize` for this feature. Update this documentation when its contract changes.
  Future<void> _initialize() async {
    try {
      final requestedId =
          widget.sessionId ?? controller.activeGroupWatchSessionId;

      if (requestedId != null && requestedId.trim().isNotEmpty) {
        controller.setActiveGroupWatchSession(requestedId);

        await controller.refreshGroupWatchSession(
          requestedId,
        );
      }

      _loadLocalPreferences();
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _cleanError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }

      _startPolling();
    }
  }

  /// Performs `_startPolling` for this feature. Update this documentation when its contract changes.
  void _startPolling() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) async {
        if (!mounted || _working) {
          return;
        }

        final session = _session;

        if (session == null || session.isEnded) {
          return;
        }

        try {
          await controller.refreshGroupWatchSession(
            session.id,
          );

          if (!mounted) {
            return;
          }

          _loadLocalPreferences();

          setState(() {});
        } catch (_) {
          // Keep the current UI alive if a polling request fails.
        }
      },
    );
  }

  GroupWatchSession? get _session {
    final active = controller.activeGroupWatchSession;

    if (active != null) {
      return active;
    }

    final requestedId =
        widget.sessionId ?? controller.activeGroupWatchSessionId;

    if (requestedId == null || requestedId.trim().isEmpty) {
      return null;
    }

    return controller.getGroupWatchSession(requestedId);
  }

  Profile? get _currentProfile => controller.currentProfile;

  GroupWatchParticipant? get _currentParticipant {
    final session = _session;
    final profile = _currentProfile;

    if (session == null || profile == null) {
      return null;
    }

    return session.participantForProfile(profile.id);
  }

  bool get _isHost {
    final session = _session;
    final profile = _currentProfile;

    if (session == null || profile == null) {
      return false;
    }

    return session.hostProfileId == profile.id;
  }

  List<GroupWatchParticipant> get _participants {
    final session = _session;

    if (session == null) {
      return const [];
    }

    return session.participantStates.values.toList();
  }

  List<GroupWatchParticipant> get _acceptedParticipants {
    return _participants
        .where((participant) => participant.isAccepted)
        .toList();
  }

  List<GroupWatchParticipant> get _pendingParticipants {
    return _participants
        .where((participant) => participant.isPending)
        .toList();
  }

  /// Performs `_hasAudio` for this feature. Update this documentation when its contract changes.
  bool _hasAudio(GroupWatchParticipant participant) {
    final id = participant.audioTrackId;

    return id != null && id.trim().isNotEmpty;
  }

  bool get _allParticipantsReady {
    final accepted = _acceptedParticipants;

    if (accepted.isEmpty) {
      return false;
    }

    return accepted.every(_hasAudio);
  }

  bool get _currentParticipantReady {
    final participant = _currentParticipant;

    if (participant == null) {
      return false;
    }

    return _hasAudio(participant);
  }

  bool get _canStart {
    final session = _session;

    if (session == null) {
      return false;
    }

    if (!_isHost) {
      return false;
    }

    if (session.isEnded ||
        session.isPlayingStatus ||
        session.isPaused) {
      return false;
    }

    return _allParticipantsReady;
  }

  bool get _canPause {
    final session = _session;

    return session != null && session.isPlayingStatus;
  }

  bool get _canResume {
    final session = _session;
    final profile = _currentProfile;

    if (session == null || profile == null) {
      return false;
    }

    if (!session.isPaused) {
      return false;
    }

    return controller.canResumeGroupWatchSession(
      session.id,
    );
  }

  /// Performs `_loadLocalPreferences` for this feature. Update this documentation when its contract changes.
  void _loadLocalPreferences() {
    final session = _session;
    final profile = _currentProfile;

    if (session == null || profile == null) {
      return;
    }

    final participant = session.participantForProfile(profile.id);

    if (participant == null) {
      return;
    }

    _localAudioTrackId = participant.audioTrackId;
    _localSubtitleTrackId = participant.subtitleTrackId;
  }

  /// Performs `_cleanError` for this feature. Update this documentation when its contract changes.
  String _cleanError(Object error) {
    var message = error.toString();

    message = message
        .replaceFirst('BackendApiException:', '')
        .replaceFirst('Exception:', '')
        .trim();

    return message.isEmpty ? 'Something went wrong.' : message;
  }

  /// Performs `_acceptInvitation` for this feature. Update this documentation when its contract changes.
  Future<void> _acceptInvitation() async {
    final session = _session;
    final profile = _currentProfile;

    if (session == null || profile == null) {
      return;
    }

    await _runAction(() async {
      await controller.acceptGroupWatchInvitation(
        sessionId: session.id,
        profileId: profile.id,
      );

      await controller.refreshGroupWatchSession(
         session.id,
      );

      _loadLocalPreferences();
    });
  }

  /// Performs `_declineInvitation` for this feature. Update this documentation when its contract changes.
  Future<void> _declineInvitation() async {
    final session = _session;
    final profile = _currentProfile;

    if (session == null || profile == null) {
      return;
    }

    await _runAction(() async {
      await controller.declineGroupWatchInvitation(
        sessionId: session.id,
        profileId: profile.id,
      );
    });
  }

  /// Performs `_chooseAudio` for this feature. Update this documentation when its contract changes.
  Future<void> _chooseAudio() async {
    final selected = await _showTrackPicker(
      title: 'Audio',
      tracks: _audioTracks,
      selectedId: _localAudioTrackId,
    );

    if (selected == null) {
      return;
    }

    final session = _session;

    if (session == null) {
      return;
    }

    await _runAction(() async {
      await controller.setGroupWatchAudioTrack(
        sessionId: session.id,
        audioTrackId: selected,
      );

      _localAudioTrackId = selected;

      await controller.refreshGroupWatchSession(
        session.id,
      );
    });
  }

  /// Performs `_chooseSubtitles` for this feature. Update this documentation when its contract changes.
  Future<void> _chooseSubtitles() async {
    final selected = await _showTrackPicker(
      title: 'Subtitles',
      tracks: _subtitleTracks,
      selectedId: _localSubtitleTrackId ?? 'none',
    );

    if (selected == null) {
      return;
    }

    final session = _session;

    if (session == null) {
      return;
    }

    await _runAction(() async {
      final subtitleId = selected == 'none' ? null : selected;

      await controller.setGroupWatchSubtitleTrack(
        sessionId: session.id,
        subtitleTrackId: subtitleId,
      );

      _localSubtitleTrackId = subtitleId;

      await controller.refreshGroupWatchSession(
        session.id,
      );
    });
  }

  /// Performs `_showTrackPicker` for this feature. Update this documentation when its contract changes.
  Future<String?> _showTrackPicker({
    required String title,
    required List<_Track> tracks,
    required String? selectedId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your choice only affects your playback.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                ...tracks.map(
                  (track) {
                    final selected = track.id == selectedId;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(sheetContext)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: .14)
                              : Colors.white.withValues(alpha: .05),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          track.icon,
                          color: selected
                              ? Theme.of(sheetContext)
                                  .colorScheme
                                  .primary
                              : Colors.white70,
                        ),
                      ),
                      title: Text(
                        track.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(track.description),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .primary,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(sheetContext, track.id);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Performs `_startSession` for this feature. Update this documentation when its contract changes.
  Future<void> _startSession() async {
    final session = _session;

    if (session == null) {
      return;
    }

    if (!_canStart) {
      _showMessage(
        _isHost
            ? 'Everyone who accepted the invitation must choose their audio before playback can start.'
            : 'Choose your audio and wait for the host to start.',
      );
      return;
    }

    await _runAction(() async {
      await controller.startGroupWatchSession(
        sessionId: session.id,
      );

      await controller.playGroupWatchSession(
        sessionId: session.id,
      );

      await controller.refreshGroupWatchSession(
        session.id,
      );
    });
  }

  /// Performs `_pauseSession` for this feature. Update this documentation when its contract changes.
  Future<void> _pauseSession() async {
    final session = _session;

    if (session == null || !_canPause) {
      return;
    }

    final reason = await _showPauseReasonDialog();

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    await _runAction(() async {
      await controller.pauseGroupWatchSession(
        sessionId: session.id,
        reason: reason.trim(),
      );

      await controller.refreshGroupWatchSession(
        session.id,
      );
    });
  }

  /// Performs `_showPauseReasonDialog` for this feature. Update this documentation when its contract changes.
  Future<String?> _showPauseReasonDialog() async {
    final textController = TextEditingController();

    const reasons = [
      'Bathroom break',
      'Getting a snack',
      'Phone call',
      'Someone needs a break',
    ];

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          String? selected;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              final custom = selected == 'custom';

              return AlertDialog(
                backgroundColor: const Color(0xFF171717),
                title: const Text('Why are you pausing?'),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: RadioGroup<String>(
                      groupValue: selected,
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          selected = value;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...reasons.map(
                            (reason) => RadioListTile<String>(
                              value: reason,
                              title: Text(reason),
                            ),
                          ),
                          const RadioListTile<String>(
                            value: 'custom',
                            title: Text('Custom reason'),
                          ),
                          if (custom) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: textController,
                              autofocus: true,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Tell everyone why',
                                hintText:
                                    'Example: I need five minutes.',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('CANCEL'),
                  ),
                  FilledButton(
                    onPressed: selected == null
                        ? null
                        : () {
                            if (selected == 'custom') {
                              final value =
                                  textController.text.trim();

                              if (value.isEmpty) {
                                return;
                              }

                              Navigator.pop(
                                dialogContext,
                                value,
                              );
                              return;
                            }

                            Navigator.pop(
                              dialogContext,
                              selected,
                            );
                          },
                    child: const Text('PAUSE'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      textController.dispose();
    }
  }

  /// Performs `_resumeSession` for this feature. Update this documentation when its contract changes.
  Future<void> _resumeSession() async {
    final session = _session;
    final profile = _currentProfile;

    if (session == null || profile == null) {
      return;
    }

    if (!_canResume) {
      final pausedBy = session.pausedByProfileId;

      if (pausedBy != null) {
        final participant =
            session.participantForProfile(pausedBy);

        _showMessage(
          '${participant?.profileName ?? 'The person who paused'} must return before playback can resume.',
        );
      }

      return;
    }

    await _runAction(() async {
      await controller.resumeGroupWatchSession(
        sessionId: session.id,
      );

      await controller.refreshGroupWatchSession(
        session.id,
      );
    });
  }

  /// Performs `_endSession` for this feature. Update this documentation when its contract changes.
  Future<void> _endSession() async {
    final session = _session;

    if (session == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171717),
          title: const Text('End Group Watch?'),
          content: const Text(
            'Everyone will leave this synchronized watch session.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('END SESSION'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _runAction(() async {
      await controller.endGroupWatchSession(
        sessionId: session.id,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  /// Performs `_runAction` for this feature. Update this documentation when its contract changes.
  Future<void> _runAction(
    /// Performs `Function` for this feature. Update this documentation when its contract changes.
    Future<void> Function() action,
  ) async {
    if (_working) {
      return;
    }

    setState(() {
      _working = true;
      _errorMessage = null;
    });

    try {
      await action();

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        final message = _cleanError(error);

        setState(() {
          _errorMessage = message;
        });

        _showMessage(message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  /// Performs `_showMessage` for this feature. Update this documentation when its contract changes.
  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Performs `_statusTitle` for this feature. Update this documentation when its contract changes.
  String _statusTitle(GroupWatchSession session) {
    if (session.isEnded) {
      return 'Session ended';
    }

    if (session.invitationsExpired && session.isWaiting) {
      return 'Invitation expired';
    }

    if (session.isPlayingStatus) {
      return 'Watching together';
    }

    if (session.isPaused) {
      return 'Paused for everyone';
    }

    if (_allParticipantsReady) {
      return 'Everyone is ready';
    }

    return 'Waiting for everyone';
  }

  /// Performs `_statusSubtitle` for this feature. Update this documentation when its contract changes.
  String _statusSubtitle(GroupWatchSession session) {
    if (session.isEnded) {
      return 'This Group Watch session is no longer active.';
    }

    if (session.invitationsExpired && session.isWaiting) {
      return 'This invitation link is expired.';
    }

    if (session.isPlayingStatus) {
      return 'Playback is synchronized across the group.';
    }

    if (session.isPaused) {
      final reason = session.pauseReason;

      if (reason != null && reason.trim().isNotEmpty) {
        return reason;
      }

      return 'Playback is paused.';
    }

    final pending = _pendingParticipants.length;

    if (pending > 0) {
      return '$pending ${pending == 1 ? 'person is' : 'people are'} still deciding whether to join.';
    }

    return 'Everyone can choose their own audio and subtitle preferences.';
  }

  /// Performs `_audioLabel` for this feature. Update this documentation when its contract changes.
  String _audioLabel(String? id) {
    if (id == null || id.trim().isEmpty) {
      return 'Not selected';
    }

    for (final track in _audioTracks) {
      if (track.id == id) {
        return track.label;
      }
    }

    return id;
  }

  /// Performs `_subtitleLabel` for this feature. Update this documentation when its contract changes.
  String _subtitleLabel(String? id) {
    if (id == null || id.trim().isEmpty) {
      return 'No subtitles';
    }

    for (final track in _subtitleTracks) {
      if (track.id == id) {
        return track.label;
      }
    }

    return id;
  }

  /// Performs `_formatPosition` for this feature. Update this documentation when its contract changes.
  String _formatPosition(Duration position) {
    final totalSeconds =
        position.inSeconds.clamp(0, 864000).toInt();

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Performs `_buildBody` for this feature. Update this documentation when its contract changes.
  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final session = _session;

    if (_errorMessage != null && session == null) {
      return _buildErrorState();
    }

    if (session == null) {
      return _buildMissingSessionState();
    }

    final participant = _currentParticipant;

    if (participant != null && participant.isPending) {
      return _buildInvitationState(
        session,
        participant,
      );
    }

    if (participant != null && participant.isDeclined) {
      return _buildSimpleState(
        icon: Icons.block_outlined,
        title: 'Invitation declined',
        message: 'You declined this Group Watch invitation.',
        button: 'GO BACK',
      );
    }

    if (session.isEnded) {
      return _buildSimpleState(
        icon: Icons.check_circle_outline,
        title: 'Group Watch ended',
        message: 'Thanks for watching together.',
        button: 'DONE',
      );
    }

    return _buildSessionState(session);
  }

  /// Performs `_buildErrorState` for this feature. Update this documentation when its contract changes.
  Widget _buildErrorState() {
    return _buildSimpleState(
      icon: Icons.cloud_off_outlined,
      title: 'Unable to load Group Watch',
      message: _errorMessage ?? 'Unknown error.',
      button: 'TRY AGAIN',
      onPressed: _initialize,
    );
  }

  /// Performs `_buildMissingSessionState` for this feature. Update this documentation when its contract changes.
  Widget _buildMissingSessionState() {
    return _buildSimpleState(
      icon: Icons.groups_2_outlined,
      title: 'Group Watch session not found',
      message: 'The session may have ended or is no longer available.',
      button: 'GO BACK',
    );
  }

  /// Performs `_buildExpiredState` for this feature. Update this documentation when its contract changes.
  Widget _buildExpiredState() {
    return _buildSimpleState(
      icon: Icons.link_off_rounded,
      title: 'This invitation link is expired.',
      message:
          'The Group Watch invitation is no longer available because its invitation window has ended.',
      button: 'GO BACK',
    );
  }

  /// Performs `_buildSimpleState` for this feature. Update this documentation when its contract changes.
  Widget _buildSimpleState({
    required IconData icon,
    required String title,
    required String message,
    required String button,
    VoidCallback? onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 62,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onPressed ??
                  () {
                    Navigator.pop(context);
                  },
              child: Text(button),
            ),
          ],
        ),
      ),
    );
  }

  /// Performs `_buildInvitationState` for this feature. Update this documentation when its contract changes.
  Widget _buildInvitationState(
    GroupWatchSession session,
    GroupWatchParticipant participant,
  ) {
    if (session.invitationsExpired || participant.isExpired) {
      return _buildExpiredState();
    }

    final host =
        session.participantStates[session.hostProfileId];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 700,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeOut,
            ),
            child: Column(
              children: [
                _buildPosterHeader(),
                const SizedBox(height: 24),
                _glassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: .12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.groups_rounded,
                            size: 36,
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'You have been invited',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${host?.profileName ?? 'Someone'} invited you to watch ${widget.media.title}.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _infoBox(session),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    _working ? null : _declineInvitation,
                                style: OutlinedButton.styleFrom(
                                  minimumSize:
                                      const Size(0, 54),
                                ),
                                child: const Text('DECLINE'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    _working ? null : _acceptInvitation,
                                style: FilledButton.styleFrom(
                                  minimumSize:
                                      const Size(0, 54),
                                ),
                                icon: const Icon(
                                  Icons.check_rounded,
                                ),
                                label: const Text('ACCEPT'),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  /// Performs `_buildPosterHeader` for this feature. Update this documentation when its contract changes.
  Widget _buildPosterHeader() {
    final imageUrl = (widget.media.imageUrl ?? '').trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _poster(
          imageUrl,
          width: 92,
          height: 128,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.media.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.media.type.toUpperCase(),
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              if (widget.media.description != null) ...[
                const SizedBox(height: 10),
                Text(
                  widget.media.description!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Performs `_poster` for this feature. Update this documentation when its contract changes.
  Widget _poster(
    String imageUrl, {
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(16),
      ),
      child: imageUrl.isEmpty
          ? const Icon(Icons.movie_outlined)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Icon(Icons.movie_outlined);
              },
            ),
    );
  }

  /// Performs `_infoBox` for this feature. Update this documentation when its contract changes.
  Widget _infoBox(GroupWatchSession session) {
    final accepted = _acceptedParticipants.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: .07),
        ),
      ),
      child: Column(
        children: [
          _infoRow(
            Icons.movie_outlined,
            'Title',
            widget.media.title,
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.people_outline,
            'Participants',
            '$accepted',
          ),
          if (session.invitationExpiresAt != null) ...[
            const SizedBox(height: 12),
            _infoRow(
              Icons.timer_outlined,
              'Invitation',
              _expirationLabel(
                session.invitationExpiresAt!,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Performs `_expirationLabel` for this feature. Update this documentation when its contract changes.
  String _expirationLabel(DateTime expiresAt) {
    final remaining =
        expiresAt.difference(DateTime.now());

    if (remaining <= Duration.zero) {
      return 'Expired';
    }

    if (remaining.inHours >= 24) {
      final days = remaining.inHours ~/ 24;
      return 'Expires in $days ${days == 1 ? 'day' : 'days'}';
    }

    if (remaining.inHours > 0) {
      return 'Expires in ${remaining.inHours}h';
    }

    final minutes =
        remaining.inMinutes.clamp(1, 59).toInt();

    return 'Expires in ${minutes}m';
  }

  /// Performs `_buildSessionState` for this feature. Update this documentation when its contract changes.
  Widget _buildSessionState(GroupWatchSession session) {
    final watching =
        session.isPlayingStatus || session.isPaused;

    return RefreshIndicator(
      onRefresh: () async {
        try {
          await controller.refreshGroupWatchSession(
            session.id,
          );

          if (mounted) {
            _loadLocalPreferences();
            setState(() {});
          }
        } catch (error) {
          _showMessage(_cleanError(error));
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildTopBar(session),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOut,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1100,
                    ),
                    child: _playerSurface(
                      session,
                      watching: watching,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              40,
            ),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1100,
                  ),
                  child: Column(
                    children: [
                      _statusCard(session),
                      if (session.isPaused) ...[
                        const SizedBox(height: 16),
                        _pauseBanner(session),
                      ],
                      const SizedBox(height: 16),
                      _preferencesCard(),
                      const SizedBox(height: 16),
                      _participantsCard(session),
                      const SizedBox(height: 16),
                      _controlsCard(session),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Performs `_buildTopBar` for this feature. Update this documentation when its contract changes.
  Widget _buildTopBar(GroupWatchSession session) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          18,
          10,
          18,
          6,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.groups_rounded, size: 21),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'GROUP WATCH',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ),
            _statusBadge(session),
            const SizedBox(width: 5),
            IconButton(
              tooltip: 'Participants',
              onPressed: () {
                _showParticipantsSheet(session);
              },
              icon: const Icon(
                Icons.people_alt_outlined,
              ),
            ),
            if (_isHost)
              IconButton(
                tooltip: 'End session',
                onPressed: _working ? null : _endSession,
                icon: const Icon(
                  Icons.more_horiz_rounded,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Performs `_statusBadge` for this feature. Update this documentation when its contract changes.
  Widget _statusBadge(GroupWatchSession session) {
    final active = session.isPlayingStatus;
    final paused = session.isPaused;

    final label = active
        ? 'LIVE'
        : paused
            ? 'PAUSED'
            : 'LOBBY';

    final color = active
        ? Colors.green
        : paused
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: color.withValues(alpha: .18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// Performs `_playerSurface` for this feature. Update this documentation when its contract changes.
  Widget _playerSurface(
    GroupWatchSession session, {
    required bool watching,
  }) {
    final imageUrl = (widget.media.imageUrl ?? '').trim();

    return AspectRatio(
      aspectRatio: 16 / 8.7,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .40),
              blurRadius: 35,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _playerFallback();
                },
              )
            else
              _playerFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .10),
                    Colors.black.withValues(alpha: .35),
                    Colors.black.withValues(alpha: .92),
                  ],
                ),
              ),
            ),
            if (!watching)
              Center(
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .55),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .15),
                    ),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    size: 37,
                  ),
                ),
              ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.media.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    watching
                        ? _formatPosition(
                            session.playbackPosition,
                          )
                        : _statusTitle(session),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _progress(session.playbackPosition),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Performs `_progress` for this feature. Update this documentation when its contract changes.
  double _progress(Duration position) {
    if (position == Duration.zero) {
      return 0;
    }

    final seconds = position.inSeconds % 300;

    return seconds / 300;
  }

  /// Performs `_playerFallback` for this feature. Update this documentation when its contract changes.
  Widget _playerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF242424),
            Color(0xFF101010),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          widget.media.type == 'movie'
              ? Icons.movie_creation_outlined
              : Icons.live_tv_outlined,
          size: 82,
          color: Colors.white.withValues(alpha: .15),
        ),
      ),
    );
  }

  /// Performs `_statusCard` for this feature. Update this documentation when its contract changes.
  Widget _statusCard(GroupWatchSession session) {
    final accepted = _acceptedParticipants;

    final ready =
        accepted.where(_hasAudio).length;

    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: session.isPlayingStatus
                    ? Colors.green.withValues(alpha: .11)
                    : session.isPaused
                        ? Colors.orange.withValues(alpha: .11)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .11),
                shape: BoxShape.circle,
              ),
              child: Icon(
                session.isPlayingStatus
                    ? Icons.play_arrow_rounded
                    : session.isPaused
                        ? Icons.pause_rounded
                        : Icons.groups_rounded,
                color: session.isPlayingStatus
                    ? Colors.green
                    : session.isPaused
                        ? Colors.orange
                        : Theme.of(context)
                            .colorScheme
                            .primary,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusTitle(session),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusSubtitle(session),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (!session.isPlayingStatus &&
                !session.isPaused &&
                accepted.isNotEmpty)
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    '$ready/${accepted.length}',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'ready',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Performs `_pauseBanner` for this feature. Update this documentation when its contract changes.
  Widget _pauseBanner(GroupWatchSession session) {
    final pausedBy = session.pausedByProfileId;

    final participant = pausedBy == null
        ? null
        : session.participantForProfile(pausedBy);

    final name = participant?.profileName ?? 'Someone';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.orange.withValues(alpha: .22),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.pause_circle_outline,
            color: Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '$name paused the watch',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (session.pauseReason != null &&
                    session.pauseReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    session.pauseReason!,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Performs `_preferencesCard` for this feature. Update this documentation when its contract changes.
  Widget _preferencesCard() {
    final participant = _currentParticipant;

    if (participant == null ||
        participant.isDeclined ||
        participant.isExpired) {
      return const SizedBox.shrink();
    }

    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _Heading(
              icon: Icons.tune_rounded,
              title: 'Your preferences',
              subtitle:
                  'Everyone can choose independently.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PreferenceTile(
                    icon: Icons.language_rounded,
                    title: 'Audio',
                    value: _audioLabel(
                      participant.audioTrackId ??
                          _localAudioTrackId,
                    ),
                    onTap:
                        _working ? null : _chooseAudio,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PreferenceTile(
                    icon: Icons.subtitles_outlined,
                    title: 'Subtitles',
                    value: _subtitleLabel(
                      participant.subtitleTrackId ??
                          _localSubtitleTrackId,
                    ),
                    onTap:
                        _working ? null : _chooseSubtitles,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Icon(
                  _currentParticipantReady
                      ? Icons.check_circle
                      : Icons.info_outline,
                  size: 17,
                  color: _currentParticipantReady
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _currentParticipantReady
                        ? 'Your preferences are ready.'
                        : 'Choose your audio before the host can start.',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
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

  /// Performs `_participantsCard` for this feature. Update this documentation when its contract changes.
  Widget _participantsCard(GroupWatchSession session) {
    final participants = _participants;

    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _Heading(
                    icon: Icons.people_alt_outlined,
                    title: 'People watching',
                    subtitle: 'Live participant status',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _showParticipantsSheet(session);
                  },
                  child: const Text('VIEW ALL'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (participants.isEmpty)
              Text(
                'No participants found.',
                style: TextStyle(
                  color: Colors.grey.shade500,
                ),
              )
            else
              ...participants.take(5).map(
                    (participant) => _participantRow(
                      participant,
                      session,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  /// Performs `_participantRow` for this feature. Update this documentation when its contract changes.
  Widget _participantRow(
    GroupWatchParticipant participant,
    GroupWatchSession session,
  ) {
    final isCurrent =
        participant.profileId == _currentProfile?.id;

    final ready =
        participant.isAccepted &&
        _hasAudio(participant);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _avatar(
            participant.profileName,
            _findAvatar(participant.profileId),
            highlighted: isCurrent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        participant.profileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (participant.profileId ==
                        session.hostProfileId) ...[
                      const SizedBox(width: 7),
                      const _MiniTag(label: 'HOST'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? '${_audioLabel(participant.audioTrackId)} · ${_subtitleLabel(participant.subtitleTrackId)}'
                      : _participantStatus(participant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ready
                        ? Colors.grey.shade500
                        : participant.isPending
                            ? Colors.orange
                            : participant.isDeclined
                                ? Colors.red
                                : Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _participantStatusIcon(participant),
        ],
      ),
    );
  }

  /// Performs `_participantStatus` for this feature. Update this documentation when its contract changes.
  String _participantStatus(
    GroupWatchParticipant participant,
  ) {
    if (participant.isExpired) {
      return 'Expired';
    }

    if (participant.isDeclined) {
      return 'Declined';
    }

    if (participant.isPending) {
      return 'Invited';
    }

    if (!_hasAudio(participant)) {
      return 'Choose audio';
    }

    return 'Ready';
  }

  String? _findAvatar(String profileId) {
    final account = controller.currentAccount;

    if (account == null) {
      return null;
    }

    for (final profile in account.profiles) {
      if (profile.id == profileId) {
        return profile.avatarUrl;
      }
    }

    return null;
  }

  /// Performs `_participantStatusIcon` for this feature. Update this documentation when its contract changes.
  Widget _participantStatusIcon(
    GroupWatchParticipant participant,
  ) {
    if (participant.isPending) {
      return const Icon(
        Icons.schedule_rounded,
        size: 19,
        color: Colors.orange,
      );
    }

    if (participant.isDeclined) {
      return const Icon(
        Icons.close_rounded,
        size: 20,
        color: Colors.red,
      );
    }

    if (participant.isExpired) {
      return const Icon(
        Icons.link_off_rounded,
        size: 19,
        color: Colors.orange,
      );
    }

    final ready = _hasAudio(participant);

    return Icon(
      ready
          ? Icons.check_circle_rounded
          : Icons.radio_button_unchecked,
      size: 20,
      color: ready
          ? Colors.green
          : Colors.grey.shade600,
    );
  }

  /// Performs `_controlsCard` for this feature. Update this documentation when its contract changes.
  Widget _controlsCard(GroupWatchSession session) {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!session.isPlayingStatus &&
                !session.isPaused)
              _lobbyControls(),
            if (session.isPlayingStatus)
              _playingControls(session),
            if (session.isPaused)
              _pausedControls(),
          ],
        ),
      ),
    );
  }

  /// Performs `_lobbyControls` for this feature. Update this documentation when its contract changes.
  Widget _lobbyControls() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _working || !_canStart ? null : _startSession,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 56),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              _allParticipantsReady
                  ? 'START WATCHING'
                  : 'WAITING FOR EVERYONE',
            ),
          ),
        ),
        if (!_allParticipantsReady) ...[
          const SizedBox(height: 11),
          Text(
            _isHost
                ? 'Everyone who accepted must choose their audio before playback can start.'
                : 'Choose your audio and wait for the host to start playback.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  /// Performs `_playingControls` for this feature. Update this documentation when its contract changes.
  Widget _playingControls(GroupWatchSession session) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: .08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: Colors.green.shade400,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Playback is synchronized',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatPosition(
                  session.playbackPosition,
                ),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed:
              _working ? null : _pauseSession,
          icon: const Icon(Icons.pause_rounded),
          label: const Text('PAUSE'),
        ),
      ],
    );
  }

  /// Performs `_pausedControls` for this feature. Update this documentation when its contract changes.
  Widget _pausedControls() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _working || !_canResume
                    ? null
                    : _resumeSession,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 54),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              _canResume
                  ? 'RESUME'
                  : 'WAITING TO RESUME',
            ),
          ),
        ),
        if (!_canResume) ...[
          const SizedBox(height: 10),
          Text(
            'The person who paused must return before playback can resume.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  /// Performs `_glassCard` for this feature. Update this documentation when its contract changes.
  Widget _glassCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: .065),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Performs `_infoRow` for this feature. Update this documentation when its contract changes.
  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 11),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  /// Performs `_avatar` for this feature. Update this documentation when its contract changes.
  Widget _avatar(
    String name,
    String? avatarUrl, {
    required bool highlighted,
  }) {
    final cleanUrl = avatarUrl?.trim() ?? '';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: highlighted
              ? Theme.of(context).colorScheme.primary
              : Colors.white.withValues(alpha: .08),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: ClipOval(
        child: cleanUrl.isEmpty
            ? _initialAvatar(name)
            : Image.network(
                cleanUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _initialAvatar(name);
                },
              ),
      ),
    );
  }

  /// Performs `_initialAvatar` for this feature. Update this documentation when its contract changes.
  Widget _initialAvatar(String name) {
    final first =
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      color: Colors.white.withValues(alpha: .055),
      alignment: Alignment.center,
      child: Text(
        first,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// Performs `_showParticipantsSheet` for this feature. Update this documentation when its contract changes.
  void _showParticipantsSheet(
    GroupWatchSession session,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final participants = _participants;

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .70,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                8,
                20,
                28,
              ),
              children: [
                const Text(
                  'Participants',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${participants.length} participant${participants.length == 1 ? '' : 's'} in this session',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 20),
                ...participants.map(
                  (participant) => _participantSheetRow(
                    participant,
                    session,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Performs `_participantSheetRow` for this feature. Update this documentation when its contract changes.
  Widget _participantSheetRow(
    GroupWatchParticipant participant,
    GroupWatchSession session,
  ) {
    final ready = _hasAudio(participant);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _avatar(
            participant.profileName,
            _findAvatar(participant.profileId),
            highlighted: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        participant.profileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (participant.profileId ==
                        session.hostProfileId) ...[
                      const SizedBox(width: 7),
                      const _MiniTag(label: 'HOST'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? '${_audioLabel(participant.audioTrackId)} · ${_subtitleLabel(participant.subtitleTrackId)}'
                      : _participantStatus(participant),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _participantStatusIcon(participant),
        ],
      ),
    );
  }

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: _buildBody(),
    );
  }
}

class _Track {
  final String id;
  final String label;
  final String description;
  final IconData icon;

  const _Track({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class _Heading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Heading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .035),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .055),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;

  const _MiniTag({
    required this.label,
  });

  @override
  /// Performs `build` for this feature. Update this documentation when its contract changes.
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: .12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context)
              .colorScheme
              .primary,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }
}
