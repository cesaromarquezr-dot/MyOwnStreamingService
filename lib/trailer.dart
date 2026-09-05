import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple trailer model used by TrailerScreen.
///
/// This is kept here because the current app_core.dart does not
/// contain a Trailer model.
class Trailer {
  final String youtubeVideoId;
  final String title;

  const Trailer({
    required this.youtubeVideoId,
    required this.title,
  });
}

/// Opens a trailer on YouTube.
Future<void> openTrailer(
  BuildContext context,
  Trailer trailer,
) async {
  final videoId =
      trailer.youtubeVideoId.trim();

  if (videoId.isEmpty) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'This trailer does not have a YouTube video ID.',
        ),
      ),
    );

    return;
  }

  final Uri youtubeUri = Uri.https(
    'www.youtube.com',
    '/watch',
    <String, String>{
      'v': videoId,
    },
  );

  try {
    final launched = await launchUrl(
      youtubeUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open the trailer.',
          ),
        ),
      );
    }
  } catch (_) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to open the trailer.',
        ),
      ),
    );
  }
}

class TrailerScreen extends StatelessWidget {
  final Trailer trailer;

  const TrailerScreen({
    super.key,
    required this.trailer,
  });

  Future<void> launchTrailer(
    BuildContext context,
  ) async {
    await openTrailer(
      context,
      trailer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          trailer.title,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 600,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  height: 300,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(0xFF111111),
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white12,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.ondemand_video,
                      color: Colors.white,
                      size: 100,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                Text(
                  trailer.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'YouTube ID: '
                  '${trailer.youtubeVideoId}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child:
                      ElevatedButton.icon(
                    onPressed: () {
                      launchTrailer(
                        context,
                      );
                    },
                    icon: const Icon(
                      Icons.play_arrow,
                    ),
                    label: const Text(
                      'WATCH TRAILER',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}