import 'dart:convert';


abstract class ShopProductSource {
  String get id;
  String get name;
  String get currency;
  double get price;
  List<String> get imageUrls;
  List<ShopCustomizationGroup> get customizationGroups;
}

class ShopCustomizationOption {
  final String id;
  String label;
  String value;
  double priceAdjustment;
  Map<String, dynamic> metadata;

  ShopCustomizationOption({
    required this.id,
    required this.label,
    String? value,
    this.priceAdjustment = 0,
    Map<String, dynamic>? metadata,
  })  : value = value ?? label,
        metadata = metadata ?? <String, dynamic>{};

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'value': value,
        'priceAdjustment': priceAdjustment,
        'metadata': metadata,
      };

  factory ShopCustomizationOption.fromJson(Map<String, dynamic> json) =>
      ShopCustomizationOption(
        id: json['id']?.toString() ?? 'option_${DateTime.now().microsecondsSinceEpoch}',
        label: json['label']?.toString() ?? json['value']?.toString() ?? 'Option',
        value: json['value']?.toString(),
        priceAdjustment: json['priceAdjustment'] is num
            ? (json['priceAdjustment'] as num).toDouble()
            : double.tryParse(json['priceAdjustment']?.toString() ?? '') ?? 0,
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : <String, dynamic>{},
      );
}

class ShopCustomizationGroup {
  final String id;
  String title;
  String type;
  bool required;
  int maxSelections;
  List<ShopCustomizationOption> options;

  ShopCustomizationGroup({
    required this.id,
    required this.title,
    this.type = 'choice',
    this.required = false,
    this.maxSelections = 1,
    List<ShopCustomizationOption>? options,
  }) : options = options ?? <ShopCustomizationOption>[];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'required': required,
        'maxSelections': maxSelections,
        'options': options.map((e) => e.toJson()).toList(),
      };

  factory ShopCustomizationGroup.fromJson(Map<String, dynamic> json) =>
      ShopCustomizationGroup(
        id: json['id']?.toString() ?? 'group_${DateTime.now().microsecondsSinceEpoch}',
        title: json['title']?.toString() ?? 'Customization',
        type: json['type']?.toString() ?? 'choice',
        required: json['required'] == true,
        maxSelections: (json['maxSelections'] as num?)?.toInt() ?? 1,
        options: (json['options'] as List?)
                ?.whereType<Map>()
                .map((e) => ShopCustomizationOption.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            <ShopCustomizationOption>[],
      );
}

Map<String, dynamic> copyCustomizationMap(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) is Map
        ? Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map)
        : <String, dynamic>{};

String customizationKey(Map<String, dynamic> customization) {
  final normalized = <String, dynamic>{...customization};
  final selections = normalized['selections'];
  if (selections is Map) {
    final keys = selections.keys.map((e) => e.toString()).toList()..sort();
    normalized['selections'] = <String, dynamic>{
      for (final key in keys) key: selections[key],
    };
  }
  return jsonEncode(normalized);
}

