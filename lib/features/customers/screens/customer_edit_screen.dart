import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_page_header.dart';
import '../providers/customer_detail_provider.dart';

/// PATCH customer profile. Email is read-only per API contract.
class CustomerEditScreen extends ConsumerWidget {
  const CustomerEditScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncDetail = ref.watch(customerDetailProvider(customerId));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(customerDetailProvider(customerId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => _CustomerEditForm(
          customerId: customerId,
          initialData: data,
          ref: ref,
          theme: theme,
        ),
      ),
    );
  }
}

class _CustomerEditForm extends StatefulWidget {
  const _CustomerEditForm({
    required this.customerId,
    required this.initialData,
    required this.ref,
    required this.theme,
  });

  final String customerId;
  final Map<String, dynamic> initialData;
  final WidgetRef ref;
  final ThemeData theme;

  @override
  State<_CustomerEditForm> createState() => _CustomerEditFormState();
}

class _CustomerEditFormState extends State<_CustomerEditForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _phoneCountryController;
  bool _saving = false;

  static String _pick(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameController = TextEditingController(
      text:
          _pick(d, ['name', 'fullName', 'full_name', 'displayName', 'display_name']),
    );
    _phoneController = TextEditingController(
      text: _pick(d, ['phone', 'phoneNumber', 'phone_number', 'mobile']),
    );
    final cc = _pick(d, ['phoneCountry', 'phone_country']);
    _phoneCountryController =
        TextEditingController(text: cc.isEmpty ? '+254' : cc);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phoneCountryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        if (_nameController.text.trim().isNotEmpty)
          'name': _nameController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty)
          'phone': _phoneController.text.trim(),
        if (_phoneCountryController.text.trim().isNotEmpty)
          'phone_country': _phoneCountryController.text.trim(),
      };

      final r = await widget.ref
          .read(apiClientProvider)
          .updateCustomer(widget.customerId, body);
      if (!r.success) {
        throw Exception(r.error?.message ?? 'Update failed');
      }
      widget.ref.invalidate(customerDetailProvider(widget.customerId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer updated')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _email => _pick(widget.initialData, ['email']);

  InputDecoration _input(String? hint) {
    final theme = widget.theme;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final emailShown =
        _email.isEmpty ? '(no email on record)' : _email;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8 + MediaQuery.paddingOf(context).top,
        16,
        120,
      ),
      children: [
        DashboardPageHeader(
          title: 'Edit customer',
          leading: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerLow,
            ),
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Email cannot be changed from the app.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text('Email',
            style:
                theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          child: SelectableText(
            emailShown,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Name',
          child: TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: _input('Customer name'),
          ),
        ),
        const SizedBox(height: 14),
        _LabeledField(
          label: 'Phone country (E.164 prefix)',
          child: TextField(
            controller: _phoneCountryController,
            decoration: _input('+254'),
            keyboardType: TextInputType.phone,
          ),
        ),
        const SizedBox(height: 14),
        _LabeledField(
          label: 'Phone',
          child: TextField(
            controller: _phoneController,
            decoration: _input('7XX XXX XXX'),
            keyboardType: TextInputType.phone,
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Save changes',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style:
                theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
