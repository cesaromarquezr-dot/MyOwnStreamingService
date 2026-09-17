// FILE: `Backend/routes/recommendations_routes.dart`.
// Purpose: Implements the recommendations routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:io';

import '../database/database.dart';
import '../middleware/authentication.dart';
import '../models/account.dart';
import '../models/media.dart';
import '../models/profile.dart';
import '../services/recommendations_service.dart'
    as recommendations;

class RecommendationsRoutes {
  final AuthenticationMiddleware authenticationMiddleware;
  final recommendations.RecommendationsService
      recommendationsService;
  final Database database;

  RecommendationsRoutes({
    required this.authenticationMiddleware,
    required this.recommendationsService,
    required this.database,
  });

  /// Performs `handle` for this feature. Update this documentation when its contract changes.
  Future<void> handle(HttpRequest request) async {
    try {
      _addCorsHeaders(request.response);

      if (request.method == 'OPTIONS') {
        request.response.statusCode =
            HttpStatus.noContent;

        await request.response.close();
        return;
      }

      if (request.method != 'GET') {
        await _sendJson(
          request.response,
          HttpStatus.methodNotAllowed,
          {
            'error': 'Method not allowed.',
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
          {
            'error': 'Authentication required.',
          },
        );
        return;
      }

      final profileId =
          request.uri.queryParameters['profileId'];

      if (profileId == null ||
          profileId.trim().isEmpty) {
        await _sendJson(
          request.response,
          HttpStatus.badRequest,
          {
            'error': 'profileId is required.',
          },
        );
        return;
      }

      final Profile? profile =
          account.getProfileById(profileId);

      if (profile == null) {
        await _sendJson(
          request.response,
          HttpStatus.notFound,
          {
            'error':
                'Profile not found for this account.',
          },
        );
        return;
      }

      final limitValue =
          request.uri.queryParameters['limit'];

      int limit =
          recommendationsService.defaultLimit;

      if (limitValue != null &&
          limitValue.trim().isNotEmpty) {
        final parsedLimit =
            int.tryParse(limitValue);

        if (parsedLimit == null ||
            parsedLimit <= 0) {
          await _sendJson(
            request.response,
            HttpStatus.badRequest,
            {
              'error':
                  'limit must be a positive integer.',
            },
          );
          return;
        }

        limit = parsedLimit;
      }

      if (limit > 100) {
        limit = 100;
      }

      final recommendationProfile =
          recommendations.RecommendationProfile(
        ownedMediaIds:
            List<String>.from(
          profile.ownedMediaIds,
        ),
        likedMediaIds:
            List<String>.from(
          profile.likedMediaIds,
        ),
        dislikedMediaIds:
            List<String>.from(
          profile.dislikedMediaIds,
        ),
        history: _buildHistory(profile),
      );

      final catalog = database
          .getAllMedia()
          .map(_toRecommendationMedia)
          .toList();

      final recommendationResults =
          recommendationsService
              .getRecommendationsFromMedia(
        profile: recommendationProfile,
        catalog: catalog,
        limit: limit,
      );

      await _sendJson(
        request.response,
        HttpStatus.ok,
        {
          'profileId': profile.id,
          'recommendations':
              recommendationResults
                  .map(
                    (recommendation) =>
                        recommendation.toJson(),
                  )
                  .toList(),
        },
      );
    } catch (error) {
      await _sendJson(
        request.response,
        HttpStatus.internalServerError,
        {
          'error':
              'Unable to generate recommendations.',
          'details': error.toString(),
        },
      );
    }
  }

  List<
      recommendations.RecommendationHistoryItem> _buildHistory(
    Profile profile,
  ) {
    final history =
        <recommendations.RecommendationHistoryItem>[];

    for (final mediaId in profile.watchHistory) {
      final progress =
          profile.getWatchProgress(mediaId);

      DateTime? watchedAt;

      history.add(
        recommendations.RecommendationHistoryItem(
          mediaId: mediaId,
          watchedAt: watchedAt,
          completion:
              progress >= 0.90
                  ? 1.0
                  : progress,
        ),
      );
    }

    for (final mediaId
        in profile.watchedMediaIds) {
      final alreadyIncluded = history.any(
        (item) => item.mediaId == mediaId,
      );

      if (alreadyIncluded) {
        continue;
      }

      final progress =
          profile.getWatchProgress(mediaId);

      history.add(
        recommendations.RecommendationHistoryItem(
          mediaId: mediaId,
          watchedAt: null,
          completion:
              progress >= 0.90
                  ? 1.0
                  : progress,
        ),
      );
    }

    return history;
  }

  List<String> _deriveSubgenres(
    List<String> genres,
    List<String> tags,
    List<String> themes,
  ) {
    final text = '${genres.join(' ')} ${tags.join(' ')} ${themes.join(' ')}'.toLowerCase();
    const values = <String>[
      'adventure', 'disaster', 'martial arts', 'spy',
      'romantic comedy', 'rom-com', 'slapstick', 'dark comedy', 'black comedy', 'mockumentary', 'satire',
      'biopic', 'historical drama', 'legal drama', 'courtroom', 'melodrama', 'medical drama', 'police procedural', 'crime drama', 'teen drama', 'dramedy',
      'slasher', 'supernatural horror', 'psychological horror', 'zombie', 'found footage',
      'space opera', 'dystopian', 'cyberpunk', 'time travel',
      'psychological thriller', 'crime thriller', 'political thriller', 'techno-thriller',
      'historical romance', 'romantic drama',
      'high fantasy', 'epic fantasy', 'urban fantasy', 'dark fantasy',
      'film noir', 'gangster', 'heist', 'neo-noir',
      'spaghetti western', 'revisionist western', 'epic western', 'space western',
      'military drama', 'anti-war', 'war biographical',
      'cgi animation', 'stop motion', 'anime', 'adult animation',
      'competition show', 'self-improvement', 'reality', 'talk show', 'interview', 'game show', 'variety show', 'award show', 'news', 'cooking', 'home and garden', 'educational', 'court show', 'religious programming', 'music television',
    ];
    return values.where(text.contains).toList();
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

      franchiseId:
          media.franchises.isNotEmpty
              ? media.franchises.first
              : null,

      actors:
          List<String>.from(media.actors),

      characters:
          List<String>.from(media.characters),

      franchises:
          List<String>.from(media.franchises),

      genres:
          List<String>.from(media.genres),

      subgenres:
          _deriveSubgenres(media.genres, media.tags, media.themes),

      themes:
          List<String>.from(media.themes),

      tags:
          List<String>.from(media.tags),

      directors:
          List<String>.from(media.directors),

      writers:
          List<String>.from(media.writers),

      music:
          List<String>.from(media.music),

      references:
          List<String>.from(media.references),

      watchOptions:
          media.watchOptions
              .map(
                (option) =>
                    recommendations.WatchOption(
                  provider:
                      option.provider,
                  type:
                      option.type,
                  url:
                      option.url,
                ),
              )
              .toList(),

      purchaseOptions:
          media.purchaseOptions
              .map(
                (option) =>
                    recommendations.PurchaseOption(
                  retailer:
                      option.retailer,
                  title:
                      option.title,
                  price:
                      option.price,
                  currency:
                      option.currency,
                  url:
                      option.url,
                  format:
                      option.format,
                ),
              )
              .toList(),
    );
  }

  /// Performs `_addCorsHeaders` for this feature. Update this documentation when its contract changes.
  void _addCorsHeaders(
    HttpResponse response,
  ) {
    response.headers.set(
      'Access-Control-Allow-Origin',
      '*',
    );

    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );

    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, OPTIONS',
    );
  }

  /// Performs `_sendJson` for this feature. Update this documentation when its contract changes.
  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> data,
  ) async {
    response.statusCode = statusCode;

    response.headers.contentType =
        ContentType.json;

    response.write(
      jsonEncode(data),
    );

    await response.close();
  }
}
