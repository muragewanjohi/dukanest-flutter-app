import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OrdersListScreen extends StatelessWidget {
  const OrdersListScreen({super.key});

  static String _orderKeyFromTitle(String idLine) {
    final match = RegExp(r'#([A-Z]+-\d+)').firstMatch(idLine);
    return match?.group(1) ?? idLine.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['All Orders', 'Pending', 'Paid', 'Shipped'];
    final orders = <({String id, String date, String customer, String status, String detail})>[
      (id: 'Order #DK-9821', date: 'Oct 24, 10:45 AM', customer: 'Sarah Jenkins', status: 'Pending', detail: '3 Items • \$142.00'),
      (id: 'Order #DK-9819', date: 'Oct 24, 09:12 AM', customer: 'Marcus Thorne', status: 'Paid', detail: '1 Item • \$89.50'),
      (id: 'Order #DK-9815', date: 'Oct 23, 04:30 PM', customer: 'Elena Rodriguez', status: 'Shipped', detail: '5 Items • \$320.15'),
      (id: 'Order #DK-9810', date: 'Oct 23, 11:15 AM', customer: 'David Kim', status: 'Pending', detail: '2 Items • \$45.00'),
    ];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 600)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Text('Order Fulfillment', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text("Manage and process your store's incoming orders."),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: _MetricCard(label: 'Active Today', value: '24')),
                SizedBox(width: 10),
                Expanded(child: _MetricCard(label: 'Pending Shipment', value: '08')),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final label = filters[index];
                  final isSelected = index == 0;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) {},
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const SearchBar(
              hintText: 'Search orders...',
              leading: Icon(Icons.search),
            ),
            const SizedBox(height: 12),
            ...List.generate(orders.length, (index) {
              final order = orders[index];
              final key = _orderKeyFromTitle(order.id);
              final color = switch (order.status) {
                'Pending' => Colors.orange,
                'Paid' => Colors.green,
                'Delivered' => Colors.teal,
                'Shipped' => Colors.blue,
                _ => Colors.grey,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    onTap: () => context.push('/orders/detail/${Uri.encodeComponent(key)}'),
                    title: Text('${order.id} ${order.date}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(order.customer, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(order.detail),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Chip(
                          label: Text(order.status),
                          side: BorderSide(color: color.withValues(alpha: 0.5)),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Processing Goal', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(value: 0.75),
                    const SizedBox(height: 8),
                    Text(
                      '75%\nYou\'ve processed 18 out of 24 orders today.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Card(child: ListTile(leading: Icon(Icons.print), title: Text('Bulk Print Labels'))),
            const Card(child: ListTile(leading: Icon(Icons.local_shipping), title: Text('Mark All as Shipped'))),
            const Card(child: ListTile(leading: Icon(Icons.file_download_outlined), title: Text('Export CSV Report'))),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
