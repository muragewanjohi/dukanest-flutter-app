import 'package:flutter/services.dart';

import 'ibeacon.dart';

/// One iBeacon Core Location is currently ranging.
class RangedBeacon {
  const RangedBeacon({required this.sighting, required this.rssi});

  final IBeaconSighting sighting;
  final int rssi;
}

/// Packets from the iOS ranging channel. Malformed entries are dropped.
List<RangedBeacon> parseRangedBeacons(Object? event) {
  if (event is! List) return const [];
  final ranged = <RangedBeacon>[];
  for (final item in event) {
    if (item is! Map) continue;
    final uuid = item['uuid']?.toString().trim() ?? '';
    final major = _asInt(item['major']);
    final minor = _asInt(item['minor']);
    if (uuid.isEmpty || major == null || minor == null) continue;
    ranged.add(
      RangedBeacon(
        sighting: IBeaconSighting(uuid: uuid, major: major, minor: minor),
        rssi: _asInt(item['rssi']) ?? 0,
      ),
    );
  }
  return ranged;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

/// Foreground iBeacon ranging. Android keeps using a Bluetooth scan.
class IosBeaconRadio {
  IosBeaconRadio._();

  static final instance = IosBeaconRadio._();

  static const _control = MethodChannel('com.dukanest.scan/beacon_control');
  static const _events = EventChannel('com.dukanest.scan/beacons');

  Stream<List<RangedBeacon>>? _sightings;

  Stream<List<RangedBeacon>> get sightings {
    return _sightings ??= _events.receiveBroadcastStream().map(parseRangedBeacons);
  }

  /// `listening`, `denied`, or `disabled`.
  Future<String> start() async {
    final status = await _control.invokeMethod<String>('start');
    return status ?? 'denied';
  }

  Future<void> stop() async {
    await _control.invokeMethod<void>('stop');
  }
}
