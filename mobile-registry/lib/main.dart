import 'package:flutter/material.dart';

import 'app.dart';
import 'core/error/global_error_handler.dart';
import 'features/users/data/face_camera.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalErrorHandlers();
  await discardInterruptedCapture();
  runApp(const AccessRegistryApp());
}
