import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_core.dart';
import 'core/services/jellyfin_plugin_admin_service.dart';

/// Reference entries for server plugins and browser-only integrations.
/// The installed and server catalog tabs below perform real authenticated API
/// actions against the connected Jellyfin server.
class JellyfinPluginEntry {
  final String name;
  final String category;
  final String description;
  final String projectUrl;
  final String sourceLabel;
  final String installNotes;
  final String? manifestUrl;
  final List<String> requirements;

  const JellyfinPluginEntry({
    required this.name,
    required this.category,
    required this.description,
    required this.projectUrl,
    required this.sourceLabel,
    required this.installNotes,
    this.manifestUrl,
    this.requirements = const [],
  });
}

const String jellyfinOfficialPluginManifest =
    'https://repo.jellyfin.org/files/plugin/manifest.json';

/// URLs and notes checked against the projects' public installation docs on
/// 26 October 2026. Re-check target ABI/version before installing a plugin.
const List<JellyfinPluginEntry> jellyfinPluginCatalog = [
  JellyfinPluginEntry(
    name: 'Intro Skipper',
    category: 'Playback',
    description: 'Detects episode intros so supported clients can skip them.',
    projectUrl: 'https://github.com/intro-skipper/intro-skipper',
    manifestUrl: 'https://intro-skipper.org/manifest.json',
    sourceLabel: 'Community repository',
    installNotes: 'The repository provides a Jellyfin-version-aware manifest. If it does not appear in the catalog, refresh the catalog and verify your server version.',
  ),
  JellyfinPluginEntry(
    name: 'Jellyfin Enhanced',
    category: 'UI & Themes',
    description: 'Web UI enhancements including keyboard shortcuts, subtitle styling, reviews and quality-of-life tools.',
    projectUrl: 'https://github.com/n00bcodr/Jellyfin-Enhanced',
    manifestUrl: 'https://raw.githubusercontent.com/n00bcodr/jellyfin-plugins/main/manifest.json',
    sourceLabel: 'Community repository',
    installNotes: 'Install the build that matches your Jellyfin server. UI behavior is limited to compatible web-based clients.',
  ),
  JellyfinPluginEntry(
    name: 'Playback Reporting',
    category: 'Playback',
    description: 'Playback statistics, history reports and usage analytics for server users.',
    projectUrl: 'https://github.com/jellyfin/jellyfin-plugin-playbackreporting',
    manifestUrl: jellyfinOfficialPluginManifest,
    sourceLabel: 'Official Jellyfin catalog',
    installNotes: 'Available through the official Jellyfin plugin catalog. The data is collected by the server plugin.',
  ),
  JellyfinPluginEntry(
    name: 'Community SSO for Jellyfin (Flowfin)',
    category: 'Accounts & Server',
    description: 'Single sign-on through supported OpenID Connect or SAML identity providers.',
    projectUrl: 'https://github.com/Flowfin/jellyfin-plugin-sso',
    manifestUrl: 'https://raw.githubusercontent.com/Flowfin/jellyfin-plugin-sso/manifest-release/manifest.json',
    sourceLabel: 'Community replacement',
    installNotes: 'The original 9p4 repository was archived in May 2026. This entry points to the Flowfin maintained replacement; carefully review its security and compatibility documentation before changing login behavior.',
  ),
  JellyfinPluginEntry(
    name: 'StreamLimit',
    category: 'Accounts & Server',
    description: 'Limits concurrent streams per user or server policy.',
    projectUrl: 'https://github.com/JellyboxAD/Jellyfin.Plugin.StreamLimit',
    manifestUrl: 'https://raw.githubusercontent.com/JellyboxAD/Jellyfin.Plugin.StreamLimit/main/manifest.json',
    sourceLabel: 'Community repository',
    installNotes: 'The project documents version-specific builds. Its HTTP hard-block feature is marked beta, so review plugin settings before enabling it.',
  ),
  JellyfinPluginEntry(
    name: 'DiscordNotifier',
    category: 'Accounts & Server',
    description: 'Sends selected server and library activity notifications to Discord.',
    projectUrl: 'https://github.com/cedev-1/Jellyfin-Plugin-DiscordNotifier',
    manifestUrl: 'https://raw.githubusercontent.com/cedev-1/Jellyfin-Plugin-DiscordNotifier/main/manifest.json',
    sourceLabel: 'Community repository',
    installNotes: 'Configure a Discord webhook inside the plugin settings. Keep webhook URLs private.',
  ),
  JellyfinPluginEntry(
    name: 'File Transformation',
    category: 'UI & Themes',
    description: 'Provides a supported mechanism for compatible plugins to inject or transform Jellyfin Web resources.',
    projectUrl: 'https://github.com/IAmParadox27/jellyfin-plugin-file-transformation',
    manifestUrl: 'https://www.iamparadox.dev/jellyfin/plugins/manifest.json',
    sourceLabel: 'IAmParadox27 plugin repository',
    installNotes: 'Shared dependency for several UI plugins. Install a version compatible with your Jellyfin server before adding dependent plugins.',
  ),
  JellyfinPluginEntry(
    name: 'Plugin Pages',
    category: 'UI & Themes',
    description: 'Lets compatible plugins add themed pages to Jellyfin Web.',
    projectUrl: 'https://github.com/IAmParadox27/jellyfin-plugin-pages',
    manifestUrl: 'https://www.iamparadox.dev/jellyfin/plugins/manifest.json',
    sourceLabel: 'IAmParadox27 plugin repository',
    installNotes: "Requires a compatible File Transformation installation. Check the project's current Jellyfin version requirements.",
    requirements: ['File Transformation'],
  ),
  JellyfinPluginEntry(
    name: 'Home Screen Sections',
    category: 'UI & Themes',
    description: 'Adds configurable library and discovery sections to the Jellyfin home screen.',
    projectUrl: 'https://github.com/IAmParadox27/jellyfin-plugin-home-sections',
    manifestUrl: 'https://www.iamparadox.dev/jellyfin/plugins/manifest.json',
    sourceLabel: 'IAmParadox27 plugin repository',
    installNotes: 'Current versions may require compatible File Transformation and Plugin Pages versions. Check the repository release notes before upgrading Jellyfin.',
    requirements: ['File Transformation', 'Plugin Pages'],
  ),
  JellyfinPluginEntry(
    name: 'Media Bar',
    category: 'UI & Themes',
    description: 'Adds a featured-content bar to Jellyfin Web.',
    projectUrl: 'https://github.com/IAmParadox27/jellyfin-plugin-media-bar',
    manifestUrl: 'https://www.iamparadox.dev/jellyfin/plugins/manifest.json',
    sourceLabel: 'IAmParadox27 plugin repository',
    installNotes: 'Requires a compatible File Transformation version. UI support depends on the Jellyfin web client.',
    requirements: ['File Transformation'],
  ),
  JellyfinPluginEntry(
    name: 'Custom Tabs',
    category: 'UI & Themes',
    description: 'Adds administrator-configured custom tabs to the Jellyfin Web navigation bar.',
    projectUrl: 'https://github.com/IAmParadox27/jellyfin-plugin-custom-tabs',
    manifestUrl: 'https://www.iamparadox.dev/jellyfin/plugins/manifest.json',
    sourceLabel: 'IAmParadox27 plugin repository',
    installNotes: 'Requires a compatible File Transformation version. Tabs are part of the web UI and may not appear in native clients.',
    requirements: ['File Transformation'],
  ),
  JellyfinPluginEntry(
    name: 'Collection Sections / Selector',
    category: 'UI & Themes',
    description: 'Adds home-screen sections for collections or playlists.',
    projectUrl: 'https://github.com/IAmParadox27/jellyfin-plugin-collection-sections',
    manifestUrl: 'https://www.iamparadox.dev/jellyfin/plugins/manifest.json',
    sourceLabel: 'IAmParadox27 plugin repository',
    installNotes: 'The maintainer has discussed folding this functionality into Home Screen Sections. Check the latest catalog and release notes to avoid installing overlapping features.',
    requirements: ['Check Home Screen Sections release notes'],
  ),
  JellyfinPluginEntry(
    name: 'KefinTweaks',
    category: 'UI & Themes',
    description: 'A modular collection of Jellyfin Web improvements, themes and navigation tweaks.',
    projectUrl: 'https://github.com/ranaldsgift/KefinTweaks',
    sourceLabel: 'Community UI script / guide',
    installNotes: 'Not installed through a single plugin manifest. Follow the README: it uses JavaScript Injector and recommends File Transformation. Review the script source before injecting code into your web client.',
    requirements: ['JavaScript Injector', 'File Transformation recommended'],
  ),
  JellyfinPluginEntry(
    name: 'Jellyfin Featured',
    category: 'UI & Themes',
    description: 'Configurable featured-content carousel with backgrounds and optional trailers.',
    projectUrl: 'https://github.com/spkesDE/jellyfin-featured-plugin',
    manifestUrl: 'https://raw.githubusercontent.com/spkesDE/jellyfin-featured-plugin/main/manifest.json',
    sourceLabel: 'Community repository',
    installNotes: 'Requires File Transformation or JavaScript Injector for the front-end helper. It only affects web clients and clients based on Jellyfin Web.',
    requirements: ['File Transformation or JavaScript Injector'],
  ),
  JellyfinPluginEntry(
    name: 'Jellyscrub',
    category: 'Playback',
    description: 'Generates or converts trickplay preview data for seek/scrubbing previews.',
    projectUrl: 'https://github.com/nicknsy/jellyscrub',
    manifestUrl: 'https://raw.githubusercontent.com/nicknsy/jellyscrub/main/manifest.json',
    sourceLabel: 'Community repository',
    installNotes: 'Jellyfin 10.9+ has native trickplay support; Jellyscrub 2.x focuses on converting older BIF files. Confirm you need that migration before installing.',
  ),
  JellyfinPluginEntry(
    name: 'Anime Multi Source',
    category: 'Metadata & Artwork',
    description: 'Combines anime metadata sources including AniList, AniDB, MAL/Jikan and others.',
    projectUrl: 'https://github.com/webbster64/jellyfin-plugin-AnimeMultiSource',
    manifestUrl: 'https://raw.githubusercontent.com/webbster64/jellyfin-plugin-AnimeMultiSource/main/manifest.json',
    sourceLabel: 'Community repository',
    installNotes: 'Some sources require provider credentials or identifiers. Configure those in the plugin page after installation and review provider rate limits.',
  ),
  JellyfinPluginEntry(
    name: 'TMDb Box Sets',
    category: 'Metadata & Artwork',
    description: 'Groups titles into box sets and collections using TMDb collection IDs.',
    projectUrl: 'https://github.com/jellyfin/jellyfin-plugin-tmdbboxsets',
    manifestUrl: jellyfinOfficialPluginManifest,
    sourceLabel: 'Official Jellyfin catalog',
    installNotes: 'Available through the official plugin catalog. Back up collection metadata before changing automatic collection rules.',
  ),
  JellyfinPluginEntry(
    name: 'Fanart.tv Provider',
    category: 'Metadata & Artwork',
    description: 'Adds additional movie and TV artwork sourced from Fanart.tv.',
    projectUrl: 'https://github.com/jellyfin/jellyfin-plugin-fanart',
    manifestUrl: jellyfinOfficialPluginManifest,
    sourceLabel: 'Official Jellyfin catalog',
    installNotes: 'A Fanart.tv API key may improve access. The plugin sources artwork on the server; it does not provide font metadata for title logos.',
  ),
  JellyfinPluginEntry(
    name: 'Jellyfin Icon Metadata',
    category: 'Metadata & Artwork',
    description: 'Displays icons for supported metadata-provider links across movies, shows, anime and music.',
    projectUrl: 'https://github.com/Druidblack/jellyfin-icon-metadata',
    sourceLabel: 'Community repository / guide',
    installNotes: 'A confirmed plugin manifest URL was not found in the project documentation we checked. Open the repository and use its current installation instructions; do not add a guessed manifest URL.',
  ),
];

class JellyfinPluginsHubScreen extends StatefulWidget {
  final String? serverUrl;
  final String? accessToken;
  final String? username;

  const JellyfinPluginsHubScreen({
    super.key,
    this.serverUrl,
    this.accessToken,
    this.username,
  });

  @override
  State<JellyfinPluginsHubScreen> createState() =>
      _JellyfinPluginsHubScreenState();
}

class _JellyfinPluginsHubScreenState extends State<JellyfinPluginsHubScreen> {
  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  final http.Client _httpClient = http.Client();
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _token;
  String? _username;
  bool _initializing = true;
  bool _busy = false;
  bool _connected = false;
  String? _error;
  String? _catalogError;
  String? _repositoryError;
  String _section = 'Installed';
  String _search = '';
  List<Map<String, dynamic>> _installed = [];
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _repositories = [];
  bool _repositoriesLoaded = false;
  final Set<String> _workingPluginIds = <String>{};
  final Set<String> _workingPackageNames = <String>{};

  String get _profileToken {
    final profileId = AppController.instance.currentProfile?.id.trim();
    return profileId != null && profileId.isNotEmpty ? profileId : 'guest';
  }

  String get _tokenKey => 'moss_jellyfin_token_$_profileToken';
  String get _userKey => 'moss_jellyfin_user_$_profileToken';
  String get _urlKey => 'moss_jellyfin_url_$_profileToken';
  String get _pluginAdminTokenKey => 'moss_jellyfin_plugin_admin_token_$_profileToken';
  String get _pluginAdminUserKey => 'moss_jellyfin_plugin_admin_user_$_profileToken';
  String get _pluginAdminUrlKey => 'moss_jellyfin_plugin_admin_url_$_profileToken';

  String _canonicalUrl(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url.toLowerCase();
  }

  String get _baseUrl {
    var value = _serverController.text.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  JellyfinPluginAdminService? get _api {
    final token = _token;
    if (token == null || token.isEmpty || _baseUrl.isEmpty) return null;
    return JellyfinPluginAdminService(
      baseUrl: _baseUrl,
      accessToken: token,
      client: _httpClient,
    );
  }

  @override
  void initState() {
    super.initState();
    _restoreConnection();
  }

  Future<void> _restoreConnection() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedUrl = preferences.getString(_urlKey) ?? '';
      final pluginAdminUrl = preferences.getString(_pluginAdminUrlKey) ?? '';
      final passedUrl = widget.serverUrl?.trim() ?? '';
      final sameAsSavedAdminServer = pluginAdminUrl.isNotEmpty &&
          (passedUrl.isEmpty ||
              _canonicalUrl(passedUrl) == _canonicalUrl(pluginAdminUrl));
      final savedAdminToken = sameAsSavedAdminServer
          ? await _secure.read(key: _pluginAdminTokenKey)
          : null;
      final normalToken = widget.accessToken ?? await _secure.read(key: _tokenKey);
      final savedAdminUser = savedAdminToken == null
          ? null
          : await _secure.read(key: _pluginAdminUserKey);
      final username = savedAdminToken != null
          ? savedAdminUser
          : (widget.username ?? await _secure.read(key: _userKey));
      final token = savedAdminToken ?? normalToken;
      if (!mounted) return;
      _serverController.text = passedUrl.isNotEmpty
          ? passedUrl
          : (pluginAdminUrl.isNotEmpty ? pluginAdminUrl : savedUrl);
      _token = token;
      _username = username;
      _usernameController.text = username ?? '';
      if (_token != null && _baseUrl.isNotEmpty) {
        await _refreshAll(showSpinner: true);
      } else {
        setState(() {
          _initializing = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Could not restore the saved Jellyfin connection: $error';
      });
    }
  }

  Map<String, String> _unauthenticatedHeaders() => <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization':
            'MediaBrowser Client="MyOwnStreamingService", Device="MyOwnStreamingService", DeviceId="moss-plugin-manager", Version="1.0.0"',
      };

  Future<void> _connectAsAdministrator() async {
    final serverUri = Uri.tryParse(_baseUrl);
    if (serverUri == null ||
        !serverUri.hasAuthority ||
        !{'http', 'https'}.contains(serverUri.scheme)) {
      setState(() => _error =
          'Enter a valid Jellyfin server URL, such as http://192.168.1.20:8096.');
      return;
    }
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Enter the Jellyfin administrator username and password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl/Users/AuthenticateByName'),
            headers: _unauthenticatedHeaders(),
            body: jsonEncode(<String, String>{
              'Username': _usernameController.text.trim(),
              'Pw': _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const JellyfinPluginAdminException(
          'Jellyfin rejected those credentials. Use a server administrator account.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw JellyfinPluginAdminException(
          'Jellyfin sign-in returned HTTP ${response.statusCode}.',
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = body['AccessToken']?.toString();
      final user = body['User'] is Map
          ? Map<String, dynamic>.from(body['User'] as Map)
          : <String, dynamic>{};
      if (accessToken == null || accessToken.isEmpty) {
        throw const JellyfinPluginAdminException(
          'Jellyfin did not return a valid session token.',
        );
      }
      _token = accessToken;
      _username = user['Name']?.toString() ?? _usernameController.text.trim();
      // Keep the elevated plugin-management token separate from the regular
      // library session token so the app does not overwrite the normal user.
      await _secure.write(key: _pluginAdminTokenKey, value: accessToken);
      await _secure.write(key: _pluginAdminUserKey, value: _username);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_pluginAdminUrlKey, _baseUrl);
      _passwordController.clear();
      await _refreshAll(showSpinner: true);
      // The server only confirms admin/elevated access when GET /Plugins
      // succeeds. Do not retain a regular-user token as an admin session.
      if (mounted && !_connected) {
        await _secure.delete(key: _pluginAdminTokenKey);
        await _secure.delete(key: _pluginAdminUserKey);
        await preferences.remove(_pluginAdminUrlKey);
        _token = null;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _initializing = false;
        _connected = false;
        _error = _errorText(error);
      });
    }
  }

  String _errorText(Object error) {
    if (error is JellyfinPluginAdminException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _refreshAll({bool showSpinner = false}) async {
    final api = _api;
    if (api == null) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _busy = false;
          _connected = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _busy = showSpinner;
        _error = null;
        _catalogError = null;
        _repositoryError = null;
        _repositoriesLoaded = false;
      });
    }
    try {
      final plugins = await api.getInstalledPlugins();
      if (!mounted) return;
      setState(() {
        _installed = plugins;
        _connected = true;
        _initializing = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _error = _errorText(error);
        _initializing = false;
        _busy = false;
      });
      return;
    }

    try {
      final packages = await api.getPackages();
      if (mounted) setState(() => _packages = packages);
    } catch (error) {
      if (mounted) setState(() => _catalogError = _errorText(error));
    }
    try {
      final repositories = await api.getRepositories();
      if (mounted) {
        setState(() {
          _repositories = repositories;
          _repositoriesLoaded = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _repositoriesLoaded = false;
          _repositoryError = _errorText(error);
        });
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _initializing = false;
      _connected = true;
    });
  }

  Future<void> _togglePlugin(
    Map<String, dynamic> plugin,
    bool enable,
  ) async {
    final api = _api;
    final id = _value(plugin, const ['Id', 'id']);
    final version = _value(plugin, const ['Version', 'version']);
    final name = _value(plugin, const ['Name', 'name'], fallback: 'plugin');
    if (api == null || id.isEmpty || version.isEmpty) {
      _showMessage('Jellyfin did not provide this plugin ID and version.');
      return;
    }
    setState(() => _workingPluginIds.add(id));
    try {
      if (enable) {
        await api.enablePlugin(pluginId: id, version: version);
      } else {
        await api.disablePlugin(pluginId: id, version: version);
      }
      await _refreshAll();
      if (!mounted) return;
      final action = enable ? 'Enable' : 'Disable';
      _showMessage(
        '$action requested for $name. If Jellyfin reports “Restart required”, restart the server to finish applying the change.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(_errorText(error));
    } finally {
      if (mounted) setState(() => _workingPluginIds.remove(id));
    }
  }

  Future<void> _uninstallPlugin(Map<String, dynamic> plugin) async {
    final name = _value(plugin, const ['Name', 'name'], fallback: 'this plugin');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Uninstall server plugin?'),
        content: Text(
          'Uninstall $name from the connected Jellyfin server? This does not mean that plugin data or external configuration will necessarily be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = _api;
    final id = _value(plugin, const ['Id', 'id']);
    final version = _value(plugin, const ['Version', 'version']);
    if (api == null || id.isEmpty || version.isEmpty) return;
    setState(() => _workingPluginIds.add(id));
    try {
      await api.uninstallPlugin(pluginId: id, version: version);
      await _refreshAll();
      if (mounted) _showMessage('$name uninstall requested. Restart Jellyfin if requested by the server.');
    } catch (error) {
      if (mounted) _showMessage(_errorText(error));
    } finally {
      if (mounted) setState(() => _workingPluginIds.remove(id));
    }
  }

  Future<void> _installPackage(Map<String, dynamic> package) async {
    final name = _value(package, const ['Name', 'name', 'PackageName']);
    if (name.isEmpty) {
      _showMessage('This catalog entry has no package name and cannot be installed by the API.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Install plugin on your server?'),
        content: Text(
          'Install $name from the connected Jellyfin server catalog? Plugins run with server privileges. Check the publisher and compatibility first. Jellyfin may need a restart after installation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Install'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = _api;
    if (api == null) return;
    setState(() => _workingPackageNames.add(name.toLowerCase()));
    try {
      final guid = _value(package, const ['Guid', 'guid', 'AssemblyGuid', 'assemblyGuid']);
      final repositoryUrl = _packageRepositoryUrl(package);
      await api.installPackage(
        name: name,
        assemblyGuid: guid.isEmpty ? null : guid,
        repositoryUrl: repositoryUrl.startsWith('http') ? repositoryUrl : null,
      );
      await _refreshAll();
      if (!mounted) return;
      _showMessage('Jellyfin accepted the installation request for $name. Refresh the catalog in a moment; a server restart may be required.');
    } catch (error) {
      if (mounted) _showMessage(_errorText(error));
    } finally {
      if (mounted) setState(() => _workingPackageNames.remove(name.toLowerCase()));
    }
  }

  Future<void> _addRepository() async {
    if (!_repositoriesLoaded) {
      _showMessage('Refresh the server and successfully load its complete repository list before adding repositories.');
      return;
    }
    final nameController = TextEditingController(text: 'Community repository');
    final urlController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add plugin repository'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Repository name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Manifest URL (HTTPS)',
                  hintText: 'https://example.org/jellyfin/manifest.json',
                ),
              ),
              const SizedBox(height: 8),
              const Text('Only add repositories you trust. A plugin may execute code with access to your server.', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final url = urlController.text.trim();
              final uri = Uri.tryParse(url);
              if (name.isEmpty || uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter a name and a valid HTTPS manifest URL.')),
                );
                return;
              }
              Navigator.pop(dialogContext, {'name': name, 'url': url});
            },
            child: const Text('Add repository'),
          ),
        ],
      ),
    );
    nameController.dispose();
    urlController.dispose();
    if (result == null) return;
    final url = result['url']!;
    if (_repositories.any((repository) =>
        _value(repository, const ['Url', 'URL', 'url']).toLowerCase() == url.toLowerCase())) {
      _showMessage('That repository URL is already configured.');
      return;
    }
    final next = <Map<String, dynamic>>[
      ..._repositories,
      <String, dynamic>{'Name': result['name'], 'Url': url, 'Enabled': true},
    ];
    await _saveRepositories(next, success: 'Repository added. Refresh the server catalog to see its packages.');
  }

  Future<void> _toggleRepository(
    Map<String, dynamic> repository,
    bool enabled,
  ) async {
    final url = _value(repository, const ['Url', 'URL', 'url']);
    final next = _repositories.map((item) {
      final currentUrl = _value(item, const ['Url', 'URL', 'url']);
      if (currentUrl == url) {
        return <String, dynamic>{
          ...item,
          'Name': _value(item, const ['Name', 'name'], fallback: 'Repository'),
          'Url': url,
          'Enabled': enabled,
        };
      }
      return Map<String, dynamic>.from(item);
    }).toList();
    final action = enabled ? 'Enabled' : 'Disabled';
    await _saveRepositories(next, success: '$action repository.');
  }

  Future<void> _removeRepository(Map<String, dynamic> repository) async {
    final name = _value(repository, const ['Name', 'name'], fallback: 'this repository');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove repository?'),
        content: Text('Remove $name from this Jellyfin server? Already installed plugins are not automatically uninstalled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    final url = _value(repository, const ['Url', 'URL', 'url']);
    final next = _repositories.where((item) =>
        _value(item, const ['Url', 'URL', 'url']) != url).map((e) => Map<String, dynamic>.from(e)).toList();
    await _saveRepositories(next, success: 'Repository removed.');
  }

  Future<void> _saveRepositories(
    List<Map<String, dynamic>> repositories, {
    required String success,
  }) async {
    if (!_repositoriesLoaded) {
      _showMessage('Repository list is not loaded; refusing to replace server repositories. Refresh first.');
      return;
    }
    final api = _api;
    if (api == null) return;
    setState(() => _busy = true);
    try {
      await api.setRepositories(repositories);
      if (!mounted) return;
      setState(() => _repositories = repositories);
      await _refreshAll();
      if (mounted) _showMessage(success);
    } catch (error) {
      if (mounted) _showMessage(_errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      _showMessage('This project URL is invalid.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _showMessage('Could not open the project URL.');
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _showMessage('$label copied to clipboard.');
  }

  String _value(
    Map<String, dynamic> record,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = record[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  String _status(Map<String, dynamic> plugin) =>
      _value(plugin, const ['Status', 'status'], fallback: 'Unknown');

  bool _pluginIsEnabled(Map<String, dynamic> plugin) =>
      _status(plugin).toLowerCase() == 'active';

  bool _canToggle(Map<String, dynamic> plugin) =>
      {'active', 'disabled'}.contains(_status(plugin).toLowerCase());

  bool _packageIsInstalled(Map<String, dynamic> package) {
    final packageGuid = _value(package, const ['Guid', 'guid', 'AssemblyGuid', 'assemblyGuid']).toLowerCase();
    final packageName = _value(package, const ['Name', 'name', 'PackageName']).toLowerCase();
    return _installed.any((plugin) {
      final pluginId = _value(plugin, const ['Id', 'id']).toLowerCase();
      final pluginName = _value(plugin, const ['Name', 'name']).toLowerCase();
      return (packageGuid.isNotEmpty && packageGuid == pluginId) ||
          (packageName.isNotEmpty && packageName == pluginName);
    });
  }

  List<Map<String, dynamic>> get _filteredInstalled => _installed.where((plugin) {
        final name = _value(plugin, const ['Name', 'name']);
        final description = _value(plugin, const ['Description', 'description']);
        final status = _value(plugin, const ['Status', 'status']);
        final text = '$name $description $status';
        return text.toLowerCase().contains(_search.trim().toLowerCase());
      }).toList();

  List<Map<String, dynamic>> get _filteredPackages => _packages.where((package) {
        final name = _value(package, const ['Name', 'name']);
        final description = _value(package, const ['Description', 'description']);
        final overview = _value(package, const ['Overview', 'overview']);
        final owner = _value(package, const ['Owner', 'owner']);
        final category = _value(package, const ['Category', 'category']);
        final text = '$name $description $overview $owner $category';
        return text.toLowerCase().contains(_search.trim().toLowerCase());
      }).toList();

  List<JellyfinPluginEntry> get _filteredGuides => jellyfinPluginCatalog.where((plugin) {
        final query = _search.trim().toLowerCase();
        return query.isEmpty ||
            '${plugin.name} ${plugin.description} ${plugin.category} ${plugin.installNotes}'
                .toLowerCase()
                .contains(query);
      }).toList();

  Future<void> _signOutFromManager() async {
    setState(() {
      _connected = false;
      _error = null;
      _token = null;
      _passwordController.clear();
    });
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayUsername = _username ?? 'Jellyfin administrator';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jellyfin Plugin Manager'),
        actions: [
          if (_connected)
            IconButton(
              tooltip: 'Refresh server plugins and catalog',
              onPressed: _busy ? null : () => _refreshAll(showSpinner: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          IconButton(
            tooltip: 'Jellyfin plugin documentation',
            onPressed: () => _openUrl('https://jellyfin.org/docs/general/server/plugins/'),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _refreshAll(showSpinner: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  if (_connected) ...[
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.dns_rounded)),
                        title: const Text('Connected with plugin-management access'),
                        subtitle: Text('$displayUsername • $_baseUrl'),
                        trailing: IconButton(
                          tooltip: 'Switch administrator account',
                          onPressed: _signOutFromManager,
                          icon: const Icon(Icons.manage_accounts_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _sectionChip('Installed', Icons.extension_rounded),
                        _sectionChip('Server Catalog', Icons.storefront_rounded),
                        _sectionChip('Repositories', Icons.hub_outlined),
                        _sectionChip('Guides', Icons.menu_book_outlined),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _search = value),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: _section == 'Installed'
                            ? 'Search installed plugins'
                            : _section == 'Server Catalog'
                                ? 'Search the server catalog'
                                : _section == 'Repositories'
                                    ? 'Search repositories'
                                    : 'Search setup guides',
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_busy) const LinearProgressIndicator(),
                    if (_section == 'Installed') ..._buildInstalledSection(colorScheme),
                    if (_section == 'Server Catalog') ..._buildCatalogSection(),
                    if (_section == 'Repositories') ..._buildRepositoriesSection(),
                    if (_section == 'Guides') ..._buildGuidesSection(),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [colorScheme.primaryContainer, colorScheme.surfaceContainerHighest],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.admin_panel_settings_rounded, size: 30),
                          SizedBox(height: 8),
                          Text('Connect as a Jellyfin administrator', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                          SizedBox(height: 6),
                          Text('This manager calls Jellyfin’s real plugin APIs. It can list installed plugins, enable or disable them, install packages from configured server repositories, uninstall plugins, and manage repositories. Administrator/elevated permissions are required.', style: TextStyle(height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _serverController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Jellyfin server URL',
                        hintText: 'http://192.168.1.20:8096',
                        prefixIcon: Icon(Icons.dns_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _usernameController,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Administrator username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Administrator password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      onSubmitted: (_) {
                        if (!_busy) _connectAsAdministrator();
                      },
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _connectAsAdministrator,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: Text(_busy ? 'Connecting…' : 'Connect and manage plugins'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Your password is used only to request a Jellyfin session and is not saved. The returned access token is stored in secure device storage, using the same per-profile storage as the Jellyfin Library connection.', style: TextStyle(fontSize: 12, height: 1.4)),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Card(
                        color: colorScheme.errorContainer.withValues(alpha: 0.45),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_error!, style: TextStyle(color: colorScheme.onErrorContainer)),
                        ),
                      ),
                    ),
                  if (_catalogError != null && _section == 'Server Catalog')
                    _ErrorCard(message: 'Could not load the server package catalog: $_catalogError'),
                  if (_repositoryError != null && _section == 'Repositories')
                    _ErrorCard(message: 'Could not load configured repositories: $_repositoryError'),
                  const SizedBox(height: 16),
                  const Text('Server plugins execute on the Jellyfin host. Install only packages you trust and check their target Jellyfin version. A successful API request may still require the server to restart before the plugin’s status changes.', style: TextStyle(fontSize: 12, height: 1.4)),
                ],
              ),
            ),
    );
  }

  Widget _sectionChip(String value, IconData icon) => ChoiceChip(
        selected: _section == value,
        avatar: Icon(icon, size: 17),
        label: Text(value),
        onSelected: (_) => setState(() => _section = value),
      );

  List<Widget> _buildInstalledSection(ColorScheme colorScheme) {
    final plugins = _filteredInstalled;
    if (plugins.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              const Icon(Icons.extension_rounded, size: 34),
              const SizedBox(height: 8),
              Text(_search.isEmpty ? 'No installed plugins were returned by Jellyfin.' : 'No installed plugins match this search.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ];
    }
    return plugins.map((plugin) {
      final id = _value(plugin, const ['Id', 'id']);
      final name = _value(plugin, const ['Name', 'name'], fallback: 'Unnamed plugin');
      final version = _value(plugin, const ['Version', 'version'], fallback: 'Unknown version');
      final status = _status(plugin);
      final enabled = _pluginIsEnabled(plugin);
      final canToggle = _canToggle(plugin) && !_workingPluginIds.contains(id);
      final canUninstall = (plugin['CanUninstall'] ?? plugin['canUninstall']) != false;
      return Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(child: Icon(enabled ? Icons.extension_rounded : Icons.extension_rounded, color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(version, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 5),
                    Text(_value(plugin, const ['Description', 'description'], fallback: 'Installed on this Jellyfin server.'), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text(_statusLabel(status), style: TextStyle(color: _statusColor(status, colorScheme), fontWeight: FontWeight.w700, fontSize: 12)),
                    if (status.toLowerCase() == 'restart')
                      const Padding(padding: EdgeInsets.only(top: 4), child: Text('Restart Jellyfin before making another state change.', style: TextStyle(fontSize: 12))),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (_canToggle(plugin))
                          OutlinedButton.icon(
                            onPressed: canToggle ? () => _togglePlugin(plugin, !enabled) : null,
                            icon: _workingPluginIds.contains(id)
                                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(enabled ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, size: 18),
                            label: Text(enabled ? 'Disable' : 'Enable'),
                          ),
                        if (canUninstall)
                          TextButton.icon(
                            onPressed: _workingPluginIds.contains(id) ? null : () => _uninstallPlugin(plugin),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: const Text('Uninstall'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildCatalogSection() {
    final packages = _filteredPackages;
    final items = <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline_rounded),
              SizedBox(width: 9),
              Expanded(child: Text('This is the live catalog returned by your Jellyfin server’s configured repositories, not a static list of links. Add a repository in the Repositories tab to expand it.', style: TextStyle(height: 1.35))),
            ],
          ),
        ),
      ),
    ];
    if (packages.isEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_search.isEmpty ? 'The server catalog is empty or has not returned any packages.' : 'No catalog packages match this search.', textAlign: TextAlign.center),
      ));
      return items;
    }
    for (final package in packages) {
      final name = _value(package, const ['Name', 'name', 'PackageName'], fallback: 'Unknown package');
      final installed = _packageIsInstalled(package);
      final isWorking = _workingPackageNames.contains(name.toLowerCase());
      final guid = _value(package, const ['Guid', 'guid', 'AssemblyGuid', 'assemblyGuid']);
      final version = _packageLatestVersion(package);
      final description = _value(package, const ['Overview', 'overview', 'Description', 'description'], fallback: 'Package available from the connected Jellyfin repository.');
      items.add(Card(
        margin: const EdgeInsets.only(top: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(child: Icon(Icons.extension_rounded)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    if (version.isNotEmpty) Text('Latest listed version: $version', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 6),
                    Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35)),
                    const SizedBox(height: 9),
                    if (installed)
                      const Chip(avatar: Icon(Icons.check_circle_outline_rounded, size: 17), label: Text('Installed'))
                    else
                      FilledButton.tonalIcon(
                        onPressed: isWorking ? null : () => _installPackage(package),
                        icon: isWorking ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded, size: 18),
                        label: Text(isWorking ? 'Installing…' : 'Install on server'),
                      ),
                    if (guid.isNotEmpty) const SizedBox(height: 3),
                    if (guid.isNotEmpty) Text('Package ID: $guid', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
    }
    return items;
  }


  String _packageRepositoryUrl(Map<String, dynamic> package) {
    final direct = _value(package, const ['RepositoryUrl', 'repositoryUrl', 'RepositoryURL']);
    if (direct.startsWith('https://')) return direct;
    final versions = package['Versions'] ?? package['versions'];
    if (versions is List) {
      for (final rawVersion in versions) {
        if (rawVersion is! Map) continue;
        final version = Map<String, dynamic>.from(rawVersion);
        final source = _value(version, const ['RepositoryUrl', 'repositoryUrl', 'RepositoryURL']);
        if (source.startsWith('https://')) return source;
      }
    }
    return '';
  }

  String _packageLatestVersion(Map<String, dynamic> package) {
    final versions = package['Versions'] ?? package['versions'];
    if (versions is List && versions.isNotEmpty) {
      final first = versions.first;
      if (first is Map) {
        return _value(Map<String, dynamic>.from(first), const ['Version', 'version']);
      }
      return first.toString();
    }
    return _value(package, const ['Version', 'version']);
  }

  List<Widget> _buildRepositoriesSection() {
    final query = _search.trim().toLowerCase();
    final repositories = _repositories.where((repository) {
      final name = _value(repository, const ['Name', 'name']);
      final url = _value(repository, const ['Url', 'URL', 'url']);
      return '$name $url'.toLowerCase().contains(query);
    }).toList();
    final widgets = <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: (_busy || !_repositoriesLoaded) ? null : _addRepository,
          icon: const Icon(Icons.add_link_rounded),
          label: const Text('Add repository'),
        ),
      ),
      const SizedBox(height: 8),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Repository changes are sent to your Jellyfin server and affect its plugin catalog. The full repository list is saved together, so existing repositories are preserved.', style: TextStyle(height: 1.35)),
        ),
      ),
    ];
    if (repositories.isEmpty) {
      widgets.add(Padding(padding: const EdgeInsets.all(24), child: Text(query.isEmpty ? 'No repositories were returned. Add a trusted HTTPS manifest URL.' : 'No repositories match this search.', textAlign: TextAlign.center)));
    }
    for (final repository in repositories) {
      final name = _value(repository, const ['Name', 'name'], fallback: 'Unnamed repository');
      final url = _value(repository, const ['Url', 'URL', 'url']);
      final enabledValue = repository['Enabled'] ?? repository['enabled'];
      final enabled = enabledValue is bool ? enabledValue : true;
      widgets.add(Card(
        margin: const EdgeInsets.only(top: 8),
        child: ListTile(
          leading: Icon(enabled ? Icons.hub_rounded : Icons.hub_outlined),
          title: Text(name),
          subtitle: SelectableText(url),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            tooltip: 'Repository actions',
            onSelected: (choice) {
              if (choice == 'toggle') _toggleRepository(repository, !enabled);
              if (choice == 'remove') _removeRepository(repository);
              if (choice == 'copy') _copy(url, 'Repository URL');
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'toggle', child: Text(enabled ? 'Disable repository' : 'Enable repository')),
              const PopupMenuItem(value: 'copy', child: Text('Copy URL')),
              const PopupMenuItem(value: 'remove', child: Text('Remove repository')),
            ],
          ),
        ),
      ));
    }
    return widgets;
  }

  Future<void> _addRepositoryForGuide(JellyfinPluginEntry plugin) async {
    if (!_repositoriesLoaded) {
      _showMessage('Refresh the server and successfully load its complete repository list before adding repositories.');
      return;
    }
    final manifestUrl = plugin.manifestUrl;
    if (manifestUrl == null) {
      _showMessage('This entry does not publish a verified repository manifest. Use its guide; it may be a browser-only integration.');
      return;
    }
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      _showMessage('This entry does not have a valid HTTPS manifest URL.');
      return;
    }
    if (_repositories.any((repository) =>
        _value(repository, const ['Url', 'URL', 'url']).toLowerCase() == manifestUrl.toLowerCase())) {
      setState(() {
        _section = 'Server Catalog';
        _search = '';
        _searchController.clear();
      });
      _showMessage('That repository is already configured. Use Server Catalog to find and install its packages.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add plugin repository to Jellyfin?'),
        content: Text(
          'Add ${plugin.sourceLabel} to your server repositories using this manifest? This only adds the repository; the plugin is not installed until you choose Install on server in the Server Catalog. Only add sources you trust.\n\n$manifestUrl',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add repository')),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = _api;
    if (api == null) return;
    final next = <Map<String, dynamic>>[
      ..._repositories,
      <String, dynamic>{
        'Name': plugin.sourceLabel,
        'Url': manifestUrl,
        'Enabled': true,
      },
    ];
    setState(() => _busy = true);
    try {
      await api.setRepositories(next);
      await _refreshAll();
      if (!mounted) return;
      setState(() {
        _section = 'Server Catalog';
        _search = '';
        _searchController.clear();
      });
      _showMessage('Repository added. Find ${plugin.name} or another package in Server Catalog and install it there.');
    } catch (error) {
      if (mounted) _showMessage(_errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _buildGuidesSection() {
    final guides = _filteredGuides;
    return <Widget>[
      const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('These are reference notes for special or browser-only integrations. For plugins that exist in a configured Jellyfin server repository, use Server Catalog → Install on server. Entries that are web scripts or themes may not be installable or enableable through Jellyfin’s server plugin API.', style: TextStyle(height: 1.4)),
        ),
      ),
      if (guides.isEmpty)
        const Padding(padding: EdgeInsets.all(24), child: Text('No guides match this search.', textAlign: TextAlign.center)),
      for (final plugin in guides)
        _PluginGuideCard(
          plugin: plugin,
          onCopy: plugin.manifestUrl == null ? null : () => _copy(plugin.manifestUrl!, 'Repository URL'),
          onAddToServer: plugin.manifestUrl == null ? null : () => _addRepositoryForGuide(plugin),
          onOpen: () => _openUrl(plugin.projectUrl),
        ),
    ];
  }
}

class _PluginGuideCard extends StatelessWidget {
  const _PluginGuideCard({required this.plugin, required this.onCopy, required this.onAddToServer, required this.onOpen});

  final JellyfinPluginEntry plugin;
  final VoidCallback? onCopy;
  final VoidCallback? onAddToServer;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Icon(_iconFor(plugin.category))),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plugin.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(plugin.category, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(plugin.description, style: const TextStyle(height: 1.35)),
            const SizedBox(height: 7),
            Text(plugin.sourceLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (plugin.requirements.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Requirements: ${plugin.requirements.join(" • ")}', style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 7),
            Text(plugin.installNotes, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35)),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (onAddToServer != null)
                  FilledButton.tonalIcon(
                    onPressed: onAddToServer,
                    icon: const Icon(Icons.add_link_rounded, size: 17),
                    label: const Text('Add repository to server'),
                  ),
                if (onCopy != null)
                  OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: const Text('Copy repository URL'),
                  ),
                OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: Text(plugin.manifestUrl == null ? 'Open install guide' : 'Open project'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
        child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
      );
}

String _statusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return 'Enabled';
    case 'disabled':
      return 'Disabled';
    case 'restart':
      return 'Restart required';
    case 'malfunctioned':
      return 'Malfunctioned';
    case 'notsupported':
      return 'Not supported by this Jellyfin version';
    case 'superseded':
    case 'superceded':
      return 'Superseded by another version';
    case 'deleted':
      return 'Marked for deletion';
    default:
      return status;
  }
}

Color _statusColor(String status, ColorScheme scheme) {
  switch (status.toLowerCase()) {
    case 'active':
      return Colors.green.shade700;
    case 'disabled':
      return scheme.onSurfaceVariant;
    case 'restart':
    case 'malfunctioned':
    case 'notsupported':
      return scheme.error;
    default:
      return scheme.onSurfaceVariant;
  }
}

IconData _iconFor(String category) => switch (category) {
      'Playback' => Icons.play_circle_outline_rounded,
      'UI & Themes' => Icons.palette_outlined,
      'Metadata & Artwork' => Icons.image_search_outlined,
      'Accounts & Server' => Icons.admin_panel_settings_outlined,
      _ => Icons.extension_outlined,
    };
