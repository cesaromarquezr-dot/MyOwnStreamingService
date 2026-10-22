import 'package:flutter/material.dart';

/// Product capability status is a roadmap/integration aid, not a live health
/// probe. "Foundation exists" means the saved source has an entry point or
/// module; it does not imply security review, provider connectivity, or release
/// readiness.
enum CapabilityReadiness {
  foundationExists,
  verifyLocally,
  setupRequired,
  providerOrHardware,
  roadmap,
}

enum CapabilityPhase {
  stabilize,
  catalog,
  discovery,
  experience,
  platformSafety,
}

class PlatformCapability {
  final String id;
  final String title;
  final String area;
  final CapabilityPhase phase;
  final CapabilityReadiness readiness;
  final String summary;
  final String acceptanceCriteria;
  final List<String> dependencies;

  const PlatformCapability({
    required this.id,
    required this.title,
    required this.area,
    required this.phase,
    required this.readiness,
    required this.summary,
    required this.acceptanceCriteria,
    this.dependencies = const <String>[],
  });
}

class PlatformCapabilityCatalog {
  PlatformCapabilityCatalog._();

  static const List<PlatformCapability> all = <PlatformCapability>[
    PlatformCapability(
      id: 'baseline', title: 'Known-good build and regression baseline',
      area: 'Engineering', phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Run analyzer, focused tests, the full test suite, and supported builds against the exact working copy.',
      acceptanceCriteria: 'No unexplained analyzer errors; tests and build results are recorded; a known-good backup or commit exists.',
    ),
    PlatformCapability(
      id: 'account-auth', title: 'Account access, recovery, and sessions',
      area: 'Accounts', phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.foundationExists,
      summary: 'Login, signup, recovery, secure session storage, and session revocation have existing app/backend foundations.',
      acceptanceCriteria: 'Verify end-to-end signup, verification, recovery, expiration, logout, and revocation on the current deployment.',
    ),
    PlatformCapability(
      id: 'profiles-kids', title: 'Profile creation, Normal/Kids type, and governance',
      area: 'Profiles', phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'The product requires profile username entry at profile creation/editing—not account signup—and immediate Kids restrictions.',
      acceptanceCriteria: 'Profile type persists; profile usernames remain distinct from account authentication; restrictions are enforced server-side for every relevant request.',
      dependencies: <String>['profile API', 'governance schema', 'RLS/authorization tests'],
    ),
    PlatformCapability(
      id: 'server-selection', title: 'Server selection and home-server connection',
      area: 'Self-hosting', phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Server selection works in explicit local mock mode; distinguish simulated servers from real server provisioning.',
      acceptanceCriteria: 'Local mock setting is opt-in; real deployments do not expose seeded fake servers; connection failures are actionable.',
    ),
    PlatformCapability(
      id: 'navigation', title: 'One consistent navigation and shared widgets',
      area: 'Engineering', phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Keep Home, Watch, Friends, and More as the stable top-level destinations; avoid duplicate destinations and parallel screen implementations.',
      acceptanceCriteria: 'Core journeys preserve active profile and return navigation; shared widgets have one canonical implementation.',
    ),
    PlatformCapability(
      id: 'catalog-identities', title: 'Canonical identities for works, editions, seasons, and people',
      area: 'Catalog', phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Use stable IDs to connect alternate editions and related credits without duplicating the underlying work.',
      acceptanceCriteria: 'A re-release has its own edition identity and metadata while sharing canonicalWorkId with the original work.',
    ),
    PlatformCapability(
      id: 'series-years', title: 'Series run years and season dates',
      area: 'Catalog', phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Completed series show first–last original release years; ongoing series show first year–Present; season dates derive from verified episode metadata.',
      acceptanceCriteria: 'Home hero, cards, details, and search use the same formatter; unknown dates remain unknown instead of being guessed.',
    ),
    PlatformCapability(
      id: 'movie-editions', title: 'Movie editions and edition-aware playback history',
      area: 'Catalog', phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Theatrical, extended, director-approved, and other verified editions remain connected to one canonical work.',
      acceptanceCriteria: 'Runtime, release year, extras, playback progress, Continue Watching, and ending/scene information remain edition-aware.',
    ),
    PlatformCapability(
      id: 'regional-versions', title: 'International versions and scene localization',
      area: 'Catalog', phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.roadmap,
      summary: 'Track regional masters, alternate visuals/text, and compatible audio/subtitle tracks separately from movie editions.',
      acceptanceCriteria: 'Only verified, authorized assets are selectable; regional choice does not bypass territory rights; versions do not duplicate movie search results.',
      dependencies: <String>['authorized regional assets', 'version compatibility metadata', 'server-side playback authorization'],
    ),
    PlatformCapability(
      id: 'people-credits', title: 'People & Credits filmography and discography',
      area: 'Catalog', phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Find a person’s movies, shows, songs, albums, voice roles, and collaborations through a unified identity.',
      acceptanceCriteria: 'Search such as "actor movies and songs" returns only records with matching registered credits and respects access rules.',
    ),
    PlatformCapability(
      id: 'company-credits', title: 'Multiple company credits and company pages',
      area: 'Catalog', phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Represent production, distributor, studio/label, and rights-holder relationships independently.',
      acceptanceCriteria: 'A production credit never implies ownership; every credit can retain source, territory, and verification provenance.',
    ),
    PlatformCapability(
      id: 'metadata-quality', title: 'Media Data Quality Center',
      area: 'Catalog', phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.roadmap,
      summary: 'Detect duplicates, missing metadata, conflicting genres, wrong artwork, and mismatched artist/title data.',
      acceptanceCriteria: 'Corrections are reviewable, provenance is retained, and automated scans never silently overwrite trusted metadata.',
    ),
    PlatformCapability(
      id: 'hybrid-genres', title: 'Hybrid film genres and music genre crossovers',
      area: 'Catalog', phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Store canonical genres and derive useful blends such as Horror-Comedy, Romantic Thriller, Country Rap, or Rap Rock.',
      acceptanceCriteria: 'All/any filter modes are clear; generated blend labels never replace source genre metadata.',
    ),
    PlatformCapability(
      id: 'cinematic-titles', title: 'Cinematic title logos and responsive fallback',
      area: 'Cinematic UI', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Use authorized title-logo artwork when available, otherwise a readable styled text treatment; respect reduced motion.',
      acceptanceCriteria: 'No forced Arial 12; logos do not stretch; metadata remains readable; screen readers receive the title as text.',
    ),
    PlatformCapability(
      id: 'adaptive-home', title: 'Personalized Home and explainable recommendations',
      area: 'Discovery', phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.foundationExists,
      summary: 'Separate recommendations by profile and media type, use hybrid genres and activity, and explain why an item was suggested.',
      acceptanceCriteria: 'Users can tune feedback; finishing a title alone does not imply that they liked it.',
    ),
    PlatformCapability(
      id: 'universal-search', title: 'Universal Search and People & Credits queries',
      area: 'Discovery', phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.foundationExists,
      summary: 'Search movies, shows, episodes, people, companies, songs, artists, collections, communities, and products where supported.',
      acceptanceCriteria: 'Category filters and back navigation preserve query state; results point to authorized and accessible items only.',
    ),
    PlatformCapability(
      id: 'availability-radar', title: 'My Availability Radar',
      area: 'Discovery', phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.providerOrHardware,
      summary: 'Show in-library, physical ownership, connected services, rent/buy, upcoming removal, unavailable, and unknown states distinctly.',
      acceptanceCriteria: 'Every provider claim has a source, territory, and checked-at time; unknown is never shown as available.',
      dependencies: <String>['licensed provider/catalog integrations', 'region and freshness rules'],
    ),
    PlatformCapability(
      id: 'taste-tuner', title: 'Taste Tuner and Mood Mixer',
      area: 'Discovery', phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.roadmap,
      summary: 'Tune genre blends, intensity, tone, runtime, familiarity, content exclusions, and desired surprises.',
      acceptanceCriteria: 'Explicit feedback is distinct from completion; Kids and account privacy controls apply.',
    ),
    PlatformCapability(
      id: 'franchise-xray', title: 'Franchise Navigator and spoiler-safe X-Ray',
      area: 'Discovery', phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.foundationExists,
      summary: 'Connect characters, actors, franchises, continuities, watch orders, scene information, and soundtracks.',
      acceptanceCriteria: 'Separate continuities stay separate; spoilers respect user progress and manual watched-state corrections.',
    ),
    PlatformCapability(
      id: 'hey-media-ai', title: 'Hey Media AI Concierge and safe actions',
      area: 'Discovery', phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.foundationExists,
      summary: 'Natural-language discovery and controlled actions use profile-scoped catalog access and backend authorization.',
      acceptanceCriteria: 'AI cannot bypass permissions, reveal another profile’s private data, or perform sensitive actions without required confirmation.',
    ),
    PlatformCapability(
      id: 'smart-queue', title: 'My Next Up Queue and Smart Double Feature',
      area: 'Discovery', phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.roadmap,
      summary: 'Combine movies, episodes, and music into a re-orderable queue with runtime-aware planning.',
      acceptanceCriteria: 'Queue actions preserve the original watchlist and only include available/authorized playback items.',
    ),
    PlatformCapability(
      id: 'watch-playback', title: 'Watch player, progress sync, and accessibility',
      area: 'Playback', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.foundationExists,
      summary: 'Resume, audio/subtitle selection, playback diagnostics, captions, and reduced motion where supported.',
      acceptanceCriteria: 'Resume includes exact edition/version and track preferences; unsupported player controls are not shown as working.',
    ),
    PlatformCapability(
      id: 'live-tv-dvr', title: 'My TV, guide, and DVR features',
      area: 'Playback', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.providerOrHardware,
      summary: 'Guide data, tuner/provider integration, live pause/restart, recording, and conflict handling.',
      acceptanceCriteria: 'Controls appear only when the attached source supports the operation.',
      dependencies: <String>['compatible tuner/provider', 'licensed guide data', 'storage and recording permissions'],
    ),
    PlatformCapability(
      id: 'internationalization', title: 'Language, audio, captions, and regional preferences',
      area: 'Playback', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Profile preferences apply to compatible tracks while keeping the actual tracks available for the selected edition/version.',
      acceptanceCriteria: 'The UI lists only verified available audio, subtitle, caption, and audio-description tracks.',
    ),
    PlatformCapability(
      id: 'offline-travel', title: 'Travel Mode and Smart Downloads',
      area: 'Playback', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.providerOrHardware,
      summary: 'Prepare supported offline media, artwork, metadata, track preferences, and progress sync when back online.',
      acceptanceCriteria: 'Only licensed downloadable content is offered; expiry, storage, encryption, and sync conflicts are handled.',
      dependencies: <String>['source-specific download permission', 'secure local storage', 'expiry handling'],
    ),
    PlatformCapability(
      id: 'watch-party', title: 'Watch Together and synchronized sessions',
      area: 'Social', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.providerOrHardware,
      summary: 'Private rooms, invitations, synchronized controls, reactions, and spoiler-safe chat.',
      acceptanceCriteria: 'Playback sync has reconnect handling; all participants have compatible access; external providers are not represented as controllable without integration.',
      dependencies: <String>['real-time session service', 'compatible player/source', 'moderation and consent controls'],
    ),
    PlatformCapability(
      id: 'social-communities', title: 'Friends, communities, feed, and shared collections',
      area: 'Social', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.foundationExists,
      summary: 'Connect posts, discussions, recommendations, collaborative lists, and community events to media records.',
      acceptanceCriteria: 'Visibility, block/report, spoiler, and moderation rules are enforced by the backend.',
    ),
    PlatformCapability(
      id: 'music-soundtracks', title: 'Music, albums, artists, and soundtrack graph',
      area: 'Music', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.foundationExists,
      summary: 'Connect songs and albums to artists, collaborators, movie/show soundtracks, and listening history.',
      acceptanceCriteria: 'Credits are source-backed; lyrics and media playback only appear where authorized.',
    ),
    PlatformCapability(
      id: 'wrapped', title: 'Monthly/yearly My Entertainment Wrapped',
      area: 'Personalization', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Provide per-profile recaps, combined-account summaries with privacy rules, and stable archived snapshots.',
      acceptanceCriteria: 'Correct period boundaries, deduplicated activity, clear ranking rules, and opt-in sharing.',
    ),
    PlatformCapability(
      id: 'marketplace', title: 'Shared Marketplace, Shop, and Food Delivery',
      area: 'Commerce', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.providerOrHardware,
      summary: 'Shared discovery can connect products and restaurants while keeping retail and food checkout/fulfillment separate.',
      acceptanceCriteria: 'Orders and addresses are private; payments use a supported processor; provider setup and order status are truthful.',
      dependencies: <String>['payment processor', 'merchant/order provider', 'secure address handling'],
    ),
    PlatformCapability(
      id: 'media-night', title: 'My Media Night planner',
      area: 'Cross-feature experiences', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.roadmap,
      summary: 'Coordinate a movie, mood, playlist, friends’ vote, runtime, and optional food suggestions in one flow.',
      acceptanceCriteria: 'Each suggestion links to a real feature/provider and purchase or outbound invitation needs explicit confirmation.',
    ),
    PlatformCapability(
      id: 'vault-import', title: 'Entertainment Vault and physical-media import',
      area: 'Library', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.foundationExists,
      summary: 'Manage local catalog and supported physical-media workflows while preserving editions and metadata provenance.',
      acceptanceCriteria: 'Duplicate detection distinguishes alternate edition, regional version, better-quality file, and actual duplicate.',
    ),
    PlatformCapability(
      id: 'security', title: 'Security, privacy, and least-privilege access',
      area: 'Platform safety', phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Verify server authz, profile ownership, session protection, rate limits, private media access, and secret handling.',
      acceptanceCriteria: 'Negative authorization tests pass; service-role keys stay server-side; production origins are explicitly allowlisted.',
    ),
    PlatformCapability(
      id: 'waf-proxy', title: 'Trusted reverse proxy and optional WAF',
      area: 'Platform safety', phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary: 'Expose only intentional public entry points; keep database and raw AI/model ports private.',
      acceptanceCriteria: 'TLS, forwarded-header trust, proxy authentication, firewall rules, and WAF policy are reviewed on the real deployment.',
      dependencies: <String>['deployment-specific network diagram', 'TLS and DNS', 'proxy/WAF configuration'],
    ),
    PlatformCapability(
      id: 'database-rls', title: 'Supabase RLS and data-isolation audit',
      area: 'Platform safety', phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary: 'Audit actual tables, RLS enablement, policies, storage rules, role grants, and profile/account scoping.',
      acceptanceCriteria: 'Every finding is reviewed against real policies and authorization tests before changes are applied.',
      dependencies: <String>['staging database', 'policy review', 'cross-account negative tests'],
    ),
    PlatformCapability(
      id: 'monitoring-recovery', title: 'Security monitoring, backups, and recovery drills',
      area: 'Platform safety', phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary: 'Keep redacted security logs, alert on anomalies, scan dependencies/secrets, and maintain encrypted backups.',
      acceptanceCriteria: 'Alerts reach an owner, backups are encrypted, and a restore drill is documented and successful.',
      dependencies: <String>['centralized logs', 'alert destination', 'backup storage', 'restore runbook'],
    ),
    PlatformCapability(
      id: 'streaming-performance', title: 'High-speed local and remote playback',
      area: 'Playback and performance', phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Prefer Direct Play when supported, use hardware-accelerated transcoding for incompatible clients, cache disposable transcodes on fast storage, and measure startup, buffering, and concurrency.',
      acceptanceCriteria: 'Record playback-start latency, buffering ratio, transcode queue wait, and simultaneous-stream tests on the actual server; never report a speed target as achieved without measurements.',
      dependencies: <String>['server CPU/GPU and hardware acceleration', 'upload/download bandwidth', 'compatible codecs/containers', 'QoE measurements'],
    ),
    PlatformCapability(
      id: 'drive-failure-resilience', title: 'Drive-failure tolerance and independent recovery',
      area: 'Storage and reliability', phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary: 'Use a redundant storage layout selected for the drive count and workload, read-only health monitoring, integrity checks, replacement/rebuild procedures, and independent backups.',
      acceptanceCriteria: 'Document the actual pool layout and failure tolerance; alert on degraded pools and SMART errors; verify backup independence; complete an isolated restore and a rehearsed drive-failure recovery without risking the only copy.',
      dependencies: <String>['compatible NAS/RAID/ZFS/Storage Spaces hardware', 'spare/replacement drive plan', 'independent backup target', 'restore drill', 'UPS and graceful shutdown'],
    ),
    PlatformCapability(
      id: 'household-multi-profile-access', title: 'Household profiles and concurrent use',
      area: 'Accounts and household', phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.verifyLocally,
      summary: 'Allow household members to use the same managed server while keeping each profile’s history, favorites, recommendations, restrictions, and private activity appropriately isolated.',
      acceptanceCriteria: 'Run concurrent playback with multiple accounts/profiles; prove cross-profile and cross-account API requests cannot read private history or bypass Kids restrictions; validate device/session revocation.',
      dependencies: <String>['authenticated profile ownership', 'server-side authorization', 'account/profile isolation tests', 'concurrency test media'],
    ),
    PlatformCapability(
      id: 'secure-worldwide-access', title: 'Secure worldwide access to owned media',
      area: 'Remote access', phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary: 'Expose only an authenticated HTTPS gateway or approved private access path; keep the database, NAS UI, storage shares, and raw backend port private.',
      acceptanceCriteria: 'Verify from an external network with valid and invalid sessions; confirm TLS, exact allowed origins, rate limits, short-lived media authorization, DNS/certificate renewal, and that internal ports are not publicly reachable.',
      dependencies: <String>['public upload bandwidth', 'DNS/DDNS', 'HTTPS reverse proxy or approved VPN', 'firewall rules', 'account auth and short-lived media URLs'],
    ),
    PlatformCapability(
      id: 'capability-checks', title: 'Capability and integration registry',
      area: 'Engineering', phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.foundationExists,
      summary: 'Maintain an explicit register of existing foundations, local verification needs, configuration, external dependencies, and roadmap work.',
      acceptanceCriteria: 'Status is not described as live health; changes to readiness are reviewed and evidence-backed.',
    ),
  ];
}

extension CapabilityReadinessPresentation on CapabilityReadiness {
  String get label => switch (this) {
        CapabilityReadiness.foundationExists => 'Foundation exists',
        CapabilityReadiness.verifyLocally => 'Verify locally',
        CapabilityReadiness.setupRequired => 'Setup required',
        CapabilityReadiness.providerOrHardware => 'Provider / hardware',
        CapabilityReadiness.roadmap => 'Roadmap',
      };

  Color colorFor(BuildContext context) => switch (this) {
        CapabilityReadiness.foundationExists => Colors.teal,
        CapabilityReadiness.verifyLocally => Colors.amber.shade800,
        CapabilityReadiness.setupRequired => Colors.deepOrange,
        CapabilityReadiness.providerOrHardware => Colors.blueGrey,
        CapabilityReadiness.roadmap => Theme.of(context).colorScheme.secondary,
      };
}

extension CapabilityPhasePresentation on CapabilityPhase {
  String get label => switch (this) {
        CapabilityPhase.stabilize => '1. Stabilize',
        CapabilityPhase.catalog => '2. Shared catalog',
        CapabilityPhase.discovery => '3. Discovery',
        CapabilityPhase.experience => '4. Connected experiences',
        CapabilityPhase.platformSafety => '5. Platform safety',
      };
}

/// Integration status page reachable from Innovation & Platform Hub.
/// This is an authored readiness register, not runtime telemetry.
class PlatformCapabilityRegistryScreen extends StatefulWidget {
  const PlatformCapabilityRegistryScreen({super.key});

  @override
  State<PlatformCapabilityRegistryScreen> createState() =>
      _PlatformCapabilityRegistryScreenState();
}

class _PlatformCapabilityRegistryScreenState
    extends State<PlatformCapabilityRegistryScreen> {
  String _query = '';
  CapabilityPhase? _phase;
  CapabilityReadiness? _readiness;

  List<PlatformCapability> get _visibleCapabilities {
    final query = _query.trim().toLowerCase();
    return PlatformCapabilityCatalog.all.where((item) {
      if (_phase != null && item.phase != _phase) return false;
      if (_readiness != null && item.readiness != _readiness) return false;
      if (query.isEmpty) return true;
      final haystack = <String>[
        item.title,
        item.area,
        item.summary,
        item.acceptanceCriteria,
        ...item.dependencies,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleCapabilities;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capability Registry & Roadmap'),
        actions: [
          IconButton(
            tooltip: 'Clear filters',
            onPressed: () => setState(() {
              _query = '';
              _phase = null;
              _readiness = null;
            }),
            icon: const Icon(Icons.filter_alt_off_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Text(
              'One roadmap for the connected product. Statuses describe the saved source snapshot and known integration needs; they are not live health checks, security audit results, or proof that a provider is configured.',
              style: TextStyle(height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const ValueKey<String>('capability-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search features, dependencies, or acceptance criteria',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          _filterRow<CapabilityPhase>(
            label: 'Phase',
            values: CapabilityPhase.values,
            selected: _phase,
            textFor: (value) => value.label,
            onSelected: (value) => setState(() {
              _phase = _phase == value ? null : value;
            }),
          ),
          _filterRow<CapabilityReadiness>(
            label: 'Status',
            values: CapabilityReadiness.values,
            selected: _readiness,
            textFor: (value) => value.label,
            onSelected: (value) => setState(() {
              _readiness = _readiness == value ? null : value;
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Text('${visible.length} of ${PlatformCapabilityCatalog.all.length} capabilities'),
                const Spacer(),
                if (_phase != null || _readiness != null || _query.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      _query = '';
                      _phase = null;
                      _readiness = null;
                    }),
                    child: const Text('Reset'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('No capabilities match these filters.'))
                : ListView.builder(
                    key: const ValueKey<String>('capability-list'),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: visible.length,
                    itemBuilder: (context, index) => _CapabilityTile(
                      key: ValueKey<String>(visible[index].id),
                      capability: visible[index],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow<T>({
    required String label,
    required List<T> values,
    required T? selected,
    required String Function(T) textFor,
    required ValueChanged<T> onSelected,
  }) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: selected == null,
                  onSelected: (_) => setState(() {
                    if (label == 'Phase') _phase = null;
                    if (label == 'Status') _readiness = null;
                  }),
                ),
                const SizedBox(width: 6),
                for (final value in values) ...[
                  ChoiceChip(
                    label: Text(textFor(value)),
                    selected: selected == value,
                    onSelected: (_) => onSelected(value),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  final PlatformCapability capability;

  const _CapabilityTile({super.key, required this.capability});

  @override
  Widget build(BuildContext context) {
    final color = capability.readiness.colorFor(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(_iconFor(capability.area)),
        ),
        title: Text(capability.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              _StatusLabel(label: capability.readiness.label, color: color),
              _StatusLabel(label: capability.phase.label, color: Theme.of(context).colorScheme.outline),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(capability.summary),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Acceptance criteria', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(capability.acceptanceCriteria),
          ),
          if (capability.dependencies.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Dependencies', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: capability.dependencies.map((item) => Chip(label: Text(item))).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String area) => switch (area) {
        'Engineering' => Icons.build_circle_outlined,
        'Accounts' || 'Profiles' => Icons.person_outline_rounded,
        'Self-hosting' => Icons.dns_outlined,
        'Catalog' => Icons.movie_filter_outlined,
        'Cinematic UI' => Icons.theaters_outlined,
        'Discovery' => Icons.explore_outlined,
        'Playback' => Icons.play_circle_outline_rounded,
        'Social' => Icons.people_outline_rounded,
        'Music' => Icons.music_note_outlined,
        'Personalization' => Icons.auto_awesome_outlined,
        'Commerce' => Icons.shopping_bag_outlined,
        'Cross-feature experiences' => Icons.hub_outlined,
        'Library' => Icons.video_library_outlined,
        'Platform safety' => Icons.shield_outlined,
        _ => Icons.extension_outlined,
      };
}

class _StatusLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );
}
