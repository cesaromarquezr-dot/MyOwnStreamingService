// Events/occasions provide many-to-many context for media and themes.
//
// A media item can belong to multiple occasions at the same time. For
// example, The Nightmare Before Christmas can be associated with both
// Halloween and Christmas without creating duplicate media records.

enum MediaEventType {
  season,
  holiday,
  cultural,
  sports,
  special,
  custom,
}

class MediaEvent {
  final String id;
  final String name;
  final MediaEventType type;
  final String? themeId;
  final String? startMonthDay;
  final String? endMonthDay;
  final bool isActive;

  const MediaEvent({
    required this.id,
    required this.name,
    required this.type,
    this.themeId,
    this.startMonthDay,
    this.endMonthDay,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        if (themeId != null) 'themeId': themeId,
        if (startMonthDay != null) 'startMonthDay': startMonthDay,
        if (endMonthDay != null) 'endMonthDay': endMonthDay,
        'isActive': isActive,
      };

  factory MediaEvent.fromJson(Map<String, dynamic> json) {
    final type = MediaEventType.values.firstWhere(
      (value) => value.name == json['type']?.toString(),
      orElse: () => MediaEventType.custom,
    );
    return MediaEvent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: type,
      themeId: json['themeId']?.toString() ?? json['theme_id']?.toString(),
      startMonthDay: json['startMonthDay']?.toString(),
      endMonthDay: json['endMonthDay']?.toString(),
      isActive: json['isActive'] != false,
    );
  }
}

class MediaEventAssociation {
  final String mediaId;
  final String eventId;
  final double relevance;
  final String source;

  const MediaEventAssociation({
    required this.mediaId,
    required this.eventId,
    this.relevance = 1.0,
    this.source = 'editorial',
  });

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'eventId': eventId,
        'relevance': relevance,
        'source': source,
      };

  factory MediaEventAssociation.fromJson(Map<String, dynamic> json) => MediaEventAssociation(
        mediaId: json['mediaId']?.toString() ?? json['media_id']?.toString() ?? '',
        eventId: json['eventId']?.toString() ?? json['event_id']?.toString() ?? '',
        relevance: (json['relevance'] as num?)?.toDouble() ?? 1.0,
        source: json['source']?.toString() ?? 'editorial',
      );
}
