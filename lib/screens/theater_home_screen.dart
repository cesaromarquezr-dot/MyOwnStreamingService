import 'package:flutter/material.dart';
import '../app_core.dart';
import '../data/theater_repository.dart';
import '../stores/theater_store.dart';
import '../widgets/theater_movie_card.dart';
import 'theater_showtime_screen.dart';

class TheaterHomeScreen extends StatefulWidget { const TheaterHomeScreen({super.key}); @override State<TheaterHomeScreen> createState()=>_TheaterHomeScreenState(); }
class _TheaterHomeScreenState extends State<TheaterHomeScreen>{final _repository=const TheaterRepository();@override void initState(){super.initState();TheaterStore.instance.load(AppController.instance.currentProfile?.id);}
 @override Widget build(BuildContext context){final items=_repository.ownedScreeningLibrary();return Scaffold(appBar:AppBar(title:const Text('Private Theater')),body:ListView(padding:const EdgeInsets.all(16),children:[Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Your own cinema',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:6),const Text('Create a private screening from a movie, episode, or TV special already in your library. Showtimes, seats and passes are personal planning tools—there is no admission fee or payment.'),const SizedBox(height:12),Row(children:[const Icon(Icons.lock_outline_rounded,size:18),const SizedBox(width:6),Text('Private viewing · Owned media only',style:Theme.of(context).textTheme.labelMedium)])]))),const SizedBox(height:18),Text('Choose something to watch',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:12),if(items.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('Your owned movie and television library will appear here.',textAlign:TextAlign.center))else SizedBox(height:240,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(width:12),itemBuilder:(context,index)=>TheaterMovieCard(media:items[index],onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>TheaterShowtimeScreen(media:items[index]))))))]));}
}
