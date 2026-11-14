import 'package:material_ui/material_ui.dart';

class MediaCaseLoading extends StatelessWidget {
  const MediaCaseLoading({super.key, this.label = 'Opening your edition…'});
  final String label;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(height: 12),
        Text(label, style: Theme.of(context).textTheme.bodyMedium)
      ]);
}
