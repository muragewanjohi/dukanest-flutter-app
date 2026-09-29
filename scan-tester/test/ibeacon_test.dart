import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_scan_tester/ibeacon.dart';

void main() {
  test('reads a DukaNest iBeacon advertisement', () {
    final payload = [
      0x02,
      0x15,
      0x6e, 0x8a, 0x4c, 0x12, 0x9f, 0x3d, 0x4b, 0x71,
      0xa2, 0xe8, 0x1d, 0x7c, 0x0b, 0x5e, 0x4a, 0x91,
      0x00, 0x01,
      0x00, 0x02,
      0xc5,
    ];
    final sighting = parseIBeacon({0x004C: payload});
    expect(sighting?.uuid, dukanestProximityUuid);
    expect(sighting?.major, 1);
    expect(sighting?.minor, 2);
  });

  test('ignores advertisements that are not iBeacon', () {
    expect(parseIBeacon({0x004C: [0x01, 0x02]}), isNull);
    expect(parseIBeacon({}), isNull);
  });
}
