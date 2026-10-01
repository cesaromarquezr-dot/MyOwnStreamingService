import '../../backend_api.dart';
import '../models/profile_governance.dart';

class ProfileGovernanceApi {
  final BackendApi backendApi;

  const ProfileGovernanceApi(this.backendApi);

  Future<Map<String, dynamic>> getCapabilities() {
    return backendApi.getProfileGovernanceCapabilities();
  }

  Future<ProfileGovernance> getGovernance(String profileId) async {
    final data = await backendApi.getProfileGovernance(profileId: profileId);
    final raw = data['governance'];
    return ProfileGovernance.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{},
    );
  }

  Future<ProfileGovernance> updateGovernance({
    required String profileId,
    required ProfileGovernance governance,
  }) async {
    final data = await backendApi.updateProfileGovernance(
      profileId: profileId,
      governance: governance.toJson(),
    );
    final raw = data['governance'];
    return ProfileGovernance.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : governance.toJson(),
    );
  }
}
