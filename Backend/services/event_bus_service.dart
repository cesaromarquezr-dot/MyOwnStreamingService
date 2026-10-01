import 'dart:async';

class PlatformEvent {
  final String type;
  final String accountId;
  final Map<String, dynamic> payload;
  final DateTime occurredAt;

  const PlatformEvent({
    required this.type,
    required this.accountId,
    this.payload = const {},
    required this.occurredAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'accountId': accountId,
        'payload': payload,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
      };
}

/// Small in-process event hub. Durable/event-queue implementations can replace
/// this without changing domain callers.
class EventBusService {
  final StreamController<PlatformEvent> _controller = StreamController.broadcast();

  Stream<PlatformEvent> get events => _controller.stream;

  void publish({
    required String type,
    required String accountId,
    Map<String, dynamic> payload = const {},
  }) {
    if (accountId.trim().isEmpty || type.trim().isEmpty) return;
    _controller.add(
      PlatformEvent(
        type: type.trim(),
        accountId: accountId.trim(),
        payload: Map<String, dynamic>.unmodifiable(payload),
        occurredAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> dispose() => _controller.close();
}
