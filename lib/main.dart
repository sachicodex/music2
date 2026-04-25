import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app_controller.dart';
import 'src/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    await windowManager.ensureInitialized();
    final bool isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final WindowOptions windowOptions = WindowOptions(
      size: isWindows ? null : const Size(1280, 720),
      minimumSize: const Size(960, 640),
      center: !isWindows,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'Musix',
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    unawaited(
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  runApp(
    ChangeNotifierProvider<MusixController>(
      create: (_) => MusixController(),
      child: const MusixApp(),
    ),
  );
}
