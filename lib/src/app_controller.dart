import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
import 'package:ytmusicapi_dart/auth/browser.dart' as ytm_browser;
import 'package:ytmusicapi_dart/ytmusicapi_dart.dart';
import 'package:ytmusicapi_dart/enums.dart' as ytm;

import 'models.dart';

class OuterTuneController extends ChangeNotifier {
  OuterTuneController() : _player = Player(), _yt = YoutubeExplode();
  static const int _smartQueueBatchSize = 10;

  static const List<String> supportedExtensions = <String>[
    'mp3',
    'flac',
    'ogg',
    'wav',
    'm4a',
    'aac',
    'opus',
    'wma',
    'aiff',
    'alac',
  ];

  final Player _player;
  final YoutubeExplode _yt;
  YTMusic? _ytMusic;
  final Uuid _uuid = const Uuid();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  final Map<String, LibrarySong> _transientSongsById = <String, LibrarySong>{};
  bool _isDisposing = false;
  bool _isDisposed = false;

  bool _initialized = false;
  bool _scanning = false;
  bool _onlineLoading = false;
  bool _homeLoading = false;
  bool _smartQueueLoading = false;
  String? _statusMessage;
  String? _errorMessage;
  String? _onlineError;
  String? _homeError;
  String? _ytMusicAuthError;
  String _onlineQuery = '';
  int _onlineResultLimit = 0;
  bool _onlineHasMore = false;
  int _onlineSearchRequestId = 0;

  AppSettings _settings = const AppSettings();
  List<String> _sources = <String>[];
  List<LibrarySong> _songs = <LibrarySong>[];
  List<UserPlaylist> _playlists = <UserPlaylist>[];
  List<PlaybackEntry> _history = <PlaybackEntry>[];
  List<LibrarySong> _onlineResults = <LibrarySong>[];
  List<HomeFeedSection> _homeFeed = <HomeFeedSection>[];
  int _homeQueryCursor = 0;
  final Set<String> _homeConsumedIdentityKeys = <String>{};
  final Set<String> _homeConsumedIds = <String>{};
  final Map<String, List<LibrarySong>> _searchCache =
      <String, List<LibrarySong>>{};
  final Map<String, List<LibrarySong>> _ytMusicSearchCache =
      <String, List<LibrarySong>>{};
  final Map<String, String?> _ytMusicVideoIdCache = <String, String?>{};
  final Set<String> _smartQueueSongIds = <String>{};
  String? _activePlaybackSongId;
  double _activePlaybackCompletionRatio = 0;

  List<String> _queueSongIds = <String>[];
  String _queueLabel = 'Now Playing';
  int _queueIndex = 0;
  bool _isPlaying = false;
  bool _isShuffleEnabled = false;
  PlaylistMode _repeatMode = PlaylistMode.none;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String? _lastTrackedSongId;

  bool get initialized => _initialized;
  bool get scanning => _scanning;
  bool get onlineLoading => _onlineLoading;
  bool get homeLoading => _homeLoading;
  bool get smartQueueLoading => _smartQueueLoading;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  String? get onlineError => _onlineError;
  String? get homeError => _homeError;
  String? get ytMusicAuthError => _ytMusicAuthError;
  bool get onlineHasMore => _onlineHasMore;
  String get onlineQuery => _onlineQuery;
  AppSettings get settings => _settings;
  Player get player => _player;
  bool get isPlaying => _isPlaying;
  bool get isShuffleEnabled => _isShuffleEnabled;
  PlaylistMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  List<String> get sources => List<String>.unmodifiable(_sources);
  List<LibrarySong> get songs => List<LibrarySong>.unmodifiable(_songs);
  List<LibrarySong> get onlineResults =>
      List<LibrarySong>.unmodifiable(_onlineResults);
  List<HomeFeedSection> get homeFeed =>
      List<HomeFeedSection>.unmodifiable(_homeFeed);
  List<UserPlaylist> get playlists =>
      List<UserPlaylist>.unmodifiable(_playlists);
  List<PlaybackEntry> get history => List<PlaybackEntry>.unmodifiable(_history);
  String get queueLabel => _queueLabel;
  int get queueIndex => _queueIndex;
  bool get hasHomeRecommendations => _homeFeed.isNotEmpty;
  bool get hasYtMusicAuth =>
      (_settings.ytMusicAuthJson?.trim().isNotEmpty ?? false);

  List<LibrarySong> get queueSongs => _queueSongIds
      .map(songById)
      .whereType<LibrarySong>()
      .toList(growable: false);

  LibrarySong? get currentSong {
    if (_queueSongIds.isEmpty ||
        _queueIndex < 0 ||
        _queueIndex >= _queueSongIds.length) {
      return null;
    }
    return songById(_queueSongIds[_queueIndex]);
  }

  bool isSmartQueueSong(String songId) => _smartQueueSongIds.contains(songId);

  Future<void> extendSmartQueueIfNeeded({LibrarySong? seed}) async {
    await _maybeExtendSmartQueue(seed: seed);
  }

  Future<void> appendSmartQueue({
    LibrarySong? seed,
    int batchSize = 10,
    bool force = false,
  }) async {
    if ((!_settings.smartQueueEnabled && !force) || _smartQueueLoading) {
      return;
    }

    final LibrarySong? anchor = seed ?? queueSongs.lastOrNull ?? currentSong;
    if (anchor == null) {
      return;
    }

    await _appendSmartQueuePredictions(anchor, limit: batchSize);
  }

  List<LibrarySong> get recentlyAddedSongs {
    final List<LibrarySong> result = List<LibrarySong>.from(_songs);
    result.sort(
      (LibrarySong a, LibrarySong b) => b.addedAt.compareTo(a.addedAt),
    );
    return result;
  }

  List<LibrarySong> get favoriteSongs {
    final List<LibrarySong> result = _songs
        .where((LibrarySong song) => song.isFavorite)
        .toList();
    result.sort(
      (LibrarySong a, LibrarySong b) => b.playCount.compareTo(a.playCount),
    );
    return result;
  }

  List<LibrarySong> get topPlayedSongs {
    final List<LibrarySong> result = List<LibrarySong>.from(_songs);
    result.sort((LibrarySong a, LibrarySong b) {
      final int countCompare = b.playCount.compareTo(a.playCount);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return result;
  }

  List<LibrarySong> get recentlyPlayedSongs {
    final Set<String> seen = <String>{};
    final List<LibrarySong> result = <LibrarySong>[];
    for (final PlaybackEntry entry in _history) {
      if (seen.add(entry.songId)) {
        final LibrarySong? song = songById(entry.songId);
        if (song != null) {
          result.add(song);
        }
      }
    }
    return result;
  }

  List<PlaybackEntry> get validPlaybackHistory => _history
      .where(
        (PlaybackEntry entry) =>
            entry.listenedToEnd || entry.completionRatio >= 0.88,
      )
      .toList(growable: false);

  List<AlbumCollection> get albums {
    final Map<String, List<LibrarySong>> grouped =
        <String, List<LibrarySong>>{};
    for (final LibrarySong song in _songs) {
      final String key =
          '${song.album.trim().toLowerCase()}::${song.albumArtist.trim().toLowerCase()}';
      grouped.putIfAbsent(key, () => <LibrarySong>[]).add(song);
    }

    final List<AlbumCollection> result = grouped.entries.map((
      MapEntry<String, List<LibrarySong>> entry,
    ) {
      final List<LibrarySong> sortedSongs = List<LibrarySong>.from(entry.value)
        ..sort((LibrarySong a, LibrarySong b) {
          final int discCompare = (a.discNumber ?? 0).compareTo(
            b.discNumber ?? 0,
          );
          if (discCompare != 0) {
            return discCompare;
          }
          final int trackCompare = (a.trackNumber ?? 0).compareTo(
            b.trackNumber ?? 0,
          );
          if (trackCompare != 0) {
            return trackCompare;
          }
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      final LibrarySong leadSong = sortedSongs.first;
      return AlbumCollection(
        id: entry.key,
        title: leadSong.album,
        artist: leadSong.albumArtist,
        songs: sortedSongs,
      );
    }).toList();

    result.sort((AlbumCollection a, AlbumCollection b) {
      final int playCompare = b.totalPlays.compareTo(a.totalPlays);
      if (playCompare != 0) {
        return playCompare;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return result;
  }

  List<ArtistCollection> get artists {
    final Map<String, List<LibrarySong>> grouped =
        <String, List<LibrarySong>>{};
    for (final LibrarySong song in _songs) {
      final String key = song.artist.trim().toLowerCase();
      grouped.putIfAbsent(key, () => <LibrarySong>[]).add(song);
    }

    final List<ArtistCollection> result = grouped.entries
        .map(
          (MapEntry<String, List<LibrarySong>> entry) => ArtistCollection(
            id: entry.key,
            name: entry.value.first.artist,
            songs: List<LibrarySong>.from(entry.value)
              ..sort((LibrarySong a, LibrarySong b) {
                return a.title.toLowerCase().compareTo(b.title.toLowerCase());
              }),
          ),
        )
        .toList();

    result.sort((ArtistCollection a, ArtistCollection b) {
      final int playCompare = b.totalPlays.compareTo(a.totalPlays);
      if (playCompare != 0) {
        return playCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  List<FolderCollection> get folders {
    final Map<String, List<LibrarySong>> grouped =
        <String, List<LibrarySong>>{};
    for (final LibrarySong song in _songs) {
      grouped.putIfAbsent(song.folderPath, () => <LibrarySong>[]).add(song);
    }

    final List<FolderCollection> result = grouped.entries
        .map(
          (MapEntry<String, List<LibrarySong>> entry) => FolderCollection(
            id: entry.key,
            name: entry.value.first.folderName,
            path: entry.key,
            songs: List<LibrarySong>.from(entry.value)
              ..sort((LibrarySong a, LibrarySong b) {
                return a.title.toLowerCase().compareTo(b.title.toLowerCase());
              }),
          ),
        )
        .toList();

    result.sort(
      (FolderCollection a, FolderCollection b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return result;
  }

  Future<void> initialize() async {
    await _loadSnapshot();
    await _recreateYtMusicClient();
    await _player.setRate(_settings.playbackRate);
    _attachPlayerListeners();
    _initialized = true;
    notifyListeners();
    unawaited(refreshHomeFeed());
  }

  Future<void> searchOnline(String query) async {
    final int requestId = ++_onlineSearchRequestId;
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      _onlineResults = <LibrarySong>[];
      _onlineError = null;
      _onlineLoading = false;
      _onlineQuery = '';
      _onlineResultLimit = 0;
      _onlineHasMore = false;
      notifyListeners();
      return;
    }

    await _performOnlineSearch(trimmed, limit: 20, requestId: requestId);
  }

  Future<void> loadMoreOnlineResults() async {
    if (_onlineLoading || _onlineQuery.isEmpty || !_onlineHasMore) {
      return;
    }
    await _performOnlineSearch(
      _onlineQuery,
      limit: _onlineResultLimit + 20,
      requestId: _onlineSearchRequestId,
    );
  }

  Future<void> _performOnlineSearch(
    String query, {
    required int limit,
    required int requestId,
  }) async {
    _onlineLoading = true;
    _onlineError = null;
    _onlineQuery = query;
    notifyListeners();

    try {
      final List<LibrarySong> results = await _searchSongs(
        query,
        limit: limit,
        force: true,
      );
      if (requestId != _onlineSearchRequestId) {
        return;
      }
      _onlineResults = results;
      _onlineResultLimit = limit;
      _onlineHasMore = _onlineResults.length >= limit;
      if (_onlineResults.isEmpty) {
        _onlineError = 'No online songs found right now.';
      }
    } catch (error) {
      if (requestId != _onlineSearchRequestId) {
        return;
      }
      _onlineError = _friendlyOnlineError(error);
      _onlineResults = <LibrarySong>[];
      _onlineResultLimit = 0;
      _onlineHasMore = false;
    } finally {
      if (requestId != _onlineSearchRequestId) {
        return;
      }
      _onlineLoading = false;
      notifyListeners();
    }
  }

  void clearOnlineResults() {
    _onlineResults = <LibrarySong>[];
    _onlineError = null;
    _onlineLoading = false;
    _onlineQuery = '';
    _onlineResultLimit = 0;
    _onlineHasMore = false;
    notifyListeners();
  }

  static const double _ytMusicPrimaryRatio = 0.8;
  static const double _youtubeFallbackRatio = 0.1;

  Future<void> _recreateYtMusicClient() async {
    _ytMusic?.close();
    final String? auth = _settings.ytMusicAuthJson?.trim();
    try {
      _ytMusic = await YTMusic.create(
        auth: auth == null || auth.isEmpty ? null : auth,
      );
      _ytMusicAuthError = null;
    } catch (error) {
      _ytMusicAuthError = '$error';
      _ytMusic = await YTMusic.create();
    }
  }

  Future<void> refreshHomeFeed({bool force = false}) async {
    if (_homeLoading) {
      return;
    }

    _homeLoading = true;
    _homeError = null;
    notifyListeners();

    try {
      final List<HomeFeedSection> previousFeed = List<HomeFeedSection>.from(
        _homeFeed,
      );
      final LibrarySong? seedSong = _primaryRecommendationSeed();
      final List<HomeFeedSection> sections = <HomeFeedSection>[];
      final Set<String> consumedIds = <String>{};
      final Set<String> consumedKeys = <String>{};

      final HomeFeedSection? focusSection = await _buildFocusHomeSection(
        excludedIds: consumedIds,
      );
      if (focusSection != null) {
        sections.add(focusSection);
        _publishHomeFeedProgress(sections);
        consumedIds.addAll(
          focusSection.songs.take(4).map((LibrarySong song) => song.id),
        );
        consumedKeys.addAll(
          focusSection.songs
              .take(8)
              .map((LibrarySong song) => _songIdentityKey(song)),
        );
      }

      if (seedSong != null) {
        final HomeFeedSection? radioSection = await _buildYtMusicRadioSection(
          seedSong,
          excludedIds: consumedIds,
        );
        if (radioSection != null) {
          sections.add(radioSection);
          _publishHomeFeedProgress(sections);
          consumedIds.addAll(
            radioSection.songs.take(4).map((LibrarySong song) => song.id),
          );
          consumedKeys.addAll(
            radioSection.songs
                .take(8)
                .map((LibrarySong song) => _songIdentityKey(song)),
          );
        }
      }

      final List<HomeFeedSection> ytmHomeSections =
          await _buildYtMusicHomeSections(excludedIds: consumedIds);
      for (final HomeFeedSection section in ytmHomeSections) {
        sections.add(section);
        _publishHomeFeedProgress(sections);
        consumedIds.addAll(
          section.songs.take(4).map((LibrarySong song) => song.id),
        );
        consumedKeys.addAll(
          section.songs
              .take(8)
              .map((LibrarySong song) => _songIdentityKey(song)),
        );
        if (sections.length >= 4) {
          break;
        }
      }

      _homeQueryCursor = 0;
      _homeConsumedIds
        ..clear()
        ..addAll(consumedIds);
      _homeConsumedIdentityKeys
        ..clear()
        ..addAll(consumedKeys);

      final List<HomeFeedSection> expanded = await _loadMoreHomeSections(
        seedSong: seedSong,
        force: force,
        already: sections,
        desiredCount: 6,
        onProgress: _publishHomeFeedProgress,
      );

      _homeFeed = expanded;
      if (_homeFeed.isEmpty) {
        _homeFeed = previousFeed;
        _homeError = previousFeed.isEmpty
            ? 'No recommendations available right now.'
            : 'Recommendations could not be refreshed right now.';
      }
    } catch (error) {
      _homeError = _friendlyOnlineError(error);
    } finally {
      _homeLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreHomeFeed({int desiredTotal = 10}) async {
    if (_homeLoading) {
      return;
    }
    if (_homeFeed.isEmpty) {
      await refreshHomeFeed();
      return;
    }

    _homeLoading = true;
    _homeError = null;
    notifyListeners();

    try {
      final LibrarySong? seedSong = _primaryRecommendationSeed();
      _homeFeed = await _loadMoreHomeSections(
        seedSong: seedSong,
        force: false,
        already: List<HomeFeedSection>.from(_homeFeed),
        desiredCount: desiredTotal,
        onProgress: _publishHomeFeedProgress,
      );
    } catch (error) {
      _homeError = _friendlyOnlineError(error);
    } finally {
      _homeLoading = false;
      notifyListeners();
    }
  }

  Future<List<HomeFeedSection>> _loadMoreHomeSections({
    required LibrarySong? seedSong,
    required bool force,
    required List<HomeFeedSection> already,
    required int desiredCount,
    void Function(List<HomeFeedSection> sections)? onProgress,
  }) async {
    final List<HomeFeedSection> sections = already;
    if (sections.length >= desiredCount) {
      return sections;
    }

    final List<_RecommendationQuery> queries = _buildHomeQueries(seedSong);
    if (queries.isEmpty) {
      return sections;
    }

    int cursor = _homeQueryCursor;
    bool recycledQueries = cursor >= queries.length;
    cursor = cursor % queries.length;
    int attempts = 0;
    final int maxAttempts = queries.length * 2;

    while (sections.length < desiredCount && attempts < maxAttempts) {
      final _RecommendationQuery query = queries[cursor];
      attempts += 1;
      cursor += 1;
      if (cursor >= queries.length) {
        cursor = 0;
        recycledQueries = true;
      }

      final List<LibrarySong> rawResults = await _searchSongs(
        query.query,
        limit: 22,
        force: force || recycledQueries,
      );
      final List<LibrarySong> ranked = _rankRecommendedSongs(
        rawResults,
        anchor: query.anchor ?? seedSong,
        excludedIds: _homeConsumedIds,
        limit: 14,
      );

      final List<LibrarySong> filtered = <LibrarySong>[
        for (final LibrarySong song in ranked)
          if (_homeConsumedIdentityKeys.add(_songIdentityKey(song)))
            if (_homeConsumedIds.add(song.id)) song,
      ];

      if (filtered.length < 4) {
        continue;
      }

      sections.add(
        HomeFeedSection(
          title: query.title,
          subtitle: query.subtitle,
          query: query.query,
          songs: filtered.take(10).toList(growable: false),
        ),
      );
      onProgress?.call(sections);
    }

    _homeQueryCursor = recycledQueries ? cursor + queries.length : cursor;
    return sections;
  }

  void _publishHomeFeedProgress(List<HomeFeedSection> sections) {
    _homeFeed = List<HomeFeedSection>.from(sections);
    notifyListeners();
  }

  Future<List<LibrarySong>> _searchSongs(
    String query, {
    int limit = 12,
    bool force = false,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return <LibrarySong>[];
    }

    final String cacheKey = trimmed.toLowerCase();
    if (!force && _searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    try {
      final List<LibrarySong> songs = await _searchOnlineMusic(
        trimmed,
        limit: limit,
        force: force,
      );
      _searchCache[cacheKey] = songs;
      return songs;
    } catch (_) {
      final List<LibrarySong> fallback = await _searchYouTubeMusicOnly(
        trimmed,
        limit: limit,
        force: force,
      );
      _searchCache[cacheKey] = fallback;
      return fallback;
    }
  }

  Future<List<LibrarySong>> _searchOnlineMusic(
    String query, {
    int limit = 12,
    bool force = false,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty || limit <= 0) {
      return <LibrarySong>[];
    }

    final int ytMusicTarget = math.max(
      1,
      math.min(limit, (limit * _ytMusicPrimaryRatio).round()),
    );
    final int youtubeTarget = math.min(
      math.max(0, (limit * _youtubeFallbackRatio).ceil()),
      math.max(0, limit - ytMusicTarget),
    );

    final List<LibrarySong> ytMusicSongs = await _searchYouTubeMusicOnly(
      trimmed,
      limit: math.max(limit, ytMusicTarget + 4),
      force: force,
    );

    final List<LibrarySong> youtubeSongs = ytMusicSongs.length >= limit
        ? <LibrarySong>[]
        : await _searchYouTubeFallbackOnly(
            trimmed,
            limit: math.max(youtubeTarget + 4, limit ~/ 2),
            force: force,
          );

    final List<LibrarySong> blended = _blendOnlineResults(
      query: trimmed,
      ytMusicSongs: ytMusicSongs,
      youtubeSongs: youtubeSongs,
      limit: limit,
      preferredYtMusicCount: ytMusicTarget,
      preferredYoutubeCount: youtubeTarget,
    );

    for (final LibrarySong song in blended) {
      _rememberTransientSong(song);
    }
    return blended;
  }

  Future<List<LibrarySong>> _searchYouTubeMusicOnly(
    String query, {
    int limit = 12,
    bool force = false,
  }) async {
    final YTMusic? client = _ytMusic;
    final String trimmed = query.trim();
    if (client == null || trimmed.isEmpty) {
      return <LibrarySong>[];
    }

    final String cacheKey = trimmed.toLowerCase();
    if (!force && _ytMusicSearchCache.containsKey(cacheKey)) {
      return _ytMusicSearchCache[cacheKey]!;
    }

    try {
      final List<dynamic> songResults = await client.search(
        trimmed,
        filter: ytm.SearchFilter.songs,
        limit: math.max(limit, 8),
      );
      final List<LibrarySong> songs = songResults
          .map((dynamic item) => _ytMusicItemToSong(item, query: trimmed))
          .whereType<LibrarySong>()
          .where(_looksLikeMusic)
          .toList(growable: false);

      if (songs.isEmpty) {
        final List<dynamic> videoResults = await client.search(
          trimmed,
          filter: ytm.SearchFilter.videos,
          limit: math.max(limit, 8),
        );
        _ytMusicSearchCache[cacheKey] = videoResults
            .map((dynamic item) => _ytMusicItemToSong(item, query: trimmed))
            .whereType<LibrarySong>()
            .where(_looksLikeMusic)
            .toList(growable: false);
      } else {
        _ytMusicSearchCache[cacheKey] = songs;
      }
    } catch (_) {
      _ytMusicSearchCache[cacheKey] = <LibrarySong>[];
    }

    _ytMusicSearchCache[cacheKey] = _rankOnlineSearchMatches(
      _ytMusicSearchCache[cacheKey]!,
      query: trimmed,
      limit: limit,
    );

    for (final LibrarySong song in _ytMusicSearchCache[cacheKey]!) {
      _rememberTransientSong(song);
    }
    return _ytMusicSearchCache[cacheKey]!;
  }

  Future<List<LibrarySong>> _searchYouTubeFallbackOnly(
    String query, {
    int limit = 12,
    bool force = false,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty || limit <= 0) {
      return <LibrarySong>[];
    }

    final String cacheKey = 'yt::$trimmed'.toLowerCase();
    if (!force && _searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    try {
      final VideoSearchList results = await _yt.search.search(
        '$trimmed audio official music',
      );
      final List<LibrarySong> songs = results
          .map(_videoToSong)
          .where(_looksLikeMusic)
          .toList(growable: false);
      final List<LibrarySong> ranked = _rankOnlineSearchMatches(
        songs,
        query: trimmed,
        limit: limit,
      );
      for (final LibrarySong song in ranked) {
        _rememberTransientSong(song);
      }
      _searchCache[cacheKey] = ranked;
      return ranked;
    } catch (_) {
      _searchCache[cacheKey] = <LibrarySong>[];
      return <LibrarySong>[];
    }
  }

  List<LibrarySong> _blendOnlineResults({
    required String query,
    required List<LibrarySong> ytMusicSongs,
    required List<LibrarySong> youtubeSongs,
    required int limit,
    required int preferredYtMusicCount,
    required int preferredYoutubeCount,
  }) {
    final Set<String> excludedIds = <String>{};
    final List<LibrarySong> result = <LibrarySong>[];

    void addFrom(List<LibrarySong> songs, int target) {
      for (final LibrarySong song in songs) {
        if (result.length >= limit || target <= 0) {
          break;
        }
        if (excludedIds.add(song.id) &&
            result.every((LibrarySong item) => !_sameSong(item, song))) {
          result.add(song);
          target -= 1;
        }
      }
    }

    addFrom(
      _rankOnlineSearchMatches(
        ytMusicSongs,
        query: query,
        limit: ytMusicSongs.length,
      ),
      preferredYtMusicCount,
    );
    addFrom(
      _rankOnlineSearchMatches(
        youtubeSongs,
        query: query,
        limit: youtubeSongs.length,
      ),
      preferredYoutubeCount,
    );
    addFrom(
      _rankOnlineSearchMatches(
        ytMusicSongs,
        query: query,
        limit: ytMusicSongs.length,
      ),
      limit,
    );
    addFrom(
      _rankOnlineSearchMatches(
        youtubeSongs,
        query: query,
        limit: youtubeSongs.length,
      ),
      limit,
    );

    return result.take(limit).toList(growable: false);
  }

  Future<List<LibrarySong>> _searchYtMusicSongs(
    String query, {
    int limit = 12,
    bool force = false,
  }) async {
    return _searchYouTubeMusicOnly(query, limit: limit, force: force);
  }

  Future<HomeFeedSection?> _buildFocusHomeSection({
    required Set<String> excludedIds,
  }) async {
    final List<LibrarySong> songs = await _searchYtMusicSongs(
      'focus music',
      limit: 12,
    );
    final List<LibrarySong> ranked = _rankRecommendedSongs(
      songs,
      excludedIds: excludedIds,
      limit: 10,
    );
    if (ranked.length < 4) {
      return null;
    }
    return HomeFeedSection(
      title: 'Focus now',
      subtitle: 'YouTube Music picks for deep work and concentration',
      query: 'focus music',
      songs: ranked,
    );
  }

  Future<HomeFeedSection?> _buildYtMusicRadioSection(
    LibrarySong anchor, {
    required Set<String> excludedIds,
  }) async {
    final List<LibrarySong> songs = await _ytMusicRadioSongs(anchor, limit: 10);
    final List<LibrarySong> filtered = _dedupeSongs(
      songs,
      excludedIds: excludedIds,
      limit: 10,
    );
    if (filtered.length < 4) {
      return null;
    }
    return HomeFeedSection(
      title: 'From YouTube Music radio',
      subtitle: 'Real YT Music up-next inspired by ${anchor.title}',
      query: '${anchor.artist} ${anchor.title} radio',
      songs: filtered,
    );
  }

  String _friendlyOnlineError(Object error) {
    final String message = '$error'.toLowerCase();
    if (message.contains('redirect limit exceeded') ||
        message.contains('google_abuse_exemption') ||
        message.contains('clientexception')) {
      return 'Online recommendations are temporarily limited by YouTube. The app will retry automatically.';
    }
    return 'Online music is unavailable right now. Please try again shortly.';
  }

  Future<List<HomeFeedSection>> _buildYtMusicHomeSections({
    required Set<String> excludedIds,
  }) async {
    final YTMusic? client = _ytMusic;
    if (client == null) {
      return <HomeFeedSection>[];
    }

    final List<dynamic> rows = await client.getHome(limit: 4);
    final List<HomeFeedSection> sections = <HomeFeedSection>[];
    final Set<String> localConsumed = <String>{...excludedIds};

    for (final dynamic row in rows) {
      if (row is! Map) {
        continue;
      }
      final String title = '${row['title'] ?? ''}'.trim();
      final List<dynamic> contents =
          (row['contents'] as List<dynamic>? ?? <dynamic>[]);
      final List<LibrarySong> songs = contents
          .map((dynamic item) => _ytMusicItemToSong(item))
          .whereType<LibrarySong>()
          .toList(growable: false);
      final List<LibrarySong> filtered = _dedupeSongs(
        songs,
        excludedIds: localConsumed,
        limit: 10,
      );
      if (title.isEmpty || filtered.length < 4) {
        continue;
      }
      sections.add(
        HomeFeedSection(
          title: title,
          subtitle: 'Shelf from YouTube Music',
          query: title,
          songs: filtered,
        ),
      );
      localConsumed.addAll(filtered.take(4).map((LibrarySong song) => song.id));
      if (sections.length >= 2) {
        break;
      }
    }
    return sections;
  }

  Future<List<LibrarySong>> _ytMusicRadioSongs(
    LibrarySong anchor, {
    int limit = 10,
  }) async {
    final YTMusic? client = _ytMusic;
    if (client == null) {
      return <LibrarySong>[];
    }

    final String? videoId = await _resolveYtMusicVideoId(anchor);
    if (videoId == null) {
      return <LibrarySong>[];
    }

    final Map<String, dynamic> response = await client.getWatchPlaylist(
      videoId: videoId,
      radio: true,
      limit: limit + 4,
    );
    final List<dynamic> tracks =
        response['tracks'] as List<dynamic>? ?? <dynamic>[];
    final List<LibrarySong> songs = tracks
        .map((dynamic item) => _ytMusicItemToSong(item))
        .whereType<LibrarySong>()
        .where((LibrarySong song) => !_sameSong(song, anchor))
        .toList(growable: false);

    for (final LibrarySong song in songs) {
      _rememberTransientSong(song);
    }
    return songs.take(limit).toList(growable: false);
  }

  Future<String?> _resolveYtMusicVideoId(LibrarySong song) async {
    final String cacheKey = _songIdentityKey(song);
    if (_ytMusicVideoIdCache.containsKey(cacheKey)) {
      return _ytMusicVideoIdCache[cacheKey];
    }

    final String? direct = _extractYouTubeVideoId(song);
    if (direct != null) {
      _ytMusicVideoIdCache[cacheKey] = direct;
      return direct;
    }

    final List<LibrarySong> matches = await _searchYtMusicSongs(
      '${song.artist} ${song.title}',
      limit: 5,
    );
    final String? resolved = matches
        .map(_extractYouTubeVideoId)
        .firstWhereOrNull((String? id) => id != null);
    _ytMusicVideoIdCache[cacheKey] = resolved;
    return resolved;
  }

  String? _extractYouTubeVideoId(LibrarySong song) {
    if (song.id.startsWith('yt:')) {
      return song.id.substring(3);
    }

    final Uri? uri = Uri.tryParse(song.externalUrl ?? song.path);
    if (uri == null) {
      return null;
    }
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    if (uri.host.contains('youtube.com') ||
        uri.host.contains('music.youtube.com')) {
      return uri.queryParameters['v'];
    }
    return null;
  }

  LibrarySong? _ytMusicItemToSong(dynamic item, {String? query}) {
    if (item is! Map) {
      return null;
    }

    final Map<dynamic, dynamic> data = item;
    final String? videoId = data['videoId'] as String?;
    if (videoId == null || videoId.isEmpty) {
      return null;
    }

    final String title = '${data['title'] ?? 'Unknown title'}'.trim();
    final String artist = _readArtistName(data) ?? 'Unknown artist';
    final String album = _readAlbumName(data) ?? 'YouTube Music';
    final String? artworkUrl = _readThumbnailUrl(data);
    final int durationMs = _parseDurationMs(
      data['duration'] ?? data['length'] ?? data['lengthSeconds'],
    );

    final LibrarySong song = LibrarySong(
      id: 'yt:$videoId',
      path: 'https://www.youtube.com/watch?v=$videoId',
      title: title.isEmpty ? 'Unknown title' : title,
      artist: artist,
      album: album,
      albumArtist: artist,
      folderName: 'YouTube Music',
      folderPath: 'ytmusic',
      sourceLabel: 'YouTube Music',
      addedAt: DateTime.now(),
      durationMs: durationMs,
      isRemote: true,
      artworkUrl: artworkUrl,
      externalUrl: 'https://music.youtube.com/watch?v=$videoId',
    );
    if (!_looksLikeMusic(song, query: query)) {
      return null;
    }
    return song;
  }

  List<LibrarySong> _rankOnlineSearchMatches(
    List<LibrarySong> songs, {
    required String query,
    required int limit,
  }) {
    final Set<String> excludedIds = <String>{};
    final Set<String> seenKeys = <String>{};
    final List<_ScoredSong> ranked = <_ScoredSong>[];

    for (final LibrarySong song in songs) {
      if (excludedIds.contains(song.id)) {
        continue;
      }
      final String key = _songIdentityKey(song);
      if (!seenKeys.add(key)) {
        continue;
      }
      ranked.add(_ScoredSong(song, _onlineSearchScore(song, query: query)));
      excludedIds.add(song.id);
    }

    ranked.sort((_ScoredSong a, _ScoredSong b) {
      final int compare = b.score.compareTo(a.score);
      if (compare != 0) {
        return compare;
      }
      return a.song.title.toLowerCase().compareTo(b.song.title.toLowerCase());
    });

    return ranked
        .take(limit)
        .map((_ScoredSong item) => item.song)
        .toList(growable: false);
  }

  double _onlineSearchScore(LibrarySong song, {required String query}) {
    double score = 0;
    final String normalizedQuery = _normalizeToken(query);
    final String title = _normalizeToken(song.title);
    final String artist = _normalizeToken(song.artist);
    final String album = _normalizeToken(song.album);
    final String haystack = '$title $artist $album';

    if (song.sourceLabel == 'YouTube Music') {
      score += 12;
    } else if (song.sourceLabel == 'YouTube') {
      score += 2;
    }

    for (final String token in normalizedQuery.split(RegExp(r'\s+'))) {
      if (token.isEmpty) {
        continue;
      }
      if (title.contains(token)) {
        score += 3.2;
      }
      if (artist.contains(token)) {
        score += 2.4;
      }
      if (album.contains(token)) {
        score += 1.4;
      }
      if (haystack.contains(token)) {
        score += 0.4;
      }
    }

    if (_hasExplicitMusicSignals(song)) {
      score += 3.5;
    }
    if (_looksNonMusicLike(song)) {
      score -= 18;
    }

    final int seconds = song.duration.inSeconds;
    if (seconds >= 90 && seconds <= 480) {
      score += 2.5;
    } else if (seconds > 0 && seconds < 45) {
      score -= 5;
    } else if (seconds > 1200) {
      score -= 8;
    }

    return score;
  }

  bool _looksLikeMusic(LibrarySong song, {String? query}) {
    if (_looksNonMusicLike(song)) {
      return false;
    }

    final int seconds = song.duration.inSeconds;
    if (seconds > 0 && seconds < 45) {
      return false;
    }

    final String normalizedQuery = _normalizeToken(query ?? '');
    if (normalizedQuery.isNotEmpty) {
      final List<String> queryTokens = normalizedQuery
          .split(RegExp(r'\s+'))
          .where((String token) => token.length >= 2)
          .toList(growable: false);
      final String haystack =
          '${_normalizeToken(song.title)} ${_normalizeToken(song.artist)} ${_normalizeToken(song.album)}';
      final int matches = queryTokens
          .where((String token) => haystack.contains(token))
          .length;
      if (queryTokens.isNotEmpty &&
          matches == 0 &&
          !_hasExplicitMusicSignals(song)) {
        return false;
      }
    }

    return true;
  }

  bool _hasExplicitMusicSignals(LibrarySong song) {
    final String text =
        '${song.title} ${song.artist} ${song.album} ${song.sourceLabel}'
            .toLowerCase();
    const List<String> goodTokens = <String>[
      'song',
      'music',
      'audio',
      'official',
      'track',
      'single',
      'album',
      'ep',
      'remix',
      'live',
      'lyrics',
      'radio edit',
    ];
    return goodTokens.any(text.contains);
  }

  bool _looksNonMusicLike(LibrarySong song) {
    final String text =
        '${song.title} ${song.artist} ${song.album} ${song.folderName}'
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    const List<String> badTokens = <String>[
      'gameplay',
      'gaming',
      'walkthrough',
      'walkthroughs',
      'tutorial',
      'lesson',
      'lecture',
      'course',
      'podcast episode',
      'news',
      'review',
      'reaction',
      'interview',
      'stream',
      'livestream',
      'highlights',
      'funny moments',
      'compilation',
      'documentary',
      'explained',
      'how to',
      'education',
      'study guide',
      'minecraft',
      'fortnite',
      'valorant',
      'pubg',
      'free fire',
      'roblox',
      'gta',
    ];
    return badTokens.any(text.contains);
  }

  List<LibrarySong> _dedupeSongs(
    List<LibrarySong> songs, {
    required Set<String> excludedIds,
    int limit = 10,
  }) {
    final Set<String> seenKeys = <String>{};
    final List<LibrarySong> result = <LibrarySong>[];
    for (final LibrarySong song in songs) {
      if (excludedIds.contains(song.id)) {
        continue;
      }
      if (!seenKeys.add(_songIdentityKey(song))) {
        continue;
      }
      result.add(song);
      if (result.length >= limit) {
        break;
      }
    }
    return result;
  }

  String? _readArtistName(Map<dynamic, dynamic> data) {
    final dynamic artists = data['artists'];
    if (artists is List && artists.isNotEmpty) {
      final dynamic first = artists.first;
      if (first is Map && first['name'] != null) {
        return '${first['name']}'.trim();
      }
    }
    if (data['artist'] != null) {
      return '${data['artist']}'.trim();
    }
    return null;
  }

  String? _readAlbumName(Map<dynamic, dynamic> data) {
    final dynamic album = data['album'];
    if (album is Map && album['name'] != null) {
      return '${album['name']}'.trim();
    }
    if (data['category'] != null) {
      return '${data['category']}'.trim();
    }
    return null;
  }

  String? _readThumbnailUrl(Map<dynamic, dynamic> data) {
    final dynamic thumbnails = data['thumbnail'] ?? data['thumbnails'];
    if (thumbnails is List && thumbnails.isNotEmpty) {
      final dynamic last = thumbnails.last;
      if (last is Map && last['url'] != null) {
        return '${last['url']}'.trim();
      }
    }
    return null;
  }

  int _parseDurationMs(dynamic rawDuration) {
    if (rawDuration is num) {
      return rawDuration.toInt() * 1000;
    }
    final String value = '${rawDuration ?? ''}'.trim();
    if (value.isEmpty) {
      return 0;
    }
    final List<int> parts = value
        .split(':')
        .map((String item) => int.tryParse(item) ?? 0)
        .toList(growable: false);
    int seconds = 0;
    for (final int part in parts) {
      seconds = (seconds * 60) + part;
    }
    return seconds * 1000;
  }

  Future<String> _normalizeYtMusicAuth(String input) async {
    if (input.startsWith('{')) {
      final Map<String, dynamic> json =
          jsonDecode(input) as Map<String, dynamic>;
      final Map<String, String> normalized = <String, String>{
        for (final MapEntry<String, dynamic> entry in json.entries)
          entry.key.toLowerCase(): '${entry.value}',
      };
      return jsonEncode(normalized);
    }

    return ytm_browser.setupBrowser(headersRaw: input);
  }

  Future<void> _maybeExtendSmartQueue({
    LibrarySong? seed,
    bool force = false,
  }) async {
    if (_isDisposing ||
        _isDisposed ||
        (!_settings.smartQueueEnabled && !force) ||
        _smartQueueLoading) {
      return;
    }

    final LibrarySong? anchor = seed ?? currentSong;
    if (anchor == null) {
      return;
    }

    final int remaining = _queueSongIds.length - _queueIndex - 1;
    if (remaining >= _smartQueueBatchSize) {
      return;
    }

    await _appendSmartQueuePredictions(
      anchor,
      limit: _smartQueueBatchSize - remaining,
    );
  }

  Future<void> _appendSmartQueuePredictions(
    LibrarySong anchor, {
    int limit = 6,
  }) async {
    if (limit <= 0 || _isDisposing || _isDisposed) {
      return;
    }

    _smartQueueLoading = true;
    notifyListeners();

    try {
      List<LibrarySong> predictions = await _predictNextSongs(
        anchor,
        limit: limit,
      );
      if (_isDisposing || _isDisposed) {
        return;
      }
      final LibrarySong? fallbackAnchor = currentSong;
      if (predictions.isEmpty &&
          fallbackAnchor != null &&
          fallbackAnchor.id != anchor.id) {
        predictions = await _predictNextSongs(fallbackAnchor, limit: limit);
      }
      if (predictions.isEmpty) {
        // Hard fallback so queue always grows for better UX.
        final List<LibrarySong> fallback = await _searchSongs(
          'top songs',
          limit: limit * 2,
          force: true,
        );
        predictions = _dedupeSongs(
          fallback,
          excludedIds: <String>{..._queueSongIds, anchor.id},
          limit: limit,
        );
      }
      if (predictions.isEmpty) {
        return;
      }

      final Set<String> queuedIds = <String>{..._queueSongIds};
      int addedCount = 0;
      for (final LibrarySong song in predictions) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        final LibrarySong prepared = await _preparePlayableSong(song);
        if (_isDisposing || _isDisposed) {
          return;
        }
        if (!queuedIds.add(prepared.id)) {
          continue;
        }

        _queueSongIds = <String>[..._queueSongIds, prepared.id];
        _smartQueueSongIds.add(prepared.id);
        await _player.add(_mediaForSong(prepared));
        addedCount += 1;
      }

      if (addedCount > 0 && _queueSongIds.length > 1) {
        if (_queueLabel == 'Song' ||
            _queueLabel == 'Now Playing' ||
            _queueLabel == 'YouTube' ||
            _queueLabel == 'URL Stream') {
          _queueLabel = 'Smart queue';
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Smart queue failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _smartQueueLoading = false;
      notifyListeners();
    }
  }

  Future<List<LibrarySong>> _predictNextSongs(
    LibrarySong anchor, {
    int limit = 6,
  }) async {
    final Set<String> excludedIds = <String>{..._queueSongIds, anchor.id};
    final List<LibrarySong> prioritized = _dedupeSongs(
      await _ytMusicRadioSongs(anchor, limit: limit + 4),
      excludedIds: excludedIds,
      limit: limit,
    );
    if (prioritized.length >= limit) {
      return prioritized;
    }

    final List<_RecommendationQuery> queries = _buildPredictionQueries(anchor);
    final List<LibrarySong> collected = <LibrarySong>[...prioritized];
    for (final _RecommendationQuery query in queries) {
      final List<LibrarySong> results = await _searchSongs(
        query.query,
        limit: 12,
      );
      collected.addAll(results);
      if (collected.length >= 36) {
        break;
      }
    }

    final List<LibrarySong> fallback = _rankRecommendedSongs(
      collected,
      anchor: anchor,
      excludedIds: excludedIds,
      limit: limit * 2,
    );
    final List<LibrarySong> merged = _dedupeSongs(
      <LibrarySong>[...prioritized, ...fallback],
      excludedIds: excludedIds,
      limit: limit,
    );
    return merged;
  }

  LibrarySong? _primaryRecommendationSeed() {
    return currentSong ??
        _validHistorySongs().firstOrNull ??
        _rankedPreferenceSongs().firstOrNull;
  }

  List<_RecommendationQuery> _buildHomeQueries(LibrarySong? seedSong) {
    final List<_TasteSignal> artists = _preferenceArtists();
    final List<_TasteSignal> genres = _preferenceGenres();
    final List<_LanguageSignal> languages = _preferredLanguagesFromValidHistory();
    final List<_RecommendationQuery> queries = <_RecommendationQuery>[];

    if (seedSong != null) {
      queries.add(
        _RecommendationQuery(
          title: 'Made for you',
          subtitle: 'Online picks tuned from ${seedSong.artist}',
          query: '${seedSong.artist} popular songs',
          anchor: seedSong,
        ),
      );
      queries.add(
        _RecommendationQuery(
          title: 'Because you played ${seedSong.title}',
          subtitle: 'Keep the same lane going',
          query: '${seedSong.artist} ${seedSong.title} song radio',
          anchor: seedSong,
        ),
      );
    }

    for (final _TasteSignal artist in artists.take(2)) {
      queries.add(
        _RecommendationQuery(
          title: 'From ${artist.label}',
          subtitle: 'Popular tracks and adjacent songs',
          query: '${artist.label} top songs',
        ),
      );
    }

    for (final _TasteSignal genre in genres.take(1)) {
      queries.add(
        _RecommendationQuery(
          title: '${genre.label} picks',
          subtitle: 'Online discoveries near your taste',
          query: '${genre.label} songs',
        ),
      );
    }

    for (final _LanguageSignal language in languages.take(1)) {
      queries.add(
        _RecommendationQuery(
          title: '${language.label} focus',
          subtitle: 'Picks tuned to your listening language',
          query: '${language.queryToken} songs',
        ),
      );
    }

    queries.addAll(const <_RecommendationQuery>[
      _RecommendationQuery(
        title: 'Trending now',
        subtitle: 'Fresh online music to start from',
        query: 'trending songs',
      ),
      _RecommendationQuery(
        title: 'Chill rotation',
        subtitle: 'Easy listens when you want a softer queue',
        query: 'chill songs',
      ),
    ]);

    return queries;
  }

  List<_RecommendationQuery> _buildPredictionQueries(LibrarySong anchor) {
    final List<_TasteSignal> artists = _preferenceArtists();
    final List<_LanguageSignal> languages = _preferredLanguagesFromValidHistory();
    final List<_RecommendationQuery> queries = <_RecommendationQuery>[
      _RecommendationQuery(
        title: 'Related to ${anchor.title}',
        subtitle: 'Auto queue',
        query: '${anchor.artist} ${anchor.title} song radio',
        anchor: anchor,
      ),
      _RecommendationQuery(
        title: 'More from ${anchor.artist}',
        subtitle: 'Auto queue',
        query: '${anchor.artist} popular songs',
        anchor: anchor,
      ),
    ];

    if ((anchor.genre ?? '').trim().isNotEmpty) {
      queries.add(
        _RecommendationQuery(
          title: '${anchor.genre} mix',
          subtitle: 'Auto queue',
          query: '${anchor.genre} ${anchor.artist} songs',
          anchor: anchor,
        ),
      );
    }

    for (final _TasteSignal artist in artists.take(2)) {
      if (_normalizeToken(artist.label) == _normalizeToken(anchor.artist)) {
        continue;
      }
      queries.add(
        _RecommendationQuery(
          title: 'Matches your taste',
          subtitle: 'Auto queue',
          query: '${artist.label} top songs',
          anchor: anchor,
        ),
      );
    }

    for (final _LanguageSignal language in languages.take(1)) {
      queries.add(
        _RecommendationQuery(
          title: '${language.label} queue',
          subtitle: 'Auto queue',
          query: '${anchor.artist} ${language.queryToken} songs',
          anchor: anchor,
        ),
      );
    }

    queries.add(
      _RecommendationQuery(
        title: 'Fallback mix',
        subtitle: 'Auto queue',
        query: 'trending songs',
        anchor: anchor,
      ),
    );
    return queries;
  }

  List<LibrarySong> _rankRecommendedSongs(
    List<LibrarySong> songs, {
    LibrarySong? anchor,
    Set<String>? excludedIds,
    int limit = 10,
  }) {
    final Set<String> blockedIds = excludedIds ?? <String>{};
    final Set<String> seenKeys = <String>{};
    final List<_ScoredSong> ranked = <_ScoredSong>[];

    for (final LibrarySong song in songs) {
      if (blockedIds.contains(song.id)) {
        continue;
      }

      final String key = _songIdentityKey(song);
      if (!seenKeys.add(key)) {
        continue;
      }

      if (anchor != null && _sameSong(anchor, song)) {
        continue;
      }

      ranked.add(_ScoredSong(song, _recommendationScore(song, anchor: anchor)));
    }

    ranked.sort((_ScoredSong a, _ScoredSong b) {
      final int scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.song.title.toLowerCase().compareTo(b.song.title.toLowerCase());
    });

    return ranked
        .take(limit)
        .map((_ScoredSong item) => item.song)
        .toList(growable: false);
  }

  double _recommendationScore(LibrarySong song, {LibrarySong? anchor}) {
    double score = song.playCount.toDouble();
    final String title = _normalizeToken(song.title);
    final String artist = _normalizeToken(song.artist);

    if (anchor != null) {
      final String anchorTitle = _normalizeToken(anchor.title);
      final String anchorArtist = _normalizeToken(anchor.artist);
      if (artist == anchorArtist) {
        score += 9;
      } else if (artist.contains(anchorArtist) ||
          anchorArtist.contains(artist)) {
        score += 4;
      }

      if (title.contains(anchorTitle) || anchorTitle.contains(title)) {
        score -= 6;
      }
    }

    for (final _TasteSignal taste in _preferenceArtists().take(4)) {
      final String preferredArtist = _normalizeToken(taste.label);
      if (artist == preferredArtist) {
        score += taste.score * 3;
      } else if (artist.contains(preferredArtist) ||
          preferredArtist.contains(artist)) {
        score += taste.score * 1.4;
      }
    }

    for (final LibrarySong recent in _validHistorySongs().take(4)) {
      final String recentArtist = _normalizeToken(recent.artist);
      if (artist == recentArtist) {
        score += 2.2;
      }
    }

    if (song.durationMs > 0) {
      score += 0.2;
    }

    return score;
  }

  List<_TasteSignal> _preferenceArtists() {
    final Map<String, double> scores = <String, double>{};
    final Map<String, String> labels = <String, String>{};

    for (final LibrarySong song in _rankedPreferenceSongs()) {
      final String key = _normalizeToken(song.artist);
      if (key.isEmpty || key == 'unknown artist') {
        continue;
      }
      labels[key] ??= song.artist;
      scores[key] = (scores[key] ?? 0) + _songPreferenceWeight(song);
    }

    return scores.entries
        .map(
          (MapEntry<String, double> entry) =>
              _TasteSignal(labels[entry.key] ?? entry.key, entry.value),
        )
        .toList()
      ..sort((_TasteSignal a, _TasteSignal b) => b.score.compareTo(a.score));
  }

  List<_TasteSignal> _preferenceGenres() {
    final Map<String, double> scores = <String, double>{};
    final Map<String, String> labels = <String, String>{};

    for (final LibrarySong song in _rankedPreferenceSongs()) {
      final String rawGenre = song.genre?.trim() ?? '';
      if (rawGenre.isEmpty) {
        continue;
      }
      final String key = _normalizeToken(rawGenre);
      labels[key] ??= rawGenre;
      scores[key] = (scores[key] ?? 0) + _songPreferenceWeight(song);
    }

    return scores.entries
        .map(
          (MapEntry<String, double> entry) =>
              _TasteSignal(labels[entry.key] ?? entry.key, entry.value),
        )
        .toList()
      ..sort((_TasteSignal a, _TasteSignal b) => b.score.compareTo(a.score));
  }

  List<LibrarySong> _rankedPreferenceSongs() {
    final Map<String, double> validHistoryBoost = <String, double>{};
    for (final PlaybackEntry entry in validPlaybackHistory.take(120)) {
      validHistoryBoost[entry.songId] =
          (validHistoryBoost[entry.songId] ?? 0) + (1 + entry.completionRatio);
    }
    final Map<String, LibrarySong> allSongs = <String, LibrarySong>{
      for (final LibrarySong song in _songs) song.id: song,
      ..._transientSongsById,
    };
    final List<LibrarySong> ranked = allSongs.values
        .where((LibrarySong song) => _songPreferenceWeight(song) > 0)
        .toList();
    ranked.sort((LibrarySong a, LibrarySong b) {
      final double leftScore =
          _songPreferenceWeight(a) + (validHistoryBoost[a.id] ?? 0) * 2.5;
      final double rightScore =
          _songPreferenceWeight(b) + (validHistoryBoost[b.id] ?? 0) * 2.5;
      final int scoreCompare = rightScore.compareTo(leftScore);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return b.addedAt.compareTo(a.addedAt);
    });
    return ranked;
  }

  List<LibrarySong> _validHistorySongs() {
    final Set<String> seen = <String>{};
    final List<LibrarySong> result = <LibrarySong>[];
    for (final PlaybackEntry entry in validPlaybackHistory.take(120)) {
      if (!seen.add(entry.songId)) {
        continue;
      }
      final LibrarySong? song = songById(entry.songId);
      if (song != null) {
        result.add(song);
      }
    }
    return result;
  }

  List<_LanguageSignal> _preferredLanguagesFromValidHistory() {
    final Map<String, double> scores = <String, double>{};
    for (final PlaybackEntry entry in validPlaybackHistory.take(120)) {
      final LibrarySong? song = songById(entry.songId);
      if (song == null) {
        continue;
      }
      final String language = _detectSongLanguage(song);
      final double weight = entry.listenedToEnd
          ? 1.8
          : math.max(0.3, entry.completionRatio);
      scores[language] = (scores[language] ?? 0) + weight;
    }
    final double total = scores.values.fold(0, (double sum, double v) => sum + v);
    if (total <= 0) {
      return const <_LanguageSignal>[];
    }
    return scores.entries
        .map(
          (MapEntry<String, double> entry) => _LanguageSignal(
            label: _languageLabel(entry.key),
            queryToken: _languageQueryToken(entry.key),
            score: entry.value / total,
          ),
        )
        .toList()
      ..sort((_LanguageSignal a, _LanguageSignal b) => b.score.compareTo(a.score));
  }

  String _detectSongLanguage(LibrarySong song) {
    final String text = '${song.title} ${song.artist} ${song.album}';
    if (RegExp(r'[\u0D80-\u0DFF]').hasMatch(text)) {
      return 'si';
    }
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) {
      return 'ta';
    }
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      return 'hi';
    }
    return 'en';
  }

  String _languageLabel(String language) {
    return switch (language) {
      'si' => 'Sinhala',
      'ta' => 'Tamil',
      'hi' => 'Hindi',
      _ => 'English',
    };
  }

  String _languageQueryToken(String language) {
    return switch (language) {
      'si' => 'sinhala',
      'ta' => 'tamil',
      'hi' => 'hindi',
      _ => 'english',
    };
  }

  double _songPreferenceWeight(LibrarySong song) {
    double score = song.playCount * 2.0;
    if (song.isFavorite) {
      score += 6;
    }
    if (song.lastPlayedAt != null) {
      final int ageHours = DateTime.now()
          .difference(song.lastPlayedAt!)
          .inHours;
      score += ageHours <= 24
          ? 4
          : ageHours <= 168
          ? 2
          : 0.5;
    }
    return score;
  }

  bool _sameSong(LibrarySong left, LibrarySong right) {
    return _songIdentityKey(left) == _songIdentityKey(right);
  }

  String _songIdentityKey(LibrarySong song) {
    return '${_normalizeToken(song.artist)}::${_normalizeToken(song.title)}';
  }

  String _normalizeToken(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(
          RegExp(
            r'\b(official|video|audio|lyrics|lyric|hd|hq|visualizer|remaster(ed)?|version|full song|music video)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> playFromUrl(String input) async {
    final String value = input.trim();
    if (value.isEmpty) {
      return;
    }

    try {
      if (_looksLikeYouTube(value)) {
        final Video video = await _yt.videos.get(value);
        final LibrarySong song = _videoToSong(video);
        await playOnlineSong(song);
        return;
      }

      final Uri? uri = Uri.tryParse(value);
      if (uri == null || !uri.hasScheme) {
        throw const FormatException('Enter a valid URL.');
      }

      final LibrarySong song = LibrarySong(
        id: 'url:${uri.toString()}',
        path: uri.toString(),
        title: p.basename(uri.path).isEmpty ? uri.host : p.basename(uri.path),
        artist: uri.host,
        album: 'Online Stream',
        albumArtist: uri.host,
        folderName: 'Online',
        folderPath: uri.toString(),
        sourceLabel: 'URL',
        addedAt: DateTime.now(),
        durationMs: 0,
        isRemote: true,
        externalUrl: uri.toString(),
      );
      await _openPreparedSong(song, label: 'URL Stream');
    } catch (error) {
      _errorMessage = '$error';
      notifyListeners();
    }
  }

  Future<void> playOnlineSong(LibrarySong song) async {
    final LibrarySong prepared = await _preparePlayableSong(song);
    await _openPreparedSong(prepared, label: 'YouTube');
  }

  void _attachPlayerListeners() {
    _subscriptions.add(
      _player.stream.playing.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _isPlaying = value as bool;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _player.stream.position.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _position = value as Duration;
        _updateActivePlaybackProgress();
        _syncQueueIndexFromPlayerState();
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _player.stream.duration.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _duration = value as Duration;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _player.stream.shuffle.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _isShuffleEnabled = value as bool;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _player.stream.playlistMode.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _repeatMode = value as PlaylistMode;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _player.stream.error.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _errorMessage = value as String;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _player.stream.playlist.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        final Playlist playlist = value as Playlist;
        _queueSongIds = playlist.medias
            .map((Media media) => media.extras?['songId'] as String?)
            .whereType<String>()
            .toList();
        _queueIndex = playlist.index.clamp(
          0,
          _queueSongIds.isEmpty ? 0 : _queueSongIds.length - 1,
        );
        final LibrarySong? song = currentSong;
        if (song != null && song.id != _lastTrackedSongId) {
          _trackPlayback(song.id);
        }
        unawaited(_maybeExtendSmartQueue(seed: song, force: true));
        notifyListeners();
      }),
    );
  }

  void _syncQueueIndexFromPlayerState() {
    if (_isDisposing || _isDisposed) {
      return;
    }
    if (_queueSongIds.isEmpty) {
      return;
    }
    final int nextIndex = _player.state.playlist.index.clamp(
      0,
      _queueSongIds.length - 1,
    );
    if (nextIndex == _queueIndex) {
      return;
    }
    _queueIndex = nextIndex;
    final LibrarySong? song = currentSong;
    if (song != null && song.id != _lastTrackedSongId) {
      _trackPlayback(song.id);
    }
    unawaited(_maybeExtendSmartQueue(seed: song, force: true));
  }

  LibrarySong? songById(String id) {
    return _songs.firstWhereOrNull((LibrarySong song) => song.id == id) ??
        _transientSongsById[id];
  }

  List<LibrarySong> songsForPlaylist(UserPlaylist playlist) {
    return playlist.songIds
        .map(songById)
        .whereType<LibrarySong>()
        .toList(growable: false);
  }

  Future<void> importFiles() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
    );
    if (result == null) {
      return;
    }

    final List<String> picked = result.paths.whereType<String>().toList();
    if (picked.isEmpty) {
      return;
    }

    _sources = <String>{..._sources, ...picked}.toList()..sort();
    await _rescanAllSources();
  }

  Future<void> importFolder() async {
    final String? folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Pick a music folder',
    );
    if (folder == null || folder.isEmpty) {
      return;
    }

    _sources = <String>{..._sources, folder}.toList()..sort();
    await _rescanAllSources();
  }

  Future<void> rescanLibrary() async {
    await _rescanAllSources();
  }

  Future<void> removeSource(String source) async {
    _sources = _sources.where((String item) => item != source).toList();
    await _rescanAllSources();
  }

  Future<void> clearLibrary() async {
    _sources = <String>[];
    _songs = <LibrarySong>[];
    _playlists = <UserPlaylist>[];
    _history = <PlaybackEntry>[];
    _onlineResults = <LibrarySong>[];
    _homeFeed = <HomeFeedSection>[];
    _transientSongsById.clear();
    _searchCache.clear();
    _ytMusicSearchCache.clear();
    _ytMusicVideoIdCache.clear();
    _queueSongIds = <String>[];
    _queueIndex = 0;
    _queueLabel = 'Now Playing';
    _lastTrackedSongId = null;
    _smartQueueSongIds.clear();
    await _player.stop();
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> _rescanAllSources() async {
    _scanning = true;
    _statusMessage = 'Scanning library...';
    _errorMessage = null;
    notifyListeners();

    try {
      final List<String> files = await _expandSourceFiles(_sources);
      final Map<String, LibrarySong> previousByPath = <String, LibrarySong>{
        for (final LibrarySong song in _songs) song.path: song,
      };
      final List<LibrarySong> scanned = <LibrarySong>[];

      for (final String filePath in files) {
        scanned.add(
          await _buildSongFromPath(filePath, previousByPath[filePath]),
        );
      }

      _songs = scanned;
      _playlists = _playlists
          .map(
            (UserPlaylist playlist) => playlist.copyWith(
              songIds: playlist.songIds
                  .where(
                    (String songId) =>
                        scanned.any((LibrarySong song) => song.id == songId),
                  )
                  .toList(),
              updatedAt: DateTime.now(),
            ),
          )
          .where((UserPlaylist playlist) => playlist.songIds.isNotEmpty)
          .toList();
      _history = _history
          .where(
            (PlaybackEntry entry) =>
                scanned.any((LibrarySong song) => song.id == entry.songId),
          )
          .toList();

      _statusMessage = scanned.isEmpty
          ? 'No supported audio files found in the selected sources.'
          : 'Imported ${scanned.length} tracks from ${_sources.length} source(s).';
      await _saveSnapshot();
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = '$error';
      _statusMessage = 'Scan failed.';
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  Future<List<String>> _expandSourceFiles(List<String> sources) async {
    final Set<String> results = <String>{};
    for (final String source in sources) {
      final FileSystemEntityType type = await FileSystemEntity.type(source);
      if (type == FileSystemEntityType.file) {
        if (_isAudioFile(source)) {
          results.add(source);
        }
        continue;
      }

      if (type == FileSystemEntityType.directory) {
        await for (final FileSystemEntity entity in Directory(
          source,
        ).list(recursive: true, followLinks: false)) {
          if (entity is File && _isAudioFile(entity.path)) {
            results.add(entity.path);
          }
        }
      }
    }

    final List<String> sorted = results.toList()..sort();
    return sorted;
  }

  bool _isAudioFile(String path) {
    final String extension = p
        .extension(path)
        .replaceFirst('.', '')
        .toLowerCase();
    return supportedExtensions.contains(extension);
  }

  Future<LibrarySong> _buildSongFromPath(
    String filePath,
    LibrarySong? previous,
  ) async {
    Tag? tag;
    try {
      tag = await AudioTags.read(filePath);
    } catch (_) {
      tag = null;
    }

    final File file = File(filePath);
    final FileStat stat = await file.stat();
    final String baseName = p.basenameWithoutExtension(filePath);
    final _FallbackTitle fallback = _fallbackFromFilename(baseName);
    final String folderPath = p.dirname(filePath);
    final String folderName = p.basename(folderPath);

    final String title = _cleanText(tag?.title) ?? fallback.title;
    final String artist =
        _cleanText(tag?.trackArtist) ?? fallback.artist ?? 'Unknown artist';
    final String album = _cleanText(tag?.album) ?? folderName;
    final String albumArtist = _cleanText(tag?.albumArtist) ?? artist;

    return LibrarySong(
      id: previous?.id ?? filePath,
      path: filePath,
      title: title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      folderName: folderName.isEmpty ? 'Library' : folderName,
      folderPath: folderPath,
      sourceLabel: _sourceLabelForPath(filePath),
      addedAt: previous?.addedAt ?? stat.changed,
      durationMs: tag?.duration ?? previous?.durationMs ?? 0,
      genre: _cleanText(tag?.genre) ?? previous?.genre,
      year: tag?.year ?? previous?.year,
      trackNumber: tag?.trackNumber ?? previous?.trackNumber,
      discNumber: tag?.discNumber ?? previous?.discNumber,
      isFavorite: previous?.isFavorite ?? false,
      playCount: previous?.playCount ?? 0,
      lastPlayedAt: previous?.lastPlayedAt,
    );
  }

  LibrarySong _videoToSong(Video video) {
    // Avoid thumbnail 404s: maxRes is not always available.
    final String artwork = video.thumbnails.highResUrl.isNotEmpty
        ? video.thumbnails.highResUrl
        : video.thumbnails.standardResUrl;
    return LibrarySong(
      id: 'yt:${video.id.value}',
      path: 'https://www.youtube.com/watch?v=${video.id.value}',
      title: video.title,
      artist: video.author,
      album: 'YouTube',
      albumArtist: video.author,
      folderName: 'YouTube',
      folderPath: 'youtube',
      sourceLabel: 'YouTube',
      addedAt: DateTime.now(),
      durationMs: video.duration?.inMilliseconds ?? 0,
      isRemote: true,
      artworkUrl: artwork,
      externalUrl: 'https://music.youtube.com/watch?v=${video.id.value}',
    );
  }

  bool _looksLikeYouTube(String value) {
    return value.contains('youtube.com/') ||
        value.contains('youtu.be/') ||
        value.startsWith('yt:');
  }

  _FallbackTitle _fallbackFromFilename(String baseName) {
    if (baseName.contains(' - ')) {
      final List<String> parts = baseName.split(' - ');
      if (parts.length >= 2) {
        return _FallbackTitle(
          artist: parts.first.trim(),
          title: parts.skip(1).join(' - ').trim(),
        );
      }
    }
    return _FallbackTitle(title: baseName.replaceAll('_', ' ').trim());
  }

  String? _cleanText(String? text) {
    if (text == null) {
      return null;
    }
    final String value = text.trim();
    return value.isEmpty ? null : value;
  }

  String _sourceLabelForPath(String path) {
    String? bestMatch;
    for (final String source in _sources) {
      if (path.startsWith(source) &&
          (bestMatch == null || source.length > bestMatch.length)) {
        bestMatch = source;
      }
    }
    if (bestMatch == null) {
      return 'Library';
    }
    return p.basename(bestMatch).isEmpty ? bestMatch : p.basename(bestMatch);
  }

  Future<void> playSongs(
    List<LibrarySong> songs, {
    int startIndex = 0,
    String label = 'Now Playing',
  }) async {
    if (songs.isEmpty) {
      return;
    }

    final int safeIndex = startIndex.clamp(0, songs.length - 1);
    final List<LibrarySong> preparedSongs = <LibrarySong>[];
    for (final LibrarySong song in songs) {
      preparedSongs.add(await _preparePlayableSong(song));
    }

    final List<Media> medias = preparedSongs.map(_mediaForSong).toList();

    _smartQueueSongIds.clear();
    _queueSongIds = preparedSongs.map((LibrarySong song) => song.id).toList();
    _queueLabel = label;
    _queueIndex = safeIndex;
    await _player.open(Playlist(medias, index: safeIndex));
    _trackPlayback(preparedSongs[safeIndex].id);
    unawaited(_maybeExtendSmartQueue(seed: preparedSongs[safeIndex], force: true));
    notifyListeners();
  }

  Future<void> playSong(LibrarySong song, {String label = 'Song'}) async {
    await playSongs(<LibrarySong>[song], label: label);
  }

  Future<void> playAlbum(AlbumCollection album, {int startIndex = 0}) async {
    await playSongs(album.songs, startIndex: startIndex, label: album.title);
  }

  Future<void> playArtist(ArtistCollection artist, {int startIndex = 0}) async {
    await playSongs(artist.songs, startIndex: startIndex, label: artist.name);
  }

  Future<void> playFolder(FolderCollection folder, {int startIndex = 0}) async {
    await playSongs(folder.songs, startIndex: startIndex, label: folder.name);
  }

  Future<void> playPlaylist(UserPlaylist playlist, {int startIndex = 0}) async {
    final List<LibrarySong> songs = songsForPlaylist(playlist);
    await playSongs(songs, startIndex: startIndex, label: playlist.name);
  }

  Future<void> enqueueSong(LibrarySong song) async {
    final LibrarySong prepared = await _preparePlayableSong(song);
    if (_queueSongIds.isEmpty) {
      await playSong(prepared, label: 'Queue');
      return;
    }
    _smartQueueSongIds.remove(prepared.id);
    _queueSongIds = <String>[..._queueSongIds, prepared.id];
    await _player.add(_mediaForSong(prepared));
    notifyListeners();
  }

  Future<LibrarySong> _preparePlayableSong(LibrarySong song) async {
    _rememberTransientSong(song);
    if (!song.isRemote || !_looksLikeYouTube(song.path)) {
      return song;
    }

    final StreamManifest manifest = await _yt.videos.streams.getManifest(
      song.path,
    );

    String resolvedUrl;
    if (manifest.hls.isNotEmpty) {
      resolvedUrl = manifest.hls.first.url.toString();
    } else if (manifest.muxed.isNotEmpty) {
      resolvedUrl = manifest.muxed.withHighestBitrate().url.toString();
    } else if (manifest.audioOnly.isNotEmpty) {
      resolvedUrl = manifest.audioOnly.withHighestBitrate().url.toString();
    } else {
      throw const FormatException('No playable YouTube stream found.');
    }

    final LibrarySong prepared = song.copyWith(path: resolvedUrl);
    _rememberTransientSong(prepared);
    return prepared;
  }

  Future<void> _openPreparedSong(
    LibrarySong song, {
    required String label,
  }) async {
    _rememberTransientSong(song);
    _smartQueueSongIds.clear();
    _queueSongIds = <String>[song.id];
    _queueLabel = label;
    _queueIndex = 0;
    await _player.open(Playlist(<Media>[_mediaForSong(song)]));
    _trackPlayback(song.id);
    unawaited(_maybeExtendSmartQueue(seed: song, force: true));
    notifyListeners();
  }

  Media _mediaForSong(LibrarySong song) {
    return Media(
      song.path,
      extras: <String, dynamic>{'songId': song.id},
      httpHeaders: _httpHeadersForSong(song),
    );
  }

  Map<String, String>? _httpHeadersForSong(LibrarySong song) {
    if (!song.isRemote) {
      return null;
    }

    final Uri? uri = Uri.tryParse(song.path);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final String host = uri.host.toLowerCase();
    if (host.contains('googlevideo.com') ||
        host.contains('youtube.com') ||
        host.contains('youtu.be')) {
      return <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        'Referer': song.externalUrl ?? 'https://music.youtube.com/',
        'Origin': 'https://music.youtube.com',
        'Accept': '*/*',
      };
    }

    return <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    };
  }

  Future<void> jumpToQueue(int index) async {
    if (index < 0 || index >= _queueSongIds.length) {
      return;
    }
    await _player.jump(index);
    _queueIndex = index;
    notifyListeners();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queueSongIds.length) {
      return;
    }
    final String removedId = _queueSongIds[index];
    await _player.remove(index);
    _queueSongIds.removeAt(index);
    _smartQueueSongIds.remove(removedId);
    if (_queueSongIds.isEmpty) {
      _queueIndex = 0;
      await _player.stop();
    } else if (index < _queueIndex) {
      _queueIndex -= 1;
    } else {
      _queueIndex = _queueIndex.clamp(0, _queueSongIds.length - 1);
    }
    unawaited(_maybeExtendSmartQueue(force: true));
    notifyListeners();
  }

  Future<void> togglePlayback() async {
    await _player.playOrPause();
  }

  Future<void> nextTrack() async {
    await _player.next();
  }

  Future<void> previousTrack() async {
    await _player.previous();
  }

  Future<void> seek(Duration target) async {
    await _player.seek(target);
  }

  Future<void> toggleShuffle() async {
    await _player.setShuffle(!_isShuffleEnabled);
  }

  Future<void> cycleRepeatMode() async {
    final PlaylistMode next = switch (_repeatMode) {
      PlaylistMode.none => PlaylistMode.loop,
      PlaylistMode.loop => PlaylistMode.single,
      PlaylistMode.single => PlaylistMode.none,
    };
    await _player.setPlaylistMode(next);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeModeIndex: mode.index);
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> setDenseLibrary(bool value) async {
    _settings = _settings.copyWith(denseLibrary: value);
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> setGridView(bool value) async {
    _settings = _settings.copyWith(useGridView: value);
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> setPlaybackRate(double value) async {
    _settings = _settings.copyWith(playbackRate: value);
    await _player.setRate(value);
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> setSmartQueueEnabled(bool value) async {
    _settings = _settings.copyWith(smartQueueEnabled: value);
    await _saveSnapshot();
    if (value) {
      unawaited(_maybeExtendSmartQueue());
    }
    notifyListeners();
  }

  Future<void> updateYtMusicAuth(String rawInput) async {
    final String trimmed = rawInput.trim();
    final String? normalized = trimmed.isEmpty
        ? null
        : await _normalizeYtMusicAuth(trimmed);

    _settings = _settings.copyWith(ytMusicAuthJson: normalized ?? '');
    await _saveSnapshot();
    await _recreateYtMusicClient();
    notifyListeners();
  }

  Future<void> clearYtMusicAuth() async {
    _settings = _settings.copyWith(ytMusicAuthJson: '');
    await _saveSnapshot();
    await _recreateYtMusicClient();
    notifyListeners();
  }

  Future<UserPlaylist> createPlaylist(String name) async {
    final DateTime now = DateTime.now();
    final UserPlaylist playlist = UserPlaylist(
      id: _uuid.v4(),
      name: name.trim(),
      songIds: <String>[],
      createdAt: now,
      updatedAt: now,
    );
    _playlists = <UserPlaylist>[playlist, ..._playlists];
    await _saveSnapshot();
    notifyListeners();
    return playlist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists = _playlists
        .where((UserPlaylist playlist) => playlist.id != playlistId)
        .toList();
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> renamePlaylist(String playlistId, String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _playlists = _playlists
        .map(
          (UserPlaylist playlist) => playlist.id == playlistId
              ? playlist.copyWith(name: trimmed, updatedAt: DateTime.now())
              : playlist,
        )
        .toList();
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    _playlists = _playlists.map((UserPlaylist playlist) {
      if (playlist.id != playlistId || playlist.songIds.contains(songId)) {
        return playlist;
      }
      return playlist.copyWith(
        songIds: <String>[...playlist.songIds, songId],
        updatedAt: DateTime.now(),
      );
    }).toList();
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    _playlists = _playlists.map((UserPlaylist playlist) {
      if (playlist.id != playlistId) {
        return playlist;
      }
      return playlist.copyWith(
        songIds: playlist.songIds.where((String id) => id != songId).toList(),
        updatedAt: DateTime.now(),
      );
    }).toList();
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> toggleFavorite(String songId) async {
    _songs = _songs
        .map(
          (LibrarySong song) => song.id == songId
              ? song.copyWith(isFavorite: !song.isFavorite)
              : song,
        )
        .toList();
    await _saveSnapshot();
    notifyListeners();
  }

  void _rememberTransientSong(LibrarySong song) {
    if (song.isRemote) {
      _transientSongsById[song.id] = song;
    }
  }

  void _trackPlayback(String songId) {
    final DateTime now = DateTime.now();
    _finalizeActivePlaybackSession(nextSongId: songId);
    final int index = _songs.indexWhere(
      (LibrarySong song) => song.id == songId,
    );
    if (index >= 0) {
      final LibrarySong song = _songs[index];
      _songs[index] = song.copyWith(
        playCount: song.playCount + 1,
        lastPlayedAt: now,
      );
    } else {
      final LibrarySong? transient = _transientSongsById[songId];
      if (transient != null) {
        _transientSongsById[songId] = transient.copyWith(
          playCount: transient.playCount + 1,
          lastPlayedAt: now,
        );
      }
    }

    _activePlaybackSongId = songId;
    _activePlaybackCompletionRatio = 0;
    _lastTrackedSongId = songId;
    unawaited(_saveSnapshot());
  }

  void _updateActivePlaybackProgress() {
    final LibrarySong? song = currentSong;
    if (song == null) {
      return;
    }
    _activePlaybackSongId ??= song.id;
    if (_activePlaybackSongId != song.id) {
      _finalizeActivePlaybackSession(nextSongId: song.id);
      _activePlaybackSongId = song.id;
      _activePlaybackCompletionRatio = 0;
    }
    final int durationMs = math.max(song.durationMs, _duration.inMilliseconds);
    if (durationMs <= 0) {
      return;
    }
    final double ratio = _position.inMilliseconds / durationMs;
    if (ratio > _activePlaybackCompletionRatio) {
      _activePlaybackCompletionRatio = ratio.clamp(0, 1);
    }
  }

  void _finalizeActivePlaybackSession({String? nextSongId}) {
    final String? songId = _activePlaybackSongId;
    if (songId == null || songId == nextSongId) {
      return;
    }
    final DateTime now = DateTime.now();
    final double ratio = _activePlaybackCompletionRatio.clamp(0, 1);
    final bool listenedToEnd = ratio >= 0.88;
    _history = <PlaybackEntry>[
      PlaybackEntry(
        songId: songId,
        playedAt: now,
        completionRatio: ratio,
        listenedToEnd: listenedToEnd,
      ),
      ..._history,
    ].take(300).toList();
    _activePlaybackSongId = null;
    _activePlaybackCompletionRatio = 0;
  }

  Future<void> _loadSnapshot() async {
    final File file = await _snapshotFile();
    if (!await file.exists()) {
      return;
    }

    final Map<String, dynamic> json =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    _settings = AppSettings.fromJson(json['settings'] as Map<String, dynamic>?);
    _sources = (json['sources'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic item) => item as String)
        .toList();
    _songs = (json['songs'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (dynamic item) => LibrarySong.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    _playlists = (json['playlists'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (dynamic item) => UserPlaylist.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    final List<LibrarySong> transientSongs =
        (json['transientSongs'] as List<dynamic>? ?? <dynamic>[])
            .map(
              (dynamic item) =>
                  LibrarySong.fromJson(item as Map<String, dynamic>),
            )
            .where((LibrarySong song) => song.isRemote)
            .toList();
    _transientSongsById
      ..clear()
      ..addEntries(
        transientSongs.map(
          (LibrarySong song) => MapEntry<String, LibrarySong>(song.id, song),
        ),
      );
    _history = (json['history'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (dynamic item) =>
              PlaybackEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _saveSnapshot() async {
    final File file = await _snapshotFile();
    await file.parent.create(recursive: true);
    final List<LibrarySong> transientSongs =
        _transientSongsById.values
            .where(
              (LibrarySong song) =>
                  song.isRemote &&
                  (song.playCount > 0 ||
                      song.lastPlayedAt != null ||
                      _queueSongIds.contains(song.id)),
            )
            .toList()
          ..sort((LibrarySong a, LibrarySong b) {
            final DateTime left = a.lastPlayedAt ?? a.addedAt;
            final DateTime right = b.lastPlayedAt ?? b.addedAt;
            return right.compareTo(left);
          });
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'settings': _settings.toJson(),
        'sources': _sources,
        'songs': _songs.map((LibrarySong song) => song.toJson()).toList(),
        'transientSongs': transientSongs
            .take(200)
            .map((LibrarySong song) => song.toJson())
            .toList(),
        'playlists': _playlists
            .map((UserPlaylist playlist) => playlist.toJson())
            .toList(),
        'history': _history
            .where((PlaybackEntry entry) => songById(entry.songId) != null)
            .map((PlaybackEntry entry) => entry.toJson())
            .toList(),
      }),
    );
  }

  Future<File> _snapshotFile() async {
    final Directory root = await getApplicationSupportDirectory();
    return File(p.join(root.path, 'outer_tune_flutter_state.json'));
  }

  @override
  void dispose() {
    if (_isDisposed || _isDisposing) {
      return;
    }
    _isDisposing = true;
    _finalizeActivePlaybackSession();
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _ytMusic?.close();
    _yt.close();
    unawaited(_player.dispose());
    _isDisposed = true;
    super.dispose();
  }
}

class _FallbackTitle {
  const _FallbackTitle({required this.title, this.artist});

  final String title;
  final String? artist;
}

class _RecommendationQuery {
  const _RecommendationQuery({
    required this.title,
    required this.subtitle,
    required this.query,
    this.anchor,
  });

  final String title;
  final String subtitle;
  final String query;
  final LibrarySong? anchor;
}

class _TasteSignal {
  const _TasteSignal(this.label, this.score);

  final String label;
  final double score;
}

class _LanguageSignal {
  const _LanguageSignal({
    required this.label,
    required this.queryToken,
    required this.score,
  });

  final String label;
  final String queryToken;
  final double score;
}

class _ScoredSong {
  const _ScoredSong(this.song, this.score);

  final LibrarySong song;
  final double score;
}
