import 'package:flutter_test/flutter_test.dart';

import 'package:music/src/models.dart';
import 'package:music/src/streaming.dart';

void main() {
  group('resolvePreferredPlaybackStream', () {
    test('prefers lowest bitrate audio-only before muxed and hls', () {
      final PlaybackStreamResolution resolved = resolvePreferredPlaybackStream(
        songId: 'song-1',
        sourceLabel: 'YouTube Music',
        originalUrl: 'https://music.youtube.com/watch?v=abc',
        candidates: const <PlaybackStreamCandidate>[
          PlaybackStreamCandidate(
            transport: PlaybackStreamTransport.muxed,
            url: 'https://example.com/muxed-high',
            bitrateBitsPerSecond: 256000,
            qualityLabel: '360p',
          ),
          PlaybackStreamCandidate(
            transport: PlaybackStreamTransport.audioOnly,
            url: 'https://example.com/audio-mid',
            bitrateBitsPerSecond: 96000,
            qualityLabel: 'medium',
          ),
          PlaybackStreamCandidate(
            transport: PlaybackStreamTransport.audioOnly,
            url: 'https://example.com/audio-low',
            bitrateBitsPerSecond: 48000,
            qualityLabel: 'low',
          ),
          PlaybackStreamCandidate(
            transport: PlaybackStreamTransport.hlsMuxed,
            url: 'https://example.com/hls',
            bitrateBitsPerSecond: 128000,
            qualityLabel: 'hls',
          ),
        ],
      );

      expect(resolved.url, 'https://example.com/audio-low');
      expect(resolved.info.transport, PlaybackStreamTransport.audioOnly);
      expect(resolved.info.bitrateBitsPerSecond, 48000);
      expect(resolved.info.selectionPolicy, 'lowest-bitrate-audio-first');
      expect(resolved.info.availableAudioOnlyCount, 2);
      expect(resolved.info.availableMuxedCount, 1);
      expect(resolved.info.availableHlsMuxedCount, 1);
    });

    test(
      'falls back to lowest bitrate muxed when audio-only is unavailable',
      () {
        final PlaybackStreamResolution resolved =
            resolvePreferredPlaybackStream(
              songId: 'song-2',
              sourceLabel: 'YouTube',
              originalUrl: 'https://www.youtube.com/watch?v=def',
              candidates: const <PlaybackStreamCandidate>[
                PlaybackStreamCandidate(
                  transport: PlaybackStreamTransport.muxed,
                  url: 'https://example.com/muxed-low',
                  bitrateBitsPerSecond: 64000,
                ),
                PlaybackStreamCandidate(
                  transport: PlaybackStreamTransport.muxed,
                  url: 'https://example.com/muxed-high',
                  bitrateBitsPerSecond: 192000,
                ),
                PlaybackStreamCandidate(
                  transport: PlaybackStreamTransport.hlsMuxed,
                  url: 'https://example.com/hls-muxed',
                  bitrateBitsPerSecond: 128000,
                ),
              ],
            );

        expect(resolved.url, 'https://example.com/muxed-low');
        expect(resolved.info.transport, PlaybackStreamTransport.muxed);
        expect(resolved.info.bitrateBitsPerSecond, 64000);
      },
    );

    test(
      'prefers the lowest muxed resolution before bitrate when video fallback is needed',
      () {
        final PlaybackStreamResolution resolved =
            resolvePreferredPlaybackStream(
              songId: 'song-2b',
              sourceLabel: 'YouTube',
              originalUrl: 'https://www.youtube.com/watch?v=ghi',
              candidates: const <PlaybackStreamCandidate>[
                PlaybackStreamCandidate(
                  transport: PlaybackStreamTransport.muxed,
                  url: 'https://example.com/muxed-360p',
                  bitrateBitsPerSecond: 64000,
                  qualityLabel: '360p',
                  videoHeight: 360,
                ),
                PlaybackStreamCandidate(
                  transport: PlaybackStreamTransport.muxed,
                  url: 'https://example.com/muxed-144p',
                  bitrateBitsPerSecond: 96000,
                  qualityLabel: '144p',
                  videoHeight: 144,
                ),
                PlaybackStreamCandidate(
                  transport: PlaybackStreamTransport.muxed,
                  url: 'https://example.com/muxed-240p',
                  bitrateBitsPerSecond: 80000,
                  qualityLabel: '240p',
                  videoHeight: 240,
                ),
              ],
            );

        expect(resolved.url, 'https://example.com/muxed-144p');
        expect(resolved.info.transport, PlaybackStreamTransport.muxed);
        expect(resolved.info.qualityLabel, '144p');
      },
    );

    test('nextPlaybackFallbackIndex skips the broken audio-only group', () {
      final List<PlaybackStreamCandidate> ranked =
          rankPlaybackStreamCandidates(const <PlaybackStreamCandidate>[
            PlaybackStreamCandidate(
              transport: PlaybackStreamTransport.audioOnly,
              url: 'https://example.com/audio-low',
              bitrateBitsPerSecond: 32000,
            ),
            PlaybackStreamCandidate(
              transport: PlaybackStreamTransport.audioOnly,
              url: 'https://example.com/audio-mid',
              bitrateBitsPerSecond: 64000,
            ),
            PlaybackStreamCandidate(
              transport: PlaybackStreamTransport.muxed,
              url: 'https://example.com/muxed-low',
              bitrateBitsPerSecond: 96000,
            ),
          ]);

      expect(nextPlaybackFallbackIndex(ranked, 0), 2);
    });
  });

  group('AppDataUsageStats', () {
    test('serializes and formats usage totals', () {
      final AppDataUsageStats usage = AppDataUsageStats(
        totalBytes: 45875200,
        streamBytes: 31457280,
        cacheBytes: 10485760,
        searchBytes: 1048576,
        loadBytes: 2097152,
        artworkBytes: 524288,
        metadataBytes: 262144,
        currentSongBytes: 5242880,
        currentSongId: 'song-1',
        lastUpdatedAt: DateTime(2026, 4, 23, 14, 24),
      );

      final AppDataUsageStats roundTrip = AppDataUsageStats.fromJson(
        usage.toJson(),
      );

      expect(roundTrip, usage);
      expect(roundTrip.totalLabel, '43.8 MB');
      expect(roundTrip.streamLabel, '30 MB');
      expect(roundTrip.cacheLabel, '10 MB');
      expect(roundTrip.otherLabel, '3.8 MB');
      expect(roundTrip.searchLabel, '1 MB');
      expect(roundTrip.loadLabel, '2 MB');
      expect(roundTrip.artworkLabel, '512 KB');
      expect(roundTrip.metadataLabel, '256 KB');
      expect(roundTrip.currentSongLabel, '5 MB');
      expect(formatDataSize(512), '512 B');
    });
  });
}
