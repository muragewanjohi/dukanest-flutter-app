import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/referral_summary.dart';

/// Copy / share / open actions for referral links.
class ReferralActionsRow extends StatelessWidget {
  const ReferralActionsRow({
    super.key,
    required this.summary,
    this.storeDisplayName,
    this.compact = false,
  });

  final ReferralSummary summary;

  /// Store display name from profile; used for sharing during in-app registration.
  final String? storeDisplayName;
  final bool compact;

  String? get _subdomain => summary.shareSubdomain?.trim();

  /// Value shared during in-app registration (`Referral shop domain` field).
  String? get _storeNameToCopy {
    final sub = _subdomain;
    if (sub != null && sub.isNotEmpty) return sub;
    final name = storeDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final subdomain = _subdomain;
    final storeNameToCopy = _storeNameToCopy;
    final inviteLink =
        summary.registrationReferralLink() ?? summary.effectiveShareLink;

    if (inviteLink == null &&
        (subdomain == null || subdomain.isEmpty) &&
        storeNameToCopy == null) {
      return const SizedBox.shrink();
    }

    final shareText = _buildShareText(
      inviteLink: inviteLink,
      subdomain: subdomain,
      storeName: storeNameToCopy,
    );

    if (compact) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          if (storeNameToCopy != null)
            TextButton.icon(
              onPressed: () => _copy(
                context,
                storeNameToCopy,
                message: 'Store name copied',
              ),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Copy store name'),
            ),
          if (inviteLink != null)
            TextButton.icon(
              onPressed: () => _copy(context, inviteLink),
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Copy link'),
            ),
          TextButton.icon(
            onPressed: () => SharePlus.instance.share(ShareParams(text: shareText)),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share'),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (storeNameToCopy != null)
          FilledButton.tonalIcon(
            onPressed: () => _copy(
              context,
              storeNameToCopy,
              message: 'Store name copied',
            ),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Copy store name'),
          ),
        if (inviteLink != null) ...[
          FilledButton.tonalIcon(
            onPressed: () => _copy(context, inviteLink),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy link'),
          ),
          if (_isLaunchable(inviteLink))
            OutlinedButton.icon(
              onPressed: () => _open(inviteLink),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open'),
            ),
        ],
        OutlinedButton.icon(
          onPressed: () =>
              SharePlus.instance.share(ShareParams(text: shareText)),
          icon: const Icon(Icons.share_outlined, size: 18),
          label: const Text('Share'),
        ),
      ],
    );
  }

  static String _buildShareText({
    required String? inviteLink,
    required String? subdomain,
    required String? storeName,
  }) {
    if (inviteLink != null) {
      if (storeName != null && subdomain != null && storeName != subdomain) {
        return 'Join DukaNest — referred by $storeName. '
            'When registering in the app, enter "$subdomain" as the referral shop domain.\n'
            '$inviteLink';
      }
      if (storeName != null) {
        return 'Join DukaNest — referred by $storeName.\n$inviteLink';
      }
      return inviteLink;
    }
    if (subdomain != null) {
      return 'Join DukaNest — use referral shop domain: $subdomain';
    }
    return storeName != null
        ? 'Join DukaNest — referred by $storeName'
        : 'Join DukaNest';
  }

  static bool _isLaunchable(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> _copy(
    BuildContext context,
    String text, {
    String message = 'Referral link copied',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

String referralProgressLabel(ReferralSummary summary) {
  final parts = <String>[];
  final successful = summary.successfulReferrals ?? summary.referralCount;
  final target = summary.targetReferrals;
  if (successful != null) {
    if (target != null && target > 0) {
      parts.add('$successful / $target referrals');
    } else {
      parts.add('$successful referral${successful == 1 ? '' : 's'}');
    }
  }
  final rewarded = summary.rewardedMonths;
  if (rewarded != null && rewarded > 0) {
    parts.add('$rewarded free month${rewarded == 1 ? '' : 's'} earned');
  }
  if (parts.isEmpty) return 'Invite other merchants and earn subscription rewards.';
  return parts.join(' · ');
}
