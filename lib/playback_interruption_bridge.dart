import 'package:flutter/foundation.dart';

/// Controls only a player instance that explicitly attaches itself in-process.
/// This bridge never searches for or controls unrelated apps or system playback.
class PlaybackInterruptionBridge {
  PlaybackInterruptionBridge._();

  static Object? _owner;
  static String? currentTitle;
  static VoidCallback? _pause;
  static VoidCallback? _resume;
  static VoidCallback? _savePosition;

  static bool get isConnected => _owner != null && _pause != null;

  static void attach({
    required Object owner,
    required String title,
    required VoidCallback pause,
    required VoidCallback resume,
    required VoidCallback savePosition,
  }) {
    _owner = owner;
    currentTitle = title;
    _pause = pause;
    _resume = resume;
    _savePosition = savePosition;
  }

  static void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    currentTitle = null;
    _pause = null;
    _resume = null;
    _savePosition = null;
  }

  static bool pauseNow() {
    final action = _pause;
    if (action == null) return false;
    action();
    return true;
  }

  static bool resumeNow() {
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
}
