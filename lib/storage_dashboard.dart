// Customizable server storage dashboard used by the More menu and home server.

import 'package:flutter/material.dart';

const Map<String, Color> namedColors = {
  'Red': Colors.red,
  'Blue': Colors.blue,
  'Black': Colors.black,
  'White': Colors.white,
  'Yellow': Colors.yellow,
  'Green': Colors.green,
  'Purple': Colors.purple,
  'Violet': Color.fromARGB(255, 238, 130, 238),
  'Indigo': Colors.indigo,
  'Pink': Colors.pink,
  'Maroon': Color.fromARGB(255, 128, 0, 0),
  'Fuchsia': Color.fromARGB(255, 255, 0, 255),
  'Aqua': Color.fromARGB(255, 0, 255, 255),
  'Cyan': Colors.cyan,
  'Orange': Colors.orange,
  'Brown': Colors.brown,
  'Lime': Colors.lime,
  'Teal': Colors.teal,
  'Amber': Colors.amber,
  'Grey': Colors.grey,
};

class StorageDashboardScreen extends StatefulWidget {
  const StorageDashboardScreen({super.key});

  static String formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    final gb = bytes / (1024 * 1024 * 1024);

    if (gb < 1024) {
      return '${gb.toStringAsFixed(1)} GB';
    }

    return '${(gb / 1024).toStringAsFixed(2)} TB';
  }

  @override
  State<StorageDashboardScreen> createState() =>
      _StorageDashboardScreenState();
}

class _StorageDashboardScreenState extends State<StorageDashboardScreen> {
  // No media has been imported yet, so all storage values start at zero.
  final Map<String, double> used = {
    'Movies': 0.0,
    'Series': 0.0,
    'Music': 0.0,
    'Available': 0.0,
  };

  // Default colors. These can be changed from the customization dialog.
  final Map<String, Color> colors = {
    'Movies': Colors.red,
    'Series': Colors.blue,
    'Music': Colors.purple,
    'Available': Colors.green,
  };

  final Map<String, String> units = {
    'Movies': 'TB',
    'Series': 'TB',
    'Music': 'GB',
    'Available': 'TB',
  };

  /// Builds the storage dashboard.
  @override
  Widget build(BuildContext context) {
    final total = used.values.fold<double>(
      0,
      (a, b) => a + b,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Storage'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Media storage',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'No media has been imported yet. Storage usage will remain at 0 until media is added.',
          ),

          const SizedBox(height: 20),

          for (final name in used.keys) _storageRow(name, total),

          const SizedBox(height: 18),

          FilledButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.palette_outlined),
            label: const Text('Customize storage colors'),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _showInfo,
            icon: const Icon(Icons.info_outline),
            label: const Text('How storage is calculated'),
          ),
        ],
      ),
    );
  }

  Widget _storageRow(
    String name,
    double total,
  ) {
    final value = used[name] ?? 0.0;

    final ratio = total <= 0
        ? 0.0
        : (value / total).clamp(0.0, 1.0);

    final displayValue = value == 0
        ? '0 ${units[name]}'
        : '${value >= 1 ? value.toStringAsFixed(
              value == value.roundToDouble() ? 0 : 2,
            ) : (value * 1024).toStringAsFixed(0)} ${units[name]}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_rounded,
                  color: colors[name],
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                Text(displayValue),
              ],
            ),

            const SizedBox(height: 10),

            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Tooltip(
                message: '$name: 0',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 12,
                    backgroundColor: Colors.white12,
                    color: colors[name],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the color customization dialog.
  Future<void> _edit() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Storage colors'),

          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final name in used.keys)
                    ListTile(
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors[name],
                          shape: BoxShape.circle,
                        ),
                      ),

                      title: Text(name),

                      subtitle: Text(
                        _colorName(colors[name] ?? Colors.grey),
                      ),

                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                      ),

                      onTap: () {
                        Navigator.pop(dialogContext);
                        _chooseColor(name);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Opens the named-color picker for a storage category.
  Future<void> _chooseColor(String category) async {
    final selectedColor = colors[category] ?? Colors.grey;

    final colorName = _colorName(selectedColor);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('$category color'),

          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in namedColors.entries)
                    RadioListTile<String>(
                      value: entry.key,
                      // ignore: deprecated_member_use
                      groupValue: colorName,
                      title: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: entry.value,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white24,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Text(entry.key),
                        ],
                      ),
                      // ignore: deprecated_member_use
                      onChanged: (value) {
                        if (value != null) {
                          Navigator.pop(
                            dialogContext,
                            value,
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final selected = namedColors[result];

    if (selected == null) {
      return;
    }

    setState(() {
      colors[category] = selected;
    });
  }

  /// Converts a Color back to its friendly customization name.
  String _colorName(Color color) {
    for (final entry in namedColors.entries) {
      if (entry.value.toARGB32() == color.toARGB32()) {
        return entry.key;
      }
    }

    return 'Grey';
  }

  void _showInfo() {
    showDialog<void>(
      context: context,
      builder: (_) {
        return const AlertDialog(
          title: Text('Storage'),
          content: Text(
            'Storage starts at 0 because no media has been imported. '
            'Storage usage will increase when movies, series, music, '
            'or other media are actually imported into the server.',
          ),
        );
      },
    );
  }
}