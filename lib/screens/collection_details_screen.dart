import 'package:flutter/material.dart';
import '../details.dart';
import '../models/media_collection_models.dart';
import '../widgets/media_case_3d_view.dart';

class CollectionDetailsScreen extends StatelessWidget { const CollectionDetailsScreen({super.key,required this.collection}); final MediaCollection collection;
 @override Widget build(BuildContext context){final items=collection.orderedItems;return Scaffold(appBar:AppBar(title:Text(collection.title)),body:ListView(padding:const EdgeInsets.all(16),children:[Center(child:MediaCase3DView(title:collection.title,imageUrl:collection.artworkUrl,format:collection.format??'BOX SET',width:150,height:204,caseColor:0xFF3A3152)),const SizedBox(height:14),Text(collection.title,textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('${items.length} programs · ${collection.discCount} discs',textAlign:TextAlign.center),const SizedBox(height:18),for(final item in items)Card(child:ListTile(leading:CircleAvatar(child:Text('${items.indexOf(item)+1}')),title:Text(item.title),subtitle:Text([item.type,if(item.discNumber!=null)'Disc ${item.discNumber}',if(item.isBonusContent)'Bonus content'].join(' · ')),trailing:const Icon(Icons.play_arrow_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>MediaDetailsScreen(media:item)))))]));}
}
