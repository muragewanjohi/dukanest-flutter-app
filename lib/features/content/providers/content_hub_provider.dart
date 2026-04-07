import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../settings/providers/dashboard_settings_provider.dart';

/// Search query for blog + page lists on the content hub.
final contentHubSearchProvider = StateProvider<String>((ref) => '');

class ContentHubSnapshot {
  const ContentHubSnapshot({
    required this.blogs,
    required this.pages,
    required this.sales,
  });

  final List<Map<String, dynamic>> blogs;
  final List<Map<String, dynamic>> pages;
  final List<Map<String, dynamic>> sales;
}

List<Map<String, dynamic>> _itemsFromResponse(dynamic raw) {
  final root = unwrapSettingsData(raw) ?? raw;
  if (root is! Map) return [];
  final items = root['items'] ?? root['data'];
  if (items is! List) return [];
  return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

final contentHubProvider = FutureProvider.autoDispose<ContentHubSnapshot>((ref) async {
  final api = ref.watch(apiClientProvider);
  final search = ref.watch(contentHubSearchProvider);
  final results = await Future.wait([
    api.getBlogs(page: 1, limit: 12, search: search),
    api.getPages(page: 1, limit: 24, search: search),
    api.getSales(page: 1, limit: 8),
  ]);
  for (final r in results) {
    if (!r.success) {
      throw StateError(r.error?.message ?? 'Failed to load content');
    }
  }
  return ContentHubSnapshot(
    blogs: _itemsFromResponse(results[0].data),
    pages: _itemsFromResponse(results[1].data),
    sales: _itemsFromResponse(results[2].data),
  );
});

String contentBlogStatusLabel(Map<String, dynamic> b) {
  final s = settingsPick(b, ['status', 'publish_status', 'publishStatus'], fallback: 'draft').toLowerCase();
  if (s == 'published' || s == 'live' || s == 'active') return 'PUBLISHED';
  return 'DRAFT';
}

String contentFormatHubDate(dynamic raw) {
  if (raw == null) return '';
  DateTime? dt;
  if (raw is String) dt = DateTime.tryParse(raw);
  if (raw is int) {
    final ms = raw < 20000000000 ? raw * 1000 : raw;
    dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 7) return 'Updated ${DateFormat.yMMMd().format(dt)}';
  if (diff.inDays >= 1) return 'Updated ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  if (diff.inHours >= 1) return 'Updated ${diff.inHours} hr${diff.inHours == 1 ? '' : 's'} ago';
  if (diff.inMinutes >= 1) return 'Updated ${diff.inMinutes} min ago';
  return 'Updated just now';
}

String contentBlogMetaLine(Map<String, dynamic> b) {
  final dateRaw = b['updated_at'] ?? b['updatedAt'] ?? b['created_at'] ?? b['createdAt'];
  final base = contentFormatHubDate(dateRaw);
  final mins = settingsPick(b, ['read_time_minutes', 'readTimeMinutes', 'reading_time']);
  if (mins.isNotEmpty) {
    final m = int.tryParse(mins) ?? 0;
    if (m > 0) {
      return base.isEmpty ? '$m min read' : '$base • $m min read';
    }
  }
  return base.isEmpty ? '' : base;
}

String contentBlogImageUrl(Map<String, dynamic> b) => settingsPick(b, [
      'featured_image',
      'featuredImage',
      'image',
      'cover_image',
      'coverImage',
      'thumbnail',
      'thumbnail_url',
      'thumbnailUrl',
    ]);

String contentBlogId(Map<String, dynamic> b) => settingsPick(b, ['id', '_id']);

String contentBlogTitle(Map<String, dynamic> b) => settingsPick(b, ['title', 'name'], fallback: 'Untitled');

String contentPageSlug(Map<String, dynamic> p) {
  final slug = settingsPick(p, ['slug']);
  if (slug.isNotEmpty) return slug;
  return settingsPick(p, ['id', '_id'], fallback: 'page');
}

String contentPageTitle(Map<String, dynamic> p) => settingsPick(p, ['title', 'name', 'slug'], fallback: 'Page');

String contentPageUpdatedLine(Map<String, dynamic> p) {
  final dateRaw = p['updated_at'] ?? p['updatedAt'] ?? p['created_at'] ?? p['createdAt'];
  final formatted = contentFormatHubDate(dateRaw);
  return formatted.isEmpty ? '' : 'Last updated: ${formatted.replaceFirst('Updated ', '')}';
}

String contentSaleTitle(Map<String, dynamic> s) => settingsPick(s, ['name', 'title'], fallback: 'Sale');
