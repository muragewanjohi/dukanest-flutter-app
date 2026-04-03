import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../data/categories_repository.dart';
import '../providers/categories_list_provider.dart';

/// Add / edit category — Stitch: "Add/Edit Category (Updated Style)"
/// (screen 823ea31c8803471096d68fdcc8d26e22).
class CategoryEditorScreen extends ConsumerStatefulWidget {
  const CategoryEditorScreen({super.key, this.categoryId});

  /// `null` → create new category (`/categories/new`).
  final String? categoryId;

  bool get isNew => categoryId == null;

  @override
  ConsumerState<CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends ConsumerState<CategoryEditorScreen> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  String? _parentId;
  bool _active = true;
  String? _imageUrl;
  String? _localImagePath;
  bool _loadingRemote = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingRemote = true);
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getCategory(widget.categoryId!);
      if (!mounted) return;
      if (!r.success || r.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error?.message ?? 'Failed to load category')),
        );
        return;
      }
      var root = r.data;
      if (root is Map<String, dynamic> && root['data'] is Map) {
        root = root['data'] as Map<String, dynamic>;
      }
      final raw = root is Map<String, dynamic>
          ? (root['category'] ?? root['item'] ?? root)
          : null;
      if (raw is! Map) return;
      final e = categoryEntryFromApi(Map<String, dynamic>.from(raw));
      setState(() {
        _nameController.text = e.name;
        _parentId = e.parentId;
        _active = e.active;
        _imageUrl = e.imageUrl;
        _localImagePath = e.localImagePath;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load category: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRemote = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted || file == null) return;
    setState(() {
      _localImagePath = file.path;
      _imageUrl = null;
    });
  }

  void _clearImage() {
    setState(() {
      _localImagePath = null;
      _imageUrl = null;
    });
  }

  List<DropdownMenuItem<String?>> _parentItems(List<CategoryEntry> entries) {
    final excludeId = widget.categoryId;
    return [
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('No parent'),
      ),
      ...entries
          .where((e) => e.id != excludeId)
          .map(
            (e) => DropdownMenuItem<String?>(
              value: e.id,
              child: Text(e.name),
            ),
          ),
    ];
  }

  String _hierarchyHint(List<CategoryEntry> entries) {
    if (_parentId == null) {
      return 'Main Category';
    }
    try {
      final p = entries.firstWhere((e) => e.id == _parentId);
      return '${p.name} → ${_nameController.text.trim().isEmpty ? '…' : _nameController.text.trim()}';
    } catch (_) {
      return 'Main Category';
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'name': name,
        if (_parentId != null) 'parentId': _parentId,
        'isActive': _active,
      };
      if (widget.isNew) {
        final r = await api.createCategory(body);
        if (!r.success) {
          throw StateError(r.error?.message ?? 'Failed to create category');
        }
      } else {
        final r = await api.updateCategory(widget.categoryId!, body);
        if (!r.success) {
          throw StateError(r.error?.message ?? 'Failed to update category');
        }
      }
      ref.invalidate(categoriesListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isNew ? 'Category created' : 'Category updated')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: const Text(
          'Products in this category may need to be reassigned.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.deleteCategory(widget.categoryId!);
      if (!r.success) {
        throw StateError(r.error?.message ?? 'Failed to delete');
      }
      ref.invalidate(categoriesListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;
    final parentList = ref.watch(categoriesListProvider).valueOrNull ?? <CategoryEntry>[];
    String? parentName;
    if (_parentId != null) {
      try {
        parentName = parentList.firstWhere((e) => e.id == _parentId).name;
      } catch (_) {
        parentName = null;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          if (_loadingRemote) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: AppTheme.primaryDark),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Text(
                    widget.isNew ? 'Add Category' : 'Edit Category',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 200 + bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Category Name',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Enter category name',
                      filled: true,
                      fillColor: AppTheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Parent Category',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _parentId,
                        hint: Text('No parent', style: GoogleFonts.inter()),
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(12),
                        items: _parentItems(parentList),
                        onChanged: (v) => setState(() => _parentId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _parentId == null
                                ? 'Currently: Main Category. Sub-categories appear nested like '
                                    'Electronics → Laptops in the storefront.'
                                : 'Currently: Sub-category under '
                                    '${parentName ?? 'parent'}. '
                                    'Path preview: ${_hierarchyHint(parentList)}.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.45,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Category Image',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.outlineVariant.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 192,
                            width: double.infinity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_localImagePath != null)
                                  Image.file(
                                    File(_localImagePath!),
                                    fit: BoxFit.cover,
                                  )
                                else if (_imageUrl != null)
                                  Image.network(
                                    _imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => ColoredBox(
                                      color: colorScheme.surfaceContainerHigh,
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: colorScheme.outline,
                                        size: 48,
                                      ),
                                    ),
                                  )
                                else
                                  ColoredBox(
                                    color: colorScheme.surfaceContainerHigh,
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: colorScheme.outline,
                                      size: 48,
                                    ),
                                  ),
                                if (_localImagePath != null || _imageUrl != null)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Material(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      shape: const CircleBorder(),
                                      clipBehavior: Clip.antiAlias,
                                      child: IconButton(
                                        icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                                        onPressed: _clearImage,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickImage,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: colorScheme.surfaceContainerHigh,
                              foregroundColor: colorScheme.onSurface,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: Text(
                              'Change Image',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Category Status',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Visible to customers on storefront',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _active,
                          onChanged: (v) => setState(() => _active = v),
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryDark, AppTheme.primary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryDark.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _saving ? null : _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _saving
                                ? 'Saving…'
                                : (widget.isNew ? 'Create Category' : 'Update Category'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (!widget.isNew) ...[
                const SizedBox(height: 12),
                Material(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _confirmDelete,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Delete Category',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
