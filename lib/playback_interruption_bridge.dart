import 'package:flutter/foundation.dart';

/// Controls only a player instance that explicitly attaches itself in-process.
/// This bridge never searches for or controls unrelated apps or system playback.
class PlaybackInterruptionBridge {
  PlaybackInterruptionBridge._();

  static Object? _owner;
  static String? currentTitle;
  static String? currentRoomId;
  static VoidCallback? _pause;
  static VoidCallback? _resume;
  static VoidCallback? _savePosition;
  static VoidCallback? _stop;

  static bool get isConnected => _owner != null && _pause != null;

  static void attach({
    required Object owner,
    required String title,
    required VoidCallback pause,
    required VoidCallback resume,
    required VoidCallback savePosition,
    String? roomId,
    VoidCallback? stop,
  }) {
    _owner = owner;
    currentTitle = title;
    currentRoomId = roomId;
    _pause = pause;
    _resume = resume;
    _savePosition = savePosition;
    _stop = stop;
  }

  static void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    currentTitle = null;
    currentRoomId = null;
    _pause = null;
    _resume = null;
    _savePosition = null;
    _stop = null;
  }

  static bool pauseNow({String? roomId}) {
    if (roomId != null && currentRoomId != roomId) return false;
    final action = _pause;
    if (action == null) return false;
    action();
    return true;
  }

  static bool resumeNow({String? roomId}) {
    if (roomId != null && currentRoomId != roomId) return false;
    final action = _resume;
    if (action == null) return false;
    action();
    return true;
  }

  static bool savePosition() {
    final action = _savePosition;
    if (action == null) return false;
    action();
    return true;
  }

  static bool stopNow({String? roomId}) {
    if (roomId != null && currentRoomId != roomId) return false;
    final action = _stop;
    if (action == null) return false;
    action();
    return true;
  }
}
