import 'package:material_ui/material_ui.dart';
import '../app_core.dart';
import '../models/theater_models.dart';
import '../stores/theater_store.dart';
import '../widgets/theater_seat_map.dart';
import 'theater_ticket_screen.dart';

class TheaterSeatSelectionScreen extends StatefulWidget {
  const TheaterSeatSelectionScreen(
      {super.key, required this.media, required this.showtime});
  final MediaItem media;
  final TheaterShowtime showtime;
  @override
  State<TheaterSeatSelectionScreen> createState() =>
      _TheaterSeatSelectionScreenState();
}

class _TheaterSeatSelectionScreenState
    extends State<TheaterSeatSelectionScreen> {
  final Set<String> _selected = <String>{};
  bool _saving = false;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Choose your seats')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text(widget.media.title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text(
            'Seats are only a private room-layout preference. They are not reserved for sale.'),
        const SizedBox(height: 22),
        TheaterSeatMap(
            selectedSeats: _selected,
            onChanged: (v) => setState(() {
                  _selected
                    ..clear()
                    ..addAll(v);
                })),
        const SizedBox(height: 22),
        FilledButton.icon(
            onPressed: _saving ? null : _continue,
            icon: const Icon(Icons.confirmation_number_outlined),
            label: Text(
                _saving ? 'Saving…' : 'Create free private screening pass'))
      ]));
  Future<void> _continue() async {
    setState(() => _saving = true);
    try {
      final session = await TheaterStore.instance.createSession(
          mediaId: widget.media.id,
          title: widget.media.title,
          seatIds: _selected,
          roomId: widget.showtime.roomId);
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
              builder: (_) =>
                  TheaterTicketScreen(media: widget.media, session: session)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
