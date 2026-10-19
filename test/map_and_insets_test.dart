import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dideban_sepehr/device_sheet.dart';
import 'package:dideban_sepehr/fleet_map.dart';
import 'package:dideban_sepehr/main.dart';
import 'package:dideban_sepehr/traccar_api.dart';
import 'package:dideban_sepehr/tracking_screen.dart';
import 'support/fleet_fixtures.dart';

void main() {
  late TraccarApi api;
  late FixtureLiveController live;
  setUp(() {
    api = TraccarApi('https://gps.example.com');
    live = FixtureLiveController(api);
  });
  tearDown(() {
    live.dispose();
    api.close();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
  }

  Widget shell(Widget child) =>
      MaterialApp(theme: buildDidebanTheme(), home: child);
  Finder button(String text) => find
      .ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      )
      .first;
  Widget screen() => shell(
    TrackingScreen(
      api: api,
      onLogout: () {},
      liveController: live,
      tileProvider: FixtureTileProvider(),
    ),
  );
  MapController camera(WidgetTester tester) =>
      tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;

  testWidgets(
    'Pinch zoom remains usable while two-finger rotation stays locked',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(
        shell(
          Scaffold(
            body: FleetMap(
              positions: const [],
              names: const {},
              tileProvider: FixtureTileProvider(),
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = camera(tester),
          initialZoom = camera(tester).camera.zoom;
      final center = tester.getCenter(find.byType(FlutterMap));
      final first = await tester.createGesture(pointer: 1),
          second = await tester.createGesture(pointer: 2);
      await first.down(center + const Offset(-50, 0));
      await second.down(center + const Offset(50, 0));
      await tester.pump();
      for (var step = 1; step <= 5; step++) {
        await first.moveTo(center + Offset(-50 - step * 10, -step * 10));
        await second.moveTo(center + Offset(50 + step * 10, step * 10));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(controller.camera.zoom, greaterThan(initialZoom));
      expect(controller.camera.rotation, closeTo(0, 0.001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Device-name clicks zoom after dismissing the sheet, including repeated clicks',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      final controller = camera(tester);
      expect(controller.camera.zoom, lessThan(16));
      Future<void> pick() async {
        await tester.tap(button('Devices'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('expand-group-1')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(DeviceSheet),
            matching: find.text('Sepehr 07'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DeviceSheet), findsNothing);
        expect(controller.camera.center.latitude, closeTo(35.7, 0.00001));
        expect(controller.camera.center.longitude, closeTo(51.4, 0.00001));
        expect(controller.camera.zoom, greaterThanOrEqualTo(16));
        expect(live.selected, {7, 8});
      }

      await pick();
      expect(
        find.descendant(
          of: find.byType(FleetMap),
          matching: find.text('Sepehr 07'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(FleetMap),
          matching: find.text('Sepehr 08'),
        ),
        findsNothing,
      );
      controller.move(const LatLng(30, 52), 7);
      await tester.pumpAndSettle();
      await pick();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Live sheet and navigation controls stay above system navigation and keyboard',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byType(NavigationBar)).dy,
        lessThanOrEqualTo(844 - 48),
      );
      await tester.tap(button('Devices'));
      await tester.pumpAndSettle();
      final footer = button('Show 2 devices');
      expect(tester.getBottomRight(footer).dy, lessThanOrEqualTo(844 - 48));
      final search = find.descendant(
        of: find.byType(DeviceSheet),
        matching: find.byType(TextField),
      );
      await tester.showKeyboard(search);
      tester.view.padding = const FakeViewPadding(top: 24);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(footer).dy, lessThanOrEqualTo(844 - 300));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Route action stays above system navigation and keyboard in its modal',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(
        shell(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open filter'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (_) => RouteFilter(
                    devices: live.devices.values.toList(),
                    groups: live.groups,
                    deviceId: 7,
                    from: DateTime(2026, 10, 19, 8),
                    to: DateTime(2026, 10, 19, 18),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open filter'));
      await tester.pumpAndSettle();
      final action = button('Load route');
      expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(844 - 48));
      await tester.showKeyboard(find.byType(TextFormField).first);
      tester.view.padding = const FakeViewPadding(top: 24);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(844 - 300));
      expect(tester.takeException(), isNull);
    },
  );
}
