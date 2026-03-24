import 'package:flutter/material.dart';
import '../../demo/demo_data.dart';
import '../../demo/demo_mode_config.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: demoListLength(demoNotifications.length),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = demoNotifications[index % demoNotifications.length];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(item.icon),
              ),
              title: Text(item.title),
              subtitle: Text('${item.message} • ${item.time}'),
              trailing: item.isUnread
                  ? const Icon(Icons.circle, size: 10, color: Colors.redAccent)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
