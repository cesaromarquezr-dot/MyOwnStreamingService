class ShowtimeModel {
  const ShowtimeModel({required this.id,required this.mediaId,required this.title,required this.startsAt,this.durationMinutes,this.roomId='main-room',this.posterUrl});
  final String id; final String mediaId; final String title; final DateTime startsAt; final int? durationMinutes; final String roomId; final String? posterUrl;
  factory ShowtimeModel.fromJson(Map<String,dynamic> json) => ShowtimeModel(id: json['id']?.toString() ?? '', mediaId: json['mediaId']?.toString() ?? '', title: json['title']?.toString() ?? '', startsAt: DateTime.tryParse(json['startsAt']?.toString() ?? '') ?? DateTime.now(), durationMinutes: int.tryParse(json['durationMinutes']?.toString() ?? ''), roomId: json['roomId']?.toString() ?? 'main-room', posterUrl: json['posterUrl']?.toString());
  Map<String,dynamic> toJson() => {'id':id,'mediaId':mediaId,'title':title,'startsAt':startsAt.toUtc().toIso8601String(),'durationMinutes':durationMinutes,'roomId':roomId,'posterUrl':posterUrl};
}
