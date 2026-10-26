// FILE: lib/cinematic_title_fonts.dart
// Title-specific display typography for poster captions, Home hero titles,
// movie/TV details, and album detail headings.
//
// Exact logo lettering is often custom artwork rather than an off-the-shelf
// typeface. `fontFamily` records the intended face when a correctly licensed
// font is registered in pubspec.yaml; `fontFamilyFallback` keeps the app
// readable when that font asset has not been installed.

import 'package:flutter/material.dart';

import 'app_core.dart';

class CinematicTitleFontProfile {
  final String key;
  final String fontName;
  final String fontFamily;
  final String fallbackFamily;
  final Color color;
  final FontWeight weight;
  final double letterSpacing;
  final bool italic;
  final bool glow;
  final double sizeScale;
  final List<String> aliases;

  const CinematicTitleFontProfile({
    required this.key,
    required this.fontName,
    required this.fontFamily,
    required this.fallbackFamily,
    required this.color,
    required this.weight,
    required this.letterSpacing,
    required this.italic,
    required this.glow,
    required this.sizeScale,
    this.aliases = const <String>[],
  });
}

class CinematicTitleFonts {
  CinematicTitleFonts._();

  static String normalize(String value) => value
      .toLowerCase()
      // Strip separators while preserving non-Latin letters. This lets an
      // original-language title select a profile without translating/replacing
      // the title displayed to the user.
      .replaceAll(RegExp(r'[\s\-_.,:;!?()\[\]{}\\/]+'), '');

  // Exact-style entries are ordered by profile, then matched by the longest
  // title/alias found in a title's known names. Names remain unchanged in UI.
  static const List<CinematicTitleFontProfile> _titleProfiles =
      <CinematicTitleFontProfile>[
    CinematicTitleFontProfile(
      key: 'john-wick', fontName: 'Compacta Italic',
      fontFamily: 'Compacta Italic', fallbackFamily: 'sans-serif-condensed',
      color: Colors.white, weight: FontWeight.w900, letterSpacing: -1.1,
      italic: true, glow: false, sizeScale: 1.12,
      aliases: <String>['John Wick'],
    ),
    CinematicTitleFontProfile(
      key: 'game-of-thrones', fontName: 'Trajan Pro',
      fontFamily: 'Trajan Pro', fallbackFamily: 'serif',
      color: Color(0xFFFFE7B0), weight: FontWeight.w700, letterSpacing: 1.4,
      italic: false, glow: true, sizeScale: 1.04,
      aliases: <String>['Game of Thrones', 'House of the Dragon', '왕좌의 게임', '权力的游戏'],
    ),
    CinematicTitleFontProfile(
      key: 'joker', fontName: 'Gothic Joker',
      fontFamily: 'Gothic Joker', fallbackFamily: 'serif',
      color: Color(0xFFFFE5E5), weight: FontWeight.w900, letterSpacing: -.45,
      italic: false, glow: true, sizeScale: 1.08,
      aliases: <String>['Joker', 'Joker Folie a Deux'],
    ),
    CinematicTitleFontProfile(
      key: 'avengers', fontName: 'Avengeance',
      fontFamily: 'Avengeance', fallbackFamily: 'sans-serif-condensed',
      color: Colors.white, weight: FontWeight.w900, letterSpacing: .55,
      italic: false, glow: true, sizeScale: 1.08,
      aliases: <String>['The Avengers', 'Avengers', 'Avengers Endgame',
        'Avengers Infinity War', 'The Avengers Age of Ultron', '어벤져스'],
    ),
    CinematicTitleFontProfile(
      key: 'dune', fontName: 'Dune Rise',
      fontFamily: 'Dune Rise', fallbackFamily: 'serif',
      color: Color(0xFFFFE5BC), weight: FontWeight.w700, letterSpacing: 1.25,
      italic: false, glow: true, sizeScale: 1.0,
      aliases: <String>['Dune', 'Dune Part Two', 'Dune Part One', '듄'],
    ),
    CinematicTitleFontProfile(
      key: 'interstellar', fontName: 'Linotype Didot',
      fontFamily: 'Linotype Didot', fallbackFamily: 'serif',
      color: Color(0xFFE9F1FF), weight: FontWeight.w500, letterSpacing: 1.15,
      italic: false, glow: true, sizeScale: .98,
      aliases: <String>['Interstellar'],
    ),
    CinematicTitleFontProfile(
      key: 'iron-man', fontName: 'Iron Man of War Font',
      fontFamily: 'iron-man-of-war-font', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFE8F5FF), weight: FontWeight.w900, letterSpacing: .5,
      italic: false, glow: true, sizeScale: 1.1,
      aliases: <String>['Iron Man', 'Iron Man 2', 'Iron Man 3', '아이언맨'],
    ),
    CinematicTitleFontProfile(
      key: 'captain-america', fontName: 'AmericanCaptain-MdEY',
      fontFamily: 'AmericanCaptain-MdEY', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFE3EDFF), weight: FontWeight.w900, letterSpacing: .75,
      italic: false, glow: true, sizeScale: .94,
      aliases: <String>['Captain America The First Avenger', 'Captain America',
        'Captain America The Winter Soldier', 'Captain America Civil War', '캡틴 아메리카'],
    ),
    CinematicTitleFontProfile(
      key: 'spider-man', fontName: 'HOMOARAK',
      fontFamily: 'HOMOARAK', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFFFE5E5), weight: FontWeight.w900, letterSpacing: -.25,
      italic: false, glow: true, sizeScale: 1.08,
      aliases: <String>['Spider Man', 'The Amazing Spider Man',
        'Spider Man Homecoming', 'Spider Man Far From Home',
        'Spider Man No Way Home', 'Spider Man Into the Spider Verse',
        'Spider Man Across the Spider Verse', 'Spiderman', '스파이더맨'],
    ),
    CinematicTitleFontProfile(
      key: 'black-widow', fontName: 'Black Widow Movie Font',
      fontFamily: 'black-widow-movie-font', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFFFE9E9), weight: FontWeight.w900, letterSpacing: .65,
      italic: false, glow: true, sizeScale: 1.03,
      aliases: <String>['Black Widow', '블랙 위도우'],
    ),
    CinematicTitleFontProfile(
      key: 'pulp-fiction', fontName: 'Aachen Bold',
      fontFamily: 'Aachen Bold', fallbackFamily: 'serif',
      color: Color(0xFFFFE69A), weight: FontWeight.w900, letterSpacing: -.35,
      italic: false, glow: false, sizeScale: 1.1,
      aliases: <String>['Pulp Fiction'],
    ),
    CinematicTitleFontProfile(
      key: 'jaws', fontName: 'Amity Jack',
      fontFamily: 'Amity Jack', fallbackFamily: 'serif',
      color: Color(0xFFBFE9FF), weight: FontWeight.w900, letterSpacing: .1,
      italic: true, glow: true, sizeScale: 1.04,
      aliases: <String>['Jaws'],
    ),
    CinematicTitleFontProfile(
      key: 'fantastic-mr-fox', fontName: 'Futura Bold',
      fontFamily: 'Futura Bold', fallbackFamily: 'sans-serif',
      color: Color(0xFFFFE0A8), weight: FontWeight.w800, letterSpacing: .2,
      italic: false, glow: false, sizeScale: .95,
      aliases: <String>['Fantastic Mr Fox'],
    ),
    CinematicTitleFontProfile(
      key: 'stranger-things', fontName: 'ITC Benguiat',
      fontFamily: 'ITC Benguiat', fallbackFamily: 'serif',
      color: Color(0xFFFFD5D8), weight: FontWeight.w900, letterSpacing: 1.0,
      italic: false, glow: true, sizeScale: .98,
      aliases: <String>['Stranger Things', '기묘한 이야기'],
    ),
    CinematicTitleFontProfile(
      key: 'moonrise-kingdom', fontName: 'Futura Bold',
      fontFamily: 'Futura Bold', fallbackFamily: 'sans-serif',
      color: Color(0xFFFFE7C2), weight: FontWeight.w800, letterSpacing: .6,
      italic: false, glow: false, sizeScale: .95,
      aliases: <String>['Moonrise Kingdom'],
    ),
    CinematicTitleFontProfile(
      key: 'star-wars', fontName: 'News Gothic Bold',
      fontFamily: 'News Gothic Bold', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFFFEAA1), weight: FontWeight.w900, letterSpacing: .75,
      italic: false, glow: true, sizeScale: 1.05,
      aliases: <String>['Star Wars', 'The Mandalorian', 'Andor', 'Ahsoka'],
    ),
    CinematicTitleFontProfile(
      key: 'lord-of-the-rings', fontName: 'Ringbearer',
      fontFamily: 'Ringbearer', fallbackFamily: 'serif',
      color: Color(0xFFFFE4A5), weight: FontWeight.w700, letterSpacing: .5,
      italic: false, glow: true, sizeScale: 1.0,
      aliases: <String>['The Lord of the Rings', 'Lord of the Rings',
        'The Hobbit', 'The Rings of Power'],
    ),
    CinematicTitleFontProfile(
      key: 'harry-potter', fontName: 'Harry Potter display lettering',
      fontFamily: 'Harry Potter', fallbackFamily: 'serif',
      color: Color(0xFFE6D7FF), weight: FontWeight.w800, letterSpacing: .25,
      italic: false, glow: true, sizeScale: 1.0,
      aliases: <String>['Harry Potter', 'Fantastic Beasts'],
    ),
    CinematicTitleFontProfile(
      key: 'the-matrix', fontName: 'Matrix-style display lettering',
      fontFamily: 'Matrix', fallbackFamily: 'monospace',
      color: Color(0xFFB8F5C4), weight: FontWeight.w800, letterSpacing: .7,
      italic: false, glow: true, sizeScale: .98,
      aliases: <String>['The Matrix', 'The Matrix Reloaded',
        'The Matrix Revolutions', 'The Matrix Resurrections'],
    ),
    CinematicTitleFontProfile(
      key: 'the-godfather', fontName: 'Corleone-style display lettering',
      fontFamily: 'Corleone', fallbackFamily: 'serif',
      color: Color(0xFFFFE9C9), weight: FontWeight.w700, letterSpacing: .2,
      italic: false, glow: false, sizeScale: 1.02,
      aliases: <String>['The Godfather'],
    ),
    CinematicTitleFontProfile(
      key: 'mission-impossible', fontName: 'Eurostile Extended',
      fontFamily: 'Eurostile Extended', fallbackFamily: 'sans-serif',
      color: Color(0xFFE2EAFF), weight: FontWeight.w900, letterSpacing: .65,
      italic: false, glow: true, sizeScale: .94,
      aliases: <String>['Mission Impossible'],
    ),
    CinematicTitleFontProfile(
      key: 'futura', fontName: 'Futura Bold',
      fontFamily: 'Futura Bold', fallbackFamily: 'sans-serif',
      color: Colors.white, weight: FontWeight.w800, letterSpacing: .25,
      italic: false, glow: false, sizeScale: 1.0,
      aliases: <String>['The Royal Tenenbaums', 'The Grand Budapest Hotel',
        'Fantastic Mr Fox', 'Moonrise Kingdom'],
    ),
    CinematicTitleFontProfile(
      key: 'avatar', fontName: 'Avatar-style display lettering',
      fontFamily: 'Avatar', fallbackFamily: 'serif',
      color: Color(0xFFB8F3FF), weight: FontWeight.w700, letterSpacing: .7,
      italic: false, glow: true, sizeScale: 1.0,
      aliases: <String>['Avatar', 'Avatar The Way of Water'],
    ),
    CinematicTitleFontProfile(
      key: 'alien', fontName: 'Microgramma-style display lettering',
      fontFamily: 'Microgramma', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFE6F4FF), weight: FontWeight.w800, letterSpacing: 1.1,
      italic: false, glow: true, sizeScale: 1.0,
      aliases: <String>['Alien', 'Aliens', 'Alien Romulus'],
    ),
    CinematicTitleFontProfile(
      key: 'blade-runner', fontName: 'Blade Runner-style display lettering',
      fontFamily: 'Blade Runner', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFE7E1FF), weight: FontWeight.w800, letterSpacing: 1.0,
      italic: false, glow: true, sizeScale: 1.0,
      aliases: <String>['Blade Runner', 'Blade Runner 2049'],
    ),
    CinematicTitleFontProfile(
      key: 'jurassic-park', fontName: 'Friz Quadrata-style display lettering',
      fontFamily: 'Friz Quadrata', fallbackFamily: 'serif',
      color: Color(0xFFFFE6A8), weight: FontWeight.w900, letterSpacing: .25,
      italic: false, glow: true, sizeScale: 1.0,
      aliases: <String>['Jurassic Park', 'Jurassic World'],
    ),
    CinematicTitleFontProfile(
      key: 'batman', fontName: 'Batman display lettering',
      fontFamily: 'BatmanForeverAlternate', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFE5E9FF), weight: FontWeight.w900, letterSpacing: 1.1,
      italic: false, glow: true, sizeScale: 1.02,
      aliases: <String>['Batman', 'The Dark Knight', 'The Batman'],
    ),
    CinematicTitleFontProfile(
      key: 'superman', fontName: 'Superman display lettering',
      fontFamily: 'Man of Steel', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFFFE5A5), weight: FontWeight.w900, letterSpacing: .5,
      italic: false, glow: true, sizeScale: 1.0,
      aliases: <String>['Superman', 'Man of Steel'],
    ),
    CinematicTitleFontProfile(
      key: 'the-last-of-us', fontName: 'Press Gothic',
      fontFamily: 'Press Gothic', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFDDE9D2), weight: FontWeight.w900, letterSpacing: .5,
      italic: false, glow: false, sizeScale: 1.02,
      aliases: <String>['The Last of Us'],
    ),
    CinematicTitleFontProfile(
      key: 'breaking-bad', fontName: 'Helvetica Neue-style title treatment',
      fontFamily: 'Helvetica Neue', fallbackFamily: 'sans-serif',
      color: Color(0xFFDFF2B1), weight: FontWeight.w800, letterSpacing: .15,
      italic: false, glow: false, sizeScale: .98,
      aliases: <String>['Breaking Bad', 'Better Call Saul'],
    ),
    CinematicTitleFontProfile(
      key: 'walking-dead', fontName: 'Trade Gothic',
      fontFamily: 'Trade Gothic', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFEAEAEA), weight: FontWeight.w900, letterSpacing: .55,
      italic: false, glow: false, sizeScale: 1.0,
      aliases: <String>['The Walking Dead'],
    ),
    CinematicTitleFontProfile(
      key: 'the-shining', fontName: 'Helvetica-style title treatment',
      fontFamily: 'Helvetica', fallbackFamily: 'sans-serif',
      color: Color(0xFFFFE7E7), weight: FontWeight.w800, letterSpacing: .25,
      italic: false, glow: false, sizeScale: 1.0,
      aliases: <String>['The Shining'],
    ),
    CinematicTitleFontProfile(
      key: '2001-space-odyssey', fontName: 'Futura Extra Bold',
      fontFamily: 'Futura Extra Bold', fallbackFamily: 'sans-serif',
      color: Color(0xFFE8F5FF), weight: FontWeight.w900, letterSpacing: .6,
      italic: false, glow: false, sizeScale: .96,
      aliases: <String>['2001 A Space Odyssey', 'A Clockwork Orange'],
    ),
    CinematicTitleFontProfile(
      key: 'squid-game', fontName: 'Geometric display fallback',
      fontFamily: 'Squid Game', fallbackFamily: 'sans-serif',
      color: Color(0xFFFFD8DE), weight: FontWeight.w900, letterSpacing: 1.15,
      italic: false, glow: true, sizeScale: 1.0,
      aliases: <String>['Squid Game', '오징어 게임'],
    ),
    CinematicTitleFontProfile(
      key: 'train-to-busan', fontName: 'Train to Busan-style display lettering',
      fontFamily: 'Train to Busan', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFE0EBF5), weight: FontWeight.w900, letterSpacing: .35,
      italic: false, glow: true, sizeScale: 1.0,
      aliases: <String>['Train to Busan', '부산행'],
    ),
    CinematicTitleFontProfile(
      key: 'parasite', fontName: 'Parasite-style title treatment',
      fontFamily: 'Parasite', fallbackFamily: 'sans-serif',
      color: Color(0xFFF4F2E8), weight: FontWeight.w700, letterSpacing: .35,
      italic: false, glow: false, sizeScale: 1.0,
      aliases: <String>['Parasite', '기생충'],
    ),
    // Profiles inspired by the user's physical DVD/Blu-ray spine reference video.
    // These are approximations for text fallback; official logo artwork still wins.
    CinematicTitleFontProfile(
      key: 'godzilla', fontName: 'Heavy squared display',
      fontFamily: 'Godzilla Display', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFB9E65A), weight: FontWeight.w900, letterSpacing: .35,
      italic: false, glow: true, sizeScale: 1.05,
      aliases: <String>['Godzilla', 'Godzilla Minus One', 'ゴジラ'],
    ),
    CinematicTitleFontProfile(
      key: 'ghostbusters', fontName: 'Rounded retro display',
      fontFamily: 'Ghostbusters Display', fallbackFamily: 'sans-serif',
      color: Color(0xFFFFF1D1), weight: FontWeight.w900, letterSpacing: -.3,
      italic: false, glow: false, sizeScale: 1.02,
      aliases: <String>['Ghostbusters', 'Ghostbusters Afterlife', 'Ghostbusters Frozen Empire'],
    ),
    CinematicTitleFontProfile(
      key: 'freaky-friday', fontName: 'Playful bold display',
      fontFamily: 'Freaky Friday Display', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFFFD9F0), weight: FontWeight.w900, letterSpacing: -.55,
      italic: false, glow: false, sizeScale: 1.02,
      aliases: <String>['Freaky Friday'],
    ),
    CinematicTitleFontProfile(
      key: 'finding-nemo', fontName: 'Rounded animated display',
      fontFamily: 'Finding Nemo Display', fallbackFamily: 'sans-serif',
      color: Color(0xFFFFC46A), weight: FontWeight.w900, letterSpacing: -.4,
      italic: false, glow: false, sizeScale: 1.04,
      aliases: <String>['Finding Nemo', 'Finding Dory'],
    ),
    CinematicTitleFontProfile(
      key: 'ferris-buellers-day-off', fontName: 'Condensed bold sans',
      fontFamily: 'Trade Gothic', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFF4F4F4), weight: FontWeight.w900, letterSpacing: -.25,
      italic: false, glow: false, sizeScale: .96,
      aliases: <String>["Ferris Bueller's Day Off", 'Ferris Buellers Day Off'],
    ),
    CinematicTitleFontProfile(
      key: 'elf', fontName: 'Friendly rounded display',
      fontFamily: 'Elf Display', fallbackFamily: 'sans-serif',
      color: Color(0xFFFF4B55), weight: FontWeight.w900, letterSpacing: -.25,
      italic: false, glow: false, sizeScale: 1.08,
      aliases: <String>['Elf'],
    ),
    CinematicTitleFontProfile(
      key: 'fred-claus', fontName: 'Festive bold sans',
      fontFamily: 'Fred Claus Display', fallbackFamily: 'sans-serif',
      color: Color(0xFFE94B52), weight: FontWeight.w900, letterSpacing: -.2,
      italic: false, glow: false, sizeScale: 1.0,
      aliases: <String>['Fred Claus'],
    ),
    CinematicTitleFontProfile(
      key: 'click', fontName: 'Geometric heavy sans',
      fontFamily: 'Gotham', fallbackFamily: 'sans-serif',
      color: Color(0xFFB8D7FF), weight: FontWeight.w900, letterSpacing: -.35,
      italic: false, glow: false, sizeScale: 1.0,
      aliases: <String>['Click'],
    ),
    CinematicTitleFontProfile(
      key: 'charlie-brown-christmas', fontName: 'Hand-lettered holiday style',
      fontFamily: 'Charlie Brown Display', fallbackFamily: 'sans-serif',
      color: Color(0xFFFFE6A8), weight: FontWeight.w800, letterSpacing: -.25,
      italic: false, glow: false, sizeScale: .96,
      aliases: <String>['A Charlie Brown Christmas', 'Charlie Brown Christmas'],
    ),
    CinematicTitleFontProfile(
      key: '8-mile', fontName: 'Heavy condensed urban sans',
      fontFamily: 'Trade Gothic', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFFFD27A), weight: FontWeight.w900, letterSpacing: -.35,
      italic: false, glow: false, sizeScale: 1.0,
      aliases: <String>['8 Mile', 'Eight Mile'],
    ),
    CinematicTitleFontProfile(
      key: 'snow-white-and-the-huntsman', fontName: 'Elegant engraved serif',
      fontFamily: 'Trajan Pro', fallbackFamily: 'serif',
      color: Color(0xFFE7C48C), weight: FontWeight.w600, letterSpacing: .8,
      italic: false, glow: true, sizeScale: .98,
      aliases: <String>['Snow White and the Huntsman', 'Snow White & the Huntsman'],
    ),
    CinematicTitleFontProfile(
      key: 'the-huntsman-winters-war', fontName: 'Classical high-contrast serif',
      fontFamily: 'Trajan Pro', fallbackFamily: 'serif',
      color: Color(0xFFF0D8AD), weight: FontWeight.w600, letterSpacing: .75,
      italic: false, glow: false, sizeScale: .95,
      aliases: <String>['The Huntsman Winters War', "The Huntsman: Winter's War", 'Huntsman Winters War'],
    ),
    CinematicTitleFontProfile(
      key: 'high-school-musical', fontName: 'Energetic bold sans',
      fontFamily: 'High School Musical Display', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFFFD45C), weight: FontWeight.w900, letterSpacing: -.3,
      italic: false, glow: false, sizeScale: 1.04,
      aliases: <String>['High School Musical', 'High School Musical 2', 'High School Musical 3'],
    ),
    CinematicTitleFontProfile(
      key: 'goosebumps', fontName: 'Playful spooky display',
      fontFamily: 'Goosebumps Display', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFB7F27C), weight: FontWeight.w900, letterSpacing: -.35,
      italic: false, glow: true, sizeScale: 1.0,
      aliases: <String>['Goosebumps', 'Goosebumps 2', 'Goosebumps 2 Haunted Halloween'],
    ),
    CinematicTitleFontProfile(
      key: 'happy-gilmore', fontName: 'Retro bold serif',
      fontFamily: 'Clarendon', fallbackFamily: 'serif',
      color: Color(0xFFE9B66C), weight: FontWeight.w800, letterSpacing: -.2,
      italic: false, glow: false, sizeScale: 1.0,
      aliases: <String>['Happy Gilmore', 'Happy Gilmore 2'],
    ),
  ];

  static const CinematicTitleFontProfile _default =
      CinematicTitleFontProfile(
    key: 'default', fontName: 'Platform display fallback',
    fontFamily: '', fallbackFamily: 'sans-serif', color: Colors.white,
    weight: FontWeight.w900, letterSpacing: .1, italic: false, glow: false,
    sizeScale: 1.0,
  );

  static const CinematicTitleFontProfile _album =
      CinematicTitleFontProfile(
    key: 'album', fontName: 'Album editorial fallback',
    fontFamily: '', fallbackFamily: 'serif',
    color: Color(0xFFF4E7FF), weight: FontWeight.w700, letterSpacing: .25,
    italic: false, glow: false, sizeScale: 1.0,
  );

  static const Map<String, CinematicTitleFontProfile> _genreProfiles =
      <String, CinematicTitleFontProfile>{
    'horror': CinematicTitleFontProfile(
      key: 'horror', fontName: 'Horror display fallback',
      fontFamily: '', fallbackFamily: 'serif', color: Color(0xFFFFD5D8),
      weight: FontWeight.w900, letterSpacing: 1.1, italic: false, glow: true,
      sizeScale: 1.0,
    ),
    'scifi': CinematicTitleFontProfile(
      key: 'scifi', fontName: 'Science-fiction display fallback',
      fontFamily: '', fallbackFamily: 'sans-serif-condensed',
      color: Color(0xFFBFEFFF), weight: FontWeight.w800,
      letterSpacing: 1.25, italic: false, glow: true, sizeScale: 1.0,
    ),
    'fantasy': CinematicTitleFontProfile(
      key: 'fantasy', fontName: 'Fantasy display fallback',
      fontFamily: '', fallbackFamily: 'serif', color: Color(0xFFE1D1FF),
      weight: FontWeight.w800, letterSpacing: .6, italic: false, glow: true,
      sizeScale: 1.0,
    ),
    'western': CinematicTitleFontProfile(
      key: 'western', fontName: 'Western display fallback',
      fontFamily: '', fallbackFamily: 'serif', color: Color(0xFFFFDDA0),
      weight: FontWeight.w900, letterSpacing: .45, italic: false, glow: false,
      sizeScale: 1.0,
    ),
    'romance': CinematicTitleFontProfile(
      key: 'romance', fontName: 'Elegant display fallback',
      fontFamily: '', fallbackFamily: 'serif', color: Color(0xFFFFDFEB),
      weight: FontWeight.w700, letterSpacing: .3, italic: true, glow: false,
      sizeScale: .99,
    ),
    'animation': CinematicTitleFontProfile(
      key: 'animation', fontName: 'Animation display fallback',
      fontFamily: '', fallbackFamily: 'sans-serif', color: Color(0xFFFFE5A3),
      weight: FontWeight.w900, letterSpacing: -.25, italic: false,
      glow: false, sizeScale: 1.0,
    ),
    'comedy': CinematicTitleFontProfile(
      key: 'comedy', fontName: 'Comedy display fallback',
      fontFamily: '', fallbackFamily: 'sans-serif', color: Color(0xFFFFE27C),
      weight: FontWeight.w900, letterSpacing: -.2, italic: false,
      glow: false, sizeScale: 1.0,
    ),
    'thriller': CinematicTitleFontProfile(
      key: 'thriller', fontName: 'Thriller display fallback',
      fontFamily: '', fallbackFamily: 'sans-serif-condensed',
      color: Colors.white, weight: FontWeight.w900, letterSpacing: 1.0,
      italic: false, glow: false, sizeScale: 1.0,
    ),
    'retro': CinematicTitleFontProfile(
      key: 'retro', fontName: 'Retro display fallback',
      fontFamily: '', fallbackFamily: 'monospace', color: Color(0xFFFFC36A),
      weight: FontWeight.w900, letterSpacing: 1.5, italic: false, glow: true,
      sizeScale: 1.0,
    ),
  };

  static CinematicTitleFontProfile resolveMedia(MediaItem media) {
    return resolveTitle(
      media.title,
      alternateTitles: <String?>[
        media.originalTitle,
        media.canonicalTitle,
        media.franchiseName,
      ],
      type: media.type,
      genres: <String>[...media.genres, ...media.tags, ...media.music],
      styleKey: media.titleStyleKey,
    );
  }

  static CinematicTitleFontProfile resolveTitle(
    String title, {
    Iterable<String?> alternateTitles = const <String?>[],
    String? type,
    Iterable<String> genres = const <String>[],
    String? styleKey,
  }) {
    final explicitKey = normalize(styleKey ?? '');
    final mappedExplicit = _profileForExplicitKey(explicitKey);
    if (mappedExplicit != null) {
      return mappedExplicit;
    }

    final normalizedType = normalize(type ?? '');
    // Album artwork follows artist/label design and often has no title text at
    // all. Do not accidentally apply a similarly named movie's logo profile.
    if (normalizedType.contains('album') || normalizedType == 'soundtrack' ||
        normalizedType == 'musicrelease') {
      return _album;
    }

    final titleKeys = <String>{
      for (final raw in <String?>[title, ...alternateTitles])
        if (raw != null && normalize(raw).isNotEmpty) normalize(raw),
    };
    CinematicTitleFontProfile? best;
    var bestAliasLength = 0;
    for (final profile in _titleProfiles) {
      for (final alias in profile.aliases) {
        final aliasKey = normalize(alias);
        if (aliasKey.isEmpty) continue;
        final matches = titleKeys.any((candidate) =>
            candidate == aliasKey ||
            candidate.startsWith(aliasKey) ||
            candidate.contains(aliasKey));
        if (matches && aliasKey.length > bestAliasLength) {
          best = profile;
          bestAliasLength = aliasKey.length;
        }
      }
    }
    if (best != null) {
      return best;
    }

    final genreText = normalize(genres.join(' '));
    if (genreText.contains('horror') || genreText.contains('slasher') ||
        genreText.contains('supernatural')) {
      return _genreProfiles['horror']!;
    }
    if (genreText.contains('sciencefiction') || genreText.contains('scifi') ||
        genreText.contains('spaceopera') || genreText.contains('cyberpunk')) {
      return _genreProfiles['scifi']!;
    }
    if (genreText.contains('fantasy') || genreText.contains('mythology')) {
      return _genreProfiles['fantasy']!;
    }
    if (genreText.contains('western')) return _genreProfiles['western']!;
    if (genreText.contains('romance') || genreText.contains('romantic')) {
      return _genreProfiles['romance']!;
    }
    if (genreText.contains('animation') || genreText.contains('animated')) {
      return _genreProfiles['animation']!;
    }
    if (genreText.contains('comedy')) return _genreProfiles['comedy']!;
    if (genreText.contains('thriller') || genreText.contains('crime')) {
      return _genreProfiles['thriller']!;
    }
    if (genreText.contains('retro') || genreText.contains('synthwave')) {
      return _genreProfiles['retro']!;
    }
    return _default;
  }

  static CinematicTitleFontProfile? _profileForExplicitKey(String key) {
    if (key.isEmpty) return null;
    for (final profile in _titleProfiles) {
      if (normalize(profile.key) == key ||
          normalize(profile.fontName) == key ||
          profile.aliases.any((alias) => normalize(alias) == key)) {
        return profile;
      }
    }
    return _genreProfiles[key];
  }

  /// Style for titles beneath artwork cards. The source artwork is not edited;
  /// this affects the separate title caption rendered by the app.
  static TextStyle captionStyle(
    MediaItem media, {
    double baseFontSize = 13,
    Color? color,
  }) => captionStyleForTitle(
    media.title,
    alternateTitles: <String?>[
      media.originalTitle,
      media.canonicalTitle,
      media.franchiseName,
    ],
    type: media.type,
    genres: <String>[...media.genres, ...media.tags, ...media.music],
    styleKey: media.titleStyleKey,
    baseFontSize: baseFontSize,
    color: _parseColor(media.titleFontColor) ??
        _parseColor(media.titleAccentColor) ?? color,
    fontFamilyOverride: media.titleFontFamily,
    fallbackFamilyOverride: media.titleFontFallbackFamily,
    sizeScaleOverride: media.titleFontSize != null && media.titleFontSize! > 0
        ? media.titleFontSize! / 42.0
        : null,
    fontWeightOverride: media.titleFontWeight,
    letterSpacingOverride: media.titleFontLetterSpacing,
    shadowColor: _parseColor(media.titleFontShadowColor),
    shadowBlur: media.titleFontShadowBlur,
  );

  static TextStyle captionStyleForTitle(
    String title, {
    Iterable<String?> alternateTitles = const <String?>[],
    String? type,
    Iterable<String> genres = const <String>[],
    String? styleKey,
    double baseFontSize = 13,
    Color? color,
    String? fontFamilyOverride,
    String? fallbackFamilyOverride,
    double? sizeScaleOverride,
    int? fontWeightOverride,
    double? letterSpacingOverride,
    Color? shadowColor,
    double? shadowBlur,
  }) {
    final profile = resolveTitle(
      title,
      alternateTitles: alternateTitles,
      type: type,
      genres: genres,
      styleKey: styleKey,
    );
    final family = (fontFamilyOverride?.trim().isNotEmpty == true
            ? fontFamilyOverride!.trim()
            : profile.fontFamily.trim());
    final fallbackFamily = (fallbackFamilyOverride?.trim().isNotEmpty == true
            ? fallbackFamilyOverride!.trim()
            : profile.fallbackFamily);
    final lengthScale = title.runes.length > 29
        ? .82
        : title.runes.length > 22
            ? .88
            : title.runes.length > 16
                ? .94
                : 1.0;
    return TextStyle(
      color: color,
      fontFamily: family.isEmpty ? null : family,
      fontFamilyFallback: <String>[
        fallbackFamily,
        if (fallbackFamily != 'sans-serif') 'sans-serif',
      ],
      fontSize: (baseFontSize * (sizeScaleOverride ?? profile.sizeScale) * lengthScale)
          .clamp(10.0, baseFontSize * 1.12)
          .toDouble(),
      fontWeight: _weightFromValue(fontWeightOverride) ?? profile.weight,
      fontStyle: profile.italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: (letterSpacingOverride ?? profile.letterSpacing)
          .clamp(-.7, 1.15).toDouble(),
      shadows: shadowColor == null
          ? null
          : <Shadow>[Shadow(color: shadowColor, blurRadius: (shadowBlur ?? 0).clamp(0.0, 80.0).toDouble())],
      height: 1.05,
    );
  }

  static FontWeight? _weightFromValue(int? value) {
    if (value == null) return null;
    if (value <= 100) return FontWeight.w100;
    if (value <= 200) return FontWeight.w200;
    if (value <= 300) return FontWeight.w300;
    if (value <= 400) return FontWeight.w400;
    if (value <= 500) return FontWeight.w500;
    if (value <= 600) return FontWeight.w600;
    if (value <= 700) return FontWeight.w700;
    if (value <= 800) return FontWeight.w800;
    return FontWeight.w900;
  }

  static Color? _parseColor(String? raw) {
    var value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('#')) value = value.substring(1);
    if (value.startsWith('0x') || value.startsWith('0X')) value = value.substring(2);
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8 || !RegExp(r'^[0-9A-Fa-f]{8}$').hasMatch(value)) return null;
    try {
      return Color(int.parse(value, radix: 16));
    } on FormatException {
      return null;
    }
  }
}
