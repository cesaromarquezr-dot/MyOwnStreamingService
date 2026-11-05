import '../../shared/owned_experience_store.dart';
import '../models/collection_model.dart';

class CollectionRepository {
  const CollectionRepository(this.store);
  final OwnedExperienceStore store;
  Future<List<CollectionModel>> list(String accountId, String profileId) async => (await store.list(accountId: accountId, profileId: profileId, recordType: 'collection')).map(CollectionModel.fromJson).toList(growable: false);
  Future<CollectionModel?> get(String accountId, String profileId, String id) async { final value = await store.get(accountId: accountId, profileId: profileId, recordType: 'collection', recordId: id); return value == null ? null : CollectionModel.fromJson(value); }
  Future<void> save(String accountId, String profileId, CollectionModel collection) => store.save(accountId: accountId, profileId: profileId, recordType: 'collection', recordId: collection.id, data: collection.toJson());
  Future<void> delete(String accountId, String profileId, String id) => store.delete(accountId: accountId, profileId: profileId, recordType: 'collection', recordId: id);
}
