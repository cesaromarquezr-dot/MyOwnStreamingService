class MediaExtraModel {
  const MediaExtraModel({required this.id,required this.title, this.kind='other',this.description,this.durationSeconds});
  final String id; final String title; final String kind; final String? description; final int? durationSeconds;
  factory MediaExtraModel.fromJson(Map<String,dynamic> json) => MediaExtraModel(id: json['id']?.toString() ?? '', title: json['title']?.toString() ?? '', kind: json['kind']?.toString() ?? 'other', description: json['description']?.toString(), durationSeconds: int.tryParse(json['durationSeconds']?.toString() ?? ''));
  Map<String,dynamic> toJson() => {'id':id,'title':title,'kind':kind,'description':description,'durationSeconds':durationSeconds};
}
