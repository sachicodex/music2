import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'models.dart';

class MusicNotificationService extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  Future<void> Function()? onPlayPause;
  Future<void> Function()? onNext;
  Future<void> Function()? onPrevious;

  Duration _position = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  double _speed = 1.0;

  void updateFromState({
    required LibrarySong? song,
    required bool playing,
    required Duration position,
    required Duration duration,
  }) {
    _position = position;
    _bufferedPosition = position;
    _speed = 1.0;

    mediaItem.add(
      song == null
          ? null
          : MediaItem(
              id: song.id,
              title: song.title,
              artist: song.artist,
              album: song.album,
              duration: duration > Duration.zero ? duration : song.duration,
              artUri: _toUri(song.artworkUrl),
            ),
    );

    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: _position,
        bufferedPosition: _bufferedPosition,
        speed: _speed,
      ),
    );
  }

  Uri? _toUri(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return Uri.tryParse(value);
  }

  @override
  Future<void> play() async {
    await onPlayPause?.call();
  }

  @override
  Future<void> pause() async {
    await onPlayPause?.call();
  }

  @override
  Future<void> skipToNext() async {
    await onNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    await onPrevious?.call();
  }

  @override
  Future<void> stop() async {
    await super.stop();
  }
}
