import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/dio_envelope.dart';
import '../../features/onboarding/providers/auth_provider.dart';

/// Full-screen friendly API/async error with optional retry and sign-in.
class ApiErrorView extends ConsumerWidget {
  const ApiErrorView({
    super.key,
    required this.error,
    this.title,
    this.onRetry,
    this.icon,
    this.padding = const EdgeInsets.all(24),
  });

  final Object error;
  final String? title;
  final VoidCallback? onRetry;
  final IconData? icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionExpired = isSessionExpiredApiError(error);
    final message = apiErrorMessage(error);
    final headline = title ??
        (sessionExpired
            ? 'Session expired'
            : 'Something went wrong');

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ??
                  (sessionExpired
                      ? Icons.lock_clock_outlined
                      : Icons.cloud_off_outlined),
              size: 48,
              color: theme.colorScheme.error.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 16),
            Text(
              headline,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (sessionExpired)
              FilledButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (!context.mounted) return;
                  context.go('/login');
                },
                child: const Text('Sign in again'),
              )
            else if (onRetry != null)
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

void showApiErrorSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(apiErrorMessage(error))),
  );
}
