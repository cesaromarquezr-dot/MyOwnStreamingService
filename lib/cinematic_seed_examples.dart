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
    this.countryOfOrigin,
  });

  final String title;
  final bool isTv;
  final String universe;
  final int? year;
  final String? notes;
  final String? countryOfOrigin;
}

class CinematicSeedExamples {
  CinematicSeedExamples._();

  static const String mcu = 'Marvel Cinematic Universe';
  static const String spiderNoirContinuity =
      'Spider-Man / Marvel — separate continuity';

  /// Countries used by the explicitly curated international browse examples.
  /// These labels are also used to prioritize the entries in regular browse UI.
  static const Set<String> internationalCatalogCountries = <String>{
    'Mexico', 'South Korea', 'Spain', 'India', 'Japan', 'Brazil', 'Portugal',
    'Turkey', 'France', 'China', 'Germany', 'Argentina', 'Thailand',
    'Indonesia', 'Philippines', 'Iran', 'Egypt', 'South Africa',
  };

  static bool isInternationalExample(CinematicSeedExample example) =>
      internationalCatalogCountries.contains(example.universe);

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
    // International catalog examples are seeded into the normal browse catalog
    // so they appear on Home, Movies/Films, and title search—not only in tests.
    // Keep display titles in their intended original/localized form; never
    // silently translate these labels into English.
    CinematicSeedExample(title: 'Una película de huevos', isTv: false, universe: 'Mexico', year: 2006),
    CinematicSeedExample(title: 'Candidato Honesto', isTv: false, universe: 'Mexico', year: 2024),
    CinematicSeedExample(title: 'La leyenda de la Nahuala', isTv: false, universe: 'Mexico', year: 2007),
    CinematicSeedExample(title: '기생충', isTv: false, universe: 'South Korea', year: 2019),
    CinematicSeedExample(title: '부산행', isTv: false, universe: 'South Korea', year: 2016),
    CinematicSeedExample(title: 'El Chavo del Ocho', isTv: true, universe: 'Mexico', year: 1973),
    CinematicSeedExample(title: 'Una familia de diez', isTv: true, universe: 'Mexico', year: 2007),
    CinematicSeedExample(title: 'La familia P. Luche', isTv: true, universe: 'Mexico', year: 2002),
    CinematicSeedExample(title: 'Élite', isTv: true, universe: 'Spain', year: 2018),
    CinematicSeedExample(title: 'Dangal', isTv: false, universe: 'India', year: 2016),
    CinematicSeedExample(title: '3 Idiots', isTv: false, universe: 'India', year: 2009),
    CinematicSeedExample(title: 'RRR', isTv: false, universe: 'India', year: 2022),
    CinematicSeedExample(title: 'The Family Man', isTv: true, universe: 'India', year: 2019),
    CinematicSeedExample(title: 'Your Name', isTv: false, universe: 'Japan', year: 2016),
    CinematicSeedExample(title: 'Spirited Away', isTv: false, universe: 'Japan', year: 2001),
    CinematicSeedExample(title: 'Attack on Titan', isTv: true, universe: 'Japan', year: 2013),
    CinematicSeedExample(title: 'City of God', isTv: false, universe: 'Brazil', year: 2002),
    CinematicSeedExample(title: '3%', isTv: true, universe: 'Brazil', year: 2016),
    CinematicSeedExample(title: 'Glória', isTv: true, universe: 'Portugal', year: 2021),
    CinematicSeedExample(title: 'Miracle in Cell No. 7', isTv: false, universe: 'Turkey', year: 2019),
    CinematicSeedExample(title: 'Ethos', isTv: true, universe: 'Turkey', year: 2020),
    CinematicSeedExample(title: 'Amélie', isTv: false, universe: 'France', year: 2001),
    CinematicSeedExample(title: 'Lupin', isTv: true, universe: 'France', year: 2021),
    CinematicSeedExample(title: 'Wolf Warrior 2', isTv: false, universe: 'China', year: 2017),
    CinematicSeedExample(title: 'The Wandering Earth', isTv: false, universe: 'China', year: 2019),
    CinematicSeedExample(title: 'Dark', isTv: true, universe: 'Germany', year: 2017),
    CinematicSeedExample(title: 'La casa de papel', isTv: true, universe: 'Spain', year: 2017),
    CinematicSeedExample(title: 'Relatos salvajes', isTv: false, universe: 'Argentina', year: 2014),
    CinematicSeedExample(title: 'Bad Genius', isTv: false, universe: 'Thailand', year: 2017),
    CinematicSeedExample(title: 'The Raid', isTv: false, universe: 'Indonesia', year: 2011),
    CinematicSeedExample(title: 'Hello, Love, Goodbye', isTv: false, universe: 'Philippines', year: 2019),
    CinematicSeedExample(title: 'Trese', isTv: true, universe: 'Philippines', year: 2021),
    CinematicSeedExample(title: 'A Separation', isTv: false, universe: 'Iran', year: 2011),
    CinematicSeedExample(title: 'Finding Ola', isTv: true, universe: 'Egypt', year: 2022),
    CinematicSeedExample(title: 'Blood & Water', isTv: true, universe: 'South Africa', year: 2020),
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
    CinematicSeedExample(title: '오징어 게임', isTv: true, universe: 'South Korea', year: 2021),
    CinematicSeedExample(title: 'Wizards of Waverly Place', isTv: true, universe: 'Disney Channel', year: 2007),
    CinematicSeedExample(title: "That's So Random!", isTv: true, universe: 'Disney Channel', year: 2011),
    CinematicSeedExample(title: 'The Suite Life of Zack & Cody', isTv: true, universe: 'Disney Channel', year: 2005),
    CinematicSeedExample(title: 'American Dragon: Jake Long', isTv: true, universe: 'Disney Channel', year: 2005),
  ];


  /// Additional titles requested for the local browse catalog. These are
  /// metadata-only preview records: they are not playable until the user imports
  /// their own media. Provider IDs/artwork are resolved at runtime when configured.
  static const List<CinematicSeedExample> requestedMovies = <CinematicSeedExample>[
    CinematicSeedExample(title: 'Caramelo', isTv: false, universe: 'Brazil', year: 2025),
    CinematicSeedExample(title: 'Scary Movie', isTv: false, universe: 'Scary Movie', year: 2000, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Scary Movie', isTv: false, universe: 'Scary Movie', year: 2026, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Scary Movie 2', isTv: false, universe: 'Scary Movie', year: 2001, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Scary Movie 3', isTv: false, universe: 'Scary Movie', year: 2003, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Scary Movie 4', isTv: false, universe: 'Scary Movie', year: 2006, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Scary Movie 5', isTv: false, universe: 'Scary Movie', year: 2013, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'WALL-E', isTv: false, universe: 'Pixar', year: 2008, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Goosebumps', isTv: false, universe: 'Goosebumps', year: 2015, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Goosebumps 2: Haunted Halloween', isTv: false, universe: 'Goosebumps', year: 2018, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Ted', isTv: false, universe: 'Ted', year: 2012, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Ted 2', isTv: false, universe: 'Ted', year: 2015, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Back to the Future', isTv: false, universe: 'Back to the Future Trilogy', year: 1985, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Back to the Future Part II', isTv: false, universe: 'Back to the Future Trilogy', year: 1989, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Back to the Future Part III', isTv: false, universe: 'Back to the Future Trilogy', year: 1990, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Buddy', isTv: false, universe: 'Requested Movies', year: 2026, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Tusk', isTv: false, universe: 'Requested Movies', year: 2014, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Donnie Darko', isTv: false, universe: 'Requested Movies', year: 2001, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Bridge to Terabithia', isTv: false, universe: 'Requested Movies', year: 2007, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Nightmare Before Christmas', isTv: false, universe: 'Requested Movies', year: 1993, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Happy Death Day', isTv: false, universe: 'Happy Death Day', year: 2017, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Happy Death Day 2U', isTv: false, universe: 'Happy Death Day', year: 2019, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Ready or Not', isTv: false, universe: 'Ready or Not', year: 2019, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Ready or Not 2: Here I Come', isTv: false, universe: 'Ready or Not', year: 2026, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: "Willy's Wonderland", isTv: false, universe: 'Requested Movies', year: 2021, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Beetlejuice', isTv: false, universe: 'Beetlejuice', year: 1988, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Beetlejuice Beetlejuice', isTv: false, universe: 'Beetlejuice', year: 2024, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Corpse Bride', isTv: false, universe: 'Requested Movies', year: 2005, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Wizard of Oz', isTv: false, universe: 'Requested Movies', year: 1939, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: "Bill & Ted's Excellent Adventure", isTv: false, universe: 'Bill & Ted Trilogy', year: 1989, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: "Bill & Ted's Bogus Journey", isTv: false, universe: 'Bill & Ted Trilogy', year: 1991, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Bill & Ted Face the Music', isTv: false, universe: 'Bill & Ted Trilogy', year: 2020, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Just Go with It', isTv: false, universe: 'Requested Movies', year: 2011, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Shark Tale', isTv: false, universe: 'Requested Movies', year: 2004, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Happy Gilmore', isTv: false, universe: 'Happy Gilmore', year: 1996, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Spider-Man', isTv: false, universe: 'Spider-Man Films', year: 2002, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Spider-Man 2', isTv: false, universe: 'Spider-Man Films', year: 2004, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Spider-Man 3', isTv: false, universe: 'Spider-Man Films', year: 2007, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Amazing Spider-Man', isTv: false, universe: 'The Amazing Spider-Man', year: 2012, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Amazing Spider-Man 2', isTv: false, universe: 'The Amazing Spider-Man', year: 2014, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Daredevil', isTv: false, universe: 'Daredevil', year: 2003, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Jaws', isTv: false, universe: 'Jaws', year: 1975, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Addams Family', isTv: false, universe: 'The Addams Family', year: 1991, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Addams Family Values', isTv: false, universe: 'The Addams Family', year: 1993, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Banana Splits Movie', isTv: false, universe: 'Requested Movies', year: 2019, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Carrie', isTv: false, universe: 'Carrie', year: 1976, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Matilda', isTv: false, universe: 'Requested Movies', year: 1996, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Karate Kid', isTv: false, universe: 'The Karate Kid', year: 1984, countryOfOrigin: 'United States'),
  ];

  static const List<CinematicSeedExample> requestedShows = <CinematicSeedExample>[
    CinematicSeedExample(title: 'Friends', isTv: true, universe: 'Requested Shows', year: 1994, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'How I Met Your Mother', isTv: true, universe: 'Requested Shows', year: 2005, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Modern Family', isTv: true, universe: 'Requested Shows', year: 2009, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Brooklyn Nine-Nine', isTv: true, universe: 'Requested Shows', year: 2013, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Home Economics', isTv: true, universe: 'Requested Shows', year: 2021, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Muppets', isTv: true, universe: 'The Muppets', year: 2015, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Muppet Show', isTv: true, universe: 'The Muppets', year: 1976, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Shake It Up', isTv: true, universe: 'Disney Channel', year: 2010, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Euphoria', isTv: true, universe: 'Requested Shows', year: 2019, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'WandaVision', isTv: true, universe: 'Marvel Television', year: 2021, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Chopped', isTv: true, universe: 'Requested Shows', year: 2009, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Cutthroat Kitchen', isTv: true, universe: 'Requested Shows', year: 2013, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Loki', isTv: true, universe: 'Marvel Television', year: 2021, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Hawkeye', isTv: true, universe: 'Marvel Television', year: 2021, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Boys', isTv: true, universe: 'The Boys Universe', year: 2019, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Gen V', isTv: true, universe: 'The Boys Universe', year: 2023, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Goosebumps', isTv: true, universe: 'Goosebumps', year: 1995, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Goosebumps', isTv: true, universe: 'Goosebumps', year: 2023, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Ted', isTv: true, universe: 'Ted', year: 2024, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Spider-Man', isTv: true, universe: 'Spider-Man Animated Series', year: 1967, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Spider-Man', isTv: true, universe: 'Spider-Man Animated Series', year: 1981, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Spider-Man and His Amazing Friends', isTv: true, universe: 'Spider-Man Animated Series', year: 1981, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Spider-Man: The Animated Series', isTv: true, universe: 'Spider-Man Animated Series', year: 1994, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Spider-Man Unlimited', isTv: true, universe: 'Spider-Man Animated Series', year: 1999, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Spider-Man: The New Animated Series', isTv: true, universe: 'Spider-Man Animated Series', year: 2003, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Spectacular Spider-Man', isTv: true, universe: 'Spider-Man Animated Series', year: 2008, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Ultimate Spider-Man', isTv: true, universe: 'Spider-Man Animated Series', year: 2012, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Spider-Man', isTv: true, universe: 'Spider-Man Animated Series', year: 2017, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Your Friendly Neighborhood Spider-Man', isTv: true, universe: 'Marvel Animation', year: 2025, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Spidey and His Amazing Friends', isTv: true, universe: 'Marvel Animation', year: 2021, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Daredevil', isTv: true, universe: 'Marvel Television', year: 2015, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Jessica Jones', isTv: true, universe: 'Marvel Television', year: 2015, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Luke Cage', isTv: true, universe: 'Marvel Television', year: 2016, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Iron Fist', isTv: true, universe: 'Marvel Television', year: 2017, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Punisher', isTv: true, universe: 'Marvel Television', year: 2017, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Defenders', isTv: true, universe: 'Marvel Television', year: 2017, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Cloak & Dagger', isTv: true, universe: 'Marvel Television', year: 2018, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Runaways', isTv: true, universe: 'Marvel Television', year: 2017, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Wednesday', isTv: true, universe: 'The Addams Family', year: 2022, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Iron Man: Armored Adventures', isTv: true, universe: 'Marvel Animation', year: 2009, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'The Super Hero Squad Show', isTv: true, universe: 'Marvel Animation', year: 2009, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Ben 10', isTv: true, universe: 'Ben 10', year: 2005, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Ben 10: Alien Force', isTv: true, universe: 'Ben 10', year: 2008, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Ben 10: Ultimate Alien', isTv: true, universe: 'Ben 10', year: 2010, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Ben 10: Omniverse', isTv: true, universe: 'Ben 10', year: 2012, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Danny Phantom', isTv: true, universe: 'Requested Shows', year: 2004, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'La CQ', isTv: true, universe: 'Requested Shows', year: 2012, countryOfOrigin: 'Mexico'),
    CinematicSeedExample(title: 'The Amazing World of Gumball', isTv: true, universe: 'Requested Shows', year: 2011, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Courage the Cowardly Dog', isTv: true, universe: 'Requested Shows', year: 1999, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'Codename: Kids Next Door', isTv: true, universe: 'Requested Shows', year: 2002, countryOfOrigin: 'United States'),
    CinematicSeedExample(title: 'El Chavo Animado', isTv: true, universe: 'Mexico', year: 2006),
  ];

  static List<CinematicSeedExample> get all => <CinematicSeedExample>[
        ...movies,
        ...shows,
        ...additionalMovies,
        ...additionalShows,
        ...requestedMovies,
        ...requestedShows,
      ];
}
