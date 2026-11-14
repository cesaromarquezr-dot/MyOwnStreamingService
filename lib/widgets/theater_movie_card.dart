import 'package:material_ui/material_ui.dart';
import '../app_core.dart';
import 'media_case_3d_view.dart';
import 'media_status_badges.dart';

class TheaterMovieCard extends StatelessWidget {
  const TheaterMovieCard({super.key, required this.media, required this.onTap});
  final MediaItem media;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
          width: 138,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 116,
                height: 146,
                child: Stack(clipBehavior: Clip.none, children: [
                  Center(
                      child: MediaCase3DView(
                          title: media.title,
                          media: media,
                          format: media.displayCaseFormat,
                          year: media.releaseYear,
                          width: 104,
                          height: 138)),
                  Positioned(
                      top: 2,
                      right: 0,
                      child: MediaStatusBadgeRow(media: media, dense: true)),
                ])),
            const SizedBox(height: 9),
            Text(media.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
                [
                  media.type,
                  if (media.releaseYear != null) '${media.releaseYear}'
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])));
}
