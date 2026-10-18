// Hey Watch Party lobby prototype. Shared session synchronization and provider
// track discovery require a backend/playback integration; this screen does not
// pretend local readiness is synchronized across devices.
import 'package:flutter/material.dart';
import 'app_core.dart';

const _partyAccent = Color(0xFF8B7CFF);

class WatchPartyLobbyScreen extends StatefulWidget {
  const WatchPartyLobbyScreen({super.key});
  @override State<WatchPartyLobbyScreen> createState() => _WatchPartyLobbyScreenState();
}

class _PartyGuest {
  _PartyGuest({required this.name, this.isHost = false, this.accepted = true,
    this.ready = false});
  final String name;
  final bool isHost;
  bool accepted;
  String audio = 'English';
  String subtitles = 'Off';
  bool ready;
}

class _WatchPartyLobbyScreenState extends State<WatchPartyLobbyScreen> {
  final _inviteController = TextEditingController();
  final List<_PartyGuest> _guests = [];
  String? _selectedMediaId;
  bool _started = false;
  bool _cancelled = false;

  List<MediaItem> get _eligibleMedia => AppController.instance.library.where((m) {
    final t = m.type.toLowerCase();
    return t.contains('movie') || t.contains('tv') || t.contains('show') || t.contains('episode') || m.seasons.isNotEmpty;
  }).toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  MediaItem? get _selectedMedia {
    for (final item in _eligibleMedia) {
      if (item.id == _selectedMediaId) {
        return item;
      }
    }
    return null;
  }
  bool get _allReady => _guests.where((g) => g.accepted).isNotEmpty && _guests.where((g) => g.accepted).every((g) => g.ready);

  @override void initState() {
    super.initState();
    final profile = AppController.instance.currentProfile;
    if (profile != null) {
      _guests.add(_PartyGuest(name: '${profile.name} · Host', isHost: true, ready: false));
    } else {
      _guests.add(_PartyGuest(name: 'You · Host', isHost: true, ready: false));
    }
  }
  @override void dispose() { _inviteController.dispose(); super.dispose(); }

  void _changed(_PartyGuest guest, VoidCallback update) => setState(() { update(); guest.ready = false; _started = false; });
  void _invite() {
    final name = _inviteController.text.trim();
    if (name.isEmpty) return;
    if (_guests.any((g) => g.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That participant is already in the lobby.'))); return;
    }
    setState(() { _guests.add(_PartyGuest(name: name, accepted: false)); _inviteController.clear(); });
  }

  @override Widget build(BuildContext context) {
    final media = _eligibleMedia;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(title: const Text('Hey Watch Party'), backgroundColor: const Color(0xFF11111A), actions: [IconButton(tooltip: 'Cancel party', onPressed: () => setState(() { _cancelled = true; _started = false; }), icon: const Icon(Icons.close_rounded))]),
      body: _cancelled ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.event_busy, size: 52, color: Colors.white54), const SizedBox(height: 12), const Text('This party was cancelled.', style: TextStyle(color: Colors.white)), TextButton(onPressed: () => setState(() { _cancelled = false; }), child: const Text('Return to lobby'))]))
      : ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Invite everyone, set your own audio and subtitles, then start when the whole party is ready.', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 18),
        _sectionTitle('1 · Choose a movie or TV episode'),
        if (media.isEmpty) const Card(color: Color(0xFF171722), child: Padding(padding: EdgeInsets.all(16), child: Text('Your catalog has no identifiable movies or TV shows yet. Add media to the library to create a party.', style: TextStyle(color: Colors.white70))))
        else DropdownButtonFormField<String>(initialValue: _selectedMediaId, isExpanded: true, dropdownColor: const Color(0xFF171722), decoration: const InputDecoration(labelText: 'Party title', border: OutlineInputBorder()), items: media.map((m) => DropdownMenuItem(value: m.id, child: Text('${m.title} · ${m.type}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() { _selectedMediaId = v; _started = false; for (final g in _guests) { g.ready = false; } })),
        const SizedBox(height: 22), _sectionTitle('2 · Invite participants'),
        Row(children: [Expanded(child: TextField(controller: _inviteController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Friend / profile name', border: OutlineInputBorder()), onSubmitted: (_) => _invite())), const SizedBox(width: 8), IconButton.filled(onPressed: _invite, icon: const Icon(Icons.person_add_alt_1), tooltip: 'Add invite')]),
        const SizedBox(height: 8),
        ..._guests.map((g) => _guestCard(g)),
        const SizedBox(height: 22), _sectionTitle('3 · Personal audio and subtitles'),
        const Text('Each accepted participant has independent choices. Languages shown here are options only; the selected source must actually provide the track.', style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 8),
        ..._guests.where((g) => g.accepted).map((g) => _settingsCard(g)),
        const SizedBox(height: 18),
        Card(color: const Color(0xFF171722), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(_allReady && _selectedMedia != null ? Icons.check_circle : Icons.hourglass_top, color: _allReady && _selectedMedia != null ? Colors.greenAccent : Colors.orangeAccent), const SizedBox(width: 8), Expanded(child: Text('${_guests.where((g) => g.accepted && g.ready).length} of ${_guests.where((g) => g.accepted).length} accepted participants ready', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]), const SizedBox(height: 8), Text(_selectedMedia == null ? 'Choose a title before starting.' : !_allReady ? 'Waiting for every accepted participant to confirm their settings and readiness.' : 'Everyone is ready. The host can start the party.', style: const TextStyle(color: Colors.white60))]))),
        const SizedBox(height: 10),
        if (!_started) FilledButton.icon(onPressed: _selectedMedia != null && _allReady ? () => setState(() => _started = true) : null, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start Watching'))
        else Card(color: const Color(0xFF17251D), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [const Icon(Icons.groups_rounded, size: 42, color: Colors.greenAccent), const SizedBox(height: 8), Text('Party ready: ${_selectedMedia?.title ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 6), const Text('The local lobby is marked started. Synchronized playback across devices requires a connected session backend and compatible playback provider.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)), TextButton(onPressed: () => setState(() { _started = false; for (final g in _guests) { g.ready = false; } }), child: const Text('Return to lobby'))]))),
        const SizedBox(height: 12),
        const Text('Prototype boundary: invitations and readiness are held in this screen only. Real invite delivery, accept/decline from another device, live track availability, synchronized playback, and reconnect recovery require backend and provider integration.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
      ]),
    );
  }

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)));

  Widget _guestCard(_PartyGuest g) => Card(color: const Color(0xFF171722), margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [CircleAvatar(backgroundColor: _partyAccent.withValues(alpha: .18), child: Icon(g.isHost ? Icons.workspace_premium : Icons.person, color: _partyAccent)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), Text(g.isHost ? 'Host' : g.accepted ? (g.ready ? 'Accepted · Ready' : 'Accepted · Not ready') : 'Invitation pending', style: const TextStyle(color: Colors.white60, fontSize: 12))])), if (!g.isHost) PopupMenuButton<String>(onSelected: (v) => setState(() { if (v == 'accept') { g.accepted = true; g.ready = false; } else if (v == 'decline') { g.accepted = false; g.ready = false; } else if (v == 'remove') { _guests.remove(g); } _started = false; }), itemBuilder: (_) => [if (!g.accepted) const PopupMenuItem(value: 'accept', child: Text('Simulate accept invitation')), if (g.accepted) const PopupMenuItem(value: 'decline', child: Text('Decline / leave party')), const PopupMenuItem(value: 'remove', child: Text('Remove participant'))], icon: const Icon(Icons.more_vert, color: Colors.white70))])));

  Widget _settingsCard(_PartyGuest g) => Card(color: const Color(0xFF171722), margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 8), DropdownButtonFormField<String>(initialValue: g.audio, isExpanded: true, dropdownColor: const Color(0xFF171722), decoration: const InputDecoration(labelText: 'Audio language', border: OutlineInputBorder()), items: ['English','Spanish','French','Portuguese','Japanese','German','Use source default'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) { if (v != null) _changed(g, () => g.audio = v); }), const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: g.subtitles, isExpanded: true, dropdownColor: const Color(0xFF171722), decoration: const InputDecoration(labelText: 'Subtitles', border: OutlineInputBorder()), items: ['Off','English','Spanish','French','Portuguese','Japanese','German','SDH / closed captions'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) { if (v != null) _changed(g, () => g.subtitles = v); }), const SizedBox(height: 8), SwitchListTile(contentPadding: EdgeInsets.zero, value: g.ready, title: const Text('Ready to Watch', style: TextStyle(color: Colors.white)), subtitle: const Text('Confirm your language and subtitle choices', style: TextStyle(color: Colors.white54)), onChanged: (v) => setState(() { g.ready = v; _started = false; }))])));
}
