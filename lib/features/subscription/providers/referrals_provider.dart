import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers/store_identity_provider.dart';
import '../../dashboard/providers/dashboard_overview_provider.dart';
import '../models/referral_summary.dart';
import '../models/referred_friend.dart';

/// Mobile `GET /dashboard/referrals` — referral subdomain, counts, friends list.
final dashboardReferralsProvider =
    FutureProvider.autoDispose<ReferralDashboard>((ref) async {
  final api = ref.watch(apiClientProvider);
  ReferralSummary? summary;
  List<ReferredFriend> friends = const [];

  final response = await api.getDashboardReferrals();
  if (!response.success) {
    throw StateError(
      response.error?.message ??
          'Could not load referral program. Please try again.',
    );
  }
  if (response.data != null) {
    final parsed = parseReferralDashboardPayload(response.data);
    summary = parsed.summary;
    friends = parsed.friends;
  }

  summary = await _resolveReferralSummary(ref, summary);

  return ReferralDashboard(
    summary: summary,
    referredFriends: friends,
  );
});

Future<ReferralSummary?> _resolveReferralSummary(
  Ref ref,
  ReferralSummary? fromReferralsApi,
) async {
  var summary = fromReferralsApi;
  if (summary != null && summary.hasShareContent) return summary;

  try {
    final overview = await ref.read(dashboardOverviewProvider.future);
    final fromOverview =
        parseReferralSummaryFromPayload(overview?['referrals']);
    summary = mergeReferralSummaries(summary, fromOverview);
    if (summary != null && summary.hasShareContent) return summary;
  } catch (_) {}

  try {
    final identity = await ref.read(storeIdentityProvider.future);
    final sub = identity.subdomain?.trim();
    if (sub != null && sub.isNotEmpty) {
      summary = mergeReferralSummaries(
        summary,
        ReferralSummary(shareSubdomain: sub),
      );
    }
  } catch (_) {}

  return summary;
}

/// Referral summary plus optional referred stores list.
class ReferralDashboard {
  const ReferralDashboard({
    required this.summary,
    required this.referredFriends,
  });

  final ReferralSummary? summary;
  final List<ReferredFriend> referredFriends;
}
