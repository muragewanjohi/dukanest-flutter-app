import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';

/// Add/Edit Product — Stitch: Add/Edit Product (Updated Nav & Sales).
class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({
    super.key,
    this.initialSku,
  });

  final String? initialSku;

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductDemo {
  const _ProductDemo({
    required this.name,
    required this.sku,
    required this.regularKes,
    required this.saleKes,
    required this.stock,
    required this.category,
    required this.description,
    this.imageUrl,
  });

  final String name;
  final String sku;
  final String regularKes;
  final String saleKes;
  final String stock;
  final String category;
  final String description;
  final String? imageUrl;
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  static const _stitchHeroImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuD0k9iZr9_nIhg0l_WEMnasUNYScknwKwxyz2tDE2DTOWu5ZjLFyLHn4iwm7yvZUiVJ3_EGxj8QXV5JWoCExk17vTO03OuVVJGaDkK_b0Fv1EAHEIlKvFNpsYWgZFqtHSF0ezvqM1SSXHgVfwXrY6179eYYhaQ4gDbkN7lDWGUB1GpP--UqZEvNwoXS8MMAks7fddRgCDlfcvf9Wa3tNIdYfYzkRLRsZK00uB9FDfNwzWvqho1lNAmecZ_XNi6q3N0sedPnTWk3bEUy';

  static const _imgSneaker =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBItpyh7rifhulInTnFVxDIGg-AgrcC3dNLPMXbdw1QqOBNP-rF6vjac2o8a4ZxGE5iuht_h7q0yXNKub5Rm-TNJ_PSiFKpMdA54Wxnfa1i6ASERO_Hdung32CBZZVqy-kINY0JOsfm1fsgaM42KaOeFldn7sPtE0UIivsZMyG1_B9eD2q7R4ytB8bAmQ3hXU7wEEXbTza-mIpaY1YIiEOARaf61fVunRr4wtJNDHF096AEFOjVZGl4VXJunIdlDvTFIaPahiBAc9GG';
  static const _imgWatch =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuC0ei8XqCEmV8Zsq5Lv3E9w-dqx_f9FBaGX_NtmPyGDvsbqMO5w26wmb4DwQKtMNn8G7BAdrz1q74g1Kto-2e7h5rUwiAWhFrIZcQtztnqm9iI6X3D0Iv6TyjU_zPNWQxpotj7e5bndssIZsXOago1HETIinyDA3QAA2YT4O4P-6tBHmdeFPgrls1GNhErRK4XHE_KME8qkXjv4FsJCm7onxa0xF2uWrybLUks7O1yBZOFXePKNpP7frYkKFTZVtFXiFBKQ9rJ1NGiK';
  static const _imgHeadphones =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuD9cWmwiE-_lsX7IB3rEswMD2xUB-QYYIvTSR8jPsKAnxUdlperQpbtwgC2fzrRrSLFT6gHVTY4d1mKcgcsfMWE68jvOEQLbhz-19GYfd3EygJ5wHRMf0x0TqfrkpCFQNEA2dGov2KgaKcVcyc8Zr-JRBVwidom5CIfH_w3DSg3R4xmMKL3z0L7TSgqzaGh8eP-xIHOLjc-bPvG_iKrshB9CCskI8ZZQlUzsVUJ5KYYi46dmmWgtiTjLnyy3SP4GUEf4SjCq2-XY0eT';
  static const _imgAviators =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDuRZSDgVO8zLQfz9qgW7UgcfYppVXgR1YjV6lvUHp6lEtQrB3shE4GKMQecGWG-TG1t5CHFNEHhdR3eMTlqzXO0omYY2-4s4UZjJU2xjXJWud6xyyq7A41Q9jwgeYb2uiF27phDBDx1n2ZyoKax62T3Orl3-Ih5LuM4thz5K9QYR7AcQx84RnXhloSoWU8J3eJyGooJwggfD81exp9XUtokbVsipUDp8fHK9P5eqhCYjIYpjQqcfuBAnJBbtnD5CbXSn2hivnU3oT3';

  static final Map<String, _ProductDemo> _demo = {
    'VN-2024-RD': _ProductDemo(
      name: 'Velocity Nitro Runner',
      sku: 'VN-2024-RD',
      regularKes: '15,200',
      saleKes: '12,900',
      stock: '124',
      category: 'Fashion',
      description:
          'Lightweight performance runner with responsive cushioning and breathable mesh upper. Ideal for daily training.',
      imageUrl: _imgSneaker,
    ),
    'MW-SL-01': _ProductDemo(
      name: 'Minimalist Slate Watch',
      sku: 'MW-SL-01',
      regularKes: '9,800',
      saleKes: '8,200',
      stock: '42',
      category: 'Fashion',
      description: 'Slim profile, sapphire glass, and a precision quartz movement.',
      imageUrl: _imgWatch,
    ),
    'SPW-BLK-99': _ProductDemo(
      name: 'Studio Pro Wireless',
      sku: 'SPW-BLK-99',
      regularKes: '24,500',
      saleKes: '21,000',
      stock: '0',
      category: 'Electronics',
      description: 'Active noise cancellation and 30-hour battery life.',
      imageUrl: _imgHeadphones,
    ),
    'GA-GLD-45': _ProductDemo(
      name: 'Golden Aviators',
      sku: 'GA-GLD-45',
      regularKes: '5,400',
      saleKes: '4,500',
      stock: '5',
      category: 'Fashion',
      description: 'UV400 lenses with lightweight metal frame.',
      imageUrl: _imgAviators,
    ),
  };

  static const _categories = [
    'Bags & Accessories',
    'Electronics',
    'Fashion',
    'Home Decor',
  ];

  static const _campaigns = [
    'Summer Flash Sale 2024',
    'Weekend Clearance',
    'New Arrival Promo',
  ];

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _regularPrice;
  late final TextEditingController _salePrice;
  late final TextEditingController _sku;
  late final TextEditingController _stock;

  String _category = _categories[0];
  String? _campaign;
  bool _visible = true;
  int _photoCount = 1;

  @override
  void initState() {
    super.initState();
    final isNew = widget.initialSku == null;
    final p = widget.initialSku != null ? _demo[widget.initialSku!] : null;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(
      text: p?.description ??
          (isNew
              ? ''
              : 'Handcrafted from top-grain Italian leather. Features a spacious interior with multiple organizational pockets and a dedicated 13-inch laptop sleeve.'),
    );
    _regularPrice = TextEditingController(text: p?.regularKes ?? (isNew ? '' : '4,500'));
    _salePrice = TextEditingController(text: p?.saleKes ?? (isNew ? '' : '3,900'));
    _sku = TextEditingController(text: p?.sku ?? (isNew ? '' : 'BG-BRN-01'));
    _stock = TextEditingController(text: p?.stock ?? (isNew ? '' : '24'));
    if (p?.category != null) {
      _category = p!.category;
      if (!_categories.contains(_category)) {
        _category = _categories[0];
      }
    }
  }

  String get _heroImageUrl {
    final p = widget.initialSku != null ? _demo[widget.initialSku!] : null;
    return p?.imageUrl ?? _stitchHeroImage;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _regularPrice.dispose();
    _salePrice.dispose();
    _sku.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.initialSku == null;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.surface.withValues(alpha: 0.92),
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.primaryDark),
              onPressed: () => context.pop(),
            ),
            title: Text(
              isNew ? 'Add Product' : 'Edit Product',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  'Publish',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MediaSectionHeader(
                  title: 'Media',
                  trailing: Text(
                    '$_photoCount / 5 Photos',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 132,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _MediaThumb(
                        imageUrl: _heroImageUrl,
                        onRemove: () {
                          if (_photoCount > 1) setState(() => _photoCount--);
                        },
                      ),
                      const SizedBox(width: 12),
                      _AddPhotoButton(onTap: () {
                        if (_photoCount < 5) setState(() => _photoCount++);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _CardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LabeledField(
                        label: 'Product Name',
                        child: TextField(
                          controller: _name,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          decoration: _fieldDeco(theme, hint: 'Enter product name'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Description',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: theme.colorScheme.surfaceContainerHighest),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _FmtIcon(icon: Icons.format_bold),
                                  _FmtIcon(icon: Icons.format_italic),
                                  _FmtIcon(icon: Icons.format_list_bulleted),
                                ],
                              ),
                            ),
                            TextField(
                              controller: _description,
                              maxLines: 5,
                              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                              decoration: InputDecoration(
                                hintText: 'Tell customers about your product...',
                                hintStyle: TextStyle(color: theme.colorScheme.outline),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Category',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _categories.contains(_category) ? _category : _categories[0],
                            isExpanded: true,
                            icon: Icon(Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
                            items: _categories
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setState(() => _category = v ?? _categories[0]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Pricing',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PriceField(
                        label: 'REGULAR PRICE',
                        controller: _regularPrice,
                        accent: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PriceField(
                        label: 'SALE PRICE',
                        controller: _salePrice,
                        accent: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _CardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Inventory',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Manage Variants',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 18, color: AppTheme.primary),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _LabeledField(
                              label: 'SKU',
                              child: TextField(
                                controller: _sku,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                decoration: _fieldDeco(theme),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LabeledField(
                              label: 'Stock',
                              child: TextField(
                                controller: _stock,
                                keyboardType: TextInputType.number,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                decoration: _fieldDeco(theme),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sales & Promotions',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Add to Existing Sale',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _campaign,
                            isExpanded: true,
                            hint: Text(
                              'Select a campaign...',
                              style: TextStyle(color: theme.colorScheme.outline),
                            ),
                            icon: Icon(Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
                            items: _campaigns.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _campaign = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Apply this product to active flash sales or discount campaigns.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.visibility_outlined, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product Visibility',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Active in your online store',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _visible,
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppTheme.primary,
                        onChanged: (v) => setState(() => _visible = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDeco(ThemeData theme, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _MediaSectionHeader extends StatelessWidget {
  const _MediaSectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.label,
    required this.controller,
    required this.accent,
  });

  final String label;
  final TextEditingController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: theme.textTheme.titleSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              prefixText: 'KES ',
              prefixStyle: theme.textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _FmtIcon extends StatelessWidget {
  const _FmtIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {},
      icon: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.imageUrl, required this.onRemove});

  final String imageUrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: 128,
            height: 128,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 128,
              height: 128,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.white.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.onTap});

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
        child: Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, color: AppTheme.primary, size: 28),
              const SizedBox(height: 6),
              Text(
                'ADD PHOTO',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
