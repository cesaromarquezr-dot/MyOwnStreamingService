// FILE: Backend/models/media_capabilities.dart.
// Purpose: Describes the codecs, containers, audio formats, and display limits
// a playback device can handle.
// This file is part of the documented Flutter/home-server architecture.
//
// These capabilities describe what a playback target can accept. They do not
// describe the media itself. The playback layer can compare MediaCapabilities
// against media metadata to decide whether direct play, remuxing, or
// transcoding is required.

class MediaCapabilities {
  final List<String> videoCodecs;
  final List<String> audioCodecs;
  final List<String> containers;

  /// Maximum display/video width supported by the playback target.
  final int maxWidth;

  /// Maximum display/video height supported by the playback target.
  final int maxHeight;

  /// Whether HDR video is supported.
  final bool hdr;

  const MediaCapabilities({
    this.videoCodecs = const ['h264'],
    this.audioCodecs = const ['aac'],
    this.containers = const ['mp4'],
    this.maxWidth = 1920,
    this.maxHeight = 1080,
    this.hdr = false,
  });

  // ---------------------------------------------------------------------------
  // CAPABILITY CHECKS
  // ---------------------------------------------------------------------------

  bool supportsVideoCodec(
    String? codec,
  ) {
    final String? normalized = _normalize(codec);

    if (normalized == null) {
      return false;
    }

    return videoCodecs.contains(normalized);
  }

  bool supportsAudioCodec(
    String? codec,
  ) {
    final String? normalized = _normalize(codec);

    if (normalized == null) {
      return false;
    }

    return audioCodecs.contains(normalized);
  }

  bool supportsContainer(
    String? container,
  ) {
    final String? normalized = _normalize(container);

    if (normalized == null) {
      return false;
    }

    return containers.contains(normalized);
  }

  bool supportsResolution({
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0) {
      return false;
    }

    return width <= maxWidth &&
        height <= maxHeight;
  }

  bool supportsHdr(
    bool mediaHasHdr,
  ) {
    return !mediaHasHdr || hdr;
  }

  /// Checks the basic video requirements for direct playback.
  ///
  /// This intentionally does not inspect bitrate, frame rate, HDR profile,
  /// audio channels, subtitles, or DRM. Those belong to more detailed
  /// playback compatibility logic.
  bool supportsVideo({
    required String? codec,
    required String? container,
    required int width,
    required int height,
    bool mediaHasHdr = false,
  }) {
    return supportsVideoCodec(codec) &&
        supportsContainer(container) &&
        supportsResolution(
          width: width,
          height: height,
        ) &&
        supportsHdr(mediaHasHdr);
  }

  /// Checks the basic audio requirements for direct playback.
  bool supportsAudio({
    required String? codec,
  }) {
    return supportsAudioCodec(codec);
  }

  /// Returns whether a video can satisfy the basic capabilities of this
  /// playback target without a video transcode.
  bool canDirectPlayVideo({
    required String? videoCodec,
    required String? audioCodec,
    required String? container,
    required int width,
    required int height,
    bool mediaHasHdr = false,
  }) {
    return supportsVideo(
          codec: videoCodec,
          container: container,
          width: width,
          height: height,
          mediaHasHdr: mediaHasHdr,
        ) &&
        supportsAudio(
          codec: audioCodec,
        );
  }

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  factory MediaCapabilities.fromJson(
    Map<String, dynamic> json,
  ) {
    return MediaCapabilities(
      videoCodecs: _readStringList(
        json['videoCodecs'],
        fallback: const ['h264'],
      ),
      audioCodecs: _readStringList(
        json['audioCodecs'],
        fallback: const ['aac'],
      ),
      containers: _readStringList(
        json['containers'],
        fallback: const ['mp4'],
      ),
      maxWidth: _readPositiveInt(
        json['maxWidth'],
        fallback: 1920,
      ),
      maxHeight: _readPositiveInt(
        json['maxHeight'],
        fallback: 1080,
      ),
      hdr: _readBool(
        json['hdr'],
        fallback: false,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'videoCodecs': videoCodecs,
      'audioCodecs': audioCodecs,
      'containers': containers,
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
      'hdr': hdr,
    };
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  static List<String> _readStringList(
    dynamic value, {
    required List<String> fallback,
  }) {
    if (value is! List) {
      return List<String>.unmodifiable(
        fallback,
      );
    }

    final Set<String> normalized =
        <String>{};

    for (final dynamic item in value) {
      final String? valueString =
          _normalize(item);

      if (valueString != null) {
        normalized.add(valueString);
      }
    }

    if (normalized.isEmpty) {
      return List<String>.unmodifiable(
        fallback,
      );
    }

    return List<String>.unmodifiable(
      normalized,
    );
  }

  static int _readPositiveInt(
    dynamic value, {
    required int fallback,
  }) {
    final int? parsed;

    if (value is int) {
      parsed = value;
    } else if (value is num) {
      parsed = value.toInt();
    } else {
      parsed = int.tryParse(
        value?.toString() ?? '',
      );
    }

    if (parsed == null || parsed <= 0) {
      return fallback;
    }

    return parsed;
  }

  static bool _readBool(
    dynamic value, {
    required bool fallback,
  }) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
          return true;
        case 'false':
        case '0':
        case 'no':
          return false;
      }
    }

    return fallback;
  }

  static String? _normalize(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final String normalized =
        value.toString().trim().toLowerCase();

    return normalized.isEmpty
        ? null
        : normalized;
  }
}