import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../../../core/widgets/dashboard_page_header.dart';

/// Lists and manages `GET/POST/DELETE /dashboard/analytics/scheduled-reports`.
class ScheduledReportsScreen extends ConsumerStatefulWidget {
  const ScheduledReportsScreen({super.key});

  @override
  ConsumerState<ScheduledReportsScreen> createState() =>
      _ScheduledReportsScreenState();
}

class _ScheduledReportsScreenState
    extends ConsumerState<ScheduledReportsScreen> {
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
      final r = await api.getScheduledReports();
      if (!r.success) {
        throw StateError(r.error?.message ?? 'Failed to load reports');
      }
      final payload = r.data;
      final root =
          payload is Map<String, dynamic> ? payload : <String, dynamic>{};
      final nested = root['data'];
      final bag = nested is Map<String, dynamic>
          ? nested
          : nested is Map
              ? Map<String, dynamic>.from(nested)
              : root;
      final raw = bag['items'] ?? bag['reports'] ?? root['items'];
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
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _createReport() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => const _ScheduledReportDialog(),
    );
    if (result == null || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      final emailsRaw = (result['emailRecipients'] ?? '').trim();
      final body = <String, dynamic>{
        'reportType': result['reportType']!.trim(),
        'frequency': result['frequency']!.trim(),
        'format': result['format']!.trim(),
        if (emailsRaw.isNotEmpty)
          'emailRecipients': emailsRaw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
      };
      final r = await api.createScheduledReport(body);
      if (!r.success) throw StateError(r.error?.message ?? 'Create failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheduled report created')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> _deleteReport(Map<String, dynamic> row) async {
    final id = '${row['id'] ?? row['_id'] ?? row['scheduleId'] ?? ''}'.trim();
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete scheduled report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final r = await ref.read(apiClientProvider).deleteScheduledReport(id);
      if (!r.success) throw StateError(r.error?.message ?? 'Delete failed');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createReport,
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Schedule report'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8 + MediaQuery.paddingOf(context).top,
                  16,
                  16,
                ),
                child: DashboardPageHeader(
                  title: 'Scheduled reports',
                  subtitle:
                      'Automatic exports sent to your team on a fixed cadence.',
                  leading: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  ),
                  storeNameOverride: 'Analytics',
                  actions: [
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No scheduled reports yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final row = _items[i];
                    final title =
                        '${row['reportType'] ?? row['type'] ?? 'Report'}';
                    final freq =
                        '${row['frequency'] ?? row['schedule'] ?? '—'}';
                    final fmt = '${row['format'] ?? 'csv'}';
                    return ListTile(
                      title: Text(title),
                      subtitle: Text('$freq • $fmt'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteReport(row),
                      ),
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

class _ScheduledReportDialog extends StatefulWidget {
  const _ScheduledReportDialog();

  @override
  State<_ScheduledReportDialog> createState() => _ScheduledReportDialogState();
}

class _ScheduledReportDialogState extends State<_ScheduledReportDialog> {
  final _type = TextEditingController(text: 'revenue');
  final _frequency = TextEditingController(text: 'weekly');
  final _emails = TextEditingController();
  String _format = 'csv';

  @override
  void dispose() {
    _type.dispose();
    _frequency.dispose();
    _emails.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New scheduled report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _type,
              decoration: const InputDecoration(labelText: 'Report type'),
            ),
            TextField(
              controller: _frequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                helperText: 'e.g. daily, weekly, monthly',
              ),
            ),
            TextField(
              controller: _emails,
              decoration: const InputDecoration(
                labelText: 'Email recipients',
                helperText: 'Comma-separated addresses',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _format,
              decoration: const InputDecoration(labelText: 'Format'),
              items: const [
                DropdownMenuItem(value: 'csv', child: Text('CSV')),
                DropdownMenuItem(value: 'json', child: Text('JSON')),
              ],
              onChanged: (v) => setState(() => _format = v ?? 'csv'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_type.text.trim().isEmpty || _frequency.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(context, {
              'reportType': _type.text,
              'frequency': _frequency.text,
              'emailRecipients': _emails.text,
              'format': _format,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
