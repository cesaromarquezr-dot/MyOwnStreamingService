import '../../app_core.dart';
import '../../music.dart';
import '../../shop.dart';

/// A locally resolved Hey Media request. Results are sourced from the media
/// and marketplace catalogs already available to the signed-in account.
enum MediaAiReplyKind {
  unseenLibrary,
  movieMarathon,
  christmasMarathon,
  giftProducts,
  latestAlbum,
}

class MediaAiPlanEntry {
  final int dayNumber;
  final MediaItem media;
  final DateTime? calendarDate;

  const MediaAiPlanEntry({
    required this.dayNumber,
    required this.media,
    this.calendarDate,
  });
}

class MediaAiReply {
  final MediaAiReplyKind kind;
  final String text;
  final List<MediaItem> mediaItems;
  final List<ShopProduct> products;
  final List<MediaAiPlanEntry> plan;
  final List<String> infoItems;

  const MediaAiReply({
    required this.kind,
    required this.text,
    this.mediaItems = const <MediaItem>[],
    this.products = const <ShopProduct>[],
    this.plan = const <MediaAiPlanEntry>[],
    this.infoItems = const <String>[],
  });
}

/// Local intent resolver for common questions about a user's own server.
/// It intentionally never fabricates library titles or marketplace listings.
/// A hosted generative-model provider can be added behind this interface later.
class MediaAiAssistantService {
  const MediaAiAssistantService();

  Future<MediaAiReply?> answer(String prompt, {DateTime? now}) async {
    final clean = _normalize(prompt);
    if (clean.isEmpty) return null;

    if (_asksForUnseen(clean)) return _unseenReply();
    if (_asksForGift(clean)) return _giftReply(clean);
    if (_asksForLatestAlbum(clean)) return _latestAlbumReply();
    if (_asksForMarathon(clean)) {
      return _marathonReply(clean, now ?? DateTime.now());
    }
    return null;
  }

  String _normalize(String input) {
    var value = input.toLowerCase().trim();
    value = value
        .replaceAll("haven't", 'havent')
        .replaceAll("hasn't", 'hasnt')
        .replaceAll("what's", 'whats')
        .replaceAll("i've", 'ive')
        .replaceAll("i'm", 'im')
        .replaceAll("you're", 'youre')
        .replaceAll("it's", 'its');
    value = value.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.startsWith('hey media ')) value = value.substring(10).trim();
    if (value == 'hey media') return '';
    if (value.startsWith('hello media ')) value = value.substring(12).trim();
    return value;
  }

  bool _asksForUnseen(String value) {
    final asksAboutViewing = value.contains('movie') ||
        value.contains('tv show') ||
        value.contains('television') ||
        value.contains('what have i') ||
        value.contains('what tv') ||
        value.contains('what movie') ||
        value.contains('what show');
    final asksNotSeen = value.contains('havent seen') ||
        value.contains('have not seen') ||
        value.contains('hasnt seen') ||
        value.contains('not seen') ||
        value.contains('havent watched') ||
        value.contains('have not watched') ||
        value.contains('not watched') ||
        value.contains('unwatched') ||
        value.contains('never watched');
    return asksNotSeen && (asksAboutViewing || value.contains('what'));
  }

  bool _asksForGift(String value) =>
      value.contains('gift') &&
      (value.contains('fan of') ||
          value.contains('fan') ||
          value.contains('related to') ||
          value.contains('for a friend'));

  bool _asksForLatestAlbum(String value) {
    final album = value.contains('album');
    final recency = value.contains('latest') ||
        value.contains('newest') ||
        value.contains('most recent') ||
        value.contains('recent album');
    return album && recency;
  }

  bool _asksForMarathon(String value) {
    final hasMarathon = value.contains('marathon') ||
        value.contains('movie schedule') ||
        value.contains('movie plan');
    final christmasPlan = value.contains('christmas') &&
        (value.contains('25 day') ||
            value.contains('25 days') ||
            value.contains('marathon') ||
            value.contains('days of christmas'));
    return hasMarathon || christmasPlan;
  }

  bool _visibleToCurrentProfile(MediaItem media) {
    final profile = AppController.instance.currentProfile;
    if (media.accessibleProfileIds.isEmpty) return true;
    if (profile == null) return false;
    return media.accessibleProfileIds.contains(profile.id);
  }

  String _compactType(String type) =>
      type.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool _isMovie(MediaItem item) {
    final type = _compactType(item.type);
    return const <String>{
      'movie', 'movies', 'film', 'films', 'featurefilm', 'feature', 'video'
    }.contains(type);
  }

  bool _isTvShow(MediaItem item) {
    final type = _compactType(item.type);
    return const <String>{
      'tvshow', 'show', 'series', 'tvseries', 'televisionshow', 'tv'
    }.contains(type);
  }

  bool _isAlbum(MediaItem item) => _compactType(item.type) == 'album';

  MediaAiReply _unseenReply() {
    final controller = AppController.instance;
    final profileName = controller.currentProfile?.name.trim() ?? '';
    final unseen = controller.library.where((item) {
      if (!_visibleToCurrentProfile(item)) return false;
      if (!_isMovie(item) && !_isTvShow(item)) return false;
      if (controller.isWatched(item.id)) return false;
      // A partially watched title should not be described as completely unseen.
      return controller.getPlaybackProgress(item.id) <= 0.01;
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    if (unseen.isEmpty) {
      final libraryLabel = profileName.isEmpty
          ? 'the library available to the current profile'
          : 'the library available to $profileName';
      return MediaAiReply(
        kind: MediaAiReplyKind.unseenLibrary,
        text: 'I couldn’t find any completely unseen movies or TV shows in '
            '$libraryLabel. If you recently added media, refresh/sync the '
            'server library and ask me again.',
      );
    }

    final profilePhrase = profileName.isEmpty
        ? 'that have not been watched by the current profile'
        : 'that $profileName has not watched yet';
    return MediaAiReply(
      kind: MediaAiReplyKind.unseenLibrary,
      text: 'Here are ${unseen.length} movie or TV show '
          '${unseen.length == 1 ? 'title' : 'titles'} in your accessible library '
          '$profilePhrase. I sorted them by title.',
      mediaItems: unseen,
    );
  }

  MediaAiReply _marathonReply(String value, DateTime now) {
    final christmas = value.contains('christmas') || value.contains('xmas');
    final month = _requestedMonth(value, christmas: christmas, now: now);
    final explicitCount = RegExp(r'\b(\d{1,2})\s+days?\b').firstMatch(value);
    int count;
    if (explicitCount != null) {
      count = int.tryParse(explicitCount.group(1) ?? '') ?? 0;
    } else if (christmas) {
      count = 25;
    } else if (month != null) {
      count = DateTime(month.year, month.month + 1, 0).day;
    } else {
      count = 31;
    }
    count = count.clamp(1, 62).toInt();

    final controller = AppController.instance;
    final movies = controller.library.where((item) {
      return _visibleToCurrentProfile(item) && _isMovie(item);
    }).toList();

    final candidates = christmas
        ? movies.where(_isChristmasMovie).toList()
        : movies.toList();
    final selected = _pickMarathonTitles(
      candidates,
      requested: count,
      preferSpooky: !christmas &&
          (value.contains('october') || value.contains('halloween')),
      controller: controller,
    );

    final profileName = controller.currentProfile?.name.trim() ?? '';
    final planDate = month;
    final heading = christmas ? 'Christmas movie plan' : 'movie marathon';
    final greeting = profileName.isEmpty ? '' : ' $profileName';

    if (selected.isEmpty) {
      return MediaAiReply(
        kind: christmas
            ? MediaAiReplyKind.christmasMarathon
            : MediaAiReplyKind.movieMarathon,
        text: 'I couldn’t find any ${christmas ? 'Christmas' : ''} movie titles '
            'in the library available to this profile, so I can’t build a '
            'real schedule yet. Sync the server library or add the relevant '
            'movies, then ask me again.',
      );
    }

    final plan = <MediaAiPlanEntry>[];
    for (var i = 0; i < selected.length; i++) {
      DateTime? date;
      if (planDate != null) {
        date = DateTime(planDate.year, planDate.month, planDate.day + i);
      }
      plan.add(MediaAiPlanEntry(
        dayNumber: i + 1,
        media: selected[i],
        calendarDate: date,
      ));
    }

    var message = 'Absolutely$greeting! Here is your $heading with '
        '${selected.length} real title${selected.length == 1 ? '' : 's'} from '
        'your server library.';
    if (selected.length < count) {
      message += ' I found only ${selected.length} eligible '
          '${christmas ? 'Christmas ' : ''}movies, so I have not invented '
          'titles or repeated movies to fill all $count days.';
    }
    if (christmas && planDate == null) {
      message += ' The schedule is numbered for 25 days; it is not tied to '
          'specific calendar dates.';
    }

    return MediaAiReply(
      kind: christmas
          ? MediaAiReplyKind.christmasMarathon
          : MediaAiReplyKind.movieMarathon,
      text: message,
      mediaItems: selected,
      plan: plan,
    );
  }

  DateTime? _requestedMonth(
    String value, {
    required bool christmas,
    required DateTime now,
  }) {
    const months = <String, int>{
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    int? requested;
    for (final entry in months.entries) {
      if (value.contains(entry.key)) {
        requested = entry.value;
        break;
      }
    }
    if (requested == null && christmas) requested = 12;
    if (requested == null) return null;

    var year = now.year;
    if (requested < now.month ||
        (requested == now.month && christmas && now.day > 25)) {
      year++;
    }
    return DateTime(year, requested, 1);
  }

  bool _isChristmasMovie(MediaItem media) {
    final haystack = <String>[
      media.title,
      media.description ?? '',
      ...media.genres,
      ...media.tags,
      media.franchiseName ?? '',
    ].join(' ').toLowerCase();
    return <String>[
      'christmas', 'xmas', 'santa', 'noel', 'holiday', 'nativity',
      'north pole', 'rudolph', 'frosty', 'mistletoe',
    ].any((term) => haystack.contains(term));
  }

  bool _isSpookyMovie(MediaItem media) {
    final haystack = <String>[
      media.title,
      media.description ?? '',
      ...media.genres,
      ...media.tags,
      media.franchiseName ?? '',
    ].join(' ').toLowerCase();
    return <String>[
      'horror', 'thriller', 'suspense', 'mystery', 'supernatural',
      'slasher', 'halloween', 'spooky', 'ghost', 'vampire', 'monster',
      'witch', 'zombie', 'haunted',
    ].any((term) => haystack.contains(term));
  }

  List<MediaItem> _pickMarathonTitles(
    List<MediaItem> candidates, {
    required int requested,
    required bool preferSpooky,
    required AppController controller,
  }) {
    final remaining = List<MediaItem>.from(candidates);
    final selected = <MediaItem>[];
    final genreCounts = <String, int>{};
    final franchiseCounts = <String, int>{};

    String primaryGenre(MediaItem media) {
      if (media.genres.isNotEmpty && media.genres.first.trim().isNotEmpty) {
        return media.genres.first.trim().toLowerCase();
      }
      if (media.tags.isNotEmpty && media.tags.first.trim().isNotEmpty) {
        return media.tags.first.trim().toLowerCase();
      }
      return 'other';
    }

    String franchise(MediaItem media) =>
        (media.franchiseName ?? media.franchiseId ?? '').trim().toLowerCase();

    while (remaining.isNotEmpty && selected.length < requested) {
      remaining.sort((a, b) {
        int score(MediaItem media) {
          var result = 0;
          if (!controller.isWatched(media.id) &&
              controller.getPlaybackProgress(media.id) <= 0.01) {
            result += 30;
          }
          if (preferSpooky && _isSpookyMovie(media)) result += 18;
          final genre = primaryGenre(media);
          result -= (genreCounts[genre] ?? 0) * 5;
          final series = franchise(media);
          if (series.isNotEmpty) result -= (franchiseCounts[series] ?? 0) * 7;
          final rating = media.userRatingStars ?? media.audienceRating ?? media.rating ?? 0;
          result += rating.round();
          return result;
        }
        return score(b).compareTo(score(a));
      });
      final chosen = remaining.removeAt(0);
      selected.add(chosen);
      final genre = primaryGenre(chosen);
      genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      final series = franchise(chosen);
      if (series.isNotEmpty) {
        franchiseCounts[series] = (franchiseCounts[series] ?? 0) + 1;
      }
    }
    return selected;
  }

  MediaAiReply _giftReply(String value) {
    var fandom = _extractFandom(value);
    if (fandom.isEmpty) {
      return const MediaAiReply(
        kind: MediaAiReplyKind.giftProducts,
        text: 'Which movie or TV show is your friend a fan of? Tell me the title, and I’ll search the currently available Store catalog for related products.',
      );
    }
    final fandomKey = fandom.toLowerCase();
    final aliases = <String>{fandomKey};
    if (fandomKey.contains('how i met your mother') ||
        fandomKey.contains('how i met you mother') ||
        fandomKey == 'himym') {
      fandom = 'How I Met Your Mother';
      aliases
        ..add('how i met your mother')
        ..add('how i met you mother')
        ..add('himym')
        ..add('barney stinson')
        ..add('ted mosby')
        ..add('robin scherbatsky')
        ..add('lily aldrin')
        ..add('marshall eriksen')
        ..add('maclarens pub')
        ..add('slap bet')
        ..add('pineapple incident');
    }

    final products = <({ShopProduct product, int score})>[];
    for (final product in ShopCatalog.instance.products) {
      if (!product.active || product.inventoryQuantity <= 0) continue;
      final associatedNames = product.associations
          .map((association) => association.name.toLowerCase())
          .join(' ');
      final haystack = _normalize(<String>[
        product.name,
        product.description,
        product.category,
        product.productType,
        associatedNames,
      ].join(' '));
      var score = 0;
      for (final alias in aliases) {
        if (alias.trim().isEmpty) continue;
        if (haystack.contains(alias)) score += alias == fandomKey ? 100 : 70;
      }
      final terms = fandom.toLowerCase().split(' ').where((term) => term.length > 2).toList();
      if (score == 0 && terms.isNotEmpty && terms.every((term) => haystack.contains(term))) {
        score = 30;
      }
      if (score > 0) {
        if (product.featured) score += 2;
        products.add((product: product, score: score));
      }
    }
    products.sort((a, b) => b.score.compareTo(a.score));
    final matches = products.take(12).map((entry) => entry.product).toList();

    if (matches.isEmpty) {
      return MediaAiReply(
        kind: MediaAiReplyKind.giftProducts,
        text: 'I checked the currently loaded, in-stock marketplace listings but '
            'couldn’t find a product explicitly related to $fandom. I won’t '
            'invent a listing; try searching the Store or adding product '
            'associations for this show.',
      );
    }

    return MediaAiReply(
      kind: MediaAiReplyKind.giftProducts,
      text: 'Here are ${matches.length} related gift '
          '${matches.length == 1 ? 'option' : 'options'} for a fan of $fandom '
          'that are currently in stock in your Store catalog.',
      products: matches,
    );
  }

  String _extractFandom(String value) {
    final patterns = <RegExp>[
      RegExp(r'fan of (.+)$'),
      RegExp(r'related to (.+)$'),
      RegExp(r'big fan of (.+)$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(value);
      if (match != null && match.group(1) != null) {
        var target = match.group(1)!.trim();
        target = target.replaceFirst(
          RegExp(r'\s+(and i|and can|can you|please|for them|for my friend).*$'),
          '',
        ).trim();
        if (target.isNotEmpty) return _canonicalFandom(target);
      }
    }
    if (value.contains('himym') ||
        value.contains('how i met your mother') ||
        value.contains('how i met you mother')) {
      return 'How I Met Your Mother';
    }
    return '';
  }

  String _canonicalFandom(String target) {
    final normalized = target.trim().toLowerCase();
    if (normalized.contains('how i met your mother') ||
        normalized.contains('how i met you mother') ||
        normalized == 'himym') {
      return 'How I Met Your Mother';
    }
    if (normalized.contains('harry potter')) return 'Harry Potter';
    if (normalized == 'marvel' || normalized.contains('avengers')) return 'Marvel / Avengers';
    if (normalized == 'dc' || normalized.contains('dc comics')) return 'DC';
    return target.trim();
  }

  MediaAiReply _latestAlbumReply() {
    final controller = AppController.instance;
    final albums = controller.library
        .where((item) => _visibleToCurrentProfile(item) && _isAlbum(item))
        .toList();
    final dated = albums.where((item) => item.releaseYear != null).toList()
      ..sort((a, b) => (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0));

    if (dated.isNotEmpty) {
      final newest = dated.first;
      return MediaAiReply(
        kind: MediaAiReplyKind.latestAlbum,
        text: 'The newest album release I can verify from your server library is '
            '“${newest.title}” (${newest.releaseYear}). I’m using the release-year '
            'metadata currently recorded for that album.',
        mediaItems: <MediaItem>[newest],
      );
    }

    final trackAlbums = <String, Map<String, dynamic>>{};
    for (final track in MusicLibraryStore.instance.tracks) {
      final album = track.album.trim();
      final albumKey = album.toLowerCase();
      if (album.isEmpty ||
          albumKey == 'unknown album' ||
          albumKey == 'server library') {
        continue;
      }
      final artist = track.artist.trim();
      final artistKey = artist.toLowerCase();
      final key = '$albumKey|$artistKey';
      final existing = trackAlbums[key];
      final modifiedAt = track.modifiedAt;
      final currentDate = existing?['modifiedAt'] as DateTime?;
      if (existing == null ||
          (modifiedAt != null &&
              (currentDate == null || modifiedAt.isAfter(currentDate)))) {
        trackAlbums[key] = <String, dynamic>{
          'album': album,
          'artist': artist,
          'modifiedAt': modifiedAt,
        };
      }
    }

    final recentlyModified = trackAlbums.values
        .where((item) => item['modifiedAt'] is DateTime)
        .toList()
      ..sort((a, b) => (b['modifiedAt'] as DateTime)
          .compareTo(a['modifiedAt'] as DateTime));

    if (recentlyModified.isNotEmpty) {
      final newest = recentlyModified.first;
      final album = newest['album'] as String;
      final artist = (newest['artist'] as String?) ?? '';
      final modifiedAt = (newest['modifiedAt'] as DateTime).toLocal();
      final timestamp = '${modifiedAt.year.toString().padLeft(4, '0')}-'
          '${modifiedAt.month.toString().padLeft(2, '0')}-'
          '${modifiedAt.day.toString().padLeft(2, '0')}';
      return MediaAiReply(
        kind: MediaAiReplyKind.latestAlbum,
        text: 'The most recently updated album folder I can identify on your '
            'server is “$album”${artist.isEmpty ? '' : ' by $artist'} (audio '
            'file timestamp: $timestamp). This indicates recent file activity, '
            'not necessarily the album’s official release date.',
        infoItems: <String>['$album${artist.isEmpty ? '' : ' — $artist'}'],
      );
    }

    final names = albums.map((album) => album.title).toSet().toList();
    names.addAll(trackAlbums.values
        .map((item) => item['album'] as String)
        .where((name) => !names.any(
            (existing) => existing.toLowerCase() == name.toLowerCase())));
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (names.isEmpty) {
      return const MediaAiReply(
        kind: MediaAiReplyKind.latestAlbum,
        text: 'I couldn’t find album metadata in the loaded server library yet. '
            'Sync the music library and organize tracks into Artist/Album folders '
            'or add album release-year metadata, then ask me again.',
      );
    }

    return MediaAiReply(
      kind: MediaAiReplyKind.latestAlbum,
      text: 'I found ${names.length} album${names.length == 1 ? '' : 's'} on '
          'your server, but their release years and file-modified timestamps '
          'are missing. I can list the albums, but I can’t honestly identify '
          'which one is newest until that metadata is available.',
      infoItems: names.take(12).toList(),
    );
  }
}
