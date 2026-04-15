import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'src/app_controller.dart';
import 'src/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final controller = OuterTuneController();
  await controller.initialize();

  runApp(
    ChangeNotifierProvider<OuterTuneController>(
      create: (_) => controller,
      child: const OuterTuneApp(),
    ),
  );
}
