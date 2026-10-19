import 'package:flutter_test/flutter_test.dart';
import 'package:dideban_sepehr/device_tree.dart';
import 'package:dideban_sepehr/models.dart';

DeviceGroup group(int id, String name, [int parent = 0]) =>
    DeviceGroup.fromJson({'id': id, 'name': name, 'groupId': parent});
Device device(int id, String name, int parent, [String identifier = '']) =>
    Device.fromJson({
      'id': id,
      'name': name,
      'groupId': parent,
      'uniqueId': identifier,
    });

Iterable<Device> leaves(DeviceGroupNode node) sync* {
  yield* node.devices;
  for (final child in node.children) {
    yield* leaves(child);
  }
}

void main() {
  test('Builds the real parent hierarchy and keeps unassigned devices', () {
    final tree = buildDeviceTree(
      [group(2, 'Tehran', 1), group(1, 'Fleet')],
      [
        device(10, 'Truck A', 1),
        device(11, 'Truck B', 2),
        device(12, 'Unassigned', 0),
        device(13, 'Missing group', 999),
      ],
    );
    expect(tree.children.single.name, 'Fleet');
    expect(tree.children.single.children.single.name, 'Tehran');
    expect(tree.children.single.deviceIds, {10, 11});
    expect(tree.devices.map((d) => d.id).toSet(), {12, 13});
    expect(tree.deviceIds, {10, 11, 12, 13});
  });

  test('Search preserves ancestors and full branch selection membership', () {
    final tree = buildDeviceTree(
      [group(1, 'Fleet'), group(2, 'Tehran', 1)],
      [device(10, 'Truck A', 1), device(11, 'Truck B', 2, 'GPS002')],
    );
    final filtered = filterDeviceTree(tree, ' gps002 ')!;
    expect(filtered.children.single.name, 'Fleet');
    expect(filtered.children.single.children.single.name, 'Tehran');
    expect(leaves(filtered).map((d) => d.id), [11]);
    expect(filtered.children.single.deviceIds, {10, 11});
    expect(leaves(filterDeviceTree(tree, 'FLEET')!).length, 2);
    expect(filterDeviceTree(tree, 'does not exist'), isNull);
  });

  test(
    'Orphan groups, cycles and self references never lose or duplicate devices',
    () {
      final tree = buildDeviceTree(
        [
          group(1, 'A', 2),
          group(2, 'B', 1),
          group(3, 'Self', 3),
          group(4, 'Orphan', 99),
        ],
        [for (var id = 1; id <= 4; id++) device(id, 'Device $id', id)],
      );
      expect(leaves(tree).map((d) => d.id).toList()..sort(), [1, 2, 3, 4]);
      expect(tree.deviceIds, {1, 2, 3, 4});
      expect(tree.selection({}), false);
      expect(tree.selection({1}), isNull);
      expect(tree.selection({1, 2, 3, 4}), true);
    },
  );
}
