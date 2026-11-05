// A private screening pass is an at-home session reference, not a paid ticket.
class TheaterTicketModel {
  const TheaterTicketModel({required this.id,required this.sessionId,required this.mediaId,required this.createdAt,this.seatIds=const [],this.status='ready'});
  final String id; final String sessionId; final String mediaId; final DateTime createdAt; final List<String> seatIds; final String status;
  factory TheaterTicketModel.fromJson(Map<String,dynamic> json) => TheaterTicketModel(id: json['id']?.toString() ?? '', sessionId: json['sessionId']?.toString() ?? '', mediaId: json['mediaId']?.toString() ?? '', createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(), seatIds: (json['seatIds'] as List? ?? const []).map((v)=>v.toString()).toList(), status: json['status']?.toString() ?? 'ready');
  Map<String,dynamic> toJson() => {'id':id,'sessionId':sessionId,'mediaId':mediaId,'createdAt':createdAt.toUtc().toIso8601String(),'seatIds':seatIds,'status':status};
}
