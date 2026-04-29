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

class PlaybackProxyCacheProgress {
  const PlaybackProxyCacheProgress({
    required this.sessionId,
    required this.songId,
    required this.bytesWritten,
    this.expectedBytes,
  });

  final String sessionId;
  final String songId;
  final int bytesWritten;
  final int? expectedBytes;
}

typedef PlaybackProxyCacheProgressCallback =
    void Function(PlaybackProxyCacheProgress progress);

class PlaybackProxyCacheResult {
  const PlaybackProxyCacheResult({
    required this.sessionId,
    required this.songId,
    required this.cacheEpoch,
    required this.cachedFilePath,
  });

  final String sessionId;
  final String songId;
  final int cacheEpoch;
  final String cachedFilePath;
}

typedef PlaybackProxyCacheCompletedCallback =
    void Function(PlaybackProxyCacheResult result);

class PlaybackProxyServer {
  PlaybackProxyServer({
    required this.onBytesTransferred,
    this.onCacheProgress,
    this.onCacheCompleted,
  });

  final PlaybackProxyTransferCallback onBytesTransferred;
  final PlaybackProxyCacheProgressCallback? onCacheProgress;
  final PlaybackProxyCacheCompletedCallback? onCacheCompleted;
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
    String? cacheFilePath,
    int cacheEpoch = 0,
  }) async {
    await _ensureStarted();
    _sessions[sessionId] = _PlaybackProxySession(
      sessionId: sessionId,
      songId: songId,
      upstreamUri: upstreamUri,
      upstreamHeaders: upstreamHeaders,
      cacheFilePath: cacheFilePath,
      cacheEpoch: cacheEpoch,
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
      if (await _tryServeFromCompletedCache(incoming, session)) {
        return;
      }
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

      final _PlaybackProxyCachePlan? cachePlan = _createCachePlan(
        session: session,
        incoming: incoming,
        upstreamResponse: upstreamResponse,
      );
      IOSink? cacheSink;
      int cachedBytes = 0;
      if (cachePlan != null) {
        session.cacheWriteInProgress = true;
        await cachePlan.tempFile.parent.create(recursive: true);
        if (await cachePlan.tempFile.exists()) {
          await cachePlan.tempFile.delete();
        }
        cacheSink = cachePlan.tempFile.openWrite();
      }

      if (incoming.method.toUpperCase() == 'HEAD') {
        await incoming.response.close();
        return;
      }

      try {
        await for (final List<int> chunk in upstreamResponse) {
          incoming.response.add(chunk);
          if (cacheSink != null && chunk.isNotEmpty) {
            cacheSink.add(chunk);
            cachedBytes += chunk.length;
            onCacheProgress?.call(
              PlaybackProxyCacheProgress(
                sessionId: session.sessionId,
                songId: session.songId,
                bytesWritten: cachedBytes,
                expectedBytes: cachePlan?.expectedBytes,
              ),
            );
          }
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
        await _completeCacheWrite(
          session: session,
          plan: cachePlan,
          sink: cacheSink,
          bytesWritten: cachedBytes,
        );
      } catch (_) {
        await _discardCacheWrite(plan: cachePlan, sink: cacheSink);
        rethrow;
      }
    } catch (_) {
      try {
        incoming.response.statusCode = HttpStatus.badGateway;
      } catch (_) {}
      await incoming.response.close();
    }
  }

  Future<bool> _tryServeFromCompletedCache(
    HttpRequest incoming,
    _PlaybackProxySession session,
  ) async {
    final String? cachePath = session.cacheFilePath?.trim();
    if (cachePath == null || cachePath.isEmpty) {
      return false;
    }
    final String method = incoming.method.toUpperCase();
    if (method != 'GET' && method != 'HEAD') {
      return false;
    }
    final File cachedFile = File(cachePath);
    if (!await cachedFile.exists() &&
        session.cacheWriteInProgress &&
        !session.cacheCompleted) {
      final bool ready = await _waitForCacheFile(
        file: cachedFile,
        session: session,
      );
      if (!ready) {
        return false;
      }
    }
    if (!await cachedFile.exists()) {
      return false;
    }

    final int fileLength = await cachedFile.length();
    int start = 0;
    int end = fileLength > 0 ? fileLength - 1 : 0;
    int statusCode = HttpStatus.ok;
    final String? rangeHeader = incoming.headers.value(HttpHeaders.rangeHeader);
    final _ByteRange? parsedRange = _ByteRange.tryParse(rangeHeader);
    if (parsedRange != null && fileLength > 0) {
      final int? resolvedStart = parsedRange.start;
      final int? resolvedEnd = parsedRange.end;
      if (resolvedStart != null && resolvedStart >= fileLength) {
        incoming.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        incoming.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */$fileLength',
        );
        await incoming.response.close();
        return true;
      }
      if (resolvedStart == null && resolvedEnd != null) {
        final int suffixLength = resolvedEnd.clamp(0, fileLength);
        start = fileLength - suffixLength;
        end = fileLength - 1;
      } else {
        start = (resolvedStart ?? 0).clamp(0, fileLength - 1);
        end = (resolvedEnd ?? (fileLength - 1)).clamp(start, fileLength - 1);
      }
      statusCode = HttpStatus.partialContent;
    }

    final int length = fileLength == 0 ? 0 : (end - start + 1);
    incoming.response.statusCode = statusCode;
    incoming.response.headers.contentType = ContentType('audio', 'mp4');
    incoming.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (statusCode == HttpStatus.partialContent) {
      incoming.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$fileLength',
      );
    }
    incoming.response.headers.contentLength = length;

    if (method == 'HEAD' || fileLength == 0 || length <= 0) {
      await incoming.response.close();
      return true;
    }

    await incoming.response.addStream(cachedFile.openRead(start, end + 1));
    await incoming.response.close();
    onBytesTransferred(
      PlaybackProxyTransfer(
        sessionId: session.sessionId,
        songId: session.songId,
        bytesTransferred: length,
      ),
    );
    return true;
  }

  Future<bool> _waitForCacheFile({
    required File file,
    required _PlaybackProxySession session,
  }) async {
    const Duration step = Duration(milliseconds: 120);
    const int maxPolls = 250; // ~30 seconds
    for (int attempt = 0; attempt < maxPolls; attempt += 1) {
      if (await file.exists()) {
        return true;
      }
      if (!session.cacheWriteInProgress || session.cacheCompleted) {
        break;
      }
      await Future<void>.delayed(step);
    }
    return await file.exists();
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

  _PlaybackProxyCachePlan? _createCachePlan({
    required _PlaybackProxySession session,
    required HttpRequest incoming,
    required HttpClientResponse upstreamResponse,
  }) {
    if ((session.cacheFilePath?.trim().isEmpty ?? true) ||
        session.cacheCompleted ||
        session.cacheWriteInProgress ||
        incoming.method.toUpperCase() != 'GET') {
      return null;
    }

    final File targetFile = File(session.cacheFilePath!);
    final File tempFile = File('${targetFile.path}.part');
    final int statusCode = upstreamResponse.statusCode;

    if (statusCode == HttpStatus.ok) {
      return _PlaybackProxyCachePlan(
        sessionId: session.sessionId,
        targetFile: targetFile,
        tempFile: tempFile,
        expectedBytes: upstreamResponse.contentLength >= 0
            ? upstreamResponse.contentLength
            : null,
      );
    }

    if (statusCode != HttpStatus.partialContent) {
      return null;
    }

    final _ContentRangeHeader? contentRange = _ContentRangeHeader.tryParse(
      upstreamResponse.headers.value(HttpHeaders.contentRangeHeader),
    );
    if (contentRange == null ||
        contentRange.start != 0 ||
        contentRange.totalLength == null ||
        contentRange.end != contentRange.totalLength! - 1) {
      return null;
    }

    return _PlaybackProxyCachePlan(
      sessionId: session.sessionId,
      targetFile: targetFile,
      tempFile: tempFile,
      expectedBytes: upstreamResponse.contentLength >= 0
          ? upstreamResponse.contentLength
          : contentRange.totalLength,
    );
  }

  Future<void> _completeCacheWrite({
    required _PlaybackProxySession session,
    required _PlaybackProxyCachePlan? plan,
    required IOSink? sink,
    required int bytesWritten,
  }) async {
    if (plan == null) {
      return;
    }

    try {
      await sink?.close();
      final int? expectedBytes = plan.expectedBytes;
      final bool complete =
          bytesWritten > 0 &&
          (expectedBytes == null || expectedBytes == bytesWritten);
      if (!complete) {
        await _deleteIfExists(plan.tempFile);
        return;
      }
      if (await plan.targetFile.exists()) {
        await plan.targetFile.delete();
      }
      await plan.tempFile.rename(plan.targetFile.path);
      session.cacheCompleted = true;
      onCacheCompleted?.call(
        PlaybackProxyCacheResult(
          sessionId: session.sessionId,
          songId: session.songId,
          cacheEpoch: session.cacheEpoch,
          cachedFilePath: plan.targetFile.path,
        ),
      );
    } finally {
      session.cacheWriteInProgress = false;
    }
  }

  Future<void> _discardCacheWrite({
    required _PlaybackProxyCachePlan? plan,
    required IOSink? sink,
  }) async {
    if (plan == null) {
      return;
    }
    try {
      await sink?.close();
    } catch (_) {}
    await _deleteIfExists(plan.tempFile);
    final _PlaybackProxySession? session = _sessions[plan.sessionId];
    session?.cacheWriteInProgress = false;
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class _PlaybackProxySession {
  _PlaybackProxySession({
    required this.sessionId,
    required this.songId,
    required this.upstreamUri,
    this.upstreamHeaders,
    this.cacheFilePath,
    required this.cacheEpoch,
  });

  final String sessionId;
  final String songId;
  final Uri upstreamUri;
  final Map<String, String>? upstreamHeaders;
  final String? cacheFilePath;
  final int cacheEpoch;
  bool cacheCompleted = false;
  bool cacheWriteInProgress = false;
}

class _PlaybackProxyCachePlan {
  const _PlaybackProxyCachePlan({
    required this.sessionId,
    required this.targetFile,
    required this.tempFile,
    required this.expectedBytes,
  });

  final String sessionId;
  final File targetFile;
  final File tempFile;
  final int? expectedBytes;
}

class _ContentRangeHeader {
  const _ContentRangeHeader({
    required this.start,
    required this.end,
    required this.totalLength,
  });

  final int start;
  final int end;
  final int? totalLength;

  static final RegExp _pattern = RegExp(
    r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$',
    caseSensitive: false,
  );

  static _ContentRangeHeader? tryParse(String? value) {
    if (value == null) {
      return null;
    }
    final RegExpMatch? match = _pattern.firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    return _ContentRangeHeader(
      start: int.parse(match.group(1)!),
      end: int.parse(match.group(2)!),
      totalLength: match.group(3) == '*' ? null : int.parse(match.group(3)!),
    );
  }
}

class _ByteRange {
  const _ByteRange({this.start, this.end});

  final int? start;
  final int? end;

  static final RegExp _pattern = RegExp(r'^bytes=(\d*)-(\d*)$');

  static _ByteRange? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final RegExpMatch? match = _pattern.firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final String startPart = match.group(1) ?? '';
    final String endPart = match.group(2) ?? '';
    if (startPart.isEmpty && endPart.isEmpty) {
      return null;
    }
    return _ByteRange(
      start: startPart.isEmpty ? null : int.tryParse(startPart),
      end: endPart.isEmpty ? null : int.tryParse(endPart),
    );
  }
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
