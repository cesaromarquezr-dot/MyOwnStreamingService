// Account-wide library publication scheduling. Physical media remains on the NAS.

enum LibraryAdditionStatus { scheduled, published, cancelled, failed }

class LibraryAddition {
  final String id;
  final String accountId;
  final String mediaId;
  final String title;
  final String mediaType;
  final DateTime scheduledFor;
  final String timeZone;
  LibraryAdditionStatus status;
  final DateTime createdAt;
  DateTime? publishedAt;
  DateTime? cancelledAt;

  LibraryAddition({
    required this.id,
    required this.accountId,
    required this.mediaId,
    required this.title,
    required this.mediaType,
    required this.scheduledFor,
    required this.timeZone,
    this.status = LibraryAdditionStatus.scheduled,
    DateTime? createdAt,
    this.publishedAt,
    this.cancelledAt,
  }) : createdAt = (createdAt ?? DateTime.now().toUtc()).toUtc();

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'mediaId': mediaId,
        'title': title,
        'mediaType': mediaType,
        'scheduledFor': scheduledFor.toUtc().toIso8601String(),
        'timeZone': timeZone,
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (publishedAt != null) 'publishedAt': publishedAt!.toUtc().toIso8601String(),
        if (cancelledAt != null) 'cancelledAt': cancelledAt!.toUtc().toIso8601String(),
      };
}
