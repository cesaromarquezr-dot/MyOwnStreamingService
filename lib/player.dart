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

class _PlayerScreenState
    extends State<PlayerScreen> {
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
  void dispose() {
    autoplayTimer?.cancel();
    super.dispose();
  }

  void updatePosition(double value) {
    setState(() {
      position = value.clamp(0.0, 1.0);
    });

    AppController.instance.updateProgress(
      widget.media,
      position,
    );
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

    AppController.instance.markFinished(
      widget.media,
    );

    final nextEpisode =
        AppController.instance.getNextEpisode(
      widget.media,
    );

    if (nextEpisode == null ||
        autoplayCancelled) {
      return;
    }

    startAutoplayCountdown(
      nextEpisode,
    );
  }

  void startAutoplayCountdown(
    MediaItem nextEpisode,
  ) {
    autoplayTimer?.cancel();

    setState(() {
      autoplaySeconds = 10;
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
          playNextEpisode(nextEpisode);
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
    MediaItem nextEpisode,
  ) {
    autoplayTimer?.cancel();

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          media: nextEpisode,
        ),
      ),
    );
  }

  void openAudioSubtitleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      isScrollControlled: true,
      builder: (_) {
        return AudioSubtitleOptions(
          media: widget.media,
          selectedAudio: selectedAudio,
          subtitlesEnabled:
              subtitlesEnabled,
          selectedSubtitle:
              selectedSubtitle,
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

    if (controller.currentProfile == null) {
      return;
    }

    controller.createGroupWatchInvite(
      widget.media,
    );

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Group watch invitation created.',
        ),
      ),
    );
  }

  void showExtras() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: widget.media.extras.isEmpty
                ? const SizedBox(
                    height: 150,
                    child: Center(
                      child: Text(
                        'No extras are available.',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      const Text(
                        'EXTRAS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ...widget.media.extras.map(
                        (extra) => ListTile(
                          leading: const Icon(
                            Icons.movie_filter,
                            color: Colors.white,
                          ),
                          title: Text(
                            extra.title,
                            style:
                                const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          subtitle:
                              extra.description ==
                                      null
                                  ? null
                                  : Text(
                                      extra
                                          .description!,
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.grey,
                                      ),
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
                    child: widget.media.posterUrl !=
                                null &&
                            widget.media.posterUrl!
                                .isNotEmpty
                        ? Image.network(
                            widget.media.posterUrl!,
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

                  if (widget.media.isEpisode &&
                      videoFinished &&
                      !autoplayCancelled)
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child:
                          NextEpisodeCountdown(
                        seconds:
                            autoplaySeconds,
                        onCancel:
                            cancelAutoplay,
                        onPlayNow: () {
                          final next =
                              AppController
                                  .instance
                                  .getNextEpisode(
                            widget.media,
                          );

                          if (next != null) {
                            playNextEpisode(
                              next,
                            );
                          }
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
            onChanged: updatePosition,
          ),

          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    position =
                        (position - 0.05)
                            .clamp(0.0, 1.0);
                  });
                  AppController.instance
                      .updateProgress(
                    widget.media,
                    position,
                  );
                },
                icon: const Icon(
                  Icons.replay_10,
                  color: Colors.white,
                ),
              ),

              IconButton(
                onPressed: () {
                  if (!videoFinished) {
                    finishVideo();
                  }
                },
                icon: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                ),
              ),

              IconButton(
                onPressed: () {
                  setState(() {
                    position =
                        (position + 0.05)
                            .clamp(0.0, 1.0);
                  });
                  AppController.instance
                      .updateProgress(
                    widget.media,
                    position,
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

class NextEpisodeCountdown
    extends StatelessWidget {
  final int seconds;
  final VoidCallback onCancel;
  final VoidCallback onPlayNow;

  const NextEpisodeCountdown({
    super.key,
    required this.seconds,
    required this.onCancel,
    required this.onPlayNow,
  });

  @override
  Widget build(BuildContext context) {
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
              'Next episode starts in $seconds',
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

class AudioSubtitleOptions
    extends StatefulWidget {
  final MediaItem media;
  final String selectedAudio;
  final bool subtitlesEnabled;
  final String? selectedSubtitle;

  final ValueChanged<String> onAudioChanged;
  final ValueChanged<String?>
      onSubtitleChanged;

  const AudioSubtitleOptions({
    super.key,
    required this.media,
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
  String? selectedSubtitle;

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
    final audioTracks =
        widget.media.audioTracks;

    final subtitleTracks =
        widget.media.subtitleTracks;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
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

            if (audioTracks.isEmpty)
              const Text(
                'Original audio',
                style: TextStyle(
                  color: Colors.white,
                ),
              )
            else
              ...audioTracks.map(
                (track) => RadioListTile<
                    String>(
                  value: track.language,
                  groupValue:
                      selectedAudio,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      selectedAudio =
                          value;
                    });

                    widget.onAudioChanged(
                      value,
                    );
                  },
                  title: Text(
                    track.language,
                    style:
                        const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    track.format,
                    style:
                        const TextStyle(
                      color: Colors.grey,
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
                  }
                });

                widget.onSubtitleChanged(
                  value
                      ? selectedSubtitle
                      : null,
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
              ...subtitleTracks.map(
                (track) {
                  final label =
                      track.sdh
                          ? '${track.language} (SDH)'
                          : track.language;

                  return RadioListTile<
                      String>(
                    value: track.language,
                    groupValue:
                        selectedSubtitle,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        selectedSubtitle =
                            value;
                      });

                      widget
                          .onSubtitleChanged(
                        value,
                      );
                    },
                    title: Text(
                      label,
                      style:
                          const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}