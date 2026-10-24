import '../../app_core.dart';

/// Resolves language defaults for playback controls from trusted media metadata
/// and a small set of explicit title/franchise rules.
///
/// This class does not claim a track exists: [bestTrack] only returns values
/// present in the supplied list. Callers must still pass the resulting track
/// to a playback engine that supports track selection.
class OriginalLanguageDefaults {
  OriginalLanguageDefaults._();

  static const Map<String, String> _knownBondTitles = <String, String>{
    'dr no': 'en',
    'from russia with love': 'en',
    'goldfinger': 'en',
    'thunderball': 'en',
    'you only live twice': 'en',
    'on her majestys secret service': 'en',
    'diamonds are forever': 'en',
    'live and let die': 'en',
    'the man with the golden gun': 'en',
    'the spy who loved me': 'en',
    'moonraker': 'en',
    'for your eyes only': 'en',
    'octopussy': 'en',
    'a view to a kill': 'en',
    'the living daylights': 'en',
    'licence to kill': 'en',
    'license to kill': 'en',
    'goldeneye': 'en',
    'tomorrow never dies': 'en',
    'the world is not enough': 'en',
    'die another day': 'en',
    'casino royale': 'en',
    'quantum of solace': 'en',
    'skyfall': 'en',
    'spectre': 'en',
    'no time to die': 'en',
  };

  static const Map<String, String> _explicitTitleLanguages = <String, String>{
    'parasite': 'ko',
    'parasitos': 'ko',
    'gisaengchung': 'ko',
    'squid game': 'ko',
    'ojingeo geim': 'ko',
    'la leyenda de la nahuala': 'es',
    'la leyenda de la nanahuala': 'es',
    'la leyenda de la llorona': 'es',
    'la leyenda de las momias de guanajuato': 'es',
    'la leyenda del chupacabras': 'es',
    'la leyenda de los chaneques': 'es',
    'la llorona': 'es',
    'llorona': 'es',
    'las momias de guanajuato': 'es',
    'momias de guanajuato': 'es',
    'el chupacabras': 'es',
    'chupacabras': 'es',
    'la leyenda del charro negro': 'es',
    'charro negro': 'es',
  };

  static const Map<String, List<String>> _languageAliases =
      <String, List<String>>{
    'en': <String>['english', 'eng', 'en-us', 'en-gb', 'en-ca', 'en-au'],
    'es': <String>[
      'spanish',
      'espanol',
      'castilian',
      'castellano',
      'spa',
      'es-es',
      'es-mx',
      'es-419',
      'latino'
    ],
    'ko': <String>['korean', 'kor', '한국어', 'hangul'],
    'fr': <String>['french', 'francais', 'fra', 'fre'],
    'ja': <String>['japanese', 'jpn', '日本語'],
    'de': <String>['german', 'deutsch', 'deu', 'ger'],
    'pt': <String>['portuguese', 'portugues', 'por', 'pt-br', 'pt-pt'],
    'it': <String>['italian', 'italiano', 'ita'],
    'zh': <String>['chinese', 'mandarin', '中文', 'zho', 'chi', 'cmn'],
    'ru': <String>['russian', 'русский', 'rus'],
    'hi': <String>['hindi', 'हिन्दी', 'hin'],
    'ar': <String>['arabic', 'العربية', 'ara'],
  };

  static String? resolveForMedia(MediaItem media) => resolveFromFields(
        title: media.title,
        originalTitle: media.originalTitle,
        canonicalTitle: media.canonicalTitle,
        originalLanguage: media.originalLanguage,
        language: media.language,
        countryOfOrigin: media.countryOfOrigin,
        franchiseName: media.franchiseName,
        franchiseNames: media.franchiseNames,
        cinematicUniverseNames: media.cinematicUniverseNames,
        cinematicUniverseIds: media.cinematicUniverseIds,
        studios: media.studios,
        companies: media.companies,
      );

  /// Field-level version also supports metadata inference during import before
  /// a complete MediaItem has been assembled.
  static String? resolveFromFields({
    required String title,
    String? originalTitle,
    String? canonicalTitle,
    String? originalLanguage,
    String? language,
    String? countryOfOrigin,
    String? franchiseName,
    Iterable<String> franchiseNames = const <String>[],
    Iterable<String> cinematicUniverseNames = const <String>[],
    Iterable<String> cinematicUniverseIds = const <String>[],
    Iterable<String> studios = const <String>[],
    Iterable<String> companies = const <String>[],
  }) {
    final titles = <String>{
      _normalize(title),
      _normalize(originalTitle ?? ''),
      _normalize(canonicalTitle ?? ''),
    }..removeWhere((value) => value.isEmpty);

    // Explicit user examples and known franchise rules are applied before a
    // sometimes-missing or incorrect provider language field.
    for (final titleValue in titles) {
      final exact = _explicitTitleLanguages[titleValue];
      if (exact != null) {
        return exact;
      }
      for (final entry in _explicitTitleLanguages.entries) {
        if (titleValue.startsWith('${entry.key} ')) {
          return entry.value;
        }
      }
    }

    final franchiseMetadata = <String>[
      franchiseName ?? '',
      ...franchiseNames,
      ...cinematicUniverseNames,
      ...cinematicUniverseIds,
      ...studios,
      ...companies,
    ].map(_normalize).join(' ');
    final titleMetadata = titles.join(' ');

    if (_isJamesBond(franchiseMetadata, titleMetadata)) {
      return 'en';
    }
    if (_isMarvel(franchiseMetadata, titleMetadata)) {
      return 'en';
    }

    final fromMetadata = canonicalLanguageCode(originalLanguage) ??
        canonicalLanguageCode(language);
    if (fromMetadata != null) {
      return fromMetadata;
    }

    return _languageFromOrigin(countryOfOrigin);
  }

  /// Converts ISO language codes, bibliographic codes, and common display
  /// labels into a short canonical code (for example `Korean` -> `ko`).
  static String? canonicalLanguageCode(String? raw) {
    final value = _normalize(raw ?? '');
    if (value.isEmpty) {
      return null;
    }
    final firstToken = value.split(' ').first;
    if (_languageAliases.containsKey(firstToken)) {
      return firstToken;
    }
    for (final entry in _languageAliases.entries) {
      if (value == entry.key ||
          value == '${entry.key} language' ||
          entry.value.any((alias) {
            final normalizedAlias = _normalize(alias);
            return value == normalizedAlias ||
                value.startsWith('$normalizedAlias ') ||
                value.endsWith(' $normalizedAlias') ||
                value.contains(' $normalizedAlias ');
          })) {
        return entry.key;
      }
    }
    return null;
  }

  /// Selects a language-matching option if present. If it is not available,
  /// prefers a non-forced/non-commentary track, then falls back to the first
  /// available option. It never fabricates a track ID or label.
  static String? bestTrack(
    Iterable<String> rawTracks, {
    required String? targetLanguage,
    bool subtitles = false,
    bool preferAudioDescription = false,
  }) {
    final tracks = rawTracks
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tracks.isEmpty) {
      return null;
    }

    final target = canonicalLanguageCode(targetLanguage) ?? targetLanguage;
    if (target != null && target.isNotEmpty) {
      final matching = tracks.where((track) =>
          canonicalLanguageCode(track) == target ||
          _languageCodeFromLabel(track) == target).toList(growable: false);
      if (matching.isNotEmpty) {
        return _preferredTrack(
          matching,
          subtitles: subtitles,
          preferAudioDescription: preferAudioDescription,
        );
      }
    }

    return _preferredTrack(
      tracks,
      subtitles: subtitles,
      preferAudioDescription: preferAudioDescription,
    );
  }

  static String _preferredTrack(
    List<String> tracks, {
    required bool subtitles,
    required bool preferAudioDescription,
  }) {
    if (subtitles) {
      final nonForced = tracks.where(
        (track) => !_normalize(track).contains('forced'),
      );
      return nonForced.isNotEmpty ? nonForced.first : tracks.first;
    }

    final nonCommentary = tracks.where((track) {
      final label = _normalize(track);
      return !label.contains('commentary') &&
          !label.contains('directors commentary');
    }).toList(growable: false);
    final audioCandidates = nonCommentary.isEmpty ? tracks : nonCommentary;
    final descriptions = audioCandidates.where((track) {
      final label = _normalize(track);
      return label.contains('audio description') ||
          label.contains('descriptive audio');
    });
    final regularAudio = audioCandidates.where((track) {
      final label = _normalize(track);
      return !label.contains('audio description') &&
          !label.contains('descriptive audio');
    });
    if (preferAudioDescription && descriptions.isNotEmpty) {
      return descriptions.first;
    }
    if (!preferAudioDescription && regularAudio.isNotEmpty) {
      return regularAudio.first;
    }
    return audioCandidates.first;
  }

  static String displayName(String? code) {
    switch (canonicalLanguageCode(code)) {
      case 'en': return 'English';
      case 'es': return 'Spanish';
      case 'ko': return 'Korean';
      case 'fr': return 'French';
      case 'ja': return 'Japanese';
      case 'de': return 'German';
      case 'pt': return 'Portuguese';
      case 'it': return 'Italian';
      case 'zh': return 'Chinese';
      case 'ru': return 'Russian';
      case 'hi': return 'Hindi';
      case 'ar': return 'Arabic';
      default: return code?.trim().isNotEmpty == true ? code!.trim() : 'Original language';
    }
  }

  static bool _isJamesBond(String franchiseMetadata, String titles) {
    if (franchiseMetadata.contains('james bond') ||
        franchiseMetadata.contains('007') ||
        franchiseMetadata.contains('bond franchise')) {
      return true;
    }
    return _knownBondTitles.keys.any((title) =>
        RegExp('(^| )${RegExp.escape(title)}( |\$)').hasMatch(titles));
  }

  static bool _isMarvel(String franchiseMetadata, String titles) {
    if (franchiseMetadata.contains('marvel') ||
        franchiseMetadata.contains('mcu') ||
        franchiseMetadata.contains('avengers cinematic universe')) {
      return true;
    }
    const titleMarkers = <String>[
      'avengers', 'iron man', 'captain america', 'captain marvel', 'the marvels',
      'thor', 'guardians of the galaxy', 'doctor strange', 'black panther',
      'black widow', 'ant man', 'antman', 'deadpool', 'x men', 'fantastic four',
      'spider man', 'spider verse', 'spiderverse', 'venom', 'wolverine', 'logan',
      'blade', 'eternals', 'shang chi', 'thunderbolts', 'morbius',
      'kraven the hunter', 'madame web', 'ghost rider', 'elektra', 'punisher',
      'new mutants', 'daredevil', 'the incredible hulk', 'werewolf by night',
    ];
    return titleMarkers.any((marker) =>
        RegExp('(^| )${RegExp.escape(marker)}( |\$)').hasMatch(titles));
  }

  static String? _languageFromOrigin(String? rawOrigin) {
    final origin = _normalize(rawOrigin ?? '');
    if (origin.isEmpty) {
      return null;
    }
    if (const <String>{
      'mx', 'es', 'ar', 'cl', 'co', 'pe', 've', 'ec', 'bo', 'py', 'uy',
      'gt', 'hn', 'sv', 'ni', 'cr', 'pa', 'do', 'cu', 'pr'
    }.contains(origin) || origin == 'latin america') {
      return 'es';
    }
    if (origin == 'kr') {
      return 'ko';
    }
    if (const <String>{'us', 'usa', 'gb', 'uk', 'ie', 'au', 'nz', 'ca'}
        .contains(origin)) {
      return 'en';
    }
    if (origin == 'fr') {
      return 'fr';
    }
    if (origin == 'jp') {
      return 'ja';
    }
    if (origin == 'de' || origin == 'at') {
      return 'de';
    }
    if (origin == 'br') {
      return 'pt';
    }
    if (origin == 'it') {
      return 'it';
    }
    if (origin == 'cn' || origin == 'tw') {
      return 'zh';
    }
    if (origin == 'ru') {
      return 'ru';
    }
    if (_containsAny(origin, <String>[
      'mexico', 'espana', 'spain', 'argentina', 'chile', 'colombia', 'peru',
      'venezuela', 'ecuador', 'bolivia', 'paraguay', 'uruguay', 'guatemala',
      'honduras', 'el salvador', 'nicaragua', 'costa rica', 'panama',
      'dominican republic', 'cuba', 'puerto rico',
    ])) {
      return 'es';
    }
    if (_containsAny(origin, <String>['south korea', 'republic of korea', 'korea'])) {
      return 'ko';
    }
    if (origin == 'uk' ||
        _containsAny(origin, <String>[
          'united states', 'usa', 'united kingdom', 'england', 'scotland',
          'wales', 'ireland', 'australia', 'new zealand', 'canada'
        ])) {
      return 'en';
    }
    if (_containsAny(origin, <String>['france'])) {
      return 'fr';
    }
    if (_containsAny(origin, <String>['japan'])) {
      return 'ja';
    }
    if (_containsAny(origin, <String>['germany', 'austria'])) {
      return 'de';
    }
    if (_containsAny(origin, <String>['brazil'])) {
      return 'pt';
    }
    if (_containsAny(origin, <String>['italy'])) {
      return 'it';
    }
    if (_containsAny(origin, <String>['china', 'taiwan'])) {
      return 'zh';
    }
    if (_containsAny(origin, <String>['russia'])) {
      return 'ru';
    }
    return null;
  }

  static String? _languageCodeFromLabel(String value) {
    final normalized = _normalize(value);
    for (final entry in _languageAliases.entries) {
      for (final alias in entry.value) {
        final candidate = _normalize(alias);
        if (normalized == candidate ||
            normalized.startsWith('$candidate ') ||
            normalized.endsWith(' $candidate') ||
            normalized.contains(' $candidate ')) {
          return entry.key;
        }
      }
    }
    // Track labels and technical IDs often contain ISO-639 codes as tokens.
    for (final entry in _languageAliases.entries) {
      final codes = <String>[entry.key];
      if (entry.key == 'en') {
        codes.add('eng');
      }
      if (entry.key == 'es') {
        codes.add('spa');
      }
      if (entry.key == 'ko') {
        codes.add('kor');
      }
      if (entry.key == 'fr') {
        codes.addAll(<String>['fra', 'fre']);
      }
      if (entry.key == 'de') {
        codes.addAll(<String>['deu', 'ger']);
      }
      if (entry.key == 'pt') {
        codes.add('por');
      }
      if (entry.key == 'it') {
        codes.add('ita');
      }
      if (entry.key == 'ja') {
        codes.add('jpn');
      }
      if (entry.key == 'zh') {
        codes.addAll(<String>['zho', 'chi']);
      }
      if (codes.any((code) => RegExp('(^|[^a-z])${RegExp.escape(code)}([^a-z]|\$)').hasMatch(normalized))) {
        return entry.key;
      }
    }
    return null;
  }

  static bool _containsAny(String value, Iterable<String> parts) =>
      parts.any((part) => value.contains(_normalize(part)));

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll(RegExp(r'[^a-z0-9\u0080-\uFFFF]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
