import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_core.dart';
import 'actor_connections.dart';
import 'core/services/cinematic_person_metadata_service.dart';
import 'media_metadata_catalog_screen.dart';

/// Kinds of catalog entities that can have a browsable profile.
enum CatalogEntityKind { person, company, character, genre, tag }

String normalizeCatalogEntityName(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool _containsEntity(Iterable<String> values, String entityName) {
  final key = normalizeCatalogEntityName(entityName);
  if (key.isEmpty) return false;
  return values.any((value) => normalizeCatalogEntityName(value) == key);
}

/// Returns the catalog roles/relationships that connect [entityName] to [work].
/// The screen uses this to build the entity's filmography/credit list from
/// actual metadata currently indexed in the service; no credits are inferred.
List<String> catalogEntityRolesForWork(
  MediaItem work,
  String entityName,
  CatalogEntityKind kind,
) {
  final roles = <String>[];
  switch (kind) {
    case CatalogEntityKind.person:
      if (_containsEntity(work.actors, entityName)) roles.add('Cast');
      if (_containsEntity(work.directors, entityName)) roles.add('Director');
      if (_containsEntity(work.writers, entityName)) roles.add('Screenwriter');
      if (_containsEntity(work.music, entityName)) roles.add('Music');
      break;
    case CatalogEntityKind.company:
      if (_containsEntity(work.companies, entityName)) roles.add('Company');
      if (_containsEntity(work.studios, entityName)) {
        roles.add('Production studio');
      }
      break;
    case CatalogEntityKind.character:
      if (_containsEntity(work.characters, entityName)) roles.add('Character');
      break;
    case CatalogEntityKind.genre:
      if (_containsEntity(work.genres, entityName) ||
          normalizeCatalogEntityName(work.primaryGenre ?? '') ==
              normalizeCatalogEntityName(entityName)) {
        roles.add('Genre');
      }
      break;
    case CatalogEntityKind.tag:
      if (_containsEntity(work.tags, entityName)) roles.add('Tag');
      break;
  }
  return roles;
}

/// Provides stable category names across inconsistent source type labels.
String catalogMediaCategory(MediaItem media) {
  if (media.isSeries) return 'TV Shows';
  final type =
      media.type.trim().toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ');
  if (type.contains('album') ||
      type == 'music' ||
      type.contains('song') ||
      type.contains('track') ||
      type.contains('audio album')) {
    return 'Music Albums';
  }
  if (type.contains('movie') || type.contains('film') || type == 'video') {
    return 'Movies';
  }
  return 'Other';
}

class CatalogEntityDetailsScreen extends StatelessWidget {
  const CatalogEntityDetailsScreen({
    super.key,
    required this.entityName,
    required this.kind,
    required this.sourceMedia,
    required this.onOpenMedia,
  });

  final String entityName;
  final CatalogEntityKind kind;
  final MediaItem sourceMedia;
  final ValueChanged<MediaItem> onOpenMedia;

  static const List<String> _categoryOrder = <String>[
    'Movies',
    'TV Shows',
    'Music Albums',
    'Other',
  ];

  String get _kindLabel {
    switch (kind) {
      case CatalogEntityKind.person:
        return 'Person';
      case CatalogEntityKind.company:
        return 'Company / Studio';
      case CatalogEntityKind.character:
        return 'Character';
      case CatalogEntityKind.genre:
        return 'Genre';
      case CatalogEntityKind.tag:
        return 'Tag';
    }
  }

  IconData get _kindIcon {
    switch (kind) {
      case CatalogEntityKind.person:
        return Icons.person_outline_rounded;
      case CatalogEntityKind.company:
        return Icons.business_outlined;
      case CatalogEntityKind.character:
        return Icons.theater_comedy_outlined;
      case CatalogEntityKind.genre:
        return Icons.local_movies_outlined;
      case CatalogEntityKind.tag:
        return Icons.sell_outlined;
    }
  }

  List<MediaItem> _allKnownWorks() {
    final byId = <String, MediaItem>{};
    final activeProfile = AppController.instance.currentProfile;
    for (final item in AppController.instance.library) {
      // Entity filmographies must obey the same per-profile access rules as
      // ordinary library browsing; hidden titles must not leak through credits.
      if (item.isAccessibleTo(activeProfile)) {
        byId[item.id] = item;
      }
    }
    // The page's source item must remain discoverable even if a detail view
    // was opened from a preview or a not-yet-synced catalog result.
    byId[sourceMedia.id] = sourceMedia;
    return byId.values.toList(growable: false);
  }

  DateTime? _releaseDate(MediaItem media) =>
      media.editionReleaseDate ?? media.releaseDate ?? media.seriesStartDate;

  int? _releaseYear(MediaItem media) =>
      _releaseDate(media)?.year ??
      media.editionReleaseYear ??
      media.releaseYear ??
      media.seriesStartYear;

  List<_EntityCredit> _matchingCredits() {
    final credits = <_EntityCredit>[];
    for (final work in _allKnownWorks()) {
      final roles = catalogEntityRolesForWork(work, entityName, kind);
      if (roles.isNotEmpty) credits.add(_EntityCredit(work, roles));
    }
    credits.sort((a, b) {
      final aYear = _releaseYear(a.media);
      final bYear = _releaseYear(b.media);
      if (aYear != null && bYear != null && aYear != bYear) {
        return bYear.compareTo(aYear);
      }
      if (aYear != null && bYear == null) return -1;
      if (aYear == null && bYear != null) return 1;
      final aDate = _releaseDate(a.media);
      final bDate = _releaseDate(b.media);
      if (aDate != null && bDate != null) {
        final byDate = bDate.compareTo(aDate);
        if (byDate != 0) return byDate;
      } else if (aDate != null && bDate == null) {
        return -1;
      } else if (aDate == null && bDate != null) {
        return 1;
      }
      final byTitle = a.media.title.toLowerCase().compareTo(
            b.media.title.toLowerCase(),
          );
      return byTitle != 0 ? byTitle : a.media.id.compareTo(b.media.id);
    });
    return credits;
  }

  String _yearLabel(MediaItem media) =>
      media.displayYearLabel ??
      _releaseYear(media)?.toString() ??
      'Year unknown';

  Widget _buildArtwork(MediaItem media) {
    final rawUrl = media.imageUrl?.trim();
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    final isNetworkUrl = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    if (!isNetworkUrl) {
      return _artworkPlaceholder();
    }
    return Image.network(
      uri.toString(),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _artworkPlaceholder(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _artworkPlaceholder(),
    );
  }

  Widget _artworkPlaceholder() => Container(
        color: const Color(0xFF242424),
        alignment: Alignment.center,
        child: Icon(
          _kindIcon,
          color: Colors.white38,
          size: 25,
        ),
      );

  Widget _buildCountSummary(List<_EntityCredit> credits) {
    final counts = <String, int>{};
    for (final credit in credits) {
      final category = catalogMediaCategory(credit.media);
      counts[category] = (counts[category] ?? 0) + 1;
    }
    final parts = <String>[
      for (final category in _categoryOrder)
        if ((counts[category] ?? 0) > 0) '${counts[category]} $category',
    ];
    return Text(
      parts.isEmpty
          ? (kind == CatalogEntityKind.person &&
                  CinematicPersonMetadataService.isConfigured
              ? 'Provider filmography loads below'
              : 'No linked titles found')
          : parts.join('  ·  '),
      style: const TextStyle(color: Colors.white70, height: 1.4),
    );
  }

  Widget _buildCreditTile(_EntityCredit credit) {
    final media = credit.media;
    return Card(
      color: const Color(0xFF151515),
      margin: const EdgeInsets.only(bottom: 9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpenMedia(media),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                    width: 58, height: 82, child: _buildArtwork(media)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${catalogMediaCategory(media)}  ·  ${_yearLabel(media)}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        for (final role in credit.roles)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              role,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final credits = _matchingCredits();
    final grouped = <String, List<_EntityCredit>>{
      for (final category in _categoryOrder) category: <_EntityCredit>[],
    };
    for (final credit in credits) {
      grouped[catalogMediaCategory(credit.media)]!.add(credit);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090909),
        surfaceTintColor: Colors.transparent,
        title: Text(entityName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (kind == CatalogEntityKind.person)
            IconButton(
              tooltip: 'Find people connections',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ActorConnectionScreen(initialPerson: entityName),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .07)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kind == CatalogEntityKind.person)
                  CatalogPersonAvatar(
                    name: entityName,
                    radius: 38,
                    fallbackIcon: _kindIcon,
                  )
                else
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.white.withValues(alpha: .08),
                    child: Icon(_kindIcon, size: 27, color: Colors.white70),
                  ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _kindLabel,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        entityName,
                        style: const TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      _buildCountSummary(credits),
                      if (sourceMedia.tags.contains('catalog-example')) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'This profile includes local catalog examples without media files. The listed filmography is limited to currently indexed credits and may not be exhaustive.',
                          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (kind == CatalogEntityKind.person) ...[
            const SizedBox(height: 16),
            _ProviderPersonFilmography(
              entityName: entityName,
              localWorks: _allKnownWorks(),
              onOpenMedia: onOpenMedia,
            ),
            _MusicBrainzArtistSection(name: entityName),
          ],
          if (kind == CatalogEntityKind.person && credits.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'LOCAL CATALOG CREDITS',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
          const SizedBox(height: 22),
          if (credits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22, horizontal: 8),
              child: Text(
                'No matching titles are currently indexed. This profile only uses sourced credits and relationships in your service catalog; it does not guess missing filmographies.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.45),
              ),
            ),
          for (final category in _categoryOrder)
            if (grouped[category]!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '${grouped[category]!.length}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              for (final credit in grouped[category]!) _buildCreditTile(credit),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _EntityCredit {
  const _EntityCredit(this.media, this.roles);
  final MediaItem media;
  final List<String> roles;
}


/// A real TMDB portrait when a strict name match is available; otherwise a
/// neutral fallback is shown instead of a guessed photo.
class CatalogPersonAvatar extends StatelessWidget {
  const CatalogPersonAvatar({
    super.key,
    required this.name,
    required this.radius,
    required this.fallbackIcon,
  });

  final String name;
  final double radius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CinematicPersonSummary?>(
      future: CinematicPersonMetadataService.lookupPersonSummary(name),
      builder: (context, snapshot) {
        final photoUrl = snapshot.hasData
            ? CinematicPersonMetadataService.imageUrl(
                snapshot.data?.profilePath,
                size: 'w185',
              )
            : null;
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.white.withValues(alpha: .08),
          backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
          child: photoUrl == null
              ? Icon(fallbackIcon, size: radius * .95, color: Colors.white70)
              : null,
        );
      },
    );
  }
}

class _ProviderPersonFilmography extends StatefulWidget {
  const _ProviderPersonFilmography({
    required this.entityName,
    required this.localWorks,
    required this.onOpenMedia,
  });

  final String entityName;
  final List<MediaItem> localWorks;
  final ValueChanged<MediaItem> onOpenMedia;

  @override
  State<_ProviderPersonFilmography> createState() =>
      _ProviderPersonFilmographyState();
}

class _ProviderPersonFilmographyState extends State<_ProviderPersonFilmography> {
  String _filter = 'All';
  bool _showAll = false;

  String _normalizeTitle(String value) => value
      .toLowerCase()
      .trim()
      // Preserve non-Latin scripts so Korean/Japanese/Chinese titles don't
      // normalize to the same empty value.
      .replaceAll(RegExp(r"[\s\-_.,:;!?()\[\]{}\\/]+"), '');

  MediaItem? _matchingLocalWork(CinematicPersonCredit credit) {
    final category = credit.mediaType == 'tv' ? 'TV Shows' : 'Movies';
    for (final item in widget.localWorks) {
      if (catalogMediaCategory(item) != category ||
          _normalizeTitle(item.title) != _normalizeTitle(credit.title)) {
        continue;
      }
      // When both years are known, don't route a remake/sequel-like title to
      // a different local work just because its title text matches.
      final localYear = item.releaseDate?.year ??
          item.seriesStartDate?.year ??
          item.releaseYear ??
          item.seriesStartYear;
      if (credit.releaseYear != null &&
          localYear != null &&
          credit.releaseYear != localYear) {
        continue;
      }
      return item;
    }
    return null;
  }

  String _year(CinematicPersonCredit credit) =>
      credit.releaseYear?.toString() ?? 'Year unknown';

  Widget _filmographyTile(CinematicPersonCredit credit) {
    final localWork = _matchingLocalWork(credit);
    final posterUrl = CinematicPersonMetadataService.imageUrl(
      credit.posterPath,
      size: 'w185',
    );
    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 49,
        height: 70,
        child: posterUrl == null
            ? Container(
                color: Colors.white.withValues(alpha: .06),
                alignment: Alignment.center,
                child: const Icon(Icons.movie_outlined, color: Colors.white38),
              )
            : Image.network(
                posterUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white.withValues(alpha: .06),
                  alignment: Alignment.center,
                  child: const Icon(Icons.movie_outlined, color: Colors.white38),
                ),
              ),
      ),
    );
    return Card(
      color: const Color(0xFF151515),
      margin: const EdgeInsets.only(bottom: 7),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (localWork != null) {
            widget.onOpenMedia(localWork);
            return;
          }
          // Provider filmography entries are often not yet in the user's local
          // library. They must remain selectable and open their own in-app
          // details page using the exact TMDB ID and media type.
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => TmdbMetadataDetailsScreen(
                id: credit.id,
                type: credit.mediaType,
                initialTitle: credit.title,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              poster,
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credit.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${credit.mediaType == 'tv' ? 'TV Show' : 'Movie'} · ${_year(credit)}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      credit.roleLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!CinematicPersonMetadataService.isConfigured) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: const Text(
          'To show provider-sourced people photos, biographies, and filmography, sign in and configure TMDB_API_KEY or TMDB_API_TOKEN in Backend/.env. Local catalog credits remain available below.',
          style: TextStyle(color: Colors.white60, height: 1.4),
        ),
      );
    }

    return FutureBuilder<CinematicPersonMetadata?>(
      future: CinematicPersonMetadataService.lookupPersonProfile(widget.entityName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Expanded(child: Text('Loading person photo, biography, and filmography from TMDB…', style: TextStyle(color: Colors.white70))),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'TMDB could not load this profile: ${snapshot.error}. Your local catalog filmography is still shown below.',
              style: const TextStyle(color: Colors.white60, height: 1.4),
            ),
          );
        }
        final profile = snapshot.data;
        if (profile == null) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'No exact TMDB person match was found for this name. To avoid showing the wrong person, this profile keeps the locally indexed credits below.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
          );
        }

        final filtered = profile.filmography.where((credit) {
          if (_filter == 'Movies') return credit.mediaType == 'movie';
          if (_filter == 'TV Shows') return credit.mediaType == 'tv';
          return true;
        }).toList(growable: false);
        final visible = _showAll ? filtered : filtered.take(24).toList();
        final dateParts = <String>[
          if ((profile.birthday ?? '').isNotEmpty) 'Born ${profile.birthday}',
          if ((profile.deathday ?? '').isNotEmpty) 'Died ${profile.deathday}',
          if ((profile.placeOfBirth ?? '').trim().isNotEmpty) profile.placeOfBirth!.trim(),
          if ((profile.person.knownForDepartment ?? '').trim().isNotEmpty)
            'Known for ${profile.person.knownForDepartment}',
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: .06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BIOGRAPHY', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  Text(
                    profile.biography.isNotEmpty
                        ? profile.biography
                        : 'TMDB does not currently provide a biography for this person.',
                    style: TextStyle(color: Colors.white.withValues(alpha: .88), height: 1.45),
                  ),
                  if (dateParts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(dateParts.join('  ·  '), style: const TextStyle(color: Colors.white60, height: 1.4, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: Text('FULL FILMOGRAPHY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: .7))),
                Text('${filtered.length} titles', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              children: [
                for (final filter in const <String>['All', 'Movies', 'TV Shows'])
                  ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() {
                      _filter = filter;
                      _showAll = false;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('TMDB has no matching movie or TV credits for this filter.', style: TextStyle(color: Colors.white60)),
              )
            else ...[
              for (final credit in visible) _filmographyTile(credit),
              if (!_showAll && filtered.length > visible.length)
                TextButton.icon(
                  onPressed: () => setState(() => _showAll = true),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text('Show all ${filtered.length} titles'),
                ),
              if (_showAll && filtered.length > 24)
                TextButton.icon(
                  onPressed: () => setState(() => _showAll = false),
                  icon: const Icon(Icons.expand_less_rounded),
                  label: const Text('Show fewer titles'),
                ),
            ],
            const Padding(
              padding: EdgeInsets.only(top: 5, bottom: 6),
              child: Text('Person data, photos, and credits provided by TMDB. Titles not in your local catalog are displayed for reference and cannot open a local playback/details record.', style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.35)),
            ),
          ],
        );
      },
    );
  }
}

/// Optional MusicBrainz enrichment keeps music and acting credits on one person page.
class _MusicBrainzArtistSection extends StatefulWidget {
  const _MusicBrainzArtistSection({required this.name});
  final String name;
  @override State<_MusicBrainzArtistSection> createState() => _MusicBrainzArtistSectionState();
}
class _MusicBrainzArtistSectionState extends State<_MusicBrainzArtistSection> {
  late Future<Map<String, dynamic>?> _future;
  @override void initState() { super.initState(); _future = _lookup(); }
  Future<Map<String, dynamic>?> _lookup() async {
    try {
      final uri = Uri.https('musicbrainz.org', '/ws/2/artist/', {'query': 'artist:"${widget.name}"', 'fmt':'json', 'limit':'5'});
      final response = await http.get(uri, headers: {'User-Agent':'MyOwnStreamingService/1.0 (personal media catalog)'}).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final artists = data['artists']; if (artists is! List) return null;
      final target = widget.name.trim().toLowerCase();
      Map<String,dynamic>? match;
      for (final item in artists.whereType<Map>()) {
        final row = Map<String,dynamic>.from(item);
        if ((row['name']?.toString().trim().toLowerCase() ?? '') == target) { match = row; break; }
      }
      if (match == null) return null;
      final id = match['id']?.toString(); if (id == null || id.isEmpty) return null;
      final releasesUri = Uri.https('musicbrainz.org', '/ws/2/release/', {'artist':id,'fmt':'json','limit':'20','inc':'artist-credits'});
      final releasesResponse = await http.get(releasesUri, headers: {'User-Agent':'MyOwnStreamingService/1.0 (personal media catalog)'}).timeout(const Duration(seconds: 8));
      final releasesData = releasesResponse.statusCode == 200 ? jsonDecode(releasesResponse.body) as Map<String,dynamic> : <String,dynamic>{};
      final raw = releasesData['releases'];
      final releases = raw is List ? raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList() : <Map<String,dynamic>>[];
      return {'artist':match,'releases':releases};
    } catch (_) { return null; }
  }
  @override Widget build(BuildContext context) => FutureBuilder<Map<String,dynamic>?>(future:_future,builder:(context,snapshot){
    if(snapshot.connectionState==ConnectionState.waiting) return const Padding(padding:EdgeInsets.all(12),child:LinearProgressIndicator());
    final data=snapshot.data; if(data==null) return const SizedBox.shrink();
    final artist=data['artist'] as Map<String,dynamic>; final releases=data['releases'] as List<Map<String,dynamic>>;
    final country=artist['country']?.toString(); final area=(artist['area'] is Map)?(artist['area'] as Map)['name']?.toString():null;
    return Container(margin:const EdgeInsets.only(top:16),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF151515),borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('MUSIC CAREER',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:1,color:Colors.white70)),const SizedBox(height:6),Text('MusicBrainz artist match · ${[if(country!=null&&country.isNotEmpty)country,if(area!=null&&area.isNotEmpty)area].join(' · ')}',style:const TextStyle(color:Colors.white60,fontSize:12)),const SizedBox(height:12),const Text('Albums & releases',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),if(releases.isEmpty)const Text('Artist found; no releases were returned.',style:TextStyle(color:Colors.white60)) else ...releases.map((r){final title=r['title']?.toString()??'Untitled release';final date=r['date']?.toString()??'Date unknown';final format=(r['release-group'] is Map)?((r['release-group'] as Map)['primary-type']?.toString()??'Release'):'Release';return ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.album_outlined),title:Text(title),subtitle:Text('$format · $date'));}),const Text('MusicBrainz data may include singles, reissues, and duplicate editions.',style:TextStyle(color:Colors.white54,fontSize:11))]));
  });
}
