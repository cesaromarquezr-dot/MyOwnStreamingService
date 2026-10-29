import 'package:flutter/material.dart';

import '../app_core.dart';

/// Small, reusable attribution label for media that was imported into a library.
/// Unknown attribution is shown only when the item is known to originate from an
/// import/server scan; catalog recommendations and demo placeholders stay clean.
class AddedByProfileLabel extends StatelessWidget {
  const AddedByProfileLabel({
    super.key,
    this.profileName,
    this.showUnknown = false,
    this.onArtwork = false,
    this.compact = true,
  });

  AddedByProfileLabel.forMedia(
    MediaItem media, {
    super.key,
    this.onArtwork = false,
    this.compact = true,
  })  : profileName = media.addedByProfileName,
        showUnknown = _shouldShowUnknownFor(media);

  final String? profileName;
  final bool showUnknown;
  final bool onArtwork;
  final bool compact;

  static bool _shouldShowUnknownFor(MediaItem media) {
    final source = media.addedSource.trim().toLowerCase();
    return const <String>{
      'home-server-scanner',
      'import/rip',
      'disc_ingestion_center',
      'approved-arm-import',
      'arm-import',
    }.contains(source);
  }

  String? get _label {
    final name = profileName?.trim() ?? '';
    if (name.isNotEmpty) return 'Added by $name';
    return showUnknown ? 'Added by unknown profile' : null;
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label == null) return const SizedBox.shrink();

    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: TextStyle(
        color: onArtwork ? Colors.white : Colors.white70,
        fontSize: compact ? 9.5 : 11,
        height: 1.1,
        fontWeight: FontWeight.w600,
      ),
    );
    if (!onArtwork) return text;

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xD914141B),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline_rounded,
              size: compact ? 11 : 13, color: Colors.white70),
          const SizedBox(width: 4),
          Flexible(child: text),
        ],
      ),
    );
  }
}

/// Resolves a persisted profile ID to its display name for a user-created
/// collection or playlist. Returns null if the profile is no longer available.
String? profileNameForId(String? profileId) {
  final id = profileId?.trim() ?? '';
  if (id.isEmpty) return null;
  for (final profile in AppController.instance.currentAccount?.profiles ?? const <Profile>[]) {
    if (profile.id == id) return profile.name;
  }
  final current = AppController.instance.currentProfile;
  if (current?.id == id) return current?.name;
  return null;
}
