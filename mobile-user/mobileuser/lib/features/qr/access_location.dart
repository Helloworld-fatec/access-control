import 'dart:async';

import 'package:geolocator/geolocator.dart';

class AccessLocationException implements Exception {
  const AccessLocationException(this.message);

  final String message;
}

Future<Position> locateForQrAccess() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AccessLocationException(
        'Ative a localização do celular e leia um QR atualizado.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AccessLocationException(
        'Permita a localização nas configurações do app e leia um QR atualizado.',
      );
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const AccessLocationException(
        'É necessário permitir a localização para validar o acesso.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    final age = DateTime.now().difference(position.timestamp).abs();
    if (age > const Duration(seconds: 15) ||
        !position.accuracy.isFinite ||
        position.accuracy <= 0 ||
        position.accuracy > 50) {
      throw const AccessLocationException(
        'Localização pouco precisa. Ative a localização precisa e leia um QR atualizado.',
      );
    }
    return position;
  } on AccessLocationException {
    rethrow;
  } on TimeoutException {
    throw const AccessLocationException(
      'A localização demorou para responder. Leia um QR atualizado.',
    );
  } on LocationServiceDisabledException {
    throw const AccessLocationException(
      'Ative a localização do celular e leia um QR atualizado.',
    );
  } on Exception {
    throw const AccessLocationException(
      'Não foi possível obter a localização. Confira a permissão e tente novamente.',
    );
  }
}
