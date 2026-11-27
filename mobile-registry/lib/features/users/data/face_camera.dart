import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

const maxFacePhotoBytes = 102400;

typedef FacePhotoCapture = Future<Uint8List?> Function();

Future<Uint8List?> captureFacePhoto() async {
  final photo = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 480,
    maxHeight: 480,
    imageQuality: 55,
    requestFullMetadata: false,
  );
  if (photo == null) return null;
  try {
    if (await photo.length() > maxFacePhotoBytes) {
      throw const FormatException('A foto excede 100 KB. Tire outra foto.');
    }
    final bytes = await photo.readAsBytes();
    if (bytes.length < 3 ||
        bytes[0] != 0xff ||
        bytes[1] != 0xd8 ||
        bytes[2] != 0xff) {
      throw const FormatException('A câmera precisa produzir uma foto JPEG.');
    }
    return bytes;
  } finally {
    await _discard(photo);
  }
}

// Após o Android recriar o processo, o formulário e o usuário vinculados
// à captura foram perdidos. Descartar a foto evita retomá-la no cadastro errado.
Future<void> discardInterruptedCapture() async {
  if (!Platform.isAndroid) return;
  try {
    final lost = await ImagePicker().retrieveLostData();
    for (final file in lost.files ?? const <XFile>[]) {
      await _discard(file);
    }
  } on Exception {
    // A próxima captura pode ser iniciada normalmente.
  }
}

Future<void> _discard(XFile photo) async {
  try {
    await File(photo.path).delete();
  } on FileSystemException {
    // O cache temporário também é gerenciado pelo Android.
  }
}
