/// Canonical person identity shared by acting, music, production, and other
/// entertainment careers.
class MediaPerson {
  final String id;
  final String name;
  final String? sortName;
  final String? biography;
  final int? birthYear;

  const MediaPerson({
    required this.id,
    required this.name,
    this.sortName,
    this.biography,
    this.birthYear,
  });

  bool get isValid => id.trim().isNotEmpty && name.trim().isNotEmpty;

  factory MediaPerson.fromJson(Map<String, dynamic> json) => MediaPerson(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        sortName: json['sortName']?.toString(),
        biography: json['biography']?.toString(),
        birthYear: _personInt(json['birthYear']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sortName': sortName,
        'biography': biography,
        'birthYear': birthYear,
      };
}

/// A sourced credit connects one person to one canonical media work. Category
/// and role remain open strings so one timeline can grow beyond acting/music.
class PersonCareerCredit {
  final String id;
  final String personId;
  final String mediaId;
  final String category;
  final String role;
  final String? characterName;
  final String? creditGroup;
  final int? startYear;
  final int? endYear;
  final String? source;

  const PersonCareerCredit({
    required this.id,
    required this.personId,
    required this.mediaId,
    required this.category,
    this.role = '',
    this.characterName,
    this.creditGroup,
    this.startYear,
    this.endYear,
    this.source,
  });

  bool get isValid => id.trim().isNotEmpty && personId.trim().isNotEmpty &&
      mediaId.trim().isNotEmpty && category.trim().isNotEmpty;

  factory PersonCareerCredit.fromJson(Map<String, dynamic> json) => PersonCareerCredit(
        id: (json['id'] ?? '').toString(),
        personId: (json['personId'] ?? '').toString(),
        mediaId: (json['mediaId'] ?? '').toString(),
        category: (json['category'] ?? '').toString(),
        role: (json['role'] ?? '').toString(),
        characterName: json['characterName']?.toString(),
        creditGroup: json['creditGroup']?.toString(),
        startYear: _personInt(json['startYear']),
        endYear: _personInt(json['endYear']),
        source: json['source']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'mediaId': mediaId,
        'category': category,
        'role': role,
        'characterName': characterName,
        'creditGroup': creditGroup,
        'startYear': startYear,
        'endYear': endYear,
        'source': source,
      };
}

int? _personInt(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
