import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'models.dart';

class FleetMap extends StatefulWidget {
  const FleetMap({
    super.key,
    required this.positions,
    required this.names,
    this.route = const [],
    this.focus,
    this.follow = false,
    this.fitRevision = 0,
    this.focusRevision = 0,
    this.showDeviceNames = false,
    this.tileProvider,
    required this.onTap,
  });
  final List<Position> positions, route;
  final Map<int, String> names;
  final Position? focus;
  final bool follow;
  final int fitRevision, focusRevision;
  final bool showDeviceNames;
  final TileProvider? tileProvider;
  final ValueChanged<int> onTap;
  @override
  State<FleetMap> createState() => _FleetMapState();
}

class _FleetMapState extends State<FleetMap> {
  final controller = MapController();
  bool ready = false;
  @override
  void didUpdateWidget(covariant FleetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!ready) return;
    if (widget.focusRevision > 0 &&
        oldWidget.focusRevision != widget.focusRevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusDevice();
      });
    } else if (oldWidget.fitRevision != widget.fitRevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fit();
      });
    } else if (widget.focus != null &&
        widget.follow &&
        (oldWidget.focus != widget.focus || !oldWidget.follow)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.focus != null) {
          controller.move(
            widget.focus!.point,
            math.max(14, controller.camera.zoom),
          );
        }
      });
    }
  }

  void focusDevice() {
    if (widget.focus == null) return;
    controller.move(widget.focus!.point, math.max(16, controller.camera.zoom));
  }

  void fit() {
    final points = (widget.route.isNotEmpty ? widget.route : widget.positions)
        .map((p) => p.point)
        .toList();
    if (points.isEmpty) return;
    if (points.length == 1) {
      controller.move(points.first, 15);
      return;
    }
    controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(60),
        maxZoom: 16,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: const LatLng(32.5, 53.5),
          initialZoom: 5,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            cursorKeyboardRotationOptions:
                CursorKeyboardRotationOptions.disabled(),
          ),
          onMapReady: () {
            ready = true;
            if (widget.focusRevision > 0 && widget.focus != null) {
              focusDevice();
            } else {
              fit();
            }
          },
        ),
        children: [
          TileLayer(
            tileProvider: widget.tileProvider,
            urlTemplate: const String.fromEnvironment(
              'MAP_TILE_URL',
              defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            userAgentPackageName: 'ir.didebansepehr.dideban_sepehr',
            maxNativeZoom: 19,
          ),
          if (widget.route.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.route.map((p) => p.point).toList(),
                  color: const Color(0xFF007F78),
                  strokeWidth: 5,
                  borderColor: Colors.white,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
          if (widget.route.isNotEmpty)
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.route.first.point,
                  width: 30,
                  height: 30,
                  child: const CircleAvatar(
                    backgroundColor: Color(0xFF007F78),
                    child: Text(
                      'S',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                Marker(
                  point: widget.route.last.point,
                  width: 30,
                  height: 30,
                  child: const CircleAvatar(
                    backgroundColor: Color(0xFF10283F),
                    child: Text(
                      'E',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          MarkerLayer(
            markers: widget.positions
                .map(
                  (p) => Marker(
                    point: p.point,
                    width: widget.showDeviceNames ? 130 : 46,
                    height: widget.showDeviceNames ? 74 : 46,
                    child: GestureDetector(
                      onTap: () => widget.onTap(p.deviceId),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.showDeviceNames)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10283F),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.names[p.deviceId] ?? '${p.deviceId}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (widget.showDeviceNames) const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: !p.valid
                                  ? Colors.grey
                                  : p.overspeed
                                  ? Colors.red
                                  : const Color(0xFF007F78),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 8),
                              ],
                            ),
                            child: Transform.rotate(
                              angle: p.course * math.pi / 180,
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      Positioned(
        bottom: 6,
        left: 8,
        child: Container(
          color: Colors.white.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: const Text(
            'Map data: (c) OpenStreetMap contributors',
            style: TextStyle(fontSize: 9, color: Colors.black87),
          ),
        ),
      ),
      Positioned(
        right: 14,
        bottom: 34,
        child: Column(
          children: [
            FloatingActionButton.small(
              heroTag: 'fit',
              tooltip: 'Fit all',
              backgroundColor: Colors.white,
              onPressed: fit,
              child: const Icon(Icons.fit_screen_rounded),
            ),
            const SizedBox(height: 6),
            FloatingActionButton.small(
              heroTag: 'zoom',
              tooltip: 'Zoom',
              backgroundColor: Colors.white,
              onPressed: () => controller.move(
                controller.camera.center,
                (controller.camera.zoom + 1).clamp(2, 19),
              ),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    ],
  );
}
