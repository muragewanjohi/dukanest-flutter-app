import 'package:dio/dio.dart';
import 'package:dukanest_app/core/api/api_client.dart';
import 'package:dukanest_app/features/proximity/beacon_provision_service.dart';
import 'package:dukanest_app/features/proximity/screens/proximity_beacons_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_dio.dart';

Map<String, dynamic> _beacon({
  required String id,
  required String zone,
  int? batteryMv,
}) {
  return {
    'id': id,
    'major': 1,
    'minor': 2,
    'last_seen_at': '2026-09-22T10:00:00.000Z',
    'battery_mv': batteryMv,
    'location': {'name': 'Ruaka Branch'},
    'zone': {'name': zone},
  };
}

Map<String, dynamic> _payload() {
  return {
    'success': true,
    'data': {
      'platform_uuid': '6e8a4c12-9f3d-4b71-a2e8-1d7c0b5e4a91',
      'recommended_profile': {
        'uuid': '6e8a4c12-9f3d-4b71-a2e8-1d7c0b5e4a91',
        'tx_power_dbm': -13.5,
        'adv_interval_ms': 500,
        'frames': 'ibeacon_only',
        'low_battery_mv': 2400,
      },
      'dark_beacon_ids': ['dark-1'],
      'beacons': [
        _beacon(id: 'dark-1', zone: 'Lotions'),
        _beacon(id: 'low-1', zone: 'Yogurt', batteryMv: 2100),
      ],
    },
  };
}

class _FakeProvision extends BeaconProvisionService {
  _FakeProvision() : super(channel: const MethodChannel('test/cp35'));

  String? configureError;
  String? lastMac;
  String? lastPassword;

  @override
  Future<List<NearbyBeacon>> scanNearbyBeacons() async {
    return const [
      NearbyBeacon(name: 'CP35', mac: 'AA:BB:CC:DD:EE:FF', rssi: -42),
    ];
  }

  @override
  Future<String?> configure({
    required String mac,
    required String password,
    required String uuid,
    required int major,
    required int minor,
    double txDbm = -13.5,
    int intervalMs = 500,
  }) async {
    lastMac = mac;
    lastPassword = password;
    return configureError;
  }
}

void main() {
  testWidgets('shows the profile and configure action', (tester) async {
    final (dio, adapter) = buildMockDio();
    adapter.onGet(
      '/dashboard/proximity/beacons',
      (server) => server.reply(200, _payload()),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(dio)),
        ],
        child: const MaterialApp(home: ProximityBeaconsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('6e8a4c12-9f3d-4b71-a2e8-1d7c0b5e4a91'), findsOneWidget);
    expect(find.text('TX -13.5 dBm'), findsOneWidget);
    expect(find.text('Ruaka Branch / Lotions'), findsOneWidget);
    expect(find.text('Dark 24h'), findsOneWidget);
    expect(find.text('Low battery'), findsOneWidget);
    expect(find.text('Configure beacon'), findsNWidgets(2));
    expect(find.text('Hold the beacon next to this phone, then configure it.'), findsOneWidget);
  });

  testWidgets('asks for a 6 character password before writing', (tester) async {
    final (dio, adapter) = buildMockDio();
    adapter.onGet(
      '/dashboard/proximity/beacons',
      (server) => server.reply(200, {
        'success': true,
        'data': {
          'platform_uuid': '6e8a4c12-9f3d-4b71-a2e8-1d7c0b5e4a91',
          'recommended_profile': {
            'tx_power_dbm': -13.5,
            'adv_interval_ms': 500,
            'low_battery_mv': 2400,
          },
          'dark_beacon_ids': [],
          'beacons': [_beacon(id: 'beacon-1', zone: 'Lotions', batteryMv: 3000)],
        },
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(ApiClient(dio))],
        child: MaterialApp(home: ProximityBeaconsScreen(provision: _FakeProvision())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configure beacon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find nearby beacons'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply profile'));
    await tester.pump();
    expect(find.text('Password must be 6 characters.'), findsOneWidget);
  });

  testWidgets('writes the radio profile and records it on the dashboard', (tester) async {
    final (dio, adapter) = buildMockDio();
    final body = {
      'success': true,
      'data': {
        'platform_uuid': '6e8a4c12-9f3d-4b71-a2e8-1d7c0b5e4a91',
        'recommended_profile': {
          'tx_power_dbm': -13.5,
          'adv_interval_ms': 500,
          'low_battery_mv': 2400,
        },
        'dark_beacon_ids': <String>[],
        'beacons': [_beacon(id: 'beacon-1', zone: 'Lotions', batteryMv: 3000)],
      },
    };
    adapter.onGet('/dashboard/proximity/beacons', (server) => server.reply(200, body));
    adapter.onGet('/dashboard/proximity/beacons', (server) => server.reply(200, body));
    adapter.onPost(
      '/dashboard/proximity/commission',
      (server) => server.reply(200, {'success': true, 'data': {'id': 'beacon-1'}}),
      data: {
        'beacon_id': 'beacon-1',
        'tx_power_dbm': -13.5,
        'adv_interval_ms': 500,
        'uuid': '6e8a4c12-9f3d-4b71-a2e8-1d7c0b5e4a91',
        'major': 1,
        'minor': 2,
      },
    );
    final provision = _FakeProvision();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(ApiClient(dio))],
        child: MaterialApp(home: ProximityBeaconsScreen(provision: provision)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configure beacon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find nearby beacons'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(provision.lastMac, 'AA:BB:CC:DD:EE:FF');
    expect(provision.lastPassword, 'dx1234');
    expect(find.text('Beacon configured'), findsOneWidget);
  });
}
