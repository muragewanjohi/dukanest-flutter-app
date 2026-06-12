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
import '../../../core/api/dio_envelope.dart';
import '../../../core/util/store_media_url.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../../settings/providers/dashboard_settings_provider.dart';
import '../data/page_content.dart';
import '../providers/content_hub_provider.dart';

class _BannerDraft {
  _BannerDraft({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.ctaLink,
    this.imageUrl,
  });

  final String id;
  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController ctaText;
  final TextEditingController ctaLink;
  String? imageUrl;
  String? pendingLocalPath;
  bool imageCleared = false;

  void dispose() {
    title.dispose();
    subtitle.dispose();
    ctaText.dispose();
    ctaLink.dispose();
  }
}

/// Edit the storefront banners section (title, subtitle, and per-banner content).
class BannersSectionEditorScreen extends ConsumerStatefulWidget {
  const BannersSectionEditorScreen({super.key, this.pageSlug = 'home'});

  final String pageSlug;

  @override
  ConsumerState<BannersSectionEditorScreen> createState() =>
      _BannersSectionEditorScreenState();
}

class _BannersSectionEditorScreenState
    extends ConsumerState<BannersSectionEditorScreen> {
  final _sectionTitle = TextEditingController();
  final _sectionSubtitle = TextEditingController();
  final _picker = ImagePicker();

  PageContent? _pc;
  List<_BannerDraft> _banners = [];
  int _columns = 2;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sectionTitle.dispose();
    _sectionSubtitle.dispose();
    for (final b in _banners) {
      b.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final pc = await loadPageBySlug(api, widget.pageSlug);
      if (!mounted) return;
      if (pc == null) {
        setState(() {
          _loading = false;
          _error = 'Page "${widget.pageSlug}" was not found.';
        });
        return;
      }
      for (final b in _banners) {
        b.dispose();
      }
      final section = readBanners(pc.content);
      _sectionTitle.text = settingsPick(section, ['title']);
      _sectionSubtitle.text = settingsPick(section, ['subtitle']);
      final cols = section['columns'];
      _columns = cols is int ? cols.clamp(1, 3) : 2;
      final rawBanners = section['banners'];
      final drafts = <_BannerDraft>[];
      if (rawBanners is List) {
        for (var i = 0; i < rawBanners.length; i++) {
          final m = rawBanners[i];
          if (m is! Map) continue;
          final map = Map<String, dynamic>.from(m);
          final img = settingsPick(map, ['image', 'imageUrl', 'image_url']);
          drafts.add(_BannerDraft(
            id: settingsPick(map, ['id'], fallback: 'banner_$i'),
            title: TextEditingController(
                text: settingsPick(map, ['title', 'heading'])),
            subtitle: TextEditingController(
                text: settingsPick(map, ['subtitle', 'subheading'])),
            ctaText: TextEditingController(
                text: settingsPick(map, ['cta_text', 'ctaText'])),
            ctaLink: TextEditingController(
                text: settingsPick(map, ['cta_link', 'ctaLink', 'link'])),
            imageUrl: img.isEmpty ? null : normalizeStoreMediaUrl(img),
          ));
        }
      }
      setState(() {
        _pc = pc;
        _banners = drafts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage(int index) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() {
        _banners[index].pendingLocalPath = file.path;
        _banners[index].imageCleared = false;
      });
    } catch (e) {
      _toast(apiErrorMessage(e));
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

  InputDecoration _inputDeco(ThemeData theme) => InputDecoration(
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Future<void> _save() async {
    final pc = _pc;
    if (pc == null || _saving) return;
    setState(() => _saving = true);
    try {
      final bannerPayload = <Map<String, dynamic>>[];
      for (final b in _banners) {
        var image = b.imageUrl ?? '';
        if (b.pendingLocalPath != null && !b.imageCleared) {
          final uploaded = await _uploadImage(b.pendingLocalPath!);
          if (!mounted) return;
          if (uploaded == null) {
            setState(() => _saving = false);
            return;
          }
          image = uploaded;
          b.imageUrl = uploaded;
        }
        if (b.imageCleared) image = '';
        bannerPayload.add({
          'id': b.id,
          'title': b.title.text.trim(),
          'subtitle': b.subtitle.text.trim(),
          'image': image,
          'cta_text': b.ctaText.text.trim(),
          'cta_link': b.ctaLink.text.trim(),
        });
      }

      final section = <String, dynamic>{
        'type': 'banners',
        'title': _sectionTitle.text.trim(),
        'subtitle': _sectionSubtitle.text.trim(),
        'columns': _columns,
        'banners': bannerPayload,
      };

      final content = Map<String, dynamic>.from(pc.content);
      writeBanners(content, section);

      final api = ref.read(apiClientProvider);
      final err = await savePageContent(
        api,
        id: pc.id,
        content: content,
        publish: false,
      );
      if (!mounted) return;
      if (err != null) {
        _toast(err);
        return;
      }
      pc.content = content;
      for (final b in _banners) {
        b.pendingLocalPath = null;
        b.imageCleared = false;
      }
      ref.invalidate(contentHubProvider);
      _toast('Saved as draft');
      if (context.canPop()) context.pop();
    } catch (e) {
      _toast(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Edit Banners',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving || _loading ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    Text(
                      'Banners Section',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Edit promotional banner cards shown on your home page.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _sectionTitle,
                      decoration:
                          _inputDeco(theme).copyWith(labelText: 'Section title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sectionSubtitle,
                      decoration: _inputDeco(theme)
                          .copyWith(labelText: 'Section subtitle'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Columns',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [1, 2, 3].map((n) {
                        return ChoiceChip(
                          label: Text('$n'),
                          selected: _columns == n,
                          onSelected: (_) => setState(() => _columns = n),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    if (_banners.isEmpty)
                      Text(
                        'No banners configured yet. Add banners from the web dashboard.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      ...List.generate(_banners.length, _bannerCard),
                  ],
                ),
    );
  }

  Widget _bannerCard(int index) {
    final theme = Theme.of(context);
    final b = _banners[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.ghostBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Banner ${index + 1}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _bannerImagePreview(theme, b),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _iconBtn(
                          theme,
                          icon: Icons.edit_outlined,
                          onTap: () => _pickImage(index),
                        ),
                        const SizedBox(width: 6),
                        _iconBtn(
                          theme,
                          icon: Icons.delete_outline,
                          color: theme.colorScheme.error,
                          onTap: () => setState(() {
                            b.imageCleared = true;
                            b.pendingLocalPath = null;
                            b.imageUrl = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: b.title,
            decoration: _inputDeco(theme).copyWith(labelText: 'Title'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: b.subtitle,
            decoration: _inputDeco(theme).copyWith(labelText: 'Subtitle'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: b.ctaText,
            decoration: _inputDeco(theme).copyWith(labelText: 'Button text'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: b.ctaLink,
            decoration: _inputDeco(theme).copyWith(labelText: 'Button link'),
          ),
        ],
      ),
    );
  }

  Widget _bannerImagePreview(ThemeData theme, _BannerDraft b) {
    if (b.pendingLocalPath != null && !b.imageCleared) {
      return Image.file(File(b.pendingLocalPath!), fit: BoxFit.cover);
    }
    final url = b.imageUrl;
    if (url != null && url.isNotEmpty && !b.imageCleared) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => ColoredBox(
          color: theme.colorScheme.surfaceContainerLowest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      );
    }
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLowest,
      child: Center(
        child: Text(
          'No image',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(
    ThemeData theme, {
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color ?? theme.colorScheme.primary),
        ),
      ),
    );
  }
}
