import 'package:flutter/material.dart';

/// Explains the standard living-room navigation inputs supported by the app.
/// Actual available gamepad keys depend on the operating system's Flutter key
/// event mapping; the app does not require a third-party controller SDK.
class LivingRoomControlsScreen extends StatelessWidget {
  const LivingRoomControlsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Living Room Controls')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _ControlRow(Icons.gamepad_rounded, 'D-pad / Arrow keys',
                'Move focus between posters, cards, menus and actions. On supported TV/controller platforms, the D-pad is delivered as directional key events.'),
            _ControlRow(Icons.circle_outlined, 'A / Enter / Space',
                'Activate the focused button, poster or menu item. Standard game-button A uses the same activation action.'),
            _ControlRow(Icons.close_rounded, 'B / Escape',
                'Close a dialog or return to the previous screen. Standard game-button B is mapped to dismiss.'),
            _ControlRow(Icons.keyboard_rounded, 'Keyboard and mouse',
                'Use text search, precision selection and the store camera controls.'),
            _ControlRow(Icons.touch_app_rounded, 'Touchscreen',
                'Tap a case, poster, seat or action; use drag gestures where supported.'),
            SizedBox(height: 12),
            Text(
              'Controller behavior depends on platform and driver key mapping. D-pad navigation, A/activate and B/back work when the controller exposes those standard key events. Dedicated vibration, analog-stick camera movement and custom controller remapping are not enabled; those require a gamepad input plugin.',
            ),
          ],
        ),
      );
}

class _ControlRow extends StatelessWidget {
  const _ControlRow(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, size: 28),
          title: Text(title),
          subtitle: Text(description),
        ),
      );
}
