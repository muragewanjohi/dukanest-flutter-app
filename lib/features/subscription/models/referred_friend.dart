import 'referral_summary.dart';

/// A store referred by the current merchant (`GET /dashboard/referrals`).
class ReferredFriend {
  const ReferredFriend({
    this.subdomain,
    this.storeName,
    this.status,
    this.createdAt,
    this.rewardedAt,
  });

  final String? subdomain;
  final String? storeName;
  final String? status;
  final DateTime? createdAt;
  final DateTime? rewardedAt;

  String get displayName {
    final name = storeName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final sub = subdomain?.trim();
    if (sub != null && sub.isNotEmpty) return sub;
    return 'Referred store';
  }

  factory ReferredFriend.fromJson(Map<String, dynamic> json) {
    return ReferredFriend(
      subdomain: _string(json, const [
        'subdomain',
        'shareSubdomain',
        'share_subdomain',
        'storeSubdomain',
        'store_subdomain',
      ]),
      storeName: _string(json, const [
        'storeName',
        'store_name',
        'name',
        'tenantName',
        'tenant_name',
      ]),
      status: _string(json, const [
        'status',
        'referralStatus',
        'referral_status',
        'state',
      ]),
      createdAt: _date(json, const [
        'createdAt',
        'created_at',
        'signedUpAt',
        'signed_up_at',
      ]),
      rewardedAt: _date(json, const [
        'rewardedAt',
        'rewarded_at',
        'completedAt',
        'completed_at',
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

  static DateTime? _date(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) {
        return DateTime.tryParse(v.trim());
      }
    }
    return null;
  }
}

List<ReferredFriend> parseReferredFriendsList(dynamic payload) {
  if (payload == null) return const [];

  dynamic raw = payload;
  if (payload is Map) {
    final map = Map<String, dynamic>.from(payload);
    for (final key in const [
      'referredFriends',
      'referred_friends',
      'friends',
      'referrals',
      'items',
      'list',
    ]) {
      final v = map[key];
      if (v is List) {
        raw = v;
        break;
      }
    }
    if (raw == payload) {
      final data = map['data'];
      if (data is Map) {
        return parseReferredFriendsList(data);
      }
    }
  }

  if (raw is! List) return const [];

  return raw
      .whereType<Map>()
      .map((e) => ReferredFriend.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// Parses summary counts plus referred friends from referrals API payload.
({ReferralSummary? summary, List<ReferredFriend> friends})
    parseReferralDashboardPayload(dynamic payload) {
  final summary = parseReferralSummaryFromPayload(payload);
  List<ReferredFriend> friends = const [];

  if (payload is Map) {
    final map = Map<String, dynamic>.from(payload);
    friends = parseReferredFriendsList(map);
    if (friends.isEmpty) {
      final data = map['data'];
      if (data is Map) {
        friends = parseReferredFriendsList(Map<String, dynamic>.from(data));
      }
    }
  }

  return (summary: summary, friends: friends);
}
