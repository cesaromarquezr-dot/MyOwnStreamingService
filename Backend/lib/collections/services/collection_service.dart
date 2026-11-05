import '../models/collection_model.dart';
import '../repositories/collection_repository.dart';

class CollectionService {
  const CollectionService(this.repository);
  final CollectionRepository repository;
  Future<List<CollectionModel>> list(String accountId, String profileId) => repository.list(accountId, profileId);
  Future<CollectionModel> save(String accountId, String profileId, Map<String, dynamic> input, {String? id}) async {
    final title = input['title']?.toString().trim() ?? '';
    if (title.isEmpty || title.length > 300) throw ArgumentError('Collection title must contain 1–300 characters.');
    final rawItems = input['items'];
    if (rawItems != null && rawItems is! List) throw ArgumentError('Collection items must be a list.');
    final items = (rawItems as List? ?? const []).whereType<Map>().take(500).map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
    final now = DateTime.now().toUtc();
    final collection = CollectionModel(id: id ?? 'collection_${now.microsecondsSinceEpoch}', title: title, kind: input['kind']?.toString() ?? 'custom', profileId: profileId, description: input['description']?.toString(), artworkUrl: input['artworkUrl']?.toString(), items: items, discCount: (int.tryParse(input['discCount']?.toString() ?? '') ?? 1).clamp(1, 100).toInt(), format: input['format']?.toString(), edition: input['edition']?.toString(), createdAt: DateTime.tryParse(input['createdAt']?.toString() ?? '') ?? now, updatedAt: now);
    await repository.save(accountId, profileId, collection);
    return collection;
  }
  Future<void> delete(String accountId, String profileId, String id) => repository.delete(accountId, profileId, id);
}
