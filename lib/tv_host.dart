import 'dart:async';

import 'package:flutter/material.dart';

import 'app_core.dart';

class TvHostScreen extends StatefulWidget {
  const TvHostScreen({super.key});

  @override
  State<TvHostScreen> createState() => _TvHostScreenState();
}

class _TvHostScreenState extends State<TvHostScreen> {
  String? _deviceId;
  String? _code;
  DateTime? _expiresAt;
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _commands = const [];
  Map<String, dynamic> _tvState = const {'state': 'idle'};

  @override
  void initState() {
    super.initState();
    _startPairing();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPairing() async {
    final controller = AppController.instance;
    _deviceId = 'tv_${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(this)}';
    try {
      final result = await controller.backendApi.createTvPairingCode(
        tvDeviceId: _deviceId!,
        tvDeviceName: 'Living Room TV',
      );
      if (!mounted) return;
      setState(() {
        _code = result['code']?.toString();
        _expiresAt = DateTime.tryParse(result['expiresAt']?.toString() ?? '');
      });
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _poll() async {
    final id = _deviceId;
    if (id == null) return;
    try {
      final commands = await AppController.instance.backendApi.pollTvCommands(id);
      final state = await AppController.instance.backendApi.getTvState(id);
      if (!mounted) return;
      setState(() {
        _tvState = state;
        if (commands.isNotEmpty) _commands = [...commands.reversed.take(8)];
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final code = _code ?? '------';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('TV Host Mode')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.tv_rounded, size: 82),
                const SizedBox(height: 24),
                const Text('Pair your phone controller', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                const Text('Open the mobile app, choose TV Controller, and enter this code.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 28),
                Text(code, style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, letterSpacing: 10)),
                if (_expiresAt != null) Text('Expires ${_expiresAt!.toLocal()}', style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 30),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: Text(_tvState['title']?.toString() ?? 'Nothing playing'),
                    subtitle: Text('${_tvState['state'] ?? 'idle'} • ${_tvState['positionSeconds'] ?? 0}s'),
                  ),
                ),
                const SizedBox(height: 12),
                if (_commands.isNotEmpty) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text('Recent controller activity', style: TextStyle(fontWeight: FontWeight.w800))),
                  const SizedBox(height: 8),
                  ..._commands.map((command) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.gamepad_outlined),
                        title: Text('${command['command']}'),
                      )),
                ],
                const SizedBox(height: 18),
                OutlinedButton.icon(onPressed: _startPairing, icon: const Icon(Icons.refresh), label: const Text('New code')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
