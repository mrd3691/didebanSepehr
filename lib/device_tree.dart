import 'models.dart';

class DeviceGroupNode {
  DeviceGroupNode({
    required this.id,
    required this.name,
    required this.children,
    required this.devices,
    Set<int>? deviceIds,
  }) : deviceIds = Set.unmodifiable(
         deviceIds ??
             {
               for (final child in children) ...child.deviceIds,
               for (final device in devices) device.id,
             },
       );

  final int id;
  final String name;
  final List<DeviceGroupNode> children;
  final List<Device> devices;
  // Keep full branch membership even when a search hides some descendants.
  final Set<int> deviceIds;

  bool? selection(Set<int> selected) {
    final count = deviceIds.where(selected.contains).length;
    if (count == 0) return false;
    return count == deviceIds.length ? true : null;
  }
}

DeviceGroupNode buildDeviceTree(
  List<DeviceGroup> groups,
  List<Device> devices,
) {
  final byId = {
    for (final group in groups)
      if (group.id != 0) group.id: group,
  };
  final parents = {
    for (final group in byId.values)
      group.id: byId.containsKey(group.groupId) && group.id != group.groupId
          ? group.groupId
          : 0,
  };
  // Broken parent references and cycles must never hide a permitted device.
  for (final id in parents.keys) {
    final seen = {id};
    var ancestor = parents[id] ?? 0;
    while (ancestor != 0) {
      if (!seen.add(ancestor)) {
        parents[id] = 0;
        break;
      }
      ancestor = parents[ancestor] ?? 0;
    }
  }
  final children = <int, List<DeviceGroup>>{};
  for (final group in byId.values) {
    (children[parents[group.id]!] ??= []).add(group);
  }
  final directDevices = <int, List<Device>>{};
  for (final device in devices) {
    final parent = byId.containsKey(device.groupId) ? device.groupId : 0;
    (directDevices[parent] ??= []).add(device);
  }
  DeviceGroupNode build(int id, String name) {
    final childGroups = children[id] ?? [];
    childGroups.sort((a, b) => a.name.compareTo(b.name));
    final leaves = directDevices[id] ?? [];
    leaves.sort((a, b) => a.name.compareTo(b.name));
    return DeviceGroupNode(
      id: id,
      name: name,
      children: [for (final group in childGroups) build(group.id, group.name)],
      devices: leaves,
    );
  }

  return build(
    0,
    const String.fromEnvironment('ROOT_GROUP_NAME', defaultValue: 'Dideban'),
  );
}

DeviceGroupNode? filterDeviceTree(DeviceGroupNode node, String input) {
  final query = input.trim().toLowerCase();
  if (query.isEmpty ||
      (node.id != 0 && node.name.toLowerCase().contains(query))) {
    return node;
  }
  final children = [
    for (final child in node.children)
      if (filterDeviceTree(child, query) case final DeviceGroupNode match)
        match,
  ];
  final devices = node.devices
      .where(
        (device) =>
            '${device.name} ${device.uniqueId}'.toLowerCase().contains(query),
      )
      .toList();
  if (children.isEmpty && devices.isEmpty) return null;
  return DeviceGroupNode(
    id: node.id,
    name: node.name,
    children: children,
    devices: devices,
    deviceIds: node.deviceIds,
  );
}
