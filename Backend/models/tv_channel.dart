class TvChannelDefinition {
  final String id;
  final String name;
  final String description;
  final List<String> filters;
  final List<String> contentTypes;
  final bool seasonal;
  final int priority;

  const TvChannelDefinition({
    required this.id,
    required this.name,
    this.description = '',
    this.filters = const [],
    this.contentTypes = const ['Movies', 'Shows'],
    this.seasonal = false,
    this.priority = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'filters': filters,
        'contentTypes': contentTypes,
        'seasonal': seasonal,
        'priority': priority,
      };
}
