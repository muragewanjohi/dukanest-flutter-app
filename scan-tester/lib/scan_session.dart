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

/// Local demos name the supermarket because a phone address is an IP, not a subdomain.
const demoStoreSubdomain = 'supermarket';

bool isLocalDemoHost(String host) {
  return host == 'localhost' ||
      host == '127.0.0.1' ||
      host.endsWith('.localhost') ||
      RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$').hasMatch(host);
}

/// Showcase deck for a supermarket demo. No beacon, scan key, or typed shelf.
Uri showcaseAdsUri(String baseUrl) {
  final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.parse('$root/api/v1/proximity/ads/showcase');
  if (!isLocalDemoHost(uri.host)) return uri;
  return uri.replace(queryParameters: {'store': demoStoreSubdomain});
}

/// The ad set on the shelf of the beacon the phone is hearing.
Uri beaconAdUri({
  required String baseUrl,
  required String uuid,
  required int major,
  required int minor,
}) {
  final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.parse('$root/api/v1/proximity/ads/beacon');
  return uri.replace(
    queryParameters: {
      'uuid': uuid,
      'major': '$major',
      'minor': '$minor',
    },
  );
}

/// Absolute image address for a card. Store-relative paths use the scan base URL.
String? cardImageUrl(Object? raw, String baseUrl) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  final parsed = Uri.tryParse(value);
  if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) return value;
  final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  if (root.isEmpty) return value;
  return value.startsWith('/') ? '$root$value' : '$root/$value';
}

/// A message when the store has nothing to show. Null means the card can be painted.
String? noCardReason(Map<String, dynamic> body) {
  if (body['action'] == 'eligible' && body['card'] is Map) return null;
  return 'No card: ${body['reason'] ?? 'nothing to show'}';
}
