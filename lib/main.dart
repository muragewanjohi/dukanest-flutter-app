import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/router.dart';
import 'config/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(); // Initialize later when Firebase config is added
  
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
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'DukaNest',
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
