import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ibeacon.dart';
import 'ios_beacon_radio.dart';
import 'scan_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScanTesterApp());
}

class ScanTesterApp extends StatelessWidget {
  const ScanTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DukaNest Scan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF355CAD)),
        useMaterial3: true,
      ),
      home: const ScanHome(),
    );
  }
}

class ScanHome extends StatefulWidget {
  const ScanHome({super.key});

  @override
  State<ScanHome> createState() => _ScanHomeState();
}

class _ScanHomeState extends State<ScanHome> {
  static const _defaultBaseUrl = 'https://www.dukanest.com';

  String _baseUrl = _defaultBaseUrl;
  String _status = 'Listening for the store beacon.';
  String? _shelf;
  Map<String, dynamic>? _card;
  bool _busy = false;
  final _watches = <String, BeaconWatch>{};
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<RangedBeacon>>? _iosSub;
  StreamSubscription<bool>? _scanningSub;
  Timer? _presenceTimer;
  Timer? _refreshTimer;
  bool _keepScanning = false;
  IBeaconSighting? _hearing;

  @override
  void initState() {
    super.initState();
    _presenceTimer = Timer.periodic(const Duration(seconds: 1), (_) => _dropAbsent());
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _refreshHeardAd());
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      _scanningSub = FlutterBluePlus.isScanning.listen((scanning) {
        if (!scanning && _keepScanning) unawaited(_startRadio());
      });
    }
    _start();
  }

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('base_url')?.trim();
    final savedHost = saved == null ? '' : Uri.tryParse(saved)?.host ?? '';
    if (saved != null && saved.isNotEmpty && !isLocalDemoHost(savedHost)) {
      _baseUrl = saved;
    } else if (saved != null && saved.isNotEmpty) {
      await prefs.setString('base_url', _defaultBaseUrl);
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _iosSub ??= IosBeaconRadio.instance.sightings.listen((beacons) {
        for (final beacon in beacons) {
          _hear(beacon.sighting, beacon.rssi);
        }
      });
    }
    if (!await _prepareRadio()) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (mounted) setState(() => _status = 'Listening for the store beacon.');
      return;
    }
    _scanSub ??= FlutterBluePlus.scanResults.listen(_onResults);
    _keepScanning = true;
    await _startRadio();
    if (mounted) setState(() => _status = 'Listening for the store beacon.');
  }

  Future<bool> _prepareRadio() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await IosBeaconRadio.instance.start();
      if (status == 'listening') return true;
      setState(() {
        _status = status == 'disabled'
            ? 'Turn Location on. The ad appears when the beacon is heard.'
            : 'Allow location so the phone can hear the store beacon.';
      });
      return false;
    }
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    if (!statuses.values.every((status) => status.isGranted)) {
      setState(() => _status = 'Allow Bluetooth and location so the phone can hear the beacon.');
      return false;
    }
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      setState(() => _status = 'Turn Bluetooth on. The ad appears when the beacon is heard.');
      return false;
    }
    return true;
  }

  Future<void> _startRadio() async {
    if (!_keepScanning) return;
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
  }

  void _dropAbsent() {
    if (!mounted || _watches.isEmpty) return;
    final now = DateTime.now();
    _watches.removeWhere((_, watch) => watch.isAway(now));
    final hearing = _hearing;
    if (hearing == null) return;
    final key = '${hearing.uuid}:${hearing.major}:${hearing.minor}';
    if (_watches.containsKey(key)) return;
    setState(() {
      _hearing = null;
      _status = 'Beacon left range. Listening again.';
    });
  }

  void _onResults(List<ScanResult> results) {
    for (final result in results) {
      final sighting = parseIBeacon(result.advertisementData.manufacturerData);
      if (sighting == null) continue;
      _hear(sighting, result.rssi);
    }
  }

  void _hear(IBeaconSighting sighting, int rssi) {
    if (!isDukanestSighting(sighting)) return;
    final now = DateTime.now();
    final key = '${sighting.uuid}:${sighting.major}:${sighting.minor}';
    final watch = _watches.putIfAbsent(key, () => BeaconWatch(sighting, now));
    if (watch.notePacket(now, rssi)) {
      unawaited(_loadAd(sighting));
    }
  }

  Future<void> _refreshHeardAd() async {
    final hearing = _hearing;
    if (hearing == null || _busy) return;
    await _loadAd(hearing);
  }

  Future<void> _loadAd(IBeaconSighting sighting) async {
    setState(() {
      _busy = true;
      _hearing = sighting;
      _status = 'Beacon heard. Loading the ad set in the store.';
    });
    try {
      final response = await http.get(
        beaconAdUri(
          baseUrl: _baseUrl,
          uuid: sighting.uuid,
          major: sighting.major,
          minor: sighting.minor,
        ),
      );
      if (response.statusCode == 404) {
        setState(() => _status = 'Beacon ads are not published on the store yet.');
        return;
      }
      final json = jsonDecode(response.body);
      if (response.statusCode != 200 || json is! Map) {
        throw Exception(json is Map ? json['error'] ?? 'Could not load the ad' : 'Could not load the ad');
      }
      final body = Map<String, dynamic>.from(json);
      final shelf = _shelfLabel(body['shelf_section'], body['branch']);
      if (body['action'] != 'eligible' || body['card'] is! Map) {
        setState(() {
          _card = null;
          _shelf = shelf;
          _status = body['reason'] == 'beacon_not_configured'
              ? 'This is not the beacon configured for the store.'
              : 'No ad is set for ${shelf == 'this shelf' ? 'this beacon' : shelf}. Set one in the store.';
        });
        return;
      }
      setState(() {
        _card = Map<String, dynamic>.from(body['card'] as Map);
        _shelf = shelf;
        _status = 'Showing the ad set for $shelf.';
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'Could not load the ad. Check the phone has internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _keepScanning = false;
    _presenceTimer?.cancel();
    _refreshTimer?.cancel();
    _scanningSub?.cancel();
    _scanSub?.cancel();
    _iosSub?.cancel();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(IosBeaconRadio.instance.stop());
    } else {
      unawaited(FlutterBluePlus.stopScan());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return Scaffold(
      appBar: AppBar(title: const Text('DukaNest Scan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_status),
          if (_shelf != null) ...[
            const SizedBox(height: 8),
            Text(_shelf!, style: Theme.of(context).textTheme.titleMedium),
          ],
          const SizedBox(height: 16),
          if (card == null)
            const Text('Set an ad on this beacon’s shelf in the store. It appears here when the beacon is heard.')
          else
            _OfferCard(card: card, baseUrl: _baseUrl),
        ],
      ),
    );
  }
}

String _shelfLabel(Object? shelf, Object? branch) {
  final shelfName = shelf?.toString().trim() ?? '';
  final branchName = branch?.toString().trim() ?? '';
  if (shelfName.isNotEmpty && branchName.isNotEmpty) return '$shelfName · $branchName';
  if (shelfName.isNotEmpty) return shelfName;
  if (branchName.isNotEmpty) return branchName;
  return 'this shelf';
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.card, required this.baseUrl});

  final Map<String, dynamic> card;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final headline = card['headline']?.toString().trim() ?? '';
    final body = card['body']?.toString().trim() ?? '';
    final advertiser = card['advertiser_name']?.toString().trim() ?? '';
    final imageUrl = cardImageUrl(card['image_url'], baseUrl);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 220,
                child: Center(child: Text('Image could not be loaded')),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (advertiser.isNotEmpty) Text(advertiser, style: Theme.of(context).textTheme.labelLarge),
                Text(
                  headline.isEmpty ? 'In-store offer' : headline,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (body.isNotEmpty && body != headline) ...[
                  const SizedBox(height: 8),
                  Text(body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
