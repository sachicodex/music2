import 'dart:async';
import 'dart:math' as math;

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
        if (controller.currentSong != null)
          _MiniPlayer(
            controller: controller,
            onOpenPlayer: () => _openPlayer(context, controller),
          ),
      ],
    );

    return Scaffold(
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
          : _KineticBottomNav(
              destination: _destination,
              onDestinationChanged: (AppDestination value) {
                setState(() => _destination = value);
              },
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
      AppDestination.library =>
        controller.songs.isEmpty
            ? _EmptyLibraryState(
                key: const ValueKey<String>('empty_library'),
                controller: controller,
              )
            : _LibraryScreen(
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

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState({super.key, required this.controller});

  final OuterTuneController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: <Color>[
                scheme.primaryContainer,
                scheme.tertiaryContainer,
                scheme.surfaceContainerHighest,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('OuterTune Flutter', style: theme.textTheme.displaySmall),
              const SizedBox(height: 12),
              Text(
                'Pure Flutter port focused on the local-library experience. Import audio files or a folder to build your library on Windows and Android.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: controller.importFiles,
                    icon: const Icon(Icons.queue_music_rounded),
                    label: const Text('Import files'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.importFolder,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Import folder'),
                  ),
                ],
              ),
              if (controller.statusMessage != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  controller.statusMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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

    final List<HomeFeedSection> feed = controller.homeFeed;
    final bool homeFeedPending = controller.homeLoading && feed.isEmpty;
    // MAY YOU LIKE should feel like YT Music: mixed across shelves, deduped,
    // and not stuck in a single recurring category.
    final List<LibrarySong> mayYouLikeFull = _buildMayYouLike(feed);
    final List<LibrarySong> mayYouLike = mayYouLikeFull
        .take(4)
        .toList(growable: false);

    final List<LibrarySong> jumpBackIn = controller.recentlyPlayedSongs
        .take(4)
        .toList(growable: false);

    final List<LibrarySong> newReleasesAll = _newReleaseSongs(controller);
    final List<LibrarySong> newReleases = newReleasesAll
        .take(4)
        .toList(growable: false);
    final _FeaturedHeroData featured = _pickFeaturedHero(
      context: context,
      controller: controller,
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
      child: ListView(
        controller: _scroll,
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
              onDetails: featured.onDetails,
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
          else
            Column(
              children: List<Widget>.generate(mayYouLike.length, (int index) {
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
          if (newReleases.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            _KineticSectionHeader(
              title: 'NEW RELEASES',
              onViewAll: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => _NewReleasesScreen(
                      controller: controller,
                      songs: newReleasesAll,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ProgressiveListReveal(
              itemCount: newReleases.length,
              itemBuilder: (BuildContext context, int index) {
                final LibrarySong song = newReleases[index];
                return _KineticPopularTrackTile(
                  index: index + 1,
                  song: song,
                  onTap: () {
                    if (song.isRemote) {
                      controller.playOnlineSong(song);
                    } else {
                      controller.playSong(song, label: 'New releases');
                    }
                  },
                );
              },
            ),
          ],
          // Infinite feed: render remaining shelves as scroll continues.
          ..._buildMoreShelves(controller: controller, skipCount: 1),
          if (controller.homeLoading) ...<Widget>[
            const SizedBox(height: 16),
            const Opacity(opacity: 0.8, child: _HomeFeedSkeleton()),
          ],
        ],
      ),
    );
  }
}

List<Widget> _buildMoreShelves({
  required OuterTuneController controller,
  int skipCount = 0,
}) {
  final List<HomeFeedSection> sections = controller.homeFeed;
  if (sections.length <= skipCount) return <Widget>[];

  return sections
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
                onViewAll: () {},
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

List<LibrarySong> _newReleaseSongs(OuterTuneController controller) {
  final List<LibrarySong> sorted = List<LibrarySong>.from(
    controller.recentlyAddedSongs,
  )..sort((LibrarySong a, LibrarySong b) => b.addedAt.compareTo(a.addedAt));

  final Set<String> seen = <String>{};
  return <LibrarySong>[
    for (final LibrarySong song in sorted)
      if (seen.add('${song.artist.toLowerCase()}::${song.title.toLowerCase()}'))
        song,
  ];
}

class _SearchGenreShelf {
  const _SearchGenreShelf({
    required this.title,
    required this.query,
    required this.colors,
    this.song,
  });

  final String title;
  final String query;
  final List<Color> colors;
  final LibrarySong? song;
}

List<_SearchGenreShelf> _buildSearchGenreShelves(
  OuterTuneController controller,
) {
  final List<LibrarySong> pool = <LibrarySong>[
    ..._buildMayYouLike(controller.homeFeed),
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
      song: pickSong(<String>['hip hop', 'rap', 'trap']),
    ),
    _SearchGenreShelf(
      title: 'Pop',
      query: 'pop',
      colors: const <Color>[Color(0xFFE92D7A), Color(0xFFB11A55)],
      song: pickSong(<String>['pop', 'dance pop', 'synthpop']),
    ),
    _SearchGenreShelf(
      title: 'Electronic',
      query: 'electronic',
      colors: const <Color>[Color(0xFF2A6CF6), Color(0xFF173C93)],
      song: pickSong(<String>['electronic', 'house', 'edm', 'techno']),
    ),
    _SearchGenreShelf(
      title: 'Jazz',
      query: 'jazz',
      colors: const <Color>[Color(0xFFEF6A0D), Color(0xFF9C3A00)],
      song: pickSong(<String>['jazz', 'blues', 'sax']),
    ),
    _SearchGenreShelf(
      title: 'Chill & Focus',
      query: 'chill focus',
      colors: const <Color>[Color(0xFF0E9383), Color(0xFF0B5E54)],
      song: pickSong(<String>['chill', 'ambient', 'lofi', 'focus']),
    ),
  ];
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
    required this.onDetails,
    this.imageUrl,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onListenNow;
  final VoidCallback onDetails;
}

_FeaturedHeroData _pickFeaturedHero({
  required BuildContext context,
  required OuterTuneController controller,
  required List<LibrarySong> mayYouLike,
}) {
  // Prefer a "playlist users may like" feel:
  // - If user has playlists, feature the most recently updated one.
  // - Else, if user has favorites, feature Favorites.
  // - Else, feature the top suggestion song (mayYouLike).
  final UserPlaylist? newestPlaylist = controller.playlists.isEmpty
      ? null
      : (List<UserPlaylist>.from(controller.playlists)..sort(
              (UserPlaylist a, UserPlaylist b) =>
                  b.updatedAt.compareTo(a.updatedAt),
            ))
            .first;

  if (newestPlaylist != null) {
    final List<LibrarySong> songs = controller.songsForPlaylist(newestPlaylist);
    final String? imageUrl = songs
        .map((LibrarySong s) => s.artworkUrl)
        .whereType<String>()
        .firstOrNull;
    final String subtitle = songs.isEmpty
        ? 'A playlist picked from your library'
        : '${songs.length} tracks • updated recently';

    return _FeaturedHeroData(
      badge: 'PLAYLIST YOU MAY LIKE',
      title: newestPlaylist.name.toUpperCase(),
      subtitle: subtitle,
      imageUrl: imageUrl,
      onListenNow: () => controller.playPlaylist(newestPlaylist),
      onDetails: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => _PlaylistScreen(
              controller: controller,
              title: newestPlaylist.name,
              songs: songs,
              playlist: newestPlaylist,
            ),
          ),
        );
      },
    );
  }

  final List<LibrarySong> favorites = controller.favoriteSongs;
  if (favorites.isNotEmpty) {
    final String? imageUrl = favorites
        .map((LibrarySong s) => s.artworkUrl)
        .whereType<String>()
        .firstOrNull;
    return _FeaturedHeroData(
      badge: 'YOUR FAVORITES',
      title: 'FAVORITES',
      subtitle: '${favorites.length} liked tracks',
      imageUrl: imageUrl,
      onListenNow: () => controller.playSongs(favorites, label: 'Favorites'),
      onDetails: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => _PlaylistScreen(
              controller: controller,
              title: 'Favorites',
              songs: favorites,
            ),
          ),
        );
      },
    );
  }

  final LibrarySong? songWithArt = mayYouLike
      .where((LibrarySong s) => (s.artworkUrl ?? '').trim().isNotEmpty)
      .firstOrNull;
  final LibrarySong? song = songWithArt ?? mayYouLike.firstOrNull;
  if (song != null) {
    return _FeaturedHeroData(
      badge: 'ARTIST OF THE MONTH',
      title: song.artist.toUpperCase(),
      subtitle:
          'Experience the synthesized evolution\nof hyper-soul in the new album\n"${song.album}".',
      imageUrl: song.artworkUrl,
      onListenNow: () {
        if (song.isRemote) {
          controller.playOnlineSong(song);
        } else {
          controller.playSong(song, label: 'Home');
        }
      },
      onDetails: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => _PopularTracksScreen(
              controller: controller,
              title: song.artist.toUpperCase(),
              songs: mayYouLike,
            ),
          ),
        );
      },
    );
  }

  return _FeaturedHeroData(
    badge: 'DISCOVER',
    title: 'KINETIC',
    subtitle: 'Search and play songs to personalize your home feed.',
    onListenNow: controller.importFolder,
    onDetails: controller.importFiles,
  );
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
          onPressed: onOpenSearch,
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
    required this.onDetails,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onListenNow;
  final VoidCallback onDetails;

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
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: FilledButton(
                              onPressed: onListenNow,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE06A2D),
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: compact ? 8 : 10,
                                ),
                                minimumSize: Size(0, compact ? 38 : 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'LISTEN NOW',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(letterSpacing: 1.2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onDetails,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: compact ? 8 : 10,
                                ),
                                minimumSize: Size(0, compact ? 38 : 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(
                                'DETAILS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(letterSpacing: 1.2),
                              ),
                            ),
                          ),
                        ],
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
    final String subtitle = (song.isRemote ? song.album : song.album).trim();
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
                    subtitle.isEmpty ? 'TRACK' : subtitle.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.55),
                      letterSpacing: 1.6,
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
          kind: (song.isRemote ? song.sourceLabel : 'TRACK').toUpperCase(),
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
    required this.kind,
    required this.seed,
    required this.onTap,
    this.imageUrl,
  });

  final double width;
  final String title;
  final String kind;
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
                    kind,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.55),
                      letterSpacing: 1.8,
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
  static const int _pageSize = 4;
  static const int _initialLoadSize = 10;
  static const int _maxItems = 50;

  final ScrollController _scroll = ScrollController();
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureInitialItems();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _onScroll() async {
    if (!mounted) return;
    if (_scroll.position.extentAfter > 220) return;
    final int total = _allItems.length;
    if (_visibleCount >= total) {
      return;
    }
    setState(() {
      _visibleCount = math.min(_visibleCount + _pageSize, total);
    });
  }

  List<LibrarySong> get _allItems =>
      _buildMayYouLike(widget.controller.homeFeed).take(_maxItems).toList();

  void _ensureInitialItems() {
    if (!mounted) {
      return;
    }
    final int available = _allItems.length;
    setState(() {
      _visibleCount = math.min(_initialLoadSize, available);
    });
  }

  @override
  Widget build(BuildContext context) {
    final OuterTuneController controller = widget.controller;
    final List<LibrarySong> items = _allItems;
    final List<LibrarySong> visibleItems = items
        .take(math.min(_visibleCount, items.length))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0A0C),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
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
              const _KineticListSkeleton(count: 8),
            Column(
              children: List<Widget>.generate(visibleItems.length, (int index) {
                final LibrarySong song = visibleItems[index];
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
            if (controller.homeLoading && items.isEmpty) ...<Widget>[
              const SizedBox(height: 12),
              const _KineticListSkeleton(count: 4),
            ],
          ],
        ),
      ),
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
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              _SkeletonBlock(width: 28, height: 16, radius: 6),
              SizedBox(width: 14),
              _SkeletonBlock(width: 44, height: 44, radius: 12),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SkeletonBlock(
                      width: double.infinity,
                      height: 16,
                      radius: 8,
                    ),
                    SizedBox(height: 8),
                    _SkeletonBlock(width: 160, height: 12, radius: 8),
                  ],
                ),
              ),
              SizedBox(width: 10),
              _SkeletonBlock(width: 40, height: 14, radius: 8),
            ],
          ),
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
                        height: compact ? 38 : 40,
                        radius: 999,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SkeletonBlock(
                        width: double.infinity,
                        height: compact ? 38 : 40,
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

class _NewReleasesScreen extends StatelessWidget {
  const _NewReleasesScreen({required this.controller, required this.songs});

  final OuterTuneController controller;
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
                  'NEW RELEASES',
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
                      controller.playSong(song, label: 'New releases');
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
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_rounded, color: Color(0xFFFF8A2A)),
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
            if (shelf.song != null)
              Positioned(
                right: wide ? 14 : -4,
                bottom: wide ? -6 : -8,
                child: Transform.rotate(
                  angle: -0.16,
                  child: Opacity(
                    opacity: 0.95,
                    child: _Artwork(
                      seed: shelf.song!.id,
                      title: shelf.song!.title,
                      size: wide ? 150 : 110,
                      imageUrl: shelf.song!.artworkUrl,
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
    final String subtitle = song.playCount > 0
        ? '${song.artist} • ${song.playCount} plays'
        : song.subtitle.replaceAll('â€¢', '•');

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

    return SafeArea(
      top: false,
      child: Container(
        height: 92,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFF130804),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Container(
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
        ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LibraryFilter.values
              .map(
                (LibraryFilter item) => ChoiceChip(
                  label: Text(item.label),
                  selected: filter == item,
                  onSelected: (_) => onFilterChanged(item),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.grid_view_rounded),
                  label: Text('Grid'),
                ),
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.view_agenda_rounded),
                  label: Text('List'),
                ),
              ],
              selected: <bool>{controller.settings.useGridView},
              onSelectionChanged: (Set<bool> values) {
                controller.setGridView(values.first);
              },
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => _showCreatePlaylistDialog(context, controller),
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('New playlist'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ..._buildLibrarySections(context),
      ],
    );
  }

  List<Widget> _buildLibrarySections(BuildContext context) {
    final List<Widget> widgets = <Widget>[];

    if (filter == LibraryFilter.all || filter == LibraryFilter.songs) {
      widgets.add(_SectionHeader(title: 'Songs'));
      widgets.add(const SizedBox(height: 12));
      widgets.addAll(
        controller.recentlyAddedSongs
            .take(filter == LibraryFilter.all ? 8 : 200)
            .map(
              (LibrarySong song) =>
                  _SongTile(song: song, controller: controller),
            ),
      );
      widgets.add(const SizedBox(height: 24));
    }

    if (filter == LibraryFilter.all || filter == LibraryFilter.albums) {
      widgets.add(_SectionHeader(title: 'Albums'));
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        _AlbumGrid(controller: controller, albums: controller.albums),
      );
      widgets.add(const SizedBox(height: 24));
    }

    if (filter == LibraryFilter.all || filter == LibraryFilter.artists) {
      widgets.add(_SectionHeader(title: 'Artists'));
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        _ArtistGrid(controller: controller, artists: controller.artists),
      );
      widgets.add(const SizedBox(height: 24));
    }

    if (filter == LibraryFilter.all || filter == LibraryFilter.folders) {
      widgets.add(_SectionHeader(title: 'Folders'));
      widgets.add(const SizedBox(height: 12));
      widgets.addAll(
        controller.folders.map(
          (FolderCollection folder) =>
              _FolderTile(folder: folder, controller: controller),
        ),
      );
      widgets.add(const SizedBox(height: 24));
    }

    if (filter == LibraryFilter.all || filter == LibraryFilter.playlists) {
      widgets.add(_SectionHeader(title: 'Playlists'));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_PlaylistGrid(controller: controller));
    }

    return widgets;
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
    final List<LibrarySong> trendingSongs = _buildMayYouLike(
      widget.controller.homeFeed,
    ).take(5).toList(growable: false);
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
            const SizedBox(height: 18),
            if (trendingSongs.isEmpty)
              Text(
                'Play songs to build search recommendations.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFD1A793),
                ),
              )
            else
              ...trendingSongs.asMap().entries.map(
                (MapEntry<int, LibrarySong> entry) => _SearchTrendingTile(
                  rank: entry.key + 1,
                  song: entry.value,
                  controller: widget.controller,
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
  List<LibrarySong> onlineResults,
  {required String query}
) {
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

    final DateFormat format = DateFormat('MMM d, HH:mm');

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
          subtitle: Text('${song.artist} • ${format.format(entry.playedAt)}'),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      children: <Widget>[
        _SectionHeader(title: 'Appearance'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.palette_outlined),
                    const SizedBox(width: 12),
                    const Text('Theme mode'),
                    const Spacer(),
                    DropdownButton<ThemeMode>(
                      value: controller.settings.themeMode,
                      items: const <DropdownMenuItem<ThemeMode>>[
                        DropdownMenuItem<ThemeMode>(
                          value: ThemeMode.system,
                          child: Text('System'),
                        ),
                        DropdownMenuItem<ThemeMode>(
                          value: ThemeMode.light,
                          child: Text('Light'),
                        ),
                        DropdownMenuItem<ThemeMode>(
                          value: ThemeMode.dark,
                          child: Text('Dark'),
                        ),
                      ],
                      onChanged: (ThemeMode? value) {
                        if (value != null) {
                          controller.setThemeMode(value);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: controller.settings.denseLibrary,
                  onChanged: controller.setDenseLibrary,
                  title: const Text('Dense lists'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: controller.settings.useGridView,
                  onChanged: controller.setGridView,
                  title: const Text('Prefer grid in library'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(title: 'Playback'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Playback rate ${controller.settings.playbackRate.toStringAsFixed(2)}x',
                ),
                Slider(
                  value: controller.settings.playbackRate,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                  onChanged: controller.setPlaybackRate,
                ),
                SwitchListTile(
                  value: controller.settings.smartQueueEnabled,
                  onChanged: controller.setSmartQueueEnabled,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Smart queue autoplay'),
                  subtitle: const Text(
                    'Predict and append the next songs automatically.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(title: 'YouTube Music'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    controller.hasYtMusicAuth
                        ? Icons.verified_user_rounded
                        : Icons.cloud_off_rounded,
                  ),
                  title: Text(
                    controller.hasYtMusicAuth
                        ? 'Personalized YT Music enabled'
                        : 'Using anonymous YT Music',
                  ),
                  subtitle: Text(
                    controller.hasYtMusicAuth
                        ? 'Home shelves and radio can use your real YouTube Music account context.'
                        : 'Paste browser request headers to get recommendations closer to your real YT Music home.',
                  ),
                ),
                if (controller.ytMusicAuthError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      controller.ytMusicAuthError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Text(
                  'Paste copied request headers from a logged-in `music.youtube.com` request. They are stored locally on this device.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () =>
                          _showYtMusicAuthDialog(context, controller),
                      icon: const Icon(Icons.vpn_key_rounded),
                      label: Text(
                        controller.hasYtMusicAuth
                            ? 'Update headers'
                            : 'Add headers',
                      ),
                    ),
                    if (controller.hasYtMusicAuth)
                      OutlinedButton.icon(
                        onPressed: controller.clearYtMusicAuth,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Clear headers'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(title: 'Library Sources'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: controller.importFiles,
                      icon: const Icon(Icons.audio_file_rounded),
                      label: const Text('Import files'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.importFolder,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Import folder'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.rescanLibrary,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Rescan'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (controller.sources.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No import sources saved yet.'),
                  ),
                ...controller.sources.map(
                  (String source) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_copy_outlined),
                    title: Text(source),
                    trailing: IconButton(
                      onPressed: () => controller.removeSource(source),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: controller.clearLibrary,
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Clear library'),
                  ),
                ),
              ],
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

  @override
  Widget build(BuildContext context) {
    final OuterTuneController controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final LibrarySong? song = controller.currentSong;
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
                                IconButton(
                                  onPressed: _showQueueSheet,
                                  icon: const Icon(Icons.more_vert_rounded),
                                  color: accent,
                                  iconSize: 24,
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
                                  child: IconButton(
                                    onPressed: () =>
                                        controller.toggleFavorite(song.id),
                                    icon: Icon(
                                      song.isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: accent,
                                      size: 32,
                                    ),
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
            child: Container(
              width: 52,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                final bool smartPick = controller.isSmartQueueSong(song.id);

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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
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
                                  smartPick
                                      ? '${song.artist} - Smart pick'
                                      : song.artist,
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
                          IconButton(
                            onPressed: () => controller.removeFromQueue(index),
                            icon: Icon(
                              Icons.close_rounded,
                              color: textPrimary.withValues(alpha: 0.78),
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
              _Artwork(seed: artist.id, title: artist.name, size: 120),
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
        _SkeletonSectionHeader(),
        SizedBox(height: 12),
        _SkeletonSongStrip(),
        SizedBox(height: 24),
        _SkeletonSectionHeader(),
        SizedBox(height: 12),
        _SkeletonSongStrip(),
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
        _SkeletonSongTile(),
        _SkeletonSongTile(),
        _SkeletonSongTile(),
        _SkeletonSongTile(),
      ],
    );
  }
}

class _SkeletonSectionHeader extends StatelessWidget {
  const _SkeletonSectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SkeletonBlock(width: 180, height: 28),
        SizedBox(height: 8),
        _SkeletonBlock(width: 240, height: 14),
      ],
    );
  }
}

class _SkeletonSongStrip extends StatelessWidget {
  const _SkeletonSongStrip();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 168,
      child: Row(
        children: <Widget>[
          Expanded(child: _SkeletonSongCard()),
          SizedBox(width: 12),
          Expanded(child: _SkeletonSongCard()),
          SizedBox(width: 12),
          Expanded(child: _SkeletonSongCard()),
        ],
      ),
    );
  }
}

class _SkeletonSongCard extends StatelessWidget {
  const _SkeletonSongCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            _SkeletonBlock(width: 96, height: 96, radius: 24),
            SizedBox(height: 12),
            _SkeletonBlock(width: double.infinity, height: 16),
            SizedBox(height: 8),
            _SkeletonBlock(width: 120, height: 12),
          ],
        ),
      ),
    );
  }
}

class _SkeletonSongTile extends StatelessWidget {
  const _SkeletonSongTile();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          _SkeletonBlock(width: 52, height: 52, radius: 16),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SkeletonBlock(width: double.infinity, height: 16),
                SizedBox(height: 8),
                _SkeletonBlock(width: 180, height: 12),
              ],
            ),
          ),
        ],
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
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        song.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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

class _PlaylistGrid extends StatelessWidget {
  const _PlaylistGrid({required this.controller});

  final OuterTuneController controller;

  @override
  Widget build(BuildContext context) {
    final List<_PlaylistShelf> shelves = <_PlaylistShelf>[
      _PlaylistShelf(
        title: 'Favorites',
        subtitle: '${controller.favoriteSongs.length} liked tracks',
        seed: 'favorites',
        songs: controller.favoriteSongs,
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
    final LibrarySong? song = controller.currentSong;
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
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
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
                                            child: Icon(
                                              controller.isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: Colors.black,
                                              size: compact
                                                  ? 22
                                                  : controller.isPlaying
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
                                          icon: _repeatIcon(
                                            controller.repeatMode,
                                          ),
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

Future<void> _showCreatePlaylistDialog(
  BuildContext context,
  OuterTuneController controller,
) async {
  final TextEditingController input = TextEditingController();
  final bool? created = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Create playlist'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (input.text.trim().isEmpty) {
                return;
              }
              await controller.createPlaylist(input.text);
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
  input.dispose();

  if (created == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Playlist created.')));
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

Future<void> _showYtMusicAuthDialog(
  BuildContext context,
  OuterTuneController controller,
) async {
  final TextEditingController input = TextEditingController(
    text: controller.settings.ytMusicAuthJson ?? '',
  );
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('YouTube Music headers'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Paste either the copied raw request headers from a logged-in `music.youtube.com` request or the saved JSON header object.',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: input,
                minLines: 8,
                maxLines: 16,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      'cookie: ...\nx-goog-authuser: 0\nauthorization: SAPISIDHASH ...',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await controller.updateYtMusicAuth(input.text);
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      controller.hasYtMusicAuth
                          ? 'YouTube Music personalization updated.'
                          : 'YouTube Music personalization cleared.',
                    ),
                  ),
                );
              } catch (error) {
                messenger.showSnackBar(SnackBar(content: Text('$error')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  input.dispose();
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
