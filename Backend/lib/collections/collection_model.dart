class CollectionModel {
  const CollectionModel({required this.id, required this.title, required this.kind, this.profileId = '', this.description, this.artworkUrl, this.items = const [], this.discCount = 1, this.format, this.edition, this.createdAt, this.updatedAt});
  final String id; final String title; final String kind; final String profileId; final String? description; final String? artworkUrl; final List<Map<String, dynamic>> items; final int discCount; final String? format; final String? edition; final DateTime? createdAt; final DateTime? updatedAt;
  factory CollectionModel.fromJson(Map<String, dynamic> json) => CollectionModel(id: _text(json['id']), title: _text(json['title']), kind: _text(json['kind'], 'custom'), profileId: _text(json['profileId']), description: _nullable(json['description']), artworkUrl: _nullable(json['artworkUrl']), items: _maps(json['items']), discCount: _positive(json['discCount']), format: _nullable(json['format']), edition: _nullable(json['edition']), createdAt: DateTime.tryParse(_text(json['createdAt'])), updatedAt: DateTime.tryParse(_text(json['updatedAt'])));
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'kind': kind, 'profileId': profileId, 'description': description, 'artworkUrl': artworkUrl, 'items': items, 'discCount': discCount, 'format': format, 'edition': edition, 'createdAt': createdAt?.toUtc().toIso8601String(), 'updatedAt': updatedAt?.toUtc().toIso8601String()};
}
String _text(Object? v, [String fallback = '']) => v?.toString() ?? fallback;
String? _nullable(Object? v) => v == null || v.toString().trim().isEmpty ? null : v.toString().trim();
int _positive(Object? v) { final n = int.tryParse(v?.toString() ?? '') ?? 1; return n < 1 ? 1 : n; }
List<Map<String,dynamic>> _maps(Object? v) => v is List ? v.whereType<Map>().map((m) => Map<String,dynamic>.from(m)).toList(growable: false) : const [];
