import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api.dart';
import 'app_core.dart';
import 'details.dart';
import 'localization.dart';

/// A single canonical work used by a curated or catalog-generated watch guide.
/// The stable id is shared between guides so completion carries across branches.
@immutable
class FranchiseWatchEntry {
  final String id;
  final String title;
  final int? year;
  final List<String> aliases;
  final String note;
  final String? mediaId;

  const FranchiseWatchEntry({
    required this.id,
    required this.title,
    this.year,
    this.aliases = const <String>[],
    this.note = '',
    this.mediaId,
  });

  List<String> get searchableTitles => <String>{title, ...aliases}.toList();
}

@immutable
class FranchiseWatchGuide {
  final String id;
  final String title;
  final String description;
  final String continuityLabel;
  final String orderKind;
  final List<FranchiseWatchEntry> entries;
  final String? spoilerWarning;

  const FranchiseWatchGuide({
    required this.id,
    required this.title,
    required this.description,
    required this.continuityLabel,
    required this.orderKind,
    required this.entries,
    this.spoilerWarning,
  });
}

@immutable
class FranchiseWatchDefinition {
  final String id;
  final String title;
  final String description;
  final List<FranchiseWatchGuide> guides;
  final bool curated;
  final List<MediaItem> catalogItems;

  const FranchiseWatchDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.guides,
    required this.curated,
    required this.catalogItems,
  });

  int get uniqueEntryCount => guides
      .expand((guide) => guide.entries)
      .map((entry) => entry.id)
      .toSet()
      .length;
}

const FranchiseWatchEntry _h1978 = FranchiseWatchEntry(
  id: 'halloween-1978',
  title: 'Halloween',
  year: 1978,
  aliases: <String>['Halloween (1978)'],
  note:
      'The original film and the shared starting point for several continuities.',
);
const FranchiseWatchEntry _h2_1981 = FranchiseWatchEntry(
  id: 'halloween-ii-1981',
  title: 'Halloween II',
  year: 1981,
  aliases: <String>['Halloween II (1981)'],
);
const FranchiseWatchEntry _h3_1982 = FranchiseWatchEntry(
  id: 'halloween-iii-1982',
  title: 'Halloween III: Season of the Witch',
  year: 1982,
  aliases: <String>['Halloween III', 'Halloween 3: Season of the Witch'],
  note:
      'A standalone anthology story; it is part of release history, not the Michael Myers timelines.',
);
const FranchiseWatchEntry _h4_1988 = FranchiseWatchEntry(
  id: 'halloween-4-1988',
  title: 'Halloween 4: The Return of Michael Myers',
  year: 1988,
  aliases: <String>['Halloween 4', 'Halloween IV: The Return of Michael Myers'],
);
const FranchiseWatchEntry _h5_1989 = FranchiseWatchEntry(
  id: 'halloween-5-1989',
  title: 'Halloween 5: The Revenge of Michael Myers',
  year: 1989,
  aliases: <String>['Halloween 5', 'Halloween V: The Revenge of Michael Myers'],
);
const FranchiseWatchEntry _h6_1995 = FranchiseWatchEntry(
  id: 'halloween-curse-1995',
  title: 'Halloween: The Curse of Michael Myers',
  year: 1995,
  aliases: <String>[
    'Halloween 6',
    'Halloween: The Curse of Michael Myers (1995)'
  ],
);
const FranchiseWatchEntry _h20_1998 = FranchiseWatchEntry(
  id: 'halloween-h20-1998',
  title: 'Halloween H20: 20 Years Later',
  year: 1998,
  aliases: <String>['Halloween H20', 'Halloween: H20 - 20 Years Later'],
);
const FranchiseWatchEntry _hResurrection2002 = FranchiseWatchEntry(
  id: 'halloween-resurrection-2002',
  title: 'Halloween: Resurrection',
  year: 2002,
  aliases: <String>['Halloween Resurrection'],
);
const FranchiseWatchEntry _rob2007 = FranchiseWatchEntry(
  id: 'halloween-rob-zombie-2007',
  title: 'Halloween',
  year: 2007,
  aliases: <String>['Halloween (2007)', "Rob Zombie's Halloween"],
  note: 'Rob Zombie reboot continuity.',
);
const FranchiseWatchEntry _rob2009 = FranchiseWatchEntry(
  id: 'halloween-rob-zombie-ii-2009',
  title: 'Halloween II',
  year: 2009,
  aliases: <String>['Halloween II (2009)', "Rob Zombie's Halloween II"],
  note: 'Sequel to the 2007 reboot, not the 1981 film.',
);
const FranchiseWatchEntry _h2018 = FranchiseWatchEntry(
  id: 'halloween-2018',
  title: 'Halloween',
  year: 2018,
  aliases: <String>['Halloween (2018)'],
  note: 'Directly continues the 1978 original in the modern sequel continuity.',
);
const FranchiseWatchEntry _hKills2021 = FranchiseWatchEntry(
  id: 'halloween-kills-2021',
  title: 'Halloween Kills',
  year: 2021,
);
const FranchiseWatchEntry _hEnds2022 = FranchiseWatchEntry(
  id: 'halloween-ends-2022',
  title: 'Halloween Ends',
  year: 2022,
);

const List<FranchiseWatchGuide> halloweenWatchGuides = <FranchiseWatchGuide>[
  FranchiseWatchGuide(
    id: 'halloween-modern-trilogy',
    title: 'Start Here: Modern Trilogy / H40 Timeline',
    description:
        'A shorter, coherent path following the 1978 original into the modern sequel branch.',
    continuityLabel: 'Modern sequel continuity',
    orderKind: 'recommended',
    entries: <FranchiseWatchEntry>[_h1978, _h2018, _hKills2021, _hEnds2022],
    spoilerWarning: 'This path ignores sequels released between 1981 and 2017.',
  ),
  FranchiseWatchGuide(
    id: 'halloween-release-order',
    title: 'Complete Release Order',
    description:
        'All 13 theatrical films in release order. Reboots and separate continuities remain separate entries.',
    continuityLabel: 'Franchise history',
    orderKind: 'release',
    entries: <FranchiseWatchEntry>[
      _h1978,
      _h2_1981,
      _h3_1982,
      _h4_1988,
      _h5_1989,
      _h6_1995,
      _h20_1998,
      _hResurrection2002,
      _rob2007,
      _rob2009,
      _h2018,
      _hKills2021,
      _hEnds2022,
    ],
  ),
  FranchiseWatchGuide(
    id: 'halloween-original-curse',
    title: 'Original Sequel Branch (through Curse)',
    description:
        'Follows the branch through Halloween II and then Halloween 4–6. Halloween III is intentionally excluded from this story path.',
    continuityLabel: 'Original sequel branch',
    orderKind: 'recommended',
    entries: <FranchiseWatchEntry>[
      _h1978,
      _h2_1981,
      _h4_1988,
      _h5_1989,
      _h6_1995
    ],
  ),
  FranchiseWatchGuide(
    id: 'halloween-h20',
    title: 'H20 Timeline',
    description:
        'Starts with the first two films, then follows the branch leading to H20 and Resurrection.',
    continuityLabel: 'H20 continuity',
    orderKind: 'recommended',
    entries: <FranchiseWatchEntry>[
      _h1978,
      _h2_1981,
      _h20_1998,
      _hResurrection2002
    ],
    spoilerWarning: 'This branch disregards Halloween 4–6.',
  ),
  FranchiseWatchGuide(
    id: 'halloween-rob-zombie',
    title: 'Rob Zombie Remake Timeline',
    description: 'The two-film reimagining, separate from the 1978 continuity.',
    continuityLabel: 'Remake continuity',
    orderKind: 'recommended',
    entries: <FranchiseWatchEntry>[_rob2007, _rob2009],
  ),
  FranchiseWatchGuide(
    id: 'halloween-anthology',
    title: 'Standalone Anthology Entry',
    description:
        'Watch Halloween III on its own; it does not continue the Michael Myers story.',
    continuityLabel: 'Standalone anthology',
    orderKind: 'recommended',
    entries: <FranchiseWatchEntry>[_h3_1982],
  ),
];

/// Normalize title strings for conservative local catalog matching.
/// Release year remains a separate comparison so the multiple Halloween reboots
/// do not collapse into a single film.
String normalizeFranchiseTitle(String value) => value
    .replaceAll(RegExp(r'\b(?:19|20)\d{2}\b'), ' ')
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

bool isFranchiseFilmOrShow(MediaItem media) {
  final type = media.type.toLowerCase();
  return type.contains('movie') ||
      type.contains('film') ||
      type.contains('show') ||
      type.contains('series') ||
      type.contains('episode') ||
      type.contains('tv');
}

/// Build a directory from the curated Halloween guides and actual accessible
/// catalog franchise metadata. Editions sharing canonicalWorkId count once.
List<FranchiseWatchDefinition> buildFranchiseWatchDirectory({
  required List<MediaItem> library,
  required Profile? profile,
}) {
  final accessible = library
      .where((m) => m.isAccessibleTo(profile) && isFranchiseFilmOrShow(m))
      .toList();
  final halloweenCatalog = _uniqueWorks(accessible.where((m) {
    final text =
        '${m.franchiseId ?? ''} ${m.franchiseName ?? ''}'.toLowerCase();
    return text.contains('halloween');
  }).toList());
  final result = <FranchiseWatchDefinition>[
    FranchiseWatchDefinition(
      id: 'halloween',
      title: 'Halloween',
      description:
          'Multiple timelines, a reboot branch, and a standalone anthology entry.',
      guides: halloweenWatchGuides,
      curated: true,
      catalogItems: halloweenCatalog,
    ),
  ];

  final grouped = <String, List<MediaItem>>{};
  final displayNames = <String, String>{};
  for (final media in accessible) {
    final name = (media.franchiseName ?? '').trim();
    final id = (media.franchiseId ?? '').trim();
    if (name.isEmpty && id.isEmpty) {
      continue;
    }
    final title = name.isNotEmpty ? name : id;
    final key =
        (id.isNotEmpty ? id : normalizeFranchiseTitle(title)).toLowerCase();
    // Halloween uses the curated branch guides above rather than the generic
    // metadata-derived guide. Keep its catalog matching in that definition.
    if (key.contains('halloween') ||
        normalizeFranchiseTitle(title) == 'halloween') {
      continue;
    }
    grouped.putIfAbsent(key, () => <MediaItem>[]).add(media);
    displayNames.putIfAbsent(key, () => title);
  }

  for (final group in grouped.entries) {
    final works = _uniqueWorks(group.value);
    works.sort((a, b) {
      final ao = a.franchiseOrder;
      final bo = b.franchiseOrder;
      if (ao != null && bo != null && ao != bo) {
        return ao.compareTo(bo);
      }
      if (ao != null && bo == null) {
        return -1;
      }
      if (ao == null && bo != null) {
        return 1;
      }
      final ay = a.releaseYear ?? 9999;
      final by = b.releaseYear ?? 9999;
      if (ay != by) {
        return ay.compareTo(by);
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    final entries = works.asMap().entries.map((indexed) {
      final media = indexed.value;
      final canonical = (media.canonicalWorkId ?? '').trim();
      return FranchiseWatchEntry(
        id: 'catalog-${group.key}-${canonical.isNotEmpty ? canonical : media.id}',
        title: media.title,
        year: media.releaseYear,
        aliases: <String>[
          media.title,
          if (media.originalTitle?.trim().isNotEmpty == true)
            media.originalTitle!.trim()
        ],
        note: media.franchiseOrder == null
            ? 'Catalog order item ${indexed.key + 1}.'
            : 'Franchise order ${media.franchiseOrder}.',
        mediaId: media.id,
      );
    }).toList(growable: false);
    result.add(FranchiseWatchDefinition(
      id: group.key,
      title: displayNames[group.key] ?? group.key,
      description:
          'Generated from the titles tagged with this franchise in your accessible catalog. A verified continuity guide has not been supplied yet.',
      guides: <FranchiseWatchGuide>[
        FranchiseWatchGuide(
          id: '${group.key}-catalog-order',
          title: 'Your Library Order',
          description:
              'Uses explicit franchise order when present, then release year. Confirm continuity details before treating this as story chronology.',
          continuityLabel: 'Catalog-derived order',
          orderKind: 'release',
          entries: entries,
        ),
      ],
      curated: false,
      catalogItems: works,
    ));
  }
  result.sort((a, b) {
    if (a.id == 'halloween') {
      return -1;
    }
    if (b.id == 'halloween') {
      return 1;
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return result;
}

List<MediaItem> _uniqueWorks(List<MediaItem> items) {
  final seen = <String>{};
  return items.where((media) {
    final canonical = (media.canonicalWorkId ?? '').trim();
    final identity =
        canonical.isNotEmpty ? 'work:$canonical' : 'media:${media.id}';
    return seen.add(identity);
  }).toList(growable: false);
}

/// Finds a matching title only within items the caller has already filtered for
/// profile access. Exact ids are preferred; ambiguous title matches are hidden.
MediaItem? matchFranchiseEntryToMedia(
  FranchiseWatchEntry entry,
  List<MediaItem> accessibleLibrary,
) {
  if (entry.mediaId != null) {
    for (final item in accessibleLibrary) {
      if (item.id == entry.mediaId) {
        return item;
      }
    }
  }
  final aliases = entry.searchableTitles
      .map(normalizeFranchiseTitle)
      .where((s) => s.isNotEmpty)
      .toSet();
  final candidates = accessibleLibrary.where((item) {
    if (!isFranchiseFilmOrShow(item)) {
      return false;
    }
    if (entry.year != null &&
        item.releaseYear != null &&
        entry.year != item.releaseYear) {
      return false;
    }
    final titles = <String>{
      normalizeFranchiseTitle(item.title),
      normalizeFranchiseTitle(item.canonicalTitle ?? ''),
      normalizeFranchiseTitle(item.originalTitle ?? ''),
    }..remove('');
    return titles.any(aliases.contains);
  }).toList();
  if (candidates.isEmpty) {
    return null;
  }
  if (entry.year != null) {
    final exactYear =
        candidates.where((m) => m.releaseYear == entry.year).toList();
    if (exactYear.isNotEmpty) {
      return exactYear.length == 1
          ? exactYear.first
          : _firstCanonicalEdition(exactYear);
    }
  }
  // If similarly named reboots or remasters remain ambiguous without a year,
  // do not open a potentially wrong film.
  if (candidates.length == 1) {
    return candidates.first;
  }
  return _firstCanonicalEdition(candidates);
}

MediaItem? _firstCanonicalEdition(List<MediaItem> candidates) {
  final canonicalIds = candidates
      .map((m) => (m.canonicalWorkId ?? '').trim())
      .toList(growable: false);
  if (canonicalIds.isNotEmpty &&
      canonicalIds.every((id) => id.isNotEmpty) &&
      canonicalIds.toSet().length == 1) {
    return candidates.first;
  }
  return null;
}

class FranchiseWatchOrdersScreen extends StatefulWidget {
  const FranchiseWatchOrdersScreen({super.key});

  @override
  State<FranchiseWatchOrdersScreen> createState() =>
      _FranchiseWatchOrdersScreenState();
}

class _FranchiseWatchOrdersScreenState
    extends State<FranchiseWatchOrdersScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    final definitions = buildFranchiseWatchDirectory(
        library: controller.library, profile: profile);
    final filtered = definitions
        .where((franchise) =>
            query.trim().isEmpty ||
            '${franchise.title} ${franchise.description}'
                .toLowerCase()
                .contains(query.trim().toLowerCase()))
        .toList();

    return Scaffold(
      appBar:
          AppBar(title: const UniversalText('Franchise Hub & Watch Orders')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
              gradient: LinearGradient(colors: [
                Colors.deepPurple.withValues(alpha: .38),
                Colors.red.withValues(alpha: .17)
              ]),
            ),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_tree_rounded, size: 38),
                  SizedBox(height: 10),
                  Text('Choose the story path',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  Text(
                      'Explore release order, alternate continuities, remakes, and standalone entries. Shared films stay one catalog item and their progress carries between guides.',
                      style: TextStyle(color: Colors.white70, height: 1.4)),
                ]),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Find a franchise',
                hintText: 'Halloween, Star Wars, Spider-Man…'),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Text(
                        'No tagged franchises found in your accessible library yet. Add verified franchise metadata during catalog import.')))
          else
            ...filtered.map((definition) => _FranchiseCard(
                  definition: definition,
                  accessibleLibrary: controller.library
                      .where((m) => m.isAccessibleTo(profile))
                      .toList(growable: false),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FranchiseWatchOrderDetailScreen(
                              definition: definition))),
                )),
        ],
      ),
    );
  }
}

class _FranchiseCard extends StatelessWidget {
  final FranchiseWatchDefinition definition;
  final List<MediaItem> accessibleLibrary;
  final VoidCallback onTap;
  const _FranchiseCard(
      {required this.definition,
      required this.accessibleLibrary,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final available = definition.guides
        .expand((g) => g.entries)
        .toSet()
        .where((entry) =>
            matchFranchiseEntryToMedia(entry, accessibleLibrary) != null)
        .map((e) => e.id)
        .toSet()
        .length;
    final total = definition.uniqueEntryCount;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
            radius: 27,
            backgroundColor: Colors.deepPurple.withValues(alpha: .35),
            child: Icon(
                definition.id == 'halloween'
                    ? Icons.nights_stay_rounded
                    : Icons.movie_filter_rounded,
                size: 28)),
        title: Text(definition.title,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                '${definition.guides.length} guide${definition.guides.length == 1 ? '' : 's'} · $available of $total distinct works matched in your accessible library\n${definition.description}')),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class FranchiseWatchOrderDetailScreen extends StatefulWidget {
  final FranchiseWatchDefinition definition;
  const FranchiseWatchOrderDetailScreen({super.key, required this.definition});

  @override
  State<FranchiseWatchOrderDetailScreen> createState() =>
      _FranchiseWatchOrderDetailScreenState();
}

class _FranchiseWatchOrderDetailScreenState
    extends State<FranchiseWatchOrderDetailScreen> {
  Set<String> watchedEntryIds = <String>{};
  String? selectedGuideId;
  bool hideWatched = false;
  bool _loaded = false;
  bool _syncFailed = false;

  String get _profileId =>
      AppController.instance.currentProfile?.id ?? 'default';
  String get _prefsKey =>
      'moss_franchise_watch_order_v1_${_profileId}_${widget.definition.id}';
  FranchiseWatchGuide get _selectedGuide => widget.definition.guides.firstWhere(
        (guide) => guide.id == selectedGuideId,
        orElse: () => widget.definition.guides.first,
      );
  List<MediaItem> get _accessibleLibrary => AppController.instance.library
      .where(
          (item) => item.isAccessibleTo(AppController.instance.currentProfile))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    selectedGuideId = widget.definition.guides.isEmpty
        ? null
        : widget.definition.guides.first.id;
    _loadProgress();
  }

  Map<String, dynamic>? _decodeProgress(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  DateTime? _timestamp(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toUtc();

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final saved = jsonDecode(raw);
        if (saved is Map) {
          watchedEntryIds =
              (saved['watchedEntryIds'] as List? ?? const <dynamic>[])
                  .map((e) => e.toString())
                  .toSet();
          final savedGuide = saved['selectedGuideId']?.toString();
          if (widget.definition.guides.any((guide) => guide.id == savedGuide)) {
            selectedGuideId = savedGuide;
          }
        }
      } catch (_) {
        // A corrupt local progress blob should not prevent the guide opening.
      }
    }
    if (mounted) setState(() => _loaded = true);

    // Sync progress through the existing profile-scoped app-record API when
    // authenticated. Local progress remains available if the backend is offline.
    final profile = AppController.instance.currentProfile;
    final api = AppController.instance.backendApi;
    if (profile == null || !api.isAuthenticated) {
      return;
    }
    try {
      final records = await api.getAppRecords(
          profileId: profile.id, recordType: 'franchise_watch_progress');
      Map<String, dynamic>? data;
      for (final record in records) {
        if (record['recordKey'] == 'franchise:${widget.definition.id}' &&
            record['data'] is Map) {
          data = Map<String, dynamic>.from(record['data'] as Map);
          break;
        }
      }
      if (data != null) {
        final localUpdatedAt =
            _timestamp(raw == null ? null : _decodeProgress(raw)?['updatedAt']);
        final serverUpdatedAt = _timestamp(data['updatedAt']);
        final localIsNewer = localUpdatedAt != null &&
            (serverUpdatedAt == null ||
                localUpdatedAt.isAfter(serverUpdatedAt));
        if (localIsNewer) {
          // Offline changes take precedence over an older server snapshot, so
          // unmarking a watched title is not undone by an unconditional union.
          await _saveProgress(sync: true);
        } else {
          watchedEntryIds =
              (data['watchedEntryIds'] as List? ?? const <dynamic>[])
                  .map((e) => e.toString())
                  .toSet();
          final savedGuide = data['selectedGuideId']?.toString();
          if (widget.definition.guides.any((guide) => guide.id == savedGuide)) {
            selectedGuideId = savedGuide;
          }
          // Preserve the server snapshot timestamp so it does not look like a
          // newer local edit on every subsequent open.
          await prefs.setString(_prefsKey, jsonEncode(data));
        }
        if (mounted) setState(() {});
      } else if (raw != null) {
        // First-time sync: upload local progress if this profile has no server
        // record yet. The backend record remains scoped to this profile.
        await _saveProgress(sync: true);
      }
    } catch (_) {
      // Local progress is the fallback; do not block the core watch-guide UI.
    }
  }

  Future<void> _saveProgress({bool sync = true}) async {
    final data = <String, dynamic>{
      'franchiseId': widget.definition.id,
      'franchiseTitle': widget.definition.title,
      'watchedEntryIds': watchedEntryIds.toList()..sort(),
      'selectedGuideId': selectedGuideId,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(data));
    if (!sync) {
      return;
    }
    final profile = AppController.instance.currentProfile;
    final api = AppController.instance.backendApi;
    if (profile == null || !api.isAuthenticated) {
      return;
    }
    try {
      await api.saveAppRecord(
        profileId: profile.id,
        recordType: 'franchise_watch_progress',
        recordKey: 'franchise:${widget.definition.id}',
        data: data,
      );
      if (mounted && _syncFailed) setState(() => _syncFailed = false);
    } catch (_) {
      if (mounted) setState(() => _syncFailed = true);
    }
  }

  Future<void> _toggleWatched(FranchiseWatchEntry entry, bool value) async {
    setState(() {
      if (value) {
        watchedEntryIds.add(entry.id);
      } else {
        watchedEntryIds.remove(entry.id);
      }
    });
    await _saveProgress();
  }

  Future<void> _selectGuide(String guideId) async {
    setState(() => selectedGuideId = guideId);
    await _saveProgress();
  }

  Future<void> _openEntry(FranchiseWatchEntry entry) async {
    final media = matchFranchiseEntryToMedia(entry, _accessibleLibrary);
    if (media == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '“${entry.title}” is not matched to a unique, accessible library title yet. Import or correct its title and release-year metadata before opening it.')));
      return;
    }
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: media)));
  }

  Future<void> _continueGuide() async {
    final remaining = _selectedGuide.entries
        .where((entry) => !watchedEntryIds.contains(entry.id))
        .toList();
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You marked every entry in this guide as watched.')));
      return;
    }
    await _openEntry(remaining.first);
  }

  @override
  Widget build(BuildContext context) {
    final guide = _selectedGuide;
    final entries = hideWatched
        ? guide.entries.where((e) => !watchedEntryIds.contains(e.id)).toList()
        : guide.entries;
    final count = guide.entries
        .where((entry) => watchedEntryIds.contains(entry.id))
        .length;
    final ratio = guide.entries.isEmpty ? 0.0 : count / guide.entries.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.definition.title), actions: [
        IconButton(
            tooltip:
                hideWatched ? 'Show watched entries' : 'Hide watched entries',
            onPressed: () => setState(() => hideWatched = !hideWatched),
            icon: Icon(hideWatched
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded)),
      ]),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
              children: [
                  Text(widget.definition.description,
                      style:
                          const TextStyle(color: Colors.white70, height: 1.4)),
                  const SizedBox(height: 14),
                  if (widget.definition.guides.length > 1) ...[
                    const Text('Choose a continuity or viewing order',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.definition.guides
                          .map((candidate) => ChoiceChip(
                                label: Text(candidate.title),
                                selected: candidate.id == guide.id,
                                onSelected: (_) => _selectGuide(candidate.id),
                              ))
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(guide.title,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 5),
                                Text(
                                    '${guide.continuityLabel} · ${guide.entries.length} entries · $count completed',
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 12),
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                        value: ratio, minHeight: 7)),
                                const SizedBox(height: 10),
                                Text(guide.description,
                                    style: const TextStyle(height: 1.4)),
                                if (guide.spoilerWarning != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                            Icons.visibility_off_outlined,
                                            size: 18),
                                        const SizedBox(width: 7),
                                        Expanded(
                                            child: Text(guide.spoilerWarning!,
                                                style: const TextStyle(
                                                    color: Colors.amberAccent)))
                                      ]),
                                ],
                                const SizedBox(height: 12),
                                Wrap(spacing: 10, runSpacing: 8, children: [
                                  FilledButton.icon(
                                      onPressed: guide.entries.isEmpty
                                          ? null
                                          : _continueGuide,
                                      icon:
                                          const Icon(Icons.play_arrow_rounded),
                                      label: const Text('Continue guide')),
                                  OutlinedButton.icon(
                                      onPressed: () =>
                                          _openEntry(guide.entries.first),
                                      icon:
                                          const Icon(Icons.first_page_rounded),
                                      label:
                                          const Text('Start from beginning')),
                                ]),
                                if (_syncFailed)
                                  const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Text(
                                          'Progress is saved on this device; account sync is currently unavailable.',
                                          style: TextStyle(
                                              color: Colors.amberAccent))),
                              ]))),
                  const SizedBox(height: 10),
                  for (var index = 0; index < entries.length; index++)
                    _buildEntryCard(entries[index],
                        guide.entries.indexOf(entries[index]) + 1),
                  if (entries.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: Text(
                                'All entries in this guide are marked watched.'))),
                  const SizedBox(height: 6),
                  const Text(
                      'Availability means a matching title exists in the active profile’s accessible catalog. It does not guarantee a provider subscription or a working stream. A guide never unlocks unavailable media.',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12, height: 1.35)),
                ]),
    );
  }

  Widget _buildEntryCard(FranchiseWatchEntry entry, int position) {
    final media = matchFranchiseEntryToMedia(entry, _accessibleLibrary);
    final watched = watchedEntryIds.contains(entry.id);
    final artwork = media?.imageUrl;
    return Card(
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 34,
                child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                        child: Text('$position',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white60))))),
            if (artwork != null && artwork.trim().isNotEmpty)
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(artwork,
                      width: 64,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _posterFallback()))
            else
              _posterFallback(),
            const SizedBox(width: 10),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4, right: 6),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 3),
                          Text(
                              '${entry.year ?? 'Year unknown'}${watched ? ' · Watched' : ''}',
                              style: const TextStyle(color: Colors.white70)),
                          if (entry.note.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(entry.note,
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    height: 1.3))
                          ],
                          const SizedBox(height: 7),
                          Row(children: [
                            Icon(
                                media == null
                                    ? Icons.video_library_outlined
                                    : Icons.check_circle_outline,
                                size: 15,
                                color: media == null
                                    ? Colors.white38
                                    : Colors.greenAccent),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(
                                    media == null
                                        ? 'Not matched in this profile’s library'
                                        : 'In accessible library',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: media == null
                                            ? Colors.white54
                                            : Colors.greenAccent))),
                          ]),
                          const SizedBox(height: 4),
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            TextButton.icon(
                                onPressed: media == null
                                    ? null
                                    : () => _openEntry(entry),
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 16),
                                label: Text(media == null
                                    ? 'Unavailable here'
                                    : 'Open title')),
                            TextButton.icon(
                                onPressed: () =>
                                    _toggleWatched(entry, !watched),
                                icon: Icon(
                                    watched
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 16),
                                label: Text(watched
                                    ? 'Mark unwatched'
                                    : 'Mark watched')),
                          ]),
                        ]))),
          ])),
    );
  }

  Widget _posterFallback() => Container(
      width: 64,
      height: 92,
      decoration: BoxDecoration(
          color: Colors.white10, borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.movie_outlined));
}
