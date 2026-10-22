/// Deterministic daily ordering for Home's hero banner.
///
/// The same candidates and local calendar date always produce the same result.
/// A new date changes the hash seed, so a different subset/order is selected
/// without introducing runtime randomness or needing a backend scheduler.
List<T> dailyHeroSelection<T>({
  required Iterable<T> candidates,
  required String Function(T item) keyOf,
  required DateTime date,
  int limit = 15,
}) {
  if (limit <= 0) return <T>[];

  final uniqueByKey = <String, T>{};
  for (final item in candidates) {
    final key = keyOf(item).trim();
    if (key.isNotEmpty) uniqueByKey.putIfAbsent(key, () => item);
  }

  final dayKey = '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final keyedItems = uniqueByKey.entries.toList(growable: false);
  keyedItems.sort((a, b) {
    final scoreA = _stableHeroHash('$dayKey|${a.key}');
    final scoreB = _stableHeroHash('$dayKey|${b.key}');
    final byScore = scoreA.compareTo(scoreB);
    return byScore != 0 ? byScore : a.key.compareTo(b.key);
  });
  return keyedItems.take(limit).map((entry) => entry.value).toList();
}

/// FNV-1a hash masked to 32 bits so results do not depend on String.hashCode's
/// runtime implementation or randomization.
int _stableHeroHash(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
