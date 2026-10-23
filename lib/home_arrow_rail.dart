import 'package:flutter/material.dart';

/// A reusable horizontal Home shelf with explicit previous/next controls.
/// Buttons move by most of the visible viewport and remain disabled at edges.
class HomeArrowRail extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;
  final double separatorExtent;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  const HomeArrowRail({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.separatorExtent = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 48),
    this.physics,
  });

  @override
  State<HomeArrowRail> createState() => _HomeArrowRailState();
}

class _HomeArrowRailState extends State<HomeArrowRail> {
  final ScrollController _controller = ScrollController();
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refreshEdges);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshEdges());
  }

  @override
  void didUpdateWidget(covariant HomeArrowRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshEdges());
    }
  }

  void _refreshEdges() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final back = position.pixels > 1;
    final forward = position.pixels < position.maxScrollExtent - 1;
    if (back != _canGoBack || forward != _canGoForward) {
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    }
  }

  void _scroll(bool forward) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final step = (position.viewportDimension * .78).clamp(180.0, 620.0);
    final target = (position.pixels + (forward ? step : -step))
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_refreshEdges);
    _controller.dispose();
    super.dispose();
  }

  Widget _arrow({required bool forward, required bool enabled, required bool rtl}) {
    final atLogicalStart = forward ? false : true;
    final icon = atLogicalStart
        ? (rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded)
        : (rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded);
    final label = forward ? 'Next items' : 'Previous items';
    return Tooltip(
      message: label,
      child: Material(
        color: const Color(0xE6171722),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? () => _scroll(forward) : null,
          child: SizedBox(
            width: 39,
            height: 45,
            child: Icon(
              icon,
              size: 25,
              color: enabled ? Colors.white : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) return const SizedBox.shrink();
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Initial edge state is refreshed after ListView lays out its extent.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshEdges());
    final showArrows = widget.itemCount > 1;
    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _refreshEdges();
              return false;
            },
            child: ListView.separated(
              controller: _controller,
              padding: widget.padding,
              scrollDirection: Axis.horizontal,
              physics: widget.physics,
              itemCount: widget.itemCount,
              separatorBuilder: (_, __) => SizedBox(width: widget.separatorExtent),
              itemBuilder: widget.itemBuilder,
            ),
          ),
          if (showArrows) ...[
            PositionedDirectional(
              start: 3,
              child: _arrow(
                forward: false,
                enabled: _canGoBack,
                rtl: rtl,
              ),
            ),
            PositionedDirectional(
              end: 3,
              child: _arrow(
                forward: true,
                enabled: _canGoForward,
                rtl: rtl,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
