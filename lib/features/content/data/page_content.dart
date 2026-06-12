import 'dart:convert';

import '../../../core/api/api_client.dart';
import '../../settings/providers/dashboard_settings_provider.dart';

/// A resolved page row plus its parsed `content` JSON, used by the page and
/// hero editors to read/write storefront sections via the real Pages API.
class PageContent {
  PageContent({
    required this.id,
    required this.slug,
    required this.title,
    required this.status,
    required this.raw,
    required this.content,
  });

  final String id;
  final String slug;
  final String title;
  final String status;
  final Map<String, dynamic> raw;
  Map<String, dynamic> content;

  bool get isProtectedSlug =>
      slug == 'home' || slug == 'about' || slug == 'contact';
}

/// Parses a page `content` field from API responses (JSON string or map).
Map<String, dynamic> parseContentField(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return <String, dynamic>{};
    }
  }
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Map<String, dynamic> _pageRowFromResponse(dynamic raw) {
  final root = unwrapSettingsData(raw) ?? raw;
  if (root is Map) {
    final map = Map<String, dynamic>.from(root);
    // Some endpoints nest the row under `page`.
    final nested = map['page'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return map;
  }
  return <String, dynamic>{};
}

PageContent _toPageContent(Map<String, dynamic> row) {
  return PageContent(
    id: settingsPick(row, ['id', '_id']),
    slug: settingsPick(row, ['slug']),
    title: settingsPick(row, ['title', 'name', 'slug'], fallback: 'Page'),
    status: settingsPick(row, ['status', 'publish_status', 'publishStatus'],
        fallback: 'draft'),
    raw: row,
    content: parseContentField(row['content']),
  );
}

/// Resolves a page by slug (falling back to id) and fetches its full row.
Future<PageContent?> loadPageBySlug(ApiClient api, String slug) async {
  final listResp = await api.getPages(page: 1, limit: 100);
  if (!listResp.success) {
    throw StateError(listResp.error?.message ?? 'Could not load pages');
  }
  final listRoot = unwrapSettingsData(listResp.data) ?? listResp.data;
  final items =
      (listRoot is Map ? (listRoot['items'] ?? listRoot['data']) : null);
  String? id;
  if (items is List) {
    for (final e in items.whereType<Map>()) {
      final row = Map<String, dynamic>.from(e);
      final rowSlug = settingsPick(row, ['slug']);
      final rowId = settingsPick(row, ['id', '_id']);
      if (rowSlug == slug || rowId == slug) {
        id = rowId.isNotEmpty ? rowId : null;
        if (id != null) break;
      }
    }
  }
  if (id == null || id.isEmpty) return null;
  final detail = await api.getPage(id);
  if (!detail.success) {
    throw StateError(detail.error?.message ?? 'Could not load page');
  }
  return _toPageContent(_pageRowFromResponse(detail.data));
}

/// Persists `content` (and optional SEO/meta) to a page. When [publish] is
/// true the content is also copied into `published_content` and the status is
/// set to published.
Future<String?> savePageContent(
  ApiClient api, {
  required String id,
  required Map<String, dynamic> content,
  String? metaTitle,
  String? metaDescription,
  required bool publish,
}) async {
  final encoded = jsonEncode(content);
  final body = <String, dynamic>{
    'content': encoded,
    if (metaTitle != null) 'meta_title': metaTitle,
    if (metaDescription != null) 'meta_description': metaDescription,
    if (publish) ...{
      'status': 'published',
      'published_content': encoded,
    } else
      'status': 'draft',
  };
  final r = await api.updatePage(id, body);
  if (!r.success) {
    return r.error?.message ?? 'Could not save page';
  }
  return null;
}

const Map<String, ({String emoji, String label})> kSectionLabels = {
  'hero': (emoji: '🎯', label: 'Hero'),
  'categories': (emoji: '📁', label: 'Categories'),
  'banners': (emoji: '🎨', label: 'Banners'),
  'sales': (emoji: '⚡', label: 'Sales Tab'),
  'sales_tab': (emoji: '⚡', label: 'Sales Tab'),
  'features': (emoji: '✨', label: 'Features'),
  'product_tabs': (emoji: '🛍️', label: 'Product Tabs'),
  'products': (emoji: '🛍️', label: 'Products'),
  'split_layout': (emoji: '🌓', label: 'Split Layout'),
  'blogs': (emoji: '📰', label: 'Blogs'),
  'cta': (emoji: '📢', label: 'Call to Action'),
  'testimonials': (emoji: '💬', label: 'Testimonials'),
  'newsletter': (emoji: '✉️', label: 'Newsletter'),
};

/// Section types that have a dedicated mobile editor.
const Set<String> kEditableSectionTypes = {
  'hero',
  'banners',
  'split_layout',
};

/// Builds a route path for editing a section on a page.
String sectionEditorRoute(String pageSlug, String sectionType) {
  final slug = Uri.encodeComponent(pageSlug);
  switch (sectionType.toLowerCase()) {
    case 'hero':
      return '/page-editor/$slug/sections/hero';
    case 'banners':
      return '/page-editor/$slug/sections/banners';
    case 'split_layout':
      return '/page-editor/$slug/sections/split-layout';
    default:
      return '/page-editor/$slug';
  }
}

/// A storefront section parsed from page content for list display + toggling.
class PageSection {
  PageSection({
    required this.key,
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.enabled,
    this.sectionIndex,
  });

  final String key;
  final String emoji;
  final String label;
  String subtitle;
  bool enabled;
  final int? sectionIndex;

  bool get isEditable => kEditableSectionTypes.contains(key.toLowerCase());
}

bool _readSectionEnabled(Map<String, dynamic> section) {
  final hidden = section['hidden'];
  if (hidden is bool) return !hidden;
  if (hidden is String) {
    final lower = hidden.toLowerCase();
    if (lower == 'true') return false;
    if (lower == 'false') return true;
  }
  for (final k in ['enabled', 'visible', 'is_enabled', 'isEnabled', 'show']) {
    final v = section[k];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
  }
  return true;
}

void _writeSectionVisibility(Map<String, dynamic> section, bool enabled) {
  section['hidden'] = !enabled;
  section['enabled'] = enabled;
}

Map<String, dynamic>? _sectionRef(
  Map<String, dynamic> content, {
  required String type,
  int? sectionIndex,
}) {
  final normalized = type.toLowerCase();
  final sections = content['sections'];
  if (sections is List) {
    if (sectionIndex != null &&
        sectionIndex >= 0 &&
        sectionIndex < sections.length &&
        sections[sectionIndex] is Map) {
      return sections[sectionIndex] as Map<String, dynamic>;
    }
    for (final s in sections) {
      if (s is Map) {
        final m = Map<String, dynamic>.from(s);
        final key =
            settingsPick(m, ['type', 'key', 'id', 'name']).toLowerCase();
        if (key == normalized) return s as Map<String, dynamic>;
      }
    }
  } else if (sections is Map && sections[type] is Map) {
    return sections[type] as Map<String, dynamic>;
  }
  if (content[type] is Map) return content[type] as Map<String, dynamic>;
  return null;
}

/// Builds a display list of sections from a content map. Supports both a
/// `sections` array and a map of named section objects.
List<PageSection> parseSections(Map<String, dynamic> content) {
  final result = <PageSection>[];
  final sections = content['sections'];

  void addFromKey(String key, dynamic value, {int? index}) {
    final meta = kSectionLabels[key.toLowerCase()];
    final emoji = meta?.emoji ?? '📄';
    final label = meta?.label ?? _humanize(key);
    final section =
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    final subtitle =
        settingsPick(section, ['title', 'heading', 'subtitle', 'description']);
    result.add(PageSection(
      key: key,
      emoji: emoji,
      label: label,
      subtitle: subtitle,
      enabled: _readSectionEnabled(section),
      sectionIndex: index,
    ));
  }

  if (sections is List) {
    for (var i = 0; i < sections.length; i++) {
      final s = sections[i];
      if (s is Map) {
        final m = Map<String, dynamic>.from(s);
        final key = settingsPick(m, ['type', 'key', 'id', 'name'],
            fallback: 'section_$i');
        addFromKey(key, m, index: i);
      }
    }
  } else if (sections is Map) {
    sections.forEach((k, v) => addFromKey(k.toString(), v));
  } else {
    // No explicit sections array; treat known top-level keys as sections.
    content.forEach((k, v) {
      if (kSectionLabels.containsKey(k.toLowerCase()) && v is Map) {
        addFromKey(k.toString(), v);
      }
    });
  }
  return result;
}

/// Writes the visibility of [section] back into [content].
void applySectionEnabled(
  Map<String, dynamic> content,
  PageSection section,
) {
  final sections = content['sections'];
  if (sections is List) {
    if (section.sectionIndex != null &&
        section.sectionIndex! >= 0 &&
        section.sectionIndex! < sections.length &&
        sections[section.sectionIndex!] is Map) {
      _writeSectionVisibility(
          sections[section.sectionIndex!] as Map<String, dynamic>,
          section.enabled);
      return;
    }
    for (final s in sections) {
      if (s is Map) {
        final key = settingsPick(
            Map<String, dynamic>.from(s), ['type', 'key', 'id', 'name']);
        if (key == section.key) {
          _writeSectionVisibility(s as Map<String, dynamic>, section.enabled);
        }
      }
    }
  } else if (sections is Map && sections[section.key] is Map) {
    _writeSectionVisibility(
        sections[section.key] as Map<String, dynamic>, section.enabled);
  } else if (content[section.key] is Map) {
    _writeSectionVisibility(
        content[section.key] as Map<String, dynamic>, section.enabled);
  }
}

/// Returns the hero section object from a content map, if present.
Map<String, dynamic> readHero(
  Map<String, dynamic> content, {
  int? sectionIndex,
}) {
  final ref = _sectionRef(content, type: 'hero', sectionIndex: sectionIndex);
  if (ref != null) return Map<String, dynamic>.from(ref);
  return <String, dynamic>{};
}

/// Writes hero fields back into the content map (matching the read shape).
void writeHero(
  Map<String, dynamic> content,
  Map<String, dynamic> hero, {
  int? sectionIndex,
}) {
  final ref = _sectionRef(content, type: 'hero', sectionIndex: sectionIndex);
  if (ref != null) {
    hero.forEach((k, v) => ref[k] = v);
    return;
  }
  final sections = content['sections'];
  if (sections is List) {
    sections.add({'type': 'hero', ...hero});
    return;
  }
  content['hero'] = {...readHero(content), ...hero};
}

/// Returns the banners section object from a content map, if present.
Map<String, dynamic> readBanners(
  Map<String, dynamic> content, {
  int? sectionIndex,
}) {
  final ref = _sectionRef(content, type: 'banners', sectionIndex: sectionIndex);
  if (ref != null) return Map<String, dynamic>.from(ref);
  return <String, dynamic>{};
}

/// Writes banners fields back into the content map.
void writeBanners(
  Map<String, dynamic> content,
  Map<String, dynamic> banners, {
  int? sectionIndex,
}) {
  final ref = _sectionRef(content, type: 'banners', sectionIndex: sectionIndex);
  if (ref != null) {
    banners.forEach((k, v) => ref[k] = v);
    return;
  }
  final sections = content['sections'];
  if (sections is List) {
    sections.add({'type': 'banners', ...banners});
    return;
  }
  content['banners'] = {...readBanners(content), ...banners};
}

/// Returns the split_layout section object from a content map, if present.
Map<String, dynamic> readSplitLayout(
  Map<String, dynamic> content, {
  int? sectionIndex,
}) {
  final ref =
      _sectionRef(content, type: 'split_layout', sectionIndex: sectionIndex);
  if (ref != null) return Map<String, dynamic>.from(ref);
  return <String, dynamic>{};
}

/// Writes split_layout fields back into the content map.
void writeSplitLayout(
  Map<String, dynamic> content,
  Map<String, dynamic> splitLayout, {
  int? sectionIndex,
}) {
  final ref =
      _sectionRef(content, type: 'split_layout', sectionIndex: sectionIndex);
  if (ref != null) {
    splitLayout.forEach((k, v) => ref[k] = v);
    return;
  }
  final sections = content['sections'];
  if (sections is List) {
    sections.add({'type': 'split_layout', ...splitLayout});
    return;
  }
  content['split_layout'] = {...readSplitLayout(content), ...splitLayout};
}

String _humanize(String key) {
  final parts = key.replaceAll(RegExp(r'[_-]+'), ' ').trim().split(' ');
  return parts
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}
