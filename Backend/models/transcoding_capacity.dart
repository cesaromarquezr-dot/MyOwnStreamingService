// FILE: Backend/models/transcoding_capacity.dart.
// Purpose: Describes server resources available to concurrent playback jobs.
// This file is part of the documented Flutter/home-server architecture.

/// Represents the configurable concurrency envelope for a media server.
class TranscodingCapacity {
  final int maxConcurrentVideoJobs;
  final int maxConcurrentAudioJobs;
  final bool hardwareAcceleration;
  final String? videoEncoder;
  final int? gpuMemoryMb;

  const TranscodingCapacity({
    this.maxConcurrentVideoJobs = 2,
    this.maxConcurrentAudioJobs = 8,
    this.hardwareAcceleration = false,
    this.videoEncoder,
    this.gpuMemoryMb,
  });

  /// Serializes the capacity for diagnostics and the server capability registry.
  Map<String, dynamic> toJson() => {
        'maxConcurrentVideoJobs': maxConcurrentVideoJobs,
        'maxConcurrentAudioJobs': maxConcurrentAudioJobs,
        'hardwareAcceleration': hardwareAcceleration,
        'videoEncoder': videoEncoder,
        'gpuMemoryMb': gpuMemoryMb,
      };
}
