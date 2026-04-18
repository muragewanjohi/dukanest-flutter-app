import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../../core/widgets/form_error_highlight.dart';

/// Edit Hero Section — Stitch: Edit Hero Section (Mobile) (438af177a59b4d84b3285b46a0c5f086).
class HeroSectionEditorScreen extends StatefulWidget {
  const HeroSectionEditorScreen({super.key});

  static const heroImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDp-A7bu-EjfbFTByoKIMteH0Ro5ZeMuMnZgCLrjKsSHMC4tOpPnnODjm3hk2_4Je6lzwwj9YTkRt_9JqvXSdJVNxe8AD3w_dOhSsw534abfaZsxcR0u_6hTo0jGge5B2QSc34D14WcrtODOD4hRj_sXLPNU4TrNPDguvIkTSWPWNyB4I04hhGkXhSzQaMF6WUnoJDhAvBDUD9kq2aPu-5zT3KT4H_qNnjQw5q6ga9tTzcn5I2zB6UpmEq1WBeRfDDnxCvO021lQVgC';

  @override
  State<HeroSectionEditorScreen> createState() => _HeroSectionEditorScreenState();
}

class _HeroSectionEditorScreenState extends State<HeroSectionEditorScreen>
    with FormErrorHighlightMixin {
  final _title = TextEditingController(text: 'Step into Style...');
  final _subtitle = TextEditingController();
  final _description = TextEditingController();
  final _bgHex = TextEditingController(text: '#F5F5F5');
  final _ctaText = TextEditingController(text: 'Shop The Collection Now');
  final _ctaLink = TextEditingController(text: '/products');

  String _textAlign = 'Center';
  String _imagePosition = 'Right';
  int _bgSegment = 1;
  bool _cropImage = false;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _description.dispose();
    _bgHex.dispose();
    _ctaText.dispose();
    _ctaLink.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      reportFieldError(
        fieldId: 'title',
        message: 'Hero title is required.',
      );
      return;
    }
    if (_ctaText.text.trim().isEmpty) {
      reportFieldError(
        fieldId: 'ctaText',
        message: 'Call-to-action button text is required.',
      );
      return;
    }
    if (_ctaLink.text.trim().isEmpty) {
      reportFieldError(
        fieldId: 'ctaLink',
        message: 'Call-to-action button link is required.',
      );
      return;
    }
    clearAllFieldErrors();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hero section saved (demo)')),
    );
    context.pop();
  }

  InputDecoration _inputDeco(ThemeData theme, {bool isInvalid = false}) {
    final errorColor = theme.colorScheme.error;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: isInvalid
          ? BorderSide(color: errorColor, width: 1.5)
          : BorderSide.none,
    );
    return InputDecoration(
      filled: true,
      fillColor: isInvalid
          ? errorColor.withValues(alpha: 0.06)
          : theme.colorScheme.surfaceContainerLowest,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isInvalid ? errorColor : theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _sectionTitleRow(ThemeData theme, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppTheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Edit Hero Section',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF001790), Color(0xFF0025CC)],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _save,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      'Save',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            'Edit Hero Section',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: AppTheme.primaryDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure your hero banner content and appearance',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitleRow(theme, Icons.edit_note_rounded, 'CONTENT'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.ghostBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Title'),
                const SizedBox(height: 8),
                KeyedSubtree(
                  key: keyFor('title'),
                  child: TextField(
                    controller: _title,
                    onChanged: (_) => clearFieldError('title'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
                    decoration: _inputDeco(
                      theme,
                      isInvalid: isFieldInvalid('title'),
                    ).copyWith(hintText: 'Hero Title'),
                  ),
                ),
                const SizedBox(height: 18),
                _fieldLabel('Subtitle'),
                const SizedBox(height: 8),
                TextField(
                  controller: _subtitle,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: _inputDeco(theme).copyWith(hintText: 'Sub-heading text'),
                ),
                const SizedBox(height: 18),
                _fieldLabel('Description'),
                const SizedBox(height: 8),
                TextField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 5,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: _inputDeco(theme).copyWith(hintText: 'Detailed brand story...'),
                ),
                const SizedBox(height: 18),
                _fieldLabel('Text Alignment'),
                const SizedBox(height: 8),
                _dropdown<String>(
                  theme,
                  value: _textAlign,
                  items: const ['Left', 'Center', 'Right'],
                  onChanged: (v) => setState(() => _textAlign = v ?? 'Center'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitleRow(theme, Icons.palette_outlined, 'IMAGE & BACKGROUND'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.ghostBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Background Type'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: _segmentChip(
                            theme,
                            labels: const ['None', 'Color', 'Image'],
                            index: i,
                            selected: _bgSegment == i,
                            onTap: () => setState(() => _bgSegment = i),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(child: _fieldLabel('Background Color')),
                    TextButton(
                      onPressed: () => setState(() => _bgHex.text = '#F5F5F5'),
                      child: Text(
                        'RESET',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _bgHex,
                          style: GoogleFonts.robotoMono(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _fieldLabel('Foreground Image'),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: HeroSectionEditorScreen.heroImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => ColoredBox(color: theme.colorScheme.surfaceContainerLowest),
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: theme.colorScheme.surfaceContainerLowest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryDark.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Column(
                            children: [
                              _roundImageAction(
                                icon: Icons.edit_outlined,
                                color: theme.colorScheme.primary,
                                bg: Colors.white.withValues(alpha: 0.92),
                                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Replace image (demo)')),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _roundImageAction(
                                icon: Icons.delete_outline_rounded,
                                color: theme.colorScheme.error,
                                bg: theme.colorScheme.errorContainer.withValues(alpha: 0.95),
                                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Remove image (demo)')),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _cropImage,
                        onChanged: (v) => setState(() => _cropImage = v ?? false),
                        activeColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Crop image to fit container',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _fieldLabel('Image Position'),
                const SizedBox(height: 8),
                _dropdown<String>(
                  theme,
                  value: _imagePosition,
                  items: const ['Left', 'Center', 'Right'],
                  onChanged: (v) => setState(() => _imagePosition = v ?? 'Right'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitleRow(theme, Icons.touch_app_outlined, 'CALL TO ACTION'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.ghostBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Button Text'),
                const SizedBox(height: 8),
                KeyedSubtree(
                  key: keyFor('ctaText'),
                  child: TextField(
                    controller: _ctaText,
                    onChanged: (_) => clearFieldError('ctaText'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
                    decoration: _inputDeco(
                      theme,
                      isInvalid: isFieldInvalid('ctaText'),
                    ).copyWith(hintText: 'CTA Label'),
                  ),
                ),
                const SizedBox(height: 18),
                _fieldLabel('Button Link'),
                const SizedBox(height: 8),
                KeyedSubtree(
                  key: keyFor('ctaLink'),
                  child: TextField(
                    controller: _ctaLink,
                    onChanged: (_) => clearFieldError('ctaLink'),
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: _inputDeco(
                      theme,
                      isInvalid: isFieldInvalid('ctaLink'),
                    ).copyWith(
                      hintText: 'e.g. /shop',
                      prefixIcon: Icon(Icons.link, color: theme.colorScheme.outline, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 64,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentChip(
    ThemeData theme, {
    required List<String> labels,
    required int index,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            labels[index],
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundImageAction({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _dropdown<T>(
    ThemeData theme, {
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text('$e', style: GoogleFonts.inter(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
