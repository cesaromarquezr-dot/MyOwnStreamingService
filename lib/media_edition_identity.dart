import 'app_core.dart';

String discImportCanonicalWorkId({
  required String title,
  int? releaseYear,
}) {
  final normalizedTitle = title.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
  return 'disc-import-work:${releaseYear ?? 'unknown'}:'
      '${Uri.encodeComponent(normalizedTitle)}';
}

String? mediaEditionGroupId(MediaItem media) {
  final canonicalWorkId = media.canonicalWorkId?.trim();
  if (canonicalWorkId != null && canonicalWorkId.isNotEmpty) {
    return canonicalWorkId;
  }
  if (media.addedSource != 'disc_ingestion_center' ||
      media.type.trim().toLowerCase() != 'movie') {
    return null;
  }
  return discImportCanonicalWorkId(
    title: media.title,
    releaseYear: media.releaseYear,
  );
}
