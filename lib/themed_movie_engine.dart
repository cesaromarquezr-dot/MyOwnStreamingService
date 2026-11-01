import 'app_core.dart';
import 'themed_episode_engine.dart';

/// Theme classifier for imported feature films.
///
/// It reuses the shared holiday vocabulary and curated movie aliases from
/// [ThemedEpisodeEngine], while explicitly excluding TV series and episodes.
class ThemedMovieEngine {
  ThemedMovieEngine._();

  static bool isMovie(MediaItem media) {
    if (media.isSeries) return false;
    final type = media.type.toLowerCase().trim();
    return type == 'movie' ||
        type == 'film' ||
        type == 'feature' ||
        type.contains('movie') ||
        type.contains('film');
  }

  static List<ThemedEpisodeMatch> matchesForMovie(
    MediaItem movie, {
    DateTime? date,
  }) {
    if (!isMovie(movie)) return const <ThemedEpisodeMatch>[];
    return ThemedEpisodeEngine.detectMediaMatches(
      title: movie.title,
      description: movie.description ?? '',
      genres: movie.genres,
      tags: movie.tags,
      date: date,
    );
  }
}
