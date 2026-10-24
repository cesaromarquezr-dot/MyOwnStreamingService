import 'package:flutter/material.dart';

import 'core/services/ai_bot_activity_service.dart';

/// Live view over real, instrumented bot events. A registered bot with no events
/// is explicitly labeled as not reporting activity, never as running.
class AiOperationsCenterScreen extends StatefulWidget {
  const AiOperationsCenterScreen({super.key});

  @override
  State<AiOperationsCenterScreen> createState() => _AiOperationsCenterScreenState();
}

class _AiOperationsCenterScreenState extends State<AiOperationsCenterScreen> {
  final AiBotActivityService _activity = AiBotActivityService.instance;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _activity.initialize();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _activity,
        builder: (context, _) {
          final events = _activity.events;
          final active = _activity.activeTasks.length;
          final attention = events
              .where((event) => event.status == 'warning' || event.status == 'critical' || event.status == 'failed')
              .take(100)
              .length;
          final completed = events
              .where((event) => event.type == 'task_finished' && event.status == 'succeeded')
              .length;
          final filtered = _filter == 'all'
              ? events
              : events.where((event) => event.botId == _filter).toList();
          return Scaffold(
            appBar: AppBar(
              title: const Text('AI Operations Center'),
              actions: [
                IconButton(
                  tooltip: 'Clear local activity history',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: events.isEmpty ? null : _confirmClear,
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('What are the bots doing?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('This view uses persisted events emitted by instrumented code paths. Bots without instrumented workers are marked as not reporting activity.', style: TextStyle(height: 1.4)),
                      const SizedBox(height: 14),
                      Row(children: [
                        _Metric(label: 'Running tasks', value: '$active', icon: Icons.play_circle_outline),
                        const SizedBox(width: 8),
                        _Metric(label: 'Recent alerts', value: '$attention', icon: Icons.warning_amber_rounded),
                        const SizedBox(width: 8),
                        _Metric(label: 'Completed', value: '$completed', icon: Icons.task_alt_rounded),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Bot status', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final bot in AiBotActivityService.bots)
                  _BotCard(
                    bot: bot,
                    events: events.where((event) => event.botId == bot.id).toList(),
                    running: _activity.activeTasks.containsKey(bot.id),
                    onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(
                      builder: (_) => AiBotDetailScreen(bot: bot),
                    )),
                  ),
                const SizedBox(height: 18),
                Text('Live activity timeline', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _filter,
                  decoration: const InputDecoration(labelText: 'Filter events by bot', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All bots')),
                    for (final bot in AiBotActivityService.bots)
                      DropdownMenuItem(value: bot.id, child: Text(bot.name)),
                  ],
                  onChanged: (value) => setState(() => _filter = value ?? 'all'),
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No activity events yet. Run an instrumented check or wait for an actual bot action to appear here.')))
                else
                  for (final event in filtered.take(100)) _EventCard(event: event),
                const SizedBox(height: 10),
                const Text('Privacy: event records are stored locally on this device. Request paths, query strings, request bodies, credentials, and model prompts are not collected by this activity service.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
              ],
            ),
          );
        },
      );

  Future<void> _confirmClear() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear activity history?'),
        content: const Text('This clears the locally stored bot activity timeline on this device. It does not stop running tasks or delete server audit logs.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear history')),
        ],
      ),
    );
    if (clear == true) _activity.clearHistory();
  }
}

class AiBotDetailScreen extends StatelessWidget {
  const AiBotDetailScreen({super.key, required this.bot});
  final AiBotDefinition bot;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AiBotActivityService.instance,
        builder: (context, _) {
          final service = AiBotActivityService.instance;
          final events = service.events.where((event) => event.botId == bot.id).toList();
          final running = service.activeTasks.containsKey(bot.id);
          final latest = events.isEmpty ? null : events.first;
          return Scaffold(
            appBar: AppBar(title: Text(bot.name)),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(bot.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), _StatusPill(label: running ? 'Running' : _statusLabel(latest), status: running ? 'running' : latest?.status ?? 'idle')]),
                const SizedBox(height: 8), Text(bot.description),
                const SizedBox(height: 12),
                Text('Latest event: ${latest == null ? 'None recorded' : latest.title}'),
                if (latest != null) Text('Last reported: ${_formatTime(latest.at)}', style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 8),
                const Text('This page only reports actions emitted by the bot implementation. A role description or configured mode is not proof of live execution.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
              ]))),
              const SizedBox(height: 12),
              Text('Task history & decisions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (events.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No instrumented activity has been recorded for this bot yet.')))
              else
                for (final event in events.take(200)) _EventCard(event: event),
            ]),
          );
        },
      );
}

class _BotCard extends StatelessWidget {
  const _BotCard({required this.bot, required this.events, required this.running, required this.onTap});
  final AiBotDefinition bot;
  final List<AiBotActivityEvent> events;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latest = events.isEmpty ? null : events.first;
    final label = running ? 'Running' : _statusLabel(latest);
    final status = running ? 'running' : latest?.status ?? 'idle';
    return Card(child: ListTile(
      leading: CircleAvatar(child: Icon(running ? Icons.sync_rounded : _iconForStatus(status))),
      title: Text(bot.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${latest?.title ?? 'No activity reported'}\n${latest == null ? bot.description : '${_formatTime(latest.at)} · ${latest.details}'}', maxLines: 3, overflow: TextOverflow.ellipsis),
      isThreeLine: true,
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [_StatusPill(label: label, status: status), const Icon(Icons.chevron_right_rounded, size: 18)]),
      onTap: onTap,
    ));
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final AiBotActivityEvent event;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2, right: 10), child: Icon(_iconForStatus(event.status), color: _colorForStatus(context, event.status))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700))), const SizedBox(width: 6), _StatusPill(label: event.status, status: event.status)]),
            const SizedBox(height: 4), Text(event.botName, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
            const SizedBox(height: 4), Text(event.details),
            const SizedBox(height: 5), Text('${_formatTime(event.at)}${event.durationMs == null ? '' : ' · ${event.durationMs} ms'}${event.taskId == null ? '' : ' · Task ${event.taskId}'}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ])),
        ])),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18), const SizedBox(height: 8), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(fontSize: 11), maxLines: 2)])));
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.status});
  final String label;
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(context, status);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withValues(alpha: .45))), child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)));
  }
}

String _statusLabel(AiBotActivityEvent? event) {
  if (event == null) return 'No heartbeat';
  return switch (event.status) {
    'running' => 'Running',
    'succeeded' => 'Succeeded',
    'failed' => 'Failed',
    'critical' => 'Critical',
    'warning' => 'Warning',
    'waiting_approval' => 'Needs approval',
    'paused' => 'Paused',
    _ => 'Idle',
  };
}

IconData _iconForStatus(String status) => switch (status) {
      'running' => Icons.sync_rounded,
      'succeeded' => Icons.check_circle_outline_rounded,
      'failed' || 'critical' => Icons.error_outline_rounded,
      'warning' => Icons.warning_amber_rounded,
      'waiting_approval' => Icons.pending_actions_rounded,
      _ => Icons.smart_toy_outlined,
    };

Color _colorForStatus(BuildContext context, String status) => switch (status) {
      'running' => Colors.lightBlueAccent,
      'succeeded' => Colors.greenAccent,
      'failed' || 'critical' => Theme.of(context).colorScheme.error,
      'warning' => Colors.orangeAccent,
      'waiting_approval' => Colors.deepPurpleAccent,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };

String _formatTime(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
