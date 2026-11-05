import '../../shared/owned_experience_routes_base.dart';
import '../../shared/owned_experience_store.dart';
import '../../../middleware/authentication.dart';
import '../../../models/account.dart';
class MediaExperienceRoutes extends OwnedExperienceRoutesBase {
  MediaExperienceRoutes({required AuthenticationMiddleware authentication, required OwnedExperienceStore store}) : super(authentication: authentication, store: store);
  @override String get routePrefix => '/api/v1/media-experience/progress';
  @override String get recordType => 'media_progress';
  @override
  String? validateWrite(Account account, String profileId, Map<String, dynamic> data) {
    final mediaId = data['mediaId']?.toString() ?? '';
    if (!isOwnedMediaForProfile(account, profileId, mediaId)) {
      return "Playback progress can only be saved for media in this account's library.";
    }
    return null;
  }
  @override Map<String,dynamic> normalize(Map<String,dynamic> body) {
    final data = super.normalize(body);
    if ((data['mediaId']?.toString().trim() ?? '').isEmpty) throw ArgumentError('A media ID is required.');
    data['positionSeconds'] = (int.tryParse(data['positionSeconds']?.toString() ?? '') ?? 0).clamp(0, 2147483647);
    data.remove('filePath'); data.remove('filesystemPath'); data.remove('sourcePath');
    return data;
  }
}
