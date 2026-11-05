import 'package:flutter/foundation.dart';
import '../app_core.dart';
import '../models/media_experience_models.dart';
import '../data/media_experience_repository.dart';

enum MediaCaseAnimationState { closed, opening, open, closing }

class MediaExperienceStore extends ChangeNotifier {
  MediaExperienceStore._(); static final MediaExperienceStore instance=MediaExperienceStore._();
  final MediaExperienceRepository _repository=const MediaExperienceRepository();
  MediaItem? _media; MediaExperienceSnapshot? _snapshot; MediaCaseAnimationState _caseState=MediaCaseAnimationState.closed;
  String _selectedAudio='Default'; String _selectedSubtitle='Off'; String? _selectedSceneId; String? _selectedExtraId;
  MediaItem? get media=>_media; MediaExperienceSnapshot? get snapshot=>_snapshot; MediaCaseAnimationState get caseState=>_caseState;
  String get selectedAudio=>_selectedAudio; String get selectedSubtitle=>_selectedSubtitle; String? get selectedSceneId=>_selectedSceneId; String? get selectedExtraId=>_selectedExtraId;
  void selectMedia(MediaItem media){_media=media;_snapshot=_repository.forMedia(media);_selectedAudio=_snapshot!.audioTracks.isEmpty?'Default':_snapshot!.audioTracks.first.label;_selectedSubtitle='Off';_selectedSceneId=null;_selectedExtraId=null;_caseState=MediaCaseAnimationState.closed;notifyListeners();}
  Future<void> openCase() async {_caseState=MediaCaseAnimationState.opening;notifyListeners();await Future<void>.delayed(const Duration(milliseconds:320));_caseState=MediaCaseAnimationState.open;notifyListeners();}
  Future<void> closeCase() async {_caseState=MediaCaseAnimationState.closing;notifyListeners();await Future<void>.delayed(const Duration(milliseconds:240));_caseState=MediaCaseAnimationState.closed;notifyListeners();}
  void setAudio(String value){_selectedAudio=value;notifyListeners();}
  void setSubtitle(String value){_selectedSubtitle=value;notifyListeners();}
  void selectScene(MediaExperienceScene scene){_selectedSceneId=scene.id;notifyListeners();}
  void selectExtra(MediaExperienceExtra extra){_selectedExtraId=extra.id;notifyListeners();}
}
