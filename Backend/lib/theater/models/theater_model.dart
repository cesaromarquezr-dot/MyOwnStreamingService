class TheaterModel {
  const TheaterModel({required this.id,required this.name,this.rows=4,this.seatsPerRow=6,this.isDefault=false});
  final String id; final String name; final int rows; final int seatsPerRow; final bool isDefault;
  factory TheaterModel.fromJson(Map<String,dynamic> json) => TheaterModel(id: json['id']?.toString() ?? '', name: json['name']?.toString() ?? 'Private Theater', rows: (int.tryParse(json['rows']?.toString() ?? '') ?? 4).clamp(1,12), seatsPerRow: (int.tryParse(json['seatsPerRow']?.toString() ?? '') ?? 6).clamp(1,16), isDefault: json['isDefault']==true);
  Map<String,dynamic> toJson() => {'id':id,'name':name,'rows':rows,'seatsPerRow':seatsPerRow,'isDefault':isDefault};
}
