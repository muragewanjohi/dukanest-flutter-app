import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
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
        _error = '$e';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
    extends ConsumerState<ThemeCustomizationScreen> {
  final _jsonCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

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
        _error = '$e';
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
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Customize theme',
        showDivider: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _loading
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
    );
  }
}
