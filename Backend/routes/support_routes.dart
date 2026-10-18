import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../supabase_store.dart';

/// Authenticated customer-support ticket API. Staff access is granted only to
/// account IDs listed in SUPPORT_ADMIN_ACCOUNT_IDS on the backend host.
class SupportRoutes {
  SupportRoutes({required this.authentication});
  final AuthenticationMiddleware authentication;
  static const _base = '/api/v1/support/tickets';
  static const _maxBodyBytes = 64 * 1024;
  static const _statuses = {'open', 'in_progress', 'waiting_on_customer', 'resolved', 'closed'};
  static const _categories = {'account', 'billing', 'playback', 'devices', 'music', 'social', 'shop', 'food_delivery', 'privacy', 'other'};

  bool _isStaff(String accountId) => (Platform.environment['SUPPORT_ADMIN_ACCOUNT_IDS'] ?? '')
      .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).contains(accountId);

  Future<void> handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    if (request.method == 'OPTIONS') { response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS'); response.statusCode = HttpStatus.noContent; await response.close(); return; }
    final account = authentication.authenticate(request);
    if (account == null) { await _json(response, 401, {'success': false, 'error': 'Authentication required.'}); return; }
    try {
      final store = SupabaseStore.instance;
      if (!store.enabled) { await _json(response, 503, {'success': false, 'error': 'Support ticket storage is not configured.'}); return; }
      if (request.method == 'GET' && request.uri.path == _base) {
        final staff = _isStaff(account.id);
        final tickets = await store.listSupportTickets(accountId: account.id, allTickets: staff && request.uri.queryParameters['scope'] == 'all');
        await _json(response, 200, {'success': true, 'tickets': tickets}); return;
      }
      if (request.method == 'POST' && request.uri.path == _base) {
        final body = await _readJson(request);
        final subject = (body['subject'] ?? '').toString().trim();
        final description = (body['description'] ?? '').toString().trim();
        final category = (body['category'] ?? 'other').toString();
        final priority = (body['priority'] ?? 'normal').toString();
        if (subject.isEmpty || subject.length > 160 || description.isEmpty || description.length > 12000 || !_categories.contains(category) || !{'low','normal','high','urgent'}.contains(priority)) {
          await _json(response, 400, {'success': false, 'error': 'Provide a subject (1–160 chars), description (1–12000 chars), valid category and priority.'}); return;
        }
        final ticket = await store.createSupportTicket(accountId: account.id, subject: subject, category: category, priority: priority, description: description);
        await _json(response, 201, {'success': true, 'ticket': ticket}); return;
      }
      final match = RegExp(r'^/api/v1/support/tickets/([A-Za-z0-9-]+)$').firstMatch(request.uri.path);
      if (request.method == 'PATCH' && match != null) {
        if (!_isStaff(account.id)) { await _json(response, 403, {'success': false, 'error': 'Support staff permission required.'}); return; }
        final body = await _readJson(request);
        final status = (body['status'] ?? 'in_progress').toString();
        final reply = (body['reply'] ?? '').toString().trim();
        if (!_statuses.contains(status) || reply.length > 12000) { await _json(response, 400, {'success': false, 'error': 'Invalid status or reply is too long.'}); return; }
        final ticket = await store.updateSupportTicket(ticketId: match.group(1)!, status: status, staffReply: reply);
        await _json(response, 200, {'success': true, 'ticket': ticket}); return;
      }
      await _json(response, 404, {'success': false, 'error': 'Support endpoint not found.'});
    } on FormatException catch (e) { await _json(response, 400, {'success': false, 'error': e.message}); }
      catch (_) { await _json(response, 500, {'success': false, 'error': 'Unable to process support request.'}); }
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      if (bytes.length + chunk.length > _maxBodyBytes) throw const FormatException('Request body too large.');
      bytes.addAll(chunk);
    }
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    if (decoded is! Map) throw const FormatException('JSON object required.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _json(HttpResponse response, int status, Map<String, dynamic> data) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }
}
