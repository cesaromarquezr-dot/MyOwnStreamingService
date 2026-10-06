class TvContentIntelligence {
  final Set<String> genres;
  final Set<String> tags;
  final Set<String> franchises;
  final Set<String> holidays;
  final Set<String> audiences;
  final Set<String> themes;
  final bool isEpisode;
  final bool isMovie;

  const TvContentIntelligence({
    this.genres = const {},
    this.tags = const {},
    this.franchises = const {},
    this.holidays = const {},
    this.audiences = const {},
    this.themes = const {},
    this.isEpisode = false,
    this.isMovie = false,
  });

  Map<String, dynamic> toJson() => {
        'genres': genres.toList(),
        'tags': tags.toList(),
        'franchises': franchises.toList(),
        'holidays': holidays.toList(),
        'audiences': audiences.toList(),
        'themes': themes.toList(),
        'isEpisode': isEpisode,
        'isMovie': isMovie,
      };
}


class TvProgrammingRule {
  final String id;
  final String name;
  final List<String> terms;
  final List<int> months;
  final List<int> daysOfWeek;
  final bool nightly;
  final int priority;

  const TvProgrammingRule({
    required this.id,
    required this.name,
    this.terms = const [],
    this.months = const [],
    this.daysOfWeek = const [],
    this.nightly = false,
    this.priority = 500,
  });

  factory TvProgrammingRule.fromJson(Map<String, dynamic> json) => TvProgrammingRule(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Programming rule',
        terms: json['terms'] is List ? (json['terms'] as List).map((e) => e.toString().trim().toLowerCase()).where((e) => e.isNotEmpty).toList() : const [],
        months: json['months'] is List ? (json['months'] as List).map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e >= 1 && e <= 12).toList() : const [],
        daysOfWeek: json['daysOfWeek'] is List ? (json['daysOfWeek'] as List).map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e >= 1 && e <= 7).toList() : const [],
        nightly: json['nightly'] == true,
        priority: (json['priority'] as num?)?.toInt() ?? 500,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'terms': terms,
        'months': months,
        'daysOfWeek': daysOfWeek,
        'nightly': nightly,
        'priority': priority,
      };
}

class TvChannelDefinition {
  final String id;
  final String name;
  final String description;
  final List<String> filters;
  final List<String> contentTypes;
  final bool seasonal;
  final int priority;
  final List<TvProgrammingRule> programmingRules;

  const TvChannelDefinition({
    required this.id,
    required this.name,
    this.description = '',
    this.filters = const [],
    this.contentTypes = const ['Movies', 'Shows'],
    this.seasonal = false,
    this.priority = 0,
    this.programmingRules = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'filters': filters,
        'contentTypes': contentTypes,
        'seasonal': seasonal,
        'priority': priority,
      };
}

class TvProgramItem {
  final String mediaId;
  final String title;
  final int score;
  final int durationMinutes;
  final TvContentIntelligence intelligence;

  const TvProgramItem({
    required this.mediaId,
    required this.title,
    required this.score,
    required this.durationMinutes,
    required this.intelligence,
  });

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'title': title,
        'score': score,
        'durationMinutes': durationMinutes,
        'intelligence': intelligence.toJson(),
      };
}
