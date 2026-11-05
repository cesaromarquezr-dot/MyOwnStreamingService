import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TheaterTicketQr extends StatelessWidget {
  const TheaterTicketQr({super.key,required this.sessionId});
  final String sessionId;
  @override Widget build(BuildContext context) => Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),child:QrImageView(data:sessionId,size:164,backgroundColor:Colors.white,eyeStyle:const QrEyeStyle(eyeShape:QrEyeShape.square,color:Colors.black),dataModuleStyle:const QrDataModuleStyle(dataModuleShape:QrDataModuleShape.square,color:Colors.black)));
}
