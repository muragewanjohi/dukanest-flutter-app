import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_scan_tester/ibeacon.dart';
import 'package:proximity_scan_tester/scan_session.dart';

void main() {
  const sighting = IBeaconSighting(uuid: dukanestProximityUuid, major: 1, minor: 2);
  final firstSeen = DateTime.utc(2026, 9, 29, 8);

  test('a gap in packets starts the dwell again', () {
    final watch = BeaconWatch(sighting, firstSeen);
    expect(watch.notePacket(firstSeen, -50), isFalse);
    final returned = firstSeen.add(const Duration(milliseconds: 4000));
    expect(watch.notePacket(returned, -60), isFalse);
    expect(watch.notePacket(returned.add(const Duration(milliseconds: 2500)), -55), isTrue);
  });

  test('continuous packets ask the store once', () {
    final watch = BeaconWatch(sighting, firstSeen);
    expect(watch.notePacket(firstSeen, -40), isFalse);
    expect(watch.notePacket(firstSeen.add(const Duration(milliseconds: 1000)), -40), isFalse);
    expect(watch.notePacket(firstSeen.add(const Duration(milliseconds: 2500)), -42), isTrue);
    expect(watch.notePacket(firstSeen.add(const Duration(milliseconds: 3000)), -42), isFalse);
  });

  test('silence marks the beacon as away', () {
    final watch = BeaconWatch(sighting, firstSeen);
    watch.notePacket(firstSeen, -40);
    expect(watch.isAway(firstSeen.add(const Duration(seconds: 14))), isFalse);
    expect(watch.isAway(firstSeen.add(const Duration(seconds: 15))), isTrue);
  });

  test('a beacon is not ready until the shopper has dwelled', () {
    expect(dwellElapsed(firstSeen, firstSeen.add(const Duration(milliseconds: 2499))), isFalse);
    expect(dwellElapsed(firstSeen, firstSeen.add(const Duration(milliseconds: 2500))), isTrue);
  });

  test('only the DukaNest UUID is treated as this store', () {
    expect(isDukanestSighting(sighting), isTrue);
    expect(
      isDukanestSighting(const IBeaconSighting(uuid: 'e2c56db5-dffb-48d2-b060-d0f5a71096e0', major: 1, minor: 2)),
      isFalse,
    );
  });

  test('the current-ad request carries dwell, consent, and the zone', () {
    final uri = currentAdUri(
      baseUrl: 'http://192.168.1.11:3000/',
      sighting: sighting,
      opaqueCustomerId: 'shopper-abc',
      visitId: 'visit-1',
      dwellElapsedMs: 2500,
    );
    expect(uri.path, '/api/v1/proximity/ads/current');
    expect(uri.queryParameters['major'], '1');
    expect(uri.queryParameters['minor'], '2');
    expect(uri.queryParameters['consent'], 'true');
    expect(uri.queryParameters['dwell_elapsed_ms'], '2500');
    expect(uri.queryParameters['opaque_customer_id'], 'shopper-abc');
  });

  test('a delivered event is marked on screen and a detection is not', () {
    final detected = proximityEventBody(
      sighting: sighting,
      eventType: 'detected',
      opaqueCustomerId: 'shopper-abc',
      visitId: 'visit-1',
      onScreen: false,
    );
    final delivered = proximityEventBody(
      sighting: sighting,
      eventType: 'delivered',
      opaqueCustomerId: 'shopper-abc',
      visitId: 'visit-1',
      onScreen: true,
      campaignId: 'campaign-1',
    );
    expect(detected['impression_on_screen'], isFalse);
    expect(detected.containsKey('campaign_id'), isFalse);
    expect(delivered['impression_on_screen'], isTrue);
    expect(delivered['campaign_id'], 'campaign-1');
  });

  test('a stored image stays absolute and a relative path uses the store address', () {
    expect(
      cardImageUrl('https://cdn.example/coke.png', 'http://127.0.0.1:3000'),
      'https://cdn.example/coke.png',
    );
    expect(cardImageUrl('/media/coke.png', 'http://127.0.0.1:3000/'), 'http://127.0.0.1:3000/media/coke.png');
    expect(cardImageUrl('  ', 'http://127.0.0.1:3000'), isNull);
  });

  test('an ineligible response does not become a shopper card', () {
    expect(noCardReason({'action': 'none', 'reason': 'frequency_cap'}), 'No card: frequency_cap');
    expect(
      noCardReason({
        'action': 'eligible',
        'card': {'campaign_id': 'campaign-1', 'headline': 'Tuesday Offers'},
      }),
      isNull,
    );
  });
}
