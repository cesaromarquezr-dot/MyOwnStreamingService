import 'package:material_ui/material_ui.dart';
import '../app_core.dart';
import '../details.dart';
import '../models/theater_models.dart';
import '../widgets/theater_ticket_qr.dart';

class TheaterTicketScreen extends StatelessWidget {
  const TheaterTicketScreen(
      {super.key, required this.media, required this.session});
  final MediaItem media;
  final TheaterSession session;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Private screening pass')),
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.local_activity_rounded, size: 42),
                        const SizedBox(height: 8),
                        Text('YOUR PRIVATE SCREENING',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        Text(media.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                            'Room: ${session.roomId} · Seats: ${session.seatIds.isEmpty ? 'Not assigned' : session.seatIds.join(', ')}'),
                        const SizedBox(height: 18),
                        TheaterTicketQr(sessionId: session.id),
                        const SizedBox(height: 12),
                        Text('Pass ${session.id}',
                            style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 8),
                        const Text(
                            'No admission fee. This pass is only a local reference for your own theater session.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 18),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            MediaDetailsScreen(media: media))),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Play from my library')))
                      ]))))));
}
