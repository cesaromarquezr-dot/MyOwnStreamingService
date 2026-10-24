/// Local metadata for browsing examples. These records are catalog-only and
/// intentionally have no playable media. Provider data can enrich them later.
class DemoFranchiseMetadata {
  const DemoFranchiseMetadata({required this.id, required this.name, required this.type, this.order});
  final String id;
  final String name;
  final String type;
  final int? order;
}

class DemoCatalogMetadata {
  DemoCatalogMetadata._();
  static String normalizeTitle(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static const Map<String, List<String>> _cast = <String, List<String>>{
    'iron man': ['Robert Downey Jr.', 'Gwyneth Paltrow', 'Terrence Howard', 'Jeff Bridges'],
    'the incredible hulk': ['Edward Norton', 'Liv Tyler', 'Tim Roth', 'William Hurt'],
    'iron man 2': ['Robert Downey Jr.', 'Gwyneth Paltrow', 'Don Cheadle', 'Scarlett Johansson'],
    'thor': ['Chris Hemsworth', 'Natalie Portman', 'Tom Hiddleston', 'Anthony Hopkins'],
    'captain america the first avenger': ['Chris Evans', 'Hayley Atwell', 'Sebastian Stan', 'Hugo Weaving'],
    'the avengers': ['Robert Downey Jr.', 'Chris Evans', 'Chris Hemsworth', 'Mark Ruffalo', 'Scarlett Johansson', 'Jeremy Renner'],
    'iron man 3': ['Robert Downey Jr.', 'Gwyneth Paltrow', 'Don Cheadle', 'Guy Pearce'],
    'thor the dark world': ['Chris Hemsworth', 'Natalie Portman', 'Tom Hiddleston', 'Idris Elba'],
    'captain america the winter soldier': ['Chris Evans', 'Scarlett Johansson', 'Sebastian Stan', 'Anthony Mackie', 'Samuel L. Jackson'],
    'guardians of the galaxy': ['Chris Pratt', 'Zoe Saldana', 'Dave Bautista', 'Vin Diesel', 'Bradley Cooper'],
    'avengers age of ultron': ['Robert Downey Jr.', 'Chris Evans', 'Chris Hemsworth', 'Mark Ruffalo', 'Scarlett Johansson', 'Elizabeth Olsen'],
    'ant man': ['Paul Rudd', 'Michael Douglas', 'Evangeline Lilly', 'Michael Pena'],
    'captain america civil war': ['Robert Downey Jr.', 'Chris Evans', 'Scarlett Johansson', 'Anthony Mackie', 'Chadwick Boseman', 'Tom Holland'],
    'doctor strange': ['Benedict Cumberbatch', 'Chiwetel Ejiofor', 'Rachel McAdams', 'Benedict Wong', 'Tilda Swinton'],
    'spider man homecoming': ['Tom Holland', 'Zendaya', 'Jacob Batalon', 'Michael Keaton', 'Robert Downey Jr.'],
    'guardians of the galaxy vol 2': ['Chris Pratt', 'Zoe Saldana', 'Dave Bautista', 'Karen Gillan', 'Pom Klementieff'],
    'black panther': ['Chadwick Boseman', 'Michael B. Jordan', 'Lupita Nyongo', 'Danai Gurira', 'Letitia Wright'],
    'avengers infinity war': ['Robert Downey Jr.', 'Chris Evans', 'Chris Hemsworth', 'Mark Ruffalo', 'Benedict Cumberbatch', 'Tom Holland'],
    'ant man and the wasp': ['Paul Rudd', 'Evangeline Lilly', 'Michael Douglas', 'Michelle Pfeiffer'],
    'captain marvel': ['Brie Larson', 'Samuel L. Jackson', 'Ben Mendelsohn', 'Lashana Lynch'],
    'avengers endgame': ['Robert Downey Jr.', 'Chris Evans', 'Chris Hemsworth', 'Mark Ruffalo', 'Scarlett Johansson', 'Brie Larson'],
    'spider man far from home': ['Tom Holland', 'Zendaya', 'Jake Gyllenhaal', 'Samuel L. Jackson'],
    'black widow': ['Scarlett Johansson', 'Florence Pugh', 'David Harbour', 'Rachel Weisz'],
    'shang chi and the legend of the ten rings': ['Simu Liu', 'Awkwafina', 'Tony Leung', 'Michelle Yeoh'],
    'eternals': ['Gemma Chan', 'Richard Madden', 'Kumail Nanjiani', 'Salma Hayek', 'Angelina Jolie'],
    'spider man no way home': ['Tom Holland', 'Zendaya', 'Benedict Cumberbatch', 'Tobey Maguire', 'Andrew Garfield', 'Willem Dafoe'],
    'thor love and thunder': ['Chris Hemsworth', 'Natalie Portman', 'Tessa Thompson', 'Christian Bale'],
    'black panther wakanda forever': ['Letitia Wright', 'Lupita Nyongo', 'Danai Gurira', 'Winston Duke', 'Angela Bassett'],
    'guardians of the galaxy vol 3': ['Chris Pratt', 'Zoe Saldana', 'Dave Bautista', 'Karen Gillan', 'Will Poulter'],
    'the marvels': ['Brie Larson', 'Iman Vellani', 'Teyonah Parris', 'Samuel L. Jackson'],
    'deadpool wolverine': ['Ryan Reynolds', 'Hugh Jackman', 'Emma Corrin', 'Morena Baccarin'],
    'captain america brave new world': ['Anthony Mackie', 'Danny Ramirez', 'Shira Haas', 'Harrison Ford', 'Liv Tyler'],
    'thunderbolts': ['Florence Pugh', 'Sebastian Stan', 'David Harbour', 'Wyatt Russell', 'Lewis Pullman'],
    'the falcon and the winter soldier': ['Anthony Mackie', 'Sebastian Stan', 'Wyatt Russell', 'Erin Kellyman', 'Danny Ramirez'],
    'spider noir': ['Nicolas Cage', 'Lamorne Morris', 'Li Jun Li', 'Brendan Gleeson'],
    'wizards of waverly place': ['Selena Gomez', 'David Henrie', 'Jake T. Austin', 'Jennifer Stone', 'David DeLuise'],
    'that s so random': ['Tiffany Thornton', 'Sterling Knight', 'Brandon Mychal Smith', 'Doug Brochu'],
    'the suite life of zack cody': ['Dylan Sprouse', 'Cole Sprouse', 'Brenda Song', 'Ashley Tisdale', 'Phill Lewis'],
    'american dragon jake long': ['Dante Basco', 'Keone Young', 'Amy Bruckner', 'Mae Whitman'],
    'how to train your dragon': ['Jay Baruchel', 'America Ferrera', 'Gerard Butler', 'Craig Ferguson', 'Jonah Hill'],
    'harry potter and the sorcerer s stone': ['Daniel Radcliffe', 'Rupert Grint', 'Emma Watson', 'Richard Harris', 'Alan Rickman'],
    'harry potter and the chamber of secrets': ['Daniel Radcliffe', 'Rupert Grint', 'Emma Watson', 'Kenneth Branagh', 'Jason Isaacs'],
    'harry potter and the prisoner of azkaban': ['Daniel Radcliffe', 'Rupert Grint', 'Emma Watson', 'Gary Oldman', 'David Thewlis'],
    'harry potter and the goblet of fire': ['Daniel Radcliffe', 'Rupert Grint', 'Emma Watson', 'Robert Pattinson', 'Ralph Fiennes'],
    'harry potter and the order of the phoenix': ['Daniel Radcliffe', 'Rupert Grint', 'Emma Watson', 'Imelda Staunton', 'Helena Bonham Carter'],
    'harry potter and the half blood prince': ['Daniel Radcliffe', 'Rupert Grint', 'Emma Watson', 'Michael Gambon', 'Tom Felton'],
    'harry potter and the deathly hallows part 1': ['Daniel Radcliffe', 'Rupert Grint', 'Emma Watson', 'Ralph Fiennes', 'Helena Bonham Carter'],
    'harry potter and the deathly hallows part 2': ['Daniel Radcliffe', 'Rupert Grint', 'Emma Watson', 'Ralph Fiennes', 'Maggie Smith'],
    'the incredibles': ['Craig T. Nelson', 'Holly Hunter', 'Samuel L. Jackson', 'Jason Lee', 'Sarah Vowell'],
    'finding nemo': ['Albert Brooks', 'Ellen DeGeneres', 'Alexander Gould', 'Willem Dafoe', 'Allison Janney'],
  };

  static const Map<String, List<String>> _directors = <String, List<String>>{
    'iron man': ['Jon Favreau'], 'the incredible hulk': ['Louis Leterrier'],
    'iron man 2': ['Jon Favreau'], 'thor': ['Kenneth Branagh'],
    'captain america the first avenger': ['Joe Johnston'], 'the avengers': ['Joss Whedon'],
    'iron man 3': ['Shane Black'], 'thor the dark world': ['Alan Taylor'],
    'captain america the winter soldier': ['Anthony Russo', 'Joe Russo'],
    'guardians of the galaxy': ['James Gunn'], 'avengers age of ultron': ['Joss Whedon'],
    'ant man': ['Peyton Reed'], 'captain america civil war': ['Anthony Russo', 'Joe Russo'],
    'doctor strange': ['Scott Derrickson'], 'spider man homecoming': ['Jon Watts'],
    'guardians of the galaxy vol 2': ['James Gunn'], 'black panther': ['Ryan Coogler'],
    'avengers infinity war': ['Anthony Russo', 'Joe Russo'], 'ant man and the wasp': ['Peyton Reed'],
    'captain marvel': ['Anna Boden', 'Ryan Fleck'], 'avengers endgame': ['Anthony Russo', 'Joe Russo'],
    'spider man far from home': ['Jon Watts'], 'black widow': ['Cate Shortland'],
    'shang chi and the legend of the ten rings': ['Destin Daniel Cretton'],
    'eternals': ['Chloe Zhao'], 'spider man no way home': ['Jon Watts'],
    'thor love and thunder': ['Taika Waititi'], 'black panther wakanda forever': ['Ryan Coogler'],
    'guardians of the galaxy vol 3': ['James Gunn'], 'the marvels': ['Nia DaCosta'],
    'deadpool wolverine': ['Shawn Levy'], 'captain america brave new world': ['Julius Onah'],
    'thunderbolts': ['Jake Schreier'], 'how to train your dragon': ['Dean DeBlois'],
    'the incredibles': ['Brad Bird'], 'finding nemo': ['Andrew Stanton'],
  };

  static List<String> castFor(String title) =>
      List<String>.unmodifiable(_cast[normalizeTitle(title)] ?? const <String>[]);

  static List<String> directorsFor(String title) =>
      List<String>.unmodifiable(_directors[normalizeTitle(title)] ?? const <String>[]);

  static List<String> writersFor(String title) => switch (normalizeTitle(title)) {
        'iron man' => const ['Mark Fergus', 'Hawk Ostby', 'Art Marcum', 'Matt Holloway'],
        'the incredible hulk' => const ['Zak Penn'],
        'the avengers' || 'avengers age of ultron' => const ['Joss Whedon'],
        'guardians of the galaxy' || 'guardians of the galaxy vol 2' || 'guardians of the galaxy vol 3' => const ['James Gunn'],
        'black panther' || 'black panther wakanda forever' => const ['Ryan Coogler'],
        'the incredibles' => const ['Brad Bird'],
        'finding nemo' => const ['Andrew Stanton', 'Bob Peterson'],
        'how to train your dragon' => const ['Dean DeBlois', 'Chris Sanders'],
        _ => const <String>[],
      };

  static List<String> genresFor(String title, {required bool isTv, required bool isMcu}) {
    if (isMcu) return const ['Action', 'Adventure', 'Superhero', 'Science Fiction'];
    final normalized = normalizeTitle(title);
    if (normalized.startsWith('harry potter') || normalized == 'how to train your dragon') {
      return const ['Fantasy', 'Adventure', 'Family'];
    }
    if (normalized == 'the incredibles' || normalized == 'finding nemo') {
      return const ['Animation', 'Family', 'Adventure', 'Comedy'];
    }
    if (isTv) return const ['Family', 'Comedy', 'Fantasy'];
    return const ['Adventure', 'Family'];
  }

  static DemoFranchiseMetadata? franchiseFor(String title) {
    final normalized = normalizeTitle(title);
    const potter = <String>[
      'harry potter and the sorcerer s stone',
      'harry potter and the chamber of secrets',
      'harry potter and the prisoner of azkaban',
      'harry potter and the goblet of fire',
      'harry potter and the order of the phoenix',
      'harry potter and the half blood prince',
      'harry potter and the deathly hallows part 1',
      'harry potter and the deathly hallows part 2',
    ];
    final index = potter.indexOf(normalized);
    if (index >= 0) {
      return DemoFranchiseMetadata(id: 'harry-potter', name: 'Harry Potter Film Series', type: 'Saga', order: index + 1);
    }
    return null;
  }
}
