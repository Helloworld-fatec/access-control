import 'dart:io';

Future<void> discardFaceCaptureFile(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // O arquivo pode ter sido removido pelo gerenciador de cache do dispositivo.
  }
}
