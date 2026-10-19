import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show TileProvider;
import 'fleet_map.dart';
import 'device_sheet.dart';
import 'position_details_card.dart';
import 'live_controller.dart';
import 'models.dart';
import 'traccar_api.dart';

const _ink = Color(0xFF10283F), _sea = Color(0xFF007F78);

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    super.key,
    required this.api,
    required this.onLogout,
    this.liveController,
    this.tileProvider,
  });
  final TraccarApi api;
  final VoidCallback onLogout;
  final LiveController? liveController;
  final TileProvider? tileProvider;
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with WidgetsBindingObserver {
  late final live = widget.liveController ?? LiveController(widget.api);
  int tab = 0, fitRevision = 0, focusRevision = 0;
  int? focusedId, routeDevice;
  bool follow = false, routeBusy = false, playing = false;
  String? routeError;
  List<Position> route = [];
  int index = 0, multiplier = 1, routeRequest = 0;
  Timer? playback;
  late DateTime from = DateTime.now().subtract(const Duration(days: 1));
  late DateTime to = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    live.addListener(changed);
    live.start();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      live.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      live.stop();
      pause();
    }
  }

  @override
  void dispose() {
    routeRequest++;
    WidgetsBinding.instance.removeObserver(this);
    live.removeListener(changed);
    if (widget.liveController == null) live.dispose();
    playback?.cancel();
    super.dispose();
  }

  void pause() {
    playback?.cancel();
    playback = null;
    if (mounted) setState(() => playing = false);
  }

  void play() {
    if (route.length < 2) return;
    playback?.cancel();
    setState(() {
      if (index == route.length - 1) index = 0;
      playing = true;
      follow = true;
    });
    playback = Timer.periodic(
      Duration(milliseconds: (900 / multiplier).round()),
      (_) {
        if (index >= route.length - 1) {
          pause();
          return;
        }
        setState(() => index++);
      },
    );
  }

  void focusDevice(int id) {
    setState(() {
      focusedId = id;
      follow = true;
      live.selected.add(id);
      focusRevision++;
    });
  }

  Future<void> loadRoute() async {
    if (routeDevice == null) return;
    pause();
    final request = ++routeRequest;
    setState(() {
      routeBusy = true;
      routeError = null;
      route = [];
      index = 0;
    });
    try {
      final result = await widget.api.positions(
        deviceId: routeDevice,
        from: from,
        to: to,
      );
      if (!mounted || request != routeRequest) return;
      setState(() {
        route = result;
        index = 0;
        follow = false;
        fitRevision++;
        if (result.isEmpty) {
          routeError = 'No positions found in this time range.';
        }
      });
    } catch (e) {
      if (mounted && request == routeRequest) {
        setState(
          () => routeError = e is ApiException
              ? e.message
              : 'Unable to load the route.',
        );
      }
    } finally {
      if (mounted && request == routeRequest) setState(() => routeBusy = false);
    }
  }

  Future<void> chooseRoute() async {
    final result = await showModalBottomSheet<RouteSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RouteFilter(
        devices: live.devices.values.toList(),
        groups: live.groups,
        deviceId: routeDevice,
        from: from,
        to: to,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      routeDevice = result.deviceId;
      from = result.from;
      to = result.to;
    });
    await loadRoute();
  }

  Future<void> chooseDevices() async {
    final focusedDevice = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DeviceSheet(
        live: live,
        onFocus: (id) {
          Navigator.pop(context, id);
        },
      ),
    );
    if (mounted && focusedDevice != null) {
      focusDevice(focusedDevice);
      return;
    }
    if (mounted) {
      setState(() {
        fitRevision++;
        if (!live.selected.contains(focusedId)) {
          focusedId = null;
          follow = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = tab == 0
        ? live.positions[focusedId]
        : (route.isEmpty ? null : route[index]);
    final displayed = tab == 0
        ? live.selected
              .map((id) => live.positions[id])
              .whereType<Position>()
              .toList()
        : (active == null ? <Position>[] : [active]);
    final error = tab == 0 ? live.error : routeError;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.radar_rounded, color: _sea, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dideban Sepehr',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  Text(
                    'FLEET MONITORING',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: live.loading ? null : () => live.start(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (_) => widget.onLogout(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  _Badge(
                    label: tab == 0
                        ? (live.connected ? 'LIVE' : 'CONNECTING')
                        : 'TRACKING',
                    color: live.connected || tab == 1 ? _sea : Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tab == 0
                          ? '${live.devices.length} devices'
                          : (routeDevice == null
                                ? 'Route history'
                                : live.devices[routeDevice]?.name ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (tab == 0)
                    Text(
                      '${live.selected.length} selected',
                      style: const TextStyle(color: _sea, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (live.loading || routeBusy)
              const LinearProgressIndicator(minHeight: 2),
            if (error != null)
              Container(
                width: double.infinity,
                color: const Color(0xFFFFF0DF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.deepOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(error, style: const TextStyle(fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: tab == 0 ? () => live.start() : loadRoute,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  FleetMap(
                    positions: displayed,
                    names: {for (final d in live.devices.values) d.id: d.name},
                    route: tab == 1 ? route : const [],
                    focus: active,
                    follow: follow,
                    fitRevision: fitRevision,
                    focusRevision: tab == 0 ? focusRevision : 0,
                    showDeviceNames: tab == 1,
                    tileProvider: widget.tileProvider,
                    onTap: focusDevice,
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: tab == 0 ? chooseDevices : chooseRoute,
                          icon: Icon(
                            tab == 0
                                ? Icons.directions_car_outlined
                                : Icons.tune_rounded,
                          ),
                          label: Text(tab == 0 ? 'Devices' : 'Select route'),
                        ),
                        const Spacer(),
                        if (active != null)
                          IconButton.filled(
                            tooltip: 'Follow device',
                            style: IconButton.styleFrom(
                              backgroundColor: follow ? _sea : Colors.white,
                              foregroundColor: follow ? Colors.white : _ink,
                            ),
                            onPressed: () => setState(() => follow = !follow),
                            icon: const Icon(Icons.my_location_rounded),
                          ),
                      ],
                    ),
                  ),
                  if ((tab == 0 && live.selected.isEmpty) ||
                      (tab == 1 && route.isEmpty && !routeBusy))
                    Center(
                      child: Card(
                        color: Colors.white.withValues(alpha: 0.95),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tab == 0
                                    ? Icons.location_searching
                                    : Icons.route_rounded,
                                size: 34,
                                color: _sea,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                tab == 0
                                    ? 'Select your devices'
                                    : 'Replay a journey',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                tab == 0
                                    ? 'Choose devices to display on the map.'
                                    : 'Choose a device and time range.',
                                style: const TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (active != null)
              PositionDetailsCard(
                position: active,
                name: live.devices[active.deviceId]?.name ?? '',
              ),
            if (tab == 1 && route.isNotEmpty) _playbackPanel(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) {
            pause();
            setState(() {
              tab = value;
              follow = false;
              fitRevision++;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.radar_outlined),
              selectedIcon: Icon(Icons.radar_rounded),
              label: 'Live',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route_rounded),
              label: 'Tracking',
            ),
          ],
        ),
      ),
    );
  }

  Widget _playbackPanel() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        Row(
          children: [
            Text(
              '${index + 1} / ${route.length}',
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
            Expanded(
              child: Slider(
                value: index.toDouble(),
                min: 0,
                max: (route.length - 1).clamp(1, 1 << 30).toDouble(),
                onChanged: route.length < 2
                    ? null
                    : (v) {
                        pause();
                        setState(() {
                          index = v.round();
                          follow = true;
                        });
                      },
              ),
            ),
            DropdownButton<int>(
              value: multiplier,
              underline: const SizedBox.shrink(),
              items: [1, 2, 4, 8, 16]
                  .map(
                    (n) => DropdownMenuItem(
                      value: n,
                      child: Text(
                        '${n}x',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => multiplier = v!);
                if (playing) play();
              },
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous point',
              onPressed: index > 0
                  ? () {
                      pause();
                      setState(() {
                        index--;
                        follow = true;
                      });
                    }
                  : null,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            FilledButton.tonalIcon(
              onPressed: route.length < 2
                  ? null
                  : playing
                  ? pause
                  : play,
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(playing ? 'Pause' : 'Play route'),
            ),
            IconButton(
              tooltip: 'Next point',
              onPressed: index < route.length - 1
                  ? () {
                      pause();
                      setState(() {
                        index++;
                        follow = true;
                      });
                    }
                  : null,
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 6),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}

class RouteSelection {
  RouteSelection(this.deviceId, this.from, this.to);
  final int deviceId;
  final DateTime from, to;
}

class RouteFilter extends StatefulWidget {
  const RouteFilter({
    super.key,
    required this.devices,
    this.groups = const [],
    required this.deviceId,
    required this.from,
    required this.to,
  });
  final List<Device> devices;
  final List<DeviceGroup> groups;
  final int? deviceId;
  final DateTime from, to;
  @override
  State<RouteFilter> createState() => _RouteFilterState();
}

class _RouteFilterState extends State<RouteFilter> {
  final form = GlobalKey<FormState>();
  late int? id = widget.devices.any((d) => d.id == widget.deviceId)
      ? widget.deviceId
      : null;
  late final fromDate = TextEditingController(
    text: stamp(widget.from).split(' ').first,
  );
  late final toDate = TextEditingController(
    text: stamp(widget.to).split(' ').first,
  );
  late final fromTime = TextEditingController(
    text: stamp(widget.from).split(' ').last.substring(0, 5),
  );
  late final toTime = TextEditingController(
    text: stamp(widget.to).split(' ').last.substring(0, 5),
  );
  String? error;
  @override
  void dispose() {
    for (final c in [fromDate, toDate, fromTime, toTime]) {
      c.dispose();
    }
    super.dispose();
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    final start = parseJalali(fromDate.text.trim(), fromTime.text.trim());
    final end = parseJalali(toDate.text.trim(), toTime.text.trim());
    if (start == null || end == null || !start.isBefore(end)) {
      setState(
        () => error = 'Enter valid dates and times. Start must be before end.',
      );
      return;
    }
    Navigator.pop(context, RouteSelection(id!, start, end));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Route history',
              style: TextStyle(
                color: _ink,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Jalali dates / device local time',
              style: TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
            const SizedBox(height: 24),
            FormField<int>(
              initialValue: id,
              validator: (v) => v == null ? 'Select a device.' : null,
              builder: (field) => InkWell(
                key: const ValueKey('route-device-picker'),
                onTap: widget.devices.isEmpty
                    ? null
                    : () async {
                        final deviceId = await showModalBottomSheet<int>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => SingleDeviceSheet(
                            devices: widget.devices,
                            groups: widget.groups,
                            selectedId: id,
                          ),
                        );
                        if (deviceId == null || !mounted) return;
                        setState(() => id = deviceId);
                        field.didChange(deviceId);
                      },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Device',
                    errorText: field.errorText,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.devices
                                  .where((d) => d.id == id)
                                  .firstOrNull
                                  ?.name ??
                              'Select a device',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.account_tree_outlined),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _field(fromDate, 'Start date', '1405/07/27'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _field(fromTime, 'Start time', '08:00'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _field(toDate, 'End date', '1405/07/27'),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _field(toTime, 'End time', '18:00')),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.deepOrange),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.devices.isEmpty ? null : submit,
                icon: const Icon(Icons.route_rounded),
                label: const Text('Load route'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _field(TextEditingController c, String label, String hint) =>
      TextFormField(
        controller: c,
        keyboardType: TextInputType.datetime,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
      );
}
