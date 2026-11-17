import 'app_core.dart';
import 'smart_search_intelligence.dart';

/// Local rank-fusion layer used before and after remote catalog retrieval.
/// Exact title and spelling-tolerant keyword matches remain authoritative;
/// descriptive metadata and multilingual intent terms provide a second lane.
class HybridSearchEngine {
  HybridSearchEngine._();

  static const Map<String, List<String>> _concepts = <String, List<String>>{
    'feel good': <String>['feel-good', 'uplifting', 'comedy', 'feelgood', 'optimistic', 'lighthearted', 'feel bien', 'buen rollo', 'alegre'],
    'cozy': <String>['comfort', 'warm', 'family', 'gentle', 'cozy', 'acogedor', 'tranquilo'],
    'mind bending': <String>['mind-bending', 'surreal', 'psychological', 'reality', 'twist', 'cerebral', 'surrealista', 'psicologico'],
    'scary': <String>['horror', 'terrifying', 'haunted', 'supernatural', 'creepy', 'terror', 'miedo', 'espeluznante'],
    'romantic': <String>['romance', 'love', 'relationship', 'romantico', 'amor'],
    'funny': <String>['comedy', 'humor', 'satire', 'hilarious', 'comedia', 'gracioso'],
    'action': <String>['adventure', 'fight', 'chase', 'superhero', 'accion', 'aventura'],
    'sad': <String>['drama', 'emotional', 'heartbreak', 'tragic', 'triste', 'drama'],
    'family': <String>['kids', 'children', 'animation', 'family-friendly', 'infantil', 'familia'],
    'christmas': <String>['holiday', 'winter', 'santa', 'navidad', 'festivo'],
    'mystery': <String>['detective', 'crime', 'investigation', 'thriller', 'misterio', 'crimen'],
    'sci fi': <String>['science fiction', 'space', 'futuristic', 'alien', 'ciencia ficcion', 'espacio'],
  };

  /// Ranks an already-retrieved candidate set using reciprocal-rank fusion.
  /// The caller remains responsible for access rules and owned/unowned labels.
  static List<MediaItem> rankMedia(
    String rawQuery,
    Iterable<MediaItem> source, {
    Map<String, double> remoteScores = const <String, double>{},
    bool onlyMatches = false,
  }) {
    final query = _normalize(rawQuery);
    if (query.isEmpty) return source.toList(growable: false);
    final candidates = source.toList(growable: false);
    final recommendationRanks = <String, int>{
      for (var index = 0;
          index < AppController.instance.recommendations.length;
          index++)
        AppController.instance.recommendations[index].id: index,
    };
    final lexical = <MediaItem, double>{};
    final semantic = <MediaItem, double>{};
    final matchedCandidates = <MediaItem>[];

    for (final media in candidates) {
      final title = <String>[
        media.title,
        media.originalTitle ?? '',
        media.canonicalTitle ?? '',
      ].where((value) => value.trim().isNotEmpty).toList();
      final titleNorms = title.map(_normalize).toList();
      final compactQuery = SmartSearchIntelligence.compact(query);
      var keywordScore = 0.0;
      if (titleNorms.any((value) => value == query ||
          SmartSearchIntelligence.compact(value) == compactQuery)) {
        keywordScore += 1000;
      } else if (titleNorms.any((value) => value.startsWith(query))) {
        keywordScore += 500;
      } else if (titleNorms.any((value) => value.contains(query) ||
          SmartSearchIntelligence.compact(value).contains(compactQuery))) {
        keywordScore += 280;
      }

      final fields = <String>[
        ...title,
        media.description ?? '',
        ...media.genres,
        ...media.tags,
        ...media.themes,
        ...media.tones,
        ...media.actors,
        ...media.characters,
        ...media.directors,
        ...media.writers,
        ...media.studios,
        ...media.franchiseNames,
        media.countryOfOrigin ?? '',
        media.originalLanguage ?? '',
        media.language ?? '',
      ];
      final normalizedFields = fields
          .map(_normalize)
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      final tokens = query.split(' ').where((value) => value.length > 1).toSet();
      for (final token in tokens) {
        if (normalizedFields.any((field) => field.split(' ').contains(token))) {
          keywordScore += 24;
        }
      }
      if (keywordScore == 0 && query.length >= 4 && tokens.length == 1) {
        final token = tokens.first;
        final closest = titleNorms
            .expand((value) => value.split(' '))
            .where((value) => (value.length - token.length).abs() <= 2)
            .map((value) => _distance(value, token, 2))
            .fold<int>(3, (best, distance) => distance < best ? distance : best);
        if (closest > 0 && closest <= (token.length >= 8 ? 2 : 1)) {
          keywordScore += closest == 1 ? 95 : 55;
        }
      }
      lexical[media] = keywordScore;

      final expanded = <String>{query};
      for (final entry in _concepts.entries) {
        final key = _normalize(entry.key);
        final aliases = entry.value.map(_normalize);
        if (query == key || aliases.contains(query) ||
            (key.length >= 4 && query.contains(key)) ||
            aliases.any((alias) => alias.length >= 4 && query.contains(alias))) {
          expanded.addAll(aliases);
          expanded.add(key);
        }
      }
      final searchable = normalizedFields.join(' ');
      var semanticScore = SmartSearchIntelligence.semanticPlotScore(
        _normalize(rawQuery), normalizedFields.join(' '));
      for (final concept in expanded) {
        if (concept == query || concept.isEmpty) continue;
        if (searchable.contains(concept)) semanticScore += 14;
      }
      semantic[media] = semanticScore.toDouble();
      // Personalization is a tie-breaker for a relevant result, never a reason
      // to return an unrelated recommendation for an arbitrary query.
      if (onlyMatches && keywordScore <= 0 && semanticScore <= 0 &&
          (remoteScores[media.id] ?? 0) <= 0) {
        continue;
      }
      final recommendationIndex = recommendationRanks[media.id];
      if (recommendationIndex != null) {
        semantic[media] = semanticScore.toDouble() +
            (45 - recommendationIndex).clamp(0, 45).toInt();
      }
      matchedCandidates.add(media);
    }

    final rankCandidates = onlyMatches ? matchedCandidates : candidates;
    final lexicalRank = _rank(lexical);
    final semanticRank = _rank(semantic);
    final remoteRank = _rankById(remoteScores);
    final scored = rankCandidates.map((media) {
      // Exact-title rank receives a modest direct bonus so semantic similarity
      // cannot displace the obvious title match.
      final direct = (lexical[media] ?? 0) >= 1000 ? 0.012 : 0.0;
      final localFusion = 0.55 / (60 + (lexicalRank[media] ?? candidates.length + 1)) +
          0.45 / (60 + (semanticRank[media] ?? candidates.length + 1));
      final fused = remoteRank.isEmpty
          ? localFusion + direct
          : 0.45 / (60 + (lexicalRank[media] ?? candidates.length + 1)) +
              0.35 / (60 + (semanticRank[media] ?? candidates.length + 1)) +
              0.20 / (60 + (remoteRank[media.id] ?? candidates.length + 1)) + direct;
      return (media: media, score: fused);
    }).toList();
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((entry) => entry.media).toList(growable: false);
  }

  static Map<String, int> _rankById(Map<String, double> scores) {
    final ordered = scores.keys.toList()
      ..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    return <String, int>{
      for (var index = 0; index < ordered.length; index++)
        ordered[index]: index + 1,
    };
  }

  static Map<MediaItem, int> _rank(Map<MediaItem, double> scores) {
    final ordered = scores.keys.toList()
      ..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    return <MediaItem, int>{
      for (var index = 0; index < ordered.length; index++) ordered[index]: index + 1,
    };
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('å', 'a')
      .replaceAll('æ', 'ae')
      .replaceAll('ç', 'c')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('œ', 'oe')
      .replaceAll('ß', 'ss')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ý', 'y')
      .replaceAll('ÿ', 'y')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static int _distance(String left, String right, int limit) {
    if ((left.length - right.length).abs() > limit) return limit + 1;
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 1; i <= left.length; i++) {
      final current = List<int>.filled(right.length + 1, limit + 1);
      current[0] = i;
      var minimum = current[0];
      for (var j = 1; j <= right.length; j++) {
        final cost = left[i - 1] == right[j - 1] ? 0 : 1;
        current[j] = <int>[
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
        if (current[j] < minimum) minimum = current[j];
      }
      if (minimum > limit) return limit + 1;
      previous = current;
    }
    return previous[right.length];
  }
}
