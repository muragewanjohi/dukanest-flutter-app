import 'package:dukanest_app/features/subscription/models/referred_friend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReferredFriend', () {
    test('parseReferredFriendsList reads referredFriends', () {
      final friends = parseReferredFriendsList({
        'referredFriends': [
          {
            'subdomain': 'friend-shop',
            'storeName': 'Friend Shop',
            'status': 'subscribed',
            'createdAt': '2026-01-15T10:00:00Z',
          },
        ],
      });

      expect(friends, hasLength(1));
      expect(friends.first.subdomain, 'friend-shop');
      expect(friends.first.displayName, 'Friend Shop');
      expect(friends.first.status, 'subscribed');
    });

    test('parseReferralDashboardPayload combines summary and friends', () {
      final parsed = parseReferralDashboardPayload({
        'data': {
          'shareSubdomain': 'mine',
          'referralCount': 2,
          'referred_friends': [
            {'store_name': 'Alpha', 'subdomain': 'alpha'},
          ],
        },
      });

      expect(parsed.summary?.shareSubdomain, 'mine');
      expect(parsed.summary?.referralCount, 2);
      expect(parsed.friends, hasLength(1));
      expect(parsed.friends.first.displayName, 'Alpha');
    });
  });
}
