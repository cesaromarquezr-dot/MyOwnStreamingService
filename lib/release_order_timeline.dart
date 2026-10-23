import 'package:flutter/material.dart';

import 'app_core.dart';
import 'details.dart';
import 'media_identity_sorting.dart';
import 'player.dart';
import 'release_order_grouping.dart';

/// Cross-catalog release timeline for movies, TV series, and music albums.
class ReleaseOrderTimelineScreen extends StatefulWidget {
  const ReleaseOrderTimelineScreen({super.key});

  @override
  State<ReleaseOrderTimelineScreen> createState() =>
      _ReleaseOrderTimelineScreenState();
}

class _ReleaseOrderTimelineScreenState extends State<ReleaseOrderTimelineScreen> {
  ReleaseOrderDirection _direction = ReleaseOrderDirection.newestFirst;
  ReleaseOrderSection? _sectionFilter;
  String? _genreFilter;

  @override
  Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final musicItems = library
        .where((item) =>
            ReleaseOrderGrouping.sectionFor(item) == ReleaseOrderSection.music)
        .toList(growable: false);
    final genres = musicItems
        .expand((item) => item.genres)
        .map((genre) => genre.trim())
        .where((genre) => genre.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final filteredItems = _filteredItems(library);
    final years = ReleaseOrderGrouping.group(
      filteredItems,
      direction: _direction,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF09090D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090D),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Release Order',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<ReleaseOrderDirection>(
            tooltip: 'Change release-year order',
            initialValue: _direction,
            icon: const Icon(Icons.sort_rounded),
            onSelected: (value) => setState(() => _direction = value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ReleaseOrderDirection.newestFirst,
                child: Text('Newest years first'),
              ),
              PopupMenuItem(
                value: ReleaseOrderDirection.oldestFirst,
                child: Text('Oldest years first'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Text(
              'Browse movies, TV shows, and music by release year. Exact release dates set the order within each section; titles without a full date follow alphabetically.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .65),
                height: 1.35,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('All Content', _sectionFilter == null, () {
                  setState(() {
                    _sectionFilter = null;
                    _genreFilter = null;
                  });
                }),
                _filterChip('Movies',
                    _sectionFilter == ReleaseOrderSection.movies, () {
                  setState(() {
                    _sectionFilter = ReleaseOrderSection.movies;
                    _genreFilter = null;
                  });
                }),
                _filterChip('TV Shows',
                    _sectionFilter == ReleaseOrderSection.shows, () {
                  setState(() {
                    _sectionFilter = ReleaseOrderSection.shows;
                    _genreFilter = null;
                  });
                }),
                _filterChip('Music',
                    _sectionFilter == ReleaseOrderSection.music, () {
                  setState(() => _sectionFilter = ReleaseOrderSection.music);
                }),
                _filterChip('Other',
                    _sectionFilter == ReleaseOrderSection.other, () {
                  setState(() {
                    _sectionFilter = ReleaseOrderSection.other;
                    _genreFilter = null;
                  });
                }),
              ],
            ),
          ),
          if (_sectionFilter == ReleaseOrderSection.music && genres.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  _genreChip('All genres', _genreFilter == null, () {
                    setState(() => _genreFilter = null);
                  }),
                  ...genres.map((genre) => _genreChip(
                        genre,
                        _genreFilter?.toLowerCase() == genre.toLowerCase(),
                        () => setState(() => _genreFilter = genre),
                      )),
                ],
              ),
            ),
          const Divider(height: 1, color: Color(0xFF292932)),
          Expanded(
            child: years.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                    itemCount: years.length,
                    itemBuilder: (context, index) {
                      final group = years[index];
                      return Card(
                        color: const Color(0xFF15151D),
                        surfaceTintColor: Colors.transparent,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: .055),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          key: PageStorageKey<String>(
                            'release-order-${group.year ?? 'unknown'}',
                          ),
                          initiallyExpanded: index == 0,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 5,
                          ),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          leading: Container(
                            width: 55,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B7CFF)
                                  .withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              group.year == null
                                  ? Icons.help_outline_rounded
                                  : Icons.calendar_month_rounded,
                              color: const Color(0xFFB7ADFF),
                            ),
                          ),
                          title: Text(
                            group.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          subtitle: Text(
                            '${group.itemCount} ${group.itemCount == 1 ? 'title' : 'titles'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .58),
                              fontSize: 12,
                            ),
                          ),
                          children: [
                            for (final section in ReleaseOrderGrouping.sectionOrder)
                              if (group.sections[section]?.isNotEmpty == true)
                                _sectionContents(
                                  section,
                                  group.sections[section]!,
                                ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<MediaItem> _filteredItems(List<MediaItem> library) {
    var items = library;
    final section = _sectionFilter;
    if (section != null) {
      items = items
          .where((item) => ReleaseOrderGrouping.sectionFor(item) == section)
          .toList(growable: false);
    }
    final genre = _genreFilter;
    if (genre != null && genre.trim().isNotEmpty) {
      items = ReleaseOrderGrouping.filterByGenre(
        items.where((item) =>
            ReleaseOrderGrouping.sectionFor(item) == ReleaseOrderSection.music),
        genre,
      );
    }
    return items;
  }

  Widget _filterChip(String label, bool selected, VoidCallback onSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        selectedColor: const Color(0xFF8B7CFF),
        backgroundColor: const Color(0xFF1A1A24),
        side: BorderSide(
          color: selected ? const Color(0xFF8B7CFF) : Colors.white12,
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _genreChip(String label, bool selected, VoidCallback onSelected) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onSelected(),
          showCheckmark: false,
          selectedColor: const Color(0xFF303040),
          backgroundColor: const Color(0xFF15151D),
          side: BorderSide(
            color: selected ? const Color(0xFFB7ADFF) : Colors.white12,
          ),
          labelStyle: TextStyle(
            color: selected ? const Color(0xFFB7ADFF) : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _sectionContents(ReleaseOrderSection section, List<MediaItem> items) {
    final config = switch (section) {
      ReleaseOrderSection.movies =>
        (label: 'Movies', icon: Icons.movie_outlined),
      ReleaseOrderSection.shows =>
        (label: 'TV Shows', icon: Icons.tv_outlined),
      ReleaseOrderSection.music =>
        (label: 'Music', icon: Icons.album_outlined),
      ReleaseOrderSection.other =>
        (label: 'Other', icon: Icons.video_library_outlined),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 7),
            child: Row(
              children: [
                Icon(config.icon, size: 17, color: const Color(0xFFB7ADFF)),
                const SizedBox(width: 8),
                Text(
                  config.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .45),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          for (final item in items) _mediaRow(item, config.icon),
        ],
      ),
    );
  }

  Widget _mediaRow(MediaItem item, IconData icon) {
    final subtitle = _subtitleFor(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.white.withValues(alpha: .025),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: () => _openMedia(item),
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox(
                    width: 46,
                    height: 62,
                    child: item.imageUrl?.trim().isNotEmpty == true
                        ? Image.network(
                            item.imageUrl!.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _artworkFallback(icon),
                          )
                        : _artworkFallback(icon),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .55),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: .45)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleFor(MediaItem item) {
    final parts = <String>[];
    final releaseDate = ReleaseOrderGrouping.releaseDateFor(item);
    if (releaseDate != null) {
      parts.add(MaterialLocalizations.of(context).formatMediumDate(releaseDate));
    }
    if ((item.editionName ?? '').trim().isNotEmpty) {
      parts.add(item.editionName!.trim());
    }
    if (item.genres.isNotEmpty) parts.add(item.genres.take(2).join(' · '));
    final disambiguator = MediaIdentitySorting.disambiguator(item);
    if (disambiguator.isNotEmpty) {
      // Keep title disambiguators for similarly named works, but avoid repeating
      // a year on the year timeline unless it distinguishes the same title.
      final sameTitleCount = AppController.instance.library.where(
        (candidate) => MediaIdentitySorting.normalizedTitle(candidate.title) ==
            MediaIdentitySorting.normalizedTitle(item.title),
      ).length;
      if (sameTitleCount > 1) parts.add(disambiguator);
    }
    return parts.toSet().join(' · ');
  }

  Widget _artworkFallback(IconData icon) => Container(
        color: const Color(0xFF242431),
        alignment: Alignment.center,
        child: Icon(icon, color: const Color(0xFFB7ADFF), size: 23),
      );

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined,
                  color: Color(0xFFB7ADFF), size: 44),
              const SizedBox(height: 14),
              const Text(
                'No matching titles yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Imported movies, shows, and music will appear here when release-year metadata is available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );

  void _openMedia(MediaItem item) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: RouteSettings(
        name: item.playbackUrl?.trim().isNotEmpty == true
            ? '/app/player'
            : '/app/details',
      ),
      builder: (_) => item.playbackUrl?.trim().isNotEmpty == true
          ? PlayerScreen(media: item)
          : MediaDetailsScreen(media: item),
    ));
  }
}
