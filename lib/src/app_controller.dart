import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
import 'package:ytmusicapi_dart/auth/browser.dart' as ytm_browser;
import 'package:ytmusicapi_dart/ytmusicapi_dart.dart';
import 'package:ytmusicapi_dart/enums.dart' as ytm;

import 'android_media_notification_bridge.dart';
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
  StreamSubscription<String>? _notificationActionSubscription;
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
  bool _trendingNowLoading = false;
  bool _homeLoading = false;
  bool _smartQueueLoading = false;
  bool _isOffline = false;
  String? _statusMessage;
  String? _errorMessage;
  String? _onlineError;
  String? _trendingNowError;
  String? _homeError;
  String? _ytMusicAuthError;
  String _onlineQuery = '';
  int _onlineResultLimit = 0;
  bool _onlineHasMore = false;
  int _onlineSearchRequestId = 0;
  int _trendingNowRequestId = 0;

  AppSettings _settings = const AppSettings();
  List<String> _sources = <String>[];
  List<LibrarySong> _songs = <LibrarySong>[];
  List<UserPlaylist> _playlists = <UserPlaylist>[];
  List<PlaybackEntry> _history = <PlaybackEntry>[];
  List<LibrarySong> _onlineResults = <LibrarySong>[];
  List<LibrarySong> _trendingNowSongs = <LibrarySong>[];
  String _trendingNowRegionLabel = 'Your region';
  List<HomeFeedSection> _homeFeed = <HomeFeedSection>[];
  List<SongRecommendation> _personalizedHomeRecommendations =
      <SongRecommendation>[];
  int _homeQueryCursor = 0;
  final Set<String> _homeConsumedIdentityKeys = <String>{};
  final Set<String> _homeConsumedIds = <String>{};
  final Map<String, List<LibrarySong>> _searchCache =
      <String, List<LibrarySong>>{};
  final Map<String, List<LibrarySong>> _ytMusicSearchCache =
      <String, List<LibrarySong>>{};
  final Map<String, String?> _ytMusicVideoIdCache = <String, String?>{};
  final Map<String, String?> _ytMusicArtistImageCache = <String, String?>{};
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
  LibrarySong? _pendingSelectionSong;
  bool _hasPublishedPlaybackNotification = false;

  String? _lastTrackedSongId;

  bool get initialized => _initialized;
  bool get scanning => _scanning;
  bool get onlineLoading => _onlineLoading;
  bool get trendingNowLoading => _trendingNowLoading;
  bool get homeLoading => _homeLoading;
  bool get smartQueueLoading => _smartQueueLoading;
  bool get isOffline => _isOffline;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  String? get onlineError => _onlineError;
  String? get trendingNowError => _trendingNowError;
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
  List<LibrarySong> get trendingNowSongs =>
      List<LibrarySong>.unmodifiable(_trendingNowSongs);
  String get trendingNowRegionLabel => _trendingNowRegionLabel;
  List<AppRegion> get availableRegions =>
      List<AppRegion>.unmodifiable(kAppRegions);
  String get preferredCountryCode =>
      _normalizeCountryCode(_settings.preferredCountryCode);
  String get preferredRegionLabel =>
      _regionLabelFromCountryCode(preferredCountryCode);
  List<HomeFeedSection> get homeFeed =>
      List<HomeFeedSection>.unmodifiable(_homeFeed);
  List<SongRecommendation> get personalizedHomeRecommendations =>
      List<SongRecommendation>.unmodifiable(_personalizedHomeRecommendations);
  List<LibrarySong> get personalizedHomeSongs =>
      _personalizedHomeRecommendations
          .map((SongRecommendation item) => item.song)
          .toList(growable: false);
  List<UserPlaylist> get playlists =>
      List<UserPlaylist>.unmodifiable(_playlists);
  List<PlaybackEntry> get history => List<PlaybackEntry>.unmodifiable(_history);
  String get queueLabel => _queueLabel;
  int get queueIndex => _queueIndex;
  bool get hasHomeRecommendations =>
      _homeFeed.isNotEmpty || _personalizedHomeRecommendations.isNotEmpty;
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

  LibrarySong? get miniPlayerSong => _pendingSelectionSong ?? currentSong;
  bool get miniPlayerSelectionLoading {
    final LibrarySong? pending = _pendingSelectionSong;
    if (pending == null) {
      return false;
    }
    final LibrarySong? active = currentSong;
    return active == null || active.id != pending.id;
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

  List<LibrarySong> get likedSongs {
    final Map<String, LibrarySong> merged = <String, LibrarySong>{
      for (final LibrarySong song in _songs)
        if (song.isLiked) song.id: song,
      for (final LibrarySong song in _transientSongsById.values)
        if (song.isLiked) song.id: song,
    };
    final List<LibrarySong> result = merged.values.toList(growable: false);
    result.sort((LibrarySong a, LibrarySong b) {
      final int playCompare = b.playCount.compareTo(a.playCount);
      if (playCompare != 0) {
        return playCompare;
      }
      final DateTime left = a.lastPlayedAt ?? a.addedAt;
      final DateTime right = b.lastPlayedAt ?? b.addedAt;
      final int recentCompare = right.compareTo(left);
      if (recentCompare != 0) {
        return recentCompare;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return result;
  }

  List<LibrarySong> get dislikedSongs {
    final Map<String, LibrarySong> merged = <String, LibrarySong>{
      for (final LibrarySong song in _songs)
        if (song.isDisliked) song.id: song,
      for (final LibrarySong song in _transientSongsById.values)
        if (song.isDisliked) song.id: song,
    };
    final List<LibrarySong> result = merged.values.toList(growable: false);
    result.sort((LibrarySong a, LibrarySong b) {
      final DateTime left = a.lastPlayedAt ?? a.addedAt;
      final DateTime right = b.lastPlayedAt ?? b.addedAt;
      final int recentCompare = right.compareTo(left);
      if (recentCompare != 0) {
        return recentCompare;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
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
    await refreshConnectivityStatus(notify: false);
    await _player.setRate(_settings.playbackRate);
    // Never block app startup on Android runtime permission UI.
    unawaited(_ensureNotificationPermission());
    _bindNotificationActions();
    _attachPlayerListeners();
    _initialized = true;
    unawaited(AndroidMediaNotificationBridge.stop());
    notifyListeners();
    unawaited(refreshHomeFeed());
  }

  Future<bool> refreshConnectivityStatus({bool notify = true}) async {
    bool online;
    try {
      final List<InternetAddress> lookup = await InternetAddress.lookup(
        'youtube.com',
      ).timeout(const Duration(seconds: 3));
      online = lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } on SocketException {
      online = false;
    } on TimeoutException {
      online = false;
    } catch (_) {
      online = true;
    }
    _setOffline(!online, notify: notify);
    return online;
  }

  Future<void> _ensureNotificationPermission() async {
    if (!Platform.isAndroid) {
      return;
    }
    final PermissionStatus status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) {
      return;
    }
    await Permission.notification.request();
  }

  Future<void> ensureNotificationPermissionIfNeeded() async {
    await _ensureNotificationPermission();
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
      if (requestId == _onlineSearchRequestId) {
        _onlineLoading = false;
        notifyListeners();
      }
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

  Future<void> loadTrendingNow({
    required String languageCode,
    String? countryCode,
    bool force = false,
  }) async {
    final int requestId = ++_trendingNowRequestId;
    final String normalizedLanguage = languageCode.trim().toLowerCase();
    final String normalizedCountry =
        ((countryCode ?? '').trim().isEmpty ? 'LK' : countryCode!)
            .trim()
            .toUpperCase();
    final String languageToken = _localeLanguageQueryToken(normalizedLanguage);
    final String regionLabel = _regionLabelFromCountryCode(normalizedCountry);

    if (_trendingNowSongs.isNotEmpty &&
        !force &&
        !_trendingNowLoading &&
        _trendingNowRegionLabel == regionLabel) {
      return;
    }

    _trendingNowLoading = true;
    _trendingNowError = null;
    _trendingNowRegionLabel = regionLabel;
    notifyListeners();

    try {
      final List<String> queries = <String>[
        if (normalizedCountry.isNotEmpty)
          '$languageToken top songs in $regionLabel last month',
        if (normalizedCountry.isNotEmpty)
          'youtube music trending in $regionLabel last month',
        if (normalizedCountry == 'LK')
          'sinhala trending songs sri lanka last month',
        if (normalizedCountry == 'LK')
          'tamil trending songs sri lanka last month',
        '$languageToken viral songs last month',
        'youtube music charts $languageToken',
        'most popular songs last month',
      ];

      final List<LibrarySong> candidates = <LibrarySong>[];
      for (int index = 0; index < queries.length; index += 1) {
        final List<LibrarySong> results = await _searchSongs(
          queries[index],
          limit: 24,
          force: force || index > 0,
        );
        candidates.addAll(results);
      }

      if (requestId != _trendingNowRequestId) {
        return;
      }

      _trendingNowSongs = _rankTrendingNowCandidates(
        candidates,
        languageCode: normalizedLanguage,
        countryCode: normalizedCountry,
        limit: 18,
      );
      if (_trendingNowSongs.isEmpty) {
        _trendingNowError = 'Trending songs are unavailable right now.';
      }
    } catch (error) {
      if (requestId != _trendingNowRequestId) {
        return;
      }
      _trendingNowError = _friendlyOnlineError(error);
      _trendingNowSongs = <LibrarySong>[];
    } finally {
      if (requestId == _trendingNowRequestId) {
        _trendingNowLoading = false;
        notifyListeners();
      }
    }
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
      final bool online = await refreshConnectivityStatus(notify: false);
      if (!online) {
        _homeError = 'No internet connection. Reconnect and tap Refresh.';
        return;
      }
      await loadTrendingNow(
        languageCode: preferredLanguageCode,
        countryCode: preferredCountryCode,
        force: force,
      );
      final List<HomeFeedSection> previousFeed = List<HomeFeedSection>.from(
        _homeFeed,
      );
      final List<SongRecommendation> previousPersonalized =
          List<SongRecommendation>.from(_personalizedHomeRecommendations);
      final LibrarySong? seedSong = _primaryRecommendationSeed();
      final List<HomeFeedSection> sections = <HomeFeedSection>[];
      final Set<String> consumedIds = <String>{};
      final Set<String> consumedKeys = <String>{};

      if (seedSong != null) {
        final HomeFeedSection? radioSection = await _buildYtMusicRadioSection(
          seedSong,
          excludedIds: consumedIds,
        );
        if (radioSection != null) {
          sections.add(radioSection);
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
      );

      _homeFeed = expanded;
      _personalizedHomeRecommendations = _buildPersonalizedHomeSongs(
        sections: _homeFeed,
        seedSong: seedSong,
      );
      if (_homeFeed.isEmpty && _personalizedHomeRecommendations.isEmpty) {
        _homeFeed = previousFeed;
        _personalizedHomeRecommendations = previousPersonalized;
        _homeError = previousFeed.isEmpty
            ? 'No recommendations available right now.'
            : 'Recommendations could not be refreshed right now.';
      }
    } catch (error) {
      if (_isConnectivityError(error)) {
        _setOffline(true, notify: false);
      }
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
      _personalizedHomeRecommendations = _buildPersonalizedHomeSongs(
        sections: _homeFeed,
        seedSong: seedSong,
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
          songs: filtered.take(50).toList(growable: false),
        ),
      );
      onProgress?.call(sections);
    }

    _homeQueryCursor = recycledQueries ? cursor + queries.length : cursor;
    return sections;
  }

  void _publishHomeFeedProgress(List<HomeFeedSection> sections) {
    _homeFeed = List<HomeFeedSection>.from(sections);
    _personalizedHomeRecommendations = _buildPersonalizedHomeSongs(
      sections: _homeFeed,
      seedSong: _primaryRecommendationSeed(),
    );
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
      _setOffline(false, notify: false);
      _searchCache[cacheKey] = songs;
      return songs;
    } catch (error) {
      if (_isConnectivityError(error)) {
        _setOffline(true, notify: false);
      }
      try {
        final List<LibrarySong> fallback = await _searchYouTubeMusicOnly(
          trimmed,
          limit: limit,
          force: force,
        );
        _setOffline(false, notify: false);
        _searchCache[cacheKey] = fallback;
        return fallback;
      } catch (fallbackError) {
        if (_isConnectivityError(fallbackError)) {
          _setOffline(true, notify: false);
        }
        rethrow;
      }
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
      title: 'Inspired by ${anchor.title}',
      subtitle: 'Built from your recent listening and full-listen history',
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
      artworkUrl: _upgradeArtworkUrl(artworkUrl),
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

  List<LibrarySong> _rankTrendingNowCandidates(
    List<LibrarySong> songs, {
    required String languageCode,
    required String countryCode,
    required int limit,
  }) {
    final Set<String> seenKeys = <String>{};
    final String expectedLanguage = _localeToLanguageBucket(languageCode);
    final String rankingQuery =
        '$countryCode $languageCode last month top songs'.trim();
    final List<_ScoredSong> ranked = <_ScoredSong>[];

    for (final LibrarySong song in songs) {
      final String key = _songIdentityKey(song);
      if (!seenKeys.add(key)) {
        continue;
      }

      double score = _onlineSearchScore(song, query: rankingQuery);
      if (_detectSongLanguage(song) == expectedLanguage) {
        score += 7.5;
      }
      if ((song.artworkUrl ?? '').trim().isNotEmpty) {
        score += 2.2;
      }
      final int seconds = song.duration.inSeconds;
      if (seconds >= 120 && seconds <= 360) {
        score += 1.4;
      } else if (seconds > 0 && seconds < 75) {
        score -= 2.8;
      }
      ranked.add(_ScoredSong(song, score));
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

  String _localeLanguageQueryToken(String languageCode) {
    return switch (languageCode) {
      'si' => 'sinhala',
      'ta' => 'tamil',
      'hi' => 'hindi',
      'ur' => 'urdu',
      'bn' => 'bengali',
      'ja' => 'japanese',
      'ko' => 'korean',
      _ => 'english',
    };
  }

  String _localeToLanguageBucket(String languageCode) {
    return switch (languageCode) {
      'si' => 'si',
      'ta' => 'ta',
      'hi' => 'hi',
      'ur' => 'ur',
      'bn' => 'bn',
      'ja' => 'ja',
      'ko' => 'ko',
      _ => 'en',
    };
  }

  String _queryTokenToLanguageCode(String token) {
    return switch (token.trim().toLowerCase()) {
      'sinhala' => 'si',
      'tamil' => 'ta',
      'hindi' => 'hi',
      'urdu' => 'ur',
      'bengali' => 'bn',
      'japanese' => 'ja',
      'korean' => 'ko',
      _ => 'en',
    };
  }

  String _regionLabelFromCountryCode(String countryCode) {
    return switch (countryCode) {
      'LK' => 'Sri Lanka',
      'IN' => 'India',
      'PK' => 'Pakistan',
      'BD' => 'Bangladesh',
      'US' => 'United States',
      'GB' => 'United Kingdom',
      'CA' => 'Canada',
      'AU' => 'Australia',
      'JP' => 'Japan',
      'KR' => 'South Korea',
      _ => countryCode.isEmpty ? 'Your region' : countryCode,
    };
  }

  String _normalizeCountryCode(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return 'LK';
    }
    final AppRegion? matched = kAppRegions.firstWhereOrNull(
      (AppRegion region) => region.countryCode == normalized,
    );
    return matched?.countryCode ?? 'LK';
  }

  AppRegion get preferredRegion {
    final String code = preferredCountryCode;
    return kAppRegions.firstWhere(
      (AppRegion region) => region.countryCode == code,
      orElse: () => kAppRegions.first,
    );
  }

  String get preferredLanguageCode {
    final List<_LanguageSignal> historyLanguages =
        _preferredLanguagesFromValidHistory();
    if (historyLanguages.isNotEmpty) {
      return _queryTokenToLanguageCode(historyLanguages.first.queryToken);
    }
    return preferredRegion.languageCode;
  }

  Future<void> setPreferredRegion(String countryCode) async {
    final String normalized = _normalizeCountryCode(countryCode);
    if (normalized == preferredCountryCode) {
      return;
    }
    _settings = _settings.copyWith(preferredCountryCode: normalized);
    _trendingNowSongs = <LibrarySong>[];
    _trendingNowRegionLabel = _regionLabelFromCountryCode(normalized);
    _trendingNowError = null;
    await _saveSnapshot();
    notifyListeners();
    await loadTrendingNow(
      languageCode: preferredLanguageCode,
      countryCode: normalized,
      force: true,
    );
    await refreshHomeFeed(force: true);
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

  String? _readArtistResultName(Map<dynamic, dynamic> data) {
    final dynamic title = data['title'] ?? data['artist'] ?? data['name'];
    final String text = '$title'.trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }

    final dynamic artists = data['artists'];
    if (artists is List && artists.isNotEmpty) {
      final dynamic first = artists.first;
      if (first is Map) {
        final String candidate = '${first['name'] ?? first['title'] ?? ''}'
            .trim();
        if (candidate.isNotEmpty) {
          return candidate;
        }
      }
      final String candidate = '$first'.trim();
      if (candidate.isNotEmpty && candidate.toLowerCase() != 'null') {
        return candidate;
      }
    }
    return null;
  }

  String? _pickArtistImageUrl(
    List<dynamic> results, {
    required String artistName,
  }) {
    final String normalizedTarget = _normalizeToken(artistName);
    String? fallback;

    for (final dynamic item in results) {
      if (item is! Map) {
        continue;
      }
      final Map<dynamic, dynamic> data = item;
      fallback ??= _readThumbnailUrl(data);

      final String candidate = _normalizeToken(
        _readArtistResultName(data) ?? '',
      );
      if (candidate.isEmpty) {
        continue;
      }
      if (candidate == normalizedTarget ||
          candidate.contains(normalizedTarget) ||
          normalizedTarget.contains(candidate)) {
        final String? matched = _readThumbnailUrl(data);
        if ((matched ?? '').trim().isNotEmpty) {
          return matched;
        }
      }
    }

    return fallback;
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
      Map<dynamic, dynamic>? best;
      for (final dynamic item in thumbnails) {
        if (item is! Map || item['url'] == null) {
          continue;
        }
        if (best == null) {
          best = item;
          continue;
        }
        final int currentWidth = (item['width'] as num?)?.toInt() ?? 0;
        final int bestWidth = (best['width'] as num?)?.toInt() ?? 0;
        if (currentWidth > bestWidth) {
          best = item;
        }
      }
      best ??= thumbnails.last is Map && thumbnails.last['url'] != null
          ? thumbnails.last as Map<dynamic, dynamic>
          : null;
      if (best != null && best['url'] != null) {
        return _upgradeArtworkUrl('${best['url']}');
      }
    }
    return null;
  }

  String _upgradeArtworkUrl(String? url) {
    final String value = (url ?? '').trim();
    if (value.isEmpty) {
      return value;
    }
    // Prefer higher quality Google artwork where possible.
    if (value.contains('googleusercontent.com') ||
        value.contains('yt3.ggpht.com')) {
      final Uri uri = Uri.parse(value);
      final String path = uri.path.replaceAllMapped(
        RegExp(r'=w\d+-h\d+'),
        (Match m) => '=w600-h600',
      );
      final Map<String, String> params = Map<String, String>.from(
        uri.queryParameters,
      );
      if (params.containsKey('w')) {
        params['w'] = '600';
      }
      if (params.containsKey('h')) {
        params['h'] = '600';
      }
      final Uri upgraded = uri.replace(
        path: path,
        queryParameters: params.isEmpty ? null : params,
      );
      return upgraded.toString();
    }
    return value;
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
    final Set<String> excludedIds = <String>{
      ..._queueSongIds,
      anchor.id,
      ..._songs
          .where((LibrarySong song) => song.isDisliked)
          .map((LibrarySong song) => song.id),
    };
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
    final List<_LanguageSignal> languages =
        _preferredLanguagesFromValidHistory();
    final List<LibrarySong> fullListenSeeds = _validHistorySongs();
    final _SessionContext session = _sessionContext();
    final List<_RecommendationQuery> queries = <_RecommendationQuery>[];
    final String languageToken = _localeLanguageQueryToken(
      preferredLanguageCode,
    );

    void addQuery(_RecommendationQuery query) {
      final String key = query.query.trim().toLowerCase();
      if (key.isEmpty ||
          queries.any(
            (_RecommendationQuery item) =>
                item.query.trim().toLowerCase() == key,
          )) {
        return;
      }
      queries.add(query);
    }

    if (seedSong != null) {
      addQuery(
        _RecommendationQuery(
          title: 'Because you played ${seedSong.title}',
          subtitle: 'Closest match to what you are into right now',
          query: '${seedSong.artist} ${seedSong.title} similar songs',
          anchor: seedSong,
        ),
      );
      addQuery(
        _RecommendationQuery(
          title: 'More from ${seedSong.artist}',
          subtitle: 'Artists and songs adjacent to your recent play',
          query: '${seedSong.artist} popular songs',
          anchor: seedSong,
        ),
      );
    }

    for (final LibrarySong song in fullListenSeeds.take(2)) {
      if (seedSong != null && _sameSong(song, seedSong)) {
        continue;
      }
      addQuery(
        _RecommendationQuery(
          title: 'Because you finished ${song.title}',
          subtitle: 'Weighted by full listens, not just quick plays',
          query: '${song.artist} ${song.title} similar songs',
          anchor: song,
        ),
      );
    }

    for (final _TasteSignal artist in artists.take(2)) {
      addQuery(
        _RecommendationQuery(
          title: 'From your liked artists',
          subtitle: 'Artists you return to most often',
          query: '${artist.label} top songs',
        ),
      );
    }

    for (final _TasteSignal genre in genres.take(2)) {
      addQuery(
        _RecommendationQuery(
          title: '${genre.label} for you',
          subtitle: 'Genre picks driven by your listening patterns',
          query: '$languageToken ${genre.label} songs',
        ),
      );
    }

    for (final _LanguageSignal language in languages.take(1)) {
      addQuery(
        _RecommendationQuery(
          title: '${language.label} picks',
          subtitle: 'Matches the language you finish most',
          query: '${language.queryToken} songs you may like',
        ),
      );
    }

    addQuery(
      _RecommendationQuery(
        title: '${session.label} for you',
        subtitle: 'Session-aware music picked for this moment',
        query: '$languageToken ${session.query} songs',
        anchor: seedSong,
      ),
    );

    if (queries.isEmpty) {
      addQuery(
        _RecommendationQuery(
          title: 'Fresh discoveries',
          subtitle:
              'Start listening, liking, and finishing songs to personalize this section',
          query: '$languageToken best songs playlist',
        ),
      );
      addQuery(
        _RecommendationQuery(
          title: 'New for your library',
          subtitle:
              'A fallback shelf until your taste profile becomes stronger',
          query: '$languageToken new music songs',
        ),
      );
    }

    return queries;
  }

  List<SongRecommendation> _buildPersonalizedHomeSongs({
    required List<HomeFeedSection> sections,
    LibrarySong? seedSong,
  }) {
    final List<LibrarySong> fullListenSongs = _validHistorySongs();
    final _TasteProfile profile = _buildTasteProfile();
    final List<LibrarySong> sectionSongs = <LibrarySong>[
      for (final HomeFeedSection section in sections) ...section.songs.take(12),
    ];
    final Map<String, int> sectionHits = <String, int>{};
    final Map<String, HomeFeedSection> primarySectionBySong =
        <String, HomeFeedSection>{};
    final Set<String> recentIds = recentlyPlayedSongs
        .take(24)
        .map((LibrarySong song) => song.id)
        .toSet();
    final Set<String> recentKeys = recentlyPlayedSongs
        .take(24)
        .map(_songIdentityKey)
        .toSet();
    final Set<String> skippedSongIds = _recentSkippedSongIds();
    final Set<String> dislikedArtistKeys = dislikedSongs
        .map((LibrarySong song) => _normalizeToken(song.artist))
        .where((String key) => key.isNotEmpty)
        .toSet();
    final Map<String, int> recentArtistCounts = <String, int>{};

    for (final LibrarySong song in recentlyPlayedSongs.take(16)) {
      final String artistKey = _normalizeToken(song.artist);
      if (artistKey.isEmpty) {
        continue;
      }
      recentArtistCounts[artistKey] = (recentArtistCounts[artistKey] ?? 0) + 1;
    }

    for (final HomeFeedSection section in sections) {
      for (final LibrarySong song in section.songs.take(12)) {
        final String key = _songIdentityKey(song);
        sectionHits[key] = (sectionHits[key] ?? 0) + 1;
        primarySectionBySong.putIfAbsent(key, () => section);
      }
    }

    final Set<String> fullListenIds = validPlaybackHistory
        .map((PlaybackEntry entry) => entry.songId)
        .toSet();
    final Set<String> likedArtistKeys = likedSongs
        .map((LibrarySong song) => _normalizeToken(song.artist))
        .where((String key) => key.isNotEmpty)
        .toSet();
    final Set<String> fullListenArtistKeys = fullListenSongs
        .map((LibrarySong song) => _normalizeToken(song.artist))
        .where((String key) => key.isNotEmpty)
        .toSet();

    final List<LibrarySong> seedSongs = _dedupeSongs(
      <LibrarySong>[
        if (currentSong case final LibrarySong current) current,
        if (seedSong case final LibrarySong seed) seed,
        ...fullListenSongs.take(4),
        ...likedSongs.take(4),
      ],
      excludedIds: <String>{},
      limit: 10,
    );
    final List<LibrarySong> candidates = _dedupeSongs(
      sectionSongs
          .where((LibrarySong song) {
            if (song.isDisliked) {
              return false;
            }
            if (recentIds.contains(song.id) ||
                recentKeys.contains(_songIdentityKey(song)) ||
                skippedSongIds.contains(song.id)) {
              return false;
            }
            final String artistKey = _normalizeToken(song.artist);
            if (dislikedArtistKeys.contains(artistKey)) {
              return false;
            }
            if (seedSongs.any((LibrarySong seed) => _sameSong(seed, song))) {
              return false;
            }
            return true;
          })
          .toList(growable: false),
      excludedIds: <String>{},
      limit: 140,
    );

    final LibrarySong? anchor = seedSongs.firstOrNull;
    final List<_ScoredRecommendation> scored = candidates
        .map((LibrarySong song) {
          final String key = _songIdentityKey(song);
          final String artistKey = _normalizeToken(song.artist);
          double score = _recommendationScore(song, anchor: anchor);
          score += (sectionHits[key] ?? 0) * 5.5;
          if (profile.genreKeys.contains(_normalizeToken(song.genre ?? ''))) {
            score += 7;
          }
          if (profile.languageKeys.contains(_detectSongLanguage(song))) {
            score += 4.5;
          }
          if (profile.moodKeys.intersection(_vibeTokens(song)).isNotEmpty) {
            score += 5.5;
          }
          if (profile.prefersRecentYears && (song.year ?? 0) >= 2018) {
            score += 2.4;
          }
          if (!profile.prefersRecentYears &&
              song.year != null &&
              song.year! > 0 &&
              song.year! < 2016) {
            score += 2.4;
          }
          if (likedArtistKeys.contains(artistKey) ||
              fullListenArtistKeys.contains(artistKey)) {
            score += 6;
          }
          final int recentArtistCount = recentArtistCounts[artistKey] ?? 0;
          if (recentArtistCount >= 2) {
            score -= 5.5 * recentArtistCount;
          }
          if ((song.artworkUrl ?? '').trim().isNotEmpty) {
            score += 1.2;
          }
          if (song.sourceLabel == 'YouTube Music') {
            score += 1.8;
          }
          if (!fullListenIds.contains(song.id) &&
              !likedArtistKeys.contains(artistKey) &&
              !fullListenArtistKeys.contains(artistKey)) {
            score += 2.8;
          }
          final bool exploratory = _isExploratoryCandidate(
            song,
            profile: profile,
            artistKey: artistKey,
            fullListenArtistKeys: fullListenArtistKeys,
            likedArtistKeys: likedArtistKeys,
          );
          return _ScoredRecommendation(
            song: song,
            score: score,
            reason: _recommendationReason(
              song,
              profile: profile,
              exploratory: exploratory,
              section: primarySectionBySong[key],
              artistKey: artistKey,
              likedArtistKeys: likedArtistKeys,
              fullListenArtistKeys: fullListenArtistKeys,
            ),
            isExploratory: exploratory,
          );
        })
        .toList(growable: false);

    return _selectPersonalizedRecommendations(scored, limit: 50);
  }

  Set<String> _recentSkippedSongIds() {
    final Set<String> result = <String>{};
    for (final PlaybackEntry entry in _history.take(80)) {
      if (!entry.listenedToEnd && entry.completionRatio < 0.45) {
        result.add(entry.songId);
      }
    }
    return result;
  }

  _TasteProfile _buildTasteProfile() {
    final List<_TasteSignal> artists = _preferenceArtists();
    final List<_TasteSignal> genres = _preferenceGenres();
    final List<_LanguageSignal> languages =
        _preferredLanguagesFromValidHistory();
    final Map<String, double> moodScores = <String, double>{};

    for (final LibrarySong song in _rankedPreferenceSongs().take(40)) {
      final double weight = _songPreferenceWeight(song);
      for (final String mood in _vibeTokens(song)) {
        moodScores[mood] = (moodScores[mood] ?? 0) + weight;
      }
    }

    final List<MapEntry<String, double>> moods = moodScores.entries.toList()
      ..sort(
        (MapEntry<String, double> a, MapEntry<String, double> b) =>
            b.value.compareTo(a.value),
      );

    final List<int> years = _rankedPreferenceSongs()
        .map((LibrarySong song) => song.year)
        .whereType<int>()
        .where((int year) => year > 0)
        .take(30)
        .toList(growable: false);
    final double averageYear = years.isEmpty
        ? DateTime.now().year.toDouble()
        : years.reduce((int a, int b) => a + b) / years.length;

    return _TasteProfile(
      artistKeys: artists
          .take(5)
          .map((item) => _normalizeToken(item.label))
          .where((String key) => key.isNotEmpty)
          .toSet(),
      genreKeys: genres
          .take(4)
          .map((item) => _normalizeToken(item.label))
          .where((String key) => key.isNotEmpty)
          .toSet(),
      moodKeys: moods
          .take(3)
          .map((MapEntry<String, double> entry) => entry.key)
          .toSet(),
      languageKeys: languages
          .take(2)
          .map((item) => _detectLanguageBucket(item.queryToken))
          .toSet(),
      prefersRecentYears: averageYear >= 2018,
    );
  }

  String _detectLanguageBucket(String queryToken) {
    return switch (queryToken.trim().toLowerCase()) {
      'sinhala' => 'si',
      'tamil' => 'ta',
      'hindi' => 'hi',
      _ => 'en',
    };
  }

  bool _isExploratoryCandidate(
    LibrarySong song, {
    required _TasteProfile profile,
    required String artistKey,
    required Set<String> fullListenArtistKeys,
    required Set<String> likedArtistKeys,
  }) {
    final bool knownArtist =
        likedArtistKeys.contains(artistKey) ||
        fullListenArtistKeys.contains(artistKey) ||
        profile.artistKeys.contains(artistKey);
    final bool knownGenre = profile.genreKeys.contains(
      _normalizeToken(song.genre ?? ''),
    );
    final bool knownMood = profile.moodKeys
        .intersection(_vibeTokens(song))
        .isNotEmpty;
    return !knownArtist || (!knownGenre && !knownMood);
  }

  List<SongRecommendation> _selectPersonalizedRecommendations(
    List<_ScoredRecommendation> scored, {
    int limit = 50,
  }) {
    final List<_ScoredRecommendation> familiar =
        scored.where((item) => !item.isExploratory).toList(growable: false)
          ..sort(_compareScoredRecommendations);
    final List<_ScoredRecommendation> exploratory =
        scored.where((item) => item.isExploratory).toList(growable: false)
          ..sort(_compareScoredRecommendations);

    final Map<String, int> artistCounts = <String, int>{};
    final Set<String> seenKeys = <String>{};
    final List<SongRecommendation> result = <SongRecommendation>[];
    final int targetTotal = math.min(limit, scored.length);
    final int exploratoryTarget = math.min(
      exploratory.length,
      math.max(1, (targetTotal * 0.25).round()),
    );
    final int familiarTarget = math.max(0, targetTotal - exploratoryTarget);

    void addFrom(List<_ScoredRecommendation> pool, int target) {
      for (final _ScoredRecommendation item in pool) {
        if (result.length >= targetTotal || target <= 0) {
          return;
        }
        final String key = _songIdentityKey(item.song);
        final String artistKey = _normalizeToken(item.song.artist);
        if (!seenKeys.add(key)) {
          continue;
        }
        if ((artistCounts[artistKey] ?? 0) >= 2) {
          continue;
        }
        result.add(
          SongRecommendation(
            song: item.song,
            reason: item.reason,
            isExploratory: item.isExploratory,
          ),
        );
        artistCounts[artistKey] = (artistCounts[artistKey] ?? 0) + 1;
        target -= 1;
      }
    }

    addFrom(familiar, familiarTarget);
    addFrom(exploratory, exploratoryTarget);
    addFrom(
      <_ScoredRecommendation>[...familiar, ...exploratory]
        ..sort(_compareScoredRecommendations),
      targetTotal - result.length,
    );

    return result;
  }

  int _compareScoredRecommendations(
    _ScoredRecommendation a,
    _ScoredRecommendation b,
  ) {
    final int scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    return a.song.title.toLowerCase().compareTo(b.song.title.toLowerCase());
  }

  String _recommendationReason(
    LibrarySong song, {
    required _TasteProfile profile,
    required bool exploratory,
    required HomeFeedSection? section,
    required String artistKey,
    required Set<String> likedArtistKeys,
    required Set<String> fullListenArtistKeys,
  }) {
    if (likedArtistKeys.contains(artistKey) ||
        fullListenArtistKeys.contains(artistKey)) {
      return 'Artist match with your repeat listens';
    }
    final String genreKey = _normalizeToken(song.genre ?? '');
    if (profile.genreKeys.contains(genreKey) &&
        profile.moodKeys.intersection(_vibeTokens(song)).isNotEmpty) {
      return 'Genre and mood match for your listening pattern';
    }
    if (profile.languageKeys.contains(_detectSongLanguage(song))) {
      return exploratory
          ? 'Fresh pick in a language you finish often'
          : 'Language match from your full-listen history';
    }
    if (section != null && section.title.trim().isNotEmpty) {
      return exploratory
          ? 'Discovery pull from ${section.title}'
          : 'Strong fit surfaced in ${section.title}';
    }
    return exploratory
        ? 'Discovery pick close to your usual vibe'
        : 'Fits the sound you usually stay with';
  }

  bool _isConnectivityError(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return true;
    }
    final String message = '$error'.toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('socketexception');
  }

  void _setOffline(bool value, {bool notify = true}) {
    if (_isOffline == value) {
      return;
    }
    _isOffline = value;
    if (notify) {
      notifyListeners();
    }
  }

  List<_RecommendationQuery> _buildPredictionQueries(LibrarySong anchor) {
    final List<_TasteSignal> artists = _preferenceArtists();
    final List<_LanguageSignal> languages =
        _preferredLanguagesFromValidHistory();
    final _SessionContext session = _sessionContext();
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
        title: '${session.label} flow',
        subtitle: 'Auto queue',
        query: '${anchor.artist} ${session.query} songs',
        anchor: anchor,
      ),
    );

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
      if (song.isDisliked) {
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
    if (song.isLiked) {
      score += 10;
    }
    if (song.isDisliked) {
      score -= 50;
    }
    final String title = _normalizeToken(song.title);
    final String artist = _normalizeToken(song.artist);
    final String language = _detectSongLanguage(song);
    final _SessionContext session = _sessionContext();
    final Set<String> recentQueueArtists = _recentQueueArtistKeys();
    final Set<String> recentQueueSongs = _recentQueueSongKeys();

    if (anchor != null) {
      final String anchorTitle = _normalizeToken(anchor.title);
      final String anchorArtist = _normalizeToken(anchor.artist);
      final String anchorLanguage = _detectSongLanguage(anchor);
      if (artist == anchorArtist) {
        score += 9;
      } else if (artist.contains(anchorArtist) ||
          anchorArtist.contains(artist)) {
        score += 4;
      }

      if (title.contains(anchorTitle) || anchorTitle.contains(title)) {
        score -= 6;
      }
      if (language == anchorLanguage) {
        score += 2.4;
      }
      score += _vibeSimilarityScore(anchor, song);
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

    final double completionAffinity = _completionAffinity(song.id);
    score += completionAffinity * 8.5;
    if (completionAffinity < 0.25) {
      score -= 5.5;
    }

    // Psychology-inspired balance:
    // - Familiarity (known artists/songs) builds comfort.
    // - Novelty (new but adjacent songs) prevents boredom.
    score += _noveltyBalanceBoost(song, completionAffinity: completionAffinity);

    // Avoid fatigue from repeating same artist/song too tightly in queue.
    if (recentQueueArtists.contains(artist)) {
      score -= 7.2;
    }
    if (recentQueueSongs.contains(_songIdentityKey(song))) {
      score -= 12;
    }

    // Session-aware mood tuning (time/day context) similar to autoplay systems.
    if (_vibeTokens(song).contains(session.vibeToken)) {
      score += 2.6;
    }

    if (song.durationMs > 0) {
      score += 0.4;
      score += _durationContinuityBoost(song, anchor: anchor);
    }

    return score;
  }

  double _completionAffinity(String songId) {
    double total = 0;
    double weighted = 0;
    for (final PlaybackEntry entry in _history.take(220)) {
      if (entry.songId != songId) {
        continue;
      }
      final double weight = entry.listenedToEnd ? 1.4 : 1;
      total += weight;
      weighted += weight * entry.completionRatio.clamp(0, 1);
    }
    if (total <= 0) {
      return 0.5;
    }
    return (weighted / total).clamp(0, 1);
  }

  double _noveltyBalanceBoost(
    LibrarySong song, {
    required double completionAffinity,
  }) {
    final bool known = song.playCount > 0 || completionAffinity >= 0.65;
    final bool fresh = song.playCount == 0 && completionAffinity < 0.45;
    final double familiarityNeed = _familiarityNeed();
    if (known) {
      return 3.0 * familiarityNeed;
    }
    if (fresh) {
      return 3.0 * (1 - familiarityNeed);
    }
    return 1.2;
  }

  double _familiarityNeed() {
    final List<PlaybackEntry> recent = _history
        .take(30)
        .toList(growable: false);
    if (recent.isEmpty) {
      return 0.55;
    }
    final double avgCompletion =
        recent.fold<double>(
          0,
          (double sum, PlaybackEntry e) => sum + e.completionRatio,
        ) /
        recent.length;
    // If recent completion is low, lean more familiar.
    return (0.75 - (avgCompletion * 0.35)).clamp(0.35, 0.8);
  }

  Set<String> _recentQueueArtistKeys() {
    final int start = math.max(0, _queueIndex - 3);
    final int end = math.min(_queueSongIds.length, _queueIndex + 3);
    final Set<String> result = <String>{};
    for (int i = start; i < end; i += 1) {
      final LibrarySong? song = songById(_queueSongIds[i]);
      if (song == null) {
        continue;
      }
      result.add(_normalizeToken(song.artist));
    }
    return result;
  }

  Set<String> _recentQueueSongKeys() {
    final int start = math.max(0, _queueIndex - 3);
    final int end = math.min(_queueSongIds.length, _queueIndex + 3);
    final Set<String> result = <String>{};
    for (int i = start; i < end; i += 1) {
      final LibrarySong? song = songById(_queueSongIds[i]);
      if (song == null) {
        continue;
      }
      result.add(_songIdentityKey(song));
    }
    return result;
  }

  double _vibeSimilarityScore(LibrarySong anchor, LibrarySong candidate) {
    final Set<String> left = _vibeTokens(anchor);
    final Set<String> right = _vibeTokens(candidate);
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }
    final int overlap = left.intersection(right).length;
    return overlap * 1.7;
  }

  Set<String> _vibeTokens(LibrarySong song) {
    final String text =
        '${song.title} ${song.artist} ${song.album} ${song.genre ?? ''}'
            .toLowerCase();
    const Map<String, List<String>> map = <String, List<String>>{
      'chill': <String>['chill', 'calm', 'ambient', 'lofi', 'acoustic', 'soft'],
      'focus': <String>['focus', 'study', 'instrumental', 'piano'],
      'energy': <String>['party', 'dance', 'edm', 'remix', 'club', 'hype'],
      'sad': <String>['sad', 'heartbreak', 'broken', 'lonely'],
      'romance': <String>['love', 'romance', 'feel', 'kiss'],
      'devotional': <String>['worship', 'devotional', 'spiritual', 'bhakti'],
    };
    final Set<String> result = <String>{};
    for (final MapEntry<String, List<String>> entry in map.entries) {
      if (entry.value.any(text.contains)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  double _durationContinuityBoost(LibrarySong song, {LibrarySong? anchor}) {
    final int seconds = song.duration.inSeconds;
    if (seconds <= 0) {
      return 0;
    }
    if (anchor == null || anchor.duration.inSeconds <= 0) {
      return (seconds >= 120 && seconds <= 300) ? 1.2 : 0.2;
    }
    final int delta = (seconds - anchor.duration.inSeconds).abs();
    if (delta <= 40) {
      return 2.1;
    }
    if (delta <= 90) {
      return 1.1;
    }
    if (delta > 220) {
      return -0.8;
    }
    return 0;
  }

  _SessionContext _sessionContext() {
    final DateTime now = DateTime.now();
    final int hour = now.hour;
    final bool weekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (hour < 6) {
      return const _SessionContext(
        label: 'Late night',
        query: 'chill night',
        vibeToken: 'chill',
      );
    }
    if (hour < 11) {
      return const _SessionContext(
        label: 'Morning',
        query: 'fresh upbeat',
        vibeToken: 'focus',
      );
    }
    if (hour < 17) {
      return const _SessionContext(
        label: 'Daytime',
        query: 'focus vibe',
        vibeToken: 'focus',
      );
    }
    if (hour < 22) {
      return _SessionContext(
        label: weekend ? 'Weekend evening' : 'Evening',
        query: weekend ? 'party energy' : 'chill evening',
        vibeToken: weekend ? 'energy' : 'chill',
      );
    }
    return const _SessionContext(
      label: 'Night',
      query: 'mellow songs',
      vibeToken: 'chill',
    );
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
    final double total = scores.values.fold(
      0,
      (double sum, double v) => sum + v,
    );
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
      ..sort(
        (_LanguageSignal a, _LanguageSignal b) => b.score.compareTo(a.score),
      );
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
    if (song.isLiked) {
      score += 8;
    }
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
    _pendingSelectionSong = song;
    notifyListeners();
    try {
      await _player.stop();
      final LibrarySong prepared = await _preparePlayableSong(song);
      await _openPreparedSong(prepared, label: 'YouTube');
    } catch (_) {
      _pendingSelectionSong = null;
      notifyListeners();
      rethrow;
    }
  }

  void _attachPlayerListeners() {
    _subscriptions.add(
      _player.stream.playing.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _isPlaying = value as bool;
        _publishNotificationState();
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
        _publishNotificationState();
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _player.stream.duration.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _duration = value as Duration;
        _publishNotificationState();
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
        final LibrarySong? pending = _pendingSelectionSong;
        if (song != null && (pending == null || pending.id == song.id)) {
          _pendingSelectionSong = null;
        }
        if (song != null && song.id != _lastTrackedSongId) {
          _trackPlayback(song.id);
        }
        unawaited(_maybeExtendSmartQueue(seed: song, force: true));
        _publishNotificationState();
        notifyListeners();
      }),
    );
  }

  void _bindNotificationActions() {
    if (!AndroidMediaNotificationBridge.isSupported) {
      return;
    }
    _notificationActionSubscription?.cancel();
    _notificationActionSubscription =
        AndroidMediaNotificationBridge.actionStream().listen((String action) {
          if (AndroidMediaNotificationBridge.isToggleAction(action)) {
            unawaited(togglePlayback());
          } else if (AndroidMediaNotificationBridge.isNextAction(action)) {
            unawaited(nextTrack());
          } else if (AndroidMediaNotificationBridge.isPreviousAction(action)) {
            unawaited(previousTrack());
          }
        });
  }

  void _publishNotificationState() {
    final LibrarySong? song = currentSong;
    if (song == null) {
      _hasPublishedPlaybackNotification = false;
      unawaited(AndroidMediaNotificationBridge.stop());
      return;
    }

    if (_isPlaying) {
      _hasPublishedPlaybackNotification = true;
    }

    if (!_hasPublishedPlaybackNotification) {
      unawaited(AndroidMediaNotificationBridge.stop());
      return;
    }

    unawaited(
      AndroidMediaNotificationBridge.updatePlayback(
        song: song,
        isPlaying: _isPlaying,
        position: _position,
        duration: _duration,
      ),
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
    _trendingNowSongs = <LibrarySong>[];
    _trendingNowRegionLabel = 'Your region';
    _trendingNowError = null;
    _trendingNowLoading = false;
    _homeFeed = <HomeFeedSection>[];
    _personalizedHomeRecommendations = <SongRecommendation>[];
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
    final String artwork = _upgradeArtworkUrl(
      video.thumbnails.highResUrl.isNotEmpty
          ? video.thumbnails.highResUrl
          : video.thumbnails.standardResUrl,
    );
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
    _pendingSelectionSong = songs[safeIndex];
    notifyListeners();
    try {
      await _player.stop();
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
      unawaited(
        _maybeExtendSmartQueue(seed: preparedSongs[safeIndex], force: true),
      );
      notifyListeners();
    } catch (_) {
      _pendingSelectionSong = null;
      notifyListeners();
      rethrow;
    }
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

  Future<String?> resolveArtistImage(String artistName) async {
    final YTMusic? client = _ytMusic;
    final String normalized = _normalizeToken(artistName);
    if (normalized.isEmpty || client == null || _isDisposed || _isDisposing) {
      return null;
    }
    if (_ytMusicArtistImageCache.containsKey(normalized)) {
      return _ytMusicArtistImageCache[normalized];
    }

    String? resolved;
    try {
      final List<dynamic> artistResults = await client.search(
        artistName.trim(),
        filter: ytm.SearchFilter.artists,
        limit: 5,
      );
      resolved = _pickArtistImageUrl(artistResults, artistName: artistName);
      if ((resolved ?? '').trim().isEmpty) {
        final List<dynamic> profileResults = await client.search(
          artistName.trim(),
          filter: ytm.SearchFilter.profiles,
          limit: 5,
        );
        resolved = _pickArtistImageUrl(profileResults, artistName: artistName);
      }
    } catch (_) {
      resolved = null;
    }

    if (_isDisposed || _isDisposing) {
      return null;
    }
    final String upgraded = _upgradeArtworkUrl(resolved);
    _ytMusicArtistImageCache[normalized] = upgraded;
    return upgraded;
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
    _pendingSelectionSong = song;
    notifyListeners();
    _rememberTransientSong(song);
    try {
      _smartQueueSongIds.clear();
      _queueSongIds = <String>[song.id];
      _queueLabel = label;
      _queueIndex = 0;
      await _player.open(Playlist(<Media>[_mediaForSong(song)]));
      _trackPlayback(song.id);
      unawaited(_maybeExtendSmartQueue(seed: song, force: true));
      notifyListeners();
    } catch (_) {
      _pendingSelectionSong = null;
      notifyListeners();
      rethrow;
    }
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

  Future<void> reorderQueue(int from, int to) async {
    if (from < 0 ||
        to < 0 ||
        from >= _queueSongIds.length ||
        to >= _queueSongIds.length ||
        from == to) {
      return;
    }

    await _player.move(from, to);

    final String movedId = _queueSongIds.removeAt(from);
    _queueSongIds.insert(to, movedId);

    if (_queueIndex == from) {
      _queueIndex = to;
    } else if (from < _queueIndex && to >= _queueIndex) {
      _queueIndex -= 1;
    } else if (from > _queueIndex && to <= _queueIndex) {
      _queueIndex += 1;
    }

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

  Future<void> setCrossfadeSeconds(int seconds) async {
    const Set<int> allowed = <int>{0, 3, 5, 7};
    final int normalized = allowed.contains(seconds) ? seconds : 0;
    _settings = _settings.copyWith(crossfadeSeconds: normalized);
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> setGaplessPlayback(bool value) async {
    _settings = _settings.copyWith(gaplessPlayback: value);
    await _saveSnapshot();
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

  Future<void> likeSong(String songId) async {
    final LibrarySong? base = songById(songId);
    if (base == null) {
      return;
    }
    final bool newLiked = !base.isLiked;
    const bool newDisliked = false;
    _songs = _songs
        .map(
          (LibrarySong song) => song.id == songId
              ? song.copyWith(isLiked: newLiked, isDisliked: newDisliked)
              : song,
        )
        .toList();
    final LibrarySong? transient = _transientSongsById[songId];
    if (transient != null) {
      _transientSongsById[songId] = transient.copyWith(
        isLiked: newLiked,
        isDisliked: newDisliked,
      );
    }
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> dislikeSong(String songId) async {
    final LibrarySong? base = songById(songId);
    if (base == null) {
      return;
    }
    final bool newDisliked = !base.isDisliked;
    const bool newLiked = false;
    _songs = _songs
        .map(
          (LibrarySong song) => song.id == songId
              ? song.copyWith(isDisliked: newDisliked, isLiked: newLiked)
              : song,
        )
        .toList();
    final LibrarySong? transient = _transientSongsById[songId];
    if (transient != null) {
      _transientSongsById[songId] = transient.copyWith(
        isDisliked: newDisliked,
        isLiked: newLiked,
      );
    }
    await _saveSnapshot();
    notifyListeners();
  }

  void _rememberTransientSong(LibrarySong song) {
    if (song.isRemote) {
      final LibrarySong? existing = _transientSongsById[song.id];
      if (existing == null) {
        _transientSongsById[song.id] = song;
        return;
      }
      _transientSongsById[song.id] = song.copyWith(
        playCount: existing.playCount,
        lastPlayedAt: existing.lastPlayedAt,
        isLiked: existing.isLiked,
        isDisliked: existing.isDisliked,
      );
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
                      song.isLiked ||
                      song.isDisliked ||
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
    unawaited(_notificationActionSubscription?.cancel());
    _notificationActionSubscription = null;
    unawaited(AndroidMediaNotificationBridge.stop());
    _ytMusic?.close();
    _yt.close();
    unawaited(_player.stop());
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

class _SessionContext {
  const _SessionContext({
    required this.label,
    required this.query,
    required this.vibeToken,
  });

  final String label;
  final String query;
  final String vibeToken;
}

class _ScoredSong {
  const _ScoredSong(this.song, this.score);

  final LibrarySong song;
  final double score;
}

class _TasteProfile {
  const _TasteProfile({
    required this.artistKeys,
    required this.genreKeys,
    required this.moodKeys,
    required this.languageKeys,
    required this.prefersRecentYears,
  });

  final Set<String> artistKeys;
  final Set<String> genreKeys;
  final Set<String> moodKeys;
  final Set<String> languageKeys;
  final bool prefersRecentYears;
}

class _ScoredRecommendation {
  const _ScoredRecommendation({
    required this.song,
    required this.score,
    required this.reason,
    required this.isExploratory,
  });

  final LibrarySong song;
  final double score;
  final String reason;
  final bool isExploratory;
}
