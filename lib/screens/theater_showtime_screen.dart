import 'package:material_ui/material_ui.dart';
import '../app_core.dart';
import '../models/theater_models.dart';
import 'theater_seat_selection_screen.dart';

class TheaterShowtimeScreen extends StatelessWidget {
  const TheaterShowtimeScreen({super.key, required this.media});
  final MediaItem media;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final times = [
      now,
      DateTime(now.year, now.month, now.day, now.hour, now.minute)
          .add(const Duration(minutes: 15)),
      DateTime(now.year, now.month, now.day, now.hour, now.minute)
          .add(const Duration(hours: 1))
    ];
    return Scaffold(
        appBar: AppBar(title: const Text('Private screening')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Text(media.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
              'Choose when to start your at-home screening. These are local reminders, not commercial cinema showtimes.'),
          const SizedBox(height: 18),
          for (var i = 0; i < times.length; i++)
            Card(
              child: ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(i == 0
                      ? 'Start now'
                      : i == 1
                          ? 'In 15 minutes'
                          : 'In about 1 hour'),
                  subtitle:
                      Text(TimeOfDay.fromDateTime(times[i]).format(context)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => TheaterSeatSelectionScreen(
                              media: media,
                              showtime: TheaterShowtime(
                                  id: 'local-${media.id}-$i',
                                  mediaId: media.id,
                                  title: media.title,
                                  startsAt: times[i],
                                  durationMinutes: media.runtimeMinutes,
                                  posterUrl: media.imageUrl))))),
            ),
          const SizedBox(height: 8),
          const Text(
              'No ticket price, checkout, or payment step is part of the private theater.',
              style: TextStyle(color: Colors.grey, fontSize: 12))
        ]));
  }
}
