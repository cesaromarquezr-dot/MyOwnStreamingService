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
      //
      // A recommendation can now be for ANY movie or TV show.
      // It does not have to exist in the media catalog.
      //
      // Expected body:
      //
      // {
      //   "title": "Interstellar",
      //   "type": "movie",
      //   "profileId": "profile_123",
      //   "votingDurationHours": 24
      // }
      //
      // activeParticipants is optional.
      //
      // If it is not supplied, every profile belonging to the
      // account becomes eligible to vote.
      //

      if (request.method == 'POST' &&
          path == '/api/v1/group/recommendations') {
        final body = await _readJsonBody(request);

        final title =
            body['title']?.toString().trim() ?? '';

        final type =
            body['type']?.toString().trim() ?? '';

        final profileId =
            body['profileId']?.toString().trim() ?? '';

        final mediaIdRaw =
            body['mediaId']?.toString().trim() ?? '';

        final String? mediaId =
            mediaIdRaw.isEmpty
                ? null
                : mediaIdRaw;

        final activeParticipants =
            _readStringSet(
          body['activeParticipants'],
        );

        if (title.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error': 'title is required.',
            },
          );
          return;
        }

        if (type.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'type is required.',
            },
          );
          return;
        }

        if (type != 'movie' &&
            type != 'tvShow') {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'type must be either "movie" or "tvShow".',
            },
          );
          return;
        }

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

        // --------------------------------------------------------
        // VOTING DURATION
        // --------------------------------------------------------
        //
        // The frontend can send:
        //
        // 24       -> 24 hours
        // 72       -> 3 days
        // 168      -> 1 week
        //
        // Custom durations are also supported.
        //

        final dynamic durationRaw =
            body['votingDurationHours'];

        double votingDurationHours;

        if (durationRaw == null) {
          // Default duration.
          votingDurationHours = 24;
        } else if (durationRaw is num) {
          votingDurationHours =
              durationRaw.toDouble();
        } else {
          votingDurationHours =
              double.tryParse(
                    durationRaw.toString(),
                  ) ??
                  0;
        }

        if (votingDurationHours <= 0) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'votingDurationHours must be greater than zero.',
            },
          );
          return;
        }

        final Duration votingDuration =
            Duration(
          milliseconds:
              (votingDurationHours *
                      Duration.millisecondsPerHour)
                  .round(),
        );

        if (votingDuration <=
            Duration.zero) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'Voting duration is invalid.',
            },
          );
          return;
        }

        // --------------------------------------------------------
        // ACTIVE PARTICIPANTS
        // --------------------------------------------------------
        //
        // No participant-selection UI is required.
        //
        // If the frontend does not provide activeParticipants,
        // every profile on the account becomes eligible.
        //

        if (activeParticipants.isEmpty) {
          activeParticipants.addAll(
            account.profiles.map(
              (profile) => profile.id,
            ),
          );
        }

        if (activeParticipants.isEmpty) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  'At least one profile is required to vote.',
            },
          );
          return;
        }

        final allParticipantsBelongToAccount =
            activeParticipants.every(
          (participantId) =>
              account.profiles.any(
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
            title: title,
            type: type,
            mediaId: mediaId,
            recommendedByProfileId:
                profileId,
            activeParticipants:
                activeParticipants,
            votingDuration:
                votingDuration,
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
              'error':
                  error.toString(),
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
      //
      // This now returns BOTH:
      //
      // 1. Catalog media wishlist items.
      // 2. Approved recommendations that may not exist in the
      //    catalog.
      //

      if (request.method == 'GET' &&
          path ==
              '/api/v1/group/wishlist') {
        final List<Map<String, dynamic>>
            wishlist =
            <Map<String, dynamic>>[];

        // --------------------------------------------------------
        // CATALOG MEDIA WISHLIST
        // --------------------------------------------------------

        for (final mediaId
            in account.wishlistMediaIds) {
          final media =
              database.getMediaById(
            mediaId,
          );

          if (media == null) {
            wishlist.add(
              <String, dynamic>{
                'id': mediaId,
                'title': mediaId,
                'type': 'unknown',
                'source': 'media',
              },
            );
            continue;
          }

          wishlist.add(
            <String, dynamic>{
              'id': media.id,
              'title': media.title,
              'type': media.type.name,
              'releaseDate':
                  media.releaseDate
                      ?.toIso8601String(),
              'year': media.year,
              'source': 'media',
              'mediaId': media.id,
            },
          );
        }

        // --------------------------------------------------------
        // APPROVED RECOMMENDATIONS
        // --------------------------------------------------------

        for (final recommendationId
            in account
                .wishlistRecommendationIds) {
          final recommendation =
              recommendationService
                  .getRecommendation(
            accountId: accountId,
            recommendationId:
                recommendationId,
          );

          if (recommendation == null) {
            continue;
          }

          if (recommendation.status !=
              GroupRecommendationStatus
                  .approved) {
            continue;
          }

          wishlist.add(
            <String, dynamic>{
              'id': recommendation.id,
              'title': recommendation.title,
              'type': recommendation.type,
              'source':
                  'recommendation',
              'recommendationId':
                  recommendation.id,
              'mediaId':
                  recommendation.mediaId,
              'recommendedByProfileId':
                  recommendation
                      .recommendedByProfileId,
              'createdAt':
                  recommendation.createdAt
                      .toIso8601String(),
              'votingEndsAt':
                  recommendation.votingEndsAt
                      .toIso8601String(),
              'yesVotes':
                  recommendation.yesVotes,
              'noVotes':
                  recommendation.noVotes,
              'yesPercentage':
                  recommendation
                      .yesPercentage,
              'noPercentage':
                  recommendation
                      .noPercentage,
            },
          );
        }

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

          final bool isInWishlist =
              recommendation.mediaId != null
                  ? account.isInWishlist(
                      recommendation.mediaId!,
                    )
                  : account
                      .isRecommendationInWishlist(
                      recommendation.id,
                    );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'recommendation':
                  recommendation.toJson(),
              'isInWishlist':
                  isInWishlist,
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  error.toString(),
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

          final bool isInWishlist =
              recommendation.mediaId != null
                  ? account.isInWishlist(
                      recommendation.mediaId!,
                    )
                  : account
                      .isRecommendationInWishlist(
                      recommendation.id,
                    );

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'recommendation':
                  recommendation.toJson(),
              'isInWishlist':
                  isInWishlist,
            },
          );
        } catch (error) {
          await _sendJson(
            request,
            HttpStatus.badRequest,
            <String, dynamic>{
              'error':
                  error.toString(),
            },
          );
        }

        return;
      }

      // ----------------------------------------------------------
      // REMOVE CATALOG MEDIA FROM GROUP WISHLIST
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
        final itemId =
            wishlistMediaMatch.group(1)!;

        // First try the existing catalog-media wishlist.
        final removedMedia =
            account.removeFromWishlist(
          itemId,
        );

        if (removedMedia) {
          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'message':
                  'Media removed from group wishlist.',
              'mediaId': itemId,
              'isInWishlist': false,
            },
          );

          return;
        }

        // Then try recommendation-based wishlist.
        final removedRecommendation =
            account
                .removeRecommendationFromWishlist(
          itemId,
        );

        if (removedRecommendation) {
          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'message':
                  'Recommendation removed from group wishlist.',
              'recommendationId':
                  itemId,
              'isInWishlist': false,
            },
          );

          return;
        }

        await _sendJson(
          request,
          HttpStatus.notFound,
          <String, dynamic>{
            'error':
                'Item is not in the group wishlist.',
          },
        );

        return;
      }

      // ----------------------------------------------------------
      // MARK CATALOG WISHLIST ITEM AS ACQUIRED
      // ----------------------------------------------------------

      final acquirePath =
          RegExp(
        r'^/api/v1/group/wishlist/([^/]+)/acquire$',
      );

      final acquireMatch =
          acquirePath.firstMatch(path);

      if (request.method == 'POST' &&
          acquireMatch != null) {
        final itemId =
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

        // --------------------------------------------------------
        // CATALOG MEDIA
        // --------------------------------------------------------

        if (account.isInWishlist(
          itemId,
        )) {
          final media =
              database.getMediaById(
            itemId,
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
            itemId,
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
              'mediaId': itemId,
              'profileId': profileId,
              'isInWishlist':
                  account.isInWishlist(
                itemId,
              ),
              'isOwned':
                  profile.ownsMedia(
                itemId,
              ),
            },
          );

          return;
        }

        // --------------------------------------------------------
        // RECOMMENDATION
        // --------------------------------------------------------
        //
        // A manually entered recommendation may not have a
        // catalog mediaId, so it cannot automatically be added
        // to Profile.ownedMedia.
        //
        // For now, acquisition removes the recommendation from
        // the shared wishlist while preserving the recommendation
        // record itself.
        //

        if (account
            .isRecommendationInWishlist(
          itemId,
        )) {
          final recommendation =
              recommendationService
                  .getRecommendation(
            accountId: accountId,
            recommendationId: itemId,
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

          final removed = account
              .removeRecommendationFromWishlist(
            itemId,
          );

          if (!removed) {
            await _sendJson(
              request,
              HttpStatus.badRequest,
              <String, dynamic>{
                'error':
                    'Unable to acquire recommendation.',
              },
            );
            return;
          }

          await _sendJson(
            request,
            HttpStatus.ok,
            <String, dynamic>{
              'message':
                  'Recommendation acquired and removed from the group wishlist.',
              'recommendationId':
                  recommendation.id,
              'title':
                  recommendation.title,
              'type':
                  recommendation.type,
              'profileId':
                  profileId,
              'isInWishlist':
                  account
                      .isRecommendationInWishlist(
                recommendation.id,
              ),
              'isOwned':
                  false,
              'catalogMedia':
                  false,
            },
          );

          return;
        }

        await _sendJson(
          request,
          HttpStatus.notFound,
          <String, dynamic>{
            'error':
                'Item is not in the group wishlist.',
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

          // If the recommendation was also in the
          // shared wishlist, remove its reference.
          account
              .removeRecommendationFromWishlist(
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
              'error':
                  error.toString(),
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
          'error':
              'Group route not found.',
        },
      );
    } catch (error) {
      await _sendJson(
        request,
        HttpStatus.internalServerError,
        <String, dynamic>{
          'error':
              error.toString(),
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