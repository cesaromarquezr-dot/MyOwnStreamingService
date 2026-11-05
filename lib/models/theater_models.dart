import 'package:flutter/foundation.dart';

@immutable
class TheaterSeat {
  const TheaterSeat({required this.id, required this.row, required this.number, this.isAvailable = true, this.isAccessible = false});
  final String id; final String row; final int number; final bool isAvailable; final bool isAccessible;
  String get label => '$row$number';
}

@immutable
class TheaterRoom {
  const TheaterRoom({required this.id, required this.name, this.rows = 4, this.seatsPerRow = 6, this.description = 'Your private home theater'});
  final String id; final String name; final int rows; final int seatsPerRow; final String description;
  List<TheaterSeat> get seats => List<TheaterSeat>.generate(rows * seatsPerRow, (i) {
    final row = String.fromCharCode(65 + i ~/ seatsPerRow); final number = i % seatsPerRow + 1;
    return TheaterSeat(id: '$id-$row$number', row: row, number: number);
  }, growable: false);
}

@immutable
class TheaterShowtime {
  const TheaterShowtime({required this.id, required this.mediaId, required this.title, required this.startsAt, this.durationMinutes, this.roomId = 'main-room', this.posterUrl});
  final String id; final String mediaId; final String title; final DateTime startsAt; final int? durationMinutes; final String roomId; final String? posterUrl;
  bool get isStarted => !startsAt.isAfter(DateTime.now());
}

@immutable
class TheaterSession {
  const TheaterSession({required this.id, required this.mediaId, required this.title, required this.roomId, required this.createdAt, this.seatIds = const [], this.status = 'ready'});
  final String id; final String mediaId; final String title; final String roomId; final DateTime createdAt; final List<String> seatIds; final String status;
  Map<String, dynamic> toJson() => {'id': id, 'mediaId': mediaId, 'title': title, 'roomId': roomId, 'createdAt': createdAt.toIso8601String(), 'seatIds': seatIds, 'status': status};
  factory TheaterSession.fromJson(Map<String, dynamic> json) => TheaterSession(id: json['id']?.toString() ?? '', mediaId: json['mediaId']?.toString() ?? '', title: json['title']?.toString() ?? '', roomId: json['roomId']?.toString() ?? 'main-room', createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(), seatIds: (json['seatIds'] as List? ?? const []).map((v) => v.toString()).toList(), status: json['status']?.toString() ?? 'ready');
}
