/// Shared authorization/confirmation policy for any Hey Media action executor.
/// Finding content is read-only. Orders, purchases, deletion, security changes,
/// and outbound sharing must be explicitly confirmed and re-authorized server-side.
enum HeyMediaAction {
  searchLibrary,
  startPlayback,
  createPlaylist,
  shareMedia,
  sendMessage,
  placeOrder,
  purchase,
  deleteMedia,
  changeSecurity,
  changePrivacy,
  deleteAccount,
}

class HeyMediaActionDecision {
  final bool allowed;
  final bool requiresConfirmation;
  final String reason;

  const HeyMediaActionDecision({
    required this.allowed,
    required this.requiresConfirmation,
    required this.reason,
  });
}

abstract final class HeyMediaActionPolicy {
  static const Set<HeyMediaAction> _confirmationRequired = <HeyMediaAction>{
    HeyMediaAction.shareMedia,
    HeyMediaAction.sendMessage,
    HeyMediaAction.placeOrder,
    HeyMediaAction.purchase,
    HeyMediaAction.deleteMedia,
    HeyMediaAction.changeSecurity,
    HeyMediaAction.changePrivacy,
    HeyMediaAction.deleteAccount,
  };

  static const Set<HeyMediaAction> _alwaysRequireExplicitConfirmation = <HeyMediaAction>{
    HeyMediaAction.placeOrder,
    HeyMediaAction.purchase,
    HeyMediaAction.deleteMedia,
    HeyMediaAction.changeSecurity,
    HeyMediaAction.deleteAccount,
  };

  static HeyMediaActionDecision evaluate(
    HeyMediaAction action, {
    required bool permittedByProfile,
    bool userConfirmed = false,
  }) {
    if (!permittedByProfile) {
      return const HeyMediaActionDecision(
        allowed: false,
        requiresConfirmation: false,
        reason: 'The active profile is not permitted to perform this action.',
      );
    }
    final confirmationRequired = _confirmationRequired.contains(action);
    if (confirmationRequired && !userConfirmed) {
      final mandatory = _alwaysRequireExplicitConfirmation.contains(action);
      return HeyMediaActionDecision(
        allowed: false,
        requiresConfirmation: true,
        reason: mandatory
            ? 'Explicit confirmation is required before this consequential action.'
            : 'Confirm before continuing with this action.',
      );
    }
    return const HeyMediaActionDecision(
      allowed: true,
      requiresConfirmation: false,
      reason: 'Allowed by the client policy; the backend must still enforce authorization.',
    );
  }
}
