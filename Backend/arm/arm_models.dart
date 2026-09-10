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


class ArmDiscTitle {
  final String id;
  final String title;
  final String mediaType;
  final String? classification;
  final int? year;
  final double? durationSeconds;
  final double confidence;
  final String? outputPath;
  final Map<String, dynamic> metadata;

  ArmDiscTitle({
    required this.id,
    required this.title,
    this.mediaType = 'movie',
    this.classification = 'feature',
    this.year,
    this.durationSeconds,
    this.confidence = 0,
    this.outputPath,
    this.metadata = const {},
  });

  bool get isFeatureMovie {
    final type = mediaType.toLowerCase();
    final kind = (classification ?? '').toLowerCase();
    return (type.contains('movie') || type.contains('film')) &&
        (kind.isEmpty || kind == 'feature' || kind == 'feature_film' || kind == 'main_feature');
  }

  factory ArmDiscTitle.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    final rawConfidence = json['confidence'] ?? json['matchConfidence'];
    return ArmDiscTitle(
      id: json['id']?.toString() ?? json['titleId']?.toString() ?? fallbackId ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Unknown title',
      mediaType: json['mediaType']?.toString() ?? json['type']?.toString() ?? json['videotype']?.toString() ?? 'movie',
      classification: json['classification']?.toString() ?? json['kind']?.toString() ?? json['contentType']?.toString() ?? 'feature',
      year: _int(json['year'] ?? json['releaseYear']),
      durationSeconds: _double(json['durationSeconds'] ?? json['duration'] ?? json['runtime'] ?? json['length']),
      confidence: rawConfidence is num ? rawConfidence.toDouble() : double.tryParse(rawConfidence?.toString() ?? '') ?? 0,
      outputPath: json['outputPath']?.toString() ?? json['output_path']?.toString() ?? json['path']?.toString(),
      metadata: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'mediaType': mediaType,
        'classification': classification,
        'year': year,
        'durationSeconds': durationSeconds,
        'confidence': confidence,
        'outputPath': outputPath,
        'metadata': metadata,
      };

  static double? _double(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
  static int? _int(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}

class ArmDisc {
  final String driveId;
  final String? title;
  final String? mediaType;
  final String? discType;
  final String? region;
  final bool detected;
  final List<ArmDiscTitle> titles;

  ArmDisc({
    required this.driveId,
    this.title,
    this.mediaType,
    this.discType,
    this.region,
    required this.detected,
    this.titles = const [],
  });

  factory ArmDisc.fromJson(Map<String, dynamic> json) => ArmDisc(
        driveId: json['driveId']?.toString() ?? '',
        title: json['title']?.toString(),
        mediaType: json['mediaType']?.toString(),
        discType: json['discType']?.toString(),
        region: json['region']?.toString(),
        detected: json['detected'] == true,
        titles: json['titles'] is List
            ? (json['titles'] as List).whereType<Map>().map((e) => ArmDiscTitle.fromJson(Map<String, dynamic>.from(e))).toList()
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'driveId': driveId,
        'title': title,
        'mediaType': mediaType,
        'discType': discType,
        'region': region,
        'detected': detected,
        'titles': titles.map((title) => title.toJson()).toList(),
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
  List<ArmDiscTitle> titles;
  String? collectionTitle;

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
    this.titles = const [],
    this.collectionTitle,
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
        'collectionTitle': collectionTitle,
        'titleCount': titles.length,
        'titles': titles.map((title) => title.toJson()).toList(),
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
