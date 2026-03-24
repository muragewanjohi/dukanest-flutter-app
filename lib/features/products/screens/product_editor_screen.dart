import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Add / edit product — opened from Product Management or FAB (Stitch: Add/Edit Product).
class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({
    super.key,
    this.initialSku,
  });

  final String? initialSku;

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  static final Map<String, ({String name, String sku, String price, String stock, String category})> _demo = {
    'VN-2024-RD': (name: 'Velocity Nitro Runner', sku: 'VN-2024-RD', price: '129.00', stock: '124', category: 'Footwear'),
    'MW-SL-01': (name: 'Minimalist Slate Watch', sku: 'MW-SL-01', price: '85.50', stock: '42', category: 'Accessories'),
    'SPW-BLK-99': (name: 'Studio Pro Wireless', sku: 'SPW-BLK-99', price: '199.00', stock: '0', category: 'Electronics'),
    'GA-GLD-45': (name: 'Golden Aviators', sku: 'GA-GLD-45', price: '45.00', stock: '5', category: 'Accessories'),
  };

  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _category;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final p = widget.initialSku != null ? _demo[widget.initialSku!] : null;
    _name = TextEditingController(text: p?.name ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _price = TextEditingController(text: p?.price ?? '');
    _stock = TextEditingController(text: p?.stock ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _description = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    _stock.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initialSku == null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(isNew ? 'Add Product' : 'Edit Product'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.camera_alt_outlined),
              title: Text('Product Photo'),
              subtitle: Text('Tap to capture or upload image'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Product Name')),
          const SizedBox(height: 12),
          TextField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU')),
          const SizedBox(height: 12),
          TextField(controller: _price, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: _stock, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
          const SizedBox(height: 12),
          TextField(controller: _description, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => context.pop(), child: Text(isNew ? 'Save Product' : 'Save changes')),
        ],
      ),
    );
  }
}
