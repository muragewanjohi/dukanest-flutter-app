import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'reward_checklist_data.dart';

/// Resolves a GoRouter location for an incomplete reward checklist step.
String? rewardStepRoute(RewardStep step) {
  final href = step.href.trim();
  if (href.isNotEmpty) {
    final fromHref = _routeFromHref(href);
    if (fromHref != null) return fromHref;
  }
  return _routeFromStepId(step.stepId);
}

void navigateToRewardStep(BuildContext context, RewardStep step) {
  if (step.done) return;
  final route = rewardStepRoute(step);
  if (route == null || route.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This step is not available in the app yet.'),
      ),
    );
    return;
  }
  context.push(route);
}

String? _routeFromStepId(String stepId) {
  final k = stepId.trim().toLowerCase().replaceAll('-', '_');
  if (k.isEmpty) return null;

  switch (k) {
    case 'products_five':
    case 'product':
    case 'products':
      return '/products';
    case 'categories_two':
    case 'category':
    case 'categories':
      return '/categories';
    case 'hero_image':
    case 'hero_description':
    case 'hero':
      return '/hero-section/edit';
    case 'banner_updated':
    case 'split_layout_image':
    case 'split_layout':
    case 'homepage':
    case 'home_page':
      return '/page-editor/home';
    case 'sale_active':
    case 'sale_products_two':
    case 'sale':
    case 'sales':
      return '/sales';
    default:
      return null;
  }
}

/// Maps web dashboard deep links from the API into mobile routes.
String? _routeFromHref(String href) {
  var path = href.trim();
  if (path.isEmpty) return null;

  final uri = Uri.tryParse(path);
  if (uri != null && uri.hasScheme) {
    path = uri.path;
  }
  if (!path.startsWith('/')) path = '/$path';

  // Already a mobile route.
  const mobilePrefixes = [
    '/products',
    '/categories',
    '/attributes',
    '/hero-section',
    '/page-editor',
    '/sales',
    '/content-management',
    '/store-identity',
    '/payment-settings',
    '/shipping-delivery',
  ];
  for (final prefix in mobilePrefixes) {
    if (path == prefix || path.startsWith('$prefix/')) return path;
  }

  final lower = path.toLowerCase();
  if (lower.contains('hero')) return '/hero-section/edit';
  if (lower.contains('/pages/') && lower.contains('edit')) {
    return '/page-editor/home';
  }
  if (lower.contains('product')) return '/products';
  if (lower.contains('categor')) return '/categories';
  if (lower.contains('sale')) return '/sales';
  if (lower.contains('content')) return '/content-management';

  return null;
}
