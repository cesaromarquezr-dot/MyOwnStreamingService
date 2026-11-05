import 'package:flutter/material.dart';

class TheaterSeatMap extends StatelessWidget {
  const TheaterSeatMap({super.key,this.rows=4,this.seatsPerRow=6,required this.selectedSeats,required this.onChanged});
  final int rows; final int seatsPerRow; final Set<String> selectedSeats; final ValueChanged<Set<String>> onChanged;
  @override Widget build(BuildContext context) {
    final scheme=Theme.of(context).colorScheme;
    return Column(children:[Container(width:double.infinity,alignment:Alignment.center,padding:const EdgeInsets.symmetric(vertical:10),decoration:BoxDecoration(color:scheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(20)),child:const Text('SCREEN',style:TextStyle(letterSpacing:4,fontWeight:FontWeight.w800))),
      const SizedBox(height:24),...List<Widget>.generate(rows,(row){final label=String.fromCharCode(65+row);return Padding(padding:const EdgeInsets.only(bottom:10),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[SizedBox(width:22,child:Text(label,style:Theme.of(context).textTheme.labelMedium)),...List<Widget>.generate(seatsPerRow,(col){final id='$label${col+1}';final active=selectedSeats.contains(id);return Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:InkWell(onTap:(){final next=Set<String>.from(selectedSeats);if(active){next.remove(id);}else if(next.length<8){next.add(id);}onChanged(next);},borderRadius:BorderRadius.circular(8),child:AnimatedContainer(duration:const Duration(milliseconds:140),width:34,height:31,decoration:BoxDecoration(color:active?scheme.primary:scheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(8),border:Border.all(color:active?scheme.primary:scheme.outlineVariant)),child:Icon(Icons.event_seat_rounded,size:17,color:active?scheme.onPrimary:scheme.onSurfaceVariant))));})]));}),
      const SizedBox(height:12),Text('${selectedSeats.length} selected · up to 8 seats',style:Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
