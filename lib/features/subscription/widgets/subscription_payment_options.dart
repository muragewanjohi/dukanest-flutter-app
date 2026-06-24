import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';

/// M-Pesa + PesaPal actions shown below the current plan card.
class SubscriptionPaymentOptions extends StatelessWidget {
  const SubscriptionPaymentOptions({
    super.key,
    required this.billingCycle,
    required this.onMpesa,
    required this.onPesapal,
    this.mpesaEnabled = true,
    this.busy = false,
  });

  final String billingCycle;
  final VoidCallback onMpesa;
  final VoidCallback onPesapal;
  final bool mpesaEnabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mpesaAvailable = mpesaEnabled && billingCycle == 'monthly';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Payment',
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppTheme.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (!mpesaAvailable && billingCycle == 'yearly')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Yearly billing is available via PesaPal.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: busy || !mpesaAvailable ? null : onMpesa,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.mpesaGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppTheme.mpesaGreen.withValues(alpha: 0.45),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('M-Pesa'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onPesapal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryDark,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('PesaPal'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Pay now to renew or upgrade your subscription.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppTheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
