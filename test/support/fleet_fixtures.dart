import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:dideban_sepehr/live_controller.dart';
import 'package:dideban_sepehr/models.dart';

class FixtureTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

class FixtureLiveController extends LiveController {
  FixtureLiveController(super.api) {
    connected = true;
    groups = [
      DeviceGroup.fromJson({'id': 1, 'name': 'Fleet'}),
    ];
    for (final id in [7, 8]) {
      devices[id] = Device.fromJson({
        'id': id,
        'name': 'Sepehr 0$id',
        'groupId': 1,
      });
      positions[id] = Position.fromJson({
        'id': id,
        'deviceId': id,
        'latitude': id == 7 ? 35.7 : 32.65,
        'longitude': id == 7 ? 51.4 : 51.66,
        'speed': 10,
        'fixTime': '2026-10-19T08:00:00Z',
      });
    }
    selected.addAll([7, 8]);
  }

  @override
  Future<void> start() async {}
}
