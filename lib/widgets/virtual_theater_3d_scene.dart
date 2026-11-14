import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../app_core.dart';
import '../catalog_poster_image.dart';

/// 360-degree private home auditorium. Drag to look in any direction and use
/// the on-screen pad to walk around the room. Poster covers remain linked to
/// real library items through [onPosterSelected].
class VirtualTheater3DScene extends StatefulWidget {
  const VirtualTheater3DScene({
    super.key,
    required this.posterMedia,
    required this.onPosterSelected,
    this.playbackActive = false,
  });

  final List<MediaItem> posterMedia;
  final ValueChanged<MediaItem> onPosterSelected;
  final bool playbackActive;

  @override
  State<VirtualTheater3DScene> createState() => _VirtualTheater3DSceneState();
}

class _VirtualTheater3DSceneState extends State<VirtualTheater3DScene> {
  final Scene _scene = Scene();
  final Map<int, PhysicallyBasedMaterial> _materials = {};
  final Map<String, CuboidGeometry> _geometries = {};
  final List<MediaItem> _posterMedia = [];
  final List<WidgetTextureController> _posterTextureControllers = [];
  final List<PhysicallyBasedMaterial> _posterMaterials = [];
  bool _ready = false;
  bool _failed = false;
  double _yaw = 0;
  double _pitch = -.04;
  double _walkX = 0;
  double _walkZ = -6.4;
  bool _cinemaMode = false;

  static const double _roomWidth = 22;
  static const double _roomDepth = 22;

  @override
  void initState() {
    super.initState();
    _cinemaMode = widget.playbackActive;
    _refreshPosters();
    _buildAuditorium();
  }

  @override
  void didUpdateWidget(covariant VirtualTheater3DScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackActive != widget.playbackActive) {
      _cinemaMode = widget.playbackActive;
    }
    final oldIds = oldWidget.posterMedia.map((item) => item.id).join('|');
    final newIds = widget.posterMedia.map((item) => item.id).join('|');
    if (oldIds != newIds) _refreshPosters();
  }

  void _refreshPosters() {
    for (final controller in _posterTextureControllers) {
      controller.dispose();
    }
    _posterMedia
      ..clear()
      ..addAll(widget.posterMedia.take(8));
    _posterTextureControllers.clear();
    for (var index = 0; index < _posterMedia.length; index++) {
      final controller = WidgetTextureController();
      controller.addListener(() => _onPosterTextureChanged(index));
      _posterTextureControllers.add(controller);
    }
  }

  void _onPosterTextureChanged(int index) {
    if (index < 0 ||
        index >= _posterMaterials.length ||
        index >= _posterTextureControllers.length) {
      return;
    }
    final texture = _posterTextureControllers[index].texture;
    if (texture != null) {
      _posterMaterials[index].baseColorTexture = GpuTextureSource(texture);
    }
  }

  PhysicallyBasedMaterial _material(Color color) {
    return _materials.putIfAbsent(color.toARGB32(), () {
      final material = PhysicallyBasedMaterial()..roughnessFactor = .86;
      material.baseColorFactor = vm.Vector4(color.r, color.g, color.b, color.a);
      return material;
    });
  }

  void _box({
    required vm.Vector3 size,
    required vm.Vector3 position,
    required Color color,
  }) {
    final key = '${size.x}:${size.y}:${size.z}';
    final geometry = _geometries.putIfAbsent(key, () => CuboidGeometry(size));
    final node = Node(mesh: Mesh(geometry, _material(color)))
      ..position = position;
    _scene.add(node);
  }

  Future<void> _buildAuditorium() async {
    try {
      await Scene.initializeStaticResources();
      if (!mounted) return;

      const floor = Color(0xFF171B24);
      const wall = Color(0xFF252B37);
      const trim = Color(0xFF98744D);
      const seat = Color(0xFF6B2633);
      const seatEdge = Color(0xFF3A1720);

      // Full room shell: floor, ceiling, front wall, rear wall and side walls.
      _box(
          size: vm.Vector3(_roomWidth, .22, _roomDepth),
          position: vm.Vector3(0, -.12, 0),
          color: floor);
      _box(
          size: vm.Vector3(_roomWidth, .20, _roomDepth),
          position: vm.Vector3(0, 7.15, 0),
          color: const Color(0xFF11151D));
      _box(
          size: vm.Vector3(.24, 7.2, _roomDepth),
          position: vm.Vector3(-_roomWidth / 2, 3.5, 0),
          color: wall);
      _box(
          size: vm.Vector3(.24, 7.2, _roomDepth),
          position: vm.Vector3(_roomWidth / 2, 3.5, 0),
          color: wall);
      _box(
          size: vm.Vector3(_roomWidth, 7.2, .24),
          position: vm.Vector3(0, 3.5, 11),
          color: wall);
      _box(
          size: vm.Vector3(_roomWidth, 7.2, .24),
          position: vm.Vector3(0, 3.5, -11),
          color: wall);

      // Wide cinema screen, stage and illuminated lower trim.
      _box(
          size: vm.Vector3(15.0, 6.0, .24),
          position: vm.Vector3(0, 3.75, 10.72),
          color: const Color(0xFF080B10));
      _box(
          size: vm.Vector3(14.4, 5.35, .08),
          position: vm.Vector3(0, 3.78, 10.55),
          color: const Color(0xFF172333));
      _box(
          size: vm.Vector3(15.8, .16, .28),
          position: vm.Vector3(0, .55, 10.45),
          color: trim);
      _box(
          size: vm.Vector3(16.2, .20, .55),
          position: vm.Vector3(0, .20, 10.2),
          color: const Color(0xFF242A34));

      // Tiered rows with individual seats, backs, bases and armrests.
      const columns = <double>[-8.1, -6.0, -3.9, -1.8, 1.8, 3.9, 6.0, 8.1];
      for (var row = 0; row < 5; row++) {
        final z = -5.0 + row * 2.35;
        final y = .32 + row * .18;
        for (final x in columns) {
          _box(
              size: vm.Vector3(1.40, .28, 1.20),
              position: vm.Vector3(x, y, z),
              color: seatEdge);
          _box(
              size: vm.Vector3(1.24, .26, .92),
              position: vm.Vector3(x, y + .20, z + .05),
              color: seat);
          _box(
              size: vm.Vector3(1.24, 1.02, .22),
              position: vm.Vector3(x, y + .78, z - .43),
              color: seat);
          _box(
              size: vm.Vector3(.16, .52, .95),
              position: vm.Vector3(x - .69, y + .48, z),
              color: seatEdge);
          _box(
              size: vm.Vector3(.16, .52, .95),
              position: vm.Vector3(x + .69, y + .48, z),
              color: seatEdge);
        }
      }

      // Step lights along side aisles and acoustic wall panels.
      for (var row = 0; row < 7; row++) {
        final z = -8.5 + row * 2.7;
        for (final x in const [-10.55, 10.55]) {
          _box(
              size: vm.Vector3(.08, .16, .48),
              position: vm.Vector3(x, .42, z),
              color: const Color(0xFFE4B66B));
          _box(
              size: vm.Vector3(.12, 1.7, .18),
              position: vm.Vector3(x, 3.6, z),
              color: trim);
        }
      }

      // Rear poster wall. Actual catalog posters are attached as GPU textures
      // after the Flutter poster widgets below have painted.
      for (var index = 0; index < 8; index++) {
        final x = -8.4 + index * 2.4;
        _box(
            size: vm.Vector3(1.65, 2.45, .16),
            position: vm.Vector3(x, 3.1, -10.72),
            color: trim);
        if (index < _posterMedia.length) {
          final material = PhysicallyBasedMaterial()..roughnessFactor = .94;
          _posterMaterials.add(material);
          final poster = Node(
              mesh: Mesh(PlaneGeometry(width: 1.48, depth: 2.25), material));
          poster.position = vm.Vector3(x, 3.1, -10.61);
          poster.rotation =
              vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -math.pi / 2);
          _scene.add(poster);
          _onPosterTextureChanged(index);
        } else {
          _box(
              size: vm.Vector3(1.45, 2.24, .04),
              position: vm.Vector3(x, 3.1, -10.60),
              color: const Color(0xFF313B49));
        }
      }

      // Ceiling coves, wall trim and rear entrance doorway.
      _box(
          size: vm.Vector3(18.5, .12, .14),
          position: vm.Vector3(0, 6.6, 0),
          color: trim);
      _box(
          size: vm.Vector3(.18, 4.0, 1.8),
          position: vm.Vector3(-8.5, 2.0, -10.76),
          color: const Color(0xFF11151D));
      _box(
          size: vm.Vector3(.18, 4.0, 1.8),
          position: vm.Vector3(8.5, 2.0, -10.76),
          color: const Color(0xFF11151D));

      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _walk(double forward, double sideways) {
    final sinYaw = math.sin(_yaw);
    final cosYaw = math.cos(_yaw);
    setState(() {
      _walkX = (_walkX + (sinYaw * forward) + (cosYaw * sideways))
          .clamp(-8.7, 8.7)
          .toDouble();
      _walkZ = (_walkZ + (cosYaw * forward) - (sinYaw * sideways))
          .clamp(-8.4, 8.4)
          .toDouble();
    });
  }

  void _resetView() {
    setState(() {
      _yaw = 0;
      _pitch = -.04;
      _walkX = 0;
      _walkZ = -6.4;
    });
  }

  void _chooseViewingPosition(String position) {
    setState(() {
      _yaw = 0;
      _pitch = -.04;
      _walkX = 0;
      _walkZ = switch (position) {
        'Front' => 5.8,
        'Rear' => -8.2,
        _ => -1.3,
      };
    });
  }

  @override
  void dispose() {
    for (final controller in _posterTextureControllers) {
      controller.dispose();
    }
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraPosition = vm.Vector3(_walkX, 1.72, _walkZ);
    final target = vm.Vector3(
      cameraPosition.x + math.sin(_yaw) * 8,
      1.55 + _pitch,
      cameraPosition.z + math.cos(_yaw) * 8,
    );

    return Container(
      height: 480,
      decoration: BoxDecoration(
        color: const Color(0xFF111722),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFFB48A56).withValues(alpha: .65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          for (var index = 0; index < _posterMedia.length; index++)
            WidgetTexture(
              key: ValueKey('theater-poster-${_posterMedia[index].id}'),
              controller: _posterTextureControllers[index],
              width: 180,
              height: 280,
              pixelRatio: 1.2,
              child: SizedBox(
                width: 180,
                height: 280,
                child: CatalogPosterImage(
                    media: _posterMedia[index], fit: BoxFit.cover),
              ),
            ),
          if (_ready)
            GestureDetector(
              onPanUpdate: (details) => setState(() {
                _yaw += details.delta.dx * .004;
                _pitch = (_pitch + details.delta.dy * .002)
                    .clamp(-.48, .42)
                    .toDouble();
              }),
              child: SceneView(
                _scene,
                camera: PerspectiveCamera(
                  position: cameraPosition,
                  target: target,
                  fovRadiansY: .94,
                ),
              ),
            )
          else
            Center(
              child: _failed
                  ? const Text(
                      'The 3D auditorium could not initialize on this device.',
                      style: TextStyle(color: Colors.white70))
                  : const CircularProgressIndicator(),
            ),
          if (_cinemaMode)
            const Positioned.fill(
              child: IgnorePointer(child: ColoredBox(color: Color(0x33000000))),
            ),
          Positioned(
            left: 12,
            top: 52,
            right: 12,
            child: Align(
              alignment: Alignment.topRight,
              child: Material(
                color: Colors.black.withValues(alpha: .62),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  child: Wrap(
                    spacing: 3,
                    children: [
                      for (final position in const ['Front', 'Middle', 'Rear'])
                        TextButton(
                          onPressed: () => _chooseViewingPosition(position),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(position,
                              style: const TextStyle(fontSize: 10)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: Row(
              children: [
                const Icon(Icons.threed_rotation_rounded,
                    color: Color(0xFFE4B66B), size: 19),
                const SizedBox(width: 7),
                const Expanded(
                    child: Text('360° PRIVATE AUDITORIUM',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 7)
                            ]))),
                IconButton.filledTonal(
                  tooltip: 'Reset view',
                  visualDensity: VisualDensity.compact,
                  onPressed: _resetView,
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 17),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  tooltip: _cinemaMode
                      ? 'Turn lobby lights back on'
                      : 'Dim auditorium lights',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _cinemaMode = !_cinemaMode),
                  icon: Icon(
                      _cinemaMode
                          ? Icons.lightbulb_rounded
                          : Icons.lightbulb_outline_rounded,
                      size: 17),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Column(
              children: [
                _walkButton(Icons.keyboard_arrow_up_rounded, 'Walk forward',
                    () => _walk(1.15, 0)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _walkButton(Icons.keyboard_arrow_left_rounded, 'Walk left',
                        () => _walk(0, -1.15)),
                    const SizedBox(width: 3),
                    _walkButton(Icons.keyboard_arrow_down_rounded,
                        'Walk backward', () => _walk(-1.15, 0)),
                    const SizedBox(width: 3),
                    _walkButton(Icons.keyboard_arrow_right_rounded,
                        'Walk right', () => _walk(0, 1.15)),
                  ],
                ),
              ],
            ),
          ),
          const Positioned(
            right: 14,
            bottom: 20,
            child: IgnorePointer(
              child: Text('DRAG TO LOOK AROUND',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)])),
            ),
          ),
        ],
      ),
    );
  }

  Widget _walkButton(IconData icon, String tooltip, VoidCallback action) =>
      Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: Colors.black.withValues(alpha: .72),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tooltip,
            onPressed: action,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            color: Colors.white,
            icon: Icon(icon, size: 20),
          ),
        ),
      );
}
