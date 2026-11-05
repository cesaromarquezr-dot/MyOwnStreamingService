import '../../shared/owned_experience_routes_base.dart';
import '../../shared/owned_experience_store.dart';
import '../../../middleware/authentication.dart';
import '../../../models/account.dart';
class KioskRoutes extends OwnedExperienceRoutesBase {
  KioskRoutes({required AuthenticationMiddleware authentication, required OwnedExperienceStore store}) : super(authentication: authentication, store: store);
  @override String get routePrefix => '/api/v1/kiosk/sessions';
  @override String get recordType => 'kiosk_session';
  @override
  String? validateWrite(Account account, String profileId, Map<String, dynamic> data) {
    final mediaId = data['mediaId']?.toString() ?? '';
    if (!isOwnedMediaForProfile(account, profileId, mediaId)) {
      return "Only media already in this account's owned library can be used here.";
    }
    return null;
  }

  @override Map<String,dynamic> normalize(Map<String,dynamic> body) {
    final data = super.normalize(body);
    if ((data['mediaId']?.toString().trim() ?? '').isEmpty) throw ArgumentError('A library media ID is required.');
    data['mode'] = data['mode'] == 'resume' ? 'resume' : 'play';
    data['startedAt'] = DateTime.now().toUtc().toIso8601String();
    data.remove('price'); data.remove('payment'); data.remove('rental'); data.remove('checkout');
    return data;
  }
}
