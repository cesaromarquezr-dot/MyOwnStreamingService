import 'package:material_ui/material_ui.dart';

/// A horizontally browsable details-page rail with persistent Back/Next arrows.
///
/// The arrows scroll by most of the visible viewport, so they work for poster
/// cards as well as variable-width collection/playlist chips.
class MediaDetailArrowRail extends StatefulWidget {
  const MediaDetailArrowRail({
    super.key,
    required this.children,
    required this.height,
    this.spacing = 11,
    this.arrowInset = 2,
    this.scrollFraction = .82,
    this.semanticLabel = 'Related media',
  });

  final List<Widget> children;
  final double height;
  final double spacing;
  final double arrowInset;
  final double scrollFraction;
  final String semanticLabel;

  @override
  State<MediaDetailArrowRail> createState() => _MediaDetailArrowRailState();
}

class _MediaDetailArrowRailState extends State<MediaDetailArrowRail> {
  final ScrollController _controller = ScrollController();
  bool _canGoBack = false;
  bool _canGoNext = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateArrowState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrowState());
  }

  @override
  void didUpdateWidget(covariant MediaDetailArrowRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length ||
        oldWidget.height != widget.height) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrowState());
    }
  }

  void _updateArrowState() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final canGoBack = position.pixels > position.minScrollExtent + 1;
    final canGoNext = position.pixels < position.maxScrollExtent - 1;
    if (canGoBack != _canGoBack || canGoNext != _canGoNext) {
      setState(() {
        _canGoBack = canGoBack;
        _canGoNext = canGoNext;
      });
    }
  }

  Future<void> _move(bool forward) async {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final distance = (position.viewportDimension * widget.scrollFraction)
        .clamp(140.0, 620.0);
    final target = (position.pixels + (forward ? distance : -distance))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _updateArrowState();
  }

  Widget _arrow({required bool forward, required bool enabled}) {
    final icon =
        forward ? Icons.chevron_right_rounded : Icons.chevron_left_rounded;
    final label = forward
        ? 'Next ${widget.semanticLabel}'
        : 'Previous ${widget.semanticLabel}';
    return Material(
      color: Colors.black.withValues(alpha: .78),
      shape: const CircleBorder(),
      elevation: 5,
      child: IconButton(
        tooltip: label,
        onPressed: enabled ? () => _move(forward) : null,
        icon: Icon(icon, size: 27),
        color: Colors.white,
        disabledColor: Colors.white30,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_updateArrowState);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 43),
            itemCount: widget.children.length,
            separatorBuilder: (_, __) => SizedBox(width: widget.spacing),
            itemBuilder: (context, index) => widget.children[index],
          ),
          Positioned(
            left: widget.arrowInset,
            child: _arrow(forward: false, enabled: _canGoBack),
          ),
          Positioned(
            right: widget.arrowInset,
            child: _arrow(forward: true, enabled: _canGoNext),
          ),
        ],
      ),
    );
  }
}
