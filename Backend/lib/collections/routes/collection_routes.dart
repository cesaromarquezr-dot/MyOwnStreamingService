import '../../shared/owned_experience_routes_base.dart';
import '../../shared/owned_experience_store.dart';
import '../../../middleware/authentication.dart';
import '../../../models/account.dart';

class CollectionRoutes extends OwnedExperienceRoutesBase {
  CollectionRoutes({required AuthenticationMiddleware authentication, required OwnedExperienceStore store}) : super(authentication: authentication, store: store);
  @override String get routePrefix => '/api/v1/collections';
  @override String get recordType => 'collection';
  @override
  String? validateWrite(Account account, String profileId, Map<String, dynamic> data) {
    final rawItems = data['items'];
    if (rawItems is! List) return null;
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final mediaId = (item['mediaId'] ?? item['id'] ?? '').toString();
      if (mediaId.isNotEmpty && !isOwnedMediaForProfile(account, profileId, mediaId)) {
        return "A collection can only include media already in this account's owned library.";
      }
    }
    return null;
  }
  @override Map<String, dynamic> normalize(Map<String, dynamic> body) {
    final data = super.normalize(body);
    final title = data['title']?.toString().trim() ?? '';
    if (title.isEmpty || title.length > 300) throw ArgumentError('A collection title is required.');
    final items = data['items'];
    if (items != null && items is! List) throw ArgumentError('Collection items must be a list.');
    data['title'] = title;
    data['items'] = (items as List? ?? const []).take(500).toList(growable: false);
    data['kind'] = data['kind']?.toString() ?? 'custom';
    data['discCount'] = (int.tryParse(data['discCount']?.toString() ?? '') ?? 1).clamp(1, 100);
    return data;
  }
}
