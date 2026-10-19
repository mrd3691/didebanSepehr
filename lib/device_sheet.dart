import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'device_tree.dart';
import 'live_controller.dart';
import 'models.dart';

const _ink = Color(0xFF10283F), _sea = Color(0xFF007F78);

class DeviceSheet extends StatelessWidget {
  const DeviceSheet({super.key, required this.live, required this.onFocus});
  final LiveController live;
  final ValueChanged<int> onFocus;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: live,
    builder: (context, _) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Devices',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: live.selectAll,
                    child: Text(
                      live.selected.length == live.devices.length
                          ? 'Clear selection'
                          : 'Select all',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: DeviceTreeSelector(
                  devices: live.devices.values.toList(),
                  groups: live.groups,
                  selected: live.selected,
                  positions: live.positions,
                  onToggleDevice: live.toggle,
                  onFocus: onFocus,
                  onToggleGroup: (node) => node.id == 0
                      ? live.selectAll()
                      : live.toggleGroup(node.deviceIds),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Show ${live.selected.length} devices'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

class SingleDeviceSheet extends StatelessWidget {
  const SingleDeviceSheet({
    super.key,
    required this.devices,
    required this.groups,
    this.selectedId,
  });
  final List<Device> devices;
  final List<DeviceGroup> groups;
  final int? selectedId;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.82,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select device',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DeviceTreeSelector(
                devices: devices,
                groups: groups,
                selected: {if (selectedId != null) selectedId!},
                singleSelection: true,
                onToggleDevice: (id) => Navigator.pop(context, id),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DeviceTreeSelector extends StatefulWidget {
  const DeviceTreeSelector({
    super.key,
    required this.devices,
    required this.groups,
    required this.selected,
    required this.onToggleDevice,
    this.onToggleGroup,
    this.onFocus,
    this.positions = const {},
    this.singleSelection = false,
  });
  final List<Device> devices;
  final List<DeviceGroup> groups;
  final Set<int> selected;
  final Map<int, Position> positions;
  final ValueChanged<int> onToggleDevice;
  final ValueChanged<DeviceGroupNode>? onToggleGroup;
  final ValueChanged<int>? onFocus;
  final bool singleSelection;

  @override
  State<DeviceTreeSelector> createState() => _DeviceTreeSelectorState();
}

class _DeviceTreeSelectorState extends State<DeviceTreeSelector> {
  String query = '';
  final expanded = <int>{0}, searchCollapsed = <int>{};
  bool isExpanded(int id) => query.trim().isNotEmpty
      ? !searchCollapsed.contains(id)
      : expanded.contains(id);
  void toggleExpansion(int id) => setState(() {
    final ids = query.trim().isNotEmpty ? searchCollapsed : expanded;
    ids.contains(id) ? ids.remove(id) : ids.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final root = filterDeviceTree(
      buildDeviceTree(widget.groups, widget.devices),
      query,
    );
    final rows = <({DeviceGroupNode? group, Device? device, int depth})>[];
    void flatten(DeviceGroupNode node, int depth) {
      rows.add((group: node, device: null, depth: depth));
      if (!isExpanded(node.id)) return;
      for (final child in node.children) {
        flatten(child, depth + 1);
      }
      for (final device in node.devices) {
        rows.add((group: null, device: device, depth: depth + 1));
      }
    }

    if (root != null) flatten(root, 0);
    return Column(
      children: [
        TextField(
          onChanged: (text) => setState(() {
            query = text;
            searchCollapsed.clear();
          }),
          decoration: const InputDecoration(
            hintText: 'Search groups, devices or identifiers...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: root == null || widget.devices.isEmpty
              ? const Center(child: Text('No devices found.'))
              : ListView.builder(
                  key: const PageStorageKey('device-tree'),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        left: math.min(row.depth, 6) * 12.0,
                      ),
                      child: row.group != null
                          ? groupRow(row.group!)
                          : deviceRow(row.device!),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget groupRow(DeviceGroupNode node) {
    final open = isExpanded(node.id);
    return Container(
      key: ValueKey('group-${node.id}'),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4EBED))),
      ),
      child: Row(
        children: [
          IconButton(
            key: ValueKey('expand-group-${node.id}'),
            tooltip: '${open ? 'Collapse' : 'Expand'} ${node.name}',
            onPressed: () => toggleExpansion(node.id),
            icon: Icon(open ? Icons.expand_more : Icons.chevron_right),
            visualDensity: VisualDensity.compact,
          ),
          if (!widget.singleSelection)
            Checkbox(
              key: ValueKey('group-checkbox-${node.id}'),
              tristate: true,
              value: node.selection(widget.selected),
              onChanged: node.deviceIds.isEmpty
                  ? null
                  : (_) => widget.onToggleGroup?.call(node),
              visualDensity: VisualDensity.compact,
            ),
          Icon(
            node.id == 0
                ? Icons.account_tree_outlined
                : open
                ? Icons.folder_open_outlined
                : Icons.folder_outlined,
            color: _sea,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: widget.singleSelection
                  ? () => toggleExpansion(node.id)
                  : () => widget.onToggleGroup?.call(node),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  node.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${node.deviceIds.length}',
            style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget deviceRow(Device device) {
    final position = widget.positions[device.id];
    void choose() {
      if (!widget.singleSelection &&
          position != null &&
          widget.onFocus != null) {
        widget.onFocus!(device.id);
      } else {
        widget.onToggleDevice(device.id);
      }
    }

    return Container(
      key: ValueKey('device-${device.id}'),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F3F4))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          Checkbox(
            key: ValueKey('device-checkbox-${device.id}'),
            value: widget.selected.contains(device.id),
            onChanged: (_) => widget.onToggleDevice(device.id),
            visualDensity: VisualDensity.compact,
          ),
          const Icon(
            Icons.directions_car_outlined,
            size: 18,
            color: Colors.blueGrey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: choose,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    if (!widget.singleSelection)
                      Text(
                        position == null
                            ? 'No position'
                            : '${position.kmh.toStringAsFixed(0)} km/h',
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!widget.singleSelection)
            IconButton(
              tooltip: 'Show on map',
              onPressed: position == null
                  ? null
                  : () => widget.onFocus?.call(device.id),
              icon: const Icon(Icons.near_me_outlined, size: 20),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
