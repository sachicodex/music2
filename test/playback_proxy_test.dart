import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:music/src/playback_proxy.dart';

void main() {
  test(
    'PlaybackProxyServer forwards bytes and reports transferred totals',
    () async {
      final List<int> payload = utf8.encode('outer-tune-low-bitrate-audio');
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
      final PlaybackProxyServer proxy = PlaybackProxyServer(
        onBytesTransferred: transfers.add,
      );

      try {
        final String proxyUrl = await proxy.register(
          sessionId: 'session-1',
          songId: 'song-1',
          upstreamUri: Uri.parse(
            'http://${upstream.address.address}:${upstream.port}/audio',
          ),
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
      } finally {
        await proxy.dispose();
        await upstream.close(force: true);
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
