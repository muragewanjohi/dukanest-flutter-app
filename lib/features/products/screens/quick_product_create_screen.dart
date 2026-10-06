import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../../../core/providers/store_identity_provider.dart';
import '../../../core/util/store_media_url.dart';
import '../../dashboard/providers/dashboard_getting_started_provider.dart';
import '../../dashboard/providers/dashboard_overview_provider.dart';
import '../../dashboard/providers/dashboard_reward_checklist_provider.dart';
import '../../onboarding/data/business_type_categories.dart';
import '../../settings/providers/dashboard_settings_provider.dart';
import '../providers/categories_list_provider.dart';
import '../providers/products_list_refresh_signal_provider.dart';
import 'products_list_screen.dart';

class QuickProductCreateScreen extends ConsumerStatefulWidget {
  const QuickProductCreateScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  ConsumerState<QuickProductCreateScreen> createState() =>
      _QuickProductCreateScreenState();
}

class _QuickProductCreateScreenState
    extends ConsumerState<QuickProductCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();

  String? _categoryId;
  String? _imagePath;
  bool _requiresShipping = true;
  bool _saving = false;
  bool _showMoreDetails = false;
  String? _savedProductSlug;
  String? _savedProductName;

  @override
  void initState() {
    super.initState();
    _loadBusinessDefaults();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessDefaults() async {
    try {
      final settings = await ref.read(dashboardSettingsProvider.future);
      final store = settingsSection(settings, 'store');
      final businessType =
          settingsPick(store, ['businessType', 'business_type']);
      if (!mounted) return;
      setState(() {
        _requiresShipping = !isServiceOnlyBusinessType(businessType);
      });
    } catch (_) {
      // Physical product is the safest fallback when settings are unavailable.
    }
  }

  Future<void> _chooseImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photo'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image != null && mounted) {
        setState(() => _imagePath = image.path);
      }
    } catch (error) {
      _showError(apiErrorMessage(error));
    }
  }

  Map<String, dynamic>? _savedProduct(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final product = map['product'] ?? map['item'];
    if (product is Map) return Map<String, dynamic>.from(product);
    final data = map['data'];
    if (data is Map) return _savedProduct(data);
    if (map['id'] != null || map['slug'] != null) return map;
    return null;
  }

  String? _categoryIdFromResponse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final direct = map['id']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    for (final key in ['category', 'data']) {
      final nested = map[key];
      final id = _categoryIdFromResponse(nested);
      if (id != null) return id;
    }
    return null;
  }

  Future<String> _fallbackCategoryId(ApiClient api) async {
    Future<String?> findExisting() async {
      ref.invalidate(categoriesListProvider);
      final categories = await ref.read(categoriesListProvider.future);
      for (final category in categories) {
        final name = category.name.trim().toLowerCase();
        if (name == 'uncategorized' || name == 'general') {
          final id = category.id.trim();
          if (id.isNotEmpty) return id;
        }
      }
      return null;
    }

    final existing = await findExisting();
    if (existing != null) return existing;

    try {
      final response = await api.createCategory({
        'name': 'Uncategorized',
        'status': 'active',
      });
      if (!response.success) {
        throw StateError(
          response.error?.message ?? 'Could not prepare a product category.',
        );
      }
      final createdId = _categoryIdFromResponse(response.data);
      if (createdId != null) {
        ref.invalidate(categoriesListProvider);
        return createdId;
      }
    } on DioException catch (error) {
      // Another request may have created the same fallback category first.
      if (error.response?.statusCode != 409) rethrow;
    }

    final createdByAnotherRequest = await findExisting();
    if (createdByAnotherRequest != null) return createdByAnotherRequest;
    throw StateError('Could not prepare a category for this product.');
  }

  String _saveErrorMessage(Object error) {
    if (error is DioException) {
      final response = asObjectMap(error.response?.data);
      final apiError = response?['error'];
      if (apiError is Map) {
        final details = apiError['details'];
        if (details is List && details.isNotEmpty && details.first is Map) {
          final message = (details.first as Map)['message']?.toString().trim();
          if (message != null && message.isNotEmpty) return message;
        }
      }
      return dioUserMessage(error, fallback: 'Could not save product.');
    }
    return apiErrorMessage(error);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final categoryId = _categoryId ?? await _fallbackCategoryId(api);
      String? imageUrl;
      final imagePath = _imagePath;
      if (imagePath != null) {
        final filename = imagePath.replaceAll(r'\', '/').split('/').last;
        final upload = await api.uploadMedia(
          FormData.fromMap({
            'file': await MultipartFile.fromFile(imagePath, filename: filename),
          }),
        );
        if (!upload.success) {
          throw StateError(
            upload.error?.message ?? 'Could not upload the product photo.',
          );
        }
        imageUrl = extractMediaUploadUrl(upload.data);
        if (imageUrl.isEmpty) {
          throw StateError(
              'The photo uploaded, but its link was not returned.');
        }
      }

      final price = double.parse(_priceController.text.trim());
      final quantity = int.parse(_quantityController.text.trim());
      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'price': price,
        // Quantity entered here is always inventory stock — even for services —
        // so the Products list and editor show the same number the merchant typed.
        'stock_quantity': quantity,
        'stockQuantity': quantity,
        'status': 'active',
        'requires_shipping': _requiresShipping,
        'requiresShipping': _requiresShipping,
        'deposit_type': 'none',
        'is_bookable': false,
        'category_id': categoryId,
        if (imageUrl != null && imageUrl.isNotEmpty) ...{
          'image': imageUrl,
          'imageUrl': imageUrl,
          'gallery': [imageUrl],
          'images': [imageUrl],
        },
      };
      final response = await api.createProduct(payload);
      if (!response.success) {
        throw StateError(response.error?.message ?? 'Could not save product.');
      }
      final product = _savedProduct(response.data);
      final slug = (product?['slug'] ?? '').toString().trim();
      if (!mounted) return;
      ProductsListScreen.clearListCache();
      bumpProductsListRefresh(ref);
      ref.invalidate(dashboardOverviewProvider);
      ref.invalidate(dashboardGettingStartedProvider);
      ref.invalidate(dashboardRewardChecklistProvider);
      setState(() {
        _savedProductSlug = slug;
        _savedProductName = _nameController.text.trim();
      });
    } on DioException catch (error) {
      _showError(_saveErrorMessage(error));
    } catch (error) {
      _showError(_saveErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _productUrl() {
    final storeUrl =
        ref.read(storeIdentityProvider).valueOrNull?.storeUrl?.trim();
    if (storeUrl == null || storeUrl.isEmpty) return null;
    final root = storeUrl.replaceFirst(RegExp(r'/+$'), '');
    final slug = _savedProductSlug?.trim() ?? '';
    return slug.isEmpty ? root : '$root/products/${Uri.encodeComponent(slug)}';
  }

  String _shareMessage() {
    final url = _productUrl();
    final name = _savedProductName ?? 'my new product';
    return url == null
        ? 'Check out $name on my DukaNest store.'
        : 'Check out $name on my store: $url';
  }

  Future<void> _shareOnWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_shareMessage())}',
    );
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    await SharePlus.instance.share(ShareParams(text: _shareMessage()));
  }

  Future<void> _copyLink() async {
    final url = _productUrl();
    if (url == null) {
      _showError(
          'Your store link is unavailable. Open Settings to refresh it.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product link copied')),
    );
  }

  void _addAnother() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _priceController.clear();
    _quantityController.text = '1';
    _descriptionController.clear();
    setState(() {
      _categoryId = null;
      _imagePath = null;
      _savedProductSlug = null;
      _savedProductName = null;
      _showMoreDetails = false;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesListProvider);
    ref.watch(storeIdentityProvider);
    if (_savedProductName != null) {
      return _buildSuccess(theme);
    }
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.firstRun ? 'Add your first product' : 'Quick add'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go(
            widget.firstRun ? '/dashboard' : '/products',
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Start with the basics',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You can add more details later. Your product goes live when you save.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _ImagePickerCard(
                imagePath: _imagePath,
                onPick: _saving ? null : _chooseImageSource,
                onRemove:
                    _saving ? null : () => setState(() => _imagePath = null),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Product or service name',
                  hintText: 'e.g. Leather handbag',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Enter a product or service name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: 'KES ',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                validator: (value) {
                  final price = double.tryParse(value?.trim() ?? '');
                  if (price == null || price <= 0) {
                    return 'Enter a price greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Stock quantity',
                  hintText: 'How many do you have?',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) {
                  final quantity = int.tryParse(value?.trim() ?? '');
                  if (quantity == null || quantity <= 0) {
                    return 'Enter a quantity of at least 1';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('This needs delivery'),
                subtitle: Text(
                  _requiresShipping
                      ? 'Customers pick delivery at checkout'
                      : 'Service or digital — no shipping step',
                ),
                value: _requiresShipping,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _requiresShipping = value),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: _showMoreDetails,
                onExpansionChanged: (value) =>
                    setState(() => _showMoreDetails = value),
                title: const Text('More details (optional)'),
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Tell customers what makes it useful',
                    ),
                  ),
                  const SizedBox(height: 16),
                  categories.when(
                    data: (items) => DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                      hint: const Text('Skip for now'),
                      items: items
                          .where((item) => item.id.trim().isNotEmpty)
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _categoryId = value),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => TextButton.icon(
                      onPressed: () => ref.invalidate(categoriesListProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Could not load categories — retry'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded),
                label: Text(_saving ? 'Saving…' : 'Save & share'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _saving ? null : () => context.push('/products/new'),
                child: const Text('Open full product editor'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    const whatsAppGreen = Color(0xFF25D366);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.check_circle_rounded,
                size: 76,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Your product is live',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share “$_savedProductName” with customers now.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _shareOnWhatsApp,
                style: FilledButton.styleFrom(
                  backgroundColor: whatsAppGreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Share on WhatsApp'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Copy product link'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  final url = _productUrl();
                  if (url != null) {
                    launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                child: const Text('View in store'),
              ),
              TextButton(
                onPressed: _addAnother,
                child: const Text('Add another product'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Go to dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.imagePath,
    required this.onPick,
    required this.onRemove,
  });

  final String? imagePath;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final image = imagePath;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPick,
        child: SizedBox(
          height: 170,
          child: image == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'Add a photo (optional)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text('Take a photo or choose one'),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(image), fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        tooltip: 'Remove photo',
                        onPressed: onRemove,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
