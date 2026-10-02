import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../beacon_provision_service.dart';

class _ConfigureBeaconDialog extends StatefulWidget {
  const _ConfigureBeaconDialog({
    required this.provision,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.txPower,
    required this.intervalMs,
  });

  final BeaconProvisionService provision;
  final String uuid;
  final int major;
  final int minor;
  final double txPower;
  final int intervalMs;

  @override
  State<_ConfigureBeaconDialog> createState() => _ConfigureBeaconDialogState();
}

class _ConfigureBeaconDialogState extends State<_ConfigureBeaconDialog> {
  final _password = TextEditingController(text: 'dx1234');
  bool _busy = false;
  String? _status;
  List<NearbyBeacon> _nearby = const [];
  NearbyBeacon? _selected;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _status = 'Looking for nearby beacons…';
      _nearby = const [];
      _selected = null;
    });
    try {
      final nearby = await widget.provision.scanNearbyBeacons();
      if (!mounted) return;
      setState(() {
        _nearby = nearby;
        _selected = nearby.isEmpty ? null : nearby.first;
        _status = nearby.isEmpty
            ? 'No Bluetooth devices found. Hold the beacon next to the phone.'
            : 'Choose the beacon, then apply the DukaNest profile.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final selected = _selected;
    if (selected == null) {
      setState(() => _status = 'Find the beacon first.');
      return;
    }
    final password = _password.text;
    if (password.length != 6) {
      setState(() => _status = 'Password must be 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Writing the DukaNest profile…';
    });
    final error = await widget.provision.configure(
      mac: selected.mac,
      password: password,
      uuid: widget.uuid,
      major: widget.major,
      minor: widget.minor,
      txDbm: widget.txPower,
      intervalMs: widget.intervalMs,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _status = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure beacon'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Writes UUID, major ${widget.major}, minor ${widget.minor}, '
                'TX ${widget.txPower} dBm, every ${widget.intervalMs} ms. '
                'The password is not changed.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Beacon password',
                  hintText: 'dx1234',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _scan,
                child: const Text('Find nearby beacons'),
              ),
              if (_status != null) ...[
                const SizedBox(height: 8),
                Text(_status!),
              ],
              ..._nearby.map(
                (beacon) => RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: beacon.mac,
                  groupValue: _selected?.mac,
                  onChanged: _busy
                      ? null
                      : (_) => setState(() => _selected = beacon),
                  title: Text(beacon.name),
                  subtitle: Text('${beacon.mac} · ${beacon.rssi} dBm'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _apply,
          child: Text(_busy ? 'Working' : 'Apply profile'),
        ),
      ],
    );
  }
}

class ProximityBeaconsScreen extends ConsumerStatefulWidget {
  const ProximityBeaconsScreen({super.key, this.provision});

  final BeaconProvisionService? provision;

  @override
  ConsumerState<ProximityBeaconsScreen> createState() =>
      _ProximityBeaconsScreenState();
}

class _ProximityBeaconsScreenState extends ConsumerState<ProximityBeaconsScreen> {
  bool _loading = true;
  String? _error;
  String? _configuringId;
  String? _platformUuid;
  Map<String, dynamic>? _profile;
  List<dynamic> _beacons = [];
  List<dynamic> _darkIds = [];

  BeaconProvisionService get _provision =>
      widget.provision ?? BeaconProvisionService();

  bool get _canConfigure => defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).getProximityBeacons();
      if (!response.success || response.data is! Map) {
        throw Exception(response.error?.message ?? 'Could not load beacons');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        _platformUuid = data['platform_uuid']?.toString();
        _profile = data['recommended_profile'] is Map
            ? Map<String, dynamic>.from(data['recommended_profile'] as Map)
            : null;
        _beacons = (data['beacons'] as List?) ?? const [];
        _darkIds = (data['dark_beacon_ids'] as List?) ?? const [];
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _configure(Map<String, dynamic> beacon) async {
    final uuid = _platformUuid ?? _profile?['uuid']?.toString() ?? '';
    final major = (beacon['major'] as num?)?.toInt() ?? 0;
    final minor = (beacon['minor'] as num?)?.toInt() ?? 0;
    final tx = _profile?['tx_power_dbm'];
    final interval = _profile?['adv_interval_ms'];
    final txPower = tx is num ? tx.toDouble() : -13.5;
    final intervalMs = interval is num ? interval.toInt() : 500;
    final wrote = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfigureBeaconDialog(
        provision: _provision,
        uuid: uuid,
        major: major,
        minor: minor,
        txPower: txPower,
        intervalMs: intervalMs,
      ),
    );
    if (wrote != true || !mounted) return;

    final id = beacon['id']?.toString() ?? '';
    setState(() => _configuringId = id);
    try {
      final response = await ref.read(apiClientProvider).recordProximityProfile(
            id,
            uuid: uuid,
            major: major,
            minor: minor,
            txPowerDbm: txPower,
            advIntervalMs: intervalMs,
          );
      if (!response.success) {
        throw Exception(response.error?.message ?? 'Could not record the profile');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beacon configured')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _configuringId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lowBattery = _profile?['low_battery_mv'] is num
        ? (_profile!['low_battery_mv'] as num).toInt()
        : 2400;

    return Scaffold(
      appBar: const DashboardAppBar(title: 'In-store beacons'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Staff commissioning only. The shopper scan app cannot change a beacon.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CP35 profile', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SelectableText('UUID ${_platformUuid ?? _profile?['uuid'] ?? ''}'),
                    Text('TX ${_profile?['tx_power_dbm'] ?? -13.5} dBm'),
                    Text('Advertise every ${_profile?['adv_interval_ms'] ?? 500} ms'),
                    Text('Frame ${_profile?['frames'] ?? 'ibeacon_only'}'),
                    const SizedBox(height: 8),
                    Text(
                      _canConfigure
                          ? 'Hold the beacon next to this phone, then configure it.'
                          : 'Configure beacons from the Android DukaNest app.',
                    ),
                    const SizedBox(height: 8),
                    Text('Replace the cell when voltage falls below $lowBattery mV.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (!_loading && _beacons.isEmpty && _error == null)
              const Text('No beacons registered yet. Add them on the web dashboard.'),
            ..._beacons.map((raw) {
              final beacon = Map<String, dynamic>.from(raw as Map);
              final id = beacon['id']?.toString() ?? '';
              final dark = _darkIds.contains(id);
              final location = beacon['location'] is Map
                  ? (beacon['location'] as Map)['name']
                  : null;
              final zone = beacon['zone'] is Map
                  ? (beacon['zone'] as Map)['name']
                  : null;
              final battery = beacon['battery_mv'];
              final low = battery is num && battery < lowBattery;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${location ?? 'Branch'} / ${zone ?? 'Zone'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (dark)
                            const Chip(label: Text('Dark 24h'))
                          else if (low)
                            const Chip(label: Text('Low battery'))
                          else
                            const Chip(label: Text('Active')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'major ${beacon['major']} · minor ${beacon['minor']}\n'
                        'last seen ${beacon['last_seen_at'] ?? 'never'}'
                        '${battery == null ? '' : '\nbattery $battery mV'}',
                      ),
                      if (_canConfigure)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _configuringId == id ? null : () => _configure(beacon),
                            child: Text(_configuringId == id ? 'Saving' : 'Configure beacon'),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
