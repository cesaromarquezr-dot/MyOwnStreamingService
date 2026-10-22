// Domain API methods extracted from backend_api.dart.
part of '../backend_api.dart';

extension BackendApiAdminMethods on BackendApi {
  // ==========================================================
  // SELF-HOSTING
  // ==========================================================

  Future<Map<String, dynamic>> getSelfHostingStatus() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/self-hosting/status'),
        headers: _headers,
      ),
      'Unable to retrieve self-hosting status.',
    );
  }


  // ==========================================================
  // OWNER-ONLY OPERATIONS BOT SCANS
  // ==========================================================

  Future<Map<String, dynamic>> getOperationsBotStatus() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/operations/bots/status'),
        headers: _headers,
      ),
      'Unable to load operations bot status.',
    );
  }

  Future<Map<String, dynamic>> runOperationsBotScan() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/operations/bots/run'),
        headers: _headers,
      ),
      'Unable to run the operations bot scan.',
    );
  }

  // ==========================================================
  // MASTER PRODUCT ARCHITECTURE
  // ==========================================================

  Future<Map<String, dynamic>> getProfileGovernanceCapabilities() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/profile-governance/capabilities'),
        headers: _headers,
      ),
      'Unable to load profile governance capabilities.',
    );
  }

  Future<Map<String, dynamic>> getProfileGovernance(
      {required String profileId}) async {
    _requireAuthentication();
    final clean = profileId.trim();
    if (clean.isEmpty) throw BackendApiException('Profile ID is required.');
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/profile-governance/${Uri.encodeComponent(clean)}'),
        headers: _headers,
      ),
      'Unable to load profile governance.',
    );
  }

  Future<Map<String, dynamic>> updateProfileGovernance({
    required String profileId,
    required Map<String, dynamic> governance,
  }) async {
    _requireAuthentication();
    final clean = profileId.trim();
    if (clean.isEmpty) throw BackendApiException('Profile ID is required.');
    return _requireSuccess(
      await http.patch(
        Uri.parse('$baseUrl/profile-governance/${Uri.encodeComponent(clean)}'),
        headers: _headers,
        body: jsonEncode({'governance': governance}),
      ),
      'Unable to update profile governance.',
    );
  }

  Future<Map<String, dynamic>> updateAccountProfileAdministrationPolicy({
    required bool allowMembersToManageOwnProfiles,
  }) async {
    _requireAuthentication();
    return _requireSuccess(
      await http.patch(
        Uri.parse('$baseUrl/profile-governance/account-policy'),
        headers: _headers,
        body: jsonEncode({
          'allowMembersToManageOwnProfiles': allowMembersToManageOwnProfiles,
        }),
      ),
      'Unable to update account profile administration policy.',
    );
  }

  Future<Map<String, dynamic>> assignMemberProfiles({
    required String memberId,
    required List<String> profileIds,
  }) async {
    _requireAuthentication();
    final cleanMember = memberId.trim();
    if (cleanMember.isEmpty) {
      throw BackendApiException('Member ID is required.');
    }
    return _requireSuccess(
      await http.patch(
        Uri.parse(
            '$baseUrl/profile-governance/member/${Uri.encodeComponent(cleanMember)}'),
        headers: _headers,
        body: jsonEncode({'profileIds': profileIds}),
      ),
      'Unable to assign profiles to this member.',
    );
  }

  Future<Map<String, dynamic>> getServerAgentStatus(
      {required String serverId}) async {
    _requireAuthentication();
    final clean = serverId.trim();
    if (clean.isEmpty) throw BackendApiException('Server ID is required.');
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/server-agent/${Uri.encodeComponent(clean)}/status'),
        headers: _headers,
      ),
      'Unable to load server agent status.',
    );
  }

  Future<Map<String, dynamic>> createMediaPlaybackStream({
    required String mediaId,
    String? versionId,
    String? serverId,
  }) async {
    _requireAuthentication();
    final cleanMedia = mediaId.trim();
    final cleanServer = serverId?.trim();
    if (cleanMedia.isEmpty || cleanServer == null || cleanServer.isEmpty) {
      throw BackendApiException(
          'Media ID and server ID are required for agent playback.');
    }
    final body = <String, dynamic>{
      'mediaId': cleanMedia,
      'serverId': cleanServer,
      if (versionId?.trim().isNotEmpty == true) 'versionId': versionId!.trim(),
    };
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/server-agent/playback'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      'Unable to create a media playback stream.',
    );
  }

  // ==========================================================
  // SECURITY / MFA
  // ==========================================================

  Future<Map<String, dynamic>> getSecurityStatus() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(Uri.parse('$baseUrl/security/status'), headers: _headers),
      'Unable to retrieve security status.',
    );
  }

  Future<Map<String, dynamic>> getSecuritySessions() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(Uri.parse('$baseUrl/security/sessions'),
          headers: _headers),
      'Unable to retrieve security sessions.',
    );
  }

  Future<Map<String, dynamic>> revokeSecuritySession({
    required String sessionId,
  }) async {
    _requireAuthentication();
    final cleanId = sessionId.trim();
    if (cleanId.isEmpty) throw BackendApiException('Session ID is required.');
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/security/sessions/revoke'),
        headers: _headers,
        body: jsonEncode({'sessionId': cleanId}),
      ),
      'Unable to revoke the security session.',
    );
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _requireAuthentication();
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      throw BackendApiException('Current and new passwords are required.');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/security/password'),
      headers: _headers,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    final data = await _requireSuccess(response, 'Unable to change password.');
    await clearToken();
    return data;
  }

  Future<Map<String, dynamic>> startMfaEnrollment() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(Uri.parse('$baseUrl/security/mfa/enroll'),
          headers: _headers),
      'Unable to start MFA enrollment.',
    );
  }

  Future<Map<String, dynamic>> verifyMfaEnrollment({
    required String code,
  }) async {
    _requireAuthentication();
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) throw BackendApiException('MFA code is required.');
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/security/mfa/enroll/verify'),
        headers: _headers,
        body: jsonEncode({'code': cleanCode}),
      ),
      'Unable to verify MFA enrollment.',
    );
  }

  Future<Map<String, dynamic>> disableMfa() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(Uri.parse('$baseUrl/security/mfa/disable'),
          headers: _headers),
      'Unable to disable MFA.',
    );
  }

  Future<Map<String, dynamic>> verifyMfaLogin({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim();
    final cleanCode = code.trim();
    if (cleanEmail.isEmpty || cleanCode.isEmpty) {
      throw BackendApiException('Email and MFA code are required.');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/auth/mfa/verify'),
      headers: _headers,
      body: jsonEncode({'email': cleanEmail, 'code': cleanCode}),
    );
    final data = await _requireSuccess(response, 'Unable to verify MFA login.');
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw BackendApiException(
          'MFA verification succeeded but no authentication token was returned.');
    }
    await setToken(token);
    return data;
  }


  // ==========================================================
  // SECURITY BOT CONTROL CENTER (administrator allowlist enforced by backend)
  // ==========================================================

  Future<Map<String, dynamic>> getSecurityBotsStatus() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/security-bots/status'),
        headers: _headers,
      ),
      'Unable to load the Security Bot Control Center.',
    );
  }

  Future<Map<String, dynamic>> runSecurityBotChecks() async {
    _requireAuthentication();
    return _requireSuccess(
      await http.post(
        Uri.parse('$baseUrl/security-bots/run'),
        headers: _headers,
      ),
      'Security diagnostics could not be completed.',
    );
  }

  Future<Map<String, dynamic>> getSecurityBotsAudit({int limit = 40}) async {
    _requireAuthentication();
    final bounded = limit.clamp(1, 100);
    return _requireSuccess(
      await http.get(
        Uri.parse('$baseUrl/security-bots/audit?limit=$bounded'),
        headers: _headers,
      ),
      'Unable to load the security bot audit history.',
    );
  }

}
