import 'dart:math';

import '../models/account.dart';
import '../supabase_store.dart';

class GameService {
  final Map<String, Map<String, dynamic>> _ratings = <String, Map<String, dynamic>>{};
  final Map<String, List<Map<String, dynamic>>> _rankedQueues = <String, List<Map<String, dynamic>>>{};
  final SupabaseStore store;

  GameService({required this.store});
  final Random _random = Random.secure();


  String _key(String profileId, String gameId, String mode) =>
      '$profileId|$gameId|$mode';

  Map<String, dynamic> _rating({required String profileId, required String gameId, required String mode}) {
    final key = _key(profileId, gameId, mode);
    return _ratings.putIfAbsent(key, () => {
          'profileId': profileId,
          'gameId': gameId,
          'mode': mode,
          'rating': 500.0,
          'gamesPlayed': 0,
          'wins': 0,
          'losses': 0,
          'draws': 0,
          'xp': 0,
          'currentStreak': 0,
          'bestStreak': 0,
        });
  }

  Future<List<Map<String, dynamic>>> ratingsFor(Account account, String profileId) async {
    if (store.enabled) {
      try {
        final rows = await store.loadGameRatings(accountExternalId: account.id, profileId: profileId);
        for (final row in rows) {
          final normalized = <String, dynamic>{
            'profileId': row['profile_id']?.toString() ?? profileId,
            'gameId': row['game_id']?.toString() ?? '',
            'mode': row['mode']?.toString() ?? 'ranked',
            'rating': row['rating'] is num ? (row['rating'] as num).toDouble() : 500.0,
            'gamesPlayed': row['games_played'] is num ? (row['games_played'] as num).toInt() : 0,
            'wins': row['wins'] is num ? (row['wins'] as num).toInt() : 0,
            'losses': row['losses'] is num ? (row['losses'] as num).toInt() : 0,
            'draws': row['draws'] is num ? (row['draws'] as num).toInt() : 0,
            'xp': row['xp'] is num ? (row['xp'] as num).toInt() : 0,
            'currentStreak': row['current_streak'] is num ? (row['current_streak'] as num).toInt() : 0,
            'bestStreak': row['best_streak'] is num ? (row['best_streak'] as num).toInt() : 0,
          };
          _ratings[_key(profileId, normalized['gameId'].toString(), normalized['mode'].toString())] = normalized;
        }
      } catch (_) {}
    }
    return _ratings.values
        .where((rating) => rating['profileId'] == profileId)
        .map((rating) => Map<String, dynamic>.from(rating))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createMatch({
    required Account account,
    required String profileId,
    required String gameId,
    required String mode,
    String? opponentProfileId,
  }) async {
    final rating = _rating(profileId: profileId, gameId: gameId, mode: mode);
    final currentRating = (rating['rating'] as num).toDouble();
    if (mode == 'ranked' && (opponentProfileId == null || opponentProfileId.isEmpty)) {
      final queueKey = '$gameId|$mode';
      final queue = _rankedQueues.putIfAbsent(queueKey, () => <Map<String, dynamic>>[]);
      Map<String, dynamic>? opponent;
      var opponentIndex = -1;
      var bestDifference = double.infinity;
      for (var i = 0; i < queue.length; i++) {
        final candidate = queue[i];
        if (candidate['profileId'] == profileId) continue;
        final candidateRating = (candidate['rating'] as num).toDouble();
        final difference = (candidateRating - currentRating).abs();
        if (difference < bestDifference && difference <= 150) {
          bestDifference = difference;
          opponent = candidate;
          opponentIndex = i;
        }
      }
      if (opponent != null) {
        queue.removeAt(opponentIndex);
        final id = 'match_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(9999)}';
        return {
          'id': id,
          'gameId': gameId,
          'mode': mode,
          'status': 'matched',
          'profileId': profileId,
          'opponentProfileId': opponent['profileId'],
          'rating': currentRating,
          'opponentRating': opponent['rating'],
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
      }
      final queued = {
        'profileId': profileId,
        'rating': currentRating,
        'queuedAt': DateTime.now().toUtc().toIso8601String(),
      };
      queue.removeWhere((item) => item['profileId'] == profileId);
      queue.add(queued);
      return {
        'id': 'queue_${DateTime.now().microsecondsSinceEpoch}',
        'gameId': gameId,
        'mode': mode,
        'status': 'queued',
        'profileId': profileId,
        'rating': currentRating,
        'searchRange': 150,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
    }

    final id = 'match_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(9999)}';
    return {
      'id': id,
      'gameId': gameId,
      'mode': mode,
      'status': 'created',
      'profileId': profileId,
      'opponentProfileId': opponentProfileId,
      'rating': rating['rating'],
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> submitResult({
    required Account account,
    required String profileId,
    required String gameId,
    required String mode,
    required String result,
    double opponentRating = 500,
  }) async {
    final rating = _rating(profileId: profileId, gameId: gameId, mode: mode);
    final current = (rating['rating'] as num).toDouble();
    final expected = 1 / (1 + pow(10, (opponentRating - current) / 400));
    final score = switch (result.toLowerCase()) {
      'win' => 1.0,
      'draw' => 0.5,
      _ => 0.0,
    };
    final k = (rating['gamesPlayed'] as int) < 20 ? 40.0 : 24.0;
    final next = max(100.0, current + k * (score - expected));
    rating['rating'] = next.roundToDouble();
    rating['gamesPlayed'] = (rating['gamesPlayed'] as int) + 1;
    rating['wins'] = (rating['wins'] as int) + (result == 'win' ? 1 : 0);
    rating['losses'] = (rating['losses'] as int) + (result == 'loss' ? 1 : 0);
    rating['draws'] = (rating['draws'] as int) + (result == 'draw' ? 1 : 0);
    rating['xp'] = (rating['xp'] as int) + (result == 'win' ? 100 : result == 'draw' ? 40 : 20);
    rating['currentStreak'] = result == 'win' ? (rating['currentStreak'] as int) + 1 : 0;
    rating['bestStreak'] = max(rating['bestStreak'] as int, rating['currentStreak'] as int);
    if (store.enabled) {
      try {
        await store.upsertGameRating(accountExternalId: account.id, rating: rating);
      } catch (_) {}
    }
    return Map<String, dynamic>.from(rating);
  }
}
