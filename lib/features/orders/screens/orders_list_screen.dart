import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';

/// Order Fulfillment — Stitch layout (metrics, chips, order cards, processing goal).
class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  int _filterIndex = 0;

  static String _orderKeyFromId(String raw) {
    final match = RegExp(r'#([A-Z]+-\d+)').firstMatch(raw);
    return match?.group(1) ?? raw.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ['All Orders', 'Pending', 'Paid', 'Shipped'];
    final orders = <({
      String idLine,
      String date,
      String customer,
      String status,
      String detail,
    })>[
      (
        idLine: 'ORDER #DK-9821',
        date: 'Oct 24, 10:45 AM',
        customer: 'Sarah Jenkins',
        status: 'Pending',
        detail: '3 Items • \$142.00',
      ),
      (
        idLine: 'ORDER #DK-9819',
        date: 'Oct 24, 09:12 AM',
        customer: 'Marcus Thorne',
        status: 'Paid',
        detail: '1 Item • \$89.50',
      ),
      (
        idLine: 'ORDER #DK-9815',
        date: 'Oct 23, 04:30 PM',
        customer: 'Elena Rodriguez',
        status: 'Shipped',
        detail: '5 Items • \$320.15',
      ),
      (
        idLine: 'ORDER #DK-9810',
        date: 'Oct 23, 11:15 AM',
        customer: 'David Kim',
        status: 'Pending',
        detail: '2 Items • \$45.00',
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 600)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 20)),
                const SizedBox(width: 10),
                Text(
                  'DukaNest',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () => context.push('/notifications'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Order Fulfillment',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Manage and process your store's incoming orders.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: _MetricCardActiveToday(value: '24')),
                SizedBox(width: 10),
                Expanded(child: _MetricCardPendingShipment(value: '08')),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = _filterIndex == index;
                  return _FilterChip(
                    label: filters[index],
                    selected: selected,
                    onTap: () => setState(() => _filterIndex = index),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SearchBar(
              hintText: 'Search orders...',
              leading: const Icon(Icons.search),
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(Colors.white),
              side: WidgetStateProperty.all(
                BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            ...orders.map((order) {
              final key = _orderKeyFromId(order.idLine);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OrderCard(
                  idLine: order.idLine,
                  date: order.date,
                  customer: order.customer,
                  status: order.status,
                  detail: order.detail,
                  accentLeft: order.status == 'Pending',
                  onOpen: () => context.push('/orders/detail/${Uri.encodeComponent(key)}'),
                ),
              );
            }),
            const SizedBox(height: 8),
            const _ProcessingGoalCard(),
            const SizedBox(height: 12),
            const _QuickActionsCard(),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? AppTheme.primaryDark : const Color(0xFFE8E8ED),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : const Color(0xFF1B1C1C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Stitch: Active Today — surface-container-low, label on-surface-variant, value primary.
class _MetricCardActiveToday extends StatelessWidget {
  const _MetricCardActiveToday({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE TODAY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stitch: Pending Shipment — primary-container/10, label & value primary tones.
class _MetricCardPendingShipment extends StatelessWidget {
  const _MetricCardPendingShipment({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PENDING SHIPMENT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.idLine,
    required this.date,
    required this.customer,
    required this.status,
    required this.detail,
    required this.accentLeft,
    required this.onOpen,
  });

  final String idLine;
  final String date;
  final String customer;
  final String status;
  final String detail;
  final bool accentLeft;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (accentLeft) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 4,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            idLine.toUpperCase(),
                            style: metaStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(date, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      customer,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatusPill(status: status),
                        Text(
                          detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _ChevronButton(onTap: onOpen),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = switch (status) {
      'Pending' => (theme.colorScheme.errorContainer, theme.colorScheme.onErrorContainer),
      'Paid' => (const Color(0xFFDFE0FF), const Color(0xFF0A2ACF)),
      'Shipped' => (theme.colorScheme.surfaceContainerHigh, theme.colorScheme.onSurfaceVariant),
      _ => (const Color(0xFFF0F0F0), theme.colorScheme.onSurfaceVariant),
    };

    final label = status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.primaryDark,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ProcessingGoalCard extends StatelessWidget {
  const _ProcessingGoalCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 120,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Processing Goal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '75%',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: 0.75,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You\'ve processed 18 out of 24 orders today. Keep it up to maintain your "Express Seller" badge!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK ACTIONS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          _QuickActionTile(icon: Icons.print_outlined, label: 'Bulk Print Labels', onTap: () {}),
          const SizedBox(height: 8),
          _QuickActionTile(icon: Icons.local_shipping_outlined, label: 'Mark All as Shipped', onTap: () {}),
          const SizedBox(height: 8),
          _QuickActionTile(icon: Icons.file_download_outlined, label: 'Export CSV Report', onTap: () {}),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
