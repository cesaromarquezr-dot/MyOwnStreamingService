import 'dart:async';

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'profiles.dart';
import 'core/models/platform_server.dart';
import 'localization.dart';

class ServerSelectionScreen extends StatefulWidget {
  final ValueChanged<BuildContext>? onProfileReady;
  final VoidCallback? onOpened;
  final VoidCallback? onServerSaved;

  const ServerSelectionScreen({
    super.key,
    this.onProfileReady,
    this.onOpened,
    this.onServerSaved,
  });

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen> {
  List<PlatformServer> _servers = const [];
  bool _loading = true;
  bool _claiming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Explicitly hide the global navbar before the first server-selection frame.
    widget.onOpened?.call();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final context = await AppController.instance.loadServerContext();
      if (!mounted) return;
      if (context.currentServer != null) {
        _finish();
        return;
      }
      setState(() {
        _servers = context.availableServers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _select(PlatformServer server) async {
    if (_claiming) return;
    setState(() {
      _claiming = true;
      _error = null;
    });
    final controller = AppController.instance;
    final nameController = TextEditingController(text: '${server.name} Library');
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Name your server'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Custom name',
              hintText: 'Cesar\'s Library',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save & Continue')),
          ],
        ),
      );
      if (accepted != true) return;
      final displayName = nameController.text.trim();
      if (displayName.isEmpty) {
        if (mounted) {
          setState(() => _error = 'Enter a name for this server.');
        }
        return;
      }
      // Avoid an indefinitely unresponsive screen if the backend is unreachable.
      // A failure is displayed below instead of being erased by _load().
      await controller
          .claimServer(serverId: server.id, displayName: displayName)
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      // Switch the global shell to the profile-selection state before replacing
      // this route, so a stale navbar cannot flash after saving the server name.
      widget.onServerSaved?.call();
      _finish();
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyError(error);

      // A timeout may happen after the server was actually assigned. Refresh
      // once and continue to profiles if the assignment is now visible.
      try {
        final serverContext = await controller
            .loadServerContext()
            .timeout(const Duration(seconds: 8));
        if (!mounted) return;
        if (serverContext.currentServer != null) {
          widget.onServerSaved?.call();
          _finish();
          return;
        }
        setState(() {
          _servers = serverContext.availableServers;
          _loading = false;
          _error = message;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = message;
        });
      }
    } finally {
      nameController.dispose();
      if (mounted) setState(() => _claiming = false);
    }
  }

  String _friendlyError(Object error) {
    var message = error.toString().trim();
    for (final prefix in const <String>[
      'BackendApiException:',
      'BackendApiException: ',
      'Exception: ',
    ]) {
      message = message.replaceFirst(prefix, '').trim();
    }
    if (message.isEmpty || message == 'Server selection request failed.') {
      return 'Could not save this server. Check the backend console for the server-assignment error, then try again.';
    }
    return message;
  }

  void _finish() {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    // Replace the onboarding stack rather than pushing over an old login or
    // server-selection route. The user must choose/create a profile next.
    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/app/profiles'),
        builder: (_) => ProfileSelectionScreen(
          onOpened: widget.onServerSaved,
          onProfileSelected: (profileContext) =>
              widget.onProfileReady?.call(profileContext),
        ),
      ),
      (route) => false,
    );
  }

  String _storage(int bytes) {
    if (bytes >= 1000000000000) return '${(bytes / 1000000000000).toStringAsFixed(1)} TB';
    if (bytes >= 1000000000) return '${(bytes / 1000000000).toStringAsFixed(0)} GB';
    return '${(bytes / 1000000).toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const UniversalText('Pick a Server'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const UniversalText(
                    'Choose the server that will power your personal library.',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const UniversalText(
                    'Servers already claimed by another account are not shown.',
                    style: TextStyle(color: Colors.white60),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text(_error!),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_servers.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: UniversalText('No available servers are currently available. Refresh after the administrator adds capacity.'),
                      ),
                    )
                  else
                    for (final server in _servers)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(child: Icon(Icons.dns_rounded)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(server.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                        Text(server.warehouseName, style: const TextStyle(color: Colors.white60)),
                                      ],
                                    ),
                                  ),
                                  Chip(label: Text(server.status.toUpperCase())),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(label: Text('${_storage(server.storageTotalBytes)} storage')),
                                  Chip(label: Text('${server.ramGb} GB RAM')),
                                  Chip(label: Text('${server.cpuCores} CPU cores')),
                                  Chip(label: Text(server.sshEnabled ? 'SSH available' : 'SSH unavailable')),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(value: server.storageUsage),
                              const SizedBox(height: 5),
                              Text('${(server.storageUsage * 100).toStringAsFixed(0)}% storage used', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _claiming ? null : () => _select(server),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Select server'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          if (_claiming)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Text(
                              'Saving server and opening profiles…',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
