import 'dart:convert';
import 'dart:io';

import '../middleware/authentication.dart';
import '../models/profile_governance.dart';
import '../services/profile_governance_service.dart';

class ProfileGovernanceRoutes {
  final AuthenticationMiddleware authentication;
  final ProfileGovernanceService service;

  const ProfileGovernanceRoutes({
    required this.authentication,
    required this.service,
  });

  Future<void> handle(HttpRequest request) async {
    final path = request.uri.path;

    if (request.method == 'PATCH' && path == '/api/v1/profile-governance/account-policy') {
      final principal = authentication.principal(request);
      if (principal == null) return _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});
      if (!principal.isOwner) return _json(request.response, 403, {'success': false, 'error': 'Only the account owner can change account profile policy.'});
      final body = await _readJson(request);
      final enabled = body['allowMembersToManageOwnProfiles'] == true;
      principal.account.allowMembersToManageOwnProfiles = enabled;
      await service.database.persistAccountAndWait(principal.account);
      return _json(request.response, 200, {
        'success': true,
        'allowMembersToManageOwnProfiles': enabled,
      });
    }

    if ((request.method == 'PATCH' || request.method == 'POST') && path.startsWith('/api/v1/profile-governance/member/')) {
      final principal = authentication.principal(request);
      if (principal == null) return _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});
      if (!principal.isOwner) return _json(request.response, 403, {'success': false, 'error': 'Only the account owner can assign profiles to members.'});
      final memberId = Uri.decodeComponent(path.substring('/api/v1/profile-governance/member/'.length)).trim();
      if (memberId.isEmpty) return _json(request.response, 400, {'success': false, 'error': 'memberId is required.'});
      final body = await _readJson(request);
      final rawIds = body['profileIds'];
      if (rawIds is! List) return _json(request.response, 400, {'success': false, 'error': 'profileIds must be an array.'});
      final ids = rawIds.map((item) => item?.toString().trim() ?? '').where((item) => item.isNotEmpty).toSet().toList();
      await service.assignMemberProfiles(principal, memberId, ids);
      return _json(request.response, 200, {'success': true, 'memberId': memberId, 'profileIds': ids});
    }

    if (request.method == 'GET' && path == '/api/v1/profile-governance/capabilities') {
      final principal = authentication.principal(request);
      if (principal == null) return _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});
      return _json(request.response, 200, {
        'success': true,
        'isAccountOwner': principal.isOwner,
        'allowMembersToManageOwnProfiles': principal.account.allowMembersToManageOwnProfiles,
      });
    }

    if (!path.startsWith('/api/v1/profile-governance/')) {
      return _json(request.response, 404, {'success': false, 'error': 'Profile governance route not found.'});
    }

    final principal = authentication.principal(request);
    if (principal == null) return _json(request.response, 401, {'success': false, 'error': 'Authentication required.'});

    final profileId = Uri.decodeComponent(path.substring('/api/v1/profile-governance/'.length)).trim();
    final profile = service.profileFor(principal.account, profileId);
    if (profile == null) return _json(request.response, 404, {'success': false, 'error': 'Profile not found.'});

    if (request.method == 'GET') {
      return _json(request.response, 200, {
        'success': true,
        'profileId': profile.id,
        'governance': profile.governance.toJson(),
        'canManage': service.canManageProfile(principal, profile),
        'canManageContentPolicy': service.canManageProfile(
          principal,
          profile,
          permission: ProfilePermission.manageContentPolicy,
        ),
      });
    }

    if (request.method != 'PATCH' && request.method != 'POST') {
      return _json(request.response, 405, {'success': false, 'error': 'PATCH or POST required.'});
    }

    final body = await _readJson(request);
    var governance = ProfileGovernance.fromJson(body['governance'] is Map
        ? Map<String, dynamic>.from(body['governance'] as Map)
        : body);

    if (!principal.isOwner) {
      if (!service.canManageProfile(
        principal,
        profile,
        permission: ProfilePermission.manageContentPolicy,
      )) {
        return _json(request.response, 403, {'success': false, 'error': 'The current member cannot change this profile policy.'});
      }
      governance = governance.copyWith(
        adminMode: profile.governance.adminMode,
        permissions: profile.governance.permissions,
      );
    }

    try {
      final updated = service.updateGovernance(principal, profile, governance);
      return _json(request.response, 200, {
        'success': true,
        'profileId': profile.id,
        'governance': updated.toJson(),
      });
    } on StateError catch (error) {
      return _json(request.response, 403, {'success': false, 'error': error.message});
    }
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final chunks = <int>[];
    await for (final chunk in request) {
      chunks.addAll(chunk);
      if (chunks.length > 256 * 1024) throw const FormatException('Request body is too large.');
    }
    if (chunks.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(utf8.decode(chunks));
    if (decoded is! Map) throw const FormatException('JSON object required.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _json(HttpResponse response, int status, Map<String, dynamic> body) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set('Cache-Control', 'no-store');
    response.write(jsonEncode(body));
    await response.close();
  }
}
