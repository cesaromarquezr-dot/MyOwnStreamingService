/// Browseable genre taxonomy shared by discovery, search, and the Top 10 UI.
///
/// The lists intentionally separate film/television from music. Providers may
/// use fewer canonical IDs than this vocabulary; imported library metadata can
/// still be indexed and filtered by these descriptive genre and subgenre tags.
class GenreCatalogGroup {
  const GenreCatalogGroup(this.name, this.genres);

  final String name;
  final List<String> genres;
}

abstract final class MediaGenreCatalog {
  static const List<GenreCatalogGroup> movieGroups = <GenreCatalogGroup>[
    GenreCatalogGroup('Action & Adventure', <String>[
      'Action', 'Adventure', 'Martial Arts', 'Disaster', 'Swashbuckler',
      'Espionage', 'Superhero', 'Survival', 'War Adventure', 'Chase Film',
      'Caper', 'Heist', 'Sword and Sorcery',
    ]),
    GenreCatalogGroup('Comedy', <String>[
      'Comedy', 'Satire', 'Screwball Comedy', 'Slapstick', 'Black Comedy',
      'Dark Comedy', 'Parody', 'Farce', 'Mockumentary', 'Horror-Comedy',
      'Romantic Comedy', 'Teen Comedy', 'Workplace Comedy',
    ]),
    GenreCatalogGroup('Crime', <String>[
      'Crime', 'Gangster', 'Heist', 'Police Procedural', 'Detective',
      'Organized Crime', 'Legal Crime', 'True Crime', 'Neo-Noir',
    ]),
    GenreCatalogGroup('Drama', <String>[
      'Drama', 'Courtroom Drama', 'Political Drama', 'Family Drama',
      'Coming-of-Age', 'Historical Drama', 'Melodrama', 'Psychological Drama',
      'Medical Drama', 'Social Drama', 'Sports Drama', 'Tragedy',
    ]),
    GenreCatalogGroup('Fantasy', <String>[
      'Fantasy', 'High Fantasy', 'Urban Fantasy', 'Dark Fantasy',
      'Sword and Sorcery', 'Fairy Tale', 'Mythic Fantasy', 'Magical Realism',
    ]),
    GenreCatalogGroup('Horror', <String>[
      'Horror', 'Folk Horror', 'Slasher', 'Supernatural Horror',
      'Psychological Horror', 'Body Horror', 'Cosmic Horror',
      'Found Footage', 'Creature Feature', 'Zombie', 'Vampire',
      'Haunted House', 'Gothic Horror', 'Survival Horror', 'Eco-Horror',
    ]),
    GenreCatalogGroup('Musical', <String>[
      'Musical', 'Jukebox Musical', 'Backstage Musical', 'Film Musical',
      'Dance Musical', 'Concert Film',
    ]),
    GenreCatalogGroup('Mystery', <String>[
      'Mystery', 'Detective Mystery', 'Whodunit', 'Cozy Mystery',
      'Locked-Room Mystery', 'Mystery Thriller',
    ]),
    GenreCatalogGroup('Romance', <String>[
      'Romance', 'Romantic Drama', 'Historical Romance', 'Romantic Comedy',
      'Romantic Thriller', 'Period Romance', 'Tragic Romance',
    ]),
    GenreCatalogGroup('Science Fiction', <String>[
      'Science Fiction', 'Space Opera', 'Cyberpunk', 'Dystopian',
      'Post-Apocalyptic', 'Time Travel', 'First Contact', 'Alien Invasion',
      'Techno-Thriller', 'Military Science Fiction', 'Biopunk',
    ]),
    GenreCatalogGroup('Thriller', <String>[
      'Thriller', 'Psychological Thriller', 'Political Thriller',
      'Techno-Thriller', 'Action Thriller', 'Crime Thriller',
      'Romantic Thriller', 'Conspiracy Thriller', 'Survival Thriller',
      'Legal Thriller', 'Spy Thriller',
    ]),
    GenreCatalogGroup('Western', <String>[
      'Western', 'Spaghetti Western', 'Revisionist Western',
      'Contemporary Western', 'Acid Western', 'Northern', 'Ostern',
    ]),
    GenreCatalogGroup('Documentary & Other', <String>[
      'Documentary', 'Biography', 'Historical', 'Sports', 'Experimental',
      'Animation', 'Family', 'Road Movie', 'Film Noir', 'Short Film',
      'Interactive Film', 'Climate Fiction',
    ]),
    GenreCatalogGroup('Hybrid & Emerging', <String>[
      'Horror-Comedy', 'Romantic Thriller', 'Action Horror', 'Action Thriller',
      'Sci-Fi Horror', 'Fantasy Adventure', 'Crime Thriller',
      'Mystery Thriller', 'Romantic Drama', 'Sci-Fi Action', 'Sci-Fi Adventure',
      'Eco-Horror', 'Climate Fiction',
    ]),
  ];

  static const List<GenreCatalogGroup> showGroups = <GenreCatalogGroup>[
    ...movieGroups,
    GenreCatalogGroup('Television Formats', <String>[
      'Crime Series', 'Limited Series', 'Miniseries', 'Anthology Series',
      'Procedural', 'Serial Drama', 'Soap Opera', 'Telenovela', 'Sitcom',
      'Sketch Comedy', 'Reality', 'Competition', 'Docuseries', 'Talk Show',
      'Variety Show', 'News', 'Kids', 'Educational', 'Anime',
    ]),
  ];

  static const List<GenreCatalogGroup> musicGroups = <GenreCatalogGroup>[
    GenreCatalogGroup('Alternative', <String>[
      'Art Punk', 'Alternative Rock', 'Britpunk', 'College Rock',
      'Crossover Thrash', 'Crust Punk', 'Emotional Hardcore', 'Emo',
      'Experimental Rock', 'Folk Punk', 'Gothic Rock', 'Grunge',
      'Hardcore Punk', 'Hard Rock', 'Indie Rock', 'Lo-fi', 'Musique Concrète',
      'New Wave', 'Progressive Rock', 'Punk', 'Shoegaze', 'Steampunk',
    ]),
    GenreCatalogGroup('Anime & Asian Pop', <String>[
      'Anime', 'Anison', 'J-Pop', 'J-Rock', 'J-Synth', 'J-Ska', 'J-Punk',
      'K-Pop', 'C-Pop', 'Cantopop', 'Mandopop', 'T-Pop', 'Enka',
      'Kayokyoku', 'City Pop', 'Taiwanese Pop', 'Pinoy Pop',
    ]),
    GenreCatalogGroup('Blues', <String>[
      'Acoustic Blues', 'African Blues', 'Blues Rock', 'Blues Shouter',
      'British Blues', 'Canadian Blues', 'Chicago Blues', 'Classic Blues',
      'Classic Female Blues', 'Contemporary Blues', 'Contemporary R&B',
      'Country Blues', 'Dark Blues', 'Delta Blues', 'Detroit Blues',
      'Doom Blues', 'Electric Blues', 'Folk Blues', 'Gospel Blues',
      'Harmonica Blues', 'Hill Country Blues', 'Hokum Blues', 'Jazz Blues',
      'Jump Blues', 'Kansas City Blues', 'Louisiana Blues', 'Memphis Blues',
      'Modern Blues', 'New Orleans Blues', 'Piano Blues', 'Piedmont Blues',
      'Punk Blues', 'Ragtime Blues', 'Rhythm Blues', 'Soul Blues',
      'St. Louis Blues', 'Swamp Blues', 'Texas Blues', 'Urban Blues',
      'Vandeville', 'West Coast Blues', 'Zydeco',
    ]),
    GenreCatalogGroup('Children, Comedy & Spoken Word', <String>[
      'Children’s Music', 'Lullabies', 'Sing-Along', 'Stories', 'Comedy',
      'Novelty', 'Parody Music', 'Stand-up Comedy', 'Vaudeville',
      'Spoken Word', 'Poetry', 'Storytelling', 'Karaoke',
    ]),
    GenreCatalogGroup('Classical & Opera', <String>[
      'Avant-Garde Classical', 'Ballet', 'Baroque', 'Cantata', 'Chamber Music',
      'String Quartet', 'Chant', 'Choral', 'Classical Crossover', 'Concerto',
      'Concerto Grosso', 'Contemporary Classical', 'Early Music',
      'Expressionist', 'High Classical', 'Impressionist', 'Mass Requiem',
      'Medieval', 'Minimalism', 'Modern Composition', 'Modern Classical',
      'Avant-Garde', 'Chamber Music', 'Contemporary Classical',
      'Opera', 'Oratorio', 'Orchestral', 'Renaissance', 'Romantic Classical',
      'Sonata', 'Symphonic', 'Symphony', 'Twelve-tone', 'Wedding Music',
    ]),
    GenreCatalogGroup('Country & Americana', <String>[
      'Alternative Country', 'Americana', 'Australian Country',
      'Bakersfield Sound', 'Bluegrass', 'Progressive Bluegrass',
      'Traditional Bluegrass', 'Blues Country', 'Cajun', 'Christian Country',
      'Classic Country', 'Contemporary Country', 'Country Gospel',
      'Country Pop', 'Country Rap', 'Country Rock', 'Country Soul',
      'Cowboy Western', 'Cowpunk', 'Honky Tonk', 'Instrumental Country',
      'Nashville Sound', 'Neotraditional Country', 'Outlaw Country',
      'Red Dirt', 'Sertanejo', 'Texas Country', 'Traditional Country',
      'Western Swing', 'Close Harmony', 'Cowboy / Western', 'Dansband',
      'Franco-Country', 'Gulf and Western', 'Hellbilly', 'Lubbock Sound',
      'Neotraditional Country', 'Truck-Driving Country', 'Urban Cowboy',
    ]),
    GenreCatalogGroup('Dance & EDM', <String>[
      'Club Dance', 'Breakcore', 'Breakbeat', 'Breakstep', '4-Beat',
      'Acid Breaks', 'Baltimore Club', 'Big Beat', 'Florida Breaks',
      'Nu Skool Breaks', 'Broken Beat', 'Brostep', 'Chillstep', 'Deep House',
      'Dubstep', 'Electroswing', 'Exercise Dance', 'Glitch Hop',
      'Electro House', 'Future Garage', 'Garage', 'Glitch Hop',
      'Glitch Pop', 'Grime', 'Hard Dance', 'Hardcore', 'Happy Hardcore',
      'Hardstyle', 'Jumpstyle', 'Gabber', 'Speedcore', 'Terrorcore',
      'Digital Hardcore', 'Doomcore', 'Hi-NRG', 'Eurodance', 'House', 'Acid House',
      'Chicago House', 'Diva House', 'Dutch House', 'Freestyle House',
      'French House', 'Hardbag', 'Italo House', 'Jackin House',
      'Funky House', 'Ghetto House', 'Hip House', 'Italo House', 'Latin House',
      'Minimal House', 'Progressive House', 'Tech House', 'Tribal House',
      'Tropical House', 'Jungle', 'Drum and Bass', 'Liquid Funk', 'Neurofunk',
      'Techno', 'Acid Techno', 'Detroit Techno', 'Minimal Techno', 'Trance',
      'Acid Trance', 'Classic Trance', 'Dark Psy', 'Dream Trance', 'Goa Trance',
      'Psy-Trance', 'Hard Trance', 'Progressive Trance', 'Tech Trance',
      'Uplifting Trance', 'Orchestral Uplifting', 'Vocal Trance', 'Trap',
    ]),
    GenreCatalogGroup('Electronic & Experimental', <String>[
      'Ambient', 'Ambient Dub', 'Ambient House', 'Ambient Techno',
      'Dark Ambient', 'Drone Music', 'Illbient', 'Isolationism', 'Lowercase',
      'Asian Underground', 'Bassline', 'Chillwave', 'Chiptune', '8-bit',
      'Bitpop', 'Game Boy', 'Nintendocore', 'Yorkshire Bleeps and Bass',
      'Video Game Music', 'Downtempo', 'Acid Jazz', 'Balearic Beat',
      'Chill Out', 'Dub Music', 'Dubtronica', 'Ethnic Electronica',
      'Moombahton', 'Nu Jazz',
      'Trip Hop', 'Electro', 'Electropop', 'Electroacoustic', 'Electronica',
      'Berlin School', 'Folktronica', 'Freestyle Music', 'Glitch', 'IDM',
      'Laptronica', 'Skweee', 'Synthcore', 'Electronic Rock', 'Dance-Punk',
      'Dance-Rock', 'Dark Wave', 'Electroclash', 'Electropunk', 'Indietronica',
      'Synthpop', 'Synthpunk', 'Space Rock', 'New Rave', 'Eurobeat',
      'Bubblegum Dance', 'Italo Dance', 'Turbofolk', 'Industrial',
      'Vaporwave', 'Hypnagogic Pop', 'Mallsoft', 'Vaportrap', 'Vaporhop',
      'UK Garage', '2-Step', '4x4', 'Speed Garage',
    ]),
    GenreCatalogGroup('Folk & Regional', <String>[
      'American Folk Revival', 'Anti-Folk', 'British Folk Revival',
      'Contemporary Folk', 'Filk Music', 'Freak Folk', 'Indie Folk',
      'Industrial Folk', 'Neofolk', 'Progressive Folk', 'Psychedelic Folk',
      'Singer/Songwriter', 'German Folk', 'French Pop', 'German Pop', 'Enka',
      'Fado', 'Celtic', 'Celtic Folk', 'Polka', 'Klezmer', 'Dangdut',
      'Bhangra', 'Filmi', 'Indian Pop', 'Hindustani', 'Carnatic',
      'Baithak Gana', 'Bhojpuri', 'Indian Ghazal', 'Lavani', 'Luk Thung',
      'Luk Krung', 'Manila Sound', 'Morlam', 'Pop Sunda', 'Ragini',
      'Thai Pop', 'Morna', 'Sega', 'Seggae', 'Calypso', 'Soca',
    ]),
    GenreCatalogGroup('Hip-Hop & Rap', <String>[
      'Alternative Rap', 'Avant-Garde Hip-Hop', 'Bounce', 'Chap Hop',
      'Christian Hip-Hop', 'Conscious Hip-Hop', 'Country Rap', 'Crunk',
      'Crunkcore', 'Cumbia Rap', 'Dirty South', 'East Coast Hip-Hop',
      'Hardcore Hip-Hop', 'Mafioso Rap', 'Freestyle Rap', 'G-Funk',
      'Gangsta Rap', 'Golden Age Hip-Hop', 'Grime', 'Hardcore Rap',
      'Hip-Hop', 'Hip Pop', 'Horrorcore', 'Hyphy', 'Industrial Hip-Hop',
      'Motswako', 'Chicago Hip-Hop', 'Detroit Hip-Hop', 'St. Louis Hip-Hop',
      'Twin Cities Hip-Hop', 'New Jersey Hip-Hop',
      'Instrumental Hip-Hop', 'Jazz Rap', 'Latin Rap', 'Low Bap',
      'Lyrical Hip-Hop', 'Merenrap', 'Midwest Hip-Hop', 'Nerdcore',
      'New Jack Swing', 'New School Rap', 'Old School Rap', 'Trap',
      'Turntablism', 'Underground Rap', 'West Coast Rap', 'Drill', 'UK Drill',
    ]),
    GenreCatalogGroup('Jazz', <String>[
      'Acid Jazz', 'Afro-Cuban Jazz', 'Avant-Garde Jazz', 'Bebop', 'Big Band',
      'Blue Note', 'Cape Jazz', 'Chamber Jazz', 'Contemporary Jazz',
      'Cool Jazz', 'Crossover Jazz', 'Continental Jazz', 'Dark Jazz',
      'Dixieland', 'Early Jazz', 'British Dance Band Jazz',
      'Electro Swing', 'Ethio-jazz', 'Ethno-Jazz', 'European Free Jazz',
      'Free Jazz', 'Fusion', 'Gypsy Jazz', 'Hard Bop', 'Indo Jazz',
      'Jazz Blues', 'Jazz-Funk', 'Jazz Fusion', 'Jazz Rap', 'Jazz Rock',
      'Kansas City Jazz', 'Latin Jazz', 'M-Base Jazz', 'Modal Jazz',
      'Neo-Bop', 'Neo-Swing', 'Nu Jazz', 'Orchestral Jazz', 'Post-Bop',
      'Punk Jazz', 'Ragtime', 'Ska Jazz', 'Skiffle', 'Smooth Jazz',
      'Soul Jazz', 'Swing Jazz', 'Straight-Ahead Jazz', 'Trad Jazz',
      'Third Stream', 'West Coast Jazz',
    ]),
    GenreCatalogGroup('Latin & Caribbean', <String>[
      'Alternativo Rock Latino', 'Argentine Tango', 'Bachata', 'Baithak Gana',
      'Baladas y Boleros', 'Bolero', 'Bossa Nova', 'Axé', 'Brazilian Rock',
      'Brega', 'Choro', 'Forró', 'Frevo', 'Funk Carioca', 'Lambada',
      'Maracatu', 'MPB', 'Pagode', 'Samba', 'Samba Rock', 'Tecnobrega',
      'Tropicalia', 'Chicha', 'Criolla', 'Contemporary Latin', 'Cumbia',
      'Flamenco', 'Huayno', 'Joropo', 'Mambo', 'Mariachi', 'Merengue',
      'Nuevo Flamenco', 'Pop Latino', 'Portuguese Fado', 'Punta', 'Punta Rock',
      'Ranchera', 'Regional Mexicano', 'Reggaeton', 'Salsa', 'Soca', 'Son',
      'Baile Funk', 'Zouk-Lambada', 'Merengue Típico', 'Timba',
      'Tejano', 'Timba', 'Vallenato', 'Zouk',
    ]),
    GenreCatalogGroup('Metal', <String>[
      'Heavy Metal', 'Speed Metal', 'Thrash Metal', 'Power Metal', 'Death Metal',
      'Black Metal', 'Pagan Metal', 'Viking Metal', 'Folk Metal',
      'Symphonic Metal', 'Gothic Metal', 'Glam Metal', 'Hair Metal',
      'Doom Metal', 'Groove Metal', 'Industrial Metal', 'Modern Metal',
      'Neoclassical Metal', 'New Wave of British Heavy Metal', 'Post-Metal',
      'Progressive Metal', 'Avant-Garde Metal', 'Sludge Metal', 'Djent',
      'Drone Metal', 'Kawaii Metal', 'Pirate Metal', 'Nu Metal', 'Math Metal',
      'Grindcore', 'Hardcore', 'Metalcore', 'Deathcore', 'Post-Hardcore',
      'Mathcore',
    ]),
    GenreCatalogGroup('Pop', <String>[
      'Adult Contemporary', 'Arab Pop', 'Baroque Pop', 'Britpop',
      'Bubblegum Pop', 'Chamber Pop', 'Chanson', 'Christian Pop',
      'Classical Crossover', 'Europop', 'Balkan Pop', 'French Pop',
      'Latin Pop', 'Russian Pop', 'Dance Pop', 'Dream Pop', 'Electro Pop',
      'Iranian Pop', 'Jangle Pop', 'Latin Ballad', 'Mexican Pop',
      'New Romanticism', 'Orchestral Pop', 'Pop Rap', 'Popera', 'Pop/Rock',
      'Pop Punk', 'Power Pop', 'Psychedelic Pop', 'Schlager', 'Soft Rock',
      'Sophisti-Pop', 'Space Age Pop', 'Sunshine Pop', 'Surf Pop',
      'Synthpop', 'Teen Pop', 'Traditional Pop', 'Turkish Pop', 'Wonky Pop',
    ]),
    GenreCatalogGroup('R&B, Soul, Funk & Disco', <String>[
      'Contemporary R&B', 'Disco', 'Doo Wop', 'Funk', 'Modern Soul', 'Motown',
      'Neo-Soul', 'Northern Soul', 'Psychedelic Soul', 'Quiet Storm',
      'Soul', 'Southern Soul', 'Beach Music', 'Boogie', 'Post-Disco',
      'Dance-pop',
    ]),
    GenreCatalogGroup('Reggae & Ska', <String>[
      '2-Tone', 'Dub', 'Roots Reggae', 'Reggae Fusion', 'Reggae en Español',
      'Spanish Reggae', 'Lovers Rock', 'Raggamuffin', 'Ragga', 'Dancehall',
      'Ska', 'Rocksteady',
    ]),
    GenreCatalogGroup('Rock', <String>[
      'Acid Rock', 'Adult-Oriented Rock', 'Afro Punk', 'Adult Alternative',
      'Alternative Rock', 'American Traditional Rock', 'Anatolian Rock',
      'Arena Rock', 'Art Rock', 'Blues-Rock', 'British Invasion', 'Glam Rock',
      'Gothic Rock', 'Grindcore', 'Jam Bands', 'Post Punk', 'Post Rock',
      'Prog-Rock', 'Psychedelic Rock', 'Rock & Roll', 'Rockabilly',
      'Roots Rock', 'Southern Rock', 'Surf Rock', 'Tex-Mex', 'Yacht Rock',
      'Singer-Songwriter',
    ]),
    GenreCatalogGroup('Soundtrack, Vocal & Other', <String>[
      'Movie Soundtrack', 'Original Score', 'TV Soundtrack', 'Musicals',
      'A Cappella', 'Barbershop', 'Gregorian Chant', 'Vocal Jazz',
      'Vocal Pop', 'Yodel', 'New Age', 'Meditation', 'Relaxation',
      'Fitness & Workout', 'Holiday', 'Christmas', 'Disney', 'Instrumental',
      'Worldbeat', 'Afrobeat', 'Afro-House', 'Afro-Pop', 'Afro-Beat',
      'African Hip-Hop', 'African Heavy Metal', 'Apala', 'Benga', 'Bikutsi',
      'Bongo Flava', 'Coupé-Décalé', 'Fuji Music', 'Genge', 'Gnawa',
      'Highlife', 'Hiplife', 'Isicathamiya', 'Jit', 'Jùjú', 'Kapuka',
      'Kizomba', 'Kuduro', 'Kwaito', 'Kwela', 'Lingala', 'Makossa',
      'Maloya', 'Marrabenta', 'Mbalax', 'Mbaqanga', 'Mbube', 'Morna',
      'Museve', 'Negro Spiritual', 'Palm-Wine', 'Raï', 'Sakara', 'Sega',
      'Seggae', 'Semba', 'Soukous', 'Taarab', 'Zouglou',
    ]),
    GenreCatalogGroup('Hybrid & Emerging', <String>[
      'Corridos Tumbados', 'Amapiano', 'UK Drill', 'Hyperpop', 'Lo-fi Hip-Hop',
      'Electro Swing', 'Rock and Roll', 'Jazz Fusion', 'Country Rap',
      'Botanica', 'Jerk', 'Cloud Rap', 'Brazilian Phonk', 'Pluggnb', 'Nu-gaze',
      'Latin Trap', 'Mariachi Trap', 'Afrobeats', 'Afrobeats-R&B',
      'Pop-Punk Rap', 'Phonk', 'Drill and Bass', 'Folktronica',
    ]),
  ];

  static List<GenreCatalogGroup> groupsFor(String medium) => switch (medium) {
        'Shows' => showGroups,
        'Music' => musicGroups,
        _ => movieGroups,
      };

  static List<String> get musicGenreTerms => <String>{
        for (final group in musicGroups) group.name,
        for (final group in musicGroups) ...group.genres,
      }.toList(growable: false);

  static List<String> get filmGenreTerms => <String>{
        for (final group in movieGroups) group.name,
        for (final group in movieGroups) ...group.genres,
      }.toList(growable: false);
}
