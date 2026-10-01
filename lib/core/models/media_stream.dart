/// A short-lived playback stream issued after backend authorization.
///
/// Flutter receives an HTTPS stream URL and never receives NAS credentials or
/// private storage paths.
class MediaStreamDescriptor {
  final String playbackSessionId;
  final String url;
  final DateTime expiresAt;
  final String transport;
  final String? mediaType;

  const MediaStreamDescriptor({
    required this.playbackSessionId,
    required this.url,
    required this.expiresAt,
    this.transport = 'https-range',
    this.mediaType,
  });

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt.toUtc());

  factory MediaStreamDescriptor.fromJson(Map<String, dynamic> json) {
    return MediaStreamDescriptor(
      playbackSessionId: json['playbackSessionId']?.toString() ?? json['playback_session_id']?.toString() ?? '',
      url: json['url']?.toString() ?? json['streamUrl']?.toString() ?? json['stream_url']?.toString() ?? '',
      expiresAt: DateTime.tryParse(
            json['expiresAt']?.toString() ?? json['expires_at']?.toString() ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      transport: json['transport']?.toString() ?? 'https-range',
      mediaType: json['mediaType']?.toString() ?? json['media_type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'playbackSessionId': playbackSessionId,
        'url': url,
        'expiresAt': expiresAt.toIso8601String(),
        'transport': transport,
        if (mediaType != null) 'mediaType': mediaType,
      };
}
