import 'ibeacon.dart';

const proximityDwellMs = 2500;

/// A packet this long after the last one starts the dwell again.
const proximityGapResetMs = 3000;

/// No packet for this long means the beacon has left.
const proximityAwayMs = 15000;

bool dwellElapsed(DateTime firstSeen, DateTime now) {
  return now.difference(firstSeen).inMilliseconds >= proximityDwellMs;
}

/// One beacon the phone is currently hearing.
class BeaconWatch {
  BeaconWatch(this.sighting, DateTime now)
      : firstSeen = now,
        lastSeen = now;

  final IBeaconSighting sighting;
  DateTime firstSeen;
  DateTime lastSeen;
  int rssi = 0;
  bool asked = false;

  /// True when this packet finishes a continuous dwell and the store should be asked once.
  bool notePacket(DateTime now, int rssi) {
    if (now.difference(lastSeen).inMilliseconds > proximityGapResetMs) {
      firstSeen = now;
      asked = false;
    }
    lastSeen = now;
    this.rssi = rssi;
    if (asked || !dwellElapsed(firstSeen, now)) return false;
    asked = true;
    return true;
  }

  bool isAway(DateTime now) {
    return now.difference(lastSeen).inMilliseconds >= proximityAwayMs;
  }
}

bool isDukanestSighting(IBeaconSighting sighting) {
  return sighting.uuid.toLowerCase() == dukanestProximityUuid;
}

Uri currentAdUri({
  required String baseUrl,
  required IBeaconSighting sighting,
  required String opaqueCustomerId,
  required String visitId,
  required int dwellElapsedMs,
  String source = 'ble',
  String locale = 'en',
}) {
  final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  return Uri.parse('$root/api/v1/proximity/ads/current').replace(
    queryParameters: {
      'uuid': sighting.uuid,
      'major': '${sighting.major}',
      'minor': '${sighting.minor}',
      'opaque_customer_id': opaqueCustomerId,
      'visit_id': visitId,
      'consent': 'true',
      'source': source,
      'dwell_elapsed_ms': '$dwellElapsedMs',
      'locale': locale,
    },
  );
}

Map<String, Object?> proximityEventBody({
  required IBeaconSighting sighting,
  required String eventType,
  required String opaqueCustomerId,
  required String visitId,
  required bool onScreen,
  String source = 'ble',
  String? campaignId,
}) {
  return {
    'event_type': eventType,
    'uuid': sighting.uuid,
    'major': sighting.major,
    'minor': sighting.minor,
    'opaque_customer_id': opaqueCustomerId,
    'visit_id': visitId,
    'consent': true,
    'source': source,
    'impression_on_screen': onScreen,
    'campaign_id': ?campaignId,
  };
}

/// A message when the store has nothing to show. Null means the card can be painted.
String? noCardReason(Map<String, dynamic> body) {
  if (body['action'] == 'eligible' && body['card'] is Map) return null;
  return 'No card: ${body['reason'] ?? 'nothing to show'}';
}
