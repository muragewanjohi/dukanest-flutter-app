import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../../../core/util/store_media_url.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../../core/widgets/form_error_highlight.dart';

/// Edit / create blog post — Stitch: Edit Blog Post (Refined) (518f2f427af54eb38a97196c5dd1a986).
/// Full-screen route: no duplicate bottom nav (Stitch mock nav omitted in app).
class BlogPostEditorScreen extends ConsumerStatefulWidget {
  const BlogPostEditorScreen({super.key, this.postId});

  /// When null, screen is "new post" mode (empty fields, no delete).
  final String? postId;

  @override
  ConsumerState<BlogPostEditorScreen> createState() =>
      _BlogPostEditorScreenState();
}

class _BlogPostEditorScreenState extends ConsumerState<BlogPostEditorScreen>
    with FormErrorHighlightMixin {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _excerpt;
  // AI-assisted blog drafting — generate-then-save (Pattern A), mirrors
  // storeflow's blog-form-client.tsx. Never auto-publishes; fills the
  // fields above for review/edit before Save.
  late final TextEditingController _aiTopic;
  bool _isDraftingWithAi = false;
  String? _aiDraftError;
  late bool _published;
  String? _imageUrl;
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  bool _bootLoading = true;
  bool _uploadingImage = false;
  final _picker = ImagePicker();

  bool get _isEditing => widget.postId != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _body = TextEditingController();
    _excerpt = TextEditingController();
    _aiTopic = TextEditingController();
    _published = false;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _loadCategories();
      if (_isEditing && widget.postId != null) {
        await _loadExistingPost(widget.postId!);
      }
    } finally {
      if (mounted) setState(() => _bootLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    final api = ref.read(apiClientProvider);
    final r = await api.getBlogCategories();
    if (!r.success || r.data == null) return;
    final payload = r.data;
    final root =
        payload is Map<String, dynamic> ? payload : <String, dynamic>{};
    final nested = root['data'];
    final bag = nested is Map<String, dynamic>
        ? nested
        : nested is Map
            ? Map<String, dynamic>.from(nested)
            : root;
    final raw = bag['items'] ?? root['items'];
    final list = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    if (!mounted) return;
    setState(() {
      _categories = list;
      if (_selectedCategoryId == null && list.isNotEmpty) {
        final firstId = '${list.first['id'] ?? list.first['_id'] ?? ''}'.trim();
        _selectedCategoryId = firstId.isEmpty ? null : firstId;
      }
    });
  }

  Future<void> _loadExistingPost(String id) async {
    final r = await ref.read(apiClientProvider).getBlog(id);
    if (!r.success || r.data == null) return;
    final payload = r.data;
    final root =
        payload is Map<String, dynamic> ? payload : <String, dynamic>{};
    final nested = root['data'] ?? root['blog'] ?? root['post'];
    final m = nested is Map<String, dynamic>
        ? nested
        : nested is Map
            ? Map<String, dynamic>.from(nested)
            : root;
    final title = '${m['title'] ?? ''}'.trim();
    final content = '${m['content'] ?? m['body'] ?? ''}'.trim();
    final excerpt = '${m['excerpt'] ?? ''}'.trim();
    final published = m['published'] == true || m['status'] == 'published';
    final img =
        '${m['featured_image'] ?? m['image'] ?? m['featuredImage'] ?? ''}'
            .trim();
    final cid = '${m['category_id'] ?? m['categoryId'] ?? ''}'.trim();
    if (!mounted) return;
    setState(() {
      _title.text = title;
      _body.text = content;
      _excerpt.text = excerpt;
      _published = published;
      if (img.isNotEmpty) _imageUrl = img;
      if (cid.isNotEmpty) _selectedCategoryId = cid;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _excerpt.dispose();
    _aiTopic.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('This permanently deletes the blog post.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final r = await ref.read(apiClientProvider).deleteBlog(widget.postId!);
      if (!r.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error?.message ?? 'Delete failed')),
        );
        return;
      }
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete post.')),
        );
      }
    }
  }

  Future<void> _save() async {
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
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'content': _body.text.trim(),
      'excerpt': _excerpt.text.trim(),
      'published': _published,
      if (_selectedCategoryId != null && _selectedCategoryId!.trim().isNotEmpty)
        'category_id': _selectedCategoryId!.trim(),
      if (_imageUrl != null && _imageUrl!.trim().isNotEmpty)
        'featured_image': _imageUrl!.trim(),
    };
    try {
      final api = ref.read(apiClientProvider);
      if (_isEditing && widget.postId != null) {
        final r = await api.updateBlog(widget.postId!, body);
        if (!r.success) {
          throw StateError(r.error?.message ?? 'Save failed');
        }
      } else {
        final r = await api.createBlog(body);
        if (!r.success) {
          throw StateError(r.error?.message ?? 'Save failed');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post saved')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> _generateBlogDraft() async {
    final topic = _aiTopic.text.trim();
    if (topic.isEmpty || _isDraftingWithAi) return;
    setState(() {
      _isDraftingWithAi = true;
      _aiDraftError = null;
    });
    try {
      final r = await ref.read(apiClientProvider).postBlogAiDraft(topic);
      if (!r.success) {
        setState(() => _aiDraftError = r.error?.message ?? 'Could not draft a post right now. Please try again.');
        return;
      }
      var data = r.data;
      if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic> && data['title'] == null) {
        data = data['data'];
      }
      if (data is! Map<String, dynamic>) {
        setState(() => _aiDraftError = 'The AI returned an unexpected response.');
        return;
      }
      final title = (data['title'] as String?)?.trim() ?? '';
      final content = (data['content'] as String?)?.trim() ?? '';
      final excerpt = (data['excerpt'] as String?)?.trim() ?? '';
      if (!mounted) return;
      setState(() {
        if (title.isNotEmpty) _title.text = title;
        if (content.isNotEmpty) _body.text = content;
        if (excerpt.isNotEmpty) _excerpt.text = excerpt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiDraftError = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isDraftingWithAi = false);
    }
  }

  Future<void> _changeImage() async {
    if (_uploadingImage) return;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      setState(() => _uploadingImage = true);
      final api = ref.read(apiClientProvider);
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.replaceAll(r'\', '/').split('/').last,
        ),
      });
      final r = await api.uploadMedia(form);
      if (!r.success || r.data == null) {
        throw StateError(r.error?.message ?? 'Image upload failed');
      }
      final url = extractMediaUploadUrl(r.data);
      if (url.isEmpty) {
        throw StateError('Upload succeeded but no image URL was returned.');
      }
      if (!mounted) return;
      setState(() => _imageUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Featured image updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
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
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle:
          TextStyle(color: theme.colorScheme.outline.withValues(alpha: 0.45)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_bootLoading) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: DashboardAppBar(
          title: _isEditing ? 'Edit Post' : 'New Post',
          showDivider: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          _FeaturedImageCard(
            imageUrl: _imageUrl,
            uploading: _uploadingImage,
            onChangeImage: _changeImage,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Draft with AI',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Describe a topic and I'll write a full draft (title, body, excerpt) below for you to review and edit — nothing is published until you save it.",
                  style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aiTopic,
                        enabled: !_isDraftingWithAi,
                        onSubmitted: (_) => _generateBlogDraft(),
                        decoration: InputDecoration(
                          hintText: 'e.g. "how to choose the right handbag"',
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isDraftingWithAi ? null : _generateBlogDraft,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isDraftingWithAi ? 'Drafting…' : 'Draft'),
                    ),
                  ],
                ),
                if (_aiDraftError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _aiDraftError!,
                    style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
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
          if (_categories.isEmpty)
            Text(
              'No blog categories returned. Add categories from your dashboard, then refresh.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: () {
                final ids = _categories
                    .map((c) => '${c['id'] ?? c['_id'] ?? ''}'.trim())
                    .where((id) => id.isNotEmpty)
                    .toList();
                if (ids.isEmpty) return null;
                final sel = _selectedCategoryId?.trim();
                if (sel != null && sel.isNotEmpty && ids.contains(sel)) {
                  return sel;
                }
                return ids.first;
              }(),
              decoration: _filledDeco(theme).copyWith(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              items: _categories
                  .map((c) {
                    final id = '${c['id'] ?? c['_id'] ?? ''}'.trim();
                    if (id.isEmpty) return null;
                    final name =
                        '${c['name'] ?? c['title'] ?? 'Category'}'.trim();
                    return DropdownMenuItem(
                      value: id,
                      child: Text(name),
                    );
                  })
                  .whereType<DropdownMenuItem<String>>()
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh
                        .withValues(alpha: 0.45),
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.format_bold,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {},
                        tooltip: 'Bold',
                      ),
                      IconButton(
                        icon: Icon(Icons.format_italic,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {},
                        tooltip: 'Italic',
                      ),
                      IconButton(
                        icon: Icon(Icons.format_list_bulleted,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {},
                        tooltip: 'List',
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.45),
                      ),
                      IconButton(
                        icon: Icon(Icons.link,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {},
                        tooltip: 'Link',
                      ),
                      IconButton(
                        icon: Icon(Icons.image_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant),
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
                    hintStyle: TextStyle(
                        color:
                            theme.colorScheme.outline.withValues(alpha: 0.4)),
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
            style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: theme.colorScheme.onSurfaceVariant),
            decoration:
                _filledDeco(theme, hint: 'A short summary for previews...'),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
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
                  inactiveTrackColor:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
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
                side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.15),
                    width: 2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 20, color: theme.colorScheme.error),
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
  const _FeaturedImageCard({
    required this.imageUrl,
    required this.uploading,
    required this.onChangeImage,
  });

  final String? imageUrl;
  final bool uploading;
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
            onTap: uploading ? null : onChangeImage,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined, size: 48)),
                  )
                else
                  Center(
                    child: Icon(Icons.add_photo_alternate_outlined,
                        size: 48, color: Theme.of(context).colorScheme.outline),
                  ),
                if (uploading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(child: CircularProgressIndicator()),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_camera_rounded,
                                size: 20, color: AppTheme.primaryDark),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
