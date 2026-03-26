import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';

/// More tab — body matches Stitch: Store Settings (e1ecf7951d11492c82adca2682445029).
/// Header row (avatar / title / notifications) and shell bottom bar are unchanged.
class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  static const _heroLogoUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBRwMWkY0HCGCFQgtE00RYDMi3igr5UEKhUQxc1GHEgFN2WR_gUG7iS_jLNgPfAgjRxT_m8JnRUnh2H_KnmemI-xsFvCrLFUwPLHjXh8pnYJYfpTF18z1kP0GzWqlUt7bUdN0k8EXzuoHZko_af4Baun8BRsXUCQ8frptpVpBJS745NXVhiVES76bptLAjXNJFY-k1iIpCj8IEuHPAAw9PEL3ENjMb8ileu5kExKLAoF7KG2xdleOPcKKeHrKR0v5iMnNiHxQA1ixtD';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary,
                child: const Text('BL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
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
                icon: Icon(Icons.notifications_none_rounded, color: theme.colorScheme.onSurfaceVariant),
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
          _DeveloperToolsCard(theme: theme, onTap: () => _demo(context, 'Developer Tools & API')),
          const SizedBox(height: 28),
          Text(
            'DukaNest v2.4.1 (Stable)',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'POWERED BY ARCHITECTURE DIGITAL',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 0.6,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  static void _demo(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label (demo)')));
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
    return Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35), indent: 68, endIndent: 16);
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C0528).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: Colors.white.withValues(alpha: 0.2),
                    child: CachedNetworkImage(
                      imageUrl: MoreMenuScreen._heroLogoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) => Icon(Icons.storefront_rounded, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
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
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.qr_code_2_rounded, color: Colors.white.withValues(alpha: 0.65), size: 28),
            onPressed: () => MoreMenuScreen._demo(context, 'Store QR'),
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
      elevation: 0,
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
                Icon(Icons.developer_mode_outlined, color: theme.colorScheme.onSurfaceVariant, size: 24),
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
                Icon(Icons.open_in_new_rounded, color: theme.colorScheme.onSurfaceVariant, size: 22),
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
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius));
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
