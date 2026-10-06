import 'dart:math';

class TvPairingService {
  final Random _random = Random.secure();
  final Map<String, Map<String, dynamic>> _pairings = <String, Map<String, dynamic>>{};
  final Map<String, List<Map<String, dynamic>>> _commands = <String, List<Map<String, dynamic>>>{};
  final Map<String, Map<String, dynamic>> _tvState = <String, Map<String, dynamic>>{};

  Map<String, dynamic> createCode({required String accountId, required String tvDeviceId, required String tvDeviceName}) {
    String code;
    do {
      code = (100000 + _random.nextInt(900000)).toString();
    } while (_pairings.values.any((row) => row['code'] == code && row['status'] == 'pending'));
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 10));
    _pairings[tvDeviceId] = {
      'tvDeviceId': tvDeviceId,
      'tvDeviceName': tvDeviceName,
      'accountId': accountId,
      'code': code,
      'status': 'pending',
      'expiresAt': expiresAt.toIso8601String(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    return Map<String, dynamic>.from(_pairings[tvDeviceId]!);
  }

  Map<String, dynamic> pair({required String accountId, required String code, required String phoneDeviceId, required String profileId}) {
    Map<String, dynamic>? row;
    for (final candidate in _pairings.values) {
      if (candidate['code'] == code && candidate['status'] == 'pending') {
        row = candidate;
        break;
      }
    }
    if (row == null) throw StateError('Pairing code is invalid or expired.');
    final expires = DateTime.tryParse(row['expiresAt']?.toString() ?? '');
    if (expires == null || expires.isBefore(DateTime.now().toUtc())) {
      row['status'] = 'expired';
      throw StateError('Pairing code is invalid or expired.');
    }
    if (row['accountId'] != accountId) throw StateError('Pairing code belongs to another account.');
    row['status'] = 'paired';
    row['phoneDeviceId'] = phoneDeviceId;
    row['profileId'] = profileId;
    row['pairedAt'] = DateTime.now().toUtc().toIso8601String();
    return Map<String, dynamic>.from(row);
  }

  void command({required String accountId, required String tvDeviceId, required String profileId, required Map<String, dynamic> command}) {
    final pairing = _pairings[tvDeviceId];
    if (pairing == null || pairing['accountId'] != accountId || pairing['status'] != 'paired' || pairing['profileId'] != profileId) {
      throw StateError('This phone is not authorized to control the selected TV.');
    }
    final list = _commands.putIfAbsent(tvDeviceId, () => <Map<String, dynamic>>[]);
    list.add({
      'accountId': accountId,
      'profileId': profileId,
      'command': command,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    if (list.length > 100) list.removeAt(0);
  }

  List<Map<String, dynamic>> pairingsForAccount(String accountId) => _pairings.values
      .where((row) => row['accountId'] == accountId && row['status'] == 'paired')
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);

  void updateState({required String accountId, required String tvDeviceId, required Map<String, dynamic> state}) {
    final pairing = _pairings[tvDeviceId];
    if (pairing == null || pairing['accountId'] != accountId) {
      throw StateError('TV device is not registered to this account.');
    }
    _tvState[tvDeviceId] = {
      ...state,
      'tvDeviceId': tvDeviceId,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> stateForAccount(String accountId, String tvDeviceId) {
    final pairing = _pairings[tvDeviceId];
    if (pairing == null || pairing['accountId'] != accountId) {
      throw StateError('TV device is not registered to this account.');
    }
    return Map<String, dynamic>.from(_tvState[tvDeviceId] ?? <String, dynamic>{
      'tvDeviceId': tvDeviceId,
      'state': 'idle',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> drainCommands(String accountId, String tvDeviceId) {
    final list = _commands.remove(tvDeviceId) ?? <Map<String, dynamic>>[];
    if (!_pairings.values.any((row) => row['accountId'] == accountId && row['tvDeviceId'] == tvDeviceId && row['status'] == 'paired')) {
      return const <Map<String, dynamic>>[];
    }
    return list.map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
  }
}

