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
      id: 'baseline',
      title: 'Known-good build and regression baseline',
      area: 'Engineering',
      phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Run analyzer, focused tests, the full test suite, and supported builds against the exact working copy.',
      acceptanceCriteria:
          'No unexplained analyzer errors; tests and build results are recorded; a known-good backup or commit exists.',
    ),
    PlatformCapability(
      id: 'account-auth',
      title: 'Account access, recovery, and sessions',
      area: 'Accounts',
      phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.foundationExists,
      summary:
          'Login, signup, recovery, secure session storage, and session revocation have existing app/backend foundations.',
      acceptanceCriteria:
          'Verify end-to-end signup, verification, recovery, expiration, logout, and revocation on the current deployment.',
    ),
    PlatformCapability(
      id: 'profiles-kids',
      title: 'Profile creation, Normal/Kids type, and governance',
      area: 'Profiles',
      phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'The product requires profile username entry at profile creation/editing—not account signup—and immediate Kids restrictions.',
      acceptanceCriteria:
          'Profile type persists; profile usernames remain distinct from account authentication; restrictions are enforced server-side for every relevant request.',
      dependencies: <String>[
        'profile API',
        'governance schema',
        'RLS/authorization tests'
      ],
    ),
    PlatformCapability(
      id: 'server-selection',
      title: 'Server selection and home-server connection',
      area: 'Self-hosting',
      phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Server selection works in explicit local mock mode; distinguish simulated servers from real server provisioning.',
      acceptanceCriteria:
          'Local mock setting is opt-in; real deployments do not expose seeded fake servers; connection failures are actionable.',
    ),
    PlatformCapability(
      id: 'navigation',
      title: 'One consistent navigation and shared widgets',
      area: 'Engineering',
      phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Keep Home, Watch, Friends, and More as the stable top-level destinations; avoid duplicate destinations and parallel screen implementations.',
      acceptanceCriteria:
          'Core journeys preserve active profile and return navigation; shared widgets have one canonical implementation.',
    ),
    PlatformCapability(
      id: 'catalog-identities',
      title: 'Canonical identities for works, editions, seasons, and people',
      area: 'Catalog',
      phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Use stable IDs to connect alternate editions and related credits without duplicating the underlying work.',
      acceptanceCriteria:
          'A re-release has its own edition identity and metadata while sharing canonicalWorkId with the original work.',
    ),
    PlatformCapability(
      id: 'series-years',
      title: 'Series run years and season dates',
      area: 'Catalog',
      phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Completed series show first–last original release years; ongoing series show first year–Present; season dates derive from verified episode metadata.',
      acceptanceCriteria:
          'Home hero, cards, details, and search use the same formatter; unknown dates remain unknown instead of being guessed.',
    ),
    PlatformCapability(
      id: 'movie-editions',
      title: 'Movie editions and edition-aware playback history',
      area: 'Catalog',
      phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Theatrical, extended, director-approved, and other verified editions remain connected to one canonical work.',
      acceptanceCriteria:
          'Runtime, release year, extras, playback progress, Continue Watching, and ending/scene information remain edition-aware.',
    ),
    PlatformCapability(
      id: 'regional-versions',
      title: 'International versions and scene localization',
      area: 'Catalog',
      phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.roadmap,
      summary:
          'Track regional masters, alternate visuals/text, and compatible audio/subtitle tracks separately from movie editions.',
      acceptanceCriteria:
          'Only verified, authorized assets are selectable; regional choice does not bypass territory rights; versions do not duplicate movie search results.',
      dependencies: <String>[
        'authorized regional assets',
        'version compatibility metadata',
        'server-side playback authorization'
      ],
    ),
    PlatformCapability(
      id: 'people-credits',
      title: 'People & Credits filmography and discography',
      area: 'Catalog',
      phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Find a person’s movies, shows, songs, albums, voice roles, and collaborations through a unified identity.',
      acceptanceCriteria:
          'Search such as "actor movies and songs" returns only records with matching registered credits and respects access rules.',
    ),
    PlatformCapability(
      id: 'company-credits',
      title: 'Multiple company credits and company pages',
      area: 'Catalog',
      phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Represent production, distributor, studio/label, and rights-holder relationships independently.',
      acceptanceCriteria:
          'A production credit never implies ownership; every credit can retain source, territory, and verification provenance.',
    ),
    PlatformCapability(
      id: 'metadata-quality',
      title: 'Media Data Quality Center',
      area: 'Catalog',
      phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.roadmap,
      summary:
          'Detect duplicates, missing metadata, conflicting genres, wrong artwork, and mismatched artist/title data.',
      acceptanceCriteria:
          'Corrections are reviewable, provenance is retained, and automated scans never silently overwrite trusted metadata.',
    ),
    PlatformCapability(
      id: 'hybrid-genres',
      title: 'Hybrid film genres and music genre crossovers',
      area: 'Catalog',
      phase: CapabilityPhase.catalog,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Store canonical genres and derive useful blends such as Horror-Comedy, Romantic Thriller, Country Rap, or Rap Rock.',
      acceptanceCriteria:
          'All/any filter modes are clear; generated blend labels never replace source genre metadata.',
    ),
    PlatformCapability(
      id: 'cinematic-titles',
      title: 'Cinematic title logos and responsive fallback',
      area: 'Cinematic UI',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Use authorized title-logo artwork when available, otherwise a readable styled text treatment; respect reduced motion.',
      acceptanceCriteria:
          'No forced Arial 12; logos do not stretch; metadata remains readable; screen readers receive the title as text.',
    ),
    PlatformCapability(
      id: 'adaptive-home',
      title: 'Personalized Home and explainable recommendations',
      area: 'Discovery',
      phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.foundationExists,
      summary:
          'Separate recommendations by profile and media type, use hybrid genres and activity, and explain why an item was suggested.',
      acceptanceCriteria:
          'Users can tune feedback; finishing a title alone does not imply that they liked it.',
    ),
    PlatformCapability(
      id: 'universal-search',
      title: 'Universal Search and People & Credits queries',
      area: 'Discovery',
      phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.foundationExists,
      summary:
          'Search movies, shows, episodes, people, companies, songs, artists, collections, communities, and products where supported.',
      acceptanceCriteria:
          'Category filters and back navigation preserve query state; results point to authorized and accessible items only.',
    ),
    PlatformCapability(
      id: 'availability-radar',
      title: 'My Availability Radar',
      area: 'Discovery',
      phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.providerOrHardware,
      summary:
          'Show in-library, physical ownership, connected services, rent/buy, upcoming removal, unavailable, and unknown states distinctly.',
      acceptanceCriteria:
          'Every provider claim has a source, territory, and checked-at time; unknown is never shown as available.',
      dependencies: <String>[
        'licensed provider/catalog integrations',
        'region and freshness rules'
      ],
    ),
    PlatformCapability(
      id: 'taste-tuner',
      title: 'Taste Tuner and Mood Mixer',
      area: 'Discovery',
      phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.roadmap,
      summary:
          'Tune genre blends, intensity, tone, runtime, familiarity, content exclusions, and desired surprises.',
      acceptanceCriteria:
          'Explicit feedback is distinct from completion; Kids and account privacy controls apply.',
    ),
    PlatformCapability(
      id: 'franchise-xray',
      title: 'Franchise Navigator and spoiler-safe X-Ray',
      area: 'Discovery',
      phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.foundationExists,
      summary:
          'Connect characters, actors, franchises, continuities, watch orders, scene information, and soundtracks.',
      acceptanceCriteria:
          'Separate continuities stay separate; spoilers respect user progress and manual watched-state corrections.',
    ),
    PlatformCapability(
      id: 'hey-media-ai',
      title: 'Hey Media AI Concierge and safe actions',
      area: 'Discovery',
      phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.foundationExists,
      summary:
          'Natural-language discovery and controlled actions use profile-scoped catalog access and backend authorization.',
      acceptanceCriteria:
          'AI cannot bypass permissions, reveal another profile’s private data, or perform sensitive actions without required confirmation.',
    ),
    PlatformCapability(
      id: 'smart-queue',
      title: 'My Next Up Queue and Smart Double Feature',
      area: 'Discovery',
      phase: CapabilityPhase.discovery,
      readiness: CapabilityReadiness.roadmap,
      summary:
          'Combine movies, episodes, and music into a re-orderable queue with runtime-aware planning.',
      acceptanceCriteria:
          'Queue actions preserve the original watchlist and only include available/authorized playback items.',
    ),
    PlatformCapability(
      id: 'watch-playback',
      title: 'Watch player, progress sync, and accessibility',
      area: 'Playback',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.foundationExists,
      summary:
          'Resume, audio/subtitle selection, playback diagnostics, captions, and reduced motion where supported.',
      acceptanceCriteria:
          'Resume includes exact edition/version and track preferences; unsupported player controls are not shown as working.',
    ),
    PlatformCapability(
      id: 'live-tv-dvr',
      title: 'My TV, guide, and DVR features',
      area: 'Playback',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.providerOrHardware,
      summary:
          'Guide data, tuner/provider integration, live pause/restart, recording, and conflict handling.',
      acceptanceCriteria:
          'Controls appear only when the attached source supports the operation.',
      dependencies: <String>[
        'compatible tuner/provider',
        'licensed guide data',
        'storage and recording permissions'
      ],
    ),
    PlatformCapability(
      id: 'internationalization',
      title: 'Language, audio, captions, and regional preferences',
      area: 'Playback',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Profile preferences apply to compatible tracks while keeping the actual tracks available for the selected edition/version.',
      acceptanceCriteria:
          'The UI lists only verified available audio, subtitle, caption, and audio-description tracks.',
    ),
    PlatformCapability(
      id: 'offline-travel',
      title: 'Travel Mode and Smart Downloads',
      area: 'Playback',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.providerOrHardware,
      summary:
          'Prepare supported offline media, artwork, metadata, track preferences, and progress sync when back online.',
      acceptanceCriteria:
          'Only licensed downloadable content is offered; expiry, storage, encryption, and sync conflicts are handled.',
      dependencies: <String>[
        'source-specific download permission',
        'secure local storage',
        'expiry handling'
      ],
    ),
    PlatformCapability(
      id: 'watch-party',
      title: 'Watch Together and synchronized sessions',
      area: 'Social',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.providerOrHardware,
      summary:
          'Private rooms, invitations, synchronized controls, reactions, and spoiler-safe chat.',
      acceptanceCriteria:
          'Playback sync has reconnect handling; all participants have compatible access; external providers are not represented as controllable without integration.',
      dependencies: <String>[
        'real-time session service',
        'compatible player/source',
        'moderation and consent controls'
      ],
    ),
    PlatformCapability(
      id: 'social-communities',
      title: 'Friends, communities, feed, and shared collections',
      area: 'Social',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.foundationExists,
      summary:
          'Connect posts, discussions, recommendations, collaborative lists, and community events to media records.',
      acceptanceCriteria:
          'Visibility, block/report, spoiler, and moderation rules are enforced by the backend.',
    ),
    PlatformCapability(
      id: 'music-soundtracks',
      title: 'Music, albums, artists, and soundtrack graph',
      area: 'Music',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.foundationExists,
      summary:
          'Connect songs and albums to artists, collaborators, movie/show soundtracks, and listening history.',
      acceptanceCriteria:
          'Credits are source-backed; lyrics and media playback only appear where authorized.',
    ),
    PlatformCapability(
      id: 'wrapped',
      title: 'Monthly/yearly My Entertainment Wrapped',
      area: 'Personalization',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Provide per-profile recaps, combined-account summaries with privacy rules, and stable archived snapshots.',
      acceptanceCriteria:
          'Correct period boundaries, deduplicated activity, clear ranking rules, and opt-in sharing.',
    ),
    PlatformCapability(
      id: 'marketplace',
      title: 'Shared Marketplace, Shop, and Food Delivery',
      area: 'Commerce',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.providerOrHardware,
      summary:
          'Shared discovery can connect products and restaurants while keeping retail and food checkout/fulfillment separate.',
      acceptanceCriteria:
          'Orders and addresses are private; payments use a supported processor; provider setup and order status are truthful.',
      dependencies: <String>[
        'payment processor',
        'merchant/order provider',
        'secure address handling'
      ],
    ),
    PlatformCapability(
      id: 'media-night',
      title: 'My Media Night planner',
      area: 'Cross-feature experiences',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.roadmap,
      summary:
          'Coordinate a movie, mood, playlist, friends’ vote, runtime, and optional food suggestions in one flow.',
      acceptanceCriteria:
          'Each suggestion links to a real feature/provider and purchase or outbound invitation needs explicit confirmation.',
    ),
    PlatformCapability(
      id: 'vault-import',
      title: 'Entertainment Vault and physical-media import',
      area: 'Library',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.foundationExists,
      summary:
          'Manage local catalog and supported physical-media workflows while preserving editions and metadata provenance.',
      acceptanceCriteria:
          'Duplicate detection distinguishes alternate edition, regional version, better-quality file, and actual duplicate.',
    ),
    PlatformCapability(
      id: 'security',
      title: 'Security, privacy, and least-privilege access',
      area: 'Platform safety',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Verify server authz, profile ownership, session protection, rate limits, private media access, and secret handling.',
      acceptanceCriteria:
          'Negative authorization tests pass; service-role keys stay server-side; production origins are explicitly allowlisted.',
    ),
    PlatformCapability(
      id: 'waf-proxy',
      title: 'Trusted reverse proxy and optional WAF',
      area: 'Platform safety',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary:
          'Expose only intentional public entry points; keep database and raw AI/model ports private.',
      acceptanceCriteria:
          'TLS, forwarded-header trust, proxy authentication, firewall rules, and WAF policy are reviewed on the real deployment.',
      dependencies: <String>[
        'deployment-specific network diagram',
        'TLS and DNS',
        'proxy/WAF configuration'
      ],
    ),
    PlatformCapability(
      id: 'database-rls',
      title: 'Supabase RLS and data-isolation audit',
      area: 'Platform safety',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary:
          'Audit actual tables, RLS enablement, policies, storage rules, role grants, and profile/account scoping.',
      acceptanceCriteria:
          'Every finding is reviewed against real policies and authorization tests before changes are applied.',
      dependencies: <String>[
        'staging database',
        'policy review',
        'cross-account negative tests'
      ],
    ),
    PlatformCapability(
      id: 'monitoring-recovery',
      title: 'Security monitoring, backups, and recovery drills',
      area: 'Platform safety',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary:
          'Keep redacted security logs, alert on anomalies, scan dependencies/secrets, and maintain encrypted backups.',
      acceptanceCriteria:
          'Alerts reach an owner, backups are encrypted, and a restore drill is documented and successful.',
      dependencies: <String>[
        'centralized logs',
        'alert destination',
        'backup storage',
        'restore runbook'
      ],
    ),
    PlatformCapability(
      id: 'streaming-performance',
      title: 'High-speed local and remote playback',
      area: 'Playback and performance',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Prefer Direct Play, remux only when appropriate, and transcode only when needed. Measure playback start, buffering, transcoder queue, and simultaneous streams.',
      acceptanceCriteria:
          'Capture representative local and remote playback measurements with supported clients and documented network conditions; never claim a speed target without measurements.',
      dependencies: <String>[
        'media gateway capabilities',
        'hardware acceleration tests',
        'measured upload and LAN bandwidth',
        'QoE telemetry'
      ],
    ),
    PlatformCapability(
      id: 'drive-failure-resilience',
      title: 'Drive-failure tolerance and independent recovery',
      area: 'Storage and reliability',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary:
          'Use a redundant storage layout selected for the actual drive count and workload, health checks, integrity scrubs, replacement procedures, and independent backups.',
      acceptanceCriteria:
          'Document tested pool failure tolerance, alerting, backup independence, and isolated restoration; complete a controlled failure drill without risking the only copy.',
      dependencies: <String>[
        'NAS or supported storage pool',
        'replacement-drive plan',
        'independent backup target',
        'UPS and graceful shutdown',
        'restore test'
      ],
    ),
    PlatformCapability(
      id: 'household-multi-profile-access',
      title: 'Household profiles and concurrent use',
      area: 'Accounts and household',
      phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Members share the authorized server/library while history, favorites, recommendations, private activity, and Kids restrictions remain profile-scoped.',
      acceptanceCriteria:
          'Validate concurrent clients and prove negative cross-profile/cross-account requests cannot read private data or bypass Kids restrictions.',
      dependencies: <String>[
        'authenticated profile ownership',
        'backend authorization tests',
        'session revocation',
        'concurrency tests'
      ],
    ),
    PlatformCapability(
      id: 'secure-worldwide-access',
      title: 'Secure worldwide media access',
      area: 'Remote access',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary:
          'Expose only an authenticated HTTPS gateway or approved private access path; keep the database, NAS UI, storage shares, and worker control ports private.',
      acceptanceCriteria:
          'External-network tests cover valid/invalid/revoked sessions, TLS, exact origins, rate limits, DNS/certificate renewal, authorized media access, and internal-port exposure.',
      dependencies: <String>[
        'internet upload capacity',
        'DNS and HTTPS gateway',
        'firewall configuration',
        'short-lived media authorization'
      ],
    ),
    PlatformCapability(
      id: 'reliability-command-center',
      title: 'MyOwn Reliability Command Center',
      area: 'Operations',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Unify server, storage, backup, gateway, transcoding, performance, and alert status while distinguishing unknown signals from verified health.',
      acceptanceCriteria:
          'Every production status has a trusted source, last-check time, stale-signal policy, and test evidence; disconnected telemetry remains unknown.',
      dependencies: <String>[
        'host collector',
        'authenticated metrics API',
        'alert destination',
        'role-protected admin UI'
      ],
    ),
    PlatformCapability(
      id: 'self-healing-infrastructure',
      title: 'Self-healing infrastructure with approval gates',
      area: 'Operations',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.roadmap,
      summary:
          'Use bounded, auditable recovery tasks with action allowlists, idempotency, timeouts, lockouts, circuit breakers, and rollback verification.',
      acceptanceCriteria:
          'Only read-only probes and pre-approved idempotent retries are automatic at first; destructive storage, security, restore, and access changes are approval-gated.',
      dependencies: <String>[
        'persistent worker scheduler',
        'backend action policy',
        'audit storage',
        'human approval workflow',
        'rollback tests'
      ],
    ),
    PlatformCapability(
      id: 'smart-streaming-optimizer',
      title: 'Smart Streaming Optimizer',
      area: 'Playback and performance',
      phase: CapabilityPhase.experience,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Recommend Direct Play, remux, or transcode using authorization and actual device/media compatibility, and budget remote streams against sustained upload.',
      acceptanceCriteria:
          'Playback decisions are validated on representative devices and codecs; temporary cache never deletes source files; measured buffering and start time are reported.',
      dependencies: <String>[
        'device/media capability negotiation',
        'media gateway',
        'supported transcoder',
        'QoE tests'
      ],
    ),
    PlatformCapability(
      id: 'media-integrity-guardian',
      title: 'Media Integrity Guardian',
      area: 'Library and recovery',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.roadmap,
      summary:
          'Check checksums, missing files, incomplete imports, metadata references, duplicates, and supported subtitle/media readability; put findings in a review queue.',
      acceptanceCriteria:
          'Scans record provenance and results; source media is never silently deleted or replaced; repair requires a verified second copy and policy approval.',
      dependencies: <String>[
        'trusted server-side file scanner',
        'checksum index',
        'review queue',
        'approved recovery copy'
      ],
    ),
    PlatformCapability(
      id: 'mindscape-ai-team',
      title: 'Mindscape AI Team — Steward, Moxie, and Fixer',
      area: 'Platform safety',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary:
          'Three scoped AI roles for security/housekeeping/encryption posture, socialization/humor/coordination, and maintenance/incident triage/authorized video analysis.',
      acceptanceCriteria:
          'Each agent has backend-enforced least privilege, prompt-injection protections, redacted audit logs, and human approval for sensitive actions. Models and workers are verified before activation.',
      dependencies: <String>[
        'approved model connector',
        'per-agent identity and scopes',
        'audit persistence',
        'approval API',
        'authorized video pipeline'
      ],
    ),
    PlatformCapability(
      id: 'mindscape-ai-orchestrator',
      title: 'Mindscape AI Orchestrator',
      area: 'AI and automation',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.roadmap,
      summary:
          'Coordinate role-based task proposals with risk classifications, bounded queues, traceable handoffs, and explicit approval boundaries.',
      acceptanceCriteria:
          'Every tool call is authorized in the backend, proposals are persisted with redacted audit trails, retries are bounded, and high-impact actions cannot execute without approval.',
      dependencies: <String>[
        'agent scheduler',
        'tool router',
        'approval persistence',
        'prompt-injection tests',
        'kill switch'
      ],
    ),
    PlatformCapability(
      id: 'worldwide-family-safety',
      title: 'Worldwide Access and Family Safety Center',
      area: 'Accounts and remote access',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.setupRequired,
      summary:
          'Review external HTTPS access, devices/sessions, profile boundaries, Kids policy coverage, and emergency remote-access disablement.',
      acceptanceCriteria:
          'External tests validate revocation, expiry, profile isolation, and server-side restrictions across search, media, music, social, commerce, and AI endpoints.',
      dependencies: <String>[
        'secure HTTPS gateway',
        'session/device API',
        'account/profile authorization tests',
        'remote incident runbook'
      ],
    ),
    PlatformCapability(
      id: 'offline-home-mode',
      title: 'Offline Home Mode',
      area: 'Self-hosting',
      phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Keep supported local-LAN playback usable through a WAN outage when the server, LAN, local media, and required authentication are still available.',
      acceptanceCriteria:
          'A WAN-disconnect test confirms local playback and catalog use; features that need cloud auth, external metadata, or remote clients disclose their dependency.',
      dependencies: <String>[
        'local server address/DNS',
        'LAN authentication behavior',
        'local media paths',
        'WAN-outage test'
      ],
    ),
    PlatformCapability(
      id: 'smart-storage-planner',
      title: 'Smart Storage Planner',
      area: 'Storage and reliability',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.verifyLocally,
      summary:
          'Estimate time to a configured free-space reserve from measured capacity and growth, and report capacity signals from the trusted host collector when connected.',
      acceptanceCriteria:
          'Forecasts identify input source and time window; live reports include pool/disk source and stale-data checks; no storage change occurs automatically.',
      dependencies: <String>[
        'filesystem/pool telemetry',
        'usage history',
        'free-space reserve policy'
      ],
    ),
    PlatformCapability(
      id: 'automatic-recovery-drills',
      title: 'Automatic Recovery Drills',
      area: 'Backup and recovery',
      phase: CapabilityPhase.platformSafety,
      readiness: CapabilityReadiness.roadmap,
      summary:
          'Schedule isolated backup restore checks and record recovery time, recovery point, checksum outcome, and missing data.',
      acceptanceCriteria:
          'Drills restore to isolated staging, never overwrite production, produce auditable evidence, and alert when the recovery objective is missed.',
      dependencies: <String>[
        'independent backups',
        'isolated restore target',
        'scheduler',
        'checksums',
        'RTO/RPO targets'
      ],
    ),
    PlatformCapability(
      id: 'capability-checks',
      title: 'Capability and integration registry',
      area: 'Engineering',
      phase: CapabilityPhase.stabilize,
      readiness: CapabilityReadiness.foundationExists,
      summary:
          'Maintain an explicit register of existing foundations, local verification needs, configuration, external dependencies, and roadmap work.',
      acceptanceCriteria:
          'Status is not described as live health; changes to readiness are reviewed and evidence-backed.',
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
                hintText:
                    'Search features, dependencies, or acceptance criteria',
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
                Text(
                    '${visible.length} of ${PlatformCapabilityCatalog.all.length} capabilities'),
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
                ? const Center(
                    child: Text('No capabilities match these filters.'))
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
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
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
        title: Text(capability.title,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              _StatusLabel(label: capability.readiness.label, color: color),
              _StatusLabel(
                  label: capability.phase.label,
                  color: Theme.of(context).colorScheme.outline),
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
            child: Text('Acceptance criteria',
                style: TextStyle(fontWeight: FontWeight.w800)),
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
              child: Text('Dependencies',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: capability.dependencies
                    .map((item) => Chip(label: Text(item)))
                    .toList(),
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
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );
}
