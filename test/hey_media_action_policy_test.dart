import 'package:flutter_test/flutter_test.dart';
import 'package:my_own_streaming_service/core/services/hey_media_action_policy.dart';

void main() {
  group('HeyMediaActionPolicy', () {
    test('read-only discovery is allowed for a permitted profile', () {
      final decision = HeyMediaActionPolicy.evaluate(
        HeyMediaAction.searchLibrary,
        permittedByProfile: true,
      );
      expect(decision.allowed, isTrue);
      expect(decision.requiresConfirmation, isFalse);
    });

    test('purchase requires explicit confirmation', () {
      final decision = HeyMediaActionPolicy.evaluate(
        HeyMediaAction.purchase,
        permittedByProfile: true,
      );
      expect(decision.allowed, isFalse);
      expect(decision.requiresConfirmation, isTrue);
    });

    test('confirmation never overrides profile authorization', () {
      final decision = HeyMediaActionPolicy.evaluate(
        HeyMediaAction.deleteMedia,
        permittedByProfile: false,
        userConfirmed: true,
      );
      expect(decision.allowed, isFalse);
    });

    test('confirmed consequential action still requires backend enforcement', () {
      final decision = HeyMediaActionPolicy.evaluate(
        HeyMediaAction.placeOrder,
        permittedByProfile: true,
        userConfirmed: true,
      );
      expect(decision.allowed, isTrue);
      expect(decision.reason, contains('backend'));
    });
  });
}
