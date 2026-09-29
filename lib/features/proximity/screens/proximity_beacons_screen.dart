import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/dashboard_app_bar.dart';

class ProximityBeaconsScreen extends ConsumerStatefulWidget {
  const ProximityBeaconsScreen({super.key});

  @override
  ConsumerState<ProximityBeaconsScreen> createState() =>
      _ProximityBeaconsScreenState();
}

class _ProximityBeaconsScreenState
    extends ConsumerState<ProximityBeaconsScreen> {
  bool _loading = true;
  String? _error;
  String? _recordingId;
  String? _platformUuid;
  String? _commissioning;
  Map<String, dynamic>? _profile;
  List<dynamic> _beacons = [];
  List<dynamic> _darkIds = [];

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
      final response =
          await ref.read(apiClientProvider).getProximityBeacons();
      if (!response.success || response.data is! Map) {
        throw Exception(response.error?.message ?? 'Could not load beacons');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        _platformUuid = data['platform_uuid']?.toString();
        _commissioning = data['commissioning']?.toString();
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

  Future<void> _record(Map<String, dynamic> beacon) async {
    final battery = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record pilot profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UUID, TX ${_profile?['tx_power_dbm'] ?? -13.5} dBm and interval ${_profile?['adv_interval_ms'] ?? 500} ms must already be set in DX-SMART. This only saves that profile on the beacon.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: battery,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Battery millivolts',
                hintText: 'Leave blank to keep the current reading',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Record'),
          ),
        ],
      ),
    );
    final batteryText = battery.text.trim();
    battery.dispose();
    if (confirmed != true || !mounted) return;

    final parsedBattery = batteryText.isEmpty ? null : int.tryParse(batteryText);
    if (batteryText.isNotEmpty && parsedBattery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Battery must be a whole number of millivolts')),
      );
      return;
    }

    final id = beacon['id']?.toString() ?? '';
    setState(() => _recordingId = id);
    try {
      final tx = _profile?['tx_power_dbm'];
      final interval = _profile?['adv_interval_ms'];
      final response = await ref.read(apiClientProvider).recordProximityProfile(
            id,
            batteryMv: parsedBattery,
            txPowerDbm: tx is num ? tx.toDouble() : -13.5,
            advIntervalMs: interval is num ? interval.toInt() : 500,
          );
      if (!response.success) {
        throw Exception(response.error?.message ?? 'Could not record the profile');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile recorded')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _recordingId = null);
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
              'Staff commissioning only. The shopper scan app never receives this screen or a commission key.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CP35 pilot profile', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SelectableText('UUID ${_platformUuid ?? _profile?['uuid'] ?? ''}'),
                    Text('TX ${_profile?['tx_power_dbm'] ?? -13.5} dBm'),
                    Text('Advertise every ${_profile?['adv_interval_ms'] ?? 500} ms'),
                    Text('Frame ${_profile?['frames'] ?? 'ibeacon_only'}'),
                    if (_commissioning != null) ...[
                      const SizedBox(height: 8),
                      Text(_commissioning!),
                    ],
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _recordingId == id ? null : () => _record(beacon),
                          child: Text(_recordingId == id ? 'Saving' : 'Record profile'),
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
