import 'package:flutter/material.dart';

import 'app_core.dart';
import 'actor_connections.dart';

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
      parts.isEmpty ? 'No linked titles found' : parts.join('  ·  '),
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
