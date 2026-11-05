import '../app_core.dart';
import '../models/media_collection_models.dart' as physical;

class CollectionRepository {
  const CollectionRepository();
  List<physical.MediaCollection> fromLibrary({bool ownedOnly = true}) {
    final controller=AppController.instance; final profile=controller.currentProfile;
    final eligible=controller.library.where((item)=>item.isAccessibleTo(profile) && (!ownedOnly || controller.isOwned(item.id))).toList(growable:false);
    final buckets=<String,List<MediaItem>>{};
    for(final item in eligible){
      final release=(item.physicalReleaseId?.trim().isNotEmpty==true)?item.physicalReleaseId!.trim():(item.discCollectionId?.trim() ?? '');
      final title=item.discCollectionTitle?.trim() ?? '';
      if(release.isEmpty && title.isEmpty) continue;
      final key=release.isNotEmpty?'release:$release':'title:${title.toLowerCase()}';
      buckets.putIfAbsent(key,()=>[]).add(item);
    }
    final results=<physical.MediaCollection>[];
    for(final entry in buckets.entries){
      final items=entry.value..sort((a,b){final disc=(a.discNumber ?? 1).compareTo(b.discNumber ?? 1);if(disc!=0)return disc;return (a.discContentPosition ?? 0x3fffffff).compareTo(b.discContentPosition ?? 0x3fffffff);});
      final first=items.first;
      final title=first.discCollectionTitle?.trim().isNotEmpty==true?first.discCollectionTitle!.trim():(first.editionName?.trim().isNotEmpty==true?first.editionName!.trim():first.title);
      final discCount=items.map((m)=>m.physicalDiscId?.trim().isNotEmpty==true?m.physicalDiscId!.trim():'disc-${m.discNumber ?? 1}').toSet().length;
      results.add(physical.MediaCollection(id:entry.key,title:title,kind:physical.collectionKindFromItems(items),items:List<MediaItem>.unmodifiable(items),description:first.description,artworkUrl:first.imageUrl,discCount:discCount,format:first.discType,edition:first.editionName));
    }
    results.sort((a,b)=>a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return List.unmodifiable(results);
  }
}
