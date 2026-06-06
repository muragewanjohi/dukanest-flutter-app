import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/dio_envelope.dart';
import '../dashboard/providers/dashboard_getting_started_provider.dart';
import '../dashboard/providers/dashboard_overview_provider.dart';
import 'models/remove_demo_products_result.dart';
import 'providers/products_list_refresh_signal_provider.dart';

Future<bool> confirmRemoveDemoProducts(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove demo products?'),
      content: const Text(
        'This removes sample catalog items that are not used in orders. '
        'Items already referenced by orders are archived instead of deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<RemoveDemoProductsResult?> runDemoProductCleanup(WidgetRef ref) async {
  final response = await ref.read(apiClientProvider).removeDemoProducts();
  if (!response.success) {
    throw StateError(response.error?.message ?? 'Request failed');
  }
  final result = RemoveDemoProductsResult.tryParse(response.data);
  ref.invalidate(dashboardGettingStartedProvider);
  ref.invalidate(dashboardOverviewProvider);
  bumpProductsListRefresh(ref);
  return result;
}

Future<void> handleDemoProductCleanup({
  required BuildContext context,
  required WidgetRef ref,
  bool confirm = true,
}) async {
  if (confirm) {
    final ok = await confirmRemoveDemoProducts(context);
    if (!ok || !context.mounted) return;
  }

  try {
    final result = await runDemoProductCleanup(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result?.successSnackBarMessage ?? 'Demo products removed.',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(apiErrorMessage(e))),
    );
  }
}
