import 'package:material_ui/material_ui.dart';

import '../app_core.dart';
import '../catalog_poster_image.dart';
import '../group_watch.dart';

/// Starts a backend-backed shared watch session from a title the active
/// profile can access. Music and non-video extras are intentionally excluded.
class GroupWatchLibraryPickerScreen extends StatefulWidget {
  const GroupWatchLibraryPickerScreen({super.key});

  @override
  State<GroupWatchLibraryPickerScreen> createState() =>
      _GroupWatchLibraryPickerScreenState();
}

class _GroupWatchLibraryPickerScreenState
    extends State<GroupWatchLibraryPickerScreen> {
  bool _starting = false;
  String? _startingMediaId;

  List<MediaItem> get _items {
    final app = AppController.instance;
    final profile = app.currentProfile;
    return app.library.where((media) {
      if (profile == null || !media.isAccessibleTo(profile)) return false;
      if (!app.isOwned(media.id)) return false;
      final type = media.type.toLowerCase();
      final isVideo = media.isSeries ||
          type.contains('movie') ||
          type.contains('film') ||
          type.contains('episode') ||
          type.contains('video');
      return isVideo && !media.isBonusContent;
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  Future<void> _start(MediaItem media) async {
    if (_starting) return;
    final app = AppController.instance;
    final profileId = app.currentProfile?.id.trim() ?? '';
    if (profileId.isEmpty) {
      _message('Select a profile before starting a shared session.');
      return;
    }
    if (!app.backendApi.isAuthenticated) {
      _message('Sign in to your account before starting Group Watch.');
      return;
    }

    setState(() {
      _starting = true;
      _startingMediaId = media.id;
    });
    try {
      final session = await app.createBackendGroupWatchSession(
        media,
        profileId: profileId,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => GroupWatchScreen(media: media, sessionId: session.id),
      ));
    } catch (error) {
      if (mounted) {
        _message(
          'Could not start Group Watch: ${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
          _startingMediaId = null;
        });
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Watch Together')),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No owned movies or shows are available for Group Watch yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final media = items[index];
                final isCurrent = _startingMediaId == media.id;
                return Card(
                  child: ListTile(
                    leading: SizedBox(
                      width: 46,
                      height: 64,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: CatalogPosterImage(
                          media: media,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    title: Text(media.title),
                    subtitle: Text(
                      '${media.type}${media.releaseYear == null ? '' : ' · ${media.releaseYear}'}',
                    ),
                    trailing: isCurrent
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.groups_rounded),
                    onTap: _starting ? null : () => _start(media),
                  ),
                );
              },
            ),
    );
  }
}
