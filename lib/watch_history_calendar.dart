import 'package:material_ui/material_ui.dart';

import 'app_core.dart';
import 'details.dart';
import 'entertainment_extensions.dart';
import 'localization.dart';

enum HistoryMediaFilter { all, movies, shows, music }

class ActivityStreakSummary {
  const ActivityStreakSummary({
    required this.currentDays,
    required this.longestDays,
  });

  final int currentDays;
  final int longestDays;
}

class WatchHistoryCalendarData {
  const WatchHistoryCalendarData._();

  static int _dayOrdinal(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  static bool matches(
    WrappedActivityRecord event,
    HistoryMediaFilter filter,
  ) {
    if (filter == HistoryMediaFilter.all) return true;
    final type = event.type.toLowerCase();
    return switch (filter) {
      HistoryMediaFilter.all => true,
      HistoryMediaFilter.movies => type.contains('movie') ||
          type.contains('film') ||
          type.contains('documentary') ||
          type.contains('special'),
      HistoryMediaFilter.shows => type.contains('show') ||
          type.contains('series') ||
          type.contains('episode'),
      HistoryMediaFilter.music => type.contains('song') ||
          type.contains('track') ||
          type.contains('music') ||
          type.contains('album'),
    };
  }

  static ActivityStreakSummary streaks(
    Iterable<WrappedActivityRecord> events, {
    required HistoryMediaFilter filter,
    required DateTime today,
  }) {
    final activeDays = events
        .where((event) => matches(event, filter))
        .map((event) => DateUtils.dateOnly(event.occurredAt.toLocal()))
        .toSet()
        .toList()
      ..sort();
    if (activeDays.isEmpty) {
      return const ActivityStreakSummary(currentDays: 0, longestDays: 0);
    }

    var longest = 1;
    var run = 1;
    for (var index = 1; index < activeDays.length; index++) {
      if (_dayOrdinal(activeDays[index]) - _dayOrdinal(activeDays[index - 1]) ==
          1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }

    final activeSet = activeDays.toSet();
    var cursor = DateUtils.dateOnly(today);
    if (!activeSet.contains(cursor)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var current = 0;
    while (activeSet.contains(cursor)) {
      current++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return ActivityStreakSummary(currentDays: current, longestDays: longest);
  }
}

class WatchHistoryCalendarScreen extends StatefulWidget {
  const WatchHistoryCalendarScreen({super.key});

  @override
  State<WatchHistoryCalendarScreen> createState() =>
      _WatchHistoryCalendarScreenState();
}

class _WatchHistoryCalendarScreenState
    extends State<WatchHistoryCalendarScreen> {
  final DateTime _today = DateUtils.dateOnly(DateTime.now());
  DateTime? _selectedDate;
  late DateTime _displayedMonth;
  List<WrappedActivityRecord> _events = const <WrappedActivityRecord>[];
  HistoryMediaFilter _filter = HistoryMediaFilter.all;
  String _loadedProfileId = '';
  bool _loading = true;
  String? _error;

  String get _profileId =>
      AppController.instance.currentProfile?.id.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _loadedProfileId = _profileId;
    _displayedMonth = DateTime(_today.year, _today.month);
    _selectedDate = _today;
    AppController.instance.addListener(_onProfileChanged);
    _load();
  }

  @override
  void dispose() {
    AppController.instance.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (_loadedProfileId == _profileId) return;
    _loadedProfileId = _profileId;
    setState(() {
      _events = const <WrappedActivityRecord>[];
      _error = null;
      _selectedDate = _today;
      _displayedMonth = DateTime(_today.year, _today.month);
    });
    _load();
  }

  Future<void> _load() async {
    final profileId = _profileId;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (profileId.isEmpty) {
      if (mounted) {
        setState(() {
          _events = const <WrappedActivityRecord>[];
          _loading = false;
        });
      }
      return;
    }
    try {
      final events = await WrappedArchiveStore.loadEvents(profileId);
      if (!mounted || profileId != _profileId) return;
      setState(() {
        _events = events.where((event) => event.profileId == profileId).toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
        _loading = false;
      });
    } catch (error) {
      if (!mounted || profileId != _profileId) return;
      setState(() {
        _error = 'History could not be loaded: $error';
        _loading = false;
      });
    }
  }

  List<WrappedActivityRecord> get _filteredEvents => _events
      .where((event) => WatchHistoryCalendarData.matches(event, _filter))
      .toList(growable: false);

  Map<DateTime, int> get _monthlyCounts {
    final counts = <DateTime, int>{};
    for (final event in _filteredEvents) {
      final localDate = DateUtils.dateOnly(event.occurredAt.toLocal());
      if (localDate.year == _displayedMonth.year &&
          localDate.month == _displayedMonth.month) {
        counts[localDate] = (counts[localDate] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<WrappedActivityRecord> get _selectedEvents {
    final selectedDate = _selectedDate;
    if (selectedDate == null) return const <WrappedActivityRecord>[];
    return _filteredEvents.where((event) {
      return DateUtils.isSameDay(event.occurredAt.toLocal(), selectedDate);
    }).toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  void _changeMonth(int amount) {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + amount);
    });
  }

  String _filterLabel(HistoryMediaFilter filter) => switch (filter) {
        HistoryMediaFilter.all => 'All',
        HistoryMediaFilter.movies => 'Movies',
        HistoryMediaFilter.shows => 'Shows',
        HistoryMediaFilter.music => 'Music',
      };

  String _eventTypeLabel(WrappedActivityRecord event) {
    final type = event.type.toLowerCase();
    if (type.contains('song') || type.contains('track')) return 'Music';
    if (type.contains('episode') ||
        type.contains('series') ||
        type.contains('show')) {
      return 'Show';
    }
    if (type.contains('movie') || type.contains('film')) return 'Movie';
    return event.type;
  }

  MediaItem? _libraryMediaFor(WrappedActivityRecord event) {
    for (final media in AppController.instance.library) {
      if (media.id == event.mediaId) return media;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final counts = _monthlyCounts;
    final streak = WatchHistoryCalendarData.streaks(
      _events,
      filter: _filter,
      today: _today,
    );
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Watch History Calendar'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const UniversalText(
            'Your playback activity, by day',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const UniversalText(
            'This calendar uses this profile’s locally saved playback-start history, including movies, episodes and music.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 14),
          SegmentedButton<HistoryMediaFilter>(
            segments: HistoryMediaFilter.values
                .map((filter) => ButtonSegment<HistoryMediaFilter>(
                      value: filter,
                      label: Text(_filterLabel(filter)),
                    ))
                .toList(growable: false),
            selected: <HistoryMediaFilter>{_filter},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                setState(() => _filter = selection.first);
              }
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            localizations.formatMonthYear(_displayedMonth),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  _buildCalendarGrid(localizations, counts),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_fire_department_rounded),
              title: Text('${streak.currentDays}-day current streak'),
              subtitle: Text('Longest streak: ${streak.longestDays} days'),
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                title: const Text('History unavailable'),
                subtitle: Text(_error!),
                trailing: TextButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
              ),
            )
          else
            _buildSelectedDay(localizations),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(
    MaterialLocalizations localizations,
    Map<DateTime, int> counts,
  ) {
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month);
    final dayCount =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstWeekdayIndex = (firstOfMonth.weekday % 7);
    final firstDayOffset =
        (firstWeekdayIndex - localizations.firstDayOfWeekIndex + 7) % 7;
    final cellCount = ((firstDayOffset + dayCount + 6) ~/ 7) * 7;
    final weekdayLabels = List<String>.generate(
      7,
      (index) => localizations
          .narrowWeekdays[(index + localizations.firstDayOfWeekIndex) % 7],
    );

    return Column(
      children: [
        Row(
          children: weekdayLabels
              .map((label) => Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(label,
                            style: const TextStyle(color: Colors.white60)),
                      ),
                    ),
                  ))
              .toList(growable: false),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 52,
          ),
          itemBuilder: (context, index) {
            final day = index - firstDayOffset + 1;
            if (day < 1 || day > dayCount) return const SizedBox.shrink();
            final date =
                DateTime(_displayedMonth.year, _displayedMonth.month, day);
            final count = counts[date] ?? 0;
            final selected = DateUtils.isSameDay(date, _selectedDate);
            return Semantics(
              button: true,
              selected: selected,
              label: '${localizations.formatMediumDate(date)}, $count items',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : count > 0
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: .18)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day'),
                      if (count > 0)
                        Text(
                          '$count',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white70),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSelectedDay(MaterialLocalizations localizations) {
    final selected = _selectedDate;
    if (selected == null) return const SizedBox.shrink();
    final events = _selectedEvents;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.formatFullDate(selected),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: UniversalText(
                  'No playback activity recorded for this day.',
                  style: TextStyle(color: Colors.white60),
                ),
              )
            else
              ...events.map((event) {
                final media = _libraryMediaFor(event);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle_outline_rounded),
                  title: Text(event.title),
                  subtitle: Text([
                    _eventTypeLabel(event),
                    if (event.artist?.isNotEmpty == true) event.artist!,
                    if (event.album?.isNotEmpty == true) event.album!,
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay.fromDateTime(event.occurredAt.toLocal()),
                    ),
                  ].join(' • ')),
                  trailing: media == null
                      ? null
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: media == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              settings: const RouteSettings(
                                  name: '/app/details/history'),
                              builder: (_) => MediaDetailsScreen(media: media),
                            ),
                          ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
