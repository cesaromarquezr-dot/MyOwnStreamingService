import 'dart:async';

import 'package:material_ui/material_ui.dart';
import '../backend_api.dart';
import '../app_core.dart';
import '../details.dart';
import '../widgets/media_case_3d_view.dart';

class KioskMovieScreen extends StatelessWidget {
  const KioskMovieScreen({super.key, required this.media});
  final MediaItem media;
  void _openPlayback(BuildContext context) {
    final controller = AppController.instance;
    final profileId = controller.currentProfile?.id;
    if (profileId != null &&
        profileId.trim().isNotEmpty &&
        controller.backendApi.isAuthenticated) {
      unawaited(controller.backendApi
          .createKioskSession(profileId: profileId, mediaId: media.id)
          .catchError((_) => <String, dynamic>{}));
    }
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => MediaDetailsScreen(media: media)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Library item')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Center(
            child: MediaCase3DView(
                title: media.title,
                media: media,
                format: media.displayCaseFormat,
                year: media.releaseYear,
                width: 164,
                height: 220)),
        const SizedBox(height: 18),
        Text(media.title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(
            [media.type, if (media.releaseYear != null) '${media.releaseYear}']
                .join(' · '),
            textAlign: TextAlign.center),
        if ((media.description ?? '').isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(media.description!)),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () => _openPlayback(context),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Open and play from my library')),
        const SizedBox(height: 10),
        const Text(
            'Playback uses the existing library permissions and media server. The kiosk does not unlock or sell titles.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12))
      ]));
}
