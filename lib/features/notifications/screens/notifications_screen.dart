import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';

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

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Notifications')),
      body: notifications.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(item.icon),
                  ),
                  title: Text(item.title),
                  subtitle: Text('${item.message} • ${item.timeLabel}'),
                  trailing: item.isUnread
                      ? const Icon(Icons.circle, size: 10, color: Colors.redAccent)
                      : null,
                ),
              );
            },
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

  const _NotificationItem({
    required this.title,
    required this.message,
    required this.isUnread,
    this.createdAt,
  });

  factory _NotificationItem.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] ?? json['created_at'] ?? json['time'];
    return _NotificationItem(
      title: (json['title'] ?? 'Notification').toString(),
      message: (json['message'] ?? json['body'] ?? '').toString(),
      isUnread: json['isUnread'] == true || json['is_read'] == false,
      createdAt: createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null,
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
