import 'package:flutter/material.dart';

import 'app_core.dart';
import 'cinematic_universe_franchise_explorer.dart';
import 'cinematic_franchise_intelligence.dart';

/// Franchise and cinematic-universe browse pages backed by verified catalog metadata.
/// New titles are discovered through the intelligence/provider flow, rather than
/// maintaining a hard-coded filmography in this browse screen.
enum FranchiseUniverseBrowseMode { franchises, universes }

class FranchiseUniverseBrowseHubScreen extends StatelessWidget {
  const FranchiseUniverseBrowseHubScreen({
    super.key,
    required this.mode,
  });

  final FranchiseUniverseBrowseMode mode;

  @override
  Widget build(BuildContext context) {
    final works = UniverseFranchiseIndex.visibleWorks(
      AppController.instance.library,
    );
    final isFranchise = mode == FranchiseUniverseBrowseMode.franchises;
    final metadataGroups = UniverseFranchiseIndex.groups(
      works,
      kind: isFranchise ? 'Franchise' : 'Universe',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isFranchise ? 'Franchises' : 'Cinematic Universes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BrowseIntroCard(
            title: isFranchise ? 'Explore movie franchises' : 'Explore connected universes',
            description: isFranchise
                ? 'Browse franchise groups derived from catalog metadata. Use live intelligence to discover future titles without maintaining a movie-by-movie list.'
                : 'Explore universe groups derived from metadata, and use live discovery to keep upcoming titles current. Studio overlap alone is not treated as proof of shared continuity.',
            icon: isFranchise ? Icons.movie_filter_rounded : Icons.hub_rounded,
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Cinematic Universe Intelligence'),
              subtitle: const Text('Discover upcoming movies and shows from live metadata; no per-title filmography maintenance.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                builder: (_) => const CinematicFranchiseIntelligenceScreen(),
              )),
            ),
          ),
          const SizedBox(height: 18),
          _SectionHeading(isFranchise ? 'Catalog franchises' : 'Catalog universes'),
          const SizedBox(height: 8),
          ...metadataGroups.map((group) => _MetadataGroupTile(group: group)),
          if (metadataGroups.isEmpty)
            _EmptyHint(isFranchise
                ? 'No franchise metadata is attached to the accessible catalog yet. Open Cinematic Universe Intelligence to discover upcoming titles from the metadata provider.'
                : 'No universe metadata is attached to the accessible catalog yet. Open Cinematic Universe Intelligence to discover upcoming titles from the metadata provider.'),
          const SizedBox(height: 18),
          const Text(
            'Counts describe the current profile-accessible catalog, not the number of titles owned by every household member or guaranteed to be playable from an external provider.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MetadataGroupTile extends StatelessWidget {
  const _MetadataGroupTile({required this.group});
  final UniverseFranchiseGroup group;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(group.kind == 'Universe' ? Icons.hub_rounded : Icons.movie_filter_rounded),
      title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${group.works.length} catalog-linked title(s)'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => UniverseFranchiseDetailsScreen(group: group),
      )),
    ),
  );
}

class _BrowseIntroCard extends StatelessWidget {
  const _BrowseIntroCard({required this.title, required this.description, required this.icon});
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Colors.white70, height: 1.4)),
        ])),
      ]),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900));
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(message, style: const TextStyle(color: Colors.white54)),
  );
}
