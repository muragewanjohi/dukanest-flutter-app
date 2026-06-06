import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../../../core/widgets/dashboard_app_bar.dart';

class FormEditorScreen extends ConsumerStatefulWidget {
  const FormEditorScreen({super.key, this.formId});

  final String? formId;

  bool get isCreate => formId == null || formId!.isEmpty;

  @override
  ConsumerState<FormEditorScreen> createState() => _FormEditorScreenState();
}

class _FormEditorScreenState extends ConsumerState<FormEditorScreen> {
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (widget.isCreate) {
      setState(() => _loading = false);
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getForm(widget.formId!);
      if (!r.success) throw StateError(r.error?.message ?? 'Failed');
      final payload = r.data;
      final root =
          payload is Map<String, dynamic> ? payload : <String, dynamic>{};
      final nested = root['data'] ?? root['form'];
      final m = nested is Map<String, dynamic>
          ? nested
          : nested is Map
              ? Map<String, dynamic>.from(nested)
              : root;
      _nameCtrl.text = '${m['name'] ?? m['title'] ?? ''}'.trim();
      _slugCtrl.text = '${m['slug'] ?? ''}'.trim();
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
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        if (_slugCtrl.text.trim().isNotEmpty) 'slug': _slugCtrl.text.trim(),
      };
      if (widget.isCreate) {
        final r = await api.createForm(body);
        if (!r.success) throw StateError(r.error?.message ?? 'Create failed');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form created')),
        );
        context.pop(true);
      } else {
        final r = await api.updateForm(widget.formId!, body);
        if (!r.success) throw StateError(r.error?.message ?? 'Save failed');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.isCreate) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete form?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final r = await ref.read(apiClientProvider).deleteForm(widget.formId!);
      if (!r.success) throw StateError(r.error?.message ?? 'Delete failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted')),
      );
      context.pop(true);
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
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final title = widget.isCreate ? 'New form' : 'Edit form';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: title,
        showDivider: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Form name',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _slugCtrl,
            decoration: const InputDecoration(
              labelText: 'Slug (optional)',
            ),
          ),
          const SizedBox(height: 24),
          if (!widget.isCreate && widget.formId != null)
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () => context.push(
                        '/forms/${Uri.encodeComponent(widget.formId!)}/submissions',
                      ),
              icon: const Icon(Icons.inbox_outlined),
              label: const Text('View submissions'),
            ),
          if (!widget.isCreate) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              label: const Text('Delete form'),
            ),
          ],
        ],
      ),
    );
  }
}
