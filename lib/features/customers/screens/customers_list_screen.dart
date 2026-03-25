import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../demo/demo_data.dart';

/// Customer Directory — Stitch: header, search row, chips, bordered cards.
class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  String _query = '';
  int _chip = 0;

  Iterable<DemoCustomer> get _visible {
    if (_query.trim().isEmpty) return demoCustomers;
    final q = _query.toLowerCase();
    return demoCustomers.where(
      (c) => c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/more');
    }
  }

  void _showCustomerSheet(DemoCustomer c) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(_initials(c.name), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        Text(c.email, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _SheetStat(label: 'Orders', value: '${c.orderCount}')),
                  Expanded(child: _SheetStat(label: 'Lifetime value', value: c.totalSpent)),
                ],
              ),
              const SizedBox(height: 12),
              Text('Last order · ${c.lastOrder}', style: theme.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible.toList();
    final chips = ['All Customers', 'VIP Customers', 'Repeat Buyers', 'New This Month'];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => _goBack(context),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/images/logo_with_name.png',
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(height: 28, width: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Customers',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search customer name...',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final sel = _chip == i;
                return Material(
                  color: sel ? AppTheme.primary : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: () => setState(() => _chip = i),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(
                        chips[i],
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: sel ? Colors.white : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(child: Text('No matches for "$_query".', style: theme.textTheme.bodyLarge)),
            )
          else
            ...List.generate(visible.length, (index) {
              final c = visible[index];
              final highlight = index == 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _showCustomerSheet(c),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: highlight
                            ? const Border(left: BorderSide(color: AppTheme.primary, width: 4))
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                            child: Text(
                              _initials(c.name),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppTheme.primaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                Text(c.email, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryDark),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SheetStat extends StatelessWidget {
  const _SheetStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
