import 'package:material_ui/material_ui.dart';

import '../app_core.dart';
import '../models/media_case_style.dart';
import 'media_case_3d_view.dart';
import 'media_status_badges.dart';

class KioskMovieCard extends StatelessWidget {
  const KioskMovieCard({
    super.key,
    required this.media,
    required this.onTap,
  });

  final MediaItem media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = MediaCaseStyle.fromFormat(media.displayCaseFormat);
    final isSquarePackage =
        style.kind == MediaCaseKind.cd || style.kind == MediaCaseKind.vinyl;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SizedBox(
                width: 116,
                height: 146,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: MediaCase3DView(
                        title: media.title,
                        media: media,
                        format: media.displayCaseFormat,
                        year: media.releaseYear,
                        width: isSquarePackage ? 106 : 104,
                        height: 138,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 0,
                      child: MediaStatusBadgeRow(media: media, dense: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              media.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              [
                media.type,
                if (media.displayCaseFormat?.trim().isNotEmpty == true)
                  MediaCaseStyle.canonicalFormat(media.displayCaseFormat),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
