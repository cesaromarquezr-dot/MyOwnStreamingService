import '../../app_core.dart';

class TvSeasonWindow {
  final String id;
  final String name;
  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;
  final Map<String, int> boosts;

  const TvSeasonWindow({
    required this.id,
    required this.name,
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
    required this.boosts,
  });
}

class TvProgrammingService {
  static const windows = <TvSeasonWindow>[
    TvSeasonWindow(
      id: 'valentines',
      name: "Valentine's",
      startMonth: 2,
      startDay: 1,
      endMonth: 2,
      endDay: 14,
      boosts: {
        'valentine': 180,
        'romance': 80,
        'romantic comedy': 100,
        'rom-com': 100,
      },
    ),
    TvSeasonWindow(
      id: 'halloween',
      name: 'Halloween',
      startMonth: 10,
      startDay: 1,
      endMonth: 10,
      endDay: 31,
      boosts: {
        'halloween': 220,
        'slasher': 150,
        'horror': 110,
        'spooky': 90,
        'christmas': -20,
      },
    ),
    TvSeasonWindow(
      id: 'christmas',
      name: 'Christmas',
      startMonth: 12,
      startDay: 1,
      endMonth: 12,
      endDay: 31,
      boosts: {
        'christmas': 240,
        'holiday': 150,
        'winter': 50,
        'family': 35,
      },
    ),
  ];

  static String? activeSeason([DateTime? now]) {
    final date = now ?? DateTime.now();
    for (final window in windows) {
      final start = DateTime(date.year, window.startMonth, window.startDay);
      final end = DateTime(date.year, window.endMonth, window.endDay, 23, 59, 59);
      if (!date.isBefore(start) && !date.isAfter(end)) return window.id;
    }
    return null;
  }

  static int seasonalScore(List<String> fields, {DateTime? now}) {
    final id = activeSeason(now);
    if (id == null) return 0;
    final window = windows.firstWhere((item) => item.id == id);
    final text = fields.join(' ').toLowerCase();
    return window.boosts.entries
        .where((entry) => text.contains(entry.key))
        .fold<int>(0, (sum, entry) => sum + entry.value);
  }

  static bool eligibleForProfile(MediaItem media, Profile? profile) {
    if (!media.isAccessibleTo(profile)) return false;
    if (profile == null) return false;
    final level = profile.governance.contentLevel;
    final normalized = <String>{
      ...media.genres,
      ...media.tags,
      ...media.relationshipTypes,
    }.map((value) => value.toLowerCase().trim()).toSet();
    final restrictedWords = <String>{
      'slasher',
      'gore',
      'serial killer',
      'mature',
      'adult',
      'explicit',
      'extreme violence',
    };
    final childLike = level.name == 'littleKids' ||
        level.name == 'kids' ||
        level.name == 'olderKids';
    if (!childLike) return true;
    if (normalized.any(restrictedWords.contains)) return false;
    return true;
  }

  static int scoreMedia(
    MediaItem media, {
    required String? channelFilter,
    Profile? profile,
    DateTime? now,
  }) {
    final fields = <String>[
      media.title,
      media.description ?? '',
      media.franchiseName ?? '',
      ...media.genres,
      ...media.tags,
      ...media.actors,
      ...media.directors,
      ...media.writers,
      ...media.relationshipTypes,
    ];
    final text = fields.join(' ').toLowerCase();
    var score = seasonalScore(fields, now: now);

    final terms = (channelFilter ?? '')
        .split(RegExp(r'[,;\n]'))
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList();
    if (terms.isNotEmpty) {
      final matched = terms.where(text.contains).length;
      score += matched * 100;
    } else {
      score += 10;
    }

    final childLike = profile?.governance.contentLevel.name == 'littleKids' ||
        profile?.governance.contentLevel.name == 'kids' ||
        profile?.governance.contentLevel.name == 'olderKids';
    if (childLike) {
      if (text.contains('nightmare before christmas')) score += 90;
      if (text.contains('goosebumps')) score += 50;
      if (text.contains('hocus pocus')) score += 45;
      if (text.contains('family') || text.contains('animation')) score += 20;
      if (text.contains('slasher') || text.contains('friday the 13th')) score -= 400;
      if (text.contains('nightmare on elm street')) score -= 400;
    }
    return score;
  }

  static String describeSeasonalBehavior(Profile? profile) {
    final season = activeSeason();
    final child = profile?.governance.contentLevel.name == 'littleKids' ||
        profile?.governance.contentLevel.name == 'kids' ||
        profile?.governance.contentLevel.name == 'olderKids';
    if (season == 'halloween' && child) {
      return 'October is emphasizing family-friendly Halloween titles and themed episodes while filtering stronger slasher content.';
    }
    if (season == 'halloween') return 'October is emphasizing Halloween, horror, slasher, spooky and themed-episode content.';
    if (season == 'christmas') return 'December is emphasizing Christmas, holiday, winter and family titles and episodes.';
    if (season == 'valentines') return "February is emphasizing romantic and Valentine's titles.";
    return 'Seasonal priorities are currently neutral.';
  }
}
