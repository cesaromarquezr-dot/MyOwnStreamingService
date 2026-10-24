/// Example catalog used to validate metadata matching, franchise grouping,
/// cast/crew profiles, TV browsing, and artist details. This is a starter set,
/// not a complete filmography; live discovery remains responsible for new titles.
class CinematicSeedExample {
  const CinematicSeedExample({
    required this.title,
    required this.isTv,
    required this.universe,
    this.year,
    this.notes,
  });

  final String title;
  final bool isTv;
  final String universe;
  final int? year;
  final String? notes;
}

class CinematicSeedExamples {
  CinematicSeedExamples._();

  static const String mcu = 'Marvel Cinematic Universe';
  static const String spiderNoirContinuity =
      'Spider-Man / Marvel — separate continuity';

  static const List<CinematicSeedExample> movies = <CinematicSeedExample>[
    CinematicSeedExample(title: 'Iron Man', isTv: false, universe: mcu, year: 2008),
    CinematicSeedExample(title: 'The Incredible Hulk', isTv: false, universe: mcu, year: 2008),
    CinematicSeedExample(title: 'Iron Man 2', isTv: false, universe: mcu, year: 2010),
    CinematicSeedExample(title: 'Thor', isTv: false, universe: mcu, year: 2011),
    CinematicSeedExample(title: 'Captain America: The First Avenger', isTv: false, universe: mcu, year: 2011),
    CinematicSeedExample(title: 'The Avengers', isTv: false, universe: mcu, year: 2012),
    CinematicSeedExample(title: 'Iron Man 3', isTv: false, universe: mcu, year: 2013),
    CinematicSeedExample(title: 'Thor: The Dark World', isTv: false, universe: mcu, year: 2013),
    CinematicSeedExample(title: 'Captain America: The Winter Soldier', isTv: false, universe: mcu, year: 2014),
    CinematicSeedExample(title: 'Guardians of the Galaxy', isTv: false, universe: mcu, year: 2014),
    CinematicSeedExample(title: 'Avengers: Age of Ultron', isTv: false, universe: mcu, year: 2015),
    CinematicSeedExample(title: 'Ant-Man', isTv: false, universe: mcu, year: 2015),
    CinematicSeedExample(title: 'Captain America: Civil War', isTv: false, universe: mcu, year: 2016),
    CinematicSeedExample(title: 'Doctor Strange', isTv: false, universe: mcu, year: 2016),
    CinematicSeedExample(title: 'Spider-Man: Homecoming', isTv: false, universe: mcu, year: 2017),
    CinematicSeedExample(title: 'Guardians of the Galaxy Vol. 2', isTv: false, universe: mcu, year: 2017),
    CinematicSeedExample(title: 'Black Panther', isTv: false, universe: mcu, year: 2018),
    CinematicSeedExample(title: 'Avengers: Infinity War', isTv: false, universe: mcu, year: 2018),
    CinematicSeedExample(title: 'Ant-Man and the Wasp', isTv: false, universe: mcu, year: 2018),
    CinematicSeedExample(title: 'Captain Marvel', isTv: false, universe: mcu, year: 2019),
    CinematicSeedExample(title: 'Avengers: Endgame', isTv: false, universe: mcu, year: 2019),
    CinematicSeedExample(title: 'Spider-Man: Far From Home', isTv: false, universe: mcu, year: 2019),
    CinematicSeedExample(title: 'Black Widow', isTv: false, universe: mcu, year: 2021),
    CinematicSeedExample(title: 'Shang-Chi and the Legend of the Ten Rings', isTv: false, universe: mcu, year: 2021),
    CinematicSeedExample(title: 'Eternals', isTv: false, universe: mcu, year: 2021),
    CinematicSeedExample(title: 'Spider-Man: No Way Home', isTv: false, universe: mcu, year: 2021),
    CinematicSeedExample(title: 'Thor: Love and Thunder', isTv: false, universe: mcu, year: 2022),
    CinematicSeedExample(title: 'Black Panther: Wakanda Forever', isTv: false, universe: mcu, year: 2022),
    CinematicSeedExample(title: 'Guardians of the Galaxy Vol. 3', isTv: false, universe: mcu, year: 2023),
    CinematicSeedExample(title: 'The Marvels', isTv: false, universe: mcu, year: 2023),
    CinematicSeedExample(title: 'Deadpool & Wolverine', isTv: false, universe: mcu, year: 2024),
    CinematicSeedExample(title: 'Captain America: Brave New World', isTv: false, universe: mcu, year: 2025),
    CinematicSeedExample(title: 'Thunderbolts*', isTv: false, universe: mcu, year: 2025),
  ];

  static const List<CinematicSeedExample> shows = <CinematicSeedExample>[
    CinematicSeedExample(title: 'The Falcon and the Winter Soldier', isTv: true, universe: mcu, year: 2021),
    CinematicSeedExample(
      title: 'Spider-Noir',
      isTv: true,
      universe: spiderNoirContinuity,
      notes: 'Keep separate from the MCU until an authoritative continuity relationship is confirmed.',
    ),
  ];

  /// Extra catalog examples used by the regular Movies and TV browsing
  /// destinations. These are not considered a complete filmography.
  static const List<CinematicSeedExample> additionalMovies = <CinematicSeedExample>[
    CinematicSeedExample(title: 'How to Train Your Dragon', isTv: false, universe: 'How to Train Your Dragon', year: 2010),
    CinematicSeedExample(title: "Harry Potter and the Sorcerer's Stone", isTv: false, universe: 'Wizarding World', year: 2001),
    CinematicSeedExample(title: 'Harry Potter and the Chamber of Secrets', isTv: false, universe: 'Wizarding World', year: 2002),
    CinematicSeedExample(title: 'Harry Potter and the Prisoner of Azkaban', isTv: false, universe: 'Wizarding World', year: 2004),
    CinematicSeedExample(title: 'Harry Potter and the Goblet of Fire', isTv: false, universe: 'Wizarding World', year: 2005),
    CinematicSeedExample(title: 'Harry Potter and the Order of the Phoenix', isTv: false, universe: 'Wizarding World', year: 2007),
    CinematicSeedExample(title: 'Harry Potter and the Half-Blood Prince', isTv: false, universe: 'Wizarding World', year: 2009),
    CinematicSeedExample(title: 'Harry Potter and the Deathly Hallows: Part 1', isTv: false, universe: 'Wizarding World', year: 2010),
    CinematicSeedExample(title: 'Harry Potter and the Deathly Hallows: Part 2', isTv: false, universe: 'Wizarding World', year: 2011),
    CinematicSeedExample(title: 'The Incredibles', isTv: false, universe: 'Pixar', year: 2004),
    CinematicSeedExample(title: 'Finding Nemo', isTv: false, universe: 'Pixar', year: 2003),
  ];

  static const List<CinematicSeedExample> additionalShows = <CinematicSeedExample>[
    CinematicSeedExample(title: 'Wizards of Waverly Place', isTv: true, universe: 'Disney Channel', year: 2007),
    CinematicSeedExample(title: "That's So Random!", isTv: true, universe: 'Disney Channel', year: 2011),
    CinematicSeedExample(title: 'The Suite Life of Zack & Cody', isTv: true, universe: 'Disney Channel', year: 2005),
    CinematicSeedExample(title: 'American Dragon: Jake Long', isTv: true, universe: 'Disney Channel', year: 2005),
  ];

  static List<CinematicSeedExample> get all => <CinematicSeedExample>[
        ...movies,
        ...shows,
        ...additionalMovies,
        ...additionalShows,
      ];
}
