import 'package:flutter/material.dart';

/// Guided troubleshooting and planning. This screen records no live playback
/// telemetry; it helps users classify a symptom until backend events are wired.
class PlaybackDiagnosticsCenterScreen extends StatefulWidget {
  const PlaybackDiagnosticsCenterScreen({super.key});

  @override
  State<PlaybackDiagnosticsCenterScreen> createState() =>
      _PlaybackDiagnosticsCenterScreenState();
}

class _PlaybackDiagnosticsCenterScreenState
    extends State<PlaybackDiagnosticsCenterScreen> {
  String _symptom = 'Buffering or quality drops';
  String _network = 'Remote / internet';
  String _path = 'Unknown';
  bool _subtitles = false;
  bool _audioIssue = false;
  bool _startedAfterUpdate = false;

  List<String> get _checks {
    final items = <String>[];
    if (_network == 'Remote / internet') {
      items.add(
          'Compare server sustained upload with the stream bitrate; leave headroom for other household traffic.');
      items.add(
          'Test remote latency and packet loss; confirm the HTTPS gateway is reachable without exposing admin or storage ports.');
    } else {
      items.add(
          'Test local Wi-Fi/Ethernet throughput and packet loss between client and media server.');
    }
    if (_path == 'Transcode') {
      items.add(
          'Inspect server-side transcode logs, CPU/GPU utilization, queue depth, and supported hardware acceleration.');
    } else if (_path == 'Direct Play') {
      items.add(
          'Verify the client supports the file container, video/audio codecs, bitrate, HDR profile, and subtitles.');
    } else {
      items.add(
          'Capture the actual playback decision (Direct Play, remux, or transcode) from the server before changing settings.');
    }
    if (_subtitles) {
      items.add(
          'Temporarily disable subtitles to determine whether subtitle rendering or burn-in triggers transcoding.');
    }
    if (_audioIssue) {
      items.add(
          'Compare another audio track and verify codec, channel layout, passthrough, and client output settings.');
    }
    if (_startedAfterUpdate) {
      items.add(
          'Compare app/server versions and recent configuration changes; roll back only with a verified recovery path.');
    }
    if (_symptom == 'Playback fails to start') {
      items.add(
          'Check authorization, media-file readability, server logs, and a known-good test title.');
    }
    if (_symptom == 'Wrong title, edition, or episode') {
      items.add(
          'Re-run metadata matching in review mode; preserve the existing match until the replacement is confirmed.');
    }
    if (_symptom == 'Remote access fails') {
      items.add(
          'Check DNS, TLS certificate validity, gateway health, account permissions, and firewall rules from outside the home network.');
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Playback Diagnostics')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.troubleshoot_rounded,
                          size: 34, color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text('Find the failing layer',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      const Text(
                          'Guided checks only. Live playback events, server logs, and network probes are not connected by this screen.'),
                    ]))),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
            initialValue: _symptom,
            decoration: const InputDecoration(labelText: 'Observed symptom'),
            items: const [
              DropdownMenuItem(
                  value: 'Buffering or quality drops',
                  child: Text('Buffering or quality drops')),
              DropdownMenuItem(
                  value: 'Playback fails to start',
                  child: Text('Playback fails to start')),
              DropdownMenuItem(
                  value: 'Remote access fails',
                  child: Text('Remote access fails')),
              DropdownMenuItem(
                  value: 'Wrong title, edition, or episode',
                  child: Text('Wrong title, edition, or episode')),
            ],
            onChanged: (v) => setState(() => _symptom = v ?? _symptom)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
            initialValue: _network,
            decoration: const InputDecoration(labelText: 'Playback location'),
            items: const [
              DropdownMenuItem(
                  value: 'Local network', child: Text('Local network')),
              DropdownMenuItem(
                  value: 'Remote / internet', child: Text('Remote / internet')),
            ],
            onChanged: (v) => setState(() => _network = v ?? _network)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
            initialValue: _path,
            decoration:
                const InputDecoration(labelText: 'Playback path (if known)'),
            items: const [
              DropdownMenuItem(value: 'Unknown', child: Text('Unknown')),
              DropdownMenuItem(
                  value: 'Direct Play', child: Text('Direct Play')),
              DropdownMenuItem(value: 'Transcode', child: Text('Transcode')),
            ],
            onChanged: (v) => setState(() => _path = v ?? _path)),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Problem changes when subtitles are disabled'),
            value: _subtitles,
            onChanged: (v) => setState(() => _subtitles = v)),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Audio track or output problem'),
            value: _audioIssue,
            onChanged: (v) => setState(() => _audioIssue = v)),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title:
                const Text('Started after an update or configuration change'),
            value: _startedAfterUpdate,
            onChanged: (v) => setState(() => _startedAfterUpdate = v)),
        const SizedBox(height: 12),
        Text('Recommended checks', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        for (var i = 0; i < _checks.length; i++)
          Card(
              child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(_checks[i]))),
        const SizedBox(height: 12),
        const Text(
            'Safety: do not disable authentication, expose database/storage ports, or delete media as a troubleshooting shortcut. Capture logs with secrets and personal data redacted.'),
      ]),
    );
  }
}
