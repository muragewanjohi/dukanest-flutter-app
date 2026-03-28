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
