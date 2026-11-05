import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend_api.dart';

import '../app_core.dart';
import '../models/theater_models.dart';

class TheaterStore extends ChangeNotifier {
  TheaterStore._();
  static final TheaterStore instance = TheaterStore._();

  static const TheaterRoom defaultRoom = TheaterRoom(
    id: 'main-room',
    name: 'Private Theater',
    rows: 4,
    seatsPerRow: 6,
  );

  List<TheaterSession> _sessions = const [];
  bool _loaded = false;
  String? _profileId;

  List<TheaterSession> get sessions => List.unmodifiable(_sessions);
  bool get isLoaded => _loaded;

  Future<void> load(String? profileId) async {
    final normalized = (profileId ?? '').trim();
    final id = normalized.isEmpty ? 'default' : normalized;
    if (_loaded && _profileId == id) return;

    _profileId = id;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(id));
    if (raw == null) {
      _sessions = const [];
    } else {
      try {
        final decoded = jsonDecode(raw);
        _sessions = decoded is List
            ? decoded
                .whereType<Map>()
                .map((row) => TheaterSession.fromJson(
                    Map<String, dynamic>.from(row)))
                .toList(growable: false)
            : const [];
      } on FormatException {
        _sessions = const [];
      }
    }
    _loaded = true;

    final controller = AppController.instance;
    if (id != 'default' && controller.backendApi.isAuthenticated) {
      try {
        final remote = await controller.backendApi.getTheaterSessions(
          profileId: id,
        );
        final merged = <String, TheaterSession>{
          for (final session in _sessions) session.id: session,
          for (final row in remote)
            if (row['id'] != null)
              row['id'].toString(): TheaterSession.fromJson(row),
        };
        _sessions = merged.values.toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _persist();
      } catch (_) {
        // Local preferences remain usable when the home server is offline.
      }
    }
    notifyListeners();
  }

  Future<TheaterSession> createSession({
    required String mediaId,
    required String title,
    Set<String> seatIds = const {},
    String roomId = 'main-room',
  }) async {
    final controller = AppController.instance;
    final profileId = controller.currentProfile?.id;
    await load(profileId);

    final now = DateTime.now();
    var session = TheaterSession(
      id: 'home-${now.microsecondsSinceEpoch}',
      mediaId: mediaId,
      title: title,
      roomId: roomId,
      createdAt: now,
      seatIds: seatIds.toList()..sort(),
    );

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
        session = TheaterSession.fromJson(remote);
      } catch (_) {
        // A failed sync must not block a private screening on the local device.
      }
    }

    _sessions = [session, ..._sessions.where((item) => item.mediaId != mediaId)]
        .take(30)
        .toList(growable: false);
    await _persist();
    notifyListeners();
    return session;
  }

  Future<void> markCompleted(String id) async {
    _sessions = _sessions
        .map((session) => session.id == id
            ? TheaterSession(
                id: session.id,
                mediaId: session.mediaId,
                title: session.title,
                roomId: session.roomId,
                createdAt: session.createdAt,
                seatIds: session.seatIds,
                status: 'completed',
              )
            : session)
        .toList(growable: false);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(_profileId ?? 'default'),
      jsonEncode(_sessions.map((session) => session.toJson()).toList()),
    );
  }

  String _key(String id) => 'private_theater_sessions_$id';
}
