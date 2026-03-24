import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Edit Sale — Stitch: Sales Editor.
class SalesEditorScreen extends StatefulWidget {
  const SalesEditorScreen({super.key});

  @override
  State<SalesEditorScreen> createState() => _SalesEditorScreenState();
}

class _SalesEditorScreenState extends State<SalesEditorScreen> {
  late List<_SaleProduct> _products;

  final _saleName = TextEditingController(text: 'Summer Flash Sale');
  final _startDate = TextEditingController(text: 'Jun 1, 2025');
  final _endDate = TextEditingController(text: 'Jun 15, 2025');
  final _note = TextEditingController(text: 'Focusing on top sellers for the summer clearance event.');

  @override
  void initState() {
    super.initState();
    _products = [
      _SaleProduct(name: 'Minimalist Chrono Watch', original: 120, salePriceCtrl: TextEditingController(text: '96.00')),
      _SaleProduct(name: 'Studio Wireless Gen 2', original: 299, salePriceCtrl: TextEditingController(text: '249.00')),
      _SaleProduct(name: 'CloudRun Performance', original: 85, salePriceCtrl: TextEditingController(text: '68.00')),
    ];
  }

  @override
  void dispose() {
    for (final p in _products) {
      p.salePriceCtrl.dispose();
    }
    _saleName.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _note.dispose();
    super.dispose();
  }

  void _removeProduct(int index) {
    setState(() {
      final removed = _products.removeAt(index);
      removed.salePriceCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Sale'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('General Info', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text('Step 1 of 2', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: _saleName,
            decoration: const InputDecoration(labelText: 'Sale Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _startDate,
            decoration: const InputDecoration(
              labelText: 'Start Date',
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _endDate,
            decoration: const InputDecoration(
              labelText: 'End Date',
              suffixIcon: Icon(Icons.calendar_month_outlined),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Products', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Product'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_products.length, (i) {
            final p = _products[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeProduct(i),
                        ),
                      ],
                    ),
                    Text('Original: \$${p.original.toStringAsFixed(2)}', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: p.salePriceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sale Price',
                        prefixText: '\$ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFFEDECF6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimated Revenue Impact', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('+\$4,250.00', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '12% higher than last sale campaign',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Quick Note', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add a short note for your team…',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Continue to step 2'),
          ),
        ],
      ),
    );
  }
}

class _SaleProduct {
  _SaleProduct({
    required this.name,
    required this.original,
    required this.salePriceCtrl,
  });

  final String name;
  final double original;
  final TextEditingController salePriceCtrl;
}
