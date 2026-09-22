// FILE: `Backend/models/remote_worker.dart`.
// Purpose: Implements the remote worker portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Remote workers are trusted execution agents that may perform work away from
// the primary server, such as ARM disc detection/ripping or other import jobs.
//
// Security boundary:
// - `token` is worker authentication material.
// - Tokens are never serialized unless explicitly requested.
// - Do not log, display, or expose worker tokens through public API responses.
// - Authorization and token verification belong to the authentication/
//   persistence layer, not this model.

class RemoteWorker {
  final String id;
  final String accountId;
  final String name;
  final String platform;
  final bool hasDiscReader;
  final bool supportsExternalReader;
  final DateTime createdAt;
  DateTime lastSeenAt;

  /// Authentication material used by the remote worker.
  ///
  /// Keep this value backend-only. Do not expose it through normal API
  /// serialization or diagnostic output.
  final String token;

  RemoteWorker({
    required this.id,
    required this.accountId,
    required this.name,
    required this.platform,
    required this.hasDiscReader,
    required this.supportsExternalReader,
    required this.createdAt,
    required this.lastSeenAt,
    required this.token,
  });

  /// Whether the worker has a usable identity.
  bool get isValid =>
      id.trim().isNotEmpty &&
      accountId.trim().isNotEmpty &&
      name.trim().isNotEmpty &&
      platform.trim().isNotEmpty;

  /// Whether the worker has a configured authentication token.
  bool get hasToken => token.trim().isNotEmpty;

  /// Whether the worker can perform local optical-disc work.
  bool get canReadDiscs => hasDiscReader;

  /// Whether the worker can use a reader attached elsewhere.
  bool get canUseExternalReader => supportsExternalReader;

  /// Returns true when the worker can participate in ARM disc work.
  bool get supportsArm =>
      hasDiscReader || supportsExternalReader;

  /// Returns the last-seen timestamp without exposing any authentication
  /// material.
  DateTime get lastSeen => lastSeenAt;

  /// Marks the worker as having checked in.
  void touch([DateTime? timestamp]) {
    lastSeenAt = timestamp ?? DateTime.now();
  }

  /// Determines whether the worker has checked in within [timeout].
  ///
  /// This is a liveness helper only. A production worker registry should
  /// enforce heartbeat/lease expiration at the service or persistence layer.
  bool isRecentlySeen({
    Duration timeout = const Duration(minutes: 2),
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    return current.difference(lastSeenAt) <= timeout;
  }

  /// Creates a modified worker while preserving the authentication token
  /// unless [token] is explicitly supplied.
  RemoteWorker copyWith({
    String? id,
    String? accountId,
    String? name,
    String? platform,
    bool? hasDiscReader,
    bool? supportsExternalReader,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    String? token,
    bool clearToken = false,
  }) {
    return RemoteWorker(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      hasDiscReader: hasDiscReader ?? this.hasDiscReader,
      supportsExternalReader:
          supportsExternalReader ?? this.supportsExternalReader,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      token: clearToken ? '' : (token ?? this.token),
    );
  }

  /// Performs `fromJson` for this feature.
  ///
  /// `workerToken` is accepted for backend/internal persistence compatibility.
  /// Public API responses should normally omit it.
  factory RemoteWorker.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    return RemoteWorker(
      id: _stringValue(json['id']),
      accountId: _stringValue(json['accountId']),
      name: _stringValue(json['name']),
      platform: _stringValue(json['platform']),
      hasDiscReader: _boolValue(json['hasDiscReader']),
      supportsExternalReader: _boolValue(json['supportsExternalReader']),
      createdAt: _dateTimeValue(json['createdAt']) ?? now,
      lastSeenAt: _dateTimeValue(json['lastSeenAt']) ?? now,
      token: _stringValue(json['workerToken'] ?? json['token']),
    );
  }

  /// Performs `toJson` for this feature.
  ///
  /// Authentication material is excluded by default. Only trusted internal
  /// persistence/registration flows should explicitly request it.
  Map<String, dynamic> toJson({bool includeToken = false}) => {
        'id': id,
        'accountId': accountId,
        'name': name,
        'platform': platform,
        'hasDiscReader': hasDiscReader,
        'supportsExternalReader': supportsExternalReader,
        'createdAt': createdAt.toIso8601String(),
        'lastSeenAt': lastSeenAt.toIso8601String(),
        if (includeToken) 'workerToken': token,
      };

  @override
  String toString() {
    return 'RemoteWorker('
        'id: $id, '
        'accountId: $accountId, '
        'name: $name, '
        'platform: $platform, '
        'hasDiscReader: $hasDiscReader, '
        'supportsExternalReader: $supportsExternalReader, '
        'createdAt: $createdAt, '
        'lastSeenAt: $lastSeenAt, '
        'hasToken: $hasToken'
        ')';
  }
}

class RemoteImportJob {
  final String id;
  final String accountId;
  final String workerId;
  final String driveName;

  /// Lifecycle state, for example:
  /// queued, detecting, ripping, verifying, importing, completed, failed,
  /// cancelled.
  String status;

  /// Normalized to the inclusive range 0.0–1.0.
  double progress;

  String? title;
  String? message;
  final DateTime createdAt;

  /// Optional completion timestamp.
  DateTime? completedAt;

  /// Optional physical-release/disc identifiers produced by ARM ingestion.
  ///
  /// These remain nullable so existing remote jobs remain compatible with
  /// the original model.
  String? physicalReleaseId;
  String? physicalDiscId;

  /// Optional imported disc-content identifier.
  String? discContentId;

  /// Optional canonical recording identifier for music imports.
  String? canonicalRecordingId;

  RemoteImportJob({
    required this.id,
    required this.accountId,
    required this.workerId,
    required this.driveName,
    this.status = 'queued',
    this.progress = 0,
    this.title,
    this.message,
    required this.createdAt,
    this.completedAt,
    this.physicalReleaseId,
    this.physicalDiscId,
    this.discContentId,
    this.canonicalRecordingId,
  });

  bool get isQueued => status.toLowerCase() == 'queued';

  bool get isActive {
    switch (status.toLowerCase()) {
      case 'detecting':
      case 'ripping':
      case 'verifying':
      case 'importing':
        return true;
      default:
        return false;
    }
  }

  bool get isCompleted =>
      status.toLowerCase() == 'completed';

  bool get isFailed =>
      status.toLowerCase() == 'failed';

  bool get isCancelled =>
      status.toLowerCase() == 'cancelled';

  bool get isTerminal =>
      isCompleted || isFailed || isCancelled;

  bool get isFinished => isTerminal;

  bool get hasPhysicalProvenance =>
      _hasText(physicalReleaseId) ||
      _hasText(physicalDiscId) ||
      _hasText(discContentId);

  bool get hasCanonicalRecording =>
      _hasText(canonicalRecordingId);

  bool get isValid =>
      id.trim().isNotEmpty &&
      accountId.trim().isNotEmpty &&
      workerId.trim().isNotEmpty &&
      driveName.trim().isNotEmpty &&
      status.trim().isNotEmpty;

  /// Updates progress while keeping it inside the valid range.
  void setProgress(double value) {
    progress = _clampProgress(value);
  }

  /// Marks the job as completed and records the completion time.
  void complete({
    DateTime? timestamp,
    String? message,
  }) {
    status = 'completed';
    progress = 1.0;
    completedAt = timestamp ?? DateTime.now();

    if (message != null) {
      this.message = message;
    }
  }

  /// Marks the job as failed.
  void fail(
    String message, {
    DateTime? timestamp,
  }) {
    status = 'failed';
    this.message = message;
    completedAt = timestamp ?? DateTime.now();
  }

  /// Marks the job as cancelled.
  void cancel({
    String? message,
    DateTime? timestamp,
  }) {
    status = 'cancelled';

    if (message != null) {
      this.message = message;
    }

    completedAt = timestamp ?? DateTime.now();
  }

  RemoteImportJob copyWith({
    String? id,
    String? accountId,
    String? workerId,
    String? driveName,
    String? status,
    double? progress,
    String? title,
    String? message,
    DateTime? createdAt,
    DateTime? completedAt,
    String? physicalReleaseId,
    String? physicalDiscId,
    String? discContentId,
    String? canonicalRecordingId,
    bool clearTitle = false,
    bool clearMessage = false,
    bool clearCompletedAt = false,
    bool clearPhysicalReleaseId = false,
    bool clearPhysicalDiscId = false,
    bool clearDiscContentId = false,
    bool clearCanonicalRecordingId = false,
  }) {
    return RemoteImportJob(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      workerId: workerId ?? this.workerId,
      driveName: driveName ?? this.driveName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      title: clearTitle ? null : (title ?? this.title),
      message: clearMessage ? null : (message ?? this.message),
      createdAt: createdAt ?? this.createdAt,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      physicalReleaseId: clearPhysicalReleaseId
          ? null
          : (physicalReleaseId ?? this.physicalReleaseId),
      physicalDiscId: clearPhysicalDiscId
          ? null
          : (physicalDiscId ?? this.physicalDiscId),
      discContentId: clearDiscContentId
          ? null
          : (discContentId ?? this.discContentId),
      canonicalRecordingId: clearCanonicalRecordingId
          ? null
          : (canonicalRecordingId ?? this.canonicalRecordingId),
    );
  }

  /// Performs `fromJson` for this feature.
  factory RemoteImportJob.fromJson(Map<String, dynamic> json) {
    return RemoteImportJob(
      id: _stringValue(json['id']),
      accountId: _stringValue(json['accountId']),
      workerId: _stringValue(json['workerId']),
      driveName: _stringValue(json['driveName']),
      status: _stringValue(json['status'], fallback: 'queued'),
      progress: _doubleValue(json['progress']),
      title: _nullableString(json['title']),
      message: _nullableString(json['message']),
      createdAt:
          _dateTimeValue(json['createdAt']) ?? DateTime.now(),
      completedAt: _dateTimeValue(json['completedAt']),
      physicalReleaseId:
          _nullableString(json['physicalReleaseId']),
      physicalDiscId:
          _nullableString(json['physicalDiscId']),
      discContentId:
          _nullableString(json['discContentId']),
      canonicalRecordingId:
          _nullableString(json['canonicalRecordingId']),
    );
  }

  /// Performs `toJson` for this feature.
  ///
  /// No authentication material is stored in this job model.
  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'workerId': workerId,
        'driveName': driveName,
        'status': status,
        'progress': progress,
        'title': title,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'physicalReleaseId': physicalReleaseId,
        'physicalDiscId': physicalDiscId,
        'discContentId': discContentId,
        'canonicalRecordingId': canonicalRecordingId,
      };

  @override
  String toString() {
    return 'RemoteImportJob('
        'id: $id, '
        'accountId: $accountId, '
        'workerId: $workerId, '
        'driveName: $driveName, '
        'status: $status, '
        'progress: $progress, '
        'title: $title, '
        'message: $message, '
        'createdAt: $createdAt, '
        'completedAt: $completedAt, '
        'physicalReleaseId: $physicalReleaseId, '
        'physicalDiscId: $physicalDiscId, '
        'discContentId: $discContentId, '
        'canonicalRecordingId: $canonicalRecordingId'
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

bool _boolValue(dynamic value, {bool fallback = false}) {
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

double _doubleValue(dynamic value, {double fallback = 0}) {
  if (value is num) {
    return _clampProgress(value.toDouble());
  }

  if (value is String) {
    final parsed = double.tryParse(value.trim());

    if (parsed != null) {
      return _clampProgress(parsed);
    }
  }

  return fallback;
}

DateTime? _dateTimeValue(dynamic value) {
  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}

double _clampProgress(double value) {
  if (value.isNaN || value.isInfinite) {
    return 0;
  }

  if (value < 0) {
    return 0;
  }

  if (value > 1) {
    return 1;
  }

  return value;
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}