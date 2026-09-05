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
  State<PlayerScreen> createState() =>
      _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double position = 0.0;

  bool videoFinished = false;
  bool creditsStarted = false;
  bool autoplayCancelled = false;

  int autoplaySeconds = 10;

  Timer? autoplayTimer;

  String selectedAudio = 'Original';

  bool subtitlesEnabled = false;
  String? selectedSubtitle;

  @override
  void initState() {
    super.initState();

    position = AppController.instance
        .getPlaybackProgress(widget.media.id)
        .clamp(0.0, 1.0)
        .toDouble();

    videoFinished = position >= 1.0;
  }

  @override
  void dispose() {
    autoplayTimer?.cancel();
    super.dispose();
  }

  void updatePosition(double value) {
    final newPosition =
        value.clamp(0.0, 1.0).toDouble();

    setState(() {
      position = newPosition;
    });

    AppController.instance.updatePlaybackProgress(
      widget.media.id,
      newPosition,
    );

    if (newPosition >= 0.999) {
      finishVideo();
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

    /*
     * The current AppController stores only the NEXT EPISODE TITLE.
     * It does not store a MediaItem for that episode.
     *
     * Therefore we cannot create a real next-episode PlayerScreen
     * yet. Show the title instead of trying to pass a String where
     * a MediaItem is required.
     */
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
            setState(() {
              selectedAudio = value;
            });
          },
          onSubtitleChanged: (value) {
            setState(() {
              selectedSubtitle = value;
              subtitlesEnabled =
                  value != null;
            });
          },
        );
      },
    );
  }

  void showGroupShare() {
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

    final session =
        controller.createGroupWatchSession(
      widget.media,
    );

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          'Group watch session created for ${session.title}.',
        ),
      ),
    );
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
                  if (!videoFinished)
                    Center(
                      child: IconButton(
                        onPressed: finishVideo,
                        iconSize: 80,
                        icon: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                        ),
                      ),
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
                            AppController.instance
                                .getNextEpisode(
                          widget.media.id,
                        ),
                        onCancel:
                            cancelAutoplay,
                        onPlayNow: () {
                          final next =
                              AppController
                                  .instance
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
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
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
            onChanged: videoFinished
                ? null
                : updatePosition,
          ),
          Row(
            children: [
              IconButton(
                onPressed: videoFinished
                    ? null
                    : () {
                        final newPosition =
                            (position - 0.05)
                                .clamp(0.0, 1.0)
                                .toDouble();

                        setState(() {
                          position =
                              newPosition;
                        });

                        AppController
                            .instance
                            .updatePlaybackProgress(
                          widget.media.id,
                          newPosition,
                        );
                      },
                icon: const Icon(
                  Icons.replay_10,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: videoFinished
                    ? null
                    : () {
                        finishVideo();
                      },
                icon: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: videoFinished
                    ? null
                    : () {
                        final newPosition =
                            (position + 0.05)
                                .clamp(0.0, 1.0)
                                .toDouble();

                        setState(() {
                          position =
                              newPosition;
                        });

                        AppController
                            .instance
                            .updatePlaybackProgress(
                          widget.media.id,
                          newPosition,
                        );

                        if (newPosition >=
                            0.999) {
                          finishVideo();
                        }
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
              IconButton(
                onPressed: showGroupShare,
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

            RadioGroup<String>(
              groupValue: selectedAudio,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedAudio = value;
                });

                widget.onAudioChanged(
                  value,
                );
              },
              child: const RadioListTile<String>(
                value: 'Original',
                title: Text(
                  'Original',
                  style: TextStyle(
                    color: Colors.white,
                  ),
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

            SwitchListTile(
              value: subtitlesEnabled,
              onChanged: (value) {
                setState(() {
                  subtitlesEnabled =
                      value;

                  if (!value) {
                    selectedSubtitle =
                        null;
                  } else {
                    selectedSubtitle =
                        'Default';
                  }
                });

                widget.onSubtitleChanged(
                  selectedSubtitle,
                );
              },
              title: const Text(
                'Subtitles',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),

            if (subtitlesEnabled)
              RadioGroup<String>(
                groupValue:
                    selectedSubtitle,
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    selectedSubtitle =
                        value;
                  });

                  widget.onSubtitleChanged(
                    value,
                  );
                },
                child:
                    const RadioListTile<String>(
                  value: 'Default',
                  title: Text(
                    'Default subtitles',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}