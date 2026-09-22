// FILE: Backend/models/transcoding_job.dart.
//
// Purpose: Tracks a cached server-side transcode prepared for playback.
//
// This file is part of the documented Flutter/home-server architecture.
//
// A TranscodingJob describes one prepared output. It does not perform the
// actual transcoding or scheduling. The playback/transcoding service is
// responsible for creating, updating, and deleting the corresponding job.

/// Represents a server-side transcode prepared for playback.
class TranscodingJob {
  final String id;

  /// Source media path on the server.
  final String inputPath;

  /// Path relative to the configured transcode/cache directory.
  final String outputRelativePath;

  /// Lifecycle state of the prepared transcode.
  ///
  /// The project intentionally keeps this as a String so the backend can
  /// introduce additional states without forcing a database migration.
  final String status;

  /// Playback characteristics requested for this transcode.
  final PlaybackJobProfile profile;

  /// Optional failure or diagnostic message.
  final String? error;

  const TranscodingJob({
    required this.id,
    required this.inputPath,
    required this.outputRelativePath,
    required this.status,
    required this.profile,
    this.error,
  });

  /// Whether the job has a usable identity and paths.
  bool get isValid =>
      id.trim().isNotEmpty &&
      inputPath.trim().isNotEmpty &&
      outputRelativePath.trim().isNotEmpty &&
      status.trim().isNotEmpty &&
      profile.isValid;

  /// Whether the job is waiting to be processed.
  bool get isQueued => _normalizedStatus == 'queued';

  /// Whether the job is currently being generated.
  bool get isRunning =>
      _normalizedStatus == 'running' ||
      _normalizedStatus == 'processing' ||
      _normalizedStatus == 'transcoding';

  /// Whether the prepared output is ready for playback.
  bool get isCompleted =>
      _normalizedStatus == 'completed' ||
      _normalizedStatus == 'complete' ||
      _normalizedStatus == 'ready' ||
      _normalizedStatus == 'finished';

  /// Whether the transcode failed.
  bool get isFailed =>
      _normalizedStatus == 'failed' ||
      _normalizedStatus == 'error';

  /// Whether the job was cancelled.
  bool get isCancelled => _normalizedStatus == 'cancelled';

  /// Whether the job has reached a terminal state.
  bool get isTerminal =>
      isCompleted || isFailed || isCancelled;

  /// Whether an error message is present.
  bool get hasError => error != null && error!.trim().isNotEmpty;

  /// Normalized lifecycle status.
  String get normalizedStatus => _normalizedStatus;

  String get _normalizedStatus => status.trim().toLowerCase();

  /// Whether this job has an output that can potentially be served.
  ///
  /// This checks the job's lifecycle state and configured output path. It
  /// does not check the filesystem; the playback/cache service must do that.
  bool get canServeOutput =>
      isCompleted && outputRelativePath.trim().isNotEmpty;

  /// Creates a modified copy of the job.
  TranscodingJob copyWith({
    String? id,
    String? inputPath,
    String? outputRelativePath,
    String? status,
    PlaybackJobProfile? profile,
    String? error,
    bool clearError = false,
  }) {
    return TranscodingJob(
      id: id ?? this.id,
      inputPath: inputPath ?? this.inputPath,
      outputRelativePath:
          outputRelativePath ?? this.outputRelativePath,
      status: status ?? this.status,
      profile: profile ?? this.profile,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Creates a transcode job from persisted/API JSON.
  factory TranscodingJob.fromJson(Map<String, dynamic> json) {
    final profileJson = _mapValue(json['profile']);

    return TranscodingJob(
      id: json['id']?.toString() ?? '',
      inputPath: json['inputPath']?.toString() ?? '',
      outputRelativePath:
          json['outputRelativePath']?.toString() ?? '',
      status: json['status']?.toString() ?? 'queued',
      profile: profileJson == null
          ? const PlaybackJobProfile()
          : PlaybackJobProfile.fromJson(profileJson),
      error: _nullableString(json['error']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'inputPath': inputPath,
        'outputRelativePath': outputRelativePath,
        'status': status,
        'profile': profile.toJson(),
        'error': error,
      };

  @override
  String toString() {
    return 'TranscodingJob('
        'id: $id, '
        'status: $status, '
        'inputPath: $inputPath, '
        'outputRelativePath: $outputRelativePath, '
        'profile: $profile, '
        'hasError: $hasError)';
  }
}

/// Describes the target playback format for a transcoding job.
///
/// This is intentionally separate from [PlaybackProfile], which represents
/// the playback decision made for a client. This model represents the concrete
/// output characteristics requested from the transcoder/cache layer.
class PlaybackJobProfile {
  final String videoCodec;
  final String audioCodec;
  final String container;
  final int width;
  final int height;
  final int bitrateKbps;

  const PlaybackJobProfile({
    this.videoCodec = 'h264',
    this.audioCodec = 'aac',
    this.container = 'mp4',
    this.width = 1920,
    this.height = 1080,
    this.bitrateKbps = 6000,
  });

  /// Whether the profile contains usable target values.
  bool get isValid =>
      normalizedVideoCodec.isNotEmpty &&
      normalizedAudioCodec.isNotEmpty &&
      normalizedContainer.isNotEmpty &&
      width > 0 &&
      height > 0 &&
      bitrateKbps > 0;

  String get normalizedVideoCodec => videoCodec.trim().toLowerCase();

  String get normalizedAudioCodec => audioCodec.trim().toLowerCase();

  String get normalizedContainer => container.trim().toLowerCase();

  /// Whether dimensions are configured.
  bool get hasDimensions => width > 0 && height > 0;

  /// Whether a positive target bitrate is configured.
  bool get hasBitrate => bitrateKbps > 0;

  /// Approximate number of pixels in the target video frame.
  int get pixelCount => width > 0 && height > 0 ? width * height : 0;

  /// Creates a modified copy of the profile.
  PlaybackJobProfile copyWith({
    String? videoCodec,
    String? audioCodec,
    String? container,
    int? width,
    int? height,
    int? bitrateKbps,
  }) {
    return PlaybackJobProfile(
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      container: container ?? this.container,
      width: width ?? this.width,
      height: height ?? this.height,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
    );
  }

  /// Creates a profile from persisted/API JSON.
  factory PlaybackJobProfile.fromJson(Map<String, dynamic> json) {
    return PlaybackJobProfile(
      videoCodec: _stringOrDefault(json['videoCodec'], 'h264'),
      audioCodec: _stringOrDefault(json['audioCodec'], 'aac'),
      container: _stringOrDefault(json['container'], 'mp4'),
      width: _intValue(json['width']) ?? 1920,
      height: _intValue(json['height']) ?? 1080,
      bitrateKbps: _intValue(json['bitrateKbps']) ?? 6000,
    );
  }

  Map<String, dynamic> toJson() => {
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'container': container,
        'width': width,
        'height': height,
        'bitrateKbps': bitrateKbps,
      };

  @override
  String toString() {
    return 'PlaybackJobProfile('
        'videoCodec: $videoCodec, '
        'audioCodec: $audioCodec, '
        'container: $container, '
        'width: $width, '
        'height: $height, '
        'bitrateKbps: $bitrateKbps)';
  }
}

Map<String, dynamic>? _mapValue(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return null;
}

String? _nullableString(dynamic value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _stringOrDefault(dynamic value, String fallback) {
  final text = _nullableString(value);
  return text ?? fallback;
}

int? _intValue(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value.trim());
  }

  return null;
}