import 'package:flutter/foundation.dart';
import '../app_core.dart';

enum KioskCategory { all, movies, television, specials, music }

@immutable
class KioskCatalogEntry {
  const KioskCatalogEntry({required this.media, required this.category, this.isFavorite = false});
  final MediaItem media; final KioskCategory category; final bool isFavorite;
  String get id => media.id;
  String get title => media.title;
}

@immutable
class KioskPlaybackSession {
  const KioskPlaybackSession({required this.id, required this.mediaId, required this.startedAt, this.lastPositionSeconds = 0});
  final String id; final String mediaId; final DateTime startedAt; final int lastPositionSeconds;
}
