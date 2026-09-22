// FILE: Backend/models/shop_entity.dart.
//
// Purpose: Represents a globally searchable marketplace association entity.
//
// Entity metadata is intentionally lightweight. Physical media, private
// account content, library files, and source-server details remain on their
// originating servers.
//
// This model is metadata/index information only. It does not grant access to
// the underlying entity.

class ShopEntity {
  /// Logical entity category, for example movie, show, person, artist,
  /// collection, or other application-defined type.
  final String type;

  /// Stable identifier for the entity within its source namespace.
  final String id;

  /// Public/searchable display name.
  final String name;

  /// Optional searchable/display subtitle.
  final String subtitle;

  /// Optional globally safe external account identifier.
  ///
  /// This must not contain credentials, session tokens, email addresses, or
  /// other private authentication material.
  final String? accountExternalId;

  /// Whether this association is eligible for the global marketplace/search
  /// surface.
  final bool isPublic;

  const ShopEntity({
    required this.type,
    required this.id,
    required this.name,
    this.subtitle = '',
    this.accountExternalId,
    this.isPublic = true,
  });

  /// Whether the entity contains the minimum information needed for a
  /// marketplace association.
  bool get isValid =>
      type.trim().isNotEmpty &&
      id.trim().isNotEmpty &&
      name.trim().isNotEmpty;

  bool get hasSubtitle => subtitle.trim().isNotEmpty;

  bool get hasAccountExternalId =>
      accountExternalId != null &&
      accountExternalId!.trim().isNotEmpty;

  /// A normalized representation useful for case-insensitive search/indexing.
  String get normalizedName => name.trim().toLowerCase();

  /// Creates a modified copy without changing the existing entity.
  ShopEntity copyWith({
    String? type,
    String? id,
    String? name,
    String? subtitle,
    String? accountExternalId,
    bool? isPublic,
    bool clearSubtitle = false,
    bool clearAccountExternalId = false,
  }) {
    return ShopEntity(
      type: type ?? this.type,
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: clearSubtitle ? '' : (subtitle ?? this.subtitle),
      accountExternalId: clearAccountExternalId
          ? null
          : (accountExternalId ?? this.accountExternalId),
      isPublic: isPublic ?? this.isPublic,
    );
  }

  /// Performs `fromJson` for this feature.
  ///
  /// Unknown/missing values remain compatible with the original model:
  /// missing types become `other`, missing strings become empty strings, and
  /// missing `isPublic` remains public.
  factory ShopEntity.fromJson(Map<String, dynamic> json) {
    return ShopEntity(
      type: _stringValue(
        json['type'],
        fallback: 'other',
      ),
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      subtitle: _stringValue(json['subtitle']),
      accountExternalId: _nullableString(
        json['accountExternalId'],
      ),
      isPublic: _boolValue(
        json['isPublic'],
        fallback: true,
      ),
    );
  }

  /// Performs `toJson` for this feature.
  ///
  /// This is the lightweight marketplace representation. It intentionally
  /// does not include private source-server paths, library files, credentials,
  /// or media payloads.
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'accountExternalId': accountExternalId,
        'isPublic': isPublic,
      };

  /// Returns the searchable fields without exposing any additional account
  /// information.
  Map<String, dynamic> toSearchJson() => {
        'type': type,
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'isPublic': isPublic,
      };

  @override
  String toString() {
    return 'ShopEntity('
        'type: $type, '
        'id: $id, '
        'name: $name, '
        'subtitle: $subtitle, '
        'accountExternalId: ${hasAccountExternalId ? '[present]' : '[none]'}, '
        'isPublic: $isPublic'
        ')';
  }
}

String _stringValue(
  dynamic value, {
  String fallback = '',
}) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(dynamic value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _boolValue(
  dynamic value, {
  bool fallback = false,
}) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'y':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'n':
        return false;
    }
  }

  return fallback;
}