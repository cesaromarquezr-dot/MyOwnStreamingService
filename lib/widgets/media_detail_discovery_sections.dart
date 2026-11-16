import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_core.dart';
import '../core/services/cinematic_title_metadata_service.dart'
    as cinematic_metadata;
import '../featured_soundtrack_catalog.dart';
import '../media_recommendation_kinds.dart';
import '../recommendation_ownership.dart';
import '../music.dart' show SoundtrackUniverseScreen;
import 'media_detail_arrow_rail.dart';

/// Discovery shelves and library memberships shown on a media details page.
/// Provider-derived shelves use stable TMDB IDs; local shelves use only
/// metadata already indexed in the active profile's library.
class MediaDetailDiscoverySections extends StatefulWidget {
  const MediaDetailDiscoverySections({
    super.key,
    required this.media,
    required this.onOpenMedia,
    this.metadata,
  });

  final MediaItem media;
  final cinematic_metadata.CinematicTitleMetadata? metadata;
  final ValueChanged<MediaItem> onOpenMedia;

  @override
  State<MediaDetailDiscoverySections> createState() =>
      _MediaDetailDiscoverySectionsState();
}

class _PersonShelf {
  const _PersonShelf({required this.name, required this.items});
  final String name;
  final List<MediaItem> items;
}

class _StudioShelf {
  const _StudioShelf({required this.name, required this.items});
  final String name;
  final List<MediaItem> items;
}

class _MediaDetailDiscoverySectionsState
    extends State<MediaDetailDiscoverySections> {
  bool _loading = false;
  List<MediaItem> _suggested = const <MediaItem>[];
  List<_PersonShelf> _people = const <_PersonShelf>[];
  List<_StudioShelf> _studios = const <_StudioShelf>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant MediaDetailDiscoverySections oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.id != widget.media.id ||
        oldWidget.metadata?.providerId != widget.metadata?.providerId) {
      _refresh();
    }
  }

  String _normal(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[\s\-_.,:;!?()\[\]{}\\/]+'), '');

  List<MediaItem> _accessibleLibrary() {
    final app = AppController.instance;
    final profile = app.currentProfile;
    return app.library
        .where((item) =>
            item.id != widget.media.id &&
            item.isAccessibleTo(profile) &&
            !item.isBonusContent)
        .toList(growable: false);
  }

  int _similarity(MediaItem candidate, MediaItem source) {
    final candidateFields = <String>{
      ...candidate.genres,
      ...candidate.tags,
      ...candidate.themes,
    }.map(_normal).where((v) => v.isNotEmpty).toSet();
    final sourceFields = <String>{
      ...source.genres,
      ...source.tags,
      ...source.themes,
    }.map(_normal).where((v) => v.isNotEmpty).toSet();
    var score = candidateFields.intersection(sourceFields).length * 5;
    final candidatePeople = <String>{
      ...candidate.actors,
      ...candidate.directors,
      ...candidate.writers,
      ...candidate.music,
    }.map(_normal).where((v) => v.isNotEmpty).toSet();
    final sourcePeople = <String>{
      ...source.actors,
      ...source.directors,
      ...source.writers,
      ...source.music,
    }.map(_normal).where((v) => v.isNotEmpty).toSet();
    score += candidatePeople.intersection(sourcePeople).length * 8;
    final candidateCompanies = <String>{
      ...candidate.studios,
      ...candidate.companies,
    }.map(_normal).where((v) => v.isNotEmpty).toSet();
    final sourceCompanies = <String>{
      ...source.studios,
      ...source.companies,
    }.map(_normal).where((v) => v.isNotEmpty).toSet();
    score += candidateCompanies.intersection(sourceCompanies).length * 4;
    final franchise = _normal(source.franchiseName ?? '');
    if (franchise.isNotEmpty &&
        franchise == _normal(candidate.franchiseName ?? '')) {
      score += 7;
    }
    if (candidate.type.toLowerCase() == source.type.toLowerCase()) score += 1;
    return score;
  }

  List<MediaItem> _localSuggestions() {
    final candidates = _accessibleLibrary()
        .map((item) => (item: item, score: _similarity(item, widget.media)))
        .where((entry) => entry.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return candidates
        .take(12)
        .map((entry) => entry.item)
        .toList(growable: false);
  }

  List<MediaItem> _localItemsForPerson(String personName) {
    final wanted = _normal(personName);
    if (wanted.isEmpty) return const <MediaItem>[];
    return _accessibleLibrary()
        .where((candidate) {
          final credits = <String>{
            ...candidate.actors,
            ...candidate.directors,
            ...candidate.writers,
            ...candidate.music,
          }.map(_normal);
          return credits.contains(wanted);
        })
        .take(12)
        .toList(growable: false);
  }

  List<MediaItem> _localItemsForCompany(String companyName) {
    final wanted = _normal(companyName);
    if (wanted.isEmpty) return const <MediaItem>[];
    return _accessibleLibrary()
        .where((candidate) {
          final companies = <String>{
            ...candidate.studios,
            ...candidate.companies,
          }.map(_normal);
          return companies.contains(wanted);
        })
        .take(16)
        .toList(growable: false);
  }

  MediaItem _toMediaItem(cinematic_metadata.CinematicTitleRecommendation item) {
    final date = DateTime.tryParse(item.releaseDate ?? '');
    return MediaItem(
      id: 'tmdb:${item.isTv ? 'tv' : 'movie'}:${item.providerId}',
      title: item.title,
      type: item.isTv ? 'tv_show' : 'movie',
      imageUrl: item.posterUrl,
      description: item.overview,
      releaseYear: date?.year,
      rating: item.voteAverage,
    );
  }

  List<MediaItem> _unique(List<MediaItem> items) {
    final seen = <String>{};
    return items.where((item) {
      final key =
          '${_normal(item.title)}|${item.releaseYear ?? 0}|${item.type.toLowerCase()}';
      return item.id != widget.media.id &&
          key.trim().isNotEmpty &&
          seen.add(key);
    }).toList(growable: false);
  }

  Future<List<MediaItem>> _musicAlbumsForArtist(String artistName) async {
    final app = AppController.instance;
    if (!app.isBackendAuthenticated || artistName.trim().isEmpty) {
      return const <MediaItem>[];
    }
    try {
      final search = await app.backendApi.searchMusicCatalog(
        artistName,
        type: 'artist',
        limit: 5,
      );
      final spotify = search['spotify'] is Map
          ? Map<String, dynamic>.from(search['spotify'] as Map)
          : <String, dynamic>{};
      final rawArtists = spotify['artists'];
      final artists = rawArtists is List
          ? rawArtists
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];
      final wanted = _normal(artistName);
      Map<String, dynamic>? artist;
      for (final candidate in artists) {
        if (_normal(candidate['name']?.toString() ?? '') == wanted) {
          artist = candidate;
          break;
        }
      }
      if (artist == null && artists.length == 1) artist = artists.first;
      final spotifyId = artist?['id']?.toString().trim() ?? '';
      if (spotifyId.isEmpty) return const <MediaItem>[];

      final page = await app.backendApi.getSpotifyArtistAlbums(
        spotifyId,
        limit: 10,
        offset: 0,
      );
      final rawAlbums = page['items'];
      if (rawAlbums is! List) return const <MediaItem>[];
      final output = <MediaItem>[];
      final seen = <String>{};
      for (final row in rawAlbums.whereType<Map>()) {
        final album = Map<String, dynamic>.from(row);
        final id = album['id']?.toString().trim() ?? '';
        final title =
            (album['title'] ?? album['name'])?.toString().trim() ?? '';
        final imageUrl =
            (album['imageUrl'] ?? album['coverArtUrl'])?.toString().trim() ??
                '';
        if (id.isEmpty || title.isEmpty) continue;
        final key = _normal(title);
        if (key.isEmpty || !seen.add(key)) continue;
        final releaseDate = DateTime.tryParse(
            (album['releaseDate'] ?? album['release_date'])?.toString() ?? '');
        output.add(MediaItem(
          id: 'spotify:album:$id',
          title: title,
          type: 'album',
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
          description: '$artistName · Music catalog recommendation',
          releaseYear: releaseDate?.year,
          music: <String>[artistName],
        ));
      }
      return output;
    } catch (_) {
      return const <MediaItem>[];
    }
  }

  Future<List<_PersonShelf>> _loadMusicCreditShelves({
    List<String> providerArtists = const <String>[],
  }) async {
    final names = <String>{
      ...widget.media.music,
      ...providerArtists,
      // Some cast members are also recording artists. Exact artist-name
      // matching in _musicAlbumsForArtist prevents arbitrary actor names from
      // being treated as musicians when the music catalog has no match.
      ...widget.media.actors.take(4),
    }.map((value) => value.trim()).where((value) => value.isNotEmpty).take(5);
    final shelves = <_PersonShelf>[];
    for (final artist in names) {
      final local = _localItemsForPerson(artist)
          .where((item) =>
              RecommendationMediaKinds.classify(item) ==
              RecommendationMediaKind.musicAlbum)
          .toList(growable: false);
      final remote = await _musicAlbumsForArtist(artist);
      final items = _unique(<MediaItem>[...local, ...remote]);
      if (items.isNotEmpty) {
        shelves.add(_PersonShelf(name: artist, items: items));
      }
    }
    return shelves;
  }

  List<_PersonShelf> _mergePersonShelves(
    Iterable<_PersonShelf> first,
    Iterable<_PersonShelf> second,
  ) {
    final merged = <String, List<MediaItem>>{};
    final labels = <String, String>{};
    for (final shelf in <_PersonShelf>[...first, ...second]) {
      final key = _normal(shelf.name);
      if (key.isEmpty) continue;
      labels.putIfAbsent(key, () => shelf.name);
      merged.putIfAbsent(key, () => <MediaItem>[]).addAll(shelf.items);
    }
    return merged.entries
        .map((entry) => _PersonShelf(
              name: labels[entry.key] ?? entry.key,
              items: _unique(entry.value),
            ))
        .where((shelf) => shelf.items.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    final provider = widget.metadata;
    final localSuggestions = _localSuggestions();
    if (provider == null ||
        !cinematic_metadata.CinematicTitleMetadataService.isConfigured) {
      final localPeople = _buildLocalPeople();
      final musicPeople = await _loadMusicCreditShelves();
      if (!mounted) return;
      setState(() {
        _suggested = localSuggestions;
        _people = _mergePersonShelves(localPeople, musicPeople);
        _studios = _buildLocalStudios();
        _loading = false;
      });
      return;
    }

    final sourceProviderId = provider.providerId;
    setState(() => _loading = true);
    try {
      final groupsFuture = cinematic_metadata.CinematicTitleMetadataService
          .lookupPersonalizedRecommendationGroups(source: provider, limit: 12);
      final castCredits = provider.castCredits
          .where((credit) =>
              credit.personId != null && credit.name.trim().isNotEmpty)
          .take(4)
          .toList(growable: false);
      final crewCredits = provider.crewCredits
          .where((credit) {
            final job = credit.job.toLowerCase();
            return credit.personId != null &&
                credit.name.trim().isNotEmpty &&
                (job.contains('director') ||
                    job.contains('producer') ||
                    job.contains('writer') ||
                    job.contains('composer'));
          })
          .take(3)
          .toList(growable: false);

      final personCredits = <({
        String name,
        Future<List<cinematic_metadata.CinematicTitleRecommendation>> future
      })>[];
      final seenPeople = <int>{};
      for (final credit in <Object>[...castCredits, ...crewCredits]) {
        final id = credit is cinematic_metadata.CinematicCastCredit
            ? credit.personId
            : (credit as cinematic_metadata.CinematicCrewCredit).personId;
        final name = credit is cinematic_metadata.CinematicCastCredit
            ? credit.name
            : (credit as cinematic_metadata.CinematicCrewCredit).name;
        if (id == null || !seenPeople.add(id)) continue;
        personCredits.add((
          name: name,
          future: cinematic_metadata.CinematicTitleMetadataService
              .lookupPersonCredits(personId: id, limit: 12),
        ));
      }

      final companyCredits = provider.companies.take(4).toList(growable: false);
      final companyFutures = companyCredits
          .map((company) => cinematic_metadata.CinematicTitleMetadataService
                  .lookupCompanyRecommendations(
                companyId: company.id,
                isNetwork: company.isNetwork,
                limit: 12,
              ))
          .toList(growable: false);

      final groups = await groupsFuture;
      final remotePeople =
          await Future.wait(personCredits.map((entry) => entry.future));
      final remoteCompanies = await Future.wait(companyFutures);
      if (!mounted) return;

      final similar = <MediaItem>[
        ...localSuggestions,
        ...(groups['similar'] ??
                const <cinematic_metadata.CinematicTitleRecommendation>[])
            .map(_toMediaItem),
      ];
      final people = <_PersonShelf>[];
      for (var index = 0; index < personCredits.length; index++) {
        final name = personCredits[index].name;
        final local = _localItemsForPerson(name);
        final remote = remotePeople[index]
            .where((item) => item.providerId != sourceProviderId)
            .map(_toMediaItem);
        final items = _unique(<MediaItem>[...local, ...remote]);
        if (items.isNotEmpty) {
          people.add(_PersonShelf(name: name, items: items));
        }
      }

      final studios = <_StudioShelf>[];
      for (var index = 0; index < companyCredits.length; index++) {
        final company = companyCredits[index];
        final local = _localItemsForCompany(company.name);
        final remote = remoteCompanies[index].map(_toMediaItem);
        final items = _unique(<MediaItem>[...local, ...remote]);
        if (items.isNotEmpty) {
          studios.add(_StudioShelf(name: company.name, items: items));
        }
      }
      final musicPeople = await _loadMusicCreditShelves(
        providerArtists: provider.music,
      );

      setState(() {
        _suggested = _unique(similar).take(16).toList(growable: false);
        _people = _mergePersonShelves(people, musicPeople);
        _studios = studios;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggested = localSuggestions;
        _people = _buildLocalPeople();
        _studios = _buildLocalStudios();
        _loading = false;
      });
    }
  }

  List<_PersonShelf> _buildLocalPeople() {
    final names = <String>{
      ...widget.media.actors.take(4),
      ...widget.media.directors.take(2),
      ...widget.media.writers.take(2),
      ...widget.media.music.take(2),
    };
    return names
        .map((name) =>
            _PersonShelf(name: name, items: _localItemsForPerson(name)))
        .where((shelf) => shelf.items.isNotEmpty)
        .toList(growable: false);
  }

  List<_StudioShelf> _buildLocalStudios() {
    final names = <String>{...widget.media.studios, ...widget.media.companies};
    return names
        .map((name) =>
            _StudioShelf(name: name, items: _localItemsForCompany(name)))
        .where((shelf) => shelf.items.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _collectionNames() {
    final controller = AppController.instance;
    final names = controller.collections
        .where((collection) => collection.mediaIds.contains(widget.media.id))
        .map((collection) => collection.name)
        .toList(growable: false);
    final discName = widget.media.discCollectionTitle?.trim() ?? '';
    if (discName.isNotEmpty && !names.contains(discName)) {
      names.insert(0, discName);
    }
    return names;
  }

  Widget _sectionTitle(String title, {String? subtitle}) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ]),
      );

  Widget _posterRail(List<MediaItem> items,
      {String semanticLabel = 'related titles'}) {
    if (items.isEmpty) return const SizedBox.shrink();
    final controller = AppController.instance;
    return MediaDetailArrowRail(
      height: 226,
      semanticLabel: semanticLabel,
      children: items.map((item) {
        final image = item.imageUrl?.trim() ?? '';
        final kind = RecommendationMediaKinds.classify(item);
        final ownedRecord =
            RecommendationOwnershipMatcher.findOwnedMediaForMedia(
          media: item,
          controller: controller,
        );
        final isOwned = ownedRecord != null;
        final isWatched = isOwned &&
            kind != RecommendationMediaKind.musicAlbum &&
            controller.watched.any((entry) => entry.id == ownedRecord.id);
        return SizedBox(
          width: 122,
          child: InkWell(
            onTap: () => widget.onOpenMedia(item),
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 122,
                    height: 150,
                    child: Stack(fit: StackFit.expand, children: [
                      if (image.startsWith('http'))
                        Image.network(
                          image,
                          fit: kind == RecommendationMediaKind.musicAlbum
                              ? BoxFit.contain
                              : BoxFit.cover,
                          errorBuilder: (_, __, ___) => _posterFallback(item),
                        )
                      else
                        _posterFallback(item),
                      Positioned(
                        left: 5,
                        top: 5,
                        child: RecommendationOwnershipBadge(
                          isOwned: isOwned,
                          isWatched: isWatched,
                          watchedLabel: 'Watched',
                          showWatchState:
                              kind != RecommendationMediaKind.musicAlbum,
                          compact: true,
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  RecommendationMediaKinds.label(kind).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB9AEFF),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700)),
                Text(
                  item.releaseYear?.toString() ??
                      (kind == RecommendationMediaKind.musicAlbum
                          ? (item.music.isEmpty
                              ? 'Album'
                              : item.music.join(', '))
                          : item.type.toUpperCase()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  List<FeaturedSoundtrackEntry> _featuredMusicForCurrentMedia() {
    final titleCandidates = <String>{
      widget.media.title,
      if ((widget.media.originalTitle ?? '').trim().isNotEmpty)
        widget.media.originalTitle!.trim(),
      if ((widget.media.canonicalTitle ?? '').trim().isNotEmpty)
        widget.media.canonicalTitle!.trim(),
    };
    final parentId = widget.media.parentMediaId?.trim() ?? '';
    if (parentId.isNotEmpty) {
      for (final candidate in AppController.instance.library) {
        if (candidate.id == parentId) {
          titleCandidates.add(candidate.title);
          if ((candidate.originalTitle ?? '').trim().isNotEmpty) {
            titleCandidates.add(candidate.originalTitle!.trim());
          }
          break;
        }
      }
    }
    final matches = <String, FeaturedSoundtrackEntry>{};
    for (final title in titleCandidates) {
      for (final entry in FeaturedSoundtrackCatalog.forMediaTitle(title)) {
        matches[entry.key] = entry;
      }
    }
    return matches.values.toList(growable: false);
  }

  Future<void> _openExternal(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Details discovery remains usable even when an external app cannot open.
    }
  }

  Widget _featuredMusicRail(List<FeaturedSoundtrackEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return MediaDetailArrowRail(
      height: 162,
      spacing: 10,
      semanticLabel: 'featured music and artists',
      children: entries.map((entry) {
        final searchUrl =
            'https://open.spotify.com/search/${Uri.encodeComponent('${entry.title} ${entry.artist}')}';
        return SizedBox(
          width: 236,
          child: Card(
            margin: EdgeInsets.zero,
            color: const Color(0xFF191922),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF30243F),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.music_note_rounded,
                            color: Color(0xFFD6B5FF), size: 23),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(entry.artist,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(entry.relationshipLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFD6B5FF),
                          fontWeight: FontWeight.w800)),
                  if ((entry.placementNote ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(entry.placementNote!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white54)),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _openExternal(searchUrl),
                        icon: const Icon(Icons.headphones_rounded, size: 14),
                        label: const Text('Find song'),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            minimumSize: const Size(0, 27),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(fontSize: 10)),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Open soundtrack source: ${entry.sourceName}',
                        onPressed: () => _openExternal(entry.sourceUrl),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                            width: 28, height: 28),
                        icon: const Icon(Icons.open_in_new_rounded,
                            size: 15, color: Colors.white60),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _membershipRail(List<String> names) {
    if (names.isEmpty) return const SizedBox.shrink();
    return MediaDetailArrowRail(
      height: 54,
      spacing: 8,
      semanticLabel: 'collections',
      children: names
          .map((name) => Chip(
                avatar:
                    const Icon(Icons.collections_bookmark_outlined, size: 16),
                label: Text(name),
              ))
          .toList(growable: false),
    );
  }

  Widget _posterFallback(MediaItem item) => Container(
        color: const Color(0xFF24242B),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Text(item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final collections = _collectionNames();
    final featuredMusic = _featuredMusicForCurrentMedia();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (featuredMusic.isNotEmpty) ...[
        _sectionTitle(
          'Featured Music and Artist',
          subtitle:
              'Featured songs, score albums and artists connected to this film or series.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => SoundtrackUniverseScreen(
                initialMediaTitle: widget.media.title,
              ),
            )),
            icon: const Icon(Icons.explore_rounded, size: 17),
            label: const Text('Explore all soundtracks'),
          ),
        ),
        _featuredMusicRail(featuredMusic),
      ],
      if (_suggested.isNotEmpty) ...[
        _sectionTitle('Titles You Might Like on Your Own Streaming Service',
            subtitle:
                'Based on the genres, people, studios and story details available for this title.'),
        _posterRail(_suggested, semanticLabel: 'titles you might like'),
      ],
      if (_people.isNotEmpty) ...[
        _sectionTitle('More from this Cast & Crew',
            subtitle:
                'Separate Film, TV Show, and Music Album recommendations from the same credited people; each card shows whether you own it.'),
        for (final person in _people) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text('More from ${person.name}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70)),
          ),
          for (final kind in RecommendationMediaKinds.displayOrder)
            if ((RecommendationMediaKinds.group(person.items)[kind] ??
                    const <MediaItem>[])
                .isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  RecommendationMediaKinds.pluralLabel(kind),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB9AEFF),
                  ),
                ),
              ),
              _posterRail(
                RecommendationMediaKinds.group(person.items)[kind]!,
                semanticLabel:
                    '${RecommendationMediaKinds.pluralLabel(kind)} from ${person.name}',
              ),
            ],
        ],
      ],
      if (_studios.isNotEmpty) ...[
        _sectionTitle('More from this Studio',
            subtitle:
                'Movies and television connected to the same production company or network, plus matching local titles.'),
        for (final studio in _studios) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text('More from ${studio.name}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70)),
          ),
          _posterRail(studio.items, semanticLabel: 'more from ${studio.name}'),
        ],
      ],
      if (collections.isNotEmpty) ...[
        _sectionTitle('This title appears in',
            subtitle:
                'Collections and physical media groupings containing this item.'),
        _membershipRail(collections),
      ],
      if (_loading && _suggested.isEmpty && _people.isEmpty && _studios.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
    ]);
  }
}
