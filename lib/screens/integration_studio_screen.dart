import 'package:material_ui/material_ui.dart';

import '../app_core.dart';
import '../core/services/cinematic_title_metadata_service.dart';
import '../music_catalog_screen.dart';
import 'smart_media_import_center_screen.dart';
import '../smart_search.dart';

/// A consolidated status surface for the integrations already supported by
/// MyOwnStreamingService. It does not download or execute arbitrary plugins.
class IntegrationStudioScreen extends StatefulWidget {
  const IntegrationStudioScreen({super.key});

  @override
  State<IntegrationStudioScreen> createState() =>
      _IntegrationStudioScreenState();
}

class _IntegrationStudioScreenState extends State<IntegrationStudioScreen> {
  bool _loading = false;
  String? _musicCatalogError;
  Map<String, dynamic> _musicProviders = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!AppController.instance.isBackendAuthenticated) {
      if (mounted) {
        setState(() {
          _musicProviders = const <String, dynamic>{};
          _musicCatalogError = null;
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _musicCatalogError = null;
    });
    try {
      final payload =
          await AppController.instance.backendApi.getMusicCatalogStatus();
      final providers = payload['providers'] is Map
          ? Map<String, dynamic>.from(payload['providers'] as Map)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() => _musicProviders = providers);
    } catch (error) {
      if (mounted) {
        setState(() => _musicCatalogError =
            error.toString().replaceFirst('BackendApiException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Widget screen) => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => screen),
      );

  Widget _status({
    required IconData icon,
    required String title,
    required String detail,
    required String state,
    Color? color,
  }) =>
      Card(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(detail),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(state,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: color ?? Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          isThreeLine: true,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppController.instance;
    final backendConnected = app.isBackendAuthenticated;
    final providerNames = _musicProviders.keys.toList()..sort();
    final musicDetail = !backendConnected
        ? 'Sign in to your backend to query configured music providers.'
        : _musicCatalogError != null
            ? _musicCatalogError!
            : _loading
                ? 'Checking configured provider status…'
                : providerNames.isEmpty
                    ? 'The status endpoint did not report provider names.'
                    : 'Reported providers: ${providerNames.join(', ')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin & Integration Studio'),
        actions: [
          IconButton(
            tooltip: 'Refresh integration status',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Built-in integration status',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'This screen reports the provider connections that the current app can verify and opens their existing setup or discovery surfaces. It does not treat an unconfigured provider as available.',
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 12),
          _status(
            icon: Icons.dns_outlined,
            title: 'MyOwnStreamingService backend',
            detail: 'Account-authenticated services and server-backed features.',
            state: backendConnected ? 'Authenticated' : 'Not connected',
            color: backendConnected ? Colors.greenAccent : Colors.orangeAccent,
          ),
          _status(
            icon: Icons.movie_filter_outlined,
            title: 'Cinematic metadata',
            detail: 'TMDB-backed title, cast, crew and recommendation lookups.',
            state: CinematicTitleMetadataService.isConfigured
                ? 'Configured'
                : 'Not configured',
            color: CinematicTitleMetadataService.isConfigured
                ? Colors.greenAccent
                : Colors.orangeAccent,
          ),
          _status(
            icon: Icons.library_music_outlined,
            title: 'Music catalog providers',
            detail: musicDetail,
            state: !backendConnected
                ? 'Unavailable'
                : _musicCatalogError != null
                    ? 'Check failed'
                    : _loading
                        ? 'Checking'
                        : providerNames.isEmpty
                            ? 'Unverified'
                            : 'Status received',
            color: !backendConnected || _musicCatalogError != null
                ? Colors.orangeAccent
                : Colors.greenAccent,
          ),
          _status(
            icon: Icons.folder_open_outlined,
            title: 'Local media library',
            detail:
                '${app.library.length} catalog records available to the active app session.',
            state: 'Local service',
          ),
          const SizedBox(height: 16),
          const Text('Open integration surfaces',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Card(
            child: ListTile(
              leading: const Icon(Icons.library_music_rounded),
              title: const Text('Music Catalog'),
              subtitle: const Text('Search artists, albums, songs and catalog metadata.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const MusicCatalogScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.movie_creation_outlined),
              title: const Text('Smart Media Import Center'),
              subtitle: const Text('Review media intake and metadata matching.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const SmartMediaImportCenterScreen()),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.search_rounded),
              title: const Text('Smart Search & Identification'),
              subtitle: const Text('Search indexed movie, show and music metadata.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const SmartSearchScreen()),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Extension safety: provider adapters use the app’s existing authenticated APIs. Arbitrary executable plugin downloads are not enabled; a future third-party plugin system should require signed packages, explicit permissions, compatibility declarations and an uninstall/rollback path.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
