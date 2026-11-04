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
    'ko': <String>['korean', 'kor', 'ko-kr', '한국어', 'hangul'],
    'tr': <String>['turkish', 'turkce', 'türkçe', 'tur', 'tr-tr'],
    'nl': <String>['dutch', 'nederlands', 'dut', 'nld'],
    'pl': <String>['polish', 'polski', 'pol'],
    'el': <String>['greek', 'ellinika', 'gre', 'ell'],
    'th': <String>['thai', 'ไทย', 'tha'],
    'vi': <String>['vietnamese', 'tieng viet', 'vie'],
    'id': <String>['indonesian', 'bahasa indonesia', 'ind'],
    'sv': <String>['swedish', 'svenska', 'swe'],
    'no': <String>['norwegian', 'norsk', 'nor'],
    'da': <String>['danish', 'dansk', 'dan'],
    'fi': <String>['finnish', 'suomi', 'fin'],
    'he': <String>['hebrew', 'ivrit', 'heb'],
    'uk': <String>['ukrainian', 'ukrayinska', 'ukr'],
    'cs': <String>['czech', 'cesky', 'cze', 'ces'],
    'ro': <String>['romanian', 'romana', 'rum', 'ron'],
    'hu': <String>['hungarian', 'magyar', 'hun'],
    'fa': <String>['persian', 'farsi', 'per', 'fas'],
    'fr': <String>['french', 'francais', 'fra', 'fre', 'fr-fr'],
    'ja': <String>['japanese', 'jpn', 'ja-jp', '日本語'],
    'de': <String>['german', 'deutsch', 'deu', 'ger', 'de-de'],
    'pt': <String>['portuguese', 'portugues', 'por', 'pt-br', 'pt-pt'],
    'it': <String>['italian', 'italiano', 'ita'],
    'zh': <String>[
      'chinese',
      'mandarin',
      'mandarin chinese',
      '中文',
      'zho',
      'chi',
      'cmn',
      'zh-cn',
      'zh-tw'
    ],
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

    // The provider's explicit original-language metadata is the strongest
    // signal. Production country and cultural inspiration are not substitutes
    // for this field (for example, Coco is a US production inspired by Mexico).
    final fromOriginalMetadata = canonicalLanguageCode(originalLanguage);
    if (fromOriginalMetadata != null) {
      return fromOriginalMetadata;
    }

    // Explicit title/franchise rules are only fallbacks when the provider did
    // not supply an original language.
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

    final fromLanguageField = canonicalLanguageCode(language);
    if (fromLanguageField != null) {
      return fromLanguageField;
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

  /// Returns only a real track matching the requested language. Unlike
  /// [bestTrack], this never returns a fallback and is safe for an Original
  /// Audio badge or an explicit availability check.
  static String? matchingTrack(
    Iterable<String> rawTracks, {
    required String? targetLanguage,
    bool subtitles = false,
    bool preferAudioDescription = false,
  }) {
    final target = canonicalLanguageCode(targetLanguage) ?? targetLanguage;
    if (target == null || target.isEmpty) return null;
    final matching = rawTracks
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .where((track) =>
            canonicalLanguageCode(track) == target ||
            _languageCodeFromLabel(track) == target)
        .toList(growable: false);
    if (matching.isEmpty) return null;
    return _preferredTrack(
      matching,
      subtitles: subtitles,
      preferAudioDescription: preferAudioDescription,
    );
  }

  /// Selects a language-matching option if present. If it is unavailable,
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
      final matching = tracks
          .where((track) =>
              canonicalLanguageCode(track) == target ||
              _languageCodeFromLabel(track) == target)
          .toList(growable: false);
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
      case 'en':
        return 'English';
      case 'es':
        return 'Spanish';
      case 'ko':
        return 'Korean';
      case 'tr':
        return 'Turkish';
      case 'nl':
        return 'Dutch';
      case 'pl':
        return 'Polish';
      case 'el':
        return 'Greek';
      case 'th':
        return 'Thai';
      case 'vi':
        return 'Vietnamese';
      case 'id':
        return 'Indonesian';
      case 'sv':
        return 'Swedish';
      case 'no':
        return 'Norwegian';
      case 'da':
        return 'Danish';
      case 'fi':
        return 'Finnish';
      case 'he':
        return 'Hebrew';
      case 'uk':
        return 'Ukrainian';
      case 'cs':
        return 'Czech';
      case 'ro':
        return 'Romanian';
      case 'hu':
        return 'Hungarian';
      case 'fa':
        return 'Persian';
      case 'fr':
        return 'French';
      case 'ja':
        return 'Japanese';
      case 'de':
        return 'German';
      case 'pt':
        return 'Portuguese';
      case 'it':
        return 'Italian';
      case 'zh':
        return 'Chinese';
      case 'ru':
        return 'Russian';
      case 'hi':
        return 'Hindi';
      case 'ar':
        return 'Arabic';
      default:
        return code?.trim().isNotEmpty == true
            ? code!.trim()
            : 'Original language';
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
      'avengers',
      'iron man',
      'captain america',
      'captain marvel',
      'the marvels',
      'thor',
      'guardians of the galaxy',
      'doctor strange',
      'black panther',
      'black widow',
      'ant man',
      'antman',
      'deadpool',
      'x men',
      'fantastic four',
      'spider man',
      'spider verse',
      'spiderverse',
      'venom',
      'wolverine',
      'logan',
      'blade',
      'eternals',
      'shang chi',
      'thunderbolts',
      'morbius',
      'kraven the hunter',
      'madame web',
      'ghost rider',
      'elektra',
      'punisher',
      'new mutants',
      'daredevil',
      'the incredible hulk',
      'werewolf by night',
    ];
    return titleMarkers.any((marker) =>
        RegExp('(^| )${RegExp.escape(marker)}( |\$)').hasMatch(titles));
  }

  static String? _languageFromOrigin(String? rawOrigin) {
    final raw = rawOrigin?.trim() ?? '';
    if (raw.isEmpty) return null;

    // Only infer from a single unambiguous production-country language, or
    // from co-production countries that all map to the same language. A US +
    // Mexico co-production without original-language metadata is ambiguous,
    // so we deliberately return null instead of guessing from one country.
    const countryLanguageAliases = <String, List<String>>{
      'en': <String>[
        'us',
        'usa',
        'united states',
        'united states of america',
        'gb',
        'uk',
        'united kingdom',
        'great britain',
        'england',
        'scotland',
        'wales',
        'ie',
        'ireland',
        'au',
        'australia',
        'nz',
        'new zealand',
        'ca',
        'canada',
      ],
      'es': <String>[
        'mx',
        'mexico',
        'es',
        'spain',
        'espana',
        'ar',
        'argentina',
        'cl',
        'chile',
        'co',
        'colombia',
        'pe',
        'peru',
        've',
        'venezuela',
        'ec',
        'ecuador',
        'bo',
        'bolivia',
        'py',
        'paraguay',
        'uy',
        'uruguay',
        'gt',
        'guatemala',
        'hn',
        'honduras',
        'sv',
        'el salvador',
        'ni',
        'nicaragua',
        'cr',
        'costa rica',
        'pa',
        'panama',
        'do',
        'dominican republic',
        'cu',
        'cuba',
        'pr',
        'puerto rico',
      ],
      'ko': <String>['kr', 'south korea', 'republic of korea', 'korea'],
      'ja': <String>['jp', 'japan'],
      'tr': <String>['tr', 'turkey', 'turkiye', 't\u00fcrkiye'],
      'fr': <String>['fr', 'france'],
      'de': <String>['de', 'germany', 'at', 'austria'],
      'pt': <String>['br', 'brazil', 'pt', 'portugal'],
      'it': <String>['it', 'italy'],
      'zh': <String>['cn', 'china', 'tw', 'taiwan'],
      'ru': <String>['ru', 'russia'],
      'nl': <String>['nl', 'netherlands'],
      'pl': <String>['pl', 'poland'],
      'el': <String>['gr', 'greece'],
      'th': <String>['th', 'thailand'],
      'vi': <String>['vn', 'vietnam'],
      'id': <String>['id', 'indonesia'],
      'sv': <String>['se', 'sweden'],
      'no': <String>['no', 'norway'],
      'da': <String>['dk', 'denmark'],
      'fi': <String>['fi', 'finland'],
      'he': <String>['il', 'israel'],
      'uk': <String>['ua', 'ukraine'],
      'cs': <String>['cz', 'czechia', 'czech republic'],
      'ro': <String>['ro', 'romania'],
      'hu': <String>['hu', 'hungary'],
      'fa': <String>['ir', 'iran'],
    };

    final pieces = raw
        .split(RegExp(r'\s*(?:[,;|/]|\s+and\s+)\s*', caseSensitive: false))
        .map(_normalize)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (pieces.isEmpty) return null;

    final resolved = <String>{};
    for (final piece in pieces) {
      String? pieceLanguage;
      for (final entry in countryLanguageAliases.entries) {
        if (entry.value.any((alias) => piece == _normalize(alias))) {
          if (pieceLanguage != null && pieceLanguage != entry.key) {
            return null;
          }
          pieceLanguage = entry.key;
        }
      }
      // Unknown or multilingual regions must not be guessed from one partial
      // country match. India is intentionally omitted because its productions
      // use many original languages; the catalog must provide that metadata.
      if (pieceLanguage == null) return null;
      resolved.add(pieceLanguage);
    }
    return resolved.length == 1 ? resolved.first : null;
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
      if (codes.any((code) =>
          RegExp('(^|[^a-z])${RegExp.escape(code)}([^a-z]|\$)')
              .hasMatch(normalized))) {
        return entry.key;
      }
    }
    return null;
  }

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
