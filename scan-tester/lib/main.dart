import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ibeacon.dart';
import 'offer_notice.dart';
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
  final _baseUrl = TextEditingController(text: 'http://192.168.1.11:3000');
  final _sdkKey = TextEditingController();
  final _major = TextEditingController(text: '1');
  final _minor = TextEditingController(text: '2');

  bool _consent = false;
  bool _scanning = false;
  bool _busy = false;
  String? _status;
  String _opaqueId = '';
  String _visitId = '';
  Map<String, dynamic>? _card;
  String? _claimCode;
  IBeaconSighting? _lastSighting;
  final _watches = <String, BeaconWatch>{};
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _scanningSub;
  Timer? _presenceTimer;
  bool _keepScanning = false;

  @override
  void initState() {
    super.initState();
    _visitId = 'visit-${DateTime.now().millisecondsSinceEpoch}';
    _presenceTimer = Timer.periodic(const Duration(seconds: 1), (_) => _dropAbsent());
    _scanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      if (_scanning != scanning) setState(() => _scanning = scanning);
      if (!scanning && _keepScanning) unawaited(_startRadio());
    });
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl.text = prefs.getString('base_url') ?? _baseUrl.text;
    _sdkKey.text = prefs.getString('scan_key') ?? '';
    _consent = prefs.getBool('consent') ?? false;
    _opaqueId = prefs.getString('opaque_id') ?? '';
    if (_opaqueId.length < 8) {
      final random = Random.secure();
      _opaqueId = 'shopper-${List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join()}';
      await prefs.setString('opaque_id', _opaqueId);
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', _baseUrl.text.trim());
    await prefs.setString('scan_key', _sdkKey.text.trim());
    await prefs.setBool('consent', _consent);
  }

  @override
  void dispose() {
    _keepScanning = false;
    _presenceTimer?.cancel();
    _scanningSub?.cancel();
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    _baseUrl.dispose();
    _sdkKey.dispose();
    _major.dispose();
    _minor.dispose();
    super.dispose();
  }

  Future<bool> _prepareRadio() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final granted = statuses.values.every((status) => status.isGranted);
    if (!granted) {
      setState(() => _status = 'Allow Bluetooth and location so the phone can hear beacons.');
      return false;
    }
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      setState(() => _status = 'Turn Bluetooth on, then start scanning.');
      return false;
    }
    return true;
  }

  Future<void> _startRadio() async {
    if (!_keepScanning) return;
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
  }

  Future<void> _toggleScan() async {
    if (_keepScanning) {
      _keepScanning = false;
      await FlutterBluePlus.stopScan();
      setState(() => _scanning = false);
      return;
    }
    if (!_consent) {
      setState(() => _status = 'Turn on in-store experiences before scanning.');
      return;
    }
    if (_sdkKey.text.trim().isEmpty) {
      setState(() => _status = 'Paste a scan key from the supermarket SDK keys page.');
      return;
    }
    await _saveSettings();
    if (!await _prepareRadio()) return;
    _scanSub ??= FlutterBluePlus.scanResults.listen(_onResults);
    _keepScanning = true;
    await _startRadio();
    setState(() {
      _scanning = true;
      _status = 'Listening for the DukaNest beacon.';
    });
  }

  void _dropAbsent() {
    if (!mounted || _watches.isEmpty) return;
    final now = DateTime.now();
    final removed = <String>[];
    _watches.removeWhere((key, watch) {
      if (!watch.isAway(now)) return false;
      removed.add(key);
      return true;
    });
    if (removed.isEmpty) return;
    final showing = _lastSighting;
    final showingKey = showing == null ? null : '${showing.uuid}:${showing.major}:${showing.minor}';
    if (showingKey != null && removed.contains(showingKey)) {
      setState(() {
        _card = null;
        _claimCode = null;
        _status = 'The beacon left range.';
      });
      return;
    }
    setState(() {});
  }

  void _onResults(List<ScanResult> results) {
    final now = DateTime.now();
    for (final result in results) {
      final sighting = parseIBeacon(result.advertisementData.manufacturerData);
      if (sighting == null || !isDukanestSighting(sighting)) continue;
      final key = '${sighting.uuid}:${sighting.major}:${sighting.minor}';
      final watch = _watches.putIfAbsent(key, () => BeaconWatch(sighting, now));
      if (watch.notePacket(now, result.rssi)) {
        unawaited(_ask(sighting, now.difference(watch.firstSeen).inMilliseconds, 'ble'));
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _askManual() async {
    final major = int.tryParse(_major.text.trim());
    final minor = int.tryParse(_minor.text.trim());
    if (major == null || minor == null) {
      setState(() => _status = 'Major and minor must be numbers.');
      return;
    }
    if (!_consent || _sdkKey.text.trim().isEmpty) {
      setState(() => _status = 'Save consent and a scan key first.');
      return;
    }
    await _saveSettings();
    await _ask(IBeaconSighting(uuid: dukanestProximityUuid, major: major, minor: minor), 2500, 'ble');
  }

  Future<void> _ask(IBeaconSighting sighting, int dwellMs, String source) async {
    setState(() {
      _busy = true;
      _claimCode = null;
      _lastSighting = sighting;
      _status = 'Asking the store for this zone.';
    });
    try {
      await _track(sighting, 'detected', onScreen: false, source: source);
      final uri = currentAdUri(
        baseUrl: _baseUrl.text,
        sighting: sighting,
        opaqueCustomerId: _opaqueId,
        visitId: _visitId,
        dwellElapsedMs: dwellMs,
        source: source,
      );
      final response = await http.get(uri, headers: {'Authorization': 'Bearer ${_sdkKey.text.trim()}'});
      final json = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(json is Map ? json['error'] ?? 'Request failed' : 'Request failed');
      }
      final map = Map<String, dynamic>.from(json as Map);
      final reason = noCardReason(map);
      if (reason != null) {
        setState(() {
          _card = null;
          _status = reason;
        });
        return;
      }
      final card = Map<String, dynamic>.from(map['card'] as Map);
      setState(() {
        _card = card;
        _status = 'Card is on screen.';
      });
      final headline = card['headline']?.toString().trim() ?? '';
      final title = headline.isEmpty ? 'In-store offer' : headline;
      final rawBody = card['body']?.toString().trim() ?? '';
      final noticeBody = rawBody.isEmpty || rawBody == title ? 'An offer is ready in this aisle.' : rawBody;
      try {
        await offerNotifications.showOffer(
          title: title,
          body: noticeBody,
          imageUrl: cardImageUrl(card['image_url'], _baseUrl.text),
        );
      } catch (_) {
        // The card stays on screen even when the shade alert cannot be posted.
      }
      await _track(
        sighting,
        'delivered',
        onScreen: true,
        source: source,
        campaignId: card['campaign_id']?.toString(),
      );
    } catch (error) {
      setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _track(
    IBeaconSighting sighting,
    String eventType, {
    required bool onScreen,
    required String source,
    String? campaignId,
  }) async {
    final response = await http.post(
      Uri.parse('${_baseUrl.text.trim()}/api/v1/proximity/events'),
      headers: {
        'Authorization': 'Bearer ${_sdkKey.text.trim()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(proximityEventBody(
        sighting: sighting,
        eventType: eventType,
        opaqueCustomerId: _opaqueId,
        visitId: _visitId,
        onScreen: onScreen,
        source: source,
        campaignId: campaignId,
      )),
    );
    if (response.statusCode >= 400 && eventType == 'delivered') {
      final json = jsonDecode(response.body);
      throw Exception(json is Map ? json['error'] ?? 'Could not record the view' : 'Could not record the view');
    }
  }

  Future<void> _act(String eventType) async {
    final card = _card;
    if (card == null) return;
    final campaignId = card['campaign_id']?.toString();
    if (campaignId == null) return;
    final sighting = _lastSighting ??
        IBeaconSighting(
          uuid: dukanestProximityUuid,
          major: int.tryParse(_major.text) ?? 1,
          minor: int.tryParse(_minor.text) ?? 2,
        );
    setState(() => _busy = true);
    try {
      if (eventType == 'claimed') {
        final response = await http.post(
          Uri.parse('${_baseUrl.text.trim()}/api/v1/proximity/claims'),
          headers: {
            'Authorization': 'Bearer ${_sdkKey.text.trim()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'campaign_id': campaignId,
            'opaque_customer_id': _opaqueId,
          }),
        );
        final json = jsonDecode(response.body);
        if (response.statusCode >= 400) {
          throw Exception(json is Map ? json['error'] ?? 'Claim failed' : 'Claim failed');
        }
        final data = json is Map ? json['data'] : null;
        setState(() => _claimCode = data is Map ? data['code']?.toString() : null);
      }
      await _track(sighting, eventType, onScreen: true, source: 'ble', campaignId: campaignId);
      setState(() => _status = eventType == 'claimed' ? 'Claim recorded.' : 'Click recorded.');
    } catch (error) {
      setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return Scaffold(
      appBar: AppBar(title: const Text('DukaNest Scan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Test shopper scan only. Beacon setup stays in the DukaNest store app.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'Store address',
              hintText: 'http://192.168.1.11:3000',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sdkKey,
            decoration: const InputDecoration(
              labelText: 'Scan key',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('In-store experiences'),
            subtitle: const Text('Bluetooth can show an offer after a short dwell. This can be turned off.'),
            value: _consent,
            onChanged: (value) => setState(() => _consent = value),
          ),
          FilledButton(
            onPressed: _toggleScan,
            child: Text(_scanning ? 'Stop scanning' : 'Start scanning'),
          ),
          const SizedBox(height: 16),
          Text('Heard', style: Theme.of(context).textTheme.titleMedium),
          if (_watches.isEmpty) const Text('No DukaNest beacon yet.'),
          ..._watches.values.map(
            (watch) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('major ${watch.sighting.major} · minor ${watch.sighting.minor}'),
              subtitle: Text('signal ${watch.rssi} dBm'),
            ),
          ),
          const Divider(),
          Text('No radio nearby', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _major,
                  decoration: const InputDecoration(labelText: 'Major', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _minor,
                  decoration: const InputDecoration(labelText: 'Minor', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _askManual,
            child: const Text('Ask for this zone'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!),
          ],
          if (card != null) ...[
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cardImageUrl(card['image_url'], _baseUrl.text) case final imageUrl?)
                    Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                        height: 180,
                        child: Center(child: Text('Image could not be loaded')),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(card['headline']?.toString() ?? 'Offer', style: Theme.of(context).textTheme.titleLarge),
                    if (card['body']?.toString().trim().isNotEmpty == true &&
                        card['body'].toString().trim() != card['headline']?.toString().trim())
                      Text(card['body'].toString()),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : () => _act('clicked'),
                      child: Text(card['cta_label']?.toString().isNotEmpty == true ? card['cta_label'].toString() : 'View offer'),
                    ),
                    if (card['coupon_enabled'] == true)
                      TextButton(
                        onPressed: _busy ? null : () => _act('claimed'),
                        child: Text(card['coupon_label']?.toString() ?? 'Claim'),
                      ),
                    if (_claimCode != null) SelectableText('Claim code $_claimCode'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
