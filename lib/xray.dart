// FILE: `lib/xray.dart`.
// Purpose: Provides an X-Ray-style cast and production overlay for playback.
// Actor identity/photo services can be connected later without changing the
// player contract; the screen is driven by imported media metadata today.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'localization.dart';

/// X-Ray screen showing cast, directors, music and other context for a title.
class XRayScreen extends StatelessWidget {
  final MediaItem media;

  const XRayScreen({
    super.key,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final actors = media.actors.where((e) => e.trim().isNotEmpty).toList();
    final directors =
        media.directors.where((e) => e.trim().isNotEmpty).toList();
    final writers = media.writers.where((e) => e.trim().isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('X-Ray'),
        actions: [
          if (media.trailerUrl?.trim().isNotEmpty == true)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.verified_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
        children: [
          _heroCard(),
          const SizedBox(height: 18),
          if (actors.isNotEmpty) ...[
            _heading('CAST', Icons.people_alt_outlined),
            const SizedBox(height: 10),
            for (final actor in actors)
              _creditTile(
                name: actor,
                subtitle: tr('Actor • Select for biography and credits'),
                icon: Icons.person_outline_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ActorBiographyScreen(
                      actorName: actor,
                      media: media,
                    ),
                  ),
                ),
              ),
          ],
          if (directors.isNotEmpty) ...[
            const SizedBox(height: 18),
            _heading('DIRECTORS', Icons.movie_creation_outlined),
            const SizedBox(height: 10),
            for (final director in directors)
              _creditTile(
                name: director,
                subtitle: tr('Director'),
                icon: Icons.videocam_outlined,
              ),
          ],
          if (writers.isNotEmpty) ...[
            const SizedBox(height: 18),
            _heading('WRITERS', Icons.edit_note_rounded),
            const SizedBox(height: 10),
            for (final writer in writers)
              _creditTile(
                name: writer,
                subtitle: tr('Writer'),
                icon: Icons.edit_outlined,
              ),
          ],
          if (media.music.isNotEmpty) ...[
            const SizedBox(height: 18),
            _heading('MUSIC', Icons.music_note_rounded),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final song in media.music)
                      Chip(
                        avatar: const Icon(Icons.music_note_rounded, size: 16),
                        label: Text(song),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const UniversalText('About X-Ray'),
              subtitle: const UniversalText('Imported cast and production metadata stays tied to your library. '
                'When actor biography/photo metadata is available, this same view can display it without moving your physical media off your home server.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1B1B), Color(0xFF0D0D0D)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 72,
              height: 104,
              child: _poster(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UniversalText('X-RAY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  media.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (media.releaseYear != null) '${media.releaseYear}',
                    if (media.genres.isNotEmpty) media.genres.take(2).join(' • '),
                  ].join(' • '),
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _poster() {
    final url = media.imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return Container(
        color: const Color(0xFF181818),
        child: const Icon(Icons.movie_outlined, color: Colors.white38),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF181818),
        child: const Icon(Icons.movie_outlined, color: Colors.white38),
      ),
    );
  }

  Widget _heading(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _creditTile({
    required String name,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          child: Icon(icon),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

/// Displays a person-focused X-Ray card for an actor.
class ActorBiographyScreen extends StatelessWidget {
  final String actorName;
  final MediaItem media;

  const ActorBiographyScreen({
    super.key,
    required this.actorName,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    final initial = actorName.trim().isEmpty ? '?' : actorName.trim()[0];

    return Scaffold(
      appBar: AppBar(title: Text(actorName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 64,
                  child: Text(
                    initial.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  actorName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const UniversalText('ACTOR PROFILE',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UniversalText('BIOGRAPHY',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 9),
                  UniversalText('$actorName appears in ${media.title}. '
                    'Biography and portrait metadata can be populated from the actor catalog when that metadata is available.',
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.movie_outlined),
              title: const UniversalText('From this title'),
              subtitle: Text(media.title),
            ),
          ),
        ],
      ),
    );
  }
}
