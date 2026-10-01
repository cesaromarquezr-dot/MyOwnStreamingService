import 'account.dart';

/// Identity attached to an authenticated backend session.
///
/// `memberId` distinguishes the account owner from an invited member even when
/// both are operating on the same account.
class AuthenticatedPrincipal {
  final Account account;
  final String memberId;

  const AuthenticatedPrincipal({
    required this.account,
    required this.memberId,
  });

  bool get isOwner => memberId == 'owner_${account.id}';
}
