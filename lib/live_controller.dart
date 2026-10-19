import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'traccar_api.dart';

class LiveController extends ChangeNotifier {
  LiveController(this.api);
  final TraccarApi api;
  final Map<int, Device> devices = {};
  final Map<int, Position> positions = {};
  List<DeviceGroup> groups = [];
  final Set<int> selected = {};
  String? error;
  bool loading = false, connected = false;
  WebSocket? _socket;
  Timer? _retry, _flush;
  int _generation = 0, _attempt = 0;
  bool _disposed = false;

  Future<void> start() async {
    stop();
    final generation = _generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await Future.wait([
        api.devices(),
        api.groups(),
        api.positions(),
      ]);
      if (_disposed || generation != _generation) return;
      devices
        ..clear()
        ..addEntries((data[0] as List<Device>).map((d) => MapEntry(d.id, d)));
      groups = data[1] as List<DeviceGroup>;
      selected.removeWhere((id) => !devices.containsKey(id));
      positions.removeWhere((id, _) => !devices.containsKey(id));
      for (final position in data[2] as List<Position>) {
        _merge(position);
      }
      await _connect(generation);
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e is ApiException ? e.message : 'Unable to load data.';
        _scheduleRetry(generation);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void _merge(Position p) {
    final previous = positions[p.deviceId];
    if (p.hasCoordinates &&
        (previous == null || !p.time.isBefore(previous.time))) {
      positions[p.deviceId] = p;
    }
  }

  Future<void> _connect(int generation) async {
    final socket = await api.connect();
    if (_disposed || generation != _generation) {
      await socket.close();
      return;
    }
    _socket = socket;
    connected = true;
    error = null;
    _attempt = 0;
    notifyListeners();
    socket.pingInterval = const Duration(seconds: 30);
    socket.listen(
      (message) {
        if (_disposed || generation != _generation) return;
        try {
          final data = jsonDecode(message as String) as Json;
          for (final row in data['positions'] as List? ?? []) {
            _merge(Position.fromJson(row as Json));
          }
          for (final row in data['devices'] as List? ?? []) {
            final device = Device.fromJson(row as Json);
            devices[device.id] = device;
          }
          _flush ??= Timer(const Duration(milliseconds: 300), () {
            _flush = null;
            if (!_disposed) notifyListeners();
          });
        } catch (_) {
          /* Keep the last known positions for incomplete frames. */
        }
      },
      onDone: () => _disconnected(generation),
      onError: (_) => _disconnected(generation),
      cancelOnError: true,
    );
  }

  void _disconnected(int generation) {
    if (_disposed || generation != _generation) return;
    connected = false;
    error = 'Live connection lost. Reconnecting...';
    notifyListeners();
    _scheduleRetry(generation);
  }

  void _scheduleRetry(int generation) {
    if (_disposed || generation != _generation || _retry != null) return;
    final seconds = 1 << (_attempt++).clamp(0, 5);
    _retry = Timer(Duration(seconds: seconds), () {
      _retry = null;
      start();
    });
  }

  void toggle(int id) {
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    notifyListeners();
  }

  void selectAll() {
    if (selected.length == devices.length) {
      selected.clear();
    } else {
      selected.addAll(devices.keys);
    }
    notifyListeners();
  }

  void toggleGroup(Iterable<int> deviceIds) {
    final ids = deviceIds.where(devices.containsKey).toSet();
    if (ids.isEmpty) return;
    // Match the web tree: a partially selected group clears its whole branch.
    if (ids.any(selected.contains)) {
      selected.removeAll(ids);
    } else {
      selected.addAll(ids);
    }
    notifyListeners();
  }

  void stop() {
    _generation++;
    _retry?.cancel();
    _retry = null;
    _flush?.cancel();
    _flush = null;
    _socket?.close();
    _socket = null;
    connected = false;
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
