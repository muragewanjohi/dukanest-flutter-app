import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';

final notificationsProvider = FutureProvider<List<_NotificationItem>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.getNotifications();
  if (!response.success || response.data == null) {
    throw StateError(response.error?.message ?? 'Unable to load notifications');
  }

  var payload = response.data;
  if (payload is Map<String, dynamic> && payload['data'] != null) {
    payload = payload['data'];
  }
  final data = payload is Map<String, dynamic>
      ? (payload['items'] ?? payload['notifications'] ?? payload['list'])
      : payload;
  if (data is! List) {
    throw const FormatException('Invalid notifications payload');
  }

  return data
      .whereType<Map>()
      .map((raw) => _NotificationItem.fromJson(Map<String, dynamic>.from(raw)))
      .toList();
});

final notificationPreferencesProvider = FutureProvider<Map<String, bool>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.getNotificationPreferences();
  if (!response.success || response.data == null) {
    throw StateError(response.error?.message ?? 'Unable to load preferences');
  }

  dynamic payload = response.data;
  if (payload is Map<String, dynamic> && payload['data'] != null) {
    payload = payload['data'];
  }
  if (payload is Map<String, dynamic> && payload['preferences'] is Map) {
    payload = Map<String, dynamic>.from(payload['preferences'] as Map);
  }
  if (payload is! Map) {
    return {
      'push': true,
      'in_app': true,
    };
  }

  final m = Map<String, dynamic>.from(payload);
  bool toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'enabled';
    }
    return false;
  }

  final out = <String, bool>{};
  for (final e in m.entries) {
    out[e.key.toString()] = toBool(e.value);
  }
  return out.isEmpty
      ? {
          'push': true,
          'in_app': true,
        }
      : out;
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Map<String, bool> _pendingPrefs = const {};
  bool _isUpdatingPref = false;

  Future<void> _togglePreference(String key, bool value) async {
    if (_isUpdatingPref) return;
    final previous = _pendingPrefs[key];
    setState(() {
      _isUpdatingPref = true;
      _pendingPrefs = {
        ..._pendingPrefs,
        key: value,
      };
    });

    final api = ref.read(apiClientProvider);
    try {
      var response = await api.updateNotificationPreferences({key: value});
      if (!response.success) {
        response = await api.updateNotificationPreferences({
          'preferences': {key: value},
        });
      }
      if (!response.success) {
        throw StateError(response.error?.message ?? 'Could not update preference');
      }
      ref.invalidate(notificationPreferencesProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          _pendingPrefs.remove(key);
        } else {
          _pendingPrefs = {
            ..._pendingPrefs,
            key: previous,
          };
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update preference: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPref = false);
      }
    }
  }

  String _labelForKey(String key) {
    final normalized = key.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (normalized.isEmpty) return key;
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String? _extractOrderKeyFromNotification(_NotificationItem item) {
    final candidates = <String?>[
      item.orderKey,
      item.link,
    ];
    for (final raw in candidates) {
      final v = (raw ?? '').trim();
      if (v.isEmpty) continue;
      // Direct order code/id.
      if (!v.contains('/')) return v;
      // Path style links like /orders/detail/ORD-... or /orders/ORD-...
      final uri = Uri.tryParse(v);
      final segments = uri?.pathSegments ?? const <String>[];
      if (segments.isEmpty) continue;
      final detailIdx = segments.indexOf('detail');
      if (detailIdx != -1 && detailIdx + 1 < segments.length) {
        return Uri.decodeComponent(segments[detailIdx + 1]);
      }
      final ordersIdx = segments.indexOf('orders');
      if (ordersIdx != -1 && ordersIdx + 1 < segments.length) {
        final next = Uri.decodeComponent(segments[ordersIdx + 1]);
        if (next != 'detail') return next;
      }
    }
    return null;
  }

  void _openNotification(_NotificationItem item) {
    final orderKey = _extractOrderKeyFromNotification(item);
    if (orderKey != null && orderKey.isNotEmpty) {
      // Use `go` instead of `push`: `/orders/detail/:orderKey` lives inside
      // the stateful shell, and pushing it on top of `/notifications` (a
      // non-shell route) would rebuild a second DashboardShell with
      // duplicate GlobalKeys, crashing the Navigator with
      // `!keyReservation.contains(key)`.
      context.go('/orders/detail/${Uri.encodeComponent(orderKey)}');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This notification has no linked order.')),
    );
  }

  static const List<String> _preferredPrefOrder = <String>[
    'push',
    'in_app',
    'sms',
    'email',
  ];

  List<MapEntry<String, bool>> _orderedPreferenceEntries(Map<String, bool> prefs) {
    final all = prefs.entries.toList();
    all.sort((a, b) {
      final ai = _preferredPrefOrder.indexOf(a.key);
      final bi = _preferredPrefOrder.indexOf(b.key);
      final aRank = ai == -1 ? 999 : ai;
      final bRank = bi == -1 ? 999 : bi;
      if (aRank != bRank) return aRank.compareTo(bRank);
      return a.key.compareTo(b.key);
    });
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'Notifications'),
      body: notifications.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              prefsAsync.when(
                data: (prefs) {
                  final merged = Map<String, bool>.from(prefs);
                  for (final e in _pendingPrefs.entries) {
                    merged[e.key] = e.value;
                  }
                  final ordered = _orderedPreferenceEntries(merged);
                  final primary = ordered
                      .where((e) => _preferredPrefOrder.contains(e.key))
                      .toList();
                  final advanced = ordered
                      .where((e) => !_preferredPrefOrder.contains(e.key))
                      .toList();
                  return Card(
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: const Text('Notification preferences'),
                      subtitle: const Text('Choose what updates you want to receive'),
                      children: [
                        for (final entry in primary)
                          SwitchListTile.adaptive(
                            value: entry.value,
                            onChanged: _isUpdatingPref
                                ? null
                                : (v) => _togglePreference(entry.key, v),
                            title: Text(_labelForKey(entry.key)),
                          ),
                        if (advanced.isNotEmpty)
                          ExpansionTile(
                            title: const Text('Advanced'),
                            children: [
                              for (final entry in advanced)
                                SwitchListTile.adaptive(
                                  value: entry.value,
                                  onChanged: _isUpdatingPref
                                      ? null
                                      : (v) => _togglePreference(entry.key, v),
                                  title: Text(_labelForKey(entry.key)),
                                ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const Card(
                  child: ListTile(
                    leading: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Loading preferences...'),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              ...List.generate(items.length, (index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(item.icon),
                      ),
                      title: Text(item.title),
                      subtitle: Text('${item.message} • ${item.timeLabel}'),
                      onTap: () => _openNotification(item),
                      trailing: item.isUnread
                          ? const Icon(Icons.circle, size: 10, color: Colors.redAccent)
                          : null,
                    ),
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(notificationsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationItem {
  final String title;
  final String message;
  final bool isUnread;
  final DateTime? createdAt;
  final String? orderKey;
  final String? link;

  const _NotificationItem({
    required this.title,
    required this.message,
    required this.isUnread,
    this.createdAt,
    this.orderKey,
    this.link,
  });

  factory _NotificationItem.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] ?? json['created_at'] ?? json['time'];
    final dataRaw = json['data'];
    final data = dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : const <String, dynamic>{};
    return _NotificationItem(
      title: (json['title'] ?? 'Notification').toString(),
      message: (json['message'] ?? json['body'] ?? '').toString(),
      isUnread: json['isUnread'] == true || json['is_read'] == false,
      createdAt: createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null,
      orderKey: (json['orderKey'] ??
              json['order_key'] ??
              json['orderCode'] ??
              json['order_code'] ??
              json['orderId'] ??
              json['order_id'] ??
              data['orderKey'] ??
              data['order_key'] ??
              data['orderCode'] ??
              data['order_code'] ??
              data['orderId'] ??
              data['order_id'])
          ?.toString(),
      link: (json['link'] ?? json['deepLink'] ?? json['deep_link'] ?? data['link'] ?? data['deepLink'] ?? data['deep_link'])
          ?.toString(),
    );
  }

  String get timeLabel {
    final t = createdAt;
    if (t == null) return 'Just now';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData get icon => isUnread ? Icons.notifications_active : Icons.notifications_none;
}
