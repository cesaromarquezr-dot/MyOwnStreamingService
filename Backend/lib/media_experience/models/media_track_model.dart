class MediaTrackModel {
  const MediaTrackModel({required this.id,required this.label,this.language,this.codec,this.isCommentary=false,this.isDefault=false});
  final String id; final String label; final String? language; final String? codec; final bool isCommentary; final bool isDefault;
  factory MediaTrackModel.fromJson(Map<String,dynamic> json) => MediaTrackModel(id: json['id']?.toString() ?? '', label: json['label']?.toString() ?? '', language: json['language']?.toString(), codec: json['codec']?.toString(), isCommentary: json['isCommentary']==true, isDefault: json['isDefault']==true);
  Map<String,dynamic> toJson() => {'id':id,'label':label,'language':language,'codec':codec,'isCommentary':isCommentary,'isDefault':isDefault};
}
