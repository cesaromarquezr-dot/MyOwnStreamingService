import 'package:flutter/foundation.dart';
import '../app_core.dart';

enum MediaCollectionKind { physicalEdition, tvSpecials, movieCollection, seasonSet, musicCollection, playlist, compilation, mixedMedia, custom }

@immutable
class MediaCollection {
  const MediaCollection({required this.id, required this.title, required this.kind, required this.items, this.description, this.artworkUrl, this.discCount = 1, this.format, this.edition});
  final String id;
  final String title;
  final MediaCollectionKind kind;
  final List<MediaItem> items;
  final String? description;
  final String? artworkUrl;
  final int discCount;
  final String? format;
  final String? edition;
  int get itemCount => items.length;
  int get bonusCount => items.where((item) => item.isBonusContent).length;
  List<MediaItem> get orderedItems => List<MediaItem>.from(items)..sort((a,b) {
    final d = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1); if (d != 0) return d;
    return (a.discContentPosition ?? 0x3fffffff).compareTo(b.discContentPosition ?? 0x3fffffff);
  });
}

MediaCollectionKind collectionKindFromItems(List<MediaItem> items) {
  final types = items.map((item) => item.type.toLowerCase()).toSet();
  final title = items.first.discCollectionTitle?.toLowerCase() ?? '';
  if (title.contains('special') || items.any((m) => m.type.toLowerCase().contains('special'))) return MediaCollectionKind.tvSpecials;
  if (types.length > 1) return MediaCollectionKind.mixedMedia;
  if (types.any((t) => t.contains('music') || t == 'album')) return MediaCollectionKind.musicCollection;
  if (types.any((t) => t.contains('tv') || t.contains('episode') || t.contains('series'))) return MediaCollectionKind.seasonSet;
  return MediaCollectionKind.physicalEdition;
}
