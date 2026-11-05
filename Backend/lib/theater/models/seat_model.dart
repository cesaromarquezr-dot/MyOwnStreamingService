class SeatModel {
  const SeatModel({required this.id,required this.row,required this.number,this.isSelected=false,this.isAccessible=false});
  final String id; final String row; final int number; final bool isSelected; final bool isAccessible;
  factory SeatModel.fromJson(Map<String,dynamic> json) => SeatModel(id: json['id']?.toString() ?? '', row: json['row']?.toString() ?? 'A', number: int.tryParse(json['number']?.toString() ?? '') ?? 1, isSelected: json['isSelected']==true, isAccessible: json['isAccessible']==true);
  Map<String,dynamic> toJson() => {'id':id,'row':row,'number':number,'isSelected':isSelected,'isAccessible':isAccessible};
}
