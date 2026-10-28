import 'package:flutter/material.dart';

import 'app_core.dart';

String countryFlagEmojiForName(String country) {
  final normalized = country.trim().toLowerCase()
      .replaceAll('.', '')
      .replaceAll(RegExp(r'\s+'), ' ');
  const aliases = <String, String>{
    'usa': 'US', 'u.s.a': 'US', 'us': 'US', 'united states': 'US',
    'united states of america': 'US', 'uk': 'GB', 'u.k': 'GB',
    'great britain': 'GB', 'britain': 'GB', 'united kingdom': 'GB',
    'south korea': 'KR', 'republic of korea': 'KR', 'korea, republic of': 'KR',
    'north korea': 'KP', "korea, democratic people's republic of": 'KP',
    'russia': 'RU', 'russian federation': 'RU', 'turkey': 'TR', 'türkiye': 'TR',
    'iran': 'IR', 'iran, islamic republic of': 'IR', 'bolivia': 'BO',
    'venezuela': 'VE', 'syria': 'SY', 'laos': 'LA', 'moldova': 'MD',
    'tanzania': 'TZ', 'brunei': 'BN', 'ivory coast': 'CI', "côte d'ivoire": 'CI',
    'czech republic': 'CZ', 'czechia': 'CZ', 'cape verde': 'CV',
    'palestine': 'PS', 'palestinian territory': 'PS', 'vietnam': 'VN',
    'macedonia': 'MK', 'north macedonia': 'MK', 'swaziland': 'SZ',
    'eswatini': 'SZ', 'burma': 'MM', 'myanmar': 'MM', 'taiwan': 'TW',
    'hong kong': 'HK', 'macao': 'MO', 'macau': 'MO', 'kosovo': 'XK',
  };
  const codes = <String, String>{
    'afghanistan':'AF','albania':'AL','algeria':'DZ','andorra':'AD','angola':'AO',
    'antigua and barbuda':'AG','argentina':'AR','armenia':'AM','australia':'AU',
    'austria':'AT','azerbaijan':'AZ','bahamas':'BS','bahrain':'BH','bangladesh':'BD',
    'barbados':'BB','belarus':'BY','belgium':'BE','belize':'BZ','benin':'BJ',
    'bhutan':'BT','bolivia':'BO','bosnia and herzegovina':'BA','botswana':'BW',
    'brazil':'BR','brunei darussalam':'BN','bulgaria':'BG','burkina faso':'BF',
    'burundi':'BI','cambodia':'KH','cameroon':'CM','canada':'CA','chad':'TD',
    'chile':'CL','china':'CN','colombia':'CO','comoros':'KM','congo':'CG',
    'democratic republic of the congo':'CD','costa rica':'CR','croatia':'HR',
    'cuba':'CU','cyprus':'CY','denmark':'DK','djibouti':'DJ','dominica':'DM',
    'dominican republic':'DO','ecuador':'EC','egypt':'EG','el salvador':'SV',
    'equatorial guinea':'GQ','eritrea':'ER','estonia':'EE','ethiopia':'ET','fiji':'FJ',
    'finland':'FI','france':'FR','gabon':'GA','gambia':'GM','georgia':'GE',
    'germany':'DE','ghana':'GH','greece':'GR','grenada':'GD','guatemala':'GT',
    'guinea':'GN','guyana':'GY','haiti':'HT','honduras':'HN','hungary':'HU',
    'iceland':'IS','india':'IN','indonesia':'ID','iraq':'IQ','ireland':'IE',
    'israel':'IL','italy':'IT','jamaica':'JM','japan':'JP','jordan':'JO',
    'kazakhstan':'KZ','kenya':'KE','kiribati':'KI','kuwait':'KW','kyrgyzstan':'KG',
    'lebanon':'LB','lesotho':'LS','liberia':'LR','libya':'LY','liechtenstein':'LI',
    'lithuania':'LT','luxembourg':'LU','madagascar':'MG','malawi':'MW','malaysia':'MY',
    'maldives':'MV','mali':'ML','malta':'MT','marshall islands':'MH','mauritania':'MR',
    'mauritius':'MU','mexico':'MX','micronesia':'FM','monaco':'MC','mongolia':'MN',
    'montenegro':'ME','morocco':'MA','mozambique':'MZ','namibia':'NA','nauru':'NR',
    'nepal':'NP','netherlands':'NL','new zealand':'NZ','nicaragua':'NI','niger':'NE',
    'nigeria':'NG','norway':'NO','oman':'OM','pakistan':'PK','palau':'PW','panama':'PA',
    'papua new guinea':'PG','paraguay':'PY','peru':'PE','philippines':'PH','poland':'PL',
    'portugal':'PT','qatar':'QA','romania':'RO','rwanda':'RW','saint lucia':'LC',
    'samoa':'WS','san marino':'SM','saudi arabia':'SA','senegal':'SN','serbia':'RS',
    'seychelles':'SC','sierra leone':'SL','singapore':'SG','slovakia':'SK','slovenia':'SI',
    'solomon islands':'SB','somalia':'SO','south africa':'ZA','south sudan':'SS','spain':'ES',
    'sri lanka':'LK','sudan':'SD','suriname':'SR','sweden':'SE','switzerland':'CH',
    'tajikistan':'TJ','thailand':'TH','togo':'TG','tonga':'TO','trinidad and tobago':'TT',
    'tunisia':'TN','turkmenistan':'TM','tuvalu':'TV','uganda':'UG','ukraine':'UA',
    'united arab emirates':'AE','uruguay':'UY','uzbekistan':'UZ','vanuatu':'VU',
    'vatican city':'VA','yemen':'YE','zambia':'ZM','zimbabwe':'ZW','netherlands antilles':'AN',
    'czech republic':'CZ','czechia':'CZ','south korea':'KR','north korea':'KP',
    'russia':'RU','turkey':'TR','türkiye':'TR','iran':'IR','taiwan':'TW','hong kong':'HK',
    'palestine':'PS','kosovo':'XK','united kingdom':'GB','united states':'US',
    'united states of america':'US','republic of korea':'KR','korea, republic of':'KR',
  };
  final code = aliases[normalized] ?? codes[normalized];
  if (code == null || code.length != 2) return '🏳️';
  return String.fromCharCodes(code.toUpperCase().codeUnits
      .map((unit) => 0x1F1E6 + unit - 0x41));
}

List<Color> countryFlagColorsForName(String country) {
  final key = country.trim().toLowerCase();
  // Palettes sampled from the primary colors used in each national flag. The
  // adjacent emoji displays the full flag and emblem; these colors decorate
  // the country name so the heading is recognizable even at a glance.
  const palettes = <String, List<Color>>{
    'usa': [Color(0xFFB22234), Color(0xFFFFFFFF), Color(0xFF3C3B6E)],
    'us': [Color(0xFFB22234), Color(0xFFFFFFFF), Color(0xFF3C3B6E)],
    'united states': [Color(0xFFB22234), Color(0xFFFFFFFF), Color(0xFF3C3B6E)],
    'united states of america': [Color(0xFFB22234), Color(0xFFFFFFFF), Color(0xFF3C3B6E)],
    'mexico': [Color(0xFF006847), Color(0xFFFFFFFF), Color(0xFFCE1126)],
    'canada': [Color(0xFFD80621), Color(0xFFFFFFFF), Color(0xFFD80621)],
    'united kingdom': [Color(0xFF012169), Color(0xFFFFFFFF), Color(0xFFC8102E)],
    'uk': [Color(0xFF012169), Color(0xFFFFFFFF), Color(0xFFC8102E)],
    'great britain': [Color(0xFF012169), Color(0xFFFFFFFF), Color(0xFFC8102E)],
    'india': [Color(0xFFFF9933), Color(0xFFFFFFFF), Color(0xFF138808)],
    'turkey': [Color(0xFFE30A17), Color(0xFFFFFFFF)],
    'türkiye': [Color(0xFFE30A17), Color(0xFFFFFFFF)],
    'south korea': [Color(0xFFFFFFFF), Color(0xFFCD2E3A), Color(0xFF0047A0)],
    'spain': [Color(0xFFAA151B), Color(0xFFF1BF00), Color(0xFFAA151B)],
    'japan': [Color(0xFFFFFFFF), Color(0xFFBC002D), Color(0xFFFFFFFF)],
    'china': [Color(0xFFDE2910), Color(0xFFFFDE00), Color(0xFFDE2910)],
    'france': [Color(0xFF0055A4), Color(0xFFFFFFFF), Color(0xFFEF4135)],
    'germany': [Color(0xFF000000), Color(0xFFDD0000), Color(0xFFFFCE00)],
    'italy': [Color(0xFF009246), Color(0xFFFFFFFF), Color(0xFFCE2B37)],
    'brazil': [Color(0xFF009739), Color(0xFFFFDF00), Color(0xFF002776)],
    'argentina': [Color(0xFF74ACDF), Color(0xFFFFFFFF), Color(0xFF74ACDF)],
    'portugal': [Color(0xFF006600), Color(0xFFFF0000)],
    'netherlands': [Color(0xFFAE1C28), Color(0xFFFFFFFF), Color(0xFF21468B)],
    'russia': [Color(0xFFFFFFFF), Color(0xFF0039A6), Color(0xFFD52B1E)],
    'south africa': [Color(0xFF007749), Color(0xFFFFB81C), Color(0xFFDE3831), Color(0xFF002395)],
    'australia': [Color(0xFF012169), Color(0xFFFFFFFF), Color(0xFFE4002B)],
    'new zealand': [Color(0xFF00247D), Color(0xFFFFFFFF), Color(0xFFCC142B)],
    'ireland': [Color(0xFF169B62), Color(0xFFFFFFFF), Color(0xFFFF883E)],
    'ukraine': [Color(0xFF0057B7), Color(0xFFFFD700)],
    'poland': [Color(0xFFFFFFFF), Color(0xFFDC143C)],
    'indonesia': [Color(0xFFFF0000), Color(0xFFFFFFFF)],
    'pakistan': [Color(0xFF01411C), Color(0xFFFFFFFF)],
    'saudi arabia': [Color(0xFF006C35), Color(0xFFFFFFFF)],
    'israel': [Color(0xFFFFFFFF), Color(0xFF0038B8)],
    'greece': [Color(0xFF0D5EAF), Color(0xFFFFFFFF)],
    'sweden': [Color(0xFF006AA7), Color(0xFFFECC00)],
    'norway': [Color(0xFFBA0C2F), Color(0xFFFFFFFF), Color(0xFF00205B)],
    'denmark': [Color(0xFFC8102E), Color(0xFFFFFFFF)],
    'finland': [Color(0xFFFFFFFF), Color(0xFF003580)],
    'switzerland': [Color(0xFFFF0000), Color(0xFFFFFFFF)],
    'belgium': [Color(0xFF000000), Color(0xFFFFCD00), Color(0xFFEF3340)],
    'austria': [Color(0xFFED2939), Color(0xFFFFFFFF), Color(0xFFED2939)],
    'egypt': [Color(0xFFCE1126), Color(0xFFFFFFFF), Color(0xFF000000)],
    'nigeria': [Color(0xFF008751), Color(0xFFFFFFFF), Color(0xFF008751)],
    'kenya': [Color(0xFF000000), Color(0xFFBB0000), Color(0xFF006600)],
    'ethiopia': [Color(0xFF078930), Color(0xFFFEDD00), Color(0xFFDA121A)],
    'colombia': [Color(0xFFFCD116), Color(0xFF003893), Color(0xFFCE1126)],
    'chile': [Color(0xFFFFFFFF), Color(0xFFD52B1E), Color(0xFF0039A6)],
    'peru': [Color(0xFFD91023), Color(0xFFFFFFFF), Color(0xFFD91023)],
    'jamaica': [Color(0xFF009B3A), Color(0xFFFFB81C), Color(0xFF000000)],
    'cuba': [Color(0xFF002A8F), Color(0xFFFFFFFF), Color(0xFFCF142B)],
    'thailand': [Color(0xFFDA251D), Color(0xFFFFFFFF), Color(0xFF241D4F)],
    'vietnam': [Color(0xFFDA251D), Color(0xFFFFD700)],
    'philippines': [Color(0xFF0038A8), Color(0xFFFFFFFF), Color(0xFFCE1126)],
    'malaysia': [Color(0xFF010066), Color(0xFFFFD100), Color(0xFFCC0000), Color(0xFFFFFFFF)],
    'singapore': [Color(0xFFEF3340), Color(0xFFFFFFFF)],
    'bangladesh': [Color(0xFF006A4E), Color(0xFFF42A41)],
    'nepal': [Color(0xFFDC143C), Color(0xFF003893), Color(0xFFFFFFFF)],
    'iran': [Color(0xFF239F40), Color(0xFFFFFFFF), Color(0xFFDA0000)],
    'iran, islamic republic of': [Color(0xFF239F40), Color(0xFFFFFFFF), Color(0xFFDA0000)],
    'czech republic': [Color(0xFFFFFFFF), Color(0xFFD7141A), Color(0xFF11457E)],
    'czechia': [Color(0xFFFFFFFF), Color(0xFFD7141A), Color(0xFF11457E)],
  };
  return palettes[key] ?? const <Color>[Color(0xFF6A8DFF), Colors.white, Color(0xFFFF6B6B)];
}



/// Shared country-of-origin presentation for Movies and TV Shows cards.
/// The flag emoji and gradient palette are the same ones used by Home country shelves.
class CountryOriginInline extends StatelessWidget {
  const CountryOriginInline({
    super.key,
    required this.media,
    this.fontSize = 10.5,
    this.fallbackColor = const Color(0xFF9A9A9A),
    this.maxCountries = 3,
  });

  final MediaItem media;
  final double fontSize;
  final Color fallbackColor;
  final int maxCountries;

  @override
  Widget build(BuildContext context) {
    final countries = mediaCountryOriginParts(media).take(maxCountries).toList(growable: false);
    if (countries.isEmpty) {
      return Text(
        'Country of origin unavailable',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fallbackColor, fontSize: fontSize),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final country in countries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(countryFlagEmojiForName(country), style: TextStyle(fontSize: fontSize + 2, height: 1.05)),
              const SizedBox(width: 3),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  colors: countryFlagColorsForName(country),
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds),
                child: Text(
                  country,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
