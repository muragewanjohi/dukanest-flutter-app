import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../../../core/widgets/dashboard_app_bar.dart';

class FormSubmissionsScreen extends ConsumerStatefulWidget {
  const FormSubmissionsScreen({super.key, required this.formId});

  final String formId;

  @override
  ConsumerState<FormSubmissionsScreen> createState() =>
      _FormSubmissionsScreenState();
}

class _FormSubmissionsScreenState extends ConsumerState<FormSubmissionsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int _page = 1;

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
      final r = await api.getFormSubmissions(
        widget.formId,
        page: page,
        limit: 20,
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
      final raw = bag['items'] ?? bag['submissions'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _items = list;
        _page = page;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: 'Submissions',
        showDivider: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(page: _page),
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                      Center(
                        child: FilledButton(
                          onPressed: () => _load(page: 1),
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _items.length + (_page > 1 ? 3 : 2),
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Back to form editor'),
                          ),
                        );
                      }
                      if (_page > 1 && i == 1) {
                        return TextButton.icon(
                          onPressed: () => _load(page: _page - 1),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Previous page'),
                        );
                      }
                      final idx = _page > 1 ? i - 2 : i - 1;
                      if (idx >= _items.length) {
                        if (_items.length >= 20) {
                          return TextButton.icon(
                            onPressed: () => _load(page: _page + 1),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next page'),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      final row = _items[idx];
                      final pretty =
                          const JsonEncoder.withIndent('  ').convert(row);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            pretty,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
