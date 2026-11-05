import 'package:flutter/material.dart';
class KioskPrimaryAction extends StatelessWidget {
  const KioskPrimaryAction({super.key,required this.title,required this.subtitle,required this.icon,required this.onPressed,this.isPrimary=true});
  final String title; final String subtitle; final IconData icon; final VoidCallback onPressed; final bool isPrimary;
  @override Widget build(BuildContext context) => SizedBox(width:double.infinity,child:FilledButton.tonalIcon(style:FilledButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:18,vertical:18),alignment:Alignment.centerLeft,backgroundColor:isPrimary?Theme.of(context).colorScheme.primaryContainer:null,foregroundColor:isPrimary?Theme.of(context).colorScheme.onPrimaryContainer:null),onPressed:onPressed,icon:Icon(icon,size:28),label:Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),Text(subtitle,style:Theme.of(context).textTheme.bodySmall)]))));
}
