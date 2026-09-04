class ArmDrive {
  final String id;
  final String path;
  final String name;
  final bool available;
  final bool discInserted;

  ArmDrive({
    required this.id,
    required this.path,
    required this.name,
    required this.available,
    required this.discInserted,
  });

  factory ArmDrive.fromJson(Map<String, dynamic> json) {
    return ArmDrive(
      id: json['id']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      available: json['available'] == true,
      discInserted: json['discInserted'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'name': name,
      'available': available,
      'discInserted': discInserted,
    };
  }
}


class ArmDisc {
  final String driveId;
  final String? title;
  final String? mediaType;
  final String? discType;
  final bool detected;

  ArmDisc({
    required this.driveId,
    this.title,
    this.mediaType,
    this.discType,
    required this.detected,
  });

  factory ArmDisc.fromJson(Map<String, dynamic> json) {
    return ArmDisc(
      driveId: json['driveId']?.toString() ?? '',
      title: json['title']?.toString(),
      mediaType: json['mediaType']?.toString(),
      discType: json['discType']?.toString(),
      detected: json['detected'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driveId': driveId,
      'title': title,
      'mediaType': mediaType,
      'discType': discType,
      'detected': detected,
    };
  }
}


enum ArmJobStatus {
  queued,
  detecting,
  identifying,
  ripping,
  processing,
  completed,
  failed,
  cancelled,
}


class ArmRipJob {
  final String id;

  final String driveId;

  String status;

  double progress;

  String? title;

  String? mediaType;

  String? message;

  String? outputPath;

  DateTime createdAt;

  DateTime? completedAt;

  ArmRipJob({
    required this.id,
    required this.driveId,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.title,
    this.mediaType,
    this.message,
    this.outputPath,
    this.completedAt,
  });

  bool get isFinished {
    return status == ArmJobStatus.completed.name ||
        status == ArmJobStatus.failed.name ||
        status == ArmJobStatus.cancelled.name;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driveId': driveId,
      'status': status,
      'progress': progress,
      'title': title,
      'mediaType': mediaType,
      'message': message,
      'outputPath': outputPath,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isFinished': isFinished,
    };
  }
}


class ArmImportResult {
  final bool success;
  final String? jobId;
  final String? message;
  final ArmRipJob? job;

  ArmImportResult({
    required this.success,
    this.jobId,
    this.message,
    this.job,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'jobId': jobId,
      'message': message,
      'job': job?.toJson(),
    };
  }
}