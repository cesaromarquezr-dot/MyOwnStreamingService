import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'music.dart';
import 'localization.dart';
import 'media_text_localizer.dart';
import 'page_customization_button.dart';

/// Calendar-aware seasonal selections drawn only from the user's own library.
class SeasonalCollectionEngine {
  SeasonalCollectionEngine._();

  static String titleFor(DateTime date) {
    switch (date.month) {
      case 1:
        return 'New Year & Winter Comforts';
      case 2:
        return 'Love Stories & Soundtracks';
      case 3:
        return 'Spring Awakenings';
      case 4:
        return 'Springtime Escapes';
      case 5:
        return 'Family Favorites';
      case 6:
        return 'Summer Kickoff';
      case 7:
        return 'Summer Adventures';
      case 8:
        return 'Late-Summer Vibes';
      case 9:
        return 'Cozy Autumn Starts';
      case 10:
        return 'Spooky Season';
      case 11:
        return 'Gratitude & Comfort';
      case 12:
        return 'Holiday Favorites';
      default:
        return 'Seasonal Favorites';
    }
  }

  static List<String> _keywords(DateTime date) {
    switch (date.month) {
      case 1:
        return ['winter', 'new year', 'snow', 'resolution', 'comfort'];
      case 2:
        return ['love', 'romance', 'valentine', 'heart', 'romantic'];
      case 3:
      case 4:
        return ['spring', 'bloom', 'garden', 'rain', 'renewal'];
      case 5:
        return ['family', 'mother', 'father', 'home', 'together'];
      case 6:
      case 7:
      case 8:
        return ['summer', 'beach', 'road trip', 'vacation', 'sun'];
      case 9:
        return ['autumn', 'fall', 'school', 'cozy', 'harvest'];
      case 10:
        return ['halloween', 'horror', 'spooky', 'witch', 'monster', 'dark'];
      case 11:
        return ['thanksgiving', 'gratitude', 'family', 'harvest', 'comfort'];
      case 12:
        return ['christmas', 'holiday', 'winter', 'snow', 'festive'];
      default:
        return const [];
    }
  }

  static bool _matches(Iterable<String> fields, List<String> keywords) {
    final searchable = fields.join(' ').toLowerCase();
    return keywords.any((keyword) => searchable.contains(keyword));
  }

  static List<MediaItem> matching(List<MediaItem> library, {DateTime? now}) {
    final date = now ?? DateTime.now();
    final keywords = _keywords(date);
    return library.where((item) => _matches(<String>[
      item.title,
      item.type,
      item.description ?? '',
      ...item.genres,
      ...item.tags,
    ], keywords)).toList(growable: false);
  }

  static List<MusicTrack> matchingSongs(List<MusicTrack> tracks, {DateTime? now}) {
    final date = now ?? DateTime.now();
    final keywords = _keywords(date);
    return tracks.where((track) => _matches(<String>[
      track.title,
      track.artist,
      track.album,
      ...track.genres,
      ...track.subgenres,
    ], keywords)).toList(growable: false);
  }
}

class SeasonalCollectionsScreen extends StatelessWidget {
  const SeasonalCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = SeasonalCollectionEngine.titleFor(DateTime.now());
    final media = SeasonalCollectionEngine.matching(AppController.instance.library);
    final songs = SeasonalCollectionEngine.matchingSongs(MusicLibraryStore.instance.tracks);

    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF090909),
        actions: const [PageCustomizeButton(pageId: 'collections')],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('$title from your library', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const UniversalText('A calendar-aware mix of your own movies, TV titles, and music.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 16),
          if (media.isEmpty && songs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: UniversalText('No seasonally tagged titles found in your library yet.', style: TextStyle(color: Colors.white54)),
            ),
          for (final item in media)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.movie_outlined),
              title: LocalizedMediaText(item.title, preserveOriginal: true),
              subtitle: Text(item.type),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: item))),
            ),
          if (songs.isNotEmpty) ...[
            const SizedBox(height: 18),
            const UniversalText('Songs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
          for (final track in songs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.music_note_rounded),
              title: LocalizedMediaText(track.title),
              subtitle: Text(musicTrackSubtitle(track), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}
