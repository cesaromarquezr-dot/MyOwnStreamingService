import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:share_plus/share_plus.dart';

class SocialVideoEditResult {
  const SocialVideoEditResult({
    required this.video,
    required this.coverBytes,
    required this.caption,
  });

  final File video;
  final Uint8List coverBytes;
  final String caption;
}

class SocialVideoEditorScreen extends StatefulWidget {
  const SocialVideoEditorScreen({required this.source, super.key});

  final File source;

  @override
  State<SocialVideoEditorScreen> createState() =>
      _SocialVideoEditorScreenState();
}

class _SocialVideoEditorScreenState extends State<SocialVideoEditorScreen> {
  static const _coverFrameCount = 7;

  final _captionController = TextEditingController();
  late final EditorVideo _sourceVideo = EditorVideo.file(widget.source.path);
  VideoMetadata? _metadata;
  List<Uint8List> _coverFrames = const [];
  RangeValues? _trim;
  int _coverIndex = 0;
  double _aspectRatio = 0;
  bool _loading = true;
  bool _rendering = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadVideo() async {
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(_sourceVideo);
      if (metadata.duration <= Duration.zero ||
          metadata.resolution.width <= 0 ||
          metadata.resolution.height <= 0) {
        throw StateError('The selected video has no readable duration or size.');
      }
      final durationSeconds = metadata.duration.inMilliseconds / 1000;
      final timestamps = List<Duration>.generate(
        _coverFrameCount,
        (index) => Duration(
          milliseconds:
              (durationSeconds * 1000 * index / _coverFrameCount).round(),
        ),
      );
      final frames = await ProVideoEditor.instance.getThumbnails(
        ThumbnailConfigs(
          video: _sourceVideo,
          outputSize: const Size(240, 360),
          timestamps: timestamps,
        ),
      );
      if (frames.isEmpty) {
        throw StateError('Could not create a cover frame from this video.');
      }
      if (!mounted) return;
      setState(() {
        _metadata = metadata;
        _coverFrames = frames;
        _trim = RangeValues(
          0,
          durationSeconds.clamp(0.1, 90).toDouble(),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open this video: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<Uint8List> _captionOverlay({
    required int width,
    required int height,
    required String caption,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final top = height * .68;
    canvas.drawRect(
      Rect.fromLTWH(0, top, width.toDouble(), height - top),
      Paint()..color = const Color(0x99000000),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: caption,
        style: TextStyle(
          color: Colors.white,
          fontSize: (width * .045).clamp(18, 64),
          fontWeight: FontWeight.w800,
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(1, 2)),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: width * .88);
    painter.paint(
      canvas,
      Offset((width - painter.width) / 2, top + height * .04),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null) throw StateError('Could not render the caption.');
    return bytes.buffer.asUint8List();
  }

  ExportTransform _cropTransform(Size sourceSize) {
    if (_aspectRatio == 0) return const ExportTransform();
    final sourceWidth = sourceSize.width.round();
    final sourceHeight = sourceSize.height.round();
    final sourceRatio = sourceWidth / sourceHeight;
    if (sourceRatio > _aspectRatio) {
      final cropWidth = (sourceHeight * _aspectRatio).round();
      return ExportTransform(
        width: cropWidth,
        height: sourceHeight,
        x: ((sourceWidth - cropWidth) / 2).round(),
        y: 0,
      );
    }
    final cropHeight = (sourceWidth / _aspectRatio).round();
    return ExportTransform(
      width: sourceWidth,
      height: cropHeight,
      x: 0,
      y: ((sourceHeight - cropHeight) / 2).round(),
    );
  }

  Future<void> _render({bool export = false}) async {
    final metadata = _metadata;
    final trim = _trim;
    if (metadata == null || trim == null || _coverFrames.isEmpty) return;
    final caption = _captionController.text.trim();
    if (caption.length > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captions can be up to 180 characters.')),
      );
      return;
    }
    setState(() => _rendering = true);
    try {
      final crop = _cropTransform(metadata.resolution);
      final frameWidth = crop.width ?? metadata.resolution.width.round();
      final frameHeight = crop.height ?? metadata.resolution.height.round();
      final imageLayers = caption.isEmpty
          ? const <ImageLayer>[]
          : <ImageLayer>[
              ImageLayer(
                image: EditorLayerImage.memory(
                  await _captionOverlay(
                    width: frameWidth,
                    height: frameHeight,
                    caption: caption,
                  ),
                ),
                offset: Offset.zero,
                size: Size(frameWidth.toDouble(), frameHeight.toDouble()),
              ),
            ];
      final directory = await getTemporaryDirectory();
      final output = File(
        '${directory.path}${Platform.pathSeparator}social_short_${DateTime.now().microsecondsSinceEpoch}.mp4',
      );
      final renderData = VideoRenderData(
        videoSegments: [
          VideoSegment(
            video: _sourceVideo,
            startTime: Duration(milliseconds: (trim.start * 1000).round()),
            endTime: Duration(milliseconds: (trim.end * 1000).round()),
          ),
        ],
        imageLayers: imageLayers,
        transform: crop,
        bitrate: 3500000,
        outputFormat: VideoOutputFormat.mp4,
        enableAudio: true,
        shouldOptimizeForNetworkUse: true,
      );
      final renderedPath = await ProVideoEditor.instance.renderVideoToFile(
        output.path,
        renderData,
      );
      final renderedFile = File(renderedPath);
      if (!await renderedFile.exists() || await renderedFile.length() == 0) {
        throw StateError('The editor did not produce a video file.');
      }
      if (!mounted) return;
      if (export) {
        try {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(renderedPath, mimeType: 'video/mp4')],
              text: caption.isEmpty ? null : caption,
              title: 'Share video',
            ),
          );
        } finally {
          if (await renderedFile.exists()) await renderedFile.delete();
        }
      } else {
        Navigator.of(context).pop(
          SocialVideoEditResult(
            video: renderedFile,
            coverBytes: _coverFrames[_coverIndex],
            caption: caption,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to render video: ${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  String _formatTime(double seconds) {
    final total = seconds.floor();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _metadata;
    final trim = _trim;
    final maxSeconds =
        metadata == null ? 90.0 : metadata.duration.inMilliseconds / 1000;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit short video')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : metadata == null || trim == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'This video could not be edited. Choose another local video and try again.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Trim to 90 seconds or less',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    RangeSlider(
                      min: 0,
                      max: maxSeconds,
                      values: trim,
                      labels: RangeLabels(
                        _formatTime(trim.start),
                        _formatTime(trim.end),
                      ),
                      onChanged: _rendering
                          ? null
                          : (value) {
                              if (value.end - value.start <= 90) {
                                setState(() => _trim = value);
                              }
                            },
                    ),
                    Text(
                      '${_formatTime(trim.start)} – ${_formatTime(trim.end)}  ·  ${_formatTime(trim.end - trim.start)}',
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<double>(
                      initialValue: _aspectRatio,
                      decoration: const InputDecoration(labelText: 'Crop'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Original')),
                        DropdownMenuItem(value: 1, child: Text('Square · 1:1')),
                        DropdownMenuItem(
                          value: 9 / 16,
                          child: Text('Portrait · 9:16'),
                        ),
                        DropdownMenuItem(
                          value: 16 / 9,
                          child: Text('Landscape · 16:9'),
                        ),
                      ],
                      onChanged: _rendering
                          ? null
                          : (value) => setState(() => _aspectRatio = value ?? 0),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _captionController,
                      maxLength: 180,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Burned-in caption (optional)',
                        hintText: 'Add a short caption to your video',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a cover frame',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _coverFrames.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => InkWell(
                          onTap: _rendering
                              ? null
                              : () => setState(() => _coverIndex = index),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: index == _coverIndex
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.memory(
                              _coverFrames[index],
                              width: 76,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _rendering ? null : () => _render(),
                      icon: _rendering
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_rendering ? 'Rendering…' : 'Use this video'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _rendering ? null : () => _render(export: true),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Export to another app'),
                    ),
                  ],
                ),
    );
  }
}
