import 'package:flutter/material.dart';

import 'app_core.dart';

Future<void> showSocialShareDialog(
  BuildContext context, {
  required String title,
  required String message,
  required Map<String, dynamic> mediaReference,
  String? sourceMessageId,
  String? sourcePostId,
}) async {
  final profile = AppController.instance.currentProfile;
  if (profile == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select a profile before sharing.')),
    );
    return;
  }

  List<Map<String, dynamic>> conversations;
  try {
    final data = await AppController.instance.backendApi.getSocialCenter(
      profileId: profile.id,
    );
    conversations = (data['conversations'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load chats: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
    return;
  }
  if (!context.mounted) return;

  final selectedIds = await showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final selected = <String>{};
      return StatefulBuilder(
        builder: (context, setDialogState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .82,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Share $title',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: conversations.isEmpty
                        ? const Center(
                            child: Text(
                              'Start a chat before sharing to conversations.',
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              for (final conversation in conversations)
                                _ConversationOption(
                                  conversation: conversation,
                                  profileId: profile.id,
                                  selected: selected.contains(
                                    conversation['id']?.toString(),
                                  ),
                                  onChanged: (enabled) {
                                    final id =
                                        conversation['id']?.toString();
                                    if (id == null || id.isEmpty) return;
                                    setDialogState(() {
                                      if (enabled) {
                                        selected.add(id);
                                      } else {
                                        selected.remove(id);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.pop(
                                  sheetContext,
                                  Set<String>.from(selected),
                                ),
                        child: Text(
                          selected.isEmpty
                              ? 'Share'
                              : 'Share (${selected.length})',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  if (selectedIds == null || selectedIds.isEmpty || !context.mounted) return;

  final failures = <String>[];
  for (final conversation in conversations.where(
    (item) => selectedIds.contains(item['id']?.toString()),
  )) {
    final id = conversation['id']?.toString();
    if (id == null) continue;
    try {
      if (sourceMessageId != null) {
        await AppController.instance.backendApi.forwardSocialMessage(
          profileId: profile.id,
          sourceMessageId: sourceMessageId,
          conversationId: id,
        );
      } else if (sourcePostId != null) {
        await AppController.instance.backendApi.forwardSocialPost(
          profileId: profile.id,
          sourcePostId: sourcePostId,
          conversationId: id,
        );
      } else {
        await AppController.instance.backendApi.sendSocialMessage(
          profileId: profile.id,
          conversationId: id,
          body: message,
          mediaReference: mediaReference,
        );
      }
    } catch (error) {
      failures.add(
        '${_conversationName(conversation)}: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failures.isEmpty
            ? 'Shared to ${selectedIds.length} chat${selectedIds.length == 1 ? '' : 's'}.'
            : 'Some chats could not be reached: ${failures.join('; ')}',
      ),
    ),
  );
}

class _ConversationOption extends StatelessWidget {
  const _ConversationOption({
    required this.conversation,
    required this.profileId,
    required this.selected,
    required this.onChanged,
  });

  final Map<String, dynamic> conversation;
  final String profileId;
  final bool selected;
  final ValueChanged<bool> onChanged;

  bool get _canCurrentProfileSend {
    if (conversation['send_policy'] != 'admins_only' &&
        conversation['sendPolicy'] != 'admins_only') {
      return true;
    }
    final members = (conversation['members'] as List? ?? const [])
        .whereType<Map>();
    return members.any((member) {
      if (member['isSelf'] != true ||
          member['profileId']?.toString() != profileId) {
        return false;
      }
      final role = member['role']?.toString().toLowerCase();
      return role == 'moderator' || role == 'owner';
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _canCurrentProfileSend;
    return CheckboxListTile(
      value: selected,
      onChanged: enabled ? (value) => onChanged(value ?? false) : null,
      title: Text(_conversationName(conversation)),
      subtitle: Text(
        enabled
            ? (conversation['kind'] == 'group' ? 'Group chat' : 'Direct message')
            : 'Only group admins can send messages',
      ),
      secondary: Icon(
        conversation['kind'] == 'group'
            ? Icons.groups_rounded
            : Icons.person_outline_rounded,
      ),
    );
  }
}

String _conversationName(Map<String, dynamic> conversation) {
  final directName = conversation['name']?.toString().trim() ?? '';
  if (directName.isNotEmpty) return directName;
  final members = (conversation['members'] as List? ?? const [])
      .whereType<Map>()
      .where((member) => member['isSelf'] != true)
      .map((member) =>
          member['display_name']?.toString() ??
          member['username']?.toString() ??
          '')
      .where((name) => name.isNotEmpty)
      .toList();
  return members.isEmpty ? 'Chat' : members.join(', ');
}
