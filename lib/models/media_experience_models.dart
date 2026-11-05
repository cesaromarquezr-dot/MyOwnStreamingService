import 'package:flutter/foundation.dart';

enum MediaProgramKind { movie, episode, tvSpecial, shortFilm, musicVideo, bonusFeature, documentary, other }

enum MediaExtraKind { commentary, deletedScene, gagReel, documentary, trailer, musicVideo, interview, bonusFeature, other }

@immutable
class MediaExperienceTrack {
  const MediaExperienceTrack({required this.id, required this.label, this.language, this.codec, this.isCommentary = false, this.isDefault = false});
  final String id;
  final String label;
  final String? language;
  final String? codec;
  final bool isCommentary;
  final bool isDefault;

  factory MediaExperienceTrack.fromJson(Map<String, dynamic> json) => MediaExperienceTrack(
    id: (json['id'] ?? json['index'] ?? '').toString(),
    label: (json['label'] ?? json['title'] ?? json['language'] ?? 'Track').toString(),
    language: json['language']?.toString(), codec: json['codec']?.toString(),
    isCommentary: json['isCommentary'] == true || json['commentary'] == true,
    isDefault: json['isDefault'] == true || json['default'] == true,
  );

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'language': language, 'codec': codec, 'isCommentary': isCommentary, 'isDefault': isDefault};
}

@immutable
class MediaExperienceScene {
  const MediaExperienceScene({required this.id, required this.title, this.positionSeconds = 0, this.thumbnailUrl});
  final String id;
  final String title;
  final int positionSeconds;
  final String? thumbnailUrl;

  factory MediaExperienceScene.fromJson(Map<String, dynamic> json, int index) => MediaExperienceScene(
    id: (json['id'] ?? json['index'] ?? index).toString(),
    title: (json['title'] ?? json['name'] ?? 'Chapter ${index + 1}').toString(),
    positionSeconds: _intValue(json['positionSeconds'] ?? json['startSeconds'] ?? json['timeSeconds']),
    thumbnailUrl: json['thumbnailUrl']?.toString(),
  );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'positionSeconds': positionSeconds, 'thumbnailUrl': thumbnailUrl};
}

@immutable
class MediaExperienceExtra {
  const MediaExperienceExtra({required this.id, required this.title, this.kind = MediaExtraKind.other, this.description, this.durationSeconds, this.mediaId, this.artworkUrl});
  final String id;
  final String title;
  final MediaExtraKind kind;
  final String? description;
  final int? durationSeconds;
  final String? mediaId;
  final String? artworkUrl;

  factory MediaExperienceExtra.fromValue(Object value, int index) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return MediaExperienceExtra(
        id: (map['id'] ?? 'extra_$index').toString(),
        title: (map['title'] ?? map['name'] ?? 'Extra ${index + 1}').toString(),
        kind: mediaExtraKindFromString(map['kind'] ?? map['type']?.toString()),
        description: map['description']?.toString(),
        durationSeconds: _nullableInt(map['durationSeconds'] ?? map['duration']),
        mediaId: map['mediaId']?.toString(), artworkUrl: map['artworkUrl']?.toString(),
      );
    }
    return MediaExperienceExtra(id: 'extra_$index', title: value.toString());
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'kind': kind.name, 'description': description, 'durationSeconds': durationSeconds, 'mediaId': mediaId, 'artworkUrl': artworkUrl};
}

@immutable
class MediaDiscProgram {
  const MediaDiscProgram({required this.mediaId, required this.title, required this.position, this.kind = MediaProgramKind.other, this.isBonus = false, this.discNumber = 1});
  final String mediaId;
  final String title;
  final int position;
  final MediaProgramKind kind;
  final bool isBonus;
  final int discNumber;
}

@immutable
class MediaExperienceSnapshot {
  const MediaExperienceSnapshot({required this.mediaId, required this.title, this.scenes = const [], this.audioTracks = const [], this.subtitleTracks = const [], this.extras = const [], this.discPrograms = const []});
  final String mediaId;
  final String title;
  final List<MediaExperienceScene> scenes;
  final List<MediaExperienceTrack> audioTracks;
  final List<MediaExperienceTrack> subtitleTracks;
  final List<MediaExperienceExtra> extras;
  final List<MediaDiscProgram> discPrograms;
}

MediaExtraKind mediaExtraKindFromString(Object? value) {
  final normalized = value?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '') ?? '';
  return MediaExtraKind.values.firstWhere((kind) => kind.name.toLowerCase() == normalized, orElse: () => MediaExtraKind.other);
}

int _intValue(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;
int? _nullableInt(Object? value) => value == null ? null : int.tryParse(value.toString());
