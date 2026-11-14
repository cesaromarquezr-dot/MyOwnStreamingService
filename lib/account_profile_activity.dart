import 'package:material_ui/material_ui.dart';

/// Empty compatibility widget after removal of Friends and profile presence.
/// It intentionally performs no cross-profile requests or messaging actions.
class AccountProfileActivityStrip extends StatelessWidget {
  const AccountProfileActivityStrip({super.key, this.onMessageProfile});

  final ValueChanged<String>? onMessageProfile;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
