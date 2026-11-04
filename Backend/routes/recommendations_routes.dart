// FILE: `Backend/routes/recommendations_routes.dart`.
// Purpose: Implements the recommendations routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Recommendation privacy:
// - Only authenticated accounts may request recommendations.
// - profileId must belong to the authenticated account.
// - Profile history, likes, dislikes, and owned media are never accepted
//   from the client; they are read from the authenticated profile.
// - Provider/purchase metadata is exposed only through the recommendation
//   service's existing catalog model.
// - Internal service errors are logged server-side and are not returned.

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import '../database/database.dart';
import '../middleware/authentication.dart';
import '../models/account.dart';
import '../models/media.dart';
import '../models/profile.dart';
import '../models/recommendation_preferences.dart';
import '../services/recommendations_service.dart'
    as recommendations;

class RecommendationsRoutes {
  static const String _recommendationsPath =
      '/api/v1/recommendations';

  static const int _maxProfileIdLength = 256;
  static const int _maxLimit = 100;

  final AuthenticationMiddleware authenticationMiddleware;
  final recommendations.RecommendationsService
      recommendationsService;
  final Database database;

  RecommendationsRoutes({
    required this.authenticationMiddleware,
    required this.recommendationsService,
    required this.database,
  });

  /// Handles authenticated recommendation requests.
  ///
  /// GET /api/v1/recommendations?profileId=<id>&limit=<n>
  Future<void> handle(HttpRequest request) async {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      await _close(
        request.response,
        HttpStatus.noContent,
      );
      return;
    }

    const supportedPaths = <String>{
      _recommendationsPath,
      '$_recommendationsPath/preferences',
      '$_recommendationsPath/feedback',
      '$_recommendationsPath/similarity',
    };
    if (!supportedPaths.contains(request.uri.path)) {
      await _sendJson(
        request.response,
        HttpStatus.notFound,
        <String, dynamic>{
          'success': false,
          'error': 'Recommendation route not found.',
        },
      );
      return;
    }

    final supportedMethod = switch (request.uri.path) {
      '$_recommendationsPath/preferences' => request.method == 'GET' || request.method == 'PUT',
      '$_recommendationsPath/feedback' => request.method == 'POST',
      _ => request.method == 'GET',
    };
    if (!supportedMethod) {
      await _sendJson(request.response, HttpStatus.methodNotAllowed,
          <String, dynamic>{'success': false, 'error': 'Method not allowed.'});
      return;
    }

    final Account? account =
        authenticationMiddleware.authenticate(request);

    if (account == null) {
      await _sendJson(
        request.response,
        HttpStatus.unauthorized,
        <String, dynamic>{
          'success': false,
          'error': 'Authentication required.',
        },
      );
      return;
    }

    try {
      switch (request.uri.path) {
        case '$_recommendationsPath/preferences':
          if (request.method == 'GET') {
            await _getPreferences(request, account);
          } else {
            await _updatePreferences(request, account);
          }
          break;
        case '$_recommendationsPath/feedback':
          await _saveFeedback(request, account);
          break;
        case '$_recommendationsPath/similarity':
          await _getSimilarity(request, account);
          break;
        default:
          await _getRecommendations(request, account);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Unable to generate recommendations.',
        name: 'RecommendationsRoutes',
        error: error,
        stackTrace: stackTrace,
      );

      await _sendJson(
        request.response,
        HttpStatus.internalServerError,
        <String, dynamic>{
          'success': false,
          'error': 'Unable to generate recommendations.',
        },
      );
    }
  }

  Future<void> _getRecommendations(
    HttpRequest request,
    Account account,
  ) async {
    final query = request.uri.queryParameters;

    final profileId =
        query['profileId']?.trim() ?? '';

    if (profileId.isEmpty) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'profileId is required.',
        },
      );
      return;
    }

    if (profileId.length > _maxProfileIdLength) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': 'profileId is too long.',
        },
      );
      return;
    }

    final Profile? profile =
        account.getProfileById(profileId);

    if (profile == null) {
      await _sendJson(
        request.response,
        HttpStatus.forbidden,
        <String, dynamic>{
          'success': false,
          'error': 'Profile does not belong to this account.',
        },
      );
      return;
    }

    final limitResult = _parseLimit(
      query['limit'],
    );

    if (limitResult.$2 != null) {
      await _sendJson(
        request.response,
        HttpStatus.badRequest,
        <String, dynamic>{
          'success': false,
          'error': limitResult.$2,
        },
      );
      return;
    }

    final limit = limitResult.$1;

    final recommendationProfile =
        recommendations.RecommendationProfile(
      ownedMediaIds: List<String>.from(
        profile.ownedMediaIds,
      ),
      likedMediaIds: List<String>.from(
        profile.likedMediaIds,
      ),
      dislikedMediaIds: List<String>.from(
        profile.dislikedMediaIds,
      ),
      history: _buildHistory(profile, account: account),
      includeOwnedLibraryItems: profile.recommendationPreferences.includeLibraryItems,
      includeExternalItems: profile.recommendationPreferences.includeExternalItems,
      includeWatchedItems: profile.recommendationPreferences.includeWatchedItems,
      includeRewatches: profile.recommendationPreferences.includeRewatches,
      excludeDisliked: profile.recommendationPreferences.excludeDisliked,
      familiarPercent: profile.recommendationPreferences.familiarPercent,
      prioritizedPerformers: profile.recommendationPreferences.prioritizedPerformers,
      prioritizedStudios: profile.recommendationPreferences.prioritizedStudios,
      prioritizedThemes: profile.recommendationPreferences.prioritizedThemes,
      excludedTones: profile.recommendationPreferences.excludedTones,
      excludedGenres: profile.recommendationPreferences.excludedGenres,
      feedback: profile.recommendationFeedback,
    );

    final catalog = database
        .getAllMedia()
        .where((media) => media.accessibleProfileIds.isEmpty ||
            media.accessibleProfileIds.contains(profile.id))
        .map(_toRecommendationMedia)
        .toList(growable: false);

    final recommendationResults =
        recommendationsService.getRecommendationsFromMedia(
      profile: recommendationProfile,
      catalog: catalog,
      limit: limit,
    );

    await _sendJson(
      request.response,
      HttpStatus.ok,
      <String, dynamic>{
        'success': true,
        'profileId': profile.id,
        'preferences': profile.recommendationPreferences.toJson(),
        'recommendations': recommendationResults
            .map(
              (recommendation) =>
                  recommendation.toJson(),
            )
            .toList(growable: false),
      },
    );
  }

  Future<void> _getPreferences(HttpRequest request, Account account) async {
    final profileId = request.uri.queryParameters['profileId']?.trim() ?? '';
    if (profileId.isEmpty || profileId.length > _maxProfileIdLength) {
      await _sendJson(request.response, HttpStatus.badRequest,
          <String, dynamic>{'success': false, 'error': 'A valid profileId is required.'});
      return;
    }
    final profile = account.getProfileById(profileId);
    if (profile == null) {
      await _sendJson(request.response, HttpStatus.forbidden,
          <String, dynamic>{'success': false, 'error': 'Profile does not belong to this account.'});
      return;
    }
    await _sendJson(request.response, HttpStatus.ok, <String, dynamic>{
      'success': true,
      'profileId': profile.id,
      'preferences': profile.recommendationPreferences.toJson(),
    });
  }

  Future<void> _updatePreferences(HttpRequest request, Account account) async {
    final body = await _readJsonBody(request);
    final profileId = body?['profileId']?.toString().trim() ?? '';
    if (profileId.isEmpty || profileId.length > _maxProfileIdLength || body?['preferences'] is! Map) {
      await _sendJson(request.response, HttpStatus.badRequest,
          <String, dynamic>{'success': false, 'error': 'profileId and a preferences object are required.'});
      return;
    }
    final profile = account.getProfileById(profileId);
    if (profile == null) {
      await _sendJson(request.response, HttpStatus.forbidden,
          <String, dynamic>{'success': false, 'error': 'Profile does not belong to this account.'});
      return;
    }
    profile.recommendationPreferences = RecommendationPreferences.fromJson(body!['preferences']);
    await database.persistAccountAndWait(account);
    await _sendJson(request.response, HttpStatus.ok, <String, dynamic>{
      'success': true,
      'profileId': profile.id,
      'preferences': profile.recommendationPreferences.toJson(),
    });
  }

  Future<void> _saveFeedback(HttpRequest request, Account account) async {
    final body = await _readJsonBody(request);
    final profileId = body?['profileId']?.toString().trim() ?? '';
    final mediaId = body?['mediaId']?.toString().trim() ?? '';
    final action = body?['action']?.toString().trim() ?? '';
    const acceptedActions = <String>{
      'moreLikeThis', 'notInterested', 'alreadyWatched', 'notPreferredGenre',
      'likeActorNotGenre', 'likeStoryNotTone', 'stopShowing',
    };
    if (profileId.isEmpty || mediaId.isEmpty || !acceptedActions.contains(action)) {
      await _sendJson(request.response, HttpStatus.badRequest,
          <String, dynamic>{'success': false, 'error': 'profileId, mediaId and a supported action are required.'});
      return;
    }
    final profile = account.getProfileById(profileId);
    if (profile == null) {
      await _sendJson(request.response, HttpStatus.forbidden,
          <String, dynamic>{'success': false, 'error': 'Profile does not belong to this account.'});
      return;
    }
    profile.recommendationFeedback[mediaId] = action;
    final media = database.getMediaById(mediaId);
    if (media != null && media.accessibleProfileIds.isNotEmpty &&
        !media.accessibleProfileIds.contains(profile.id)) {
      await _sendJson(request.response, HttpStatus.notFound,
          <String, dynamic>{'success': false, 'error': 'Catalog title not found.'});
      return;
    }
    final preferences = profile.recommendationPreferences;
    List<String> mergeValues(List<String> current, Iterable<String> additions) =>
        <String>{...current, ...additions.map((value) => value.trim()).where((value) => value.isNotEmpty)}.toList();

    if (action == 'moreLikeThis') profile.likeMedia(mediaId);
    if (action == 'alreadyWatched') profile.markAsWatched(mediaId);
    if (media != null && action == 'notPreferredGenre') {
      profile.recommendationPreferences = preferences.copyWith(
        excludedGenres: mergeValues(preferences.excludedGenres, media.genres),
      );
    }
    if (media != null && action == 'likeActorNotGenre') {
      profile.recommendationPreferences = preferences.copyWith(
        prioritizedPerformers: mergeValues(
          preferences.prioritizedPerformers,
          media.actors,
        ),
        excludedGenres: mergeValues(preferences.excludedGenres, media.genres),
      );
    }
    if (media != null && action == 'likeStoryNotTone') {
      profile.recommendationPreferences = preferences.copyWith(
        prioritizedThemes: mergeValues(
          preferences.prioritizedThemes,
          media.themes,
        ),
        excludedTones: mergeValues(
          preferences.excludedTones,
          media.tones,
        ),
      );
    }
    if (action == 'notInterested' || action == 'stopShowing') {
      profile.dislikedMediaIds.remove(mediaId);
      // Explicit recommendation suppression is separate from the user's
      // global dislike list and is retained in recommendationFeedback.
    }
    await database.persistAccountAndWait(account);
    await _sendJson(request.response, HttpStatus.ok, <String, dynamic>{
      'success': true,
      'profileId': profile.id,
      'mediaId': mediaId,
      'action': action,
    });
  }

  Future<void> _getSimilarity(HttpRequest request, Account account) async {
    final query = request.uri.queryParameters;
    final profileId = query['profileId']?.trim() ?? '';
    final sourceId = query['sourceId']?.trim() ?? '';
    final targetId = query['targetId']?.trim() ?? '';
    if (profileId.isEmpty || sourceId.isEmpty || targetId.isEmpty) {
      await _sendJson(request.response, HttpStatus.badRequest,
          <String, dynamic>{'success': false, 'error': 'profileId, sourceId and targetId are required.'});
      return;
    }
    if (account.getProfileById(profileId) == null) {
      await _sendJson(request.response, HttpStatus.forbidden,
          <String, dynamic>{'success': false, 'error': 'Profile does not belong to this account.'});
      return;
    }
    final source = database.getMediaById(sourceId);
    final target = database.getMediaById(targetId);
    if (source == null || target == null ||
        (source.accessibleProfileIds.isNotEmpty &&
            !source.accessibleProfileIds.contains(profileId)) ||
        (target.accessibleProfileIds.isNotEmpty &&
            !target.accessibleProfileIds.contains(profileId))) {
      await _sendJson(request.response, HttpStatus.notFound,
          <String, dynamic>{'success': false, 'error': 'One or both catalog titles were not found.'});
      return;
    }
    await _sendJson(request.response, HttpStatus.ok, <String, dynamic>{
      'success': true,
      'comparison': recommendationsService.compareTitles(
        source: _toRecommendationMedia(source),
        target: _toRecommendationMedia(target),
      ),
    });
  }

  Future<Map<String, dynamic>?> _readJsonBody(HttpRequest request) async {
    const maxBodyBytes = 65536;
    final builder = BytesBuilder(copy: false);
    var totalBytes = 0;
    var tooLarge = false;
    await for (final chunk in request) {
      totalBytes += chunk.length;
      if (totalBytes > maxBodyBytes) {
        tooLarge = true;
      } else if (!tooLarge) {
        builder.add(chunk);
      }
    }
    if (tooLarge) return null;
    try {
      final content = utf8.decode(builder.takeBytes());
      final decoded = jsonDecode(content);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  (int, String?) _parseLimit(String? value) {
    final defaultLimit =
        recommendationsService.defaultLimit;

    final boundedDefault = defaultLimit.clamp(
      1,
      _maxLimit,
    );

    if (value == null || value.trim().isEmpty) {
      return (
        boundedDefault,
        null,
      );
    }

    final parsed = int.tryParse(
      value.trim(),
    );

    if (parsed == null) {
      return (
        boundedDefault,
        'limit must be a positive integer.',
      );
    }

    if (parsed <= 0) {
      return (
        boundedDefault,
        'limit must be a positive integer.',
      );
    }

    if (parsed > _maxLimit) {
      return (
        _maxLimit,
        'limit cannot exceed $_maxLimit.',
      );
    }

    return (
      parsed,
      null,
    );
  }

  List<recommendations.RecommendationHistoryItem> _buildHistory(
    Profile profile, {
    required Account account,
  }) {
    final history =
        <recommendations.RecommendationHistoryItem>[];

    final seen = <String>{};

    void addHistoryItem(String mediaId) {
      final normalizedId = mediaId.trim();

      if (normalizedId.isEmpty ||
          !seen.add(normalizedId)) {
        return;
      }

      final progress = profile.getWatchProgress(
        normalizedId,
      );

      final completion = profile.watchedMediaIds.contains(normalizedId)
          ? 1.0
          : _normalizeCompletion(progress);

      history.add(
        recommendations.RecommendationHistoryItem(
          mediaId: normalizedId,
          watchedAt: profile.getLastWatchedAt(normalizedId),
          completion: completion,
          sourceProfileName: null,
        ),
      );
    }

    for (final mediaId in profile.watchHistory) {
      addHistoryItem(mediaId);
    }

    for (final mediaId in profile.watchedMediaIds) {
      addHistoryItem(mediaId);
    }

    // Activity is private by default. Only other profiles that explicitly
    // enabled sharing may contribute signals, and the current profile must
    // separately opt in to using those shared signals.
    if (profile.recommendationPreferences.useOtherProfileActivity) {
      final ownHistoryIds = <String>{
        ...profile.watchHistory,
        ...profile.watchedMediaIds,
      }.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
      final sharedIdsSeen = <String>{};
      for (final otherProfile in account.profiles) {
        if (otherProfile.id == profile.id ||
            !otherProfile.recommendationPreferences.shareHistoryWithOtherProfiles) {
          continue;
        }
        final sharedIds = <String>{
          ...otherProfile.watchHistory,
          ...otherProfile.watchedMediaIds,
        };
        for (final mediaId in sharedIds) {
          final normalizedId = mediaId.trim();
          if (normalizedId.isEmpty || ownHistoryIds.contains(normalizedId) ||
              !sharedIdsSeen.add(normalizedId)) continue;
          history.add(recommendations.RecommendationHistoryItem(
            mediaId: normalizedId,
            watchedAt: otherProfile.getLastWatchedAt(normalizedId),
            completion: otherProfile.watchedMediaIds.contains(normalizedId)
                ? 1.0
                : _normalizeCompletion(otherProfile.getWatchProgress(normalizedId)),
            sourceProfileName: otherProfile.name,
          ));
        }
      }
    }

    return history;
  }

  double _normalizeCompletion(double progress) {
    if (!progress.isFinite || progress <= 0) {
      return 0.0;
    }

    if (progress >= 0.90) {
      return 1.0;
    }

    return progress.clamp(
      0.0,
      1.0,
    );
  }

  List<String> _deriveSubgenres(
    List<String> genres,
    List<String> tags,
    List<String> themes,
  ) {
    final text =
        '${genres.join(' ')} '
        '${tags.join(' ')} '
        '${themes.join(' ')}'
            .toLowerCase();

    const values = <String>[
      'adventure',
      'disaster',
      'martial arts',
      'spy',
      'romantic comedy',
      'rom-com',
      'slapstick',
      'dark comedy',
      'black comedy',
      'mockumentary',
      'satire',
      'biopic',
      'historical drama',
      'legal drama',
      'courtroom',
      'melodrama',
      'medical drama',
      'police procedural',
      'crime drama',
      'teen drama',
      'dramedy',
      'slasher',
      'supernatural horror',
      'psychological horror',
      'zombie',
      'found footage',
      'space opera',
      'dystopian',
      'cyberpunk',
      'time travel',
      'psychological thriller',
      'crime thriller',
      'political thriller',
      'techno-thriller',
      'historical romance',
      'romantic drama',
      'high fantasy',
      'epic fantasy',
      'urban fantasy',
      'dark fantasy',
      'film noir',
      'gangster',
      'heist',
      'neo-noir',
      'spaghetti western',
      'revisionist western',
      'epic western',
      'space western',
      'military drama',
      'anti-war',
      'war biographical',
      'cgi animation',
      'stop motion',
      'anime',
      'adult animation',
      'competition show',
      'self-improvement',
      'reality',
      'talk show',
      'interview',
      'game show',
      'variety show',
      'award show',
      'news',
      'cooking',
      'home and garden',
      'educational',
      'court show',
      'religious programming',
      'music television',
    ];

    return values
        .where((value) => text.contains(value))
        .toList(growable: false);
  }

  recommendations.RecommendationMedia
      _toRecommendationMedia(
    Media media,
  ) {
    return recommendations.RecommendationMedia(
      id: media.id,
      title: media.title,
      year: media.year,
      posterUrl: media.posterUrl,
      description: media.description,
      rating: media.rating,
      ratingReason: media.ratingReason,
      mediaType: media.type.name,
      seriesId: media.seriesId,
      franchiseId: media.franchises.isNotEmpty
          ? media.franchises.first
          : null,
      countryOfOrigin: media.countryOfOrigin,
      language: media.language,
      adaptationGroupId: media.adaptationGroupId,
      adaptationGroupName: media.adaptationGroupName,
      relationshipTypes:
          List<String>.from(media.relationshipTypes),
      actors: List<String>.from(media.actors),
      characters: List<String>.from(media.characters),
      franchises: List<String>.from(media.franchises),
      genres: List<String>.from(media.genres),
      subgenres: _deriveSubgenres(
        media.genres,
        media.tags,
        media.themes,
      ),
      themes: List<String>.from(media.themes),
      tones: List<String>.from(media.tones),
      culturalSettings: List<String>.from(media.culturalSettings),
      culturalInspirations: List<String>.from(media.culturalInspirations),
      tags: List<String>.from(media.tags),
      directors: List<String>.from(media.directors),
      writers: List<String>.from(media.writers),
      music: List<String>.from(media.music),
      studios: List<String>.from(media.studios),
      companies: List<String>.from(media.companies),
      references: List<String>.from(media.references),
      watchOptions: media.watchOptions
          .map(
            (option) => recommendations.WatchOption(
              provider: option.provider,
              type: option.type,
              url: option.url,
            ),
          )
          .toList(growable: false),
      purchaseOptions: media.purchaseOptions
          .map(
            (option) => recommendations.PurchaseOption(
              retailer: option.retailer,
              title: option.title,
              price: option.price,
              currency: option.currency,
              url: option.url,
              format: option.format,
            ),
          )
          .toList(growable: false),
    );
  }

  void _addCorsHeaders(
    HttpResponse response,
  ) {
    response.headers
      ..set(
        'Access-Control-Allow-Origin',
        '*',
      )
      ..set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization',
      )
      ..set(
        'Access-Control-Allow-Methods',
        'GET, PUT, POST, OPTIONS',
      )
      ..set(
        'Access-Control-Expose-Headers',
        'Content-Type, Content-Length',
      );
  }

  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> data,
  ) async {
    response.statusCode = statusCode;

    response.headers
      ..contentType = ContentType.json
      ..set(
        'Cache-Control',
        'no-store, no-cache, must-revalidate',
      )
      ..set(
        'Pragma',
        'no-cache',
      )
      ..set(
        'X-Content-Type-Options',
        'nosniff',
      );

    response.write(
      jsonEncode(data),
    );

    await response.close();
  }

  Future<void> _close(
    HttpResponse response,
    int statusCode,
  ) async {
    response.statusCode = statusCode;

    response.headers
      ..set(
        'Cache-Control',
        'no-store',
      )
      ..set(
        'X-Content-Type-Options',
        'nosniff',
      );

    await response.close();
  }
}