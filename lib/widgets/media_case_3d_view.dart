import 'package:material_ui/material_ui.dart';

import '../app_core.dart';
import '../catalog_poster_image.dart';
import '../core/media_experience/renderer/media_3d_renderer.dart';
import '../core/services/cinematic_title_metadata_service.dart';
import '../models/media_case_style.dart';

/// A lightweight perspective-rendered physical-media case.
///
/// When [media] is supplied, the cover resolves through the app's normal
/// artwork pipeline (including profile-selected posters and album artwork).
/// [imageUrl] remains available for an explicit custom cover override.
class MediaCase3DView extends StatelessWidget {
  const MediaCase3DView({
    super.key,
    required this.title,
    this.media,
    this.imageUrl,
    this.format,
    this.year,
    this.caseColor = 0xFF243447,
    this.width = 108,
    this.height = 142,
  });

  final String title;
  final MediaItem? media;

  /// Explicit artwork override, such as a custom case design front cover.
  final String? imageUrl;
  final String? format;
  final int? year;
  final int caseColor;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final selectedFormat = (format?.trim().isNotEmpty ?? false)
        ? format
        : media?.displayCaseFormat;
    final style = MediaCaseStyle.fromFormat(selectedFormat);
    final resolvedColor =
        caseColor == 0xFF243447 ? style.color.toARGB32() : caseColor;
    // Audio CDs and vinyl sleeves are square packages, unlike DVD/Blu-ray cases.
    final caseHeight =
        style.kind == MediaCaseKind.cd || style.kind == MediaCaseKind.vinyl
            ? width
            : height;

    return SizedBox(
      width: width + 8,
      height: caseHeight,
      child: Media3DRenderer.perspective(
        perspective: 0.0014,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 8,
              top: 1,
              right: 1,
              bottom: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(resolvedColor),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                  border: Border.all(color: Colors.white38, width: 0.8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 7,
                      offset: Offset(3, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCover(resolvedColor, caseHeight),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0x30000000),
                            Colors.transparent,
                            Color(0x42000000),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          style.label,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            letterSpacing: .6,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (year != null)
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          color: Colors.black87,
                          child: Text(
                            '$year',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 1,
              bottom: 1,
              width: 10,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(resolvedColor).withValues(alpha: .55),
                      Color(resolvedColor),
                      Colors.black.withValues(alpha: .55),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                  border: Border.all(color: Colors.white38, width: .7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(int resolvedColor, double caseHeight) {
    final override = imageUrl?.trim() ?? '';
    if (override.isNotEmpty) {
      final normalized = override.startsWith('/')
          ? (CinematicTitleMetadataService.imageUrl(override) ?? override)
          : override;
      return Image.network(
        normalized,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => media == null
            ? _fallbackCover(resolvedColor)
            : _buildMediaArtwork(resolvedColor, caseHeight),
      );
    }
    return _buildMediaArtwork(resolvedColor, caseHeight);
  }

  Widget _buildMediaArtwork(int resolvedColor, double caseHeight) {
    final item = media;
    if (item == null) return _fallbackCover(resolvedColor);

    final type = item.type.toLowerCase();
    final isAudio = type.contains('music') ||
        type.contains('album') ||
        type.contains('song') ||
        type.contains('track') ||
        MediaCaseStyle.canonicalFormat(item.displayCaseFormat) == 'Audio CD';
    if (isAudio) {
      final albumImage = item.imageUrl?.trim() ?? '';
      final normalizedAlbumImage = albumImage.startsWith('/')
          ? (CinematicTitleMetadataService.imageUrl(albumImage) ?? albumImage)
          : albumImage;
      return AlbumArtworkImage(
        title: item.title,
        artist: item.music.isEmpty ? '' : item.music.first,
        imageUrl: normalizedAlbumImage,
        width: width,
        height: caseHeight,
        fit: BoxFit.cover,
        placeholder: _fallbackCover(resolvedColor),
        errorPlaceholder: _fallbackCover(resolvedColor),
      );
    }

    return CatalogPosterImage(
      media: item,
      width: width,
      height: caseHeight,
      fit: BoxFit.cover,
      forcePosterOnly: true,
      placeholder: _fallbackCover(resolvedColor),
      errorPlaceholder: _fallbackCover(resolvedColor),
    );
  }

  Widget _fallbackCover(int resolvedColor) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(resolvedColor),
              Color(resolvedColor).withValues(alpha: .72),
              Colors.black87,
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
        alignment: Alignment.center,
        child: Text(
          title,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1.15,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
          ),
        ),
      );
}
