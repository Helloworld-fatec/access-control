import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobileuser/core/api/api_client.dart';
import 'package:mobileuser/features/qr/access_location.dart';

class _Location extends GeolocatorPlatform {
  bool enabled = true;
  bool timeout = false;
  int requests = 0;
  int reads = 0;
  double accuracy = 12;
  Duration age = Duration.zero;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission afterRequest = LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return afterRequest;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    reads++;
    expect(locationSettings?.accuracy, LocationAccuracy.high);
    expect(locationSettings?.timeLimit, const Duration(seconds: 8));
    if (timeout) throw TimeoutException('Location timeout');
    return Position(
      latitude: -23.5,
      longitude: -46.6,
      timestamp: DateTime.now().subtract(age),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late _Location location;
  setUp(() {
    final original = GeolocatorPlatform.instance;
    location = _Location();
    GeolocatorPlatform.instance = location;
    addTearDown(() => GeolocatorPlatform.instance = original);
  });

  test('solicita permissão ao ler QR e envia somente token e coordenadas', () async {
    location.permission = LocationPermission.denied;
    final position = await locateForQrAccess();
    expect(location.requests, 1);
    final client = MockClient((request) async {
      expect(request.url.path, '/api/access/qr/consume');
      expect(request.headers['authorization'], 'Bearer jwt');
      expect(jsonDecode(request.body), {
        'token': 'test-qr',
        'latitude': -23.5,
        'longitude': -46.6,
      });
      return http.Response('{"result":"GRANTED"}', 200);
    });
    addTearDown(client.close);
    final api = ApiClient('https://server.example', 'jwt', client);
    await api.consumeQr(
      'test-qr',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  });

  test('recusa localização desligada ou permissão negada sem ler posição', () async {
    location.enabled = false;
    await expectLater(locateForQrAccess(), throwsA(isA<AccessLocationException>()));
    location.enabled = true;
    location.permission = LocationPermission.denied;
    location.afterRequest = LocationPermission.denied;
    await expectLater(locateForQrAccess(), throwsA(isA<AccessLocationException>()));
    expect(location.requests, 1);
    expect(location.reads, 0);
  });

  test('recusa baixa precisão, posição antiga e timeout', () async {
    location.accuracy = 51;
    await expectLater(locateForQrAccess(), throwsA(isA<AccessLocationException>()));
    location.accuracy = 20;
    location.age = const Duration(seconds: 16);
    await expectLater(locateForQrAccess(), throwsA(isA<AccessLocationException>()));
    location.timeout = true;
    await expectLater(locateForQrAccess(), throwsA(isA<AccessLocationException>()));
  });
}
