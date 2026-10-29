import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_core.dart';

/// App-wide energy profile. These choices reduce avoidable work; they cannot
/// measure actual device wattage or control hardware power limits directly.
enum EnergySaverMode { eco, balanced, cinema }

class EnergySaverController extends ChangeNotifier with WidgetsBindingObserver {
  EnergySaverController._();

  static final EnergySaverController instance = EnergySaverController._();

  static const String _storagePrefix = 'moss_energy_saver_v1_';
  String _profileScope = '';
  Future<void>? _pendingLoad;
  String? _loadingScope;
  bool _observerRegistered = false;
  bool _loaded = false;

  EnergySaverMode _mode = EnergySaverMode.eco;
  bool _autoPlayHeroPreviews = false;
  bool _hoverVideoPreviews = true;
  bool _pauseWhenAppHidden = true;
  bool _pauseInactivePageWork = true;
  bool _lowPowerArtworkLoading = true;
  bool _reduceAnimations = false;
  bool _preferDirectPlay = true;
  bool _cacheArtwork = true;
  // OLED/AMOLED panels can use less display power with genuinely black pixels.
  // This is a visual preference; it does not control device hardware.
  bool _oledBlackTheme = true;
  double _estimatedDeviceWatts = 100;
  double _hoursPerDay = 6;
  double _electricityRate = 0.15;

  bool _appIsForeground = true;
  String _activePage = 'home';
  int _heroPreviewStarts = 0;
  int _artworkLookupsStarted = 0;
  int _artworkCacheHits = 0;
  int _backgroundTasksSkipped = 0;
  int _backgroundPauseTransitions = 0;
  int _pageEntries = 0;
  DateTime? _sessionStartedAt;
  DateTime? _lastPageChangedAt;

  EnergySaverMode get mode => _mode;
  bool get autoPlayHeroPreviews => _autoPlayHeroPreviews;
  bool get hoverVideoPreviews => _hoverVideoPreviews;
  bool get pauseWhenAppHidden => _pauseWhenAppHidden;
  bool get pauseInactivePageWork => _pauseInactivePageWork;
  bool get lowPowerArtworkLoading => _lowPowerArtworkLoading;
  bool get reduceAnimations => _reduceAnimations;
  bool get preferDirectPlay => _preferDirectPlay;
  bool get cacheArtwork => _cacheArtwork;
  bool get oledBlackTheme => _oledBlackTheme;
  bool get appIsForeground => _appIsForeground;
  String get activePage => _activePage;
  bool get isLoaded => _loaded;
  int get heroPreviewStarts => _heroPreviewStarts;
  int get artworkLookupsStarted => _artworkLookupsStarted;
  int get artworkCacheHits => _artworkCacheHits;
  int get backgroundTasksSkipped => _backgroundTasksSkipped;
  int get backgroundPauseTransitions => _backgroundPauseTransitions;
  int get pageEntries => _pageEntries;
  DateTime? get sessionStartedAt => _sessionStartedAt;
  DateTime? get lastPageChangedAt => _lastPageChangedAt;
  double get estimatedDeviceWatts => _estimatedDeviceWatts;
  double get hoursPerDay => _hoursPerDay;
  double get electricityRate => _electricityRate;
  double get estimatedMonthlyKwh =>
      (_estimatedDeviceWatts / 1000) * _hoursPerDay * 30;
  double get estimatedMonthlyCost => estimatedMonthlyKwh * _electricityRate;

  Duration get hoverPreviewDelay => switch (_mode) {
        EnergySaverMode.eco => const Duration(milliseconds: 1400),
        EnergySaverMode.balanced => const Duration(milliseconds: 900),
        EnergySaverMode.cinema => const Duration(milliseconds: 250),
      };

  String get modeLabel => switch (_mode) {
        EnergySaverMode.eco => 'Eco',
        EnergySaverMode.balanced => 'Balanced',
        EnergySaverMode.cinema => 'Cinema',
      };

  /// Backend heartbeat cadence while video playback is active. Eco avoids
  /// redundant progress writes; pause/seek/completion still sync immediately.
  Duration get playbackSessionSyncInterval => switch (_mode) {
        EnergySaverMode.eco => const Duration(seconds: 60),
        EnergySaverMode.balanced => const Duration(seconds: 30),
        EnergySaverMode.cinema => const Duration(seconds: 15),
      };

  /// Throttle player-driven UI rebuilds in low-work mode without affecting
  /// direct user interactions such as seeking or pressing pause.
  Duration get playbackUiRefreshInterval => switch (_mode) {
        EnergySaverMode.eco => const Duration(milliseconds: 900),
        EnergySaverMode.balanced => const Duration(milliseconds: 500),
        EnergySaverMode.cinema => const Duration(milliseconds: 300),
      };

  /// Local continue-watching progress is saved less often in Eco mode; the
  /// player's final position is still saved when playback closes.
  Duration get playbackProgressSaveInterval => switch (_mode) {
        EnergySaverMode.eco => const Duration(seconds: 15),
        EnergySaverMode.balanced => const Duration(seconds: 10),
        EnergySaverMode.cinema => const Duration(seconds: 10),
      };

  /// Scan optional intro/credit markers less frequently in low-work mode.
  Duration get playbackMarkerScanInterval => switch (_mode) {
        EnergySaverMode.eco => const Duration(milliseconds: 900),
        EnergySaverMode.balanced => const Duration(milliseconds: 400),
        EnergySaverMode.cinema => const Duration(milliseconds: 150),
      };

  /// Batch watch-time telemetry less frequently in Eco to reduce writes.
  Duration get watchTimeBatchInterval => switch (_mode) {
        EnergySaverMode.eco => const Duration(seconds: 60),
        EnergySaverMode.balanced => const Duration(seconds: 45),
        EnergySaverMode.cinema => const Duration(seconds: 30),
      };

  Future<void> ensureLoaded({String? profileId}) async {
    final scope = _scopeFor(profileId ?? (_profileScope.isEmpty ? AppController.instance.currentProfile?.id : _profileScope));
    if (_loaded && _profileScope == scope) return;
    if (_pendingLoad != null) {
      await _pendingLoad;
      if (_loaded && _profileScope == scope) return;
    }
    if (_loadingScope == scope && _pendingLoad != null) {
      await _pendingLoad;
      return;
    }
    _loadingScope = scope;
    final future = _load(scope);
    _pendingLoad = future;
    try {
      await future;
    } finally {
      if (identical(_pendingLoad, future)) _pendingLoad = null;
      _loadingScope = null;
    }
  }

  Future<void> _load(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storagePrefix$scope');
    _profileScope = scope;
    _mode = EnergySaverMode.eco;
    _oledBlackTheme = true;
    _applyModeDefaults(EnergySaverMode.eco);
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _mode = EnergySaverMode.values.firstWhere(
          (mode) => mode.name == data['mode'],
          orElse: () => EnergySaverMode.eco,
        );
        _applyModeDefaults(_mode);
        _autoPlayHeroPreviews = data['autoPlayHeroPreviews'] as bool? ?? _autoPlayHeroPreviews;
        _hoverVideoPreviews = data['hoverVideoPreviews'] as bool? ?? _hoverVideoPreviews;
        _pauseWhenAppHidden = data['pauseWhenAppHidden'] as bool? ?? _pauseWhenAppHidden;
        _pauseInactivePageWork = data['pauseInactivePageWork'] as bool? ?? _pauseInactivePageWork;
        _lowPowerArtworkLoading = data['lowPowerArtworkLoading'] as bool? ?? _lowPowerArtworkLoading;
        _reduceAnimations = data['reduceAnimations'] as bool? ?? _reduceAnimations;
        _preferDirectPlay = data['preferDirectPlay'] as bool? ?? _preferDirectPlay;
        _cacheArtwork = data['cacheArtwork'] as bool? ?? _cacheArtwork;
        _oledBlackTheme = data['oledBlackTheme'] as bool? ?? _oledBlackTheme;
        _estimatedDeviceWatts = _number(data['estimatedDeviceWatts'], 100).clamp(1, 3000).toDouble();
        _hoursPerDay = _number(data['hoursPerDay'], 6).clamp(0, 24).toDouble();
        _electricityRate = _number(data['electricityRate'], 0.15).clamp(0, 10).toDouble();
      } catch (_) {
        // Invalid local preferences are optional; use the low-power Eco defaults.
      }
    }
    _loaded = true;
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
    _sessionStartedAt ??= DateTime.now();
    notifyListeners();
  }

  static double _number(Object? value, double fallback) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

  static String _scopeFor(String? profileId) {
    final id = profileId?.trim() ?? '';
    if (id.isEmpty) return 'guest';
    return id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  void _applyModeDefaults(EnergySaverMode mode) {
    switch (mode) {
      case EnergySaverMode.eco:
        _autoPlayHeroPreviews = false;
        _hoverVideoPreviews = false;
        _pauseWhenAppHidden = true;
        _pauseInactivePageWork = true;
        _lowPowerArtworkLoading = true;
        _reduceAnimations = true;
        _preferDirectPlay = true;
        _cacheArtwork = true;
        break;
      case EnergySaverMode.balanced:
        _autoPlayHeroPreviews = false;
        _hoverVideoPreviews = true;
        _pauseWhenAppHidden = true;
        _pauseInactivePageWork = true;
        _lowPowerArtworkLoading = true;
        _reduceAnimations = false;
        _preferDirectPlay = true;
        _cacheArtwork = true;
        break;
      case EnergySaverMode.cinema:
        _autoPlayHeroPreviews = true;
        _hoverVideoPreviews = true;
        _pauseWhenAppHidden = true;
        _pauseInactivePageWork = true;
        _lowPowerArtworkLoading = false;
        _reduceAnimations = false;
        _preferDirectPlay = true;
        _cacheArtwork = true;
        break;
    }
  }

  Future<void> setMode(EnergySaverMode mode) async {
    await ensureLoaded();
    _mode = mode;
    _applyModeDefaults(mode);
    await _save();
    notifyListeners();
  }

  Future<void> setOptions({
    bool? autoPlayHeroPreviews,
    bool? hoverVideoPreviews,
    bool? pauseWhenAppHidden,
    bool? pauseInactivePageWork,
    bool? lowPowerArtworkLoading,
    bool? reduceAnimations,
    bool? preferDirectPlay,
    bool? cacheArtwork,
    bool? oledBlackTheme,
  }) async {
    await ensureLoaded();
    _autoPlayHeroPreviews = autoPlayHeroPreviews ?? _autoPlayHeroPreviews;
    _hoverVideoPreviews = hoverVideoPreviews ?? _hoverVideoPreviews;
    _pauseWhenAppHidden = pauseWhenAppHidden ?? _pauseWhenAppHidden;
    _pauseInactivePageWork = pauseInactivePageWork ?? _pauseInactivePageWork;
    _lowPowerArtworkLoading = lowPowerArtworkLoading ?? _lowPowerArtworkLoading;
    _reduceAnimations = reduceAnimations ?? _reduceAnimations;
    _preferDirectPlay = preferDirectPlay ?? _preferDirectPlay;
    _cacheArtwork = cacheArtwork ?? _cacheArtwork;
    _oledBlackTheme = oledBlackTheme ?? _oledBlackTheme;
    await _save();
    notifyListeners();
  }

  Future<void> setPowerEstimate({
    double? watts,
    double? hoursPerDay,
    double? rate,
  }) async {
    await ensureLoaded();
    _estimatedDeviceWatts = (watts ?? _estimatedDeviceWatts).clamp(1, 3000).toDouble();
    _hoursPerDay = (hoursPerDay ?? _hoursPerDay).clamp(0, 24).toDouble();
    _electricityRate = (rate ?? _electricityRate).clamp(0, 10).toDouble();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _profileScope.isEmpty ? 'guest' : _profileScope;
    await prefs.setString('$_storagePrefix$scope', jsonEncode(<String, Object>{
      'mode': _mode.name,
      'autoPlayHeroPreviews': _autoPlayHeroPreviews,
      'hoverVideoPreviews': _hoverVideoPreviews,
      'pauseWhenAppHidden': _pauseWhenAppHidden,
      'pauseInactivePageWork': _pauseInactivePageWork,
      'lowPowerArtworkLoading': _lowPowerArtworkLoading,
      'reduceAnimations': _reduceAnimations,
      'preferDirectPlay': _preferDirectPlay,
      'cacheArtwork': _cacheArtwork,
      'oledBlackTheme': _oledBlackTheme,
      'estimatedDeviceWatts': _estimatedDeviceWatts,
      'hoursPerDay': _hoursPerDay,
      'electricityRate': _electricityRate,
    }));
  }

  Future<void> pageChanged(String pageId, {String? profileId}) async {
    await ensureLoaded(profileId: profileId);
    final next = pageId.trim().isEmpty ? 'home' : pageId;
    if (_activePage == next) return;
    _activePage = next;
    _pageEntries++;
    _lastPageChangedAt = DateTime.now();
    notifyListeners();
  }

  bool allowsHeroPreview({bool fromHover = false, bool userInitiated = false}) {
    if (!_appIsForeground && _pauseWhenAppHidden) return false;
    if (userInitiated) return true;
    if (fromHover) return _hoverVideoPreviews;
    return _autoPlayHeroPreviews;
  }

  bool canRunBackgroundWork({String? pageId}) {
    if (!_appIsForeground && _pauseWhenAppHidden) return false;
    if (pageId != null && _pauseInactivePageWork && pageId != _activePage) {
      return false;
    }
    return true;
  }

  void _notifyMetricIfVisible() {
    // Avoid forcing the entire app shell to rebuild for every image request.
    // Session metrics refresh live only while their dashboard is visible.
    if (_activePage == 'power-performance') notifyListeners();
  }

  void recordHeroPreviewStart() {
    _heroPreviewStarts++;
    _notifyMetricIfVisible();
  }

  void recordArtworkLookup({required bool cacheHit}) {
    if (cacheHit) {
      _artworkCacheHits++;
    } else {
      _artworkLookupsStarted++;
    }
    _notifyMetricIfVisible();
  }

  void recordBackgroundTaskSkipped() {
    _backgroundTasksSkipped++;
    _notifyMetricIfVisible();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_appIsForeground == foreground) return;
    _appIsForeground = foreground;
    if (!foreground) _backgroundPauseTransitions++;
    notifyListeners();
  }

  void resetSessionMetrics() {
    _heroPreviewStarts = 0;
    _artworkLookupsStarted = 0;
    _artworkCacheHits = 0;
    _backgroundTasksSkipped = 0;
    _backgroundPauseTransitions = 0;
    _pageEntries = 0;
    _sessionStartedAt = DateTime.now();
    _lastPageChangedAt = null;
    _notifyMetricIfVisible();
  }

  Map<String, int> get sessionMetrics => <String, int>{
        'Hero previews started': _heroPreviewStarts,
        'Artwork lookups started': _artworkLookupsStarted,
        'Artwork cache hits': _artworkCacheHits,
        'Background tasks skipped': _backgroundTasksSkipped,
        'App background transitions': _backgroundPauseTransitions,
        'Page entries': _pageEntries,
      };

  @override
  void dispose() {
    if (_observerRegistered) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
