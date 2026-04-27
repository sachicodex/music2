import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_user_data_service.dart';
import 'src/app_controller.dart';
import 'src/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final _FirebaseStartupResult firebaseStartupResult =
      await _initializeFirebase();

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

  Widget app = MusixApp(
    home: firebaseStartupResult.isReady
        ? const AuthGate()
        : FirebaseSetupScreen(errorMessage: firebaseStartupResult.errorMessage),
  );

  if (firebaseStartupResult.isReady) {
    app = MultiProvider(
      providers: [
        Provider<FirestoreUserDataService>(
          create: (_) => FirestoreUserDataService(),
        ),
        Provider<AuthService>(
          create: (BuildContext context) => AuthService(
            firestoreUserDataService: context.read<FirestoreUserDataService>(),
          ),
        ),
        ChangeNotifierProvider<MusixController>(
          create: (BuildContext context) => MusixController(
            firestoreUserDataService: context.read<FirestoreUserDataService>(),
          ),
        ),
      ],
      child: app,
    );
  } else {
    app = ChangeNotifierProvider<MusixController>(
      create: (_) => MusixController(),
      child: app,
    );
  }

  runApp(app);
}

Future<_FirebaseStartupResult> _initializeFirebase() async {
  try {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on UnsupportedError {
      await Firebase.initializeApp();
    }
    return const _FirebaseStartupResult(isReady: true);
  } on UnsupportedError catch (error) {
    return _FirebaseStartupResult(
      isReady: false,
      errorMessage:
          'Firebase is not configured yet. Run "flutterfire configure" and add your Firebase app files.\n\n$error',
    );
  } on FirebaseException catch (error) {
    return _FirebaseStartupResult(
      isReady: false,
      errorMessage: error.message ?? 'Firebase initialization failed.',
    );
  } catch (error) {
    return _FirebaseStartupResult(
      isReady: false,
      errorMessage: 'Unexpected Firebase error: $error',
    );
  }
}

class _FirebaseStartupResult {
  const _FirebaseStartupResult({required this.isReady, this.errorMessage});

  final bool isReady;
  final String? errorMessage;
}
