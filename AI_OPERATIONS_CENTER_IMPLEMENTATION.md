# AI Operations Center

## Included

- `lib/core/services/ai_bot_activity_service.dart` provides a shared event model, task lifecycle methods, a 500-event local history, and best-effort SharedPreferences persistence.
- `lib/ai_operations_center.dart` provides the operations overview, per-bot detail pages, status summaries, event filters, and a clear-history confirmation.
- `lib/ai_bot_center.dart` links the new operations center from the AI Bot Center.
- `lib/core/services/self_driving_network_engine.dart` emits events for network warnings, failures, retries, and slow responses. Ordinary successful requests remain in the bounded network metrics buffer rather than cluttering the activity feed.
- `lib/security_bot_center.dart` records the lifecycle of explicit on-demand read-only security checks.
- `lib/mindscape_ai_orchestrator.dart` records local task proposal creation and removal without copying task objective text into the shared event log or implying that a worker executed it.
- `test/ai_bot_activity_service_test.dart` covers task start, step, completion, and active-state cleanup.

## Status semantics

A bot with no emitted events is displayed as `No heartbeat`; it is not marked as running. Only `startTask` marks a task as running, and completion/failure closes the active task. If a persisted task was left running when the app process ended, initialization records it as interrupted instead of treating it as a live worker.

## Scope and limitations

The timeline is persisted locally on the current device, not to a server-wide audit database. The Self-Driving Network and Security Bot are instrumented in their existing code paths. Steward, Moxie, Fixer, and other catalog entries only report actual events when their corresponding UI or worker calls the activity service; their role descriptions do not represent active AI model execution. This patch does not add a background scheduler, WebSocket worker protocol, external LLM, or remote bot runtime. Live screen updates occur immediately for events received by the current app process; remote multi-device live updates need backend event storage and streaming/polling integration.

Activity records avoid request bodies, headers, query strings, secrets, and task objective text. Clearing history affects only local bot activity records; it does not stop tasks or delete server-side audit logs.
