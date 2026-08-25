import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../../../core/widgets/api_error_view.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../theme_list_data.dart';

class ThemesScreen extends ConsumerStatefulWidget {
  const ThemesScreen({super.key});

  @override
  ConsumerState<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends ConsumerState<ThemesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String? _activeId;
  Set<String> _installedIds = {};
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _listFrom(dynamic payload) =>
      themeListFrom(payload);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.getThemes(),
        api.getInstalledThemes(),
        api.getCurrentTheme(),
      ]);
      final themesResp = results[0];
      if (!themesResp.success) {
        throw StateError(themesResp.error?.message ?? 'Failed');
      }
      final list = _listFrom(themesResp.data);

      final installed = results[1].success
          ? _listFrom(results[1].data)
          : <Map<String, dynamic>>[];
      final installedIds =
          installed.map(_id).where((e) => e.isNotEmpty).toSet();

      final activeId =
          results[2].success ? currentThemeId(results[2].data) : null;

      if (!mounted) return;
      setState(() {
        _items = list;
        _installedIds = installedIds;
        _activeId = activeId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  String _id(Map<String, dynamic> m) => themeId(m);

  Future<void> _install(Map<String, dynamic> row) async {
    final id = _id(row);
    if (id.isEmpty || _busyId != null) return;
    setState(() => _busyId = id);
    try {
      final r = await ref.read(apiClientProvider).installTheme({'themeId': id});
      if (!r.success) throw StateError(r.error?.message ?? 'Install failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Theme installed')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _activate(Map<String, dynamic> row) async {
    final id = _id(row);
    if (id.isEmpty || _busyId != null) return;
    setState(() => _busyId = id);
    try {
      final api = ref.read(apiClientProvider);
      if (!_installedIds.contains(id)) {
        final installResp = await api.installTheme({'themeId': id});
        if (!installResp.success) {
          throw StateError(installResp.error?.message ?? 'Install failed');
        }
      }
      final r = await api.updateCurrentTheme({'themeId': id, 'id': id});
      if (!r.success) {
        throw StateError(r.error?.message ?? 'Could not activate');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Theme activated')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Themes',
        showDivider: true,
        actions: [
          IconButton(
            tooltip: 'Customize active',
            onPressed: () => context.push('/themes/customize'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    ],
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.66,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final row = _items[i];
                      final id = _id(row);
                      return _ThemeCard(
                        theme: theme,
                        name: '${row['name'] ?? row['title'] ?? 'Theme'}',
                        thumb:
                            '${row['thumbnail'] ?? row['previewUrl'] ?? row['image'] ?? row['preview_image'] ?? ''}',
                        isActive: _activeId != null && id == _activeId,
                        isInstalled: _installedIds.contains(id),
                        busy: _busyId == id,
                        onActivate: () => _activate(row),
                        onInstall: () => _install(row),
                      );
                    },
                  ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.name,
    required this.thumb,
    required this.isActive,
    required this.isInstalled,
    required this.busy,
    required this.onActivate,
    required this.onInstall,
  });

  final ThemeData theme;
  final String name;
  final String thumb;
  final bool isActive;
  final bool isInstalled;
  final bool busy;
  final VoidCallback onActivate;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppTheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isActive ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumb.isEmpty)
                  ColoredBox(
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Icon(Icons.palette_outlined,
                        color: theme.colorScheme.outline, size: 36),
                  )
                else
                  CachedNetworkImage(
                    imageUrl: thumb,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHigh),
                    errorWidget: (_, __, ___) => ColoredBox(
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: Icon(Icons.broken_image_outlined,
                          color: theme.colorScheme.outline),
                    ),
                  ),
                if (isActive)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  )
                else if (isInstalled)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'INSTALLED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: isActive
                      ? OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Active',
                              style: TextStyle(fontSize: 12)),
                        )
                      : FilledButton(
                          onPressed: busy ? null : onActivate,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: busy
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  isInstalled ? 'Set active' : 'Install & use',
                                  style: const TextStyle(fontSize: 12),
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeCustomizationScreen extends ConsumerStatefulWidget {
  const ThemeCustomizationScreen({super.key});

  @override
  ConsumerState<ThemeCustomizationScreen> createState() =>
      _ThemeCustomizationScreenState();
}

class _ThemeCustomizationScreenState
    extends ConsumerState<ThemeCustomizationScreen>
    with SingleTickerProviderStateMixin {
  final _jsonCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late final TabController _tabController;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 2 tabs: real AI-generated homepage images (DA.25, the common case a
    // merchant actually wants) first, the raw JSON editor (existing,
    // untouched) second — matches web's Theme Customize adding a new
    // "Homepage Images" tab alongside its existing ones.
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getCurrentTheme();
      if (!r.success) throw StateError(r.error?.message ?? 'Failed');
      final payload = r.data;
      final root =
          payload is Map<String, dynamic> ? payload : <String, dynamic>{};
      final nested = root['data'] ?? root['theme'];
      final m = nested is Map<String, dynamic>
          ? nested
          : nested is Map
              ? Map<String, dynamic>.from(nested)
              : root;
      _jsonCtrl.text = const JsonEncoder.withIndent('  ').convert(m);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(_jsonCtrl.text) as Map<String, dynamic>;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid JSON')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await ref.read(apiClientProvider).updateCurrentTheme(parsed);
      if (!r.success) throw StateError(r.error?.message ?? 'Save failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Theme settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onAdvancedTab = _tabController.index == 1;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Customize theme',
        showDivider: true,
        actions: [
          // Save only applies to the raw JSON editor (Advanced tab) —
          // hidden on the Homepage Images tab so it doesn't read as "save
          // my image changes" (those save themselves per-regenerate).
          if (onAdvancedTab)
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Homepage Images'),
            Tab(text: 'Advanced'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _HomepageImagesSection(),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    Text(
                      'Edit the active theme payload as JSON. Invalid shapes are rejected by the server.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _jsonCtrl,
                      maxLines: 24,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

/// DA.25 — the store's 5 real AI-generated homepage images (hero, 3
/// banners, split-layout), each individually regenerable, gated by the same
/// real monthly quota (marketing_image_prompt) the Dashboard AI Assistant's
/// homepage_image chat target uses — identical behavior and identical
/// remaining-quota accounting whether triggered here or from chat.
class _HomepageImagesSection extends ConsumerStatefulWidget {
  const _HomepageImagesSection();

  @override
  ConsumerState<_HomepageImagesSection> createState() =>
      _HomepageImagesSectionState();
}

class _HomepageImagesSectionState
    extends ConsumerState<_HomepageImagesSection> {
  static const _slots = ['hero', 'banner1', 'banner2', 'banner3', 'split_layout'];
  static const _slotLabels = {
    'hero': 'Hero image',
    'banner1': 'New Arrivals banner',
    'banner2': 'Best Sellers banner',
    'banner3': 'Special Offers banner',
    'split_layout': 'Split-layout image',
  };

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _images;
  Map<String, dynamic>? _quota;
  String? _regeneratingSlot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getHomepageImages();
      if (!r.success) throw StateError(r.error?.message ?? 'Failed to load');
      final data = r.data is Map<String, dynamic>
          ? r.data as Map<String, dynamic>
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _images = data['images'] is Map ? Map<String, dynamic>.from(data['images']) : {};
        _quota = data['quota'] is Map ? Map<String, dynamic>.from(data['quota']) : {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  String? _imageForSlot(String slot) {
    final images = _images;
    if (images == null) return null;
    final key = slot == 'split_layout' ? 'splitLayout' : slot;
    final value = images[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<void> _regenerate(String slot) async {
    setState(() => _regeneratingSlot = slot);
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.regenerateHomepageImage(slot);
      if (!r.success) throw StateError(r.error?.message ?? 'Regeneration failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New image generated and applied to your homepage.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _regeneratingSlot = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ApiErrorView(error: _error!, onRetry: _load);
    }

    final quota = _quota ?? {};
    final allowed = quota['allowed'] == true;
    final current = quota['current'] is int ? quota['current'] as int : 0;
    final limit = quota['limit'] is int ? quota['limit'] as int : null;
    final remaining = limit != null ? (limit - current).clamp(0, limit) : null;
    final homepageFound = _images?['homepageFound'] == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'These 5 AI-generated images were created automatically for your store. Regenerate any one of them individually if you\'d like a different look.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (allowed)
          Text(
            remaining != null
                ? '$remaining of $limit regeneration${limit == 1 ? '' : 's'} remaining this month.'
                : 'Unlimited regenerations on your plan.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Text(
            (quota['reason'] as String?) ?? "You've used all your regenerations for this month.",
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        if (!homepageFound) ...[
          const SizedBox(height: 4),
          Text(
            'No homepage sections were found to preview yet — regenerating will still create a real image.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        for (final slot in _slots) ...[
          _HomepageImageCard(
            label: _slotLabels[slot]!,
            imageUrl: _imageForSlot(slot),
            regenerating: _regeneratingSlot == slot,
            disabled: _regeneratingSlot != null || !allowed,
            onRegenerate: () => _regenerate(slot),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HomepageImageCard extends StatelessWidget {
  const _HomepageImageCard({
    required this.label,
    required this.imageUrl,
    required this.regenerating,
    required this.disabled,
    required this.onRegenerate,
  });

  final String label;
  final String? imageUrl;
  final bool regenerating;
  final bool disabled;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.ghostBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 96,
                height: 64,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.surfaceContainerLow,
                          child: const Icon(Icons.image_not_supported_outlined, size: 20),
                        ),
                      )
                    : Container(
                        color: AppTheme.surfaceContainerLow,
                        child: const Icon(Icons.image_not_supported_outlined, size: 20),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      onPressed: disabled ? null : onRegenerate,
                      icon: regenerating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(
                        regenerating ? 'Regenerating... (~15s)' : 'Regenerate',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
