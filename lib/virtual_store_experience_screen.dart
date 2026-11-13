import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_core.dart' hide MediaCollection;
import 'data/collection_repository.dart';
import 'interface_experience.dart';
import 'models/media_case_style.dart';
import 'models/media_collection_models.dart';
import 'music.dart';
import 'music_catalog_screen.dart';
import 'screens/collection_details_screen.dart';
import 'screens/virtual_store_catalog_computer_screen.dart';
import 'screens/theater_home_screen.dart';
import 'details.dart';
import 'catalog_poster_image.dart';
import 'stores/collection_store.dart';
import 'widgets/animated_media_case_dialog.dart';
import 'widgets/collection_box.dart';
import 'widgets/media_case_3d_view.dart';
import 'widgets/virtual_store_3d_scene.dart';

/// The Virtual Store is an accessible, navigable 3D environment with an
/// owned-library browser. It deliberately uses the user's owned media as its
/// catalog. The store has
/// no rental, checkout, payment, or purchasing flow.
class VirtualStoreExperienceScreen extends StatefulWidget {
  const VirtualStoreExperienceScreen({
    super.key,
    required this.config,
  });

  final InterfaceExperienceConfig config;

  @override
  State<VirtualStoreExperienceScreen> createState() =>
      _VirtualStoreExperienceScreenState();
}

class _VirtualStoreExperienceScreenState
    extends State<VirtualStoreExperienceScreen> {
  final FocusNode _navigationFocus = FocusNode(debugLabel: 'Virtual Store');
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _collectionsKey = GlobalKey();
  final GlobalKey _playlistsKey = GlobalKey();
  final GlobalKey _walkwayKey = GlobalKey();
  final TextEditingController _storeFinderController = TextEditingController();
  final MusicLibraryStore _music = MusicLibraryStore.instance;
  final CollectionStore _collections = CollectionStore.instance;

  int _zoneIndex = 0;
  int _selectedMediaIndex = 0;
  bool _shelfOpen = false;
  String? _selectedMediaId;
  String? _guidedMediaId;

  VirtualStoreDesign? get _design => widget.config.activeStore;

  @override
  void initState() {
    super.initState();
    _music.addListener(_refresh);
    _collections.addListener(_refresh);
    _collections.load();
    unawaited(_music.initializeForProfile(
      AppController.instance.currentProfile?.id,
    ));
  }

  @override
  void dispose() {
    _music.removeListener(_refresh);
    _collections.removeListener(_refresh);
    _navigationFocus.dispose();
    _storeFinderController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _employeeNormalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  bool _employeeQueryMentions(String query, String candidate) {
    final normalizedQuery = _employeeNormalize(query);
    final normalizedCandidate = _employeeNormalize(candidate);
    if (normalizedCandidate.length < 2 || normalizedQuery.isEmpty) return false;
    return normalizedQuery == normalizedCandidate ||
        normalizedQuery.contains(normalizedCandidate);
  }

  List<MusicTrack> get _allStoreTracks {
    final byId = <String, MusicTrack>{
      for (final track in _music.tracks) track.id: track,
      ..._music.catalogTracks,
    };
    return byId.values.toList(growable: false);
  }

  String _employeeCollectionLocation() {
    final placement = _design?.collectionGalleryPlacement ?? 'Back wall';
    switch (placement.toLowerCase()) {
      case 'back wall':
        return 'the Collection Gallery at the back of the store';
      case 'front display':
        return 'the Collection Gallery near the entrance';
      default:
        return 'the Collection Gallery on the center island';
    }
  }

  StoreAisle? _employeeAisleForMedia(MediaItem media) {
    final design = _design;
    if (design == null) return null;
    for (final aisle in design.aisles) {
      final foundInMainShelf = _resolveRule(
        filterType: aisle.filterType,
        filterValue: aisle.filterValue,
        mediaIds: aisle.mediaIds,
      ).any((item) => item.id == media.id);
      final foundInSubShelf = aisle.shelves.any((shelf) => _resolveRule(
            filterType: shelf.filterType,
            filterValue: shelf.filterValue,
            mediaIds: shelf.mediaIds,
          ).any((item) => item.id == media.id));
      if (foundInMainShelf || foundInSubShelf) return aisle;
    }
    return null;
  }

  String _employeeMediaLocation(MediaItem media) {
    final physical = CollectionRepository().fromLibrary().where(
      (collection) => collection.items.any((item) => item.id == media.id),
    );
    if (physical.isNotEmpty) {
      final box = physical.first;
      final aisle = _employeeAisleForMedia(media);
      final aisleNote = aisle == null ? '' : ' It is also indexed in the ${aisle.name} aisle.';
      return 'You can find it in the physical collection box "${box.title}" in ${_employeeCollectionLocation()}.$aisleNote';
    }

    final curated = _design?.curatedCollections.where(
      (collection) => collection.mediaIds.contains(media.id),
    ).toList(growable: false) ?? const <StoreCuratedCollection>[];
    final aisle = _employeeAisleForMedia(media);
    if (aisle != null) {
      final collectionNote = curated.isEmpty
          ? ''
          : ' It is also included in the digital collection "${curated.first.title}".';
      return 'You can find it in the ${aisle.name} aisle.$collectionNote';
    }
    if (curated.isNotEmpty) {
      return 'It is in the digital collection "${curated.first.title}" in the Curated Collections area.';
    }

    final type = _employeeNormalize(media.type);
    if (type.contains('music') || type.contains('album') || type.contains('song') || type.contains('track')) {
      return 'You can find it in the Music & Albums section.';
    }
    if (type.contains('tv') || type.contains('show') || type.contains('series') || type.contains('episode')) {
      return 'You can find it in the TV Shows section.';
    }
    return 'You can find it in the Movies & Films section.';
  }

  bool _employeeIsMovie(MediaItem media) {
    final type = _employeeNormalize(media.type);
    return type.contains('movie') || type.contains('film') ||
        type.contains('documentary') || type.contains('concert film');
  }

  bool _employeeIsShow(MediaItem media) {
    final type = _employeeNormalize(media.type);
    return type.contains('tv') || type.contains('show') ||
        type.contains('series') || type.contains('episode') ||
        type.contains('special');
  }

  String _employeeAvailabilityNote(MediaItem media) {
    final format = MediaCaseStyle.canonicalFormat(media.displayCaseFormat);
    final caseNote = format == 'Digital / not recorded'
        ? 'It is listed as digital media, so there is no confirmed physical case on the shelf.'
        : 'Its catalogued case format is $format.';
    final playable = media.playbackUrl?.trim().isNotEmpty == true;
    final playbackNote = playable
        ? 'Its playback stream is connected, so you can open it and play it.'
        : 'The library record exists, but a playable stream is not connected yet.';
    return '$caseNote $playbackNote';
  }

  String _employeeInventorySummary(List<MediaItem> owned, List<MusicTrack> tracks) {
    final movies = owned.where(_employeeIsMovie).length;
    final shows = owned.where(_employeeIsShow).length;
    final albums = tracks
        .map((track) => track.album.trim())
        .where((album) => album.isNotEmpty)
        .toSet()
        .length;
    final songs = tracks.length;
    final boxes = CollectionRepository().fromLibrary().length;
    final playlistCount = _playlists.length;
    return 'I checked this profile: $movies movies, $shows TV titles, $albums indexed music albums, $songs indexed tracks, $boxes physical collection boxes, and $playlistCount playlists are listed. The catalog computer can show you the full lists.';
  }

  String _employeeFormatInventory(List<MediaItem> owned, String requestedFormat) {
    final matching = owned.where((media) =>
        MediaCaseStyle.canonicalFormat(media.displayCaseFormat)
            .toLowerCase() == requestedFormat.toLowerCase()).toList(growable: false);
    if (matching.isEmpty) {
      return 'I checked the owned library and do not see any titles marked as $requestedFormat yet. The catalog computer can show the available formats; imported physical media will appear here after it is added and indexed.';
    }
    return 'Yes. I found ${matching.length} owned title${matching.length == 1 ? '' : 's'} marked as $requestedFormat. They are arranged in their configured movie or TV aisles. Ask me for a title and I can check its exact shelf location.';
  }

  String _employeeCategoryLocation(String category) {
    final matchingAisles = <String>[];
    for (final aisle in _design?.aisles ?? const <StoreAisle>[]) {
      final items = _resolveRule(
        filterType: aisle.filterType,
        filterValue: aisle.filterValue,
        mediaIds: aisle.mediaIds,
      );
      final categoryItems = items.where((item) {
        if (category == 'Movies') return _employeeIsMovie(item);
        if (category == 'TV Shows') return _employeeIsShow(item);
        return false;
      });
      if (categoryItems.isNotEmpty) matchingAisles.add(aisle.name);
    }
    if (matchingAisles.isNotEmpty) {
      return 'You can browse $category in ${matchingAisles.join(', ')}. Those are the configured aisles with matching titles.';
    }
    if (category == 'Music & CDs') {
      return 'The Music & CDs area and Listening Lounge are near the front of the store. Albums and playlists are shown there when their tracks are indexed.';
    }
    if (category == 'TV Shows') {
      return 'The TV Shows section is in the configured show aisles. I do not see a dedicated populated aisle in the current store layout yet.';
    }
    return 'The Movies & Films section is in the configured movie aisles. I do not see a dedicated populated movie aisle in the current store layout yet.';
  }

  String _employeeReply(String question) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final query = _employeeNormalize(question);
    final allAccessible = controller.library
        .where((item) => item.isAccessibleTo(profile))
        .toList(growable: false);
    final owned = _ownedLibrary;
    final tracks = _allStoreTracks;
    final playlists = _playlists;

    if (RegExp(r'^(hi|hello|hey|good morning|good afternoon|good evening)$')
        .hasMatch(query)) {
      return 'Hello! Welcome in. I can check movies, TV shows, music, collections and playlists, then tell you where to find them.';
    }
    if (query.contains('thank')) {
      return 'You are very welcome! Let me know if you would like directions to another aisle or want me to check another title.';
    }
    if (query.contains('where is the catalog computer') ||
        query.contains('where is the computer')) {
      return 'The Catalog Computer is at the information counter near the entrance. You can search the owned library there by title, genre, person, artist or format.';
    }
    if (query.contains('where is the theater') ||
        query.contains('theater corridor')) {
      return 'The Theater Corridor leads to the private rooms and poster displays. Follow the theater signs from the main store floor.';
    }
    if (query.contains('where is the collection gallery') ||
        query.contains('where are the collection boxes')) {
      return 'The Collection Gallery is ${_employeeCollectionLocation()}. The boxes are grouped by their collection or release name.';
    }
    if (query.contains('where is the coming soon') ||
        query.contains('coming soon section')) {
      return 'The Coming Soon area belongs with the featured and new-release displays near the entrance. Treat those entries as previews; they are not playable library titles until you add and index them.';
    }
    if (query.contains('is the store open') || query.contains('store hours')) {
      return 'This is your personal virtual media store, so there are no physical opening hours. It is available whenever the app and your media server are online.';
    }

    // A track title is a stronger match than its album or artist name.
    final trackMatches = tracks.where((track) =>
        _employeeQueryMentions(query, track.title)).toList(growable: false)
      ..sort((a, b) => b.title.length.compareTo(a.title.length));
    if (trackMatches.isNotEmpty) {
      final track = trackMatches.first;
      final containingPlaylists = playlists.where(
        (playlist) => playlist.trackIds.contains(track.id),
      ).toList(growable: false);
      final album = track.album.trim().isEmpty
          ? 'an album that is not named in the track metadata'
          : 'the album "${track.album}"';
      final asksPlaylist = query.contains('playlist');
      final location = containingPlaylists.isEmpty
          ? 'You can find it in Music & CDs, with $album.'
          : 'You can find it in Music & CDs, with $album. It is also in the "${containingPlaylists.first.name}" playlist display near the entrance.';
      final playlistStatus = asksPlaylist && containingPlaylists.isEmpty
          ? ' I do not see this track assigned to one of your playlists yet.'
          : '';
      if (track.audioUrl?.trim().isNotEmpty == true) {
        return 'Yes, we have "${track.title}" by ${track.artist}. $location$playlistStatus The audio file is indexed and ready to play.';
      }
      return 'I found "${track.title}" by ${track.artist} in the music catalog. $location$playlistStatus I can see the listing, but there is no playable audio file indexed for it yet. Add a copy you are entitled to use and import the audio file to make it playable.';
    }

    // If the question names an album rather than a song, locate its tracks.
    final albumMatches = tracks.where((track) =>
        _employeeQueryMentions(query, track.album)).toList(growable: false);
    if (albumMatches.isNotEmpty) {
      final albumName = albumMatches.first.album;
      final albumTracks = albumMatches.where((track) =>
          track.album == albumName).toList(growable: false);
      final playableCount = albumTracks.where((track) =>
          track.audioUrl?.trim().isNotEmpty == true).length;
      final playlistMatches = playlists.where((entry) => entry.trackIds.any(
        (id) => albumTracks.any((track) => track.id == id),
      )).toList(growable: false);
      final playlistNote = playlistMatches.isEmpty
          ? ''
          : ' Some of its tracks are also in "${playlistMatches.first.name}" in the Listening Lounge playlist display near the entrance.';
      final playbackNote = playableCount == albumTracks.length
          ? 'All indexed tracks have playable audio.'
          : '$playableCount of ${albumTracks.length} indexed tracks have playable audio.';
      return 'Yes, I found the album "$albumName" in Music & CDs with ${albumTracks.length} indexed tracks. $playbackNote$playlistNote I can only confirm a physical CD case when the library has physical-disc information for it.';
    }

    // If a visitor asks for an artist, list the albums represented in the catalog.
    final artistMatches = tracks.where((track) =>
        _employeeQueryMentions(query, track.artist)).toList(growable: false);
    if (artistMatches.isNotEmpty) {
      final artist = artistMatches.first.artist;
      final albums = artistMatches.map((track) => track.album.trim())
          .where((album) => album.isNotEmpty).toSet().toList()..sort();
      final albumText = albums.isEmpty ? 'track listings' : albums.map((a) => '"$a"').join(', ');
      return 'Yes, I found ${artistMatches.length} indexed tracks by $artist in Music & CDs. The catalog includes $albumText. The Listening Lounge is near the entrance.';
    }

    // A direct playlist question should identify the named playlist first.
    for (final playlist in playlists) {
      if (_employeeQueryMentions(query, playlist.name)) {
        final trackCount = _tracksForPlaylist(playlist).length;
        final kind = playlist.isSmart ? 'smart playlist' : 'playlist';
        return 'Yes, we have the $kind "${playlist.name}" with $trackCount indexed tracks. Its display is in the Listening Lounge playlist area near the entrance. You can open it from the Listening Lounge display.';
      }
    }

    // Search owned titles before anything that is merely present in metadata.
    final mediaMatches = owned.where((media) =>
        _employeeQueryMentions(query, media.title) ||
        (media.originalTitle?.isNotEmpty == true &&
            _employeeQueryMentions(query, media.originalTitle!)))
        .toList(growable: false)
      ..sort((a, b) => b.title.length.compareTo(a.title.length));
    if (mediaMatches.isNotEmpty) {
      final media = mediaMatches.first;
      final location = _employeeMediaLocation(media);
      final formatNote = _employeeAvailabilityNote(media);
      return 'Yes, we have "${media.title}" in this profile\'s owned library. $location $formatNote';
    }

    // Physical and curated collection names can be requested directly.
    final physicalCollections = CollectionRepository().fromLibrary();
    for (final collection in physicalCollections) {
      if (_employeeQueryMentions(query, collection.title)) {
        return 'Yes, we have the physical collection box "${collection.title}" in ${_employeeCollectionLocation()}. It contains ${collection.itemCount} indexed items. You can open the box from the Collection Gallery to browse its contents.';
      }
    }
    for (final collection in _design?.curatedCollections ?? const <StoreCuratedCollection>[]) {
      if (_employeeQueryMentions(query, collection.title)) {
        final count = owned.where((item) => collection.mediaIds.contains(item.id)).length;
        return 'Yes, the digital collection "${collection.title}" is available in the Curated Collections area. It contains $count owned titles.';
      }
    }

    // Search profile-accessible metadata separately from owned/playable media.
    final notOwnedMatches = allAccessible.where((media) =>
        _employeeQueryMentions(query, media.title)).toList(growable: false);
    if (notOwnedMatches.isNotEmpty) {
      final item = notOwnedMatches.first;
      return 'I found "${item.title}" in the app catalog, but it is not in this profile\'s owned library, so it is not available to play here yet. To add it, obtain a copy from a legitimate source and import it into your library. For a physical DVD, Blu-ray, 4K disc or CD, use your supported ripping/import workflow where permitted. Once the file is imported and indexed, I can help you find it on the shelves.';
    }

    // Helpful discovery questions that do not name a particular title.
    if (query.contains('new release') || query.contains('recently added') ||
        query.contains('what is new') || query.contains('whats new') || query.contains('what s new')) {
      final recent = owned.toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      if (recent.isEmpty) {
        return 'There are no newly added owned titles to feature yet. Import media into your library and the New Releases display can pick it up.';
      }
      final titles = recent.take(5).map((item) => '"${item.title}"').join(', ');
      return 'The latest additions I can see are $titles. They are featured in the New Releases display near the entrance; ask me for any title and I can check its exact aisle.';
    }
    if (query.contains('genre') || query.contains('categories')) {
      final genres = <String>{};
      for (final media in owned) {
        genres.addAll(media.genres.where((genre) => genre.trim().isNotEmpty));
        if (media.primaryGenre?.trim().isNotEmpty == true) {
          genres.add(media.primaryGenre!.trim());
        }
      }
      if (genres.isEmpty) {
        return 'I do not see genre tags in the owned catalog yet. Once your titles have genre metadata, I can direct you to the matching aisles.';
      }
      final genreNames = genres.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return 'The store has these genres represented in your library: ${genreNames.join(', ')}. The Browse by Genre displays use the genre tags on your titles.';
    }
    if (query.contains('recommend') || query.contains('suggest something') ||
        query.contains('surprise me')) {
      final candidates = owned.where((media) {
        if (query.contains('show') || query.contains('series')) return _employeeIsShow(media);
        if (query.contains('movie') || query.contains('film')) return _employeeIsMovie(media);
        return _employeeIsMovie(media) || _employeeIsShow(media);
      }).toList()
        ..sort((a, b) {
          final score = (b.userRatingStars ?? b.rating ?? 0.0)
              .compareTo(a.userRatingStars ?? a.rating ?? 0.0);
          return score != 0 ? score : b.addedAt.compareTo(a.addedAt);
        });
      if (candidates.isEmpty) {
        return 'I do not have enough owned titles of that type to make a recommendation yet. Add more movies or shows and I can suggest something from your shelves.';
      }
      final suggestions = candidates.take(3).map((media) =>
          '"${media.title}" (${_employeeMediaLocation(media)})').join(' ');
      return 'Certainly! Based on the titles and ratings in this library, I would suggest: $suggestions Tell me which one you would like to inspect.';
    }

    // General inventory / department / format questions.
    final asksInventory = query.contains('what do you have') ||
        query.contains('what is available') || query.contains('what available') ||
        query.contains('inventory') || query.contains('in stock') ||
        query.contains('how many titles') || query == 'what do you have';
    if (asksInventory) return _employeeInventorySummary(owned, tracks);

    if (query.contains('4k') || query.contains('ultra hd')) {
      return _employeeFormatInventory(owned, '4K Ultra HD');
    }
    if (query.contains('blu ray') || query.contains('bluray')) {
      return _employeeFormatInventory(owned, 'Blu-ray');
    }
    if (query.contains('dvd')) return _employeeFormatInventory(owned, 'DVD');
    if (query.contains('steelbook')) return _employeeFormatInventory(owned, 'Steelbook');
    if (query.contains('cd')) return _employeeFormatInventory(owned, 'Audio CD');

    final asksWhere = query.contains('where') || query.contains('find');
    if (query.contains('movie') || query.contains('movies') || query.contains('film')) {
      if (asksWhere || query.contains('what') || query.contains('have')) {
        return _employeeCategoryLocation('Movies');
      }
    }
    if (query.contains('show') || query.contains('shows') ||
        query.contains('series') || query.contains('television')) {
      if (asksWhere || query.contains('what') || query.contains('have')) {
        return _employeeCategoryLocation('TV Shows');
      }
    }
    if (query.contains('music') || query.contains('album') ||
        query.contains('song') || query.contains('cd')) {
      if (asksWhere || query.contains('what') || query.contains('have')) {
        return '${_employeeCategoryLocation('Music & CDs')} I can see ${tracks.length} indexed tracks across ${tracks.map((track) => track.album.trim()).where((album) => album.isNotEmpty).toSet().length} albums.';
      }
    }
    if (query.contains('collection') || query.contains('box set')) {
      final boxes = physicalCollections.length;
      return boxes == 0
          ? 'I do not see any physical collection boxes indexed yet. When you import a multi-disc or boxed release with its collection information, it can appear in the Collection Gallery at ${_employeeCollectionLocation()}.'
          : 'We have $boxes physical collection box${boxes == 1 ? '' : 'es'} in the Collection Gallery at ${_employeeCollectionLocation()}. Ask me for a collection name and I can check its contents.';
    }
    if (query.contains('playlist')) {
      return playlists.isEmpty
          ? 'I do not see any playlists indexed for this profile yet. Create or import a playlist and I can direct you to it.'
          : 'We have ${playlists.length} playlists in the Listening Lounge display near the entrance. Ask me for a playlist name and I can check its tracks.';
    }

    return 'Sorry, I cannot find that title in the store catalog or indexed music. It may not have been added to this library yet. To make it available, obtain a copy from a legitimate source and import it. For DVDs, Blu-rays, 4K discs or CDs, use the supported disc-import/ripping workflow where permitted. After the media file and its metadata are indexed, I can tell you its aisle, collection box or playlist location.';
  }

  MediaItem? _employeeQueryMatch(String question) {
    final query = _employeeNormalize(question);
    final matches = _storePosterLibrary.where((media) {
      final title = _employeeNormalize(media.title);
      final original = _employeeNormalize(media.originalTitle ?? '');
      return (title.length >= 2 && query.contains(title)) ||
          (original.length >= 2 && query.contains(original));
    }).toList(growable: false)
      ..sort((a, b) => b.title.length.compareTo(a.title.length));
    if (matches.isNotEmpty) return matches.first;

    // A song request should guide the visitor to its album's physical CD
    // display, rather than leaving the employee's answer without a location.
    final trackMatches = _allStoreTracks.where((track) {
      final title = _employeeNormalize(track.title);
      return title.length >= 2 && query.contains(title);
    }).toList(growable: false)
      ..sort((a, b) => b.title.length.compareTo(a.title.length));
    if (trackMatches.isEmpty) return null;
    final albumTitle = _employeeNormalize(trackMatches.first.album);
    final albums = _storePosterLibrary.where((media) =>
        media.id.startsWith('store-album:') &&
        _employeeNormalize(media.title) == albumTitle).toList(growable: false);
    return albums.isEmpty ? null : albums.first;
  }

  Future<void> _openStoreEmployee() async {
    final inputController = TextEditingController();
    MediaItem? guideTarget;
    final messages = <({String text, bool visitor})>[
      (
        text: 'Welcome in! I can help you find movies, TV shows, albums, songs, collections and playlists. Ask me what we have or where something is, and I will check the store system.',
        visitor: false,
      ),
    ];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void sendQuestion([String? suggested]) {
            final question = (suggested ?? inputController.text).trim();
            if (question.isEmpty) return;
            setDialogState(() {
              messages.add((text: question, visitor: true));
              messages.add((text: 'Let me check the store system...', visitor: false));
              guideTarget = _employeeQueryMatch(question);
            });
            inputController.clear();
            unawaited(Future<void>.delayed(const Duration(milliseconds: 350), () {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                messages.add((text: _employeeReply(question), visitor: false));
              });
            }));
          }

          final sampleTitle = _ownedLibrary.isEmpty ? 'a movie' : _ownedLibrary.first.title;
          return AlertDialog(
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(_design?.accentColor ?? 0xFFFFC107),
                  foregroundColor: Colors.black,
                  child: const Icon(Icons.support_agent_rounded),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ask the store employee'),
                      Text('Catalog desk · Here to help', style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.normal)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              height: 430,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return Align(
                          alignment: message.visitor ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 420),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: message.visitor
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(message.text),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ActionChip(
                          label: const Text('Find my music'),
                          onPressed: () => sendQuestion('Where can I find my music albums?'),
                        ),
                        ActionChip(
                          label: const Text('Find a movie'),
                          onPressed: () => sendQuestion('Do you have $sampleTitle?'),
                        ),
                        ActionChip(
                          label: const Text('Find a collection'),
                          onPressed: () => sendQuestion('Where are my collection boxes?'),
                        ),
                        ActionChip(
                          label: const Text('Check inventory'),
                          onPressed: () => sendQuestion('What do you have in the store?'),
                        ),
                        ActionChip(
                          label: const Text('Find playlists'),
                          onPressed: () => sendQuestion('Where are my playlists?'),
                        ),
                        if (guideTarget != null)
                          ActionChip(
                            avatar: const Icon(Icons.directions_walk_rounded, size: 16),
                            label: Text('Guide me to ${guideTarget!.title}', overflow: TextOverflow.ellipsis),
                            onPressed: () {
                              final target = guideTarget!;
                              Navigator.pop(dialogContext);
                              _focusMediaInStore(target);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextField(
                controller: inputController,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Ask for a title, artist, album, collection or playlist...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => sendQuestion(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => sendQuestion(),
                    icon: const Icon(Icons.send_rounded, size: 17),
                    label: const Text('Ask'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    inputController.dispose();
  }

  List<MediaItem> get _ownedLibrary {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    return controller.library
        .where((item) => item.isAccessibleTo(profile) && controller.isOwned(item.id))
        .toList(growable: false);
  }

  /// The physical store's artwork source combines owned video media with
  /// album-level artwork derived from this profile's indexed music tracks.
  /// Synthetic album cards are display-only and are never added to the library.
  List<MediaItem> get _storePosterLibrary {
    final items = _ownedLibrary.toList();
    final existingAlbumTitles = items
        .where((item) => item.type.toLowerCase().contains('album'))
        .map((item) => item.title.trim().toLowerCase())
        .where((title) => title.isNotEmpty)
        .toSet();
    final albumByKey = <String, MusicTrack>{};
    for (final track in _music.tracks) {
      final album = track.album.trim();
      final artwork = track.artworkUrl?.trim() ?? '';
      if (album.isEmpty || artwork.isEmpty || track.catalogOnly) continue;
      final key = '${track.artist.trim().toLowerCase()}|${album.toLowerCase()}';
      albumByKey.putIfAbsent(key, () => track);
    }
    final sortedAlbums = albumByKey.values.toList()
      ..sort((left, right) {
        final leftGenre = left.allGenreTags.isEmpty ? '' : left.allGenreTags.first.toLowerCase();
        final rightGenre = right.allGenreTags.isEmpty ? '' : right.allGenreTags.first.toLowerCase();
        final genreOrder = leftGenre.compareTo(rightGenre);
        if (genreOrder != 0) return genreOrder;
        final artistOrder = left.artist.toLowerCase().compareTo(right.artist.toLowerCase());
        if (artistOrder != 0) return artistOrder;
        return left.album.toLowerCase().compareTo(right.album.toLowerCase());
      });
    for (final track in sortedAlbums) {
      final album = track.album.trim();
      if (existingAlbumTitles.contains(album.toLowerCase())) continue;
      items.add(MediaItem(
        id: 'store-album:${track.id}',
        title: album,
        type: 'album',
        imageUrl: track.artworkUrl,
        description: 'Album by ${track.artist}',
        genres: track.allGenreTags,
        primaryGenre: track.allGenreTags.isEmpty ? null : track.allGenreTags.first,
        casePresentationFormat: 'Audio CD',
        addedAt: track.modifiedAt,
      ));
      existingAlbumTitles.add(album.toLowerCase());
    }
    return items;
  }

  List<String> get _zoneLabels {
    final aisles = _design?.aisles ?? const <StoreAisle>[];
    return <String>[
      ...aisles.map((aisle) => aisle.name),
      'Collection Gallery',
      'Listening Lounge',
      'Catalog Computer',
      'Theater Corridor',
      'Entrance & Featured Displays',
    ];
  }

  int get _safeZoneIndex => _zoneIndex.clamp(0, _zoneLabels.length - 1).toInt();

  StoreAisle? get _currentAisle {
    final aisles = _design?.aisles ?? const <StoreAisle>[];
    if (_safeZoneIndex >= aisles.length) return null;
    return aisles[_safeZoneIndex];
  }

  List<MediaItem> _resolveRule({
    required String filterType,
    String filterValue = '',
    List<String> mediaIds = const <String>[],
  }) {
    final all = _ownedLibrary;
    final query = filterValue.trim().toLowerCase();
    Iterable<MediaItem> result = all;
    switch (filterType) {
      case 'manual':
        result = all.where((item) => mediaIds.contains(item.id));
        break;
      case 'genre':
        result = all.where((item) =>
            item.genres.any((genre) => genre.toLowerCase() == query) ||
            item.primaryGenre?.toLowerCase() == query);
        break;
      case 'country':
        result = all.where((item) => item.countryOfOrigin?.toLowerCase() == query);
        break;
      case 'decade':
        final decade = int.tryParse(filterValue.trim());
        if (decade != null) {
          result = all.where((item) =>
              item.releaseYear != null &&
              item.releaseYear! >= decade &&
              item.releaseYear! < decade + 10);
        }
        break;
      case 'franchise':
        result = all.where((item) =>
            item.franchiseNames.any((name) => name.toLowerCase().contains(query)) ||
            item.franchiseName?.toLowerCase().contains(query) == true ||
            item.cinematicUniverseNames.any((name) => name.toLowerCase().contains(query)));
        break;
      case 'studio':
        result = all.where((item) =>
            item.studios.any((name) => name.toLowerCase().contains(query)));
        break;
      case 'type':
        result = all.where((item) {
          final type = item.type.toLowerCase().replaceAll('_', ' ');
          if (query == 'music' || query == 'audio') {
            return type.contains('music') || type.contains('song') ||
                type.contains('track') || type.contains('album') || type.contains('audio');
          }
          if (query == 'tv' || query == 'television' || query == 'specials') {
            return type.contains('tv') || type.contains('show') ||
                type.contains('series') || type.contains('episode') || type.contains('special');
          }
          if (query == 'movie' || query == 'movies' || query == 'film') {
            return type.contains('movie') || type.contains('film') ||
                type.contains('documentary') || type.contains('concert film');
          }
          return type == query;
        });
        break;
      case 'tag':
        result = all.where((item) => item.tags.any((tag) => tag.toLowerCase() == query));
        break;
      case 'recent':
        final recent = all.toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
        return recent.take(40).toList(growable: false);
      case 'favorites':
        result = all.where((item) =>
            AppController.instance.liked.any((liked) => liked.id == item.id));
        break;
      case 'all':
        break;
      default:
        result = all;
    }
    return result.take(60).toList(growable: false);
  }

  List<_StoreShelfData> _shelvesFor(StoreAisle aisle) {
    final shelves = <_StoreShelfData>[
      _StoreShelfData(
        title: aisle.name,
        items: _resolveRule(
          filterType: aisle.filterType,
          filterValue: aisle.filterValue,
          mediaIds: aisle.mediaIds,
        ),
      ),
    ];
    for (final shelf in aisle.shelves) {
      shelves.add(_StoreShelfData(
        title: shelf.title,
        items: _resolveRule(
          filterType: shelf.filterType,
          filterValue: shelf.filterValue,
          mediaIds: shelf.mediaIds,
        ),
      ));
    }
    return shelves;
  }

  List<MediaItem> get _currentAisleItems {
    final aisle = _currentAisle;
    if (aisle == null) return const <MediaItem>[];
    final seen = <String>{};
    return [
      for (final shelf in _shelvesFor(aisle))
        for (final item in shelf.items)
          if (seen.add(item.id)) item,
    ];
  }

  MediaItem? get _selectedMedia {
    final items = _currentAisleItems;
    if (items.isEmpty) return null;
    if (_selectedMediaId != null) {
      for (final item in items) {
        if (item.id == _selectedMediaId) return item;
      }
    }
    final index = _selectedMediaIndex.clamp(0, items.length - 1).toInt();
    return items[index];
  }

  void _selectZone(int delta) {
    if (_zoneLabels.isEmpty) return;
    setState(() {
      _zoneIndex = (_safeZoneIndex + delta).clamp(0, _zoneLabels.length - 1).toInt();
      _shelfOpen = false;
      _selectedMediaIndex = 0;
      _selectedMediaId = null;
    });
  }

  void _cycleMedia(int delta) {
    final items = _currentAisleItems;
    if (items.isEmpty) return;
    setState(() {
      _selectedMediaIndex = (_selectedMediaIndex + delta).clamp(0, items.length - 1).toInt();
      _selectedMediaId = items[_selectedMediaIndex].id;
    });
  }

  void _openCurrentZone() {
    final aisleCount = _design?.aisles.length ?? 0;
    if (_safeZoneIndex < aisleCount) {
      setState(() {
        _shelfOpen = true;
        _selectedMediaIndex = 0;
        _selectedMediaId = _currentAisleItems.isEmpty ? null : _currentAisleItems.first.id;
      });
      return;
    }
    if (_safeZoneIndex == aisleCount + 2) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const VirtualStoreCatalogComputerScreen()),
      );
      return;
    }
    if (_safeZoneIndex == aisleCount + 3) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const TheaterHomeScreen()),
      );
      return;
    }
    final target = _safeZoneIndex == aisleCount ? _collectionsKey : _playlistsKey;
    final targetContext = target.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: _motionDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  void _focusMediaInStore(MediaItem media) {
    final design = _design;
    if (design == null) return;
    final aisle = _employeeAisleForMedia(media);
    var nextZone = _safeZoneIndex;
    if (aisle != null) {
      final aisleIndex = design.aisles.indexOf(aisle);
      if (aisleIndex >= 0) nextZone = aisleIndex;
    } else {
      final type = _employeeNormalize(media.type);
      if (media.id.startsWith('store-album:') || type.contains('music') ||
          type.contains('album') || type.contains('song') || type.contains('track')) {
        nextZone = design.aisles.length + 1;
      }
    }
    setState(() {
      _guidedMediaId = media.id;
      _zoneIndex = nextZone;
      _shelfOpen = false;
      _selectedMediaId = media.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _walkwayKey.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: _motionDuration,
          curve: Curves.easeInOut,
          alignment: .25,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Finding ${media.title} in the store…')),
    );
  }

  Widget _buildStoreFinder(VirtualStoreDesign design) {
    final query = _storeFinderController.text.trim().toLowerCase();
    final matches = query.length < 2
        ? const <MediaItem>[]
        : _storePosterLibrary.where((media) =>
            media.title.toLowerCase().contains(query) ||
            (media.originalTitle?.toLowerCase().contains(query) ?? false))
            .take(5).toList(growable: false);
    return Card(
      color: Color(design.shelfColor).withValues(alpha: .94),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.location_searching_rounded),
              SizedBox(width: 8),
              Expanded(child: Text('Find a title in the store', style: TextStyle(fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _storeFinderController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search your movies, shows or albums…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _storeFinderController.text.isEmpty ? null : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () => setState(() {
                    _storeFinderController.clear();
                    _guidedMediaId = null;
                  }),
                  icon: const Icon(Icons.close_rounded),
                ),
                isDense: true,
                filled: true,
                fillColor: Colors.black.withValues(alpha: .12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (query.length >= 2 && matches.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('No matching owned title or indexed album was found.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            for (final media in matches)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 34,
                  height: 46,
                  child: ClipRRect(borderRadius: BorderRadius.circular(5), child: CatalogPosterImage(media: media, fit: BoxFit.cover)),
                ),
                title: Text(media.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(media.type, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.directions_walk_rounded),
                onTap: () => _focusMediaInStore(media),
              ),
            if (_guidedMediaId != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _guidedMediaId = null),
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: const Text('Clear shelf guidance'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Duration get _motionDuration {
    final design = _design;
    final level = design?.animationLevel ?? 'full';
    if (level == 'minimal') return Duration.zero;
    final base = level == 'reduced' ? 180 : 320;
    final speed = (design?.movementSpeed ?? 3).clamp(1, 5);
    return Duration(milliseconds: (base * (4 - speed) / 3).round().clamp(55, base).toInt());
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isLeft = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA;
    final isRight = key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD;
    final isUp = key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW;
    final isDown = key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS;
    final isSelect = key == LogicalKeyboardKey.keyE || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    final isBack = key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.backspace;

    if (_shelfOpen && _currentAisle != null) {
      if (isLeft || isUp) {
        _cycleMedia(-1);
        return KeyEventResult.handled;
      }
      if (isRight || isDown) {
        _cycleMedia(1);
        return KeyEventResult.handled;
      }
      if (isSelect) {
        _inspectSelectedMedia();
        return KeyEventResult.handled;
      }
      if (isBack) {
        setState(() => _shelfOpen = false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (isLeft || isUp) {
      _selectZone(-1);
      return KeyEventResult.handled;
    }
    if (isRight || isDown) {
      _selectZone(1);
      return KeyEventResult.handled;
    }
    if (isSelect) {
      _openCurrentZone();
      return KeyEventResult.handled;
    }
    if (isBack) return KeyEventResult.ignored;
    return KeyEventResult.ignored;
  }

  Future<void> _inspectSelectedMedia() async {
    final media = _selectedMedia;
    if (media == null) return;
    await _inspectMedia(media);
  }

  Future<void> _inspectMedia(MediaItem media) async {
    if (!mounted) return;
    final format = MediaCaseStyle.canonicalFormat(media.displayCaseFormat);
    final isAlbum = media.id.startsWith('store-album:') ||
        media.type.toLowerCase().contains('album');
    if (format == 'Digital / not recorded' && !isAlbum) {
      _openMediaDetails(media);
      return;
    }
    await showAnimatedMediaCaseDialog(
      context,
      media: media,
      animationLevel: _design?.animationLevel ?? 'full',
      onOpenTitle: () {
        if (isAlbum) {
          final sourceId = media.id.startsWith('store-album:')
              ? media.id.substring('store-album:'.length)
              : '';
          final artistNames = media.music.map((value) => value.trim().toLowerCase()).toSet();
          final sourceTracks = _music.tracks.where((track) {
            final sameAlbum = track.album.trim().toLowerCase() ==
                media.title.trim().toLowerCase();
            final artistMatches = artistNames.isEmpty ||
                artistNames.contains(track.artist.trim().toLowerCase());
            final selectedSource = sourceId.isNotEmpty && track.id == sourceId;
            return !track.catalogOnly &&
                (selectedSource || (sameAlbum && artistMatches));
          }).toList(growable: false);
          final leadTrack = sourceTracks.isEmpty ? null : sourceTracks.first;
          final localRows = sourceTracks.asMap().entries.map((entry) =>
              <String, dynamic>{
                'title': entry.value.title,
                'artist': entry.value.artist,
                'durationMs': entry.value.duration.inMilliseconds,
                'trackNumber': entry.key + 1,
                'artworkUrl': entry.value.artworkUrl,
              }).toList(growable: false);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OwnedAlbumDetailsScreen(
                media: media,
                albumTitle: media.title,
                artistName: leadTrack?.artist ?? media.music.join(', '),
                artworkUrl: media.imageUrl,
                localTracks: localRows,
                isOwned: sourceTracks.isNotEmpty ||
                    AppController.instance.isOwned(media.id),
              ),
            ),
          );
        } else {
          _openMediaDetails(media);
        }
      },
    );
  }

  void _openMediaDetails(MediaItem media) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MediaDetailsScreen(media: media),
      ),
    );
  }

  void _openPhysicalCollection(MediaCollection collection) {
    showAnimatedCollectionBoxDialog(
      context,
      collection: collection,
      animationLevel: _design?.animationLevel ?? 'full',
      onOpenCollection: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CollectionDetailsScreen(collection: collection),
        ),
      ),
    );
  }

  Future<void> _openDigitalCollection(StoreCuratedCollection collection) async {
    final items = _ownedLibrary
        .where((media) => collection.mediaIds.contains(media.id))
        .toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(collection.title),
        content: SizedBox(
          width: 480,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (collection.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(collection.description),
                ),
              Text('${items.length} titles · Digital collection',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No matching owned titles in this collection.'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            leading: SizedBox(
                              width: 42,
                              child: CatalogPosterImage(
                                media: item,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${item.type} · ${item.releaseYear ?? 'Year unknown'}'),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _openMediaDetails(item);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<_StorePlaylistData> get _playlists {
    final output = <_StorePlaylistData>[];
    for (final entry in _music.playlists.entries) {
      output.add(_StorePlaylistData(name: entry.key, trackIds: entry.value, isSmart: false));
    }
    for (final entry in _music.smartPlaylists.entries) {
      output.add(_StorePlaylistData(name: entry.key, trackIds: entry.value, isSmart: true));
    }
    return output.where((playlist) => playlist.trackIds.isNotEmpty).toList(growable: false);
  }

  List<MusicTrack> _tracksForPlaylist(_StorePlaylistData playlist) {
    final tracksById = <String, MusicTrack>{
      for (final track in _music.tracks) track.id: track,
      ..._music.catalogTracks,
    };
    return playlist.trackIds
        .map((id) => tracksById[id])
        .whereType<MusicTrack>()
        .toList(growable: false);
  }

  Future<void> _openPlaylist(_StorePlaylistData playlist) async {
    final tracks = _tracksForPlaylist(playlist);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(playlist.name),
        content: SizedBox(
          width: 440,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tracks.length} tracks · ${playlist.isSmart ? 'Smart playlist' : 'Your playlist'}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: tracks.isEmpty
                    ? const Center(child: Text('Playlist tracks are not loaded in this profile yet.'))
                    : ListView.builder(
                        itemCount: tracks.length,
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          return ListTile(
                            leading: const Icon(Icons.music_note_rounded),
                            title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${track.artist} · ${track.album}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const MusicScreen()),
              );
            },
            icon: const Icon(Icons.library_music_rounded),
            label: const Text('Open Music'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final design = _design;
    if (design == null) {
      return const Scaffold(
        body: Center(child: Text('Create a Virtual Store design in Customize App first.')),
      );
    }

    final posters = _ownedLibrary;
    final physicalCollections = CollectionRepository().fromLibrary();
    final zoneLabels = _zoneLabels;

    return Scaffold(
      backgroundColor: Color(design.wallColor),
      appBar: AppBar(
        backgroundColor: Color(design.shelfColor),
        title: Text(design.name),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.verified_rounded, size: 15),
              label: Text('OWNED LIBRARY'),
            ),
          ),
          IconButton(
            tooltip: 'Keyboard controls',
            onPressed: _showControls,
            icon: const Icon(Icons.keyboard_alt_outlined),
          ),
          IconButton(
            tooltip: 'Ask the store employee',
            onPressed: _openStoreEmployee,
            icon: const Icon(Icons.support_agent_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openStoreEmployee,
        icon: const Icon(Icons.support_agent_rounded),
        label: const Text('Ask employee'),
      ),
      body: Focus(
        focusNode: _navigationFocus,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _navigationFocus.requestFocus(),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
            children: [
              _StoreInteriorWall(
                design: design,
                posterMedia: posters,
              ),
              const SizedBox(height: 12),
              _buildStoreFinder(design),
              const SizedBox(height: 18),
              _buildNewReleaseWall(design),
              const SizedBox(height: 18),
              _buildGenreAisles(design),
              const SizedBox(height: 18),
              _buildStaffPicks(design),
              if (design.collectionGalleryPlacement == 'Front display') ...[
                const SizedBox(height: 16),
                _buildPhysicalCollections(physicalCollections, design),
              ],
              const SizedBox(height: 12),
              _buildWalkway(design, zoneLabels),
              const SizedBox(height: 10),
              _buildNavigationPanel(design, zoneLabels),
              const SizedBox(height: 16),
              _buildCurrentZonePanel(design),
              const SizedBox(height: 22),
              _buildCuratedCollections(design),
              if (design.collectionGalleryPlacement == 'Center island') ...[
                const SizedBox(height: 22),
                _buildPhysicalCollections(physicalCollections, design),
              ],
              const SizedBox(height: 22),
              _buildListeningLounge(design),
              if (design.collectionGalleryPlacement == 'Back wall') ...[
                const SizedBox(height: 22),
                _buildPhysicalCollections(physicalCollections, design),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewReleaseWall(VirtualStoreDesign design) {
    final items = _ownedLibrary.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final recent = items.take(12).toList(growable: false);
    if (recent.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 12),
      decoration: BoxDecoration(
        color: Color(design.shelfColor).withValues(alpha: .90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(design.accentColor).withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoreSectionHeading(
            title: 'New release wall',
            subtitle: 'The newest additions to your personal collection',
            icon: Icons.new_releases_rounded,
            accent: Color(design.accentColor),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 174,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final media = recent[index];
                return SizedBox(
                  width: 108,
                  child: InkWell(
                    onTap: () => _openMediaDetails(media),
                    borderRadius: BorderRadius.circular(9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(width: double.infinity, child: CatalogPosterImage(media: media, fit: BoxFit.cover)),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreAisles(VirtualStoreDesign design) {
    final mediaByGenre = <String, List<MediaItem>>{};
    for (final media in _ownedLibrary) {
      final genres = media.genres.isNotEmpty
          ? media.genres
          : (media.primaryGenre?.trim().isNotEmpty == true ? <String>[media.primaryGenre!.trim()] : const <String>[]);
      for (final genre in genres) {
        final clean = genre.trim();
        if (clean.isNotEmpty) (mediaByGenre[clean] ??= <MediaItem>[]).add(media);
      }
    }
    final genres = mediaByGenre.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (genres.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StoreSectionHeading(
          title: 'Browse by genre',
          subtitle: 'Curated aisles built from the genres in your library',
          icon: Icons.category_rounded,
          accent: Color(design.accentColor),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: genres.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final genre = genres[index];
              final items = mediaByGenre[genre] ?? const <MediaItem>[];
              final sample = items.isEmpty ? null : items.first;
              return SizedBox(
                width: 174,
                child: Material(
                  color: Color(design.shelfColor),
                  borderRadius: BorderRadius.circular(11),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showGenreAisle(genre, items),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (sample != null) CatalogPosterImage(media: sample, fit: BoxFit.cover),
                        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.black87, Colors.black26]))),
                        Padding(
                          padding: const EdgeInsets.all(11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(genre.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: .8, fontSize: 12)),
                              Text('${items.length} titles', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showGenreAisle(String genre, List<MediaItem> items) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$genre aisle'),
        content: SizedBox(
          width: 520,
          height: 470,
          child: items.isEmpty
              ? const Center(child: Text('No owned titles are currently assigned to this genre.'))
              : GridView.builder(
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: .62,
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final media = items[index];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(dialogContext);
                        _openMediaDetails(media);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(7), child: SizedBox(width: double.infinity, child: CatalogPosterImage(media: media, fit: BoxFit.cover)))),
                          const SizedBox(height: 4),
                          Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  Widget _buildStaffPicks(VirtualStoreDesign design) {
    final likedIds = AppController.instance.liked.map((media) => media.id).toSet();
    final liked = _ownedLibrary.where((media) => likedIds.contains(media.id)).toList(growable: false);
    final recent = _ownedLibrary.toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final picks = (liked.isNotEmpty ? liked : recent).take(8).toList(growable: false);
    if (picks.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 12),
      decoration: BoxDecoration(
        color: Color(design.shelfColor).withValues(alpha: .60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(design.accentColor).withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoreSectionHeading(
            title: 'Staff picks',
            subtitle: liked.isNotEmpty ? 'Your liked titles, featured like a video-store recommendation wall' : 'A rotating selection from your owned library',
            icon: Icons.star_rate_rounded,
            accent: Color(design.accentColor),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 135,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: picks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final media = picks[index];
                return SizedBox(
                  width: 220,
                  child: InkWell(
                    onTap: () => _openMediaDetails(media),
                    borderRadius: BorderRadius.circular(10),
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: Color(design.wallColor),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        children: [
                          SizedBox(width: 82, height: double.infinity, child: CatalogPosterImage(media: media, fit: BoxFit.cover)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(liked.isNotEmpty ? 'FAVORITE PICK' : 'FEATURED PICK', style: TextStyle(color: Color(design.accentColor), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .8)),
                                  const SizedBox(height: 5),
                                  Text(media.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  const Text('Open details', style: TextStyle(color: Colors.white60, fontSize: 9)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkway(
    VirtualStoreDesign design,
    List<String> zones,
  ) {
    final sceneMedia = _storePosterLibrary;
    return KeyedSubtree(
      key: _walkwayKey,
      child: VirtualStore3DScene(
      design: design,
      aisles: design.aisles,
      posterMedia: sceneMedia,
      focusedMediaId: _guidedMediaId,
      activeZoneIndex: _safeZoneIndex,
      zoneLabels: zones,
      onZoneChanged: (next) => setState(() {
        _zoneIndex = next;
        _shelfOpen = false;
        _selectedMediaIndex = 0;
        _selectedMediaId = null;
      }),
      onComputerSelected: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const VirtualStoreCatalogComputerScreen()),
      ),
      onEmployeeSelected: _openStoreEmployee,
      onMediaSelected: (media) => unawaited(_inspectMedia(media)),
      ),
    );
  }

  Widget _buildNavigationPanel(VirtualStoreDesign design, List<String> zones) {
    return Card(
      color: Color(design.shelfColor).withValues(alpha: .88),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk_rounded),
                const SizedBox(width: 8),
                const Expanded(child: Text('Walk through the store', style: TextStyle(fontWeight: FontWeight.w900))),
                TextButton(
                  onPressed: _showControls,
                  child: const Text('Controls'),
                ),
              ],
            ),
            Text(
              design.navigationMode == 'easyBrowse'
                  ? 'Tap a zone to browse. Drag the 3D view to look around and use its arrow pad to walk.'
                  : 'Drag the 3D view for a 360° look. Use its on-screen arrow pad to walk; use W/A/S/D or the zone chips to change areas. Press E / Enter to interact.',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var index = 0; index < zones.length; index++)
                  ChoiceChip(
                    label: Text(zones[index]),
                    selected: index == _safeZoneIndex,
                    onSelected: (_) => setState(() {
                      _zoneIndex = index;
                      _shelfOpen = false;
                      _selectedMediaIndex = 0;
                      _selectedMediaId = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dPadButton(Icons.keyboard_arrow_left_rounded, 'Previous zone', () => _shelfOpen ? _cycleMedia(-1) : _selectZone(-1)),
                const SizedBox(width: 8),
                Column(
                  children: [
                    _dPadButton(Icons.keyboard_arrow_up_rounded, 'Previous item / zone', () => _shelfOpen ? _cycleMedia(-1) : _selectZone(-1)),
                    const SizedBox(height: 4),
                    _dPadButton(Icons.keyboard_arrow_down_rounded, 'Next item / zone', () => _shelfOpen ? _cycleMedia(1) : _selectZone(1)),
                  ],
                ),
                const SizedBox(width: 8),
                _dPadButton(Icons.keyboard_arrow_right_rounded, 'Next zone', () => _shelfOpen ? _cycleMedia(1) : _selectZone(1)),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _shelfOpen ? _inspectSelectedMedia : _openCurrentZone,
                  icon: Icon(_shelfOpen ? Icons.open_in_full_rounded : Icons.touch_app_rounded),
                  label: Text(_shelfOpen ? 'Inspect selected' : 'E · Interact'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dPadButton(IconData icon, String tooltip, VoidCallback onPressed) =>
      SizedBox(
        width: 42,
        height: 38,
        child: IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: () {
            onPressed();
            _navigationFocus.requestFocus();
          },
          icon: Icon(icon),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      );

  Widget _buildCurrentZonePanel(VirtualStoreDesign design) {
    final aisle = _currentAisle;
    final aisleCount = design.aisles.length;
    if (_safeZoneIndex == aisleCount) {
      return _buildCollectionsJumpPanel(design);
    }
    if (_safeZoneIndex == aisleCount + 1) {
      return _buildPlaylistsJumpPanel(design);
    }
    if (_safeZoneIndex == aisleCount + 2) {
      return _buildComputerJumpPanel(design);
    }
    if (_safeZoneIndex == aisleCount + 3) {
      return _buildTheaterCorridorPanel(design);
    }
    if (aisle == null) return const SizedBox.shrink();

    final shelves = _shelvesFor(aisle);
    final allItems = _currentAisleItems;
    final selected = _selectedMedia;
    return Card(
      color: Color(design.shelfColor).withValues(alpha: .75),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 7, height: 26, decoration: BoxDecoration(color: Color(aisle.color), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(aisle.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(design.accentColor))),
                ),
                if (_shelfOpen)
                  IconButton(
                    tooltip: 'Return to walkway',
                    onPressed: () => setState(() => _shelfOpen = false),
                    icon: const Icon(Icons.close_fullscreen_rounded),
                  ),
              ],
            ),
            if (aisle.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(aisle.description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            if (!_shelfOpen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.video_library_rounded, size: 28),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${allItems.length} owned titles on these shelves. Press E / Enter or tap Browse aisle to step closer.', style: const TextStyle(fontSize: 12, color: Colors.white70))),
                    FilledButton(onPressed: _openCurrentZone, child: const Text('Browse aisle')),
                  ],
                ),
              )
            else ...[
              for (var shelfIndex = 0; shelfIndex < shelves.length; shelfIndex++)
                _buildShelf(design, shelves[shelfIndex], shelfIndex, allItems),
              if (selected != null)
                Card(
                  color: Color(design.accentColor).withValues(alpha: .13),
                  child: ListTile(
                    leading: SizedBox(width: 42, child: CatalogPosterImage(media: selected, fit: BoxFit.cover)),
                    title: Text(selected.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${selected.type} · ${MediaCaseStyle.canonicalFormat(selected.displayCaseFormat)}'),
                    trailing: FilledButton.icon(
                      onPressed: _inspectSelectedMedia,
                      icon: const Icon(Icons.open_in_full_rounded),
                      label: const Text('Inspect'),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShelf(
    VirtualStoreDesign design,
    _StoreShelfData shelf,
    int shelfIndex,
    List<MediaItem> allItems,
  ) {
    if (shelf.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text('${shelf.title}: no matching owned media yet.', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 7),
          child: Row(
            children: [
              const Icon(Icons.video_library_rounded, size: 17),
              const SizedBox(width: 7),
              Expanded(child: Text(shelf.title, style: const TextStyle(fontWeight: FontWeight.w900))),
              Text('${shelf.items.length} titles', style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          ),
        ),
        SizedBox(
          height: 204,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shelf.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final media = shelf.items[index];
              final selectedIndex = allItems.indexWhere((item) => item.id == media.id);
              final isSelected = media.id == _selectedMediaId ||
                  (_selectedMediaId == null && selectedIndex == _selectedMediaIndex);
              final isPhysical = MediaCaseStyle.canonicalFormat(media.displayCaseFormat) != 'Digital / not recorded';
              return SizedBox(
                width: 116,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMediaIndex = selectedIndex < 0 ? 0 : selectedIndex;
                      _selectedMediaId = media.id;
                    });
                    _navigationFocus.requestFocus();
                  },
                  onDoubleTap: () {
                    setState(() {
                      _selectedMediaIndex = selectedIndex < 0 ? 0 : selectedIndex;
                      _selectedMediaId = media.id;
                    });
                    if (isPhysical) {
                      showAnimatedMediaCaseDialog(
                        context,
                        media: media,
                        animationLevel: design.animationLevel,
                        onOpenTitle: () => _openMediaDetails(media),
                      );
                    } else {
                      _openMediaDetails(media);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: _motionDuration,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isSelected ? Color(design.accentColor).withValues(alpha: .22) : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? Color(design.accentColor) : Colors.white12, width: isSelected ? 2 : 1),
                      boxShadow: isSelected ? [BoxShadow(color: Color(design.accentColor).withValues(alpha: .22), blurRadius: 12)] : const [],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: AnimatedScale(
                            duration: _motionDuration,
                            scale: isSelected ? 1.04 : 1,
                            child: isPhysical
                                ? MediaCase3DView(title: media.title, media: media, width: 100, height: 142)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: CatalogPosterImage(media: media, width: 102, height: 142, fit: BoxFit.cover),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionsJumpPanel(VirtualStoreDesign design) => Card(
        color: Color(design.shelfColor).withValues(alpha: .8),
        child: ListTile(
          leading: const Icon(Icons.collections_bookmark_rounded, size: 32),
          title: const Text('Collection Gallery', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('Physical box sets and curated digital collections · ${design.collectionGalleryPlacement}'),
          trailing: const Icon(Icons.arrow_downward_rounded),
          onTap: () {
            final target = _collectionsKey.currentContext;
            if (target != null) Scrollable.ensureVisible(target, duration: _motionDuration);
          },
        ),
      );

  Widget _buildPlaylistsJumpPanel(VirtualStoreDesign design) => Card(
        color: Color(design.shelfColor).withValues(alpha: .8),
        child: ListTile(
          leading: const Icon(Icons.queue_music_rounded, size: 32),
          title: const Text('Listening Lounge', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: const Text('Playlists are virtual music collections, not physical disc cases.'),
          trailing: const Icon(Icons.arrow_downward_rounded),
          onTap: () {
            final target = _playlistsKey.currentContext;
            if (target != null) {
              Scrollable.ensureVisible(target, duration: _motionDuration);
            }
          },
        ),
      );

  Widget _buildComputerJumpPanel(VirtualStoreDesign design) => Card(
        color: Color(design.shelfColor).withValues(alpha: .88),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.computer_rounded, size: 30, color: Color(design.accentColor)), const SizedBox(width: 9), const Text('Catalog Computer', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))]),
              const SizedBox(height: 6),
              const Text('Search your collection by movie, show, DVD, Blu-ray, 4K Ultra HD, CD, album or track. Ask the computer for a suggestion by mood, runtime or favorites.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VirtualStoreCatalogComputerScreen())),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Use catalog computer'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openStoreEmployee,
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('Ask the employee'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildTheaterCorridorPanel(VirtualStoreDesign design) => Card(
        color: Color(design.shelfColor).withValues(alpha: .86),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.meeting_room_rounded, size: 34, color: Color(design.accentColor)),
              const SizedBox(height: 8),
              Text('Private Theater Corridor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(design.accentColor))),
              const SizedBox(height: 5),
              const Text('Step out of the store aisles and manage Room 1, Room 2, Room 3, Room 4, and any rooms you add.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TheaterHomeScreen())),
                icon: const Icon(Icons.door_front_door_rounded),
                label: const Text('Enter Theater Rooms'),
              ),
            ],
          ),
        ),
      );

  Widget _buildCuratedCollections(VirtualStoreDesign design) {
    final collections = design.curatedCollections;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoreSectionHeading(
            title: 'Curated digital collections',
            subtitle: 'Your own themed groups of owned titles. They stay digital and do not pretend to be physical box sets.',
            icon: Icons.collections_bookmark_rounded,
            accent: Color(design.accentColor),
          ),
          if (collections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Create themed groups in Customize App → Virtual Store → Digital collections.', style: TextStyle(color: Colors.white60, fontSize: 12)),
            )
          else
            SizedBox(
              height: 164,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: collections.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final collection = collections[index];
                  final items = _ownedLibrary.where((media) => collection.mediaIds.contains(media.id)).toList(growable: false);
                  return SizedBox(
                    width: 220,
                    child: Card(
                      color: Color(design.shelfColor),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openDigitalCollection(collection),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 88,
                              height: double.infinity,
                              child: collection.artworkUrl.trim().isNotEmpty
                                  ? Image.network(collection.artworkUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.collections_bookmark_rounded, size: 36))
                                  : items.isNotEmpty
                                      ? CatalogPosterImage(media: items.first, fit: BoxFit.cover)
                                      : const Icon(Icons.collections_bookmark_rounded, size: 36),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('DIGITAL COLLECTION', style: TextStyle(fontSize: 8, letterSpacing: 1, color: Colors.white60, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 5),
                                    Text(collection.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 6),
                                    Text('${items.length} titles', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
  }

  Widget _buildPhysicalCollections(List<MediaCollection> physicalCollections, VirtualStoreDesign design) {
    return Container(
      key: _collectionsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        _StoreSectionHeading(
          title: 'Physical box-set gallery',
          subtitle: 'Placed at ${design.collectionGalleryPlacement.toLowerCase()}. Open a physical box to reveal its indexed discs and programs.',
          icon: Icons.inventory_2_rounded,
          accent: Color(design.accentColor),
        ),
        if (physicalCollections.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Physical collections appear here when owned titles share a physical release or collection ID.', style: TextStyle(color: Colors.white60, fontSize: 12)),
          )
        else
          Column(
            children: [
              for (final collection in physicalCollections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CollectionBox(
                    collection: collection,
                    onTap: () => _openPhysicalCollection(collection),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListeningLounge(VirtualStoreDesign design) {
    final playlists = _playlists;
    final allTracks = <MusicTrack>{..._music.tracks, ..._music.catalogTracks.values};
    return Container(
      key: _playlistsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoreSectionHeading(
            title: 'Music listening lounge',
            subtitle: 'Playlists are arranged like listening cards and album sleeves—not as physical CDs unless an owned physical CD edition exists.',
            icon: Icons.headphones_rounded,
            accent: Color(design.accentColor),
          ),
          Builder(builder: (context) {
            final albums = _ownedLibrary.where((media) {
              final type = media.type.toLowerCase().replaceAll('_', ' ');
              return type.contains('album') || type.contains('music');
            }).toList(growable: false);
            if (albums.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('ALBUM WALL', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                ),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: albums.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 9),
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return SizedBox(
                        width: 112,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MediaDetailsScreen(media: album))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: double.infinity, child: CatalogPosterImage(media: album, fit: BoxFit.cover)))),
                              const SizedBox(height: 5),
                              Text(album.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MusicScreen())), icon: const Icon(Icons.library_music_rounded), label: const Text('Open full music library'))),
                const SizedBox(height: 12),
              ],
            );
          }),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Your custom and smart playlists will appear here after they are created in Music.', style: TextStyle(color: Colors.white60, fontSize: 12)),
            )
          else
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: playlists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final tracks = playlist.trackIds
                      .map((id) => allTracks.where((track) => track.id == id).isEmpty
                          ? null
                          : allTracks.firstWhere((track) => track.id == id))
                      .whereType<MusicTrack>()
                      .toList(growable: false);
                  final artworkTracks = tracks.where((track) => track.artworkUrl?.trim().isNotEmpty == true);
                  final artwork = artworkTracks.isEmpty ? null : artworkTracks.first.artworkUrl;
                  return SizedBox(
                    width: 154,
                    child: InkWell(
                      onTap: () => _openPlaylist(playlist),
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        color: Color(design.shelfColor),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (artwork != null)
                                    Image.network(artwork, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF283040), child: Icon(Icons.queue_music_rounded, size: 42)))
                                  else
                                    const ColoredBox(color: Color(0xFF283040), child: Icon(Icons.queue_music_rounded, size: 42)),
                                  Positioned(
                                    left: 6,
                                    top: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(99)),
                                      child: Text(playlist.isSmart ? 'SMART MIX' : 'PLAYLIST', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .7)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('${tracks.length} tracks', style: const TextStyle(color: Colors.white70, fontSize: 9)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showControls() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Virtual Store controls'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('W / ↑  ·  Move to previous zone'),
            Text('S / ↓  ·  Move to next zone'),
            Text('A / ←  ·  Move left / previous item'),
            Text('D / →  ·  Move right / next item'),
            Text('E / Enter  ·  Interact with aisle or inspect selected case'),
            Text('Esc  ·  Close the shelf view'),
            SizedBox(height: 10),
            Text('Mouse / touch: tap a zone, tap a case to select it, then use Inspect. Double-tap a case to open it.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _StoreInteriorWall extends StatelessWidget {
  const _StoreInteriorWall({required this.design, required this.posterMedia});

  final VirtualStoreDesign design;
  final List<MediaItem> posterMedia;

  MediaItem? _mediaForPoster(Map<String, dynamic> poster, int fallbackIndex) {
    final requestedId = poster['mediaId']?.toString();
    if (requestedId != null && requestedId.isNotEmpty) {
      for (final media in posterMedia) {
        if (media.id == requestedId) return media;
      }
    }
    return fallbackIndex < posterMedia.length ? posterMedia[fallbackIndex] : null;
  }

  @override
  Widget build(BuildContext context) {
    final configuredPosters = design.showWallPosters
        ? design.layoutElements
            .where((item) => item['type']?.toString() == 'poster' || item['type']?.toString() == 'standee')
            .toList(growable: false)
        : <Map<String, dynamic>>[];
    final posters = configuredPosters.isNotEmpty
        ? configuredPosters
        : (design.showWallPosters
            ? (posterMedia.toList()..shuffle(math.Random(DateTime.now().day + design.name.hashCode)))
                .take(12)
                .map((media) => <String, dynamic>{
                  'label': media.title,
                  'mediaId': media.id,
                  'placement': 'Around the store',
                }).toList(growable: false)
            : <Map<String, dynamic>>[]);
    final posterGroups = <String, List<Map<String, dynamic>>>{};
    for (final poster in posters) {
      final location = poster['placement']?.toString().trim();
      final label = location == null || location.isEmpty ? 'Around the store' : location;
      (posterGroups[label] ??= <Map<String, dynamic>>[]).add(poster);
    }

    final banners = design.showHangingBanners
        ? design.layoutElements.where((item) => item['type']?.toString() == 'hangingBanner').toList(growable: false)
        : <Map<String, dynamic>>[];
    final bannerItems = banners.isEmpty && design.showHangingBanners
        ? const <Map<String, dynamic>>[
            {'label': 'MOVIES & FILMS', 'placement': 'Overhead · front aisle'},
            {'label': 'TV SHOWS & SPECIALS', 'placement': 'Overhead · center aisle'},
            {'label': 'MUSIC & ALBUMS', 'placement': 'Overhead · music aisle'},
          ]
        : banners;

    return Container(
      decoration: BoxDecoration(
        color: Color(design.wallColor),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(design.accentColor).withValues(alpha: .6)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(design.shelfColor), Color(design.wallColor)]),
            ),
            child: Column(
              children: [
                if (design.logoUrl.trim().isNotEmpty)
                  Image.network(design.logoUrl, height: 36, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                Text(design.name.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(color: Color(design.accentColor), fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(design.greeting, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          if (bannerItems.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(design.wallColor), Color(design.shelfColor).withValues(alpha: .8)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 2, bottom: 7),
                    child: Text('HANGING AISLE SIGNS', style: TextStyle(fontSize: 8, letterSpacing: 1.4, color: Colors.white60, fontWeight: FontWeight.w900)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final banner in bannerItems)
                        SizedBox(
                          width: 104,
                          child: Column(
                            children: [
                              Transform(
                                alignment: Alignment.topCenter,
                                transform: Matrix4.identity()..setEntry(3, 2, .001)..rotateX(-.05),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Color(design.accentColor),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
                                  ),
                                  child: Text(banner['label']?.toString().toUpperCase() ?? 'IN YOUR COLLECTION', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .7)),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(banner['placement']?.toString().toUpperCase() ?? 'OVERHEAD AISLE', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 6, color: Colors.white54, letterSpacing: .6)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (design.showWallPosters)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(design.wallColor), Color(design.shelfColor).withValues(alpha: .72), Color(design.wallColor)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 2, bottom: 7),
                    child: Text('FRAMED POSTERS & STANDEES AROUND THE STORE', style: TextStyle(fontSize: 8, letterSpacing: 1.2, color: Colors.white60, fontWeight: FontWeight.w900)),
                  ),
                  if (posterGroups.isEmpty)
                    const Text('Add owned-media posters in Customize App → Virtual Store → Store displays.', style: TextStyle(fontSize: 11, color: Colors.white60))
                  else
                    for (final group in posterGroups.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group.key.toUpperCase(), style: TextStyle(fontSize: 7, letterSpacing: 1.1, color: Color(design.accentColor), fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (var index = 0; index < group.value.length; index++)
                                    SizedBox(
                                      width: 82,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: _FramedStorePoster(
                                          media: _mediaForPoster(group.value[index], index),
                                          label: group.value[index]['label']?.toString() ?? 'From your collection',
                                          location: group.value[index]['placement']?.toString() ?? 'Store wall',
                                          accent: Color(design.accentColor),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          if (design.layoutElements.any((item) => item['type']?.toString() == 'neonSign' || item['type']?.toString() == 'decoration'))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final element in design.layoutElements.where((item) => item['type']?.toString() == 'neonSign' || item['type']?.toString() == 'decoration'))
                    Chip(avatar: const Icon(Icons.auto_awesome_rounded, size: 14), label: Text(element['label']?.toString() ?? 'Store display')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FramedStorePoster extends StatelessWidget {
  const _FramedStorePoster({
    this.media,
    required this.label,
    required this.location,
    required this.accent,
  });

  final MediaItem? media;
  final String label;
  final String location;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: .68,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0D0F),
                border: Border.all(color: accent, width: 2),
                borderRadius: BorderRadius.circular(5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 8,
                    offset: Offset(2, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (media != null)
                      CatalogPosterImage(media: media!, fit: BoxFit.cover)
                    else
                      ColoredBox(
                        color: const Color(0xFF252A35),
                        child: Icon(Icons.local_movies_rounded, color: accent, size: 28),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        color: Colors.black.withValues(alpha: .78),
                        child: Text(
                          media?.title ?? label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            location.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 7,
              letterSpacing: .8,
              color: Colors.white60,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
}

class _StoreSectionHeading extends StatelessWidget {
  const _StoreSectionHeading({required this.title, required this.subtitle, required this.icon, required this.accent});

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StoreShelfData {
  const _StoreShelfData({required this.title, required this.items});
  final String title;
  final List<MediaItem> items;
}

class _StorePlaylistData {
  const _StorePlaylistData({required this.name, required this.trackIds, required this.isSmart});
  final String name;
  final List<String> trackIds;
  final bool isSmart;
}
