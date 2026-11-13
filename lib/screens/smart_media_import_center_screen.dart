import 'package:flutter/material.dart';

import '../disc_ingestion_center.dart';
import '../media_health_screen.dart';
import '../media_metadata_catalog_screen.dart';
import '../personal_media_intelligence_center.dart';

/// Guided entry point to the app's existing physical-media intake and review
/// tools. It does not claim to scan arbitrary folders by itself.
class SmartMediaImportCenterScreen extends StatelessWidget {
  const SmartMediaImportCenterScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Smart Media Import Center')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Identify, review and organize new media', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Use the existing MakeMKV disc intake, metadata intelligence and TMDB catalog tools. Review uncertain matches before adding or changing library records.'),
                  const SizedBox(height: 12),
                  const Text('This center does not automatically scan every folder or bypass disc encryption. Import only media you are authorized to copy and access.'),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            _ImportAction(
              icon: Icons.album_rounded,
              title: 'Scan a DVD, Blu-ray or 4K disc',
              subtitle: 'Detect an optical drive, inspect titles and run the configured MakeMKV workflow.',
              onTap: () => _open(context, const DiscIngestionCenterScreen()),
            ),
            _ImportAction(
              icon: Icons.fact_check_outlined,
              title: 'Review metadata and import records',
              subtitle: 'Match disc mappings, preservation records and media metadata before approval.',
              onTap: () => _open(context, const PersonalMediaIntelligenceCenterScreen(initialTab: 1)),
            ),
            _ImportAction(
              icon: Icons.travel_explore_rounded,
              title: 'Search the global movie and TV catalog',
              subtitle: 'Use the configured TMDB-backed catalog to identify titles and metadata.',
              onTap: () => _open(context, const MediaMetadataCatalogScreen()),
            ),
            _ImportAction(
              icon: Icons.health_and_safety_outlined,
              title: 'Check library quality after import',
              subtitle: 'Find missing artwork, descriptions, streams and audio/subtitle metadata.',
              onTap: () => _open(context, const MediaHealthScreen()),
            ),
          ],
        ),
      );
}

class _ImportAction extends StatelessWidget {
  const _ImportAction({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
          isThreeLine: true,
        ),
      );
}
