import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'app_controller.dart';
import 'models.dart';

class OuterTuneApp extends StatelessWidget {
  const OuterTuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    final OuterTuneController controller = context.watch<OuterTuneController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OuterTune Flutter',
      themeMode: controller.settings.themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const OuterTuneShell(),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B7D73),
    brightness: brightness,
  );

  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
  );

  final TextTheme body = GoogleFonts.ibmPlexSansTextTheme(base.textTheme);
  final TextTheme display = GoogleFonts.spaceGroteskTextTheme(body);

  return base.copyWith(
    textTheme: body.copyWith(
      displayLarge: display.displayLarge,
      displayMedium: display.displayMedium,
      displaySmall: display.displaySmall,
      headlineLarge: display.headlineLarge,
      headlineMedium: display.headlineMedium,
      headlineSmall: display.headlineSmall,
      titleLarge: display.titleLarge,
      titleMedium: display.titleMedium,
      titleSmall: display.titleSmall,
    ),
  );
}

class OuterTuneShell extends StatefulWidget {
  const OuterTuneShell({super.key});

  @override
  State<OuterTuneShell> createState() => _OuterTuneShellState();
}

class _OuterTuneShellState extends State<OuterTuneShell> {
  AppDestination _destination = AppDestination.home;
  LibraryFilter _libraryFilter = LibraryFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        context
            .read<OuterTuneController>()
            .ensureNotificationPermissionIfNeeded(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final OuterTuneController controller = context.watch<OuterTuneController>();
    final bool wide = MediaQuery.sizeOf(context).width >= 960;

    final Widget content = Column(
      children: <Widget>[
        if (controller.scanning) const LinearProgressIndicator(minHeight: 3),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildPage(context, controller),
          ),
        ),
        if (wide && controller.miniPlayerSong != null)
          _MiniPlayer(
            controller: controller,
            onOpenPlayer: () => _openPlayer(context, controller),
          ),
      ],
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF120503),
      body: Row(
        children: <Widget>[
          if (wide)
            NavigationRail(
              selectedIndex: _destination.index,
              extended: MediaQuery.sizeOf(context).width >= 1240,
              onDestinationSelected: (int index) {
                setState(() => _destination = AppDestination.values[index]);
              },
              destinations: AppDestination.values
                  .map(
                    (AppDestination item) => NavigationRailDestination(
                      icon: Icon(item.unselectedIcon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
          Expanded(child: content),
        ],
      ),

      bottomNavigationBar: wide
          ? null
          : _MobileBottomChrome(
              controller: controller,
              onOpenPlayer: () => _openPlayer(context, controller),
              child: _KineticBottomNav(
                destination: _destination,
                onDestinationChanged: (AppDestination value) {
                  setState(() => _destination = value);
                },
              ),
            ),
    );
  }

  Widget _buildPage(BuildContext context, OuterTuneController controller) {
    return switch (_destination) {
      AppDestination.home => _HomeScreen(
        key: const ValueKey<String>('home'),
        controller: controller,
        onOpenSearch: () =>
            setState(() => _destination = AppDestination.search),
      ),
      AppDestination.library => _LibraryScreen(
        key: const ValueKey<String>('library'),
        controller: controller,
        filter: _libraryFilter,
        onFilterChanged: (LibraryFilter value) {
          setState(() => _libraryFilter = value);
        },
      ),
      AppDestination.search => _SearchScreen(
        key: const ValueKey<String>('search'),
        controller: controller,
      ),
      AppDestination.history => _HistoryScreen(
        key: const ValueKey<String>('history'),
        controller: controller,
      ),
      AppDestination.settings => _SettingsScreen(
        key: const ValueKey<String>('settings'),
        controller: controller,
      ),
    };
  }

  Future<void> _openPlayer(
    BuildContext context,
    OuterTuneController controller,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            _PlayerScreen(controller: controller),
      ),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  const _HomeScreen({
    super.key,
    required this.controller,
    required this.onOpenSearch,
  });

  final OuterTuneController controller;
  final VoidCallback onOpenSearch;

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _onScroll() async {
    // Home recommendations are intentionally static for this app session.
  }

  @override
  Widget build(BuildContext context) {
    final OuterTuneController controller = widget.controller;

    final List<HomeFeedSection> feed = controller.homeFeed
        .where((HomeFeedSection section) {
          final String key = section.title.trim().toLowerCase();
          return key != 'trending now' && key != 'chill rotation';
        })
        .toList(growable: false);
    final bool homeFeedPending = controller.homeLoading && feed.isEmpty;
    final List<LibrarySong> mayYouLikeFull = _resolvedMayYouLikeSongs(
      controller,
    );
    final List<LibrarySong> mayYouLike = mayYouLikeFull
        .take(4)
        .toList(growable: false);

    final List<LibrarySong> jumpBackIn = controller.recentlyPlayedSongs
        .take(4)
        .toList(growable: false);

    final _FeaturedHeroData featured = _pickFeaturedHero(
      context: context,
      controller: controller,
      feed: feed,
      mayYouLike: mayYouLikeFull,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF140804),
            Color(0xFF211008),
            Color(0xFF0D0503),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: <Widget>[
          RefreshIndicator(
            color: const Color(0xFFFF8A2A),
            backgroundColor: const Color(0xFF2A1007),
            onRefresh: () => controller.refreshHomeFeed(force: true),
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: <Widget>[
                const SizedBox(height: 6),
                _KineticTopBar(onOpenSearch: widget.onOpenSearch),
                const SizedBox(height: 14),
                if (homeFeedPending)
                  const _KineticHeroSkeleton()
                else
                  _KineticHeroCard(
                    badge: featured.badge,
                    title: featured.title,
                    subtitle: featured.subtitle,
                    imageUrl: featured.imageUrl,
                    onListenNow: featured.onListenNow,
                  ),
                const SizedBox(height: 18),
                _KineticSectionHeader(
                  title: 'MAY YOU LIKE',
                  onViewAll: () {
                    if (mayYouLikeFull.isEmpty) {
                      widget.onOpenSearch();
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            _MayYouLikeScreen(controller: controller),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                if (homeFeedPending)
                  const _KineticListSkeleton(count: 4)
                else if (mayYouLike.isEmpty)
                  const _PersonalizationHintCard(
                    message:
                        'Play, like, and finish songs to train your personalized May You Like section.',
                  )
                else
                  Column(
                    children: List<Widget>.generate(mayYouLike.length, (
                      int index,
                    ) {
                      final LibrarySong song = mayYouLike[index];
                      return _KineticPopularTrackTile(
                        index: index + 1,
                        song: song,
                        onTap: () {
                          if (song.isRemote) {
                            controller.playOnlineSong(song);
                          } else {
                            controller.playSong(song, label: 'May you like');
                          }
                        },
                      );
                    }),
                  ),
                if (jumpBackIn.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  _KineticSectionHeader(
                    title: 'JUMP BACK IN',
                    onViewAll: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              _RecentPlaysScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _KineticJumpBackGrid(
                    items: jumpBackIn,
                    onTapItem: (LibrarySong song) {
                      if (song.isRemote) {
                        controller.playOnlineSong(song);
                      } else {
                        controller.playSong(song, label: 'Jump back in');
                      }
                    },
                  ),
                ],
                // Infinite feed: render remaining shelves as scroll continues.
                ..._buildMoreShelves(
                  context: context,
                  controller: controller,
                  skipCount: 1,
                ),
                if (controller.homeLoading) ...<Widget>[
                  const SizedBox(height: 16),
                  const Opacity(opacity: 0.8, child: _HomeFeedSkeleton()),
                ],
              ],
            ),
          ),
          if (controller.isOffline)
            Positioned.fill(
              child: _NoInternetOverlay(
                onRefresh: () async {
                  final bool online = await controller
                      .refreshConnectivityStatus();
                  if (online) {
                    await controller.refreshHomeFeed(force: true);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NoInternetOverlay extends StatelessWidget {
  const _NoInternetOverlay({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.68),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Card(
              color: const Color(0xFF2A1007),
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0x66FF8A2A)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Color(0xFFFFA25E),
                      size: 34,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No internet connection',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.splineSans(
                        color: const Color(0xFFFFE8DA),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reconnect to load your online recommendations.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.splineSans(
                        color: const Color(0xFFFFC8A9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onRefresh,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8A2A),
                          foregroundColor: const Color(0xFF2D1308),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          'Refresh',
                          style: GoogleFonts.splineSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonalizationHintCard extends StatelessWidget {
  const _PersonalizationHintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1007),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x44FF8A2A)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFFFC8A9),
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

List<Widget> _buildMoreShelves({
  required BuildContext context,
  required OuterTuneController controller,
  int skipCount = 0,
}) {
  final List<HomeFeedSection> sections = controller.homeFeed
      .where((HomeFeedSection section) {
        final String key = section.title.trim().toLowerCase();
        return key != 'trending now' && key != 'chill rotation';
      })
      .toList(growable: false);
  final HomeFeedSection? featuredArtistSection = _pickSingleArtistSection(
    sections,
  );
  final List<HomeFeedSection> normalizedSections = sections
      .where((HomeFeedSection section) {
        if (_isArtistNamedSection(section)) {
          return identical(section, featuredArtistSection);
        }
        return true;
      })
      .toList(growable: false);
  if (normalizedSections.length <= skipCount) return <Widget>[];

  return normalizedSections
      .skip(skipCount)
      .map((HomeFeedSection section) {
        final List<LibrarySong> songs = section.songs
            .take(6)
            .toList(growable: false);
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _KineticSectionHeader(
                title: section.title.toUpperCase(),
                onViewAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => _PopularTracksScreen(
                        controller: controller,
                        title: section.title.toUpperCase(),
                        songs: section.songs,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ...songs.asMap().entries.map((MapEntry<int, LibrarySong> e) {
                final LibrarySong song = e.value;
                return _KineticPopularTrackTile(
                  index: e.key + 1,
                  song: song,
                  onTap: () {
                    if (song.isRemote) {
                      controller.playOnlineSong(song);
                    } else {
                      controller.playSong(song, label: section.title);
                    }
                  },
                );
              }),
            ],
          ),
        );
      })
      .toList(growable: false);
}

bool _isArtistNamedSection(HomeFeedSection section) {
  final String title = section.title.trim().toLowerCase();
  return title.startsWith('from ') && !title.contains('youtube music');
}

HomeFeedSection? _pickSingleArtistSection(List<HomeFeedSection> sections) {
  final List<HomeFeedSection> artistSections = sections
      .where(_isArtistNamedSection)
      .toList(growable: false);
  if (artistSections.isEmpty) {
    return null;
  }
  artistSections.sort((HomeFeedSection a, HomeFeedSection b) {
    final int songCompare = b.songs.length.compareTo(a.songs.length);
    if (songCompare != 0) {
      return songCompare;
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return artistSections.first;
}

class _SearchGenreShelf {
  const _SearchGenreShelf({
    required this.title,
    required this.query,
    required this.colors,
    required this.assetPath,
    this.fallbackAssetPath,
    this.song,
  });

  final String title;
  final String query;
  final List<Color> colors;
  final String assetPath;
  final String? fallbackAssetPath;
  final LibrarySong? song;
}

List<_SearchGenreShelf> _buildSearchGenreShelves(
  OuterTuneController controller,
) {
  final List<LibrarySong> pool = <LibrarySong>[
    ..._resolvedMayYouLikeSongs(controller),
    ...controller.recentlyAddedSongs,
    ...controller.songs,
  ];

  LibrarySong? pickSong(List<String> tokens) {
    for (final LibrarySong song in pool) {
      final String text = '${song.genre ?? ''} ${song.title} ${song.artist}'
          .toLowerCase();
      if (tokens.any(text.contains)) {
        return song;
      }
    }
    return pool.firstOrNull;
  }

  return <_SearchGenreShelf>[
    _SearchGenreShelf(
      title: 'Hip-Hop',
      query: 'hip hop',
      colors: const <Color>[Color(0xFF6E2BDE), Color(0xFF3B1B7A)],
      assetPath: 'assets/img/hip_hop.png',
      fallbackAssetPath: 'assets/images/Hip-Hop.png',
      song: pickSong(<String>['hip hop', 'rap', 'trap']),
    ),
    _SearchGenreShelf(
      title: 'Pop',
      query: 'pop',
      colors: const <Color>[Color(0xFFE92D7A), Color(0xFFB11A55)],
      assetPath: 'assets/img/pop.png',
      fallbackAssetPath: 'assets/images/Pop.png',
      song: pickSong(<String>['pop', 'dance pop', 'synthpop']),
    ),
    _SearchGenreShelf(
      title: 'Electronic',
      query: 'electronic',
      colors: const <Color>[Color(0xFF2A6CF6), Color(0xFF173C93)],
      assetPath: 'assets/img/electronic.png',
      fallbackAssetPath: 'assets/images/Electronic.png',
      song: pickSong(<String>['electronic', 'house', 'edm', 'techno']),
    ),
    _SearchGenreShelf(
      title: 'Jazz',
      query: 'jazz',
      colors: const <Color>[Color(0xFFEF6A0D), Color(0xFF9C3A00)],
      assetPath: 'assets/img/jazz.png',
      fallbackAssetPath: 'assets/images/Jazz.png',
      song: pickSong(<String>['jazz', 'blues', 'sax']),
    ),
    _SearchGenreShelf(
      title: 'Chill & Focus',
      query: 'chill focus',
      colors: const <Color>[Color(0xFF0E9383), Color(0xFF0B5E54)],
      assetPath: 'assets/img/chill_focus.png',
      fallbackAssetPath: 'assets/images/Chill.png',
      song: pickSong(<String>['chill', 'ambient', 'lofi', 'focus']),
    ),
  ];
}

List<LibrarySong> _resolvedMayYouLikeSongs(OuterTuneController controller) {
  return _resolvedMayYouLikeRecommendations(
    controller,
  ).map((SongRecommendation item) => item.song).toList(growable: false);
}

List<SongRecommendation> _resolvedMayYouLikeRecommendations(
  OuterTuneController controller,
) {
  if (controller.personalizedHomeRecommendations.isNotEmpty) {
    return controller.personalizedHomeRecommendations;
  }
  return _buildMayYouLike(controller.homeFeed)
      .map(
        (LibrarySong song) => SongRecommendation(
          song: song,
          reason: 'Picked from your current recommendation feed',
        ),
      )
      .toList(growable: false);
}

List<LibrarySong> _buildMayYouLike(List<HomeFeedSection> feed) {
  if (feed.isEmpty) {
    return <LibrarySong>[];
  }

  final List<LibrarySong> all = <LibrarySong>[
    for (final HomeFeedSection section in feed) ...section.songs,
  ];

  final Set<String> seen = <String>{};
  final List<LibrarySong> unique = <LibrarySong>[
    for (final LibrarySong song in all)
      if (seen.add('${song.artist.toLowerCase()}::${song.title.toLowerCase()}'))
        if (seen.add(song.id)) song,
  ];

  // First pass: filter out low-quality / repetitive meditation-type results
  // that tend to dominate anonymous recommendations.
  final List<LibrarySong> filtered = unique
      .where((LibrarySong s) => !_isFilteredSuggestion(s))
      .toList(growable: false);

  List<LibrarySong> ranked = filtered.isNotEmpty ? filtered : unique;
  ranked = List<LibrarySong>.from(ranked);
  ranked.sort((LibrarySong a, LibrarySong b) {
    final int artCompare = _hasArtwork(b).compareTo(_hasArtwork(a));
    if (artCompare != 0) return artCompare;

    final int durationCompare = _durationScore(b).compareTo(_durationScore(a));
    if (durationCompare != 0) return durationCompare;

    final int titleCompare = _titleScore(b).compareTo(_titleScore(a));
    if (titleCompare != 0) return titleCompare;

    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  return ranked;
}

List<LibrarySong> _buildMonthlyTrendingNow({
  required OuterTuneController controller,
}) {
  final List<LibrarySong> seed = List<LibrarySong>.from(
    controller.trendingNowSongs,
  );
  final Set<String> seen = <String>{};
  return <LibrarySong>[
    for (final LibrarySong song in seed)
      if (seen.add('${song.artist.toLowerCase()}::${song.title.toLowerCase()}'))
        song,
  ];
}

String _lastMonthLabel() {
  final DateTime now = DateTime.now();
  final DateTime lastMonth = DateTime(now.year, now.month - 1);
  return DateFormat('MMMM').format(lastMonth);
}

int _hasArtwork(LibrarySong song) {
  return (song.artworkUrl ?? '').trim().isEmpty ? 0 : 1;
}

int _durationScore(LibrarySong song) {
  final int seconds = song.duration.inSeconds;
  // Prefer typical music-length tracks (avoid 1h “mix” style dominating).
  if (seconds == 0) return 1;
  if (seconds >= 120 && seconds <= 360) return 5; // 2-6 minutes
  if (seconds >= 60 && seconds < 120) return 3;
  if (seconds > 360 && seconds <= 600) return 2;
  if (seconds > 600) return 0;
  return 1;
}

int _titleScore(LibrarySong song) {
  final int len = song.title.trim().length;
  if (len <= 28) return 4;
  if (len <= 48) return 3;
  if (len <= 72) return 2;
  return 0;
}

bool _isFilteredSuggestion(LibrarySong song) {
  if (song.isDisliked) {
    return true;
  }
  final String text = '${song.title} ${song.artist} ${song.album}'
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Heuristic blacklist: these tend to flood anonymous YT recommendations.
  const List<String> badTokens = <String>[
    ' hz',
    'binaural',
    'healing',
    'meditation',
    'sleep',
    'study music',
    'focus music',
    'focus for work',
    'deep focus',
    'concentration',
    'productivity',
    'zen',
    'alpha waves',
    'beta waves',
    'theta',
    '432hz',
    '528hz',
    '741hz',
    'frequency',
    'chakra',
    'aura',
  ];
  for (final String token in badTokens) {
    if (text.contains(token)) {
      return true;
    }
  }

  // Very long tracks also correlate with those categories.
  if (song.duration.inMinutes >= 20) {
    return true;
  }

  return false;
}

class _FeaturedHeroData {
  const _FeaturedHeroData({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.onListenNow,
    this.imageUrl,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onListenNow;
}

_FeaturedHeroData _pickFeaturedHero({
  required BuildContext context,
  required OuterTuneController controller,
  required List<HomeFeedSection> feed,
  required List<LibrarySong> mayYouLike,
}) {
  final LibrarySong? song = _pickAdvancedHeroSong(
    controller: controller,
    feed: feed,
    mayYouLike: mayYouLike,
  );
  if (song != null) {
    return _FeaturedHeroData(
      badge: 'PICK FOR YOU',
      title: song.title.toUpperCase(),
      subtitle: song.artist.trim().isEmpty ? song.album : song.artist,
      imageUrl: song.artworkUrl,
      onListenNow: () {
        if (song.isRemote) {
          controller.playOnlineSong(song);
        } else {
          controller.playSong(song, label: 'Home');
        }
      },
    );
  }

  return _FeaturedHeroData(
    badge: 'DISCOVER',
    title: 'KINETIC',
    subtitle: 'Search and play songs to unlock smarter recommendations.',
    onListenNow: controller.importFolder,
  );
}

LibrarySong? _pickAdvancedHeroSong({
  required OuterTuneController controller,
  required List<HomeFeedSection> feed,
  required List<LibrarySong> mayYouLike,
}) {
  final Set<String> historyIds = controller.history
      .map((PlaybackEntry entry) => entry.songId)
      .toSet();
  final List<LibrarySong> historySongs = controller.history
      .map((PlaybackEntry entry) => controller.songById(entry.songId))
      .whereType<LibrarySong>()
      .toList(growable: false);

  final Set<String> seen = <String>{};
  final List<LibrarySong> candidates =
      <LibrarySong>[
            ...mayYouLike,
            for (final HomeFeedSection section in feed) ...section.songs,
            ...controller.onlineResults,
          ]
          .where((LibrarySong song) {
            final String key =
                '${song.title.toLowerCase()}::${song.artist.toLowerCase()}';
            return seen.add(key);
          })
          .toList(growable: false);
  if (candidates.isEmpty) {
    return null;
  }

  final Map<String, double> artistAffinity = <String, double>{};
  final Map<String, double> genreAffinity = <String, double>{};
  final Map<String, double> languageAffinity = <String, double>{};
  final Map<String, double> vibeAffinity = <String, double>{};

  for (int i = 0; i < historySongs.length; i += 1) {
    final LibrarySong song = historySongs[i];
    final double weight = math.max(1, 28 - i).toDouble();
    final String artist = song.artist.trim().toLowerCase();
    final String genre = (song.genre ?? '').trim().toLowerCase();
    final String language = _songLanguageToken(song);
    if (artist.isNotEmpty) {
      artistAffinity[artist] = (artistAffinity[artist] ?? 0) + weight;
    }
    if (genre.isNotEmpty) {
      genreAffinity[genre] = (genreAffinity[genre] ?? 0) + weight;
    }
    languageAffinity[language] = (languageAffinity[language] ?? 0) + weight;
    for (final String token in _heroVibeTokens(song)) {
      vibeAffinity[token] = (vibeAffinity[token] ?? 0) + (weight * 0.7);
    }
  }

  final List<LibrarySong> favorites = controller.likedSongs
      .take(12)
      .toList(growable: false);
  for (int i = 0; i < favorites.length; i += 1) {
    final LibrarySong song = favorites[i];
    final String artist = song.artist.trim().toLowerCase();
    if (artist.isNotEmpty) {
      artistAffinity[artist] = (artistAffinity[artist] ?? 0) + (12 - i);
    }
  }

  final List<_HeroCandidateScore> ranked =
      candidates
          .map((LibrarySong song) {
            double score = 0;
            final String artist = song.artist.trim().toLowerCase();
            final String genre = (song.genre ?? '').trim().toLowerCase();
            final String language = _songLanguageToken(song);
            final bool unheard =
                !historyIds.contains(song.id) && song.playCount == 0;
            final bool mostlyUnheard = !historyIds.contains(song.id);

            if (unheard) {
              score += 80;
            } else if (mostlyUnheard) {
              score += 42;
            } else {
              score -= 18;
            }

            score += artistAffinity[artist] ?? 0;
            score += (genreAffinity[genre] ?? 0) * 0.9;
            score += (languageAffinity[language] ?? 0) * 0.8;
            for (final String vibe in _heroVibeTokens(song)) {
              score += vibeAffinity[vibe] ?? 0;
            }

            if ((song.artworkUrl ?? '').trim().isNotEmpty) {
              score += 6;
            }
            final int seconds = song.duration.inSeconds;
            if (seconds >= 120 && seconds <= 360) {
              score += 5;
            } else if (seconds > 0 && seconds < 480) {
              score += 2;
            }
            if (song.isRemote) {
              score += 2;
            }
            if (_isFilteredSuggestion(song)) {
              score -= 30;
            }

            return _HeroCandidateScore(song: song, score: score);
          })
          .toList(growable: false)
        ..sort((_HeroCandidateScore a, _HeroCandidateScore b) {
          final int scoreCompare = b.score.compareTo(a.score);
          if (scoreCompare != 0) {
            return scoreCompare;
          }
          return a.song.title.toLowerCase().compareTo(
            b.song.title.toLowerCase(),
          );
        });

  return ranked.firstOrNull?.song;
}

String _songLanguageToken(LibrarySong song) {
  final String text =
      '${song.title} ${song.artist} ${song.album} ${song.genre ?? ''}'.trim();
  if (RegExp(r'[඀-෿]').hasMatch(text)) {
    return 'sinhala';
  }
  if (RegExp(r'[஀-௿]').hasMatch(text)) {
    return 'tamil';
  }
  if (RegExp(r'[a-zA-Z]').hasMatch(text)) {
    return 'english';
  }
  return 'unknown';
}

Set<String> _heroVibeTokens(LibrarySong song) {
  final String text =
      '${song.title} ${song.artist} ${song.album} ${song.genre ?? ''}'
          .toLowerCase();
  final Set<String> tokens = <String>{};
  const Map<String, List<String>> groups = <String, List<String>>{
    'chill': <String>['chill', 'calm', 'soft', 'acoustic', 'lofi'],
    'energy': <String>['dance', 'party', 'energy', 'anthem', 'beat'],
    'romance': <String>['love', 'romance', 'heart', 'feel', 'melody'],
    'sad': <String>['sad', 'cry', 'pain', 'broken', 'lonely'],
    'focus': <String>['focus', 'study', 'piano', 'instrumental'],
  };
  groups.forEach((String vibe, List<String> words) {
    if (words.any(text.contains)) {
      tokens.add(vibe);
    }
  });
  return tokens;
}

class _HeroCandidateScore {
  const _HeroCandidateScore({required this.song, required this.score});

  final LibrarySong song;
  final double score;
}

class _KineticTopBar extends StatelessWidget {
  const _KineticTopBar({required this.onOpenSearch});

  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        Text(
          'KINETIC',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            letterSpacing: 3.2,
            color: Colors.white.withValues(alpha: 0.92),
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.settings_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

class _KineticHeroCard extends StatelessWidget {
  const _KineticHeroCard({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onListenNow,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onListenNow;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.6,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxHeight < 235;
          return ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (imageUrl != null && imageUrl!.trim().isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    Color(0xFF2A160C),
                                    Color(0xFF0B0A0C),
                                    Color(0xFF0B0A0C),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            );
                          },
                    ),
                  )
                else
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Color(0xFF2A160C),
                          Color(0xFF0B0A0C),
                          Color(0xFF0B0A0C),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    compact ? 12 : 14,
                    16,
                    compact ? 10 : 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10 : 12,
                          vertical: compact ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFE06A2D,
                          ).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(
                              0xFFE06A2D,
                            ).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          badge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xFFE06A2D),
                                letterSpacing: compact ? 1.2 : 1.6,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      SizedBox(height: compact ? 6 : 8),
                      Text(
                        title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              height: 0.95,
                              fontSize: compact ? 34 : null,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                      ),
                      SizedBox(height: compact ? 6 : 8),
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                height: 1.22,
                                color: Colors.white.withValues(alpha: 0.68),
                              ),
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      FilledButton(
                        onPressed: onListenNow,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE06A2D),
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: compact ? 8 : 10,
                          ),
                          minimumSize: Size(double.infinity, compact ? 38 : 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(Icons.play_arrow_rounded, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'LISTEN NOW',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(letterSpacing: 1.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KineticSectionHeader extends StatelessWidget {
  const _KineticSectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.55),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: Size.zero,
          ),
          child: Text(
            'VIEW ALL',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 1.4),
          ),
        ),
      ],
    );
  }
}

class _KineticPopularTrackTile extends StatelessWidget {
  const _KineticPopularTrackTile({
    required this.index,
    required this.song,
    required this.onTap,
  });

  final int index;
  final LibrarySong song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String durationText = _formatClock(song.duration);
    final String subtitle = _songArtistLabel(song);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            _Artwork(
              seed: song.id,
              title: song.title,
              size: 44,
              imageUrl: song.artworkUrl,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              durationText,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KineticJumpBackGrid extends StatelessWidget {
  const _KineticJumpBackGrid({required this.items, required this.onTapItem});

  final List<LibrarySong> items;
  final ValueChanged<LibrarySong> onTapItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'Play something and it’ll show up here.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.55),
        ),
      );
    }

    final double width = MediaQuery.sizeOf(context).width;
    final double gap = 14;
    final double cardWidth = (width - 18 - 18 - gap) / 2;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: items.take(4).map((LibrarySong song) {
        return _KineticJumpBackCard(
          width: cardWidth,
          title: song.title,
          subtitle: _songArtistLabel(song),
          seed: song.id,
          imageUrl: song.artworkUrl,
          onTap: () => onTapItem(song),
        );
      }).toList(),
    );
  }
}

class _KineticJumpBackCard extends StatelessWidget {
  const _KineticJumpBackCard({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.seed,
    required this.onTap,
    this.imageUrl,
  });

  final double width;
  final String title;
  final String subtitle;
  final String seed;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: width,
        height: 74,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: <Color>[
              const Color(0xFF2A160C).withValues(alpha: 0.55),
              const Color(0xFF0B0A0C).withValues(alpha: 0.55),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: <Widget>[
            _Artwork(seed: seed, title: title, size: 46, imageUrl: imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularTracksScreen extends StatelessWidget {
  const _PopularTracksScreen({
    required this.controller,
    required this.title,
    required this.songs,
  });

  final OuterTuneController controller;
  final String title;
  final List<LibrarySong> songs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A0C),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ProgressiveListReveal(
              itemCount: songs.length,
              itemBuilder: (BuildContext context, int index) {
                final LibrarySong song = songs[index];
                return _KineticPopularTrackTile(
                  index: index + 1,
                  song: song,
                  onTap: () {
                    if (song.isRemote) {
                      controller.playOnlineSong(song);
                    } else {
                      controller.playSong(song, label: title);
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPlaysScreen extends StatelessWidget {
  const _RecentPlaysScreen({required this.controller});

  final OuterTuneController controller;

  @override
  Widget build(BuildContext context) {
    final List<LibrarySong> songs = controller.recentlyPlayedSongs;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0A0C),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'JUMP BACK IN',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (songs.isEmpty)
              Text(
                'Play songs and they will appear here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              )
            else
              _ProgressiveListReveal(
                itemCount: songs.length,
                itemBuilder: (BuildContext context, int index) {
                  final LibrarySong song = songs[index];
                  return _KineticPopularTrackTile(
                    index: index + 1,
                    song: song,
                    onTap: () {
                      if (song.isRemote) {
                        controller.playOnlineSong(song);
                      } else {
                        controller.playSong(song, label: 'Jump back in');
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MayYouLikeScreen extends StatefulWidget {
  const _MayYouLikeScreen({required this.controller});

  final OuterTuneController controller;

  @override
  State<_MayYouLikeScreen> createState() => _MayYouLikeScreenState();
}

class _MayYouLikeScreenState extends State<_MayYouLikeScreen> {
  static const int _maxItems = 50;

  List<SongRecommendation> get _allItems => _resolvedMayYouLikeRecommendations(
    widget.controller,
  ).take(_maxItems).toList();

  @override
  Widget build(BuildContext context) {
    final OuterTuneController controller = widget.controller;
    final List<SongRecommendation> items = _allItems;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0A0C),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'MAY YOU LIKE',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty && controller.homeLoading)
              const _ProgressiveSkeletonList(count: 8),
            if (items.isEmpty && !controller.homeLoading)
              const _PersonalizationHintCard(
                message:
                    'Your personalized picks will appear here after the app learns from your likes, history, and full listens.',
              )
            else
              _ProgressiveListReveal(
                itemCount: items.length,
                itemBuilder: (BuildContext context, int index) {
                  final SongRecommendation recommendation = items[index];
                  final LibrarySong song = recommendation.song;
                  return _KineticPopularTrackTile(
                    index: index + 1,
                    song: song,
                    onTap: () {
                      if (song.isRemote) {
                        controller.playOnlineSong(song);
                      } else {
                        controller.playSong(song, label: 'May you like');
                      }
                    },
                  );
                },
              ),
            if (controller.homeLoading && items.isEmpty) ...<Widget>[
              const SizedBox(height: 12),
              const _ProgressiveSkeletonList(count: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressiveSkeletonList extends StatelessWidget {
  const _ProgressiveSkeletonList({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return _ProgressiveListReveal(
      itemCount: count,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          key: ValueKey<String>('skeleton-$index'),
          padding: EdgeInsets.zero,
          child: _KineticPopularTrackTileSkeleton(index: index + 1),
        );
      },
    );
  }
}

class _KineticListSkeleton extends StatelessWidget {
  const _KineticListSkeleton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(count, (int index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _KineticPopularTrackTileSkeleton(index: index + 1),
        );
      }),
    );
  }
}

class _ProgressiveListReveal extends StatefulWidget {
  const _ProgressiveListReveal({
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_ProgressiveListReveal> createState() => _ProgressiveListRevealState();
}

class _ProgressiveListRevealState extends State<_ProgressiveListReveal> {
  Timer? _timer;
  int _visibleCount = 0;

  @override
  void initState() {
    super.initState();
    _scheduleReveal(reset: true, allowImmediateSetState: false);
  }

  @override
  void didUpdateWidget(covariant _ProgressiveListReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount < _visibleCount) {
      _visibleCount = widget.itemCount;
    }
    if (widget.itemCount != oldWidget.itemCount) {
      _scheduleReveal(
        reset: widget.itemCount == 0 || oldWidget.itemCount == 0,
        allowImmediateSetState: true,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleReveal({
    required bool reset,
    required bool allowImmediateSetState,
  }) {
    _timer?.cancel();
    if (!mounted) {
      return;
    }

    if (reset) {
      _visibleCount = 0;
    }

    if (_visibleCount >= widget.itemCount) {
      if (allowImmediateSetState) {
        setState(() {});
      }
      return;
    }

    if (allowImmediateSetState) {
      setState(() {});
    }
    _timer = Timer.periodic(const Duration(milliseconds: 85), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_visibleCount >= widget.itemCount) {
        timer.cancel();
        return;
      }
      setState(() {
        _visibleCount += 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(_visibleCount, (int index) {
        return _RevealIn(
          key: ValueKey<String>('reveal-$index'),
          child: widget.itemBuilder(context, index),
        );
      }),
    );
  }
}

class _RevealIn extends StatelessWidget {
  const _RevealIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      child: child,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      onEnd: () {},
    );
  }
}

class _KineticHeroSkeleton extends StatelessWidget {
  const _KineticHeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.6,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxHeight < 235;
          return Container(
            padding: EdgeInsets.fromLTRB(
              16,
              compact ? 12 : 14,
              16,
              compact ? 10 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.02),
                  Colors.black.withValues(alpha: 0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SkeletonBlock(
                  width: compact ? 76 : 92,
                  height: compact ? 28 : 36,
                  radius: 999,
                ),
                SizedBox(height: compact ? 10 : 16),
                _SkeletonBlock(
                  width: compact ? 180 : 220,
                  height: compact ? 32 : 44,
                  radius: 10,
                ),
                SizedBox(height: compact ? 10 : 12),
                _SkeletonBlock(
                  width: compact ? 240 : 320,
                  height: 16,
                  radius: 8,
                ),
                const SizedBox(height: 8),
                _SkeletonBlock(
                  width: compact ? 200 : 260,
                  height: 16,
                  radius: 8,
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SkeletonBlock(
                        width: double.infinity,
                        height: compact ? 38 : 42,
                        radius: 999,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchPulseHeader extends StatelessWidget {
  const _SearchPulseHeader({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const Spacer(),
        Text(
          'PULSE',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFFFF8A2A),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.settings_rounded, color: Color(0xFFFF8A2A)),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _SearchSectionLabel extends StatelessWidget {
  const _SearchSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: const Color(0xFFE7BAA5),
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _SearchSectionTitle extends StatelessWidget {
  const _SearchSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        color: const Color(0xFFFFE7DB),
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SearchHistoryChip extends StatelessWidget {
  const _SearchHistoryChip({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF3C1705),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFFFE7DB),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFFC99173),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchGenreCard extends StatelessWidget {
  const _SearchGenreCard({
    required this.shelf,
    required this.height,
    required this.onTap,
    this.wide = false,
  });

  final _SearchGenreShelf shelf;
  final double height;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: shelf.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 18,
              left: 16,
              right: 16,
              child: Text(
                shelf.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFFFEDE3),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              right: wide ? 14 : -4,
              bottom: wide ? -6 : -8,
              child: Transform.rotate(
                angle: -0.16,
                child: Opacity(
                  opacity: 0.95,
                  child: _SearchGenreThumbnail(
                    shelf: shelf,
                    size: wide ? 150 : 110,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchGenreThumbnail extends StatelessWidget {
  const _SearchGenreThumbnail({required this.shelf, required this.size});

  final _SearchGenreShelf shelf;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          shelf.assetPath,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) {
                final String? fallbackAssetPath = shelf.fallbackAssetPath;
                if (fallbackAssetPath != null) {
                  return Image.asset(
                    fallbackAssetPath,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return _SearchGenreThumbnailFallback(
                            shelf: shelf,
                            size: size,
                          );
                        },
                  );
                }
                return _SearchGenreThumbnailFallback(shelf: shelf, size: size);
              },
        ),
      ),
    );
  }
}

class _SearchGenreThumbnailFallback extends StatelessWidget {
  const _SearchGenreThumbnailFallback({
    required this.shelf,
    required this.size,
  });

  final _SearchGenreShelf shelf;
  final double size;

  @override
  Widget build(BuildContext context) {
    final LibrarySong? song = shelf.song;
    if (song != null) {
      return _Artwork(
        seed: song.id,
        title: song.title,
        size: size,
        imageUrl: song.artworkUrl,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: LinearGradient(
          colors: shelf.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white.withValues(alpha: 0.92),
        size: size * 0.42,
      ),
    );
  }
}

class _SearchTrendingTile extends StatelessWidget {
  const _SearchTrendingTile({
    required this.rank,
    required this.song,
    required this.controller,
  });

  final int rank;
  final LibrarySong song;
  final OuterTuneController controller;

  @override
  Widget build(BuildContext context) {
    final String subtitle = _songArtistLabel(song);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (song.isRemote) {
            controller.playOnlineSong(song);
          } else {
            controller.playSong(song, label: 'Search trending');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 38,
                child: Text(
                  rank.toString().padLeft(2, '0'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF5E2B16),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _Artwork(
                seed: song.id,
                title: song.title,
                size: 64,
                imageUrl: song.artworkUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFFFE7DB),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFD1A793),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF2A1209),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFFD1A793),
                ),
                onSelected: (String value) {
                  switch (value) {
                    case 'play':
                      if (song.isRemote) {
                        controller.playOnlineSong(song);
                      } else {
                        controller.playSong(song, label: 'Search trending');
                      }
                    case 'queue':
                      controller.enqueueSong(song);
                    case 'favorite':
                      controller.toggleFavorite(song.id);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'play',
                    child: Text('Play now'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'queue',
                    child: Text('Add to queue'),
                  ),
                  PopupMenuItem<String>(
                    value: 'favorite',
                    child: Text(
                      song.isFavorite ? 'Remove favorite' : 'Add favorite',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KineticBottomNav extends StatelessWidget {
  const _KineticBottomNav({
    required this.destination,
    required this.onDestinationChanged,
  });

  final AppDestination destination;
  final ValueChanged<AppDestination> onDestinationChanged;

  @override
  Widget build(BuildContext context) {
    // Match the provided design: 4 tabs.
    final List<_BottomItem> items = <_BottomItem>[
      const _BottomItem(AppDestination.home, 'Home', Icons.home_rounded),
      const _BottomItem(AppDestination.search, 'Search', Icons.search_rounded),
      const _BottomItem(
        AppDestination.library,
        'Library',
        Icons.library_music_rounded,
      ),
      const _BottomItem(
        AppDestination.settings,
        'Profile',
        Icons.person_rounded,
      ),
    ];

    return Container(
      height: 85,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF241007), Color(0xFF180904)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: items.map((_BottomItem item) {
          final bool selected = destination == item.destination;
          return Expanded(
            child: _KineticBottomNavItem(
              icon: item.icon,
              label: item.label,
              selected: selected,
              onTap: () => onDestinationChanged(item.destination),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MobileBottomChrome extends StatelessWidget {
  const _MobileBottomChrome({
    required this.controller,
    required this.onOpenPlayer,
    required this.child,
  });

  final OuterTuneController controller;
  final VoidCallback onOpenPlayer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (controller.miniPlayerSong != null)
            _MiniPlayer(controller: controller, onOpenPlayer: onOpenPlayer),
          child,
        ],
      ),
    );
  }
}

class _BottomItem {
  const _BottomItem(this.destination, this.label, this.icon);
  final AppDestination destination;
  final String label;
  final IconData icon;
}

class _KineticBottomNavItem extends StatelessWidget {
  const _KineticBottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color active = const Color(0xFFE06A2D);
    final Color inactive = const Color(0xFFD4C0B3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 54,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? active.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: selected ? active : inactive, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? active : inactive,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                height: 1.0,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryScreen extends StatelessWidget {
  const _LibraryScreen({
    super.key,
    required this.controller,
    required this.filter,
    required this.onFilterChanged,
  });

  final OuterTuneController controller;
  final LibraryFilter filter;
  final ValueChanged<LibraryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final List<UserPlaylist> playlists = controller.playlists;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF190802),
            Color(0xFF2A0E02),
            Color(0xFF120502),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(40, 18, 22, 30),
        children: <Widget>[
          _LibraryHeader(
            onOpenSettings: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      _SettingsScreen(controller: controller),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _LibraryFeatureCard(
                  title: 'Liked\nSongs',
                  subtitle: '${controller.likedSongs.length} tracks',
                  icon: Icons.favorite_rounded,
                  accent: const Color(0xFFFF8A3D),
                  secondary: const Color(0xFFFF7D2F),
                  watermark: Icons.favorite_rounded,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => _PlaylistScreen(
                          controller: controller,
                          title: 'Liked Songs',
                          songs: controller.likedSongs,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _LibraryFeatureCard(
                  title: 'Offline',
                  subtitle: 'Synced locally',
                  icon: Icons.download_rounded,
                  accent: const Color(0xFF4A1D06),
                  secondary: const Color(0xFF512007),
                  watermark: Icons.download_rounded,
                  darkText: false,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => _PlaylistScreen(
                          controller: controller,
                          title: 'Offline',
                          songs: controller.songs,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Playlists',
                  style: GoogleFonts.splineSans(
                    color: const Color(0xFFFFE2D2),
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 0.95,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showCreatePlaylistDialog(context, controller),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF9B54),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Create New +',
                  style: GoogleFonts.splineSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (playlists.isEmpty)
            _LibraryEmptyPlaylistCard(
              onCreate: () => _showCreatePlaylistDialog(context, controller),
            )
          else
            ...playlists.map(
              (UserPlaylist playlist) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _LibraryPlaylistRow(
                  controller: controller,
                  playlist: playlist,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchScreen extends StatefulWidget {
  const _SearchScreen({super.key, required this.controller});

  final OuterTuneController controller;

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 250);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _recentSearches = <String>[];
  Timer? _searchDebounce;
  bool _requestedTrending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _requestedTrending) {
        return;
      }
      _requestedTrending = true;
      unawaited(
        widget.controller.loadTrendingNow(
          languageCode: widget.controller.preferredLanguageCode,
          countryCode: widget.controller.preferredCountryCode,
        ),
      );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter > 480) {
      return;
    }
    if (_searchController.text.trim().isEmpty) {
      return;
    }
    widget.controller.loadMoreOnlineResults();
  }

  void _runSearch(String value) {
    final String trimmed = value.trim();
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(widget.controller.searchOnline(trimmed));
    });
  }

  void _rememberSearch(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    setState(() {
      _recentSearches.removeWhere(
        (String item) => item.toLowerCase() == trimmed.toLowerCase(),
      );
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > 8) {
        _recentSearches.removeRange(8, _recentSearches.length);
      }
    });
  }

  void _applySearch(String value) {
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _rememberSearch(value);
    _runSearch(value);
  }

  Future<void> _showUrlSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2A1209),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Play From URL',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFFFE0CF),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _urlController,
                onSubmitted: (String value) {
                  widget.controller.playFromUrl(value);
                  Navigator.of(context).pop();
                },
                style: const TextStyle(color: Color(0xFFFFE0CF)),
                decoration: InputDecoration(
                  hintText: 'Paste a YouTube link or direct audio URL',
                  hintStyle: const TextStyle(color: Color(0xFFC99173)),
                  prefixIcon: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFFFF8A2A),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF4A2204),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    widget.controller.playFromUrl(_urlController.text);
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A2A),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play URL'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();

    final List<LibrarySong> songs = widget.controller.songs
        .where(
          (LibrarySong song) =>
              query.isEmpty ||
              song.title.toLowerCase().contains(query) ||
              song.artist.toLowerCase().contains(query) ||
              song.album.toLowerCase().contains(query),
        )
        .toList();
    final List<LibrarySong> monthlyTrendingSongs = _buildMonthlyTrendingNow(
      controller: widget.controller,
    ).take(7).toList(growable: false);
    final List<_SearchGenreShelf> browseShelves = _buildSearchGenreShelves(
      widget.controller,
    );
    final List<LibrarySong> topResults = _mergeSearchResults(
      songs,
      widget.controller.onlineResults,
      query: _searchController.text,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF2B0D02), Color(0xFF170602)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        children: <Widget>[
          _SearchPulseHeader(
            onOpenSettings: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      _SettingsScreen(controller: widget.controller),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: _runSearch,
            onSubmitted: _rememberSearch,
            style: const TextStyle(
              color: Color(0xFFFFDFC8),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFFD8A68C),
              ),
              suffixIcon: IconButton(
                onPressed: _showUrlSheet,
                icon: const Icon(Icons.link_rounded, color: Color(0xFFFF8A2A)),
              ),
              hintText: 'Artists, songs, or podcasts',
              hintStyle: const TextStyle(color: Color(0xFFC99173)),
              filled: true,
              fillColor: const Color(0xFF5A2904),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
          const SizedBox(height: 22),
          if (_recentSearches.isNotEmpty) ...<Widget>[
            const _SearchSectionLabel('RECENTLY SEARCHED'),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _recentSearches.map((String term) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _SearchHistoryChip(
                      label: term,
                      onTap: () => _applySearch(term),
                      onRemove: () {
                        setState(() => _recentSearches.remove(term));
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),
          ],
          if (query.isEmpty) ...<Widget>[
            Text(
              'Browse All',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: const Color(0xFFFFE7DB),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                final double smallWidth = ((width - 14) / 2).clamp(
                  120.0,
                  260.0,
                );
                final _SearchGenreShelf large = browseShelves.last;
                final List<_SearchGenreShelf> small = browseShelves
                    .take(browseShelves.length - 1)
                    .toList(growable: false);
                return Wrap(
                  spacing: 14,
                  runSpacing: 16,
                  children: <Widget>[
                    ...small.map(
                      (_SearchGenreShelf shelf) => SizedBox(
                        width: smallWidth,
                        child: _SearchGenreCard(
                          shelf: shelf,
                          height: 164,
                          onTap: () => _applySearch(shelf.query),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _SearchGenreCard(
                        shelf: large,
                        height: 196,
                        wide: true,
                        onTap: () => _applySearch(large.query),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 34),
            const _SearchSectionTitle('Trending Now'),
            const SizedBox(height: 6),
            Text(
              '${_lastMonthLabel()} chart • ${widget.controller.trendingNowRegionLabel}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFD1A793),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Based on last month popularity in your selected region.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFBC917D),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            if (monthlyTrendingSongs.isEmpty &&
                !widget.controller.trendingNowLoading)
              Text(
                'Regional chart songs are loading for ${widget.controller.preferredRegionLabel}.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFD1A793),
                ),
              )
            else
              ...monthlyTrendingSongs.asMap().entries.map(
                (MapEntry<int, LibrarySong> entry) => _SearchTrendingTile(
                  rank: entry.key + 1,
                  song: entry.value,
                  controller: widget.controller,
                ),
              ),
            if (widget.controller.trendingNowLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: _OnlineSongResultsSkeleton(),
              ),
            if (widget.controller.trendingNowError != null &&
                monthlyTrendingSongs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  widget.controller.trendingNowError!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFFA27C),
                  ),
                ),
              ),
          ] else ...<Widget>[
            _SearchSectionTitle('Top Results'),
            const SizedBox(height: 14),
            if (topResults.isEmpty && !widget.controller.onlineLoading)
              Text(
                'No matches found for "${_searchController.text.trim()}".',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFD1A793),
                ),
              )
            else ...<Widget>[
              ...topResults.map(
                (LibrarySong song) => _SearchTrendingTile(
                  rank: topResults.indexOf(song) + 1,
                  song: song,
                  controller: widget.controller,
                ),
              ),
              if (widget.controller.onlineLoading)
                const _OnlineSongResultsSkeleton()
              else if (widget.controller.onlineHasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      'Scroll for more',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFD1A793),
                      ),
                    ),
                  ),
                ),
            ],
            if (widget.controller.onlineError != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  widget.controller.onlineError!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFFA27C),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

List<LibrarySong> _mergeSearchResults(
  List<LibrarySong> localResults,
  List<LibrarySong> onlineResults, {
  required String query,
}) {
  final List<LibrarySong> merged = <LibrarySong>[];
  final Set<String> seen = <String>{};

  String keyOf(LibrarySong song) {
    String normalize(String value) {
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

    return '${normalize(song.artist)}::${normalize(song.title)}';
  }

  for (final LibrarySong song in <LibrarySong>[
    ...localResults,
    ...onlineResults,
  ]) {
    final String key = keyOf(song);
    if (seen.add(key)) {
      merged.add(song);
    }
  }

  final String normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return merged;
  }

  int score(LibrarySong song) {
    final String title = song.title.trim().toLowerCase();
    final String artist = song.artist.trim().toLowerCase();
    final String album = song.album.trim().toLowerCase();
    final String full = '$title $artist $album';

    int value = 0;
    if (title == normalizedQuery) {
      value += 220;
    }
    if (artist == normalizedQuery) {
      value += 110;
    }
    if (title.startsWith(normalizedQuery)) {
      value += 80;
    }
    if (artist.startsWith(normalizedQuery)) {
      value += 42;
    }
    if (album.startsWith(normalizedQuery)) {
      value += 24;
    }
    if (title.contains(normalizedQuery)) {
      value += 20;
    }
    if (full.contains(' $normalizedQuery ')) {
      value += 18;
    }
    if (full.contains(normalizedQuery)) {
      value += 8;
    }
    if (song.isRemote) {
      value += 2;
    }
    return value;
  }

  merged.sort((LibrarySong a, LibrarySong b) {
    final int scoreCompare = score(b).compareTo(score(a));
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return merged;
}

class _HistoryScreen extends StatelessWidget {
  const _HistoryScreen({super.key, required this.controller});

  final OuterTuneController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.history.isEmpty) {
      return const Center(child: Text('Playback history will appear here.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      itemCount: controller.history.length,
      itemBuilder: (BuildContext context, int index) {
        final PlaybackEntry entry = controller.history[index];
        final LibrarySong? song = controller.songById(entry.songId);
        if (song == null) {
          return const SizedBox.shrink();
        }
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 4,
          ),
          leading: _Artwork(
            seed: song.id,
            title: song.title,
            size: 52,
            imageUrl: song.artworkUrl,
          ),
          title: Text(song.title),
          subtitle: Text(_songArtistLabel(song)),
          trailing: IconButton(
            tooltip: 'Play',
            onPressed: () => controller.playSong(song, label: 'History'),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        );
      },
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen({super.key, required this.controller});

  final OuterTuneController controller;

  @override
  Widget build(BuildContext context) {
    const Color pageTop = Color(0xFF210A03);
    const Color pageBottom = Color(0xFF100402);
    const Color card = Color(0xFF2A1007);
    const Color cardEdge = Color(0xFF3A170C);
    const Color titleColor = Color(0xFFFFE6D5);
    const Color subtitleColor = Color(0xFFC89373);
    const Color accent = Color(0xFFFF8A2A);

    final int crossfadeSeconds = controller.settings.crossfadeSeconds;
    final bool gapless = controller.settings.gaplessPlayback;
    final String preferredRegion = controller.preferredRegionLabel;

    Future<void> pickCrossfade() async {
      final int? selected = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: const Color(0xFF1C0904),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (BuildContext context) {
          const List<int> options = <int>[0, 3, 5, 7];
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Crossfade',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...options.map((int value) {
                    final bool active = value == crossfadeSeconds;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onTap: () => Navigator.of(context).pop(value),
                      title: Text(
                        value == 0 ? 'Off' : '${value}s',
                        style: TextStyle(
                          color: active ? accent : titleColor,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: active
                          ? const Icon(Icons.check_rounded, color: accent)
                          : null,
                    );
                  }),
                ],
              ),
            ),
          );
        },
      );
      if (selected != null) {
        await controller.setCrossfadeSeconds(selected);
      }
    }

    Future<void> pickRegion() async {
      final String? selected = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF1C0904),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (BuildContext context) {
          final List<AppRegion> regions = controller.availableRegions;
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Choose region',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Regional trending and charts will follow this region.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                  ),
                  const SizedBox(height: 12),
                  ...regions.map((AppRegion region) {
                    final bool active =
                        region.countryCode == controller.preferredCountryCode;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onTap: () =>
                          Navigator.of(context).pop(region.countryCode),
                      title: Text(
                        region.label,
                        style: TextStyle(
                          color: active ? accent : titleColor,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        region.countryCode,
                        style: const TextStyle(color: subtitleColor),
                      ),
                      trailing: active
                          ? const Icon(Icons.check_rounded, color: accent)
                          : null,
                    );
                  }),
                ],
              ),
            ),
          );
        },
      );
      if (selected != null) {
        await controller.setPreferredRegion(selected);
      }
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[pageTop, pageBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: <Widget>[
          Row(
            children: <Widget>[
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF4F220D),
                child: Icon(Icons.music_note_rounded, color: accent, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'PULSE',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.settings_rounded, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardEdge),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.public_rounded, color: subtitleColor),
                    const SizedBox(width: 10),
                    Text(
                      'Discovery Region',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Region',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Controls Trending Now and regional chart shelves',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                  ),
                  trailing: GestureDetector(
                    onTap: pickRegion,
                    child: Text(
                      preferredRegion,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  onTap: pickRegion,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardEdge),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A1D0E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_circle_rounded,
                    color: Color(0xFFFFC8A1),
                    size: 66,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'PREMIUM SUBSCRIBER',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: subtitleColor,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ALEX RIVERS',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'alex.rivers@pulse.audio',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cardEdge),
                          foregroundColor: titleColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          backgroundColor: const Color(0xFF51220E),
                        ),
                        child: const Text('EDIT PROFILE'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardEdge),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.library_music_rounded,
                      color: subtitleColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Library Import',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Import audio files or a full folder into your library.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: controller.importFiles,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(Icons.queue_music_rounded),
                      label: const Text('Import files'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.importFolder,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: titleColor,
                        side: const BorderSide(color: cardEdge),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Import folder'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardEdge),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.person_outline_rounded,
                      color: subtitleColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Account',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ProfileRow(
                  title: 'Subscription Plan',
                  subtitle: 'Your current billing cycle ends Oct 12',
                  trailing: 'Ultra High-Fi',
                ),
                const Divider(color: cardEdge, height: 20),
                _ProfileRow(
                  title: 'Payment Method',
                  subtitle: 'Default card for renewals',
                  trailing: '• • • •  4421',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardEdge),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.slow_motion_video_rounded,
                      color: subtitleColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Playback',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Crossfade',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Smooth transition between tracks',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                  ),
                  trailing: GestureDetector(
                    onTap: pickCrossfade,
                    child: Text(
                      crossfadeSeconds == 0 ? 'Off' : '${crossfadeSeconds}s',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  onTap: pickCrossfade,
                ),
                const Divider(color: cardEdge, height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Gapless Playback',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Remove silence between album tracks',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                  ),
                  trailing: Switch(
                    value: gapless,
                    activeThumbColor: accent,
                    activeTrackColor: const Color(0xFF9D4D18),
                    inactiveThumbColor: const Color(0xFFD8A98A),
                    inactiveTrackColor: const Color(0xFF5C2A17),
                    onChanged: controller.setGaplessPlayback,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardEdge),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Pulse Audio v4.2.1-stable',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: subtitleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Proudly built for music enthusiasts.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: subtitleColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'PRIVACY      TERMS      CREDITS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: subtitleColor,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 42),
                side: const BorderSide(color: cardEdge),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                foregroundColor: accent,
              ),
              child: const Text('SIGN OUT OF PULSE'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    const Color titleColor = Color(0xFFFFE6D5);
    const Color subtitleColor = Color(0xFFC89373);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: subtitleColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            trailing,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerScreen extends StatefulWidget {
  const _PlayerScreen({required this.controller});

  final OuterTuneController controller;

  @override
  State<_PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<_PlayerScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _showQueueSheet() async {
    final OuterTuneController controller = widget.controller;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, _) {
            return _PlayerQueueSheet(controller: controller);
          },
        );
      },
    );
  }

  Future<void> _handlePlayerMenuSelection(
    String value,
    LibrarySong song,
  ) async {
    final OuterTuneController controller = widget.controller;
    switch (value) {
      case 'save':
        await _showAddToPlaylistDialog(context, controller, song);
      case 'like':
        await controller.likeSong(song.id);
      case 'dislike':
        await controller.dislikeSong(song.id);
      case 'queue':
        await controller.enqueueSong(song);
    }
  }

  void _handlePlayerVerticalDrag(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity > 380) {
      Navigator.of(context).maybePop();
      return;
    }
    if (velocity < -380) {
      _showQueueSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final OuterTuneController controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final LibrarySong? song =
            controller.miniPlayerSong ?? controller.currentSong;
        if (song == null) {
          return const Scaffold(
            body: Center(child: Text('Nothing is playing.')),
          );
        }

        final Duration duration = controller.duration == Duration.zero
            ? song.duration
            : controller.duration;
        final double sliderMax = math.max(
          duration.inMilliseconds.toDouble(),
          1,
        );
        final double sliderValue = controller.position.inMilliseconds
            .clamp(0, sliderMax.toInt())
            .toDouble();
        const Color backgroundTop = Color(0xFF774120);
        const Color backgroundBottom = Color(0xFF200901);
        const Color surface = Color(0xFF120606);
        const Color accent = Color(0xFFFF7F2A);
        const Color textPrimary = Color(0xFFFFDFC9);
        const Color textSecondary = Color(0xFFE9A56F);
        const Color trackInactive = Color(0xFF5A2508);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: _showQueueSheet,
            onVerticalDragEnd: _handlePlayerVerticalDrag,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[backgroundTop, backgroundBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double artSize = math.min(
                      constraints.maxWidth - 64,
                      328,
                    );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 36,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  color: accent,
                                  iconSize: 28,
                                ),
                                Expanded(
                                  child: Text(
                                    'NOW PLAYING',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.splineSans(
                                      color: accent,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  color: const Color(0xFF2A1209),
                                  icon: const Icon(Icons.more_vert_rounded),
                                  iconColor: accent,
                                  onSelected: (String value) async {
                                    await _handlePlayerMenuSelection(
                                      value,
                                      song,
                                    );
                                  },
                                  itemBuilder: (BuildContext context) =>
                                      <PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(
                                          value: 'save',
                                          child: Text('Save'),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'like',
                                          child: Text(
                                            song.isLiked
                                                ? 'Unlike song'
                                                : 'Like song',
                                          ),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'dislike',
                                          child: Text(
                                            song.isDisliked
                                                ? 'Remove dislike'
                                                : 'Dislike song',
                                          ),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'queue',
                                          child: Text('Add to queue'),
                                        ),
                                      ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 26),
                            Center(
                              child: Container(
                                width: artSize,
                                height: artSize,
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(34),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.42,
                                      ),
                                      blurRadius: 32,
                                      offset: const Offset(14, 18),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child:
                                    song.artworkUrl != null &&
                                        song.artworkUrl!.trim().isNotEmpty
                                    ? Image.network(
                                        song.artworkUrl!,
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.high,
                                        errorBuilder:
                                            (
                                              BuildContext context,
                                              Object error,
                                              StackTrace? stackTrace,
                                            ) {
                                              return const _PlayerArtFallback();
                                            },
                                      )
                                    : const _PlayerArtFallback(),
                              ),
                            ),
                            const SizedBox(height: 34),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        song.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.splineSans(
                                          color: textPrimary,
                                          fontSize: 33,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -1.6,
                                          height: 0.96,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.splineSans(
                                          color: textSecondary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      IconButton(
                                        tooltip: song.isLiked
                                            ? 'Unlike'
                                            : 'Like',
                                        onPressed: () =>
                                            controller.likeSong(song.id),
                                        icon: Icon(
                                          song.isLiked
                                              ? Icons.thumb_up_rounded
                                              : Icons.thumb_up_outlined,
                                          color: accent,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        tooltip: song.isDisliked
                                            ? 'Remove dislike'
                                            : 'Dislike',
                                        onPressed: () =>
                                            controller.dislikeSong(song.id),
                                        icon: Icon(
                                          song.isDisliked
                                              ? Icons.thumb_down_rounded
                                              : Icons.thumb_down_outlined,
                                          color: song.isDisliked
                                              ? Colors.redAccent
                                              : accent,
                                          size: 28,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 6,
                                activeTrackColor: accent,
                                inactiveTrackColor: trackInactive,
                                thumbColor: accent,
                                overlayShape: SliderComponentShape.noOverlay,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 0,
                                ),
                              ),
                              child: Slider(
                                value: sliderValue,
                                min: 0,
                                max: sliderMax,
                                onChanged: (double value) {
                                  controller.seek(
                                    Duration(milliseconds: value.round()),
                                  );
                                },
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -6),
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    _formatClock(controller.position),
                                    style: GoogleFonts.splineSans(
                                      color: textPrimary.withValues(
                                        alpha: 0.86,
                                      ),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatClock(duration),
                                    style: GoogleFonts.splineSans(
                                      color: textPrimary.withValues(
                                        alpha: 0.86,
                                      ),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 26),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                _PlayerIconButton(
                                  icon: Icons.shuffle_rounded,
                                  onPressed: controller.toggleShuffle,
                                  color: controller.isShuffleEnabled
                                      ? accent
                                      : textPrimary.withValues(alpha: 0.9),
                                ),
                                _PlayerIconButton(
                                  icon: Icons.skip_previous_rounded,
                                  onPressed: controller.previousTrack,
                                  color: textPrimary,
                                  size: 34,
                                ),
                                GestureDetector(
                                  onTap: controller.togglePlayback,
                                  onLongPress: _showQueueSheet,
                                  child: Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accent,
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: accent.withValues(alpha: 0.38),
                                          blurRadius: 28,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      controller.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: controller.isPlaying ? 44 : 52,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                _PlayerIconButton(
                                  icon: Icons.skip_next_rounded,
                                  onPressed: controller.nextTrack,
                                  color: textPrimary,
                                  size: 34,
                                ),
                                _PlayerIconButton(
                                  icon: _repeatIcon(controller.repeatMode),
                                  onPressed: controller.cycleRepeatMode,
                                  color: textPrimary.withValues(alpha: 0.9),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: IconButton(
                                onPressed: _showQueueSheet,
                                icon: const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                ),
                                color: textPrimary.withValues(alpha: 0.92),
                                iconSize: 34,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayerArtFallback extends StatelessWidget {
  const _PlayerArtFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: <Color>[
            Color(0xFF43100B),
            Color(0xFF120607),
            Color(0xFF070508),
          ],
          stops: <double>[0.0, 0.56, 1.0],
          center: Alignment(0, -0.25),
          radius: 1.05,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 72,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({
    required this.icon,
    required this.onPressed,
    required this.color,
    this.size = 28,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: size),
      splashRadius: 24,
    );
  }
}

class _PlayerQueueSheet extends StatefulWidget {
  const _PlayerQueueSheet({required this.controller});

  final OuterTuneController controller;

  @override
  State<_PlayerQueueSheet> createState() => _PlayerQueueSheetState();
}

class _PlayerQueueSheetState extends State<_PlayerQueueSheet> {
  static const int _queueBatchSize = 10;

  final ScrollController _scroll = ScrollController();
  bool _loadingMore = false;

  OuterTuneController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureInitialQueueBatch();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _onScroll() async {
    if (_loadingMore || !mounted || !_scroll.hasClients) {
      return;
    }
    if (_scroll.position.extentAfter > 280) {
      return;
    }
    await _loadMoreQueue();
  }

  Future<void> _ensureInitialQueueBatch() async {
    if (!mounted) {
      return;
    }
    while (mounted && controller.queueSongs.length < _queueBatchSize) {
      final int before = controller.queueSongs.length;
      final int shortfall = _queueBatchSize - before;
      await _loadMoreQueue(batchSize: shortfall);
      final int after = controller.queueSongs.length;
      if (after <= before) {
        break;
      }
    }
  }

  Future<void> _loadMoreQueue({int batchSize = _queueBatchSize}) async {
    if (_loadingMore || controller.smartQueueLoading) {
      return;
    }
    _loadingMore = true;
    if (mounted) {
      setState(() {});
    }
    try {
      await controller.appendSmartQueue(batchSize: batchSize, force: true);
    } finally {
      _loadingMore = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<LibrarySong> songs = controller.queueSongs;
    const Color sheet = Color(0xFF140807);
    const Color tile = Color(0xFF23100C);
    const Color accent = Color(0xFFFF7F2A);
    const Color textPrimary = Color(0xFFFFDFC9);
    const Color textSecondary = Color(0xFFE9A56F);
    final bool loading = controller.smartQueueLoading || _loadingMore;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.62,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      decoration: const BoxDecoration(
        color: sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              color: textPrimary.withValues(alpha: 0.92),
              iconSize: 34,
            ),
          ),
          Text(
            'Queue',
            style: GoogleFonts.splineSans(
              color: textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            loading
                ? '${controller.queueLabel} - adding more songs...'
                : controller.queueLabel,
            style: GoogleFonts.splineSans(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (loading) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: const AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading related songs...',
                  style: GoogleFonts.splineSans(
                    color: textPrimary.withValues(alpha: 0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              controller: _scroll,
              itemCount: songs.length + (loading ? 1 : 0),
              separatorBuilder: (_, int index) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                if (index >= songs.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final LibrarySong song = songs[index];
                final bool active = controller.queueIndex == index;

                return Material(
                  color: active ? accent.withValues(alpha: 0.14) : tile,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () async {
                      await controller.jumpToQueue(index);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    onLongPress: () async {
                      await controller.removeFromQueue(index);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Removed from queue')),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child:
                                  song.artworkUrl != null &&
                                      song.artworkUrl!.trim().isNotEmpty
                                  ? Image.network(
                                      song.artworkUrl!,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.high,
                                      errorBuilder:
                                          (
                                            BuildContext context,
                                            Object error,
                                            StackTrace? stackTrace,
                                          ) {
                                            return const _PlayerArtFallback();
                                          },
                                    )
                                  : const _PlayerArtFallback(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.splineSans(
                                    color: textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _songArtistLabel(song),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.splineSans(
                                    color: active ? accent : textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumScreen extends StatelessWidget {
  const _AlbumScreen({required this.controller, required this.album});

  final OuterTuneController controller;
  final AlbumCollection album;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(album.title),
        actions: <Widget>[
          IconButton(
            onPressed: () => controller.playAlbum(album),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Artwork(seed: album.id, title: album.title, size: 120),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      album.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('${album.artist} • ${album.songCount} tracks'),
                    const SizedBox(height: 8),
                    Text(_formatDuration(album.totalDuration)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...album.songs.asMap().entries.map(
            (MapEntry<int, LibrarySong> entry) => _SongTile(
              song: entry.value,
              controller: controller,
              onTap: () => controller.playAlbum(album, startIndex: entry.key),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistScreen extends StatelessWidget {
  const _ArtistScreen({required this.controller, required this.artist});

  final OuterTuneController controller;
  final ArtistCollection artist;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(artist.name),
        actions: <Widget>[
          IconButton(
            onPressed: () => controller.playArtist(artist),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        children: <Widget>[
          Row(
            children: <Widget>[
              _ResolvedArtistAvatar(
                controller: controller,
                artistName: artist.name,
                seed: artist.id,
                size: 120,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${artist.songs.length} tracks • ${artist.albumCount} albums',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...artist.songs.map(
            (LibrarySong song) => _SongTile(song: song, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _FolderScreen extends StatelessWidget {
  const _FolderScreen({required this.controller, required this.folder});

  final OuterTuneController controller;
  final FolderCollection folder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        actions: <Widget>[
          IconButton(
            onPressed: () => controller.playFolder(folder),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        children: <Widget>[
          Text(folder.path, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          ...folder.songs.map(
            (LibrarySong song) => _SongTile(song: song, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _PlaylistScreen extends StatelessWidget {
  const _PlaylistScreen({
    required this.controller,
    required this.title,
    required this.songs,
    this.playlist,
  });

  final OuterTuneController controller;
  final String title;
  final List<LibrarySong> songs;
  final UserPlaylist? playlist;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            onPressed: () => controller.playSongs(songs, label: title),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          if (playlist != null)
            IconButton(
              onPressed: () async {
                await controller.deletePlaylist(playlist!.id);
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        children: songs
            .map(
              (LibrarySong song) => _SongTile(
                song: song,
                controller: controller,
                extraPlaylistId: playlist?.id,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HomeFeedSkeleton extends StatelessWidget {
  const _HomeFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const <Widget>[
        _KineticSectionHeaderSkeleton(),
        SizedBox(height: 8),
        _KineticListSkeleton(count: 4),
        SizedBox(height: 22),
        _KineticSectionHeaderSkeleton(),
        SizedBox(height: 8),
        _KineticListSkeleton(count: 4),
      ],
    );
  }
}

class _OnlineSongResultsSkeleton extends StatelessWidget {
  const _OnlineSongResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        _SearchTrendingTileSkeleton(),
        _SearchTrendingTileSkeleton(),
        _SearchTrendingTileSkeleton(),
        _SearchTrendingTileSkeleton(),
      ],
    );
  }
}

class _KineticSectionHeaderSkeleton extends StatelessWidget {
  const _KineticSectionHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const <Widget>[
        Expanded(child: _SkeletonBlock(width: double.infinity, height: 22)),
        SizedBox(width: 12),
        _SkeletonBlock(width: 64, height: 14, radius: 8),
      ],
    );
  }
}

class _KineticPopularTrackTileSkeleton extends StatelessWidget {
  const _KineticPopularTrackTileSkeleton({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 28,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _SkeletonBlock(
              width: index >= 10 ? 20 : 16,
              height: 16,
              radius: 6,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const _SkeletonBlock(width: 44, height: 44, radius: 12),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _SkeletonBlock(
                width: double.infinity,
                height: 16,
                radius: 8,
              ),
              const SizedBox(height: 8),
              const _SkeletonBlock(width: 160, height: 12, radius: 8),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const _SkeletonBlock(width: 40, height: 14, radius: 8),
      ],
    );
  }
}

class _SearchTrendingTileSkeleton extends StatelessWidget {
  const _SearchTrendingTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 38,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SkeletonBlock(width: 24, height: 24, radius: 8),
              ),
            ),
            SizedBox(width: 12),
            _SkeletonBlock(width: 64, height: 64, radius: 16),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SkeletonBlock(width: double.infinity, height: 18, radius: 8),
                  SizedBox(height: 8),
                  _SkeletonBlock(width: 220, height: 14, radius: 8),
                  SizedBox(height: 6),
                  _SkeletonBlock(width: 140, height: 14, radius: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 12,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: <Color>[
            scheme.surfaceContainerHighest.withValues(alpha: 0.9),
            scheme.surfaceContainerHigh.withValues(alpha: 0.55),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.title,
    required this.subtitle,
    required this.seed,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String seed;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Artwork(seed: seed, title: title, size: 102, icon: icon),
              const SizedBox(height: 14),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF5E3D6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: const Icon(Icons.person_rounded, color: Color(0xFF6F4529)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'LIBRARY',
            style: GoogleFonts.splineSans(
              color: const Color(0xFFFF8B3E),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.settings_outlined),
          color: const Color(0xFFFF8B3E),
        ),
      ],
    );
  }
}

class _LibraryFeatureCard extends StatelessWidget {
  const _LibraryFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.secondary,
    required this.watermark,
    required this.onTap,
    this.darkText = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color secondary;
  final IconData watermark;
  final VoidCallback onTap;
  final bool darkText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 164,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: <Color>[accent, secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: darkText
                      ? const Color(0xFFC96C32).withValues(alpha: 0.52)
                      : Colors.black.withValues(alpha: 0.18),
                ),
                child: Icon(
                  icon,
                  color: darkText ? Colors.black : const Color(0xFFFFC99F),
                  size: 24,
                ),
              ),
            ),
            Positioned(
              right: -12,
              top: -8,
              child: Icon(
                watermark,
                size: 114,
                color: darkText
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: GoogleFonts.splineSans(
                      color: darkText
                          ? Colors.black.withValues(alpha: 0.94)
                          : const Color(0xFFF6E3D2),
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      height: 0.98,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.splineSans(
                      color: darkText
                          ? Colors.black.withValues(alpha: 0.76)
                          : const Color(0xFFD6B099),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryEmptyPlaylistCard extends StatelessWidget {
  const _LibraryEmptyPlaylistCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF2A1209),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.queue_music_rounded,
            color: Color(0xFFFF9C54),
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No playlists yet. Create one and save songs into it.',
              style: GoogleFonts.splineSans(
                color: const Color(0xFFF4D7C4),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(onPressed: onCreate, child: const Text('Create')),
        ],
      ),
    );
  }
}

class _LibraryPlaylistRow extends StatelessWidget {
  const _LibraryPlaylistRow({required this.controller, required this.playlist});

  final OuterTuneController controller;
  final UserPlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final List<LibrarySong> songs = controller.songsForPlaylist(playlist);
    final LibrarySong? leadSong = songs.isEmpty ? null : songs.first;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => _PlaylistScreen(
              controller: controller,
              title: playlist.name,
              songs: songs,
              playlist: playlist,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: leadSong != null
                  ? _Artwork(
                      seed: playlist.id,
                      title: playlist.name,
                      size: 64,
                      imageUrl: leadSong.artworkUrl,
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[Color(0xFF6C2D08), Color(0xFF1B0D05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.queue_music_rounded,
                        color: Color(0xFFFFD1AD),
                        size: 32,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.splineSans(
                    color: const Color(0xFFFFE2D2),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Playlist · ${songs.length} Tracks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.splineSans(
                    color: const Color(0xFFD3A689),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: const Color(0xFF7E4B2B),
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.controller,
    this.onTap,
    this.extraPlaylistId,
  });

  final LibrarySong song;
  final OuterTuneController controller;
  final VoidCallback? onTap;
  final String? extraPlaylistId;

  @override
  Widget build(BuildContext context) {
    final bool active = controller.currentSong?.id == song.id;
    final List<PopupMenuEntry<String>> menuItems = <PopupMenuEntry<String>>[
      if (!song.isRemote)
        PopupMenuItem<String>(
          value: 'favorite',
          child: Text(song.isFavorite ? 'Unfavorite' : 'Favorite'),
        ),
      const PopupMenuItem<String>(
        value: 'enqueue',
        child: Text('Add to queue'),
      ),
      if (!song.isRemote)
        const PopupMenuItem<String>(
          value: 'playlist',
          child: Text('Add to playlist'),
        ),
      if (song.externalUrl != null)
        const PopupMenuItem<String>(
          value: 'copy_link',
          child: Text('Show link'),
        ),
      if (extraPlaylistId != null)
        const PopupMenuItem<String>(
          value: 'remove_playlist',
          child: Text('Remove from playlist'),
        ),
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      dense: controller.settings.denseLibrary,
      leading: _Artwork(
        seed: song.id,
        title: song.title,
        size: 52,
        imageUrl: song.artworkUrl,
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        _songArtistLabel(song),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      selected: active,
      onTap:
          onTap ??
          () {
            if (song.isRemote) {
              controller.playOnlineSong(song);
            } else {
              controller.playSong(song, label: song.sourceLabel);
            }
          },
      trailing: PopupMenuButton<String>(
        onSelected: (String value) {
          switch (value) {
            case 'favorite':
              controller.toggleFavorite(song.id);
            case 'enqueue':
              controller.enqueueSong(song);
            case 'playlist':
              _showAddToPlaylistDialog(context, controller, song);
            case 'copy_link':
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(song.externalUrl ?? song.path)),
              );
            case 'remove_playlist':
              if (extraPlaylistId != null) {
                controller.removeSongFromPlaylist(extraPlaylistId!, song.id);
              }
          }
        },
        itemBuilder: (BuildContext context) => menuItems,
      ),
    );
  }
}

String _songArtistLabel(LibrarySong song) {
  final String artist = song.artist.trim();
  return artist.isEmpty ? 'Unknown artist' : artist;
}

// ignore: unused_element
class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({required this.controller, required this.albums});

  final OuterTuneController controller;
  final List<AlbumCollection> albums;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: albums.take(24).map((AlbumCollection album) {
        return SizedBox(
          width: 200,
          child: _CollectionCard(
            title: album.title,
            subtitle: '${album.artist} • ${album.songCount} tracks',
            seed: album.id,
            icon: Icons.album_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      _AlbumScreen(controller: controller, album: album),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

// ignore: unused_element
class _ArtistGrid extends StatelessWidget {
  const _ArtistGrid({required this.controller, required this.artists});

  final OuterTuneController controller;
  final List<ArtistCollection> artists;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: artists.take(24).map((ArtistCollection artist) {
        return SizedBox(
          width: 200,
          child: _CollectionCard(
            title: artist.name,
            subtitle:
                '${artist.songs.length} tracks • ${artist.albumCount} albums',
            seed: artist.id,
            icon: Icons.person_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      _ArtistScreen(controller: controller, artist: artist),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

// ignore: unused_element
class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder, required this.controller});

  final FolderCollection folder;
  final OuterTuneController controller;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: _Artwork(
        seed: folder.id,
        title: folder.name,
        size: 52,
        icon: Icons.folder_rounded,
      ),
      title: Text(folder.name),
      subtitle: Text('${folder.songs.length} tracks'),
      trailing: IconButton(
        onPressed: () => controller.playFolder(folder),
        icon: const Icon(Icons.play_arrow_rounded),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) =>
                _FolderScreen(controller: controller, folder: folder),
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _PlaylistGrid extends StatelessWidget {
  const _PlaylistGrid({required this.controller});

  final OuterTuneController controller;

  @override
  Widget build(BuildContext context) {
    final List<_PlaylistShelf> shelves = <_PlaylistShelf>[
      _PlaylistShelf(
        title: 'Liked Songs',
        subtitle: '${controller.likedSongs.length} liked tracks',
        seed: 'liked_songs',
        songs: controller.likedSongs,
      ),
      _PlaylistShelf(
        title: 'Most played',
        subtitle: '${controller.topPlayedSongs.take(25).length} highlights',
        seed: 'top_played',
        songs: controller.topPlayedSongs.take(25).toList(),
      ),
      ...controller.playlists.map(
        (UserPlaylist playlist) => _PlaylistShelf(
          title: playlist.name,
          subtitle: '${playlist.songIds.length} tracks',
          seed: playlist.id,
          songs: controller.songsForPlaylist(playlist),
          playlist: playlist,
        ),
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: shelves.map((_PlaylistShelf shelf) {
        return SizedBox(
          width: 220,
          child: _CollectionCard(
            title: shelf.title,
            subtitle: shelf.subtitle,
            seed: shelf.seed,
            icon: Icons.queue_music_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => _PlaylistScreen(
                    controller: controller,
                    title: shelf.title,
                    songs: shelf.songs,
                    playlist: shelf.playlist,
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

// ignore: unused_element
class _PlaylistShelf {
  const _PlaylistShelf({
    required this.title,
    required this.subtitle,
    required this.seed,
    required this.songs,
    this.playlist,
  });

  final String title;
  final String subtitle;
  final String seed;
  final List<LibrarySong> songs;
  final UserPlaylist? playlist;
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.controller, required this.onOpenPlayer});

  final OuterTuneController controller;
  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    final LibrarySong? song = controller.miniPlayerSong;
    if (song == null) {
      return const SizedBox.shrink();
    }

    final Duration duration = controller.duration == Duration.zero
        ? song.duration
        : controller.duration;
    final double progress = duration.inMilliseconds <= 0
        ? 0
        : controller.position.inMilliseconds / duration.inMilliseconds;
    final double safeProgress = progress.isFinite
        ? progress.clamp(0.0, 1.0)
        : 0.0;
    final bool isMiniLoading = controller.miniPlayerSelectionLoading;
    final bool showPauseIcon = controller.isPlaying && !isMiniLoading;

    const Color shell = Color(0xFF100502);
    const Color card = Color(0xFF2A1209);
    const Color cardEdge = Color(0xFF402016);
    const Color accent = Color(0xFFFF7F17);
    const Color inactive = Color(0xFFEEDDCF);
    const Color track = Color(0xFF4D2A1D);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onOpenPlayer,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            constraints: const BoxConstraints(minHeight: 78),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: cardEdge, width: 1),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: shell.withValues(alpha: 0.42),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child:
                        song.artworkUrl != null &&
                            song.artworkUrl!.trim().isNotEmpty
                        ? Image.network(
                            song.artworkUrl!,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            loadingBuilder:
                                (
                                  BuildContext context,
                                  Widget child,
                                  ImageChunkEvent? loadingProgress,
                                ) {
                                  if (loadingProgress == null) {
                                    return child;
                                  }
                                  return const _MiniArtworkFallback();
                                },
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) {
                                  return const _MiniArtworkFallback();
                                },
                          )
                        : const _MiniArtworkFallback(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final bool compact = constraints.maxWidth < 250;
                      final double playButtonSize = compact ? 42 : 48;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    _MiniPlayerIcon(
                                      icon: Icons.shuffle_rounded,
                                      color: controller.isShuffleEnabled
                                          ? accent
                                          : inactive,
                                      onPressed: controller.toggleShuffle,
                                      compact: compact,
                                    ),
                                    _MiniPlayerIcon(
                                      icon: Icons.skip_previous_rounded,
                                      color: inactive,
                                      onPressed: controller.previousTrack,
                                      compact: compact,
                                    ),
                                    GestureDetector(
                                      onTap: controller.togglePlayback,
                                      child: Container(
                                        width: playButtonSize,
                                        height: playButtonSize,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: accent,
                                        ),
                                        child: isMiniLoading
                                            ? Center(
                                                child: SizedBox(
                                                  width: compact ? 18 : 20,
                                                  height: compact ? 18 : 20,
                                                  child: const CircularProgressIndicator(
                                                    strokeWidth: 1,

                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.black),
                                                  ),
                                                ),
                                              )
                                            : Icon(
                                                showPauseIcon
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                                color: Colors.black,
                                                size: compact
                                                    ? 22
                                                    : showPauseIcon
                                                    ? 24
                                                    : 28,
                                              ),
                                      ),
                                    ),
                                    _MiniPlayerIcon(
                                      icon: Icons.skip_next_rounded,
                                      color: inactive,
                                      onPressed: controller.nextTrack,
                                      compact: compact,
                                    ),
                                    _MiniPlayerIcon(
                                      icon: _repeatIcon(controller.repeatMode),
                                      color: inactive,
                                      onPressed: controller.cycleRepeatMode,
                                      compact: compact,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: SizedBox(
                              height: 5,
                              width: double.infinity,
                              child: ColoredBox(
                                color: track,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: safeProgress,
                                    alignment: Alignment.centerLeft,
                                    child: const SizedBox.expand(
                                      child: ColoredBox(color: accent),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerIcon extends StatelessWidget {
  const _MiniPlayerIcon({
    required this.icon,
    required this.onPressed,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      iconSize: compact ? 22 : 28,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(
        width: compact ? 28 : 34,
        height: compact ? 28 : 34,
      ),
      icon: Icon(icon, color: color),
    );
  }
}

class _MiniArtworkFallback extends StatelessWidget {
  const _MiniArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF1F8E96), Color(0xFF23516E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.album_rounded, color: Color(0xFFE4F3EE), size: 34),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.seed,
    required this.title,
    required this.size,
    this.icon = Icons.music_note_rounded,
    this.imageUrl,
  });

  final String seed;
  final String title;
  final double size;
  final IconData icon;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors = _gradientFor(seed, scheme);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          if (imageUrl != null)
            Positioned.fill(
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) => const SizedBox.shrink(),
              ),
            ),
          Align(
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: size * 0.36,
              color: colors.last.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Text(
              _initials(title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color:
                    ThemeData.estimateBrightnessForColor(colors.first) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({
    required this.seed,
    required this.title,
    required this.size,
    this.imageUrl,
  });

  final String seed;
  final String title;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors = _gradientFor(seed, scheme);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (imageUrl != null && imageUrl!.trim().isNotEmpty)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder:
                  (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) => const SizedBox.shrink(),
            ),
          if (imageUrl == null || imageUrl!.trim().isEmpty)
            Center(
              child: Text(
                _initials(title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      ThemeData.estimateBrightnessForColor(colors.first) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResolvedArtistAvatar extends StatelessWidget {
  const _ResolvedArtistAvatar({
    required this.controller,
    required this.artistName,
    required this.seed,
    required this.size,
  });

  final OuterTuneController controller;
  final String artistName;
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: controller.resolveArtistImage(artistName),
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        return _ArtistAvatar(
          seed: seed,
          title: artistName,
          size: size,
          imageUrl: snapshot.data,
        );
      },
    );
  }
}

Future<void> _showCreatePlaylistDialog(
  BuildContext context,
  OuterTuneController controller,
) async {
  final TextEditingController input = TextEditingController();
  final String? name = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + bottomInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: const Color(0xFF262D2E),
              borderRadius: BorderRadius.circular(28),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    final bool canCreate = input.text.trim().isNotEmpty;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Create playlist',
                          style: GoogleFonts.ibmPlexSans(
                            color: const Color(0xFFE8EFEF),
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 26),
                        TextField(
                          controller: input,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (String value) {
                            final String trimmed = value.trim();
                            if (trimmed.isNotEmpty) {
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(trimmed);
                            }
                          },
                          style: GoogleFonts.ibmPlexSans(
                            color: const Color(0xFFE8EFEF),
                            fontSize: 18,
                          ),
                          cursorColor: const Color(0xFF8BDFD6),
                          decoration: InputDecoration(
                            hintText: 'new song',
                            hintStyle: GoogleFonts.ibmPlexSans(
                              color: const Color(0xFFD2DFDE),
                              fontSize: 18,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.only(bottom: 14),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0xFF8BDFD6),
                                width: 2,
                              ),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0xFF8BDFD6),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF8BDFD6),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.ibmPlexSans(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: canCreate
                                  ? () => Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).pop(input.text.trim())
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF8BDFD6),
                                foregroundColor: const Color(0xFF244242),
                                disabledBackgroundColor: const Color(
                                  0xFF8BDFD6,
                                ).withValues(alpha: 0.45),
                                disabledForegroundColor: const Color(
                                  0xFF244242,
                                ),
                                minimumSize: const Size(112, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: Text(
                                'Create',
                                style: GoogleFonts.ibmPlexSans(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  input.dispose();

  if (name != null && name.trim().isNotEmpty) {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!context.mounted) {
      return;
    }
    await controller.createPlaylist(name);
  }
}

Future<void> _showAddToPlaylistDialog(
  BuildContext context,
  OuterTuneController controller,
  LibrarySong song,
) async {
  if (controller.playlists.isEmpty) {
    await _showCreatePlaylistDialog(context, controller);
  }

  if (!context.mounted || controller.playlists.isEmpty) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Add "${song.title}"'),
        content: SizedBox(
          width: 380,
          child: ListView(
            shrinkWrap: true,
            children: controller.playlists
                .map(
                  (UserPlaylist playlist) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.songIds.length} tracks'),
                    onTap: () async {
                      await controller.addSongToPlaylist(playlist.id, song.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                )
                .toList(),
          ),
        ),
      );
    },
  );
}

List<Color> _gradientFor(String seed, ColorScheme scheme) {
  final int hash = seed.hashCode;
  final double hue = (hash % 360).toDouble();
  return <Color>[
    HSLColor.fromAHSL(
      1,
      hue,
      0.58,
      scheme.brightness == Brightness.dark ? 0.34 : 0.68,
    ).toColor(),
    HSLColor.fromAHSL(
      1,
      (hue + 40) % 360,
      0.54,
      scheme.brightness == Brightness.dark ? 0.2 : 0.84,
    ).toColor(),
  ];
}

String _initials(String text) {
  final List<String> words = text
      .split(RegExp(r'\s+'))
      .where((String item) => item.trim().isNotEmpty)
      .take(2)
      .toList();
  if (words.isEmpty) {
    return 'OT';
  }
  return words.map((String item) => item.characters.first.toUpperCase()).join();
}

String _formatClock(Duration duration) {
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);
  final int hours = duration.inHours;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${duration.inMinutes}:${seconds.toString().padLeft(2, '0')}';
}

String _formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  return '${duration.inMinutes}m';
}

IconData _repeatIcon(PlaylistMode mode) {
  return switch (mode) {
    PlaylistMode.none => Icons.repeat_rounded,
    PlaylistMode.loop => Icons.repeat_on_rounded,
    PlaylistMode.single => Icons.repeat_one_on_rounded,
  };
}
