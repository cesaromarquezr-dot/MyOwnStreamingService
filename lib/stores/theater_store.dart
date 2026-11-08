import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend_api.dart';
import '../app_core.dart';
import '../models/theater_models.dart';

class TheaterStore extends ChangeNotifier {
  TheaterStore._();
  static final TheaterStore instance = TheaterStore._();

  static const List<TheaterRoom> _initialRooms = <TheaterRoom>[
    TheaterRoom(id: 'room-1', name: 'Room 1', description: 'Private viewing room'),
    TheaterRoom(id: 'room-2', name: 'Room 2', description: 'Private viewing room'),
    TheaterRoom(id: 'room-3', name: 'Room 3', description: 'Private viewing room'),
    TheaterRoom(id: 'room-4', name: 'Room 4', description: 'Private viewing room'),
  ];

  List<TheaterRoom> _rooms = List<TheaterRoom>.unmodifiable(_initialRooms);
  List<TheaterSession> _sessions = const <TheaterSession>[];
  bool _loaded = false;
  bool _remoteRefreshInFlight = false;
  String? _profileId;

  List<TheaterRoom> get rooms => List<TheaterRoom>.unmodifiable(_rooms);
  List<TheaterSession> get sessions => List<TheaterSession>.unmodifiable(_sessions);
  bool get isLoaded => _loaded;

  TheaterSession? sessionForRoom(String roomId) {
    for (final session in _sessions) {
      if (session.roomId == roomId && session.isCurrent) return session;
    }
    return null;
  }

  Future<void> load(String? profileId) async {
    final normalized = (profileId ?? '').trim();
    final id = normalized.isEmpty ? 'default' : normalized;
    if (_loaded && _profileId == id) return;

    _profileId = id;
    final preferences = await SharedPreferences.getInstance();
    final savedRooms = preferences.getString(_roomsKey(id));
    final migratedRooms = preferences.getBool(_roomsMigrationKey(id)) ?? false;
    if (savedRooms == null) {
      _rooms = List<TheaterRoom>.unmodifiable(_initialRooms);
    } else {
      try {
        final decoded = jsonDecode(savedRooms);
        final parsed = decoded is List
            ? decoded
                .whereType<Map>()
                .map((row) => TheaterRoom.fromJson(Map<String, dynamic>.from(row)))
                .where((room) => room.id.isNotEmpty)
                .toList(growable: false)
            : const <TheaterRoom>[];
        final rooms = parsed.isEmpty
            ? <TheaterRoom>[..._initialRooms]
            : <TheaterRoom>[...parsed];
        // One-time migration from the former single-room theater to Room 1–4.
        if (!migratedRooms) {
          final existingIds = rooms.map((room) => room.id).toSet();
          for (final defaultRoom in _initialRooms) {
            if (existingIds.add(defaultRoom.id)) rooms.add(defaultRoom);
          }
        }
        _rooms = List<TheaterRoom>.unmodifiable(rooms);
      } on FormatException {
        _rooms = List<TheaterRoom>.unmodifiable(_initialRooms);
      }
    }
    if (!migratedRooms) {
      await preferences.setBool(_roomsMigrationKey(id), true);
      await _persistRooms();
    }

    final raw = preferences.getString(_sessionsKey(id));
    if (raw == null) {
      _sessions = const <TheaterSession>[];
    } else {
      try {
        final decoded = jsonDecode(raw);
        _sessions = decoded is List
            ? decoded
                .whereType<Map>()
                .map((row) => TheaterSession.fromJson(Map<String, dynamic>.from(row)))
                .where((session) => session.id.isNotEmpty)
                .toList(growable: false)
            : const <TheaterSession>[];
      } on FormatException {
        _sessions = const <TheaterSession>[];
      }
    }
    _loaded = true;

    final controller = AppController.instance;
    if (id != 'default' && controller.backendApi.isAuthenticated) {
      try {
        final remote = await controller.backendApi.getTheaterSessions(profileId: id);
        final merged = <String, TheaterSession>{
          for (final session in _sessions) session.id: session,
          for (final row in remote)
            if (row['id'] != null)
              row['id'].toString(): TheaterSession.fromJson(row),
        };
        _sessions = merged.values.toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _persistSessions();
      } catch (_) {
        // Local room state remains available when the optional home server is offline.
      }
    }
    notifyListeners();
  }

  /// Pulls room sessions again while the Theater dashboard is visible, so
  /// playback started on another signed-in device appears without reopening it.
  Future<void> refreshRemoteSessions() async {
    final controller = AppController.instance;
    final profileId = _profileId;
    if (_remoteRefreshInFlight || profileId == null || profileId == 'default' ||
        !controller.backendApi.isAuthenticated) {
      return;
    }
    _remoteRefreshInFlight = true;
    try {
      final remote = await controller.backendApi.getTheaterSessions(profileId: profileId);
      final merged = <String, TheaterSession>{
        for (final session in _sessions) session.id: session,
      };
      var changed = false;
      for (final row in remote) {
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final incoming = TheaterSession.fromJson(row);
        final existing = merged[id];
        final existingUpdated = existing?.updatedAt ?? existing?.createdAt;
        final incomingUpdated = incoming.updatedAt ?? incoming.createdAt;
        if (existing == null || !incomingUpdated.isBefore(existingUpdated!)) {
          if (existing == null ||
              existing.status != incoming.status ||
              existing.positionSeconds != incoming.positionSeconds ||
              existing.roomId != incoming.roomId ||
              existing.title != incoming.title) {
            changed = true;
          }
          merged[id] = incoming;
        }
      }
      if (changed) {
        _sessions = merged.values.toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _persistSessions();
        notifyListeners();
      }
    } catch (_) {
      // The local room dashboard remains usable when the home server is offline.
    } finally {
      _remoteRefreshInFlight = false;
    }
  }

  Future<TheaterRoom> addRoom({String? name}) async {
    await load(AppController.instance.currentProfile?.id);
    final trimmed = name?.trim();
    final room = TheaterRoom(
      id: 'room-${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed == null || trimmed.isEmpty ? 'Room ${_rooms.length + 1}' : trimmed,
      description: 'Private viewing room',
    );
    _rooms = List<TheaterRoom>.unmodifiable(<TheaterRoom>[..._rooms, room]);
    await _persistRooms();
    notifyListeners();
    return room;
  }

  Future<void> renameRoom(String roomId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _rooms = List<TheaterRoom>.unmodifiable(_rooms.map((room) =>
        room.id == roomId
            ? TheaterRoom(
                id: room.id,
                name: trimmed,
                description: room.description,
                rows: room.rows,
                seatsPerRow: room.seatsPerRow,
                deviceName: room.deviceName,
              )
            : room));
    await _persistRooms();
    notifyListeners();
  }

  Future<void> removeRoom(String roomId) async {
    if (_rooms.length <= 1) return;
    _rooms = List<TheaterRoom>.unmodifiable(
      _rooms.where((room) => room.id != roomId),
    );
    final stoppedSessions = <TheaterSession>[];
    _sessions = _sessions.map((session) {
      if (session.roomId != roomId || !session.isCurrent) return session;
      final stopped = session.copyWith(status: 'stopped');
      stoppedSessions.add(stopped);
      return stopped;
    }).toList(growable: false);
    await _persistAll();
    for (final session in stoppedSessions) {
      unawaited(_syncRemoteSession(session));
    }
    notifyListeners();
  }

  Future<TheaterSession> createSession({
    required String mediaId,
    required String title,
    Set<String> seatIds = const <String>{},
    String roomId = 'room-1',
    String? subtitle,
  }) async {
    final controller = AppController.instance;
    final profileId = controller.currentProfile?.id;
    await load(profileId);

    final now = DateTime.now();
    final session = TheaterSession(
      id: 'home-${now.microsecondsSinceEpoch}',
      mediaId: mediaId,
      title: title,
      roomId: roomId,
      createdAt: now,
      seatIds: seatIds.toList()..sort(),
      status: 'ready',
      subtitle: subtitle,
      updatedAt: now,
    );

    _sessions = <TheaterSession>[
      session,
      for (final item in _sessions)
        if (item.roomId != roomId) item
        else if (item.isCurrent) item.copyWith(status: 'stopped')
        else item,
    ].take(40).toList(growable: false);
    await _persistSessions();
    notifyListeners();

    if (profileId != null && profileId.trim().isNotEmpty &&
        controller.backendApi.isAuthenticated) {
      try {
        final remote = await controller.backendApi.createTheaterSession(
          profileId: profileId,
          mediaId: mediaId,
          title: title,
          seatIds: session.seatIds,
          roomId: roomId,
        );
        final remoteSession = TheaterSession.fromJson(remote);
        _sessions = _sessions
            .map((item) => item.id == session.id
                ? remoteSession.copyWith(status: 'ready', subtitle: subtitle)
                : item)
            .toList(growable: false);
        await _persistSessions();
        notifyListeners();
        return _sessions.firstWhere((item) => item.roomId == roomId && item.mediaId == mediaId);
      } catch (_) {
        // Local room session remains usable when remote theater sync is offline.
      }
    }
    return session;
  }

  Future<void> updatePlaybackState({
    required String roomId,
    required String mediaId,
    required String status,
    double? positionSeconds,
  }) async {
    final allowed = <String>{'starting', 'playing', 'previewing', 'paused', 'stopped', 'completed', 'error'};
    if (!allowed.contains(status)) return;
    var changed = false;
    TheaterSession? updated;
    _sessions = _sessions.map((session) {
      if (session.roomId != roomId || session.mediaId != mediaId || !session.isCurrent) {
        return session;
      }
      changed = true;
      updated = session.copyWith(
        status: status,
        positionSeconds: positionSeconds,
        updatedAt: DateTime.now(),
      );
      return updated!;
    }).toList(growable: false);
    if (!changed) return;
    await _persistSessions();
    notifyListeners();
    if (updated != null) unawaited(_syncRemoteSession(updated!));
  }

  Future<void> _syncRemoteSession(TheaterSession session) async {
    final controller = AppController.instance;
    final profileId = _profileId;
    if (profileId == null || profileId == 'default' || !controller.backendApi.isAuthenticated) return;
    // Local fallback IDs are not addressable on the backend.
    if (!session.id.startsWith('exp_') && !session.id.startsWith('theater_')) return;
    try {
      await controller.backendApi.updateTheaterSession(
        profileId: profileId,
        sessionId: session.id,
        mediaId: session.mediaId,
        title: session.title,
        roomId: session.roomId,
        seatIds: session.seatIds,
        status: session.status,
        positionSeconds: session.positionSeconds,
        subtitle: session.subtitle,
      );
    } catch (_) {
      // The local dashboard remains usable when the optional home server is offline.
    }
  }

  Future<void> markMediaPlaybackState({
    required String mediaId,
    required String status,
    double? positionSeconds,
  }) async {
    final roomsForMedia = _sessions
        .where((session) => session.mediaId == mediaId && session.isCurrent)
        .toList(growable: false);
    for (final session in roomsForMedia) {
      await updatePlaybackState(
        roomId: session.roomId,
        mediaId: mediaId,
        status: status,
        positionSeconds: positionSeconds,
      );
    }
  }

  Future<void> markCompleted(String id) async {
    _sessions = _sessions
        .map((session) => session.id == id
            ? session.copyWith(status: 'completed')
            : session)
        .toList(growable: false);
    await _persistSessions();
    notifyListeners();
  }

  Future<void> _persistAll() async {
    await _persistRooms();
    await _persistSessions();
  }

  Future<void> _persistRooms() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _roomsKey(_profileId ?? 'default'),
      jsonEncode(_rooms.map((room) => room.toJson()).toList()),
    );
  }

  Future<void> _persistSessions() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _sessionsKey(_profileId ?? 'default'),
      jsonEncode(_sessions.map((session) => session.toJson()).toList()),
    );
  }

  String _roomsKey(String id) => 'private_theater_rooms_$id';
  String _roomsMigrationKey(String id) => 'private_theater_rooms_migrated_v2_$id';
  String _sessionsKey(String id) => 'private_theater_sessions_$id';
}
