import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'src/app_controller.dart';
import 'src/media_notification_service.dart';
import 'src/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final MusicNotificationService notificationService = MusicNotificationService();
  bool notificationInitOk = true;
  try {
    await AudioService.init(
      builder: () => notificationService,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.music.playback',
        androidNotificationChannelName: 'Music Playback',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ),
    );
  } catch (_) {
    notificationInitOk = false;
  }

  final controller = OuterTuneController(
    notificationService: notificationInitOk ? notificationService : null,
  );
  await controller.initialize();

  runApp(
    ChangeNotifierProvider<OuterTuneController>(
      create: (_) => controller,
      child: const OuterTuneApp(),
    ),
  );
}
