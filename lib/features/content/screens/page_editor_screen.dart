import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';

/// Page Editor (home & storefront sections) — Stitch: Page Editor (Full Mobile)
/// (193cf9f46f214b38ab8e5ca84d6a5192). No duplicate tab bar; bottom bar is in-screen actions only.
class PageEditorScreen extends StatefulWidget {
  const PageEditorScreen({super.key, required this.pageSlug});

  final String pageSlug;

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _SectionItem {
  _SectionItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;
  bool enabled = true;
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  late final List<_SectionItem> _sections;

  @override
  void initState() {
    super.initState();
    _sections = [
      _SectionItem(emoji: '🎯', title: 'Hero #1', subtitle: 'Step into Style: Elevate...'),
      _SectionItem(emoji: '📁', title: 'Categories #2', subtitle: '8 categories'),
      _SectionItem(emoji: '🎨', title: 'Banners #3', subtitle: '3 banners'),
      _SectionItem(emoji: '⚡', title: 'Sales Tab #4', subtitle: 'Super Flash Sale'),
      _SectionItem(emoji: '✨', title: 'Features #5', subtitle: '6 features'),
      _SectionItem(emoji: '🛍️', title: 'Product Tabs #6', subtitle: '3 tabs'),
      _SectionItem(emoji: '🌓', title: 'Split Layout #7', subtitle: '50-50'),
      _SectionItem(emoji: '📰', title: 'Blogs #8', subtitle: '6 posts'),
      _SectionItem(emoji: '📢', title: 'CTA #9', subtitle: 'Continue Your Shopping'),
    ];
  }

  String get _headline {
    if (widget.pageSlug == 'home') return 'Home Page Design';
    final parts = widget.pageSlug.split('-').where((e) => e.isNotEmpty);
    if (parts.isEmpty) return 'Page Design';
    return '${parts.map((p) => p[0].toUpperCase() + p.substring(1)).join(' ')} Page Design';
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppTheme.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Page Editor'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: theme.colorScheme.primary),
            onPressed: () => _toast('Page settings (demo)'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.12)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + bottomInset + 72),
              children: [
                Text(
                  'STOREFRONT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _headline,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Curate your customer experience by managing page components.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                ...List.generate(_sections.length, (i) => _sectionTile(context, theme, i)),
                const SizedBox(height: 20),
                _AddSectionCard(theme: theme, onTap: () => _toast('Add section (demo)')),
                const SizedBox(height: 28),
                _SeoExpansionCard(
                  theme: theme,
                  title: 'SEO Settings',
                  subtitle: 'Meta tags for search engine optimization',
                ),
                const SizedBox(height: 10),
                _SeoExpansionCard(
                  theme: theme,
                  title: 'SEO Preview',
                  subtitle: 'How your page will appear in search engine results',
                ),
              ],
            ),
          ),
          _BottomActionBar(
            bottomPadding: bottomInset,
            onPreview: () => _toast('Preview (demo)'),
            onSaveDraft: () => _toast('Draft saved (demo)'),
            onPublish: () => _toast('Page published (demo)'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTile(BuildContext context, ThemeData theme, int i) {
    final s = _sections[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        elevation: 0,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: i == 0 ? () => context.push('/hero-section/edit') : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
            children: [
              Icon(Icons.drag_indicator_rounded, color: theme.colorScheme.outline, size: 22),
              const SizedBox(width: 8),
              Text(s.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.82,
                child: Switch(
                  value: s.enabled,
                  onChanged: (v) => setState(() => s.enabled = v),
                  activeTrackColor: theme.colorScheme.primary,
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant, size: 22),
                onPressed: () {
                  if (i == 0) {
                    context.push('/hero-section/edit');
                  } else {
                    _toast('Edit ${s.title} (demo)');
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _AddSectionCard extends StatelessWidget {
  const _AddSectionCard({required this.theme, required this.onTap});

  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          foregroundPainter: _DashedRectPainter(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            strokeWidth: 2,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add New Section',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
      const Radius.circular(12),
    );
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      double len = 0;
      while (len < metric.length) {
        final double end = (len + 6).clamp(0.0, metric.length);
        final extract = metric.extractPath(len, end);
        canvas.drawPath(extract, paint);
        len += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class _SeoExpansionCard extends StatelessWidget {
  const _SeoExpansionCard({
    required this.theme,
    required this.title,
    required this.subtitle,
  });

  final ThemeData theme;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
          ),
          title: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Text(
              'Configure in a future build.',
              style: GoogleFonts.inter(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.bottomPadding,
    required this.onPreview,
    required this.onSaveDraft,
    required this.onPublish,
  });

  final double bottomPadding;
  final VoidCallback onPreview;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (bottomPadding > 0 ? 0 : 8)),
          child: Row(
            children: [
              Expanded(
                child: _barButton(
                  theme,
                  label: 'Preview',
                  filled: false,
                  onPressed: onPreview,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _barButton(
                  theme,
                  label: 'Save Draft',
                  filled: false,
                  onPressed: onSaveDraft,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _barButton(
                  theme,
                  label: 'Publish Page',
                  filled: true,
                  onPressed: onPublish,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barButton(
    ThemeData theme, {
    required String label,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    final style = GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800);
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
        ),
        child: Text(label, style: style),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: style),
    );
  }
}
