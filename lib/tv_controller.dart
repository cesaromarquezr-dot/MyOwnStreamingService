import 'package:flutter/material.dart';

import 'app_core.dart';
import 'localization.dart';

class TvControllerScreen extends StatefulWidget {
  const TvControllerScreen({super.key});

  @override
  State<TvControllerScreen> createState() => _TvControllerScreenState();
}

class _TvControllerScreenState extends State<TvControllerScreen> {
  String _mode = 'remote';
  List<Map<String, dynamic>> _pairings = const [];
  bool _loading = true;
  String? _selectedTvId;
  String? _phoneDeviceId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _phoneDeviceId ??= await AppController.instance.ensureDeviceId();
      final pairings = await AppController.instance.backendApi.getTvPairings();
      if (!mounted) return;
      setState(() {
        _pairings = pairings;
        _selectedTvId ??= pairings.isNotEmpty ? pairings.first['tvDeviceId']?.toString() : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pair() async {
    final codeController = TextEditingController();
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pair a TV'),
          content: TextField(controller: codeController, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit TV code')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Pair')),
          ],
        ),
      );
      if (accepted != true) return;
      await AppController.instance.backendApi.pairTvDevice(
        codeController.text.trim(),
        profileId: AppController.instance.currentProfile?.id ?? '',
        phoneDeviceId: _phoneDeviceId ?? await AppController.instance.ensureDeviceId(),
      );
      await _load();
    } finally {
      codeController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _pairings.firstWhere(
      (item) => item['tvDeviceId']?.toString() == _selectedTvId,
      orElse: () => const <String, dynamic>{},
    );
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('TV Controller'),
        actions: [IconButton(onPressed: _pair, icon: const Icon(Icons.add_link_rounded), tooltip: 'Pair TV')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                if (_pairings.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(20), child: UniversalText('Pair a TV to use your phone as a remote, game controller, keyboard, or second screen.')))
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTvId,
                    decoration: const InputDecoration(labelText: 'Connected TV', border: OutlineInputBorder()),
                    items: _pairings.map((pairing) => DropdownMenuItem(value: pairing['tvDeviceId']?.toString(), child: Text(pairing['tvName']?.toString() ?? 'TV'))).toList(),
                    onChanged: (value) => setState(() => _selectedTvId = value),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'remote', label: Text('Remote'), icon: Icon(Icons.settings_remote_rounded)),
                      ButtonSegment(value: 'controller', label: Text('Gamepad'), icon: Icon(Icons.sports_esports_outlined)),
                      ButtonSegment(value: 'second-screen', label: Text('Second Screen'), icon: Icon(Icons.phone_android)),
                      ButtonSegment(value: 'keyboard', label: Text('Keyboard'), icon: Icon(Icons.keyboard_outlined)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (selection) => setState(() => _mode = selection.first),
                  ),
                  const SizedBox(height: 18),
                  _mode == 'remote'
                      ? _RemoteControls(tvId: _selectedTvId)
                      : _mode == 'controller'
                          ? _GameController(tvId: _selectedTvId)
                          : _mode == 'keyboard'
                              ? _KeyboardController(tvId: _selectedTvId)
                              : _SecondScreen(tv: selected),
                ],
              ],
            ),
    );
  }
}

class _RemoteControls extends StatelessWidget {
  final String? tvId;
  const _RemoteControls({required this.tvId});

  void _send(BuildContext context, String action) {
    AppController.instance.backendApi.sendTvCommand(tvDeviceId: tvId ?? '', profileId: AppController.instance.currentProfile?.id ?? '', command: {'type': 'remote', 'action': action}).catchError((error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: () => _send(context, 'back'), icon: const Icon(Icons.arrow_back)),
            IconButton(onPressed: () => _send(context, 'home'), icon: const Icon(Icons.home_outlined)),
            IconButton(onPressed: () => _send(context, 'guide'), icon: const Icon(Icons.tv_outlined)),
          ]),
          const SizedBox(height: 8),
          IconButton.filled(onPressed: () => _send(context, 'play_pause'), icon: const Icon(Icons.play_arrow_rounded), iconSize: 34),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: () => _send(context, 'rewind'), icon: const Icon(Icons.replay_10)),
            IconButton(onPressed: () => _send(context, 'forward'), icon: const Icon(Icons.forward_10)),
            IconButton(onPressed: () => _send(context, 'next'), icon: const Icon(Icons.skip_next)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton(onPressed: () => _send(context, 'volume_down'), child: const Text('Vol -')),
            OutlinedButton(onPressed: () => _send(context, 'volume_up'), child: const Text('Vol +')),
            OutlinedButton(onPressed: () => _send(context, 'mute'), child: const Text('Mute')),
          ]),
        ]),
      ),
    );
  }
}

class _GameController extends StatelessWidget {
  final String? tvId;
  const _GameController({required this.tvId});

  void _send(BuildContext context, String command) {
    AppController.instance.backendApi.sendTvCommand(tvDeviceId: tvId ?? '', profileId: AppController.instance.currentProfile?.id ?? '', command: {'type': 'gamepad', 'action': command}).catchError((error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(onPressed: () => _send(context, 'left'), icon: const Icon(Icons.arrow_left_rounded), iconSize: 36),
        Column(children: [
          IconButton(onPressed: () => _send(context, 'up'), icon: const Icon(Icons.arrow_drop_up_rounded), iconSize: 36),
          IconButton(onPressed: () => _send(context, 'down'), icon: const Icon(Icons.arrow_drop_down_rounded), iconSize: 36),
        ]),
        IconButton(onPressed: () => _send(context, 'right'), icon: const Icon(Icons.arrow_right_rounded), iconSize: 36),
      ]),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: () => _send(context, 'primary'), icon: const Icon(Icons.circle), label: const Text('A / Select')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => _send(context, 'secondary'), icon: const Icon(Icons.close), label: const Text('B / Back')),
    ])));
  }
}

class _KeyboardController extends StatelessWidget {
  final String? tvId;
  const _KeyboardController({required this.tvId});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: TextField(
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Type on TV', border: OutlineInputBorder()),
      onChanged: (value) => AppController.instance.backendApi.sendTvCommand(tvDeviceId: tvId ?? '', profileId: AppController.instance.currentProfile?.id ?? '', command: {'type': 'keyboard', 'text': value}),
    )));
  }
}

class _SecondScreen extends StatelessWidget {
  final Map<String, dynamic> tv;
  const _SecondScreen({required this.tv});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tv['tvName']?.toString() ?? 'TV', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('Companion / second-screen mode does not take over playback. It displays synchronized information while the TV remains the primary screen.', style: TextStyle(color: Colors.white60)),
      const SizedBox(height: 14),
      const ListTile(leading: Icon(Icons.info_outline), title: Text('Now Playing'), subtitle: Text('The TV app can publish the current title, episode, cast, soundtrack, trivia and synchronized controls here.')),
      const ListTile(leading: Icon(Icons.people_outline), title: Text('Social'), subtitle: Text('Friends, reactions, chat and watch-party controls can appear here while the TV stays focused on playback.')),
    ])));
  }
}
