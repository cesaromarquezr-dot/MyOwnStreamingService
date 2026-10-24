import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted, redacted activity stream shared by AI bot screens and workers.
/// Events describe real code paths that call this service; catalog entries alone
/// are never treated as evidence that a bot is running.
class AiBotActivityEvent {
  const AiBotActivityEvent({
    required this.id,
    required this.botId,
    required this.botName,
    required this.type,
    required this.status,
    required this.title,
    required this.details,
    required this.at,
    this.taskId,
    this.durationMs,
  });

  final String id;
  final String botId;
  final String botName;
  final String type;
  final String status;
  final String title;
  final String details;
  final DateTime at;
  final String? taskId;
  final int? durationMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'botId': botId,
        'botName': botName,
        'type': type,
        'status': status,
        'title': title,
        'details': details,
        'at': at.toUtc().toIso8601String(),
        if (taskId != null) 'taskId': taskId,
        if (durationMs != null) 'durationMs': durationMs,
      };

  factory AiBotActivityEvent.fromJson(Map<String, dynamic> json) =>
      AiBotActivityEvent(
        id: json['id']?.toString() ?? '',
        botId: json['botId']?.toString() ?? 'unknown',
        botName: json['botName']?.toString() ?? 'Unknown bot',
        type: json['type']?.toString() ?? 'event',
        status: json['status']?.toString() ?? 'info',
        title: json['title']?.toString() ?? 'Activity',
        details: json['details']?.toString() ?? '',
        at: DateTime.tryParse(json['at']?.toString() ?? '')?.toUtc() ??
            DateTime.now().toUtc(),
        taskId: json['taskId']?.toString(),
        durationMs: (json['durationMs'] as num?)?.toInt(),
      );
}

class AiBotDefinition {
  const AiBotDefinition({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

class AiBotActivityService extends ChangeNotifier {
  AiBotActivityService._();
  static final AiBotActivityService instance = AiBotActivityService._();

  static const String _storageKey = 'ai_bot_activity_events_v1';
  static const int _eventLimit = 500;
  final List<AiBotActivityEvent> _events = <AiBotActivityEvent>[];
  final Map<String, String> _activeTasks = <String, String>{};
  bool _initialized = false;
  Future<void> _persistChain = Future<void>.value();
  int _sequence = 0;

  static const List<AiBotDefinition> bots = <AiBotDefinition>[
    AiBotDefinition(id: 'self_driving_network', name: 'Self-Driving Network Bot', description: 'API health, latency baselines, bounded retries, and recovery signals.'),
    AiBotDefinition(id: 'security', name: 'Security Bot', description: 'On-demand, authorized security and reliability diagnostics.'),
    AiBotDefinition(id: 'steward', name: 'Steward', description: 'Planning and policy review role; execution is shown only when instrumented.'),
    AiBotDefinition(id: 'moxie', name: 'Moxie', description: 'Creative assistant role; model/tool activity requires a connected runtime.'),
    AiBotDefinition(id: 'fixer', name: 'Fixer', description: 'Troubleshooting and repair proposals; changes require supported actions and authorization.'),
    AiBotDefinition(id: 'database_backup', name: 'Database & Backup Bot', description: 'Backend diagnostic checks and backup readiness where connected.'),
    AiBotDefinition(id: 'media_metadata', name: 'Media & Metadata Bot', description: 'Metadata and media-processing jobs when instrumented by their worker.'),
  ];

  List<AiBotActivityEvent> get events =>
      List<AiBotActivityEvent>.unmodifiable(_events.reversed);
  Map<String, String> get activeTasks =>
      Map<String, String>.unmodifiable(_activeTasks);
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final knownIds = _events.map((event) => event.id).toSet();
          for (final item in decoded) {
            if (item is Map) {
              final event = AiBotActivityEvent.fromJson(
                  Map<String, dynamic>.from(item));
              if (knownIds.add(event.id)) _events.add(event);
            }
          }
        }
      }
    } catch (_) {
      // Activity logging must never prevent the app from starting.
    }
    _events.sort((a, b) => a.at.compareTo(b.at));
    if (_events.length > _eventLimit) {
      _events.removeRange(0, _events.length - _eventLimit);
    }
    // A task left running at process shutdown is not falsely shown as active.
    final latestByTask = <String, AiBotActivityEvent>{};
    for (final event in _events) {
      if (event.taskId != null) latestByTask[event.taskId!] = event;
    }
    for (final entry in latestByTask.entries) {
      if (entry.value.status == 'running') {
        _events.add(_newEvent(
          botId: entry.value.botId,
          botName: entry.value.botName,
          type: 'task_interrupted',
          status: 'failed',
          title: 'Task interrupted by app restart',
          details: 'The previous process ended before this task recorded completion.',
          taskId: entry.key,
        ));
      }
    }
    _trim();
    await _persist();
    notifyListeners();
  }

  String startTask({
    required String botId,
    required String botName,
    required String title,
    required String details,
  }) {
    final taskId = '${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
    _activeTasks[botId] = taskId;
    _append(_newEvent(
      botId: botId,
      botName: botName,
      type: 'task_started',
      status: 'running',
      title: title,
      details: details,
      taskId: taskId,
    ));
    return taskId;
  }

  void recordStep({
    required String botId,
    required String botName,
    required String title,
    required String details,
    String status = 'info',
    String? taskId,
  }) {
    _append(_newEvent(
      botId: botId,
      botName: botName,
      type: 'step',
      status: status,
      title: title,
      details: details,
      taskId: taskId ?? _activeTasks[botId],
    ));
  }

  void completeTask({
    required String botId,
    required String botName,
    required String taskId,
    required String title,
    required String details,
    required bool success,
    int? durationMs,
  }) {
    _activeTasks.removeWhere((key, value) => key == botId && value == taskId);
    _append(_newEvent(
      botId: botId,
      botName: botName,
      type: 'task_finished',
      status: success ? 'succeeded' : 'failed',
      title: title,
      details: details,
      taskId: taskId,
      durationMs: durationMs,
    ));
  }

  void recordEvent({
    required String botId,
    required String botName,
    required String title,
    required String details,
    String type = 'event',
    String status = 'info',
    int? durationMs,
  }) {
    _append(_newEvent(
      botId: botId,
      botName: botName,
      type: type,
      status: status,
      title: title,
      details: details,
      durationMs: durationMs,
    ));
  }

  void clearHistory() {
    _events.clear();
    _persist();
    notifyListeners();
  }

  AiBotActivityEvent _newEvent({
    required String botId,
    required String botName,
    required String type,
    required String status,
    required String title,
    required String details,
    String? taskId,
    int? durationMs,
  }) => AiBotActivityEvent(
        id: '${DateTime.now().microsecondsSinceEpoch}-${++_sequence}',
        botId: botId,
        botName: botName,
        type: type,
        status: status,
        title: title,
        details: details,
        at: DateTime.now().toUtc(),
        taskId: taskId,
        durationMs: durationMs,
      );

  void _append(AiBotActivityEvent event) {
    _events.add(event);
    _trim();
    _persist();
    notifyListeners();
  }

  void _trim() {
    if (_events.length > _eventLimit) {
      _events.removeRange(0, _events.length - _eventLimit);
    }
  }

  Future<void> _persist() {
    _persistChain = _persistChain.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _storageKey,
          jsonEncode(_events.map((event) => event.toJson()).toList()),
        );
      } catch (_) {
        // Persistence is best-effort; in-memory activity remains available.
      }
    });
    return _persistChain;
  }
}
