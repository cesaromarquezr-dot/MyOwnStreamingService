import 'package:flutter/material.dart';

import 'mindscape_ai_team.dart';

/// Safe, local task-planning UI for the Mindscape team.
/// Proposals stay in widget memory and are not sent to AI providers or workers.
class MindscapeAiOrchestratorScreen extends StatefulWidget {
  const MindscapeAiOrchestratorScreen({super.key});

  @override
  State<MindscapeAiOrchestratorScreen> createState() => _MindscapeAiOrchestratorScreenState();
}

class _MindscapeAiOrchestratorScreenState extends State<MindscapeAiOrchestratorScreen> {
  final _taskController = TextEditingController();
  String _roleId = 'fixer';
  String _risk = 'Read-only review';
  final List<_TaskProposal> _proposals = <_TaskProposal>[];
  int _nextId = 1;

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  MindscapeAiBotRole get _selectedRole => MindscapeAiBotCatalog.roles.firstWhere((role) => role.id == _roleId);

  void _draftProposal() {
    final task = _taskController.text.trim();
    if (task.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Describe a task before drafting it.')));
      return;
    }
    setState(() {
      _proposals.insert(0, _TaskProposal(id: _nextId++, role: _selectedRole.name, task: task, risk: _risk));
      _taskController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proposal saved locally for review. No action was executed.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mindscape AI Orchestrator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.account_tree_rounded, size: 34, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text('Coordinate the three roles, not their privileges.', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Draft a task for the appropriate role, state its impact level, and keep it pending review. In this first implementation, proposals are local to this screen and no AI call, shell command, storage change, or external message is run.'),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Text('Assign responsibility', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _roleId,
            onChanged: (String? value) {
              if (value == null) return;
              setState(() => _roleId = value);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final role in MindscapeAiBotCatalog.roles)
                  Card(
                    child: RadioListTile<String>(
                      value: role.id,
                      title: Text(role.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(role.tagline),
                      secondary: Icon(role.icon),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _taskController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Task objective', hintText: 'Example: review backup freshness and prepare a safe recovery checklist.', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Text('Impact level', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final risk in const ['Read-only review', 'Reversible action', 'High impact'])
              ChoiceChip(label: Text(risk), selected: _risk == risk, onSelected: (_) => setState(() => _risk = risk)),
          ]),
          const SizedBox(height: 8),
          if (_risk == 'High impact')
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.gpp_maybe_outlined),
              title: Text('Explicit human approval required'),
              subtitle: Text('Examples: deleting data, changing access policy, key rotation, restoring over production, sending messages, or changing network exposure.'),
            ),
          FilledButton.icon(onPressed: _draftProposal, icon: const Icon(Icons.playlist_add_rounded), label: const Text('Draft task for review')),
          const SizedBox(height: 20),
          Text('Review queue (${_proposals.length})', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_proposals.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No local task proposals yet.'))),
          for (final proposal in _proposals)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.pending_actions_rounded),
                title: Text('Proposal ${proposal.id}: ${proposal.role}'),
                subtitle: Text('${proposal.risk} • Awaiting review'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(alignment: Alignment.centerLeft, child: Text(proposal.task)),
                  const SizedBox(height: 8),
                  const Align(alignment: Alignment.centerLeft, child: Text('No worker execution or persistence is connected in this version.')),
                  Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => setState(() => _proposals.removeWhere((item) => item.id == proposal.id)), icon: const Icon(Icons.delete_outline), label: const Text('Remove draft'))),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const Text('Production requirements: separate service identity per agent, backend-enforced tool permissions, prompt-injection defenses, bounded queues, external audit persistence, secret redaction, timeouts, rate limits, and approval-gated mutations.'),
        ],
      ),
    );
  }
}

class _TaskProposal {
  final int id;
  final String role;
  final String task;
  final String risk;
  const _TaskProposal({required this.id, required this.role, required this.task, required this.risk});
}
