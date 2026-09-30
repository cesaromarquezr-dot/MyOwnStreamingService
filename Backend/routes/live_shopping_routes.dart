import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../middleware/authentication.dart';
import '../models/account.dart';
import '../supabase_store.dart';

/// Authenticated seller controls and buyer discovery/interactions for Shop live
/// events. Stream ingest/delivery is delegated to the seller's HTTPS provider.
class LiveShoppingRoutes {
  final AuthenticationMiddleware authentication;
  final SupabaseStore store;
  static final Map<String, Map<String, dynamic>> _memory = {};
  static const int _maxBodyBytes = 64 * 1024;

  LiveShoppingRoutes({
    required this.authentication,
    SupabaseStore? store,
  }) : store = store ?? SupabaseStore.instance;

  Future<void> handle(HttpRequest request) async {
    try {
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      final account = authentication.authenticate(request);
      if (account == null) {
        return _json(request.response, HttpStatus.unauthorized, {
          'success': false,
          'error': 'Authentication required.',
        });
      }

      const root = '/api/v1/shop/live-events';
      final path = request.uri.path;
      if (path == root && request.method == 'GET') {
        final persisted = await store.loadShopLiveEvents();
        final events = <String, Map<String, dynamic>>{
          for (final event in persisted) event['id'].toString(): event,
          ..._memory,
        }.values.toList()
          ..sort((a, b) => (a['scheduledAt'] ?? '').toString().compareTo((b['scheduledAt'] ?? '').toString()));
        return _json(request.response, HttpStatus.ok, {'success': true, 'events': events});
      }
      if (path == root && request.method == 'POST') {
        final body = await _body(request);
        final streamUrl = _optionalText(body, 'streamUrl', 2000);
        if (streamUrl != null && !_validStreamUrl(streamUrl)) {
          throw const FormatException('Stream URLs must use HTTPS.');
        }
        final scheduled = _optionalDate(body['scheduledAt']);
        final productIds = _stringList(body['productIds'], maxItems: 100, maxLength: 200);
        final pinned = _optionalText(body, 'pinnedProductId', 200);
        if (pinned != null && !productIds.contains(pinned)) {
          throw const FormatException('The featured product must be included in the event product list.');
        }
        final now = DateTime.now().toUtc().toIso8601String();
        final event = <String, dynamic>{
          'id': _uuid(),
          'sellerAccountId': account.id,
          'storeId': _requiredText(body, 'storeId', 200),
          'storeName': _requiredText(body, 'storeName', 240),
          'title': _requiredText(body, 'title', 240),
          'description': _optionalText(body, 'description', 4000) ?? '',
          'status': 'scheduled',
          'scheduledAt': scheduled?.toIso8601String(),
          'startedAt': null,
          'endedAt': null,
          'streamUrl': streamUrl,
          'replayUrl': null,
          'productIds': productIds,
          'pinnedProductId': pinned,
          'questions': <Map<String, dynamic>>[],
          'poll': null,
          'randomizedRewardsEnabled': body['randomizedRewardsEnabled'] == true,
          'createdAt': now,
          'updatedAt': now,
        };
        await _save(event);
        return _json(request.response, HttpStatus.ok, {'success': true, 'event': event});
      }

      final parts = path.substring(root.length).split('/').where((part) => part.isNotEmpty).toList();
      if (parts.isEmpty || parts.length > 2) {
        return _json(request.response, HttpStatus.notFound, {'success': false, 'error': 'Live event not found.'});
      }
      final id = Uri.decodeComponent(parts.first);
      final event = await _load(id);
      if (event == null) {
        return _json(request.response, HttpStatus.notFound, {'success': false, 'error': 'Live event not found.'});
      }
      if (parts.length == 1 && request.method == 'PATCH') {
        _requireSeller(account, event);
        final body = await _body(request);
        if (body.containsKey('status')) {
          final status = body['status']?.toString();
          if (status == 'live' && event['status'] == 'scheduled') {
            final url = _optionalText(body, 'streamUrl', 2000) ?? event['streamUrl']?.toString();
            if (url == null || !_validStreamUrl(url)) throw const FormatException('An HTTPS stream URL is required to start an event.');
            event['status'] = 'live';
            event['streamUrl'] = url;
            event['startedAt'] = DateTime.now().toUtc().toIso8601String();
          } else if (status == 'ended' && event['status'] == 'live') {
            final replay = _optionalText(body, 'replayUrl', 2000);
            if (replay != null && !_validStreamUrl(replay)) throw const FormatException('Replay URLs must use HTTPS.');
            event['status'] = 'ended';
            event['endedAt'] = DateTime.now().toUtc().toIso8601String();
            event['replayUrl'] = replay;
          } else {
            throw const FormatException('Invalid live-event status transition.');
          }
        }
        if (body.containsKey('pinnedProductId')) {
          final pinned = _optionalText(body, 'pinnedProductId', 200);
          if (pinned != null && !(event['productIds'] as List).contains(pinned)) {
            throw const FormatException('The featured product must be included in this event.');
          }
          event['pinnedProductId'] = pinned;
        }
        if (body.containsKey('poll')) event['poll'] = _validatePoll(body['poll']);
        if (body.containsKey('randomizedRewardsEnabled')) {
          event['randomizedRewardsEnabled'] = body['randomizedRewardsEnabled'] == true;
        }
        event['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        await _save(event);
        return _json(request.response, HttpStatus.ok, {'success': true, 'event': event});
      }
      if (parts.length == 2 && parts[1] == 'questions' && request.method == 'POST') {
        if (event['status'] != 'live') throw const FormatException('Questions are open only while the event is live.');
        final body = await _body(request);
        final profileId = _ownedProfile(account, _requiredText(body, 'profileId', 256));
        final question = _requiredText(body, 'question', 1000);
        final questions = (event['questions'] as List? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
        if (questions.length >= 500) questions.removeAt(0);
        questions.add({
          'id': _uuid(),
          'profileId': profileId,
          'profileName': account.profiles.firstWhere((profile) => profile.id == profileId).name,
          'text': question,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'moderationStatus': 'pending',
        });
        event['questions'] = questions;
        event['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        await _save(event);
        return _json(request.response, HttpStatus.ok, {'success': true, 'event': event});
      }
      if (parts.length == 2 && parts[1] == 'vote' && request.method == 'POST') {
        if (event['status'] != 'live' || event['poll'] is! Map) throw const FormatException('There is no active poll.');
        final body = await _body(request);
        final profileId = _ownedProfile(account, _requiredText(body, 'profileId', 256));
        final optionIndex = body['optionIndex'];
        final poll = Map<String, dynamic>.from(event['poll'] as Map);
        final options = poll['options'] as List? ?? const [];
        if (optionIndex is! int || optionIndex < 0 || optionIndex >= options.length) {
          throw const FormatException('Invalid poll choice.');
        }
        final votes = (poll['votes'] as List? ?? List<int>.filled(options.length, 0)).map((value) => (value as num).toInt()).toList();
        if (poll['voters'] is! Map) poll['voters'] = <String, dynamic>{};
        final voters = Map<String, dynamic>.from(poll['voters'] as Map);
        final previous = voters[profileId];
        if (previous is int) votes[previous]--;
        voters[profileId] = optionIndex;
        votes[optionIndex]++;
        poll['votes'] = votes;
        poll['voters'] = voters;
        event['poll'] = poll;
        event['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        await _save(event);
        return _json(request.response, HttpStatus.ok, {'success': true, 'event': event});
      }
      return _json(request.response, HttpStatus.methodNotAllowed, {'success': false, 'error': 'Unsupported live-event operation.'});
    } on FormatException catch (error) {
      return _json(request.response, HttpStatus.badRequest, {'success': false, 'error': error.message});
    } on ArgumentError catch (error) {
      return _json(request.response, HttpStatus.forbidden, {'success': false, 'error': error.message});
    } catch (_) {
      return _json(request.response, HttpStatus.internalServerError, {'success': false, 'error': 'Unable to process live event.'});
    }
  }

  Future<Map<String, dynamic>?> _load(String id) async {
    final saved = await store.loadShopLiveEvent(id);
    return saved ?? _memory[id];
  }

  Future<void> _save(Map<String, dynamic> event) async {
    await store.saveShopLiveEvent(
      accountExternalId: event['sellerAccountId'] as String,
      event: event,
    );
    _memory[event['id'] as String] = event;
  }

  void _requireSeller(Account account, Map<String, dynamic> event) {
    if (event['sellerAccountId'] != account.id) throw ArgumentError('Only this store’s seller account may manage the event.');
  }

  String _ownedProfile(Account account, String value) {
    if (!account.profiles.any((profile) => profile.id == value)) throw ArgumentError('Profile does not belong to this account.');
    return value;
  }

  Map<String, dynamic> _validatePoll(dynamic value) {
    if (value is! Map) throw const FormatException('Poll must be an object.');
    final question = value['question']?.toString().trim() ?? '';
    final options = value['options'];
    if (question.isEmpty || question.length > 240 || options is! List || options.length < 2 || options.length > 6) {
      throw const FormatException('Polls need a question and between 2 and 6 options.');
    }
    final cleanOptions = options.map((item) => item.toString().trim()).toList();
    if (cleanOptions.any((item) => item.isEmpty || item.length > 120)) throw const FormatException('Poll options must be 1–120 characters.');
    return {
      'question': question,
      'options': cleanOptions,
      'votes': List<int>.filled(cleanOptions.length, 0),
      'voters': <String, int>{},
    };
  }

  bool _validStreamUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  Map<String, dynamic> _bodyDecode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) throw const FormatException('Expected a JSON object.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final bytes = await request.fold<List<int>>(<int>[], (buffer, chunk) {
      buffer.addAll(chunk);
      if (buffer.length > _maxBodyBytes) throw const FormatException('Request body is too large.');
      return buffer;
    });
    return _bodyDecode(utf8.decode(bytes));
  }

  String _requiredText(Map<String, dynamic> body, String key, int max) {
    final value = body[key]?.toString().trim() ?? '';
    if (value.isEmpty || value.length > max || value.contains('\u0000')) throw FormatException('$key is required and must be at most $max characters.');
    return value;
  }

  String? _optionalText(Map<String, dynamic> body, String key, int max) {
    final value = body[key]?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    if (value.length > max || value.contains('\u0000')) throw FormatException('$key is too long or invalid.');
    return value;
  }

  DateTime? _optionalDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    final result = DateTime.tryParse(value.toString());
    if (result == null) throw const FormatException('Invalid scheduled time.');
    return result.toUtc();
  }

  List<String> _stringList(dynamic value, {required int maxItems, required int maxLength}) {
    if (value == null) return <String>[];
    if (value is! List || value.length > maxItems) throw const FormatException('Invalid product list.');
    final result = value.map((item) => item.toString().trim()).toSet().toList();
    if (result.any((item) => item.isEmpty || item.length > maxLength)) throw const FormatException('Invalid product ID.');
    return result;
  }

  String _uuid() {
    final source = Random.secure();
    final random = List<int>.generate(16, (_) => source.nextInt(256));
    random[6] = (random[6] & 0x0f) | 0x40;
    random[8] = (random[8] & 0x3f) | 0x80;
    final hex = random.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _json(HttpResponse response, int status, Map<String, dynamic> value) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set('cache-control', 'no-store');
    response.headers.set('access-control-allow-origin', '*');
    response.headers.set('access-control-allow-headers', 'Authorization, Content-Type');
    response.headers.set('access-control-allow-methods', 'GET, POST, PATCH, OPTIONS');
    response.write(jsonEncode(value));
    await response.close();
  }
}
