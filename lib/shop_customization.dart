import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'shop_customization_models.dart';

class ShopProductCustomizationEditor extends StatefulWidget {
  const ShopProductCustomizationEditor({
    super.key,
    required this.initialGroups,
  });

  final List<ShopCustomizationGroup> initialGroups;

  @override
  State<ShopProductCustomizationEditor> createState() =>
      _ShopProductCustomizationEditorState();
}

class _ShopProductCustomizationEditorState
    extends State<ShopProductCustomizationEditor> {
  late final List<ShopCustomizationGroup> groups;

  @override
  void initState() {
    super.initState();
    groups = widget.initialGroups
        .map((group) => ShopCustomizationGroup.fromJson(group.toJson()))
        .toList();
  }

  Future<void> _addGroup({String? preset}) async {
    final title = TextEditingController();
    final options = TextEditingController();
    String type = 'choice';
    bool required = false;
    int maxSelections = 1;

    if (preset == 'character') {
      title.text = 'Character';
      type = 'character';
      options.text = '1 person\n2 people\n3 people\n4 people';
    } else if (preset == 'clothing') {
      title.text = 'Shirt';
      options.text = 'T-Shirt\nHoodie\nSweater';
    } else if (preset == 'personalized') {
      title.text = 'Custom Text';
      type = 'text';
      required = false;
    }

    final result = await showDialog<ShopCustomizationGroup>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(preset == null ? 'Add customization' : 'Add $preset customization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Option group name'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'choice', child: Text('Choice')),
                  DropdownMenuItem(value: 'color', child: Text('Color')),
                  DropdownMenuItem(value: 'size', child: Text('Size')),
                  DropdownMenuItem(value: 'text', child: Text('Text')),
                  DropdownMenuItem(value: 'font', child: Text('Font')),
                  DropdownMenuItem(value: 'icon', child: Text('Icon')),
                  DropdownMenuItem(value: 'image', child: Text('Image')),
                  DropdownMenuItem(value: 'character', child: Text('Character')),
                ],
                onChanged: (value) => setDialogState(() => type = value ?? 'choice'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: options,
                minLines: 2,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'Options',
                  hintText: 'One option per line',
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: required,
                onChanged: (value) => setDialogState(() => required = value),
                title: const Text('Required'),
              ),
              if (type == 'choice' || type == 'icon' || type == 'character')
                DropdownButtonFormField<int>(
                  initialValue: maxSelections,
                  decoration: const InputDecoration(labelText: 'Maximum selections'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1')),
                    DropdownMenuItem(value: 2, child: Text('2')),
                    DropdownMenuItem(value: 3, child: Text('3')),
                    DropdownMenuItem(value: 4, child: Text('4')),
                  ],
                  onChanged: (value) => setDialogState(() => maxSelections = value ?? 1),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final cleanTitle = title.text.trim();
                final values = options.text
                    .split(RegExp(r'[\n,;]'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                if (cleanTitle.isEmpty && type != 'text') return;
                Navigator.pop(
                  dialogContext,
                  ShopCustomizationGroup(
                    id: 'group_${DateTime.now().microsecondsSinceEpoch}',
                    title: cleanTitle.isEmpty ? 'Custom text' : cleanTitle,
                    type: type,
                    required: required,
                    maxSelections: maxSelections,
                    options: [
                      for (var i = 0; i < values.length; i++)
                        ShopCustomizationOption(
                          id: 'option_${DateTime.now().microsecondsSinceEpoch}_$i',
                          label: values[i],
                        ),
                    ],
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    options.dispose();
    if (!mounted || result == null) return;
    setState(() {
      groups.add(result);
      if (preset == 'character') {
        const presets = <MapEntry<String, List<String>> >[
          MapEntry('Life status', ['Alive', 'Deceased']),
          MapEntry('Hair', ['Short', 'Long', 'Curly', 'Braids', 'Bald']),
          MapEntry('Eyes', ['Brown', 'Blue', 'Green', 'Hazel']),
          MapEntry('Shirt', ['T-Shirt', 'Hoodie', 'Sweater', 'Jacket']),
          MapEntry('Pants', ['Jeans', 'Black', 'Khaki', 'Shorts']),
          MapEntry('Glasses', ['None', 'Round', 'Square', 'Sunglasses']),
          MapEntry('Drink', ['None', 'Coffee', 'Soda', 'Cocktail', 'Juice']),
        ];
        for (final presetGroup in presets) {
          final stamp = DateTime.now().microsecondsSinceEpoch;
          groups.add(ShopCustomizationGroup(
            id: 'group_${stamp}_${presetGroup.key.replaceAll(' ', '_')}',
            title: presetGroup.key,
            options: [
              for (var i = 0; i < presetGroup.value.length; i++)
                ShopCustomizationOption(
                  id: 'option_${stamp}_$i',
                  label: presetGroup.value[i],
                ),
            ],
          ));
        }
      }
    });
  }

  Future<void> _editGroup(ShopCustomizationGroup group) async {
    final title = TextEditingController(text: group.title);
    final options = TextEditingController(text: group.options.map((e) => e.label).join('\n'));
    String type = group.type;
    bool required = group.required;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Edit customization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Group name')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: const {'choice','color','size','text','font','icon','image','character'}.contains(type) ? type : 'choice',
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'choice', child: Text('Choice')),
                  DropdownMenuItem(value: 'color', child: Text('Color')),
                  DropdownMenuItem(value: 'size', child: Text('Size')),
                  DropdownMenuItem(value: 'text', child: Text('Text')),
                  DropdownMenuItem(value: 'font', child: Text('Font')),
                  DropdownMenuItem(value: 'icon', child: Text('Icon')),
                  DropdownMenuItem(value: 'image', child: Text('Image')),
                  DropdownMenuItem(value: 'character', child: Text('Character')),
                ],
                onChanged: (value) => setDialogState(() => type = value ?? 'choice'),
              ),
              const SizedBox(height: 10),
              TextField(controller: options, minLines: 2, maxLines: 7, decoration: const InputDecoration(labelText: 'Options', hintText: 'One option per line')),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: required, onChanged: (value) => setDialogState(() => required = value), title: const Text('Required')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (!mounted || result != true) {
      title.dispose();
      options.dispose();
      return;
    }
    final values = options.text.split(RegExp(r'[\n,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    group.title = title.text.trim().isEmpty ? group.title : title.text.trim();
    group.type = type;
    group.required = required;
    group.options = [
      for (var i = 0; i < values.length; i++)
        ShopCustomizationOption(
          id: i < group.options.length ? group.options[i].id : 'option_${DateTime.now().microsecondsSinceEpoch}_$i',
          label: values[i],
        ),
    ];
    title.dispose();
    options.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Product'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, groups),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          const Text('Buyer options', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Define what buyers can change. These groups are stored with the product and appear at checkout.'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(onPressed: () => _addGroup(preset: 'character'), icon: const Icon(Icons.person_outline), label: const Text('Character preset')),
              OutlinedButton.icon(onPressed: () => _addGroup(preset: 'clothing'), icon: const Icon(Icons.checkroom_outlined), label: const Text('Clothing preset')),
              OutlinedButton.icon(onPressed: () => _addGroup(preset: 'personalized'), icon: const Icon(Icons.text_fields_rounded), label: const Text('Personalized text')),
              FilledButton.icon(onPressed: _addGroup, icon: const Icon(Icons.add_rounded), label: const Text('Custom group')),
            ],
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            const Card(child: ListTile(leading: Icon(Icons.tune_rounded), title: Text('No buyer customization yet'), subtitle: Text('Add a group such as Size, Color, Text, Image, or Character.'))),
          for (final group in groups)
            Card(
              child: ListTile(
                leading: const Icon(Icons.drag_handle_rounded),
                title: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${group.type} • ${group.options.length} options${group.required ? ' • required' : ''}'),
                trailing: Wrap(children: [IconButton(onPressed: () => _editGroup(group), icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: () => setState(() => groups.remove(group)), icon: const Icon(Icons.delete_outline))]),
              ),
            ),
        ],
      ),
    );
  }
}

class ShopProductCustomizerScreen extends StatefulWidget {
  const ShopProductCustomizerScreen({
    super.key,
    required this.product,
  });

  final ShopProductSource product;

  @override
  State<ShopProductCustomizerScreen> createState() => _ShopProductCustomizerScreenState();
}

class _ShopProductCustomizerScreenState extends State<ShopProductCustomizerScreen> {
  final Map<String, dynamic> selections = <String, dynamic>{};
  final textController = TextEditingController();
  String? selectedUploadedImage;
  double textX = .5;
  double textY = .72;
  double imageX = .5;
  double imageY = .5;
  double textScale = 1;
  double imageScale = 1;
  String fontFamily = 'Sans';
  String textColor = '#FFFFFF';

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1600);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      selectedUploadedImage = 'data:image/${file.name.split('.').last.toLowerCase()};base64,${base64Encode(bytes)}';
      selections['imageUpload'] = selectedUploadedImage;
    });
  }

  double get _customPrice => widget.product.price + selections.values.whereType<Map>().fold<double>(0, (sum, value) => sum + ((value['priceAdjustment'] as num?)?.toDouble() ?? 0));

  void _setChoice(ShopCustomizationGroup group, ShopCustomizationOption option) {
    setState(() {
      if (group.maxSelections > 1) {
        final current = List<String>.from(selections[group.id] is List ? selections[group.id] as List : <String>[]);
        if (current.contains(option.id)) {
          current.remove(option.id);
        } else if (current.length < group.maxSelections) {
          current.add(option.id);
        }
        selections[group.id] = current;
      } else {
        selections[group.id] = {
          'optionId': option.id,
          'label': option.label,
          'value': option.value,
          'priceAdjustment': option.priceAdjustment,
        };
      }
    });
  }

  String? _selectionLabel(ShopCustomizationGroup group) {
    final value = selections[group.id];
    if (value is Map) return value['label']?.toString();
    if (value is List) return value.join(', ');
    return value?.toString();
  }

  Widget _group(ShopCustomizationGroup group) {
    switch (group.type) {
      case 'text':
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: textController,
              maxLength: 80,
              decoration: InputDecoration(labelText: group.title, hintText: 'Enter custom text'),
              onChanged: (value) => setState(() => selections[group.id] = value),
            ),
          ),
        );
      case 'color':
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final option in group.options) ChoiceChip(label: Text(option.label), selected: _selectionLabel(group) == option.label, onSelected: (_) => _setChoice(group, option))]),
            ]),
          ),
        );
      default:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(group.title, style: const TextStyle(fontWeight: FontWeight.w900))), if (group.required) const Text('Required', style: TextStyle(fontSize: 11))]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final option in group.options) ChoiceChip(label: Text(option.label), selected: _selectionLabel(group) == option.label || (selections[group.id] is List && (selections[group.id] as List).contains(option.id)), onSelected: (_) => _setChoice(group, option))]),
            ]),
          ),
        );
    }
  }

  Widget _preview() {
    final baseImage = widget.product.imageUrls.isEmpty ? null : widget.product.imageUrls.first;
    Widget base;
    if (baseImage == null) {
      base = const Center(child: Icon(Icons.shopping_bag_outlined, size: 72));
    } else if (baseImage.startsWith('data:image/')) {
      base = Image.memory(base64Decode(baseImage.substring(baseImage.indexOf(',') + 1)), fit: BoxFit.contain);
    } else {
      base = Image.network(baseImage, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 72));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.clamp(280.0, 620.0);
        return Center(
          child: Container(
            width: maxW,
            height: maxW,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
            child: Stack(children: [
              Positioned.fill(child: base),
              if (selectedUploadedImage != null)
                Align(
                  alignment: Alignment(imageX * 2 - 1, imageY * 2 - 1),
                  child: GestureDetector(
                    onPanUpdate: (details) => setState(() {
                      imageX = (imageX + details.delta.dx / maxW).clamp(0.08, 0.92);
                      imageY = (imageY + details.delta.dy / maxW).clamp(0.08, 0.92);
                    }),
                    child: Transform.scale(
                      scale: imageScale,
                      child: Container(
                        width: maxW * .35,
                        height: maxW * .35,
                        decoration: BoxDecoration(border: Border.all(color: Colors.white70), borderRadius: BorderRadius.circular(12)),
                        clipBehavior: Clip.antiAlias,
                        child: Image.memory(base64Decode(selectedUploadedImage!.substring(selectedUploadedImage!.indexOf(',') + 1)), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              if (textController.text.trim().isNotEmpty)
                Positioned(
                  left: (textX * maxW - maxW * .35).clamp(8.0, maxW - maxW * .68),
                  top: (textY * maxW - 30).clamp(8.0, maxW - 60),
                  child: GestureDetector(
                    onPanUpdate: (details) => setState(() {
                      textX = (textX + details.delta.dx / maxW).clamp(.05, .95);
                      textY = (textY + details.delta.dy / maxW).clamp(.05, .95);
                    }),
                    child: Transform.scale(scale: textScale, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)), child: Text(textController.text, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _parseColor(textColor), fontFamily: fontFamily == 'Sans' ? null : fontFamily)))),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }

  Color _parseColor(String value) {
    final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
    return parsed == null ? Colors.white : Color(0xFF000000 | parsed);
  }

  bool _valid() {
    for (final group in widget.product.customizationGroups) {
      if (!group.required) continue;
      final value = selections[group.id];
      if (value == null || (value is String && value.trim().isEmpty) || (value is List && value.isEmpty)) return false;
    }
    return true;
  }

  void _done() {
    if (!_valid()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete the required customization options.')));
      return;
    }
    final result = <String, dynamic>{
      'selections': copyCustomizationMap(selections),
      'imageUpload': selectedUploadedImage,
      'text': textController.text.trim(),
      'font': fontFamily,
      'textColor': textColor,
      'textX': textX,
      'textY': textY,
      'textScale': textScale,
      'imageX': imageX,
      'imageY': imageY,
      'imageScale': imageScale,
      'customPrice': _customPrice,
    };
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.product.customizationGroups;
    return Scaffold(
      appBar: AppBar(title: const Text('Customize Product')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final preview = SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(children: [
              _preview(),
              if (textController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Drag text or your uploaded image directly on the preview.'),
              ],
            ]));
            final controls = ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 28), children: [
              Card(child: ListTile(leading: const Icon(Icons.image_outlined), title: const Text('Choose your image'), subtitle: Text(selectedUploadedImage == null ? 'Use the seller image or upload your own.' : 'Custom image selected'), trailing: FilledButton.tonal(onPressed: _pickImage, child: const Text('Choose')))),
              const SizedBox(height: 8),
              if (groups.isEmpty) const Card(child: ListTile(title: Text('This product has no configurable options yet.'), subtitle: Text('The seller can add options from Seller Dashboard → Customize Product.'))),
              for (final group in groups) _group(group),
              Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Design tools', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                TextField(controller: textController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Text on product', hintText: 'Add text')),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [for (final font in ['Sans','Serif','Monospace']) ChoiceChip(label: Text(font), selected: fontFamily == font, onSelected: (_) => setState(() => fontFamily = font))]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [for (final color in ['#FFFFFF','#000000','#FF5252','#FFD740','#40C4FF','#E040FB']) ChoiceChip(label: const Text(''), avatar: CircleAvatar(backgroundColor: _parseColor(color)), selected: textColor == color, onSelected: (_) => setState(() => textColor = color))]),
                const SizedBox(height: 8),
                Row(children: [const Text('Text size'), Expanded(child: Slider(value: textScale, min: .7, max: 2.4, onChanged: (v) => setState(() => textScale = v)))]),
                Row(children: [const Text('Image size'), Expanded(child: Slider(value: imageScale, min: .5, max: 2.5, onChanged: (v) => setState(() => imageScale = v)))]),
              ]))),
              const SizedBox(height: 12),
              Card(child: ListTile(leading: const Icon(Icons.attach_money_rounded), title: const Text('Estimated price'), trailing: Text('${_customPrice.toStringAsFixed(2)} ${widget.product.currency}', style: const TextStyle(fontWeight: FontWeight.w900)))),
              const SizedBox(height: 12),
              SizedBox(height: 52, child: FilledButton.icon(onPressed: _done, icon: const Icon(Icons.check_rounded), label: const Text('Use this customization'))),
            ]);
            if (wide) return Row(children: [Expanded(child: preview), SizedBox(width: 420, child: controls)]);
            return controls;
          },
        ),
      ),
    );
  }
}
