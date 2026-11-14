import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../app_core.dart';
import '../catalog_poster_image.dart';
import '../interface_experience.dart';
import '../models/media_case_style.dart';

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
    required this.onEmployeeSelected,
    required this.onMediaSelected,
    this.focusedMediaId,
  });

  final VirtualStoreDesign design;
  final List<StoreAisle> aisles;
  final List<MediaItem> posterMedia;
  final int activeZoneIndex;
  final List<String> zoneLabels;
  final ValueChanged<int> onZoneChanged;
  final VoidCallback onComputerSelected;
  final VoidCallback onEmployeeSelected;
  final ValueChanged<MediaItem> onMediaSelected;
  final String? focusedMediaId;

  @override
  State<VirtualStore3DScene> createState() => _VirtualStore3DSceneState();
}

class _VirtualStore3DSceneState extends State<VirtualStore3DScene> {
  final Scene _scene = Scene();
  final Map<int, PhysicallyBasedMaterial> _materials =
      <int, PhysicallyBasedMaterial>{};
  final Map<String, CuboidGeometry> _geometries = <String, CuboidGeometry>{};
  final List<MediaItem> _posterMedia = <MediaItem>[];
  final List<WidgetTextureController> _posterTextureControllers =
      <WidgetTextureController>[];
  final List<PhysicallyBasedMaterial> _posterMaterials =
      <PhysicallyBasedMaterial>[];
  final List<WidgetTextureController> _signTextureControllers =
      <WidgetTextureController>[];
  final List<PhysicallyBasedMaterial> _signMaterials =
      <PhysicallyBasedMaterial>[];
  final List<_StoreSignSpec> _signSpecs = <_StoreSignSpec>[];
  // Each controller drives one front-facing cover on a physical shelf case.
  // A fixed controller pool lets artwork refresh when the owned library loads
  // without rebuilding the native Scene graph.
  static const int _shelfCoverCount = 256;
  final List<MediaItem> _shelfCoverMedia = <MediaItem>[];
  final List<_StoreCaseHit> _caseHits = <_StoreCaseHit>[];
  final List<WidgetTextureController> _shelfTextureControllers =
      <WidgetTextureController>[];
  final List<PhysicallyBasedMaterial> _shelfMaterials =
      <PhysicallyBasedMaterial>[];
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
    for (var i = 0; i < _shelfCoverCount; i++) {
      final controller = WidgetTextureController();
      controller.addListener(() => _onShelfTextureChanged(i));
      _shelfTextureControllers.add(controller);
    }
    _refreshShelfSources();
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
    final oldIds = oldWidget.posterMedia
        .map((item) => '${item.id}|${item.imageUrl}|${item.displayCaseFormat}')
        .join('|');
    final newIds = widget.posterMedia
        .map((item) => '${item.id}|${item.imageUrl}|${item.displayCaseFormat}')
        .join('|');
    if (oldIds != newIds) {
      _refreshPosterSources();
      _refreshShelfSources();
    }
    if (oldWidget.focusedMediaId != widget.focusedMediaId &&
        widget.focusedMediaId != null) {
      _focusCameraOnMedia(widget.focusedMediaId);
    }
  }

  void _focusCameraOnMedia(String? mediaId) {
    if (mediaId == null || mediaId.isEmpty || _caseHits.isEmpty) return;
    _StoreCaseHit? match;
    for (final hit in _caseHits) {
      if (hit.media.id == mediaId) {
        match = hit;
        break;
      }
    }
    final selected = match;
    if (selected == null) return;
    final approach = selected.approachPosition ??
        vm.Vector3(selected.center.x, 1.72, selected.center.z - 1.8);
    // _walkX/_walkZ are offsets added to the selected zone's base camera
    // position, so convert the absolute approach point into zone-relative offsets.
    final aisleCount = widget.aisles.length;
    double baseX = 0;
    double baseZ = -2.0;
    if (widget.activeZoneIndex >= aisleCount) {
      if (widget.activeZoneIndex == aisleCount) {
        baseZ = 7.3;
      } else if (widget.activeZoneIndex == aisleCount + 1) {
        baseZ = -8.6;
      } else if (widget.activeZoneIndex == aisleCount + 2) {
        baseZ = -7.8;
      } else if (widget.activeZoneIndex == aisleCount + 3) {
        baseX = 5.8;
        baseZ = 1.0;
      } else {
        baseZ = -8.8;
      }
    } else {
      baseX = <double>[
        -5.1,
        -1.7,
        1.7,
        5.1
      ][widget.activeZoneIndex.clamp(0, 3).toInt()];
    }
    if (!mounted) return;
    setState(() {
      _walkX = (approach.x - baseX).clamp(-7.5, 7.5).toDouble();
      _walkZ = (approach.z - baseZ).clamp(-10.0, 10.0).toDouble();
      _yaw = selected.approachYaw ??
          math.atan2(selected.center.x - _walkX, selected.center.z - _walkZ);
      _pitch = -.04;
    });
  }

  void _refreshPosterSources() {
    for (final controller in _posterTextureControllers) {
      controller.dispose();
    }
    _posterMedia
      ..clear()
      ..addAll(widget.posterMedia.toList()
        ..shuffle(math.Random(DateTime.now().microsecondsSinceEpoch)));
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

  bool _isMusicMedia(MediaItem media) {
    final type = media.type.toLowerCase();
    final format =
        MediaCaseStyle.canonicalFormat(media.displayCaseFormat).toLowerCase();
    return type.contains('music') ||
        type.contains('album') ||
        type.contains('song') ||
        type.contains('track') ||
        format.contains('audio cd') ||
        format == 'cd';
  }

  void _refreshShelfSources() {
    _shelfCoverMedia
      ..clear()
      ..addAll(widget.posterMedia.isEmpty
          ? const <MediaItem>[]
          : List<MediaItem>.generate(
              _shelfCoverCount,
              (index) => widget.posterMedia[index % widget.posterMedia.length],
            ));
  }

  void _onShelfTextureChanged(int index) {
    if (index < 0 ||
        index >= _shelfMaterials.length ||
        index >= _shelfTextureControllers.length) {
      return;
    }
    final texture = _shelfTextureControllers[index].texture;
    if (texture != null) {
      _shelfMaterials[index].baseColorTexture = GpuTextureSource(texture);
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

  void _addTextPanel({
    required String label,
    required vm.Vector3 position,
    required double width,
    required double height,
    required Color background,
    Color foreground = Colors.white,
    double rotationY = 0,
  }) {
    final index = _signSpecs.length;
    final controller = WidgetTextureController();
    controller.addListener(() => _onSignTextureChanged(index));
    _signTextureControllers.add(controller);
    _signSpecs.add(_StoreSignSpec(
      label: label,
      background: background,
      foreground: foreground,
    ));
    final material = PhysicallyBasedMaterial()..roughnessFactor = .72;
    _signMaterials.add(material);
    final node = Node(
      mesh: Mesh(PlaneGeometry(width: width, depth: height), material),
    );
    node.position = position;
    node.rotation = vm.Quaternion.axisAngle(
          vm.Vector3(1, 0, 0),
          -math.pi / 2,
        ) *
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), rotationY);
    _scene.add(node);
  }

  void _onSignTextureChanged(int index) {
    if (index < 0 ||
        index >= _signMaterials.length ||
        index >= _signTextureControllers.length) {
      return;
    }
    final texture = _signTextureControllers[index].texture;
    if (texture != null) {
      _signMaterials[index].baseColorTexture = GpuTextureSource(texture);
    }
  }

  @override
  void dispose() {
    for (var i = 0; i < _posterTextureControllers.length; i++) {
      _posterTextureControllers[i].dispose();
    }
    for (final controller in _shelfTextureControllers) {
      controller.dispose();
    }
    for (final controller in _signTextureControllers) {
      controller.dispose();
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
    _caseHits.clear();
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
      _box(
          size: vm.Vector3(roomWidth, .18, roomDepth),
          position: vm.Vector3(0, -.12, 0),
          color: floor);
      _box(
          size: vm.Vector3(.24, wallHeight, roomDepth),
          position: vm.Vector3(-roomWidth / 2, wallHeight / 2, 0),
          color: wall);
      _box(
          size: vm.Vector3(.24, wallHeight, roomDepth),
          position: vm.Vector3(roomWidth / 2, wallHeight / 2, 0),
          color: wall);
      _box(
          size: vm.Vector3(roomWidth, wallHeight, .24),
          position: vm.Vector3(0, wallHeight / 2, roomDepth / 2),
          color: wall);
      _box(
          size: vm.Vector3(roomWidth, .16, roomDepth),
          position: vm.Vector3(0, wallHeight + .08, 0),
          color: shelf.withValues(alpha: .72));

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
          _box(
              size: vm.Vector3(.12, 3.25, .16),
              position: vm.Vector3(x + side * 1.42, 1.62, -2.0),
              color: rackColor);
          _box(
              size: vm.Vector3(.12, 3.25, .16),
              position: vm.Vector3(x + side * 1.42, 1.62, 9.1),
              color: rackColor);
        }
        for (var level = 0; level < 4; level++) {
          final y = .42 + level * .82;
          _box(
              size: vm.Vector3(2.95, .10, 11.3),
              position: vm.Vector3(x, y, 3.5),
              color: shelf);
          // Dense colored spines sit behind the artwork-facing cases.
          for (var slot = 0; slot < 20; slot++) {
            final z = -1.65 + slot * .54;
            final colors = <Color>[
              rackColor,
              accent,
              const Color(0xFF26394B),
              const Color(0xFF5B3434),
              const Color(0xFF343C32),
            ];
            final caseColor =
                colors[(slot + level * 2 + rackIndex) % colors.length];
            _box(
              size: vm.Vector3(.32, .62, .11),
              position: vm.Vector3(x - 1.18 + (slot % 8) * .33, y + .36, z),
              color: caseColor,
            );
          }

          // Actual library cover art is mounted on the aisle-facing side of
          // each rack. Covers are individual textured planes, sized like DVD
          // and Blu-ray fronts, not generic colored placeholders.
          if (_shelfCoverMedia.isNotEmpty) {
            for (var sideIndex = 0; sideIndex < 2; sideIndex++) {
              final facingSide = sideIndex == 0 ? -1.0 : 1.0;
              for (var cover = 0; cover < 8; cover++) {
                final textureIndex =
                    rackIndex * 64 + level * 16 + sideIndex * 8 + cover;
                final z = -1.8 + cover * .72;
                final media = _shelfCoverMedia[textureIndex];
                final format = MediaCaseStyle.canonicalFormat(
                  media.displayCaseFormat,
                ).toLowerCase();
                final isCd = format.contains('cd') || _isMusicMedia(media);
                final is4k = format.contains('4k') || format.contains('ultra');
                final isSteelbook = format.contains('steel');
                final caseBodyColor = isCd
                    ? const Color(0xFFB7C2C8)
                    : is4k
                        ? const Color(0xFF2B3546)
                        : isSteelbook
                            ? const Color(0xFF8D969F)
                            : format.contains('dvd')
                                ? const Color(0xFF243C59)
                                : const Color(0xFF263D50);
                // A thin physical case body sits behind each artwork face.
                // The cover remains a live texture from the owned library.
                final caseCenter = vm.Vector3(
                  x + facingSide * 1.455,
                  y + .36,
                  z,
                );
                _box(
                  size: vm.Vector3(
                    isCd ? .035 : .055,
                    isCd ? .58 : .72,
                    isCd ? .58 : .56,
                  ),
                  position: caseCenter,
                  color: caseBodyColor,
                );
                _caseHits.add(_StoreCaseHit(
                  media: media,
                  center: caseCenter,
                  halfExtents: vm.Vector3(
                    isCd ? .05 : .07,
                    isCd ? .31 : .38,
                    isCd ? .31 : .30,
                  ),
                  approachPosition: vm.Vector3(
                    caseCenter.x + facingSide * 1.7,
                    1.72,
                    caseCenter.z,
                  ),
                  approachYaw: facingSide > 0 ? -math.pi / 2 : math.pi / 2,
                ));
                final material = PhysicallyBasedMaterial()
                  ..roughnessFactor = .88;
                _shelfMaterials.add(material);
                final coverNode = Node(
                  mesh: Mesh(
                    PlaneGeometry(
                      width: isCd ? .62 : .56,
                      depth: isCd ? .62 : .72,
                    ),
                    material,
                  ),
                );
                coverNode.position = vm.Vector3(
                  x + facingSide * 1.49,
                  y + .36,
                  z,
                );
                coverNode.rotation = vm.Quaternion.axisAngle(
                      vm.Vector3(0, 1, 0),
                      facingSide * math.pi / 2,
                    ) *
                    vm.Quaternion.axisAngle(
                      vm.Vector3(1, 0, 0),
                      -math.pi / 2,
                    );
                _scene.add(coverNode);
                _onShelfTextureChanged(textureIndex);
              }
            }
          }
        }
        // Header sign suspended above each aisle.
        _box(
            size: vm.Vector3(2.8, .48, .18),
            position: vm.Vector3(x, 4.15, -1.5),
            color: rackColor);
        _box(
            size: vm.Vector3(.08, .62, .08),
            position: vm.Vector3(x - 1.05, 4.62, -1.5),
            color: accent);
        _box(
            size: vm.Vector3(.08, .62, .08),
            position: vm.Vector3(x + 1.05, 4.62, -1.5),
            color: accent);
        final aisleName = rackIndex < widget.aisles.length
            ? widget.aisles[rackIndex].name
            : 'MEDIA';
        _addTextPanel(
          label: aisleName.toUpperCase(),
          position: vm.Vector3(x, 4.15, -1.39),
          width: 2.55,
          height: .36,
          background: rackColor,
        );
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
          _caseHits.add(_StoreCaseHit(
            media: _posterMedia[i],
            center: vm.Vector3(x, 2.35, 12.22),
            halfExtents: vm.Vector3(.60, .86, .09),
            approachPosition: vm.Vector3(x, 1.72, 10.2),
            approachYaw: 0,
          ));
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
        _box(
            size: vm.Vector3(.10, 1.65, 1.2),
            position: vm.Vector3(-7.82, 2.3, -8 + i * 4.4),
            color: <Color>[
              accent,
              const Color(0xFF35516B),
              const Color(0xFF75453B)
            ][i % 3]);
      }

      // Back-of-store collection gallery: physical box-set pedestals and
      // stacked box forms, distinct from ordinary individual media cases.
      for (var i = 0; i < 5; i++) {
        final x = -5.2 + i * 2.6;
        _box(
            size: vm.Vector3(1.8, .22, 1.5),
            position: vm.Vector3(x, .18, 10.3),
            color: shelf);
        _box(
            size: vm.Vector3(.78, 1.05, .62),
            position: vm.Vector3(x - .42, .82, 10.3),
            color: <Color>[
              accent,
              const Color(0xFF4A526A),
              const Color(0xFF75513B)
            ][i % 3]);
        _box(
            size: vm.Vector3(.78, .12, .64),
            position: vm.Vector3(x - .42, 1.4, 10.3),
            color: const Color(0xFFD5C49B));
        _box(
            size: vm.Vector3(.68, .92, .58),
            position: vm.Vector3(x + .43, .75, 10.3),
            color: const Color(0xFF344C46));
      }

      // Music listening lounge: album/CD displays, speakers, soft seating and
      // a shared listening table in a dedicated front-of-store alcove.
      final albumTextureIndices = <int>[];
      for (var index = 0;
          index < _shelfCoverMedia.length && index < _shelfMaterials.length;
          index++) {
        if (_isMusicMedia(_shelfCoverMedia[index])) {
          albumTextureIndices.add(index);
        }
      }
      for (var i = 0; i < 4; i++) {
        final x = -5.4 + i * 3.6;
        _box(
            size: vm.Vector3(2.3, .18, 1.3),
            position: vm.Vector3(x, .18, -5.3),
            color: shelf);
        for (var cd = 0; cd < 7; cd++) {
          final caseX = x - .95 + cd * .31;
          _box(
            size: vm.Vector3(.29, .42, .035),
            position: vm.Vector3(caseX, .48, -5.3),
            color: const Color(0xFFB7C2C8),
          );
          if (albumTextureIndices.isNotEmpty) {
            final albumPosition = (i * 7 + cd) % albumTextureIndices.length;
            final coverIndex = albumTextureIndices[albumPosition];
            _caseHits.add(_StoreCaseHit(
              media: _shelfCoverMedia[coverIndex],
              center: vm.Vector3(caseX, .48, -5.3),
              halfExtents: vm.Vector3(.16, .23, .05),
              approachPosition: vm.Vector3(caseX, 1.72, -4.1),
              approachYaw: math.pi,
            ));
            final cdFace = Node(
              mesh: Mesh(
                PlaneGeometry(width: .265, depth: .36),
                _shelfMaterials[coverIndex],
              ),
            );
            cdFace.position = vm.Vector3(caseX, .48, -5.275);
            cdFace.rotation = vm.Quaternion.axisAngle(
              vm.Vector3(1, 0, 0),
              -math.pi / 2,
            );
            _scene.add(cdFace);
          }
        }
      }
      for (final x in const [-3.35, 3.35]) {
        // Sofa base, cushions, backrest and arm rests.
        _box(
            size: vm.Vector3(2.25, .28, .92),
            position: vm.Vector3(x, .42, -7.15),
            color: const Color(0xFF343B4A));
        _box(
            size: vm.Vector3(2.25, .68, .22),
            position: vm.Vector3(x, .82, -7.55),
            color: const Color(0xFF465064));
        _box(
            size: vm.Vector3(.22, .54, .92),
            position: vm.Vector3(x - 1.02, .66, -7.15),
            color: const Color(0xFF465064));
        _box(
            size: vm.Vector3(.22, .54, .92),
            position: vm.Vector3(x + 1.02, .66, -7.15),
            color: const Color(0xFF465064));
      }
      _box(
          size: vm.Vector3(1.8, .12, .85),
          position: vm.Vector3(0, .38, -6.65),
          color: const Color(0xFF6C5239));
      for (final x in const [-6.4, 6.4]) {
        _box(
            size: vm.Vector3(.62, 1.55, .55),
            position: vm.Vector3(x, .82, -5.45),
            color: const Color(0xFF202733));
        _box(
            size: vm.Vector3(.40, .40, .08),
            position: vm.Vector3(x, 1.05, -5.13),
            color: const Color(0xFF68778A));
        _box(
            size: vm.Vector3(.22, .22, .08),
            position: vm.Vector3(x, .62, -5.13),
            color: const Color(0xFFB48A56));
      }

      // Theater corridor: four framed room doors along the east wall.
      // The room dashboard below the 3D environment supplies the live session
      // labels and controls for these physical-looking entrances.
      for (var roomIndex = 0; roomIndex < 4; roomIndex++) {
        final z = -7.2 + roomIndex * 4.2;
        final roomAccent = <Color>[
          accent,
          const Color(0xFF536B83),
          const Color(0xFF8A654C),
          const Color(0xFF547765)
        ][roomIndex];
        _box(
            size: vm.Vector3(.18, 2.45, 1.92),
            position: vm.Vector3(7.72, 1.22, z),
            color: roomAccent.withValues(alpha: .82));
        _box(
            size: vm.Vector3(.28, 2.62, .14),
            position: vm.Vector3(7.57, 1.3, z - 1.0),
            color: const Color(0xFFD2B47C));
        _box(
            size: vm.Vector3(.28, 2.62, .14),
            position: vm.Vector3(7.57, 1.3, z + 1.0),
            color: const Color(0xFFD2B47C));
        _box(
            size: vm.Vector3(.28, .15, 2.12),
            position: vm.Vector3(7.57, 2.62, z),
            color: const Color(0xFFD2B47C));
        _box(
            size: vm.Vector3(.10, .42, .10),
            position: vm.Vector3(7.48, 1.28, z + .62),
            color: const Color(0xFFFFD78A));
      }

      // ------------------------------------------------------------------
      // Blockbuster-era storefront, feature displays and retail atmosphere.
      // All product artwork reuses live library textures; these are display
      // props only and do not introduce shopping, rentals or payments.
      // ------------------------------------------------------------------
      // Entrance marquee and open glass-door frame.
      _box(
          size: vm.Vector3(8.2, .34, .34),
          position: vm.Vector3(0, 4.12, -12.12),
          color: const Color(0xFF153B69));
      _box(
          size: vm.Vector3(8.0, .09, .38),
          position: vm.Vector3(0, 3.90, -12.10),
          color: const Color(0xFFE4C46D));
      for (final x in const [-3.75, 3.75]) {
        _box(
            size: vm.Vector3(.22, 3.15, .30),
            position: vm.Vector3(x, 1.58, -12.08),
            color: const Color(0xFF1D4776));
        _box(
            size: vm.Vector3(.06, 2.85, .035),
            position: vm.Vector3(x + (x < 0 ? .15 : -.15), 1.62, -11.91),
            color: const Color(0xFF87A7C1));
      }
      // Sliding-door leaves are kept slightly apart to leave the entrance open.
      for (final x in const [-.78, .78]) {
        _box(
            size: vm.Vector3(.045, 2.35, 1.08),
            position: vm.Vector3(x, 1.34, -12.04),
            color: const Color(0xFF56758D));
        _box(
            size: vm.Vector3(.035, .48, .05),
            position: vm.Vector3(x + (x < 0 ? .30 : -.30), 1.34, -11.98),
            color: const Color(0xFFD8C99C));
      }
      _addTextPanel(
        label: 'WELCOME  •  MOVIES  •  TV  •  MUSIC',
        position: vm.Vector3(0, 4.10, -11.91),
        width: 7.35,
        height: .28,
        background: const Color(0xFF153B69),
      );
      _addTextPanel(
        label: 'YOUR ENTERTAINMENT STORE',
        position: vm.Vector3(0, 3.24, -11.91),
        width: 3.8,
        height: .34,
        background: const Color(0xFF233C58),
      );
      // Branded entrance mat and floor runners help visually separate zones.
      _box(
          size: vm.Vector3(5.0, .025, 1.25),
          position: vm.Vector3(0, .015, -9.25),
          color: const Color(0xFF142F52));
      _box(
          size: vm.Vector3(4.72, .018, 1.02),
          position: vm.Vector3(0, .032, -9.25),
          color: const Color(0xFFD3B66F));
      for (final x in const [-3.4, 0.0, 3.4]) {
        _box(
            size: vm.Vector3(.10, .018, 17.6),
            position: vm.Vector3(x, .006, 1.2),
            color: const Color(0xFF273B55));
      }

      // New Releases end-cap tables near the entrance. The faces use the
      // same artwork materials as the stocked shelf cases.
      for (var display = 0; display < 2; display++) {
        final centerX = display == 0 ? -5.55 : 5.55;
        final tableColor = display == 0 ? accent : const Color(0xFF23466E);
        _box(
            size: vm.Vector3(2.45, .20, 1.35),
            position: vm.Vector3(centerX, .82, -7.95),
            color: tableColor);
        _box(
            size: vm.Vector3(.14, .76, .14),
            position: vm.Vector3(centerX - 1.0, .39, -7.95),
            color: shelf);
        _box(
            size: vm.Vector3(.14, .76, .14),
            position: vm.Vector3(centerX + 1.0, .39, -7.95),
            color: shelf);
        for (var slot = 0; slot < 4; slot++) {
          final caseX = centerX - .83 + slot * .55;
          _box(
            size: vm.Vector3(.06, .88, .58),
            position: vm.Vector3(caseX, 1.34, -7.82),
            color: const Color(0xFF26394B),
          );
          if (_shelfMaterials.isNotEmpty) {
            final materialIndex =
                (display * 8 + slot + 4) % _shelfMaterials.length;
            _caseHits.add(_StoreCaseHit(
              media: _shelfCoverMedia[materialIndex],
              center: vm.Vector3(caseX, 1.34, -7.82),
              halfExtents: vm.Vector3(.08, .46, .31),
              approachPosition: vm.Vector3(caseX, 1.72, -6.1),
              approachYaw: math.pi,
            ));
            final featureFace = Node(
              mesh: Mesh(
                PlaneGeometry(width: .53, depth: .78),
                _shelfMaterials[materialIndex],
              ),
            );
            featureFace.position = vm.Vector3(caseX, 1.34, -7.785);
            featureFace.rotation = vm.Quaternion.axisAngle(
              vm.Vector3(1, 0, 0),
              -math.pi / 2,
            );
            _scene.add(featureFace);
          }
        }
      }
      _addTextPanel(
        label: 'FEATURED FROM YOUR LIBRARY',
        position: vm.Vector3(0, 3.48, -8.65),
        width: 3.35,
        height: .42,
        background: const Color(0xFF173F70),
      );
      // A compact Staff Picks display sits just off the main walkway.
      _box(
          size: vm.Vector3(2.6, .15, .95),
          position: vm.Vector3(0, .70, -3.75),
          color: const Color(0xFF70502F));
      if (_shelfMaterials.isNotEmpty) {
        for (var pick = 0; pick < 3; pick++) {
          final materialIndex = (pick + 62) % _shelfMaterials.length;
          _caseHits.add(_StoreCaseHit(
            media: _shelfCoverMedia[materialIndex],
            center: vm.Vector3(-.72 + pick * .72, 1.20, -3.69),
            halfExtents: vm.Vector3(.34, .44, .08),
            approachPosition: vm.Vector3(-.72 + pick * .72, 1.72, -2.2),
            approachYaw: math.pi,
          ));
          final pickFace = Node(
            mesh: Mesh(PlaneGeometry(width: .62, depth: .80),
                _shelfMaterials[materialIndex]),
          );
          pickFace.position = vm.Vector3(-.72 + pick * .72, 1.20, -3.69);
          pickFace.rotation =
              vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -math.pi / 2);
          _scene.add(pickFace);
        }
      }
      _addTextPanel(
        label: 'FEATURED PICKS',
        position: vm.Vector3(0, 2.14, -3.75),
        width: 2.35,
        height: .34,
        background: const Color(0xFF70502F),
      );

      // Collector's glass cabinet and physical box-set zone at the back.
      _box(
          size: vm.Vector3(5.8, .12, .90),
          position: vm.Vector3(0, 1.18, 9.35),
          color: const Color(0xFF253647));
      _box(
          size: vm.Vector3(5.8, .055, .90),
          position: vm.Vector3(0, 2.28, 9.35),
          color: const Color(0xFF8EA2B3));
      for (final x in const [-2.85, 0.0, 2.85]) {
        _box(
            size: vm.Vector3(.055, 1.05, .82),
            position: vm.Vector3(x, 1.72, 9.35),
            color: const Color(0xFF7892A8));
      }
      _addTextPanel(
        label: "COLLECTOR'S CORNER",
        position: vm.Vector3(0, 3.0, 9.86),
        width: 5.35,
        height: .42,
        background: const Color(0xFF27394B),
      );

      // Music and listening signs. The CD cases below are textured with
      // indexed album artwork instead of generic colored rectangles.
      _addTextPanel(
        label: 'MUSIC & CDS  •  ALBUMS BY GENRE & ARTIST',
        position: vm.Vector3(-5.3, 2.18, -5.95),
        width: 3.8,
        height: .40,
        background: const Color(0xFF573E66),
      );
      _addTextPanel(
        label: 'LISTENING LOUNGE',
        position: vm.Vector3(0, 2.05, -7.95),
        width: 3.3,
        height: .36,
        background: const Color(0xFF344B50),
      );
      _addTextPanel(
        label: 'CATALOG COMPUTER',
        position: vm.Vector3(0, 2.95, -10.82),
        width: 2.5,
        height: .32,
        background: const Color(0xFF23466E),
      );
      _addTextPanel(
        label: 'PRIVATE THEATERS  →',
        position: vm.Vector3(7.40, 3.10, .6),
        width: 2.7,
        height: .38,
        background: const Color(0xFF27394B),
        rotationY: math.pi / 2,
      );
      _addTextPanel(
        label: 'COLLECTION GALLERY',
        position: vm.Vector3(0, 3.35, 11.88),
        width: 4.0,
        height: .42,
        background: const Color(0xFF344B50),
      );
      _addTextPanel(
        label: 'POSTER GALLERY',
        position: vm.Vector3(0, 3.78, 12.02),
        width: 3.4,
        height: .34,
        background: const Color(0xFF173F70),
      );

      // Ceiling fluorescent fixtures and support rails create the familiar
      // bright retail-store rhythm. These are static fixtures, not fake lights.
      for (var row = 0; row < 4; row++) {
        final z = -8.2 + row * 5.2;
        for (final x in const [-4.4, 0.0, 4.4]) {
          _box(
              size: vm.Vector3(2.5, .055, .24),
              position: vm.Vector3(x, 4.63, z),
              color: const Color(0xFFE0E6E9));
          _box(
              size: vm.Vector3(2.15, .018, .08),
              position: vm.Vector3(x, 4.59, z),
              color: const Color(0xFFB9C9D5));
        }
      }
      // Wall-mounted promo monitors: the screen glow is represented by a
      // bright inset panel and can later be replaced by live trailer textures.
      for (final z in const [-5.8, -.5, 4.8]) {
        _box(
            size: vm.Vector3(.16, 1.12, 1.75),
            position: vm.Vector3(7.78, 2.95, z),
            color: const Color(0xFF101820));
        _box(
            size: vm.Vector3(.06, .88, 1.46),
            position: vm.Vector3(7.66, 2.95, z),
            color: const Color(0xFF315875));
      }
      // Practical retail details: a security camera, exit marker, extinguisher
      // and display baskets. They are scene props only, not commerce controls.
      _box(
          size: vm.Vector3(.46, .12, .28),
          position: vm.Vector3(-7.45, 4.42, -11.2),
          color: const Color(0xFF222B36));
      _box(
          size: vm.Vector3(.10, .12, .18),
          position: vm.Vector3(-7.20, 4.34, -11.05),
          color: const Color(0xFF697C8B));
      _box(
          size: vm.Vector3(.62, .24, .08),
          position: vm.Vector3(6.9, 3.75, -11.98),
          color: const Color(0xFF267247));
      _box(
          size: vm.Vector3(.30, .74, .24),
          position: vm.Vector3(-7.45, .48, 8.3),
          color: const Color(0xFFB23C32));
      _box(
          size: vm.Vector3(.12, .12, .12),
          position: vm.Vector3(-7.45, .91, 8.3),
          color: const Color(0xFFE0D5C2));
      for (var basket = 0; basket < 2; basket++) {
        final x = 4.8 + basket * .72;
        _box(
            size: vm.Vector3(.52, .32, .42),
            position: vm.Vector3(x, .28, -9.0),
            color: const Color(0xFF244A73));
        _box(
            size: vm.Vector3(.46, .045, .34),
            position: vm.Vector3(x, .47, -9.0),
            color: const Color(0xFF9DB0C0));
      }

      // Entrance counter and interactive catalog-computer station.
      _box(
          size: vm.Vector3(3.6, 1.0, 1.0),
          position: vm.Vector3(0, .58, -10.7),
          color: shelf);
      _box(
          size: vm.Vector3(2.4, .12, 1.1),
          position: vm.Vector3(0, 1.15, -10.7),
          color: accent);
      _box(
          size: vm.Vector3(1.85, 1.15, .18),
          position: vm.Vector3(0, 1.86, -10.45),
          color: const Color(0xFF111820));
      _box(
          size: vm.Vector3(1.62, .88, .06),
          position: vm.Vector3(0, 1.88, -10.33),
          color: const Color(0xFF28506B));
      _box(
          size: vm.Vector3(.12, .32, .16),
          position: vm.Vector3(0, 1.22, -10.42),
          color: const Color(0xFF8995A2));
      _box(
          size: vm.Vector3(.94, .08, .42),
          position: vm.Vector3(0, 1.22, -9.95),
          color: const Color(0xFF202733));
      _box(
          size: vm.Vector3(.78, .035, .28),
          position: vm.Vector3(0, 1.28, -9.95),
          color: const Color(0xFF77828E));
      _box(
          size: vm.Vector3(2.0, .34, .10),
          position: vm.Vector3(0, 3.0, -10.70),
          color: accent);

      // A simple in-world store clerk stands behind the information counter.
      // The separate Talk to employee control opens the catalog-aware assistant.
      const clerkX = 1.35;
      const clerkZ = -11.52;
      const uniform = Color(0xFF233B55);
      const skin = Color(0xFFD2A17D);
      _box(
          size: vm.Vector3(.82, 1.05, .38),
          position: vm.Vector3(clerkX, 1.72, clerkZ),
          color: uniform);
      _box(
          size: vm.Vector3(.18, .48, .20),
          position: vm.Vector3(clerkX - .55, 1.78, clerkZ),
          color: uniform);
      _box(
          size: vm.Vector3(.18, .48, .20),
          position: vm.Vector3(clerkX + .55, 1.78, clerkZ),
          color: uniform);
      _box(
          size: vm.Vector3(.24, .20, .22),
          position: vm.Vector3(clerkX, 2.34, clerkZ),
          color: skin);
      _box(
          size: vm.Vector3(.48, .50, .42),
          position: vm.Vector3(clerkX, 2.68, clerkZ),
          color: skin);
      _box(
          size: vm.Vector3(.50, .15, .44),
          position: vm.Vector3(clerkX, 2.94, clerkZ),
          color: const Color(0xFF34271F));
      _box(
          size: vm.Vector3(.10, .34, .06),
          position: vm.Vector3(clerkX, 1.86, clerkZ - .205),
          color: accent);
      _box(
          size: vm.Vector3(.19, .11, .045),
          position: vm.Vector3(clerkX + .22, 2.05, clerkZ - .215),
          color: const Color(0xFFE2D7B8));

      // Reuse the project's authored GLB case and box models as hero props.
      // Each import is isolated so a missing/invalid optional model never
      // prevents the procedural store from opening.
      await _addModel(
          'assets/3d/cases/dvd_case.glb', vm.Vector3(-1.35, 1.35, -10.65), .72);
      await _addModel('assets/3d/cases/bluray_case.glb',
          vm.Vector3(-.45, 1.35, -10.65), .72);
      await _addModel('assets/3d/cases/steelbook_case.glb',
          vm.Vector3(.45, 1.35, -10.65), .72);
      await _addModel('assets/3d/cases/cd_jewel_case.glb',
          vm.Vector3(1.35, 1.35, -10.65), .72);
      await _addModel('assets/3d/collections/movie_collection_box.glb',
          vm.Vector3(-4.8, 1.05, 10.1), .9);
      await _addModel('assets/3d/collections/series_collection_box.glb',
          vm.Vector3(-1.6, 1.05, 10.1), .9);
      await _addModel('assets/3d/collections/music_collection_box.glb',
          vm.Vector3(1.6, 1.05, 10.1), .9);
      await _addModel('assets/3d/collections/playlist_box.glb',
          vm.Vector3(4.8, 1.05, 10.1), .9);

      if (mounted) {
        setState(() => _ready = true);
        _focusCameraOnMedia(widget.focusedMediaId);
      }
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
    if (zone == aisleCount + 3) {
      return math.pi / 2; // Face the theater doors on the east wall.
    }
    if (zone == aisleCount + 4) return math.pi; // Face the storefront entrance.
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
      } else if (zone == aisleCount + 3) {
        base = vm.Vector3(5.8, 1.9, 1.0);
      } else {
        // Entrance zone: stand just inside the store and face the doors/counter.
        base = vm.Vector3(0, 1.82, -8.8);
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

  void _handleSceneTap(Offset position, Size size, vm.Vector3 cameraPosition) {
    if (size.width <= 0 || size.height <= 0 || _caseHits.isEmpty) return;
    final target = vm.Vector3(
      cameraPosition.x + math.sin(_yaw) * 2.2,
      1.5 + _pitch,
      cameraPosition.z + math.cos(_yaw) * 8,
    );
    final forward = vm.Vector3(
      target.x - cameraPosition.x,
      target.y - cameraPosition.y,
      target.z - cameraPosition.z,
    )..normalize();
    final right = vm.Vector3(0, 1, 0).cross(forward)..normalize();
    final cameraUp = forward.cross(right)..normalize();
    final normalizedX = (position.dx / size.width) * 2 - 1;
    final normalizedY = 1 - (position.dy / size.height) * 2;
    const verticalFov = .92;
    final tangent = math.tan(verticalFov / 2);
    final aspect = size.width / size.height;
    final direction = vm.Vector3(
      forward.x +
          right.x * normalizedX * aspect * tangent +
          cameraUp.x * normalizedY * tangent,
      forward.y +
          right.y * normalizedX * aspect * tangent +
          cameraUp.y * normalizedY * tangent,
      forward.z +
          right.z * normalizedX * aspect * tangent +
          cameraUp.z * normalizedY * tangent,
    )..normalize();

    _StoreCaseHit? nearest;
    var nearestDistance = 12.0;
    for (final hit in _caseHits) {
      final distance = _rayBoxDistance(
        cameraPosition,
        direction,
        hit.center,
        hit.halfExtents,
      );
      if (distance != null && distance < nearestDistance) {
        nearestDistance = distance;
        nearest = hit;
      }
    }
    final selected = nearest;
    if (selected != null) widget.onMediaSelected(selected.media);
  }

  double? _rayBoxDistance(
    vm.Vector3 origin,
    vm.Vector3 direction,
    vm.Vector3 center,
    vm.Vector3 halfExtents,
  ) {
    final origins = <double>[origin.x, origin.y, origin.z];
    final directions = <double>[direction.x, direction.y, direction.z];
    final centers = <double>[center.x, center.y, center.z];
    final halves = <double>[halfExtents.x, halfExtents.y, halfExtents.z];
    var near = 0.0;
    var far = double.infinity;
    for (var axis = 0; axis < 3; axis++) {
      final minBound = centers[axis] - halves[axis];
      final maxBound = centers[axis] + halves[axis];
      final directionValue = directions[axis];
      if (directionValue.abs() < 0.000001) {
        if (origins[axis] < minBound || origins[axis] > maxBound) return null;
        continue;
      }
      var first = (minBound - origins[axis]) / directionValue;
      var second = (maxBound - origins[axis]) / directionValue;
      if (first > second) {
        final swap = first;
        first = second;
        second = swap;
      }
      if (first > near) near = first;
      if (second < far) far = second;
      if (near > far) return null;
    }
    if (far < 0) return null;
    return near > 0 ? near : far;
  }

  void _walk(double forward, double sideways) {
    final sinYaw = math.sin(_yaw);
    final cosYaw = math.cos(_yaw);
    setState(() {
      _walkX = (_walkX + sinYaw * forward + cosYaw * sideways)
          .clamp(-7.5, 7.5)
          .toDouble();
      _walkZ = (_walkZ + cosYaw * forward - sinYaw * sideways)
          .clamp(-10.0, 10.0)
          .toDouble();
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
        border: Border.all(
            color: Color(widget.design.accentColor).withValues(alpha: .7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          for (var i = 0; i < _signSpecs.length; i++)
            WidgetTexture(
              key: ValueKey('store-sign-texture-$i-${_signSpecs[i].label}'),
              controller: _signTextureControllers[i],
              width: 480,
              height: 84,
              pixelRatio: 1,
              child: SizedBox(
                width: 480,
                height: 84,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _signSpecs[i].background,
                    border:
                        Border.all(color: const Color(0xFFE0C57D), width: 4),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 3)),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        _signSpecs[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _signSpecs[i].foreground,
                          fontSize: _signSpecs[i].label.length > 30 ? 20 : 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 4)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < _shelfCoverMedia.length; i++)
            WidgetTexture(
              key: ValueKey('store-shelf-cover-$i-${_shelfCoverMedia[i].id}'),
              controller: _shelfTextureControllers[i],
              width: 96,
              height: 128,
              pixelRatio: 1,
              child: SizedBox(
                width: 96,
                height: 128,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CatalogPosterImage(
                      media: _shelfCoverMedia[i],
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      left: 2,
                      top: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xDD101820),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 2,
                          ),
                          child: Text(
                            (_isMusicMedia(_shelfCoverMedia[i])
                                    ? 'CD'
                                    : MediaCaseStyle.canonicalFormat(
                                        _shelfCoverMedia[i].displayCaseFormat,
                                      ))
                                .toUpperCase(),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 6,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                child: CatalogPosterImage(
                    media: _posterMedia[i], fit: BoxFit.cover),
              ),
            ),
          if (_ready)
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onPanUpdate: (details) => setState(() {
                  _yaw += details.delta.dx * .004;
                  _pitch = (_pitch + details.delta.dy * .002).clamp(-.42, .12);
                }),
                onTapUp: (details) => _handleSceneTap(
                  details.localPosition,
                  Size(constraints.maxWidth, constraints.maxHeight),
                  cameraPosition,
                ),
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
              ),
            )
          else
            Center(
              child: _failed
                  ? const Text('3D store could not initialize on this device.',
                      style: TextStyle(color: Colors.white70))
                  : const CircularProgressIndicator(),
            ),
          if (_ready)
            const IgnorePointer(
              child: Center(
                child: Icon(Icons.add_rounded, color: Colors.white70, size: 22),
              ),
            ),
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: Row(
              children: [
                const Icon(Icons.view_in_ar_rounded,
                    size: 18, color: Colors.white),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '3D STORE · ${widget.zoneLabels.isEmpty ? 'ENTRANCE' : widget.zoneLabels[widget.activeZoneIndex.clamp(0, widget.zoneLabels.length - 1).toInt()]}'
                        .toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        shadows: [Shadow(color: Colors.black, blurRadius: 6)]),
                  ),
                ),
                const Icon(Icons.pan_tool_alt_rounded,
                    size: 15, color: Colors.white70),
                const SizedBox(width: 4),
                const Text('DRAG TO LOOK  •  TAP A CASE TO INSPECT',
                    style: TextStyle(
                        fontSize: 8,
                        color: Colors.white70,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (widget.activeZoneIndex == widget.aisles.length + 2)
            Positioned(
              left: 12,
              right: 12,
              bottom: 58,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  FilledButton.icon(
                    onPressed: widget.onEmployeeSelected,
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('Talk to employee'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: widget.onComputerSelected,
                    icon: const Icon(Icons.computer_rounded),
                    label: const Text('Catalog computer'),
                  ),
                ],
              ),
            ),
          Positioned(
            right: 10,
            bottom: 54,
            child: Column(
              children: [
                _walkButton(
                    Icons.keyboard_arrow_up_rounded, () => _walk(1.0, 0)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _walkButton(Icons.keyboard_arrow_left_rounded,
                        () => _walk(0, -1.0)),
                    _walkButton(Icons.keyboard_arrow_down_rounded,
                        () => _walk(-1.0, 0)),
                    _walkButton(Icons.keyboard_arrow_right_rounded,
                        () => _walk(0, 1.0)),
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
                _moveButton(
                    Icons.chevron_left,
                    () => widget.onZoneChanged((widget.activeZoneIndex - 1)
                        .clamp(0, widget.zoneLabels.length - 1)
                        .toInt())),
                const SizedBox(width: 6),
                _moveButton(
                    Icons.chevron_right,
                    () => widget.onZoneChanged((widget.activeZoneIndex + 1)
                        .clamp(0, widget.zoneLabels.length - 1)
                        .toInt())),
                const Spacer(),
                Text(
                    '${widget.activeZoneIndex + 1}/${widget.zoneLabels.length}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
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

class _StoreSignSpec {
  const _StoreSignSpec({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

class _StoreCaseHit {
  const _StoreCaseHit({
    required this.media,
    required this.center,
    required this.halfExtents,
    this.approachPosition,
    this.approachYaw,
  });

  final MediaItem media;
  final vm.Vector3 center;
  final vm.Vector3 halfExtents;
  final vm.Vector3? approachPosition;
  final double? approachYaw;
}
