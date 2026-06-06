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
    this.compact = false,
  });

  final ReferralSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final subdomain = summary.shareSubdomain?.trim();
    final inviteLink =
        summary.registrationReferralLink() ?? summary.effectiveShareLink;

    if (inviteLink == null && (subdomain == null || subdomain.isEmpty)) {
      return const SizedBox.shrink();
    }

    final shareText = inviteLink ??
        (subdomain != null
            ? 'Join DukaNest — use referral code: $subdomain'
            : 'Join DukaNest');

    if (compact) {
      return Row(
        children: [
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

  static bool _isLaunchable(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral link copied')),
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
