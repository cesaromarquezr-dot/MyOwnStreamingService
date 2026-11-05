// Shared presentation layer for owned movies, episodes, TV specials, music,
// physical discs, collections, chapters, and bonus features.
import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'stores/media_experience_store.dart';
import 'widgets/audio_subtitle_selector.dart';
import 'widgets/media_action_bar.dart';
import 'widgets/media_case_3d_view.dart';
import 'widgets/media_disc_3d_view.dart';
import 'widgets/media_extras_grid.dart';
import 'widgets/scene_selection_grid.dart';

class MediaExperienceScreen extends StatefulWidget {
  const MediaExperienceScreen({super.key, this.media});
  final MediaItem? media;

  @override
  State<MediaExperienceScreen> createState() => _MediaExperienceScreenState();
}

class _MediaExperienceScreenState extends State<MediaExperienceScreen> {
  final MediaExperienceStore _store = MediaExperienceStore.instance;

  List<MediaItem> get _ownedMedia {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    return controller.library
        .where((item) =>
            item.isAccessibleTo(profile) && controller.isOwned(item.id))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    final selected = widget.media ?? _store.media ?? _defaultMedia();
    if (selected != null) _store.selectMedia(selected);
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  MediaItem? _defaultMedia() {
    final items = _ownedMedia;
    return items.isEmpty ? null : items.first;
  }

  void _selectMedia(String? id) {
    if (id == null) return;
    for (final item in _ownedMedia) {
      if (item.id == id) {
        _store.selectMedia(item);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = _store.media;
    final snapshot = _store.snapshot;
    final ownedMedia = _ownedMedia;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Experience'),
        actions: [
          if (media != null)
            IconButton(
              tooltip: 'Close disc case',
              onPressed: _store.closeCase,
              icon: const Icon(Icons.close_fullscreen_rounded),
            ),
        ],
      ),
      body: media == null || snapshot == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Add owned media to your library to open its complete experience.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (ownedMedia.length > 1) ...[
                  DropdownButtonFormField<String>(
                    initialValue: ownedMedia.any((item) => item.id == media.id)
                        ? media.id
                        : ownedMedia.first.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Choose owned media',
                      prefixIcon: Icon(Icons.video_library_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: ownedMedia
                        .map((item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(
                                item.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(growable: false),
                    onChanged: _selectMedia,
                  ),
                  const SizedBox(height: 16),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _store.caseState == MediaCaseAnimationState.open
                      ? Column(
                          key: const ValueKey('open'),
                          children: [
                            MediaCase3DView(
                              title: media.title,
                              media: media,
                              format: media.displayCaseFormat,
                              year: media.releaseYear,
                              width: 142,
                              height: 190,
                            ),
                            const SizedBox(height: 10),
                            MediaDisc3DView(
                              label: 'DISC ${media.discNumber ?? 1}',
                              size: 106,
                            ),
                          ],
                        )
                      : Center(
                          key: const ValueKey('closed'),
                          child: MediaCase3DView(
                            title: media.title,
                            media: media,
                            format: media.displayCaseFormat,
                            year: media.releaseYear,
                            width: 168,
                            height: 224,
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  media.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    media.type,
                    if (media.releaseYear != null) '${media.releaseYear}',
                    if (media.displayCaseFormat != null) media.displayCaseFormat!,
                  ].join(' · '),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_store.caseState != MediaCaseAnimationState.open)
                  Center(
                    child: FilledButton.icon(
                      onPressed: _store.openCase,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Open case / disc menu'),
                    ),
                  ),
                if (snapshot.discPrograms.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Programs on this physical edition',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...snapshot.discPrograms.map((program) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.play_circle_outline),
                          title: Text(program.title),
                          subtitle: Text(
                            'Disc ${program.discNumber} · ${program.kind.name}'
                            '${program.isBonus ? ' · Bonus' : ''}',
                          ),
                          onTap: () {
                            MediaItem? selected;
                            for (final item in AppController.instance.library) {
                              if (item.id == program.mediaId) {
                                selected = item;
                                break;
                              }
                            }
                            if (selected != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      MediaDetailsScreen(media: selected!),
                                ),
                              );
                            }
                          },
                        ),
                      )),
                ],
                const SizedBox(height: 18),
                Text(
                  'Playback & navigation',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                MediaActionBar(
                  onPlay: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MediaDetailsScreen(media: media),
                    ),
                  ),
                  onScenes: () => _showSection(
                    context,
                    'Scenes',
                    SceneSelectionGrid(
                      scenes: snapshot.scenes,
                      onSelected: _store.selectScene,
                    ),
                  ),
                  onExtras: () => _showSection(
                    context,
                    'Bonus content',
                    MediaExtrasGrid(
                      extras: snapshot.extras,
                      onSelected: _store.selectExtra,
                    ),
                  ),
                  onTracks: () => _showSection(
                    context,
                    'Audio & subtitles',
                    AudioSubtitleSelector(
                      audioTracks:
                          snapshot.audioTracks.map((e) => e.label).toList(),
                      subtitleTracks: [
                        'Off',
                        ...snapshot.subtitleTracks.map((e) => e.label),
                      ],
                      selectedAudio: _store.selectedAudio,
                      selectedSubtitle: _store.selectedSubtitle,
                      onAudioChanged: _store.setAudio,
                      onSubtitleChanged: _store.setSubtitle,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Bonus features',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                MediaExtrasGrid(
                  extras: snapshot.extras,
                  onSelected: _store.selectExtra,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Disc contents are separate playable library records. A physical release can group films, episodes, TV specials, music tracks and bonus features without duplicating their canonical media records.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
    );
  }

  void _showSection(BuildContext context, String title, Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
