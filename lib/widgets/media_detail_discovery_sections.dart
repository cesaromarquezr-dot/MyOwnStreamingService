import 'package:material_ui/material_ui.dart';

import '../app_core.dart';
import '../core/services/cinematic_title_metadata_service.dart'
    as cinematic_metadata;
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
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

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

  Future<void> _refresh() async {
    final provider = widget.metadata;
    final localSuggestions = _localSuggestions();
    if (provider == null ||
        !cinematic_metadata.CinematicTitleMetadataService.isConfigured) {
      if (!mounted) return;
      setState(() {
        _suggested = localSuggestions;
        _people = _buildLocalPeople();
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

      setState(() {
        _suggested = _unique(similar).take(16).toList(growable: false);
        _people = people;
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
    return MediaDetailArrowRail(
      height: 206,
      semanticLabel: semanticLabel,
      children: items.map((item) {
        final image = item.imageUrl?.trim() ?? '';
        return SizedBox(
          width: 116,
          child: InkWell(
            onTap: () => widget.onOpenMedia(item),
            borderRadius: BorderRadius.circular(10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 116,
                  height: 154,
                  child: image.startsWith('http')
                      ? Image.network(image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _posterFallback(item))
                      : _posterFallback(item),
                ),
              ),
              const SizedBox(height: 6),
              Text(item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
              Text(item.releaseYear?.toString() ?? item.type.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.white54)),
            ]),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_suggested.isNotEmpty) ...[
        _sectionTitle('Titles You Might Like on Your Own Streaming Service',
            subtitle:
                'Based on the genres, people, studios and story details available for this title.'),
        _posterRail(_suggested, semanticLabel: 'titles you might like'),
      ],
      if (_people.isNotEmpty) ...[
        _sectionTitle('More from this Cast & Crew',
            subtitle:
                'Other movies and shows credited to the same people, plus matching items indexed in your library.'),
        for (final person in _people) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text('More from ${person.name}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70)),
          ),
          _posterRail(person.items, semanticLabel: 'more from ${person.name}'),
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
