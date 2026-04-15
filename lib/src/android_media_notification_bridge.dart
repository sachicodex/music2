import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

class AndroidMediaNotificationBridge {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.music/media_notification',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.music/media_notification_actions',
  );

  static const String _actionPlayPause = 'play_pause';
  static const String _actionPlay = 'play';
  static const String _actionPause = 'pause';
  static const String _actionNext = 'next';
  static const String _actionPrevious = 'previous';

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Stream<String> actionStream() {
    if (!isSupported) {
      return const Stream<String>.empty();
    }
    return _eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => (event as Map<dynamic, dynamic>)['action'])
        .where((dynamic action) => action is String)
        .cast<String>();
  }

  static Future<void> updatePlayback({
    required LibrarySong? song,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
  }) async {
    if (!isSupported) {
      return;
    }

    await _methodChannel.invokeMethod<void>('updateNotification', <String, dynamic>{
      'title': song?.title ?? 'Nothing playing',
      'artist': song?.artist ?? 'Unknown artist',
      'album': song?.album ?? 'Unknown album',
      'artUri': song?.artworkUrl,
      'isPlaying': isPlaying,
      'positionMs': position.inMilliseconds,
      'durationMs': duration.inMilliseconds > 0
          ? duration.inMilliseconds
          : (song?.durationMs ?? 0),
    });
  }

  static Future<void> stop() async {
    if (!isSupported) {
      return;
    }
    await _methodChannel.invokeMethod<void>('stopNotification');
  }

  static bool isToggleAction(String action) {
    return action == _actionPlayPause ||
        action == _actionPlay ||
        action == _actionPause;
  }

  static bool isNextAction(String action) => action == _actionNext;

  static bool isPreviousAction(String action) => action == _actionPrevious;
}
