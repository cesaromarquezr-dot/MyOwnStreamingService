// FILE: Backend/services/radio_market_catalog.dart.
// Purpose: Small set of broadcaster-confirmed market stations used to fill
// gaps when public radio directories omit a local station or its stream URL.
//
// This catalog is a supplement, not the primary directory. Radio Browser is
// queried first so the radio feature can scale to many markets. Catalog rows
// should point to the broadcaster's public listening page when a raw stream is
// not published by the directory.

class RadioMarketStation {
  final String countryCode;
  final String state;
  final String city;
  final String callSign;
  final String name;
  final num frequency;
  final String band;
  final String format;
  final String homepage;
  final String tags;

  const RadioMarketStation({
    required this.countryCode,
    required this.state,
    required this.city,
    required this.callSign,
    required this.name,
    required this.frequency,
    required this.band,
    required this.format,
    required this.homepage,
    required this.tags,
  });
}

class RadioMarketCatalog {
  const RadioMarketCatalog._();

  // Broadcaster-confirmed El Paso, Texas market stations. These are merged
  // only for the matching city/region and are intentionally limited to
  // metadata + official listening pages.
  static const List<RadioMarketStation> stations = <RadioMarketStation>[
    RadioMarketStation(
      countryCode: 'US',
      state: 'Texas',
      city: 'El Paso',
      callSign: 'KSII',
      name: '93.1 KISS-FM',
      frequency: 93.1,
      band: 'FM',
      format: 'Hot AC',
      homepage: 'https://kisselpaso.com/',
      tags: 'music,hot ac,pop,el paso',
    ),
    RadioMarketStation(
      countryCode: 'US',
      state: 'Texas',
      city: 'El Paso',
      callSign: 'KHEY-FM',
      name: '96.3 KHEY Country',
      frequency: 96.3,
      band: 'FM',
      format: 'Country',
      homepage: 'https://khey.iheart.com/',
      tags: 'music,country,el paso',
    ),
    RadioMarketStation(
      countryCode: 'US',
      state: 'Texas',
      city: 'El Paso',
      callSign: 'KTSM-FM',
      name: 'Sunny 99.9',
      frequency: 99.9,
      band: 'FM',
      format: 'Adult Contemporary',
      homepage: 'https://sunny999fm.iheart.com/',
      tags: 'music,adult contemporary,el paso',
    ),
    RadioMarketStation(
      countryCode: 'US',
      state: 'Texas',
      city: 'El Paso',
      callSign: 'KPRR',
      name: 'Power 102.1',
      frequency: 102.1,
      band: 'FM',
      format: 'Top 40 & Pop / Rhythmic',
      homepage: 'https://kprr.iheart.com/',
      tags: 'music,pop,rhythmic,el paso',
    ),
    RadioMarketStation(
      countryCode: 'US',
      state: 'Texas',
      city: 'El Paso',
      callSign: 'KLAQ',
      name: '95.5 KLAQ',
      frequency: 95.5,
      band: 'FM',
      format: 'Rock',
      homepage: 'https://klaq.com/',
      tags: 'music,rock,el paso',
    ),
  ];

  static String normalizeStateForRoute(String value) => _normalizeState(value);

  static List<RadioMarketStation> forLocation({
    required String countryCode,
    required String state,
    required String city,
  }) {
    final normalizedCountry = countryCode.trim().toUpperCase();
    final normalizedState = _normalizeState(state);
    final normalizedCity = _normalize(city);

    return stations.where((station) {
      return station.countryCode == normalizedCountry &&
          _normalizeState(station.state) == normalizedState &&
          _normalize(station.city) == normalizedCity;
    }).toList(growable: false);
  }

  static String _normalizeState(String value) {
    final clean = value.trim().toLowerCase();
    const abbreviations = <String, String>{
      'al': 'alabama',
      'ak': 'alaska',
      'az': 'arizona',
      'ar': 'arkansas',
      'ca': 'california',
      'co': 'colorado',
      'ct': 'connecticut',
      'de': 'delaware',
      'fl': 'florida',
      'ga': 'georgia',
      'hi': 'hawaii',
      'id': 'idaho',
      'il': 'illinois',
      'in': 'indiana',
      'ia': 'iowa',
      'ks': 'kansas',
      'ky': 'kentucky',
      'la': 'louisiana',
      'me': 'maine',
      'md': 'maryland',
      'ma': 'massachusetts',
      'mi': 'michigan',
      'mn': 'minnesota',
      'ms': 'mississippi',
      'mo': 'missouri',
      'mt': 'montana',
      'ne': 'nebraska',
      'nv': 'nevada',
      'nh': 'new hampshire',
      'nj': 'new jersey',
      'nm': 'new mexico',
      'ny': 'new york',
      'nc': 'north carolina',
      'nd': 'north dakota',
      'oh': 'ohio',
      'ok': 'oklahoma',
      'or': 'oregon',
      'pa': 'pennsylvania',
      'ri': 'rhode island',
      'sc': 'south carolina',
      'sd': 'south dakota',
      'tn': 'tennessee',
      'tx': 'texas',
      'ut': 'utah',
      'vt': 'vermont',
      'va': 'virginia',
      'wa': 'washington',
      'wv': 'west virginia',
      'wi': 'wisconsin',
      'wy': 'wyoming',
    };
    return abbreviations[clean] ?? clean;
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
