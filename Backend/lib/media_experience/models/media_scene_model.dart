class MediaSceneModel {
  const MediaSceneModel({required this.id,required this.title,this.positionSeconds=0,this.thumbnailUrl});
  final String id; final String title; final int positionSeconds; final String? thumbnailUrl;
  factory MediaSceneModel.fromJson(Map<String,dynamic> json) => MediaSceneModel(id: json['id']?.toString() ?? '', title: json['title']?.toString() ?? '', positionSeconds: (int.tryParse(json['positionSeconds']?.toString() ?? '') ?? 0).clamp(0, 2147483647), thumbnailUrl: json['thumbnailUrl']?.toString());
  Map<String,dynamic> toJson() => {'id':id,'title':title,'positionSeconds':positionSeconds,'thumbnailUrl':thumbnailUrl};
}
