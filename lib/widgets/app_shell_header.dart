// Shared app-shell header. Kept separate from main.dart so search and
// profile/header UI can be maintained independently from route orchestration.
import 'package:flutter/material.dart';

import '../localization.dart';
import '../page_customization_button.dart';

/// Compact contextual utility/header bar shared by every major page.
class AppShellHeader extends StatefulWidget {
  final String title;
  final String pageId;
  final ValueChanged<String> onSearch;
  final VoidCallback onSurpriseMe;

  const AppShellHeader({
    super.key,
    required this.title,
    required this.pageId,
    required this.onSearch,
    required this.onSurpriseMe,
  });

  @override
  State<AppShellHeader> createState() => _AppShellHeaderState();
}

class _AppShellHeaderState extends State<AppShellHeader> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSearch(controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Container(
      padding:
          EdgeInsets.fromLTRB(compact ? 12 : 20, 10, compact ? 12 : 20, 10),
      decoration: BoxDecoration(
        color: const Color(0xEE090909),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: .07))),
      ),
      child: Row(
        children: [
          if (!compact) ...[
            Text(widget.title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(width: 18),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: true,
              showCursor: false,
              onTap: _submit,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: compact
                    ? 'Search everything…'
                    : 'Search movies, TV, music, people, communities…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _submit,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!compact)
            FilledButton.tonalIcon(
              onPressed: widget.onSurpriseMe,
              icon: const Icon(Icons.shuffle_rounded, size: 19),
              label: const UniversalText('Surprise Me'),
            )
          else
            IconButton(
              tooltip: 'Surprise Me',
              onPressed: widget.onSurpriseMe,
              icon: const Icon(Icons.shuffle_rounded),
            ),
          PageCustomizeButton(pageId: widget.pageId),
        ],
      ),
    );
  }
}
