import '../../shared/owned_experience_routes_base.dart';
import '../../shared/owned_experience_store.dart';
import '../../../middleware/authentication.dart';
import '../../../models/account.dart';
class TheaterRoutes extends OwnedExperienceRoutesBase {
  TheaterRoutes({required AuthenticationMiddleware authentication, required OwnedExperienceStore store}) : super(authentication: authentication, store: store);
  @override String get routePrefix => '/api/v1/theater/sessions';
  @override String get recordType => 'theater_session';
  @override
  String? validateWrite(Account account, String profileId, Map<String, dynamic> data) {
    final mediaId = data['mediaId']?.toString() ?? '';
    if (!isOwnedMediaForProfile(account, profileId, mediaId)) {
      return "Only media already in this account's owned library can be used here.";
    }
    return null;
  }

  @override Map<String,dynamic> normalize(Map<String,dynamic> body) {
    final data=super.normalize(body);
    if((data['mediaId']?.toString().trim() ?? '').isEmpty) throw ArgumentError('A media ID from your library is required.');
    data['seatIds']=(data['seatIds'] as List? ?? const []).map((v)=>v.toString()).take(32).toList(growable:false);
    data['privateViewing']=true; data['paymentRequired']=false; data.remove('price'); data.remove('ticketPrice'); data.remove('checkout');
    data['status']=['ready','playing','completed','cancelled'].contains(data['status']) ? data['status'] : 'ready';
    return data;
  }
}
