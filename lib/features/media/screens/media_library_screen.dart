import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/dio_envelope.dart';
import '../../../core/util/store_media_url.dart';
import '../../../core/widgets/dashboard_page_header.dart';
import '../media_item.dart';

class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key, this.pickMode = false});

  /// When true, tapping a tile pops with the selected (normalized) media URL
  /// instead of opening the edit dialog.
  final bool pickMode;

  /// Opens the library as a picker and resolves to the chosen media URL (or
  /// null if dismissed).
  static Future<String?> pick(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const MediaLibraryScreen(pickMode: true),
      ),
    );
  }

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  int _offset = 0;
  static const _limit = 40;
  bool _end = false;

  String _pickId(Map<String, dynamic> m) => mediaItemId(m);

  String _pickUrl(Map<String, dynamic> m) => mediaItemUrl(m);

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _offset = 0;
      _end = false;
      _items.clear();
    }
    if (_end) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getMedia(limit: _limit, offset: _offset);
      if (!r.success) throw StateError(r.error?.message ?? 'Load failed');
      final payload = r.data;
      final root =
          payload is Map<String, dynamic> ? payload : <String, dynamic>{};
      final nested = root['data'];
      final bag = nested is Map<String, dynamic>
          ? nested
          : nested is Map
              ? Map<String, dynamic>.from(nested)
              : root;
      final raw = bag['items'] ?? bag['media'] ?? root['items'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _items.addAll(list);
        _offset += list.length;
        if (list.length < _limit) _end = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _editItem(Map<String, dynamic> raw) async {
    final id = _pickId(raw);
    if (id.isEmpty) return;
    final titleCtrl = TextEditingController(
      text: '${raw['title'] ?? raw['name'] ?? ''}',
    );
    final altCtrl = TextEditingController(
      text: '${raw['alt'] ?? raw['altText'] ?? raw['alt_text'] ?? ''}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit media'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: altCtrl,
              decoration: const InputDecoration(labelText: 'Alt text'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        if (titleCtrl.text.trim().isNotEmpty) 'title': titleCtrl.text.trim(),
        if (altCtrl.text.trim().isNotEmpty) 'alt_text': altCtrl.text.trim(),
      };
      if (body.isEmpty) return;
      final r = await api.updateMedia(id, body);
      if (!r.success) throw StateError(r.error?.message ?? 'Update failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media updated')),
      );
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      titleCtrl.dispose();
      altCtrl.dispose();
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> raw) async {
    final id = _pickId(raw);
    if (id.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this file?'),
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
    if (confirm != true || !mounted) return;
    try {
      final r = await ref.read(apiClientProvider).deleteMedia(id);
      if (!r.success) throw StateError(r.error?.message ?? 'Delete failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted')),
      );
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8 + MediaQuery.paddingOf(context).top,
                  16,
                  8,
                ),
                child: DashboardPageHeader(
                  title: widget.pickMode ? 'Choose media' : 'Media library',
                  subtitle: widget.pickMode
                      ? 'Tap an image to use it.'
                      : 'Images and files uploaded to your store.',
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      if (widget.pickMode) {
                        Navigator.of(context).pop();
                      } else {
                        context.pop();
                      }
                    },
                  ),
                  storeNameOverride: 'Content',
                ),
              ),
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i >= _items.length) {
                      if (!_end && !_loading) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _load();
                        });
                      }
                      return _loading
                          ? const Center(child: CircularProgressIndicator())
                          : const SizedBox.shrink();
                    }
                    final item = _items[i];
                    final url = _pickUrl(item);
                    return Material(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          if (widget.pickMode) {
                            final selected = normalizeStoreMediaUrl(url);
                            if (selected.isEmpty) return;
                            Navigator.of(context).pop(selected);
                          } else {
                            _editItem(item);
                          }
                        },
                        onLongPress:
                            widget.pickMode ? null : () => _deleteItem(item),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: url.isEmpty
                                  ? const Center(
                                      child: Icon(Icons.insert_drive_file),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.broken_image),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                '${item['title'] ?? item['name'] ?? '—'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _items.length + (_end ? 0 : 1),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }
}
