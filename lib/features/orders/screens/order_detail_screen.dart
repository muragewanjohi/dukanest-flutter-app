import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Order detail — opened from Order Fulfillment list (Stitch: Order Details).
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderKey,
  });

  final String orderKey;

  static final Map<String, _OrderDetailData> _demo = {
    'DK-9821': _OrderDetailData(
      code: 'DK-9821',
      date: 'Oct 24, 2025 • 10:45 AM',
      customer: 'Sarah Jenkins',
      email: 'sarah.j@email.com',
      status: 'Pending',
      itemLine: '3 Items • \$142.00',
      items: [
        ('Organic Coffee Beans', '×2', '\$48.00'),
        ('Almond Milk 1L', '×1', '\$12.00'),
        ('Reusable Tote', '×1', '\$82.00'),
      ],
    ),
    'DK-9819': _OrderDetailData(
      code: 'DK-9819',
      date: 'Oct 24, 2025 • 09:12 AM',
      customer: 'Marcus Thorne',
      email: 'marcus.t@email.com',
      status: 'Paid',
      itemLine: '1 Item • \$89.50',
      items: [('Minimalist Slate Watch', '×1', '\$89.50')],
    ),
    'DK-9815': _OrderDetailData(
      code: 'DK-9815',
      date: 'Oct 23, 2025 • 04:30 PM',
      customer: 'Elena Rodriguez',
      email: 'elena.r@email.com',
      status: 'Shipped',
      itemLine: '5 Items • \$320.15',
      items: [
        ('Studio Pro Wireless', '×2', '\$398.00'),
      ],
    ),
    'DK-9810': _OrderDetailData(
      code: 'DK-9810',
      date: 'Oct 23, 2025 • 11:15 AM',
      customer: 'David Kim',
      email: 'david.k@email.com',
      status: 'Pending',
      itemLine: '2 Items • \$45.00',
      items: [('Golden Aviators', '×2', '\$45.00')],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final data = _demo[orderKey] ?? _OrderDetailData(
          code: orderKey,
          date: '',
          customer: 'Customer',
          email: '',
          status: 'Pending',
          itemLine: '',
          items: const [],
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Order #${data.code}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(data.date, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(data.customer, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(data.email, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Chip(label: Text(data.status)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order summary', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(data.itemLine),
                  const SizedBox(height: 12),
                  ...data.items.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(line.$1)),
                          Text(line.$2),
                          const SizedBox(width: 12),
                          Text(line.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Update status')),
              OutlinedButton(onPressed: () {}, child: const Text('Share invoice')),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderDetailData {
  const _OrderDetailData({
    required this.code,
    required this.date,
    required this.customer,
    required this.email,
    required this.status,
    required this.itemLine,
    required this.items,
  });

  final String code;
  final String date;
  final String customer;
  final String email;
  final String status;
  final String itemLine;
  final List<(String, String, String)> items;
}
