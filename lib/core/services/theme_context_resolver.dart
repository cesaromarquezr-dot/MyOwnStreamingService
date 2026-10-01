import '../models/media_event.dart';

/// Chooses presentation context without changing the underlying media record.
/// Collection context wins when explicitly supplied; otherwise active seasonal
/// events are considered in relevance order.
class ThemeContextResolver {
  const ThemeContextResolver();

  MediaEvent? resolve({
    MediaEvent? collectionContext,
    required List<MediaEvent> activeEvents,
    String? userPreferredThemeId,
  }) {
    if (collectionContext != null) return collectionContext;

    if (userPreferredThemeId != null && userPreferredThemeId.trim().isNotEmpty) {
      for (final event in activeEvents) {
        if (event.themeId == userPreferredThemeId) return event;
      }
    }

    final candidates = List<MediaEvent>.from(activeEvents)..sort((a, b) {
      final aSeasonal = a.type == MediaEventType.season || a.type == MediaEventType.holiday;
      final bSeasonal = b.type == MediaEventType.season || b.type == MediaEventType.holiday;
      if (aSeasonal != bSeasonal) return aSeasonal ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return candidates.isEmpty ? null : candidates.first;
  }
}
