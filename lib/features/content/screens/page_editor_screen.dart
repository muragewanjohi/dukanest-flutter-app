import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/store_identity_provider.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../providers/content_hub_provider.dart';
import '../data/page_content.dart';

/// Page Editor (home & storefront sections). Loads the real page row via the
/// Pages API, lets the merchant toggle sections + edit SEO, and saves/publishes
/// back to `PUT /dashboard/pages/:id`.
class PageEditorScreen extends ConsumerStatefulWidget {
  const PageEditorScreen({super.key, required this.pageSlug});

  final String pageSlug;

  @override
  ConsumerState<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends ConsumerState<PageEditorScreen> {
  PageContent? _pc;
  List<PageSection> _sections = [];
  final _metaTitle = TextEditingController();
  final _metaDescription = TextEditingController();

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
    _metaTitle.dispose();
    _metaDescription.dispose();
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
      final seo = pc.content['seo'];
      final seoMap = seo is Map ? Map<String, dynamic>.from(seo) : const {};
      _metaTitle.text = (seoMap['meta_title'] ??
              seoMap['metaTitle'] ??
              pc.raw['meta_title'] ??
              pc.raw['metaTitle'] ??
              '')
          .toString();
      _metaDescription.text = (seoMap['meta_description'] ??
              seoMap['metaDescription'] ??
              pc.raw['meta_description'] ??
              pc.raw['metaDescription'] ??
              '')
          .toString();
      setState(() {
        _pc = pc;
        _sections = parseSections(pc.content);
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

  String get _headline {
    if (widget.pageSlug == 'home') return 'Home Page Design';
    final title = _pc?.title ?? '';
    if (title.isNotEmpty) return '$title Page Design';
    final parts = widget.pageSlug.split('-').where((e) => e.isNotEmpty);
    if (parts.isEmpty) return 'Page Design';
    return '${parts.map((p) => p[0].toUpperCase() + p.substring(1)).join(' ')} Page Design';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Map<String, dynamic> _buildContentForSave() {
    final pc = _pc!;
    final content = Map<String, dynamic>.from(pc.content);
    for (final s in _sections) {
      applySectionEnabled(content, s);
    }
    final seo = <String, dynamic>{
      if (content['seo'] is Map) ...Map<String, dynamic>.from(content['seo']),
      'meta_title': _metaTitle.text.trim(),
      'meta_description': _metaDescription.text.trim(),
    };
    content['seo'] = seo;
    return content;
  }

  Future<void> _save({required bool publish}) async {
    final pc = _pc;
    if (pc == null || _saving) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final err = await savePageContent(
        api,
        id: pc.id,
        content: _buildContentForSave(),
        metaTitle: _metaTitle.text.trim(),
        metaDescription: _metaDescription.text.trim(),
        publish: publish,
      );
      if (!mounted) return;
      if (err != null) {
        _toast(err);
        return;
      }
      ref.invalidate(contentHubProvider);
      _toast(publish ? 'Page published' : 'Draft saved');
    } catch (e) {
      _toast('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _preview() async {
    final identity = ref.read(storeIdentityProvider).valueOrNull;
    final base = (identity?.storeUrl ?? '').trim();
    if (base.isEmpty) {
      _toast('Store URL is not available yet.');
      return;
    }
    final slug = widget.pageSlug;
    final path = slug == 'home' ? '' : '/$slug';
    final uri = Uri.tryParse('$base$path');
    if (uri == null) {
      _toast('Could not open the storefront.');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('Could not open the storefront.');
    }
  }

  Future<void> _confirmDelete() async {
    final pc = _pc;
    if (pc == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete page?'),
        content: Text('This permanently removes the "${pc.title}" page.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.deletePage(pc.id);
      if (!mounted) return;
      if (!r.success) {
        _toast(r.error?.message ?? 'Could not delete page');
        return;
      }
      ref.invalidate(contentHubProvider);
      _toast('Page deleted');
      if (context.canPop()) context.pop();
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final canDelete = _pc != null && !_pc!.isProtectedSlug;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Page Editor',
        showDivider: true,
        actions: [
          if (canDelete)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: theme.colorScheme.error),
              onPressed: _confirmDelete,
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
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                            24, 24, 24, 16 + bottomInset + 72),
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
                          if (_sections.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'This page has no configurable sections yet.',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          else
                            ...List.generate(
                              _sections.length,
                              (i) => _sectionTile(context, theme, i),
                            ),
                          const SizedBox(height: 28),
                          _SeoEditorCard(
                            theme: theme,
                            metaTitle: _metaTitle,
                            metaDescription: _metaDescription,
                          ),
                        ],
                      ),
                    ),
                    _BottomActionBar(
                      bottomPadding: bottomInset,
                      saving: _saving,
                      onPreview: _preview,
                      onSaveDraft: () => _save(publish: false),
                      onPublish: () => _save(publish: true),
                    ),
                  ],
                ),
    );
  }

  Widget _sectionTile(BuildContext context, ThemeData theme, int i) {
    final s = _sections[i];
    final isHero = s.key.toLowerCase() == 'hero';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        elevation: 0,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isHero ? () => context.push('/hero-section/edit') : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
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
                Icon(Icons.drag_indicator_rounded,
                    color: theme.colorScheme.outline, size: 22),
                const SizedBox(width: 8),
                Text(s.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                      if (s.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
                    inactiveTrackColor: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.45),
                  ),
                ),
                if (isHero)
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        color: theme.colorScheme.onSurfaceVariant, size: 22),
                    onPressed: () => context.push('/hero-section/edit'),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeoEditorCard extends StatelessWidget {
  const _SeoEditorCard({
    required this.theme,
    required this.metaTitle,
    required this.metaDescription,
  });

  final ThemeData theme;
  final TextEditingController metaTitle;
  final TextEditingController metaDescription;

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );

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
            side: BorderSide(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
          ),
          title: Text(
            'SEO Settings',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            'Meta tags for search engine optimization',
            style: GoogleFonts.inter(
                fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
          children: [
            TextField(controller: metaTitle, decoration: deco('Meta title')),
            const SizedBox(height: 12),
            TextField(
              controller: metaDescription,
              minLines: 2,
              maxLines: 4,
              decoration: deco('Meta description'),
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
    required this.saving,
    required this.onPreview,
    required this.onSaveDraft,
    required this.onPublish,
  });

  final double bottomPadding;
  final bool saving;
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
          padding:
              EdgeInsets.fromLTRB(16, 12, 16, 12 + (bottomPadding > 0 ? 0 : 8)),
          child: Row(
            children: [
              Expanded(
                child: _barButton(
                  theme,
                  label: 'Preview',
                  filled: false,
                  onPressed: saving ? null : onPreview,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _barButton(
                  theme,
                  label: 'Save Draft',
                  filled: false,
                  onPressed: saving ? null : onSaveDraft,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _barButton(
                  theme,
                  label: saving ? 'Saving…' : 'Publish Page',
                  filled: true,
                  onPressed: saving ? null : onPublish,
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
    required VoidCallback? onPressed,
  }) {
    final style =
        GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800);
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: style),
    );
  }
}
