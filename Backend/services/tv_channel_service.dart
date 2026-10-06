import '../models/tv_channel.dart';

/// Account-owned TV channel support.
///
/// The platform does not generate themed channels. Each account owns its
/// channels and decides what belongs in them. The intelligence layer and TV
/// guide operate only on the contents of a selected channel.
class TvChannelService {
  static const serviceVersion = '2';

  Map<String, dynamic> capabilities() => {
        'serviceVersion': serviceVersion,
        'automaticChannels': false,
        'accountOwnedChannels': true,
        'contentIntelligence': true,
        'seasonalScheduling': true,
        'holidayClassification': true,
        'franchiseClassification': true,
        'audienceFiltering': true,
        'epgLineups': true,
        'profileAware': true,
        'ownedLibraryOnly': true,
      };

  /// Kept for API compatibility. There are no system-generated channel
  /// definitions; the account creates its own channels.
  List<Map<String, dynamic>> channelDefinitions({bool kidsProfile = false}) =>
      const <Map<String, dynamic>>[];

  Map<String, dynamic> seasonalPolicy({DateTime? now, bool kidsProfile = false}) {
    final date = now ?? DateTime.now();
    String season = 'neutral';
    if (date.month == 2) season = 'valentines';
    if (date.month == 10) season = 'halloween';
    if (date.month == 12) season = 'christmas';
    return {
      'season': season,
      'kidsProfile': kidsProfile,
      'purpose': 'Prioritize matching programs inside each account-owned channel; never create or move channels.',
    };
  }

  Map<String, dynamic> classify(Map<String, dynamic> media) {
    final text = <String>[
      media['title']?.toString() ?? '',
      media['description']?.toString() ?? '',
      media['franchiseName']?.toString() ?? '',
      ...(media['genres'] is List
          ? (media['genres'] as List).map((e) => e.toString())
          : const <String>[]),
      ...(media['tags'] is List
          ? (media['tags'] as List).map((e) => e.toString())
          : const <String>[]),
      ...(media['studios'] is List
          ? (media['studios'] as List).map((e) => e.toString())
          : const <String>[]),
      ...(media['companies'] is List
          ? (media['companies'] as List).map((e) => e.toString())
          : const <String>[]),
      ...(media['relationshipTypes'] is List
          ? (media['relationshipTypes'] as List).map((e) => e.toString())
          : const <String>[]),
    ].join(' ').toLowerCase();

    final holidays = <String>[];
    if (text.contains('halloween') || text.contains('spooky') || text.contains('goosebumps')) holidays.add('halloween');
    if (text.contains('christmas') || text.contains('holiday') || text.contains('winter')) holidays.add('christmas');
    if (text.contains('valentine') || text.contains('romance') || text.contains('rom-com')) holidays.add('valentines');

    final tags = <String>{};
    for (final token in const [
      'action', 'adventure', 'animation', 'comedy', 'crime', 'drama', 'fantasy',
      'horror', 'romance', 'rom-com', 'science fiction', 'sci-fi', 'sitcom',
      'family', 'thriller', 'musical', 'documentary', 'slasher', 'superhero',
    ]) {
      if (text.contains(token)) tags.add(token);
    }

    return {
      'genres': tags.toList(growable: false),
      'holidays': holidays,
      'franchises': media['franchiseName']?.toString().trim().isNotEmpty == true
          ? [media['franchiseName'].toString()]
          : <String>[],
      'studios': media['studios'] is List ? (media['studios'] as List).map((e) => e.toString()).toList() : const <String>[],
      'companies': media['companies'] is List ? (media['companies'] as List).map((e) => e.toString()).toList() : const <String>[],
      'mature': text.contains('slasher') || text.contains('gore') || text.contains('explicit') || text.contains('extreme violence'),
      'family': text.contains('family') || text.contains('kids') || text.contains('children') || text.contains('animation'),
      'metadataSources': ['title', 'description', 'genres', 'tags', 'franchise', 'studios', 'companies', 'relationships', 'people'],
    };
  }
}
