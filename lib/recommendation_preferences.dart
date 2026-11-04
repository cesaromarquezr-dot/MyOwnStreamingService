/// Saved recommendation controls for the active profile.
/// The defaults intentionally balance familiar picks (65%) with discovery (35%).
class RecommendationPreferences {
  static const List<String> defaultSections = <String>[
    'forYou', 'performers', 'studios', 'creators', 'characters', 'stories',
    'franchises', 'adaptations', 'soundtracks', 'moodEra', 'awards',
    'hidden', 'world', 'trails', 'taste',
  ];

  final int familiarPercent;
  final bool includeLibraryItems;
  final bool includeExternalItems;
  final bool includeWatchedItems;
  final bool includeRewatches;
  final bool shareHistoryWithOtherProfiles;
  final bool useOtherProfileActivity;
  final bool explainRecommendations;
  final bool spoilerSafe;
  final bool excludeDisliked;
  final List<String> enabledSections;
  final List<String> prioritizedPerformers;
  final List<String> prioritizedStudios;
  final List<String> prioritizedThemes;
  final List<String> excludedGenres;
  final List<String> excludedTones;

  const RecommendationPreferences({
    this.familiarPercent = 65,
    this.includeLibraryItems = true,
    this.includeExternalItems = true,
    this.includeWatchedItems = false,
    this.includeRewatches = false,
    this.shareHistoryWithOtherProfiles = false,
    this.useOtherProfileActivity = false,
    this.explainRecommendations = true,
    this.spoilerSafe = true,
    this.excludeDisliked = true,
    this.enabledSections = defaultSections,
    this.prioritizedPerformers = const <String>[],
    this.prioritizedStudios = const <String>[],
    this.prioritizedThemes = const <String>[],
    this.excludedGenres = const <String>[],
    this.excludedTones = const <String>[],
  });

  int get unexpectedPercent => 100 - familiarPercent.clamp(0, 100).toInt();

  RecommendationPreferences copyWith({
    int? familiarPercent,
    bool? includeLibraryItems,
    bool? includeExternalItems,
    bool? includeWatchedItems,
    bool? includeRewatches,
    bool? shareHistoryWithOtherProfiles,
    bool? useOtherProfileActivity,
    bool? explainRecommendations,
    bool? spoilerSafe,
    bool? excludeDisliked,
    List<String>? enabledSections,
    List<String>? prioritizedPerformers,
    List<String>? prioritizedStudios,
    List<String>? prioritizedThemes,
    List<String>? excludedGenres,
    List<String>? excludedTones,
  }) => RecommendationPreferences(
    familiarPercent: (familiarPercent ?? this.familiarPercent).clamp(0, 100).toInt(),
    includeLibraryItems: includeLibraryItems ?? this.includeLibraryItems,
    includeExternalItems: includeExternalItems ?? this.includeExternalItems,
    includeWatchedItems: includeWatchedItems ?? this.includeWatchedItems,
    includeRewatches: includeRewatches ?? this.includeRewatches,
    shareHistoryWithOtherProfiles: shareHistoryWithOtherProfiles ?? this.shareHistoryWithOtherProfiles,
    useOtherProfileActivity: useOtherProfileActivity ?? this.useOtherProfileActivity,
    explainRecommendations: explainRecommendations ?? this.explainRecommendations,
    spoilerSafe: spoilerSafe ?? this.spoilerSafe,
    excludeDisliked: excludeDisliked ?? this.excludeDisliked,
    enabledSections: enabledSections ?? this.enabledSections,
    prioritizedPerformers: prioritizedPerformers ?? this.prioritizedPerformers,
    prioritizedStudios: prioritizedStudios ?? this.prioritizedStudios,
    prioritizedThemes: prioritizedThemes ?? this.prioritizedThemes,
    excludedGenres: excludedGenres ?? this.excludedGenres,
    excludedTones: excludedTones ?? this.excludedTones,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'familiarPercent': familiarPercent.clamp(0, 100).toInt(),
    'unexpectedPercent': unexpectedPercent,
    'includeLibraryItems': includeLibraryItems,
    'includeExternalItems': includeExternalItems,
    'includeWatchedItems': includeWatchedItems,
    'includeRewatches': includeRewatches,
    'shareHistoryWithOtherProfiles': shareHistoryWithOtherProfiles,
    'useOtherProfileActivity': useOtherProfileActivity,
    'explainRecommendations': explainRecommendations,
    'spoilerSafe': spoilerSafe,
    'excludeDisliked': excludeDisliked,
    'enabledSections': List<String>.from(enabledSections),
    'prioritizedPerformers': List<String>.from(prioritizedPerformers),
    'prioritizedStudios': List<String>.from(prioritizedStudios),
    'prioritizedThemes': List<String>.from(prioritizedThemes),
    'excludedGenres': List<String>.from(excludedGenres),
    'excludedTones': List<String>.from(excludedTones),
  };

  factory RecommendationPreferences.fromJson(dynamic value) {
    if (value is! Map) return const RecommendationPreferences();
    final json = Map<String, dynamic>.from(value);
    int intValue(String key, int fallback) {
      final raw = json[key];
      final parsed = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
      return (parsed ?? fallback).clamp(0, 100).toInt();
    }
    bool boolValue(String key, bool fallback) => json[key] is bool ? json[key] as bool : fallback;
    List<String> stringList(String key, List<String> fallback) {
      final raw = json[key];
      if (raw is! List) return List<String>.from(fallback);
      return raw.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toSet().toList();
    }
    return RecommendationPreferences(
      familiarPercent: intValue('familiarPercent', 65),
      includeLibraryItems: boolValue('includeLibraryItems', true),
      includeExternalItems: boolValue('includeExternalItems', true),
      includeWatchedItems: boolValue('includeWatchedItems', false),
      includeRewatches: boolValue('includeRewatches', false),
      shareHistoryWithOtherProfiles: boolValue('shareHistoryWithOtherProfiles', false),
      useOtherProfileActivity: boolValue('useOtherProfileActivity', false),
      explainRecommendations: boolValue('explainRecommendations', true),
      spoilerSafe: boolValue('spoilerSafe', true),
      excludeDisliked: boolValue('excludeDisliked', true),
      enabledSections: stringList('enabledSections', defaultSections),
      prioritizedPerformers: stringList('prioritizedPerformers', const <String>[]),
      prioritizedStudios: stringList('prioritizedStudios', const <String>[]),
      prioritizedThemes: stringList('prioritizedThemes', const <String>[]),
      excludedGenres: stringList('excludedGenres', const <String>[]),
      excludedTones: stringList('excludedTones', const <String>[]),
    );
  }
}
