import 'package:flutter/material.dart';

/// Shared presentation modes for browsing movies, shows, albums, and collections.
enum LibraryViewMode { list, grid, gallery, table, timeline }

extension LibraryViewModePresentation on LibraryViewMode {
  String get label {
    switch (this) {
      case LibraryViewMode.list:
        return 'List';
      case LibraryViewMode.grid:
        return 'Poster grid';
      case LibraryViewMode.gallery:
        return 'Gallery';
      case LibraryViewMode.table:
        return 'Table';
      case LibraryViewMode.timeline:
        return 'Timeline';
    }
  }

  IconData get icon {
    switch (this) {
      case LibraryViewMode.list:
        return Icons.view_list_rounded;
      case LibraryViewMode.grid:
        return Icons.grid_view_rounded;
      case LibraryViewMode.gallery:
        return Icons.photo_library_outlined;
      case LibraryViewMode.table:
        return Icons.table_chart_outlined;
      case LibraryViewMode.timeline:
        return Icons.timeline_rounded;
    }
  }
}

/// Keeps the selected view by library area during the current app session.
/// A profile-specific preference can be layered on top of this when desired.
class LibraryViewPreferenceStore {
  LibraryViewPreferenceStore._();

  static final Map<String, LibraryViewMode> _modes =
      <String, LibraryViewMode>{};

  static LibraryViewMode get(
    String scope, {
    LibraryViewMode fallback = LibraryViewMode.grid,
  }) => _modes[scope] ?? fallback;

  static void set(String scope, LibraryViewMode mode) {
    _modes[scope] = mode;
  }
}

class LibraryViewModePicker extends StatelessWidget {
  const LibraryViewModePicker({
    super.key,
    required this.scope,
    required this.value,
    required this.onChanged,
    this.modes = const <LibraryViewMode>[
      LibraryViewMode.list,
      LibraryViewMode.grid,
      LibraryViewMode.gallery,
      LibraryViewMode.table,
      LibraryViewMode.timeline,
    ],
    this.compact = false,
  });

  final String scope;
  final LibraryViewMode value;
  final ValueChanged<LibraryViewMode> onChanged;
  final List<LibraryViewMode> modes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final mode in modes) ...[
              if (mode != modes.first) const SizedBox(width: 8),
              ChoiceChip(
                avatar: Icon(mode.icon, size: 16),
                label: Text(mode.label),
                selected: value == mode,
                visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                onSelected: (_) {
                  LibraryViewPreferenceStore.set(scope, mode);
                  onChanged(mode);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One selectable item in any of the supported library views.
class LibraryViewEntry {
  const LibraryViewEntry({
    required this.title,
    required this.subtitle,
    this.year,
    this.imageUrl,
    this.artworkBuilder,
    this.fallbackIcon = Icons.movie_outlined,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final int? year;
  final String? imageUrl;
  final Widget Function(BuildContext context, BoxFit fit)? artworkBuilder;
  final IconData fallbackIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
}

/// A common renderer for list, grid, gallery, table, and timeline layouts.
/// It is designed to sit inside a parent's scrollable; its grids are shrink-wrapped.
class LibraryCollectionView extends StatelessWidget {
  const LibraryCollectionView({
    super.key,
    required this.entries,
    required this.mode,
    this.padding = const EdgeInsets.fromLTRB(18, 4, 18, 30),
    this.gridItemBuilder,
    this.emptyMessage = 'Nothing to show here yet.',
  });

  final List<LibraryViewEntry> entries;
  final LibraryViewMode mode;
  final EdgeInsetsGeometry padding;
  final Widget Function(BuildContext context, int index)? gridItemBuilder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: padding,
        child: Center(
          child: Text(emptyMessage, style: const TextStyle(color: Colors.white60)),
        ),
      );
    }

    switch (mode) {
      case LibraryViewMode.list:
        return _list(context);
      case LibraryViewMode.grid:
        return _grid(context);
      case LibraryViewMode.gallery:
        return _gallery(context);
      case LibraryViewMode.table:
        return _table(context);
      case LibraryViewMode.timeline:
        return _timeline(context);
    }
  }

  Widget _list(BuildContext context) => Padding(
        padding: padding,
        child: Column(
          children: [
            for (final entry in entries)
              Card(
                color: Colors.white.withValues(alpha: .045),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  leading: SizedBox(width: 52, height: 70, child: _artwork(context, entry, BoxFit.contain)),
                  title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(entry.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  trailing: entry.trailing ?? const Icon(Icons.chevron_right_rounded),
                  onTap: entry.onTap,
                ),
              ),
          ],
        ),
      );

  Widget _grid(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1300 ? 6 : width >= 1000 ? 5 : width >= 720 ? 4 : width >= 480 ? 3 : 2;
    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: .61,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
        ),
        itemBuilder: (context, index) {
          if (gridItemBuilder != null) return gridItemBuilder!(context, index);
          final entry = entries[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            color: Colors.white.withValues(alpha: .045),
            child: InkWell(
              onTap: entry.onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _artwork(context, entry, BoxFit.cover)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(height: 3),
                      Text(entry.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white60, fontSize: 10)),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _gallery(BuildContext context) => Padding(
        padding: padding,
        child: SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return SizedBox(
                width: 170,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  color: Colors.white.withValues(alpha: .045),
                  child: InkWell(
                    onTap: entry.onTap,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _artwork(context, entry, BoxFit.cover)),
                      Padding(
                        padding: const EdgeInsets.all(9),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          const SizedBox(height: 3),
                          Text(entry.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white60, fontSize: 10)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      );

  Widget _table(BuildContext context) => Padding(
        padding: padding,
        child: Card(
          color: Colors.white.withValues(alpha: .035),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Container(
              color: Colors.white.withValues(alpha: .05),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: const Row(children: [
                Expanded(flex: 5, child: Text('TITLE', style: TextStyle(fontSize: 10, color: Colors.white60, fontWeight: FontWeight.w800))),
                Expanded(flex: 3, child: Text('DETAILS', style: TextStyle(fontSize: 10, color: Colors.white60, fontWeight: FontWeight.w800))),
                SizedBox(width: 24),
              ]),
            ),
            for (var i = 0; i < entries.length; i++)
              InkWell(
                onTap: entries[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(children: [
                    Expanded(flex: 5, child: Text(entries[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(flex: 3, child: Text(entries[i].subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11))),
                    entries[i].trailing ?? const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white54),
                  ]),
                ),
              ),
            if (entries.isEmpty) const SizedBox.shrink(),
          ]),
        ),
      );

  Widget _timeline(BuildContext context) {
    final ordered = List<LibraryViewEntry>.from(entries)
      ..sort((a, b) => (a.year ?? 9999).compareTo(b.year ?? 9999));
    return Padding(
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var index = 0; index < ordered.length; index++) ...[
          if (index == 0 || ordered[index].year != ordered[index - 1].year)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 0, 8),
              child: Text(ordered[index].year?.toString() ?? 'Year unknown',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white70)),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle)),
                if (index < ordered.length - 1) Container(width: 2, height: 68, color: Colors.white12),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  color: Colors.white.withValues(alpha: .04),
                  child: ListTile(
                    leading: SizedBox(width: 42, height: 60, child: _artwork(context, ordered[index], BoxFit.contain)),
                    title: Text(ordered[index].title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(ordered[index].subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    onTap: ordered[index].onTap,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _artwork(BuildContext context, LibraryViewEntry entry, BoxFit fit) {
    final custom = entry.artworkBuilder;
    if (custom != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(8), child: custom(context, fit));
    }
    final url = entry.imageUrl?.trim() ?? '';
    if (url.startsWith('https://') || url.startsWith('http://')) {
      return Image.network(url, fit: fit, errorBuilder: (_, __, ___) => _placeholder(entry));
    }
    return _placeholder(entry);
  }

  Widget _placeholder(LibraryViewEntry entry) => Container(
        color: Colors.white.withValues(alpha: .045),
        alignment: Alignment.center,
        child: Icon(entry.fallbackIcon, size: 30, color: Colors.white38),
      );
}
