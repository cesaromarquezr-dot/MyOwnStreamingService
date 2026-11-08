import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../app_core.dart';
import '../catalog_poster_image.dart';
import '../interface_experience.dart';

/// Procedurally-built, navigable 3D entertainment store.
///
/// Geometry is generated from the active Store design, so no extra model
/// downloads are needed. The media cards remain linked to the owned-library
/// browser below the scene; this view supplies the walkable physical space.
class VirtualStore3DScene extends StatefulWidget {
  const VirtualStore3DScene({
    super.key,
    required this.design,
    required this.aisles,
    required this.posterMedia,
    required this.activeZoneIndex,
    required this.zoneLabels,
    required this.onZoneChanged,
    required this.onComputerSelected,
  });

  final VirtualStoreDesign design;
  final List<StoreAisle> aisles;
  final List<MediaItem> posterMedia;
  final int activeZoneIndex;
  final List<String> zoneLabels;
  final ValueChanged<int> onZoneChanged;
  final VoidCallback onComputerSelected;

  @override
  State<VirtualStore3DScene> createState() => _VirtualStore3DSceneState();
}

class _VirtualStore3DSceneState extends State<VirtualStore3DScene> {
  final Scene _scene = Scene();
  final Map<int, PhysicallyBasedMaterial> _materials = <int, PhysicallyBasedMaterial>{};
  final Map<String, CuboidGeometry> _geometries = <String, CuboidGeometry>{};
  final List<MediaItem> _posterMedia = <MediaItem>[];
  final List<WidgetTextureController> _posterTextureControllers = <WidgetTextureController>[];
  final List<PhysicallyBasedMaterial> _posterMaterials = <PhysicallyBasedMaterial>[];
  bool _ready = false;
  bool _failed = false;
  double _yaw = 0;
  double _pitch = -.10;
  double _walkX = 0;
  double _walkZ = 0;

  @override
  void initState() {
    super.initState();
    _refreshPosterSources();
    _yaw = _defaultYawForZone(widget.activeZoneIndex);
    _buildScene();
  }

  @override
  void didUpdateWidget(covariant VirtualStore3DScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeZoneIndex != widget.activeZoneIndex) {
      _walkX = 0;
      _walkZ = 0;
      _yaw = _defaultYawForZone(widget.activeZoneIndex);
      _pitch = -.10;
    }
    final oldIds = oldWidget.posterMedia.map((item) => item.id).join('|');
    final newIds = widget.posterMedia.map((item) => item.id).join('|');
    if (oldIds != newIds) _refreshPosterSources();
  }

  void _refreshPosterSources() {
    for (final controller in _posterTextureControllers) {
      controller.dispose();
    }
    _posterMedia
      ..clear()
      ..addAll(widget.posterMedia.toList()..shuffle(math.Random(DateTime.now().microsecondsSinceEpoch)));
    if (_posterMedia.length > 7) {
      _posterMedia.removeRange(7, _posterMedia.length);
    }
    _posterTextureControllers.clear();
    for (var i = 0; i < _posterMedia.length; i++) {
      final controller = WidgetTextureController();
      controller.addListener(() => _onPosterTextureChanged(i));
      _posterTextureControllers.add(controller);
    }
  }

  void _onPosterTextureChanged(int index) {
    if (index < 0 || index >= _posterMaterials.length || index >= _posterTextureControllers.length) return;
    final texture = _posterTextureControllers[index].texture;
    if (texture != null) {
      _posterMaterials[index].baseColorTexture = GpuTextureSource(texture);
    }
  }

  @override
  void dispose() {
    for (var i = 0; i < _posterTextureControllers.length; i++) {
      _posterTextureControllers[i].dispose();
    }
    _scene.dispose();
    super.dispose();
  }

  Color _color(int value) => Color(value);

  PhysicallyBasedMaterial _material(Color color) {
    return _materials.putIfAbsent(color.toARGB32(), () {
      final material = PhysicallyBasedMaterial()..roughnessFactor = .82;
      material.baseColorFactor = vm.Vector4(
        color.r,
        color.g,
        color.b,
        color.a,
      );
      return material;
    });
  }

  void _box({
    required vm.Vector3 size,
    required vm.Vector3 position,
    required Color color,
    double rotationY = 0,
  }) {
    final geometryKey = '${size.x}:${size.y}:${size.z}';
    final geometry = _geometries.putIfAbsent(
      geometryKey,
      () => CuboidGeometry(size),
    );
    final node = Node(mesh: Mesh(geometry, _material(color)));
    node.position = position;
    if (rotationY != 0) {
      node.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), rotationY);
    }
    _scene.add(node);
  }

  Future<void> _buildScene() async {
    try {
      await Scene.initializeStaticResources();
      if (!mounted) return;

      final wall = _color(widget.design.wallColor);
      final floor = _color(widget.design.floorColor);
      final shelf = _color(widget.design.shelfColor);
      final accent = _color(widget.design.accentColor);
      const roomWidth = 16.0;
      const roomDepth = 25.0;
      const wallHeight = 4.8;

      // Floor, room shell and entrance framing.
      _box(size: vm.Vector3(roomWidth, .18, roomDepth), position: vm.Vector3(0, -.12, 0), color: floor);
      _box(size: vm.Vector3(.24, wallHeight, roomDepth), position: vm.Vector3(-roomWidth / 2, wallHeight / 2, 0), color: wall);
      _box(size: vm.Vector3(.24, wallHeight, roomDepth), position: vm.Vector3(roomWidth / 2, wallHeight / 2, 0), color: wall);
      _box(size: vm.Vector3(roomWidth, wallHeight, .24), position: vm.Vector3(0, wallHeight / 2, roomDepth / 2), color: wall);
      _box(size: vm.Vector3(roomWidth, .16, roomDepth), position: vm.Vector3(0, wallHeight + .08, 0), color: shelf.withValues(alpha: .72));

      // Main aisle racks: long double-sided shelving with multiple rows of
      // upright media cases. The open center lane is wide enough to walk.
      final rackXs = <double>[-5.1, -1.7, 1.7, 5.1];
      for (var rackIndex = 0; rackIndex < rackXs.length; rackIndex++) {
        final x = rackXs[rackIndex];
        final rackColor = rackIndex < widget.aisles.length
            ? Color(widget.aisles[rackIndex].color)
            : shelf;
        // Vertical end posts and long shelf boards.
        for (final side in const [-1.0, 1.0]) {
          _box(size: vm.Vector3(.12, 3.25, .16), position: vm.Vector3(x + side * 1.42, 1.62, -2.0), color: rackColor);
          _box(size: vm.Vector3(.12, 3.25, .16), position: vm.Vector3(x + side * 1.42, 1.62, 9.1), color: rackColor);
        }
        for (var level = 0; level < 4; level++) {
          final y = .42 + level * .82;
          _box(size: vm.Vector3(2.95, .10, 11.3), position: vm.Vector3(x, y, 3.5), color: shelf);
          // Media cases: alternating case colors make each shelf read as
          // a dense, physical row of DVD/Blu-ray/CD spines from the aisle.
          for (var slot = 0; slot < 20; slot++) {
            final z = -1.65 + slot * .54;
            final colors = <Color>[
              rackColor,
              accent,
              const Color(0xFF26394B),
              const Color(0xFF5B3434),
              const Color(0xFF343C32),
            ];
            final caseColor = colors[(slot + level * 2 + rackIndex) % colors.length];
            _box(
              size: vm.Vector3(.32, .62, .11),
              position: vm.Vector3(x - 1.18 + (slot % 8) * .33, y + .36, z),
              color: caseColor,
            );
          }
        }
        // Header sign suspended above each aisle.
        _box(size: vm.Vector3(2.8, .48, .18), position: vm.Vector3(x, 4.15, -1.5), color: rackColor);
        _box(size: vm.Vector3(.08, .62, .08), position: vm.Vector3(x - 1.05, 4.62, -1.5), color: accent);
        _box(size: vm.Vector3(.08, .62, .08), position: vm.Vector3(x + 1.05, 4.62, -1.5), color: accent);
      }

      // A real gallery wall: seven poster frames are backed by live WidgetTexture
      // captures of the selected library artwork, so the scene displays actual
      // movie, series and album covers instead of decorative color blocks.
      for (var i = 0; i < 7; i++) {
        final x = -6.9 + i * 2.3;
        final posterColor = <Color>[
          accent,
          const Color(0xFF263D55),
          const Color(0xFF713C35),
          const Color(0xFF365446),
        ][i % 4];
        _box(
          size: vm.Vector3(1.22, 1.78, .12),
          position: vm.Vector3(x, 2.35, 12.30),
          color: const Color(0xFF16191F),
        );
        _box(
          size: vm.Vector3(.055, 1.84, .10),
          position: vm.Vector3(x - .61, 2.35, 12.20),
          color: const Color(0xFFB99A61),
        );
        _box(
          size: vm.Vector3(.055, 1.84, .10),
          position: vm.Vector3(x + .61, 2.35, 12.20),
          color: const Color(0xFFB99A61),
        );
        if (i < _posterMedia.length) {
          final material = PhysicallyBasedMaterial()..roughnessFactor = .94;
          _posterMaterials.add(material);
          final posterNode = Node(
            mesh: Mesh(PlaneGeometry(width: 1.10, depth: 1.68), material),
          );
          posterNode.position = vm.Vector3(x, 2.35, 12.22);
          posterNode.rotation = vm.Quaternion.axisAngle(
            vm.Vector3(1, 0, 0),
            -math.pi / 2,
          );
          _scene.add(posterNode);
          _onPosterTextureChanged(i);
        } else {
          _box(
            size: vm.Vector3(1.10, 1.68, .035),
            position: vm.Vector3(x, 2.35, 12.22),
            color: posterColor,
          );
        }
      }
      for (var i = 0; i < 4; i++) {
        _box(size: vm.Vector3(.10, 1.65, 1.2), position: vm.Vector3(-7.82, 2.3, -8 + i * 4.4), color: <Color>[accent, const Color(0xFF35516B), const Color(0xFF75453B)][i % 3]);
      }

      // Back-of-store collection gallery: physical box-set pedestals and
      // stacked box forms, distinct from ordinary individual media cases.
      for (var i = 0; i < 5; i++) {
        final x = -5.2 + i * 2.6;
        _box(size: vm.Vector3(1.8, .22, 1.5), position: vm.Vector3(x, .18, 10.3), color: shelf);
        _box(size: vm.Vector3(.78, 1.05, .62), position: vm.Vector3(x - .42, .82, 10.3), color: <Color>[accent, const Color(0xFF4A526A), const Color(0xFF75513B)][i % 3]);
        _box(size: vm.Vector3(.78, .12, .64), position: vm.Vector3(x - .42, 1.4, 10.3), color: const Color(0xFFD5C49B));
        _box(size: vm.Vector3(.68, .92, .58), position: vm.Vector3(x + .43, .75, 10.3), color: const Color(0xFF344C46));
      }

      // Music listening lounge: album/CD displays, speakers, soft seating and
      // a shared listening table in a dedicated front-of-store alcove.
      for (var i = 0; i < 4; i++) {
        final x = -5.4 + i * 3.6;
        _box(size: vm.Vector3(2.3, .18, 1.3), position: vm.Vector3(x, .18, -5.3), color: shelf);
        for (var cd = 0; cd < 7; cd++) {
          _box(size: vm.Vector3(.34, .42, .12), position: vm.Vector3(x - .95 + cd * .31, .48, -5.3), color: <Color>[accent, const Color(0xFF455B70), const Color(0xFF71443C)][cd % 3]);
        }
      }
      for (final x in const [-3.35, 3.35]) {
        // Sofa base, cushions, backrest and arm rests.
        _box(size: vm.Vector3(2.25, .28, .92), position: vm.Vector3(x, .42, -7.15), color: const Color(0xFF343B4A));
        _box(size: vm.Vector3(2.25, .68, .22), position: vm.Vector3(x, .82, -7.55), color: const Color(0xFF465064));
        _box(size: vm.Vector3(.22, .54, .92), position: vm.Vector3(x - 1.02, .66, -7.15), color: const Color(0xFF465064));
        _box(size: vm.Vector3(.22, .54, .92), position: vm.Vector3(x + 1.02, .66, -7.15), color: const Color(0xFF465064));
      }
      _box(size: vm.Vector3(1.8, .12, .85), position: vm.Vector3(0, .38, -6.65), color: const Color(0xFF6C5239));
      for (final x in const [-6.4, 6.4]) {
        _box(size: vm.Vector3(.62, 1.55, .55), position: vm.Vector3(x, .82, -5.45), color: const Color(0xFF202733));
        _box(size: vm.Vector3(.40, .40, .08), position: vm.Vector3(x, 1.05, -5.13), color: const Color(0xFF68778A));
        _box(size: vm.Vector3(.22, .22, .08), position: vm.Vector3(x, .62, -5.13), color: const Color(0xFFB48A56));
      }

      // Theater corridor: four framed room doors along the east wall.
      // The room dashboard below the 3D environment supplies the live session
      // labels and controls for these physical-looking entrances.
      for (var roomIndex = 0; roomIndex < 4; roomIndex++) {
        final z = -7.2 + roomIndex * 4.2;
        final roomAccent = <Color>[accent, const Color(0xFF536B83), const Color(0xFF8A654C), const Color(0xFF547765)][roomIndex];
        _box(size: vm.Vector3(.18, 2.45, 1.92), position: vm.Vector3(7.72, 1.22, z), color: roomAccent.withValues(alpha: .82));
        _box(size: vm.Vector3(.28, 2.62, .14), position: vm.Vector3(7.57, 1.3, z - 1.0), color: const Color(0xFFD2B47C));
        _box(size: vm.Vector3(.28, 2.62, .14), position: vm.Vector3(7.57, 1.3, z + 1.0), color: const Color(0xFFD2B47C));
        _box(size: vm.Vector3(.28, .15, 2.12), position: vm.Vector3(7.57, 2.62, z), color: const Color(0xFFD2B47C));
        _box(size: vm.Vector3(.10, .42, .10), position: vm.Vector3(7.48, 1.28, z + .62), color: const Color(0xFFFFD78A));
      }

      // Entrance counter and interactive catalog-computer station.
      _box(size: vm.Vector3(3.6, 1.0, 1.0), position: vm.Vector3(0, .58, -10.7), color: shelf);
      _box(size: vm.Vector3(2.4, .12, 1.1), position: vm.Vector3(0, 1.15, -10.7), color: accent);
      _box(size: vm.Vector3(1.85, 1.15, .18), position: vm.Vector3(0, 1.86, -10.45), color: const Color(0xFF111820));
      _box(size: vm.Vector3(1.62, .88, .06), position: vm.Vector3(0, 1.88, -10.33), color: const Color(0xFF28506B));
      _box(size: vm.Vector3(.12, .32, .16), position: vm.Vector3(0, 1.22, -10.42), color: const Color(0xFF8995A2));
      _box(size: vm.Vector3(.94, .08, .42), position: vm.Vector3(0, 1.22, -9.95), color: const Color(0xFF202733));
      _box(size: vm.Vector3(.78, .035, .28), position: vm.Vector3(0, 1.28, -9.95), color: const Color(0xFF77828E));
      _box(size: vm.Vector3(2.0, .34, .10), position: vm.Vector3(0, 3.0, -10.70), color: accent);

      // Reuse the project's authored GLB case and box models as hero props.
      // Each import is isolated so a missing/invalid optional model never
      // prevents the procedural store from opening.
      await _addModel('assets/3d/cases/dvd_case.glb', vm.Vector3(-1.35, 1.35, -10.65), .72);
      await _addModel('assets/3d/cases/bluray_case.glb', vm.Vector3(-.45, 1.35, -10.65), .72);
      await _addModel('assets/3d/cases/steelbook_case.glb', vm.Vector3(.45, 1.35, -10.65), .72);
      await _addModel('assets/3d/cases/cd_jewel_case.glb', vm.Vector3(1.35, 1.35, -10.65), .72);
      await _addModel('assets/3d/collections/movie_collection_box.glb', vm.Vector3(-4.8, 1.05, 10.1), .9);
      await _addModel('assets/3d/collections/series_collection_box.glb', vm.Vector3(-1.6, 1.05, 10.1), .9);
      await _addModel('assets/3d/collections/music_collection_box.glb', vm.Vector3(1.6, 1.05, 10.1), .9);
      await _addModel('assets/3d/collections/playlist_box.glb', vm.Vector3(4.8, 1.05, 10.1), .9);

      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }


  Future<void> _addModel(String path, vm.Vector3 position, double scale) async {
    try {
      final model = await Node.fromGlbAsset(path);
      model.position = position;
      model.scale = vm.Vector3.all(scale);
      _scene.add(model);
    } catch (_) {
      // Keep the procedural shelf/box geometry as a graceful fallback.
    }
  }

  double _defaultYawForZone(int zone) {
    final aisleCount = widget.aisles.length;
    if (zone == aisleCount + 2) return math.pi; // Face the catalog terminal.
    if (zone == aisleCount + 3) return math.pi / 2; // Face the theater doors on the east wall.
    return 0;
  }

  vm.Vector3 _cameraPosition() {
    final zone = widget.activeZoneIndex;
    final aisleCount = widget.aisles.length;
    late final vm.Vector3 base;
    if (zone >= aisleCount) {
      if (zone == aisleCount) {
        base = vm.Vector3(0, 2.0, 7.3);
      } else if (zone == aisleCount + 1) {
        base = vm.Vector3(0, 1.9, -8.6);
      } else if (zone == aisleCount + 2) {
        base = vm.Vector3(0, 1.82, -7.8);
      } else {
        base = vm.Vector3(5.8, 1.9, 1.0);
      }
    } else {
      final x = <double>[-5.1, -1.7, 1.7, 5.1][zone.clamp(0, 3).toInt()];
      base = vm.Vector3(x, 1.72, -2.0);
    }
    return vm.Vector3(
      (base.x + _walkX).clamp(-7.2, 7.2).toDouble(),
      base.y,
      (base.z + _walkZ).clamp(-10.5, 10.5).toDouble(),
    );
  }

  void _walk(double forward, double sideways) {
    final sinYaw = math.sin(_yaw);
    final cosYaw = math.cos(_yaw);
    setState(() {
      _walkX = (_walkX + sinYaw * forward + cosYaw * sideways)
          .clamp(-7.5, 7.5).toDouble();
      _walkZ = (_walkZ + cosYaw * forward - sinYaw * sideways)
          .clamp(-10.0, 10.0).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraPosition = _cameraPosition();
    return Container(
      height: 440,
      decoration: BoxDecoration(
        color: Color(widget.design.floorColor),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(widget.design.accentColor).withValues(alpha: .7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          for (var i = 0; i < _posterMedia.length; i++)
            WidgetTexture(
              key: ValueKey('store-poster-texture-$i-${_posterMedia[i].id}'),
              controller: _posterTextureControllers[i],
              width: 180,
              height: 280,
              pixelRatio: 1.25,
              child: SizedBox(
                width: 180,
                height: 280,
                child: CatalogPosterImage(media: _posterMedia[i], fit: BoxFit.cover),
              ),
            ),
          if (_ready)
            GestureDetector(
              onPanUpdate: (details) => setState(() {
                _yaw += details.delta.dx * .004;
                _pitch = (_pitch + details.delta.dy * .002).clamp(-.42, .12);
              }),
              child: SceneView(
                _scene,
                camera: PerspectiveCamera(
                  position: cameraPosition,
                  target: vm.Vector3(
                    cameraPosition.x + math.sin(_yaw) * 2.2,
                    1.5 + _pitch,
                    cameraPosition.z + math.cos(_yaw) * 8,
                  ),
                  fovRadiansY: .92,
                ),
              ),
            )
          else
            Center(
              child: _failed
                  ? const Text('3D store could not initialize on this device.', style: TextStyle(color: Colors.white70))
                  : const CircularProgressIndicator(),
            ),
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: Row(
              children: [
                const Icon(Icons.view_in_ar_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '3D STORE · ${widget.zoneLabels.isEmpty ? 'ENTRANCE' : widget.zoneLabels[widget.activeZoneIndex.clamp(0, widget.zoneLabels.length - 1).toInt()]}'.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1, shadows: [Shadow(color: Colors.black, blurRadius: 6)]),
                  ),
                ),
                const Icon(Icons.pan_tool_alt_rounded, size: 15, color: Colors.white70),
                const SizedBox(width: 4),
                const Text('DRAG TO LOOK', style: TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (widget.activeZoneIndex == widget.aisles.length + 2)
            Positioned(
              left: 12,
              right: 12,
              bottom: 58,
              child: Center(
                child: FilledButton.icon(
                  onPressed: widget.onComputerSelected,
                  icon: const Icon(Icons.computer_rounded),
                  label: const Text('Use catalog computer'),
                ),
              ),
            ),
          Positioned(
            right: 10,
            bottom: 54,
            child: Column(
              children: [
                _walkButton(Icons.keyboard_arrow_up_rounded, () => _walk(1.0, 0)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _walkButton(Icons.keyboard_arrow_left_rounded, () => _walk(0, -1.0)),
                    _walkButton(Icons.keyboard_arrow_down_rounded, () => _walk(-1.0, 0)),
                    _walkButton(Icons.keyboard_arrow_right_rounded, () => _walk(0, 1.0)),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Row(
              children: [
                _moveButton(Icons.chevron_left, () => widget.onZoneChanged((widget.activeZoneIndex - 1).clamp(0, widget.zoneLabels.length - 1).toInt())),
                const SizedBox(width: 6),
                _moveButton(Icons.chevron_right, () => widget.onZoneChanged((widget.activeZoneIndex + 1).clamp(0, widget.zoneLabels.length - 1).toInt())),
                const Spacer(),
                Text('${widget.activeZoneIndex + 1}/${widget.zoneLabels.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _walkButton(IconData icon, VoidCallback onPressed) => Material(
        color: Colors.black.withValues(alpha: .72),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          tooltip: 'Walk',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 29, height: 29),
          padding: EdgeInsets.zero,
          color: Colors.white,
          icon: Icon(icon, size: 18),
        ),
      );

  Widget _moveButton(IconData icon, VoidCallback onPressed) => Material(
        color: Colors.black.withValues(alpha: .62),
        shape: const CircleBorder(),
        child: IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
          color: Colors.white,
          icon: Icon(icon),
          tooltip: icon == Icons.chevron_left ? 'Previous aisle' : 'Next aisle',
        ),
      );
}
