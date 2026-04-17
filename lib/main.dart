import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'core/auth/auth_state.dart';
import 'core/notifications/push_notification_service.dart';
import 'features/onboarding/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization skipped: $e');
  }

  runApp(
    const ProviderScope(
      child: DukaNestApp(),
    ),
  );
}

class DukaNestApp extends ConsumerWidget {
  const DukaNestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_pushBootstrapProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'DukaNest',
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}

final _pushBootstrapProvider = FutureProvider<void>((ref) async {
  final pushService = ref.watch(pushNotificationServiceProvider);
  await pushService.initialize();

  pushService.setTapHandler((data) {
    final router = ref.read(routerProvider);
    final orderKey = _resolveOrderKeyFromPushData(data);
    if (orderKey != null && orderKey.isNotEmpty) {
      router.go('/orders/detail/${Uri.encodeComponent(orderKey)}');
      return;
    }
    // Fallback: take the merchant to the notifications inbox if the push
    // didn't carry a specific order link.
    router.go('/notifications');
  });

  ref.listen<AuthState>(authProvider, (previous, next) {
    if (next.status == AuthStatus.authenticated &&
        previous?.status != AuthStatus.authenticated) {
      pushService.registerDeviceToken();
    }
  });

  final currentAuthState = ref.read(authProvider);
  if (currentAuthState.status == AuthStatus.authenticated) {
    await pushService.registerDeviceToken();
  }
});

/// Pulls an order key out of a push data payload. Accepts either a bare
/// order code/id under common field names, or a deep-link URL under
/// `link` / `deepLink` like `/orders/detail/ORD-20260416-268561`.
String? _resolveOrderKeyFromPushData(Map<String, dynamic> data) {
  for (final field in const [
    'orderKey',
    'order_key',
    'orderCode',
    'order_code',
    'orderId',
    'order_id',
  ]) {
    final raw = data[field];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  }

  for (final field in const ['link', 'deepLink', 'deep_link', 'url']) {
    final raw = data[field];
    if (raw is! String || raw.trim().isEmpty) continue;
    final uri = Uri.tryParse(raw.trim());
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
