// Connected command center: Universal Search, Remote, Movie Night, Media Health,
// Soundtrack discovery, Entertainment Recap, Playback Preferences and Account Center.
// Local settings are profile-scoped; real remote/device sync requires a configured provider.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_core.dart';
import 'smart_search.dart';
import 'localization.dart';
import 'details.dart';
import 'watch_party_lobby.dart';
import 'platform_operations_center.dart';
import 'cinematic_discovery_studio.dart';
import 'three_phase_discovery_hub.dart';

const _accent = Color(0xFF8B7CFF);

class ConnectedCommandCenterScreen extends StatelessWidget {
  const ConnectedCommandCenterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppController.instance;
    final profile = c.currentProfile;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      appBar: AppBar(title: const UniversalText('Connected Command Center'), backgroundColor: const Color(0xFF11111A)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(profile == null ? 'Your entertainment, connected' : 'Personalized for ${profile.name}', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        _FeatureTile(icon: Icons.search_rounded, title: 'Hey Universal Search', subtitle: 'Search your media library by title, person, genre or soundtrack.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalSearchHubScreen()))),
        _FeatureTile(icon: Icons.hub_rounded, title: 'Three-Phase Discovery', subtitle: 'Compare shared cast across titles, explore person connections, get history-based recommendations and review library metadata health.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThreePhaseDiscoveryHubScreen()))),
        _FeatureTile(icon: Icons.auto_awesome_rounded, title: 'My Cinematic Universe', subtitle: 'Mood Mixer, hybrid genres, Smart Double Features, franchises, calendar, vault and Media Wrapped.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CinematicDiscoveryStudioScreen()))),
        _FeatureTile(icon: Icons.gamepad_rounded, title: 'Hey Remote', subtitle: 'Playback controls and connected-device shortcuts.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeyRemoteScreen()))),
        _FeatureTile(icon: Icons.event_rounded, title: 'Hey Movie Night', subtitle: 'Build a movie-night shortlist and save your plan.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MovieNightScreen()))),
        _FeatureTile(icon: Icons.groups_rounded, title: 'Hey Watch Party', subtitle: 'Invite participants, configure individual audio and subtitles, and wait until everyone is ready.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchPartyLobbyScreen()))),
        _FeatureTile(icon: Icons.health_and_safety_rounded, title: 'My Media Health', subtitle: 'Review library size, metadata gaps and media availability.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaHealthScreen()))),
        _FeatureTile(icon: Icons.queue_music_rounded, title: 'Hey Soundtrack', subtitle: 'Discover soundtrack entries attached to your media catalog.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoundtrackScreen()))),
        _FeatureTile(icon: Icons.auto_graph_rounded, title: 'My Entertainment Recap', subtitle: 'A profile-specific snapshot of your activity.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EntertainmentRecapScreen()))),
        _FeatureTile(icon: Icons.tune_rounded, title: 'Universal Playback Preferences', subtitle: 'Save language, captions and playback preferences for this profile.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaybackPreferencesScreen()))),
        _FeatureTile(icon: Icons.manage_accounts_rounded, title: 'Account Command Center', subtitle: 'Review profile privacy and account controls.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountCommandCenterScreen()))),
        _FeatureTile(icon: Icons.admin_panel_settings_rounded, title: 'Platform Operations', subtitle: 'Admin, support, incidents, identity, billing, rights, privacy and release readiness.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlatformOperationsCenterScreen()))),
        const SizedBox(height: 12),
        const Text('Note: device remote control, cross-device sync, live program data and provider-backed playback require compatible configured services. This screen does not claim to control unsupported devices.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  const _FeatureTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override Widget build(BuildContext context) => Card(color: const Color(0xFF171722), margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: CircleAvatar(backgroundColor: _accent.withValues(alpha: .18), child: Icon(icon, color: _accent)), title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)), trailing: const Icon(Icons.chevron_right, color: Colors.white54), onTap: onTap));
}

class UniversalSearchHubScreen extends StatefulWidget { const UniversalSearchHubScreen({super.key}); @override State<UniversalSearchHubScreen> createState() => _UniversalSearchHubScreenState(); }
class _UniversalSearchHubScreenState extends State<UniversalSearchHubScreen> {
  String query = '';
  @override Widget build(BuildContext context) {
    final library = AppController.instance.library;
    final results = SmartSearch.search(query, library);
    return Scaffold(backgroundColor: const Color(0xFF0B0B10), appBar: AppBar(title: const Text('Hey Universal Search')), body: Column(children: [Padding(padding: const EdgeInsets.all(16), child: TextField(onChanged: (v) => setState(() => query = v), style: const TextStyle(color: Colors.white), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search titles, actors, genres, music…', border: OutlineInputBorder()))), Expanded(child: query.trim().isEmpty ? const Center(child: Text('Search your available media catalog.', style: TextStyle(color: Colors.white60))) : results.isEmpty ? const Center(child: Text('No matches in the current library.', style: TextStyle(color: Colors.white60))) : ListView.builder(itemCount: results.length, itemBuilder: (context, i) { final item = results[i]; return ListTile(title: Text(item.title, style: const TextStyle(color: Colors.white)), subtitle: Text('${item.type} ${item.releaseYear ?? ''}', style: const TextStyle(color: Colors.white60)), leading: const Icon(Icons.play_circle_outline, color: _accent), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaDetailsScreen(media: item)))); }))]));
  }
}

class HeyRemoteScreen extends StatelessWidget {
  const HeyRemoteScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B0B10),
        appBar: AppBar(title: const Text('Hey Remote')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gamepad_rounded, color: _accent, size: 64),
                const SizedBox(height: 16),
                const Text('Choose a connected player', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Remote commands become active when a compatible TV or playback integration is configured.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _remoteButton(Icons.skip_previous, 'Previous'),
                    _remoteButton(Icons.pause, 'Play / Pause'),
                    _remoteButton(Icons.skip_next, 'Next'),
                    _remoteButton(Icons.volume_down, 'Volume'),
                    _remoteButton(Icons.subtitles, 'Subtitles'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _remoteButton(IconData icon, String label) => OutlinedButton.icon(
        onPressed: null,
        icon: Icon(icon),
        label: Text(label),
      );
}

class MovieNightScreen extends StatefulWidget { const MovieNightScreen({super.key}); @override State<MovieNightScreen> createState() => _MovieNightScreenState(); }
class _MovieNightScreenState extends State<MovieNightScreen> {
  final selected = <String>{}; String note = '';
  @override Widget build(BuildContext context) { final items = AppController.instance.library.where((m) => m.type.toLowerCase().contains('movie')).toList(); return Scaffold(backgroundColor: const Color(0xFF0B0B10), appBar: AppBar(title: const Text('Hey Movie Night')), body: ListView(padding: const EdgeInsets.all(16), children: [const Text('Choose candidates for your next movie night.', style: TextStyle(color: Colors.white70)), TextField(onChanged: (v) => note = v, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Plan note (optional)', labelStyle: TextStyle(color: Colors.white60))), const SizedBox(height: 12), ...items.map((m) => CheckboxListTile(value: selected.contains(m.id), activeColor: _accent, title: Text(m.title, style: const TextStyle(color: Colors.white)), subtitle: Text(m.releaseYear?.toString() ?? m.type, style: const TextStyle(color: Colors.white60)), onChanged: (v) => setState(() => v == true ? selected.add(m.id) : selected.remove(m.id))),), ElevatedButton.icon(onPressed: selected.isEmpty ? null : () async { final messenger = ScaffoldMessenger.of(context); final id = AppController.instance.currentProfile?.id ?? 'default'; final selectedIds = selected.toList(); final savedNote = note; final prefs = await SharedPreferences.getInstance(); await prefs.setStringList('movie_night_$id', selectedIds); await prefs.setString('movie_night_note_$id', savedNote); if (!mounted) return; messenger.showSnackBar(const SnackBar(content: Text('Movie-night shortlist saved on this device.'))); }, icon: const Icon(Icons.save), label: const Text('Save movie-night shortlist'))])); }
}

class MediaHealthScreen extends StatelessWidget { const MediaHealthScreen({super.key}); @override Widget build(BuildContext context) { final items = AppController.instance.library; final noArtwork = items.where((m) => (m.imageUrl ?? '').trim().isEmpty).length; final noDescription = items.where((m) => (m.description ?? '').trim().isEmpty).length; final noPlayback = items.where((m) => (m.playbackUrl ?? '').trim().isEmpty).length; return Scaffold(backgroundColor: const Color(0xFF0B0B10), appBar: AppBar(title: const Text('My Media Health')), body: ListView(padding: const EdgeInsets.all(16), children: [const Text('Current catalog snapshot', style: TextStyle(color: Colors.white70)), _stat('Catalog items', '${items.length}', Icons.video_library), _stat('Missing artwork', '$noArtwork', Icons.image_not_supported), _stat('Missing descriptions', '$noDescription', Icons.description_outlined), _stat('No direct playback URL', '$noPlayback', Icons.link_off), const SizedBox(height: 12), const Text('A missing direct URL does not necessarily mean media is broken: a configured server may resolve playback on demand.', style: TextStyle(color: Colors.white54))])); } }
Widget _stat(String title, String value, IconData icon) => Card(color: const Color(0xFF171722), child: ListTile(leading: Icon(icon, color: _accent), title: Text(title, style: const TextStyle(color: Colors.white)), trailing: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));

class SoundtrackScreen extends StatelessWidget { const SoundtrackScreen({super.key}); @override Widget build(BuildContext context) { final items = AppController.instance.library.where((m) => m.music.isNotEmpty).toList(); return Scaffold(backgroundColor: const Color(0xFF0B0B10), appBar: AppBar(title: const Text('Hey Soundtrack')), body: items.isEmpty ? const Center(child: Text('No soundtrack metadata is available in this catalog yet.', style: TextStyle(color: Colors.white60))) : ListView.builder(itemCount: items.length, itemBuilder: (_, i) => ExpansionTile(title: Text(items[i].title, style: const TextStyle(color: Colors.white)), leading: const Icon(Icons.music_note, color: _accent), children: items[i].music.map((track) => ListTile(title: Text(track, style: const TextStyle(color: Colors.white70)), subtitle: const Text('Track metadata · playback depends on a configured music source', style: TextStyle(color: Colors.white38)))).toList()))); } }

class EntertainmentRecapScreen extends StatelessWidget { const EntertainmentRecapScreen({super.key}); @override Widget build(BuildContext context) { final c = AppController.instance; final watched = c.watched; final genres = <String,int>{}; for (final m in watched) { for (final g in m.genres) { genres[g] = (genres[g] ?? 0) + 1; } } final top = genres.entries.toList()..sort((a,b) => b.value.compareTo(a.value)); return Scaffold(backgroundColor: const Color(0xFF0B0B10), appBar: AppBar(title: const Text('My Entertainment Recap')), body: ListView(padding: const EdgeInsets.all(16), children: [_stat('Watched items', '${watched.length}', Icons.visibility), _stat('Catalog size', '${c.library.length}', Icons.video_library), _stat('Genres represented in watched history', '${genres.length}', Icons.category), const SizedBox(height: 16), const Text('Most represented genres in watched history', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 8), if (top.isEmpty) const Text('Watch some catalog items to build your recap.', style: TextStyle(color: Colors.white60)), ...top.take(8).map((e) => ListTile(title: Text(e.key, style: const TextStyle(color: Colors.white)), trailing: Text('${e.value}', style: const TextStyle(color: Colors.white70))))])); } }

class PlaybackPreferencesScreen extends StatefulWidget { const PlaybackPreferencesScreen({super.key}); @override State<PlaybackPreferencesScreen> createState() => _PlaybackPreferencesScreenState(); }
class _PlaybackPreferencesScreenState extends State<PlaybackPreferencesScreen> {
  String language = 'Use content default'; String quality = 'Auto'; bool captions = false; bool audioDescription = false; bool autoplay = true; bool loading = true;
  String get keyPrefix => 'playback_${AppController.instance.currentProfile?.id ?? 'default'}_';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); if (!mounted) return; setState(() { language = p.getString('${keyPrefix}language') ?? language; quality = p.getString('${keyPrefix}quality') ?? quality; captions = p.getBool('${keyPrefix}captions') ?? captions; audioDescription = p.getBool('${keyPrefix}audio_description') ?? audioDescription; autoplay = p.getBool('${keyPrefix}autoplay') ?? autoplay; loading = false; }); }
  Future<void> _save() async { final p = await SharedPreferences.getInstance(); await p.setString('${keyPrefix}language', language); await p.setString('${keyPrefix}quality', quality); await p.setBool('${keyPrefix}captions', captions); await p.setBool('${keyPrefix}audio_description', audioDescription); await p.setBool('${keyPrefix}autoplay', autoplay); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF0B0B10), appBar: AppBar(title: const Text('Playback Preferences')), body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [DropdownButtonFormField<String>(initialValue: language, dropdownColor: const Color(0xFF171722), decoration: const InputDecoration(labelText: 'Preferred audio language'), items: ['Use content default','English','Spanish','French','Portuguese','Japanese'].map((x) => DropdownMenuItem(value:x, child: Text(x))).toList(), onChanged: (v) { if(v!=null) setState(()=>language=v); }), const SizedBox(height: 16), DropdownButtonFormField<String>(initialValue: quality, dropdownColor: const Color(0xFF171722), decoration: const InputDecoration(labelText: 'Playback quality'), items: ['Auto','Data saver','Standard','High'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(), onChanged:(v){if(v!=null)setState(()=>quality=v);}), SwitchListTile(value: captions, title: const Text('Captions / subtitles'), onChanged:(v)=>setState(()=>captions=v)), SwitchListTile(value: audioDescription, title: const Text('Audio description when available'), onChanged:(v)=>setState(()=>audioDescription=v)), SwitchListTile(value: autoplay, title: const Text('Autoplay next episode'), onChanged:(v)=>setState(()=>autoplay=v)), ElevatedButton.icon(onPressed: () async { final messenger = ScaffoldMessenger.of(context); await _save(); if (!mounted) return; messenger.showSnackBar(const SnackBar(content: Text('Preferences saved for this profile on this device.'))); }, icon: const Icon(Icons.save), label: const Text('Save preferences'))]));
}

class AccountCommandCenterScreen extends StatefulWidget { const AccountCommandCenterScreen({super.key}); @override State<AccountCommandCenterScreen> createState() => _AccountCommandCenterScreenState(); }
class _AccountCommandCenterScreenState extends State<AccountCommandCenterScreen> {
 bool shareActivity = true; bool showFriends = true; bool personalizedRecommendations = true; bool notifications = true; bool loading = true;
 String get prefix => 'account_center_${AppController.instance.currentProfile?.id ?? 'default'}_';
 @override void initState(){super.initState(); _load();}
 Future<void> _load() async { final p=await SharedPreferences.getInstance(); if(!mounted)return; setState((){shareActivity=p.getBool('${prefix}share_activity')??true;showFriends=p.getBool('${prefix}show_friends')??true;personalizedRecommendations=p.getBool('${prefix}recommendations')??true;notifications=p.getBool('${prefix}notifications')??true;loading=false;}); }
 Future<void> _save() async { final p=await SharedPreferences.getInstance(); await p.setBool('${prefix}share_activity',shareActivity);await p.setBool('${prefix}show_friends',showFriends);await p.setBool('${prefix}recommendations',personalizedRecommendations);await p.setBool('${prefix}notifications',notifications); }
 @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF0B0B10), appBar: AppBar(title: const Text('Account Command Center')), body: loading ? const Center(child:CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [const Text('Profile preferences · saved on this device',style:TextStyle(color:Colors.white60)), SwitchListTile(value:shareActivity,title:const Text('Share my watch/listening activity'),onChanged:(v)=>setState(()=>shareActivity=v)),SwitchListTile(value:showFriends,title:const Text('Show my profile to friends'),onChanged:(v)=>setState(()=>showFriends=v)),SwitchListTile(value:personalizedRecommendations,title:const Text('Personalized recommendations'),onChanged:(v)=>setState(()=>personalizedRecommendations=v)),SwitchListTile(value:notifications,title:const Text('Entertainment notifications'),onChanged:(v)=>setState(()=>notifications=v)),const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('These client-side preferences are not a replacement for backend authorization. Shared activity and friend visibility must also be enforced by the account service.',style:TextStyle(color:Colors.orangeAccent))),ElevatedButton.icon(onPressed:() async {final messenger = ScaffoldMessenger.of(context); await _save(); if (!mounted) return; messenger.showSnackBar(const SnackBar(content:Text('Profile preferences saved on this device.')));},icon:const Icon(Icons.save),label:const Text('Save account preferences'))]));
}
