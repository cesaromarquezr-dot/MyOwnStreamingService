/// Cinematic-universe watch orders built on the shared MediaItem catalog.
///
/// The MCU chronology is a dated editorial snapshot, not an assertion that a
/// third-party catalog is always current. New releases should be assigned a
/// verified story position before they are inserted into the official guide.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'core/models/profile_governance.dart';
import 'details.dart';

const String mcuChronologySource =
    'Marvel, “See the Complete MCU Timeline on Disney+”, published June 2, 2026';
const String mcuChronologySourceUrl =
    'https://www.marvel.com/articles/movies/mcu-timeline-order-disney-plus';

/// The order is editorially meaningful: an entry can appear in multiple guides
/// without duplicating its underlying catalog media record.
enum CinematicUniverseGuideMode {
  firstTimeViewer,
  filmReleaseOrder,
  officialChronology,
  phasesAndSagas,
  essentialStoryPath,
  catalogMetadata,
  catalogChronology,
  catalogPhasesAndSagas,
}

extension CinematicUniverseGuideModeLabel on CinematicUniverseGuideMode {
  String get label => switch (this) {
        CinematicUniverseGuideMode.firstTimeViewer => 'Release Order · Recommended for First-Time Viewers',
        CinematicUniverseGuideMode.filmReleaseOrder => 'Film Release Order',
        CinematicUniverseGuideMode.officialChronology =>
          'Official Complete Timeline',
        CinematicUniverseGuideMode.phasesAndSagas => 'Phases & Sagas',
        CinematicUniverseGuideMode.essentialStoryPath => 'Essential Story Path',
        CinematicUniverseGuideMode.catalogMetadata => 'Catalog Release Order',
        CinematicUniverseGuideMode.catalogChronology => 'Catalog Story Timeline',
        CinematicUniverseGuideMode.catalogPhasesAndSagas => 'Catalog Phases & Sagas',
      };
}

enum UniverseContentKind { movie, seriesSeason, short, special }

class UniverseGuideEntry {
  final String id;
  final String title;
  final String catalogTitle;
  final int? releaseYear;
  final UniverseContentKind kind;
  final int? phase;
  final String? saga;
  final int? seasonNumber;
  final List<String> aliases;
  final String? timelineLabel;
  final int? storyOrder;
  final int? releaseOrder;
  final String? editorialNote;
  final bool timelinePlacementVerified;

  const UniverseGuideEntry({
    required this.id,
    required this.title,
    required this.catalogTitle,
    this.releaseYear,
    required this.kind,
    this.phase,
    this.saga,
    this.seasonNumber,
    this.aliases = const <String>[],
    this.timelineLabel,
    this.storyOrder,
    this.releaseOrder,
    this.editorialNote,
    this.timelinePlacementVerified = true,
  });

  String get typeLabel => switch (kind) {
        UniverseContentKind.movie => 'Film',
        UniverseContentKind.seriesSeason =>
          seasonNumber == null ? 'Series' : 'Series · Season $seasonNumber',
        UniverseContentKind.short => 'Short',
        UniverseContentKind.special => 'Special',
      };

  String get sagaLabel => saga ?? (phase == null ? 'MCU' : 'Phase $phase');
}

class CinematicUniverseDefinition {
  final String id;
  final String name;
  final String description;
  final bool hasSeedGuides;

  const CinematicUniverseDefinition({
    required this.id,
    required this.name,
    required this.description,
    this.hasSeedGuides = false,
  });
}

class CinematicUniverseProgress {
  CinematicUniverseProgress._();

  static String _key(String profileId) =>
      'moss_cinematic_universe_watched_v1_${Uri.encodeComponent(profileId)}';

  static Future<Set<String>> load(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key(profileId)) ?? const <String>[]).toSet();
  }

  static Future<void> save(String profileId, Set<String> workIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(profileId), workIds.toList()..sort());
  }
}

class CinematicUniverseWatchLogic {
  CinematicUniverseWatchLogic._();

  static const mcu = CinematicUniverseDefinition(
    id: 'marvel-cinematic-universe',
    name: 'Marvel Cinematic Universe (MCU)',
    description:
        'A connected universe across films, season-level TV entries, shorts and specials.',
    hasSeedGuides: true,
  );

  static const List<UniverseGuideEntry> _chronology = <UniverseGuideEntry>[
    UniverseGuideEntry(id:'eyes-of-wakanda-s1',title:'Eyes of Wakanda · Season 1',catalogTitle:'Eyes of Wakanda',releaseYear:2025,kind:UniverseContentKind.seriesSeason,seasonNumber:1,timelineLabel:'Across early Wakandan history',storyOrder:1),
    UniverseGuideEntry(id:'captain-america-first-avenger',title:'Captain America: The First Avenger',catalogTitle:'Captain America: The First Avenger',releaseYear:2011,kind:UniverseContentKind.movie,phase:1,saga:'Infinity Saga',aliases:['Captain America: First Avenger'],timelineLabel:'World War II era',storyOrder:2),
    UniverseGuideEntry(id:'agent-carter-one-shot',title:'Marvel One-Shot: Agent Carter',catalogTitle:'Agent Carter',releaseYear:2013,kind:UniverseContentKind.short,aliases:['Marvel Studios One Shot: Agent Carter'],timelineLabel:'Post-war era',storyOrder:3),
    UniverseGuideEntry(id:'captain-marvel',title:'Captain Marvel',catalogTitle:'Captain Marvel',releaseYear:2019,kind:UniverseContentKind.movie,phase:3,saga:'Infinity Saga',timelineLabel:'1990s',storyOrder:4),
    UniverseGuideEntry(id:'iron-man',title:'Iron Man',catalogTitle:'Iron Man',releaseYear:2008,kind:UniverseContentKind.movie,phase:1,saga:'Infinity Saga',timelineLabel:'2008',storyOrder:5),
    UniverseGuideEntry(id:'iron-man-2',title:'Iron Man 2',catalogTitle:'Iron Man 2',releaseYear:2010,kind:UniverseContentKind.movie,phase:1,saga:'Infinity Saga',timelineLabel:'2010',storyOrder:6),
    UniverseGuideEntry(id:'incredible-hulk',title:'The Incredible Hulk',catalogTitle:'The Incredible Hulk',releaseYear:2008,kind:UniverseContentKind.movie,phase:1,saga:'Infinity Saga',aliases:['Hulk'],timelineLabel:'2010 era',storyOrder:7),
    UniverseGuideEntry(id:'funny-thing-thor-one-shot',title:'Marvel One-Shot: A Funny Thing Happened on the Way to Thor’s Hammer',catalogTitle:'A Funny Thing Happened on the Way to Thor’s Hammer',releaseYear:2011,kind:UniverseContentKind.short,aliases:['Marvel Studios One Shot: A Funny Thing Happened on the Way to Thor’s Hammer'],timelineLabel:'Before Thor',storyOrder:8),
    UniverseGuideEntry(id:'thor',title:'Thor',catalogTitle:'Thor',releaseYear:2011,kind:UniverseContentKind.movie,phase:1,saga:'Infinity Saga',timelineLabel:'2011',storyOrder:9),
    UniverseGuideEntry(id:'the-consultant-one-shot',title:'Marvel One-Shot: The Consultant',catalogTitle:'The Consultant',releaseYear:2011,kind:UniverseContentKind.short,aliases:['Marvel Studios One Shot: The Consultant'],timelineLabel:'After The Incredible Hulk',storyOrder:10),
    UniverseGuideEntry(id:'the-avengers',title:'The Avengers',catalogTitle:'The Avengers',releaseYear:2012,kind:UniverseContentKind.movie,phase:1,saga:'Infinity Saga',aliases:['Marvel’s the Avengers','Marvels The Avengers','Avengers'],timelineLabel:'2012',storyOrder:11),
    UniverseGuideEntry(id:'item-47',title:'Marvel One-Shot: Item 47',catalogTitle:'Item 47',releaseYear:2012,kind:UniverseContentKind.short,aliases:['Marvel Studios One Shot: Item 47'],timelineLabel:'After The Avengers',storyOrder:12),
    UniverseGuideEntry(id:'thor-dark-world',title:'Thor: The Dark World',catalogTitle:'Thor: The Dark World',releaseYear:2013,kind:UniverseContentKind.movie,phase:2,saga:'Infinity Saga',timelineLabel:'After The Avengers',storyOrder:13),
    UniverseGuideEntry(id:'iron-man-3',title:'Iron Man 3',catalogTitle:'Iron Man 3',releaseYear:2013,kind:UniverseContentKind.movie,phase:2,saga:'Infinity Saga',timelineLabel:'After The Avengers',storyOrder:14),
    UniverseGuideEntry(id:'all-hail-the-king',title:'Marvel One-Shot: All Hail the King',catalogTitle:'All Hail the King',releaseYear:2014,kind:UniverseContentKind.short,aliases:['Marvel Studios One Shot: All Hail the King'],timelineLabel:'Post–Iron Man 3',storyOrder:15),
    UniverseGuideEntry(id:'winter-soldier',title:'Captain America: The Winter Soldier',catalogTitle:'Captain America: The Winter Soldier',releaseYear:2014,kind:UniverseContentKind.movie,phase:2,saga:'Infinity Saga',aliases:['Captain America 2'],timelineLabel:'2014',storyOrder:16),
    UniverseGuideEntry(id:'guardians-galaxy',title:'Guardians of the Galaxy',catalogTitle:'Guardians of the Galaxy',releaseYear:2014,kind:UniverseContentKind.movie,phase:2,saga:'Infinity Saga',timelineLabel:'2014',storyOrder:17),
    UniverseGuideEntry(id:'guardians-galaxy-vol-2',title:'Guardians of the Galaxy Vol. 2',catalogTitle:'Guardians of the Galaxy Vol. 2',releaseYear:2017,kind:UniverseContentKind.movie,phase:3,saga:'Infinity Saga',aliases:['Guardians of the Galaxy 2'],timelineLabel:'Shortly after the first Guardians',storyOrder:18),
    UniverseGuideEntry(id:'i-am-groot-s1',title:'I Am Groot · Season 1',catalogTitle:'I Am Groot',releaseYear:2022,kind:UniverseContentKind.seriesSeason,seasonNumber:1,timelineLabel:'After Guardians Vol. 2',storyOrder:19),
    UniverseGuideEntry(id:'i-am-groot-s2',title:'I Am Groot · Season 2',catalogTitle:'I Am Groot',releaseYear:2023,kind:UniverseContentKind.seriesSeason,seasonNumber:2,timelineLabel:'After Guardians Vol. 2',storyOrder:20),
    UniverseGuideEntry(id:'daredevil-s1',title:'Daredevil · Season 1',catalogTitle:'Daredevil',releaseYear:2015,kind:UniverseContentKind.seriesSeason,seasonNumber:1,timelineLabel:'Mid-2010s',storyOrder:21),
    UniverseGuideEntry(id:'jessica-jones-s1',title:'Jessica Jones · Season 1',catalogTitle:'Jessica Jones',releaseYear:2015,kind:UniverseContentKind.seriesSeason,seasonNumber:1,timelineLabel:'Mid-2010s',storyOrder:22),
    UniverseGuideEntry(id:'age-of-ultron',title:'Avengers: Age of Ultron',catalogTitle:'Avengers: Age of Ultron',releaseYear:2015,kind:UniverseContentKind.movie,phase:2,saga:'Infinity Saga',aliases:['The Avengers: Age of Ultron'],timelineLabel:'2015',storyOrder:23),
    UniverseGuideEntry(id:'ant-man',title:'Ant-Man',catalogTitle:'Ant-Man',releaseYear:2015,kind:UniverseContentKind.movie,phase:2,saga:'Infinity Saga',timelineLabel:'2015',storyOrder:24),
    UniverseGuideEntry(id:'daredevil-s2',title:'Daredevil · Season 2',catalogTitle:'Daredevil',releaseYear:2016,kind:UniverseContentKind.seriesSeason,seasonNumber:2,timelineLabel:'After Daredevil Season 1',storyOrder:25),
    UniverseGuideEntry(id:'luke-cage-s1',title:'Luke Cage · Season 1',catalogTitle:'Luke Cage',releaseYear:2016,kind:UniverseContentKind.seriesSeason,seasonNumber:1,timelineLabel:'Mid-2010s',storyOrder:26),
    UniverseGuideEntry(id:'iron-fist-s1',title:'Iron Fist · Season 1',catalogTitle:'Iron Fist',releaseYear:2017,kind:UniverseContentKind.seriesSeason,seasonNumber:1,timelineLabel:'Mid-2010s',storyOrder:27),
    UniverseGuideEntry(id:'the-defenders',title:'The Defenders',catalogTitle:'The Defenders',releaseYear:2017,kind:UniverseContentKind.seriesSeason,timelineLabel:'After the first street-level hero seasons',storyOrder:28),
    UniverseGuideEntry(id:'civil-war',title:'Captain America: Civil War',catalogTitle:'Captain America: Civil War',releaseYear:2016,kind:UniverseContentKind.movie,phase:3,saga:'Infinity Saga',timelineLabel:'2016',storyOrder:29),
    UniverseGuideEntry(id:'black-widow',title:'Black Widow',catalogTitle:'Black Widow',releaseYear:2021,kind:UniverseContentKind.movie,phase:4,saga:'Multiverse Saga',timelineLabel:'After Civil War',storyOrder:30),
    UniverseGuideEntry(id:'black-panther',title:'Black Panther',catalogTitle:'Black Panther',releaseYear:2018,kind:UniverseContentKind.movie,phase:3,saga:'Infinity Saga',timelineLabel:'2016',storyOrder:31),
    UniverseGuideEntry(id:'spider-man-homecoming',title:'Spider-Man: Homecoming',catalogTitle:'Spider-Man: Homecoming',releaseYear:2017,kind:UniverseContentKind.movie,phase:3,saga:'Infinity Saga',aliases:['Spiderman Homecoming'],timelineLabel:'After Civil War',storyOrder:32),
    UniverseGuideEntry(id:'punisher-s1',title:'The Punisher · Season 1',catalogTitle:'The Punisher',releaseYear:2017,kind:UniverseContentKind.seriesSeason,seasonNumber:1,timelineLabel:'Street-level stories',storyOrder:33),
    UniverseGuideEntry(id:'doctor-strange',title:'Doctor Strange',catalogTitle:'Doctor Strange',releaseYear:2016,kind:UniverseContentKind.movie,phase:3,saga:'Infinity Saga',timelineLabel:'2016–2017',storyOrder:34),
    UniverseGuideEntry(id:'jessica-jones-s2',title:'Jessica Jones · Season 2',catalogTitle:'Jessica Jones',releaseYear:2018,kind:UniverseContentKind.seriesSeason,seasonNumber:2,timelineLabel:'After The Defenders',storyOrder:35),
    UniverseGuideEntry(id:'luke-cage-s2',title:'Luke Cage · Season 2',catalogTitle:'Luke Cage',releaseYear:2018,kind:UniverseContentKind.seriesSeason,seasonNumber:2,timelineLabel:'After The Defenders',storyOrder:36),
    UniverseGuideEntry(id:'iron-fist-s2',title:'Iron Fist · Season 2',catalogTitle:'Iron Fist',releaseYear:2018,kind:UniverseContentKind.seriesSeason,seasonNumber:2,timelineLabel:'After The Defenders',storyOrder:37),
    UniverseGuideEntry(id:'daredevil-s3',title:'Daredevil · Season 3',catalogTitle:'Daredevil',releaseYear:2018,kind:UniverseContentKind.seriesSeason,seasonNumber:3,timelineLabel:'After The Defenders',storyOrder:38),
    UniverseGuideEntry(id:'thor-ragnarok',title:'Thor: Ragnarok',catalogTitle:'Thor: Ragnarok',releaseYear:2017,kind:UniverseContentKind.movie,phase:3,saga:'Infinity Saga',timelineLabel:'2017',storyOrder:39),
    UniverseGuideEntry(id:'punisher-s2',title:'The Punisher · Season 2',catalogTitle:'The Punisher',releaseYear:2019,kind:UniverseContentKind.seriesSeason,seasonNumber:2,timelineLabel:'After Punisher Season 1',storyOrder:40),
    UniverseGuideEntry(id:'jessica-jones-s3',title:'Jessica Jones · Season 3',catalogTitle:'Jessica Jones',releaseYear:2019,kind:UniverseContentKind.seriesSeason,seasonNumber:3,timelineLabel:'After Jessica Jones Season 2',storyOrder:41),
    UniverseGuideEntry(id:'ant-man-wasp',title:'Ant-Man and the Wasp',catalogTitle:'Ant-Man and the Wasp',releaseYear:2018,kind:UniverseContentKind.movie,phase:3,saga:'Infinity Saga',timelineLabel:'2018',storyOrder:42),
    UniverseGuideEntry(id:'infinity-war',title:'Avengers: Infinity War',catalogTitle:'Avengers: Infinity War',releaseYear:2018,kind:UniverseContentKind.movie,phase:3,saga:'Infinity Saga',timelineLabel:'2018',storyOrder:43),
    UniverseGuideEntry(id:'endgame',title:'Avengers: Endgame',catalogTitle:'Avengers: Endgame',releaseYear:2019,kind:UniverseContentKind.movie,phase:3,saga:'Infinity Saga',timelineLabel:'2018–2023',storyOrder:44),
    UniverseGuideEntry(id:'loki-s1',title:'Loki · Season 1',catalogTitle:'Loki',releaseYear:2021,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',timelineLabel:'Branching timelines',storyOrder:45),
    UniverseGuideEntry(id:'what-if-s1',title:'What If…? · Season 1',catalogTitle:'What If…?',releaseYear:2021,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',aliases:['What If...?','What If'],timelineLabel:'Alternate realities',storyOrder:46),
    UniverseGuideEntry(id:'marvel-zombies',title:'Marvel Zombies',catalogTitle:'Marvel Zombies',releaseYear:2025,kind:UniverseContentKind.seriesSeason,saga:'Multiverse Saga',timelineLabel:'Alternate reality',storyOrder:47),
    UniverseGuideEntry(id:'wandavision',title:'WandaVision',catalogTitle:'WandaVision',releaseYear:2021,kind:UniverseContentKind.seriesSeason,saga:'Multiverse Saga',timelineLabel:'After Endgame',storyOrder:48),
    UniverseGuideEntry(id:'shang-chi',title:'Shang-Chi and the Legend of the Ten Rings',catalogTitle:'Shang-Chi and the Legend of the Ten Rings',releaseYear:2021,kind:UniverseContentKind.movie,phase:4,saga:'Multiverse Saga',aliases:['Shang-Chi'],timelineLabel:'Post-Blip',storyOrder:49),
    UniverseGuideEntry(id:'falcon-winter-soldier',title:'The Falcon and the Winter Soldier',catalogTitle:'The Falcon and the Winter Soldier',releaseYear:2021,kind:UniverseContentKind.seriesSeason,saga:'Multiverse Saga',aliases:['Falcon and the Winter Soldier'],timelineLabel:'After Endgame',storyOrder:50),
    UniverseGuideEntry(id:'spider-man-far-from-home',title:'Spider-Man: Far From Home',catalogTitle:'Spider-Man: Far From Home',releaseYear:2019,kind:UniverseContentKind.movie,phase:3,saga:'Infinity Saga',aliases:['Spiderman Far From Home'],timelineLabel:'After Endgame',storyOrder:51),
    UniverseGuideEntry(id:'eternals',title:'Eternals',catalogTitle:'Eternals',releaseYear:2021,kind:UniverseContentKind.movie,phase:4,saga:'Multiverse Saga',timelineLabel:'After the Blip',storyOrder:52),
    UniverseGuideEntry(id:'spider-man-no-way-home',title:'Spider-Man: No Way Home',catalogTitle:'Spider-Man: No Way Home',releaseYear:2021,kind:UniverseContentKind.movie,phase:4,saga:'Multiverse Saga',aliases:['Spiderman No Way Home'],timelineLabel:'After Far From Home',storyOrder:53),
    UniverseGuideEntry(id:'doctor-strange-multiverse',title:'Doctor Strange in the Multiverse of Madness',catalogTitle:'Doctor Strange in the Multiverse of Madness',releaseYear:2022,kind:UniverseContentKind.movie,phase:4,saga:'Multiverse Saga',aliases:['Doctor Strange 2'],timelineLabel:'After WandaVision',storyOrder:54),
    UniverseGuideEntry(id:'hawkeye-s1',title:'Hawkeye · Season 1',catalogTitle:'Hawkeye',releaseYear:2021,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',timelineLabel:'Holiday season',storyOrder:55),
    UniverseGuideEntry(id:'moon-knight-s1',title:'Moon Knight · Season 1',catalogTitle:'Moon Knight',releaseYear:2022,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',timelineLabel:'Post-Blip',storyOrder:56),
    UniverseGuideEntry(id:'wakanda-forever',title:'Black Panther: Wakanda Forever',catalogTitle:'Black Panther: Wakanda Forever',releaseYear:2022,kind:UniverseContentKind.movie,phase:4,saga:'Multiverse Saga',timelineLabel:'Post-Blip',storyOrder:57),
    UniverseGuideEntry(id:'echo-s1',title:'Echo · Season 1',catalogTitle:'Echo',releaseYear:2024,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',timelineLabel:'After Hawkeye',storyOrder:58),
    UniverseGuideEntry(id:'she-hulk-s1',title:'She-Hulk: Attorney at Law · Season 1',catalogTitle:'She-Hulk: Attorney at Law',releaseYear:2022,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',aliases:['She-Hulk'],timelineLabel:'Post-Blip',storyOrder:59),
    UniverseGuideEntry(id:'ms-marvel-s1',title:'Ms. Marvel · Season 1',catalogTitle:'Ms. Marvel',releaseYear:2022,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',timelineLabel:'Post-Blip',storyOrder:60),
    UniverseGuideEntry(id:'thor-love-thunder',title:'Thor: Love and Thunder',catalogTitle:'Thor: Love and Thunder',releaseYear:2022,kind:UniverseContentKind.movie,phase:4,saga:'Multiverse Saga',timelineLabel:'Post-Blip',storyOrder:61),
    UniverseGuideEntry(id:'ironheart-s1',title:'Ironheart · Season 1',catalogTitle:'Ironheart',releaseYear:2025,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',timelineLabel:'After Wakanda Forever',storyOrder:62),
    UniverseGuideEntry(id:'werewolf-by-night',title:'Werewolf by Night',catalogTitle:'Werewolf by Night',releaseYear:2022,kind:UniverseContentKind.special,saga:'Multiverse Saga',timelineLabel:'Special presentation',storyOrder:63),
    UniverseGuideEntry(id:'guardians-holiday-special',title:'The Guardians of the Galaxy Holiday Special',catalogTitle:'The Guardians of the Galaxy Holiday Special',releaseYear:2022,kind:UniverseContentKind.special,saga:'Multiverse Saga',aliases:['Guardians of the Galaxy Holiday Special'],timelineLabel:'Holiday special',storyOrder:64),
    UniverseGuideEntry(id:'quantumania',title:'Ant-Man and the Wasp: Quantumania',catalogTitle:'Ant-Man and the Wasp: Quantumania',releaseYear:2023,kind:UniverseContentKind.movie,phase:5,saga:'Multiverse Saga',aliases:['Ant-Man Quantumania'],timelineLabel:'Post-Blip',storyOrder:65),
    UniverseGuideEntry(id:'guardians-galaxy-vol-3',title:'Guardians of the Galaxy Vol. 3',catalogTitle:'Guardians of the Galaxy Vol. 3',releaseYear:2023,kind:UniverseContentKind.movie,phase:5,saga:'Multiverse Saga',timelineLabel:'After the Holiday Special',storyOrder:66),
    UniverseGuideEntry(id:'secret-invasion-s1',title:'Secret Invasion · Season 1',catalogTitle:'Secret Invasion',releaseYear:2023,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',timelineLabel:'Post-Blip',storyOrder:67),
    UniverseGuideEntry(id:'the-marvels',title:'The Marvels',catalogTitle:'The Marvels',releaseYear:2023,kind:UniverseContentKind.movie,phase:5,saga:'Multiverse Saga',timelineLabel:'After Ms. Marvel',storyOrder:68),
    UniverseGuideEntry(id:'loki-s2',title:'Loki · Season 2',catalogTitle:'Loki',releaseYear:2023,kind:UniverseContentKind.seriesSeason,seasonNumber:2,saga:'Multiverse Saga',timelineLabel:'Branching timelines',storyOrder:69),
    UniverseGuideEntry(id:'what-if-s2',title:'What If…? · Season 2',catalogTitle:'What If…?',releaseYear:2023,kind:UniverseContentKind.seriesSeason,seasonNumber:2,saga:'Multiverse Saga',aliases:['What If...?','What If'],timelineLabel:'Alternate realities',storyOrder:70),
    UniverseGuideEntry(id:'deadpool-wolverine',title:'Deadpool & Wolverine',catalogTitle:'Deadpool & Wolverine',releaseYear:2024,kind:UniverseContentKind.movie,phase:5,saga:'Multiverse Saga',timelineLabel:'Multiverse story',storyOrder:71),
    UniverseGuideEntry(id:'agatha-all-along-s1',title:'Agatha All Along · Season 1',catalogTitle:'Agatha All Along',releaseYear:2024,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',timelineLabel:'After WandaVision',storyOrder:72),
    UniverseGuideEntry(id:'what-if-s3',title:'What If…? · Season 3',catalogTitle:'What If…?',releaseYear:2024,kind:UniverseContentKind.seriesSeason,seasonNumber:3,saga:'Multiverse Saga',aliases:['What If...?','What If'],timelineLabel:'Alternate realities',storyOrder:73),
    UniverseGuideEntry(id:'daredevil-born-again-s1',title:'Daredevil: Born Again · Season 1',catalogTitle:'Daredevil: Born Again',releaseYear:2025,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',timelineLabel:'Street-level continuity',storyOrder:74),
    UniverseGuideEntry(id:'brave-new-world',title:'Captain America: Brave New World',catalogTitle:'Captain America: Brave New World',releaseYear:2025,kind:UniverseContentKind.movie,phase:5,saga:'Multiverse Saga',timelineLabel:'Post-Blip',storyOrder:75),
    UniverseGuideEntry(id:'thunderbolts',title:'Thunderbolts*',catalogTitle:'Thunderbolts*',releaseYear:2025,kind:UniverseContentKind.movie,phase:5,saga:'Multiverse Saga',aliases:['Thunderbolts'],timelineLabel:'Post-Blip',storyOrder:76),
    UniverseGuideEntry(id:'fantastic-four-first-steps',title:'The Fantastic Four: First Steps',catalogTitle:'The Fantastic Four: First Steps',releaseYear:2025,kind:UniverseContentKind.movie,phase:6,saga:'Multiverse Saga',aliases:['Fantastic Four: First Steps'],timelineLabel:'Separate retro-futurist world',storyOrder:77),
    UniverseGuideEntry(id:'wonder-man-s1',title:'Wonder Man · Season 1',catalogTitle:'Wonder Man',releaseYear:2026,kind:UniverseContentKind.seriesSeason,seasonNumber:1,saga:'Multiverse Saga',timelineLabel:'Post-Blip',storyOrder:78),
    UniverseGuideEntry(id:'daredevil-born-again-s2',title:'Daredevil: Born Again · Season 2',catalogTitle:'Daredevil: Born Again',releaseYear:2026,kind:UniverseContentKind.seriesSeason,seasonNumber:2,saga:'Multiverse Saga',timelineLabel:'Street-level continuity',storyOrder:79),
    UniverseGuideEntry(id:'punisher-one-last-kill',title:'The Punisher: One Last Kill',catalogTitle:'The Punisher: One Last Kill',releaseYear:2026,kind:UniverseContentKind.special,saga:'Multiverse Saga',timelineLabel:'Special presentation',storyOrder:80),
    UniverseGuideEntry(id:'spider-man-brand-new-day',title:'Spider-Man: Brand New Day',catalogTitle:'Spider-Man: Brand New Day',releaseYear:2026,kind:UniverseContentKind.movie,phase:6,saga:'Multiverse Saga',aliases:['Spiderman Brand New Day'],timelineLabel:'Chronology placement awaiting official timeline update',timelinePlacementVerified:false),
  ];

  static const List<String> _filmReleaseOrderIds = <String>[
    'iron-man','incredible-hulk','iron-man-2','thor','captain-america-first-avenger','the-avengers',
    'iron-man-3','thor-dark-world','winter-soldier','guardians-galaxy','age-of-ultron','ant-man',
    'civil-war','doctor-strange','guardians-galaxy-vol-2','spider-man-homecoming','thor-ragnarok',
    'black-panther','infinity-war','ant-man-wasp','captain-marvel','endgame','spider-man-far-from-home',
    'black-widow','shang-chi','eternals','spider-man-no-way-home','doctor-strange-multiverse',
    'thor-love-thunder','wakanda-forever','quantumania','guardians-galaxy-vol-3','the-marvels',
    'deadpool-wolverine','brave-new-world','thunderbolts','fantastic-four-first-steps','spider-man-brand-new-day',
  ];

  static const List<String> _essentialIds = <String>[
    'iron-man','the-avengers','winter-soldier','guardians-galaxy','age-of-ultron','civil-war',
    'doctor-strange','black-panther','thor-ragnarok','infinity-war','endgame','wandavision',
    'spider-man-far-from-home','spider-man-no-way-home','loki-s1','doctor-strange-multiverse',
    'fantastic-four-first-steps',
  ];

  static final Map<String, UniverseGuideEntry> _byId = <String, UniverseGuideEntry>{
    for (final entry in _chronology) entry.id: entry,
  };

  static List<UniverseGuideEntry> pendingTimelineUpdates() =>
      _chronology.where((entry) => !entry.timelinePlacementVerified).toList(growable: false);

  static List<UniverseGuideEntry> seededMcuGuide(CinematicUniverseGuideMode mode) {
    switch (mode) {
      case CinematicUniverseGuideMode.firstTimeViewer:
      case CinematicUniverseGuideMode.filmReleaseOrder:
        return _filmReleaseOrderIds
            .map((id) => _byId[id])
            .whereType<UniverseGuideEntry>()
            .toList(growable: false);
      case CinematicUniverseGuideMode.officialChronology:
        return List<UniverseGuideEntry>.unmodifiable(
          _chronology.where((entry) => entry.timelinePlacementVerified),
        );
      case CinematicUniverseGuideMode.phasesAndSagas:
        final entries = _filmReleaseOrderIds
            .map((id) => _byId[id])
            .whereType<UniverseGuideEntry>()
            .toList();
        entries.sort((a, b) {
          final phase = (a.phase ?? 99).compareTo(b.phase ?? 99);
          if (phase != 0) return phase;
          return _filmReleaseOrderIds.indexOf(a.id).compareTo(
              _filmReleaseOrderIds.indexOf(b.id));
        });
        return entries;
      case CinematicUniverseGuideMode.essentialStoryPath:
        return _essentialIds
            .map((id) => _byId[id])
            .whereType<UniverseGuideEntry>()
            .toList(growable: false);
      case CinematicUniverseGuideMode.catalogMetadata:
      case CinematicUniverseGuideMode.catalogChronology:
      case CinematicUniverseGuideMode.catalogPhasesAndSagas:
        return const <UniverseGuideEntry>[];
    }
  }

  static List<CinematicUniverseDefinition> universesInCatalog(
    Iterable<MediaItem> items,
  ) {
    final byId = <String, CinematicUniverseDefinition>{mcu.id: mcu};
    for (final item in items) {
      for (var i = 0; i < item.cinematicUniverseIds.length; i++) {
        final id = item.cinematicUniverseIds[i].trim();
        if (id.isEmpty || byId.containsKey(id)) continue;
        final name = i < item.cinematicUniverseNames.length
            ? item.cinematicUniverseNames[i].trim()
            : _humanizeId(id);
        byId[id] = CinematicUniverseDefinition(
          id: id,
          name: name.isEmpty ? _humanizeId(id) : name,
          description: 'Built from explicit cinematic-universe catalog metadata.',
        );
      }
    }
    return byId.values.toList()
      ..sort((a, b) {
        if (a.id == mcu.id) return -1;
        if (b.id == mcu.id) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  static List<MediaItem> catalogItemsForUniverse({
    required String universeId,
    required Iterable<MediaItem> library,
    required Profile profile,
    bool chronological = false,
    bool phasesAndSagas = false,
  }) {
    final items = library.where((item) =>
        item.isAccessibleTo(profile) && item.cinematicUniverseIds.contains(universeId)).toList();
    items.sort((a, b) {
      if (phasesAndSagas) {
        final aPhase = _phaseNumber(a.cinematicUniversePhase);
        final bPhase = _phaseNumber(b.cinematicUniversePhase);
        final byPhase = aPhase.compareTo(bPhase);
        if (byPhase != 0) return byPhase;
        final bySaga = (a.cinematicUniverseSaga ?? '').compareTo(b.cinematicUniverseSaga ?? '');
        if (bySaga != 0) return bySaga;
      }
      if (chronological) {
        final byStory = (a.cinematicUniverseTimelineOrder ?? 1 << 30)
            .compareTo(b.cinematicUniverseTimelineOrder ?? 1 << 30);
        if (byStory != 0) return byStory;
      } else {
        final byRelease = (a.cinematicUniverseReleaseOrder ?? 1 << 30)
            .compareTo(b.cinematicUniverseReleaseOrder ?? 1 << 30);
        if (byRelease != 0) return byRelease;
      }
      final byYear = (a.releaseYear ?? 9999).compareTo(b.releaseYear ?? 9999);
      return byYear != 0 ? byYear : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return items;
  }

  static MediaItem? resolveEntryToCatalog({
    required UniverseGuideEntry entry,
    required Iterable<MediaItem> library,
    required Profile profile,
  }) {
    final acceptedNames = <String>{
      normalizeTitle(entry.catalogTitle),
      normalizeTitle(entry.title),
      ...entry.aliases.map(normalizeTitle),
    }..remove('');
    final candidates = library.where((item) {
      if (!item.isAccessibleTo(profile)) return false;
      final isSeries = item.isSeries || item.type.toLowerCase().contains('show') ||
          item.type.toLowerCase().contains('season') || item.seasons.isNotEmpty;
      if (entry.kind == UniverseContentKind.seriesSeason && !isSeries) return false;
      if (entry.kind == UniverseContentKind.movie && isSeries) return false;
      final names = <String>{
        normalizeTitle(item.title),
        normalizeTitle(item.canonicalTitle ?? ''),
        normalizeTitle(item.originalTitle ?? ''),
      }..remove('');
      return names.any(acceptedNames.contains);
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final aDistance = ((a.releaseYear ?? entry.releaseYear ?? 0) - (entry.releaseYear ?? a.releaseYear ?? 0)).abs();
      final bDistance = ((b.releaseYear ?? entry.releaseYear ?? 0) - (entry.releaseYear ?? b.releaseYear ?? 0)).abs();
      return aDistance.compareTo(bDistance);
    });
    return candidates.first;
  }

  static int _phaseNumber(String? value) {
    final match = RegExp(r'\d+').firstMatch(value ?? '');
    return int.tryParse(match?.group(0) ?? '') ?? (1 << 30);
  }

  static String normalizeTitle(String value) => value
      .toLowerCase()
      .replaceAll('…', '...')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static bool isContentRestrictedForUniverseGuide(Profile profile) =>
      const <ProfileContentLevel>{
        ProfileContentLevel.littleKids,
        ProfileContentLevel.kids,
        ProfileContentLevel.olderKids,
        ProfileContentLevel.custom,
      }.contains(profile.governance.contentLevel);

  static String _humanizeId(String id) => id
      .split(RegExp(r'[-_]'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class CinematicUniverseWatchOrdersScreen extends StatefulWidget {
  const CinematicUniverseWatchOrdersScreen({super.key});

  @override
  State<CinematicUniverseWatchOrdersScreen> createState() =>
      _CinematicUniverseWatchOrdersScreenState();
}

class _CinematicUniverseWatchOrdersScreenState
    extends State<CinematicUniverseWatchOrdersScreen> {
  String _universeId = CinematicUniverseWatchLogic.mcu.id;
  CinematicUniverseGuideMode _mode = CinematicUniverseGuideMode.firstTimeViewer;
  String _query = '';
  bool _hideCompleted = false;
  Set<String> _watchedWorkIds = <String>{};
  bool _loadingProgress = true;

  Profile? get _profile => AppController.instance.currentProfile;
  List<MediaItem> get _library => AppController.instance.library;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final profile = _profile;
    if (profile == null) {
      if (mounted) setState(() => _loadingProgress = false);
      return;
    }
    final rows = await CinematicUniverseProgress.load(profile.id);
    if (!mounted) return;
    setState(() {
      _watchedWorkIds = rows;
      _loadingProgress = false;
    });
  }

  Future<void> _toggleWatched(String workId) async {
    final profile = _profile;
    if (profile == null) return;
    setState(() {
      if (!_watchedWorkIds.add(workId)) _watchedWorkIds.remove(workId);
    });
    await CinematicUniverseProgress.save(profile.id, _watchedWorkIds);
  }

  List<UniverseGuideEntry> get _entries {
    if (_universeId == CinematicUniverseWatchLogic.mcu.id) {
      return CinematicUniverseWatchLogic.seededMcuGuide(_mode);
    }
    return const <UniverseGuideEntry>[];
  }

  List<MediaItem> get _metadataItems => CinematicUniverseWatchLogic.catalogItemsForUniverse(
        universeId: _universeId,
        library: _library,
        profile: _profile!,
        chronological: _mode == CinematicUniverseGuideMode.officialChronology ||
            _mode == CinematicUniverseGuideMode.catalogChronology,
        phasesAndSagas: _mode == CinematicUniverseGuideMode.catalogPhasesAndSagas,
      );

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cinematic Universe Watch Orders')),
        body: const Center(child: Text('Select a profile to view universe watch guides.')),
      );
    }
    final universes = CinematicUniverseWatchLogic.universesInCatalog(_library);
    final selectedUniverse = universes.firstWhere(
      (universe) => universe.id == _universeId,
      orElse: () => CinematicUniverseWatchLogic.mcu,
    );
    final restricted = CinematicUniverseWatchLogic.isContentRestrictedForUniverseGuide(profile);
    final isCatalogMode = const <CinematicUniverseGuideMode>{
      CinematicUniverseGuideMode.catalogMetadata,
      CinematicUniverseGuideMode.catalogChronology,
      CinematicUniverseGuideMode.catalogPhasesAndSagas,
    }.contains(_mode);
    final usingSeed = _universeId == CinematicUniverseWatchLogic.mcu.id && !isCatalogMode;
    final rawEntries = usingSeed ? _entries : const <UniverseGuideEntry>[];
    final resolved = rawEntries.map((entry) => _ResolvedUniverseEntry(
      entry: entry,
      media: CinematicUniverseWatchLogic.resolveEntryToCatalog(
        entry: entry,
        library: _library,
        profile: profile,
      ),
    )).toList();
    final metadataItems = isCatalogMode || !usingSeed
        ? _metadataItems
        : const <MediaItem>[];
    final normalizedQuery = CinematicUniverseWatchLogic.normalizeTitle(_query.trim());
    final filteredEntries = resolved.where((item) {
      if (restricted) return false;
      if (_hideCompleted && _watchedWorkIds.contains(item.entry.id)) return false;
      if (normalizedQuery.isNotEmpty &&
          !CinematicUniverseWatchLogic.normalizeTitle(item.entry.title).contains(normalizedQuery)) {
        return false;
      }
      return true;
    }).toList();
    final filteredMetadata = metadataItems.where((item) {
      if (restricted) return false;
      if (_hideCompleted && _watchedWorkIds.contains(_catalogProgressId(item))) return false;
      return normalizedQuery.isEmpty ||
          CinematicUniverseWatchLogic.normalizeTitle(item.title).contains(normalizedQuery);
    }).toList();
    final pendingUpdates = CinematicUniverseWatchLogic.pendingTimelineUpdates().where((entry) {
      if (restricted) return false;
      if (_hideCompleted && _watchedWorkIds.contains(entry.id)) return false;
      return normalizedQuery.isEmpty ||
          CinematicUniverseWatchLogic.normalizeTitle(entry.title).contains(normalizedQuery);
    }).toList(growable: false);
    final totalCount = usingSeed ? resolved.length : metadataItems.length;
    final completedCount = usingSeed
        ? resolved.where((item) => _watchedWorkIds.contains(item.entry.id)).length
        : metadataItems.where((item) => _watchedWorkIds.contains(_catalogProgressId(item))).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Cinematic Universe Watch Orders')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF27213C), Color(0xFF11131D)],
              ),
              border: Border.all(color: Colors.white12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.public_rounded, size: 38),
                SizedBox(height: 10),
                Text('Cinematic Universe Hub',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('Choose release order, an in-universe timeline, phases and sagas, or your own catalog order. A work can appear in many guides without being duplicated.',
                    style: TextStyle(color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _universeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Cinematic universe'),
            items: universes.map((universe) => DropdownMenuItem(
              value: universe.id,
              child: Text(universe.name, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _universeId = value;
                if (value != CinematicUniverseWatchLogic.mcu.id) {
                  _mode = CinematicUniverseGuideMode.catalogMetadata;
                } else if (const <CinematicUniverseGuideMode>{
                  CinematicUniverseGuideMode.catalogMetadata,
                  CinematicUniverseGuideMode.catalogChronology,
                  CinematicUniverseGuideMode.catalogPhasesAndSagas,
                }.contains(_mode)) {
                  _mode = CinematicUniverseGuideMode.firstTimeViewer;
                }
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<CinematicUniverseGuideMode>(
            initialValue: _mode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Watch guide'),
            items: (_universeId == CinematicUniverseWatchLogic.mcu.id
                    ? CinematicUniverseGuideMode.values
                        .where((mode) => mode != CinematicUniverseGuideMode.filmReleaseOrder &&
                            mode != CinematicUniverseGuideMode.catalogMetadata &&
                            mode != CinematicUniverseGuideMode.catalogChronology &&
                            mode != CinematicUniverseGuideMode.catalogPhasesAndSagas)
                    : const <CinematicUniverseGuideMode>[
                        CinematicUniverseGuideMode.catalogMetadata,
                        CinematicUniverseGuideMode.catalogChronology,
                        CinematicUniverseGuideMode.catalogPhasesAndSagas,
                      ])
                .map((mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(mode.label, overflow: TextOverflow.ellipsis),
                )).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _mode = value);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Find a film, series, special or season…',
            ),
          ),
          const SizedBox(height: 10),
          if (_loadingProgress) const LinearProgressIndicator(),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide completed entries'),
            subtitle: const Text('Progress is saved separately for each profile and shared across guides when the underlying work ID matches.'),
            value: _hideCompleted,
            onChanged: (value) => setState(() => _hideCompleted = value),
          ),
          if (restricted)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Universe watch guides are hidden for this profile because the starter guide does not have verified age ratings for every entry. Use a parent-managed content policy and a catalog with verified ratings before enabling these guides for a restricted profile.'),
              ),
            )
          else ...[
            if (_universeId == CinematicUniverseWatchLogic.mcu.id &&
                _mode == CinematicUniverseGuideMode.officialChronology)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Source snapshot: Marvel’s published Complete MCU Timeline (June 2, 2026). Spider-Man: Brand New Day was released later; its in-universe placement remains outside this dated guide until a trusted timeline source confirms it.',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
              ),
            if (selectedUniverse.id != CinematicUniverseWatchLogic.mcu.id ||
                isCatalogMode)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('This guide uses explicit universe metadata from your catalog. It does not infer shared continuity from studio names or franchise labels alone.',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$completedCount of $totalCount completed',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: totalCount == 0 ? 0 : completedCount / totalCount),
                  const SizedBox(height: 4),
                  Text(usingSeed
                      ? 'The guide is independent of your catalog. Only matching, profile-accessible local entries can open for playback.'
                      : 'Custom universe guide built from catalog metadata.' ,
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
              ),
            ),
            if (_mode == CinematicUniverseGuideMode.phasesAndSagas)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('This curated phase view groups films by published phase and saga. Use Official Complete Timeline for season-level series, shorts and specials.',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ),
            if (_mode == CinematicUniverseGuideMode.phasesAndSagas && filteredEntries.isNotEmpty)
              ..._phaseGroupedEntries(filteredEntries),
            if (_mode == CinematicUniverseGuideMode.catalogPhasesAndSagas && filteredMetadata.isNotEmpty)
              ..._phaseGroupedMetadata(filteredMetadata),
            if (_mode != CinematicUniverseGuideMode.phasesAndSagas)
              ...filteredEntries.asMap().entries.map((row) => _entryTile(row.key + 1, row.value)),
            if (_universeId == CinematicUniverseWatchLogic.mcu.id &&
                _mode == CinematicUniverseGuideMode.officialChronology &&
                pendingUpdates.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 18, bottom: 6),
                child: Text('Released after the official timeline snapshot',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              ...pendingUpdates.map((entry) => _entryTile(0, _ResolvedUniverseEntry(
                    entry: entry,
                    media: CinematicUniverseWatchLogic.resolveEntryToCatalog(
                      entry: entry, library: _library, profile: profile),
                  ))),
            ],
            if (filteredMetadata.isNotEmpty && _mode != CinematicUniverseGuideMode.catalogPhasesAndSagas)
              ...filteredMetadata.map((item) => _catalogMediaTile(item)),
            if (filteredEntries.isEmpty && filteredMetadata.isEmpty && pendingUpdates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No entries match this guide, search and profile access. Add explicit universe metadata or make matching media available to this profile.'),
              ),
          ],
          const SizedBox(height: 14),
          const Text('Continuity is not the same as branding: only catalog entries with explicit verified universe metadata are added to custom universes. Phase and saga labels are groupings, not automatically a chronological order.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  List<Widget> _phaseGroupedEntries(List<_ResolvedUniverseEntry> entries) {
    final widgets = <Widget>[];
    int? currentPhase;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final phase = entry.entry.phase;
      if (phase != currentPhase) {
        currentPhase = phase;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(phase == null ? (entry.entry.saga ?? 'Other connected entries') :
              '${entry.entry.saga ?? 'MCU'} · Phase $phase',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ));
      }
      widgets.add(_entryTile(i + 1, entry));
    }
    return widgets;
  }

  Widget _entryTile(int position, _ResolvedUniverseEntry resolved) {
    final entry = resolved.entry;
    final media = resolved.media;
    final watched = _watchedWorkIds.contains(entry.id);
    final canOpen = media != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: watched
              ? const Icon(Icons.check_rounded)
              : (position <= 0 ? const Icon(Icons.update_rounded) : Text('$position')),
        ),
        title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(<String>[entry.typeLabel, if (entry.releaseYear != null) '${entry.releaseYear}', if (entry.timelineLabel != null) entry.timelineLabel!].join(' · ')),
            if (entry.phase != null) Text('${entry.saga ?? 'MCU'} · Phase ${entry.phase}'),
            if (entry.editorialNote != null) Text(entry.editorialNote!, style: const TextStyle(color: Colors.amberAccent)),
            Text(!canOpen
                ? 'Not found in this profile’s catalog'
                : (entry.kind == UniverseContentKind.seriesSeason
                    ? 'Series found — verify this season in details'
                    : 'Available in this profile’s catalog'),
              style: TextStyle(color: canOpen ? Colors.greenAccent : Colors.white38, fontSize: 11)),
            if (media?.postCreditSceneCount != null)
              Text('${media!.postCreditSceneCount} post-credit scene(s) in catalog metadata',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          tooltip: 'Entry actions',
          onSelected: (action) {
            if (action == 'toggle') _toggleWatched(entry.id);
            if (action == 'open' && media != null) {
              Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: media)));
            }
          },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'toggle', child: Text(watched ? 'Mark unwatched' : 'Mark watched')),
            if (media != null) const PopupMenuItem(value: 'open', child: Text('Open title details')),
          ],
          child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.more_vert)),
        ),
        onTap: canOpen
            ? () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: media)))
            : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('This title is not in the active profile’s catalog. Use the entry menu to mark it watched if you have seen it elsewhere.'))),
      ),
    );
  }

  List<Widget> _phaseGroupedMetadata(List<MediaItem> items) {
    final grouped = <String, List<MediaItem>>{};
    for (final item in items) {
      final phase = item.cinematicUniversePhase?.trim();
      final saga = item.cinematicUniverseSaga?.trim();
      final label = <String>[if (saga != null && saga.isNotEmpty) saga,
        if (phase != null && phase.isNotEmpty) phase].join(' · ');
      grouped.putIfAbsent(label.isEmpty ? 'Universe titles without phase metadata' : label,
          () => <MediaItem>[]).add(item);
    }
    final widgets = <Widget>[];
    for (final group in grouped.entries) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(group.key, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ));
      widgets.addAll(group.value.map(_catalogMediaTile));
    }
    return widgets;
  }

  Widget _catalogMediaTile(MediaItem item) {
    final watched = _watchedWorkIds.contains(_catalogProgressId(item));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: watched ? const Icon(Icons.check_rounded) : const Icon(Icons.movie_outlined)),
        title: Text(item.title),
        subtitle: Text(<String>[item.type, if (item.releaseYear != null) '${item.releaseYear}', if (item.cinematicUniverseSaga != null) item.cinematicUniverseSaga!, if (item.cinematicUniversePhase != null) item.cinematicUniversePhase!].join(' · ')),
        trailing: IconButton(
          icon: Icon(watched ? Icons.check_circle : Icons.check_circle_outline),
          tooltip: watched ? 'Mark unwatched' : 'Mark watched',
          onPressed: () => _toggleWatched(_catalogProgressId(item)),
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: item))),
      ),
    );
  }
}

String _catalogProgressId(MediaItem item) {
  final canonical = item.canonicalWorkId?.trim();
  return canonical == null || canonical.isEmpty ? item.id : canonical;
}

class _ResolvedUniverseEntry {
  final UniverseGuideEntry entry;
  final MediaItem? media;
  const _ResolvedUniverseEntry({required this.entry, required this.media});
}
