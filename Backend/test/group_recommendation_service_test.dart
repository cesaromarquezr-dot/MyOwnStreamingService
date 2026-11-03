import 'package:test/test.dart';

import '../database/database.dart';
import '../models/account.dart';
import '../models/group_recommendation.dart';
import '../models/profile.dart';
import '../services/group_recommendation_service.dart';

void main() {
  group('GroupRecommendationService finalization', () {
    test('a rejected recommendation enters every eligible profile wishlist',
        () {
      final database = Database.instance;
      final firstProfile = Profile(id: 'profile-1', name: 'One');
      final secondProfile = Profile(id: 'profile-2', name: 'Two');
      final account = _account([firstProfile, secondProfile]);
      database.saveAccount(account, persist: false);

      final recommendation = _endedRecommendation(
        accountId: account.id,
        votes: {
          firstProfile.id: GroupRecommendationVote.no,
          secondProfile.id: GroupRecommendationVote.yes,
        },
        participants: {firstProfile.id, secondProfile.id},
      );
      database.saveGroupRecommendation(recommendation);

      GroupRecommendationService(database).getRecommendation(
        accountId: account.id,
        recommendationId: recommendation.id,
      );

      expect(recommendation.status, GroupRecommendationStatus.rejected);
      expect(
          firstProfile.wishlistRecommendationIds, contains(recommendation.id));
      expect(
          secondProfile.wishlistRecommendationIds, contains(recommendation.id));
      expect(account.wishlistRecommendationIds,
          isNot(contains(recommendation.id)));
    });

    test('a yes majority puts the recommendation in the account wishlist only',
        () {
      final database = Database.instance;
      final firstProfile = Profile(id: 'profile-1', name: 'One');
      final secondProfile = Profile(id: 'profile-2', name: 'Two');
      final thirdProfile = Profile(id: 'profile-3', name: 'Three');
      final account = _account([firstProfile, secondProfile, thirdProfile]);
      database.saveAccount(account, persist: false);

      final recommendation = _endedRecommendation(
        accountId: account.id,
        votes: {
          firstProfile.id: GroupRecommendationVote.yes,
          secondProfile.id: GroupRecommendationVote.yes,
          thirdProfile.id: GroupRecommendationVote.no,
        },
        participants: {
          firstProfile.id,
          secondProfile.id,
          thirdProfile.id,
        },
      );
      database.saveGroupRecommendation(recommendation);

      GroupRecommendationService(database).getRecommendation(
        accountId: account.id,
        recommendationId: recommendation.id,
      );

      expect(recommendation.status, GroupRecommendationStatus.approved);
      expect(account.wishlistRecommendationIds, contains(recommendation.id));
      for (final profile in account.profiles) {
        expect(profile.wishlistRecommendationIds,
            isNot(contains(recommendation.id)));
      }
    });

    test('importing a rejected recommendation clears profile wishlists', () {
      final database = Database.instance;
      final firstProfile = Profile(id: 'profile-1', name: 'One');
      final secondProfile = Profile(id: 'profile-2', name: 'Two');
      final account = _account([firstProfile, secondProfile]);
      database.saveAccount(account);

      final recommendation = _endedRecommendation(
        accountId: account.id,
        votes: {
          firstProfile.id: GroupRecommendationVote.no,
          secondProfile.id: GroupRecommendationVote.no,
        },
        participants: {firstProfile.id, secondProfile.id},
      );
      database.saveGroupRecommendation(recommendation);
      final service = GroupRecommendationService(database);
      service.getRecommendation(
        accountId: account.id,
        recommendationId: recommendation.id,
      );
      expect(
          firstProfile.wishlistRecommendationIds, contains(recommendation.id));

      service.reconcileImportedMedia(
        accountId: account.id,
        mediaId: 'server-file-1',
        title: recommendation.title,
        type: recommendation.type,
      );

      expect(recommendation.status, GroupRecommendationStatus.acquired);
      expect(firstProfile.wishlistRecommendationIds,
          isNot(contains(recommendation.id)));
      expect(secondProfile.wishlistRecommendationIds,
          isNot(contains(recommendation.id)));
    });

    test('account supports ten profiles', () {
      final profiles = List<Profile>.generate(
        Account.maxProfiles,
        (index) => Profile(id: 'profile-$index', name: 'Profile $index'),
      );
      final account = _account(profiles);

      expect(Account.maxProfiles, 10);
      expect(account.canAddProfile, isFalse);
    });
  });
}

Account _account(List<Profile> profiles) {
  return Account(
    id: 'group-recommendation-test-account',
    username: 'owner',
    email: 'owner@example.test',
    passwordHash: 'password-hash',
    securityAnswerHash: 'answer-hash',
    profiles: profiles,
  );
}

GroupRecommendation _endedRecommendation({
  required String accountId,
  required Map<String, GroupRecommendationVote> votes,
  required Set<String> participants,
}) {
  final now = DateTime.now();
  return GroupRecommendation(
    id: 'recommendation-1',
    accountId: accountId,
    title: 'A recommendation',
    type: 'album',
    recommendedByProfileId: participants.first,
    createdAt: now.subtract(const Duration(days: 2)),
    votingEndsAt: now.subtract(const Duration(days: 1)),
    votes: votes,
    activeParticipants: participants,
  );
}
