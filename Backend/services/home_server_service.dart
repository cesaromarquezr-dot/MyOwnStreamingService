// Home-server storage and ARM integration status service.
import 'dart:io';
import '../config.dart';

class HomeServerService {
  /// Returns configured media paths, capacities and filesystem status.
  Map<String, dynamic> storageStatus() {
    final movies = _path('MOVIES_PATH', '${AppConfig.mediaRoot}/movies');
    final series = _path('SERIES_PATH', '${AppConfig.mediaRoot}/series');
    final music = _path('MUSIC_PATH', '${AppConfig.mediaRoot}/music');
    return {
      'root': AppConfig.mediaRoot,
      'categories': [
        _category('Movies', movies, AppConfig.moviesCapacityBytes),
        _category('Series', series, AppConfig.seriesCapacityBytes),
        _category('Music', music, AppConfig.musicCapacityBytes),
      ],
      'availableBytes': AppConfig.availableStorageBytes,
      'totalBytes': AppConfig.moviesCapacityBytes + AppConfig.seriesCapacityBytes + AppConfig.musicCapacityBytes + AppConfig.availableStorageBytes,
    };
  }

  /// Returns the paths used by ARM and the media importer.
  Map<String, dynamic> armStatus() => {
    'armServerUrl': AppConfig.armServerUrl,
    'mediaRoot': AppConfig.mediaRoot,
    'opticalDriveHint': Platform.environment['ARM_OPTICAL_DRIVE'] ?? 'Configure ARM optical drive',
    'connected': AppConfig.armServerUrl.trim().isNotEmpty,
  };

  Map<String, dynamic> _category(String name, String path, int capacity) {
    final dir = Directory(path);
    final exists = dir.existsSync();
    return {'name': name, 'path': path, 'capacityBytes': capacity, 'usedBytes': exists ? _size(dir) : 0, 'exists': exists};
  }

  String _path(String env, String fallback) => Platform.environment[env]?.trim().isNotEmpty == true ? Platform.environment[env]!.trim() : fallback;

  int _size(Directory directory) {
    var total = 0;
    try {
      for (final entity in directory.listSync(recursive: true, followLinks: false)) {
        if (entity is File) total += entity.lengthSync();
      }
    } catch (_) {}
    return total;
  }
}
