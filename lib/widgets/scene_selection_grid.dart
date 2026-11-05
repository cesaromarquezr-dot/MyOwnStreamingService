import 'package:flutter/material.dart';
import '../models/media_experience_models.dart';
class SceneSelectionGrid extends StatelessWidget {
  const SceneSelectionGrid({super.key,required this.scenes,required this.onSelected});
  final List<MediaExperienceScene> scenes; final ValueChanged<MediaExperienceScene> onSelected;
  @override Widget build(BuildContext context){if(scenes.isEmpty)return const Padding(padding:EdgeInsets.all(14),child:Text('Chapter information is not available for this item.'));return Wrap(spacing:8,runSpacing:8,children:scenes.map((scene)=>ActionChip(avatar:const Icon(Icons.play_arrow_rounded,size:18),label:Text(scene.title),onPressed:()=>onSelected(scene))).toList());}
}
