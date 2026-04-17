import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../onboarding/providers/auth_provider.dart';
import '../../../config/theme.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/providers/store_identity_provider.dart';
import '../../../core/widgets/dashboard_app_bar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final identityAsync = ref.watch(storeIdentityProvider);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'Store Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              identityAsync.when(
                data: (id) {
                  final name = id.name?.trim();
                  final initial = (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?';
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  );
                },
                loading: () => CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.35),
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
                error: (_, __) => CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary,
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: identityAsync.when(
                  data: (id) => Text(
                    (id.name != null && id.name!.trim().isNotEmpty) ? id.name!.trim() : 'Your store',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  loading: () => Text(
                    '…',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  error: (_, __) => Text(
                    'Settings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          identityAsync.when(
            data: (id) => _StoreHeroCard(
              theme: theme,
              storeName: id.name,
              storeUrl: id.storeUrl,
            ),
            loading: () => _StoreHeroCard(theme: theme),
            error: (_, __) => _StoreHeroCard(theme: theme),
          ),
          const SizedBox(height: 24),
          _CategoryHeader(title: 'General'),
          _SettingsCard(
            theme: theme,
            children: [
              _SettingsRow(
                theme: theme,
                icon: Icons.storefront_outlined,
                title: 'Store settings',
                subtitle: 'Name, logo, subdomain, address',
                onTap: () => context.push('/store-identity'),
              ),
              _rowDivider(theme),
              _SettingsRow(
                theme: theme,
                icon: Icons.refresh_rounded,
                title: 'Show refresh tips again',
                subtitle: 'Re-enable swipe-to-refresh helper tips',
                onTap: () async {
                  final storage = ref.read(tokenStorageProvider);
                  await storage.saveProductsListRefreshHintSeen(false);
                  await storage.saveProductDetailRefreshHintSeen(false);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refresh tips reset. They will appear again.')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          _CategoryHeader(title: 'Payments'),
          _SettingsCard(
            theme: theme,
            children: [
              _SettingsRow(
                theme: theme,
                icon: Icons.payments_outlined,
                title: 'Payments',
                subtitle: 'Cash on delivery and M-Pesa',
                onTap: () => context.push('/payment-settings'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _CategoryHeader(title: 'Operations'),
          _SettingsCard(
            theme: theme,
            children: [
              _SettingsRow(
                theme: theme,
                icon: Icons.local_shipping_outlined,
                title: 'Shipping & delivery',
                subtitle: 'Zones, fees, carriers, and pickup',
                onTap: () => context.push('/shipping-delivery'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _CategoryHeader(title: 'Taxes'),
          _SettingsCard(
            theme: theme,
            children: [
              _SettingsRow(
                theme: theme,
                icon: Icons.receipt_long_outlined,
                title: 'Taxes',
                subtitle: 'Tax rules, inclusive/exclusive',
                onTap: () => context.push('/tax-settings'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _CategoryHeader(title: 'Communications'),
          _SettingsCard(
            theme: theme,
            children: [
              _SettingsRow(
                theme: theme,
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                subtitle: 'Push preferences, Email alerts',
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  static Widget _rowDivider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 1,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
      indent: 68,
      endIndent: 16,
    );
  }
}

class _StoreHeroCard extends StatelessWidget {
  const _StoreHeroCard({required this.theme, this.storeName, this.storeUrl});

  final ThemeData theme;
  final String? storeName;
  final String? storeUrl;

  @override
  Widget build(BuildContext context) {
    final name = (storeName != null && storeName!.trim().isNotEmpty) ? storeName!.trim() : 'Your store';
    final url = (storeUrl != null && storeUrl!.trim().isNotEmpty) ? storeUrl!.trim() : '';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.primary],
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            child: Icon(Icons.storefront_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                if (url.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    url.replaceFirst(RegExp(r'^https?://'), ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.theme, required this.children});

  final ThemeData theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final ThemeData theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryDark, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
