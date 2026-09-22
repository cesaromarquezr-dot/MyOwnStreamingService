// FILE: Backend/models/transcoding_capacity.dart.
//
// Purpose: Describes server resources available to concurrent playback jobs.
//
// This file is part of the documented Flutter/home-server architecture.
//
// The model describes the server's configured transcoding envelope. It does
// not perform scheduling, reserve resources, start FFmpeg jobs, or decide
// whether a particular media item should be transcoded.

/// Represents the configurable concurrency envelope for a media server.
class TranscodingCapacity {
  /// Maximum number of concurrent video transcoding jobs.
  final int maxConcurrentVideoJobs;

  /// Maximum number of concurrent audio transcoding jobs.
  final int maxConcurrentAudioJobs;

  /// Whether hardware-assisted transcoding is available/configured.
  final bool hardwareAcceleration;

  /// Configured video encoder, such as a platform-specific hardware encoder.
  final String? videoEncoder;

  /// GPU memory available to the transcoding subsystem, when known.
  final int? gpuMemoryMb;

  const TranscodingCapacity({
    this.maxConcurrentVideoJobs = 2,
    this.maxConcurrentAudioJobs = 8,
    this.hardwareAcceleration = false,
    this.videoEncoder,
    this.gpuMemoryMb,
  });

  /// Whether this capacity configuration contains usable values.
  bool get isValid =>
      maxConcurrentVideoJobs >= 0 &&
      maxConcurrentAudioJobs >= 0 &&
      (gpuMemoryMb == null || gpuMemoryMb! >= 0);

  /// Whether the server can run at least one video transcoding job.
  bool get canTranscodeVideo => maxConcurrentVideoJobs > 0;

  /// Whether the server can run at least one audio transcoding job.
  bool get canTranscodeAudio => maxConcurrentAudioJobs > 0;

  /// Whether any transcoding workload can currently be scheduled.
  bool get canTranscode =>
      canTranscodeVideo || canTranscodeAudio;

  /// Whether a hardware encoder has been explicitly configured.
  bool get hasHardwareEncoder =>
      hardwareAcceleration &&
      videoEncoder != null &&
      videoEncoder!.trim().isNotEmpty;

  /// Whether GPU memory information is available.
  bool get hasGpuMemory => gpuMemoryMb != null;

  /// Total configured concurrent workload slots.
  ///
  /// This is useful for diagnostics only. Video and audio jobs may consume
  /// different underlying resources in the actual scheduler.
  int get totalConfiguredJobs =>
      maxConcurrentVideoJobs + maxConcurrentAudioJobs;

  /// Returns a normalized encoder name, or null when none is configured.
  String? get normalizedVideoEncoder {
    final value = videoEncoder?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Returns normalized GPU memory, or null when it is not known.
  int? get normalizedGpuMemoryMb {
    final value = gpuMemoryMb;
    if (value == null) {
      return null;
    }
    return value < 0 ? 0 : value;
  }

  /// Creates a modified copy of this capacity configuration.
  TranscodingCapacity copyWith({
    int? maxConcurrentVideoJobs,
    int? maxConcurrentAudioJobs,
    bool? hardwareAcceleration,
    String? videoEncoder,
    int? gpuMemoryMb,
    bool clearVideoEncoder = false,
    bool clearGpuMemoryMb = false,
  }) {
    return TranscodingCapacity(
      maxConcurrentVideoJobs:
          maxConcurrentVideoJobs ?? this.maxConcurrentVideoJobs,
      maxConcurrentAudioJobs:
          maxConcurrentAudioJobs ?? this.maxConcurrentAudioJobs,
      hardwareAcceleration:
          hardwareAcceleration ?? this.hardwareAcceleration,
      videoEncoder:
          clearVideoEncoder ? null : (videoEncoder ?? this.videoEncoder),
      gpuMemoryMb:
          clearGpuMemoryMb ? null : (gpuMemoryMb ?? this.gpuMemoryMb),
    );
  }

  /// Creates a capacity model from persisted or API JSON.
  factory TranscodingCapacity.fromJson(Map<String, dynamic> json) {
    return TranscodingCapacity(
      maxConcurrentVideoJobs:
          _intValue(json['maxConcurrentVideoJobs']) ?? 2,
      maxConcurrentAudioJobs:
          _intValue(json['maxConcurrentAudioJobs']) ?? 8,
      hardwareAcceleration:
          _boolValue(json['hardwareAcceleration']) ?? false,
      videoEncoder: _nullableString(json['videoEncoder']),
      gpuMemoryMb: _intValue(json['gpuMemoryMb']),
    );
  }

  /// Serializes the capacity for diagnostics and the server capability
  /// registry.
  Map<String, dynamic> toJson() => {
        'maxConcurrentVideoJobs': maxConcurrentVideoJobs,
        'maxConcurrentAudioJobs': maxConcurrentAudioJobs,
        'hardwareAcceleration': hardwareAcceleration,
        'videoEncoder': videoEncoder,
        'gpuMemoryMb': gpuMemoryMb,
      };

  @override
  String toString() {
    return 'TranscodingCapacity('
        'maxConcurrentVideoJobs: $maxConcurrentVideoJobs, '
        'maxConcurrentAudioJobs: $maxConcurrentAudioJobs, '
        'hardwareAcceleration: $hardwareAcceleration, '
        'videoEncoder: ${normalizedVideoEncoder ?? '[none]'}, '
        'gpuMemoryMb: ${normalizedGpuMemoryMb ?? '[unknown]'})';
  }
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

bool? _boolValue(dynamic value) {
  if (value is bool) {
    return value;
  }

  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
    }
  }

  if (value is num) {
    return value != 0;
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