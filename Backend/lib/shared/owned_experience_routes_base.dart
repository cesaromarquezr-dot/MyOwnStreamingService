import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../../middleware/authentication.dart';
import '../../models/account.dart';
import 'owned_experience_store.dart';

abstract class OwnedExperienceRoutesBase {
  OwnedExperienceRoutesBase({required this.authentication, required this.store});
  final AuthenticationMiddleware authentication;
  final OwnedExperienceStore store;
  String get routePrefix;
  String get recordType;

  /// Subclasses can enforce domain ownership before a record is persisted.
  String? validateWrite(Account account, String profileId, Map<String, dynamic> data) => null;

  bool isOwnedMediaForProfile(Account account, String profileId, String mediaId) {
    final cleanId = mediaId.trim();
    if (cleanId.isEmpty) return false;
    if (account.sharedMediaIds.contains(cleanId)) return true;
    return account.profiles.any((profile) =>
        (profileId.isEmpty || profile.id == profileId) && profile.ownsMedia(cleanId));
  }

  Future<void> handle(HttpRequest request) async {
    if (request.method == 'OPTIONS') { request.response.statusCode = HttpStatus.noContent; await request.response.close(); return; }
    final account = authentication.authenticate(request);
    if (account == null || account.id.trim().isEmpty) { await _send(request.response, HttpStatus.unauthorized, {'success': false, 'error': 'Authentication required.'}); return; }
    try {
      final path = request.uri.path;
      final segments = path.split('/').where((part) => part.isNotEmpty).toList();
      final prefixSegments = routePrefix.split('/').where((part) => part.isNotEmpty).toList();
      if (segments.length < prefixSegments.length || !_samePrefix(segments, prefixSegments)) { await _send(request.response, HttpStatus.notFound, {'success': false, 'error': 'Route not found.'}); return; }
      final suffix = segments.length == prefixSegments.length ? null : Uri.decodeComponent(segments[prefixSegments.length]);
      final profileId = (request.uri.queryParameters['profileId'] ?? '').trim();
      if (profileId.isNotEmpty && !account.profiles.any((profile) => profile.id == profileId)) {
        await _send(request.response, HttpStatus.forbidden, {'success': false, 'error': 'This profile does not belong to the authenticated account.'});
        return;
      }
      if (request.method == 'GET' && suffix == null) {
        final records = await store.list(accountId: account.id, profileId: profileId, recordType: recordType);
        await _send(request.response, HttpStatus.ok, {'success': true, 'durable': store.isDurable, 'records': records}); return;
      }
      if (request.method == 'POST' && suffix == null) {
        final body = await _readBody(request);
        final resolvedProfile = _profile(body, profileId);
        if (resolvedProfile.isNotEmpty && !account.profiles.any((profile) => profile.id == resolvedProfile)) {
          await _send(request.response, HttpStatus.forbidden, {'success': false, 'error': 'This profile does not belong to the authenticated account.'});
          return;
        }
        final data = normalize(body);
        final validationError = validateWrite(account, resolvedProfile, data);
        if (validationError != null) { await _send(request.response, HttpStatus.forbidden, {'success': false, 'error': validationError}); return; }
        final now = DateTime.now().toUtc().toIso8601String();
        final id = _newId();
        final record = <String, dynamic>{...data, 'id': id, 'profileId': resolvedProfile, 'createdAt': now, 'updatedAt': now};
        await store.save(accountId: account.id, profileId: resolvedProfile, recordType: recordType, recordId: id, data: record);
        await _send(request.response, HttpStatus.created, {'success': true, 'durable': store.isDurable, 'record': record}); return;
      }
      if (suffix != null && request.method == 'GET') {
        final record = await store.get(accountId: account.id, profileId: profileId, recordType: recordType, recordId: suffix);
        if (record == null) { await _send(request.response, HttpStatus.notFound, {'success': false, 'error': 'Record not found.'}); return; }
        await _send(request.response, HttpStatus.ok, {'success': true, 'record': record}); return;
      }
      if (suffix != null && (request.method == 'PUT' || request.method == 'PATCH')) {
        final body = await _readBody(request);
        final resolvedProfile = _profile(body, profileId);
        if (resolvedProfile.isNotEmpty && !account.profiles.any((profile) => profile.id == resolvedProfile)) {
          await _send(request.response, HttpStatus.forbidden, {'success': false, 'error': 'This profile does not belong to the authenticated account.'});
          return;
        }
        final existing = await store.get(accountId: account.id, profileId: resolvedProfile, recordType: recordType, recordId: suffix);
        final data = normalize(body);
        final validationError = validateWrite(account, resolvedProfile, data);
        if (validationError != null) { await _send(request.response, HttpStatus.forbidden, {'success': false, 'error': validationError}); return; }
        final now = DateTime.now().toUtc().toIso8601String();
        final record = <String, dynamic>{...?existing, ...data, 'id': suffix, 'profileId': resolvedProfile, 'createdAt': existing?['createdAt'] ?? now, 'updatedAt': now};
        await store.save(accountId: account.id, profileId: resolvedProfile, recordType: recordType, recordId: suffix, data: record);
        await _send(request.response, HttpStatus.ok, {'success': true, 'record': record}); return;
      }
      if (suffix != null && request.method == 'DELETE') {
        await store.delete(accountId: account.id, profileId: profileId, recordType: recordType, recordId: suffix);
        await _send(request.response, HttpStatus.ok, {'success': true, 'deleted': true}); return;
      }
      await _send(request.response, HttpStatus.methodNotAllowed, {'success': false, 'error': 'Method not supported for this route.'});
    } on FormatException catch (error) { await _send(request.response, HttpStatus.badRequest, {'success': false, 'error': error.message}); }
      on ArgumentError catch (error) { await _send(request.response, HttpStatus.badRequest, {'success': false, 'error': error.message}); }
      catch (_) { await _send(request.response, HttpStatus.internalServerError, {'success': false, 'error': 'Unable to process owned media experience request.'}); }
  }

  Map<String, dynamic> normalize(Map<String, dynamic> body) => Map<String, dynamic>.from(body['data'] is Map ? body['data'] as Map : body)..remove('accountId');

  String _profile(Map<String, dynamic> body, String queryProfile) {
    final value = (body['profileId'] ?? queryProfile).toString().trim();
    if (value.length > 200) throw ArgumentError('Profile ID is too long.');
    return value;
  }

  bool _samePrefix(List<String> path, List<String> prefix) { for (var i = 0; i < prefix.length; i++) { if (path[i] != prefix[i]) return false; } return true; }
  Future<Map<String, dynamic>> _readBody(HttpRequest request) async {
    final bytes = await request.fold<List<int>>(<int>[], (buffer, chunk) { if (buffer.length + chunk.length > 128 * 1024) throw const FormatException('Request body is too large.'); return buffer..addAll(chunk); });
    if (bytes.isEmpty) throw const FormatException('A JSON body is required.');
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const FormatException('A JSON object is required.');
    return Map<String, dynamic>.from(decoded);
  }
  String _newId() => 'exp_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 20)}';
  Future<void> _send(HttpResponse response, int status, Map<String, dynamic> body) async { response.statusCode = status; response.headers.contentType = ContentType.json; response.headers.set('cache-control', 'no-store'); response.write(jsonEncode(body)); await response.close(); }
}
