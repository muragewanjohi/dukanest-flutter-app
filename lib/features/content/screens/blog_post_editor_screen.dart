import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../../core/widgets/form_error_highlight.dart';

/// Edit / create blog post — Stitch: Edit Blog Post (Refined) (518f2f427af54eb38a97196c5dd1a986).
/// Full-screen route: no duplicate bottom nav (Stitch mock nav omitted in app).
class BlogPostEditorScreen extends StatefulWidget {
  const BlogPostEditorScreen({super.key, this.postId});

  /// When null, screen is "new post" mode (empty fields, no delete).
  final String? postId;

  @override
  State<BlogPostEditorScreen> createState() => _BlogPostEditorScreenState();
}

class _BlogPostEditorScreenState extends State<BlogPostEditorScreen>
    with FormErrorHighlightMixin {
  static const _featuredImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCIrd3l2JengENcu3661cT8M8paT4CLmmCZQyFx6nOD9vOzT2r00FEXBuyqTgI5J2Ncn1xEr2spbOAFRIMnQ-qXbWCU_55LQXmEhwwaXDbanaU6rbljzRd1rMXv2lKJoQevKPFyEtuH2MG_qFqGsx1bX3dR3S978mArlTc0LGPcr6SJUzhENEnpqpR6i5dwR5DE-v3F9BifYth4gkGPZdXghRmOTlZYALj_v910AhZBhMYXu_aZZyt8bX4dcYkDU9Y7wAiyiGajJQmz';

  static const _categories = [
    'Style Tips',
    'Guides',
    'Company News',
    'Productivity',
  ];

  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _excerpt;
  late int _categoryIndex;
  late bool _published;
  String? _imageUrl;

  bool get _isEditing => widget.postId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _title = TextEditingController(text: '10 Minimalist Design Trends for 2024');
      _body = TextEditingController(
        text:
            'In the ever-evolving landscape of digital commerce, minimalism remains a pillar of clarity and conversion. As we look toward 2024, the "less is more" philosophy is being refined through tactile textures and intentional white space...',
      );
      _excerpt = TextEditingController(
        text:
            'Explore the upcoming design shifts that prioritize user focus and brand authenticity in the digital space.',
      );
      _categoryIndex = 0;
      _published = true;
      _imageUrl = _featuredImageUrl;
    } else {
      _title = TextEditingController();
      _body = TextEditingController();
      _excerpt = TextEditingController();
      _categoryIndex = 0;
      _published = false;
      _imageUrl = _featuredImageUrl;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _excerpt.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('This removes the blog post from your workspace (demo).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) context.pop();
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      reportFieldError(
        fieldId: 'title',
        message: 'Post title is required.',
      );
      return;
    }
    if (_body.text.trim().isEmpty) {
      reportFieldError(
        fieldId: 'body',
        message: 'Add some content for the post.',
      );
      return;
    }
    clearAllFieldErrors();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post saved (demo)')),
    );
    context.pop();
  }

  void _changeImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image picker (demo)')),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryDark,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  InputDecoration _filledDeco(
    ThemeData theme, {
    String? hint,
    EdgeInsetsGeometry? contentPadding,
    bool isInvalid = false,
  }) {
    final errorColor = theme.colorScheme.error;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: isInvalid
          ? BorderSide(color: errorColor, width: 1.5)
          : BorderSide.none,
    );
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isInvalid
          ? errorColor.withValues(alpha: 0.06)
          : theme.colorScheme.surfaceContainerLow,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isInvalid ? errorColor : theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: theme.colorScheme.outline.withValues(alpha: 0.45)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: _isEditing ? 'Edit Post' : 'New Post',
        showDivider: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: Colors.white,
                elevation: 1,
                shadowColor: Colors.black26,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          _FeaturedImageCard(imageUrl: _imageUrl, onChangeImage: _changeImage),
          const SizedBox(height: 24),
          _sectionLabel('Post Title'),
          KeyedSubtree(
            key: keyFor('title'),
            child: Builder(builder: (context) {
              final invalid = isFieldInvalid('title');
              final errorColor = theme.colorScheme.error;
              return TextField(
                controller: _title,
                onChanged: (_) => clearFieldError('title'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: _filledDeco(
                  theme,
                  hint: 'Enter post title...',
                  isInvalid: invalid,
                ).copyWith(
                  fillColor: invalid
                      ? errorColor.withValues(alpha: 0.06)
                      : theme.colorScheme.surfaceContainerHighest,
                ),
              );
            }),
          ),
          const SizedBox(height: 22),
          _sectionLabel('Category'),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = i == _categoryIndex;
                return FilterChip(
                  showCheckmark: false,
                  label: Text(_categories[i]),
                  selected: selected,
                  onSelected: (_) => setState(() => _categoryIndex = i),
                  selectedColor: theme.colorScheme.primaryContainer,
                  checkmarkColor: Colors.white,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                  ),
                  side: BorderSide.none,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: const StadiumBorder(),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          _sectionLabel('Post Content'),
          Container(
            key: keyFor('body'),
            decoration: BoxDecoration(
              color: isFieldInvalid('body')
                  ? theme.colorScheme.error.withValues(alpha: 0.04)
                  : AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isFieldInvalid('body')
                    ? theme.colorScheme.error
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: isFieldInvalid('body') ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.format_bold, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {},
                        tooltip: 'Bold',
                      ),
                      IconButton(
                        icon: Icon(Icons.format_italic, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {},
                        tooltip: 'Italic',
                      ),
                      IconButton(
                        icon: Icon(Icons.format_list_bulleted, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {},
                        tooltip: 'List',
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                      IconButton(
                        icon: Icon(Icons.link, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {},
                        tooltip: 'Link',
                      ),
                      IconButton(
                        icon: Icon(Icons.image_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {},
                        tooltip: 'Image',
                      ),
                    ],
                  ),
                ),
                TextField(
                  controller: _body,
                  minLines: 10,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  onChanged: (_) => clearFieldError('body'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.45,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Start writing your story...',
                    hintStyle: TextStyle(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _sectionLabel('Excerpt'),
          TextField(
            controller: _excerpt,
            minLines: 3,
            maxLines: 5,
            style: GoogleFonts.inter(fontSize: 14, height: 1.45, color: theme.colorScheme.onSurfaceVariant),
            decoration: _filledDeco(theme, hint: 'A short summary for previews...'),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Publish Post',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Visible to all your store visitors',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          height: 1.25,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _published,
                  onChanged: (v) => setState(() => _published = v),
                  activeTrackColor: AppTheme.primary,
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: _confirmDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.15), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'DELETE POST',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedImageCard extends StatelessWidget {
  const _FeaturedImageCard({required this.imageUrl, required this.onChangeImage});

  final String? imageUrl;
  final VoidCallback onChangeImage;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: onChangeImage,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
                  )
                else
                  Center(
                    child: Icon(Icons.add_photo_alternate_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.95),
                    elevation: 6,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: onChangeImage,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_camera_rounded, size: 20, color: AppTheme.primaryDark),
                            const SizedBox(width: 8),
                            Text(
                              'Change Image',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'FEATURED IMAGE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
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
