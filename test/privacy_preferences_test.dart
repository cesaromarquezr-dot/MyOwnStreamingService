import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_own_streaming_service/privacy_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('diagnostics are opt-in while existing presence can be disabled per profile', () async {
    final defaults = await PrivacyPreferencesStore.load(profileId: 'family-profile');
    expect(defaults.sharePlaybackDiagnostics, isFalse);
    expect(defaults.sharePresence, isTrue);

    defaults
      ..sharePresence = false
      ..shareActivity = false
      ..personalizedRecommendations = false;
    await PrivacyPreferencesStore.save(profileId: 'family-profile', value: defaults);

    final reloaded = await PrivacyPreferencesStore.load(profileId: 'family-profile');
    expect(reloaded.sharePresence, isFalse);
    expect(reloaded.shareActivity, isFalse);
    expect(reloaded.personalizedRecommendations, isFalse);
  });

  test('privacy choices are isolated between profiles', () async {
    final first = await PrivacyPreferencesStore.load(profileId: 'first');
    first.shareActivity = false;
    await PrivacyPreferencesStore.save(profileId: 'first', value: first);
    final second = await PrivacyPreferencesStore.load(profileId: 'second');
    expect(second.shareActivity, isTrue);
  });
}
