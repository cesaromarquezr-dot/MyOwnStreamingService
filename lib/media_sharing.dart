import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a media reference through the device's native share sheet.
/// This uses the device share sheet and has no in-app social dependency.
Future<void> showMediaShareDialog(
  BuildContext context, {
  required String title,
  required String message,
  required Map<String, dynamic> mediaReference,
  String? sourceMessageId,
  String? sourcePostId,
}) async {
  final text = <String>[title.trim(), message.trim()]
      .where((value) => value.isNotEmpty)
      .join('\n');
  if (text.isEmpty) return;
  try {
    await SharePlus.instance.share(ShareParams(title: title, text: text));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to open sharing: $error')),
    );
  }
}
