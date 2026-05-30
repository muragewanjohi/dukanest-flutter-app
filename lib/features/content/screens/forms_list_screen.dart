import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';

class FormsListScreen extends ConsumerStatefulWidget {
  const FormsListScreen({super.key});

  @override
  ConsumerState<FormsListScreen> createState() => _FormsListScreenState();
}

class _FormsListScreenState extends ConsumerState<FormsListScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getForms(
        page: page,
        limit: 20,
        search: _search.text.trim(),
      );
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
      final raw = bag['items'] ?? root['items'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      final pg = root['pagination'];
      final pMap =
          pg is Map ? Map<String, dynamic>.from(pg) : const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _items = list;
        _page = page;
        _totalPages = (pMap['totalPages'] ?? pMap['total_pages'] ?? 1) is int
            ? (pMap['totalPages'] ?? pMap['total_pages']) as int
            : int.tryParse(
                    '${pMap['totalPages'] ?? pMap['total_pages'] ?? 1}') ??
                1;
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
    for (final k in ['id', '_id']) {
      final v = m[k];
      if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Forms',
        showDivider: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/forms/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search forms',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _load(page: 1),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(page: _page),
              child: _loading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!, textAlign: TextAlign.center),
                        )
                      : ListView.builder(
                          itemCount: _items.length + (_totalPages > 1 ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= _items.length) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: _page > 1 && !_loading
                                        ? () => _load(
                                              page: _page - 1,
                                            )
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Text('$_page / $_totalPages'),
                                  IconButton(
                                    onPressed: _page < _totalPages && !_loading
                                        ? () => _load(
                                              page: _page + 1,
                                            )
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              );
                            }
                            final row = _items[i];
                            final id = _id(row);
                            final title =
                                '${row['name'] ?? row['title'] ?? 'Form'}';
                            return ListTile(
                              title: Text(title),
                              subtitle: Text(id),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                if (id.isEmpty) return;
                                context.push(
                                  '/forms/${Uri.encodeComponent(id)}/edit',
                                );
                              },
                              onLongPress: () {
                                if (id.isEmpty) return;
                                context.push(
                                  '/forms/${Uri.encodeComponent(id)}/submissions',
                                );
                              },
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
