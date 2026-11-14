import 'package:material_ui/material_ui.dart';

class AudioSubtitleSelector extends StatelessWidget {
  const AudioSubtitleSelector(
      {super.key,
      required this.audioTracks,
      required this.subtitleTracks,
      required this.selectedAudio,
      required this.selectedSubtitle,
      required this.onAudioChanged,
      required this.onSubtitleChanged});
  final List<String> audioTracks;
  final List<String> subtitleTracks;
  final String selectedAudio;
  final String selectedSubtitle;
  final ValueChanged<String> onAudioChanged;
  final ValueChanged<String> onSubtitleChanged;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<String>(
            initialValue: audioTracks.contains(selectedAudio)
                ? selectedAudio
                : (audioTracks.isEmpty ? 'Default' : audioTracks.first),
            decoration: const InputDecoration(
                labelText: 'Audio track',
                prefixIcon: Icon(Icons.surround_sound_rounded)),
            items: (audioTracks.isEmpty ? const ['Default'] : audioTracks)
                .map((v) => DropdownMenuItem(
                    value: v, child: Text(v, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) {
              if (v != null) onAudioChanged(v);
            }),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
            initialValue: subtitleTracks.contains(selectedSubtitle)
                ? selectedSubtitle
                : (subtitleTracks.isEmpty ? 'Off' : subtitleTracks.first),
            decoration: const InputDecoration(
                labelText: 'Subtitles',
                prefixIcon: Icon(Icons.subtitles_rounded)),
            items: (subtitleTracks.isEmpty ? const ['Off'] : subtitleTracks)
                .map((v) => DropdownMenuItem(
                    value: v, child: Text(v, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) {
              if (v != null) onSubtitleChanged(v);
            })
      ]);
}
