import 'package:material_ui/material_ui.dart';
import '../models/media_experience_models.dart';

class MediaExtrasGrid extends StatelessWidget {
  const MediaExtrasGrid({super.key, required this.extras, this.onSelected});
  final List<MediaExperienceExtra> extras;
  final ValueChanged<MediaExperienceExtra>? onSelected;
  @override
  Widget build(BuildContext context) {
    if (extras.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(18),
          child: Text('No bonus content was recorded for this title.'));
    }
    return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: extras.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 210,
            childAspectRatio: 1.45,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10),
        itemBuilder: (context, index) {
          final item = extras[index];
          return Card(
              child: InkWell(
                  onTap: onSelected == null ? null : () => onSelected!(item),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_icon(item.kind), size: 23),
                            const Spacer(),
                            Text(item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            Text(item.kind.name,
                                style: Theme.of(context).textTheme.labelSmall)
                          ]))));
        });
  }

  IconData _icon(MediaExtraKind kind) => switch (kind) {
        MediaExtraKind.commentary => Icons.record_voice_over_outlined,
        MediaExtraKind.deletedScene => Icons.cut_rounded,
        MediaExtraKind.gagReel => Icons.sentiment_very_satisfied_outlined,
        MediaExtraKind.documentary => Icons.movie_filter_outlined,
        MediaExtraKind.trailer => Icons.play_circle_outline,
        MediaExtraKind.musicVideo => Icons.music_video_outlined,
        MediaExtraKind.interview => Icons.mic_none_rounded,
        MediaExtraKind.bonusFeature => Icons.auto_awesome_outlined,
        MediaExtraKind.other => Icons.more_horiz_rounded
      };
}
