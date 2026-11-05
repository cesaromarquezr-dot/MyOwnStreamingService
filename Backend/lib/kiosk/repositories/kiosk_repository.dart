import '../../shared/owned_experience_store.dart';
import '../models/kiosk_inventory_model.dart';
class KioskRepository {
  const KioskRepository(this.store); final OwnedExperienceStore store;
  Future<List<KioskInventoryModel>> listFavorites(String accountId,String profileId) async => (await store.list(accountId: accountId, profileId: profileId, recordType: 'kiosk_favorite')).map(KioskInventoryModel.fromJson).toList(growable:false);
  Future<void> saveFavorite(String accountId,String profileId,KioskInventoryModel item) => store.save(accountId: accountId, profileId: profileId, recordType: 'kiosk_favorite', recordId: item.mediaId, data: item.toJson());
  Future<void> removeFavorite(String accountId,String profileId,String mediaId) => store.delete(accountId: accountId, profileId: profileId, recordType: 'kiosk_favorite', recordId: mediaId);
}
