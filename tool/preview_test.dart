import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dideban_sepehr/main.dart';
import 'package:dideban_sepehr/models.dart';
import 'package:dideban_sepehr/live_controller.dart';
import 'package:dideban_sepehr/traccar_api.dart';
import 'package:dideban_sepehr/tracking_screen.dart';
import 'package:dideban_sepehr/device_sheet.dart';

// Run explicitly with --update-goldens; previews go into ignored build output.
void main() {
  testWidgets('Capture mobile screens at 390 x 844', (tester) async {
    final font = FontLoader('SepehrSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
    await icons.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capture = ValueKey('capture');
    Widget shell(Widget child) => RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildDidebanTheme(),
        home: child,
      ),
    );
    await tester.pumpWidget(shell(ServerSetupScreen(onSave: (_) async {})));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('../build/previews/setup.png'),
    );
    await tester.pumpWidget(
      shell(
        LoginScreen(
          server: 'https://gps.example.com',
          onLogin: (a, b, c, d) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('../build/previews/login.png'),
    );
    final now = DateTime(2026, 10, 19, 8);
    final devices = [
      Device.fromJson({
        'id': 1,
        'name': 'Sepehr 01',
        'uniqueId': '001',
        'status': 'online',
        'groupId': 2,
      }),
      Device.fromJson({
        'id': 2,
        'name': 'Sepehr 02',
        'uniqueId': '002',
        'status': 'offline',
        'groupId': 2,
      }),
      Device.fromJson({
        'id': 3,
        'name': 'Sepehr 03',
        'uniqueId': '003',
        'status': 'online',
        'groupId': 3,
      }),
    ];
    await tester.pumpWidget(
      shell(
        Scaffold(
          body: SafeArea(
            child: RouteFilter(
              devices: devices,
              deviceId: 1,
              from: now,
              to: now.add(const Duration(hours: 10)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('../build/previews/tracking-filter.png'),
    );
    final api = TraccarApi('https://gps.example.com');
    final live = LiveController(api);
    for (final device in devices) {
      live.devices[device.id] = device;
    }
    live.groups = [
      DeviceGroup.fromJson({'id': 1, 'name': 'Sepehr fleet'}),
      DeviceGroup.fromJson({'id': 2, 'name': 'Tehran', 'groupId': 1}),
      DeviceGroup.fromJson({'id': 3, 'name': 'Karaj', 'groupId': 1}),
    ];
    live.selected.add(1);
    await tester.pumpWidget(
      shell(
        Scaffold(
          body: DeviceSheet(live: live, onFocus: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final id in [1, 2, 3]) {
      final expand = find.byKey(ValueKey('expand-group-$id'));
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('../build/previews/devices.png'),
    );
    await tester.pumpWidget(const SizedBox());
    live.dispose();
    api.close();
    expect(tester.takeException(), isNull);
  });
}
