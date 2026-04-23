import 'dart:async';
import 'dart:io';

class PlaybackProxyTransfer {
  const PlaybackProxyTransfer({
    required this.sessionId,
    required this.songId,
    required this.bytesTransferred,
  });

  final String sessionId;
  final String songId;
  final int bytesTransferred;
}

typedef PlaybackProxyTransferCallback =
    void Function(PlaybackProxyTransfer transfer);

class PlaybackProxyServer {
  PlaybackProxyServer({required this.onBytesTransferred});

  final PlaybackProxyTransferCallback onBytesTransferred;
  final HttpClient _client = HttpClient();
  final Map<String, _PlaybackProxySession> _sessions =
      <String, _PlaybackProxySession>{};
  HttpServer? _server;
  Future<void>? _starting;

  Future<String> register({
    required String sessionId,
    required String songId,
    required Uri upstreamUri,
    Map<String, String>? upstreamHeaders,
  }) async {
    await _ensureStarted();
    _sessions[sessionId] = _PlaybackProxySession(
      sessionId: sessionId,
      songId: songId,
      upstreamUri: upstreamUri,
      upstreamHeaders: upstreamHeaders,
    );
    final HttpServer server = _server!;
    return 'http://${server.address.address}:${server.port}/$sessionId';
  }

  Future<void> unregister(String sessionId) async {
    _sessions.remove(sessionId);
  }

  Future<void> dispose() async {
    _sessions.clear();
    _client.close(force: true);
    final HttpServer? server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<void> _ensureStarted() async {
    final HttpServer? existing = _server;
    if (existing != null) {
      return;
    }
    if (_starting != null) {
      await _starting;
      return;
    }

    final Completer<void> completer = Completer<void>();
    _starting = completer.future;
    try {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      server.listen(_handleRequest);
      _server = server;
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _starting = null;
    }
  }

  Future<void> _handleRequest(HttpRequest incoming) async {
    final String sessionId = incoming.uri.pathSegments.firstOrNull ?? '';
    final _PlaybackProxySession? session = _sessions[sessionId];
    if (session == null) {
      incoming.response.statusCode = HttpStatus.notFound;
      await incoming.response.close();
      return;
    }

    try {
      final HttpClientRequest upstream = await _client.openUrl(
        incoming.method,
        session.upstreamUri,
      );
      _copyRequestHeaders(
        from: incoming.headers,
        to: upstream.headers,
        overrides: session.upstreamHeaders,
      );
      final HttpClientResponse upstreamResponse = await upstream.close();

      incoming.response.statusCode = upstreamResponse.statusCode;
      _copyResponseHeaders(
        from: upstreamResponse.headers,
        to: incoming.response.headers,
      );

      if (incoming.method.toUpperCase() == 'HEAD') {
        await incoming.response.close();
        return;
      }

      await for (final List<int> chunk in upstreamResponse) {
        incoming.response.add(chunk);
        if (chunk.isNotEmpty) {
          onBytesTransferred(
            PlaybackProxyTransfer(
              sessionId: session.sessionId,
              songId: session.songId,
              bytesTransferred: chunk.length,
            ),
          );
        }
      }
      await incoming.response.close();
    } catch (_) {
      try {
        incoming.response.statusCode = HttpStatus.badGateway;
      } catch (_) {}
      await incoming.response.close();
    }
  }

  void _copyRequestHeaders({
    required HttpHeaders from,
    required HttpHeaders to,
    Map<String, String>? overrides,
  }) {
    const Set<String> blocked = <String>{
      'connection',
      'content-length',
      'host',
      'transfer-encoding',
    };

    from.forEach((String name, List<String> values) {
      if (blocked.contains(name.toLowerCase())) {
        return;
      }
      for (final String value in values) {
        to.add(name, value);
      }
    });

    overrides?.forEach((String name, String value) {
      to.set(name, value);
    });
  }

  void _copyResponseHeaders({
    required HttpHeaders from,
    required HttpHeaders to,
  }) {
    const Set<String> blocked = <String>{
      'connection',
      'content-length',
      'transfer-encoding',
    };

    from.forEach((String name, List<String> values) {
      if (blocked.contains(name.toLowerCase())) {
        return;
      }
      for (final String value in values) {
        to.add(name, value);
      }
    });

    final int contentLength = from.contentLength;
    if (contentLength >= 0) {
      to.contentLength = contentLength;
      to.chunkedTransferEncoding = false;
    }
  }
}

class _PlaybackProxySession {
  const _PlaybackProxySession({
    required this.sessionId,
    required this.songId,
    required this.upstreamUri,
    this.upstreamHeaders,
  });

  final String sessionId;
  final String songId;
  final Uri upstreamUri;
  final Map<String, String>? upstreamHeaders;
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
