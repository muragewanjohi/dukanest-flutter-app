import 'package:dukanest_app/features/subscription/models/referral_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReferralSummary', () {
    test('parses camelCase fields', () {
      final summary = ReferralSummary.fromJson({
        'shareSubdomain': 'my-store',
        'referralLink': 'https://www.dukanest.com/ref/my-store',
        'referralCount': 5,
        'successfulReferrals': 2,
        'rewardedMonths': 1,
      });

      expect(summary.shareSubdomain, 'my-store');
      expect(summary.effectiveShareLink,
          'https://www.dukanest.com/register?ref=my-store');
      expect(summary.referralCount, 5);
      expect(summary.successfulReferrals, 2);
      expect(summary.rewardedMonths, 1);
      expect(summary.hasShareContent, isTrue);
    });

    test('parses snake_case fields', () {
      final summary = ReferralSummary.fromJson({
        'share_subdomain': 'shop-b',
        'referral_link': 'https://example.com/r/shop-b',
        'referral_count': 3,
        'rewarded_months': 2,
      });

      expect(summary.shareSubdomain, 'shop-b');
      expect(summary.registrationReferralLink(
              marketingHost: 'https://www.dukanest.com'),
          'https://www.dukanest.com/register?ref=shop-b');
      expect(summary.referralCount, 3);
      expect(summary.rewardedMonths, 2);
    });

    test('parseReferralSummaryFromPayload unwraps data envelope', () {
      final summary = parseReferralSummaryFromPayload({
        'success': true,
        'data': {
          'shareSubdomain': 'x',
          'referralLink': 'https://link.test/x',
        },
      });

      expect(summary?.shareSubdomain, 'x');
      expect(
        summary?.effectiveShareLink,
        'https://www.dukanest.com/register?ref=x',
      );
    });

    test('parses referredBySubdomain read-only field', () {
      final summary = ReferralSummary.fromJson({
        'shareSubdomain': 'mine',
        'referred_by_subdomain': 'friend-shop',
      });

      expect(summary.referredBySubdomain, 'friend-shop');
    });

    test('parseReferrerSubdomainInput accepts ref query and paths', () {
      expect(
        parseReferrerSubdomainInput(
          'https://www.dukanest.com/register?ref=janes-boutique',
        ),
        'janes-boutique',
      );
      expect(
        parseReferrerSubdomainInput('https://www.dukanest.com/ref/acme'),
        'acme',
      );
      expect(parseReferrerSubdomainInput('  acme-shop  '), 'acme-shop');
      expect(parseReferrerSubdomainInput('ab'), isNull);
      expect(parseReferrerSubdomainInput('bad slug!'), isNull);
    });

    test('overview referrals nested object', () {
      final summary = parseReferralSummaryFromPayload({
        'referrals': {
          'share_subdomain': 'nest',
          'referral_link': 'https://nest.test',
        },
      });

      expect(summary?.shareSubdomain, 'nest');
    });

    test('mergeReferralSummaries fills share subdomain from fallback', () {
      final merged = mergeReferralSummaries(
        const ReferralSummary(referralCount: 2),
        const ReferralSummary(shareSubdomain: 'my-shop'),
      );

      expect(merged?.shareSubdomain, 'my-shop');
      expect(merged?.referralCount, 2);
      expect(merged?.hasShareContent, isTrue);
    });
  });
}
