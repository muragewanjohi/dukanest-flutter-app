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

/// Edit the left-side banner of a split layout section on the storefront home page.
class SplitLayoutSectionEditorScreen extends ConsumerStatefulWidget {
  const SplitLayoutSectionEditorScreen({super.key, this.pageSlug = 'home'});

  final String pageSlug;

  @override
  ConsumerState<SplitLayoutSectionEditorScreen> createState() =>
      _SplitLayoutSectionEditorScreenState();
}

class _SplitLayoutSectionEditorScreenState
    extends ConsumerState<SplitLayoutSectionEditorScreen> {
  final _ctaLink = TextEditingController();
  final _picker = ImagePicker();

  PageContent? _pc;
  String _leftSideType = 'banner';
  double _overlayOpacity = 0;
  String? _imageUrl;
  String? _pendingLocalPath;
  bool _imageCleared = false;

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
      final pc = await loadPageBySlug(api, widget.pageSlug);
      if (!mounted) return;
      if (pc == null) {
        setState(() {
          _loading = false;
          _error = 'Page "${widget.pageSlug}" was not found.';
        });
        return;
      }
      final section = readSplitLayout(pc.content);
      final left = section['left_side'];
      final leftMap =
          left is Map ? Map<String, dynamic>.from(left) : <String, dynamic>{};
      _leftSideType =
          settingsPick(leftMap, ['type'], fallback: 'banner').toLowerCase();
      final img = settingsPick(leftMap, ['image', 'imageUrl', 'image_url']);
      _imageUrl = img.isEmpty ? null : normalizeStoreMediaUrl(img);
      _ctaLink.text = settingsPick(leftMap, ['cta_link', 'ctaLink', 'link']);
      final opacity = leftMap['overlay_opacity'];
      _overlayOpacity = opacity is num ? opacity.toDouble().clamp(0, 100) : 0;
      setState(() {
        _pc = pc;
        _loading = false;
        _pendingLocalPath = null;
        _imageCleared = false;
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

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() {
        _pendingLocalPath = file.path;
        _imageCleared = false;
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
    if (_leftSideType != 'banner') {
      _toast('Left side is not a banner. Edit this section on the web dashboard.');
      return;
    }
    setState(() => _saving = true);
    try {
      var image = _imageUrl ?? '';
      if (_pendingLocalPath != null && !_imageCleared) {
        final uploaded = await _uploadImage(_pendingLocalPath!);
        if (!mounted) return;
        if (uploaded == null) {
          setState(() => _saving = false);
          return;
        }
        image = uploaded;
        _imageUrl = uploaded;
      }
      if (_imageCleared) image = '';

      final existing = readSplitLayout(pc.content);
      final left = existing['left_side'];
      final leftMap =
          left is Map ? Map<String, dynamic>.from(left) : <String, dynamic>{};
      leftMap['type'] = 'banner';
      leftMap['image'] = image;
      leftMap['cta_link'] = _ctaLink.text.trim();
      leftMap['overlay_opacity'] = _overlayOpacity.round();

      final section = Map<String, dynamic>.from(existing);
      section['type'] = 'split_layout';
      section['left_side'] = leftMap;

      final content = Map<String, dynamic>.from(pc.content);
      writeSplitLayout(content, section);

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
      _pendingLocalPath = null;
      _imageCleared = false;
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
        title: 'Edit Split Layout',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving || _loading || _leftSideType != 'banner'
                  ? null
                  : _save,
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
              : _leftSideType != 'banner'
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(
                            'The left side of this split layout is not a banner '
                            '(type: $_leftSideType). Edit it from the web dashboard.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      children: [
                        Text(
                          'Left Banner',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Update the left-side banner image and link for your split layout section.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _imagePreview(theme),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Column(
                                    children: [
                                      _roundAction(
                                        icon: Icons.edit_outlined,
                                        onTap: _pickImage,
                                      ),
                                      const SizedBox(height: 8),
                                      _roundAction(
                                        icon: Icons.delete_outline,
                                        color: theme.colorScheme.error,
                                        onTap: () => setState(() {
                                          _imageCleared = true;
                                          _pendingLocalPath = null;
                                          _imageUrl = null;
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _ctaLink,
                          decoration: _inputDeco(theme).copyWith(
                            labelText: 'Banner link',
                            prefixIcon: Icon(Icons.link,
                                color: theme.colorScheme.outline),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Overlay opacity (${_overlayOpacity.round()}%)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          value: _overlayOpacity,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '${_overlayOpacity.round()}%',
                          onChanged: (v) => setState(() => _overlayOpacity = v),
                        ),
                      ],
                    ),
    );
  }

  Widget _imagePreview(ThemeData theme) {
    if (_pendingLocalPath != null && !_imageCleared) {
      return Image.file(File(_pendingLocalPath!), fit: BoxFit.cover);
    }
    final url = _imageUrl;
    if (url != null && url.isNotEmpty && !_imageCleared) {
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
          'Tap edit to add an image',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _roundAction({
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
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: color ?? AppTheme.primaryDark),
        ),
      ),
    );
  }
}
