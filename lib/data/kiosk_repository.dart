import '../app_core.dart';
import '../models/kiosk_models.dart';

class KioskRepository {
  const KioskRepository();
  List<KioskCatalogEntry> catalog({KioskCategory category=KioskCategory.all}) {
    final controller=AppController.instance; final profile=controller.currentProfile;
    final rows=controller.library.where((media)=>media.isAccessibleTo(profile)&&controller.isOwned(media.id));
    return rows.where((media)=>category==KioskCategory.all||_category(media)==category).map((media)=>KioskCatalogEntry(media:media,category:_category(media))).toList(growable:false);
  }
  KioskCategory _category(MediaItem media){final type=media.type.toLowerCase();if(type.contains('music')||type=='album'||type=='song')return KioskCategory.music;if(type.contains('special'))return KioskCategory.specials;if(type.contains('tv')||type.contains('episode')||type.contains('series')||type.contains('show'))return KioskCategory.television;return KioskCategory.movies;}
}
