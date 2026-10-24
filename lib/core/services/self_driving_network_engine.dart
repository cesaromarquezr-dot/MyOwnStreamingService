/// Self-driving networking controls for the app's HTTP API client.
///
/// The first implementation learns from real request timings and outcomes,
/// adapts bounded response-header timeouts for safe reads, and retries only
/// body-less GET/HEAD requests.
/// It deliberately does not change router, firewall, account, or host settings.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_bot_activity_service.dart';

enum NetworkAutomationMode { automatic, observeOnly, paused }

/// Application-level intent profiles; they do not configure physical network gear.
enum NetworkIntentProfile { balanced, streamingPriority, lowLatency }

enum NetworkEventSeverity { info, warning, critical }

class NetworkSecurityEvent {
  const NetworkSecurityEvent({
    required this.at,
    required this.host,
    required this.severity,
    required this.title,
    required this.details,
    required this.action,
  });

  final DateTime at;
  final String host;
  final NetworkEventSeverity severity;
  final String title;
  final String details;
  final String action;
}

class NetworkRequestSample {
  const NetworkRequestSample({
    required this.at,
    required this.host,
    required this.path,
    required this.method,
    required this.durationMs,
    required this.networkHealthy,
    required this.wasRetry,
    this.statusCode,
    this.timedOut = false,
    this.failureKind,
  });

  final DateTime at;
  final String host;
  final String path;
  final String method;
  final int durationMs;
  final bool networkHealthy;
  final bool wasRetry;
  final int? statusCode;
  final bool timedOut;
  final String? failureKind;
}

class _HostFailureState {
  _HostFailureState(this.lastSeen);

  final List<DateTime> failures = <DateTime>[];
  DateTime? suppressRetriesUntil;
  DateTime lastSeen;
  DateTime? lastFailureAlertAt;
}

/// In-memory network baseline and safety policy shared by all BackendApi instances.
class SelfDrivingNetworkMonitor extends ChangeNotifier {
  SelfDrivingNetworkMonitor._();

  static final SelfDrivingNetworkMonitor instance = SelfDrivingNetworkMonitor._();
  static const String _modeKey = 'self_driving_network_mode';
  static const String _intentKey = 'self_driving_network_intent';
  static const int _sampleLimit = 200;
  static const int _failureWindowSeconds = 30;
  static const int _retrySuppressionSeconds = 30;
  static const int _hostStateLimit = 128;
  static const int _requestBurstThreshold = 40;
  static const int _requestWindowSeconds = 10;
  static const int _requestStartsPerHostLimit = 256;
  static const int _eventLimit = 50;

  NetworkAutomationMode _mode = NetworkAutomationMode.automatic;
  NetworkIntentProfile _intentProfile = NetworkIntentProfile.balanced;
  final List<NetworkRequestSample> _samples = <NetworkRequestSample>[];
  final List<NetworkSecurityEvent> _securityEvents = <NetworkSecurityEvent>[];
  final Map<String, List<DateTime>> _requestStarts = <String, List<DateTime>>{};
  final Map<String, DateTime> _lastBurstAlerts = <String, DateTime>{};
  final Map<String, int> _firstConnectionLatencyByHost = <String, int>{};
  final Map<String, _HostFailureState> _hostFailures = <String, _HostFailureState>{};
  int _requestsObserved = 0;
  int _retryAttempts = 0;
  int _transientFailures = 0;
  int _timeouts = 0;
  double? _latencyBaselineMs;
  bool _initialized = false;
  late final SelfDrivingHttpClient _httpClient = SelfDrivingHttpClient(monitor: this);

  SelfDrivingHttpClient get httpClient => _httpClient;
  NetworkAutomationMode get mode => _mode;
  NetworkIntentProfile get intentProfile => _intentProfile;
  List<NetworkSecurityEvent> get securityEvents => List<NetworkSecurityEvent>.unmodifiable(_securityEvents.reversed);
  bool get automaticActionsEnabled => _mode == NetworkAutomationMode.automatic;
  bool get observing => _mode != NetworkAutomationMode.paused;
  int get requestsObserved => _requestsObserved;
  int get retryAttempts => _retryAttempts;
  int get transientFailures => _transientFailures;
  int get timeouts => _timeouts;
  double? get latencyBaselineMs => _latencyBaselineMs;
  List<NetworkRequestSample> get samples => List<NetworkRequestSample>.unmodifiable(_samples.reversed);
  int get detectedBurstHosts => _lastBurstAlerts.keys.where((host) {
        final alertAt = _lastBurstAlerts[host];
        return alertAt != null && DateTime.now().toUtc().difference(alertAt).inSeconds < 60;
      }).length;
  int get uniqueHostsObserved => _samples.map((sample) => sample.host).toSet().length;
  double? get medianLatencyMs {
    final values = _samples
        .where((sample) => sample.networkHealthy)
        .map((sample) => sample.durationMs)
        .toList(growable: false)
      ..sort();
    if (values.isEmpty) return null;
    final middle = values.length ~/ 2;
    if (values.length.isOdd) return values[middle].toDouble();
    return (values[middle - 1] + values[middle]) / 2;
  }
  int get slowRequestCount => _samples.reversed
      .take(30)
      .where((sample) => sample.networkHealthy && sample.durationMs >= 3000)
      .length;
  int? get firstObservedHostConnectionLatencyMs => _firstConnectionLatencyByHost.isEmpty
      ? null
      : _firstConnectionLatencyByHost.values.reduce((a, b) => a + b) ~/
          _firstConnectionLatencyByHost.length;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_modeKey);
      if (saved != null) {
        _mode = NetworkAutomationMode.values.firstWhere(
          (value) => value.name == saved,
          orElse: () => NetworkAutomationMode.automatic,
        );
      }
    } catch (_) {
      // Preferences are optional; a failed read must not block app startup.
    }
    notifyListeners();
  }

  Future<void> setMode(NetworkAutomationMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_modeKey, mode.name);
    } catch (_) {
      // Keep the current process setting even if persistence is unavailable.
    }
  }

  Future<void> setIntentProfile(NetworkIntentProfile profile) async {
    _intentProfile = profile;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_intentKey, profile.name);
    } catch (_) {
      // Keep the current process setting even if persistence is unavailable.
    }
  }

  String get intentDescription => switch (_intentProfile) {
        NetworkIntentProfile.balanced =>
          'Balances responsiveness and resilience using the host-specific P95 latency baseline.',
        NetworkIntentProfile.streamingPriority =>
          'Allows more headroom for slower service responses (8–30 seconds); it does not reserve bandwidth in the operating system or router.',
        NetworkIntentProfile.lowLatency =>
          'Favors quicker failure feedback (8–15 seconds); suitable for interactive navigation rather than large downloads.',
      };

  /// Records an outbound attempt and optionally applies modest local backpressure.
  /// This is client-side burst protection, not inbound DDoS detection or blocking.
  Duration? beforeRequest(Uri uri, String method) {
    if (!observing) return null;
    final host = _hostKey(uri);
    final now = DateTime.now().toUtc();
    if (_requestStarts.length >= _hostStateLimit && !_requestStarts.containsKey(host)) {
      final oldest = _requestStarts.entries.first.key;
      _requestStarts.remove(oldest);
      _lastBurstAlerts.remove(oldest);
    }
    final starts = _requestStarts.putIfAbsent(host, () => <DateTime>[]);
    while (starts.isNotEmpty &&
        now.difference(starts.first).inSeconds >= _requestWindowSeconds) {
      starts.removeAt(0);
    }
    starts.add(now);
    while (starts.length > _requestStartsPerHostLimit) {
      starts.removeAt(0);
    }
    if (starts.length < _requestBurstThreshold) return null;

    final lastAlert = _lastBurstAlerts[host];
    if (lastAlert == null || now.difference(lastAlert).inSeconds >= 60) {
      _lastBurstAlerts[host] = now;
      _addSecurityEvent(NetworkSecurityEvent(
        at: now,
        host: host,
        severity: NetworkEventSeverity.warning,
        title: 'Outbound request burst detected',
        details: '${starts.length} request attempts to one host in $_requestWindowSeconds seconds.',
        action: automaticActionsEnabled
            ? 'Automatic mode may delay body-less GET/HEAD requests within a short bound; write requests are never delayed by this guard.'
            : 'Recorded for review; no automatic backpressure was applied.',
      ));
    }
    final safeRead = method.toUpperCase() == 'GET' || method.toUpperCase() == 'HEAD';
    if (automaticActionsEnabled && safeRead && starts.length >= _requestBurstThreshold) {
      final excess = starts.length - _requestBurstThreshold;
      final millis = (250 + (excess ~/ 5) * 100).clamp(250, 1200).toInt();
      return Duration(milliseconds: millis);
    }
    return null;
  }

  void _addSecurityEvent(NetworkSecurityEvent event) {
    _securityEvents.add(event);
    if (_securityEvents.length > _eventLimit) _securityEvents.removeAt(0);
    AiBotActivityService.instance.recordEvent(
      botId: 'self_driving_network',
      botName: 'Self-Driving Network Bot',
      type: 'network_signal',
      status: switch (event.severity) {
        NetworkEventSeverity.info => 'info',
        NetworkEventSeverity.warning => 'warning',
        NetworkEventSeverity.critical => 'critical',
      },
      title: event.title,
      details: '${event.details} Action: ${event.action}',
    );
  }

  /// A local, deterministic diagnostic helper. It does not send the query anywhere.
  String diagnose(String query) {
    final q = query.toLowerCase();
    final p95 = p95LatencyMs;
    final p50 = medianLatencyMs;
    final failurePercent = (recentFailureRate * 100).round();
    if (q.contains('security') || q.contains('attack') || q.contains('dos') ||
        q.contains('zero trust') || q.contains('burst') || q.contains('threat')) {
      final lastBurst = securityEvents.where((e) => e.title.contains('burst')).length;
      return 'Local security posture: $lastBurst recorded outbound-burst event(s), '
          '$activeRetrySuppressions host retry suppression(s), and $failurePercent% recent request failures. '
          'Automatic mode may add bounded delay to body-less safe reads during a local request burst. '
          'This client cannot see inbound packet floods, rogue DHCP, Wi-Fi radio events, or server firewall logs; '
          'connect backend/gateway telemetry for those controls.';
    }
    if (q.contains('latency') || q.contains('slow') || q.contains('performance') ||
        q.contains('buffer') || q.contains('stream')) {
      final p95Text = p95 == null ? 'not available yet' : '${p95.round()} ms';
      final p50Text = p50 == null ? 'not available yet' : '${p50.round()} ms';
      return 'Response-header latency: median $p50Text, P95 $p95Text, $slowRequestCount slow response(s) among the latest 30 samples. '
          'Trend: $trendLabel. Intent: ${_intentProfile.name}. '
          '${trendLabel == 'Latency rising' ? 'Consider checking the affected host and backend load.' : 'Continue gathering samples to improve the baseline.'} '
          'These are API response measurements, not Wi-Fi association or media-player buffer metrics.';
    }
    if (q.contains('traffic') || q.contains('route') || q.contains('failover') ||
        q.contains('congestion') || q.contains('endpoint')) {
      return 'Traffic-engineering status: $uniqueHostsObserved host(s) observed so far. '
          'The app currently uses explicitly configured service URLs; automatic rerouting requires multiple administrator-approved endpoints and health/identity compatibility checks. '
          'No untrusted endpoint will be selected automatically.';
    }
    if (q.contains('predict') || q.contains('forecast') || q.contains('failure')) {
      return 'Predictive signal: $trendLabel; current health is $healthLabel with $failurePercent% recent failures. '
          'Prediction is currently heuristic (rolling median and error rate), not a trained ML model. '
          'A model provider can be added behind a reviewed proposal interface later.';
    }
    return 'Network is $healthLabel. Trend: $trendLabel. Observed attempts: $_requestsObserved; '
        'P95 latency: ${p95 == null ? 'learning baseline' : '${p95.round()} ms'}; '
        'timeouts: $_timeouts; transient failures: $_transientFailures. '
        'Mode: ${_mode.name}; intent: ${_intentProfile.name}. '
        'Try asking about latency, security, traffic routing, or prediction.';
  }

  /// Chooses a bounded response-header timeout from the observed latency baseline.
  Duration get recommendedTimeout {
    if (!automaticActionsEnabled) return const Duration(seconds: 15);
    final p95 = p95LatencyMs;
    if (p95 == null) return _defaultTimeoutForIntent;
    return _timeoutForLatency(p95);
  }

  Duration get _defaultTimeoutForIntent => switch (_intentProfile) {
        NetworkIntentProfile.balanced => const Duration(seconds: 12),
        NetworkIntentProfile.streamingPriority => const Duration(seconds: 15),
        NetworkIntentProfile.lowLatency => const Duration(seconds: 8),
      };

  /// Adapts each host independently so a slow external feed cannot skew the
  /// timeout policy for the app backend (or vice versa).
  Duration recommendedTimeoutFor(Uri uri) {
    if (!automaticActionsEnabled) return const Duration(seconds: 15);
    final host = _hostKey(uri);
    final values = _samples
        .where((sample) => sample.host == host && sample.networkHealthy)
        .map((sample) => sample.durationMs)
        .toList(growable: false)
      ..sort();
    if (values.isEmpty) return _defaultTimeoutForIntent;
    final index = ((values.length * 0.95).ceil() - 1)
        .clamp(0, values.length - 1)
        .toInt();
    return _timeoutForLatency(values[index].toDouble());
  }

  Duration _timeoutForLatency(double latencyMs) {
    final double candidateSeconds;
    final double minSeconds;
    final double maxSeconds;
    switch (_intentProfile) {
      case NetworkIntentProfile.balanced:
        candidateSeconds = (latencyMs / 1000 * 2) + 2;
        minSeconds = 8;
        maxSeconds = 30;
        break;
      case NetworkIntentProfile.streamingPriority:
        candidateSeconds = (latencyMs / 1000 * 2.5) + 3;
        minSeconds = 12;
        maxSeconds = 30;
        break;
      case NetworkIntentProfile.lowLatency:
        candidateSeconds = (latencyMs / 1000 * 1.25) + 1;
        minSeconds = 8;
        maxSeconds = 15;
        break;
    }
    final boundedSeconds = candidateSeconds.clamp(minSeconds, maxSeconds);
    return Duration(milliseconds: (boundedSeconds * 1000).round());
  }

  /// Returns true while transient retries for this host are temporarily suppressed.
  bool retriesSuppressed(Uri uri) {
    final state = _hostFailures[_hostKey(uri)];
    final until = state?.suppressRetriesUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// Records one HTTP attempt without storing query strings, headers, or payloads.
  void recordAttempt({
    required Uri uri,
    required String method,
    required Duration duration,
    required bool failure,
    required bool wasRetry,
    int? statusCode,
    bool timedOut = false,
    String? failureKind,
  }) {
    if (!observing) return;
    final now = DateTime.now().toUtc();
    final host = _hostKey(uri);
    final durationMs = math.max(0, duration.inMilliseconds).toInt();
    _requestsObserved++;
    if (wasRetry) _retryAttempts++;
    if (timedOut) _timeouts++;
    if (failure) _transientFailures++;

    final sample = NetworkRequestSample(
      at: now,
      host: host,
      path: _safePath(uri),
      method: method.toUpperCase(),
      durationMs: durationMs,
      networkHealthy: !failure && statusCode != null && statusCode >= 200 && statusCode < 500,
      wasRetry: wasRetry,
      statusCode: statusCode,
      timedOut: timedOut,
      failureKind: failureKind,
    );
    _samples.add(sample);
    if (_samples.length > _sampleLimit) _samples.removeAt(0);

    // Only surface notable real request outcomes to the cross-bot timeline;
    // ordinary successful traffic stays in the bounded network metrics buffer.
    if (failure || wasRetry || durationMs >= 5000) {
      AiBotActivityService.instance.recordEvent(
        botId: 'self_driving_network',
        botName: 'Self-Driving Network Bot',
        type: wasRetry ? 'retry_attempt' : (failure ? 'request_failure' : 'slow_response'),
        status: failure ? 'warning' : (wasRetry ? 'info' : 'warning'),
        title: wasRetry
            ? 'Safe request retry observed'
            : (failure ? 'API request failed' : 'Slow API response'),
        details: '${method.toUpperCase()} ${_safePath(uri)} on $host; '
            'duration ${durationMs}ms'
            '${statusCode == null ? '' : ', HTTP $statusCode'}'
            '${timedOut ? ', timeout' : ''}.'
            ' Query strings, headers, and request bodies are omitted.',
        durationMs: durationMs,
      );
    }

    final hostState = _failureStateFor(host, now);
    while (hostState.failures.isNotEmpty &&
        now.difference(hostState.failures.first).inSeconds > _failureWindowSeconds) {
      hostState.failures.removeAt(0);
    }
    if (failure) {
      hostState.failures.add(now);
      if (hostState.failures.length >= 5) {
        hostState.suppressRetriesUntil = now.add(
          const Duration(seconds: _retrySuppressionSeconds),
        );
        if (hostState.failures.length == 5 &&
            (hostState.lastFailureAlertAt == null ||
                now.difference(hostState.lastFailureAlertAt!).inSeconds >= 60)) {
          hostState.lastFailureAlertAt = now;
          _addSecurityEvent(NetworkSecurityEvent(
            at: now,
            host: host,
            severity: NetworkEventSeverity.critical,
            title: 'Repeated host failures',
            details: 'Five transient failures were observed inside $_failureWindowSeconds seconds.',
            action: automaticActionsEnabled
                ? 'Suppressed automatic retries for $_retrySuppressionSeconds seconds to avoid a retry storm; normal requests are still attempted.'
                : 'Repeated failures recorded; automatic retries are already disabled in the current mode.',
          ));
        }
      }
    } else if (statusCode != null && statusCode >= 200 && statusCode < 500) {
      if (!_firstConnectionLatencyByHost.containsKey(host) &&
          _firstConnectionLatencyByHost.length >= _hostStateLimit) {
        _firstConnectionLatencyByHost.remove(_firstConnectionLatencyByHost.keys.first);
      }
      _firstConnectionLatencyByHost.putIfAbsent(host, () => durationMs);
      hostState.failures.clear();
      hostState.suppressRetriesUntil = null;
      _latencyBaselineMs = _latencyBaselineMs == null
          ? durationMs.toDouble()
          : (_latencyBaselineMs! * 0.85) + (durationMs * 0.15);
    }
    notifyListeners();
  }

  _HostFailureState _failureStateFor(String host, DateTime now) {
    final current = _hostFailures[host];
    if (current != null) {
      current.lastSeen = now;
      return current;
    }
    if (_hostFailures.length >= _hostStateLimit) {
      String? oldestHost;
      DateTime? oldestSeen;
      for (final entry in _hostFailures.entries) {
        if (oldestSeen == null || entry.value.lastSeen.isBefore(oldestSeen)) {
          oldestHost = entry.key;
          oldestSeen = entry.value.lastSeen;
        }
      }
      if (oldestHost != null) _hostFailures.remove(oldestHost);
    }
    final created = _HostFailureState(now);
    _hostFailures[host] = created;
    return created;
  }

  int get activeRetrySuppressions {
    final now = DateTime.now();
    return _hostFailures.values
        .where((state) => state.suppressRetriesUntil != null && now.isBefore(state.suppressRetriesUntil!))
        .length;
  }

  double get recentFailureRate {
    final recent = _samples.reversed.take(30).toList(growable: false);
    if (recent.isEmpty) return 0;
    return recent.where((sample) => !sample.networkHealthy).length / recent.length;
  }

  double? get p95LatencyMs {
    final values = _samples
        .where((sample) => sample.networkHealthy)
        .map((sample) => sample.durationMs)
        .toList(growable: false)
      ..sort();
    if (values.isEmpty) return null;
    final index = ((values.length * 0.95).ceil() - 1)
        .clamp(0, values.length - 1)
        .toInt();
    return values[index].toDouble();
  }

  String get healthLabel {
    if (_samples.isEmpty) return 'Learning baseline';
    if (_samples.length >= 5 && recentFailureRate >= 0.25) return 'Critical';
    if (recentFailureRate >= 0.10 || (p95LatencyMs ?? 0) >= 8000) return 'Degraded';
    return 'Healthy';
  }

  String get trendLabel {
    final recent = _samples.where((sample) => sample.networkHealthy).toList(growable: false);
    if (recent.length < 12) return 'Collecting baseline';
    final last = recent.skip(recent.length - 6).map((s) => s.durationMs).toList()..sort();
    final previous = recent.skip(recent.length - 12).take(6).map((s) => s.durationMs).toList()..sort();
    final recentMedian = last[last.length ~/ 2].toDouble();
    final previousMedian = previous[previous.length ~/ 2].toDouble();
    if (previousMedian > 0 && recentMedian >= previousMedian * 1.75) {
      return 'Latency rising';
    }
    if (recentFailureRate >= 0.10) return 'Failure spike';
    return 'Stable';
  }

  /// Clear only the local performance samples; no server or user data is touched.
  void clearHistory() {
    _samples.clear();
    _hostFailures.clear();
    _securityEvents.clear();
    _requestStarts.clear();
    _lastBurstAlerts.clear();
    _firstConnectionLatencyByHost.clear();
    _requestsObserved = 0;
    _retryAttempts = 0;
    _transientFailures = 0;
    _timeouts = 0;
    _latencyBaselineMs = null;
    notifyListeners();
  }

  static String _hostKey(Uri uri) => uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;

  static String _safePath(Uri uri) {
    if (uri.path.isEmpty) {
      return '/';
    }
    final segments = uri.path.split('/');
    final uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    final longIdentifier = RegExp(r'^[a-zA-Z0-9._~-]{24,}$');
    final numericIdentifier = RegExp(r'^\d{4,}$');
    return segments.map((segment) {
      var decodedSegment = segment;
      try {
        decodedSegment = Uri.decodeComponent(segment);
      } catch (_) {
        // Keep the original segment if an escaped path component is malformed.
      }
      if (decodedSegment.contains('@') ||
          uuid.hasMatch(decodedSegment) ||
          longIdentifier.hasMatch(decodedSegment) ||
          numericIdentifier.hasMatch(decodedSegment)) {
        return ':id';
      }
      return segment;
    }).join('/');
  }
}

/// HTTP client wrapper providing bounded timeout adaptation and safe GET/HEAD retries.
class SelfDrivingHttpClient extends http.BaseClient {
  SelfDrivingHttpClient({
    required this.monitor,
    http.Client? inner,
    this.allowSafeReadAutomation = true,
  }) : _inner = inner ?? http.Client();

  final SelfDrivingNetworkMonitor monitor;
  final http.Client _inner;
  final bool allowSafeReadAutomation;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    final method = request.method.toUpperCase();
    final canCloneSafely = request is http.Request && request.body.isEmpty;
    final safeMethod = method == 'GET' || method == 'HEAD';
    final safeReadRequest = safeMethod && canCloneSafely;
    final canRetry = allowSafeReadAutomation &&
        monitor.automaticActionsEnabled &&
        safeReadRequest && !monitor.retriesSuppressed(uri);
    final maxAttempts = canRetry ? 3 : 1;
    final originalRequest = canCloneSafely ? request : null;
    final Duration? policyTimeout = allowSafeReadAutomation &&
            safeReadRequest &&
            monitor.mode != NetworkAutomationMode.paused
        ? monitor.recommendedTimeoutFor(uri)
        : null;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final backpressure = monitor.beforeRequest(uri, method);
      if (backpressure != null && backpressure > Duration.zero) {
        await Future<void>.delayed(backpressure);
      }
      final abortCompleter = policyTimeout == null ? null : Completer<void>();
      final attemptRequest = abortCompleter != null && originalRequest != null
          ? _cloneEmptyRequest(originalRequest, abortCompleter.future)
          : request;
      final stopwatch = Stopwatch()..start();
      try {
        final sendFuture = _inner.send(attemptRequest);
        final response = policyTimeout == null
            ? await sendFuture
            : await sendFuture.timeout(policyTimeout);
        stopwatch.stop();
        final retryableStatus = const <int>{408, 502, 503, 504}.contains(response.statusCode);
        final shouldRetry = retryableStatus && attempt + 1 < maxAttempts;
        if (shouldRetry) {
          try {
            await response.stream.drain<void>().timeout(const Duration(seconds: 2));
          } catch (_) {
            // Stop a slow transient response body before making another attempt.
            if (abortCompleter != null && !abortCompleter.isCompleted) {
              abortCompleter.complete();
            }
          }
          monitor.recordAttempt(
            uri: uri,
            method: method,
            duration: stopwatch.elapsed,
            failure: true,
            wasRetry: attempt > 0,
            statusCode: response.statusCode,
          );
          await Future<void>.delayed(Duration(milliseconds: 120 * (attempt + 1)));
          continue;
        }
        monitor.recordAttempt(
          uri: uri,
          method: method,
          duration: stopwatch.elapsed,
          failure: retryableStatus || response.statusCode >= 500,
          wasRetry: attempt > 0,
          statusCode: response.statusCode,
        );
        return response;
      } catch (error) {
        stopwatch.stop();
        final isTimeout = error is TimeoutException;
        final retryableError = isTimeout || error is http.ClientException;
        final shouldRetry = retryableError && attempt + 1 < maxAttempts;
        if (isTimeout && abortCompleter != null && !abortCompleter.isCompleted) {
          abortCompleter.complete();
        }
        monitor.recordAttempt(
          uri: uri,
          method: method,
          duration: stopwatch.elapsed,
          failure: true,
          wasRetry: attempt > 0,
          timedOut: isTimeout,
          failureKind: error.runtimeType.toString(),
        );
        if (!shouldRetry) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 120 * (attempt + 1)));
      }
    }
    throw StateError('Self-driving network exhausted its bounded retry budget.');
  }

  static http.AbortableRequest _cloneEmptyRequest(
    http.Request source,
    Future<void> abortTrigger,
  ) {
    return http.AbortableRequest(
      source.method,
      source.url,
      abortTrigger: abortTrigger,
    )
      ..headers.addAll(source.headers)
      ..contentLength = 0
      ..followRedirects = source.followRedirects
      ..maxRedirects = source.maxRedirects
      ..persistentConnection = source.persistentConnection;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
