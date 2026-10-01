enum MediaImportKind {
  movie,
  tv,
  music,
}

enum MediaImportState {
  detecting,
  ripping,
  staging,
  analyzing,
  verifying,
  matching,
  review,
  approved,
  transferring,
  completed,
  failed,
  cancelled,
}

class MediaImportJob {
  final String id;
  final MediaImportKind kind;
  final MediaImportState state;
  final double progress;
  final String? mediaTitle;
  final String? sourceDriveId;
  final String? destinationServerId;
  final int verifiedItems;
  final int totalItems;
  final String? error;

  const MediaImportJob({
    required this.id,
    required this.kind,
    required this.state,
    this.progress = 0,
    this.mediaTitle,
    this.sourceDriveId,
    this.destinationServerId,
    this.verifiedItems = 0,
    this.totalItems = 0,
    this.error,
  });

  factory MediaImportJob.fromJson(Map<String, dynamic> json) {
    MediaImportKind parseKind(dynamic value) => MediaImportKind.values.firstWhere(
          (item) => item.name == value?.toString(),
          orElse: () => MediaImportKind.movie,
        );
    MediaImportState parseState(dynamic value) => MediaImportState.values.firstWhere(
          (item) => item.name == value?.toString(),
          orElse: () => MediaImportState.detecting,
        );

    return MediaImportJob(
      id: json['id']?.toString() ?? '',
      kind: parseKind(json['kind']),
      state: parseState(json['state']),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      mediaTitle: json['mediaTitle']?.toString() ?? json['media_title']?.toString(),
      sourceDriveId: json['sourceDriveId']?.toString() ?? json['source_drive_id']?.toString(),
      destinationServerId: json['destinationServerId']?.toString() ?? json['destination_server_id']?.toString(),
      verifiedItems: (json['verifiedItems'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      error: json['error']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'state': state.name,
        'progress': progress,
        if (mediaTitle != null) 'mediaTitle': mediaTitle,
        if (sourceDriveId != null) 'sourceDriveId': sourceDriveId,
        if (destinationServerId != null) 'destinationServerId': destinationServerId,
        'verifiedItems': verifiedItems,
        'totalItems': totalItems,
        if (error != null) 'error': error,
      };
}
