import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

/// Per-profile, per-title local theme assets. Files are copied into app storage;
/// the original media library is never renamed or modified.
class CinematicThemeAssets {
  const CinematicThemeAssets({this.themeSongPath, this.themeVideoPath});
  final String? themeSongPath;
  final String? themeVideoPath;

  static String _key(String profileId, String mediaId, String kind) =>
      'cinematic_theme_${kind}_${profileId}_$mediaId';

  static Future<CinematicThemeAssets> load(
      {required String profileId, required String mediaId}) async {
    final p = await SharedPreferences.getInstance();
    return CinematicThemeAssets(
      themeSongPath: p.getString(_key(profileId, mediaId, 'song')),
      themeVideoPath: p.getString(_key(profileId, mediaId, 'video')),
    );
  }

  static Future<String?> importAsset(
      {required String profileId,
      required String mediaId,
      required bool video}) async {
    // file_picker 12.x exposes static methods and returns a PlatformFile
    // directly for single-file selection.
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions:
          video ? ['mp4', 'mov', 'm4v'] : ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
    );
    final source = picked?.path;
    if (source == null || source.isEmpty) return null;
    final root = await getApplicationSupportDirectory();
    final folder =
        Directory('${root.path}/cinematic_themes/$profileId/$mediaId');
    await folder.create(recursive: true);
    final extension = source.split('.').last.toLowerCase();
    final target =
        '${folder.path}/${video ? 'theme_video' : 'theme_song'}.$extension';
    await File(source).copy(target);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key(profileId, mediaId, video ? 'video' : 'song'), target);
    return target;
  }

  static Future<void> clear(
      {required String profileId,
      required String mediaId,
      required bool video}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(profileId, mediaId, video ? 'video' : 'song');
    final path = prefs.getString(key);
    await prefs.remove(key);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}

class CinematicThemeAssetEditor extends StatefulWidget {
  const CinematicThemeAssetEditor(
      {super.key,
      required this.profileId,
      required this.mediaId,
      required this.title,
      required this.isTv});
  final String profileId;
  final String mediaId;
  final String title;
  final bool isTv;
  @override
  State<CinematicThemeAssetEditor> createState() =>
      _CinematicThemeAssetEditorState();
}

class _CinematicThemeAssetEditorState extends State<CinematicThemeAssetEditor> {
  CinematicThemeAssets _assets = const CinematicThemeAssets();
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await CinematicThemeAssets.load(
        profileId: widget.profileId, mediaId: widget.mediaId);
    if (mounted) {
      setState(() {
        _assets = value;
        _loading = false;
      });
    }
  }

  Future<void> _pick(bool video) async {
    await CinematicThemeAssets.importAsset(
        profileId: widget.profileId, mediaId: widget.mediaId, video: video);
    await _load();
  }

  Future<void> _remove(bool video) async {
    await CinematicThemeAssets.clear(
        profileId: widget.profileId, mediaId: widget.mediaId, video: video);
    await _load();
  }

  Widget _assetRow(String label, String? path, bool video) => ListTile(
        leading: Icon(video ? Icons.movie_outlined : Icons.music_note),
        title: Text(label),
        subtitle: Text(
            path == null
                ? 'Not configured'
                : path.split(Platform.pathSeparator).last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        trailing: Wrap(spacing: 4, children: [
          IconButton(
              tooltip: 'Import $label',
              onPressed: () => _pick(video),
              icon: const Icon(Icons.file_upload_outlined)),
          if (path != null)
            IconButton(
                tooltip: 'Remove $label',
                onPressed: () => _remove(video),
                icon: const Icon(Icons.delete_outline))
        ]),
      );
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Cinematic themes · ${widget.title}'),
        content: _loading
            ? const SizedBox(
                height: 60, child: Center(child: CircularProgressIndicator()))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.isTv)
                  _assetRow('TV theme song', _assets.themeSongPath, false),
                if (!widget.isTv)
                  _assetRow('Movie theme video', _assets.themeVideoPath, true),
                const SizedBox(height: 8),
                const Text(
                    'Assets are stored in app support storage and are scoped to this profile and title. They do not alter your original movie/show folders.',
                    style: TextStyle(fontSize: 12)),
              ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'))
        ],
      );
}

/// Autoplaying, muted loop for a movie's short details-page theme clip.
class CinematicThemeVideoBackdrop extends StatefulWidget {
  const CinematicThemeVideoBackdrop({super.key, required this.path});
  final String path;
  @override
  State<CinematicThemeVideoBackdrop> createState() =>
      _CinematicThemeVideoBackdropState();
}

class _CinematicThemeVideoBackdropState
    extends State<CinematicThemeVideoBackdrop> {
  VideoPlayerController? _controller;
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.file(File(widget.path));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      await controller.dispose();
      if (identical(_controller, controller)) _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c)));
  }
}

/// Plays a show's locally assigned theme audio while its details page is open.
class CinematicThemeSongAudio extends StatefulWidget {
  const CinematicThemeSongAudio({super.key, required this.path});
  final String path;
  @override
  State<CinematicThemeSongAudio> createState() =>
      _CinematicThemeSongAudioState();
}

class _CinematicThemeSongAudioState extends State<CinematicThemeSongAudio> {
  VideoPlayerController? _controller;
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final c = VideoPlayerController.file(File(widget.path));
    _controller = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(.65);
      await c.play();
    } catch (_) {
      await c.dispose();
      if (identical(_controller, c)) _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
