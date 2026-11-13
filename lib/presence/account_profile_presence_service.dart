import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend_api.dart';
import '../app_core.dart';
import '../privacy_preferences.dart';

/// A fresh same-account profile presence record returned by the backend.
class AccountProfilePresence {
  const AccountProfilePresence({
    required this.profileId,
    required this.name,
    required this.presenceStatus,
    required this.activityType,
    required this.activityText,
    required this.lastSeenAt,
    this.avatarUrl,
  });

  final String profileId;
  final String name;
  final String presenceStatus;
  final String? activityType;
  final String? activityText;
  final DateTime? lastSeenAt;
  final String? avatarUrl;

  bool get isRecentlyActive {
    final seen = lastSeenAt;
    return presenceStatus == 'active' &&
        seen != null &&
        DateTime.now().toUtc().difference(seen.toUtc()) <=
            const Duration(seconds: 75);
  }

  factory AccountProfilePresence.fromJson(Map<String, dynamic> json) {
    final rawSeen = json['lastSeenAt']?.toString();
    return AccountProfilePresence(
      profileId: json['profileId']?.toString() ?? '',
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString()
          : 'Profile',
      presenceStatus: json['presenceStatus']?.toString() ?? 'away',
      activityType: json['activityType']?.toString(),
      activityText: json['activityText']?.toString(),
      lastSeenAt: rawSeen == null ? null : DateTime.tryParse(rawSeen),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}

/// Publishes a short heartbeat and reads activity for other profiles in the
/// same account. A profile is shown as active only while its heartbeat is
/// recent; an abandoned/stale presence row is not treated as live.
class AccountProfilePresenceService extends ChangeNotifier {
  AccountProfilePresenceService._();

  static final AccountProfilePresenceService instance =
      AccountProfilePresenceService._();

  static const Duration _heartbeatInterval = Duration(seconds: 20);
  static const Duration _refreshInterval = Duration(seconds: 12);

  Timer? _heartbeatTimer;
  Timer? _refreshTimer;
  String? _profileId;
  String? _activityType;
  String? _activityText;
  bool _requestInFlight = false;
  bool _refreshInFlight = false;
  bool _disposed = false;
  List<AccountProfilePresence> _profiles = const [];

  List<AccountProfilePresence> get activeProfiles =>
      List<AccountProfilePresence>.unmodifiable(
        _profiles.where((profile) => profile.isRecentlyActive),
      );

  List<AccountProfilePresence> get otherActiveProfiles =>
      List<AccountProfilePresence>.unmodifiable(
        activeProfiles.where((profile) => profile.profileId != _profileId),
      );

  /// Begin/refresh presence for the current profile and visible experience.
  void start({
    required String profileId,
    required String activityType,
    required String activityText,
  }) {
    final id = profileId.trim();
    if (id.isEmpty) return;
    final changed = _profileId != id ||
        _activityType != activityType ||
        _activityText != activityText;
    _profileId = id;
    _activityType = activityType;
    _activityText = activityText;
    _heartbeatTimer ??= Timer.periodic(_heartbeatInterval, (_) {
      unawaited(_publishHeartbeat());
    });
    _refreshTimer ??= Timer.periodic(_refreshInterval, (_) {
      unawaited(refresh());
    });
    if (changed) unawaited(_publishHeartbeat());
    unawaited(refresh());
  }

  /// Change the activity text/type without restarting the polling timers.
  void updateActivity({
    required String activityType,
    required String activityText,
  }) {
    if (_profileId == null) return;
    if (_activityType == activityType && _activityText == activityText) return;
    _activityType = activityType;
    _activityText = activityText;
    unawaited(_publishHeartbeat());
  }

  Future<void> _publishHeartbeat() async {
    final profileId = _profileId;
    final controller = AppController.instance;
    if (_requestInFlight ||
        profileId == null ||
        !controller.backendApi.isAuthenticated) {
      return;
    }
    _requestInFlight = true;
    try {
      final privacy = await PrivacyPreferencesStore.load(profileId: profileId);
      await controller.backendApi.setSocialProfilePresence(
        profileId: profileId,
        availability: privacy.sharePresence ? 'active' : 'away',
        activityType: privacy.sharePresence && privacy.shareActivity
            ? _activityType
            : null,
        activityText: privacy.sharePresence && privacy.shareActivity
            ? _activityText
            : null,
        clearActivity: !privacy.sharePresence || !privacy.shareActivity,
      );
    } catch (_) {
      // Presence is optional. Offline/backend failures must never block media.
    } finally {
      _requestInFlight = false;
    }
  }

  Future<void> refresh() async {
    final profileId = _profileId;
    final controller = AppController.instance;
    if (_refreshInFlight ||
        profileId == null ||
        !controller.backendApi.isAuthenticated) {
      return;
    }
    _refreshInFlight = true;
    try {
      final rows = await controller.backendApi.getSocialAccountProfiles(
        profileId: profileId,
      );
      final next = rows
          .map(AccountProfilePresence.fromJson)
          .where((profile) => profile.profileId.isNotEmpty)
          .toList(growable: false);
      if (_sameProfiles(_profiles, next)) {
        // Rebuild on each poll so records naturally disappear after the
        // 75-second freshness window even when the backend snapshot is static.
        if (!_disposed) notifyListeners();
        return;
      }
      _profiles = next;
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Preserve the last successful snapshot; freshness filtering expires it.
    } finally {
      _refreshInFlight = false;
    }
  }

  bool _sameProfiles(
    List<AccountProfilePresence> a,
    List<AccountProfilePresence> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.profileId != y.profileId ||
          x.name != y.name ||
          x.presenceStatus != y.presenceStatus ||
          x.activityType != y.activityType ||
          x.activityText != y.activityText ||
          x.lastSeenAt != y.lastSeenAt ||
          x.avatarUrl != y.avatarUrl) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
