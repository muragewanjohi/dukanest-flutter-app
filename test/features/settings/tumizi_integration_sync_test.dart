import 'package:dukanest_app/features/settings/tumizi_integration_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldRequestTumiziMerchantCreation', () {
    test('true when there is no existing config', () {
      expect(shouldRequestTumiziMerchantCreation(null), isTrue);
    });

    test('true when nothing has been provisioned yet', () {
      expect(shouldRequestTumiziMerchantCreation({'enabled': false}), isTrue);
    });

    // Regression test: registration queues Tumizi provisioning async
    // (provisioning_status: 'pending') and only a server cron ever drains
    // that queue. Treating "pending" as "skip creation" left new tenants
    // stuck forever with enabled=true but no merchantExternalId — every
    // Tumizi action then fails with "Tumizi is not enabled for this store"
    // no matter how many times the merchant re-enables it.
    test('true while provisioning is still pending (must retry, not skip)', () {
      expect(
        shouldRequestTumiziMerchantCreation({
          'enabled': false,
          'metadata': {'provisioning_status': 'pending'},
        }),
        isTrue,
      );
    });

    test('true when a previous provisioning attempt failed', () {
      expect(
        shouldRequestTumiziMerchantCreation({
          'metadata': {'provisioning_status': 'failed'},
        }),
        isTrue,
      );
    });

    test('false once a merchant is already linked, even mid-provisioning', () {
      expect(
        shouldRequestTumiziMerchantCreation({
          'enabled': true,
          'merchantExternalId': 'storeflow-tenant-1',
          'metadata': {'provisioning_status': 'pending'},
        }),
        isFalse,
      );
    });

    test('recognises snake_case and alternate id keys', () {
      expect(
        shouldRequestTumiziMerchantCreation({'merchant_external_id': 'x'}),
        isFalse,
      );
      expect(
        shouldRequestTumiziMerchantCreation({'externalId': 'x'}),
        isFalse,
      );
    });
  });

  group('tumiziConfigFromResponse', () {
    test('unwraps a nested data envelope', () {
      final config = tumiziConfigFromResponse({
        'data': {'enabled': true},
      });
      expect(config, {'enabled': true});
    });

    test('passes through a flat map', () {
      expect(tumiziConfigFromResponse({'enabled': false}), {'enabled': false});
    });

    test('null for non-map input', () {
      expect(tumiziConfigFromResponse(null), isNull);
      expect(tumiziConfigFromResponse('nope'), isNull);
    });
  });
}
