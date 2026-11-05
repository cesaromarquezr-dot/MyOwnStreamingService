import '../backend_api.dart';

/// Thin authenticated API adapter. The UI still works offline; synchronization
/// is attempted only when the account already has a backend session.
class MediaExperienceApi {
  const MediaExperienceApi(this.api); final BackendApi api;
  Future<Map<String,dynamic>?> loadProgress({required String profileId,required String mediaId}) async {
    if(!api.isAuthenticated)return null;
    try{return await api.getMediaExperienceProgress(profileId:profileId,mediaId:mediaId);}catch(_){return null;}
  }
  Future<void> saveProgress({required String profileId,required String mediaId,required int positionSeconds,String? audioTrack,String? subtitleTrack}) async {
    if(!api.isAuthenticated)return;
    await api.saveMediaExperienceProgress(profileId:profileId,mediaId:mediaId,positionSeconds:positionSeconds,audioTrack:audioTrack,subtitleTrack:subtitleTrack);
  }
}
