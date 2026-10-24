// Customer-support API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiSupportMethods on BackendApi {
  // ==========================================================
  // CUSTOMER SUPPORT / TICKETING
  // ==========================================================

  Future<List<Map<String, dynamic>>> listSupportTickets({bool allTickets = false}) async {
    if (!isAuthenticated) throw BackendApiException('Sign in to view support tickets.');
    final response = await _networkClient.get(Uri.parse('$baseUrl/support/tickets${allTickets ? '?scope=all' : ''}'), headers: _headers);
    final data = await _requireSuccess(response, 'Unable to load support tickets.');
    return (data['tickets'] as List? ?? const []).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> createSupportTicket({required String subject, required String category, required String priority, required String description}) async {
    if (!isAuthenticated) throw BackendApiException('Sign in to contact customer support.');
    final response = await _networkClient.post(Uri.parse('$baseUrl/support/tickets'), headers: _headers, body: jsonEncode({'subject': subject, 'category': category, 'priority': priority, 'description': description}));
    return _requireSuccess(response, 'Unable to create support ticket.');
  }

  Future<Map<String, dynamic>> updateSupportTicket({required String ticketId, required String status, String reply = ''}) async {
    if (!isAuthenticated) throw BackendApiException('Sign in to manage support tickets.');
    final response = await _networkClient.patch(Uri.parse('$baseUrl/support/tickets/${Uri.encodeComponent(ticketId)}'), headers: _headers, body: jsonEncode({'status': status, 'reply': reply}));
    return _requireSuccess(response, 'Unable to update support ticket.');
  }



}
