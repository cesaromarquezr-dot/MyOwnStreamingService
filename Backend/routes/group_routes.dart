import 'dart:convert';
import 'dart:io';

import '../database/database.dart';
import '../middleware/authentication.dart';
import '../models/group_recommendation.dart';
import '../services/group_recommendation_service.dart';

class GroupRoutes {
  final Database database;
  final AuthenticationMiddleware authenticationMiddleware;
  final GroupRecommendationService recommendationService;

  GroupRoutes({
    required this.database,
    required this.authenticationMiddleware,
    required this.recommendationService,
  });

  Future<void> handle(HttpRequest request) async {
    try {
      final authenticatedAccount =
          authenticationMiddleware.authenticate(request);

      if (authenticatedAccount == null) {
        await _sendJson(
          request,
          HttpStatus.unauthorized,
          <String, dynamic>{
            'error': 'Authentication required.',
          },
        );
        return;
      }

      final account = authenticatedAccount;
      final accountId = account.id;
      final path = request.uri.path;

      // ----------------------------------------------------------
      // CREATE RECOMMENDATION
      // ----------------------------------------------------------

      if (request.method == 'POST' &&
          path == '/api/v1/group/recommendations') {
        final body = await _readJsonBody(request);

        final mediaId =
            body['mediaId']?.toString().trim() ?? '';

        final profileId =
            body['profileId']?.toString().trim() ?? '';

        final activeParticipants =
            _readStringSet(
          body['activeParticipants'],
        );

        if (mediaId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': 'mediaId is required.',
            },
          );
          return;
        }

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': 'profileId is required.',
            },
          );
          return;
        }

        final profileExists = account.profiles.any(
          (profile) => profile.id == profileId,
        );

        if (!profileExists) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        final media =
            database.getMediaById(mediaId);

        if (media == null) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error': 'Media not found.',
            },
          );
          return;
        }

        if (activeParticipants.isEmpty) {
          activeParticipants.add(profileId);
        }

        final allParticipantsBelongToAccount =
            activeParticipants.every(
          (participantId) => account.profiles.any(
            (profile) =>
                profile.id == participantId,
          ),
        );

        if (!allParticipantsBelongToAccount) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'One or more active participants do not belong to the account.',
            },
          );
          return;
        }

        try {
          final recommendation =
              recommendationService
                  .createRecommendation(
            accountId: accountId,
            media: media,
            recommendedByProfileId:
                profileId,
            activeParticipants:
                activeParticipants,
          );

          await _sendJson(
            request,
            HttpStatus.created,
            <String, dynamic>{
              'recommendation':
                  recommendation.toJson(),
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // GET ALL RECOMMENDATIONS
      // ----------------------------------------------------------

      if (request.method == 'GET' &&
          path ==
              '/api/v1/group/recommendations') {
        final recommendations =
            recommendationService
                .getRecommendations(
          accountId: accountId,
        );

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'recommendations':
                recommendations
                    .map(
                      (recommendation) =>
                          recommendation
                              .toJson(),
                    )
                    .toList(),
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // GET SHARED GROUP WISHLIST
      // ----------------------------------------------------------

      if (request.method == 'GET' &&
          path ==
              '/api/v1/group/wishlist') {
        final wishlist = account
            .wishlistMediaIds
            .map(
              (mediaId) {
                final media =
                    database.getMediaById(
                  mediaId,
                );

                if (media == null) {
                  return <String, dynamic>{
                    'id': mediaId,
                    'title': mediaId,
                    'type': 'unknown',
                  };
                }

                return <String, dynamic>{
                  'id': media.id,
                  'title': media.title,
                  'type': media.type.name,
                  'releaseDate':
                      media.releaseDate
                          ?.toIso8601String(),
                  'year': media.year,
                };
              },
            )
            .toList();

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'wishlist': wishlist,
            'count': wishlist.length,
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // GET SINGLE RECOMMENDATION
      // ----------------------------------------------------------

      final recommendationPath =
          RegExp(
        r'^/api/v1/group/recommendations/([^/]+)$',
      );

      final recommendationMatch =
          recommendationPath.firstMatch(
        path,
      );

      if (request.method == 'GET' &&
          recommendationMatch != null) {
        final recommendationId =
            recommendationMatch.group(1)!;

        final recommendation =
            recommendationService
                .getRecommendation(
          accountId: accountId,
          recommendationId:
              recommendationId,
        );

        if (recommendation == null) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Recommendation not found.',
            },
          );
          return;
        }

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'recommendation':
                recommendation.toJson(),
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // VOTE
      // ----------------------------------------------------------

      final votePath =
          RegExp(
        r'^/api/v1/group/recommendations/([^/]+)/vote$',
      );

      final voteMatch =
          votePath.firstMatch(path);

      if (request.method == 'POST' &&
          voteMatch != null) {
        final recommendationId =
            voteMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        final voteString =
            body['vote']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        final profileExists =
            account.profiles.any(
          (profile) =>
              profile.id == profileId,
        );

        if (!profileExists) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        GroupRecommendationVote? vote;

        if (voteString == 'yes') {
          vote =
              GroupRecommendationVote.yes;
        } else if (voteString == 'no') {
          vote =
              GroupRecommendationVote.no;
        }

        if (vote == null) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'vote must be either "yes" or "no".',
            },
          );
          return;
        }

        try {
          final recommendation =
              recommendationService.vote(
            accountId: accountId,
            recommendationId:
                recommendationId,
            profileId: profileId,
            vote: vote,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'recommendation':
                  recommendation.toJson(),
              'isInWishlist':
                  account.isInWishlist(
                recommendation.mediaId,
              ),
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // CLOSE VOTING
      // ----------------------------------------------------------

      final closePath =
          RegExp(
        r'^/api/v1/group/recommendations/([^/]+)/close$',
      );

      final closeMatch =
          closePath.firstMatch(path);

      if (request.method == 'POST' &&
          closeMatch != null) {
        final recommendationId =
            closeMatch.group(1)!;

        try {
          final recommendation =
              recommendationService
                  .closeVoting(
            accountId: accountId,
            recommendationId:
                recommendationId,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'recommendation':
                  recommendation.toJson(),
              'isInWishlist':
                  account.isInWishlist(
                recommendation.mediaId,
              ),
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // REMOVE FROM GROUP WISHLIST
      // ----------------------------------------------------------

      final wishlistMediaPath =
          RegExp(
        r'^/api/v1/group/wishlist/([^/]+)$',
      );

      final wishlistMediaMatch =
          wishlistMediaPath.firstMatch(
        path,
      );

      if (request.method == 'DELETE' &&
          wishlistMediaMatch != null) {
        final mediaId =
            wishlistMediaMatch.group(1)!;

        final removed =
            account.removeFromWishlist(
          mediaId,
        );

        if (!removed) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Media is not in the group wishlist.',
            },
          );
          return;
        }

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'message':
                'Media removed from group wishlist.',
            'mediaId': mediaId,
            'isInWishlist': false,
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // MARK WISHLIST ITEM AS ACQUIRED
      // ----------------------------------------------------------

      final acquirePath =
          RegExp(
        r'^/api/v1/group/wishlist/([^/]+)/acquire$',
      );

      final acquireMatch =
          acquirePath.firstMatch(path);

      if (request.method == 'POST' &&
          acquireMatch != null) {
        final mediaId =
            acquireMatch.group(1)!;

        final body =
            await _readJsonBody(request);

        final profileId =
            body['profileId']
                    ?.toString()
                    .trim() ??
                '';

        if (profileId.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'profileId is required.',
            },
          );
          return;
        }

        final profile =
            account.getProfileById(
          profileId,
        );

        if (profile == null) {
          await _sendJson(
            request,
            HttpStatus.forbidden,
            <String, dynamic>{
              'error':
                  'This profile does not belong to the account.',
            },
          );
          return;
        }

        if (!account.isInWishlist(
          mediaId,
        )) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Media is not in the group wishlist.',
            },
          );
          return;
        }

        final media =
            database.getMediaById(
          mediaId,
        );

        if (media == null) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error':
                  'Media not found.',
            },
          );
          return;
        }

        final acquired =
            account.markWishlistItemAcquired(
          mediaId,
          profileId: profileId,
        );

        if (!acquired) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'Unable to acquire wishlist item.',
            },
          );
          return;
        }

        await _sendJson(
          request,
          HttpStatus.ok,
          <String, dynamic>{
            'message':
                'Media acquired and added to the selected profile library.',
            'mediaId': mediaId,
            'profileId': profileId,
            'isInWishlist':
                account.isInWishlist(
              mediaId,
            ),
            'isOwned':
                profile.ownsMedia(
              mediaId,
            ),
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // DELETE RECOMMENDATION
      // ----------------------------------------------------------

      if (request.method == 'DELETE' &&
          recommendationMatch != null) {
        final recommendationId =
            recommendationMatch.group(1)!;

        try {
          recommendationService
              .deleteRecommendation(
            accountId: accountId,
            recommendationId:
                recommendationId,
          );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'message':
                  'Recommendation deleted.',
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.notFound,
            <String, dynamic>{
              'error': error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // ROUTE NOT FOUND
      // ----------------------------------------------------------

      await _sendJson(
        request,
        HttpStatus.notFound,
        <String, dynamic>{
          'error': 'Group route not found.',
        },
      );
    } catch (error) {
      await _sendJson(
        request,
        HttpStatus.internalServerError,
        <String, dynamic>{
          'error': error.toString(),
        },
      );
    }
  }

  // ------------------------------------------------------------
  // JSON BODY
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> _readJsonBody(
    HttpRequest request,
  ) async {
    final body =
        await utf8.decoder
            .bind(request)
            .join();

    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded =
        jsonDecode(body);

    if (decoded is! Map) {
      throw FormatException(
        'Request body must be a JSON object.',
      );
    }

    return Map<String, dynamic>.from(
      decoded,
    );
  }

  // ------------------------------------------------------------
  // STRING SET
  // ------------------------------------------------------------

  Set<String> _readStringSet(
    dynamic value,
  ) {
    if (value is! List) {
      return <String>{};
    }

    return value
        .map(
          (item) =>
              item.toString().trim(),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .toSet();
  }

  // ------------------------------------------------------------
  // JSON RESPONSE
  // ------------------------------------------------------------

  Future<void> _sendJson(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode =
        statusCode;

    request.response.headers.contentType =
        ContentType.json;

    request.response.write(
      jsonEncode(body),
    );

    await request.response.close();
  }
}