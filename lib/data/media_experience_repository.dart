import '../app_core.dart';
import '../models/media_experience_models.dart';

class MediaExperienceRepository {
  const MediaExperienceRepository();
  MediaExperienceSnapshot forMedia(MediaItem media) {
    final scenes=<MediaExperienceScene>[];
    for(var i=0;i<media.chapters.length;i++){scenes.add(MediaExperienceScene(id:'chapter-$i',title:media.chapters[i],positionSeconds:0));}
    final audio=media.audioTracks.asMap().entries.map((e)=>MediaExperienceTrack(id:'audio-${e.key}',label:e.value,isDefault:e.key==0)).toList(growable:false);
    final subtitles=media.subtitles.asMap().entries.map((e)=>MediaExperienceTrack(id:'subtitle-${e.key}',label:e.value,isDefault:e.key==0)).toList(growable:false);
    final extras=media.extras.asMap().entries.map((e)=>MediaExperienceExtra.fromValue(e.value,e.key)).toList(growable:false);
    final controller=AppController.instance; final profile=controller.currentProfile;
    final sameDisc=controller.library.where((item){final rel=media.physicalReleaseId?.trim() ?? '';final disc=media.physicalDiscId?.trim() ?? '';if(rel.isNotEmpty)return item.physicalReleaseId==rel;if(disc.isNotEmpty)return item.physicalDiscId==disc;final collection=media.discCollectionId?.trim() ?? '';return collection.isNotEmpty&&item.discCollectionId==collection;}).where((item)=>item.isAccessibleTo(profile)&&controller.isOwned(item.id)).toList(growable:false);
    final programs=sameDisc.map((item)=>MediaDiscProgram(mediaId:item.id,title:item.title,position:item.discContentPosition??0,discNumber:item.discNumber??1,isBonus:item.isBonusContent,kind:_kind(item))).toList(growable:false);
    return MediaExperienceSnapshot(mediaId:media.id,title:media.title,scenes:scenes,audioTracks:audio,subtitleTracks:subtitles,extras:extras,discPrograms:programs);
  }
  MediaProgramKind _kind(MediaItem media){final type=media.type.toLowerCase();if(type.contains('movie'))return MediaProgramKind.movie;if(type.contains('episode'))return MediaProgramKind.episode;if(type.contains('special'))return MediaProgramKind.tvSpecial;if(type.contains('music'))return MediaProgramKind.musicVideo;return MediaProgramKind.other;}
}
