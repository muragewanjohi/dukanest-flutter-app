import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';

class ThemesScreen extends ConsumerStatefulWidget {
  const ThemesScreen({super.key});

  @override
  ConsumerState<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends ConsumerState<ThemesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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
      final r = await api.getThemes();
      if (!r.success) throw StateError(r.error?.message ?? 'Failed');
      final payload = r.data;
      final root =
          payload is Map<String, dynamic> ? payload : <String, dynamic>{};
      final nested = root['data'];
      final bag = nested is Map<String, dynamic>
          ? nested
          : nested is Map
              ? Map<String, dynamic>.from(nested)
              : root;
      final raw = bag['items'] ?? bag['themes'] ?? root['items'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _items = list;
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

  String _id(Map<String, dynamic> m) {
    for (final k in ['id', '_id', 'themeId']) {
      final v = m[k];
      if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
    }
    return '';
  }

  Future<void> _install(Map<String, dynamic> row) async {
    final id = _id(row);
    if (id.isEmpty) return;
    try {
      final r = await ref.read(apiClientProvider).installTheme({
        'themeId': id,
      });
      if (!r.success) throw StateError(r.error?.message ?? 'Install failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Theme installed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final row = _items[i];
                      final name =
                          '${row['name'] ?? row['title'] ?? 'Theme'}';
                      final thumb =
                          '${row['thumbnail'] ?? row['previewUrl'] ?? row['image'] ?? ''}';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: thumb.isEmpty
                              ? const Icon(Icons.palette_outlined)
                              : SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    child:
                                        CachedNetworkImage(
                                      imageUrl: thumb,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                          title: Text(name),
                          subtitle: Text(_id(row)),
                          trailing: FilledButton(
                            onPressed: () => _install(row),
                            child: const Text('Install'),
                          ),
                        ),
                      );
                    },
                  ),
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
      _jsonCtrl.text =
          const JsonEncoder.withIndent('  ').convert(m);
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
      final r =
          await ref.read(apiClientProvider).updateCurrentTheme(parsed);
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
