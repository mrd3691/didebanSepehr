import 'package:latlong2/latlong.dart';
import 'package:shamsi_date/shamsi_date.dart';

typedef Json = Map<String, dynamic>;
final speedAlertThreshold =
    double.tryParse(
      const String.fromEnvironment(
        'SPEED_ALERT_THRESHOLD_KMH',
        defaultValue: '100',
      ),
    ) ??
    100;

class Device {
  Device.fromJson(Json json)
    : id = (json['id'] as num).toInt(),
      name = json['name'] as String? ?? '',
      uniqueId = json['uniqueId'] as String? ?? '',
      groupId = (json['groupId'] as num?)?.toInt() ?? 0,
      status = json['status'] as String? ?? 'unknown';
  final int id, groupId;
  final String name, uniqueId, status;
}

class DeviceGroup {
  DeviceGroup.fromJson(Json json)
    : id = (json['id'] as num).toInt(),
      groupId = (json['groupId'] as num?)?.toInt() ?? 0,
      name = json['name'] as String? ?? '';
  final int id, groupId;
  final String name;
}

class Position {
  Position.fromJson(Json json)
    : id = (json['id'] as num).toInt(),
      deviceId = (json['deviceId'] as num).toInt(),
      latitude = (json['latitude'] as num).toDouble(),
      longitude = (json['longitude'] as num).toDouble(),
      speed = (json['speed'] as num?)?.toDouble() ?? 0,
      course = (json['course'] as num?)?.toDouble() ?? 0,
      time = DateTime.parse(json['fixTime'] as String).toUtc(),
      valid = json['valid'] != false,
      address = json['address'] as String? ?? '',
      attributes = (json['attributes'] as Json?) ?? {};
  final int id, deviceId;
  final double latitude, longitude, speed, course;
  final DateTime time;
  final bool valid;
  final String address;
  final Json attributes;
  double get kmh => speed * 1.852;
  bool get overspeed => speedAlertThreshold > 0 && kmh > speedAlertThreshold;
  bool get hasCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
  LatLng get point => LatLng(latitude, longitude);
}

String stamp(DateTime value) {
  final local = value.toLocal();
  final date = Jalali.fromDateTime(local);
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${date.year}/${pad(date.month)}/${pad(date.day)} '
      '${pad(local.hour)}:${pad(local.minute)}:${pad(local.second)}';
}

DateTime? parseJalali(String date, String time) {
  final parts = date.split('/').map(int.tryParse).toList();
  final clock = time.split(':').map(int.tryParse).toList();
  if (parts.length != 3 ||
      clock.length != 2 ||
      parts.any((v) => v == null) ||
      clock.any((v) => v == null)) {
    return null;
  }
  if (clock[0]! < 0 || clock[0]! > 23 || clock[1]! < 0 || clock[1]! > 59) {
    return null;
  }
  try {
    final day = Jalali(parts[0]!, parts[1]!, parts[2]!);
    final gregorian = day.toDateTime();
    return DateTime(
      gregorian.year,
      gregorian.month,
      gregorian.day,
      clock[0]!,
      clock[1]!,
    );
  } catch (_) {
    return null;
  }
}
