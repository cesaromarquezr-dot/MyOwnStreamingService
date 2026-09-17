// FILE: `lib/media_experience.dart`.
// Purpose: Provides the cross-media experience tools and future-oriented UI entry points.

import 'package:flutter/material.dart';

class MediaExperienceScreen extends StatelessWidget {
  const MediaExperienceScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Media Experience')),
    body: ListView(padding: const EdgeInsets.all(18), children: const [
      _ExperienceCard('Complete the Experience', 'Watch, soundtrack, music video, lyrics, cast, characters, extras, trailers and connections.', Icons.all_inclusive_rounded),
      _ExperienceCard('Media Journey', 'Movie → song → artist → album → actor → franchise → another movie.', Icons.route_rounded),
      _ExperienceCard('What Was I Into?', 'Explore your personal media history by month or year.', Icons.timeline_rounded),
      _ExperienceCard('Finish What You Started', 'Find incomplete movies, seasons, albums, playlists, franchises and journeys.', Icons.playlist_play_rounded),
      _ExperienceCard('Shared Discovery', 'Remember who introduced you to a movie, song, artist or franchise.', Icons.people_alt_outlined),
      _ExperienceCard('Library Detective', 'Review duplicate, metadata and missing-content findings before anything changes.', Icons.manage_search_rounded),
    ]),
  );
}
class _ExperienceCard extends StatelessWidget {
  final String title; final String description; final IconData icon;
  const _ExperienceCard(this.title, this.description, this.icon);
  @override Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon, size: 30), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(description)));
}
