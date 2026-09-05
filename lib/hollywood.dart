import 'package:flutter/material.dart';

/// Actor/Actress discovered from media imported into the user's library.
class Actor {
  final String id;
  final String name;

  String photoUrl;
  String biography;
  String placeOfBirth;
  DateTime? dateOfBirth;
  String knownFor;
  String relationshipStatus;
  String partnerName;

  Actor({
    required this.id,
    required this.name,
    this.photoUrl = '',
    this.biography = '',
    this.placeOfBirth = '',
    this.dateOfBirth,
    this.knownFor = '',
    this.relationshipStatus = '',
    this.partnerName = '',
  });

  int? get currentAge {
    if (dateOfBirth == null) return null;

    final now = DateTime.now();

    int age = now.year - dateOfBirth!.year;

    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month &&
            now.day < dateOfBirth!.day)) {
      age--;
    }

    return age;
  }
}

/// Cast member belonging to a movie or TV episode.
class CastMember {
  final String actorId;
  final String actorName;
  final String characterName;
  final String? photoUrl;

  CastMember({
    required this.actorId,
    required this.actorName,
    required this.characterName,
    this.photoUrl,
  });
}

/// Legacy model retained so your old code can still reference it.
class TopHollywood {
  String? imgurl;
  String? name;

  TopHollywood({
    this.imgurl,
    this.name,
  });
}

/// Actor list screen.
class ActorsScreen extends StatelessWidget {
  const ActorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Actors & Actresses'),
      ),
      body: const Center(
        child: Text(
          'Actors discovered from your library will appear here.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

/// Compatibility name for older code.
class Actors extends ActorsScreen {
  const Actors({super.key});
}