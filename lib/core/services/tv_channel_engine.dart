import '../../app_core.dart';
import '../models/tv_channel.dart';
import 'tv_programming_service.dart';

class TvChannelEngine {
  TvChannelEngine._();
  static final TvChannelEngine instance = TvChannelEngine._();

  // Channels are supplied by the account; this service never creates
  // themed channel definitions.


  TvContentIntelligence classify(MediaItem media) {
    final fields = <String>[
      media.title,
      media.description ?? '',
      media.franchiseName ?? '',
      media.franchiseType ?? '',
      ...media.genres,
      ...media.tags,
      ...media.studios,
      ...media.companies,
      ...media.relationshipTypes,
      ...media.actors,
      ...media.directors,
      ...media.writers,
    ].join(' ').toLowerCase();

    final hit = <String>{};
    for (final token in const [
      'action', 'adventure', 'animation', 'comedy', 'crime', 'drama', 'fantasy',
      'horror', 'romance', 'rom-com', 'science fiction', 'sci-fi', 'sitcom',
      'family', 'thriller', 'musical', 'documentary', 'slasher', 'superhero',
    ]) {
      if (fields.contains(token)) hit.add(token);
    }

    final holidays = <String>{};
    if (fields.contains('halloween') || fields.contains('spooky') || fields.contains('goosebumps')) holidays.add('halloween');
    if (fields.contains('christmas') || fields.contains('holiday') || fields.contains('winter')) holidays.add('christmas');
    if (fields.contains('valentine') || fields.contains('romance') || fields.contains('rom-com')) holidays.add('valentines');

    final franchises = <String>{};
    for (final token in const [
      'marvel', 'spider-man', 'x-men', 'avengers', 'harry potter', 'fantastic beasts',
      'twilight', 'fast & furious', 'hobbs & shaw', 'friends', 'goosebumps',
      'friday the 13th', "child's play", 'scream', 'fear street',
    ]) {
      if (fields.contains(token)) franchises.add(token);
    }

    final audiences = <String>{};
    if (fields.contains('family') || fields.contains('kids') || fields.contains('children') || fields.contains('animation')) audiences.add('family');
    if (fields.contains('slasher') || fields.contains('gore') || fields.contains('explicit') || fields.contains('extreme violence')) audiences.add('mature');

    final themes = <String>{};
    if (fields.contains('spider-man') || fields.contains('superhero') || fields.contains('avengers')) themes.add('superhero');
    if (fields.contains('sitcom') || fields.contains('friends') || fields.contains('modern family')) themes.add('sitcom');
    if (fields.contains('romance') || fields.contains('rom-com')) themes.add('romance');
    if (fields.contains('horror') || fields.contains('slasher') || fields.contains('spooky')) themes.add('spooky');

    final type = media.type.toLowerCase();
    return TvContentIntelligence(
      genres: hit,
      tags: media.tags.map((e) => e.toLowerCase()).toSet(),
      franchises: franchises,
      holidays: holidays,
      audiences: audiences,
      themes: themes,
      isEpisode: type.contains('episode') || type.contains('tv'),
      isMovie: type.contains('movie') || type.contains('film'),
    );
  }

  List<TvProgramItem> buildLineup(
    List<MediaItem> library,
    TvChannelDefinition channel, {
    Profile? profile,
    DateTime? now,
    int limit = 40,
  }) {
    final candidates = library.where((media) {
      if (profile == null || !TvProgrammingService.eligibleForProfile(media, profile)) return false;
      if (media.type.toLowerCase().contains('extra')) return false;
      final intelligence = classify(media);
      if (_isKids(profile) && intelligence.audiences.contains('mature')) return false;
      if (channel.contentTypes.isNotEmpty && !_typeAllowed(media, channel.contentTypes)) return false;
      if (channel.filters.isEmpty) return true;
      final text = _searchText(media);
      return channel.filters.any((filter) => text.contains(filter.toLowerCase()));
    }).toList();

    final scored = candidates.map((media) {
      final intelligence = classify(media);
      var score = TvProgrammingService.scoreMedia(
        media,
        channelFilter: channel.filters.join(','),
        profile: profile,
        now: now,
      );
      score += channel.priority;
      score += _intelligenceBoost(intelligence, channel, profile);
      score += _programmingRuleScore(media, channel, now ?? DateTime.now());
      return TvProgramItem(
        mediaId: media.id,
        title: media.title,
        score: score,
        durationMinutes: _duration(media),
        intelligence: intelligence,
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList(growable: false);
  }

  bool _typeAllowed(MediaItem media, List<String> types) {
    final type = media.type.toLowerCase();
    final show = type.contains('tv') || type.contains('show') || type.contains('series') || type.contains('episode');
    return types.contains(show ? 'Shows' : 'Movies');
  }

  String _searchText(MediaItem media) => <String>[
        media.title,
        media.description ?? '',
        media.franchiseName ?? '',
        ...media.genres,
        ...media.tags,
        ...media.studios,
        ...media.companies,
        ...media.relationshipTypes,
      ].join(' ').toLowerCase();

  int _programmingRuleScore(MediaItem media, TvChannelDefinition channel, DateTime now) {
    if (channel.programmingRules.isEmpty) return 0;
    final fields = _searchText(media);
    var best = 0;
    for (final rule in channel.programmingRules) {
      if (rule.months.isNotEmpty && !rule.months.contains(now.month)) continue;
      if (rule.daysOfWeek.isNotEmpty && !rule.daysOfWeek.contains(now.weekday)) continue;
      if (rule.terms.isEmpty) continue;
      final matched = rule.terms.where(fields.contains).length;
      if (matched == 0) continue;
      final multiplier = rule.nightly ? 2 : 1;
      best = best > rule.priority * matched * multiplier
          ? best
          : rule.priority * matched * multiplier;
    }
    return best;
  }

  int _intelligenceBoost(TvContentIntelligence intelligence, TvChannelDefinition channel, Profile? profile) {
    var score = 0;
    if (channel.seasonal && intelligence.holidays.contains(TvProgrammingService.activeSeason())) score += 60;
    if (_isKids(profile) && intelligence.audiences.contains('family')) score += 35;
    return score;
  }

  bool _isKids(Profile? profile) {
    final level = profile?.governance.contentLevel.name;
    return level == 'littleKids' || level == 'kids' || level == 'olderKids';
  }

  int _duration(MediaItem media) {
    final type = media.type.toLowerCase();
    final episode = type.contains('episode') || type.contains('tv') || type.contains('show') || type.contains('series');
    return episode ? 30 : 120;
  }
}
