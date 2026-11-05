import 'package:flutter/material.dart';
import '../models/media_collection_models.dart';
import 'media_case_3d_view.dart';
class CollectionBox extends StatelessWidget {
  const CollectionBox({super.key,required this.collection,required this.onTap});
  final MediaCollection collection; final VoidCallback onTap;
  @override Widget build(BuildContext context)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(16),child:Card(clipBehavior:Clip.antiAlias,child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[MediaCase3DView(title:collection.title,imageUrl:collection.artworkUrl,format:collection.format ?? 'BOX SET',width:82,height:110,caseColor:0xFF353047),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(collection.title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16),maxLines:2,overflow:TextOverflow.ellipsis),const SizedBox(height:5),Text(collection.kind.name.replaceAllMapped(RegExp(r'[A-Z]'),(m)=>' ${m.group(0)}').trim(),style:Theme.of(context).textTheme.labelMedium),const SizedBox(height:5),Text('${collection.itemCount} programs · ${collection.discCount} ${collection.discCount==1?'disc':'discs'}',style:Theme.of(context).textTheme.bodySmall),if(collection.bonusCount>0)Text('${collection.bonusCount} bonus items',style:Theme.of(context).textTheme.bodySmall)])),const Icon(Icons.chevron_right_rounded)]))));
}
