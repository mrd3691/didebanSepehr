import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dideban_sepehr/models.dart';
import 'package:dideban_sepehr/traccar_api.dart';
import 'package:dideban_sepehr/live_controller.dart';

Map<String, dynamic> position(int id, String time, {double latitude = 35.7}) =>
    {
      'id': id,
      'deviceId': 7,
      'latitude': latitude,
      'longitude': 51.4,
      'speed': 10,
      'course': 90,
      'fixTime': time,
      'valid': true,
    };

void main() {
  test('Mobile HTTP server uses the matching REST and WebSocket endpoints', () {
    final api = TraccarApi('http://37.202.178.136:8082');
    addTearDown(api.close);
    expect(api.base.toString(), 'http://37.202.178.136:8082/');
    expect(
      api.endpoint('session').toString(),
      'http://37.202.178.136:8082/api/session',
    );
    expect(api.socketUri.toString(), 'ws://37.202.178.136:8082/api/socket');
    final secure = TraccarApi('https://gps.example.com');
    addTearDown(secure.close);
    expect(secure.socketUri.toString(), 'wss://gps.example.com/api/socket');
  });
  test('Speed conversion and invalid coordinates', () {
    final p = Position.fromJson(position(1, '2026-10-19T08:00:00Z'));
    expect(p.kmh, closeTo(18.52, 0.001));
    expect(p.hasCoordinates, true);
    expect(
      Position.fromJson(
        position(2, '2026-10-19T08:00:00Z', latitude: 91),
      ).hasCoordinates,
      false,
    );
  });
  test('Shamsi input validates calendar and round trips local time', () {
    final date = parseJalali('1405/07/27', '08:30')!;
    expect(date, DateTime(2026, 10, 19, 8, 30));
    expect(stamp(date), '1405/07/27 08:30:00');
    expect(parseJalali('1405/13/01', '08:00'), isNull);
    expect(parseJalali('1405/07/31', '08:00'), isNull);
    expect(parseJalali('1405/07/27', '24:00'), isNull);
  });
  test('Server URLs reject credentials and injected paths', () {
    for (final value in [
      'gps.example.com',
      'https://user:pass@gps.example.com',
      'https://gps.example.com/api',
      'https://gps.example.com?token=a',
    ]) {
      expect(() => TraccarApi(value), throwsA(isA<ApiException>()));
    }
  });

  group('Traccar integration with local test server', () {
    late HttpServer server;
    late TraccarApi api;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      api = TraccarApi('http://127.0.0.1:${server.port}');
    });
    tearDown(() async {
      api.close();
      await server.close(force: true);
    });

    test(
      'Login encodes password and sends session cookie on subsequent requests',
      () async {
        server.listen((request) async {
          if (request.uri.path == '/api/session') {
            final form = Uri.splitQueryString(
              await utf8.decoder.bind(request).join(),
            );
            expect(form, {
              'email': 'driver@example.com',
              'password': 'x&+ =123',
            });
            request.response.cookies.add(Cookie('JSESSIONID', 'session-test'));
            request.response.write(jsonEncode({'id': 3}));
          } else {
            expect(request.headers.value('cookie'), 'JSESSIONID=session-test');
            request.response.write('[]');
          }
          await request.response.close();
        });
        await api.login('driver@example.com', 'x&+ =123');
        expect(api.cookie, 'JSESSIONID=session-test');
        expect(await api.devices(), isEmpty);
      },
    );

    test(
      'History includes UTC range, sorts points and excludes broken coordinates',
      () async {
        final from = DateTime.utc(2026, 10, 19, 8),
            to = DateTime.utc(2026, 10, 19, 9);
        server.listen((request) async {
          expect(request.uri.queryParameters, {
            'deviceId': '7',
            'from': from.toIso8601String(),
            'to': to.toIso8601String(),
          });
          request.response.write(
            jsonEncode([
              position(2, '2026-10-19T08:10:00Z'),
              position(1, '2026-10-19T08:00:00Z'),
              position(3, '2026-10-19T08:20:00Z', latitude: 95),
            ]),
          );
          await request.response.close();
        });
        final result = await api.positions(deviceId: 7, from: from, to: to);
        expect(result.map((p) => p.id), [1, 2]);
      },
    );

    test('401 reports expired session', () async {
      var expired = false;
      api.onUnauthorized = () => expired = true;
      server.listen((request) async {
        request.response.statusCode = 401;
        await request.response.close();
      });
      await expectLater(
        api.devices(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(expired, true);
    });

    test(
      'WebSocket merges devices and keeps newer positions; stop closes stream',
      () async {
        api.cookie = 'JSESSIONID=session-test';
        final socketReady = Completer<WebSocket>();
        server.listen((request) async {
          expect(request.headers.value('cookie'), 'JSESSIONID=session-test');
          if (request.uri.path == '/api/socket') {
            socketReady.complete(await WebSocketTransformer.upgrade(request));
            return;
          }
          request.response.write(switch (request.uri.path) {
            '/api/devices' => '[{"id":7,"name":"Sepehr","status":"offline"}]',
            '/api/groups' => '[]',
            _ => jsonEncode([position(2, '2026-10-19T08:10:00Z')]),
          });
          await request.response.close();
        });
        final live = LiveController(api);
        addTearDown(live.dispose);
        await live.start();
        final socket = await socketReady.future;
        expect(live.connected, true);
        final updated = Completer<void>();
        live.addListener(() {
          if (live.devices[7]?.status == 'online' && !updated.isCompleted) {
            updated.complete();
          }
        });
        socket.add(
          jsonEncode({
            'positions': [position(1, '2026-10-19T08:00:00Z')],
            'devices': [
              {'id': 7, 'name': 'Sepehr', 'status': 'online'},
            ],
          }),
        );
        await updated.future.timeout(const Duration(seconds: 3));
        expect(live.positions[7]!.id, 2);
        live.toggle(7);
        expect(live.selected, {7});
        live.stop();
        expect(live.connected, false);
        await socket.close();
      },
    );
  });
}
