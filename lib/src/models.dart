import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

enum AppDestination {
  home('Home', Icons.home_rounded, Icons.home_outlined),
  library('Library', Icons.library_music_rounded, Icons.library_music_outlined),
  search('Search', Icons.manage_search_rounded, Icons.search_rounded),
  history('History', Icons.history_rounded, Icons.history_toggle_off_rounded),
  settings(
    'Profile',
    Icons.account_circle_rounded,
    Icons.person_outline_rounded,
  );

  const AppDestination(this.label, this.selectedIcon, this.unselectedIcon);

  final String label;
  final IconData selectedIcon;
  final IconData unselectedIcon;
}

enum LibraryFilter {
  all('All'),
  songs('Songs'),
  folders('Folders'),
  artists('Artists'),
  albums('Albums'),
  playlists('Playlists');

  const LibraryFilter(this.label);

  final String label;
}

class AppRegion {
  const AppRegion({
    required this.countryCode,
    required this.label,
    required this.languageCode,
  });

  final String countryCode;
  final String label;
  final String languageCode;
}

const List<AppRegion> kAppRegions = <AppRegion>[
  AppRegion(countryCode: 'LK', label: 'Sri Lanka', languageCode: 'si'),
  AppRegion(countryCode: 'IN', label: 'India', languageCode: 'hi'),
  AppRegion(countryCode: 'PK', label: 'Pakistan', languageCode: 'ur'),
  AppRegion(countryCode: 'BD', label: 'Bangladesh', languageCode: 'bn'),
  AppRegion(countryCode: 'NP', label: 'Nepal', languageCode: 'ne'),
  AppRegion(
    countryCode: 'AE',
    label: 'United Arab Emirates',
    languageCode: 'ar',
  ),
  AppRegion(countryCode: 'SA', label: 'Saudi Arabia', languageCode: 'ar'),
  AppRegion(countryCode: 'QA', label: 'Qatar', languageCode: 'ar'),
  AppRegion(countryCode: 'SG', label: 'Singapore', languageCode: 'en'),
  AppRegion(countryCode: 'MY', label: 'Malaysia', languageCode: 'ms'),
  AppRegion(countryCode: 'TH', label: 'Thailand', languageCode: 'th'),
  AppRegion(countryCode: 'ID', label: 'Indonesia', languageCode: 'id'),
  AppRegion(countryCode: 'PH', label: 'Philippines', languageCode: 'en'),
  AppRegion(countryCode: 'US', label: 'United States', languageCode: 'en'),
  AppRegion(countryCode: 'GB', label: 'United Kingdom', languageCode: 'en'),
  AppRegion(countryCode: 'CA', label: 'Canada', languageCode: 'en'),
  AppRegion(countryCode: 'AU', label: 'Australia', languageCode: 'en'),
  AppRegion(countryCode: 'NZ', label: 'New Zealand', languageCode: 'en'),
  AppRegion(countryCode: 'DE', label: 'Germany', languageCode: 'de'),
  AppRegion(countryCode: 'FR', label: 'France', languageCode: 'fr'),
  AppRegion(countryCode: 'IT', label: 'Italy', languageCode: 'it'),
  AppRegion(countryCode: 'ES', label: 'Spain', languageCode: 'es'),
  AppRegion(countryCode: 'NL', label: 'Netherlands', languageCode: 'nl'),
  AppRegion(countryCode: 'SE', label: 'Sweden', languageCode: 'sv'),
  AppRegion(countryCode: 'NO', label: 'Norway', languageCode: 'no'),
  AppRegion(countryCode: 'DK', label: 'Denmark', languageCode: 'da'),
  AppRegion(countryCode: 'FI', label: 'Finland', languageCode: 'fi'),
  AppRegion(countryCode: 'TR', label: 'Turkey', languageCode: 'tr'),
  AppRegion(countryCode: 'BR', label: 'Brazil', languageCode: 'pt'),
  AppRegion(countryCode: 'MX', label: 'Mexico', languageCode: 'es'),
  AppRegion(countryCode: 'AR', label: 'Argentina', languageCode: 'es'),
  AppRegion(countryCode: 'ZA', label: 'South Africa', languageCode: 'en'),
  AppRegion(countryCode: 'JP', label: 'Japan', languageCode: 'ja'),
  AppRegion(countryCode: 'KR', label: 'South Korea', languageCode: 'ko'),
];

class AppSettings {
  const AppSettings({
    this.themeModeIndex = 0,
    this.denseLibrary = false,
    this.useGridView = true,
    this.playbackRate = 1.0,
    this.smartQueueEnabled = true,
    this.gaplessPlayback = true,
    this.offlinePlaybackCacheEnabled = true,
    this.offlineMusicMode = false,
    this.nextChanceSongCount = 0,
    this.preferredCountryCode = 'LK',
    this.ytMusicAuthJson,
  });

  final int themeModeIndex;
  final bool denseLibrary;
  final bool useGridView;
  final double playbackRate;
  final bool smartQueueEnabled;
  final bool gaplessPlayback;
  final bool offlinePlaybackCacheEnabled;
  final bool offlineMusicMode;
  final int nextChanceSongCount;
  final String preferredCountryCode;
  final String? ytMusicAuthJson;

  ThemeMode get themeMode {
    if (themeModeIndex < 0 || themeModeIndex >= ThemeMode.values.length) {
      return ThemeMode.system;
    }
    return ThemeMode.values[themeModeIndex];
  }

  AppSettings copyWith({
    int? themeModeIndex,
    bool? denseLibrary,
    bool? useGridView,
    double? playbackRate,
    bool? smartQueueEnabled,
    bool? gaplessPlayback,
    bool? offlinePlaybackCacheEnabled,
    bool? offlineMusicMode,
    int? nextChanceSongCount,
    String? preferredCountryCode,
    String? ytMusicAuthJson,
  }) {
    return AppSettings(
      themeModeIndex: themeModeIndex ?? this.themeModeIndex,
      denseLibrary: denseLibrary ?? this.denseLibrary,
      useGridView: useGridView ?? this.useGridView,
      playbackRate: playbackRate ?? this.playbackRate,
      smartQueueEnabled: smartQueueEnabled ?? this.smartQueueEnabled,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      offlinePlaybackCacheEnabled:
          offlinePlaybackCacheEnabled ?? this.offlinePlaybackCacheEnabled,
      offlineMusicMode: offlineMusicMode ?? this.offlineMusicMode,
      nextChanceSongCount: nextChanceSongCount ?? this.nextChanceSongCount,
      preferredCountryCode: preferredCountryCode ?? this.preferredCountryCode,
      ytMusicAuthJson: ytMusicAuthJson ?? this.ytMusicAuthJson,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'themeModeIndex': themeModeIndex,
      'denseLibrary': denseLibrary,
      'useGridView': useGridView,
      'playbackRate': playbackRate,
      'smartQueueEnabled': smartQueueEnabled,
      'gaplessPlayback': gaplessPlayback,
      'offlinePlaybackCacheEnabled': offlinePlaybackCacheEnabled,
      'offlineMusicMode': offlineMusicMode,
      'nextChanceSongCount': nextChanceSongCount,
      'preferredCountryCode': preferredCountryCode,
      'ytMusicAuthJson': ytMusicAuthJson,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AppSettings();
    }

    final String preferredCountryCode =
        (json['preferredCountryCode'] as String? ?? 'LK').trim().toUpperCase();
    final int nextChanceSongCount =
        (json['nextChanceSongCount'] as num?)?.toInt().clamp(0, 5) ?? 0;

    return AppSettings(
      themeModeIndex: (json['themeModeIndex'] as num?)?.toInt() ?? 0,
      denseLibrary: json['denseLibrary'] as bool? ?? false,
      useGridView: json['useGridView'] as bool? ?? true,
      playbackRate: (json['playbackRate'] as num?)?.toDouble() ?? 1.0,
      smartQueueEnabled: json['smartQueueEnabled'] as bool? ?? true,
      gaplessPlayback: json['gaplessPlayback'] as bool? ?? true,
      offlinePlaybackCacheEnabled:
          json['offlinePlaybackCacheEnabled'] as bool? ?? true,
      offlineMusicMode: json['offlineMusicMode'] as bool? ?? false,
      nextChanceSongCount: nextChanceSongCount,
      preferredCountryCode: preferredCountryCode.isEmpty
          ? 'LK'
          : preferredCountryCode,
      ytMusicAuthJson: json['ytMusicAuthJson'] as String?,
    );
  }
}

class LibrarySong {
  const LibrarySong({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.folderName,
    required this.folderPath,
    required this.sourceLabel,
    required this.addedAt,
    required this.durationMs,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayedAt,
    this.isRemote = false,
    this.artworkUrl,
    this.externalUrl,
    this.isLiked = false,
    this.isDisliked = false,
  });

  final String id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final String folderName;
  final String folderPath;
  final String sourceLabel;
  final DateTime addedAt;
  final int durationMs;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final bool isFavorite;
  final int playCount;
  final DateTime? lastPlayedAt;
  final bool isRemote;
  final String? artworkUrl;
  final String? externalUrl;
  final bool isLiked;
  final bool isDisliked;

  Duration get duration => Duration(milliseconds: durationMs.clamp(0, 1 << 31));

  String get subtitle {
    if (artist.trim().isEmpty) {
      return album;
    }
    return '$artist • $album';
  }

  LibrarySong copyWith({
    String? path,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? folderName,
    String? folderPath,
    String? sourceLabel,
    DateTime? addedAt,
    int? durationMs,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayedAt,
    bool? isRemote,
    String? artworkUrl,
    String? externalUrl,
    bool? isLiked,
    bool? isDisliked,
  }) {
    return LibrarySong(
      id: id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      folderName: folderName ?? this.folderName,
      folderPath: folderPath ?? this.folderPath,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      addedAt: addedAt ?? this.addedAt,
      durationMs: durationMs ?? this.durationMs,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isRemote: isRemote ?? this.isRemote,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      externalUrl: externalUrl ?? this.externalUrl,
      isLiked: isLiked ?? this.isLiked,
      isDisliked: isDisliked ?? this.isDisliked,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtist': albumArtist,
      'folderName': folderName,
      'folderPath': folderPath,
      'sourceLabel': sourceLabel,
      'addedAt': addedAt.toIso8601String(),
      'durationMs': durationMs,
      'genre': genre,
      'year': year,
      'trackNumber': trackNumber,
      'discNumber': discNumber,
      'isFavorite': isFavorite,
      'playCount': playCount,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'isRemote': isRemote,
      'artworkUrl': artworkUrl,
      'externalUrl': externalUrl,
      'isLiked': isLiked,
      'isDisliked': isDisliked,
    };
  }

  factory LibrarySong.fromJson(Map<String, dynamic> json) {
    return LibrarySong(
      id: json['id'] as String,
      path: json['path'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String? ?? 'Unknown artist',
      album: json['album'] as String? ?? 'Unknown album',
      albumArtist: json['albumArtist'] as String? ?? 'Unknown artist',
      folderName: json['folderName'] as String? ?? 'Library',
      folderPath: json['folderPath'] as String? ?? '',
      sourceLabel: json['sourceLabel'] as String? ?? 'Library',
      addedAt:
          DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      genre: json['genre'] as String?,
      year: (json['year'] as num?)?.toInt(),
      trackNumber: (json['trackNumber'] as num?)?.toInt(),
      discNumber: (json['discNumber'] as num?)?.toInt(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      lastPlayedAt: DateTime.tryParse(json['lastPlayedAt'] as String? ?? ''),
      isRemote: json['isRemote'] as bool? ?? false,
      artworkUrl: json['artworkUrl'] as String?,
      externalUrl: json['externalUrl'] as String?,
      isLiked: json['isLiked'] as bool? ?? false,
      isDisliked: json['isDisliked'] as bool? ?? false,
    );
  }
}

class UserPlaylist {
  const UserPlaylist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> songIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserPlaylist copyWith({
    String? name,
    List<String>? songIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPlaylist(
      id: id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'songIds': songIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserPlaylist.fromJson(Map<String, dynamic> json) {
    return UserPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      songIds: (json['songIds'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic item) => item as String)
          .toList(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class PlaybackEntry {
  const PlaybackEntry({
    required this.songId,
    required this.playedAt,
    this.completionRatio = 0,
    this.listenedToEnd = false,
  });

  final String songId;
  final DateTime playedAt;
  final double completionRatio;
  final bool listenedToEnd;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'songId': songId,
      'playedAt': playedAt.toIso8601String(),
      'completionRatio': completionRatio,
      'listenedToEnd': listenedToEnd,
    };
  }

  factory PlaybackEntry.fromJson(Map<String, dynamic> json) {
    return PlaybackEntry(
      songId: json['songId'] as String,
      playedAt:
          DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.now(),
      completionRatio: (json['completionRatio'] as num?)?.toDouble() ?? 0,
      listenedToEnd: json['listenedToEnd'] as bool? ?? false,
    );
  }
}

class AlbumCollection {
  const AlbumCollection({
    required this.id,
    required this.title,
    required this.artist,
    required this.songs,
  });

  final String id;
  final String title;
  final String artist;
  final List<LibrarySong> songs;

  LibrarySong get leadSong => songs.first;
  int get songCount => songs.length;
  int get totalPlays => songs.fold<int>(
    0,
    (int total, LibrarySong song) => total + song.playCount,
  );
  Duration get totalDuration => songs.fold<Duration>(
    Duration.zero,
    (Duration total, LibrarySong song) => total + song.duration,
  );
}

class ArtistCollection {
  const ArtistCollection({
    required this.id,
    required this.name,
    required this.songs,
  });

  final String id;
  final String name;
  final List<LibrarySong> songs;

  LibrarySong get leadSong => songs.first;
  int get albumCount =>
      songs.map((LibrarySong song) => song.album).toSet().length;
  int get totalPlays => songs.fold<int>(
    0,
    (int total, LibrarySong song) => total + song.playCount,
  );
}

class FolderCollection {
  const FolderCollection({
    required this.id,
    required this.name,
    required this.path,
    required this.songs,
  });

  final String id;
  final String name;
  final String path;
  final List<LibrarySong> songs;

  LibrarySong get leadSong => songs.first;
}

class HomeFeedSection {
  const HomeFeedSection({
    required this.title,
    required this.subtitle,
    required this.query,
    required this.songs,
  });

  final String title;
  final String subtitle;
  final String query;
  final List<LibrarySong> songs;
}

class SongRecommendation {
  const SongRecommendation({
    required this.song,
    required this.reason,
    this.isExploratory = false,
  });

  final LibrarySong song;
  final String reason;
  final bool isExploratory;
}

class NowPlayingState {
  const NowPlayingState({
    this.song,
    this.isLoading = false,
    this.isShuffleEnabled = false,
    this.repeatMode = PlaylistMode.none,
    this.queueIndex = 0,
    this.queueLength = 0,
  });

  final LibrarySong? song;
  final bool isLoading;
  final bool isShuffleEnabled;
  final PlaylistMode repeatMode;
  final int queueIndex;
  final int queueLength;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NowPlayingState &&
            runtimeType == other.runtimeType &&
            song == other.song &&
            isLoading == other.isLoading &&
            isShuffleEnabled == other.isShuffleEnabled &&
            repeatMode == other.repeatMode &&
            queueIndex == other.queueIndex &&
            queueLength == other.queueLength;
  }

  @override
  int get hashCode => Object.hash(
    song,
    isLoading,
    isShuffleEnabled,
    repeatMode,
    queueIndex,
    queueLength,
  );
}

class PlaybackProgressState {
  const PlaybackProgressState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackProgressState &&
            runtimeType == other.runtimeType &&
            isPlaying == other.isPlaying &&
            position == other.position &&
            duration == other.duration;
  }

  @override
  int get hashCode => Object.hash(isPlaying, position, duration);
}
