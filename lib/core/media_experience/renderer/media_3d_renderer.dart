import 'package:flutter/widgets.dart';

/// Shared perspective renderer for the current Flutter-native 2.5D fallback.
/// The geometry assets in assets/3d are valid glTF 2.0 models; a GLB scene
/// runtime can replace this presentation layer without changing feature code.
class Media3DRenderer {
  const Media3DRenderer._();

  static Widget perspective({
    required Widget child,
    double rotateX = 0,
    double rotateY = -0.10,
    double rotateZ = 0,
    double perspective = 0.0012,
    Alignment alignment = Alignment.center,
  }) {
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, perspective)
      ..rotateX(rotateX)
      ..rotateY(rotateY)
      ..rotateZ(rotateZ);
    return Transform(alignment: alignment, transform: matrix, child: child);
  }
}
