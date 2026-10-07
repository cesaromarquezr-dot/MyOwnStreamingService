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
    this.genres = const <String>{},
    this.tags = const <String>{},
    this.franchises = const <String>{},
    this.holidays = const <String>{},
    this.audiences = const <String>{},
    this.themes = const <String>{},
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
    this.terms = const <String>[],
    this.months = const <int>[],
    this.daysOfWeek = const <int>[],
    this.nightly = false,
    this.priority = 500,
  });

  factory TvProgrammingRule.fromJson(Map<String, dynamic> json) {
    return TvProgrammingRule(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Programming rule',
      terms: _stringList(json['terms']),
      months: _intList(json['months'], min: 1, max: 12),
      daysOfWeek: _intList(json['daysOfWeek'], min: 1, max: 7),
      nightly: json['nightly'] == true,
      priority: (json['priority'] as num?)?.toInt() ?? 500,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'terms': terms,
        'months': months,
        'daysOfWeek': daysOfWeek,
        'nightly': nightly,
        'priority': priority,
      };

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item.toString().trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<int> _intList(dynamic value, {required int min, required int max}) {
    if (value is! List) return const <int>[];
    return value
        .map((item) => int.tryParse(item.toString()) ?? 0)
        .where((item) => item >= min && item <= max)
        .toList(growable: false);
  }
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
    this.filters = const <String>[],
    this.contentTypes = const <String>['Movies', 'Shows'],
    this.seasonal = false,
    this.priority = 0,
    this.programmingRules = const <TvProgrammingRule>[],
  });

  factory TvChannelDefinition.fromJson(Map<String, dynamic> json) {
    final rawRules = json['programmingRules'];
    return TvChannelDefinition(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'My Channel',
      description: json['description']?.toString() ?? '',
      filters: _stringList(json['filters']),
      contentTypes: _stringList(json['contentTypes']),
      seasonal: json['seasonal'] == true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      programmingRules: rawRules is List
          ? rawRules
              .whereType<Map>()
              .map((item) => TvProgrammingRule.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const <TvProgrammingRule>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'filters': filters,
        'contentTypes': contentTypes,
        'seasonal': seasonal,
        'priority': priority,
        'programmingRules': programmingRules.map((rule) => rule.toJson()).toList(),
      };

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
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
