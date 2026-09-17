// FILE: lib/profile_content_safety.dart.
// Purpose: Provides profile-scoped content and safety controls for film, TV,
// music, lyrics, music videos, search, social features and Group Watch.
// Settings are stored by profile and do not alter the account's source media.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'localization.dart';
import 'platform_expansion.dart';

/// Available high-level content levels for a profile.
class ProfileContentSafetyScreen extends StatefulWidget {
  final Profile profile;

  const ProfileContentSafetyScreen({super.key, required this.profile});

  @override
  State<ProfileContentSafetyScreen> createState() =>
      _ProfileContentSafetyScreenState();
}

class _ProfileContentSafetyScreenState
    extends State<ProfileContentSafetyScreen> {
  static const _levels = <String>['Baby', 'Kids', 'Teen', '18+', '21+', 'Custom'];

  String get _level => PlatformPreferenceStore.getString(
        'content_safety',
        'level',
        fallback: 'Teen',
      );

  Future<void> _setLevel(String value) async {
    await PlatformPreferenceStore.setString('content_safety', 'level', value);
    if (mounted) setState(() {});
  }

  bool _get(String key, {bool fallback = false}) =>
      PlatformPreferenceStore.getBool('content_safety', key, fallback: fallback);

  Future<void> _set(String key, bool value) async {
    await PlatformPreferenceStore.setBool('content_safety', key, value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.profile.name} • Content & Safety'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const UniversalText(
            'Content & Safety',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const UniversalText(
            'Set this profile independently from every other profile. Film and TV use age levels; music uses its own explicit-content controls.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UniversalText(
                    'Movies & TV',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _levels.contains(_level) ? _level : 'Teen',
                    decoration: const InputDecoration(
                      labelText: 'Content level',
                      border: OutlineInputBorder(),
                    ),
                    items: _levels
                        .map((level) => DropdownMenuItem(
                              value: level,
                              child: Text(level),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _setLevel(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  const UniversalText(
                    'Custom can be used when the profile needs a more specific combination of ratings and categories.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _section(
            'Music & Audio',
            [
              _switch('Block explicit songs', 'block_explicit_music', true),
              _switch('Block explicit lyrics', 'block_explicit_lyrics', true),
              _switch('Clean music videos only', 'clean_music_videos', true),
              _switch('Block mature themes', 'block_mature_music', false),
              _switch('Hide lyrics entirely', 'hide_lyrics', false),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            'App Access',
            [
              _switch('Hide restricted search results', 'hide_restricted_search', true),
              _switch('Block restricted Group Watch', 'block_group_watch', true),
              _switch('Restrict social features', 'restrict_social', false),
              _switch('Restrict importing', 'restrict_imports', false),
              _switch('Restrict purchases', 'restrict_purchases', true),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            'Additional Safety Checks',
            [
              _switch('Require approval for uncertain metadata', 'approval_uncertain', true),
              _switch('Require approval for mature content', 'approval_mature', false),
              _switch('Show content warnings before playback', 'show_warnings', true),
              _switch('Protect mature content with profile PIN', 'mature_pin', false),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlatformExpansionScreen()),
            ),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('OPEN ADVANCED SAFETY SETTINGS'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              ),
              ...children,
            ],
          ),
        ),
      );

  Widget _switch(String title, String key, bool fallback) => SwitchListTile(
        title: Text(title),
        value: _get(key, fallback: fallback),
        onChanged: (value) => _set(key, value),
      );
}

/// Returns whether a profile-level music restriction is enabled.
bool profileBlocksExplicitMusic(Profile? profile) {
  if (profile == null) return false;
  return PlatformPreferenceStore.getBool(
    'content_safety',
    'block_explicit_music',
    fallback: true,
  );
}

/// Returns whether a profile-level mature music restriction is enabled.
bool profileBlocksMatureMusic(Profile? profile) {
  if (profile == null) return false;
  return PlatformPreferenceStore.getBool(
    'content_safety',
    'block_mature_music',
    fallback: false,
  );
}
