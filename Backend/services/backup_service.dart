// FILE: Backend/services/backup_service.dart.
// Purpose: Provides a safe backup policy abstraction. It never deletes originals.

import 'dart:io';

class BackupService {
  const BackupService();

  /// Checks whether a configured backup destination is reachable.
  Future<Map<String, dynamic>> status() async {
    final destination = Platform.environment['BACKUP_DESTINATION']?.trim() ?? '';
    final configured = destination.isNotEmpty;
    final reachable = configured && Directory(destination).existsSync();
    return {
      'configured': configured,
      'reachable': reachable,
      'destination': destination,
      'state': !configured ? 'not_configured' : (reachable ? 'ready' : 'unreachable'),
      'raidIsNotBackup': true,
    };
  }
}
