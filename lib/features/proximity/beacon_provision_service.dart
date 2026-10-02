import 'package:flutter/services.dart';

/// Android bridge that writes a CP35 iBeacon profile. Shopper builds do not include this.
class BeaconProvisionService {
  BeaconProvisionService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.dukanest.dukanest_app/cp35');

  final MethodChannel _channel;

  Future<bool> isSdkAvailable() async {
    final result = await _channel.invokeMethod<bool>('isSdkAvailable');
    return result ?? false;
  }

  Future<List<NearbyBeacon>> scanNearbyBeacons() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('scanNearbyBeacons');
    return (raw ?? const [])
        .whereType<Map>()
        .map((item) => NearbyBeacon.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<bool> connect(String mac) async {
    final ok = await _channel.invokeMethod<bool>('connect', {'mac': mac});
    return ok ?? false;
  }

  Future<bool> unlock(String password) async {
    final ok = await _channel.invokeMethod<bool>('unlock', {'password': password});
    return ok ?? false;
  }

  Future<bool> writeIBeacon({
    required String uuid,
    required int major,
    required int minor,
    double txDbm = -13.5,
    int intervalMs = 500,
  }) async {
    final ok = await _channel.invokeMethod<bool>('writeIBeacon', {
      'uuid': uuid,
      'major': major,
      'minor': minor,
      'txDbm': txDbm,
      'intervalMs': intervalMs,
    });
    return ok ?? false;
  }

  Future<bool> restart(String password) async {
    final ok = await _channel.invokeMethod<bool>('restart', {'password': password});
    return ok ?? false;
  }

  Future<void> disconnect() async {
    await _channel.invokeMethod<bool>('disconnect');
  }

  /// Unlock, write the iBeacon slot, save, and restart. Does not change the password or enable TLM.
  Future<String?> configure({
    required String mac,
    required String password,
    required String uuid,
    required int major,
    required int minor,
    double txDbm = -13.5,
    int intervalMs = 500,
  }) async {
    if (password.length != 6) {
      return 'Password must be 6 characters.';
    }
    try {
      if (!await connect(mac)) {
        return 'Could not connect to the beacon. Hold it next to the phone and try again.';
      }
      if (!await unlock(password)) {
        return 'Wrong beacon password.';
      }
      if (!await writeIBeacon(
        uuid: uuid,
        major: major,
        minor: minor,
        txDbm: txDbm,
        intervalMs: intervalMs,
      )) {
        return 'Could not write the iBeacon profile.';
      }
      if (!await restart(password)) {
        return 'Could not save and restart the beacon.';
      }
      return null;
    } on PlatformException catch (error) {
      return error.message ?? 'Could not configure the beacon.';
    } finally {
      try {
        await disconnect();
      } catch (_) {
        // The restart command already closes the radio.
      }
    }
  }
}

class NearbyBeacon {
  const NearbyBeacon({required this.name, required this.mac, required this.rssi});

  final String name;
  final String mac;
  final int rssi;

  factory NearbyBeacon.fromMap(Map<String, dynamic> map) {
    return NearbyBeacon(
      name: map['name']?.toString() ?? 'Unknown',
      mac: map['mac']?.toString() ?? '',
      rssi: (map['rssi'] as num?)?.toInt() ?? 0,
    );
  }
}
