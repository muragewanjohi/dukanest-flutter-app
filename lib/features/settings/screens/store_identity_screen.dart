import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';

/// Store Identity — Stitch: Store Identity (Refined) (e00fbf7d264a41b28406065a10d940de).
/// Includes delete-account panel per product spec.
class StoreIdentityScreen extends StatefulWidget {
  const StoreIdentityScreen({super.key});

  static const _keFlagUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuC2aTS8N0I0XazxD9RUrUxD3-5GEOmtvQnsyp1j9rktHX8Ux8DXjc5WevFm83W2PLJmsPXGukkAIbqGONp0BeQni0EgjGdqppFCxQsiV8OUkJzDFgSfTl1qJBMUd1clEtAil3hb_-UM19MCqB9pmr5a3o7Xsm8-d8of9Wj6H9Np3arrOhs9RHWSKvIiJwtNxe2WG-6GonPCqxCKCDkD_ptXtX3aoR1UB2cg5dGoEnmt447ybDF47DCQKfBTbzisUZmdQ9eORQDMUo5e';

  @override
  State<StoreIdentityScreen> createState() => _StoreIdentityScreenState();
}

class _StoreIdentityScreenState extends State<StoreIdentityScreen> {
  final _storeName = TextEditingController();
  final _domain = TextEditingController();
  final _phoneLocal = TextEditingController();
  final _address1 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _country = TextEditingController();
  final _postal = TextEditingController();
  final _supportEmail = TextEditingController();
  final _description = TextEditingController();

  String _businessType = 'Retail';
  String _sellingCategory = 'Electronics & Gadgets';

  @override
  void dispose() {
    _storeName.dispose();
    _domain.dispose();
    _phoneLocal.dispose();
    _address1.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    _postal.dispose();
    _supportEmail.dispose();
    _description.dispose();
    super.dispose();
  }

  InputDecoration _fieldDeco(ThemeData theme, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes saved (demo)')),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This will sign you out, disable your store, and schedule hard deletion after the retention period.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion requested (demo)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Store Identity',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _SectionCard(
            theme: theme,
            icon: Icons.storefront_outlined,
            title: 'Store Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(theme, 'Store Name'),
                TextField(
                  controller: _storeName,
                  decoration: _fieldDeco(theme, hint: 'e.g. Acme Electronics'),
                ),
                const SizedBox(height: 16),
                _label(theme, 'Store Domain'),
                TextField(
                  controller: _domain,
                  decoration: _fieldDeco(theme, hint: 'acme-store').copyWith(
                    suffixText: '.dukanest.com',
                    suffixStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _label(theme, 'Phone Number'),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
                        backgroundColor: theme.colorScheme.surfaceContainer,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(
                              width: 24,
                              height: 16,
                              child: CachedNetworkImage(
                                imageUrl: StoreIdentityScreen._keFlagUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Text('🇰🇪', style: TextStyle(fontSize: 14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('+254', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                          Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurfaceVariant, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneLocal,
                        keyboardType: TextInputType.phone,
                        decoration: _fieldDeco(theme, hint: '712 345 678'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _SectionCard(
            theme: theme,
            icon: Icons.branding_watermark_outlined,
            title: 'Store Logo',
            child: Material(
              color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logo upload (demo)')),
                ),
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _DashedRectPainter(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    radius: 16,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(Icons.upload_file_rounded, color: theme.colorScheme.primary, size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Upload Store Logo',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PNG, JPG up to 5MB (512x512px)',
                          style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _SectionCard(
            theme: theme,
            icon: Icons.category_outlined,
            title: 'Business Category',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(theme, 'Business Type'),
                _dropdown(theme, value: _businessType, items: const [
                  'Retail',
                  'Wholesale',
                  'Service Provider',
                  'Digital Goods',
                ], onChanged: (v) => setState(() => _businessType = v ?? 'Retail')),
                const SizedBox(height: 16),
                _label(theme, 'What are you selling?'),
                _dropdown(theme, value: _sellingCategory, items: const [
                  'Electronics & Gadgets',
                  'Fashion & Apparel',
                  'Home & Living',
                  'Food & Beverages',
                ], onChanged: (v) => setState(() => _sellingCategory = v ?? 'Electronics & Gadgets')),
              ],
            ),
          ),
          _SectionCard(
            theme: theme,
            icon: Icons.description_outlined,
            title: 'Store Description',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _description,
                  minLines: 5,
                  maxLines: 8,
                  decoration: _fieldDeco(theme, hint: 'Tell your customers what makes your store unique...'),
                ),
                const SizedBox(height: 8),
                Text(
                  'PROFESSIONAL TIP: KEEP IT CONCISE AND CUSTOMER-FOCUSED.',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          _SectionCard(
            theme: theme,
            icon: Icons.location_on_outlined,
            title: 'Physical Address',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(theme, 'Address Line 1'),
                TextField(
                  controller: _address1,
                  decoration: _fieldDeco(theme, hint: 'Street, Building, Suite'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'City'),
                          TextField(
                            controller: _city,
                            decoration: _fieldDeco(theme, hint: 'Nairobi'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'State/Province'),
                          TextField(
                            controller: _state,
                            decoration: _fieldDeco(theme, hint: 'Nairobi'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'Country'),
                          TextField(
                            controller: _country,
                            decoration: _fieldDeco(theme, hint: 'Kenya'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(theme, 'Postal Code'),
                          TextField(
                            controller: _postal,
                            decoration: _fieldDeco(theme, hint: '00100'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _SectionCard(
            theme: theme,
            icon: Icons.support_agent_outlined,
            title: 'Contact & Support',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(theme, 'Support Email'),
                TextField(
                  controller: _supportEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDeco(theme, hint: 'support@yourstore.com').copyWith(
                    prefixIcon: Icon(Icons.mail_outline_rounded, color: theme.colorScheme.onSurfaceVariant, size: 22),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Used for order confirmations and customer inquiries.',
                  style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _DeleteAccountSection(onDeletePressed: _confirmDeleteAccount),
        ],
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        color: AppTheme.surface.withValues(alpha: 0.92),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
              label: Text('Save Changes', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _dropdown(
    ThemeData theme, {
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.unfold_more_rounded, color: theme.colorScheme.onSurfaceVariant),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.inter(fontSize: 14))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.theme,
    required this.icon,
    required this.title,
    required this.child,
  });

  final ThemeData theme;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountSection extends StatelessWidget {
  const _DeleteAccountSection({required this.onDeletePressed});

  final VoidCallback onDeletePressed;

  static const _cardBg = Color(0xFFFFF5F5);
  static const _border = Color(0xFFFFCDD2);
  static const _titleRed = Color(0xFFB71C1C);
  static const _buttonRed = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: _titleRed, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete Account',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _titleRed,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Permanently close your store. Your storefront and dashboard access will be disabled immediately. Store data is retained for up to 90 days before permanent deletion.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.45,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border.withValues(alpha: 0.9)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: _titleRed, shape: BoxShape.circle),
                  child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This action is serious',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _titleRed,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deleting your account will sign you out, disable your store, and schedule hard deletion after the retention period. If you change your mind, contact support before the retention period expires.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.45,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onDeletePressed,
              style: FilledButton.styleFrom(
                backgroundColor: _buttonRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(
                'Delete my account',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), Radius.circular(radius));
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      var len = 0.0;
      while (len < metric.length) {
        final end = (len + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(len, end), paint);
        len += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
