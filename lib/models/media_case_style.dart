import 'package:material_ui/material_ui.dart';

/// Physical packaging styles used by the Virtual Store, Kiosk and Theater.
///
/// A missing format is deliberately presented as DIGITAL / NOT RECORDED rather
/// than silently pretending every title is a Blu-ray.
enum MediaCaseKind {
  dvd,
  bluRay,
  ultraHd,
  steelbook,
  cd,
  vinyl,
  tvBox,
  collection,
  digital,
}

@immutable
class MediaCaseStyle {
  const MediaCaseStyle({
    required this.kind,
    required this.label,
    required this.color,
    required this.aspectRatio,
  });

  final MediaCaseKind kind;
  final String label;
  final Color color;

  /// Width / height ratio of the visible front cover.
  final double aspectRatio;

  static const List<String> physicalFormatFilters = <String>[
    'DVD',
    'Blu-ray',
    '4K Ultra HD',
    'Audio CD',
    'Vinyl',
  ];

  /// Normalizes format names recorded by ARM, MakeMKV, manual imports and
  /// older catalog payloads into one stable display/filter value.
  static String canonicalFormat(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Digital / not recorded';

    final text = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (text.contains('4k') ||
        text.contains('uhd') ||
        text.contains('ultrahd')) {
      return '4K Ultra HD';
    }
    if (text.contains('steelbook') || text.contains('steelcase')) {
      return 'Steelbook';
    }
    if (text.contains('bluray') || text == 'bd' || text.contains('blu ray')) {
      return 'Blu-ray';
    }
    if (text.contains('dvd') || text == 'video_ts') return 'DVD';
    if (text.contains('audiocd') ||
        text.contains('compactdisc') ||
        text == 'cd' ||
        text == 'cds' ||
        text.contains('musiccd')) {
      return 'Audio CD';
    }
    if (text.contains('vinyl') || text == 'lp' || text.contains('record')) {
      return 'Vinyl';
    }
    if (text.contains('season') ||
        text.contains('tvbox') ||
        text.contains('seriesbox')) {
      return 'TV Collection';
    }
    if (text == 'owned' ||
        text == 'library' ||
        text == 'digital' ||
        text == 'unknown' ||
        text == 'other' ||
        text == 'notrecorded') {
      return 'Digital / not recorded';
    }
    return raw;
  }

  static MediaCaseStyle fromFormat(String? value) {
    switch (canonicalFormat(value)) {
      case 'DVD':
        return const MediaCaseStyle(
          kind: MediaCaseKind.dvd,
          label: 'DVD',
          color: Color(0xFF754126),
          aspectRatio: .70,
        );
      case 'Blu-ray':
        return const MediaCaseStyle(
          kind: MediaCaseKind.bluRay,
          label: 'BLU-RAY',
          color: Color(0xFF173E78),
          aspectRatio: .70,
        );
      case '4K Ultra HD':
        return const MediaCaseStyle(
          kind: MediaCaseKind.ultraHd,
          label: '4K ULTRA HD',
          color: Color(0xFF263D2F),
          aspectRatio: .70,
        );
      case 'Steelbook':
        return const MediaCaseStyle(
          kind: MediaCaseKind.steelbook,
          label: 'STEELBOOK',
          color: Color(0xFF394957),
          aspectRatio: .70,
        );
      case 'Audio CD':
        return const MediaCaseStyle(
          kind: MediaCaseKind.cd,
          label: 'CD',
          color: Color(0xFF59636A),
          aspectRatio: 1,
        );
      case 'Vinyl':
        return const MediaCaseStyle(
          kind: MediaCaseKind.vinyl,
          label: 'VINYL',
          color: Color(0xFF443B55),
          aspectRatio: 1,
        );
      case 'TV Collection':
        return const MediaCaseStyle(
          kind: MediaCaseKind.tvBox,
          label: 'TV COLLECTION',
          color: Color(0xFF315347),
          aspectRatio: .76,
        );
      case 'Digital / not recorded':
        return const MediaCaseStyle(
          kind: MediaCaseKind.digital,
          label: 'OWNED MEDIA',
          color: Color(0xFF3B3B40),
          aspectRatio: .70,
        );
      default:
        return const MediaCaseStyle(
          kind: MediaCaseKind.collection,
          label: 'COLLECTION',
          color: Color(0xFF45413A),
          aspectRatio: .72,
        );
    }
  }
}
