import 'package:dukanest_app/core/navigation/in_app_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveInAppRoute — dashboard URLs and paths', () {
    test('maps a full dukanest dashboard URL to the native route', () {
      expect(
        resolveInAppRoute('https://acme.dukanest.com/dashboard/themes'),
        '/themes',
      );
      expect(
        resolveInAppRoute('https://www.dukanest.com/dashboard/settings'),
        '/settings',
      );
    });

    test('maps a bare /dashboard/* path', () {
      expect(resolveInAppRoute('/dashboard/products'), '/products');
      expect(resolveInAppRoute('/dashboard/orders'), '/orders');
      expect(resolveInAppRoute('/dashboard/themes/customize'), '/themes/customize');
    });

    test('passes an already-native app path through', () {
      expect(resolveInAppRoute('/themes'), '/themes');
      expect(resolveInAppRoute('/payment-settings'), '/payment-settings');
      expect(resolveInAppRoute('/products/new'), '/products/new');
    });

    test('preserves a bare deep-link sub-route', () {
      expect(resolveInAppRoute('/products/edit/SKU-123'.toLowerCase()),
          '/products/edit/sku-123');
      expect(resolveInAppRoute('/analytics/expenses'), '/analytics/expenses');
    });

    test('translates a /dashboard/* web deep link to the area root', () {
      expect(resolveInAppRoute('/dashboard/products/some/web/path'), '/products');
    });

    test('maps payments/tax/delivery aliases', () {
      expect(resolveInAppRoute('/dashboard/payments'), '/payment-settings');
      expect(resolveInAppRoute('/dashboard/tax'), '/tax-settings');
      expect(resolveInAppRoute('/dashboard/delivery-zones'), '/shipping-delivery');
    });

    test('openAssistant query routes to the assistant tab', () {
      expect(
        resolveInAppRoute('https://www.dukanest.com/dashboard?openAssistant=1'),
        '/assistant',
      );
    });
  });

  group('resolveInAppRoute — help articles', () {
    test('maps a theme help article to the Themes screen', () {
      expect(
        resolveInAppRoute('https://www.dukanest.com/help/customize-your-store-theme'),
        '/themes',
      );
      expect(resolveInAppRoute('/help/managing-themes'), '/themes');
    });

    test('maps payment / delivery help articles', () {
      expect(
        resolveInAppRoute('https://www.dukanest.com/help/set-up-mpesa-payments'),
        '/payment-settings',
      );
      expect(
        resolveInAppRoute('https://www.dukanest.com/help/delivery-zones-explained'),
        '/shipping-delivery',
      );
    });

    test('leaves a conceptual help article for the browser', () {
      expect(
        resolveInAppRoute('https://www.dukanest.com/help/understanding-your-analytics'),
        isNull,
      );
    });
  });

  group('resolveInAppRoute — external', () {
    test('non-dukanest hosts are external', () {
      expect(resolveInAppRoute('https://google.com/dashboard/themes'), isNull);
      expect(resolveInAppRoute('https://example.com/help/theme'), isNull);
    });

    test('the storefront root is external', () {
      expect(resolveInAppRoute('https://acme.dukanest.com'), isNull);
      expect(resolveInAppRoute('https://acme.dukanest.com/'), isNull);
    });

    test('an unknown dashboard area is not forced in-app', () {
      expect(resolveInAppRoute('/dashboard/some-future-thing'), isNull);
    });

    test('empty / unparseable input', () {
      expect(resolveInAppRoute(''), isNull);
      expect(resolveInAppRoute('   '), isNull);
    });
  });
}
