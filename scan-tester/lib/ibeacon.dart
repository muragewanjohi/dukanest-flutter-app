class IBeaconSighting {
  const IBeaconSighting({required this.uuid, required this.major, required this.minor});

  final String uuid;
  final int major;
  final int minor;
}

const dukanestProximityUuid = '6e8a4c12-9f3d-4b71-a2e8-1d7c0b5e4a91';

/// Apple iBeacon manufacturer payload: 0x02 0x15, 16-byte UUID, major, minor.
IBeaconSighting? parseIBeacon(Map<int, List<int>> manufacturerData) {
  final apple = manufacturerData[0x004C];
  if (apple == null || apple.length < 23) return null;
  if (apple[0] != 0x02 || apple[1] != 0x15) return null;
  final hex = apple.sublist(2, 18).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  final uuid =
      '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  final major = (apple[18] << 8) | apple[19];
  final minor = (apple[20] << 8) | apple[21];
  return IBeaconSighting(uuid: uuid, major: major, minor: minor);
}
