import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'src/app_controller.dart';
import 'src/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final controller = SonixController();
  await controller.initialize();

  runApp(
    ChangeNotifierProvider<SonixController>.value(
      value: controller,
      child: const SonixApp(),
    ),
  );
}
