import 'package:flutter/material.dart';

class LibraryReleaseChoice {
  final bool schedule;
  final DateTime? scheduledFor;
  final String timeZone;

  const LibraryReleaseChoice({
    required this.schedule,
    this.scheduledFor,
    this.timeZone = 'UTC',
  });
}

/// Account-wide release choice. Profiles are intentionally not selectable:
/// imported media belongs to the account's NAS library.
Future<LibraryReleaseChoice?> showLibraryReleaseChoice(
  BuildContext context,
) async {
  var schedule = false;
  DateTime? date;
  TimeOfDay? time;
  final now = DateTime.now();

  final result = await showDialog<LibraryReleaseChoice>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add to Account Library'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The media is stored once on the account home NAS and is shared by all active profiles.',
              ),
              const SizedBox(height: 16),

              RadioGroup<bool>(
                groupValue: schedule,
                onChanged: (value) {
                  setState(() => schedule = value ?? false);
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      value: false,
                      title: const Text('Right Now'),
                      subtitle: const Text(
                        'Publish immediately to the account library.',
                      ),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      title: const Text('Schedule Additions'),
                      subtitle: const Text(
                        'Keep the import staged until the release time.',
                      ),
                    ),
                  ],
                ),
              ),

              if (schedule) ...[
                const SizedBox(height: 8),

                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    date == null
                        ? 'Choose release date'
                        : MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(date!),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: now,
                      lastDate: DateTime(now.year + 5),
                      initialDate:
                          date ?? now.add(const Duration(days: 1)),
                    );

                    if (picked != null) {
                      setState(() => date = picked);
                    }
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(
                    time == null
                        ? 'Choose release time'
                        : time!.format(context),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          time ?? const TimeOfDay(hour: 7, minute: 0),
                    );

                    if (picked != null) {
                      setState(() => time = picked);
                    }
                  },
                ),

                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text(
                    'Time zone: Mountain Time (device/backend should preserve the account release zone).',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: schedule && (date == null || time == null)
                ? null
                : () {
                    final selected = schedule
                        ? DateTime(
                            date!.year,
                            date!.month,
                            date!.day,
                            time!.hour,
                            time!.minute,
                          )
                        : null;

                    Navigator.pop(
                      dialogContext,
                      LibraryReleaseChoice(
                        schedule: schedule,
                        scheduledFor: selected,
                        timeZone: 'America/Denver',
                      ),
                    );
                  },
            child: Text(schedule ? 'Schedule' : 'Add Now'),
          ),
        ],
      ),
    ),
  );

  return result;
}

class ComingSoonScreen extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() loader;

  const ComingSoonScreen({
    super.key,
    required this.loader,
  });

  @override
  State<ComingSoonScreen> createState() => _ComingSoonScreenState();
}

class _ComingSoonScreenState extends State<ComingSoonScreen> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coming Soon'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final items =
              snapshot.data ?? const <Map<String, dynamic>>[];

          if (items.isEmpty) {
            return const Center(
              child: Text('Nothing is scheduled for release.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];

              final when = DateTime.tryParse(
                item['scheduledFor']?.toString() ?? '',
              )?.toLocal();

              return Card(
                child: ListTile(
                  leading: Icon(
                    _icon(item['mediaType']?.toString() ?? ''),
                  ),
                  title: Text(
                    item['title']?.toString() ?? 'Untitled',
                  ),
                  subtitle: Text(
                    when == null
                        ? 'Scheduled'
                        : 'Available '
                            '${MaterialLocalizations.of(context).formatFullDate(when)} '
                            'at '
                            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(when))}',
                  ),
                  trailing: const Icon(
                    Icons.schedule_outlined,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _icon(String type) {
    final value = type.toLowerCase();

    if (value.contains('music') || value.contains('album')) {
      return Icons.album_outlined;
    }

    if (value.contains('tv') || value.contains('show')) {
      return Icons.tv_outlined;
    }

    return Icons.movie_outlined;
  }
}