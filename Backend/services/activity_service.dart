/// Projects persisted profile events into a compact activity feed.
///
/// Domain records remain authoritative; this service only presents events
/// written through the shared action contract.
class ActivityService {
  const ActivityService();

  List<Map<String, dynamic>> projectMediaActions(
    Iterable<Map<String, dynamic>> records, {
    int limit = 50,
  }) {
    final activities = <Map<String, dynamic>>[];
    for (final record in records) {
      if (record['recordType'] != 'universal_media_action') continue;
      final data = record['data'];
      if (data is! Map) continue;
      activities.add(<String, dynamic>{
        'id': record['id'],
        'profileId': record['profileId'],
        'action': data['action'],
        'contentType': data['contentType'],
        'contentId': data['contentId'],
        if (data['mediaVersionId'] != null)
          'mediaVersionId': data['mediaVersionId'],
        if (data['targetId'] != null) 'targetId': data['targetId'],
        'occurredAt': record['updatedAt'] ?? record['createdAt'],
      });
    }
    activities.sort((a, b) =>
        '${b['occurredAt']}'.compareTo('${a['occurredAt']}'));
    final boundedLimit = limit.clamp(1, 100).toInt();
    return activities.take(boundedLimit).toList(growable: false);
  }
}
