import 'package:flutter/material.dart';
import '../core/media_experience/renderer/media_3d_renderer.dart';
class MediaDisc3DView extends StatelessWidget {
  const MediaDisc3DView({super.key,this.label='DISC 1',this.size=112,this.color=const Color(0xFFB8C4D4)});
  final String label; final double size; final Color color;
  @override Widget build(BuildContext context)=>Media3DRenderer.perspective(perspective:.001,rotateX:-.04,rotateY:-.12,child:Container(width:size,height:size,decoration:BoxDecoration(shape:BoxShape.circle,gradient:RadialGradient(colors:[Colors.white,color,color.withValues(alpha:.75),const Color(0xFF303846)],stops:const [0,.12,.78,1]),border:Border.all(color:Colors.white70),boxShadow:const [BoxShadow(color:Colors.black38,blurRadius:10,offset:Offset(4,5))]),child:Stack(alignment:Alignment.center,children:[Container(width:size*.18,height:size*.18,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xFF202631),border:Border.all(color:Colors.white70))),Positioned(bottom:size*.19,child:Text(label,style:TextStyle(fontSize:size*.085,color:const Color(0xFF202631),fontWeight:FontWeight.w900,letterSpacing:1)))])));
}
