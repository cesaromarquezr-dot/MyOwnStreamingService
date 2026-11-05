import '../../shared/owned_experience_store.dart';
class TheaterRepository {
  const TheaterRepository(this.store); final OwnedExperienceStore store;
  Future<List<Map<String,dynamic>>> listSessions(String accountId,String profileId) => store.list(accountId:accountId,profileId:profileId,recordType:'theater_session');
  Future<void> saveSession(String accountId,String profileId,String id,Map<String,dynamic> data) => store.save(accountId:accountId,profileId:profileId,recordType:'theater_session',recordId:id,data:data);
  Future<void> deleteSession(String accountId,String profileId,String id) => store.delete(accountId:accountId,profileId:profileId,recordType:'theater_session',recordId:id);
}
