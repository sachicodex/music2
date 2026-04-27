import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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

import '../services/firestore_user_data_service.dart';
import 'android_media_notification_bridge.dart';
import 'models.dart';
import 'playback_proxy.dart';
import 'streaming.dart';
import 'windows_media_controls_bridge.dart';

enum _AppNetworkUsageBucket { search, load, artwork, metadata }

class MusixController extends ChangeNotifier with WidgetsBindingObserver {
  MusixController({FirestoreUserDataService? firestoreUserDataService})
    : _yt = YoutubeExplode(),
      _firestoreUserDataService = firestoreUserDataService {
    WidgetsBinding.instance.addObserver(this);
  }
  static const int _smartQueueBatchSize = 7;
  static const Duration _minBrowsableSongDuration = Duration(seconds: 30);
  static const Duration _maxBrowsableSongDuration = Duration(minutes: 10);
  static const Duration _playbackActivationMinimumLoading = Duration(
    seconds: 1,
  );
  static const Duration _playbackActivationForcedStableDuration = Duration(
    seconds: 2,
  );

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

  Player? _playerInstance;
  bool _playerBound = false;
  final YoutubeExplode _yt;
  final FirestoreUserDataService? _firestoreUserDataService;
  late final PlaybackProxyServer _playbackProxy = PlaybackProxyServer(
    onBytesTransferred: _handlePlaybackProxyTransfer,
    onCacheProgress: _handlePlaybackProxyCacheProgress,
    onCacheCompleted: _handlePlaybackProxyCacheCompleted,
  );
  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<NowPlayingState> nowPlayingState =
      ValueNotifier<NowPlayingState>(const NowPlayingState());
  final ValueNotifier<PlaybackProgressState> playbackProgressState =
      ValueNotifier<PlaybackProgressState>(const PlaybackProgressState());
  final ValueNotifier<AppDataUsageStats> dataUsageState =
      ValueNotifier<AppDataUsageStats>(const AppDataUsageStats());
  StreamSubscription<String>? _notificationActionSubscription;
  StreamSubscription<String>? _windowsMediaActionSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<FirestoreUserData>? _cloudUserDataSubscription;
  Future<void>? _cloudUserDataLoadFuture;
  YTMusic? _ytMusic;
  final Uuid _uuid = const Uuid();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  final Map<String, LibrarySong> _transientSongsById = <String, LibrarySong>{};
  final Set<String> _cloudLikedSongIds = <String>{};
  final Set<String> _cloudDislikedSongIds = <String>{};
  final Set<String> _cloudSongHydrationInFlight = <String>{};
  final Map<String, String> _preparedMediaUrlsBySongId = <String, String>{};
  final Map<String, Map<String, String>?> _preparedMediaHeadersBySongId =
      <String, Map<String, String>?>{};
  final Map<String, List<PlaybackStreamCandidate>>
  _rankedPlaybackCandidatesBySongId = <String, List<PlaybackStreamCandidate>>{};
  final Map<String, PlaybackStreamInfo> _playbackStreamInfoBySongId =
      <String, PlaybackStreamInfo>{};
  final Map<String, int> _playbackCandidateIndexBySongId = <String, int>{};
  final Map<String, int> _songPlaybackBytes = <String, int>{};
  final Map<String, _ActivePlaybackProxy> _activePlaybackProxiesBySongId =
      <String, _ActivePlaybackProxy>{};
  final Set<String> _playbackProxyBypassSongIds = <String>{};
  bool _isDisposing = false;
  bool _isDisposed = false;

  bool _initialized = false;
  bool _startupContinuationScheduled = false;
  bool _scanning = false;
  bool _onlineLoading = false;
  bool _trendingNowLoading = false;
  bool _homeLoading = false;
  bool _smartQueueLoading = false;
  bool _isOffline = false;
  bool _startupOfflineMode = false;
  String? _statusMessage;
  String? _errorMessage;
  String? _cloudSyncMessage;
  String? _connectivityMessage;
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
  List<String> _autoSources = <String>[];
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
  final Map<String, String> _offlinePlaybackCachePaths = <String, String>{};
  final Map<String, int> _offlinePlaybackCacheSizesBySongId = <String, int>{};
  final Map<String, int> _offlinePlaybackCacheProgressBytesBySongId =
      <String, int>{};
  final Map<String, int> _offlinePlaybackCacheExpectedBytesBySongId =
      <String, int>{};
  final List<String> _offlinePlaybackCacheQueue = <String>[];
  final Set<String> _offlinePlaybackCacheQueuedSongIds = <String>{};
  final Set<String> _offlinePlaybackPrefetchInFlight = <String>{};
  String? _activePlaybackSongId;
  double _activePlaybackCompletionRatio = 0;
  DateTime? _lastAutoHomeRefreshAt;
  AppDataUsageStats _dataUsage = const AppDataUsageStats();
  Timer? _dataUsageSnapshotTimer;
  Timer? _playbackActivationTimer;
  bool _playbackFallbackRecoveryInFlight = false;
  String? _playbackFallbackRecoverySongId;
  int? _playbackFallbackRecoveryIndex;
  String? _playbackActivationSongId;
  DateTime? _playbackActivationStartedAt;
  bool _refreshingOfflinePlaybackCache = false;
  bool _offlinePlaybackCacheRefreshQueued = false;
  int _offlinePlaybackCacheEpoch = 0;
  bool _offlineQueueAdvancePending = false;
  bool _queueNavigationInFlight = false;
  String? _offlineQueueActivationTargetSongId;
  int? _offlineQueueActivationTargetIndex;
  List<String>? _offlineQueueActivationSongIds;
  String? _offlineQueueWaitingSongId;
  int? _offlineQueueWaitingIndex;
  Future<void>? _offlinePlaybackCacheWorker;
  bool _offlineDetachedQueueMode = false;
  String? _activeCloudUserId;
  bool _cloudUserDataLoaded = false;

  List<String> _queueSongIds = <String>[];
  String _queueLabel = 'Now Playing';
  int _queueIndex = 0;
  bool _isPlaying = false;
  bool _isShuffleEnabled = false;
  PlaylistMode _repeatMode = PlaylistMode.none;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  LibrarySong? _pendingSelectionSong;
  String? _startupMiniPlayerSongId;
  String? _transitioningSongId;
  int? _transitioningQueueIndex;
  bool _hasPublishedPlaybackNotification = false;
  String _searchDraft = '';
  List<String> _recentSearchTerms = <String>[];

  String? _lastTrackedSongId;

  Player get _player {
    final Player player = _playerInstance ??= Player();
    if (!_playerBound) {
      _playerBound = true;
      _attachPlayerListeners(player);
      _syncPlaybackNotifiers();
      unawaited(player.setRate(_settings.playbackRate));
    }
    return player;
  }

  bool get initialized => _initialized;
  bool get scanning => _scanning;
  bool get onlineLoading => _onlineLoading;
  bool get trendingNowLoading => _trendingNowLoading;
  bool get homeLoading => _homeLoading;
  bool get smartQueueLoading => _smartQueueLoading;
  bool get isOffline => _isOffline;
  bool get isOfflineViewActive => _startupOfflineMode || offlineMusicMode;
  bool get offlineMusicMode => _settings.offlineMusicMode;
  bool get offlinePlaybackCacheEnabled => true;
  int get offlinePlaybackCacheSongCount => _offlinePlaybackCachePaths.keys
      .toList(growable: false)
      .where(_hasOfflinePlaybackCache)
      .length;
  int get nextChanceSongCount => _settings.nextChanceSongCount;
  AppDataUsageStats get dataUsage => dataUsageState.value;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  String? get cloudSyncMessage => _cloudSyncMessage;
  String? get connectivityMessage => _connectivityMessage;
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
  List<LibrarySong> get browsableSongs => _filterSongsForBrowsing(_songs);
  List<LibrarySong> get onlineResults =>
      List<LibrarySong>.unmodifiable(_onlineResults);
  List<LibrarySong> get trendingNowSongs => List<LibrarySong>.unmodifiable(
    _filterSongsForBrowsing(_trendingNowSongs),
  );
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
  List<LibrarySong> get cachedSongs {
    final List<LibrarySong> result = _offlinePlaybackCachePaths.keys
        .toList(growable: false)
        .where(_hasOfflinePlaybackCache)
        .map(songById)
        .whereType<LibrarySong>()
        .toList(growable: false);
    result.sort((LibrarySong a, LibrarySong b) {
      final DateTime left = a.lastPlayedAt ?? a.addedAt;
      final DateTime right = b.lastPlayedAt ?? b.addedAt;
      return right.compareTo(left);
    });
    return result;
  }

  List<UserPlaylist> get playlists =>
      List<UserPlaylist>.unmodifiable(_playlists);
  List<PlaybackEntry> get history => List<PlaybackEntry>.unmodifiable(
    _history.where(
      (PlaybackEntry entry) => _shouldUseSongIdForHistorySignals(entry.songId),
    ),
  );
  String get searchDraft => _searchDraft;
  List<String> get recentSearchTerms =>
      List<String>.unmodifiable(_recentSearchTerms);
  String get queueLabel => _queueLabel;
  int get queueIndex => _queueIndex;
  bool get hasHomeRecommendations =>
      _homeFeed.isNotEmpty || _personalizedHomeRecommendations.isNotEmpty;
  bool get hasYtMusicAuth =>
      (_settings.ytMusicAuthJson?.trim().isNotEmpty ?? false);
  PlaybackStreamInfo? get currentPlaybackStreamInfo {
    final String? songId = miniPlayerSong?.id;
    if (songId == null) {
      return null;
    }
    return _playbackStreamInfoBySongId[songId];
  }

  List<LibrarySong> get queueSongs => _queueSongIds
      .map(songById)
      .whereType<LibrarySong>()
      .toList(growable: false);

  String? takeCloudSyncMessage() {
    final String? message = _cloudSyncMessage;
    _cloudSyncMessage = null;
    return message;
  }

  String? takeConnectivityMessage() {
    final String? message = _connectivityMessage;
    _connectivityMessage = null;
    return message;
  }

  List<String> get _playerQueueSongIds {
    final Player? player = _playerInstance;
    if (player == null) {
      return const <String>[];
    }
    return player.state.playlist.medias
        .map((Media media) => media.extras?['songId'] as String?)
        .whereType<String>()
        .toList(growable: false);
  }

  LibrarySong? get currentSong {
    if (_queueSongIds.isEmpty ||
        _queueIndex < 0 ||
        _queueIndex >= _queueSongIds.length) {
      return null;
    }
    return songById(_queueSongIds[_queueIndex]);
  }

  LibrarySong? get miniPlayerSong {
    final String? waitingSongId = _offlineQueueWaitingSongId;
    if (waitingSongId != null) {
      return songById(waitingSongId) ?? _pendingSelectionSong ?? currentSong;
    }
    final String? transitioningSongId = _transitioningSongId;
    if (transitioningSongId != null) {
      return songById(transitioningSongId) ??
          _pendingSelectionSong ??
          currentSong;
    }
    return _pendingSelectionSong ?? currentSong ?? _startupMiniPlayerSong;
  }

  LibrarySong? get startupSuggestionSong => _startupMiniPlayerSong;

  LibrarySong? get _startupMiniPlayerSong {
    final LibrarySong? lastPlayedSong = recentlyPlayedSongs.firstOrNull;
    if (lastPlayedSong != null) {
      _startupMiniPlayerSongId = lastPlayedSong.id;
      return lastPlayedSong;
    }

    final String? cachedSongId = _startupMiniPlayerSongId;
    if (cachedSongId != null) {
      final LibrarySong? cachedSong = songById(cachedSongId);
      if (cachedSong != null &&
          cachedSong.isRemote &&
          shouldShowSongOutsideSearch(cachedSong)) {
        return cachedSong;
      }
    }

    final List<LibrarySong> remoteSongs = <LibrarySong>[
      ..._songs.where(
        (LibrarySong song) =>
            song.isRemote && shouldShowSongOutsideSearch(song),
      ),
      ..._transientSongsById.values.where(
        (LibrarySong song) =>
            song.isRemote && shouldShowSongOutsideSearch(song),
      ),
    ];
    if (remoteSongs.isEmpty) {
      _startupMiniPlayerSongId = null;
      return null;
    }

    final LibrarySong randomSong =
        remoteSongs[math.Random().nextInt(remoteSongs.length)];
    _startupMiniPlayerSongId = randomSong.id;
    return randomSong;
  }

  bool shouldShowSongOutsideSearch(LibrarySong song) {
    final int durationMs = song.durationMs;
    if (durationMs <= 0) {
      return true;
    }
    return durationMs >= _minBrowsableSongDuration.inMilliseconds &&
        durationMs <= _maxBrowsableSongDuration.inMilliseconds;
  }

  bool _shouldCacheSongForOfflinePlayback(LibrarySong song) {
    return song.isRemote && shouldShowSongOutsideSearch(song);
  }

  List<LibrarySong> _filterSongsForBrowsing(Iterable<LibrarySong> songs) {
    return songs.where(shouldShowSongOutsideSearch).toList(growable: false);
  }

  List<HomeFeedSection> _filterHomeFeedSectionsForBrowsing(
    Iterable<HomeFeedSection> sections,
  ) {
    final List<HomeFeedSection> result = <HomeFeedSection>[];
    for (final HomeFeedSection section in sections) {
      final List<LibrarySong> songs = _filterSongsForBrowsing(section.songs);
      if (songs.isEmpty) {
        continue;
      }
      result.add(
        HomeFeedSection(
          title: section.title,
          subtitle: section.subtitle,
          query: section.query,
          songs: songs,
        ),
      );
    }
    return result;
  }

  void _dropRestrictedDurationOfflinePlaybackCacheEntry(String songId) {
    final LibrarySong? song = songById(songId);
    if (song == null || shouldShowSongOutsideSearch(song)) {
      return;
    }
    final String? path = _offlinePlaybackCachePaths[songId];
    _dropOfflinePlaybackCacheEntry(songId);
    if (path != null && path.trim().isNotEmpty) {
      unawaited(_deleteFileIfExists(path));
    }
  }

  void _purgeRestrictedDurationOfflinePlaybackCacheEntries() {
    for (final String songId in _offlinePlaybackCachePaths.keys.toList()) {
      _dropRestrictedDurationOfflinePlaybackCacheEntry(songId);
    }
  }

  bool get miniPlayerSelectionLoading {
    if (_playbackActivationSongId != null) {
      return true;
    }
    final LibrarySong? active = currentSong;
    final String? waitingSongId = _offlineQueueWaitingSongId;
    if (waitingSongId != null &&
        (active == null || active.id != waitingSongId)) {
      return true;
    }
    final String? transitioningSongId = _transitioningSongId;
    if (transitioningSongId != null &&
        (active == null || active.id != transitioningSongId)) {
      return true;
    }
    final LibrarySong? pending = _pendingSelectionSong;
    if (pending == null) {
      return false;
    }
    return active == null || active.id != pending.id;
  }

  bool _playerQueueHasControllerPlaylist() {
    if (_queueSongIds.isEmpty) {
      return false;
    }
    final List<String> playerQueueSongIds = _playerQueueSongIds;
    if (playerQueueSongIds.length != _queueSongIds.length) {
      return false;
    }
    for (int i = 0; i < _queueSongIds.length; i += 1) {
      if (playerQueueSongIds[i] != _queueSongIds[i]) {
        return false;
      }
    }
    return true;
  }

  bool _playerQueueMatchesControllerState() {
    if (!_playerQueueHasControllerPlaylist() ||
        _queueIndex < 0 ||
        _queueIndex >= _queueSongIds.length) {
      return false;
    }
    final List<String> playerQueueSongIds = _playerQueueSongIds;
    final int playerIndex = _player.state.playlist.index;
    return playerIndex >= 0 &&
        playerIndex < playerQueueSongIds.length &&
        playerQueueSongIds[playerIndex] == _queueSongIds[_queueIndex];
  }

  int? _activePlayerQueueIndex() {
    final List<String> playerQueueSongIds = _playerQueueSongIds;
    final int playerIndex = _player.state.playlist.index;
    if (playerIndex < 0 || playerIndex >= playerQueueSongIds.length) {
      return null;
    }
    return playerIndex;
  }

  bool _syncControllerQueueIndexToPlayer({bool notify = false}) {
    if (!_playerQueueHasControllerPlaylist()) {
      return false;
    }
    final int? playerIndex = _activePlayerQueueIndex();
    if (playerIndex == null || playerIndex == _queueIndex) {
      return false;
    }
    _debugPlayback(
      'player.queue sync immediate queueIndex=$_queueIndex -> $playerIndex',
    );
    _queueIndex = playerIndex;
    if (notify) {
      notifyListeners();
    }
    return true;
  }

  bool _playerHasLoadedCurrentSong(LibrarySong? song) {
    if (song == null) {
      return false;
    }
    final int? playerIndex = _activePlayerQueueIndex();
    if (playerIndex == null) {
      return false;
    }
    final List<String> playerQueueSongIds = _playerQueueSongIds;
    return playerQueueSongIds[playerIndex] == song.id;
  }

  bool _songHasImmediatePlaybackSource(LibrarySong song) {
    if (!songNeedsResolvedPlaybackUrl(song)) {
      return true;
    }
    if (_offlinePlaybackCachePathForSong(song.id) != null) {
      return true;
    }
    final String? prepared = _preparedMediaUrlsBySongId[song.id];
    return prepared != null && prepared.isNotEmpty && prepared != song.path;
  }

  Future<void> _primeStartupMiniPlayerPlayback() async {
    final LibrarySong? song = currentSong;
    if (song == null || !_songHasImmediatePlaybackSource(song)) {
      return;
    }
    try {
      await _preparePlayableSong(song);
      if (!_isDisposed && !_isDisposing) {
        notifyListeners();
      }
    } catch (error) {
      _debugPlayback(
        'startup.prime skipped song=${_debugSongLabel(song)} error=$error',
      );
    }
  }

  Future<bool> _resumeMiniPlayerPlaybackFallback() async {
    final LibrarySong? song = miniPlayerSong;
    if (song == null) {
      return false;
    }
    final String trimmedQueueLabel = _queueLabel.trim();
    final String label =
        trimmedQueueLabel.isEmpty || trimmedQueueLabel == 'Now Playing'
        ? 'Jump back in'
        : trimmedQueueLabel;
    await playSong(song, label: label);
    return true;
  }

  NowPlayingState _buildNowPlayingState() {
    final LibrarySong? song = miniPlayerSong;
    return NowPlayingState(
      song: song,
      isLoading: miniPlayerSelectionLoading,
      isShuffleEnabled: _isShuffleEnabled,
      repeatMode: _repeatMode,
      queueIndex: _queueIndex,
      queueLength: _queueSongIds.length,
      streamInfo: song == null ? null : _playbackStreamInfoBySongId[song.id],
    );
  }

  PlaybackProgressState _buildPlaybackProgressState() {
    return PlaybackProgressState(
      isPlaying: _isPlaying,
      position: _position,
      duration: _duration,
    );
  }

  void _syncPlaybackNotifiers() {
    if (_isDisposed) {
      return;
    }
    final NowPlayingState nextNowPlaying = _buildNowPlayingState();
    if (nowPlayingState.value != nextNowPlaying) {
      nowPlayingState.value = nextNowPlaying;
    }
    final PlaybackProgressState nextProgress = _buildPlaybackProgressState();
    if (playbackProgressState.value != nextProgress) {
      playbackProgressState.value = nextProgress;
    }
    _syncDataUsageState();
  }

  void _syncDataUsageState() {
    final String? songId = miniPlayerSong?.id ?? currentSong?.id;
    final (int currentCacheBytes, int currentCacheExpectedBytes) =
        songId == null ? (0, 0) : _currentSongCacheProgress(songId);
    final AppDataUsageStats next = _dataUsage.copyWith(
      totalBytes: _dataUsage.streamBytes + _dataUsage.otherBytes,
      cacheBytes: 0,
      currentSongId: songId,
      currentSongBytes: currentCacheBytes,
      currentCacheSongId: songId,
      currentCacheBytes: currentCacheBytes,
      currentCacheExpectedBytes: currentCacheExpectedBytes,
    );
    if (dataUsageState.value != next) {
      _dataUsage = next;
      dataUsageState.value = next;
    }
  }

  void _recordStreamBytes(String songId, int bytes) {
    if (bytes <= 0) {
      return;
    }
    _songPlaybackBytes.update(
      songId,
      (int value) => value + bytes,
      ifAbsent: () => bytes,
    );
    _dataUsage = _dataUsage.copyWith(
      totalBytes: _dataUsage.totalBytes + bytes,
      streamBytes: _dataUsage.streamBytes + bytes,
      lastUpdatedAt: DateTime.now(),
    );
    _syncDataUsageState();
    _scheduleSnapshotSave();
  }

  void _beginPlaybackActivation(
    LibrarySong? song, {
    bool resetMetrics = false,
    bool notify = true,
  }) {
    if (song == null) {
      return;
    }
    _playbackActivationSongId = song.id;
    _playbackActivationStartedAt = DateTime.now();
    _schedulePlaybackActivationCheck();
    if (resetMetrics) {
      _position = Duration.zero;
      _duration = Duration.zero;
    }
    if (notify) {
      notifyListeners();
    }
  }

  void _clearPlaybackActivation({bool notify = false}) {
    if (_playbackActivationSongId == null &&
        _playbackActivationStartedAt == null &&
        _playbackActivationTimer == null) {
      return;
    }
    _playbackActivationTimer?.cancel();
    _playbackActivationTimer = null;
    _playbackActivationSongId = null;
    _playbackActivationStartedAt = null;
    if (notify) {
      notifyListeners();
    }
  }

  void _maybeResolvePlaybackActivation({bool notify = false}) {
    final String? targetSongId = _playbackActivationSongId;
    if (targetSongId == null) {
      return;
    }
    if (!_hasPlaybackActivationMinimumElapsed()) {
      _schedulePlaybackActivationCheck();
      return;
    }
    if (!_isPlaybackActivationStable(targetSongId)) {
      _schedulePlaybackActivationCheck();
      return;
    }
    _clearPlaybackActivation(notify: notify);
  }

  Duration _playbackActivationElapsed() {
    final DateTime? startedAt = _playbackActivationStartedAt;
    if (startedAt == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(startedAt);
  }

  bool _hasPlaybackActivationMinimumElapsed() {
    return _playbackActivationElapsed() >= _playbackActivationMinimumLoading;
  }

  bool _hasPlaybackActivationForcedStableElapsed() {
    return _playbackActivationElapsed() >=
        _playbackActivationForcedStableDuration;
  }

  bool _isPlaybackActivationStable(String targetSongId) {
    if (_playbackFallbackRecoveryInFlight ||
        _playbackFallbackRecoverySongId != null ||
        _offlineQueueWaitingSongId != null ||
        _offlineQueueActivationTargetSongId != null ||
        _shouldHoldTransitionMetrics()) {
      return false;
    }
    final LibrarySong? active = currentSong;
    if (active == null ||
        active.id != targetSongId ||
        !_playerHasLoadedCurrentSong(active) ||
        !_isPlaying) {
      return false;
    }
    if (_position > Duration.zero) {
      return true;
    }
    if (!_hasPlaybackActivationForcedStableElapsed()) {
      return false;
    }
    return _duration > Duration.zero || _playerHasLoadedCurrentSong(active);
  }

  void _schedulePlaybackActivationCheck() {
    _playbackActivationTimer?.cancel();
    _playbackActivationTimer = null;
    if (_isDisposed || _isDisposing || _playbackActivationSongId == null) {
      return;
    }
    final Duration elapsed = _playbackActivationElapsed();
    Duration? delay;
    if (elapsed < _playbackActivationMinimumLoading) {
      delay = _playbackActivationMinimumLoading - elapsed;
    } else if (elapsed < _playbackActivationForcedStableDuration) {
      delay = _playbackActivationForcedStableDuration - elapsed;
    } else {
      delay = const Duration(milliseconds: 220);
    }
    if (delay <= Duration.zero) {
      return;
    }
    _playbackActivationTimer = Timer(delay, () {
      if (_isDisposed || _isDisposing) {
        return;
      }
      _maybeResolvePlaybackActivation(notify: true);
    });
  }

  void _recordOtherUsage({
    int searchBytes = 0,
    int loadBytes = 0,
    int artworkBytes = 0,
    int metadataBytes = 0,
  }) {
    final int safeSearchBytes = math.max(0, searchBytes);
    final int safeLoadBytes = math.max(0, loadBytes);
    final int safeArtworkBytes = math.max(0, artworkBytes);
    final int safeMetadataBytes = math.max(0, metadataBytes);
    final int totalIncrement =
        safeSearchBytes + safeLoadBytes + safeArtworkBytes + safeMetadataBytes;
    if (totalIncrement <= 0) {
      return;
    }
    _dataUsage = _dataUsage.copyWith(
      totalBytes: _dataUsage.totalBytes + totalIncrement,
      searchBytes: _dataUsage.searchBytes + safeSearchBytes,
      loadBytes: _dataUsage.loadBytes + safeLoadBytes,
      artworkBytes: _dataUsage.artworkBytes + safeArtworkBytes,
      metadataBytes: _dataUsage.metadataBytes + safeMetadataBytes,
      lastUpdatedAt: DateTime.now(),
    );
    _syncDataUsageState();
    _scheduleSnapshotSave();
  }

  int _estimateUsagePayloadBytes(Object? payload) {
    final Object? normalized = _normalizeUsagePayload(payload);
    return utf8.encode(jsonEncode(normalized)).length;
  }

  Object? _normalizeUsagePayload(Object? payload) {
    if (payload == null ||
        payload is num ||
        payload is bool ||
        payload is String) {
      return payload;
    }
    if (payload is DateTime) {
      return payload.toIso8601String();
    }
    if (payload is LibrarySong) {
      return payload.toJson();
    }
    if (payload is PlaybackStreamCandidate) {
      return <String, dynamic>{
        'transport': payload.transport.name,
        'url': payload.url,
        'bitrateBitsPerSecond': payload.bitrateBitsPerSecond,
        'streamTag': payload.streamTag,
        'videoHeight': payload.videoHeight,
        'qualityLabel': payload.qualityLabel,
        'containerName': payload.containerName,
        'codecDescription': payload.codecDescription,
        'audioCodec': payload.audioCodec,
        'videoCodec': payload.videoCodec,
      };
    }
    if (payload is Map<Object?, Object?>) {
      return <String, Object?>{
        for (final MapEntry<Object?, Object?> entry in payload.entries)
          '${entry.key}': _normalizeUsagePayload(entry.value),
      };
    }
    if (payload is Iterable<Object?>) {
      return payload.map(_normalizeUsagePayload).toList(growable: false);
    }
    return '$payload';
  }

  int _estimateArtworkUsageBytesFromSongs(Iterable<LibrarySong> songs) {
    final List<String> artworkUrls = songs
        .map((LibrarySong song) => (song.artworkUrl ?? '').trim())
        .where((String url) => url.isNotEmpty)
        .toList(growable: false);
    if (artworkUrls.isEmpty) {
      return 0;
    }
    return _estimateUsagePayloadBytes(artworkUrls);
  }

  void _recordSongCollectionUsage(
    Iterable<LibrarySong> songs, {
    required _AppNetworkUsageBucket bucket,
    String? query,
  }) {
    final List<LibrarySong> materialized = songs.toList(growable: false);
    if (materialized.isEmpty) {
      return;
    }
    final int artworkBytes = _estimateArtworkUsageBytesFromSongs(materialized);
    final int totalBytes = _estimateUsagePayloadBytes(<String, Object?>{
      'query': query,
      'songs': materialized.map((LibrarySong song) => song.toJson()).toList(),
    });
    final int bucketBytes = math.max(0, totalBytes - artworkBytes);
    switch (bucket) {
      case _AppNetworkUsageBucket.search:
        _recordOtherUsage(searchBytes: bucketBytes, artworkBytes: artworkBytes);
      case _AppNetworkUsageBucket.load:
        _recordOtherUsage(loadBytes: bucketBytes, artworkBytes: artworkBytes);
      case _AppNetworkUsageBucket.artwork:
        _recordOtherUsage(artworkBytes: totalBytes);
      case _AppNetworkUsageBucket.metadata:
        _recordOtherUsage(metadataBytes: totalBytes);
    }
  }

  void _handlePlaybackProxyTransfer(PlaybackProxyTransfer transfer) {
    if (_isDisposed || _isDisposing) {
      return;
    }
  }

  void _handlePlaybackProxyCacheProgress(PlaybackProxyCacheProgress progress) {
    if (_isDisposed || _isDisposing) {
      return;
    }
    _updateOfflinePlaybackCacheProgress(
      songId: progress.songId,
      bytesWritten: progress.bytesWritten,
      expectedBytes: progress.expectedBytes,
    );
  }

  void _handlePlaybackProxyCacheCompleted(PlaybackProxyCacheResult result) {
    if (_isDisposed || _isDisposing) {
      return;
    }
    if (result.cacheEpoch != _offlinePlaybackCacheEpoch) {
      unawaited(_deleteFileIfExists(result.cachedFilePath));
      return;
    }
    _offlinePlaybackCachePaths[result.songId] = result.cachedFilePath;
    final File cachedFile = File(result.cachedFilePath);
    if (cachedFile.existsSync()) {
      _offlinePlaybackCacheSizesBySongId[result.songId] = cachedFile
          .lengthSync();
    }
    final int completedSize =
        _offlinePlaybackCacheSizesBySongId[result.songId] ?? 0;
    if (completedSize > 0) {
      _offlinePlaybackCacheProgressBytesBySongId[result.songId] = completedSize;
      _offlinePlaybackCacheExpectedBytesBySongId[result.songId] = completedSize;
    }
    _preparedMediaUrlsBySongId[result.songId] = result.cachedFilePath;
    _preparedMediaHeadersBySongId[result.songId] = null;
    final LibrarySong? song = songById(result.songId);
    if (song != null) {
      _playbackStreamInfoBySongId[result.songId] =
          buildCachedPlaybackStreamInfo(
            song: song,
            cachedPath: result.cachedFilePath,
            previousInfo: _playbackStreamInfoBySongId[result.songId],
          );
      _updateOfflinePlaybackCacheProgress(
        songId: result.songId,
        bytesWritten: completedSize,
        expectedBytes: completedSize,
      );
    }
    unawaited(_saveSnapshot());
    notifyListeners();
  }

  void _scheduleSnapshotSave() {
    _dataUsageSnapshotTimer?.cancel();
    _dataUsageSnapshotTimer = Timer(const Duration(milliseconds: 700), () {
      if (_isDisposing || _isDisposed) {
        return;
      }
      unawaited(_saveSnapshot());
    });
  }

  Future<void> _clearPreparedPlaybackState() async {
    final List<String> sessionIds = _activePlaybackProxiesBySongId.values
        .map((_ActivePlaybackProxy item) => item.sessionId)
        .toList(growable: false);
    _activePlaybackProxiesBySongId.clear();
    _playbackProxyBypassSongIds.clear();
    _preparedMediaUrlsBySongId.clear();
    _preparedMediaHeadersBySongId.clear();
    _rankedPlaybackCandidatesBySongId.clear();
    _playbackCandidateIndexBySongId.clear();
    _playbackStreamInfoBySongId.clear();
    _songPlaybackBytes.clear();
    _playbackFallbackRecoveryInFlight = false;
    _playbackFallbackRecoverySongId = null;
    _playbackFallbackRecoveryIndex = null;
    _clearPlaybackActivation();
    for (final String sessionId in sessionIds) {
      unawaited(_playbackProxy.unregister(sessionId));
    }
    _syncDataUsageState();
  }

  @override
  void notifyListeners() {
    _syncPlaybackNotifiers();
    super.notifyListeners();
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
    if (_isOffline ||
        offlineMusicMode ||
        (!_settings.smartQueueEnabled && !force) ||
        _smartQueueLoading) {
      return;
    }

    final LibrarySong? queuedAnchor = queueSongs.lastOrNull;
    final LibrarySong? current = currentSong;
    final LibrarySong? anchor =
        (seed != null && seed.isRemote && shouldShowSongOutsideSearch(seed))
        ? seed
        : (queuedAnchor != null &&
              queuedAnchor.isRemote &&
              shouldShowSongOutsideSearch(queuedAnchor))
        ? queuedAnchor
        : (current != null &&
              current.isRemote &&
              shouldShowSongOutsideSearch(current))
        ? current
        : null;
    if (anchor == null) {
      return;
    }

    await _appendSmartQueuePredictions(anchor, limit: batchSize);
  }

  bool _hasOfflinePlaybackCache(String songId) {
    if (!offlinePlaybackCacheEnabled) {
      return false;
    }
    final LibrarySong? song = songById(songId);
    if (song != null && !shouldShowSongOutsideSearch(song)) {
      return false;
    }
    final String? path = _offlinePlaybackCachePaths[songId];
    if (path == null || path.isEmpty) {
      return false;
    }
    if (_isOfflinePlaybackCacheFileUsable(path)) {
      return true;
    }
    _dropOfflinePlaybackCacheEntry(songId);
    return false;
  }

  String? _offlinePlaybackCachePathForSong(String songId) {
    if (!offlinePlaybackCacheEnabled) {
      return null;
    }
    final LibrarySong? song = songById(songId);
    if (song != null && !shouldShowSongOutsideSearch(song)) {
      return null;
    }
    final String? path = _offlinePlaybackCachePaths[songId];
    if (path == null || path.isEmpty) {
      return null;
    }
    if (_isOfflinePlaybackCacheFileUsable(path)) {
      return path;
    }
    _dropOfflinePlaybackCacheEntry(songId);
    return null;
  }

  bool _isOfflinePlaybackCacheFileUsable(String path) {
    if (path.trim().isEmpty) {
      return false;
    }
    final File file = File(path);
    if (!file.existsSync()) {
      return false;
    }
    final String extension = p.extension(path).toLowerCase();
    if (extension == '.m3u8' || extension == '.m3u') {
      return false;
    }
    return file.lengthSync() > 0;
  }

  void _dropOfflinePlaybackCacheEntry(String songId) {
    _offlinePlaybackCachePaths.remove(songId);
    _offlinePlaybackCacheSizesBySongId.remove(songId);
    _offlinePlaybackCacheProgressBytesBySongId.remove(songId);
    _offlinePlaybackCacheExpectedBytesBySongId.remove(songId);
  }

  List<LibrarySong> get recentlyAddedSongs {
    final List<LibrarySong> result = _filterSongsForBrowsing(_songs);
    result.sort(
      (LibrarySong a, LibrarySong b) => b.addedAt.compareTo(a.addedAt),
    );
    return result;
  }

  List<LibrarySong> get favoriteSongs {
    final List<LibrarySong> result = _songs
        .where(
          (LibrarySong song) =>
              song.isFavorite && shouldShowSongOutsideSearch(song),
        )
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
    final List<LibrarySong> result = _filterSongsForBrowsing(merged.values);
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
    final List<LibrarySong> result = _filterSongsForBrowsing(merged.values);
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
    final List<LibrarySong> result = _songs
        .where(_shouldUseSongForHistorySignals)
        .toList(growable: false);
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
        if (song != null && _shouldUseSongForHistorySignals(song)) {
          result.add(song);
        }
      }
    }
    final List<LibrarySong> fallbackSongs =
        <LibrarySong>[..._songs, ..._transientSongsById.values]
            .where(
              (LibrarySong song) =>
                  _shouldUseSongForHistorySignals(song) &&
                  (song.playCount > 0 || song.lastPlayedAt != null),
            )
            .toList(growable: false)
          ..sort((LibrarySong a, LibrarySong b) {
            final DateTime left = a.lastPlayedAt ?? a.addedAt;
            final DateTime right = b.lastPlayedAt ?? b.addedAt;
            final int recentCompare = right.compareTo(left);
            if (recentCompare != 0) {
              return recentCompare;
            }
            return b.playCount.compareTo(a.playCount);
          });
    for (final LibrarySong song in fallbackSongs) {
      if (seen.add(song.id)) {
        result.add(song);
      }
    }
    return result;
  }

  void cacheSearchDraft(String value) {
    _searchDraft = value;
  }

  void clearSearchState({bool clearRecentSearches = false}) {
    _onlineSearchRequestId += 1;
    _searchDraft = '';
    _onlineResults = <LibrarySong>[];
    _onlineError = null;
    _onlineLoading = false;
    _onlineQuery = '';
    _onlineResultLimit = 0;
    _onlineHasMore = false;
    if (clearRecentSearches) {
      _recentSearchTerms = <String>[];
    }
    _scheduleSnapshotSave();
    notifyListeners();
  }

  void rememberRecentSearch(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _recentSearchTerms = <String>[
      trimmed,
      ..._recentSearchTerms.where(
        (String item) => item.toLowerCase() != trimmed.toLowerCase(),
      ),
    ].take(8).toList(growable: false);
    _scheduleSnapshotSave();
  }

  void removeRecentSearch(String value) {
    _recentSearchTerms = _recentSearchTerms
        .where((String item) => item != value)
        .toList(growable: false);
    _scheduleSnapshotSave();
  }

  List<PlaybackEntry> get validPlaybackHistory => _history
      .where(
        (PlaybackEntry entry) =>
            _shouldUseSongIdForHistorySignals(entry.songId) &&
            (entry.listenedToEnd || entry.completionRatio >= 0.88),
      )
      .toList(growable: false);

  List<LibrarySong> get _decisionLikedSongs => likedSongs
      .where((LibrarySong song) => song.isRemote)
      .toList(growable: false);

  List<LibrarySong> get _decisionDislikedSongs => dislikedSongs
      .where((LibrarySong song) => song.isRemote)
      .toList(growable: false);

  bool _shouldUseSongForHistorySignals(LibrarySong song) {
    return song.isRemote && shouldShowSongOutsideSearch(song);
  }

  bool _shouldUseSongIdForHistorySignals(String songId) {
    final LibrarySong? song = songById(songId);
    return song != null && _shouldUseSongForHistorySignals(song);
  }

  void _prunePlaybackHistory() {
    _history = _history
        .where(
          (PlaybackEntry entry) =>
              _shouldUseSongIdForHistorySignals(entry.songId),
        )
        .take(300)
        .toList(growable: false);
  }

  List<AlbumCollection> get albums {
    final Map<String, List<LibrarySong>> grouped =
        <String, List<LibrarySong>>{};
    for (final LibrarySong song in browsableSongs) {
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
    for (final LibrarySong song in browsableSongs) {
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
    for (final LibrarySong song in browsableSongs) {
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
    if (_initialized) {
      return;
    }
    await _loadSnapshot();
    _player;
    unawaited(_primeStartupMiniPlayerPlayback());
    // Never block app startup on Android runtime permission UI.
    unawaited(_ensureNotificationPermission());
    _bindNotificationActions();
    _initialized = true;
    unawaited(AndroidMediaNotificationBridge.stop());
    unawaited(WindowsMediaControlsBridge.stop());
    notifyListeners();
    _scheduleStartupContinuation();
  }

  Future<void> loadUserDataFromCloud({bool force = false}) {
    final Future<void>? activeLoad = _cloudUserDataLoadFuture;
    if (activeLoad != null) {
      return activeLoad;
    }

    final Future<void> loadFuture = _loadUserDataFromCloud(force: force);
    _cloudUserDataLoadFuture = loadFuture;
    return loadFuture.whenComplete(() {
      if (identical(_cloudUserDataLoadFuture, loadFuture)) {
        _cloudUserDataLoadFuture = null;
      }
    });
  }

  Future<void> _loadUserDataFromCloud({bool force = false}) async {
    final FirestoreUserDataService? service = _firestoreUserDataService;
    if (service == null) {
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    final String? userId = service.currentUserId;
    if (userId == null) {
      await clearUserDataFromCloud();
      return;
    }

    if (!service.supportsCloudSync) {
      if (_activeCloudUserId != userId || !_cloudUserDataLoaded) {
        _queueCloudSyncMessage(
          'Cloud sync is temporarily disabled on Windows. Local music data is still available.',
        );
      }
      _activeCloudUserId = userId;
      _cloudUserDataLoaded = true;
      notifyListeners();
      return;
    }

    if (!force &&
        _activeCloudUserId == userId &&
        _cloudUserDataLoaded &&
        _cloudUserDataSubscription != null) {
      return;
    }

    try {
      await service.ensureCurrentUserDocument();
      final FirestoreUserData userData = await service.loadCurrentUserData();
      if (_isDisposed || _isDisposing || service.currentUserId != userId) {
        return;
      }
      _activeCloudUserId = userId;
      _cloudUserDataLoaded = true;
      _applyCloudUserData(userData);
      await _startCloudUserDataSubscription(userId);
      _homeFeed = <HomeFeedSection>[];
      _personalizedHomeRecommendations = <SongRecommendation>[];
      await _saveSnapshot();
      notifyListeners();
      if (!_isOffline && !offlineMusicMode) {
        _requestAutoHomeRefresh(force: true);
      }
    } on FirestoreUserDataException catch (error) {
      if (_isDisposed || _isDisposing || service.currentUserId != userId) {
        return;
      }
      _queueCloudSyncMessage(error.message);
      notifyListeners();
    } catch (error) {
      if (_isDisposed || _isDisposing || service.currentUserId != userId) {
        return;
      }
      _queueCloudSyncMessage(
        'Could not load your Firestore library. Local data is still available.',
      );
      debugPrint('Firestore user data load failed: $error');
      notifyListeners();
    }
  }

  Future<void> clearUserDataFromCloud() async {
    _cloudUserDataLoadFuture = null;
    await _cloudUserDataSubscription?.cancel();
    _cloudUserDataSubscription = null;
    _applyCloudUserData(const FirestoreUserData.empty());
    _activeCloudUserId = null;
    _cloudUserDataLoaded = false;
    _homeFeed = <HomeFeedSection>[];
    _personalizedHomeRecommendations = <SongRecommendation>[];
    await _saveSnapshot();
    notifyListeners();
  }

  void _applyCloudUserData(FirestoreUserData userData) {
    final Set<String> dislikedSongIds = Set<String>.from(
      userData.dislikedSongIds,
    );
    final Set<String> likedSongIds = Set<String>.from(userData.likedSongIds)
      ..removeAll(dislikedSongIds);
    _cloudLikedSongIds
      ..clear()
      ..addAll(likedSongIds);
    _cloudDislikedSongIds
      ..clear()
      ..addAll(dislikedSongIds);

    _songs = _songs.map(_withCloudPreferenceState).toList(growable: false);
    _transientSongsById.updateAll(
      (_, LibrarySong song) => _withCloudPreferenceState(song),
    );
    _playlists = userData.playlists.toList(growable: false)
      ..sort(_sortUserPlaylists);
    unawaited(
      _hydrateMissingCloudSongs(
        songIds: userData.playlists.expand(
          (UserPlaylist playlist) => playlist.songIds,
        ),
      ),
    );
  }

  int _sortUserPlaylists(UserPlaylist a, UserPlaylist b) {
    final int updatedCompare = b.updatedAt.compareTo(a.updatedAt);
    if (updatedCompare != 0) {
      return updatedCompare;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  void _queueCloudSyncMessage(String message) {
    _cloudSyncMessage = message;
  }

  LibrarySong _withCloudPreferenceState(LibrarySong song) {
    final bool isDisliked = _cloudDislikedSongIds.contains(song.id);
    final bool isLiked = !isDisliked && _cloudLikedSongIds.contains(song.id);
    if (song.isLiked == isLiked && song.isDisliked == isDisliked) {
      return song;
    }
    return song.copyWith(isLiked: isLiked, isDisliked: isDisliked);
  }

  LibrarySong _withKnownCloudPreferenceState(LibrarySong song) {
    if (_activeCloudUserId == null || !_cloudUserDataLoaded) {
      return song;
    }
    return _withCloudPreferenceState(song);
  }

  Future<void> _hydrateMissingCloudSongs({
    Iterable<String> songIds = const <String>[],
  }) async {
    if (_isDisposed || _isDisposing) {
      return;
    }

    final List<String> missingSongIds =
        <String>{..._cloudLikedSongIds, ..._cloudDislikedSongIds, ...songIds}
            .where((String songId) {
              return songById(songId) == null &&
                  _cloudSongHydrationInFlight.add(songId);
            })
            .toList(growable: false);
    if (missingSongIds.isEmpty) {
      return;
    }

    final String? expectedUserId = _firestoreUserDataService?.currentUserId;
    List<LibrarySong?> hydratedSongs = const <LibrarySong?>[];
    try {
      hydratedSongs = await Future.wait(
        missingSongIds.map(_hydrateCloudSongById),
      );
    } finally {
      _cloudSongHydrationInFlight.removeAll(missingSongIds);
    }

    if (_isDisposed ||
        _isDisposing ||
        expectedUserId == null ||
        _firestoreUserDataService?.currentUserId != expectedUserId ||
        _activeCloudUserId != expectedUserId ||
        !_cloudUserDataLoaded) {
      return;
    }

    bool changed = false;
    for (final LibrarySong song in hydratedSongs.whereType<LibrarySong>()) {
      _rememberTransientSong(song);
      changed = true;
    }
    if (!changed) {
      return;
    }

    await _saveSnapshot();
    if (!_isDisposed && !_isDisposing) {
      notifyListeners();
    }
  }

  Future<LibrarySong?> _hydrateCloudSongById(String songId) async {
    try {
      if (songId.startsWith('yt:')) {
        final String videoId = songId.substring(3).trim();
        if (videoId.isEmpty) {
          return null;
        }
        final Video video = await _yt.videos.get(videoId);
        _recordOtherUsage(
          metadataBytes: _estimateUsagePayloadBytes(<String, Object?>{
            'videoId': video.id.value,
            'title': video.title,
            'author': video.author,
            'durationMs': video.duration?.inMilliseconds,
            'thumbnail': video.thumbnails.highResUrl,
          }),
        );
        return _withKnownCloudPreferenceState(_videoToSong(video));
      }

      if (songId.startsWith('url:')) {
        final Uri? uri = Uri.tryParse(songId.substring(4));
        if (uri == null || !uri.hasScheme) {
          return null;
        }
        return _withKnownCloudPreferenceState(_urlToSong(uri));
      }
    } catch (error) {
      debugPrint('Cloud song hydration failed for $songId: $error');
    }
    return null;
  }

  Future<void> _startCloudUserDataSubscription(String userId) async {
    final FirestoreUserDataService? service = _firestoreUserDataService;
    if (service == null) {
      return;
    }

    await _cloudUserDataSubscription?.cancel();
    _cloudUserDataSubscription = service.watchCurrentUserData().listen(
      (FirestoreUserData userData) {
        if (_activeCloudUserId != userId || _matchesCloudUserData(userData)) {
          return;
        }
        _applyCloudUserData(userData);
        _cloudUserDataLoaded = true;
        _homeFeed = <HomeFeedSection>[];
        _personalizedHomeRecommendations = <SongRecommendation>[];
        unawaited(_saveSnapshot());
        if (!_isDisposed && !_isDisposing) {
          notifyListeners();
        }
      },
      onError: (Object error) {
        final String message = error is FirestoreUserDataException
            ? error.message
            : 'Could not sync your Firestore library.';
        _queueCloudSyncMessage(message);
        if (!_isDisposed && !_isDisposing) {
          notifyListeners();
        }
      },
    );
  }

  bool _matchesCloudUserData(FirestoreUserData userData) {
    final Set<String> incomingDislikedSongIds = Set<String>.from(
      userData.dislikedSongIds,
    );
    final Set<String> incomingLikedSongIds = Set<String>.from(
      userData.likedSongIds,
    )..removeAll(incomingDislikedSongIds);

    if (!setEquals(_cloudLikedSongIds, incomingLikedSongIds) ||
        !setEquals(_cloudDislikedSongIds, incomingDislikedSongIds) ||
        _playlists.length != userData.playlists.length) {
      return false;
    }

    for (int index = 0; index < _playlists.length; index++) {
      final UserPlaylist currentPlaylist = _playlists[index];
      final UserPlaylist incomingPlaylist = userData.playlists[index];
      if (currentPlaylist.id != incomingPlaylist.id ||
          currentPlaylist.name != incomingPlaylist.name ||
          currentPlaylist.createdAt != incomingPlaylist.createdAt ||
          currentPlaylist.updatedAt != incomingPlaylist.updatedAt ||
          !listEquals(currentPlaylist.songIds, incomingPlaylist.songIds)) {
        return false;
      }
    }

    return true;
  }

  Future<void> _syncLikedSongToCloud({
    required String songId,
    required bool isLiked,
  }) async {
    final FirestoreUserDataService? service = _firestoreUserDataService;
    if (service == null || service.currentUserId == null) {
      return;
    }

    try {
      await service.setLikedSong(songId: songId, isLiked: isLiked);
    } on FirestoreUserDataException catch (error) {
      _queueCloudSyncMessage(
        '${error.message} The change was kept only on this device.',
      );
      notifyListeners();
    } catch (error) {
      _queueCloudSyncMessage(
        'Could not sync liked songs to Firestore. The change was kept only on this device.',
      );
      debugPrint('Firestore liked song sync failed: $error');
      notifyListeners();
    }
  }

  Future<void> _syncDislikedSongToCloud({
    required String songId,
    required bool isDisliked,
  }) async {
    final FirestoreUserDataService? service = _firestoreUserDataService;
    if (service == null || service.currentUserId == null) {
      return;
    }

    try {
      await service.setDislikedSong(songId: songId, isDisliked: isDisliked);
    } on FirestoreUserDataException catch (error) {
      _queueCloudSyncMessage(
        '${error.message} The change was kept only on this device.',
      );
      notifyListeners();
    } catch (error) {
      _queueCloudSyncMessage(
        'Could not sync disliked songs to Firestore. The change was kept only on this device.',
      );
      debugPrint('Firestore disliked song sync failed: $error');
      notifyListeners();
    }
  }

  Future<void> _syncPlaylistToCloud(UserPlaylist playlist) async {
    final FirestoreUserDataService? service = _firestoreUserDataService;
    if (service == null || service.currentUserId == null) {
      return;
    }

    try {
      await service.upsertPlaylist(playlist);
    } on FirestoreUserDataException catch (error) {
      _queueCloudSyncMessage(
        '${error.message} The playlist change was kept only on this device.',
      );
      notifyListeners();
    } catch (error) {
      _queueCloudSyncMessage(
        'Could not sync the playlist to Firestore. The change was kept only on this device.',
      );
      debugPrint('Firestore playlist sync failed: $error');
      notifyListeners();
    }
  }

  Future<void> _deletePlaylistFromCloud(String playlistId) async {
    final FirestoreUserDataService? service = _firestoreUserDataService;
    if (service == null || service.currentUserId == null) {
      return;
    }

    try {
      await service.deletePlaylist(playlistId);
    } on FirestoreUserDataException catch (error) {
      _queueCloudSyncMessage(
        '${error.message} The playlist was removed only on this device.',
      );
      notifyListeners();
    } catch (error) {
      _queueCloudSyncMessage(
        'Could not delete the playlist from Firestore. The change was kept only on this device.',
      );
      debugPrint('Firestore playlist delete failed: $error');
      notifyListeners();
    }
  }

  void _scheduleStartupContinuation() {
    if (_startupContinuationScheduled || _isDisposed || _isDisposing) {
      return;
    }
    _startupContinuationScheduled = true;
    unawaited(_completeStartupInitialization());
  }

  Future<void> _completeStartupInitialization() async {
    try {
      await _recreateYtMusicClient();
      await refreshConnectivityStatus(notify: false);
      if (_isDisposed || _isDisposing) {
        return;
      }
      _startConnectivityMonitoring();
      notifyListeners();
      unawaited(rescanLibrary());
      _requestAutoHomeRefresh();
    } catch (error, stackTrace) {
      debugPrint('Startup continuation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> refreshConnectivityStatus({
    bool notify = true,
    bool syncOfflineMode = true,
    bool announceLoss = false,
  }) async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    final bool online = await _isNetworkReachable(results);
    _setConnectivityOffline(!online, notify: false, announceLoss: announceLoss);
    if (syncOfflineMode) {
      _setStartupOfflineMode(!online, notify: false);
    }
    if (notify) {
      notifyListeners();
    }
    return online;
  }

  void _startConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      unawaited(_handleConnectivityChange(results));
    });
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    final bool online = await _isNetworkReachable(results);
    final bool wasOffline = _isOffline;
    _setConnectivityOffline(!online, notify: false, announceLoss: true);
    if (!online) {
      _onlineLoading = false;
      _trendingNowLoading = false;
      _onlineError = 'Internet is unavailable right now.';
      _trendingNowError = 'No internet connection.';
      if (_homeFeed.isEmpty) {
        _homeError = 'No internet connection. Reconnect and tap Refresh.';
      }
      final LibrarySong? activeSong = currentSong;
      if (activeSong != null &&
          activeSong.isRemote &&
          offlinePlaybackCacheEnabled &&
          _queueSongIds.isNotEmpty) {
        _debugPlayback(
          'connectivity.offline keeping queue flow simple '
          'current=${_debugSongLabel(activeSong)} '
          'positionMs=${_position.inMilliseconds} '
          'queueIndex=$_queueIndex',
        );
      }
      notifyListeners();
      return;
    }
    _setStartupOfflineMode(false, notify: false);
    if (_offlineQueueWaitingSongId != null) {
      unawaited(_resumeOfflineWaitingQueue());
    }
    unawaited(_refreshOfflinePlaybackCache(anchor: currentSong));
    notifyListeners();
    if (_initialized &&
        wasOffline &&
        _homeFeed.isEmpty &&
        !_homeLoading &&
        !offlineMusicMode) {
      _requestAutoHomeRefresh(force: true);
    }
  }

  Future<bool> _resolveOfflineStateForAction() async {
    if (!_isOffline || _startupOfflineMode || offlineMusicMode) {
      return _isOffline;
    }
    final bool online = await refreshConnectivityStatus(
      notify: false,
      syncOfflineMode: false,
    );
    return !online;
  }

  void _maybeAdvanceOfflineQueueAtTrackEnd() {
    if (_offlineQueueAdvancePending ||
        !_isOffline ||
        offlineMusicMode ||
        _duration <= Duration.zero) {
      return;
    }
    final LibrarySong? song = currentSong;
    if (song == null || !song.isRemote) {
      return;
    }
    final Duration remaining = _duration - _position;
    if (remaining > const Duration(milliseconds: 1200)) {
      return;
    }
    final int? targetIndex = _nextQueueIndex(respectSingleRepeat: false);
    if (targetIndex == null) {
      return;
    }
    _offlineQueueAdvancePending = true;
    unawaited(() async {
      try {
        final LibrarySong? targetSong = songById(_queueSongIds[targetIndex]);
        if (targetSong == null) {
          return;
        }
        final bool canOpenNow =
            !targetSong.isRemote ||
            _offlinePlaybackCachePathForSong(targetSong.id) != null;
        if (canOpenNow) {
          await _reopenQueueAtIndex(targetIndex);
          await play();
          return;
        }
        await _enterOfflineQueueWait(targetIndex);
      } finally {
        _offlineQueueAdvancePending = false;
      }
    }());
  }

  void _requestAutoHomeRefresh({bool force = false}) {
    final DateTime now = DateTime.now();
    if (_homeLoading) {
      return;
    }
    if (_lastAutoHomeRefreshAt != null &&
        now.difference(_lastAutoHomeRefreshAt!) <
            const Duration(milliseconds: 1500)) {
      return;
    }
    _lastAutoHomeRefreshAt = now;
    unawaited(refreshHomeFeed(force: force));
  }

  Future<bool> _isNetworkReachable(List<ConnectivityResult> results) async {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return false;
    }
    try {
      final List<InternetAddress> lookup = await InternetAddress.lookup(
        'youtube.com',
      ).timeout(const Duration(milliseconds: 1200));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return true;
    }
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

  Future<void> _ensureLibraryAccessPermissionIfNeeded() async {
    if (!Platform.isAndroid) {
      return;
    }
    final List<Permission> permissions = <Permission>[
      Permission.audio,
      Permission.storage,
    ];
    for (final Permission permission in permissions) {
      final PermissionStatus status = await permission.status;
      if (status.isGranted || status.isLimited) {
        return;
      }
    }
    for (final Permission permission in permissions) {
      await permission.request();
    }
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

    final bool offline = await _resolveOfflineStateForAction();
    if (offline) {
      _onlineResults = <LibrarySong>[];
      _onlineError = 'Internet is unavailable right now.';
      _onlineLoading = false;
      _onlineQuery = trimmed;
      _onlineResultLimit = 0;
      _onlineHasMore = false;
      notifyListeners();
      return;
    }

    if (offlineMusicMode) {
      _onlineResults = <LibrarySong>[];
      _onlineError = 'Offline Music mode is on.';
      _onlineLoading = false;
      _onlineQuery = trimmed;
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
        usageBucket: _AppNetworkUsageBucket.search,
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
    if (offlineMusicMode) {
      _trendingNowSongs = <LibrarySong>[];
      _trendingNowLoading = false;
      _trendingNowError = 'Offline Music mode is on.';
      notifyListeners();
      return;
    }
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
          usageBucket: _AppNetworkUsageBucket.load,
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
      if (offlineMusicMode) {
        _homeFeed = <HomeFeedSection>[];
        _personalizedHomeRecommendations = <SongRecommendation>[];
        _homeError = 'Offline Music mode is on.';
        return;
      }
      final bool online = await refreshConnectivityStatus(
        notify: false,
        syncOfflineMode: false,
        announceLoss: true,
      );
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
      _commitHomeFeedSections(expanded, seedSong: seedSong);

      if (_homeFeed.isEmpty && _personalizedHomeRecommendations.isEmpty) {
        _homeFeed = previousFeed;
        _personalizedHomeRecommendations = previousPersonalized;
        _homeError = previousFeed.isEmpty
            ? 'No recommendations available right now.'
            : 'Recommendations could not be refreshed right now.';
      }
    } catch (error) {
      if (_isConnectivityError(error)) {
        _setConnectivityOffline(true, notify: false, announceLoss: true);
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
    if (offlineMusicMode) {
      return;
    }
    if (await _resolveOfflineStateForAction()) {
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
      final List<HomeFeedSection> expanded = await _loadMoreHomeSections(
        seedSong: seedSong,
        force: false,
        already: List<HomeFeedSection>.from(_homeFeed),
        desiredCount: desiredTotal,
      );
      _commitHomeFeedSections(
        expanded,
        seedSong: seedSong,
        preservePersonalized: true,
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
        usageBucket: _AppNetworkUsageBucket.load,
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
    }

    _homeQueryCursor = recycledQueries ? cursor + queries.length : cursor;
    return sections;
  }

  void _commitHomeFeedSections(
    List<HomeFeedSection> sections, {
    required LibrarySong? seedSong,
    bool preservePersonalized = false,
  }) {
    _homeFeed = _filterHomeFeedSectionsForBrowsing(sections);
    if (!preservePersonalized || _personalizedHomeRecommendations.isEmpty) {
      _personalizedHomeRecommendations = _buildPersonalizedHomeSongs(
        sections: _homeFeed,
        seedSong: seedSong,
      );
    }
    notifyListeners();
  }

  Future<List<LibrarySong>> _searchSongs(
    String query, {
    int limit = 12,
    bool force = false,
    required _AppNetworkUsageBucket usageBucket,
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
        usageBucket: usageBucket,
      );
      _searchCache[cacheKey] = songs;
      return songs;
    } catch (error) {
      if (_isConnectivityError(error)) {
        _setConnectivityOffline(true, notify: false, announceLoss: true);
      }
      try {
        final List<LibrarySong> fallback = await _searchYouTubeMusicOnly(
          trimmed,
          limit: limit,
          force: force,
          usageBucket: usageBucket,
        );
        _searchCache[cacheKey] = fallback;
        return fallback;
      } catch (fallbackError) {
        if (_isConnectivityError(fallbackError)) {
          _setConnectivityOffline(true, notify: false, announceLoss: true);
        }
        rethrow;
      }
    }
  }

  Future<List<LibrarySong>> _searchOnlineMusic(
    String query, {
    int limit = 12,
    bool force = false,
    required _AppNetworkUsageBucket usageBucket,
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
      usageBucket: usageBucket,
    );

    final List<LibrarySong> youtubeSongs = ytMusicSongs.length >= limit
        ? <LibrarySong>[]
        : await _searchYouTubeFallbackOnly(
            trimmed,
            limit: math.max(youtubeTarget + 4, limit ~/ 2),
            force: force,
            usageBucket: usageBucket,
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
    required _AppNetworkUsageBucket usageBucket,
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
    _recordSongCollectionUsage(
      _ytMusicSearchCache[cacheKey]!,
      bucket: usageBucket,
      query: trimmed,
    );
    return _ytMusicSearchCache[cacheKey]!;
  }

  Future<List<LibrarySong>> _searchYouTubeFallbackOnly(
    String query, {
    int limit = 12,
    bool force = false,
    required _AppNetworkUsageBucket usageBucket,
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
      _recordSongCollectionUsage(ranked, bucket: usageBucket, query: trimmed);
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
    _AppNetworkUsageBucket usageBucket = _AppNetworkUsageBucket.metadata,
  }) async {
    return _searchYouTubeMusicOnly(
      query,
      limit: limit,
      force: force,
      usageBucket: usageBucket,
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
    _recordSongCollectionUsage(
      songs,
      bucket: _AppNetworkUsageBucket.load,
      query: '${anchor.artist} ${anchor.title} radio',
    );

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
    final String normalized = _normalizeCountryCode(countryCode);
    final AppRegion? matched = kAppRegions.firstWhereOrNull(
      (AppRegion region) => region.countryCode == normalized,
    );
    return matched?.label ?? (normalized.isEmpty ? 'Your region' : normalized);
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
    final Set<String> seenIds = <String>{};
    final Set<String> dislikedKeys = _decisionDislikedSongs
        .map(_songIdentityKey)
        .toSet();
    final List<LibrarySong> result = <LibrarySong>[];
    for (final LibrarySong song in songs) {
      final String identityKey = _songIdentityKey(song);
      if (excludedIds.contains(song.id) ||
          !shouldShowSongOutsideSearch(song) ||
          song.isDisliked ||
          dislikedKeys.contains(identityKey)) {
        continue;
      }
      if (!seenIds.add(song.id)) {
        continue;
      }
      if (!seenKeys.add(identityKey)) {
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
        _isOffline ||
        offlineMusicMode ||
        (!_settings.smartQueueEnabled && !force) ||
        _smartQueueLoading) {
      return;
    }

    final LibrarySong? current = currentSong;
    final LibrarySong? anchor =
        (seed != null && seed.isRemote && shouldShowSongOutsideSearch(seed))
        ? seed
        : (current != null &&
              current.isRemote &&
              shouldShowSongOutsideSearch(current))
        ? current
        : null;
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
      final LibrarySong? current = currentSong;
      final LibrarySong? fallbackAnchor =
          current != null &&
              current.isRemote &&
              shouldShowSongOutsideSearch(current)
          ? current
          : null;
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
          usageBucket: _AppNetworkUsageBucket.load,
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

      final Set<String> dislikedKeys = _decisionDislikedSongs
          .map(_songIdentityKey)
          .toSet();
      final Set<String> queuedIds = <String>{..._queueSongIds};
      final Set<String> queuedKeys = queueSongs.map(_songIdentityKey).toSet();
      int addedCount = 0;
      for (final LibrarySong song in predictions) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        if (song.isDisliked || dislikedKeys.contains(_songIdentityKey(song))) {
          continue;
        }
        final LibrarySong prepared = await _preparePlayableSong(
          song,
          primeOfflineCache: false,
        );
        if (_isDisposing || _isDisposed) {
          return;
        }
        final String preparedKey = _songIdentityKey(prepared);
        if (dislikedKeys.contains(preparedKey) ||
            !queuedIds.add(prepared.id) ||
            !queuedKeys.add(preparedKey)) {
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
        usageBucket: _AppNetworkUsageBucket.load,
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
    final LibrarySong? current = currentSong;
    if (current != null &&
        current.isRemote &&
        shouldShowSongOutsideSearch(current)) {
      return current;
    }
    return _validHistorySongs().firstOrNull ??
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
      for (final HomeFeedSection section in sections)
        ...section.songs.where((LibrarySong song) => song.isRemote).take(12),
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
    final Set<String> dislikedArtistKeys = _decisionDislikedSongs
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
    final Set<String> likedArtistKeys = _decisionLikedSongs
        .map((LibrarySong song) => _normalizeToken(song.artist))
        .where((String key) => key.isNotEmpty)
        .toSet();
    final Set<String> fullListenArtistKeys = fullListenSongs
        .map((LibrarySong song) => _normalizeToken(song.artist))
        .where((String key) => key.isNotEmpty)
        .toSet();

    final List<LibrarySong> seedSongs = _dedupeSongs(
      <LibrarySong>[
        if (currentSong case final LibrarySong current
            when current.isRemote && shouldShowSongOutsideSearch(current))
          current,
        if (seedSong case final LibrarySong seed
            when seed.isRemote && shouldShowSongOutsideSearch(seed))
          seed,
        ...fullListenSongs.take(4),
        ..._decisionLikedSongs.take(4),
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
      if (_shouldUseSongIdForHistorySignals(entry.songId) &&
          !entry.listenedToEnd &&
          entry.completionRatio < 0.45) {
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

  void _setConnectivityOffline(
    bool value, {
    bool notify = true,
    bool announceLoss = false,
  }) {
    if (_isOffline == value) {
      return;
    }
    _isOffline = value;
    if (value && announceLoss && !_startupOfflineMode && !offlineMusicMode) {
      _connectivityMessage =
          'Connection lost. Online features may not work until internet returns.';
    }
    if (notify) {
      notifyListeners();
    }
  }

  void _setStartupOfflineMode(bool value, {bool notify = true}) {
    if (_startupOfflineMode == value) {
      return;
    }
    _startupOfflineMode = value;
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
      if (!shouldShowSongOutsideSearch(song)) {
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
    final List<PlaybackEntry> recent = validPlaybackHistory
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
      if (song == null ||
          !song.isRemote ||
          !shouldShowSongOutsideSearch(song)) {
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
      if (song == null ||
          !song.isRemote ||
          !shouldShowSongOutsideSearch(song)) {
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
        .where(
          (LibrarySong song) =>
              song.isRemote && _songPreferenceWeight(song) > 0,
        )
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
        _recordOtherUsage(
          metadataBytes: _estimateUsagePayloadBytes(<String, Object?>{
            'sourceUrl': value,
            'videoId': video.id.value,
            'title': video.title,
            'author': video.author,
            'durationMs': video.duration?.inMilliseconds,
            'thumbnail': video.thumbnails.highResUrl,
          }),
        );
        final LibrarySong song = _videoToSong(video);
        await playOnlineSong(song);
        return;
      }

      final Uri? uri = Uri.tryParse(value);
      if (uri == null || !uri.hasScheme) {
        throw const FormatException('Enter a valid URL.');
      }

      final LibrarySong song = _urlToSong(uri);
      await _clearPreparedPlaybackState();
      final LibrarySong prepared = await _preparePlayableSong(
        song,
        primeOfflineCache: true,
      );
      await _openPreparedSong(prepared, label: 'URL Stream');
    } catch (error) {
      _errorMessage = '$error';
      notifyListeners();
    }
  }

  Future<void> playOnlineSong(LibrarySong song) async {
    if (offlineMusicMode) {
      _errorMessage = 'Offline Music mode is on.';
      notifyListeners();
      return;
    }
    if (await _resolveOfflineStateForAction()) {
      _errorMessage = offlineMusicMode
          ? 'Offline Music mode is on.'
          : 'Internet is unavailable right now.';
      notifyListeners();
      return;
    }
    _pendingSelectionSong = song;
    notifyListeners();
    try {
      await _player.stop();
      await _clearPreparedPlaybackState();
      final LibrarySong prepared = await _preparePlayableSong(
        song,
        primeOfflineCache: true,
      );
      await _openPreparedSong(prepared, label: 'YouTube');
    } catch (_) {
      _pendingSelectionSong = null;
      _clearPlaybackActivation();
      notifyListeners();
      rethrow;
    }
  }

  void _attachPlayerListeners([Player? playerInstance]) {
    final Player player = playerInstance ?? _player;
    _subscriptions.add(
      player.stream.playing.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _isPlaying = value as bool;
        _maybeResolvePlaybackActivation();
        _publishNotificationState();
        _syncPlaybackNotifiers();
      }),
    );

    _subscriptions.add(
      player.stream.position.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        if (_shouldHoldTransitionMetrics()) {
          return;
        }
        _position = value as Duration;
        _maybeResolvePlaybackActivation();
        _updateActivePlaybackProgress();
        _syncQueueIndexFromPlayerState();
        _maybeAdvanceOfflineQueueAtTrackEnd();
        _publishNotificationState();
        _syncPlaybackNotifiers();
      }),
    );

    _subscriptions.add(
      player.stream.duration.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        if (_shouldHoldTransitionMetrics()) {
          return;
        }
        _duration = value as Duration;
        _maybeResolvePlaybackActivation();
        _publishNotificationState();
        _syncPlaybackNotifiers();
      }),
    );

    _subscriptions.add(
      player.stream.shuffle.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _isShuffleEnabled = value as bool;
        _syncPlaybackNotifiers();
      }),
    );

    _subscriptions.add(
      player.stream.playlistMode.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _repeatMode = value as PlaylistMode;
        _syncPlaybackNotifiers();
      }),
    );

    _subscriptions.add(
      player.stream.error.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        _errorMessage = value as String;
        _debugPlayback(
          'player.error message="$_errorMessage" '
          'current=${_debugSongLabel(currentSong)} '
          'pending=${_debugSongLabel(_pendingSelectionSong)} '
          'transitionSong=$_transitioningSongId '
          'transitionIndex=$_transitioningQueueIndex '
          'queueIndex=$_queueIndex '
          'playerIndex=${player.state.playlist.index}',
        );
        final LibrarySong? failedSong = currentSong ?? _pendingSelectionSong;
        if (_isPlayableOpenFailure(_errorMessage!) &&
            failedSong != null &&
            _schedulePlaybackFallbackRecovery(
              failedSong,
              preferDirectRetry:
                  _isLocalPlaybackProxyFailure(_errorMessage!) ||
                  _isSongUsingPlaybackProxy(failedSong.id),
            )) {
          return;
        }
        if (_isConnectivityError(_errorMessage!)) {
          _setConnectivityOffline(true, notify: false, announceLoss: true);
        }
        if (_isOffline || offlineMusicMode) {
          final int? transitionIndex = _transitioningQueueIndex;
          if (_offlineQueueActivationTargetSongId == null &&
              transitionIndex != null &&
              transitionIndex >= 0 &&
              transitionIndex < _queueSongIds.length) {
            final LibrarySong? target = songById(
              _queueSongIds[transitionIndex],
            );
            if (target != null &&
                _offlinePlaybackCachePathForSong(target.id) != null) {
              _debugPlayback(
                'player.error reopening cached target '
                'index=$transitionIndex song=${_debugSongLabel(target)}',
              );
              unawaited(_reopenQueueAtIndex(transitionIndex));
              notifyListeners();
              return;
            }
          }
          _debugPlayback(
            'player.error offline mode active without full queue activation '
            'current=${_debugSongLabel(currentSong)} '
            'queueIndex=$_queueIndex',
          );
        }
        _clearPlaybackActivation();
        notifyListeners();
      }),
    );

    _subscriptions.add(
      player.stream.playlist.listen((dynamic value) {
        if (_isDisposing || _isDisposed) {
          return;
        }
        final Playlist playlist = value as Playlist;
        final List<String> nextQueueSongIds = playlist.medias
            .map((Media media) => media.extras?['songId'] as String?)
            .whereType<String>()
            .toList();
        final int nextQueueIndex = playlist.index.clamp(
          0,
          nextQueueSongIds.isEmpty ? 0 : nextQueueSongIds.length - 1,
        );
        _debugPlayback(
          'player.playlist event '
          'playerIndex=${playlist.index} '
          'nextIndex=$nextQueueIndex '
          'nextSong=${nextQueueSongIds.isEmpty ? 'null' : nextQueueSongIds[nextQueueIndex]} '
          'queueLen=${nextQueueSongIds.length} '
          'activationTarget=$_offlineQueueActivationTargetSongId '
          'fallbackTarget=$_playbackFallbackRecoverySongId '
          'transitionSong=$_transitioningSongId '
          'transitionIndex=$_transitioningQueueIndex',
        );
        if (_playbackFallbackRecoverySongId != null) {
          final String? activeSongId = nextQueueSongIds.isEmpty
              ? null
              : nextQueueSongIds[nextQueueIndex];
          final bool recoveryResolved =
              activeSongId == _playbackFallbackRecoverySongId &&
              (_playbackFallbackRecoveryIndex == null ||
                  nextQueueIndex == _playbackFallbackRecoveryIndex);
          if (!recoveryResolved) {
            _debugPlayback(
              'player.playlist ignored during fallback recovery '
              'active=$activeSongId '
              'expected=$_playbackFallbackRecoverySongId '
              'expectedIndex=$_playbackFallbackRecoveryIndex',
            );
            return;
          }
          _debugPlayback(
            'player.playlist fallback recovery resolved '
            'song=$activeSongId index=$nextQueueIndex',
          );
        }
        if (_offlineQueueActivationTargetSongId != null) {
          final String? activeSongId = nextQueueSongIds.isEmpty
              ? null
              : nextQueueSongIds[nextQueueIndex];
          final bool activationResolved =
              activeSongId == _offlineQueueActivationTargetSongId &&
              nextQueueIndex == _offlineQueueActivationTargetIndex &&
              listEquals(nextQueueSongIds, _offlineQueueActivationSongIds);
          if (!activationResolved) {
            _debugPlayback(
              'player.playlist ignored during activation '
              'active=$activeSongId '
              'expected=$_offlineQueueActivationTargetSongId '
              'expectedIndex=$_offlineQueueActivationTargetIndex',
            );
            return;
          }
          _debugPlayback(
            'player.playlist activation resolved '
            'song=$activeSongId index=$nextQueueIndex',
          );
        }
        if (_offlineDetachedQueueMode) {
          final LibrarySong? song = currentSong;
          _resolveTrackTransition(song);
          if (song != null && song.id != _lastTrackedSongId) {
            _trackPlayback(song.id);
          }
          _publishNotificationState();
          notifyListeners();
          return;
        }
        if (_offlineQueueWaitingSongId != null) {
          final String? activeSongId = nextQueueSongIds.isEmpty
              ? null
              : nextQueueSongIds[nextQueueIndex];
          if (activeSongId != _offlineQueueWaitingSongId ||
              nextQueueIndex != _offlineQueueWaitingIndex) {
            _debugPlayback(
              'player.playlist ignored during offline wait '
              'active=$activeSongId waiting=$_offlineQueueWaitingSongId '
              'waitingIndex=$_offlineQueueWaitingIndex',
            );
            return;
          }
          _debugPlayback(
            'player.playlist offline wait resolved '
            'song=$activeSongId index=$nextQueueIndex',
          );
        }
        _queueSongIds = nextQueueSongIds;
        _queueIndex = nextQueueIndex;
        final LibrarySong? song = currentSong;
        if (_offlineQueueActivationTargetSongId == null) {
          _resolveTrackTransition(song);
        }
        if (song != null && song.id != _lastTrackedSongId) {
          _trackPlayback(song.id);
        }
        unawaited(_maybeExtendSmartQueue(seed: song, force: true));
        unawaited(_refreshOfflinePlaybackCache(anchor: song));
        _publishNotificationState();
        notifyListeners();
      }),
    );
  }

  void _bindNotificationActions() {
    _notificationActionSubscription?.cancel();
    _notificationActionSubscription = null;
    if (AndroidMediaNotificationBridge.isSupported) {
      _notificationActionSubscription =
          AndroidMediaNotificationBridge.actionStream().listen((String action) {
            if (AndroidMediaNotificationBridge.isToggleAction(action)) {
              unawaited(togglePlayback());
            } else if (AndroidMediaNotificationBridge.isPlayAction(action)) {
              unawaited(play());
            } else if (AndroidMediaNotificationBridge.isPauseAction(action)) {
              unawaited(pause());
            } else if (AndroidMediaNotificationBridge.isNextAction(action)) {
              unawaited(nextTrack());
            } else if (AndroidMediaNotificationBridge.isPreviousAction(
              action,
            )) {
              unawaited(previousTrack());
            }
          });
    }

    _windowsMediaActionSubscription?.cancel();
    _windowsMediaActionSubscription = null;
    if (WindowsMediaControlsBridge.isSupported) {
      _windowsMediaActionSubscription =
          WindowsMediaControlsBridge.actionStream().listen((String action) {
            if (WindowsMediaControlsBridge.isToggleAction(action)) {
              unawaited(togglePlayback());
            } else if (WindowsMediaControlsBridge.isPlayAction(action)) {
              unawaited(play());
            } else if (WindowsMediaControlsBridge.isPauseAction(action)) {
              unawaited(pause());
            } else if (WindowsMediaControlsBridge.isNextAction(action)) {
              unawaited(nextTrack());
            } else if (WindowsMediaControlsBridge.isPreviousAction(action)) {
              unawaited(previousTrack());
            }
          });
    }
  }

  void _publishNotificationState() {
    final LibrarySong? song = currentSong;
    if (song == null) {
      _hasPublishedPlaybackNotification = false;
      unawaited(AndroidMediaNotificationBridge.stop());
      unawaited(WindowsMediaControlsBridge.stop());
      return;
    }

    if (_isPlaying) {
      _hasPublishedPlaybackNotification = true;
    }

    if (!_hasPublishedPlaybackNotification) {
      unawaited(AndroidMediaNotificationBridge.stop());
      unawaited(WindowsMediaControlsBridge.stop());
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
    unawaited(
      WindowsMediaControlsBridge.updatePlayback(
        song: song,
        isPlaying: _isPlaying,
        position: _position,
        duration: _duration,
        queueIndex: _queueIndex,
        queueLength: _queueSongIds.length,
      ),
    );
  }

  void _syncQueueIndexFromPlayerState() {
    if (_isDisposing || _isDisposed) {
      return;
    }
    if (_offlineQueueActivationTargetSongId != null ||
        _playbackFallbackRecoverySongId != null ||
        _offlineDetachedQueueMode ||
        _offlineQueueWaitingSongId != null ||
        _transitioningSongId != null) {
      _debugPlayback(
        'player.position queue sync skipped '
        'activation=$_offlineQueueActivationTargetSongId '
        'fallback=$_playbackFallbackRecoverySongId '
        'detached=$_offlineDetachedQueueMode '
        'waiting=$_offlineQueueWaitingSongId '
        'transitionSong=$_transitioningSongId '
        'transitionIndex=$_transitioningQueueIndex '
        'queueIndex=$_queueIndex '
        'playerIndex=${_player.state.playlist.index}',
      );
      return;
    }
    if (_queueSongIds.isEmpty) {
      return;
    }
    if (!_playerQueueHasControllerPlaylist()) {
      return;
    }
    final int nextIndex = _player.state.playlist.index.clamp(
      0,
      _queueSongIds.length - 1,
    );
    if (nextIndex == _queueIndex) {
      return;
    }
    _debugPlayback(
      'player.position queue sync apply '
      'queueIndex=$_queueIndex -> $nextIndex '
      'playerIndex=${_player.state.playlist.index}',
    );
    _queueIndex = nextIndex;
    final LibrarySong? song = currentSong;
    if (song != null && song.id != _lastTrackedSongId) {
      _trackPlayback(song.id);
    }
    unawaited(_maybeExtendSmartQueue(seed: song, force: true));
    unawaited(_refreshOfflinePlaybackCache(anchor: song));
  }

  LibrarySong? songById(String id) {
    return _songs.firstWhereOrNull((LibrarySong song) => song.id == id) ??
        _transientSongsById[id];
  }

  List<LibrarySong> songsForPlaylist(UserPlaylist playlist) {
    return playlist.songIds
        .map(songById)
        .whereType<LibrarySong>()
        .where(shouldShowSongOutsideSearch)
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

  Future<void> clearPlaybackHistory() async {
    _history = <PlaybackEntry>[];
    _songs = _songs
        .map(
          (LibrarySong song) =>
              song.copyWith(playCount: 0, clearLastPlayedAt: true),
        )
        .toList(growable: false);
    _transientSongsById.updateAll(
      (_, LibrarySong song) =>
          song.copyWith(playCount: 0, clearLastPlayedAt: true),
    );
    _activePlaybackSongId = null;
    _activePlaybackCompletionRatio = 0;
    _lastTrackedSongId = null;
    _startupMiniPlayerSongId = null;
    _homeFeed = <HomeFeedSection>[];
    _personalizedHomeRecommendations = <SongRecommendation>[];
    _scheduleSnapshotSave();
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> _rescanAllSources() async {
    _scanning = true;
    _statusMessage = 'Scanning device audio...';
    _errorMessage = null;
    notifyListeners();

    try {
      await _ensureLibraryAccessPermissionIfNeeded();
      _autoSources = await _discoverAutomaticSources();
      final List<String> activeSources = <String>{
        ..._autoSources,
        ..._sources,
      }.toList()..sort();
      final List<String> files = await _expandSourceFiles(activeSources);
      final Map<String, LibrarySong> previousByPath = <String, LibrarySong>{
        for (final LibrarySong song in _songs) song.path: song,
      };
      final List<LibrarySong> scanned = <LibrarySong>[];

      for (final String filePath in files) {
        scanned.add(
          await _buildSongFromPath(filePath, previousByPath[filePath]),
        );
      }

      _songs = scanned
          .map(_withKnownCloudPreferenceState)
          .toList(growable: false);
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
          .toList();
      _history = _history
          .where(
            (PlaybackEntry entry) =>
                scanned.any((LibrarySong song) => song.id == entry.songId),
          )
          .toList();
      _prunePlaybackHistory();
      _purgeRestrictedDurationOfflinePlaybackCacheEntries();

      _statusMessage = scanned.isEmpty
          ? 'No supported audio files found on this device.'
          : 'Loaded ${scanned.length} tracks from device storage.';
      await _saveSnapshot();
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = '$error';
      _statusMessage = 'Device scan failed.';
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  Future<List<String>> _discoverAutomaticSources() async {
    final Set<String> results = <String>{};
    if (Platform.isAndroid) {
      results.addAll(await _discoverAndroidAudioRoots());
    } else if (Platform.isWindows) {
      results.addAll(_discoverWindowsAudioRoots());
    }
    return results.toList()..sort();
  }

  Future<List<String>> _discoverAndroidAudioRoots() async {
    final Set<String> candidates = <String>{
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
      '/storage/emulated/0/Podcasts',
      '/sdcard/Music',
      '/sdcard/Download',
      '/sdcard/Downloads',
      '/sdcard/Podcasts',
    };
    for (final String key in <String>[
      'EXTERNAL_STORAGE',
      'SECONDARY_STORAGE',
      'EMULATED_STORAGE_TARGET',
    ]) {
      final String? raw = Platform.environment[key];
      if (raw == null || raw.trim().isEmpty) {
        continue;
      }
      for (final String root in raw.split(':')) {
        final String trimmed = root.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        candidates.add(trimmed);
        candidates.add(p.join(trimmed, 'Music'));
        candidates.add(p.join(trimmed, 'Download'));
        candidates.add(p.join(trimmed, 'Downloads'));
        candidates.add(p.join(trimmed, 'Podcasts'));
      }
    }

    final Set<String> existing = <String>{};
    for (final String path in candidates) {
      final Directory directory = Directory(path);
      if (await directory.exists()) {
        existing.add(directory.path);
      }
    }
    return existing.toList()..sort();
  }

  List<String> _discoverWindowsAudioRoots() {
    final String? userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null || userProfile.trim().isEmpty) {
      return <String>[];
    }
    final Set<String> candidates = <String>{
      p.join(userProfile, 'Music'),
      p.join(userProfile, 'Downloads'),
      p.join(userProfile, 'Desktop'),
      p.join(userProfile, 'Videos'),
    };
    return candidates
        .where((String path) => Directory(path).existsSync())
        .toList()
      ..sort();
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

  LibrarySong _urlToSong(Uri uri) {
    return LibrarySong(
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
  }

  bool _looksLikeYouTube(String value) {
    return looksLikeYouTubePlaybackSource(value);
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
    for (final String source in <String>{..._autoSources, ..._sources}) {
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
    _clearOfflineQueueWait(notify: false);
    _offlineDetachedQueueMode = false;
    _pendingSelectionSong = songs[safeIndex];
    _beginPlaybackActivation(
      songs[safeIndex],
      resetMetrics: true,
      notify: false,
    );
    notifyListeners();
    try {
      await _player.stop();
      await _clearPreparedPlaybackState();
      final List<LibrarySong> preparedSongs = <LibrarySong>[];
      for (int i = 0; i < songs.length; i += 1) {
        preparedSongs.add(
          await _preparePlayableSong(
            songs[i],
            primeOfflineCache: i == safeIndex,
          ),
        );
      }

      final List<Media> medias = preparedSongs.map(_mediaForSong).toList();

      _smartQueueSongIds.clear();
      _queueSongIds = preparedSongs.map((LibrarySong song) => song.id).toList();
      _queueLabel = label;
      _queueIndex = safeIndex;
      await _ensureSequentialPlayback();
      await _player.open(Playlist(medias, index: safeIndex));
      await _player.play();
      _trackPlayback(preparedSongs[safeIndex].id);
      if (!_isOffline && !offlineMusicMode) {
        unawaited(
          _maybeExtendSmartQueue(seed: preparedSongs[safeIndex], force: true),
        );
      }
      notifyListeners();
    } catch (_) {
      _pendingSelectionSong = null;
      _clearPlaybackActivation();
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
      _recordOtherUsage(
        artworkBytes: _estimateUsagePayloadBytes(<String, Object?>{
          'artistName': artistName,
          'results': artistResults,
        }),
      );
      resolved = _pickArtistImageUrl(artistResults, artistName: artistName);
      if ((resolved ?? '').trim().isEmpty) {
        final List<dynamic> profileResults = await client.search(
          artistName.trim(),
          filter: ytm.SearchFilter.profiles,
          limit: 5,
        );
        _recordOtherUsage(
          artworkBytes: _estimateUsagePayloadBytes(<String, Object?>{
            'artistName': artistName,
            'results': profileResults,
          }),
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
    final LibrarySong prepared = await _preparePlayableSong(
      song,
      primeOfflineCache: false,
    );
    if (!shouldShowSongOutsideSearch(prepared)) {
      return;
    }
    final Set<String> dislikedKeys = dislikedSongs
        .map(_songIdentityKey)
        .toSet();
    if (prepared.isDisliked ||
        dislikedKeys.contains(_songIdentityKey(prepared))) {
      return;
    }
    if (_queueSongIds.isEmpty) {
      await playSong(prepared, label: 'Queue');
      return;
    }
    final String preparedKey = _songIdentityKey(prepared);
    final bool alreadyQueued =
        _queueSongIds.contains(prepared.id) ||
        queueSongs.any(
          (LibrarySong queuedSong) =>
              _songIdentityKey(queuedSong) == preparedKey,
        );
    if (alreadyQueued) {
      return;
    }
    _smartQueueSongIds.remove(prepared.id);
    _queueSongIds = <String>[..._queueSongIds, prepared.id];
    await _player.add(_mediaForSong(prepared));
    unawaited(_refreshOfflinePlaybackCache(anchor: currentSong ?? prepared));
    notifyListeners();
  }

  Future<LibrarySong> _preparePlayableSong(
    LibrarySong song, {
    bool primeOfflineCache = false,
  }) async {
    _rememberTransientSong(song);
    final String? cachedPath = _offlinePlaybackCachePathForSong(song.id);
    if (cachedPath != null) {
      _disablePlaybackProxyForSong(song.id);
      _preparedMediaUrlsBySongId[song.id] = cachedPath;
      _preparedMediaHeadersBySongId[song.id] = null;
      _playbackStreamInfoBySongId[song.id] = buildCachedPlaybackStreamInfo(
        song: song,
        cachedPath: cachedPath,
        previousInfo: _playbackStreamInfoBySongId[song.id],
      );
      return song;
    }

    final _ActivePlaybackProxy? activeProxy =
        _activePlaybackProxiesBySongId[song.id];
    if (activeProxy != null &&
        _preparedMediaUrlsBySongId[song.id] == activeProxy.proxyUrl &&
        !_playbackProxyBypassSongIds.contains(song.id)) {
      if (primeOfflineCache) {
        _maybePrimeAndroidPlaybackCache(
          song: song,
          resolvedUrl: activeProxy.upstreamUrl,
          upstreamHeaders: activeProxy.upstreamHeaders,
        );
      }
      return song;
    }

    if (!song.isRemote) {
      _disablePlaybackProxyForSong(song.id);
      _preparedMediaUrlsBySongId[song.id] = song.path;
      _preparedMediaHeadersBySongId[song.id] = null;
      _playbackStreamInfoBySongId[song.id] = buildLocalPlaybackStreamInfo(song);
      return song;
    }

    if (offlineMusicMode || await _resolveOfflineStateForAction()) {
      throw const SocketException('Song is not cached for offline playback.');
    }

    final _PreparedPlaybackSource prepared =
        await _resolvePreparedPlaybackSource(
          song,
          primeOfflineCache: primeOfflineCache,
        );
    _preparedMediaUrlsBySongId[song.id] = prepared.mediaUrl;
    _preparedMediaHeadersBySongId[song.id] = prepared.mediaHeaders;
    _playbackStreamInfoBySongId[song.id] = prepared.streamInfo;
    _debugPlayback(
      'stream.selected song=${_debugSongLabel(song)} '
      '${prepared.streamInfo.debugSummary}',
    );
    return song;
  }

  Future<void> _openPreparedSong(
    LibrarySong song, {
    required String label,
  }) async {
    _clearOfflineQueueWait(notify: false);
    _offlineDetachedQueueMode = false;
    _pendingSelectionSong = song;
    _beginPlaybackActivation(song, resetMetrics: true, notify: false);
    notifyListeners();
    _rememberTransientSong(song);
    try {
      _smartQueueSongIds.clear();
      _queueSongIds = <String>[song.id];
      _queueLabel = label;
      _queueIndex = 0;
      await _ensureSequentialPlayback();
      await _player.open(Playlist(<Media>[_mediaForSong(song)]));
      await _player.play();
      _trackPlayback(song.id);
      unawaited(_maybeExtendSmartQueue(seed: song, force: true));
      unawaited(_refreshOfflinePlaybackCache(anchor: song));
      notifyListeners();
    } catch (_) {
      _pendingSelectionSong = null;
      notifyListeners();
      rethrow;
    }
  }

  Media _mediaForSong(LibrarySong song) {
    return Media(
      _resolvedMediaUrlForSong(song),
      extras: <String, dynamic>{'songId': song.id},
      httpHeaders: _resolvedMediaHeadersForSong(song),
    );
  }

  String _resolvedMediaUrlForSong(LibrarySong song) {
    final String? cachedPath = _offlinePlaybackCachePathForSong(song.id);
    if (cachedPath != null) {
      return cachedPath;
    }

    final String? prepared = _preparedMediaUrlsBySongId[song.id];
    if (prepared != null && prepared.isNotEmpty) {
      return prepared;
    }
    return song.path;
  }

  Map<String, String>? _resolvedMediaHeadersForSong(LibrarySong song) {
    if (_offlinePlaybackCachePathForSong(song.id) != null) {
      return null;
    }
    if (_preparedMediaHeadersBySongId.containsKey(song.id)) {
      return _preparedMediaHeadersBySongId[song.id];
    }
    return song.isRemote ? _upstreamHeadersForUrl(song, song.path) : null;
  }

  Media? _playerQueueMediaAt(int index) {
    final List<Media> medias = _player.state.playlist.medias;
    if (index < 0 || index >= medias.length) {
      return null;
    }
    return medias[index];
  }

  bool _playerQueueEntryNeedsRefresh(LibrarySong song, int index) {
    final Media? media = _playerQueueMediaAt(index);
    if (media == null) {
      return true;
    }
    final String expectedUrl = Media.normalizeURI(
      _resolvedMediaUrlForSong(song),
    );
    if (media.uri != expectedUrl) {
      _debugPlayback(
        'queue.refresh stale media '
        'index=$index song=${_debugSongLabel(song)} '
        'expected="$expectedUrl" actual="${media.uri}"',
      );
      return true;
    }
    final Map<String, String>? expectedHeaders = _resolvedMediaHeadersForSong(
      song,
    );
    if (!mapEquals(media.httpHeaders, expectedHeaders)) {
      _debugPlayback(
        'queue.refresh stale headers '
        'index=$index song=${_debugSongLabel(song)}',
      );
      return true;
    }
    return false;
  }

  bool _queueSongNeedsQueueRefresh(LibrarySong song, int index) {
    if (_queueSongNeedsPreparedMediaSource(song)) {
      return true;
    }
    return _playerQueueEntryNeedsRefresh(song, index);
  }

  Future<_PreparedPlaybackSource> _resolvePreparedPlaybackSource(
    LibrarySong song, {
    bool primeOfflineCache = false,
  }) async {
    final bool cacheAllowed = _shouldCacheSongForOfflinePlayback(song);
    final _ResolvedRemotePlayback resolved = await _resolvePlayableRemoteStream(
      song,
      preferPlaybackCompatibility: true,
    );
    if (_playbackProxyBypassSongIds.contains(song.id)) {
      if (primeOfflineCache && cacheAllowed) {
        _maybePrimeAndroidPlaybackCache(
          song: song,
          resolvedUrl: resolved.resolvedUrl,
          upstreamHeaders: resolved.upstreamHeaders,
        );
      }
      _disablePlaybackProxyForSong(song.id, bypass: true);
      return _PreparedPlaybackSource(
        mediaUrl: resolved.resolvedUrl,
        mediaHeaders: resolved.upstreamHeaders,
        streamInfo: resolved.streamInfo,
      );
    }
    if (Platform.isWindows) {
      _debugPlayback(
        'proxy.bypass platform=windows song=${_debugSongLabel(song)}',
      );
      if (primeOfflineCache && cacheAllowed) {
        _maybePrimeAndroidPlaybackCache(
          song: song,
          resolvedUrl: resolved.resolvedUrl,
          upstreamHeaders: resolved.upstreamHeaders,
        );
      }
      _disablePlaybackProxyForSong(song.id, bypass: true);
      return _PreparedPlaybackSource(
        mediaUrl: resolved.resolvedUrl,
        mediaHeaders: resolved.upstreamHeaders,
        streamInfo: resolved.streamInfo,
      );
    }
    final String? proxyCacheFilePath = Platform.isAndroid || !cacheAllowed
        ? null
        : (await _offlinePlaybackCacheTargetFile(
            song,
            resolved.resolvedUrl,
          )).path;
    try {
      final String proxyUrl = await _registerPlaybackProxy(
        song: song,
        upstreamUrl: resolved.resolvedUrl,
        upstreamHeaders: resolved.upstreamHeaders,
        cacheFilePath: proxyCacheFilePath,
      );
      if (primeOfflineCache && cacheAllowed) {
        _maybePrimeAndroidPlaybackCache(
          song: song,
          resolvedUrl: resolved.resolvedUrl,
          upstreamHeaders: resolved.upstreamHeaders,
        );
      }
      return _PreparedPlaybackSource(
        mediaUrl: proxyUrl,
        mediaHeaders: null,
        streamInfo: resolved.streamInfo,
      );
    } catch (error) {
      _debugPlayback(
        'proxy.register failed song=${_debugSongLabel(song)} error=$error',
      );
    }
    if (primeOfflineCache && cacheAllowed) {
      _maybePrimeAndroidPlaybackCache(
        song: song,
        resolvedUrl: resolved.resolvedUrl,
        upstreamHeaders: resolved.upstreamHeaders,
      );
    }
    return _PreparedPlaybackSource(
      mediaUrl: resolved.resolvedUrl,
      mediaHeaders: resolved.upstreamHeaders,
      streamInfo: resolved.streamInfo,
    );
  }

  bool _isSongUsingPlaybackProxy(String songId) {
    final _ActivePlaybackProxy? activeProxy =
        _activePlaybackProxiesBySongId[songId];
    if (activeProxy == null) {
      return false;
    }
    return _preparedMediaUrlsBySongId[songId] == activeProxy.proxyUrl;
  }

  void _disablePlaybackProxyForSong(String songId, {bool bypass = false}) {
    if (bypass) {
      _playbackProxyBypassSongIds.add(songId);
    } else {
      _playbackProxyBypassSongIds.remove(songId);
    }
    final _ActivePlaybackProxy? existing = _activePlaybackProxiesBySongId
        .remove(songId);
    if (existing != null) {
      unawaited(_playbackProxy.unregister(existing.sessionId));
    }
  }

  Future<String> _registerPlaybackProxy({
    required LibrarySong song,
    required String upstreamUrl,
    required Map<String, String>? upstreamHeaders,
    required String? cacheFilePath,
  }) async {
    final _ActivePlaybackProxy? existing =
        _activePlaybackProxiesBySongId[song.id];
    if (existing != null &&
        existing.upstreamUrl == upstreamUrl &&
        mapEquals(existing.upstreamHeaders, upstreamHeaders)) {
      return existing.proxyUrl;
    }
    if (existing != null) {
      unawaited(_playbackProxy.unregister(existing.sessionId));
    }

    final String sessionId = _uuid.v4();
    final String proxyUrl = await _playbackProxy.register(
      sessionId: sessionId,
      songId: song.id,
      upstreamUri: Uri.parse(upstreamUrl),
      upstreamHeaders: upstreamHeaders,
      cacheFilePath: cacheFilePath,
      cacheEpoch: _offlinePlaybackCacheEpoch,
    );
    _activePlaybackProxiesBySongId[song.id] = _ActivePlaybackProxy(
      sessionId: sessionId,
      proxyUrl: proxyUrl,
      upstreamUrl: upstreamUrl,
      upstreamHeaders: upstreamHeaders == null
          ? null
          : Map<String, String>.unmodifiable(
              Map<String, String>.from(upstreamHeaders),
            ),
    );
    return proxyUrl;
  }

  Future<_ResolvedRemotePlayback> _resolvePlayableRemoteStream(
    LibrarySong song, {
    bool preferPlaybackCompatibility = false,
  }) async {
    if (!_looksLikeYouTube(song.path)) {
      return _ResolvedRemotePlayback(
        resolvedUrl: song.path,
        upstreamHeaders: _upstreamHeadersForUrl(song, song.path),
        streamInfo: buildDirectPlaybackStreamInfo(song),
      );
    }

    final List<PlaybackStreamCandidate> rankedCandidates =
        await _rankedPlaybackCandidatesForSong(song);

    if (rankedCandidates.isEmpty) {
      throw const FormatException('No playable YouTube stream found.');
    }

    final int currentIndex = (_playbackCandidateIndexBySongId[song.id] ?? 0)
        .clamp(0, rankedCandidates.length - 1);
    final int selectedIndex = preferredPlaybackCandidateIndex(
      rankedCandidates: rankedCandidates,
      currentIndex: currentIndex,
      preferMuxedStability: preferPlaybackCompatibility && Platform.isWindows,
    );
    _playbackCandidateIndexBySongId[song.id] = selectedIndex;
    final PlaybackStreamResolution resolved = resolvePlaybackStreamAtIndex(
      songId: song.id,
      sourceLabel: song.sourceLabel,
      originalUrl: song.path,
      externalUrl: song.externalUrl,
      candidates: rankedCandidates,
      rankedCandidates: rankedCandidates,
      selectedIndex: selectedIndex,
      selectionPolicy: selectedIndex == currentIndex
          ? (selectedIndex == 0
                ? 'lowest-bitrate-audio-first'
                : 'fallback-after-open-failure')
          : 'windows-muxed-stability-first',
    );
    return _ResolvedRemotePlayback(
      resolvedUrl: resolved.url,
      upstreamHeaders: _upstreamHeadersForUrl(song, resolved.url),
      streamInfo: resolved.info,
    );
  }

  Future<List<PlaybackStreamCandidate>> _rankedPlaybackCandidatesForSong(
    LibrarySong song,
  ) async {
    final List<PlaybackStreamCandidate>? cachedCandidates =
        _rankedPlaybackCandidatesBySongId[song.id];
    if (cachedCandidates != null && cachedCandidates.isNotEmpty) {
      return cachedCandidates;
    }

    final StreamManifest manifest = await _yt.videos.streams.getManifest(
      song.path,
    );
    final List<PlaybackStreamCandidate> rankedCandidates =
        rankPlaybackStreamCandidates(_buildPlaybackStreamCandidates(manifest));
    _recordOtherUsage(
      metadataBytes: _estimateUsagePayloadBytes(<String, Object?>{
        'songId': song.id,
        'source': song.path,
        'candidates': rankedCandidates
            .map(_normalizeUsagePayload)
            .toList(growable: false),
      }),
    );
    _rankedPlaybackCandidatesBySongId[song.id] = rankedCandidates;
    return rankedCandidates;
  }

  bool _isPlayableOpenFailure(String message) {
    final String normalized = message.toLowerCase();
    return normalized.contains('failed to open http://') ||
        normalized.contains('failed to open https://') ||
        normalized.contains('failed to recognize file format');
  }

  bool _isLocalPlaybackProxyFailure(String message) {
    final String normalized = message.toLowerCase();
    return normalized.contains('failed to open http://127.0.0.1:') ||
        normalized.contains('failed to open http://localhost:');
  }

  void _primePlaybackFallbackRecovery(LibrarySong song) {
    final int queueSongIndex = _queueSongIds.indexOf(song.id);
    _playbackFallbackRecoverySongId = song.id;
    _playbackFallbackRecoveryIndex = queueSongIndex >= 0
        ? queueSongIndex
        : null;
    _transitioningSongId = song.id;
    if (queueSongIndex >= 0) {
      _transitioningQueueIndex = queueSongIndex;
    }
    _pendingSelectionSong = song;
    _position = Duration.zero;
    _duration = Duration.zero;
    _beginPlaybackActivation(song, notify: false);
    _debugPlayback(
      'stream.fallback prime song=${_debugSongLabel(song)} '
      'targetIndex=$_playbackFallbackRecoveryIndex queueIndex=$_queueIndex',
    );
    notifyListeners();
  }

  void _clearPlaybackFallbackRecoveryState() {
    _playbackFallbackRecoverySongId = null;
    _playbackFallbackRecoveryIndex = null;
  }

  Future<void> _pausePlayerForFallbackRecovery() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  bool _schedulePlaybackFallbackRecovery(
    LibrarySong song, {
    bool preferDirectRetry = false,
  }) {
    if (_playbackFallbackRecoveryInFlight || !_looksLikeYouTube(song.path)) {
      return false;
    }
    final List<PlaybackStreamCandidate>? rankedCandidates =
        _rankedPlaybackCandidatesBySongId[song.id];
    final int candidateCount = rankedCandidates?.length ?? 0;
    final int currentIndex = candidateCount == 0
        ? 0
        : (_playbackCandidateIndexBySongId[song.id] ?? 0).clamp(
            0,
            candidateCount - 1,
          );
    final bool bypassPlaybackProxy =
        preferDirectRetry || _isSongUsingPlaybackProxy(song.id);
    int targetIndex = currentIndex;
    if (!bypassPlaybackProxy) {
      if (rankedCandidates == null || rankedCandidates.isEmpty) {
        return false;
      }
      final int? nextIndex = nextPlaybackFallbackIndex(
        rankedCandidates,
        currentIndex,
      );
      if (nextIndex == null) {
        return false;
      }
      targetIndex = nextIndex;
    }
    _playbackFallbackRecoveryInFlight = true;
    if (bypassPlaybackProxy) {
      _disablePlaybackProxyForSong(song.id, bypass: true);
    }
    _primePlaybackFallbackRecovery(song);
    unawaited(_pausePlayerForFallbackRecovery());
    unawaited(
      _recoverPlaybackWithFallback(
        song: song,
        currentIndex: currentIndex,
        nextIndex: targetIndex,
        bypassPlaybackProxy: bypassPlaybackProxy,
      ),
    );
    return true;
  }

  Future<void> _recoverPlaybackWithFallback({
    required LibrarySong song,
    required int currentIndex,
    required int nextIndex,
    required bool bypassPlaybackProxy,
  }) async {
    try {
      _playbackCandidateIndexBySongId[song.id] = nextIndex;
      final _ResolvedRemotePlayback resolved =
          await _resolvePlayableRemoteStream(
            song,
            preferPlaybackCompatibility: true,
          );
      _preparedMediaUrlsBySongId[song.id] = resolved.resolvedUrl;
      _preparedMediaHeadersBySongId[song.id] = resolved.upstreamHeaders;
      _playbackStreamInfoBySongId[song.id] = resolved.streamInfo;
      _errorMessage = null;
      _debugPlayback(
        'stream.fallback song=${_debugSongLabel(song)} '
        'fromIndex=$currentIndex toIndex=$nextIndex '
        'proxyBypass=$bypassPlaybackProxy '
        '${resolved.streamInfo.debugSummary}',
      );

      final int queueSongIndex = _queueSongIds.indexOf(song.id);
      if (queueSongIndex >= 0) {
        await _reopenQueueAtIndex(queueSongIndex);
        await _player.play();
      } else {
        final LibrarySong prepared = await _preparePlayableSong(
          song,
          primeOfflineCache: true,
        );
        await _openPreparedSong(prepared, label: _queueLabel);
      }
      notifyListeners();
    } catch (error) {
      _debugPlayback(
        'stream.fallback failed song=${_debugSongLabel(song)} '
        'fromIndex=$currentIndex toIndex=$nextIndex error=$error',
      );
      _clearPlaybackActivation();
    } finally {
      _clearPlaybackFallbackRecoveryState();
      _playbackFallbackRecoveryInFlight = false;
    }
  }

  List<PlaybackStreamCandidate> _buildPlaybackStreamCandidates(
    StreamManifest manifest,
  ) {
    final List<PlaybackStreamCandidate> candidates = <PlaybackStreamCandidate>[
      ...manifest.audioOnly.map((AudioOnlyStreamInfo stream) {
        return _playbackStreamCandidate(
          stream: stream,
          transport: PlaybackStreamTransport.audioOnly,
        );
      }),
      ...manifest.muxed.map((MuxedStreamInfo stream) {
        return _playbackStreamCandidate(
          stream: stream,
          transport: PlaybackStreamTransport.muxed,
        );
      }),
      ...manifest.streams.whereType<HlsAudioStreamInfo>().map((
        HlsAudioStreamInfo stream,
      ) {
        return _playbackStreamCandidate(
          stream: stream,
          transport: PlaybackStreamTransport.hlsAudioOnly,
        );
      }),
      ...manifest.streams.whereType<HlsMuxedStreamInfo>().map((
        HlsMuxedStreamInfo stream,
      ) {
        return _playbackStreamCandidate(
          stream: stream,
          transport: PlaybackStreamTransport.hlsMuxed,
        );
      }),
      ...manifest.streams.whereType<HlsVideoStreamInfo>().map((
        HlsVideoStreamInfo stream,
      ) {
        return _playbackStreamCandidate(
          stream: stream,
          transport: PlaybackStreamTransport.hlsVideoOnly,
        );
      }),
    ];
    return candidates;
  }

  PlaybackStreamCandidate _playbackStreamCandidate({
    required StreamInfo stream,
    required PlaybackStreamTransport transport,
  }) {
    return PlaybackStreamCandidate(
      transport: transport,
      url: stream.url.toString(),
      bitrateBitsPerSecond: stream.bitrate.bitsPerSecond,
      streamTag: stream.tag,
      videoHeight: stream is VideoStreamInfo
          ? stream.videoResolution.height
          : null,
      qualityLabel: stream.qualityLabel,
      containerName: stream.container.name,
      codecDescription: stream.codec.toString(),
      audioCodec: stream is AudioStreamInfo ? stream.audioCodec : null,
      videoCodec: stream is VideoStreamInfo ? stream.videoCodec : null,
    );
  }

  Map<String, String>? _upstreamHeadersForUrl(
    LibrarySong song,
    String resolvedUrl,
  ) {
    final Uri? uri = Uri.tryParse(resolvedUrl);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final String host = uri.host.toLowerCase();
    if (host.contains('googlevideo.com') ||
        host.contains('youtube.com') ||
        host.contains('youtu.be')) {
      final String referer = (song.externalUrl ?? '').trim().isNotEmpty
          ? song.externalUrl!
          : song.sourceLabel == 'YouTube'
          ? 'https://www.youtube.com/'
          : 'https://music.youtube.com/';
      return <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        'Referer': referer,
        'Origin': referer.startsWith('https://www.youtube.com')
            ? 'https://www.youtube.com'
            : 'https://music.youtube.com',
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
    final bool shouldBootstrapPlayback =
        _shouldBootstrapPlaybackForQueueNavigation();
    final bool shouldShowPlaybackLoading =
        _isPlaying || shouldBootstrapPlayback;
    final LibrarySong? targetSong = songById(_queueSongIds[index]);
    if (shouldShowPlaybackLoading) {
      _beginPlaybackActivation(targetSong, resetMetrics: true);
    }
    _debugPlayback(
      'jumpToQueue requested index=$index '
      'currentIndex=$_queueIndex '
      'target=${_debugSongLabel(songById(_queueSongIds[index]))}',
    );
    if (await _tryHandleOfflineTargetTransition(
      index,
      bootstrapPlayback: shouldBootstrapPlayback,
    )) {
      return;
    }
    if (!_playerQueueHasControllerPlaylist()) {
      await _reopenQueueAtIndex(index, forcePlay: shouldBootstrapPlayback);
      return;
    }
    if (await _shouldUseOfflineQueueTransition(index)) {
      await _reopenQueueAtIndex(index, forcePlay: shouldBootstrapPlayback);
      return;
    }
    if (targetSong != null && _queueSongNeedsQueueRefresh(targetSong, index)) {
      await _reopenQueueAtIndex(index, forcePlay: shouldBootstrapPlayback);
      return;
    }
    _primePendingTrackTransition(index);
    try {
      await _player.jump(index);
      _queueIndex = index;
      notifyListeners();
    } catch (error) {
      if (await _recoverTransitionFromError(index, error)) {
        return;
      }
      _clearTrackTransition();
      rethrow;
    }
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

  Future<void> _removeQueuedSongInstances(
    LibrarySong song, {
    bool keepCurrent = false,
  }) async {
    final String identityKey = _songIdentityKey(song);
    for (int index = _queueSongIds.length - 1; index >= 0; index -= 1) {
      final LibrarySong? queuedSong = songById(_queueSongIds[index]);
      if (queuedSong == null || _songIdentityKey(queuedSong) != identityKey) {
        continue;
      }
      if (keepCurrent && index == _queueIndex) {
        continue;
      }
      await removeFromQueue(index);
    }
  }

  Future<void> _skipDislikedCurrentSong(LibrarySong song) async {
    if (currentSong?.id != song.id) {
      return;
    }

    final String identityKey = _songIdentityKey(song);
    final int foundIndex = _queueSongIds.indexWhere((String queuedSongId) {
      final LibrarySong? queuedSong = songById(queuedSongId);
      return queuedSong != null && _songIdentityKey(queuedSong) != identityKey;
    }, _queueIndex + 1);
    int? targetIndex = foundIndex >= 0 ? foundIndex : null;

    if (targetIndex == null &&
        !_isOffline &&
        !offlineMusicMode &&
        !_settings.smartQueueEnabled) {
      await _appendSmartQueuePredictions(song, limit: 1);
      if (_queueIndex < _queueSongIds.length - 1) {
        targetIndex = _queueIndex + 1;
      }
    } else if (targetIndex == null && !_isOffline && !offlineMusicMode) {
      await _maybeExtendSmartQueue(seed: song, force: true);
      if (_queueIndex < _queueSongIds.length - 1) {
        targetIndex = _queueIndex + 1;
      }
    }

    if (targetIndex != null) {
      await jumpToQueue(targetIndex);
      await play();
    }
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
    if (_queueSongIds.isEmpty || currentSong == null) {
      await _resumeMiniPlayerPlaybackFallback();
      return;
    }
    if (_isPlaying) {
      await pause();
      return;
    }
    await play();
  }

  Future<void> play() async {
    if (_isPlaying) {
      return;
    }
    if (_queueSongIds.isEmpty || currentSong == null) {
      if (await _resumeMiniPlayerPlaybackFallback()) {
        return;
      }
    }
    _syncControllerQueueIndexToPlayer();
    final LibrarySong? activeSong = currentSong;
    if (_playerHasLoadedCurrentSong(activeSong)) {
      try {
        await _player.play();
        if (activeSong != null && _lastTrackedSongId != activeSong.id) {
          _trackPlayback(activeSong.id);
        }
        return;
      } catch (error) {
        _debugPlayback(
          'player.play resume failed song=${_debugSongLabel(activeSong)} '
          'error=$error',
        );
      }
    }
    _beginPlaybackActivation(activeSong);
    if (activeSong != null &&
        !_playerQueueHasControllerPlaylist() &&
        _songHasImmediatePlaybackSource(activeSong)) {
      await _reopenQueueAtIndex(
        _queueIndex,
        forcePlay: true,
        preferDetached: true,
      );
      return;
    }
    if (activeSong != null &&
        _queueSongNeedsQueueRefresh(activeSong, _queueIndex)) {
      await _reopenQueueAtIndex(_queueIndex);
      await _player.play();
      return;
    }
    if (!_playerQueueMatchesControllerState()) {
      await _reopenQueueAtIndex(_queueIndex);
    }
    await _player.play();
  }

  Future<void> pause() async {
    if (!_isPlaying) {
      return;
    }
    _clearPlaybackActivation();
    await _player.pause();
  }

  Future<void> nextTrack() async {
    if (_queueNavigationInFlight) {
      _debugPlayback('nextTrack ignored while queue navigation is in flight');
      return;
    }
    _queueNavigationInFlight = true;
    try {
      _syncControllerQueueIndexToPlayer();
      final int? targetIndex = _nextQueueIndex(respectSingleRepeat: false);
      if (targetIndex == null) {
        return;
      }
      final bool shouldBootstrapPlayback =
          _shouldBootstrapPlaybackForQueueNavigation();
      final bool shouldShowPlaybackLoading =
          _isPlaying || shouldBootstrapPlayback;
      final LibrarySong? targetSong = songById(_queueSongIds[targetIndex]);
      if (shouldShowPlaybackLoading) {
        _beginPlaybackActivation(targetSong, resetMetrics: true);
      }
      _debugPlayback(
        'nextTrack requested currentIndex=$_queueIndex targetIndex=$targetIndex '
        'current=${_debugSongLabel(currentSong)} '
        'target=${_debugSongLabel(songById(_queueSongIds[targetIndex]))}',
      );
      if (await _tryHandleOfflineTargetTransition(
        targetIndex,
        bootstrapPlayback: shouldBootstrapPlayback,
      )) {
        return;
      }
      if (!_playerQueueHasControllerPlaylist()) {
        await _reopenQueueAtIndex(
          targetIndex,
          forcePlay: shouldBootstrapPlayback,
        );
        return;
      }
      if (await _shouldUseOfflineQueueTransition(targetIndex)) {
        await _reopenQueueAtIndex(
          targetIndex,
          forcePlay: shouldBootstrapPlayback,
        );
        return;
      }
      if (targetSong != null &&
          _queueSongNeedsQueueRefresh(targetSong, targetIndex)) {
        await _reopenQueueAtIndex(
          targetIndex,
          forcePlay: shouldBootstrapPlayback,
        );
        return;
      }
      _primePendingTrackTransition(targetIndex);
      try {
        await _player.next();
      } catch (error) {
        if (await _recoverTransitionFromError(targetIndex, error)) {
          return;
        }
        _clearTrackTransition();
        rethrow;
      }
    } finally {
      _queueNavigationInFlight = false;
    }
  }

  Future<void> previousTrack() async {
    if (_queueNavigationInFlight) {
      _debugPlayback(
        'previousTrack ignored while queue navigation is in flight',
      );
      return;
    }
    _queueNavigationInFlight = true;
    try {
      _syncControllerQueueIndexToPlayer();
      final int? targetIndex = _previousQueueIndex(respectSingleRepeat: false);
      if (targetIndex == null) {
        return;
      }
      final bool shouldBootstrapPlayback =
          _shouldBootstrapPlaybackForQueueNavigation();
      final bool shouldShowPlaybackLoading =
          _isPlaying || shouldBootstrapPlayback;
      final LibrarySong? targetSong = songById(_queueSongIds[targetIndex]);
      if (shouldShowPlaybackLoading) {
        _beginPlaybackActivation(targetSong, resetMetrics: true);
      }
      _debugPlayback(
        'previousTrack requested currentIndex=$_queueIndex targetIndex=$targetIndex '
        'current=${_debugSongLabel(currentSong)} '
        'target=${_debugSongLabel(songById(_queueSongIds[targetIndex]))}',
      );
      if (await _tryHandleOfflineTargetTransition(
        targetIndex,
        bootstrapPlayback: shouldBootstrapPlayback,
      )) {
        return;
      }
      if (!_playerQueueHasControllerPlaylist()) {
        await _reopenQueueAtIndex(
          targetIndex,
          forcePlay: shouldBootstrapPlayback,
        );
        return;
      }
      if (await _shouldUseOfflineQueueTransition(targetIndex)) {
        await _reopenQueueAtIndex(
          targetIndex,
          forcePlay: shouldBootstrapPlayback,
        );
        return;
      }
      if (targetSong != null &&
          _queueSongNeedsQueueRefresh(targetSong, targetIndex)) {
        await _reopenQueueAtIndex(
          targetIndex,
          forcePlay: shouldBootstrapPlayback,
        );
        return;
      }
      _primePendingTrackTransition(targetIndex);
      try {
        await _player.previous();
      } catch (error) {
        if (await _recoverTransitionFromError(targetIndex, error)) {
          return;
        }
        _clearTrackTransition();
        rethrow;
      }
    } finally {
      _queueNavigationInFlight = false;
    }
  }

  Future<void> seek(Duration target) async {
    await _player.seek(target);
  }

  Future<void> toggleShuffle() async {
    if (_isShuffleEnabled) {
      _debugPlayback('shuffle disabled to keep queue order sequential');
      await _player.setShuffle(false);
      return;
    }
    _statusMessage = 'Shuffle is disabled. Queue always plays in order.';
    notifyListeners();
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

  Future<void> setGaplessPlayback(bool value) async {
    _settings = _settings.copyWith(gaplessPlayback: value);
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> setOfflinePlaybackCacheEnabled(bool value) async {
    if (!_settings.offlinePlaybackCacheEnabled) {
      _settings = _settings.copyWith(offlinePlaybackCacheEnabled: true);
      await _saveSnapshot();
      notifyListeners();
    }
  }

  Future<void> setOfflineMusicMode(bool value) async {
    if (_settings.offlineMusicMode == value) {
      return;
    }
    _settings = _settings.copyWith(offlineMusicMode: value);
    if (value) {
      _onlineResults = <LibrarySong>[];
      _onlineError = 'Offline Music mode is on.';
      _trendingNowSongs = <LibrarySong>[];
      _trendingNowError = 'Offline Music mode is on.';
      _homeFeed = <HomeFeedSection>[];
      _personalizedHomeRecommendations = <SongRecommendation>[];
      _homeError = 'Offline Music mode is on.';
    } else if (!_isOffline) {
      _requestAutoHomeRefresh(force: true);
    }
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> setNextChanceSongCount(int value) async {
    final int normalized = value.clamp(0, 5);
    if (_settings.nextChanceSongCount == normalized) {
      return;
    }
    _settings = _settings.copyWith(nextChanceSongCount: normalized);
    await _saveSnapshot();
    if (normalized > 0) {
      unawaited(_maybeExtendSmartQueue(force: true));
    }
    unawaited(_refreshOfflinePlaybackCache(anchor: currentSong));
    notifyListeners();
  }

  Future<void> clearOfflinePlaybackCacheAndNotify() async {
    await _clearOfflinePlaybackCache();
    await _saveSnapshot();
    notifyListeners();
  }

  Future<void> resetDataUsageStats() async {
    _songPlaybackBytes.clear();
    _dataUsage = const AppDataUsageStats();
    _syncDataUsageState();
    await _saveSnapshot();
    notifyListeners();
  }

  Future<Directory> _offlinePlaybackCacheDirectory() async {
    final Directory root = await getApplicationSupportDirectory();
    final Directory dir = Directory(
      p.join(root.path, 'offline_playback_cache'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _clearOfflinePlaybackCache() async {
    _offlinePlaybackCacheEpoch += 1;
    _offlinePlaybackCacheQueue.clear();
    _offlinePlaybackCacheQueuedSongIds.clear();
    _offlinePlaybackPrefetchInFlight.clear();
    _offlinePlaybackCacheSizesBySongId.clear();
    _offlinePlaybackCacheProgressBytesBySongId.clear();
    _offlinePlaybackCacheExpectedBytesBySongId.clear();
    final Map<String, String> cachedPaths = Map<String, String>.from(
      _offlinePlaybackCachePaths,
    );
    _offlinePlaybackCachePaths.clear();
    for (final String songId in cachedPaths.keys) {
      final String? preparedUrl = _preparedMediaUrlsBySongId[songId];
      if (preparedUrl == cachedPaths[songId]) {
        _preparedMediaUrlsBySongId.remove(songId);
        _preparedMediaHeadersBySongId.remove(songId);
        _playbackStreamInfoBySongId.remove(songId);
      }
    }
    final Set<String> paths = <String>{...cachedPaths.values};
    final Directory dir = await _offlinePlaybackCacheDirectory();
    if (await dir.exists()) {
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is File) {
          paths.add(entity.path);
        }
      }
    }
    for (final String path in paths) {
      try {
        await _deleteFileIfExists(path);
      } catch (_) {}
    }
    _syncDataUsageState();
  }

  Future<void> _ensureSequentialPlayback() async {
    if (!_isShuffleEnabled) {
      return;
    }
    _debugPlayback('forcing sequential queue playback by disabling shuffle');
    await _player.setShuffle(false);
  }

  String _offlinePlaybackCacheFileName(LibrarySong song, String resolvedUrl) {
    final Uri? uri = Uri.tryParse(resolvedUrl);
    final String extension = p.extension(uri?.path ?? '').trim().isEmpty
        ? '.m4a'
        : p.extension(uri!.path);
    final String safeId = song.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '$safeId$extension';
  }

  Future<File> _offlinePlaybackCacheTargetFile(
    LibrarySong song,
    String resolvedUrl,
  ) async {
    final Directory dir = await _offlinePlaybackCacheDirectory();
    final String fileName = _offlinePlaybackCacheFileName(song, resolvedUrl);
    return File(p.join(dir.path, fileName));
  }

  Future<void> _deleteFileIfExists(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _maybePrimeAndroidPlaybackCache({
    required LibrarySong song,
    required String resolvedUrl,
    required Map<String, String>? upstreamHeaders,
  }) {
    if (!Platform.isAndroid ||
        !offlinePlaybackCacheEnabled ||
        !_shouldCacheSongForOfflinePlayback(song) ||
        _hasOfflinePlaybackCache(song.id) ||
        _offlinePlaybackPrefetchInFlight.contains(song.id) ||
        _isOffline ||
        offlineMusicMode ||
        _isDisposing ||
        _isDisposed ||
        resolvedUrl.trim().isEmpty) {
      return;
    }
    unawaited(
      _cacheResolvedSongForOfflinePlayback(
        song: song,
        resolvedUrl: resolvedUrl,
        upstreamHeaders: upstreamHeaders,
      ),
    );
  }

  Future<void> _cacheResolvedSongForOfflinePlayback({
    required LibrarySong song,
    required String resolvedUrl,
    required Map<String, String>? upstreamHeaders,
    bool manageInFlight = true,
  }) async {
    if (!offlinePlaybackCacheEnabled ||
        !_shouldCacheSongForOfflinePlayback(song) ||
        _hasOfflinePlaybackCache(song.id) ||
        _isDisposing ||
        _isDisposed) {
      return;
    }
    if (manageInFlight) {
      if (_offlinePlaybackPrefetchInFlight.contains(song.id)) {
        return;
      }
      _offlinePlaybackPrefetchInFlight.add(song.id);
    }

    try {
      final String? stalePath = _offlinePlaybackCachePaths[song.id];
      if (stalePath != null && !File(stalePath).existsSync()) {
        _dropOfflinePlaybackCacheEntry(song.id);
      }
      final List<_ResolvedRemotePlayback> attempts =
          await _resolveOfflineCacheAttempts(
            song,
            preferredResolvedUrl: resolvedUrl,
            preferredHeaders: upstreamHeaders,
          );
      if (attempts.isEmpty) {
        _debugPlayback(
          'cache.download skipped no cacheable stream '
          'song=${_debugSongLabel(song)}',
        );
        return;
      }

      Object? lastError;
      for (final _ResolvedRemotePlayback attempt in attempts) {
        try {
          await _downloadResolvedSongToOfflineCache(
            song: song,
            resolved: attempt,
          );
          _debugPlayback(
            'cache.download success song=${_debugSongLabel(song)} '
            '${attempt.streamInfo.debugSummary}',
          );
          return;
        } catch (error) {
          lastError = error;
          _debugPlayback(
            'cache.download failed song=${_debugSongLabel(song)} '
            '${attempt.streamInfo.debugSummary} error=$error',
          );
          _updateOfflinePlaybackCacheProgress(
            songId: song.id,
            bytesWritten: 0,
            expectedBytes: 0,
          );
        }
      }

      if (lastError != null) {
        throw lastError;
      }
    } catch (_) {
      final String? path = _offlinePlaybackCachePaths[song.id];
      if (path != null && !File(path).existsSync()) {
        _dropOfflinePlaybackCacheEntry(song.id);
      }
      if (_offlinePlaybackCachePathForSong(song.id) == null) {
        _offlinePlaybackCacheProgressBytesBySongId.remove(song.id);
        _offlinePlaybackCacheExpectedBytesBySongId.remove(song.id);
      }
    } finally {
      if (manageInFlight) {
        _offlinePlaybackPrefetchInFlight.remove(song.id);
      }
      _syncDataUsageState();
    }
  }

  bool _isOfflineCacheableTransport(PlaybackStreamTransport transport) {
    return transport.isNetwork && !transport.isHls;
  }

  Future<List<_ResolvedRemotePlayback>> _resolveOfflineCacheAttempts(
    LibrarySong song, {
    String? preferredResolvedUrl,
    Map<String, String>? preferredHeaders,
  }) async {
    if (!_looksLikeYouTube(song.path)) {
      final String directUrl = (preferredResolvedUrl ?? '').trim().isNotEmpty
          ? preferredResolvedUrl!.trim()
          : song.path;
      return <_ResolvedRemotePlayback>[
        _ResolvedRemotePlayback(
          resolvedUrl: directUrl,
          upstreamHeaders:
              preferredHeaders ?? _upstreamHeadersForUrl(song, directUrl),
          streamInfo: buildDirectPlaybackStreamInfo(song),
        ),
      ];
    }

    final List<PlaybackStreamCandidate> rankedCandidates =
        await _rankedPlaybackCandidatesForSong(song);
    if (rankedCandidates.isEmpty) {
      return const <_ResolvedRemotePlayback>[];
    }

    final List<int> orderedIndexes = <int>[];

    void addIndex(int index) {
      if (index < 0 || index >= rankedCandidates.length) {
        return;
      }
      if (!_isOfflineCacheableTransport(rankedCandidates[index].transport)) {
        return;
      }
      if (!orderedIndexes.contains(index)) {
        orderedIndexes.add(index);
      }
    }

    final String trimmedPreferredUrl = (preferredResolvedUrl ?? '').trim();
    if (trimmedPreferredUrl.isNotEmpty) {
      addIndex(
        rankedCandidates.indexWhere(
          (PlaybackStreamCandidate candidate) =>
              candidate.url == trimmedPreferredUrl,
        ),
      );
    }

    final int currentIndex = (_playbackCandidateIndexBySongId[song.id] ?? 0)
        .clamp(0, rankedCandidates.length - 1);
    addIndex(currentIndex);
    for (int index = 0; index < rankedCandidates.length; index += 1) {
      addIndex(index);
    }

    final Set<String> seenUrls = <String>{};
    final List<_ResolvedRemotePlayback> attempts = <_ResolvedRemotePlayback>[];
    for (final int index in orderedIndexes) {
      final PlaybackStreamResolution resolved = resolvePlaybackStreamAtIndex(
        songId: song.id,
        sourceLabel: song.sourceLabel,
        originalUrl: song.path,
        externalUrl: song.externalUrl,
        candidates: rankedCandidates,
        rankedCandidates: rankedCandidates,
        selectedIndex: index,
        selectionPolicy: index == currentIndex
            ? 'offline-cache-preferred'
            : 'offline-cache-fallback',
      );
      if (!seenUrls.add(resolved.url)) {
        continue;
      }
      attempts.add(
        _ResolvedRemotePlayback(
          resolvedUrl: resolved.url,
          upstreamHeaders: _upstreamHeadersForUrl(song, resolved.url),
          streamInfo: resolved.info,
        ),
      );
    }

    return attempts;
  }

  Future<void> _downloadResolvedSongToOfflineCache({
    required LibrarySong song,
    required _ResolvedRemotePlayback resolved,
  }) async {
    final int cacheEpoch = _offlinePlaybackCacheEpoch;
    final File target = await _offlinePlaybackCacheTargetFile(
      song,
      resolved.resolvedUrl,
    );
    final File temp = File('${target.path}.part');
    int bytesWritten = 0;
    final int estimatedExpectedBytes =
        _currentStreamSongDataBytes(song: song, info: resolved.streamInfo) ?? 0;

    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(
        Uri.parse(resolved.resolvedUrl),
      );
      resolved.upstreamHeaders?.forEach(request.headers.set);
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Cache download failed: ${response.statusCode}',
          uri: Uri.parse(resolved.resolvedUrl),
        );
      }
      await temp.parent.create(recursive: true);
      if (await temp.exists()) {
        await temp.delete();
      }
      final IOSink sink = temp.openWrite();
      final int? expectedBytes = response.contentLength >= 0
          ? response.contentLength
          : null;
      _updateOfflinePlaybackCacheProgress(
        songId: song.id,
        bytesWritten: 0,
        expectedBytes: expectedBytes ?? estimatedExpectedBytes,
      );
      try {
        await for (final List<int> chunk in response) {
          if (chunk.isEmpty) {
            continue;
          }
          sink.add(chunk);
          bytesWritten += chunk.length;
          _updateOfflinePlaybackCacheProgress(
            songId: song.id,
            bytesWritten: bytesWritten,
            expectedBytes: expectedBytes ?? estimatedExpectedBytes,
          );
        }
      } finally {
        await sink.close();
      }
      if (bytesWritten <= 0 ||
          (expectedBytes != null && expectedBytes != bytesWritten)) {
        await _deleteFileIfExists(temp.path);
        throw StateError('Incomplete cache download.');
      }
    } catch (_) {
      await _deleteFileIfExists(temp.path);
      rethrow;
    } finally {
      client.close(force: true);
    }

    if (cacheEpoch != _offlinePlaybackCacheEpoch) {
      await _deleteFileIfExists(temp.path);
      await _deleteFileIfExists(target.path);
      throw StateError('Offline cache epoch changed during download.');
    }

    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
    _offlinePlaybackCachePaths[song.id] = target.path;
    _offlinePlaybackCacheSizesBySongId[song.id] = bytesWritten;
    _preparedMediaUrlsBySongId[song.id] = target.path;
    _preparedMediaHeadersBySongId[song.id] = null;
    _playbackStreamInfoBySongId[song.id] = buildCachedPlaybackStreamInfo(
      song: song,
      cachedPath: target.path,
      previousInfo: resolved.streamInfo,
    );
    _updateOfflinePlaybackCacheProgress(
      songId: song.id,
      bytesWritten: bytesWritten,
      expectedBytes: bytesWritten,
    );
    unawaited(_saveSnapshot());
    notifyListeners();
  }

  Future<void> _cacheSongForOfflinePlayback(LibrarySong song) async {
    if (!offlinePlaybackCacheEnabled ||
        !_shouldCacheSongForOfflinePlayback(song) ||
        _offlinePlaybackPrefetchInFlight.contains(song.id) ||
        _hasOfflinePlaybackCache(song.id) ||
        _isDisposing ||
        _isDisposed) {
      return;
    }

    _offlinePlaybackPrefetchInFlight.add(song.id);
    try {
      await _cacheResolvedSongForOfflinePlayback(
        song: song,
        resolvedUrl: song.path,
        upstreamHeaders: _upstreamHeadersForUrl(song, song.path),
        manageInFlight: false,
      );
    } catch (_) {
      final String? path = _offlinePlaybackCachePaths[song.id];
      if (path != null && !File(path).existsSync()) {
        _dropOfflinePlaybackCacheEntry(song.id);
      }
    } finally {
      _offlinePlaybackPrefetchInFlight.remove(song.id);
    }
  }

  int? _offlinePlaybackCacheAnchorQueueIndex({LibrarySong? anchor}) {
    if (_queueSongIds.isEmpty) {
      return null;
    }
    if (anchor != null) {
      final int anchorIndex = _queueSongIds.indexOf(anchor.id);
      if (anchorIndex >= 0) {
        return anchorIndex;
      }
    }
    final int? playerIndex = _activePlayerQueueIndex();
    if (playerIndex != null) {
      return playerIndex;
    }
    if (_queueIndex < 0 || _queueIndex >= _queueSongIds.length) {
      return null;
    }
    return _queueIndex;
  }

  List<LibrarySong> _offlinePlaybackCacheCandidates({LibrarySong? anchor}) {
    if (!offlinePlaybackCacheEnabled) {
      return <LibrarySong>[];
    }
    final LibrarySong? target = anchor ?? currentSong;
    final int upcomingWindow = _settings.nextChanceSongCount.clamp(0, 5);
    final int? queueIndex = _offlinePlaybackCacheAnchorQueueIndex(
      anchor: target,
    );
    final List<LibrarySong> result = <LibrarySong>[];
    final Set<String> seenSongIds = <String>{};

    void addCandidate(LibrarySong? song) {
      if (song == null ||
          !_shouldCacheSongForOfflinePlayback(song) ||
          !seenSongIds.add(song.id)) {
        return;
      }
      result.add(song);
    }

    addCandidate(target);

    if (queueIndex != null && upcomingWindow > 0) {
      final int queueLength = _queueSongIds.length;
      int nextIndex = queueIndex;
      final Set<int> visitedIndexes = <int>{queueIndex};
      for (int offset = 0; offset < upcomingWindow; offset += 1) {
        nextIndex += 1;
        if (nextIndex >= queueLength) {
          if (_repeatMode != PlaylistMode.loop || queueLength <= 1) {
            break;
          }
          nextIndex = 0;
        }
        if (!visitedIndexes.add(nextIndex)) {
          break;
        }
        addCandidate(songById(_queueSongIds[nextIndex]));
      }
    }

    _debugPlayback(
      'cache.refresh candidates '
      'anchor=${_debugSongLabel(target)} '
      'queueIndex=${queueIndex ?? -1} '
      'upcomingWindow=$upcomingWindow '
      'count=${result.length} '
      'songs=${result.map((LibrarySong song) => song.id).join(', ')}',
    );
    return result;
  }

  void _enqueueOfflinePlaybackCacheSongs(List<LibrarySong> songs) {
    for (final LibrarySong song in songs) {
      if (!_shouldCacheSongForOfflinePlayback(song) ||
          _hasOfflinePlaybackCache(song.id) ||
          _offlinePlaybackPrefetchInFlight.contains(song.id) ||
          !_offlinePlaybackCacheQueuedSongIds.add(song.id)) {
        continue;
      }
      _offlinePlaybackCacheQueue.add(song.id);
    }
  }

  Future<void> _ensureOfflinePlaybackCacheWorkerRunning() {
    final Future<void>? activeWorker = _offlinePlaybackCacheWorker;
    if (activeWorker != null) {
      return activeWorker;
    }
    final Future<void> worker = () async {
      while (_offlinePlaybackCacheQueue.isNotEmpty &&
          !_isDisposed &&
          !_isDisposing &&
          offlinePlaybackCacheEnabled) {
        final String songId = _offlinePlaybackCacheQueue.removeAt(0);
        _offlinePlaybackCacheQueuedSongIds.remove(songId);
        final LibrarySong? song = songById(songId);
        if (song == null) {
          continue;
        }
        await _cacheSongForOfflinePlayback(song);
      }
    }();
    _offlinePlaybackCacheWorker = worker;
    return worker.whenComplete(() {
      if (identical(_offlinePlaybackCacheWorker, worker)) {
        _offlinePlaybackCacheWorker = null;
      }
    });
  }

  Future<void> _refreshOfflinePlaybackCache({LibrarySong? anchor}) async {
    if (!offlinePlaybackCacheEnabled) {
      await _clearOfflinePlaybackCache();
      return;
    }
    if (_isDisposing || _isDisposed) {
      return;
    }
    if (_refreshingOfflinePlaybackCache) {
      _offlinePlaybackCacheRefreshQueued = true;
      return;
    }
    _refreshingOfflinePlaybackCache = true;
    try {
      do {
        _offlinePlaybackCacheRefreshQueued = false;
        _offlinePlaybackCacheQueue.clear();
        _offlinePlaybackCacheQueuedSongIds.clear();
        final List<LibrarySong> candidates = _offlinePlaybackCacheCandidates(
          anchor: anchor,
        );
        _enqueueOfflinePlaybackCacheSongs(candidates);
        await _ensureOfflinePlaybackCacheWorkerRunning();
      } while (_offlinePlaybackCacheRefreshQueued);
    } finally {
      _refreshingOfflinePlaybackCache = false;
    }
  }

  Future<void> _reopenQueueAtIndex(
    int index, {
    bool forcePlay = false,
    bool preferDetached = false,
  }) async {
    if (index < 0 || index >= _queueSongIds.length) {
      return;
    }
    final List<LibrarySong> queue = queueSongs;
    if (queue.isEmpty || index >= queue.length) {
      return;
    }
    final bool openDetachedQueue =
        preferDetached ||
        offlineMusicMode ||
        await _resolveOfflineStateForAction();
    final List<LibrarySong> preparedQueue = List<LibrarySong>.from(queue);
    final List<int> preparationIndexes = openDetachedQueue
        ? <int>[index]
        : queueReopenPreparationIndexes(queue: queue, targetIndex: index);
    for (final int queueIndex in preparationIndexes) {
      final LibrarySong song = queue[queueIndex];
      if (queueIndex != index && !_queueSongNeedsPreparedMediaSource(song)) {
        continue;
      }
      preparedQueue[queueIndex] = await _preparePlayableSong(
        song,
        primeOfflineCache: queueIndex == index,
      );
    }
    final LibrarySong target = preparedQueue[index];

    _primePendingTrackTransition(index);
    try {
      final bool shouldResume = forcePlay || _isPlaying;
      if (shouldResume) {
        _beginPlaybackActivation(target, notify: false);
      }
      _debugPlayback(
        'queue.reopen start index=$index '
        'target=${_debugSongLabel(target)} '
        'shouldResume=$shouldResume '
        'forcePlay=$forcePlay '
        'currentIndex=$_queueIndex '
        'playerIndex=${_player.state.playlist.index} '
        'detached=$openDetachedQueue',
      );
      final List<String> preparedQueueSongIds = preparedQueue
          .map((LibrarySong song) => song.id)
          .toList();
      if (!openDetachedQueue) {
        _offlineDetachedQueueMode = false;
        _primeOfflineQueueActivation(
          targetSongId: target.id,
          targetIndex: index,
          queueSongIds: preparedQueueSongIds,
        );
        _queueSongIds = preparedQueueSongIds;
      } else {
        _offlineDetachedQueueMode = true;
      }
      _queueIndex = index;
      notifyListeners();
      await _ensureSequentialPlayback();
      if (openDetachedQueue) {
        await _player.open(Playlist(<Media>[_mediaForSong(target)]));
      } else {
        await _player.open(
          Playlist(preparedQueue.map(_mediaForSong).toList(), index: index),
        );
      }
      if (shouldResume) {
        await _player.play();
      }
      _clearOfflineQueueActivationState();
      _resolveTrackTransition(preparedQueue[index]);
      _trackPlayback(preparedQueue[index].id);
      unawaited(_refreshOfflinePlaybackCache(anchor: preparedQueue[index]));
      _debugPlayback(
        'queue.reopen complete index=$index '
        'target=${_debugSongLabel(preparedQueue[index])}',
      );
      notifyListeners();
    } catch (_) {
      _debugPlayback('queue.reopen failed index=$index');
      _clearOfflineQueueActivationState();
      _offlineDetachedQueueMode = false;
      _clearTrackTransition();
      rethrow;
    }
  }

  bool _queueSongNeedsPreparedMediaSource(LibrarySong song) {
    if (!songNeedsResolvedPlaybackUrl(song)) {
      return false;
    }
    if (_offlinePlaybackCachePathForSong(song.id) != null) {
      return false;
    }
    final String? prepared = _preparedMediaUrlsBySongId[song.id];
    return prepared == null || prepared.isEmpty || prepared == song.path;
  }

  Future<bool> _tryHandleOfflineTargetTransition(
    int targetIndex, {
    bool bootstrapPlayback = false,
  }) async {
    final bool offline = await _resolveOfflineStateForAction();
    if (!offlineMusicMode && !offline) {
      return false;
    }
    if (targetIndex < 0 || targetIndex >= _queueSongIds.length) {
      return false;
    }
    final LibrarySong? targetSong = songById(_queueSongIds[targetIndex]);
    if (targetSong == null) {
      return false;
    }
    final bool canOpenNow =
        !targetSong.isRemote ||
        _offlinePlaybackCachePathForSong(targetSong.id) != null;
    if (canOpenNow) {
      await _reopenQueueAtIndex(targetIndex, forcePlay: bootstrapPlayback);
      return true;
    }
    await _enterOfflineQueueWait(targetIndex);
    return true;
  }

  bool _shouldBootstrapPlaybackForQueueNavigation() {
    return !_isPlaying &&
        _queueSongIds.isNotEmpty &&
        currentSong != null &&
        _player.state.playlist.medias.isEmpty;
  }

  Future<bool> _shouldUseOfflineQueueTransition(int targetIndex) async {
    final bool offline = await _resolveOfflineStateForAction();
    if (offlineMusicMode || offline) {
      _debugPlayback(
        'queue.transition offline shortcut '
        'targetIndex=$targetIndex offline=$offline offlineMode=$offlineMusicMode',
      );
      return true;
    }
    if (targetIndex < 0 || targetIndex >= _queueSongIds.length) {
      return false;
    }
    final LibrarySong? targetSong = songById(_queueSongIds[targetIndex]);
    if (targetSong == null || !targetSong.isRemote) {
      return false;
    }
    if (_offlinePlaybackCachePathForSong(targetSong.id) == null) {
      return false;
    }
    final bool online = await refreshConnectivityStatus(
      notify: false,
      syncOfflineMode: false,
      announceLoss: true,
    );
    _debugPlayback(
      'queue.transition connectivity check '
      'targetIndex=$targetIndex target=${_debugSongLabel(targetSong)} online=$online',
    );
    return !online;
  }

  Future<bool> _recoverTransitionFromError(
    int targetIndex,
    Object error,
  ) async {
    _debugPlayback(
      'transition.recover check '
      'targetIndex=$targetIndex error=$error',
    );
    if (!_isConnectivityError(error)) {
      return false;
    }
    _setConnectivityOffline(true, notify: false, announceLoss: true);
    if (targetIndex < 0 || targetIndex >= _queueSongIds.length) {
      return false;
    }
    final LibrarySong? targetSong = songById(_queueSongIds[targetIndex]);
    if (targetSong == null ||
        _offlinePlaybackCachePathForSong(targetSong.id) == null) {
      return false;
    }
    _debugPlayback(
      'transition.recover reopening cached target '
      'targetIndex=$targetIndex target=${_debugSongLabel(targetSong)}',
    );
    await _reopenQueueAtIndex(targetIndex);
    return true;
  }

  void _primePendingTrackTransition(int targetIndex) {
    final LibrarySong? pending = songById(_queueSongIds[targetIndex]);
    if (pending == null) {
      return;
    }
    _clearOfflineQueueWait(notify: false);
    _transitioningSongId = pending.id;
    _transitioningQueueIndex = targetIndex;
    _pendingSelectionSong = pending;
    _position = Duration.zero;
    _duration = Duration.zero;
    _debugPlayback(
      'transition.prime index=$targetIndex song=${_debugSongLabel(pending)} '
      'queueIndex=$_queueIndex',
    );
    notifyListeners();
  }

  bool _shouldHoldTransitionMetrics() {
    if (_offlineQueueActivationTargetSongId != null) {
      return true;
    }
    if (_offlineQueueWaitingSongId != null) {
      return true;
    }
    final String? transitioningSongId = _transitioningSongId;
    if (transitioningSongId == null) {
      return false;
    }
    final LibrarySong? active = currentSong;
    return active == null || active.id != transitioningSongId;
  }

  void _resolveTrackTransition(LibrarySong? song) {
    if (song == null) {
      return;
    }
    if (_offlineQueueWaitingSongId == song.id) {
      _clearOfflineQueueWait(notify: false);
    }
    if (_transitioningSongId == song.id) {
      _transitioningSongId = null;
      _transitioningQueueIndex = null;
    }
    _offlineQueueAdvancePending = false;
    final LibrarySong? pending = _pendingSelectionSong;
    if (pending == null || pending.id == song.id) {
      _pendingSelectionSong = null;
    }
    _debugPlayback(
      'transition.resolve song=${_debugSongLabel(song)} '
      'pending=${_debugSongLabel(_pendingSelectionSong)} '
      'transitionSong=$_transitioningSongId '
      'transitionIndex=$_transitioningQueueIndex '
      'queueIndex=$_queueIndex',
    );
  }

  void _clearTrackTransition() {
    _transitioningSongId = null;
    _transitioningQueueIndex = null;
    _pendingSelectionSong = null;
    _debugPlayback('transition.clear queueIndex=$_queueIndex');
    notifyListeners();
  }

  Future<void> _enterOfflineQueueWait(int targetIndex) async {
    if (targetIndex < 0 || targetIndex >= _queueSongIds.length) {
      return;
    }
    final LibrarySong? targetSong = songById(_queueSongIds[targetIndex]);
    if (targetSong == null) {
      return;
    }
    _offlineQueueWaitingSongId = targetSong.id;
    _offlineQueueWaitingIndex = targetIndex;
    _queueIndex = targetIndex;
    _transitioningSongId = targetSong.id;
    _transitioningQueueIndex = targetIndex;
    _pendingSelectionSong = targetSong;
    _position = Duration.zero;
    _duration = Duration.zero;
    _statusMessage = 'Waiting for internet to continue queue';
    _clearPlaybackActivation();
    _debugPlayback(
      'offline.wait enter '
      'targetIndex=$targetIndex song=${_debugSongLabel(targetSong)}',
    );
    try {
      await _player.pause();
    } catch (_) {}
    notifyListeners();
  }

  void _clearOfflineQueueWait({bool notify = true}) {
    if (_offlineQueueWaitingSongId == null &&
        _offlineQueueWaitingIndex == null) {
      return;
    }
    _offlineQueueWaitingSongId = null;
    _offlineQueueWaitingIndex = null;
    _statusMessage = null;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _resumeOfflineWaitingQueue() async {
    final int? targetIndex = _offlineQueueWaitingIndex;
    final bool offline = await _resolveOfflineStateForAction();
    if (targetIndex == null || offline || offlineMusicMode) {
      return;
    }
    if (targetIndex < 0 || targetIndex >= _queueSongIds.length) {
      _clearOfflineQueueWait();
      return;
    }
    final LibrarySong? targetSong = songById(_queueSongIds[targetIndex]);
    _debugPlayback(
      'offline.wait resume '
      'targetIndex=$targetIndex target=${_debugSongLabel(targetSong)}',
    );
    _clearOfflineQueueWait(notify: false);
    await _reopenQueueAtIndex(targetIndex);
    await play();
  }

  void _primeOfflineQueueActivation({
    required String targetSongId,
    required int targetIndex,
    required List<String> queueSongIds,
  }) {
    _offlineQueueActivationTargetSongId = targetSongId;
    _offlineQueueActivationTargetIndex = targetIndex;
    _offlineQueueActivationSongIds = List<String>.from(queueSongIds);
    _transitioningSongId = targetSongId;
    _transitioningQueueIndex = targetIndex;
    _pendingSelectionSong = songById(targetSongId) ?? _pendingSelectionSong;
    _debugPlayback(
      'offline.activation prime target=$targetSongId '
      'targetIndex=$targetIndex queueLen=${queueSongIds.length}',
    );
  }

  void _clearOfflineQueueActivationState() {
    _offlineQueueActivationTargetSongId = null;
    _offlineQueueActivationTargetIndex = null;
    _offlineQueueActivationSongIds = null;
  }

  void _debugPlayback(String message) {
    debugPrint('[PlaybackDebug] $message');
  }

  String _debugSongLabel(LibrarySong? song) {
    if (song == null) {
      return 'null';
    }
    return '${song.id}("${song.title}" by "${song.artist}")';
  }

  int? _queueProgressIndex() {
    if (_queueSongIds.isEmpty) {
      return null;
    }
    if (_offlineDetachedQueueMode ||
        _offlineQueueWaitingSongId != null ||
        !_playerQueueHasControllerPlaylist()) {
      if (_queueIndex < 0 || _queueIndex >= _queueSongIds.length) {
        return null;
      }
      return _queueIndex;
    }
    return _activePlayerQueueIndex() ?? _queueIndex;
  }

  int? _nextQueueIndex({bool respectSingleRepeat = true}) {
    if (_queueSongIds.isEmpty) {
      return null;
    }
    final int? currentIndex = _queueProgressIndex();
    if (currentIndex == null) {
      return null;
    }
    if (respectSingleRepeat && _repeatMode == PlaylistMode.single) {
      return currentIndex;
    }
    if (currentIndex < _queueSongIds.length - 1) {
      return currentIndex + 1;
    }
    if (_repeatMode == PlaylistMode.loop) {
      return 0;
    }
    return null;
  }

  int? _previousQueueIndex({bool respectSingleRepeat = true}) {
    if (_queueSongIds.isEmpty) {
      return null;
    }
    final int? currentIndex = _queueProgressIndex();
    if (currentIndex == null) {
      return null;
    }
    if (respectSingleRepeat && _repeatMode == PlaylistMode.single) {
      return currentIndex;
    }
    if (currentIndex > 0) {
      return currentIndex - 1;
    }
    if (_repeatMode == PlaylistMode.loop) {
      return _queueSongIds.length - 1;
    }
    return null;
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
    final String trimmed = name.trim();
    final String playlistName = trimmed.isEmpty ? 'Untitled Playlist' : trimmed;
    final DateTime now = DateTime.now();
    final UserPlaylist playlist = UserPlaylist(
      id: _uuid.v4(),
      name: playlistName,
      songIds: <String>[],
      createdAt: now,
      updatedAt: now,
    );
    _playlists = <UserPlaylist>[playlist, ..._playlists];
    await _saveSnapshot();
    notifyListeners();
    await _syncPlaylistToCloud(playlist);
    return playlist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists = _playlists
        .where((UserPlaylist playlist) => playlist.id != playlistId)
        .toList();
    await _saveSnapshot();
    notifyListeners();
    await _deletePlaylistFromCloud(playlistId);
  }

  Future<void> renamePlaylist(String playlistId, String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _playlists =
        _playlists
            .map(
              (UserPlaylist playlist) => playlist.id == playlistId
                  ? playlist.copyWith(name: trimmed, updatedAt: DateTime.now())
                  : playlist,
            )
            .toList()
          ..sort(_sortUserPlaylists);
    await _saveSnapshot();
    notifyListeners();
    final UserPlaylist? updated = _playlists.firstWhereOrNull(
      (UserPlaylist playlist) => playlist.id == playlistId,
    );
    if (updated != null) {
      await _syncPlaylistToCloud(updated);
    }
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
    }).toList()..sort(_sortUserPlaylists);
    await _saveSnapshot();
    notifyListeners();
    final UserPlaylist? updated = _playlists.firstWhereOrNull(
      (UserPlaylist playlist) => playlist.id == playlistId,
    );
    if (updated != null) {
      await _syncPlaylistToCloud(updated);
    }
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
    }).toList()..sort(_sortUserPlaylists);
    await _saveSnapshot();
    notifyListeners();
    final UserPlaylist? updated = _playlists.firstWhereOrNull(
      (UserPlaylist playlist) => playlist.id == playlistId,
    );
    if (updated != null) {
      await _syncPlaylistToCloud(updated);
    }
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
    await _syncLikedSongToCloud(songId: songId, isLiked: newLiked);
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
    if (newDisliked) {
      final String dislikedKey = _songIdentityKey(base);
      _personalizedHomeRecommendations = _personalizedHomeRecommendations
          .where(
            (SongRecommendation item) =>
                _songIdentityKey(item.song) != dislikedKey,
          )
          .toList(growable: false);
    }
    await _saveSnapshot();
    if (newDisliked) {
      final bool isCurrentSong = currentSong?.id == songId;
      await _removeQueuedSongInstances(base, keepCurrent: isCurrentSong);
      if (isCurrentSong) {
        await _skipDislikedCurrentSong(
          songById(songId) ?? base.copyWith(isDisliked: true, isLiked: false),
        );
      }
    }
    notifyListeners();
    await _syncDislikedSongToCloud(songId: songId, isDisliked: newDisliked);
  }

  void _rememberTransientSong(LibrarySong song) {
    if (song.isRemote) {
      final LibrarySong? existing = _transientSongsById[song.id];
      if (existing == null) {
        _transientSongsById[song.id] = _withKnownCloudPreferenceState(song);
        return;
      }
      _transientSongsById[song.id] = _withKnownCloudPreferenceState(
        song.copyWith(
          playCount: existing.playCount,
          lastPlayedAt: existing.lastPlayedAt,
          isLiked: existing.isLiked,
          isDisliked: existing.isDisliked,
        ),
      );
    }
  }

  void _trackPlayback(String songId) {
    final DateTime now = DateTime.now();
    _finalizeActivePlaybackSession(nextSongId: songId);
    final LibrarySong? currentSong = songById(songId);
    final bool shouldTrack =
        currentSong != null && _shouldUseSongForHistorySignals(currentSong);
    final int index = _songs.indexWhere(
      (LibrarySong song) => song.id == songId,
    );
    if (shouldTrack && index >= 0) {
      final LibrarySong song = _songs[index];
      _songs[index] = song.copyWith(
        playCount: song.playCount + 1,
        lastPlayedAt: now,
      );
    } else if (shouldTrack) {
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
    _scheduleSnapshotSave();
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

  String currentStreamSongDataLabel({
    required LibrarySong song,
    required PlaybackStreamInfo info,
    required String fallbackLabel,
  }) {
    final int? bytes = _currentStreamSongDataBytes(song: song, info: info);
    if (bytes != null && bytes > 0) {
      return formatDataSize(bytes);
    }
    return fallbackLabel;
  }

  String currentCacheProgressLabel({
    required LibrarySong song,
    required String fallbackLabel,
  }) {
    final (int bytes, int _) = _currentSongCacheProgress(song.id);
    if (bytes > 0) {
      return formatDataSize(bytes);
    }
    return fallbackLabel;
  }

  (int, int) _currentSongCacheProgress(String songId) {
    final int bytes = _offlinePlaybackCacheProgressBytesBySongId[songId] ?? 0;
    int expected = _offlinePlaybackCacheExpectedBytesBySongId[songId] ?? 0;
    if (expected <= 0) {
      expected = _estimatedSourceSizeBytes(songId) ?? 0;
    }
    final LibrarySong? song = songById(songId);
    final PlaybackStreamInfo? info = _playbackStreamInfoBySongId[songId];
    final int? fullSize = song == null || info == null
        ? null
        : _currentStreamSongDataBytes(song: song, info: info);
    if (fullSize != null && fullSize > 0) {
      if (expected <= 0 || expected < fullSize) {
        expected = fullSize;
      }
      if (info != null &&
          (info.transport == PlaybackStreamTransport.cachedFile ||
              info.transport == PlaybackStreamTransport.localFile)) {
        return (fullSize, fullSize);
      }
    }
    return (bytes.clamp(0, expected > 0 ? expected : bytes), expected);
  }

  void _updateOfflinePlaybackCacheProgress({
    required String songId,
    required int bytesWritten,
    int? expectedBytes,
  }) {
    final int normalizedBytes = math.max(0, bytesWritten);
    final int previousBytes =
        _offlinePlaybackCacheProgressBytesBySongId[songId] ?? 0;
    _offlinePlaybackCacheProgressBytesBySongId[songId] = normalizedBytes;
    final int normalizedExpected = math.max(0, expectedBytes ?? 0);
    if (normalizedExpected > 0) {
      _offlinePlaybackCacheExpectedBytesBySongId[songId] = normalizedExpected;
    } else {
      final int? estimated = _estimatedSourceSizeBytes(songId);
      if (estimated != null && estimated > 0) {
        _offlinePlaybackCacheExpectedBytesBySongId[songId] = estimated;
      }
    }
    final int delta = normalizedBytes - previousBytes;
    if (delta > 0) {
      _recordStreamBytes(songId, delta);
      return;
    }
  }

  int? _estimatedSourceSizeBytes(String songId, {LibrarySong? fallbackSong}) {
    final LibrarySong? song = fallbackSong ?? songById(songId);
    final PlaybackStreamInfo? info = _playbackStreamInfoBySongId[songId];
    if (song == null || info == null) {
      return null;
    }
    return _currentStreamSongDataBytes(song: song, info: info);
  }

  int? _currentStreamSongDataBytes({
    required LibrarySong song,
    required PlaybackStreamInfo info,
  }) {
    if (info.transport == PlaybackStreamTransport.cachedFile) {
      final int? cachedSize = _offlinePlaybackCacheSizesBySongId[song.id];
      if (cachedSize != null && cachedSize > 0) {
        return cachedSize;
      }
      final String? cachedPath = _offlinePlaybackCachePathForSong(song.id);
      if (cachedPath != null) {
        final File cachedFile = File(cachedPath);
        if (cachedFile.existsSync()) {
          final int length = cachedFile.lengthSync();
          _offlinePlaybackCacheSizesBySongId[song.id] = length;
          return length;
        }
      }
    }

    if (info.transport == PlaybackStreamTransport.localFile) {
      final File localFile = File(info.resolvedUrl);
      if (localFile.existsSync()) {
        return localFile.lengthSync();
      }
    }

    final int? bitrate = info.bitrateBitsPerSecond;
    final int durationMs = math.max(
      song.durationMs,
      currentSong?.id == song.id ? _duration.inMilliseconds : 0,
    );
    if (bitrate != null && bitrate > 0 && durationMs > 0) {
      return ((bitrate * durationMs) / 8000).round();
    }
    final int consumedBytes = _songPlaybackBytes[song.id] ?? 0;
    return consumedBytes > 0 ? consumedBytes : null;
  }

  void _finalizeActivePlaybackSession({String? nextSongId}) {
    final String? songId = _activePlaybackSongId;
    if (songId == null || songId == nextSongId) {
      return;
    }
    if (!_offlinePlaybackPrefetchInFlight.contains(songId)) {
      _offlinePlaybackCacheProgressBytesBySongId.remove(songId);
      _offlinePlaybackCacheExpectedBytesBySongId.remove(songId);
    }
    if (!_shouldUseSongIdForHistorySignals(songId)) {
      _activePlaybackSongId = null;
      _activePlaybackCompletionRatio = 0;
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
    _scheduleSnapshotSave();
  }

  Future<void> _loadSnapshot() async {
    final File file = await _snapshotFile();
    if (!await file.exists()) {
      return;
    }

    late final Map<String, dynamic> json;
    try {
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        await file.delete();
        return;
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Snapshot root is not a JSON object.');
      }
      json = decoded;
    } on FormatException catch (error) {
      debugPrint('Snapshot load skipped due to invalid JSON: $error');
      await file.delete();
      return;
    }

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
    _prunePlaybackHistory();
    _searchDraft = json['searchDraft'] as String? ?? '';
    _recentSearchTerms =
        (json['recentSearchTerms'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic item) => item as String)
            .where((String item) => item.trim().isNotEmpty)
            .take(8)
            .toList(growable: false);
    final Map<String, dynamic> cachedPathsJson =
        json['offlinePlaybackCachePaths'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    _offlinePlaybackCachePaths
      ..clear()
      ..addEntries(
        cachedPathsJson.entries
            .map(
              (MapEntry<String, dynamic> item) =>
                  MapEntry<String, String>(item.key, item.value as String),
            )
            .where((MapEntry<String, String> item) {
              return _isOfflinePlaybackCacheFileUsable(item.value);
            }),
      );
    _offlinePlaybackCacheSizesBySongId
      ..clear()
      ..addEntries(
        _offlinePlaybackCachePaths.entries.map(
          (MapEntry<String, String> item) =>
              MapEntry<String, int>(item.key, File(item.value).lengthSync()),
        ),
      );
    _purgeRestrictedDurationOfflinePlaybackCacheEntries();
    final List<String> restoredQueueSongIds =
        (json['queueSongIds'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic item) => item as String)
            .where((String songId) {
              final LibrarySong? song = songById(songId);
              return song != null && song.isRemote;
            })
            .toList(growable: false);
    _queueSongIds = restoredQueueSongIds;
    final int restoredQueueIndex = (json['queueIndex'] as num?)?.toInt() ?? 0;
    _queueIndex = restoredQueueSongIds.isEmpty
        ? 0
        : restoredQueueIndex.clamp(0, restoredQueueSongIds.length - 1);
    final String restoredQueueLabel =
        json['queueLabel'] as String? ?? 'Now Playing';
    _queueLabel = restoredQueueLabel.trim().isEmpty
        ? 'Now Playing'
        : restoredQueueLabel;
    final AppDataUsageStats restoredDataUsage = AppDataUsageStats.fromJson(
      json['dataUsage'] as Map<String, dynamic>?,
    );
    _dataUsage = restoredDataUsage.copyWith(
      totalBytes: 0,
      streamBytes: restoredDataUsage.streamBytes,
      cacheBytes: 0,
      currentSongBytes: 0,
      clearCurrentSongId: true,
      currentCacheBytes: 0,
      currentCacheExpectedBytes: 0,
      clearCurrentCacheSongId: true,
    );
    _dataUsage = _dataUsage.copyWith(
      totalBytes: _dataUsage.streamBytes + _dataUsage.otherBytes,
    );
    dataUsageState.value = _dataUsage;
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
        'queueSongIds': _queueSongIds
            .where((String songId) => songById(songId) != null)
            .toList(growable: false),
        'queueIndex': _queueIndex,
        'queueLabel': _queueLabel,
        'searchDraft': _searchDraft,
        'recentSearchTerms': _recentSearchTerms,
        'offlinePlaybackCachePaths': _offlinePlaybackCachePaths,
        'dataUsage': _dataUsage.toJson(),
      }),
    );
  }

  Future<File> _snapshotFile() async {
    final Directory root = await getApplicationSupportDirectory();
    return File(p.join(root.path, 'musix_flutter_state.json'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      clearSearchState();
      _finalizeActivePlaybackSession();
      unawaited(_saveSnapshot());
    }
  }

  @override
  void dispose() {
    if (_isDisposed || _isDisposing) {
      return;
    }
    _isDisposing = true;
    _finalizeActivePlaybackSession();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_saveSnapshot());
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _dataUsageSnapshotTimer?.cancel();
    _dataUsageSnapshotTimer = null;
    _playbackActivationTimer?.cancel();
    _playbackActivationTimer = null;
    unawaited(_cloudUserDataSubscription?.cancel());
    _cloudUserDataSubscription = null;
    unawaited(_notificationActionSubscription?.cancel());
    _notificationActionSubscription = null;
    unawaited(_windowsMediaActionSubscription?.cancel());
    _windowsMediaActionSubscription = null;
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
    unawaited(AndroidMediaNotificationBridge.stop());
    unawaited(WindowsMediaControlsBridge.stop());
    _ytMusic?.close();
    _yt.close();
    unawaited(_playbackProxy.dispose());
    _isDisposed = true;
    nowPlayingState.dispose();
    playbackProgressState.dispose();
    dataUsageState.dispose();
    final Player? player = _playerInstance;
    if (player != null) {
      unawaited(player.stop());
      unawaited(player.dispose());
      _playerInstance = null;
    }
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

class _ActivePlaybackProxy {
  const _ActivePlaybackProxy({
    required this.sessionId,
    required this.proxyUrl,
    required this.upstreamUrl,
    required this.upstreamHeaders,
  });

  final String sessionId;
  final String proxyUrl;
  final String upstreamUrl;
  final Map<String, String>? upstreamHeaders;
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

class _PreparedPlaybackSource {
  const _PreparedPlaybackSource({
    required this.mediaUrl,
    this.mediaHeaders,
    required this.streamInfo,
  });

  final String mediaUrl;
  final Map<String, String>? mediaHeaders;
  final PlaybackStreamInfo streamInfo;
}

class _ResolvedRemotePlayback {
  const _ResolvedRemotePlayback({
    required this.resolvedUrl,
    required this.streamInfo,
    this.upstreamHeaders,
  });

  final String resolvedUrl;
  final PlaybackStreamInfo streamInfo;
  final Map<String, String>? upstreamHeaders;
}
