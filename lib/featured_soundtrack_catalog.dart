/// Source-backed song-to-film/TV relationships displayed on Details pages.
///
/// The catalogue deliberately distinguishes songs used in the picture from
/// tracks listed on an official soundtrack album. A relationship is shown only
/// when a named soundtrack source is attached to the record; title similarity
/// is never used to infer that a song appeared in a film or episode.
enum FeaturedSoundtrackKind {
  featuredSong,
  officialSoundtrackAlbum,
  originalScore,
}

class GeneratedSoundtrackCollection {
  const GeneratedSoundtrackCollection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.collectionType,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<FeaturedSoundtrackEntry> entries;
  final String collectionType;
}

class FeaturedSoundtrackEntry {
  const FeaturedSoundtrackEntry({
    required this.key,
    required this.title,
    required this.artist,
    required this.mediaTitles,
    required this.sourceName,
    required this.sourceUrl,
    this.album = '',
    this.relationshipLabel = 'In-film placement',
    this.kind = FeaturedSoundtrackKind.featuredSong,
    this.isCoverOrAlternateVersion = false,
    this.placementNote,
    this.sceneStart,
    this.sceneEnd,
    this.artistAliases = const <String>[],
    this.creditedArtists = const <String>[],
    this.titleAliases = const <String>[],
    this.mediaTitleAliases = const <String>[],
  });

  final String key;
  final String title;
  final String artist;
  final String album;
  final List<String> mediaTitles;
  final String sourceName;
  final String sourceUrl;
  final String relationshipLabel;
  final FeaturedSoundtrackKind kind;
  final bool isCoverOrAlternateVersion;
  final String? placementNote;
  /// Optional, source-backed placement timing. Null means no reliable timecode.
  final Duration? sceneStart;
  final Duration? sceneEnd;
  final List<String> artistAliases;
  /// Individually credited performers for collaborations; the display artist
  /// string remains intact for source-faithful presentation.
  final List<String> creditedArtists;
  final List<String> titleAliases;
  final List<String> mediaTitleAliases;

  List<String> get allCreditedArtists => <String>{
        ...(creditedArtists.isEmpty ? <String>[artist] : creditedArtists),
      }.where((name) => name.trim().isNotEmpty).toList(growable: false);

  static String normalize(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  bool matchesQuery(String query) {
    final needle = normalize(query);
    if (needle.isEmpty) return false;
    if (const <String>['spiderman', 'spidey', 'peterparker'].contains(needle)) {
      return <String>{...mediaTitles, ...mediaTitleAliases}
          .map(normalize)
          .any((value) => value.contains('spider'));
    }
    final searchable = <String>{
      title,
      artist,
      album,
      ...mediaTitles,
      ...artistAliases,
      ...creditedArtists,
      ...titleAliases,
      ...mediaTitleAliases,
    }.map(normalize).where((value) => value.isNotEmpty);
    return searchable.any((value) =>
        value.contains(needle) || (needle.length >= 4 && needle.contains(value)));
  }

  bool matchesMediaTitle(String rawTitle) {
    final needle = normalize(rawTitle);
    if (needle.isEmpty) return false;
    final candidates = <String>{...mediaTitles, ...mediaTitleAliases}
        .map(normalize)
        .where((value) => value.isNotEmpty);
    return candidates.any((value) {
      if (value == needle) return true;
      if (!needle.startsWith(value)) return false;
      final suffix = needle.substring(value.length);
      return RegExp(r'^(18|19|20)\d{2}$').hasMatch(suffix);
    });
  }
}

class FeaturedSoundtrackCatalog {
  FeaturedSoundtrackCatalog._();

  static const List<FeaturedSoundtrackEntry> entries =
      <FeaturedSoundtrackEntry>[
    // Marvel / Iron Man
    FeaturedSoundtrackEntry(
      key: 'iron-man-back-in-black',
      title: 'Back in Black',
      artist: 'AC/DC',
      album: 'Back in Black',
      mediaTitles: <String>['Iron Man'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt0371746/soundtrack/',
      placementNote: 'Used in the film’s opening sequence.',
    ),
    FeaturedSoundtrackEntry(
      key: 'iron-man-2-shoot-to-thrill',
      title: 'Shoot to Thrill',
      artist: 'AC/DC',
      album: 'Back in Black',
      mediaTitles: <String>['Iron Man 2'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt1228705/soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'thor-ragnarok-immigrant-song',
      title: 'Immigrant Song',
      artist: 'Led Zeppelin',
      album: 'Led Zeppelin III',
      mediaTitles: <String>['Thor: Ragnarok'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt3501632/soundtrack/',
      placementNote: 'Featured in the film’s action sequences.',
    ),
    FeaturedSoundtrackEntry(
      key: 'thor-love-and-thunder-welcome-to-the-jungle',
      title: 'Welcome to the Jungle',
      artist: "Guns N' Roses",
      album: 'Appetite for Destruction',
      mediaTitles: <String>['Thor: Love and Thunder'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt10648342/soundtrack/',
      placementNote: 'Plays during the first fight with the Guardians of the Galaxy.',
    ),
    FeaturedSoundtrackEntry(
      key: 'black-widow-smells-like-teen-spirit',
      title: 'Smells Like Teen Spirit',
      artist: 'Think Up Anger feat. Malia J',
      creditedArtists: <String>['Think Up Anger', 'Malia J'],
      album: '',
      mediaTitles: <String>['Black Widow'],
      artistAliases: <String>['Malia J', 'Nirvana'],
      sourceName: 'IMDb / WhatSong soundtrack credits',
      sourceUrl: 'https://www.whatsong.org/movie/black-widow',
      isCoverOrAlternateVersion: true,
      placementNote: 'Opening-credits cover version; performed by Think Up Anger featuring Malia J, not the original Nirvana recording.',
    ),
    FeaturedSoundtrackEntry(
      key: 'black-panther-pray-for-me',
      title: 'Pray for Me',
      artist: 'The Weeknd & Kendrick Lamar',
      creditedArtists: <String>['The Weeknd', 'Kendrick Lamar'],
      album: 'Black Panther: The Album',
      mediaTitles: <String>['Black Panther'],
      titleAliases: <String>['Prey for Me'],
      sourceName: 'WhatSong soundtrack guide',
      sourceUrl: 'https://www.whatsong.org/movie/black-panther',
      placementNote: 'Plays as T’Challa, Okoye and Nakia enter the Busan casino.',
    ),
    FeaturedSoundtrackEntry(
      key: 'black-panther-all-the-stars',
      title: 'All the Stars',
      artist: 'Kendrick Lamar & SZA',
      creditedArtists: <String>['Kendrick Lamar', 'SZA'],
      album: 'Black Panther: The Album',
      mediaTitles: <String>['Black Panther'],
      sourceName: 'WhatSong soundtrack guide',
      sourceUrl: 'https://www.whatsong.org/movie/black-panther',
      placementNote: 'Featured in the end credits.',
    ),
    FeaturedSoundtrackEntry(
      key: 'civil-war-left-hand-free',
      title: 'Left Hand Free',
      artist: 'alt-J',
      album: 'This Is All Yours',
      mediaTitles: <String>['Captain America: Civil War'],
      mediaTitleAliases: <String>['Captain America Civil War'],
      sourceName: 'IMDb / WhatSong soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt3498820/soundtrack/',
      placementNote: 'Introduces Peter Parker / Spider-Man and returns during the end credits. This song is from Captain America: Civil War, not Spider-Man: Homecoming.',
    ),
    FeaturedSoundtrackEntry(
      key: 'spider-man-homecoming-blitzkrieg-bop',
      title: 'Blitzkrieg Bop',
      artist: 'Ramones',
      album: 'Ramones',
      mediaTitles: <String>['Spider-Man: Homecoming'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt2250912/soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'guardians-come-and-get-your-love',
      title: 'Come and Get Your Love',
      artist: 'Redbone',
      album: 'Wovoka',
      mediaTitles: <String>['Guardians of the Galaxy', 'Avengers: Endgame'],
      sourceName: 'IMDb / Marvel official soundtrack list',
      sourceUrl: 'https://www.marvel.com/articles/movies/avengers-endgame-every-single-song-and-theme-in-the-film',
      placementNote: 'Peter Quill’s opening sequence in Guardians of the Galaxy; also appears in the official Avengers: Endgame song list.',
    ),
    FeaturedSoundtrackEntry(
      key: 'guardians-escape-pina-colada',
      title: 'Escape (The Piña Colada Song)',
      artist: 'Rupert Holmes',
      album: 'Partners in Crime',
      mediaTitles: <String>['Guardians of the Galaxy'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt2015381/soundtrack/',
      placementNote: 'Plays as the Guardians escape the Kyln prison.',
    ),
    FeaturedSoundtrackEntry(
      key: 'guardians-fooled-around',
      title: 'Fooled Around and Fell in Love',
      artist: 'Elvin Bishop',
      album: 'Struttin’ My Stuff',
      mediaTitles: <String>['Guardians of the Galaxy'],
      titleAliases: <String>['Fool Around in Love'],
      sourceName: 'IMDb / WhatSong soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt2015381/soundtrack/',
      placementNote: 'Plays during the dance between Gamora and Peter Quill.',
    ),
    FeaturedSoundtrackEntry(
      key: 'deadpool-wolverine-bye-bye-bye',
      title: 'Bye Bye Bye',
      artist: '*NSYNC',
      album: 'No Strings Attached',
      mediaTitles: <String>['Deadpool & Wolverine'],
      mediaTitleAliases: <String>['Deadpool and Wolverine'],
      sourceName: 'IMDb / Radio Times soundtrack credits',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/deadpool-3-wolverine-soundtrack-all-songs/',
      placementNote: 'Accompanies the opening fight sequence.',
    ),
    FeaturedSoundtrackEntry(
      key: 'back-to-the-future-power-of-love',
      title: 'The Power of Love',
      artist: 'Huey Lewis & The News',
      album: 'Fore!',
      mediaTitles: <String>['Back to the Future'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt0088763/soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'brave-new-world-i-kendrick-lamar',
      title: 'i',
      artist: 'Kendrick Lamar',
      album: 'To Pimp a Butterfly',
      mediaTitles: <String>['Captain America: Brave New World'],
      mediaTitleAliases: <String>['Captain America Brave New World'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt14513804/soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'captain-marvel-just-a-girl',
      title: 'Just a Girl',
      artist: 'No Doubt',
      album: 'Tragic Kingdom',
      mediaTitles: <String>['Captain Marvel'],
      sourceName: 'Marvel official soundtrack guide',
      sourceUrl: 'https://www.marvel.com/articles/movies/every-single-90s-song-in-captain-marvel-and-more',
    ),
    FeaturedSoundtrackEntry(
      key: 'wakanda-forever-alone',
      title: 'Alone',
      artist: 'Burna Boy',
      album: 'Black Panther: Wakanda Forever - Music From and Inspired By',
      mediaTitles: <String>['Black Panther: Wakanda Forever'],
      sourceName: 'WhatSong soundtrack guide',
      sourceUrl: 'https://www.whatsong.org/movie/black-panther-wakanda-forever',
    ),
    FeaturedSoundtrackEntry(
      key: 'wakanda-forever-lift-me-up',
      title: 'Lift Me Up',
      artist: 'Rihanna',
      album: 'Black Panther: Wakanda Forever - Music From and Inspired By',
      mediaTitles: <String>['Black Panther: Wakanda Forever'],
      sourceName: 'WhatSong soundtrack guide',
      sourceUrl: 'https://www.whatsong.org/movie/black-panther-wakanda-forever',
    ),
    FeaturedSoundtrackEntry(
      key: 'agatha-you-should-see-me-in-a-crown',
      title: 'You Should See Me in a Crown',
      artist: 'Billie Eilish',
      album: 'When We All Fall Asleep, Where Do We Go?',
      mediaTitles: <String>['Agatha All Along'],
      sourceName: 'TheWrap / Den of Geek episode coverage',
      sourceUrl: 'https://www.thewrap.com/agatha-all-along-songs-soundtrack-list/',
      placementNote: 'Featured over the end credits of episode 5.',
    ),
    FeaturedSoundtrackEntry(
      key: 'thunderbolts-nothings-gonna-stop-us-now',
      title: "Nothing's Gonna Stop Us Now",
      artist: 'Jefferson Starship (credited as Starship)',
      album: 'No Protection',
      mediaTitles: <String>['Thunderbolts*', 'Thunderbolts'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt20969586/soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'guardians-vol-2-mr-blue-sky',
      title: 'Mr. Blue Sky',
      artist: 'Electric Light Orchestra',
      album: 'Out of the Blue',
      mediaTitles: <String>['Guardians of the Galaxy Vol. 2'],
      mediaTitleAliases: <String>['Guardians of the Galaxy 2', 'Guardians Vol 2'],
      sourceName: 'IMDb / WhatSong soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt3896198/soundtrack/',
      placementNote: 'Opens the film as Baby Groot dances during the battle with the Abilisk.',
    ),
    // Original scores: these are score albums/composer credits, not pop songs
    // placed in a scene. Their classification is kept separate in Explorer.
    FeaturedSoundtrackEntry(
      key: 'iron-man-original-score',
      title: 'Iron Man (Original Motion Picture Score)',
      artist: 'Ramin Djawadi',
      album: 'Iron Man: Original Motion Picture Soundtrack',
      mediaTitles: <String>['Iron Man'],
      relationshipLabel: 'Original score album',
      kind: FeaturedSoundtrackKind.originalScore,
      sourceName: 'Hans Zimmer official project discography',
      sourceUrl: 'https://hans-zimmer.com/product/iron-man/',
    ),
    FeaturedSoundtrackEntry(
      key: 'black-panther-original-score',
      title: 'Black Panther (Original Motion Picture Score)',
      artist: 'Ludwig Göransson',
      album: 'Black Panther (Original Motion Picture Score)',
      mediaTitles: <String>['Black Panther'],
      relationshipLabel: 'Original score album',
      kind: FeaturedSoundtrackKind.originalScore,
      sourceName: 'Universal Music Canada / Marvel Music announcement',
      sourceUrl: 'https://www.universalmusic.ca/2018/02/13/marvel-studios-black-panther-original-motion-picture-score-soundtrack-digitally-february-16/',
    ),
    FeaturedSoundtrackEntry(
      key: 'avengers-endgame-original-score',
      title: 'Avengers: Endgame (Original Motion Picture Score)',
      artist: 'Alan Silvestri',
      album: 'Avengers: Endgame (Original Motion Picture Soundtrack)',
      mediaTitles: <String>['Avengers: Endgame'],
      relationshipLabel: 'Original score album',
      kind: FeaturedSoundtrackKind.originalScore,
      sourceName: 'Alan Silvestri official filmography',
      sourceUrl: 'https://www.alansilvestri.com/filmography-marvels-avengers-endgame-92.htm',
    ),
    FeaturedSoundtrackEntry(
      key: 'shang-chi-in-the-dark',
      title: 'In the Dark',
      artist: 'Swae Lee & Jhené Aiko',
      creditedArtists: <String>['Swae Lee', 'Jhené Aiko'],
      album: 'Shang-Chi and The Legend of The Ten Rings: The Album',
      mediaTitles: <String>['Shang-Chi and the Legend of the Ten Rings'],
      mediaTitleAliases: <String>['Shang Chi and the Legend of the Ten Rings', 'Shang-Chi'],
      relationshipLabel: 'Official soundtrack album',
      kind: FeaturedSoundtrackKind.officialSoundtrackAlbum,
      sourceName: 'Marvel official soundtrack tracklist',
      sourceUrl: 'https://www.marvel.com/articles/movies/shang-chi-legend-of-the-ten-rings-album',
    ),
    FeaturedSoundtrackEntry(
      key: 'shang-chi-fire-in-the-sky',
      title: 'Fire in the Sky',
      artist: 'Anderson .Paak',
      album: 'Shang-Chi and The Legend of The Ten Rings: The Album',
      mediaTitles: <String>['Shang-Chi and the Legend of the Ten Rings'],
      mediaTitleAliases: <String>['Shang Chi and the Legend of the Ten Rings', 'Shang-Chi'],
      relationshipLabel: 'Official soundtrack album',
      kind: FeaturedSoundtrackKind.officialSoundtrackAlbum,
      sourceName: 'Marvel official soundtrack tracklist',
      sourceUrl: 'https://www.marvel.com/articles/movies/shang-chi-legend-of-the-ten-rings-album',
    ),
    FeaturedSoundtrackEntry(
      key: 'shang-chi-every-summertime',
      title: 'Every Summertime',
      artist: 'NIKI',
      album: 'Shang-Chi and The Legend of The Ten Rings: The Album',
      mediaTitles: <String>['Shang-Chi and the Legend of the Ten Rings'],
      mediaTitleAliases: <String>['Shang Chi and the Legend of the Ten Rings', 'Shang-Chi'],
      relationshipLabel: 'Official soundtrack album',
      kind: FeaturedSoundtrackKind.officialSoundtrackAlbum,
      sourceName: 'Marvel official soundtrack tracklist',
      sourceUrl: 'https://www.marvel.com/articles/movies/shang-chi-legend-of-the-ten-rings-album',
    ),
    FeaturedSoundtrackEntry(
      key: 'ms-marvel-blinding-lights',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      mediaTitles: <String>['Ms. Marvel'],
      mediaTitleAliases: <String>['Ms Marvel'],
      sourceName: 'Soundtracki episode guide',
      sourceUrl: 'https://soundtracki.com/shows/ms-marvel-season-1-soundtrack',
      placementNote: 'Opens episode 1, “Generation Why”.',
    ),
    FeaturedSoundtrackEntry(
      key: 'moon-knight-a-man-without-love',
      title: 'A Man Without Love',
      artist: 'Engelbert Humperdinck',
      album: 'A Man Without Love',
      mediaTitles: <String>['Moon Knight'],
      sourceName: 'Engelbert Humperdinck official news / Noise11',
      sourceUrl: 'https://www.engelbert.com/news/engelbert-humperdincks-a-man-without-love-features-in-the-new-marvel-series-moon-knight',
      placementNote: 'Featured in the opening sequence of episode 1.',
    ),
    FeaturedSoundtrackEntry(
      key: 'wandavision-agatha-all-along',
      title: 'Agatha All Along',
      artist: 'Kathryn Hahn & the WandaVision song cast',
      album: 'WandaVision: Episode 7 (Original Soundtrack)',
      mediaTitles: <String>['WandaVision'],
      sourceName: 'TheWrap soundtrack coverage',
      sourceUrl: 'https://www.thewrap.com/wandavision-agatha-harkness-kathryn-hahn-theme-song/',
      placementNote: 'The episode 7 theme song features Kathryn Hahn as a vocalist.',
    ),
    FeaturedSoundtrackEntry(
      key: 'agatha-ballad-witches-road',
      title: 'The Ballad of the Witches’ Road',
      artist: 'Kathryn Hahn and the coven cast',
      album: 'Agatha All Along (Original Soundtrack)',
      mediaTitles: <String>['Agatha All Along'],
      titleAliases: <String>['Ballad of the Witches Road'],
      sourceName: 'TheWrap / Yahoo soundtrack coverage',
      sourceUrl: 'https://www.thewrap.com/agatha-all-along-songs-soundtrack-list/',
      placementNote: 'The series features multiple versions, including the True Crime and Sacred Chant versions.',
    ),
    FeaturedSoundtrackEntry(
      key: 'endgame-dear-mr-fantasy',
      title: 'Dear Mr. Fantasy',
      artist: 'Traffic',
      album: 'John Barleycorn Must Die',
      mediaTitles: <String>['Avengers: Endgame'],
      mediaTitleAliases: <String>['Avengers Endgame', 'Avengers Endgame Encore'],
      sourceName: 'Marvel official song list',
      sourceUrl: 'https://www.marvel.com/articles/movies/avengers-endgame-every-single-song-and-theme-in-the-film',
      placementNote: 'The official Marvel song list credits Traffic; “Terrific” is a typo.',
    ),
    FeaturedSoundtrackEntry(
      key: 'spider-man-no-way-home-magic-number',
      title: 'The Magic Number',
      artist: 'De La Soul',
      album: '3 Feet High and Rising',
      mediaTitles: <String>['Spider-Man: No Way Home'],
      mediaTitleAliases: <String>['Spider Man No Way Home'],
      titleAliases: <String>['3 Is the Magic Number', 'Three Is the Magic Number'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt10872600/soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'captain-america-first-avenger-star-spangled-man',
      title: 'Star Spangled Man',
      artist: 'The Star Spangled Singers',
      album: 'Captain America: The First Avenger (Original Motion Picture Soundtrack)',
      mediaTitles: <String>['Captain America: The First Avenger'],
      mediaTitleAliases: <String>['Captain America the First Avenger'],
      sourceName: 'WhatSong / Alan Menken official song page',
      sourceUrl: 'https://www.whatsong.org/movie/captain-america-the-first-avenger',
      placementNote: 'Performed on stage as part of the USO show.',
    ),
    FeaturedSoundtrackEntry(
      key: 'brand-new-day-wolf-like-me',
      title: 'Wolf Like Me',
      artist: 'TV on the Radio',
      album: 'Return to Cookie Mountain',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'brand-new-day-im-every-woman',
      title: "I'm Every Woman",
      artist: 'Chaka Khan',
      album: 'Chaka',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'brand-new-day-monopoly',
      title: 'Monopoly',
      artist: 'Monetochka',
      album: '',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'brand-new-day-fire-for-you',
      title: 'Fire for You',
      artist: 'Cannons',
      album: 'Shadows',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'brand-new-day-st-elmos-fire',
      title: "St. Elmo's Fire",
      artist: 'Brian Eno',
      album: 'Another Green World',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'brand-new-day-oh-yeah',
      title: 'Oh yeah?',
      artist: 'Steve Lacy',
      album: '',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'brand-new-day-dame-tu-amistad',
      title: 'Dame Tu Amistad',
      artist: 'Dominique Patrick Noel, Hector Luis Pagan, Eduardo Padua & Eddie Montalvo',
      album: '',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'brand-new-day-party-in-the-usa',
      title: 'Party in the U.S.A.',
      artist: 'Miley Cyrus',
      album: 'The Time of Our Lives',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'brand-new-day-eoo',
      title: 'EoO',
      artist: 'Bad Bunny',
      album: '',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'brand-new-day-loser',
      title: 'Loser',
      artist: 'Tame Impala',
      album: '',
      mediaTitles: <String>['Spider-Man: Brand New Day'],
      sourceName: 'Radio Times / TheWrap soundtrack guide',
      sourceUrl: 'https://www.radiotimes.com/movies/scifi/spider-man-brand-new-day-soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'amazing-spider-man-2-its-on-again',
      title: 'It’s On Again',
      artist: 'Alicia Keys feat. Kendrick Lamar',
      creditedArtists: <String>['Alicia Keys', 'Kendrick Lamar'],
      album: 'The Amazing Spider-Man 2 (Original Motion Picture Soundtrack)',
      mediaTitles: <String>['The Amazing Spider-Man 2'],
      mediaTitleAliases: <String>['Amazing Spider-Man 2'],
      relationshipLabel: 'Featured in film and official soundtrack',
      sourceName: 'Sony Pictures / Columbia Records announcement',
      sourceUrl: 'https://sony.mediaroom.com/2014-03-12-The-Amazing-Spider-Man-2-To-Include-Its-On-Again-by-Alicia-Keys-Featuring-Kendrick-Lamar-Written-by-Pharrell-Williams-Alicia-Keys-Hans-Zimmer-and-Kendrick-Lamar',
      placementNote: 'Written for the film and selected by director Marc Webb as the end-credit song.',
    ),

    // Existing indexed soundtrack relationships retained from the prior search index.
    FeaturedSoundtrackEntry(
      key: 'spiderman-hero',
      title: 'Hero',
      artist: 'Chad Kroeger feat. Josey Scott',
      album: 'Music from and Inspired by Spider-Man',
      mediaTitles: <String>['Spider-Man (2002)'],
      artistAliases: <String>['Nickelback', 'Josey Scott'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt0145487/soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'spiderman-2-raindrops',
      title: 'Raindrops Keep Fallin’ on My Head',
      artist: 'B. J. Thomas',
      album: '',
      mediaTitles: <String>['Spider-Man 2 (2004)'],
      artistAliases: <String>['B.J. Thomas', 'BJ Thomas'],
      titleAliases: <String>['Raindrops Keep Falling on My Head'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt0316654/soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'spiderman-3-funky-soul',
      title: 'People Get Up and Drive Your Funky Soul (Remix)',
      artist: 'James Brown',
      album: '',
      mediaTitles: <String>['Spider-Man 3 (2007)'],
      sourceName: 'WhatSong soundtrack guide',
      sourceUrl: 'https://www.whatsong.org/movie/spider-man-3',
    ),
    FeaturedSoundtrackEntry(
      key: 'spiderman-into-spider-verse-sunflower',
      title: 'Sunflower',
      artist: 'Post Malone & Swae Lee',
      creditedArtists: <String>['Post Malone', 'Swae Lee'],
      album: 'Spider-Man: Into the Spider-Verse (Soundtrack from & Inspired by the Motion Picture)',
      mediaTitles: <String>['Spider-Man: Into the Spider-Verse'],
      artistAliases: <String>['Post Malone', 'Swae Lee'],
      sourceName: 'IMDb soundtrack credits',
      sourceUrl: 'https://www.imdb.com/title/tt4633694/soundtrack/',
    ),
    FeaturedSoundtrackEntry(
      key: 'amazing-spiderman-2-gone-gone-gone',
      title: 'Gone, Gone, Gone',
      artist: 'Phillip Phillips',
      album: 'The World from the Side of the Moon',
      mediaTitles: <String>['The Amazing Spider-Man 2'],
      sourceName: 'Soundtrack Radar',
      sourceUrl: 'https://soundtrackradar.com/the-amazing-spider-man-2-soundtrack/',
    ),
  ];

  static List<FeaturedSoundtrackEntry> forMediaTitle(String title) =>
      entries.where((entry) => entry.matchesMediaTitle(title)).toList(growable: false);

  static List<FeaturedSoundtrackEntry> forArtist(String artist) {
    final needle = FeaturedSoundtrackEntry.normalize(artist);
    if (needle.isEmpty) return const <FeaturedSoundtrackEntry>[];
    return entries.where((entry) {
      final names = <String>{entry.artist, ...entry.allCreditedArtists, ...entry.artistAliases};
      return names.map(FeaturedSoundtrackEntry.normalize).contains(needle);
    }).toList(growable: false);
  }

  static List<FeaturedSoundtrackEntry> forSong({
    required String title,
    required String artist,
  }) {
    final normalizedTitle = FeaturedSoundtrackEntry.normalize(title);
    final normalizedArtist = FeaturedSoundtrackEntry.normalize(artist);
    return entries.where((entry) {
      final titles = <String>{entry.title, ...entry.titleAliases}
          .map(FeaturedSoundtrackEntry.normalize);
      final artists = <String>{entry.artist, ...entry.allCreditedArtists, ...entry.artistAliases}
          .map(FeaturedSoundtrackEntry.normalize);
      return titles.contains(normalizedTitle) &&
          (normalizedArtist.isEmpty || artists.contains(normalizedArtist));
    }).toList(growable: false);
  }

  /// Builds dynamic soundtrack shelves from known song-to-title relationships.
  /// Franchise shelves are optional and only use franchise metadata supplied
  /// by the caller's actual media library; no franchise is inferred from names.
  static List<GeneratedSoundtrackCollection> generatedCollections({
    Map<String, List<String>> franchisesByMediaTitle = const <String, List<String>>{},
  }) {
    final output = <GeneratedSoundtrackCollection>[];
    final byMedia = <String, List<FeaturedSoundtrackEntry>>{};
    final byAlbum = <String, List<FeaturedSoundtrackEntry>>{};
    final byArtist = <String, List<FeaturedSoundtrackEntry>>{};
    final byFranchise = <String, List<FeaturedSoundtrackEntry>>{};

    for (final entry in entries) {
      for (final mediaTitle in entry.mediaTitles) {
        byMedia.putIfAbsent(mediaTitle, () => <FeaturedSoundtrackEntry>[]).add(entry);
        for (final franchise in franchisesByMediaTitle.entries) {
          if (entry.matchesMediaTitle(franchise.key)) {
            for (final franchiseName in franchise.value) {
              if (franchiseName.trim().isNotEmpty) {
                byFranchise.putIfAbsent(franchiseName.trim(), () => <FeaturedSoundtrackEntry>[]).add(entry);
              }
            }
          }
        }
      }
      if (entry.album.trim().isNotEmpty) {
        byAlbum.putIfAbsent(entry.album.trim(), () => <FeaturedSoundtrackEntry>[]).add(entry);
      }
      for (final artist in entry.allCreditedArtists) {
        byArtist.putIfAbsent(artist.trim(), () => <FeaturedSoundtrackEntry>[]).add(entry);
      }
    }

    String slug(String value) => FeaturedSoundtrackEntry.normalize(value);
    for (final group in byMedia.entries) {
      final unique = <String, FeaturedSoundtrackEntry>{
        for (final entry in group.value) entry.key: entry,
      }.values.toList(growable: false);
      output.add(GeneratedSoundtrackCollection(
        id: 'media:${slug(group.key)}',
        title: 'Music from ${group.key}',
        subtitle: '${unique.length} catalogued song${unique.length == 1 ? '' : 's'} connected to this title',
        entries: unique,
        collectionType: 'media',
      ));
    }
    for (final group in byAlbum.entries) {
      final unique = <String, FeaturedSoundtrackEntry>{
        for (final entry in group.value) entry.key: entry,
      }.values.toList(growable: false);
      output.add(GeneratedSoundtrackCollection(
        id: 'album:${slug(group.key)}',
        title: group.key,
        subtitle: '${unique.length} indexed soundtrack relationship${unique.length == 1 ? '' : 's'} from this album',
        entries: unique,
        collectionType: 'album',
      ));
    }
    for (final group in byArtist.entries) {
      final unique = <String, FeaturedSoundtrackEntry>{
        for (final entry in group.value) entry.key: entry,
      }.values.toList(growable: false);
      final mediaCount = unique.expand((entry) => entry.mediaTitles).toSet().length;
      if (mediaCount < 2) continue;
      output.add(GeneratedSoundtrackCollection(
        id: 'artist:${slug(group.key)}',
        title: '${group.key} across movies & series',
        subtitle: 'Connected to $mediaCount different films or series',
        entries: unique,
        collectionType: 'artist',
      ));
    }
    for (final group in byFranchise.entries) {
      final unique = <String, FeaturedSoundtrackEntry>{
        for (final entry in group.value) entry.key: entry,
      }.values.toList(growable: false);
      final mediaCount = unique.expand((entry) => entry.mediaTitles).toSet().length;
      if (mediaCount < 2) continue;
      output.add(GeneratedSoundtrackCollection(
        id: 'franchise:${slug(group.key)}',
        title: 'Music from ${group.key}',
        subtitle: 'Soundtrack connections across $mediaCount titles in your library franchise metadata',
        entries: unique,
        collectionType: 'franchise',
      ));
    }

    output.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return output;
  }

  static List<FeaturedSoundtrackEntry> search(String query) {
    final cleaned = query.trim();
    if (cleaned.isEmpty) return const <FeaturedSoundtrackEntry>[];
    return entries.where((entry) => entry.matchesQuery(cleaned)).toList(growable: false);
  }
}
