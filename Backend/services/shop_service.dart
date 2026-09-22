// FILE: Backend/services/shop_service.dart.
// Purpose: Global marketplace association search and entity synchronization.
//
// The service provides discovery metadata only. It does not invent merchant
// offers or imply that a media item is purchasable. Actual merchandise
// eligibility belongs to ShopEligibilityService and merchant/offer data.

import '../database/database.dart';
import '../models/shop_entity.dart';
import '../supabase_store.dart';

class ShopService {
  static const int defaultSearchLimit = 50;
  static const int maximumSearchLimit = 100;
  static const int maximumQueryLength = 200;
  static const int maximumEntityIdLength = 300;
  static const int maximumEntityNameLength = 500;
  static const int maximumEntitySubtitleLength = 500;
  static const int maximumSyncEntities = 500;

  final Database database;

  ShopService({
    required this.database,
  });

  /// Searches global marketplace association metadata.
  ///
  /// Supabase is used as the cross-server source when configured. The local
  /// media index is also searched so a newly deployed server remains useful
  /// before its Shop metadata has been synchronized.
  ///
  /// Discovery results do not constitute proof that merchandise is available.
  Future<List<ShopEntity>> searchEntities(
    String query, {
    int limit = defaultSearchLimit,
  }) async {
    final normalized = _normalizeQuery(query);
    final effectiveLimit = _validateLimit(limit);

    if (normalized.isEmpty) {
      return const <ShopEntity>[];
    }

    final result = <String, ShopEntity>{};

    // ----------------------------------------------------------
    // GLOBAL / SUPABASE METADATA
    // ----------------------------------------------------------

    try {
      final remoteEntities = await SupabaseStore.instance.searchShopEntities(
        query: normalized,
        limit: effectiveLimit,
      );

      for (final entity in remoteEntities) {
        try {
          final parsed = ShopEntity.fromJson(entity);

          if (!_isValidEntity(parsed)) {
            continue;
          }

          final key = _entityKey(parsed);

          result[key] = parsed;
        } catch (_) {
          // A malformed remote entity must not invalidate the entire search.
          continue;
        }
      }
    } catch (_) {
      // Supabase is an optional cross-server source. Local metadata remains
      // available if the Shop migration is unavailable or temporarily fails.
    }

    // ----------------------------------------------------------
    // LOCAL MEDIA INDEX
    // ----------------------------------------------------------

    for (final media in database.getAllMedia()) {
      final candidates = <ShopEntity>[
        ShopEntity(
          type: media.isMovie ? 'movie' : 'show',
          id: media.id,
          name: media.title,
          subtitle: media.year == null
              ? 'Movie / Show'
              : '${media.isMovie ? 'Movie' : 'TV show'} • ${media.year}',
        ),

        ..._entitiesFromValues(
          type: 'franchise',
          values: media.franchises,
          subtitle: 'Franchise',
        ),

        ..._entitiesFromValues(
          type: 'genre',
          values: media.genres,
          subtitle: 'Genre',
        ),

        ..._entitiesFromValues(
          type: 'actor',
          values: media.actors,
          subtitle: 'Actor',
        ),

        ..._entitiesFromValues(
          type: 'director',
          values: media.directors,
          subtitle: 'Director',
        ),

        ..._entitiesFromValues(
          type: 'artist',
          values: media.music,
          subtitle: 'Artist / Music',
        ),
      ];

      for (final candidate in candidates) {
        if (!_isValidEntity(candidate)) {
          continue;
        }

        if (!_matches(candidate.name, normalized)) {
          continue;
        }

        final key = _entityKey(candidate);

        result[key] = candidate;

        // Keep memory/work bounded during local catalog traversal.
        if (result.length >= effectiveLimit * 2) {
          break;
        }
      }

      if (result.length >= effectiveLimit * 2) {
        break;
      }
    }

    final values = result.values.toList();

    _sortByRelevance(values, normalized);

    if (values.length <= effectiveLimit) {
      return List<ShopEntity>.unmodifiable(values);
    }

    return List<ShopEntity>.unmodifiable(
      values.take(effectiveLimit),
    );
  }

  /// Synchronizes Shop discovery entities to the global Supabase index.
  ///
  /// The account ID is supplied by the authenticated backend route rather
  /// than trusted from a client-provided entity payload.
  Future<void> syncEntities(
    String accountExternalId,
    List<ShopEntity> entities,
  ) async {
    final accountId = accountExternalId.trim();

    if (accountId.isEmpty) {
      throw Exception('Account ID is required.');
    }

    if (accountId.length > maximumEntityIdLength ||
        _containsInvalidControlCharacter(accountId)) {
      throw Exception('Account ID is invalid.');
    }

    if (entities.isEmpty) {
      return;
    }

    if (entities.length > maximumSyncEntities) {
      throw Exception(
        'A maximum of $maximumSyncEntities Shop entities may be synchronized '
        'at once.',
      );
    }

    final sanitized = <ShopEntity>[];
    final seen = <String>{};

    for (final entity in entities) {
      if (!_isValidEntity(entity)) {
        throw Exception('Shop entity contains invalid metadata.');
      }

      final key = _entityKey(entity);

      if (!seen.add(key)) {
        continue;
      }

      sanitized.add(entity);
    }

    if (sanitized.isEmpty) {
      return;
    }

    await SupabaseStore.instance.upsertShopEntities(
      accountExternalId: accountId,
      entities: List<ShopEntity>.unmodifiable(sanitized),
    );
  }

  // ==========================================================
  // LOCAL ENTITY BUILDING
  // ==========================================================

  List<ShopEntity> _entitiesFromValues({
    required String type,
    required Iterable<String> values,
    required String subtitle,
  }) {
    final entities = <ShopEntity>[];

    for (final value in values) {
      final name = value.trim();

      if (name.isEmpty) {
        continue;
      }

      final normalizedName = _normalizeName(name);

      if (normalizedName.isEmpty) {
        continue;
      }

      entities.add(
        ShopEntity(
          type: type,
          id: '$type:$normalizedName',
          name: name,
          subtitle: subtitle,
        ),
      );
    }

    return entities;
  }

  // ==========================================================
  // VALIDATION
  // ==========================================================

  String _normalizeQuery(String value) {
    if (value.contains('\u0000')) {
      throw Exception('Shop search query contains an invalid character.');
    }

    if (value.length > maximumQueryLength) {
      throw Exception(
        'Shop search query must not exceed $maximumQueryLength characters.',
      );
    }

    return _normalizeName(value);
  }

  int _validateLimit(int limit) {
    if (limit < 1 || limit > maximumSearchLimit) {
      throw Exception(
        'Shop search limit must be between 1 and $maximumSearchLimit.',
      );
    }

    return limit;
  }

  bool _isValidEntity(ShopEntity entity) {
    final type = entity.type.trim();
    final id = entity.id.trim();
    final name = entity.name.trim();
    final subtitle = entity.subtitle?.trim();

    if (type.isEmpty ||
        type.length > 100 ||
        id.isEmpty ||
        id.length > maximumEntityIdLength ||
        name.isEmpty ||
        name.length > maximumEntityNameLength) {
      return false;
    }

    if (subtitle != null &&
        subtitle.length > maximumEntitySubtitleLength) {
      return false;
    }

    if (_containsInvalidControlCharacter(type) ||
        _containsInvalidControlCharacter(id) ||
        _containsInvalidControlCharacter(name) ||
        (subtitle != null &&
            _containsInvalidControlCharacter(subtitle))) {
      return false;
    }

    return true;
  }

  bool _containsInvalidControlCharacter(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit == 0 ||
          (codeUnit < 32 && codeUnit != 9 && codeUnit != 10 && codeUnit != 13)) {
        return true;
      }
    }

    return false;
  }

  // ==========================================================
  // MATCHING / SORTING
  // ==========================================================

  String _normalizeName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _matches(
    String value,
    String normalizedQuery,
  ) {
    final normalized = _normalizeName(value);

    if (normalized.isEmpty || normalizedQuery.isEmpty) {
      return false;
    }

    return normalized == normalizedQuery ||
        normalized.startsWith(normalizedQuery) ||
        normalized.contains(normalizedQuery);
  }

  String _entityKey(ShopEntity entity) {
    return '${entity.type.trim().toLowerCase()}:'
        '${entity.id.trim().toLowerCase()}';
  }

  void _sortByRelevance(
    List<ShopEntity> entities,
    String normalizedQuery,
  ) {
    entities.sort(
      (a, b) {
        final nameA = _normalizeName(a.name);
        final nameB = _normalizeName(b.name);

        final rankA = _matchRank(nameA, normalizedQuery);
        final rankB = _matchRank(nameB, normalizedQuery);

        final rankComparison = rankA.compareTo(rankB);

        if (rankComparison != 0) {
          return rankComparison;
        }

        final nameComparison = nameA.compareTo(nameB);

        if (nameComparison != 0) {
          return nameComparison;
        }

        final typeComparison = a.type
            .trim()
            .toLowerCase()
            .compareTo(
              b.type.trim().toLowerCase(),
            );

        if (typeComparison != 0) {
          return typeComparison;
        }

        return a.id
            .trim()
            .toLowerCase()
            .compareTo(
              b.id.trim().toLowerCase(),
            );
      },
    );
  }

  int _matchRank(
    String normalizedName,
    String normalizedQuery,
  ) {
    if (normalizedName == normalizedQuery) {
      return 0;
    }

    if (normalizedName.startsWith(normalizedQuery)) {
      return 1;
    }

    if (normalizedName.contains(normalizedQuery)) {
      return 2;
    }

    return 3;
  }
}