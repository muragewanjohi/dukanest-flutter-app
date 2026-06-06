import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../../../core/widgets/api_error_view.dart';
import '../../../core/widgets/dashboard_page_header.dart';
import '../../../features/onboarding/providers/auth_provider.dart';
import '../providers/customer_detail_provider.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  static bool _canDeleteCustomer(String? role) {
    final r = (role ?? '').toLowerCase().trim();
    return r == 'tenant_admin' || r == 'owner';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncDetail = ref.watch(customerDetailProvider(customerId));
    final role = ref.watch(authProvider.select((s) => s.user?.role));
    final allowDelete = _canDeleteCustomer(role);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ApiErrorView(
          error: e,
          title: 'Could not load customer',
          onRetry: () => ref.invalidate(customerDetailProvider(customerId)),
        ),
        data: (raw) => _CustomerDetailBody(
          customerId: customerId,
          data: raw,
          allowDelete: allowDelete,
          onAfterEdit: () => ref.invalidate(customerDetailProvider(customerId)),
          theme: theme,
        ),
      ),
    );
  }
}

class _CustomerDetailBody extends ConsumerWidget {
  const _CustomerDetailBody({
    required this.customerId,
    required this.data,
    required this.allowDelete,
    required this.onAfterEdit,
    required this.theme,
  });

  final String customerId;
  final Map<String, dynamic> data;
  final bool allowDelete;
  final VoidCallback onAfterEdit;
  final ThemeData theme;

  static String _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString();
    }
    return '';
  }

  static int _pickInt(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
    }
    return 0;
  }

  static String _formatMoney(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return '—';
    if (raw is num) {
      final fmt = NumberFormat.currency(
        locale: 'en_KE',
        symbol: 'KES ',
        decimalDigits: raw % 1 == 0 ? 0 : 2,
      );
      return fmt.format(raw.toDouble());
    }
    return raw.toString();
  }

  static String _formatDate(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return '—';
    DateTime? d;
    if (raw is String) d = DateTime.tryParse(raw);
    if (raw is int) {
      final ms = raw < 20000000000 ? raw * 1000 : raw;
      d = DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (d == null) return raw.toString();
    return DateFormat.yMMMd().add_jm().format(d.toLocal());
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete customer?'),
        content: const Text(
          'This permanently removes this customer profile. Orders may remain linked in reports.',
        ),
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
    if (ok != true || !context.mounted) return;
    try {
      final r = await ref.read(apiClientProvider).deleteCustomer(customerId);
      if (!r.success) {
        throw Exception(r.error?.message ?? 'Delete failed');
      }
      if (!context.mounted) return;
      ref.invalidate(customerDetailProvider(customerId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer deleted')),
      );
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = _pickString(
        data, ['name', 'fullName', 'full_name', 'displayName', 'display_name']);
    final email = _pickString(data, ['email']);
    final phone =
        _pickString(data, ['phone', 'phoneNumber', 'phone_number', 'mobile']);
    final orders = _pickInt(
        data, ['orderCount', 'ordersCount', 'totalOrders', 'total_orders']);
    final spentRaw = data['totalSpent'] ??
        data['lifetimeValue'] ??
        data['total_spent'] ??
        data['lifetime_value'];
    final avgRaw =
        data['averageOrderValue'] ?? data['average_order_value'] ?? data['aov'];

    final lastOrder =
        data['lastOrderAt'] ?? data['last_order_at'] ?? data['lastOrder'];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerDetailProvider(customerId));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          8 + MediaQuery.paddingOf(context).top,
          16,
          32,
        ),
        children: [
          DashboardPageHeader(
            title: name.isEmpty ? 'Customer' : name,
            leading: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerLow,
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/customers');
                }
              },
            ),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  await context.push<bool>(
                      '/customers/edit/${Uri.encodeComponent(customerId)}');
                  onAfterEdit();
                },
              ),
              if (allowDelete)
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  onPressed: () => _confirmDelete(context, ref),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (email.isNotEmpty)
            Text(
              email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              phone,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _AggregateCard(
                  label: 'Orders',
                  value: '$orders',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AggregateCard(
                  label: 'Lifetime value',
                  value: _formatMoney(spentRaw),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AggregateCard(
                  label: 'Avg. order',
                  value: avgRaw != null ? _formatMoney(avgRaw) : '—',
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AggregateCard(
                  label: 'Last order',
                  value: _formatDate(lastOrder),
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 10),
          _InfoTile(
              label: 'Customer ID',
              value: customerId.isNotEmpty ? customerId : '(missing id)',
              monospace: true),
          if (_pickString(data, ['createdAt', 'created_at']).isNotEmpty)
            _InfoTile(
              label: 'Joined',
              value: _formatDate(data['createdAt'] ?? data['created_at']),
            ),
          if (_pickString(data, ['notes', 'internal_notes']).isNotEmpty)
            _InfoTile(
              label: 'Notes',
              value: _pickString(data, ['notes', 'internal_notes']),
            ),
        ],
      ),
    );
  }
}

class _AggregateCard extends StatelessWidget {
  const _AggregateCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: monospace ? 'monospace' : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
