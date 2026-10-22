// Pure planning models used by the reliability center.
// These calculate estimates from inputs; they do not claim to read live host
// telemetry or execute playback/storage operations.

enum PlaybackPlanKind { directPlay, remux, transcode, unavailable }

class PlaybackPlan {
  final PlaybackPlanKind kind;
  final String explanation;

  const PlaybackPlan(this.kind, this.explanation);
}

class PlaybackCompatibility {
  final bool authorized;
  final bool containerSupported;
  final bool videoCodecSupported;
  final bool audioCodecSupported;
  final bool subtitlesCompatible;
  final bool transcodingAvailable;

  const PlaybackCompatibility({
    required this.authorized,
    required this.containerSupported,
    required this.videoCodecSupported,
    required this.audioCodecSupported,
    required this.subtitlesCompatible,
    required this.transcodingAvailable,
  });

  PlaybackPlan recommend() {
    if (!authorized) {
      return const PlaybackPlan(
        PlaybackPlanKind.unavailable,
        'The server must authorize this media and profile before playback.',
      );
    }
    final codecsSupported = videoCodecSupported && audioCodecSupported;
    if (containerSupported && codecsSupported && subtitlesCompatible) {
      return const PlaybackPlan(
        PlaybackPlanKind.directPlay,
        'The client supports the container, codecs, and subtitle path; Direct Play minimizes server work.',
      );
    }
    if (!containerSupported && codecsSupported && subtitlesCompatible) {
      return const PlaybackPlan(
        PlaybackPlanKind.remux,
        'The codecs are supported but the container is not; remuxing may avoid video re-encoding.',
      );
    }
    if (transcodingAvailable) {
      return const PlaybackPlan(
        PlaybackPlanKind.transcode,
        'Use a supported transcode profile and verify CPU/GPU capacity and bandwidth.',
      );
    }
    return const PlaybackPlan(
      PlaybackPlanKind.unavailable,
      'No compatible direct/remux path or configured transcoder was reported.',
    );
  }
}

class StreamBudgetEstimate {
  final double usableUploadMbps;
  final int estimatedConcurrentStreams;
  final double reservedFraction;

  const StreamBudgetEstimate({
    required this.usableUploadMbps,
    required this.estimatedConcurrentStreams,
    required this.reservedFraction,
  });

  static StreamBudgetEstimate calculate({
    required double sustainedUploadMbps,
    required double averageStreamMbps,
    double reservedFraction = 0.30,
  }) {
    if (!sustainedUploadMbps.isFinite || sustainedUploadMbps < 0) {
      throw ArgumentError.value(sustainedUploadMbps, 'sustainedUploadMbps');
    }
    if (!averageStreamMbps.isFinite || averageStreamMbps <= 0) {
      throw ArgumentError.value(averageStreamMbps, 'averageStreamMbps');
    }
    if (!reservedFraction.isFinite || reservedFraction < 0 || reservedFraction >= 1) {
      throw ArgumentError.value(reservedFraction, 'reservedFraction');
    }
    final usable = sustainedUploadMbps * (1 - reservedFraction);
    return StreamBudgetEstimate(
      usableUploadMbps: usable,
      estimatedConcurrentStreams: (usable / averageStreamMbps).floor(),
      reservedFraction: reservedFraction,
    );
  }
}

class StorageForecast {
  final double freeGb;
  final double reserveGb;
  final double dailyGrowthGb;
  final double? daysUntilReserve;

  const StorageForecast({
    required this.freeGb,
    required this.reserveGb,
    required this.dailyGrowthGb,
    required this.daysUntilReserve,
  });

  static StorageForecast calculate({
    required double freeGb,
    required double reserveGb,
    required double dailyGrowthGb,
  }) {
    if (!freeGb.isFinite || freeGb < 0) {
      throw ArgumentError.value(freeGb, 'freeGb');
    }
    if (!reserveGb.isFinite || reserveGb < 0) {
      throw ArgumentError.value(reserveGb, 'reserveGb');
    }
    if (!dailyGrowthGb.isFinite || dailyGrowthGb < 0) {
      throw ArgumentError.value(dailyGrowthGb, 'dailyGrowthGb');
    }
    final effectiveFree = freeGb - reserveGb;
    final double? days = effectiveFree <= 0
        ? 0
        : dailyGrowthGb == 0
            ? null
            : effectiveFree / dailyGrowthGb;
    return StorageForecast(
      freeGb: freeGb,
      reserveGb: reserveGb,
      dailyGrowthGb: dailyGrowthGb,
      daysUntilReserve: days,
    );
  }
}

enum SignalState { unknown, healthy, warning, critical }

class ReliabilitySignal {
  final String id;
  final String label;
  final SignalState state;
  final String detail;

  const ReliabilitySignal({
    required this.id,
    required this.label,
    this.state = SignalState.unknown,
    this.detail = 'Not connected to a live data source.',
  });
}
