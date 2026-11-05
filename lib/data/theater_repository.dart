import '../app_core.dart';
import '../models/theater_models.dart';

class TheaterRepository {
  const TheaterRepository();
  List<MediaItem> ownedScreeningLibrary() {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    return controller.library.where((item) {
      if (!item.isAccessibleTo(profile) || !controller.isOwned(item.id)) {
        return false;
      }
      final type = item.type.toLowerCase();
      return type.contains('movie') ||
          type.contains('film') ||
          type.contains('tv') ||
          type.contains('special') ||
          type.contains('episode');
    }).toList(growable: false);
  }

  List<TheaterShowtime> createSuggestedShowtimes({DateTime? now}) {
    final start = now ?? DateTime.now();
    return ownedScreeningLibrary()
        .take(12)
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) {
      final index = entry.key;
      final media = entry.value;
      return TheaterShowtime(
        id: 'local-${media.id}',
        mediaId: media.id,
        title: media.title,
        startsAt: start.add(Duration(minutes: index * 5)),
        durationMinutes: media.runtimeMinutes,
        posterUrl: media.imageUrl,
      );
    }).toList(growable: false);
  }
}
