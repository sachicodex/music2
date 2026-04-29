import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:musix/src/playback_proxy.dart';

void main() {
  test(
    'PlaybackProxyServer forwards bytes and reports transferred totals',
    () async {
      final List<int> payload = utf8.encode('musix-low-bitrate-audio');
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'playback-proxy-test-',
      );
      final String cachePath =
          '${tempDir.path}${Platform.pathSeparator}song.m4a';
      final HttpServer upstream = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      upstream.listen((HttpRequest request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'application',
          'octet-stream',
        );
        request.response.headers.contentLength = payload.length;
        request.response.add(payload);
        await request.response.close();
      });

      final List<PlaybackProxyTransfer> transfers = <PlaybackProxyTransfer>[];
      PlaybackProxyCacheResult? cacheResult;
      final PlaybackProxyServer proxy = PlaybackProxyServer(
        onBytesTransferred: transfers.add,
        onCacheCompleted: (PlaybackProxyCacheResult result) {
          cacheResult = result;
        },
      );

      try {
        final String proxyUrl = await proxy.register(
          sessionId: 'session-1',
          songId: 'song-1',
          upstreamUri: Uri.parse(
            'http://${upstream.address.address}:${upstream.port}/audio',
          ),
          cacheFilePath: cachePath,
          cacheEpoch: 7,
        );

        final HttpClient client = HttpClient();
        try {
          final HttpClientRequest request = await client.getUrl(
            Uri.parse(proxyUrl),
          );
          final HttpClientResponse response = await request.close();
          final List<int> proxiedPayload =
              await consolidateHttpClientResponseBytes(response);

          expect(response.statusCode, HttpStatus.ok);
          expect(proxiedPayload, payload);
        } finally {
          client.close(force: true);
        }

        final int totalBytes = transfers.fold<int>(
          0,
          (int sum, PlaybackProxyTransfer item) => sum + item.bytesTransferred,
        );
        expect(totalBytes, payload.length);
        expect(
          transfers.every(
            (PlaybackProxyTransfer item) => item.songId == 'song-1',
          ),
          isTrue,
        );
        for (
          int attempt = 0;
          attempt < 20 && cacheResult == null;
          attempt += 1
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        expect(cacheResult, isNotNull);
        expect(cacheResult!.songId, 'song-1');
        expect(cacheResult!.cacheEpoch, 7);
        expect(cacheResult!.cachedFilePath, cachePath);
        expect(await File(cachePath).readAsBytes(), payload);
      } finally {
        await proxy.dispose();
        await upstream.close(force: true);
        await tempDir.delete(recursive: true);
      }
    },
  );

  test(
    'PlaybackProxyServer avoids duplicate upstream download during cache write',
    () async {
      final List<int> payload = List<int>.generate(512 * 1024, (int i) => i % 251);
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'playback-proxy-dedupe-',
      );
      final String cachePath =
          '${tempDir.path}${Platform.pathSeparator}song.m4a';
      int upstreamRequestCount = 0;
      final HttpServer upstream = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      upstream.listen((HttpRequest request) async {
        upstreamRequestCount += 1;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'application',
          'octet-stream',
        );
        request.response.headers.contentLength = payload.length;
        for (int offset = 0; offset < payload.length; offset += 32 * 1024) {
          final int end = (offset + 32 * 1024).clamp(0, payload.length);
          request.response.add(payload.sublist(offset, end));
          await Future<void>.delayed(const Duration(milliseconds: 4));
        }
        await request.response.close();
      });

      final PlaybackProxyServer proxy = PlaybackProxyServer(
        onBytesTransferred: (_) {},
      );

      try {
        final String proxyUrl = await proxy.register(
          sessionId: 'session-2',
          songId: 'song-2',
          upstreamUri: Uri.parse(
            'http://${upstream.address.address}:${upstream.port}/audio',
          ),
          cacheFilePath: cachePath,
          cacheEpoch: 1,
        );

        final HttpClient firstClient = HttpClient();
        final HttpClient secondClient = HttpClient();
        try {
          final Future<List<int>> first = () async {
            final HttpClientRequest request = await firstClient.getUrl(
              Uri.parse(proxyUrl),
            );
            final HttpClientResponse response = await request.close();
            return consolidateHttpClientResponseBytes(response);
          }();
          await Future<void>.delayed(const Duration(milliseconds: 40));
          final Future<List<int>> second = () async {
            final HttpClientRequest request = await secondClient.getUrl(
              Uri.parse(proxyUrl),
            );
            final HttpClientResponse response = await request.close();
            return consolidateHttpClientResponseBytes(response);
          }();
          final List<List<int>> result = await Future.wait<List<int>>(
            <Future<List<int>>>[first, second],
          );
          expect(result[0], payload);
          expect(result[1], payload);
          expect(upstreamRequestCount, 1);
        } finally {
          firstClient.close(force: true);
          secondClient.close(force: true);
        }
      } finally {
        await proxy.dispose();
        await upstream.close(force: true);
        await tempDir.delete(recursive: true);
      }
    },
  );
}

Future<List<int>> consolidateHttpClientResponseBytes(
  HttpClientResponse response,
) async {
  final BytesBuilder builder = BytesBuilder(copy: false);
  await for (final List<int> chunk in response) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}
