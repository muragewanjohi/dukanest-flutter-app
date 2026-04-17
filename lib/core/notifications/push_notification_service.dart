import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref.read(apiClientProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Callback fired when the user taps a push notification (foreground, background,
/// or cold-start). The payload is the `data` map from the FCM message — use it
/// to resolve the deep link (e.g. `data.link`, `data.orderKey`).
typedef PushTapHandler = void Function(Map<String, dynamic> data);

class PushNotificationService {
  PushNotificationService(this._apiClient);

  final ApiClient _apiClient;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  bool _initialized = false;
  String? _lastRegisteredToken;

  /// Android notification channel for order / alert pushes. The channel is
  /// explicitly created so foreground-presented notifications can target a
  /// channel with importance = high (heads-up banner + sound).
  static const AndroidNotificationChannel _ordersChannel =
      AndroidNotificationChannel(
    'orders_alerts',
    'Order alerts',
    description: 'New orders, payment confirmations and fulfilment updates.',
    importance: Importance.high,
  );

  PushTapHandler? _onTap;

  /// Register a tap handler. Called on-next-frame with any pending
  /// "app launched from a push" payload, and then every time the user taps
  /// a notification thereafter. Pass `null` to clear.
  void setTapHandler(PushTapHandler? handler) {
    _onTap = handler;
    if (handler != null) {
      // Replay the cold-start message if we were launched by a push.
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          handler(_dataFromMessage(message));
        }
      });
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _setupLocalNotifications();
    } catch (e, st) {
      debugPrint('Local notifications init skipped: $e\n$st');
    }

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      // Android-only: make sure foreground messages produce a system
      // notification (iOS already does this when presentation options are set
      // via `setForegroundNotificationPresentationOptions`).
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) async {
        await registerDeviceToken(tokenOverride: token);
      });

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _onTap?.call(_dataFromMessage(message));
      });
    } catch (e, st) {
      debugPrint('Push init skipped: $e\n$st');
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map<String, dynamic>) {
            _onTap?.call(data);
          }
        } catch (_) {/* ignore malformed payloads */}
      },
    );

    // Create the channel up-front so importance is respected the first time a
    // notification is posted (creating it lazily can fall back to "default").
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_ordersChannel);
  }

  /// Android does NOT auto-display FCM messages while the app is in the
  /// foreground — we must show a local notification ourselves so the
  /// merchant still gets heads-up banner + sound while the app is open.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final android = message.notification?.android;
      final data = _dataFromMessage(message);

      final title = notification?.title ??
          (data['title']?.toString() ?? 'New order');
      final body = notification?.body ??
          (data['body']?.toString() ?? data['message']?.toString() ?? '');

      final notificationId = message.hashCode & 0x7fffffff;
      await _localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _ordersChannel.id,
            _ordersChannel.name,
            channelDescription: _ordersChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(data),
      );
    } catch (e, st) {
      debugPrint('Foreground push display failed: $e\n$st');
    }
  }

  Map<String, dynamic> _dataFromMessage(RemoteMessage message) {
    final out = <String, dynamic>{};
    message.data.forEach((key, value) {
      out[key] = value;
    });
    final notification = message.notification;
    if (notification != null) {
      out['title'] ??= notification.title;
      out['body'] ??= notification.body;
    }
    return out;
  }

  Future<void> registerDeviceToken({String? tokenOverride}) async {
    try {
      final token = tokenOverride ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      if (_lastRegisteredToken == token) {
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final deviceId = '${packageInfo.packageName}:$_platformName';
      final result = await _apiClient.registerDeviceToken(
        token: token,
        platform: _platformName,
        deviceId: deviceId,
        appVersion: packageInfo.version,
        deviceName: _deviceName,
      );

      if (result.success) {
        _lastRegisteredToken = token;
      } else {
        debugPrint('Device token registration failed: ${result.error?.message}');
      }
    } catch (e, st) {
      debugPrint('Device token registration skipped: $e\n$st');
    }
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  String? get _deviceName {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    return null;
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
  }
}
