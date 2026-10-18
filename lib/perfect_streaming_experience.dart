// FILE: `lib/perfect_streaming_experience.dart`.
// Purpose: Combines the most useful streaming UX patterns into one per-profile
// preference screen. Provider-specific integrations remain opt-in and separate.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';
import 'localization.dart';
import 'smart_search.dart';

class PerfectStreamingExperienceScreen extends StatefulWidget {
  const PerfectStreamingExperienceScreen({super.key});

  @override
  State<PerfectStreamingExperienceScreen> createState() =>
      _PerfectStreamingExperienceScreenState();
}

class _PerfectStreamingExperienceScreenState
    extends State<PerfectStreamingExperienceScreen> {
  SharedPreferences? _prefs;
  bool _loading = true;
  bool _cleanNavigation = true;
  bool _personalizedDiscovery = true;
  bool _autoplayNext = true;
  bool _rememberPlayback = true;
  bool _unifiedSeasons = true;
  bool _liveAndNextDay = false;
  bool _watchParty = true;
  bool _tagSearch = true;

  String get _profileKey =>
      AppController.instance.currentProfile?.id ?? 'default';

  String _key(String setting) => 'perfect_streaming_${_profileKey}_$setting';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _cleanNavigation = prefs.getBool(_key('clean_navigation')) ?? true;
      _personalizedDiscovery = prefs.getBool(_key('personalized_discovery')) ?? true;
      _autoplayNext = prefs.getBool(_key('autoplay_next')) ?? true;
      _rememberPlayback = prefs.getBool(_key('remember_playback')) ?? true;
      _unifiedSeasons = prefs.getBool(_key('unified_seasons')) ?? true;
      _liveAndNextDay = prefs.getBool(_key('live_next_day')) ?? false;
      _watchParty = prefs.getBool(_key('watch_party')) ?? true;
      _tagSearch = prefs.getBool(_key('tag_search')) ?? true;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value, void Function() update) async {
    setState(update);
    await _prefs?.setBool(_key(key), value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const UniversalText('Perfect Streaming Experience'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 30),
                      const SizedBox(height: 10),
                      Text('Your streaming, your way',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      const Text(
                        'Combine clean navigation, smarter discovery, a better player and shared viewing. These preferences are saved for this profile.',
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SmartSearchScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Open unified search'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _section('Navigation & discovery', 'Make it easy to find something worth watching.'),
                _toggle('Clean, intuitive navigation', 'Prefer clear destinations and fewer confusing menu layers.', _cleanNavigation,
                    (v) => _set('clean_navigation', v, () => _cleanNavigation = v), Icons.explore_outlined),
                _toggle('Personalized recommendations', 'Use profile preferences and viewing activity where supported.', _personalizedDiscovery,
                    (v) => _set('personalized_discovery', v, () => _personalizedDiscovery = v), Icons.recommend_outlined),
                _toggle('Tag-based search filters', 'Keep genre, mood, year and other descriptive filters available.', _tagSearch,
                    (v) => _set('tag_search', v, () => _tagSearch = v), Icons.filter_alt_outlined),
                const SizedBox(height: 12),
                _section('Player & series', 'Reduce friction between episodes and keep your place.'),
                _toggle('Autoplay next episode', 'Allow the next episode to start automatically when supported.', _autoplayNext,
                    (v) => _set('autoplay_next', v, () => _autoplayNext = v), Icons.skip_next_rounded),
                _toggle('Remember playback position', 'Make it easy to resume a movie or episode.', _rememberPlayback,
                    (v) => _set('remember_playback', v, () => _rememberPlayback = v), Icons.history_rounded),
                _toggle('Unified seasons and episodes', 'Prefer season and episode navigation without returning to the main menu.', _unifiedSeasons,
                    (v) => _set('unified_seasons', v, () => _unifiedSeasons = v), Icons.video_library_outlined),
                const SizedBox(height: 12),
                _section('Shared and live viewing', 'Bring people and more kinds of programming together.'),
                _toggle('Watch Party shortcuts', 'Keep synchronized group viewing easy to discover.', _watchParty,
                    (v) => _set('watch_party', v, () => _watchParty = v), Icons.groups_rounded),
                _toggle('Live TV and next-day content', 'Show interest in live or next-day programming when a connected provider offers it.', _liveAndNextDay,
                    (v) => _set('live_next_day', v, () => _liveAndNextDay = v), Icons.live_tv_rounded),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'These controls save your experience preferences. Live TV, next-day catalogs, provider recommendations and Watch Party playback still depend on the relevant content source, backend and licensing rights; enabling a preference does not create a provider integration.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _section(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  Widget _toggle(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged, IconData icon) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          secondary: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      );
}
