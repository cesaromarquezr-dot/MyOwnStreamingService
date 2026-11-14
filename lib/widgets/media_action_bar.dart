import 'package:material_ui/material_ui.dart';

class MediaActionBar extends StatelessWidget {
  const MediaActionBar(
      {super.key,
      required this.onPlay,
      required this.onScenes,
      required this.onExtras,
      required this.onTracks,
      this.playLabel = 'Play'});
  final VoidCallback onPlay;
  final VoidCallback onScenes;
  final VoidCallback onExtras;
  final VoidCallback onTracks;
  final String playLabel;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(playLabel)),
        OutlinedButton.icon(
            onPressed: onScenes,
            icon: const Icon(Icons.video_library_outlined),
            label: const Text('Scenes')),
        OutlinedButton.icon(
            onPressed: onExtras,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Extras')),
        OutlinedButton.icon(
            onPressed: onTracks,
            icon: const Icon(Icons.subtitles_rounded),
            label: const Text('Audio & subtitles'))
      ]);
}
