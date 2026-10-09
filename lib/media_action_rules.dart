class MediaAbilityEffect {
  final String id;
  final String name;
  final Duration duration;
  final bool invulnerable;
  final bool instantDefeatOnHit;
  final int? maxCharges;

  const MediaAbilityEffect({
    required this.id,
    required this.name,
    required this.duration,
    this.invulnerable = false,
    this.instantDefeatOnHit = false,
    this.maxCharges,
  });
}

/// Rule data for a game/extras experience based on Sam Raimi's Spider-Man 3.
/// The effect is fictional gameplay logic and is only active when an experience
/// explicitly opts into the Spider-Man 3 symbiote ruleset.
const MediaAbilityEffect spiderMan3RageMode = MediaAbilityEffect(
  id: 'spider_man_3_rage_mode',
  name: 'Rage Mode',
  duration: Duration(seconds: 15),
  invulnerable: true,
  instantDefeatOnHit: true,
);

class MediaGameplayContext {
  final String mediaTitle;
  final String? mediaId;
  final String rulesetId;

  const MediaGameplayContext({
    required this.mediaTitle,
    this.mediaId,
    required this.rulesetId,
  });

  bool get isSpiderMan3 =>
      mediaTitle.toLowerCase().contains('spider-man 3') ||
      mediaTitle.toLowerCase().contains('spiderman 3');
}

class RageModeState {
  final bool active;
  final DateTime? expiresAt;

  const RageModeState({this.active = false, this.expiresAt});

  bool get invulnerable => active;

  bool canInstantDefeat(DateTime now) =>
      active && expiresAt != null && now.isBefore(expiresAt!);

  RageModeState activate(DateTime now) => RageModeState(
        active: true,
        expiresAt: now.add(spiderMan3RageMode.duration),
      );

  RageModeState expire(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!)
          ? const RageModeState()
          : this;
}
