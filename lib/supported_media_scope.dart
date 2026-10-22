/// Product-scope guard for content types that MyOwnStreamingService does not support.
///
/// The music product intentionally focuses on songs/tracks, albums, artists,
/// music videos, soundtracks, and playlists. Podcast, audiobook, and internet-
/// radio records must not surface through catalog browsing, search, or
/// recommendations, even if a provider or legacy cache contains them.
class SupportedMediaScope {
  SupportedMediaScope._();

  static const Set<String> supportedMusicTypes = <String>{
    'song',
    'track',
    'single',
    'album',
    'artist',
    'musicvideo',
    'soundtrack',
    'playlist',
    'compilation',
  };

  static String normalizeType(String? type) => (type ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static bool isExcludedType(String? type) {
    final normalized = normalizeType(type);
    if (normalized.isEmpty) return false;

    return normalized.startsWith('podcast') ||
        normalized.startsWith('audiobook') ||
        normalized.startsWith('internetradio') ||
        normalized.startsWith('webradio') ||
        normalized.startsWith('radiostation') ||
        normalized.startsWith('liveradio') ||
        normalized == 'radio' ||
        normalized == 'amradio' ||
        normalized == 'fmradio' ||
        normalized == 'onlineaudiochannel';
  }

  static bool isAllowedType(String? type) => !isExcludedType(type);

  static List<T> filterByType<T>(
    Iterable<T> items,
    String? Function(T item) typeOf,
  ) => items
      .where((item) => isAllowedType(typeOf(item)))
      .toList(growable: false);
}
