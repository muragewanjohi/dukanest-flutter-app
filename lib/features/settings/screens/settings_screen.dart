import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../onboarding/providers/auth_provider.dart';
import '../../../config/theme.dart';
import '../../../core/auth/token_storage.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Store Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary,
                child: const Text(
                  'BL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Tenant Dashboard',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
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
          _StoreHeroCard(theme: theme),
          const SizedBox(height: 24),
          _CategoryHeader(title: 'General'),
          _SettingsCard(
            theme: theme,
            children: [
              _SettingsRow(
                theme: theme,
                icon: Icons.storefront_outlined,
                title: 'Store Identity',
                subtitle: 'Name, logo, and subdomain',
                onTap: () => context.push('/store-identity'),
              ),
              _rowDivider(theme),
              _SettingsRow(
                theme: theme,
                icon: Icons.currency_exchange_rounded,
                title: 'Currency',
                subtitle: 'Set your primary store currency',
                onTap: () => _demo(context, 'Currency'),
              ),
              _rowDivider(theme),
              _SettingsRow(
                theme: theme,
                icon: Icons.public_outlined,
                title: 'Country',
                subtitle: 'Set your business country or region',
                onTap: () => _demo(context, 'Country'),
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
                subtitle: 'M-Pesa, PesaPal, Bank Transfer',
                trailing: _activePill(theme),
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
              _rowDivider(theme),
              _SettingsRow(
                theme: theme,
                icon: Icons.support_agent_outlined,
                title: 'Support',
                subtitle: 'Help center, Ticket history',
                onTap: () => _demo(context, 'Support'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _DeveloperToolsCard(
            theme: theme,
            onTap: () => _demo(context, 'Developer Tools & API'),
          ),
          const SizedBox(height: 24),
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

  static void _demo(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label (demo)')),
    );
  }

  static Widget _activePill(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ACTIVE',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF047857),
        ),
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
  const _StoreHeroCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
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
                  'DukaNest Premium',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'dukanest.com/mystore',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.qr_code_2_rounded,
              color: Colors.white.withValues(alpha: 0.65),
              size: 28,
            ),
            onPressed: () => SettingsScreen._demo(context, 'Store QR'),
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
    this.trailing,
  });

  final ThemeData theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

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
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeveloperToolsCard extends StatelessWidget {
  const _DeveloperToolsCard({required this.theme, required this.onTap});

  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        radius: 14,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Icon(
                  Icons.developer_mode_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Developer Tools & API',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var len = 0.0;
      while (len < metric.length) {
        final end = (len + 5).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(len, end), paint);
        len += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
