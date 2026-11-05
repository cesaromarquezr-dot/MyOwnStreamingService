import '../models/kiosk_inventory_model.dart';
import '../repositories/kiosk_repository.dart';
class KioskService {
  const KioskService(this.repository); final KioskRepository repository;
  Future<List<KioskInventoryModel>> favorites(String accountId,String profileId) => repository.listFavorites(accountId,profileId);
  Future<void> setFavorite(String accountId,String profileId,KioskInventoryModel item) {
    if (item.mediaId.trim().isEmpty || item.title.trim().isEmpty) throw ArgumentError('A library media ID and title are required.');
    if (!item.isOwned) throw ArgumentError('The Kiosk only displays media in the account library.');
    return repository.saveFavorite(accountId,profileId,item);
  }
  Future<void> removeFavorite(String accountId,String profileId,String mediaId) => repository.removeFavorite(accountId,profileId,mediaId);
}
