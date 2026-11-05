import 'package:flutter/material.dart';
import '../app_core.dart';
import 'media_case_3d_view.dart';

class TheaterMovieCard extends StatelessWidget {
  const TheaterMovieCard({super.key, required this.media, required this.onTap});
  final MediaItem media; final VoidCallback onTap;
  @override Widget build(BuildContext context) => InkWell(onTap:onTap,borderRadius:BorderRadius.circular(14),child: SizedBox(width:138,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Center(child:MediaCase3DView(title:media.title,media:media,format:media.displayCaseFormat,year:media.releaseYear,width:104,height:138)),
    const SizedBox(height:9),Text(media.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),
    Text([media.type,if(media.releaseYear!=null) '${media.releaseYear}'].join(' · '),maxLines:1,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.bodySmall?.copyWith(color:Theme.of(context).colorScheme.onSurfaceVariant)),
  ])));
}
