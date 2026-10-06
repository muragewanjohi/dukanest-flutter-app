import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

/// Shade alert for an in-store offer. The card in the app is separate.
class OfferNotifications {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'in_store_offers',
    'In-store offers',
    description: 'Offers shown when you dwell near a store beacon.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(settings: const InitializationSettings(android: android));
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);
    _ready = true;
  }

  Future<void> showOffer({
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    await initialize();
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    ByteArrayAndroidBitmap? picture;
    final image = imageUrl?.trim() ?? '';
    if (image.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(image)).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          picture = ByteArrayAndroidBitmap(response.bodyBytes);
        }
      } catch (_) {
        picture = null;
      }
    }
    await _plugin.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: picture == null
              ? null
              : BigPictureStyleInformation(picture, contentTitle: title, summaryText: body),
        ),
      ),
    );
  }
}

final offerNotifications = OfferNotifications();
