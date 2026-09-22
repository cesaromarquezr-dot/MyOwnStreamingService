// FILE: Backend/models/playback_profile.dart.
//
// Purpose: Represents the server's playback decision for one media request.
// This file is part of the documented Flutter/home-server architecture.
//
// A PlaybackProfile describes the result of server-side playback negotiation.
// It does not itself perform transcoding or direct play. The playback service
// is responsible for comparing media properties against client capabilities
// and producing this decision.
//
// Supported playback modes:
// - directPlay
// - remux
// - audioTranscode
// - transcode

class PlaybackProfile {
  final String mode;

  final String videoCodec;

  final String audioCodec;

  final String container;

  final int? width;

  final int? height;

  final int? bitrateKbps;

  final String? reason;

  const PlaybackProfile({
    required this.mode,
    required this.videoCodec,
    required this.audioCodec,
    required this.container,
    this.width,
    this.height,
    this.bitrateKbps,
    this.reason,
  });

  /// Whether the server selected direct playback with no media conversion.
  bool get isDirectPlay => normalizedMode == 'directPlay';

  /// Whether the server selected container remuxing without transcoding the
  /// underlying media streams.
  bool get isRemux => normalizedMode == 'remux';

  /// Whether only the audio stream needs transcoding.
  bool get isAudioTranscode => normalizedMode == 'audioTranscode';

  /// Whether video/audio transcoding is required.
  bool get isTranscode => normalizedMode == 'transcode';

  /// True when this profile represents a recognized playback mode.
  bool get hasKnownMode =>
      normalizedMode == 'directPlay' ||
      normalizedMode == 'remux' ||
      normalizedMode == 'audioTranscode' ||
      normalizedMode == 'transcode';

  /// Normalized playback mode used by comparisons.
  String get normalizedMode {
    final value = mode.trim();

    switch (value.toLowerCase()) {
      case 'directplay':
        return 'directPlay';
      case 'remux':
        return 'remux';
      case 'audiotranscode':
        return 'audioTranscode';
      case 'transcode':
        return 'transcode';
      default:
        return value;
    }
  }

  /// Normalized video codec name.
  String get normalizedVideoCodec => videoCodec.trim().toLowerCase();

  /// Normalized audio codec name.
  String get normalizedAudioCodec => audioCodec.trim().toLowerCase();

  /// Normalized container name.
  String get normalizedContainer => container.trim().toLowerCase();

  /// Whether dimensions are available and valid.
  bool get hasDimensions =>
      width != null &&
      height != null &&
      width! > 0 &&
      height! > 0;

  /// Whether bitrate information is available and valid.
  bool get hasBitrate => bitrateKbps != null && bitrateKbps! > 0;

  /// Whether the profile contains a human-readable decision reason.
  bool get hasReason => reason?.trim().isNotEmpty ?? false;

  /// Performs basic model validation.
  ///
  /// This validates the playback decision itself. It does not determine
  /// whether the decision is optimal for a particular device; that belongs
  /// to the playback decision service.
  bool get isValid {
    if (!hasKnownMode) {
      return false;
    }

    if (normalizedVideoCodec.isEmpty ||
        normalizedAudioCodec.isEmpty ||
        normalizedContainer.isEmpty) {
      return false;
    }

    if (width != null && width! <= 0) {
      return false;
    }

    if (height != null && height! <= 0) {
      return false;
    }

    if (bitrateKbps != null && bitrateKbps! <= 0) {
      return false;
    }

    return true;
  }

  /// Creates a modified playback profile.
  PlaybackProfile copyWith({
    String? mode,
    String? videoCodec,
    String? audioCodec,
    String? container,
    int? width,
    int? height,
    int? bitrateKbps,
    String? reason,
    bool clearWidth = false,
    bool clearHeight = false,
    bool clearBitrateKbps = false,
    bool clearReason = false,
  }) {
    return PlaybackProfile(
      mode: mode ?? this.mode,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      container: container ?? this.container,
      width: clearWidth ? null : (width ?? this.width),
      height: clearHeight ? null : (height ?? this.height),
      bitrateKbps:
          clearBitrateKbps ? null : (bitrateKbps ?? this.bitrateKbps),
      reason: clearReason ? null : (reason ?? this.reason),
    );
  }

  /// Creates a playback profile from persisted/API JSON.
  ///
  /// Required playback-decision fields must be present and valid. Numeric
  /// values may be supplied either as JSON numbers or numeric strings.
  factory PlaybackProfile.fromJson(Map<String, dynamic> json) {
    final mode = _stringValue(json['mode']);
    final videoCodec = _stringValue(json['videoCodec']);
    final audioCodec = _stringValue(json['audioCodec']);
    final container = _stringValue(json['container']);

    if (mode == null ||
        videoCodec == null ||
        audioCodec == null ||
        container == null) {
      throw const FormatException(
        'Invalid playback profile: required fields are missing.',
      );
    }

    final profile = PlaybackProfile(
      mode: mode,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      container: container,
      width: _positiveInt(json['width']),
      height: _positiveInt(json['height']),
      bitrateKbps: _positiveInt(json['bitrateKbps']),
      reason: _nullableString(json['reason']),
    );

    if (!profile.isValid) {
      throw const FormatException(
        'Invalid playback profile: unsupported or malformed values.',
      );
    }

    return profile;
  }

  /// Serializes the server playback decision.
  Map<String, dynamic> toJson() => {
        'mode': mode,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'container': container,
        'width': width,
        'height': height,
        'bitrateKbps': bitrateKbps,
        'reason': reason,
      };

  @override
  String toString() {
    return 'PlaybackProfile('
        'mode: $mode, '
        'videoCodec: $videoCodec, '
        'audioCodec: $audioCodec, '
        'container: $container, '
        'width: $width, '
        'height: $height, '
        'bitrateKbps: $bitrateKbps, '
        'reason: $reason'
        ')';
  }
}

String? _stringValue(Object? value) {
  if (value is! String) {
    return null;
  }

  final result = value.trim();
  return result.isEmpty ? null : result;
}

String? _nullableString(Object? value) {
  return _stringValue(value);
}

int? _positiveInt(Object? value) {
  if (value is int) {
    return value > 0 ? value : null;
  }

  if (value is num) {
    final result = value.toInt();
    return result > 0 ? result : null;
  }

  if (value is String) {
    final result = int.tryParse(value.trim());
    return result != null && result > 0 ? result : null;
  }

  return null;
}