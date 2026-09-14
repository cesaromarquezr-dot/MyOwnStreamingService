import 'package:flutter/material.dart';

/// Device/layout information shared by every screen in the application.
///
/// The metrics are recalculated whenever the available window size changes,
/// so desktop resizing, browser resizing, rotation, split-screen and TV
/// layouts can react without restarting the app.
class ResponsiveMetrics {
  final double width;
  final double height;

  const ResponsiveMetrics({required this.width, required this.height});

  double get shortestSide => width < height ? width : height;
  bool get isPhone => width < 600;
  bool get isTablet => width >= 600 && width < 1024;
  bool get isDesktop => width >= 1024 && width < 1600;
  bool get isTv => width >= 1600 || (shortestSide >= 900 && width >= 1280);
  bool get isPortrait => height > width;
  bool get isLandscape => width >= height;

  int get gridColumns {
    if (isPhone) return width < 380 ? 2 : 3;
    if (isTablet) return 4;
    if (isDesktop) return 5;
    return 6;
  }

  double get pagePadding {
    if (isPhone) return 12;
    if (isTablet) return 20;
    if (isDesktop) return 28;
    return 40;
  }

  double get contentMaxWidth {
    if (isPhone) return double.infinity;
    if (isTablet) return 1100;
    if (isDesktop) return 1500;
    return 1900;
  }

  double get controlHeight => isTv ? 64 : isPhone ? 48 : 54;

  double get spacing {
    if (isPhone) return 12;
    if (isTablet) return 16;
    if (isDesktop) return 20;
    return 24;
  }

  /// Returns a value appropriate for the current device class.
  T value<T>({
    required T phone,
    T? tablet,
    T? desktop,
    T? tv,
  }) {
    if (isTv && tv != null) return tv;
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return phone;
  }
}

class ResponsiveScope extends StatelessWidget {
  final Widget child;

  const ResponsiveScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = ResponsiveMetrics(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );

        return _ResponsiveInherited(
          metrics: metrics,
          child: child,
        );
      },
    );
  }
}

class _ResponsiveInherited extends InheritedWidget {
  final ResponsiveMetrics metrics;

  const _ResponsiveInherited({required this.metrics, required super.child});

  @override
  bool updateShouldNotify(_ResponsiveInherited oldWidget) {
    return oldWidget.metrics.width != metrics.width ||
        oldWidget.metrics.height != metrics.height;
  }
}

extension ResponsiveContext on BuildContext {
  ResponsiveMetrics get responsive {
    final inherited = dependOnInheritedWidgetOfExactType<_ResponsiveInherited>();
    if (inherited != null) return inherited.metrics;

    final size = MediaQuery.sizeOf(this);
    return ResponsiveMetrics(width: size.width, height: size.height);
  }

  bool get isPhone => responsive.isPhone;
  bool get isTablet => responsive.isTablet;
  bool get isDesktop => responsive.isDesktop;
  bool get isTv => responsive.isTv;
}

/// Keeps wide screens readable while preserving the full available width on
/// phones and tablets. All application routes are placed inside this shell.
class ResponsiveAppSurface extends StatelessWidget {
  final Widget child;

  const ResponsiveAppSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final metrics = context.responsive;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: metrics.contentMaxWidth),
        child: child,
      ),
    );
  }
}
