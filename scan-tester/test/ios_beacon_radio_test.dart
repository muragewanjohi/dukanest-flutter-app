import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_scan_tester/ibeacon.dart';
import 'package:proximity_scan_tester/ios_beacon_radio.dart';
import 'package:proximity_scan_tester/scan_session.dart';

void main() {
  test('reads ranged DukaNest beacons from Core Location', () {
    final ranged = parseRangedBeacons([
      {
        'uuid': dukanestProximityUuid.toUpperCase(),
        'major': 1,
        'minor': 2,
        'rssi': -62,
      },
    ]);
    expect(ranged, hasLength(1));
    expect(ranged.single.sighting.uuid, dukanestProximityUuid.toUpperCase());
    expect(ranged.single.sighting.major, 1);
    expect(ranged.single.sighting.minor, 2);
    expect(ranged.single.rssi, -62);
    expect(isDukanestSighting(ranged.single.sighting), isTrue);
  });

  test('drops malformed ranging packets', () {
    expect(parseRangedBeacons(null), isEmpty);
    expect(parseRangedBeacons(['beacon']), isEmpty);
    expect(parseRangedBeacons([
      {'uuid': '', 'major': 1, 'minor': 2},
    ]), isEmpty);
  });
}
