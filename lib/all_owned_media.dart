import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'details.dart';

/// The three owned-media families shown by All Owned Media.
/// Episodes and individual tracks remain accessible from their parent show or
/// album pages and are intentionally not repeated as top-level owned titles.
enum AllOwnedMediaKind { movie, show, album }

enum AllOwnedMediaSort {
  titleAscending,
  titleDescending,
  countryAscending,
  countryDescending,
  ratingAscending,
  ratingDescending,
  releaseNewest,
  releaseOldest,
  addedNewest,
  addedOldest,
}

extension AllOwnedMediaSortLabel on AllOwnedMediaSort {
  String get label => switch (this) {
        AllOwnedMediaSort.titleAscending => 'Title: A–Z',
        AllOwnedMediaSort.titleDescending => 'Title: Z–A',
        AllOwnedMediaSort.countryAscending => 'Country: A–Z',
        AllOwnedMediaSort.countryDescending => 'Country: Z–A',
        AllOwnedMediaSort.ratingAscending => 'Rating: Lowest–Highest',
        AllOwnedMediaSort.ratingDescending => 'Rating: Highest–Lowest',
        AllOwnedMediaSort.releaseNewest => 'Release: Newest–Oldest',
        AllOwnedMediaSort.releaseOldest => 'Release: Oldest–Newest',
        AllOwnedMediaSort.addedNewest => 'Added: Newest–Oldest',
        AllOwnedMediaSort.addedOldest => 'Added: Oldest–Newest',
      };
}

/// Shared classification and ordering logic for the unified owned-media view.
/// The source of truth is AppController.library, not the external metadata
/// catalog, so reference-only titles never appear as owned items.
class AllOwnedMediaCatalog {
  const AllOwnedMediaCatalog._();

  static AllOwnedMediaKind? kindOf(MediaItem media) {
    if (media.isSeries) return AllOwnedMediaKind.show;

    final type = _normalizeType(media.type);
    if (_albumTypes.contains(type)) return AllOwnedMediaKind.album;
    if (_movieTypes.contains(type) ||
        type.contains('movie') ||
        type.contains('film')) {
      return AllOwnedMediaKind.movie;
    }
    return null;
  }

  static List<MediaItem> visibleOwnedItems(AppController controller) {
    final profile = controller.currentProfile;
    return controller.library.where((media) {
      if (!media.isAccessibleTo(profile)) return false;
      if (_nonOwnedSources.contains(media.addedSource.trim().toLowerCase())) {
        return false;
      }
      return kindOf(media) != null;
    }).toList(growable: false);
  }

  static List<MediaItem> sort(
    Iterable<MediaItem> source,
    AllOwnedMediaSort sort,
  ) {
    final result = source.toList();
    result.sort((a, b) {
      int comparison;
      switch (sort) {
        case AllOwnedMediaSort.titleAscending:
          comparison = _compareText(a.title, b.title);
          break;
        case AllOwnedMediaSort.titleDescending:
          comparison = _compareText(b.title, a.title);
          break;
        case AllOwnedMediaSort.countryAscending:
          comparison = _compareOptionalText(
            _countryKey(a),
            _countryKey(b),
            descending: false,
          );
          break;
        case AllOwnedMediaSort.countryDescending:
          comparison = _compareOptionalText(
            _countryKey(a),
            _countryKey(b),
            descending: true,
          );
          break;
        case AllOwnedMediaSort.ratingAscending:
          comparison = _compareOptionalNumber(
            a.rating,
            b.rating,
            descending: false,
          );
          break;
        case AllOwnedMediaSort.ratingDescending:
          comparison = _compareOptionalNumber(
            a.rating,
            b.rating,
            descending: true,
          );
          break;
        case AllOwnedMediaSort.releaseNewest:
          comparison = _compareOptionalDate(
            _releaseDate(a),
            _releaseDate(b),
            descending: true,
          );
          break;
        case AllOwnedMediaSort.releaseOldest:
          comparison = _compareOptionalDate(
            _releaseDate(a),
            _releaseDate(b),
            descending: false,
          );
          break;
        case AllOwnedMediaSort.addedNewest:
          comparison = b.addedAt.compareTo(a.addedAt);
          break;
        case AllOwnedMediaSort.addedOldest:
          comparison = a.addedAt.compareTo(b.addedAt);
          break;
      }

      // A deterministic tie-breaker keeps order stable when metadata is equal
      // and avoids random-looking card movement after refreshes.
      if (comparison == 0) comparison = _compareText(a.title, b.title);
      if (comparison == 0) comparison = a.id.compareTo(b.id);
      return comparison;
    });
    return result;
  }

  static String _normalizeType(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static const Set<String> _albumTypes = <String>{
    'album',
    'music album',
    'record',
    'soundtrack album',
    'compilation album',
    'music compilation',
  };

  static const Set<String> _movieTypes = <String>{
    'movie',
    'film',
    'feature',
    'feature film',
    'motion picture',
    'cinema movie',
  };

  static const Set<String> _nonOwnedSources = <String>{
    'demo-preview',
    'preview-only',
    'not-playable',
    'catalog-example',
    'music-artist-example',
  };

  static String? _countryKey(MediaItem media) {
    final parts = mediaCountryOriginParts(media);
    if (parts.isEmpty) return null;
    return parts.join(', ').toLowerCase();
  }

  static DateTime? _releaseDate(MediaItem media) {
    final exactDate =
        media.editionReleaseDate ?? media.releaseDate ?? media.seriesStartDate;
    if (exactDate != null) return exactDate;
    final year =
        media.editionReleaseYear ?? media.releaseYear ?? media.seriesStartYear;
    // Year-only metadata is kept at year precision for ordering; no month/day
    // is invented in the UI or shown to the user.
    return year == null ? null : DateTime(year, 1, 1);
  }

  static int _compareText(String a, String b) =>
      a.trim().toLowerCase().compareTo(b.trim().toLowerCase());

  static int _compareOptionalText(
    String? a,
    String? b, {
    required bool descending,
  }) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final value = _compareText(a, b);
    return descending ? -value : value;
  }

  static int _compareOptionalNumber(
    num? a,
    num? b, {
    required bool descending,
  }) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final value = a.compareTo(b);
    return descending ? -value : value;
  }

  static int _compareOptionalDate(
    DateTime? a,
    DateTime? b, {
    required bool descending,
  }) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final value = a.compareTo(b);
    return descending ? -value : value;
  }
}

class AllOwnedMediaScreen extends StatefulWidget {
  const AllOwnedMediaScreen({super.key});

  @override
  State<AllOwnedMediaScreen> createState() => _AllOwnedMediaScreenState();
}

class _AllOwnedMediaScreenState extends State<AllOwnedMediaScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _kindFilter = 'All';
  AllOwnedMediaSort _sort = AllOwnedMediaSort.titleAscending;
  bool _gridView = true;
  bool _loadingPreferences = true;

  String get _preferenceKey {
    final controller = AppController.instance;
    final accountId = controller.currentAccount?.id.trim();
    final profileId = controller.currentProfile?.id.trim();
    final account =
        accountId == null || accountId.isEmpty ? 'local' : accountId;
    final profile =
        profileId == null || profileId.isEmpty ? 'guest' : profileId;
    return 'all_owned_media_preferences:$account:$profile';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreferences());
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final rawSort = preferences.getString('$_preferenceKey:sort');
      final rawView = preferences.getBool('$_preferenceKey:grid');
      final restoredSort = AllOwnedMediaSort.values.where(
        (value) => value.name == rawSort,
      );
      if (!mounted) return;
      setState(() {
        if (restoredSort.isNotEmpty) _sort = restoredSort.first;
        if (rawView != null) _gridView = rawView;
        _loadingPreferences = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPreferences = false);
    }
  }

  Future<void> _savePreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('$_preferenceKey:sort', _sort.name);
      await preferences.setBool('$_preferenceKey:grid', _gridView);
    } catch (_) {
      // Sorting and display remain fully usable when local preferences fail.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final owned = AllOwnedMediaCatalog.visibleOwnedItems(controller);
        final movieCount = owned
            .where((item) =>
                AllOwnedMediaCatalog.kindOf(item) == AllOwnedMediaKind.movie)
            .length;
        final showCount = owned
            .where((item) =>
                AllOwnedMediaCatalog.kindOf(item) == AllOwnedMediaKind.show)
            .length;
        final albumCount = owned
            .where((item) =>
                AllOwnedMediaCatalog.kindOf(item) == AllOwnedMediaKind.album)
            .length;

        final filtered = owned.where((item) {
          final kind = AllOwnedMediaCatalog.kindOf(item);
          final selectedKindMatches = switch (_kindFilter) {
            'Movies' => kind == AllOwnedMediaKind.movie,
            'TV Shows' => kind == AllOwnedMediaKind.show,
            'Albums' => kind == AllOwnedMediaKind.album,
            _ => true,
          };
          if (!selectedKindMatches) return false;
          final query = _query.trim().toLowerCase();
          if (query.isEmpty) return true;
          final searchable = <String>[
            item.title,
            item.originalTitle ?? '',
            item.canonicalTitle ?? '',
            item.countryOfOrigin ?? '',
            ...item.genres,
            ...item.actors,
            ...item.music,
            ...item.studios,
          ].join(' ').toLowerCase();
          return searchable.contains(query);
        }).toList(growable: false);
        final sorted = AllOwnedMediaCatalog.sort(filtered, _sort);

        return Scaffold(
          appBar: AppBar(
            title: const Text('All Owned Media'),
            actions: [
              IconButton(
                tooltip:
                    _gridView ? 'Switch to list view' : 'Switch to grid view',
                onPressed: () {
                  setState(() => _gridView = !_gridView);
                  unawaited(_savePreferences());
                },
                icon: Icon(_gridView
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _countChip('Movies', movieCount)),
                        const SizedBox(width: 8),
                        Expanded(child: _countChip('TV Shows', showCount)),
                        const SizedBox(width: 8),
                        Expanded(child: _countChip('Albums', albumCount)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Search your owned movies, shows and albums',
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final filter in const <String>[
                            'All',
                            'Movies',
                            'TV Shows',
                            'Albums',
                          ]) ...[
                            ChoiceChip(
                              label: Text(filter),
                              selected: _kindFilter == filter,
                              onSelected: (_) =>
                                  setState(() => _kindFilter = filter),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<AllOwnedMediaSort>(
                            initialValue: _sort,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Organize by',
                              prefixIcon: Icon(Icons.sort_rounded),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: AllOwnedMediaSort.values
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value.label,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _sort = value);
                              unawaited(_savePreferences());
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${sorted.length} ${sorted.length == 1 ? 'title' : 'titles'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loadingPreferences
                    ? const Center(child: CircularProgressIndicator())
                    : sorted.isEmpty
                        ? _emptyState()
                        : _gridView
                            ? _buildGrid(sorted)
                            : _buildList(sorted),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _countChip(String label, int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      );

  Widget _buildGrid(List<MediaItem> items) => LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              (constraints.maxWidth / 168).floor().clamp(2, 8).toInt();
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: .62,
            ),
            itemBuilder: (context, index) => _gridCard(items[index]),
          );
        },
      );

  Widget _gridCard(MediaItem media) {
    final kind = AllOwnedMediaCatalog.kindOf(media)!;
    final year = _displayYear(media);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetails(media),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _poster(media, fit: BoxFit.cover)),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      _kindLabel(kind),
                      if (year != null) year,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (media.rating != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(media.rating!.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<MediaItem> items) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final media = items[index];
          final kind = AllOwnedMediaCatalog.kindOf(media)!;
          final details = <String>[
            _kindLabel(kind),
            if (_displayYear(media) != null) _displayYear(media)!,
            if (mediaCountryOriginParts(media).isNotEmpty)
              mediaCountryOriginParts(media).join(', '),
            if (media.rating != null)
              'Rating ${media.rating!.toStringAsFixed(1)}',
          ];
          return Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: SizedBox(
                width: 54,
                height: 78,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _poster(media, fit: BoxFit.cover),
                ),
              ),
              title: Text(media.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                details.isEmpty ? 'Owned media' : details.join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openDetails(media),
            ),
          );
        },
      );

  Widget _poster(MediaItem media, {required BoxFit fit}) {
    final url = media.imageUrl?.trim() ?? '';
    if (url.isEmpty) return _posterFallback(media);
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, __, ___) => _posterFallback(media),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
    );
  }

  Widget _posterFallback(MediaItem media) {
    final kind = AllOwnedMediaCatalog.kindOf(media);
    final icon = switch (kind) {
      AllOwnedMediaKind.movie => Icons.movie_outlined,
      AllOwnedMediaKind.show => Icons.tv_outlined,
      AllOwnedMediaKind.album => Icons.album_outlined,
      null => Icons.perm_media_outlined,
    };
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(icon,
          size: 42, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_library_outlined, size: 52),
              const SizedBox(height: 12),
              const Text('No matching owned media',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                _query.isNotEmpty || _kindFilter != 'All'
                    ? 'Try a different search or media filter.'
                    : 'Owned movies, TV shows and albums will appear here after they are added to this profile’s library.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  String _kindLabel(AllOwnedMediaKind kind) => switch (kind) {
        AllOwnedMediaKind.movie => 'Movie',
        AllOwnedMediaKind.show => 'TV Show',
        AllOwnedMediaKind.album => 'Album',
      };

  String? _displayYear(MediaItem media) {
    final year =
        media.editionReleaseYear ?? media.releaseYear ?? media.seriesStartYear;
    return year?.toString();
  }

  void _openDetails(MediaItem media) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MediaDetailsScreen(media: media),
    ));
  }
}
