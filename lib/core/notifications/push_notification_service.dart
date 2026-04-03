import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref.read(apiClientProvider));
  ref.onDispose(service.dispose);
  return service;
});

class PushNotificationService {
  PushNotificationService(this._apiClient);

  final ApiClient _apiClient;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  String? _lastRegisteredToken;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) async {
        await registerDeviceToken(tokenOverride: token);
      });
    } catch (e, st) {
      debugPrint('Push init skipped: $e\n$st');
    }
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
  }
}
