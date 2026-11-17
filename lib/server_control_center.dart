import 'package:material_ui/material_ui.dart';

import 'all_owned_media.dart';
import 'app_core.dart';
import 'library_organization_studio.dart';

/// A polished, user-facing home-server control surface.
///
/// The client can report authentication and local catalog readiness. It does
/// not pretend to know host CPU, disk, transcoder, or network telemetry unless
/// a dedicated server diagnostics endpoint is added.
class ServerControlCenterScreen extends StatefulWidget {
  const ServerControlCenterScreen({super.key});

  @override
  State<ServerControlCenterScreen> createState() =>
      _ServerControlCenterScreenState();
}

class _ServerControlCenterScreenState extends State<ServerControlCenterScreen> {
  bool _syncing = false;
  DateTime? _lastSyncAt;
  int? _lastMergedCount;
  String? _lastError;

  Future<void> _syncLibrary() async {
    final controller = AppController.instance;
    if (!controller.backendApi.isAuthenticated) {
      setState(() {
        _lastError = 'Sign in to the home-server account before syncing.';
      });
      return;
    }

    setState(() {
      _syncing = true;
      _lastError = null;
    });
    try {
      final merged = await controller.syncHomeServerLibrary();
      if (!mounted) return;
      setState(() {
        _lastSyncAt = DateTime.now();
        _lastMergedCount = merged;
        _syncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Library sync finished · $merged entries merged'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _lastError = 'The server scan did not complete: $error';
      });
    }
  }

  void _open(BuildContext context, Widget page, String route) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      settings: RouteSettings(name: route),
      builder: (_) => page,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppController.instance,
      builder: (context, _) {
        final controller = AppController.instance;
        final profile = controller.currentProfile;
        final visible = controller.library
            .where((item) => item.isAccessibleTo(profile))
            .toList(growable: false);
        final movies = visible.where((item) {
          final type = item.type.toLowerCase();
          return type.contains('movie') || type.contains('film');
        }).length;
        final shows = visible.where((item) => item.isSeries).length;
        final albums = visible.where((item) {
          final type = item.type.toLowerCase().replaceAll('_', ' ').trim();
          return type == 'album' ||
              type == 'music album' ||
              type == 'soundtrack album';
        }).length;
        final playable = visible
            .where((item) => item.playbackUrl?.trim().isNotEmpty == true)
            .length;
        final missingArtwork = visible
            .where((item) => item.imageUrl?.trim().isNotEmpty != true)
            .length;
        final missingDescriptions = visible
            .where((item) => item.description?.trim().isNotEmpty != true)
            .length;
        final authenticated = controller.backendApi.isAuthenticated;

        return Scaffold(
          backgroundColor: const Color(0xFF090B10),
          appBar: AppBar(
            backgroundColor: const Color(0xFF090B10),
            title: const Text('Server Control Center'),
          ),
          body: RefreshIndicator(
            onRefresh: _syncLibrary,
            color: Colors.white,
            backgroundColor: const Color(0xFF20232C),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 34),
              children: [
                _serverHero(authenticated: authenticated),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _syncing || !authenticated ? null : _syncLibrary,
                        icon: _syncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(_syncing ? 'Syncing…' : 'Sync library'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _open(
                        context,
                        const AllOwnedMediaScreen(),
                        '/app/page/all-owned-media',
                      ),
                      icon: const Icon(Icons.video_library_outlined),
                      label: const Text('Library'),
                    ),
                  ],
                ),
                if (_lastError != null) ...[
                  const SizedBox(height: 10),
                  _messageCard(
                    icon: Icons.warning_amber_rounded,
                    title: 'Sync needs attention',
                    message: _lastError!,
                    accent: const Color(0xFFFFC27A),
                  ),
                ],
                const SizedBox(height: 20),
                _sectionTitle(
                    'Library overview', 'What this profile can currently see'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.75,
                  children: [
                    _metric('Visible titles', '${visible.length}',
                        Icons.video_library_rounded),
                    _metric('Movies', '$movies', Icons.movie_rounded),
                    _metric('TV shows', '$shows', Icons.tv_rounded),
                    _metric('Albums', '$albums', Icons.album_rounded),
                    _metric('Playable URLs', '$playable',
                        Icons.play_circle_outline_rounded),
                    _metric('Missing artwork', '$missingArtwork',
                        Icons.image_not_supported_outlined),
                    _metric('Missing descriptions', '$missingDescriptions',
                        Icons.description_outlined),
                    _metric(
                        'Profiles',
                        '${controller.currentAccount?.profiles.length ?? 0}',
                        Icons.people_alt_outlined),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle('Quick management',
                    'Common library tasks without digging through settings'),
                const SizedBox(height: 10),
                _actionCard(
                  icon: Icons.tune_rounded,
                  title: 'Library organization',
                  subtitle: 'Genre sections, artwork, display names and tags',
                  onTap: () => _open(
                    context,
                    const LibraryOrganizationStudioScreen(),
                    '/app/page/library-organization',
                  ),
                ),
                _actionCard(
                  icon: Icons.sort_rounded,
                  title: 'All owned media',
                  subtitle:
                      'Browse and organize owned movies, shows and albums',
                  onTap: () => _open(
                    context,
                    const AllOwnedMediaScreen(),
                    '/app/page/all-owned-media',
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle(
                    'Sync activity', 'Recent client-side sync information'),
                const SizedBox(height: 10),
                _messageCard(
                  icon: Icons.history_rounded,
                  title: _lastSyncAt == null
                      ? 'No sync recorded in this session'
                      : 'Last sync · ${_formatTime(_lastSyncAt!)}',
                  message: _lastMergedCount == null
                      ? 'Use Sync library to scan the authenticated home server and merge discovered media into this profile’s accessible catalog.'
                      : 'The most recent scan merged $_lastMergedCount entries. This is a catalog result, not a live host-performance measurement.',
                  accent: const Color(0xFF8CCBFF),
                ),
                const SizedBox(height: 20),
                _messageCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Server telemetry boundary',
                  message:
                      'This screen reports account authentication and local catalog readiness. CPU, memory, disk health, network throughput, active streams, and transcoder load require a host-side telemetry collector and a diagnostics API; they are not invented or inferred here.',
                  accent: const Color(0xFFB4A6FF),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _serverHero({required bool authenticated}) {
    final color =
        authenticated ? const Color(0xFF8FDEB1) : const Color(0xFFFFC27A);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1D2937), Color(0xFF111820)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_rounded, size: 30),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: color.withValues(alpha: .40)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: color),
                    const SizedBox(width: 7),
                    Text(
                      authenticated
                          ? 'ACCOUNT AUTHENTICATED'
                          : 'SIGN-IN REQUIRED',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        letterSpacing: .7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Your home entertainment server',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            authenticated
                ? 'Your account is signed in. Run a library sync to verify that the server scan is responding.'
                : 'Sign in to connect the account library and scan your home server.',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      );

  Widget _metric(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF171C25),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.white70),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Card(
        color: const Color(0xFF171C25),
        child: ListTile(
          leading: Icon(icon),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
    required Color accent,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF151A22),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: accent.withValues(alpha: .23)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(message,
                      style: const TextStyle(
                          color: Colors.white60, height: 1.4, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} · $hour:$minute $suffix';
  }
}
