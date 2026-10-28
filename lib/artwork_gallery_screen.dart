import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_core.dart';
import 'artwork_selection_store.dart';
import 'core/services/cinematic_title_metadata_service.dart';

/// Dedicated selector for all poster and backdrop paths returned by TMDB.
/// The user's chosen paths are saved profile-by-profile and media-by-media.
class ArtworkGalleryScreen extends StatefulWidget {
  const ArtworkGalleryScreen({
    super.key,
    required this.media,
    required this.metadata,
    required this.initialPosterPath,
    required this.initialBackdropPath,
    required this.onPosterSet,
    required this.onBackdropSet,
    this.profileIdOverride,
  });

  final MediaItem media;
  final CinematicTitleMetadata metadata;
  final String? initialPosterPath;
  final String? initialBackdropPath;
  final ValueChanged<String> onPosterSet;
  final ValueChanged<String> onBackdropSet;
  /// Optional scope override, used by the profile picker to save a shared
  /// default before the viewer chooses an individual profile.
  final String? profileIdOverride;

  @override
  State<ArtworkGalleryScreen> createState() => _ArtworkGalleryScreenState();
}

class _ArtworkGalleryScreenState extends State<ArtworkGalleryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _selectedPosterPath;
  String? _selectedBackdropPath;
  bool _saving = false;

  List<String> get _activePaths => _tabs.index == 1
      ? widget.metadata.backdropPaths
      : widget.metadata.posterPaths;

  String? get _activeSelection => _tabs.index == 1
      ? _selectedBackdropPath
      : _selectedPosterPath;

  void _stepSelection(int delta) {
    final paths = _activePaths;
    if (paths.isEmpty) return;
    final current = paths.indexOf(_activeSelection ?? '');
    final start = current < 0 ? 0 : current;
    final next = (start + delta + paths.length) % paths.length;
    setState(() {
      if (_tabs.index == 1) {
        _selectedBackdropPath = paths[next];
      } else {
        _selectedPosterPath = paths[next];
      }
    });
  }

  String get _profileId => widget.profileIdOverride ??
      AppController.instance.currentProfile?.id ?? 'guest';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _selectedPosterPath = widget.initialPosterPath ?? widget.metadata.posterPath;
    _selectedBackdropPath =
        widget.initialBackdropPath ?? widget.metadata.backdropPath;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _applySelection({required bool backdrop}) async {
    final path = backdrop ? _selectedBackdropPath : _selectedPosterPath;
    if (path == null || path.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      if (backdrop) {
        await ArtworkSelectionStore.setBackdropPath(
          profileId: _profileId,
          mediaId: widget.media.id,
          path: path,
        );
        widget.onBackdropSet(path);
      } else {
        await ArtworkSelectionStore.setPosterPath(
          profileId: _profileId,
          mediaId: widget.media.id,
          path: path,
        );
        widget.onPosterSet(path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(backdrop
              ? 'Selected backdrop saved for the Home hero banner.'
              : 'Selected poster saved for this details page.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save artwork selection: $error'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posters = widget.metadata.posterPaths;
    final backdrops = widget.metadata.backdropPaths;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.media.title} · Art Gallery'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Posters (${posters.length})'),
            Tab(text: 'Backdrops (${backdrops.length})'),
          ],
        ),
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _stepSelection(-1);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _stepSelection(1);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: TabBarView(
          controller: _tabs,
          children: [
          _galleryGrid(
            paths: posters,
            backdrop: false,
            selectedPath: _selectedPosterPath,
            onSelected: (path) => setState(() => _selectedPosterPath = path),
          ),
          _galleryGrid(
            paths: backdrops,
            backdrop: true,
            selectedPath: _selectedBackdropPath,
            onSelected: (path) => setState(() => _selectedBackdropPath = path),
          ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: AnimatedBuilder(
          animation: _tabs,
          builder: (context, _) {
            final isBackdrop = _tabs.index == 1;
            final paths = isBackdrop ? backdrops : posters;
            final selected = isBackdrop ? _selectedBackdropPath : _selectedPosterPath;
            final selectedIndex = paths.indexOf(selected ?? '');
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Previous artwork (Left Arrow)',
                      onPressed: paths.length > 1 ? () => _stepSelection(-1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          paths.isEmpty
                              ? 'No artwork available'
                              : '${selectedIndex < 0 ? 'Choose' : selectedIndex + 1} of ${paths.length} · Use ← / → to browse',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Next artwork (Right Arrow)',
                      onPressed: paths.length > 1 ? () => _stepSelection(1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving || selected == null
                        ? null
                        : () => _applySelection(backdrop: isBackdrop),
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isBackdrop
                            ? Icons.wallpaper_rounded
                            : Icons.check_circle_outline_rounded),
                    label: Text(isBackdrop
                        ? 'Set selected image as Home hero banner'
                        : 'Set selected image for details page'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _galleryGrid({
    required List<String> paths,
    required bool backdrop,
    required String? selectedPath,
    required ValueChanged<String> onSelected,
  }) {
    if (paths.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'No ${backdrop ? 'backdrops' : 'posters'} are available for this title from TMDB.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1200 ? 6 : width >= 850 ? 5 : width >= 580 ? 4 : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          itemCount: paths.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: backdrop ? 1.42 : .57,
          ),
          itemBuilder: (context, index) {
            final path = paths[index];
            final url = CinematicTitleMetadataService.imageUrl(
              path,
              size: backdrop ? 'w780' : 'w342',
            );
            if (url == null) return const SizedBox.shrink();
            final selected = path == selectedPath;
            return Material(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(path),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            size: 38, color: Colors.white38),
                      ),
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    if (selected)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.greenAccent, width: 4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .78),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: selected ? Colors.greenAccent : Colors.white70,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                selected ? 'Selected' : (backdrop ? 'Select backdrop' : 'Select poster'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
