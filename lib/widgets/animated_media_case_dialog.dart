import 'package:material_ui/material_ui.dart';

import '../app_core.dart' hide MediaCollection;
import '../models/media_collection_models.dart';
import '../widgets/media_case_3d_view.dart';

/// Opens a format-aware, animated inspection view for a physical media case.
Future<void> showAnimatedMediaCaseDialog(
  BuildContext context, {
  required MediaItem media,
  String animationLevel = 'full',
  required VoidCallback onOpenTitle,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => _AnimatedMediaCaseDialog(
      media: media,
      animationLevel: animationLevel,
      onOpenTitle: onOpenTitle,
    ),
  );
}

/// Opens a box-set display. The box opens to reveal the real indexed contents.
Future<void> showAnimatedCollectionBoxDialog(
  BuildContext context, {
  required MediaCollection collection,
  String animationLevel = 'full',
  required VoidCallback onOpenCollection,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => _AnimatedCollectionBoxDialog(
      collection: collection,
      animationLevel: animationLevel,
      onOpenCollection: onOpenCollection,
    ),
  );
}

Duration _animationDuration(String level) => switch (level) {
      'minimal' => Duration.zero,
      'reduced' => const Duration(milliseconds: 260),
      _ => const Duration(milliseconds: 760),
    };

class _AnimatedMediaCaseDialog extends StatefulWidget {
  const _AnimatedMediaCaseDialog({
    required this.media,
    required this.animationLevel,
    required this.onOpenTitle,
  });

  final MediaItem media;
  final String animationLevel;
  final VoidCallback onOpenTitle;

  @override
  State<_AnimatedMediaCaseDialog> createState() =>
      _AnimatedMediaCaseDialogState();
}

class _AnimatedMediaCaseDialogState extends State<_AnimatedMediaCaseDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _open;

  bool get _isAudio {
    final type = widget.media.type.toLowerCase();
    return type.contains('music') ||
        type.contains('album') ||
        type.contains('song') ||
        type.contains('track') ||
        (widget.media.displayCaseFormat?.toLowerCase().contains('cd') ??
            false) ||
        (widget.media.displayCaseFormat?.toLowerCase().contains('vinyl') ??
            false);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration(widget.animationLevel),
    );
    _open = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCase() {
    if (_controller.isAnimating) return;
    if (_controller.value >= .5) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final coverWidth = _isAudio ? 184.0 : 160.0;
    final coverHeight = _isAudio ? 184.0 : 220.0;

    return Dialog(
      backgroundColor: const Color(0xFF17191D),
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isAudio ? 'Album / disc inspection' : 'Case inspection',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close inspection',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                media.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: _open,
                builder: (context, _) {
                  final progress = _open.value;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final coverLeft = ((availableWidth - coverWidth - 64) / 2)
                          .clamp(8.0, availableWidth - coverWidth - 8.0)
                          .toDouble();
                      final discSize = (availableWidth * .48)
                          .clamp(104.0, _isAudio ? 154.0 : 140.0)
                          .toDouble();
                      final maxDiscLeft = (availableWidth - discSize - 8.0)
                          .clamp(8.0, double.infinity)
                          .toDouble();
                      final discLeft = (coverLeft + coverWidth * .72)
                          .clamp(8.0, maxDiscLeft)
                          .toDouble();
                      return SizedBox(
                        height: 260,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: discLeft,
                              top: _isAudio ? 38 : 48,
                              child: Opacity(
                                opacity: progress,
                                child: Transform.rotate(
                                  angle: progress * 1.7,
                                  child: _DiscGraphic(
                                    label: _isAudio ? 'AUDIO CD' : 'DISC',
                                    accent: _isAudio
                                        ? const Color(0xFF84C8D8)
                                        : const Color(0xFF9DB7D6),
                                    size: discSize,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: coverLeft + 6,
                              top: _isAudio ? 30 : 18,
                              child: Container(
                                width: coverWidth + 10,
                                height: coverHeight + 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252A31),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 16,
                                      offset: Offset(5, 8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: coverLeft,
                              top: _isAudio ? 24 : 12,
                              child: Transform(
                                alignment: Alignment.centerLeft,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.002)
                                  ..translateByDouble(
                                      progress * -14.0, 0.0, 0.0, 1.0)
                                  ..rotateY(-progress * 1.12),
                                child: SizedBox(
                                  width: coverWidth,
                                  height: coverHeight,
                                  child: MediaCase3DView(
                                    title: media.title,
                                    media: media,
                                    width: coverWidth,
                                    height: coverHeight,
                                  ),
                                ),
                              ),
                            ),
                            if (progress > .72)
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .68),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: const Text(
                                    'DISC REVEALED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.1,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                _isAudio
                    ? 'Open the jewel case or sleeve to reveal the disc and album artwork.'
                    : 'Open the front cover to reveal the disc and inside case.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  AnimatedBuilder(
                    animation: _open,
                    builder: (context, _) {
                      final isOpen = _open.value >= .5;
                      return OutlinedButton.icon(
                        onPressed: _toggleCase,
                        icon: Icon(isOpen
                            ? Icons.close_fullscreen
                            : Icons.open_in_full),
                        label: Text(isOpen ? 'Close case' : 'Open case'),
                      );
                    },
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpenTitle();
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Open title'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedCollectionBoxDialog extends StatefulWidget {
  const _AnimatedCollectionBoxDialog({
    required this.collection,
    required this.animationLevel,
    required this.onOpenCollection,
  });

  final MediaCollection collection;
  final String animationLevel;
  final VoidCallback onOpenCollection;

  @override
  State<_AnimatedCollectionBoxDialog> createState() =>
      _AnimatedCollectionBoxDialogState();
}

class _AnimatedCollectionBoxDialogState
    extends State<_AnimatedCollectionBoxDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration(widget.animationLevel),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    return Dialog(
      backgroundColor: const Color(0xFF17191D),
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Collection box',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                collection.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress =
                      Curves.easeInOutCubic.transform(_controller.value);
                  return SizedBox(
                    height: 230,
                    width: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: 24,
                          left: 44,
                          right: 44,
                          child: Container(
                            height: 116,
                            decoration: BoxDecoration(
                              color: const Color(0xFF342B42),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white30),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final item
                                    in collection.orderedItems.take(3))
                                  Container(
                                    width: 48,
                                    height: 88,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF526078),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Center(
                                      child: Text(
                                        item.title,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 24 + progress * 118,
                          left: 36,
                          right: 36,
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.002)
                              ..rotateX(-progress * 1.18),
                            child: Container(
                              height: 108,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4C3D60),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white38),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 12,
                                      offset: Offset(0, 5)),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.collections_bookmark_rounded,
                                      size: 30),
                                  const SizedBox(height: 4),
                                  Text(
                                    collection.title,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Text(
                '${collection.itemCount} programs · ${collection.discCount} ${collection.discCount == 1 ? 'disc' : 'discs'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenCollection();
                },
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Browse collection contents'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscGraphic extends StatelessWidget {
  const _DiscGraphic(
      {required this.label, required this.accent, required this.size});

  final String label;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [
            const Color(0xFFB9C5D2),
            accent,
            const Color(0xFF6F8299),
            const Color(0xFFE1E7ED),
            accent,
            const Color(0xFFB9C5D2),
          ]),
          border: Border.all(color: Colors.white70, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54, blurRadius: 15, offset: Offset(5, 7)),
          ],
        ),
        alignment: Alignment.center,
        child: Container(
          width: size * .22,
          height: size * .22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1C2026),
            border: Border.all(color: Colors.white70, width: 2),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 6, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      );
}
