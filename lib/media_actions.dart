// Shared media action contract and adapter to existing domain owners.
// The backend event is an idempotent audit/sync record; it does not duplicate
// authoritative likes, playlists, or collection membership.

import 'dart:async';

import 'app_core.dart';

enum UniversalMediaAction {
  like,
  dislike,
  removeReaction,
  addToPlaylist,
  removeFromPlaylist,
  addToCollection,
  removeFromCollection,
  queue,
  share,
  rate,
  review,
  wishlist,
}

extension UniversalMediaActionValue on UniversalMediaAction {
  String get value {
    switch (this) {
      case UniversalMediaAction.removeReaction:
        return 'remove_reaction';
      case UniversalMediaAction.addToPlaylist:
        return 'add_to_playlist';
      case UniversalMediaAction.removeFromPlaylist:
        return 'remove_from_playlist';
      case UniversalMediaAction.addToCollection:
        return 'add_to_collection';
      case UniversalMediaAction.removeFromCollection:
        return 'remove_from_collection';
      default:
        return name;
    }
  }
}

class UniversalMediaActionContext {
  final String contentType;
  final String contentId;
  final String profileId;
  final String? mediaVersionId;
  final Set<UniversalMediaAction> availableActions;

  const UniversalMediaActionContext({
    required this.contentType,
    required this.contentId,
    required this.profileId,
    required this.availableActions,
    this.mediaVersionId,
  });
}

class UniversalMediaActionResult {
  final bool applied;
  final bool recorded;

  const UniversalMediaActionResult({
    required this.applied,
    required this.recorded,
  });
}

/// Runs an action through a shared permission check and the existing domain
/// service, then records the successful interaction for cross-device sync.
class UniversalMediaActions {
  UniversalMediaActions._();

  static int _sequence = 0;

  static Future<UniversalMediaActionResult> perform({
    required UniversalMediaActionContext context,
    required UniversalMediaAction action,
    required FutureOr<void> Function() apply,
    String? targetId,
    String? idempotencyKey,
  }) async {
    if (!context.availableActions.contains(action) ||
        context.contentId.trim().isEmpty ||
        context.profileId.trim().isEmpty) {
      return const UniversalMediaActionResult(applied: false, recorded: false);
    }

    await apply();
    final api = AppController.instance.backendApi;
    if (!api.isAuthenticated) {
      return const UniversalMediaActionResult(applied: true, recorded: false);
    }

    final actionKey = idempotencyKey?.trim().isNotEmpty == true
        ? idempotencyKey!.trim()
        : 'media_action_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
    try {
      await api.recordUniversalMediaAction(
        profileId: context.profileId,
        action: action.value,
        contentType: context.contentType,
        contentId: context.contentId,
        idempotencyKey: actionKey,
        mediaVersionId: context.mediaVersionId,
        targetId: targetId,
      );
      return const UniversalMediaActionResult(applied: true, recorded: true);
    } catch (_) {
      // Existing domain state has already been applied. A record failure must
      // not make the UI claim the action itself was rolled back.
      return const UniversalMediaActionResult(applied: true, recorded: false);
    }
  }
}
