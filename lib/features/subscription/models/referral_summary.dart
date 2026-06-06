import '../../../config/app_config.dart';

export '../../../core/util/referrer_subdomain.dart' show parseReferrerSubdomainInput;

/// Parsed from `GET /dashboard/referrals` or `GET /dashboard/overview` → `referrals`.
class ReferralSummary {
  const ReferralSummary({
    this.shareSubdomain,
    this.referralLink,
    this.referralCount,
    this.successfulReferrals,
    this.rewardedMonths,
    this.targetReferrals,
    this.monthsPerReward,
    this.referredBySubdomain,
  });

  final String? shareSubdomain;
  final String? referralLink;
  final int? referralCount;
  final int? successfulReferrals;
  final int? rewardedMonths;
  final int? targetReferrals;
  final int? monthsPerReward;

  /// Who referred this store (read-only; set at signup on the server).
  final String? referredBySubdomain;

  /// Signup invite link (`/register?ref=`); falls back to server `referralLink`.
  String? get effectiveShareLink {
    final built = registrationReferralLink();
    if (built != null) return built;
    final link = referralLink?.trim();
    if (link != null && link.isNotEmpty) return link;
    return null;
  }

  /// Share link for inviting new merchants (same as web).
  String? registrationReferralLink({
    String marketingHost = AppConfig.publicApiBaseUrl,
  }) {
    final sub = shareSubdomain?.trim();
    if (sub == null || sub.isEmpty) return null;
    final base = marketingHost.endsWith('/')
        ? marketingHost.substring(0, marketingHost.length - 1)
        : marketingHost;
    return '$base/register?ref=$sub';
  }

  bool get hasShareContent =>
      (effectiveShareLink != null && effectiveShareLink!.isNotEmpty) ||
      (shareSubdomain != null && shareSubdomain!.trim().isNotEmpty);

  static ReferralSummary? tryParse(dynamic raw) {
    if (raw == null) return null;
    Map<String, dynamic>? map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else {
      return null;
    }
    final nested = map['referrals'] ?? map['referral'];
    if (nested is Map) {
      map = Map<String, dynamic>.from(nested);
    }
    final referrals = map['data'];
    if (referrals is Map) {
      map = Map<String, dynamic>.from(referrals);
    }
    return ReferralSummary.fromJson(map);
  }

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    return ReferralSummary(
      shareSubdomain: _string(json, const [
        'shareSubdomain',
        'share_subdomain',
        'subdomain',
        'referralSubdomain',
        'referral_subdomain',
      ]),
      referralLink: _string(json, const [
        'referralLink',
        'referral_link',
        'link',
        'shareLink',
        'share_link',
        'url',
      ]),
      referralCount: _int(json, const [
        'referralCount',
        'referral_count',
        'totalReferrals',
        'total_referrals',
        'count',
      ]),
      successfulReferrals: _int(json, const [
        'successfulReferrals',
        'successful_referrals',
        'completedReferrals',
        'completed_referrals',
        'successfulCount',
        'successful_count',
      ]),
      rewardedMonths: _int(json, const [
        'rewardedMonths',
        'rewarded_months',
        'bonusMonths',
        'bonus_months',
        'monthsRewarded',
        'months_rewarded',
      ]),
      targetReferrals: _int(json, const [
        'targetReferrals',
        'target_referrals',
        'referralsRequired',
        'referrals_required',
        'goal',
      ]),
      monthsPerReward: _int(json, const [
        'monthsPerReward',
        'months_per_reward',
        'rewardMonths',
        'reward_months',
      ]),
      referredBySubdomain: _string(json, const [
        'referredBySubdomain',
        'referred_by_subdomain',
        'referrerSubdomain',
        'referrer_subdomain',
        'referredBy',
        'referred_by',
      ]),
    );
  }

  static String? _string(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static int? _int(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v == null) continue;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
    }
    return null;
  }
}

/// Unwraps API envelopes and parses a [ReferralSummary].
ReferralSummary? parseReferralSummaryFromPayload(dynamic payload) {
  if (payload == null) return null;
  if (payload is! Map) return ReferralSummary.tryParse(payload);

  final outer = Map<String, dynamic>.from(payload);
  final direct = ReferralSummary.tryParse(outer);
  if (direct != null && direct.hasShareContent) return direct;

  final inner = outer['data'];
  if (inner is Map) {
    final fromInner = ReferralSummary.tryParse(Map<String, dynamic>.from(inner));
    if (fromInner != null) return fromInner;
  }

  final referral = outer['referral'] ?? outer['referrals'];
  if (referral is Map) {
    return ReferralSummary.tryParse(Map<String, dynamic>.from(referral));
  }

  return direct;
}

/// Combines referral fields, preferring [primary] counts/links when present.
ReferralSummary? mergeReferralSummaries(
  ReferralSummary? primary,
  ReferralSummary? secondary,
) {
  if (primary == null) return secondary;
  if (secondary == null) return primary;
  return ReferralSummary(
    shareSubdomain: primary.shareSubdomain ?? secondary.shareSubdomain,
    referralLink: primary.referralLink ?? secondary.referralLink,
    referralCount: primary.referralCount ?? secondary.referralCount,
    successfulReferrals:
        primary.successfulReferrals ?? secondary.successfulReferrals,
    rewardedMonths: primary.rewardedMonths ?? secondary.rewardedMonths,
    targetReferrals: primary.targetReferrals ?? secondary.targetReferrals,
    monthsPerReward: primary.monthsPerReward ?? secondary.monthsPerReward,
    referredBySubdomain:
        primary.referredBySubdomain ?? secondary.referredBySubdomain,
  );
}
