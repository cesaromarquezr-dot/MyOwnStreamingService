import 'package:flutter/foundation.dart';

@immutable
class TheaterSeat {
  const TheaterSeat({
    required this.id,
    required this.row,
    required this.number,
    this.isAvailable = true,
    this.isAccessible = false,
  });

  final String id;
  final String row;
  final int number;
  final bool isAvailable;
  final bool isAccessible;

  String get label => '$row$number';
}

/// A named playback destination in the household's private theater.
///
/// The legacy seat dimensions are retained so older saved theater data still
/// deserializes, but the current room dashboard does not use ticket/seat flows.
@immutable
class TheaterRoom {
  const TheaterRoom({
    required this.id,
    required this.name,
    this.rows = 4,
    this.seatsPerRow = 6,
    this.description = 'Your private home theater',
    this.deviceName,
  });

  final String id;
  final String name;
  final int rows;
  final int seatsPerRow;
  final String description;
  final String? deviceName;

  List<TheaterSeat> get seats => List<TheaterSeat>.generate(
        rows * seatsPerRow,
        (index) {
          final row = String.fromCharCode(65 + index ~/ seatsPerRow);
          final number = index % seatsPerRow + 1;
          return TheaterSeat(
            id: '$id-$row$number',
            row: row,
            number: number,
          );
        },
        growable: false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'rows': rows,
        'seatsPerRow': seatsPerRow,
        'description': description,
        'deviceName': deviceName,
      };

  factory TheaterRoom.fromJson(Map<String, dynamic> json) => TheaterRoom(
        id: json['id']?.toString() == 'main-room'
            ? 'room-1'
            : (json['id']?.toString() ?? ''),
        name: json['name']?.toString().trim().isNotEmpty == true
            ? json['name'].toString()
            : 'Theater Room',
        rows: json['rows'] is num ? (json['rows'] as num).toInt() : 4,
        seatsPerRow: json['seatsPerRow'] is num
            ? (json['seatsPerRow'] as num).toInt()
            : 6,
        description: json['description']?.toString() ?? 'Your private home theater',
        deviceName: json['deviceName']?.toString(),
      );
}

@immutable
class TheaterShowtime {
  const TheaterShowtime({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.startsAt,
    this.durationMinutes,
    this.roomId = 'room-1',
    this.posterUrl,
  });

  final String id;
  final String mediaId;
  final String title;
  final DateTime startsAt;
  final int? durationMinutes;
  final String roomId;
  final String? posterUrl;

  bool get isStarted => !startsAt.isAfter(DateTime.now());
}

@immutable
class TheaterSession {
  const TheaterSession({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.roomId,
    required this.createdAt,
    this.seatIds = const <String>[],
    this.status = 'ready',
    this.subtitle,
    this.positionSeconds = 0,
    this.updatedAt,
  });

  final String id;
  final String mediaId;
  final String title;
  final String roomId;
  final DateTime createdAt;
  final List<String> seatIds;
  /// starting, playing, previewing, paused, ready, stopped, completed, or error.
  final String status;
  final String? subtitle;
  final double positionSeconds;
  final DateTime? updatedAt;

  bool get isCurrent =>
      status == 'starting' ||
      status == 'playing' ||
      status == 'previewing' ||
      status == 'paused' ||
      status == 'ready' ||
      status == 'error';

  TheaterSession copyWith({
    String? status,
    String? subtitle,
    double? positionSeconds,
    DateTime? updatedAt,
  }) =>
      TheaterSession(
        id: id,
        mediaId: mediaId,
        title: title,
        roomId: roomId,
        createdAt: createdAt,
        seatIds: seatIds,
        status: status ?? this.status,
        subtitle: subtitle ?? this.subtitle,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'mediaId': mediaId,
        'title': title,
        'roomId': roomId,
        'createdAt': createdAt.toIso8601String(),
        'seatIds': seatIds,
        'status': status,
        'subtitle': subtitle,
        'positionSeconds': positionSeconds,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory TheaterSession.fromJson(Map<String, dynamic> json) => TheaterSession(
        id: json['id']?.toString() ?? '',
        mediaId: json['mediaId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        roomId: (json['roomId']?.toString() == 'main-room')
            ? 'room-1'
            : (json['roomId']?.toString() ?? 'room-1'),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        seatIds: (json['seatIds'] as List? ?? const <dynamic>[])
            .map((value) => value.toString())
            .toList(growable: false),
        status: json['status']?.toString() ?? 'ready',
        subtitle: json['subtitle']?.toString(),
        positionSeconds: json['positionSeconds'] is num
            ? (json['positionSeconds'] as num).toDouble()
            : 0,
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );
}
