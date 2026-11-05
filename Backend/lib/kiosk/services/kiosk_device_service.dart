import '../../shared/owned_experience_store.dart';
class KioskDeviceService {
  const KioskDeviceService(this.store); final OwnedExperienceStore store;
  Future<Map<String,dynamic>> loadPreferences(String accountId,String profileId) async => await store.get(accountId: accountId, profileId: profileId, recordType: 'kiosk_preferences', recordId: 'default') ?? <String,dynamic>{'layout':'poster-wall','autoplayPreviews':false,'showOnlyOwned':true};
  Future<void> savePreferences(String accountId,String profileId,Map<String,dynamic> value) async {
    final autoplay = value['autoplayPreviews'] == true;
    final layout = value['layout']?.toString() ?? 'poster-wall';
    if (!{'poster-wall','shelf','compact'}.contains(layout)) throw ArgumentError('Unsupported kiosk layout.');
    await store.save(accountId: accountId, profileId: profileId, recordType: 'kiosk_preferences', recordId: 'default', data: {'layout':layout,'autoplayPreviews':autoplay,'showOnlyOwned':true});
  }
}
