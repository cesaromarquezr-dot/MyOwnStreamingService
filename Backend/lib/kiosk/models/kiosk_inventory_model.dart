class KioskInventoryModel {
  const KioskInventoryModel({required this.mediaId, required this.title, required this.mediaType, this.artworkUrl, this.isOwned = true, this.isFavorite = false, this.lastPlayedAt});
  final String mediaId; final String title; final String mediaType; final String? artworkUrl; final bool isOwned; final bool isFavorite; final DateTime? lastPlayedAt;
  factory KioskInventoryModel.fromJson(Map<String,dynamic> json) => KioskInventoryModel(mediaId: json['mediaId']?.toString() ?? '', title: json['title']?.toString() ?? '', mediaType: json['mediaType']?.toString() ?? 'other', artworkUrl: json['artworkUrl']?.toString(), isOwned: json['isOwned'] != false, isFavorite: json['isFavorite'] == true, lastPlayedAt: DateTime.tryParse(json['lastPlayedAt']?.toString() ?? ''));
  Map<String,dynamic> toJson() => {'mediaId': mediaId, 'title': title, 'mediaType': mediaType, 'artworkUrl': artworkUrl, 'isOwned': isOwned, 'isFavorite': isFavorite, 'lastPlayedAt': lastPlayedAt?.toUtc().toIso8601String()};
}
