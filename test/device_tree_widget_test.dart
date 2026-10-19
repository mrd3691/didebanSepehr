import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dideban_sepehr/device_sheet.dart';
import 'package:dideban_sepehr/live_controller.dart';
import 'package:dideban_sepehr/main.dart';
import 'package:dideban_sepehr/models.dart';
import 'package:dideban_sepehr/position_details_card.dart';
import 'package:dideban_sepehr/traccar_api.dart';
import 'package:dideban_sepehr/tracking_screen.dart';

void main() {
  late TraccarApi api;
  late LiveController live;
  setUp(() {
    api = TraccarApi('https://gps.example.com');
    live = LiveController(api);
    live.groups = [
      DeviceGroup.fromJson({'id': 1, 'name': 'Fleet'}),
      DeviceGroup.fromJson({'id': 2, 'name': 'Tehran', 'groupId': 1}),
      DeviceGroup.fromJson({'id': 3, 'name': 'Other'}),
    ];
    for (final row in [
      {'id': 10, 'name': 'Truck A', 'groupId': 1, 'status': 'online'},
      {
        'id': 11,
        'name': 'Truck B',
        'uniqueId': 'GPS002',
        'groupId': 2,
        'status': 'offline',
      },
      {'id': 12, 'name': 'Van C', 'groupId': 3, 'status': 'unknown'},
      {'id': 13, 'name': 'Unassigned', 'groupId': 0},
    ]) {
      final device = Device.fromJson(row);
      live.devices[device.id] = device;
    }
    live.positions[10] = Position.fromJson({
      'id': 1,
      'deviceId': 10,
      'latitude': 35.75432,
      'longitude': 51.48567,
      'speed': 10,
      'fixTime': '2026-10-19T08:00:00Z',
      'address': '',
    });
  });
  tearDown(() {
    live.dispose();
    api.close();
  });

  Widget shell(Widget child) => MaterialApp(
    theme: buildDidebanTheme(),
    home: Scaffold(body: child),
  );
  Finder key(String value) => find.byKey(ValueKey(value));
  Future<void> toggle(WidgetTester tester, String value) async {
    await tester.ensureVisible(key(value));
    await tester.tap(key(value));
    await tester.pumpAndSettle();
  }

  Checkbox check(WidgetTester tester, String value) =>
      tester.widget<Checkbox>(key(value));

  testWidgets(
    'Nested expansion, cascading selection and partial group clearing match web',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(shell(DeviceSheet(live: live, onFocus: (_) {})));
      expect(find.text('Fleet'), findsOneWidget);
      expect(find.text('Truck B'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      await toggle(tester, 'expand-group-1');
      expect(find.text('Truck A'), findsOneWidget);
      expect(find.text('Tehran'), findsOneWidget);
      expect(find.text('Truck B'), findsNothing);
      await toggle(tester, 'expand-group-2');
      expect(find.text('Truck B'), findsOneWidget);
      await toggle(tester, 'group-checkbox-1');
      expect(live.selected, {10, 11});
      expect(check(tester, 'group-checkbox-1').value, true);
      expect(check(tester, 'group-checkbox-0').value, isNull);
      await toggle(tester, 'device-checkbox-11');
      expect(live.selected, {10});
      expect(check(tester, 'group-checkbox-1').value, isNull);
      await toggle(tester, 'group-checkbox-1');
      expect(live.selected, isEmpty);
      await toggle(tester, 'group-checkbox-0');
      expect(live.selected, {10, 11, 12, 13});
      await toggle(tester, 'group-checkbox-0');
      expect(live.selected, isEmpty);
    },
  );

  testWidgets(
    'Search reveals ancestors, group search reveals descendants, clearing restores expansion',
    (tester) async {
      await tester.pumpWidget(shell(DeviceSheet(live: live, onFocus: (_) {})));
      await tester.enterText(find.byType(TextField), 'GPS002');
      await tester.pumpAndSettle();
      for (final text in ['Dideban', 'Fleet', 'Tehran', 'Truck B']) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('Truck A'), findsNothing);
      expect(find.text('Other'), findsNothing);
      await toggle(tester, 'group-checkbox-1');
      expect(live.selected, {10, 11});
      await tester.enterText(find.byType(TextField), 'Fleet');
      await tester.pumpAndSettle();
      expect(find.text('Truck A'), findsOneWidget);
      expect(find.text('Truck B'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Truck B'), findsNothing);
      expect(find.text('Other'), findsOneWidget);
      expect(live.selected, {10, 11});
    },
  );

  testWidgets(
    'Live device list hides device statuses and all coordinate values',
    (tester) async {
      await tester.pumpWidget(shell(DeviceSheet(live: live, onFocus: (_) {})));
      await tester.enterText(find.byType(TextField), 'Truck');
      await tester.pumpAndSettle();
      expect(find.text('19 km/h'), findsOneWidget);
      expect(
        find.textContaining(
          RegExp(r'\b(online|offline|unknown)\b', caseSensitive: false),
        ),
        findsNothing,
      );
      expect(find.textContaining('35.75432'), findsNothing);
      expect(find.textContaining('51.48567'), findsNothing);
    },
  );

  testWidgets(
    'Shared Live and Tracking details keep time, speed and address without coordinate fallback',
    (tester) async {
      await tester.pumpWidget(
        shell(
          PositionDetailsCard(position: live.positions[10]!, name: 'Truck A'),
        ),
      );
      expect(find.text('Truck A'), findsOneWidget);
      expect(find.text('km/h'), findsOneWidget);
      expect(find.textContaining('35.75432'), findsNothing);
      expect(find.textContaining('51.48567'), findsNothing);
      expect(
        find.textContaining(
          RegExp(r'\b(online|offline|unknown)\b', caseSensitive: false),
        ),
        findsNothing,
      );
      final addressed = Position.fromJson({
        'id': 2,
        'deviceId': 10,
        'latitude': 35.75432,
        'longitude': 51.48567,
        'speed': 10,
        'fixTime': '2026-10-19T08:00:00Z',
        'address': 'Valiasr Street',
      });
      await tester.pumpWidget(
        shell(PositionDetailsCard(position: addressed, name: 'Truck A')),
      );
      expect(find.text('Valiasr Street'), findsOneWidget);
      expect(find.textContaining('35.75432'), findsNothing);
    },
  );

  testWidgets('Tracking selects one device through the same nested tree', (
    tester,
  ) async {
    RouteSelection? selection;
    await tester.pumpWidget(
      shell(
        Builder(
          builder: (context) => TextButton(
            child: const Text('Open route filter'),
            onPressed: () async {
              selection = await showModalBottomSheet<RouteSelection>(
                context: context,
                isScrollControlled: true,
                builder: (_) => RouteFilter(
                  devices: live.devices.values.toList(),
                  groups: live.groups,
                  deviceId: null,
                  from: DateTime(2026, 10, 19, 8),
                  to: DateTime(2026, 10, 19, 18),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open route filter'));
    await tester.pumpAndSettle();
    await toggle(tester, 'route-device-picker');
    await toggle(tester, 'expand-group-1');
    await toggle(tester, 'expand-group-2');
    expect(key('group-checkbox-1'), findsNothing);
    await toggle(tester, 'device-checkbox-11');
    expect(find.byType(SingleDeviceSheet), findsNothing);
    expect(find.text('Truck B'), findsOneWidget);
    await tester.tap(find.text('Load route'));
    await tester.pumpAndSettle();
    expect(selection?.deviceId, 11);
    expect(selection?.from, DateTime(2026, 10, 19, 8));
    expect(selection?.to, DateTime(2026, 10, 19, 18));
  });
}
