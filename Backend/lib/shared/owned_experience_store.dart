// Account-scoped persistence for private Store, Kiosk, Theater and media details.
// When Supabase is not configured, a process-local cache keeps local development usable.
import 'dart:io';
import 'package:supabase/supabase.dart';

class OwnedExperienceStore {
  OwnedExperienceStore({SupabaseClient? client}) : _client = client ?? _createClient();
  final SupabaseClient? _client;
  final Map<String, Map<String, dynamic>> _memory = <String, Map<String, dynamic>>{};
  bool get isDurable => _client != null;

  static SupabaseClient? _createClient() {
    final url = (Platform.environment['SUPABASE_URL'] ?? '').trim();
    final key = (Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ?? '').trim();
    if (url.isEmpty || key.isEmpty) return null;
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.isAbsolute || !{'http', 'https'}.contains(parsed.scheme) || parsed.host.isEmpty) {
      throw StateError('SUPABASE_URL must be an absolute HTTP(S) URL.');
    }
    if (key.length < 20) throw StateError('SUPABASE_SERVICE_ROLE_KEY appears invalid.');
    return SupabaseClient(url, key);
  }

  Future<String?> _internalAccountId(String externalAccountId) async {
    final client = _client;
    if (client == null) return null;
    final row = await client.from('accounts').select('id').eq('external_account_id', externalAccountId).maybeSingle();
    return row?['id']?.toString();
  }

  Future<List<Map<String, dynamic>>> list({required String accountId, required String profileId, required String recordType}) async {
    final client = _client;
    if (client == null) {
      final prefix = _key(accountId, profileId, recordType, '');
      return _memory.entries.where((entry) => entry.key.startsWith(prefix)).map((entry) => Map<String, dynamic>.from(entry.value)).toList(growable: false);
    }
    final internalId = await _internalAccountId(accountId);
    if (internalId == null) return const <Map<String, dynamic>>[];
    final rows = await client.from('owned_experience_records').select('record_id,data,updated_at').eq('account_id', internalId).eq('profile_id', profileId).eq('record_type', recordType).order('updated_at', ascending: false);
    return rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row['data'] as Map)).toList(growable: false);
  }

  Future<Map<String, dynamic>?> get({required String accountId, required String profileId, required String recordType, required String recordId}) async {
    final client = _client;
    if (client == null) {
      final value = _memory[_key(accountId, profileId, recordType, recordId)];
      return value == null ? null : Map<String, dynamic>.from(value);
    }
    final internalId = await _internalAccountId(accountId);
    if (internalId == null) return null;
    final row = await client.from('owned_experience_records').select('data').eq('account_id', internalId).eq('profile_id', profileId).eq('record_type', recordType).eq('record_id', recordId).maybeSingle();
    final data = row?['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> save({required String accountId, required String profileId, required String recordType, required String recordId, required Map<String, dynamic> data}) async {
    final client = _client;
    if (client == null) {
      _memory[_key(accountId, profileId, recordType, recordId)] = Map<String, dynamic>.from(data);
      return;
    }
    final internalId = await _internalAccountId(accountId);
    if (internalId == null) throw StateError('Authenticated account could not be resolved for persistence.');
    await client.from('owned_experience_records').upsert({
      'account_id': internalId,
      'profile_id': profileId,
      'record_type': recordType,
      'record_id': recordId,
      'data': data,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'account_id,profile_id,record_type,record_id');
  }

  Future<void> delete({required String accountId, required String profileId, required String recordType, required String recordId}) async {
    final client = _client;
    if (client == null) {
      _memory.remove(_key(accountId, profileId, recordType, recordId));
      return;
    }
    final internalId = await _internalAccountId(accountId);
    if (internalId == null) return;
    await client.from('owned_experience_records').delete().eq('account_id', internalId).eq('profile_id', profileId).eq('record_type', recordType).eq('record_id', recordId);
  }

  String _key(String accountId, String profileId, String recordType, String recordId) => '$accountId|$profileId|$recordType|$recordId';
}
