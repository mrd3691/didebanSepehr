import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class TraccarApi {
  TraccarApi(String server, {this.cookie}) : base = normalizeServer(server);
  final Uri base;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  String? cookie;
  void Function()? onUnauthorized;

  static Uri normalizeServer(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ApiException(
        'Enter a server address such as http://37.202.178.136:8082.',
      );
    }
    return uri.replace(path: '/');
  }

  Uri endpoint(String path, [Map<String, String>? query]) =>
      base.resolve('api/$path').replace(queryParameters: query);

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, String>? query,
    String? form,
  }) async {
    try {
      final request = await _client.openUrl(method, endpoint(path, query));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (cookie != null) {
        request.headers.set(HttpHeaders.cookieHeader, cookie!);
      }
      if (form != null) {
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        request.write(form);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) onUnauthorized?.call();
        throw ApiException(
          response.statusCode == 401
              ? 'Invalid username or password, or your session has expired.'
              : 'Unable to load data (${response.statusCode}).',
          response.statusCode,
        );
      }
      for (final item in response.cookies) {
        if (item.name == 'JSESSIONID') cookie = '${item.name}=${item.value}';
      }
      return body.trim().isEmpty ? null : jsonDecode(body);
    } on TimeoutException {
      throw ApiException('The server did not respond. Please try again.');
    } on SocketException {
      throw ApiException(
        'Cannot connect to the server. Check your connection and server address.',
      );
    } on HandshakeException {
      throw ApiException('The server HTTPS certificate is not valid.');
    } on FormatException {
      throw ApiException('The server returned an invalid response.');
    }
  }

  Future<Json> login(String username, String password) async {
    final body = Uri(
      queryParameters: {'email': username, 'password': password},
    ).query;
    final user = await request('POST', 'session', form: body) as Json;
    if (cookie == null) {
      throw ApiException('The server did not return a valid session.');
    }
    return user;
  }

  Future<Json> session() async => await request('GET', 'session') as Json;
  Future<List<Device>> devices() async =>
      (await request('GET', 'devices') as List)
          .map((e) => Device.fromJson(e as Json))
          .toList();
  Future<List<DeviceGroup>> groups() async =>
      (await request('GET', 'groups') as List)
          .map((e) => DeviceGroup.fromJson(e as Json))
          .toList();
  Future<List<Position>> positions({
    int? deviceId,
    DateTime? from,
    DateTime? to,
  }) async {
    final rows =
        await request(
              'GET',
              'positions',
              query: deviceId == null
                  ? null
                  : {
                      'deviceId': '$deviceId',
                      'from': from!.toUtc().toIso8601String(),
                      'to': to!.toUtc().toIso8601String(),
                    },
            )
            as List;
    return rows
        .map((e) => Position.fromJson(e as Json))
        .where((p) => p.hasCoordinates)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  Uri get socketUri =>
      endpoint('socket').replace(scheme: base.scheme == 'https' ? 'wss' : 'ws');

  Future<WebSocket> connect() => WebSocket.connect(
    socketUri.toString(),
    headers: {HttpHeaders.cookieHeader: cookie!},
  ).timeout(const Duration(seconds: 20));
  void close() => _client.close(force: true);
}
