// FILE: `lib/navigation_hubs.dart`.
// Purpose: Fixed primary-navigation hubs for Library, Discover, and Friends.
// The primary navbar stays intentionally small; detailed destinations live
// inside these hubs or behind More.

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'feature_center.dart';
import 'library_hubs.dart';
import 'library_release.dart';
import 'movies.dart';
import 'music.dart';
import 'my_tv.dart';
import 'radio.dart';
import 'reviews.dart';
import 'series.dart';
import 'smart_search.dart';

class LibraryHubScreen extends StatelessWidget {
  const LibraryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final library = controller.library;
    final movies = library.where((m) => m.type.toLowerCase().contains('movie')).length;
    final shows = library.where((m) {
      final type = m.type.toLowerCase();
      return type.contains('tv') || type.contains('show') || type.contains('series');
    }).length;
    final music = library.where((m) {
      final type = m.type.toLowerCase();
      return type.contains('music') || type.contains('song') || type.contains('album') || type.contains('track');
    }).length;

    return _HubScaffold(
      title: 'Library',
      subtitle: 'Everything published to this account’s shared home-server library.',
      icon: Icons.video_library_rounded,
      children: [
        Row(
          children: [
            Expanded(child: _statCard(context, 'Media', '${library.length}', Icons.library_music_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _statCard(context, 'Movies', '$movies', Icons.movie_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _statCard(context, 'TV', '$shows', Icons.tv_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _statCard(context, 'Music', '$music', Icons.album_outlined)),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle('Browse your library'),
        _hubGrid(context, [
          _HubEntry('Movies', 'Movies in the account NAS library', Icons.movie_rounded,
              () => _push(context, const MoviesScreen())),
          _HubEntry('TV Shows', 'Series and episodes', Icons.tv_rounded,
              () => _push(context, const SeriesScreen())),
          _HubEntry('Music', 'Albums, artists and tracks', Icons.music_note_rounded,
              () => _push(context, const MusicScreen())),
          _HubEntry('Radio', 'Live and saved stations', Icons.radio_rounded,
              () => _push(context, const RadioScreen())),
          _HubEntry('Collections', 'Curated account collections', Icons.collections_bookmark_rounded,
              () => _push(context, const CollectionsPanel())),
          _HubEntry('My TV', 'Your television-focused library', Icons.live_tv_rounded,
              () => _push(context, const MyTvScreen())),
          _HubEntry('Favorites', 'Liked media and music', Icons.favorite_rounded,
              () => _push(context, const FavoritesScreen())),
          _HubEntry('Coming Soon', 'Scheduled library publications', Icons.schedule_rounded,
              () => _push(context, ComingSoonScreen(loader: controller.backendApi.getScheduledLibraryAdditions))),
        ]),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storage_rounded),
            title: const Text('Account-wide library storage'),
            subtitle: Text(
              'One physical copy lives on the account home NAS. ${controller.currentAccount?.profiles.length ?? 0} profiles share access while keeping their own progress, ratings and collections.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class DiscoverHubScreen extends StatelessWidget {
  const DiscoverHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _HubScaffold(
      title: 'Discover',
      subtitle: 'Find media, people, communities, reviews and everything else in the service.',
      icon: Icons.explore_rounded,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.search_rounded, size: 30),
            title: const Text('Universal Search', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('Search movies, TV, music and the growing social catalog.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _push(context, const SmartSearchScreen()),
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle('Explore'),
        _hubGrid(context, [
          _HubEntry('Movies', 'Browse your movie catalog', Icons.movie_rounded,
              () => _push(context, const MoviesScreen())),
          _HubEntry('TV Shows', 'Browse series and episodes', Icons.tv_rounded,
              () => _push(context, const SeriesScreen())),
          _HubEntry('Reviews', 'Read and publish reviews', Icons.rate_review_rounded,
              () => _push(context, const ReviewsHubScreen())),
          _HubEntry('People', 'Actors, directors and media credits', Icons.people_alt_rounded,
              () => _push(context, const LibraryActorsScreen())),
          _HubEntry('Music', 'Artists, albums and songs', Icons.music_note_rounded,
              () => _push(context, const MusicScreen())),
          _HubEntry('Radio', 'Discover live radio', Icons.radio_rounded,
              () => _push(context, const RadioScreen())),
        ]),
      ],
    );
  }
}

class FriendsAndCommunitiesScreen extends StatefulWidget {
  const FriendsAndCommunitiesScreen({super.key});

  @override
  State<FriendsAndCommunitiesScreen> createState() => _FriendsAndCommunitiesScreenState();
}

class _FriendsAndCommunitiesScreenState extends State<FriendsAndCommunitiesScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;
  bool busy = false;
  String communityQuery = '';
  late final TabController tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final controller = AppController.instance;
    final profile = controller.currentProfile;
    if (profile == null || !controller.backendApi.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Select a profile and sign in to use Friends and Communities.';
      });
      return;
    }

    try {
      final result = await controller.backendApi.getSocialHome(profileId: profile.id);
      if (!mounted) return;
      setState(() {
        data = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> _textDialog({required String title, required String label, String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _addFriend() async {
    final username = await _textDialog(title: 'Add a friend', label: '@username');
    if (username == null || username.trim().isEmpty) return;
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    await _act(() => AppController.instance.backendApi.sendFriendRequest(
          profileId: profile.id,
          username: username.trim().replaceFirst('@', ''),
        ));
  }

  Future<void> _createCommunity() async {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return;
    final name = await _textDialog(title: 'Create community', label: 'Community name');
    if (name == null || name.trim().isEmpty) return;
    final description = await _textDialog(title: 'Community description', label: 'Description') ?? '';
    await _act(() => AppController.instance.backendApi.createSocialCommunity(
          profileId: profile.id,
          name: name.trim(),
          description: description.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final friends = (data?['friends'] as List? ?? const []).whereType<Map>().toList();
    final requests = (data?['requests'] as List? ?? const []).whereType<Map>().toList();
    final suggestions = (data?['suggestions'] as List? ?? const []).whereType<Map>().toList();
    final communities = (data?['communities'] as List? ?? const []).whereType<Map>().toList();
    final query = communityQuery.trim().toLowerCase();
    final matchingCommunities = communities.where((community) {
      if (query.isEmpty) return true;
      return '${community['name'] ?? ''} ${community['description'] ?? ''}'.toLowerCase().contains(query);
    }).toList();
    final profile = AppController.instance.currentProfile;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: Row(
            children: [
              const Icon(Icons.people_rounded, size: 30),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Friends & Communities', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
              FilledButton.icon(onPressed: _addFriend, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add Friend')),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Card(child: ListTile(leading: const Icon(Icons.error_outline_rounded), title: const Text('Social services unavailable'), subtitle: Text(error!))),
          ),
        Material(
          color: Colors.transparent,
          child: TabBar(
            controller: tabs,
            tabs: [
              Tab(text: 'Friends (${friends.length})', icon: const Icon(Icons.people_outline_rounded)),
              Tab(text: 'Communities (${communities.length})', icon: const Icon(Icons.groups_rounded)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: tabs,
            children: [
              RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.alternate_email_rounded),
                        ),
                        title: const Text(
                          'Your username',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          _currentUsername(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        trailing: const Icon(Icons.info_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Friends', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    if (friends.isEmpty)
                      const Card(child: ListTile(leading: Icon(Icons.person_search_rounded), title: Text('No friends yet'), subtitle: Text('Use Add Friend and enter someone’s unique @username.'))),
                    for (final friend in friends) _friendCard(friend),
                    if (requests.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text('Friend requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      for (final request in requests) _requestCard(request),
                    ],
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text('People you may know', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      for (final suggestion in suggestions) _suggestionCard(suggestion),
                    ],
                  ],
                ),
              ),
              RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Discover Communities', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                        FilledButton.icon(onPressed: _createCommunity, icon: const Icon(Icons.add_rounded), label: const Text('Create')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (value) => setState(() => communityQuery = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search communities',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (matchingCommunities.isEmpty)
                      const Card(child: ListTile(leading: Icon(Icons.groups_rounded), title: Text('No communities found'), subtitle: Text('Create a community or search again.'))),
                    for (final community in matchingCommunities) _communityCard(community, profile?.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _currentUsername() {
    final username = AppController.instance.currentAccount?.username.trim() ?? '';
    return username.isEmpty ? 'Set a username during account setup' : '@$username';
  }

  String _initial(String value) {
    final clean = value.trim();
    return clean.isEmpty ? '?' : clean.substring(0, 1).toUpperCase();
  }

  Widget _friendCard(Map friend) {
    final username = friend['username']?.toString() ?? '';
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(_initial(friend['display_name']?.toString() ?? username))),
        title: Text(friend['display_name']?.toString() ?? 'Friend', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(username.isEmpty ? 'Friend' : '@$username'),
      ),
    );
  }

  Widget _requestCard(Map request) {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();
    final sender = request['sender'] as Map? ?? const {};
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_add_alt_1_rounded),
        title: Text(sender['display_name']?.toString() ?? sender['username']?.toString() ?? 'Someone'),
        subtitle: Text(sender['username'] == null ? 'Friend request' : '@${sender['username']}'),
        trailing: Wrap(
          children: [
            TextButton(onPressed: () => _act(() => AppController.instance.backendApi.respondFriendRequest(profileId: profile.id, friendshipId: request['id'].toString(), action: 'decline')), child: const Text('Decline')),
            FilledButton(onPressed: () => _act(() => AppController.instance.backendApi.respondFriendRequest(profileId: profile.id, friendshipId: request['id'].toString(), action: 'accept')), child: const Text('Accept')),
          ],
        ),
      ),
    );
  }

  Widget _suggestionCard(Map person) {
    final profile = AppController.instance.currentProfile;
    if (profile == null) return const SizedBox.shrink();
    final username = person['username']?.toString() ?? '';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_search_rounded),
        title: Text(person['display_name']?.toString() ?? username),
        subtitle: Text(username.isEmpty ? 'Suggested person' : '@$username'),
        trailing: username.isEmpty ? null : IconButton(
          tooltip: 'Add friend',
          onPressed: () => _act(() => AppController.instance.backendApi.sendFriendRequest(profileId: profile.id, username: username)),
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
      ),
    );
  }

  Widget _communityCard(Map community, String? profileId) {
    final id = community['id']?.toString() ?? '';
    final joined = community['joined'] == true;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.groups_rounded)),
        title: Text(community['name']?.toString() ?? 'Community', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(community['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: joined
            ? const Chip(label: Text('Joined'))
            : FilledButton(
                onPressed: profileId == null || id.isEmpty
                    ? null
                    : () => _act(() => AppController.instance.backendApi.joinSocialCommunity(profileId: profileId, communityId: id)),
                child: const Text('Join'),
              ),
      ),
    );
  }
}

class _HubScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _HubScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 38),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(subtitle, style: const TextStyle(color: Colors.white60, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}

class _HubEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _HubEntry(this.title, this.subtitle, this.icon, this.onTap);
}

Widget _hubGrid(BuildContext context, List<_HubEntry> entries) {
  final columns = MediaQuery.sizeOf(context).width >= 1050
      ? 4
      : MediaQuery.sizeOf(context).width >= 700
          ? 3
          : 2;

  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: entries.length,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.45,
    ),
    itemBuilder: (_, index) {
      final entry = entries[index];
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: entry.onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(entry.icon, size: 30),
                const SizedBox(height: 9),
                Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(entry.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _sectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
    );

void _push(BuildContext context, Widget page) {
  final pageId = switch (page) {
    MoviesScreen() => 'movies',
    SeriesScreen() => 'series',
    MusicScreen() => 'music',
    LibraryActorsScreen() => 'actors',
    RadioScreen() => 'radio',
    CollectionsPanel() => 'collections',
    MyTvScreen() => 'my-tv',
    FavoritesScreen() => 'favorites',
    ComingSoonScreen() => 'coming-soon',
    SmartSearchScreen() => 'search',
    ReviewsHubScreen() => 'reviews',
    _ => null,
  };
  Navigator.push(
    context,
    MaterialPageRoute(
      settings: pageId == null ? null : RouteSettings(name: '/app/page/$pageId'),
      builder: (_) => page,
    ),
  );
}
