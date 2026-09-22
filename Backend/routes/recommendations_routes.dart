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

import '../database/database.dart';
import '../middleware/authentication.dart';
import '../models/account.dart';
import '../models/media.dart';
import '../models/profile.dart';
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

    if (request.method != 'GET') {
      await _sendJson(
        request.response,
        HttpStatus.methodNotAllowed,
        <String, dynamic>{
          'success': false,
          'error': 'Method not allowed.',
        },
      );
      return;
    }

    if (request.uri.path != _recommendationsPath) {
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
      await _getRecommendations(
        request,
        account,
      );
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
      history: _buildHistory(profile),
    );

    final catalog = database
        .getAllMedia()
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
        'recommendations': recommendationResults
            .map(
              (recommendation) =>
                  recommendation.toJson(),
            )
            .toList(growable: false),
      },
    );
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

  List<
      recommendations.RecommendationHistoryItem> _buildHistory(
    Profile profile,
  ) {
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

      final completion = _normalizeCompletion(
        progress,
      );

      history.add(
        recommendations.RecommendationHistoryItem(
          mediaId: normalizedId,
          watchedAt: null,
          completion: completion,
        ),
      );
    }

    for (final mediaId in profile.watchHistory) {
      addHistoryItem(mediaId);
    }

    for (final mediaId in profile.watchedMediaIds) {
      addHistoryItem(mediaId);
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
      tags: List<String>.from(media.tags),
      directors: List<String>.from(media.directors),
      writers: List<String>.from(media.writers),
      music: List<String>.from(media.music),
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
        'GET, OPTIONS',
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