// FILE: Backend/models/physical_item.dart.
// Purpose: Records an account-owned physical media copy independently from
// its retail release, canonical work, disc contents, and imported server files.

enum PhysicalMediaFormat { uhd4k, bluRay, dvd, cd, other }

enum PhysicalOwnershipStatus { owned, loaned, lost, damaged, sold, archived }

class PhysicalOwnershipChange {
  final PhysicalOwnershipStatus status;
  final DateTime changedAt;
  final String? note;
  final String? actorId;

  const PhysicalOwnershipChange({
    required this.status,
    required this.changedAt,
    this.note,
    this.actorId,
  });

  factory PhysicalOwnershipChange.fromJson(Map<String, dynamic> json) =>
      PhysicalOwnershipChange(
        status: _ownershipStatus(json['status']),
        changedAt: _date(json['changedAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        note: _optionalText(json['note']),
        actorId: _optionalText(json['actorId']),
      );

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'changedAt': changedAt.toUtc().toIso8601String(),
        'note': note,
        'actorId': actorId,
      };
}

/// One account's physical copy of a release. This is ownership evidence,
/// not a playable media record; imported server files link to it separately.
class PhysicalItem {
  final String id;
  final String accountId;
  final String title;
  final PhysicalMediaFormat format;
  final String? region;
  final String? edition;
  final String? editionId;
  final String? physicalReleaseId;
  final DateTime? releaseDate;
  final String? barcode;
  final String? catalogNumber;
  final int discCount;
  final DateTime acquiredAt;
  final String? condition;
  final PhysicalOwnershipStatus ownershipStatus;
  final String? notes;
  final String? artworkUrl;
  final List<String> includedExtras;
  final List<PhysicalOwnershipChange> ownershipHistory;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PhysicalItem({
    required this.id,
    required this.accountId,
    required this.title,
    required this.format,
    required this.discCount,
    required this.acquiredAt,
    required this.ownershipStatus,
    required this.createdAt,
    required this.updatedAt,
    this.region,
    this.edition,
    this.editionId,
    this.physicalReleaseId,
    this.releaseDate,
    this.barcode,
    this.catalogNumber,
    this.condition,
    this.notes,
    this.artworkUrl,
    this.includedExtras = const [],
    this.ownershipHistory = const [],
  });

  factory PhysicalItem.fromJson(Map<String, dynamic> json) {
    final now = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return PhysicalItem(
      id: _requiredText(json['id'], 'id'),
      accountId: _requiredText(json['accountId'], 'accountId'),
      title: _requiredText(json['title'], 'title'),
      format: _mediaFormat(json['format']),
      region: _optionalText(json['region']),
      edition: _optionalText(json['edition']),
      editionId: _optionalText(json['editionId']),
      physicalReleaseId: _optionalText(json['physicalReleaseId']),
      releaseDate: _date(json['releaseDate']),
      barcode: _optionalText(json['barcode']),
      catalogNumber: _optionalText(json['catalogNumber']),
      discCount: _positiveInt(json['discCount'], fallback: 1),
      acquiredAt: _date(json['acquiredAt']) ?? now,
      condition: _optionalText(json['condition']),
      ownershipStatus: _ownershipStatus(json['ownershipStatus']),
      notes: _optionalText(json['notes']),
      artworkUrl: _optionalText(json['artworkUrl']),
      includedExtras: _stringList(json['includedExtras']),
      ownershipHistory: _mapList(json['ownershipHistory'])
          .map(PhysicalOwnershipChange.fromJson)
          .toList(growable: false),
      createdAt: _date(json['createdAt']) ?? now,
      updatedAt: _date(json['updatedAt']) ?? now,
    );
  }

  PhysicalItem changeOwnership({
    required PhysicalOwnershipStatus status,
    required String actorId,
    String? note,
    DateTime? changedAt,
  }) {
    final timestamp = (changedAt ?? DateTime.now()).toUtc();
    return PhysicalItem(
      id: id,
      accountId: accountId,
      title: title,
      format: format,
      region: region,
      edition: edition,
      editionId: editionId,
      physicalReleaseId: physicalReleaseId,
      releaseDate: releaseDate,
      barcode: barcode,
      catalogNumber: catalogNumber,
      discCount: discCount,
      acquiredAt: acquiredAt,
      condition: condition,
      ownershipStatus: status,
      notes: notes,
      artworkUrl: artworkUrl,
      includedExtras: includedExtras,
      ownershipHistory: [
        ...ownershipHistory,
        PhysicalOwnershipChange(
          status: status,
          changedAt: timestamp,
          note: note,
          actorId: actorId,
        ),
      ],
      createdAt: createdAt,
      updatedAt: timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'title': title,
        'format': format.name,
        'region': region,
        'edition': edition,
        'editionId': editionId,
        'physicalReleaseId': physicalReleaseId,
        'releaseDate': releaseDate?.toUtc().toIso8601String(),
        'barcode': barcode,
        'catalogNumber': catalogNumber,
        'discCount': discCount,
        'acquiredAt': acquiredAt.toUtc().toIso8601String(),
        'condition': condition,
        'ownershipStatus': ownershipStatus.name,
        'notes': notes,
        'artworkUrl': artworkUrl,
        'includedExtras': includedExtras,
        'ownershipHistory':
            ownershipHistory.map((change) => change.toJson()).toList(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

String _requiredText(dynamic value, String field) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) throw FormatException('$field is required.');
  return text;
}

String? _optionalText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) => value is DateTime
    ? value.toUtc()
    : DateTime.tryParse(value?.toString() ?? '')?.toUtc();

int _positiveInt(dynamic value, {required int fallback}) {
  final parsed = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : fallback;
}

List<String> _stringList(dynamic value) => value is Iterable
    ? value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false)
    : const [];

List<Map<String, dynamic>> _mapList(dynamic value) => value is Iterable
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false)
    : const [];

PhysicalMediaFormat _mediaFormat(dynamic value) {
  final key = value
          ?.toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '') ??
      '';
  return switch (key) {
    'uhd4k' || '4kuhd' || 'uhd' => PhysicalMediaFormat.uhd4k,
    'bluray' || 'bd' => PhysicalMediaFormat.bluRay,
    'dvd' => PhysicalMediaFormat.dvd,
    'cd' => PhysicalMediaFormat.cd,
    _ => PhysicalMediaFormat.other,
  };
}

PhysicalOwnershipStatus _ownershipStatus(dynamic value) {
  final key = value?.toString().trim().toLowerCase() ?? '';
  for (final status in PhysicalOwnershipStatus.values) {
    if (status.name.toLowerCase() == key) return status;
  }
  throw FormatException('Unknown physical ownership status: $key');
}
