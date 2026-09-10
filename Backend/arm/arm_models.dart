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

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'name': name,
        'available': available,
        'discInserted': discInserted,
      };
}

class ArmDisc {
  final String driveId;
  final String? title;
  final String? mediaType;
  final String? discType;
  final String? region;
  final bool detected;

  ArmDisc({
    required this.driveId,
    this.title,
    this.mediaType,
    this.discType,
    this.region,
    required this.detected,
  });

  factory ArmDisc.fromJson(Map<String, dynamic> json) => ArmDisc(
        driveId: json['driveId']?.toString() ?? '',
        title: json['title']?.toString(),
        mediaType: json['mediaType']?.toString(),
        discType: json['discType']?.toString(),
        region: json['region']?.toString(),
        detected: json['detected'] == true,
      );

  Map<String, dynamic> toJson() => {
        'driveId': driveId,
        'title': title,
        'mediaType': mediaType,
        'discType': discType,
        'region': region,
        'detected': detected,
      };
}

enum ArmJobStatus {
  queued,
  detecting,
  identifying,
  ripping,
  processing,
  verifying,
  readyForReview,
  completed,
  failed,
  rejected,
  cancelled,
}

class ArmVerificationResult {
  final bool passed;
  final double score;
  final String? reason;
  final List<String> checks;
  final List<String> failures;
  final double? durationSeconds;
  final double? expectedDurationSeconds;
  final int? chapterCount;
  final int? expectedChapterCount;
  final bool hasVideo;
  final bool hasAudio;
  final bool contentFingerprintAvailable;

  ArmVerificationResult({
    required this.passed,
    required this.score,
    this.reason,
    this.checks = const [],
    this.failures = const [],
    this.durationSeconds,
    this.expectedDurationSeconds,
    this.chapterCount,
    this.expectedChapterCount,
    this.hasVideo = false,
    this.hasAudio = false,
    this.contentFingerprintAvailable = false,
  });

  factory ArmVerificationResult.fromJson(Map<String, dynamic> json) =>
      ArmVerificationResult(
        passed: json['passed'] == true,
        score: json['score'] is num ? (json['score'] as num).toDouble() : 0,
        reason: json['reason']?.toString(),
        checks: _strings(json['checks']),
        failures: _strings(json['failures']),
        durationSeconds: _double(json['durationSeconds']),
        expectedDurationSeconds: _double(json['expectedDurationSeconds']),
        chapterCount: _int(json['chapterCount']),
        expectedChapterCount: _int(json['expectedChapterCount']),
        hasVideo: json['hasVideo'] == true,
        hasAudio: json['hasAudio'] == true,
        contentFingerprintAvailable: json['contentFingerprintAvailable'] == true,
      );

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'score': score,
        'reason': reason,
        'checks': checks,
        'failures': failures,
        'durationSeconds': durationSeconds,
        'expectedDurationSeconds': expectedDurationSeconds,
        'chapterCount': chapterCount,
        'expectedChapterCount': expectedChapterCount,
        'hasVideo': hasVideo,
        'hasAudio': hasAudio,
        'contentFingerprintAvailable': contentFingerprintAvailable,
      };

  static List<String> _strings(dynamic value) =>
      value is List ? value.map((e) => e.toString()).toList() : <String>[];

  static double? _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

  static int? _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
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
  String? discType;
  String? region;
  DateTime createdAt;
  DateTime? completedAt;
  ArmVerificationResult? verification;

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
    this.discType,
    this.region,
    this.completedAt,
    this.verification,
  });

  bool get isFinished =>
      {
        ArmJobStatus.completed.name,
        ArmJobStatus.failed.name,
        ArmJobStatus.rejected.name,
        ArmJobStatus.cancelled.name,
        ArmJobStatus.readyForReview.name,
      }.contains(status);

  Map<String, dynamic> toJson() => {
        'id': id,
        'driveId': driveId,
        'status': status,
        'progress': progress,
        'title': title,
        'mediaType': mediaType,
        'message': message,
        'outputPath': outputPath,
        'discType': discType,
        'region': region,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'isFinished': isFinished,
        'verification': verification?.toJson(),
      };
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

  Map<String, dynamic> toJson() => {
        'success': success,
        'jobId': jobId,
        'message': message,
        'job': job?.toJson(),
      };
}
