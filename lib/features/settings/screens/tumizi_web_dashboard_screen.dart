import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/providers/store_identity_provider.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../tumizi_dashboard_url.dart';

/// Opens the tenant **web** Tumizi dashboard (session cookies on the store host).
///
/// General information, merchant edit, withdrawals, and refunds live there —
/// they are **not** separate Material tabs in the Flutter admin app (see
/// `docs/backend-context/tumizi/TUMIZI_MOBILE_AND_SETTINGS.md`).
class TumiziWebDashboardScreen extends ConsumerWidget {
  const TumiziWebDashboardScreen({super.key});

  Future<void> _openInBrowser(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw StateError('Could not open browser');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncId = ref.watch(storeIdentityProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'Tumizi (web)'),
      body: asyncId.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (identity) {
          final uri = buildTumiziWebDashboardUri(
            storeUrl: identity.storeUrl,
            subdomain: identity.subdomain,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Text(
                'Wallet, withdrawals & refunds',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'On the web dashboard, Tumizi is split into areas such as general merchant information, '
                'editing profile or wallet details, withdrawals, and refunds. '
                'Those screens use tenant session APIs (/api/tumizi/…) and are not '
                'implemented as separate tabs inside this mobile admin app.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'What you already do here',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use Payments in this app only to choose whether the storefront may offer Tumizi '
                'and the default checkout method (PATCH /api/v1/mobile/dashboard/settings).',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              if (uri == null)
                Text(
                  'Store URL is not available yet. Set your store domain in Store identity, then try again.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: theme.colorScheme.error,
                    height: 1.4,
                  ),
                )
              else ...[
                SelectableText(
                  uri.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      await _openInBrowser(uri);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open link: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open Tumizi dashboard in browser'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: uri.toString()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy link'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Sign in on the website with the same store account if prompted. '
                'An in-app WebView can be added later if you need embedded session UX.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.4,
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ],
          );
        },
      ),
    );
  }
}
