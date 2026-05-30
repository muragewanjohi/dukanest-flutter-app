import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/util/store_media_url.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../../core/widgets/form_error_highlight.dart';
import '../../settings/providers/dashboard_settings_provider.dart';
import '../data/page_content.dart';
import '../providers/content_hub_provider.dart';

/// Edit Hero Section. Loads the storefront `home` page, hydrates the hero block
/// from its `content`, and persists changes back via the Pages API.
class HeroSectionEditorScreen extends ConsumerStatefulWidget {
  const HeroSectionEditorScreen({super.key});

  @override
  ConsumerState<HeroSectionEditorScreen> createState() =>
      _HeroSectionEditorScreenState();
}

class _HeroSectionEditorScreenState
    extends ConsumerState<HeroSectionEditorScreen>
    with FormErrorHighlightMixin {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _description = TextEditingController();
  final _bgHex = TextEditingController(text: '#F5F5F5');
  final _ctaText = TextEditingController();
  final _ctaLink = TextEditingController(text: '/products');
  final _picker = ImagePicker();

  PageContent? _pc;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  String? _heroImageUrl;
  String? _pendingLocalImagePath;
  bool _imageCleared = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final pc = await loadPageBySlug(api, 'home');
      if (!mounted) return;
      if (pc == null) {
        setState(() {
          _loading = false;
          _error = 'Home page was not found.';
        });
        return;
      }
      final hero = readHero(pc.content);
      _title.text = settingsPick(hero, ['title', 'heading']);
      _subtitle.text = settingsPick(hero, ['subtitle', 'subheading']);
      _description.text = settingsPick(hero, ['description', 'text', 'body']);
      _ctaText.text = settingsPick(hero,
          ['cta_text', 'ctaText', 'button_text', 'buttonText', 'cta_label']);
      final ctaLink = settingsPick(hero,
          ['cta_link', 'ctaLink', 'button_link', 'buttonLink', 'href', 'link']);
      if (ctaLink.isNotEmpty) _ctaLink.text = ctaLink;
      final bg = settingsPick(
          hero, ['background_color', 'backgroundColor', 'bg_color', 'bgColor']);
      if (bg.isNotEmpty) _bgHex.text = bg;
      final img = settingsPick(hero, [
        'image',
        'banner_image',
        'bannerImage',
        'imageUrl',
        'image_url',
        'foreground_image',
      ]);
      _heroImageUrl = img.isEmpty ? null : normalizeStoreMediaUrl(img);
      setState(() {
        _pc = pc;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() {
        _pendingLocalImagePath = file.path;
        _imageCleared = false;
      });
    } catch (e) {
      _toast('Could not pick image: $e');
    }
  }

  Future<String?> _uploadImage(String path) async {
    final api = ref.read(apiClientProvider);
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          path,
          filename: path.replaceAll(r'\', '/').split('/').last,
        ),
      });
      final r = await api.uploadMedia(form);
      if (!r.success || r.data == null) {
        _toast(r.error?.message ?? 'Image upload failed');
        return null;
      }
      final url = extractMediaUploadUrl(r.data);
      if (url.isEmpty) {
        _toast('Upload succeeded but no image URL was returned.');
        return null;
      }
      return url;
    } on DioException catch (e) {
      _toast('Image upload failed: ${e.message}');
      return null;
    }
  }

  Future<void> _save() async {
    final pc = _pc;
    if (pc == null || _saving) return;
    if (_title.text.trim().isEmpty) {
      reportFieldError(fieldId: 'title', message: 'Hero title is required.');
      return;
    }
    if (_ctaText.text.trim().isEmpty) {
      reportFieldError(
          fieldId: 'ctaText',
          message: 'Call-to-action button text is required.');
      return;
    }
    if (_ctaLink.text.trim().isEmpty) {
      reportFieldError(
          fieldId: 'ctaLink',
          message: 'Call-to-action button link is required.');
      return;
    }
    clearAllFieldErrors();
    setState(() => _saving = true);
    try {
      var image = _heroImageUrl ?? '';
      if (_pendingLocalImagePath != null && !_imageCleared) {
        final uploaded = await _uploadImage(_pendingLocalImagePath!);
        if (!mounted) return;
        if (uploaded == null) {
          setState(() => _saving = false);
          return;
        }
        image = uploaded;
        _heroImageUrl = uploaded;
      }
      if (_imageCleared) image = '';

      final hero = <String, dynamic>{
        'title': _title.text.trim(),
        'heading': _title.text.trim(),
        'subtitle': _subtitle.text.trim(),
        'description': _description.text.trim(),
        'cta_text': _ctaText.text.trim(),
        'ctaText': _ctaText.text.trim(),
        'cta_link': _ctaLink.text.trim(),
        'ctaLink': _ctaLink.text.trim(),
        'background_color': _bgHex.text.trim(),
        'backgroundColor': _bgHex.text.trim(),
        'image': image,
        'banner_image': image,
        'imageUrl': image,
      };
      final content = Map<String, dynamic>.from(pc.content);
      writeHero(content, hero);

      final api = ref.read(apiClientProvider);
      final err = await savePageContent(
        api,
        id: pc.id,
        content: content,
        publish: true,
      );
      if (!mounted) return;
      if (err != null) {
        _toast(err);
        return;
      }
      pc.content = content;
      _pendingLocalImagePath = null;
      _imageCleared = false;
      ref.invalidate(contentHubProvider);
      _toast('Hero section saved');
      if (context.canPop()) context.pop();
    } catch (e) {
      _toast('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                  onTap: _saving || _loading ? null : _save,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildForm(theme),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return ListView(
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
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500, fontSize: 14),
                  decoration:
                      _inputDeco(theme, isInvalid: isFieldInvalid('title'))
                          .copyWith(hintText: 'Hero Title'),
                ),
              ),
              const SizedBox(height: 18),
              _fieldLabel('Subtitle'),
              const SizedBox(height: 8),
              TextField(
                controller: _subtitle,
                style: GoogleFonts.inter(fontSize: 14),
                decoration:
                    _inputDeco(theme).copyWith(hintText: 'Sub-heading text'),
              ),
              const SizedBox(height: 18),
              _fieldLabel('Description'),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: _inputDeco(theme)
                    .copyWith(hintText: 'Detailed brand story...'),
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
                        color:
                            _parseHex(_bgHex.text) ?? const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.35)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _bgHex,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.robotoMono(
                            fontSize: 14, fontWeight: FontWeight.w500),
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
                      _heroImagePreview(theme),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Column(
                          children: [
                            _roundImageAction(
                              icon: Icons.edit_outlined,
                              color: theme.colorScheme.primary,
                              bg: Colors.white.withValues(alpha: 0.92),
                              onTap: _pickImage,
                            ),
                            const SizedBox(height: 8),
                            _roundImageAction(
                              icon: Icons.delete_outline_rounded,
                              color: theme.colorScheme.error,
                              bg: theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.95),
                              onTap: () => setState(() {
                                _imageCleared = true;
                                _pendingLocalImagePath = null;
                                _heroImageUrl = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500, fontSize: 14),
                  decoration:
                      _inputDeco(theme, isInvalid: isFieldInvalid('ctaText'))
                          .copyWith(hintText: 'CTA Label'),
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
                  decoration:
                      _inputDeco(theme, isInvalid: isFieldInvalid('ctaLink'))
                          .copyWith(
                    hintText: 'e.g. /shop',
                    prefixIcon: Icon(Icons.link,
                        color: theme.colorScheme.outline, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroImagePreview(ThemeData theme) {
    if (_pendingLocalImagePath != null && !_imageCleared) {
      return Image.file(File(_pendingLocalImagePath!), fit: BoxFit.cover);
    }
    final url = _heroImageUrl;
    if (url != null && url.isNotEmpty && !_imageCleared) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            ColoredBox(color: theme.colorScheme.surfaceContainerLowest),
        errorWidget: (_, __, ___) => ColoredBox(
          color: theme.colorScheme.surfaceContainerLowest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      );
    }
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: theme.colorScheme.outline, size: 36),
            const SizedBox(height: 6),
            Text(
              'Tap edit to add an image',
              style: GoogleFonts.inter(
                  fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Color? _parseHex(String raw) {
    var s = raw.trim().replaceAll('#', '');
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    return v == null ? null : Color(v);
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
}
