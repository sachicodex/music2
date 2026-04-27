part of '../ui.dart';

class _HomeStyleHeader extends StatelessWidget {
  const _HomeStyleHeader({
    required this.title,
    required this.leading,
    required this.trailing,
  });

  final String title;
  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    letterSpacing: 3.2,
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Align(alignment: Alignment.centerLeft, child: leading),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeStyleProfileBadge extends StatelessWidget {
  const _HomeStyleProfileBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
    );
  }
}

class _HomeStyleNotificationIcon extends StatelessWidget {
  const _HomeStyleNotificationIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 44,
      height: 44,
      child: Align(
        alignment: Alignment.centerRight,
        child: Icon(Icons.notifications_none_rounded, color: Colors.white),
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

  final MusixController controller;
  final VoidCallback onOpenSearch;

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen>
    with AutomaticKeepAliveClientMixin<_HomeScreen> {
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

  @override
  bool get wantKeepAlive => true;

  Future<void> _onScroll() async {
    // Home recommendations are intentionally static for this app session.
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final MusixController controller = widget.controller;
    if (_isDesktopPlatform()) {
      return _DesktopHomeScreen(
        controller: controller,
        onOpenSearch: widget.onOpenSearch,
      );
    }
    if (controller.isOfflineViewActive) {
      return _HomeOfflineState(controller: controller);
    }

    final List<HomeFeedSection> feed = controller.homeFeed
        .where((HomeFeedSection section) {
          final String key = section.title.trim().toLowerCase();
          return key != 'trending now' && key != 'chill rotation';
        })
        .toList(growable: false);
    final List<LibrarySong> mayYouLikeFull = _resolvedMayYouLikeSongs(
      controller,
    );
    final List<LibrarySong> mayYouLike = mayYouLikeFull
        .take(4)
        .toList(growable: false);
    final bool hasRevealableContent =
        feed.isNotEmpty || mayYouLikeFull.isNotEmpty;

    final List<LibrarySong> jumpBackIn = controller.recentlyPlayedSongs
        .take(4)
        .toList(growable: false);
    final _FeaturedHeroData? featured = _pickFeaturedHero(
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
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: const Color(0xFFFF8A2A),
              backgroundColor: const Color(0xFF2A1007),
              onRefresh: () => controller.refreshHomeFeed(force: true),
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: _rootScreenContentPadding(
                  context,
                  hasMiniPlayer: controller.miniPlayerSong != null,
                ),
                children: <Widget>[
                  const _MusixTopBar(),
                  const SizedBox(height: 14),
                  if (controller.homeLoading && !hasRevealableContent)
                    const _MusixHeroSkeleton()
                  else if (featured != null)
                    _MusixHeroCard(
                      badge: featured.badge,
                      title: featured.title,
                      subtitle: featured.subtitle,
                      imageUrl: featured.imageUrl,
                      onListenNow: featured.onListenNow,
                    )
                  else
                    const _PersonalizationHintCard(
                      message:
                          'Play local songs, like tracks, or reconnect to load personalized recommendations here.',
                    ),
                  const SizedBox(height: 18),
                  _MusixSectionHeader(
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
                  if (controller.homeLoading && !hasRevealableContent)
                    const _MusixListSkeleton(count: 4)
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
                        return _MusixPopularTrackTile(
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
                  ..._buildMoreShelves(
                    context: context,
                    controller: controller,
                    skipCount: 1,
                  ),
                  if (!controller.homeLoading &&
                      jumpBackIn.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    _MusixSectionHeader(
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
                    _MusixJumpBackGrid(
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
                  if (controller.homeLoading &&
                      !hasRevealableContent) ...<Widget>[
                    const SizedBox(height: 16),
                    const Opacity(opacity: 0.8, child: _HomeFeedSkeleton()),
                  ],
                ],
              ),
            ),
          ),
        ],
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

class _HomeOfflineState extends StatelessWidget {
  const _HomeOfflineState({required this.controller});

  final MusixController controller;

  @override
  Widget build(BuildContext context) {
    final List<LibrarySong> localSongs = controller.browsableSongs
        .where((LibrarySong song) => !song.isRemote)
        .take(6)
        .toList(growable: false);
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
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: _rootScreenContentPadding(
            context,
            hasMiniPlayer: controller.miniPlayerSong != null,
          ),
          children: <Widget>[
            const _MusixTopBar(),
            const SizedBox(height: 18),
            _NetworkUnavailablePanel(
              title: controller.offlineMusicMode
                  ? 'Offline Music Mode'
                  : 'No Internet Connection',
              message: controller.offlineMusicMode
                  ? 'Only your local music is active right now. Online recommendations, search, and cloud content stay paused while you are offline.'
                  : 'Home recommendations need internet. Your downloaded and local tracks stay available until the connection comes back.',
              actionLabel: 'Retry',
              onAction: () async {
                final bool online = await controller
                    .refreshConnectivityStatus();
                if (online && !controller.offlineMusicMode) {
                  await controller.refreshHomeFeed(force: true);
                }
              },
              icon: controller.offlineMusicMode
                  ? Icons.offline_bolt_rounded
                  : Icons.cloud_off_rounded,
            ),
            const SizedBox(height: 22),
            Text(
              'READY OFFLINE',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFE7BAA5),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            if (localSongs.isEmpty)
              const _PersonalizationHintCard(
                message:
                    'Import a folder or add local songs to build your offline library.',
              )
            else
              ...localSongs.asMap().entries.map((MapEntry<int, LibrarySong> e) {
                return _MusixPopularTrackTile(
                  index: e.key + 1,
                  song: e.value,
                  onTap: () => controller.playSongs(
                    localSongs,
                    startIndex: e.key,
                    label: 'Offline',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

List<Widget> _buildMoreShelves({
  required BuildContext context,
  required MusixController controller,
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
              _MusixSectionHeader(
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
                return _MusixPopularTrackTile(
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

List<_SearchGenreShelf> _buildSearchGenreShelves(MusixController controller) {
  final List<LibrarySong> pool = <LibrarySong>[
    ..._resolvedMayYouLikeSongs(controller),
    ...controller.recentlyAddedSongs,
    ...controller.browsableSongs,
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

List<LibrarySong> _resolvedMayYouLikeSongs(MusixController controller) {
  return _resolvedMayYouLikeRecommendations(controller)
      .map((SongRecommendation item) => item.song)
      .where((LibrarySong song) => song.isRemote)
      .toList(growable: false);
}

List<SongRecommendation> _resolvedMayYouLikeRecommendations(
  MusixController controller,
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
    for (final HomeFeedSection section in feed)
      ...section.songs.where((LibrarySong song) => song.isRemote),
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
  required MusixController controller,
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
  // Prefer typical music-length tracks (avoid 1h "mix" style dominating).
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

String _heroSongKey(LibrarySong song) {
  return '${song.title.trim().toLowerCase()}::${song.artist.trim().toLowerCase()}';
}

String _normalizeHeroToken(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(
        RegExp(r'[^\w\s\u0D80-\u0DFF\u0B80-\u0BFF\u0900-\u097F]'),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _heroLanguageBucket(LibrarySong song) {
  final String text =
      '${song.title} ${song.artist} ${song.album} ${song.genre ?? ''}'.trim();
  if (RegExp(r'[\u0D80-\u0DFF]').hasMatch(text)) {
    return 'si';
  }
  if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) {
    return 'ta';
  }
  if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
    return 'hi';
  }
  if (RegExp(r'[a-zA-Z]').hasMatch(text)) {
    return 'en';
  }
  return 'unknown';
}

String _heroHintLanguageBucket(String text) {
  final String normalized = _normalizeHeroToken(text);
  if (normalized.contains('sinhala') ||
      normalized.contains('sinhalese') ||
      normalized.contains('sri lanka')) {
    return 'si';
  }
  if (normalized.contains('tamil')) {
    return 'ta';
  }
  if (normalized.contains('hindi') || normalized.contains('bollywood')) {
    return 'hi';
  }
  if (normalized.contains('english')) {
    return 'en';
  }
  return 'unknown';
}

Set<String> _heroVibeTokens(LibrarySong song) {
  final String text =
      '${song.title} ${song.artist} ${song.album} ${song.genre ?? ''}'
          .toLowerCase();
  const Map<String, List<String>> groups = <String, List<String>>{
    'chill': <String>['chill', 'calm', 'soft', 'lofi', 'acoustic', 'mellow'],
    'energy': <String>['dance', 'party', 'energy', 'club', 'anthem', 'beat'],
    'romance': <String>['love', 'romance', 'heart', 'feel', 'melody'],
    'sad': <String>['sad', 'cry', 'pain', 'broken', 'lonely'],
    'folk': <String>['folk', 'traditional', 'classical', 'acoustic'],
    'devotional': <String>['devotional', 'worship', 'spiritual', 'bhakti'],
    'focus': <String>['focus', 'study', 'piano', 'instrumental'],
  };
  final Set<String> tokens = <String>{};
  for (final MapEntry<String, List<String>> entry in groups.entries) {
    if (entry.value.any(text.contains)) {
      tokens.add(entry.key);
    }
  }
  return tokens;
}

bool _hasKnownHeroArtist(LibrarySong song) {
  final String artist = song.artist.trim().toLowerCase();
  return artist.isNotEmpty && artist != 'unknown' && artist != 'unknown artist';
}

class _HeroPreferenceProfile {
  const _HeroPreferenceProfile({
    required this.primaryLanguage,
    required this.secondaryLanguages,
    required this.artistKeys,
    required this.genreKeys,
    required this.vibeKeys,
    required this.recentArtistKeys,
  });

  final String primaryLanguage;
  final Set<String> secondaryLanguages;
  final Set<String> artistKeys;
  final Set<String> genreKeys;
  final Set<String> vibeKeys;
  final Set<String> recentArtistKeys;
}

class _HeroCandidateInput {
  const _HeroCandidateInput({
    required this.song,
    required this.fromMayYouLike,
    this.queryHint = '',
    this.sectionTitle = '',
  });

  final LibrarySong song;
  final bool fromMayYouLike;
  final String queryHint;
  final String sectionTitle;
}

_HeroPreferenceProfile _buildHeroPreferenceProfile(MusixController controller) {
  final Map<String, double> languageScores = <String, double>{};
  final Map<String, double> artistScores = <String, double>{};
  final Map<String, double> genreScores = <String, double>{};
  final Map<String, double> vibeScores = <String, double>{};

  void addSongs(Iterable<LibrarySong> songs, double baseWeight) {
    int index = 0;
    for (final LibrarySong song in songs) {
      if (!song.isRemote) {
        continue;
      }
      final double weight = math.max(1.0, baseWeight - (index * 0.18));
      final String language = _heroLanguageBucket(song);
      languageScores[language] = (languageScores[language] ?? 0) + weight;

      final String artistKey = _normalizeHeroToken(song.artist);
      if (artistKey.isNotEmpty) {
        artistScores[artistKey] = (artistScores[artistKey] ?? 0) + weight;
      }

      final String genreKey = _normalizeHeroToken(song.genre ?? '');
      if (genreKey.isNotEmpty) {
        genreScores[genreKey] = (genreScores[genreKey] ?? 0) + weight;
      }

      for (final String vibe in _heroVibeTokens(song)) {
        vibeScores[vibe] = (vibeScores[vibe] ?? 0) + weight;
      }
      index += 1;
    }
  }

  addSongs(controller.recentlyPlayedSongs.take(18), 7.5);
  addSongs(controller.topPlayedSongs.take(12), 5.8);
  addSongs(
    controller.likedSongs.where((LibrarySong song) => song.isRemote).take(12),
    5.2,
  );
  addSongs(controller.cachedSongs.take(10), 3.6);

  List<String> topKeys(Map<String, double> scores, int limit) {
    final List<MapEntry<String, double>> sorted = scores.entries.toList()
      ..sort(
        (MapEntry<String, double> a, MapEntry<String, double> b) =>
            b.value.compareTo(a.value),
      );
    return sorted
        .where((MapEntry<String, double> entry) => entry.key.isNotEmpty)
        .take(limit)
        .map((MapEntry<String, double> entry) => entry.key)
        .toList(growable: false);
  }

  final List<String> topLanguages = topKeys(languageScores, 3);
  final String preferredLanguage = controller.preferredLanguageCode;
  final String primaryLanguage = topLanguages.firstWhere(
    (String value) => value != 'unknown',
    orElse: () => preferredLanguage,
  );

  return _HeroPreferenceProfile(
    primaryLanguage: primaryLanguage,
    secondaryLanguages: topLanguages.skip(1).toSet(),
    artistKeys: topKeys(artistScores, 6).toSet(),
    genreKeys: topKeys(genreScores, 5).toSet(),
    vibeKeys: topKeys(vibeScores, 4).toSet(),
    recentArtistKeys: controller.recentlyPlayedSongs
        .take(8)
        .map((LibrarySong song) => _normalizeHeroToken(song.artist))
        .where((String artist) => artist.isNotEmpty)
        .toSet(),
  );
}

String _heroCandidateLanguageBucket(_HeroCandidateInput candidate) {
  final String songLanguage = _heroLanguageBucket(candidate.song);
  if (songLanguage != 'en' && songLanguage != 'unknown') {
    return songLanguage;
  }
  final String hintedLanguage = _heroHintLanguageBucket(
    '${candidate.queryHint} ${candidate.sectionTitle}',
  );
  if (hintedLanguage != 'unknown') {
    return hintedLanguage;
  }
  return songLanguage;
}

bool _isEligibleHeroSong(
  LibrarySong song, {
  required Set<String> historyIds,
  required Set<String> historyKeys,
  required Set<String> queuedKeys,
}) {
  final String key = _heroSongKey(song);
  if (!song.isRemote) {
    return false;
  }
  if (song.playCount > 0 || song.lastPlayedAt != null) {
    return false;
  }
  if (historyIds.contains(song.id) || historyKeys.contains(key)) {
    return false;
  }
  if (queuedKeys.contains(key)) {
    return false;
  }
  if (_isFilteredSuggestion(song)) {
    return false;
  }
  if (!_hasKnownHeroArtist(song)) {
    return false;
  }
  if (_durationScore(song) <= 0) {
    return false;
  }
  return true;
}

double _heroCandidateScore(
  _HeroCandidateInput candidate, {
  required _HeroPreferenceProfile profile,
  required String regionalLanguage,
}) {
  final LibrarySong song = candidate.song;
  double score = 0;
  if (candidate.fromMayYouLike) {
    score += 28;
  }
  score += _hasArtwork(song) * 16;
  score += _durationScore(song) * 3.5;
  score += _titleScore(song) * 2.5;
  if (song.sourceLabel == 'YouTube Music') {
    score += 8;
  } else if (song.sourceLabel == 'YouTube') {
    score += 4;
  }
  if ((song.year ?? 0) >= DateTime.now().year - 4) {
    score += 4;
  }
  final String language = _heroCandidateLanguageBucket(candidate);
  final String artistKey = _normalizeHeroToken(song.artist);
  final String genreKey = _normalizeHeroToken(song.genre ?? '');
  final int vibeMatches = _heroVibeTokens(
    song,
  ).intersection(profile.vibeKeys).length;
  final bool hasTasteMatch =
      profile.artistKeys.contains(artistKey) ||
      (genreKey.isNotEmpty && profile.genreKeys.contains(genreKey)) ||
      vibeMatches > 0;

  if (language == profile.primaryLanguage) {
    score += language == 'en' && !hasTasteMatch ? 4 : 26;
  } else if (profile.secondaryLanguages.contains(language)) {
    score += language == 'en' && !hasTasteMatch ? 2 : 12;
  } else if (regionalLanguage != 'en' && language == regionalLanguage) {
    score += 18;
  } else {
    if (language == 'en' && profile.primaryLanguage != 'en') {
      score -= 18;
    } else if (language != 'unknown' && profile.primaryLanguage != 'unknown') {
      score -= 8;
    }
  }

  if (profile.artistKeys.contains(artistKey)) {
    score += 20;
  }
  if (genreKey.isNotEmpty && profile.genreKeys.contains(genreKey)) {
    score += 10;
  }
  score += vibeMatches * 7;

  if (!profile.recentArtistKeys.contains(artistKey)) {
    score += 4;
  } else if (!profile.artistKeys.contains(artistKey)) {
    score -= 6;
  }

  if (language == 'en' && regionalLanguage != 'en' && !hasTasteMatch) {
    score -= 18;
  }

  if (language != profile.primaryLanguage &&
      !profile.artistKeys.contains(artistKey) &&
      !profile.genreKeys.contains(genreKey) &&
      vibeMatches == 0) {
    score -= 16;
  }
  return score;
}

bool _heroMatchesProfile(
  _HeroCandidateInput candidate,
  _HeroPreferenceProfile profile, {
  required String regionalLanguage,
}) {
  final LibrarySong song = candidate.song;
  final String language = _heroCandidateLanguageBucket(candidate);
  final String artistKey = _normalizeHeroToken(song.artist);
  final String genreKey = _normalizeHeroToken(song.genre ?? '');
  final int vibeMatches = _heroVibeTokens(
    song,
  ).intersection(profile.vibeKeys).length;
  final bool tasteMatch =
      profile.artistKeys.contains(artistKey) ||
      (genreKey.isNotEmpty && profile.genreKeys.contains(genreKey)) ||
      vibeMatches > 0;

  if (language == profile.primaryLanguage ||
      profile.secondaryLanguages.contains(language)) {
    if (language != 'en') {
      return true;
    }
    return tasteMatch;
  }
  if (regionalLanguage != 'en' && language == regionalLanguage && tasteMatch) {
    return true;
  }
  return tasteMatch;
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

_FeaturedHeroData? _pickFeaturedHero({
  required BuildContext context,
  required MusixController controller,
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
  return null;
}

LibrarySong? _pickAdvancedHeroSong({
  required MusixController controller,
  required List<HomeFeedSection> feed,
  required List<LibrarySong> mayYouLike,
}) {
  final Set<String> historyIds = controller.history
      .map((PlaybackEntry entry) => entry.songId)
      .toSet();
  final Set<String> historyKeys = controller.history
      .map((PlaybackEntry entry) => controller.songById(entry.songId))
      .whereType<LibrarySong>()
      .map(_heroSongKey)
      .toSet();
  final Set<String> queuedKeys = controller.queueSongs
      .where((LibrarySong song) => song.isRemote)
      .map(_heroSongKey)
      .toSet();
  final _HeroPreferenceProfile profile = _buildHeroPreferenceProfile(
    controller,
  );
  final String regionalLanguage = controller.preferredRegion.languageCode;
  final Set<String> mayYouLikeKeys = mayYouLike.map(_heroSongKey).toSet();
  final Map<String, _HeroCandidateInput> candidatesByKey =
      <String, _HeroCandidateInput>{};

  void addCandidate(
    LibrarySong song, {
    required bool fromMayYouLike,
    String queryHint = '',
    String sectionTitle = '',
  }) {
    if (!_isEligibleHeroSong(
      song,
      historyIds: historyIds,
      historyKeys: historyKeys,
      queuedKeys: queuedKeys,
    )) {
      return;
    }
    final String key = _heroSongKey(song);
    final _HeroCandidateInput? existing = candidatesByKey[key];
    if (existing == null) {
      candidatesByKey[key] = _HeroCandidateInput(
        song: song,
        fromMayYouLike: fromMayYouLike,
        queryHint: queryHint,
        sectionTitle: sectionTitle,
      );
      return;
    }
    candidatesByKey[key] = _HeroCandidateInput(
      song: existing.song,
      fromMayYouLike: existing.fromMayYouLike || fromMayYouLike,
      queryHint: existing.queryHint.isNotEmpty ? existing.queryHint : queryHint,
      sectionTitle: existing.sectionTitle.isNotEmpty
          ? existing.sectionTitle
          : sectionTitle,
    );
  }

  for (final HomeFeedSection section in feed) {
    for (final LibrarySong song in section.songs) {
      addCandidate(
        song,
        fromMayYouLike: mayYouLikeKeys.contains(_heroSongKey(song)),
        queryHint: section.query,
        sectionTitle: section.title,
      );
    }
  }
  for (final LibrarySong song in mayYouLike) {
    addCandidate(song, fromMayYouLike: true);
  }

  final List<_HeroCandidateInput> candidates = candidatesByKey.values.toList(
    growable: false,
  );
  if (candidates.isEmpty) {
    return _pickFallbackHeroSong(feed: feed, mayYouLike: mayYouLike);
  }

  final List<_HeroCandidateInput> profileMatched = candidates
      .where(
        (_HeroCandidateInput candidate) => _heroMatchesProfile(
          candidate,
          profile,
          regionalLanguage: regionalLanguage,
        ),
      )
      .toList(growable: false);
  final List<_HeroCandidateInput> languageMatched = profileMatched
      .where(
        (_HeroCandidateInput candidate) =>
            _heroCandidateLanguageBucket(candidate) == profile.primaryLanguage,
      )
      .toList(growable: false);
  final List<_HeroCandidateInput> regionalLanguageMatched =
      regionalLanguage == 'en'
      ? const <_HeroCandidateInput>[]
      : profileMatched
            .where(
              (_HeroCandidateInput candidate) =>
                  _heroCandidateLanguageBucket(candidate) == regionalLanguage,
            )
            .toList(growable: false);
  final List<_HeroCandidateInput> explicitNonEnglishMatches = profileMatched
      .where((_HeroCandidateInput candidate) {
        final String language = _heroCandidateLanguageBucket(candidate);
        return language != 'en' && language != 'unknown';
      })
      .toList(growable: false);
  final List<_HeroCandidateInput> rankingPool = languageMatched.isNotEmpty
      ? languageMatched
      : regionalLanguageMatched.isNotEmpty
      ? regionalLanguageMatched
      : explicitNonEnglishMatches.isNotEmpty
      ? explicitNonEnglishMatches
      : profileMatched.isNotEmpty
      ? profileMatched
      : candidates;

  final List<_HeroCandidateScore> ranked =
      rankingPool
          .map((_HeroCandidateInput candidate) {
            final double score = _heroCandidateScore(
              candidate,
              profile: profile,
              regionalLanguage: regionalLanguage,
            );
            return _HeroCandidateScore(song: candidate.song, score: score);
          })
          .toList(growable: false)
        ..sort((_HeroCandidateScore a, _HeroCandidateScore b) {
          final int scoreCompare = b.score.compareTo(a.score);
          if (scoreCompare != 0) {
            return scoreCompare;
          }
          final int mayYouLikeCompare = candidateFromMayYouLike(
            b.song,
            mayYouLike,
          ).compareTo(candidateFromMayYouLike(a.song, mayYouLike));
          if (mayYouLikeCompare != 0) {
            return mayYouLikeCompare;
          }
          return a.song.title.toLowerCase().compareTo(
            b.song.title.toLowerCase(),
          );
        });
  return ranked.firstOrNull?.song ??
      _pickFallbackHeroSong(feed: feed, mayYouLike: mayYouLike);
}

int candidateFromMayYouLike(LibrarySong song, List<LibrarySong> mayYouLike) {
  return mayYouLike.any((LibrarySong item) => item.id == song.id) ? 1 : 0;
}

LibrarySong? _pickFallbackHeroSong({
  required List<HomeFeedSection> feed,
  required List<LibrarySong> mayYouLike,
}) {
  final Map<String, LibrarySong> candidatesByKey = <String, LibrarySong>{};

  void addSong(LibrarySong song) {
    if (!song.isRemote) {
      return;
    }
    if (_isFilteredSuggestion(song)) {
      return;
    }
    if (!_hasKnownHeroArtist(song)) {
      return;
    }
    if (_durationScore(song) <= 0) {
      return;
    }
    candidatesByKey.putIfAbsent(_heroSongKey(song), () => song);
  }

  for (final LibrarySong song in mayYouLike) {
    addSong(song);
  }
  for (final HomeFeedSection section in feed) {
    for (final LibrarySong song in section.songs) {
      addSong(song);
    }
  }

  final List<LibrarySong> ranked =
      candidatesByKey.values.toList(growable: false)
        ..sort((LibrarySong a, LibrarySong b) {
          final int mayYouLikeCompare = candidateFromMayYouLike(
            b,
            mayYouLike,
          ).compareTo(candidateFromMayYouLike(a, mayYouLike));
          if (mayYouLikeCompare != 0) {
            return mayYouLikeCompare;
          }
          final int artworkCompare = _hasArtwork(b).compareTo(_hasArtwork(a));
          if (artworkCompare != 0) {
            return artworkCompare;
          }
          final int sourceCompare = (b.sourceLabel == 'YouTube Music' ? 1 : 0)
              .compareTo(a.sourceLabel == 'YouTube Music' ? 1 : 0);
          if (sourceCompare != 0) {
            return sourceCompare;
          }
          final int durationCompare = _durationScore(
            b,
          ).compareTo(_durationScore(a));
          if (durationCompare != 0) {
            return durationCompare;
          }
          final int titleCompare = _titleScore(b).compareTo(_titleScore(a));
          if (titleCompare != 0) {
            return titleCompare;
          }
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });

  return ranked.firstOrNull;
}

class _HeroCandidateScore {
  const _HeroCandidateScore({required this.song, required this.score});

  final LibrarySong song;
  final double score;
}

class _MusixTopBar extends StatelessWidget {
  const _MusixTopBar();

  @override
  Widget build(BuildContext context) {
    return const _HomeStyleHeader(
      title: 'MUSIX',
      leading: _HomeStyleProfileBadge(),
      trailing: _HomeStyleNotificationIcon(),
    );
  }
}

class _MusixHeroCard extends StatelessWidget {
  const _MusixHeroCard({
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
                    child: _CachedArtworkImage(
                      imageUrl: imageUrl!,
                      dimension: constraints.maxWidth,
                      errorWidget: const DecoratedBox(
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
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.play_circle, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'LISTEN NOW',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      letterSpacing: 1.2,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
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

class _MusixSectionHeader extends StatelessWidget {
  const _MusixSectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final Widget action = TextButton(
      onPressed: onViewAll,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.55),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.zero,
      ),
      child: Text(
        'VIEW ALL',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(letterSpacing: 1.4),
      ),
    );

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
        Align(alignment: Alignment.centerRight, child: action),
      ],
    );
  }
}

class _MusixPopularTrackTile extends StatelessWidget {
  const _MusixPopularTrackTile({
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
    return RepaintBoundary(
      child: InkWell(
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
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  durationText,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusixJumpBackGrid extends StatelessWidget {
  const _MusixJumpBackGrid({required this.items, required this.onTapItem});

  final List<LibrarySong> items;
  final ValueChanged<LibrarySong> onTapItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        "Play something and it'll show up here.",
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.55),
        ),
      );
    }

    final double width = MediaQuery.sizeOf(context).width;
    final double gap = 14;
    final double cardWidth =
        (width - (_kScreenHorizontalPadding * 2) - gap) / 2;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: items.take(4).map((LibrarySong song) {
        return _MusixJumpBackCard(
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

class _MusixJumpBackCard extends StatelessWidget {
  const _MusixJumpBackCard({
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
          color: const Color(0xFF2A160C).withValues(alpha: 0.70),
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

class _SimplePlaybackTile extends StatelessWidget {
  const _SimplePlaybackTile({required this.song, required this.onTap});

  final LibrarySong song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              _Artwork(
                seed: song.id,
                title: song.title,
                size: 48,
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
                      _songArtistLabel(song),
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

  final MusixController controller;
  final String title;
  final List<LibrarySong> songs;

  @override
  Widget build(BuildContext context) {
    return _MusixSubscreenScaffold(
      title: title,
      child: _ProgressiveListReveal(
        itemCount: songs.length,
        itemBuilder: (BuildContext context, int index) {
          final LibrarySong song = songs[index];
          return _MusixPopularTrackTile(
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
    );
  }
}

class _RecentPlaysScreen extends StatelessWidget {
  const _RecentPlaysScreen({required this.controller});

  final MusixController controller;

  @override
  Widget build(BuildContext context) {
    final MusixController liveController = context.watch<MusixController>();
    final List<LibrarySong> songs = liveController.recentlyPlayedSongs;

    return _MusixSubscreenScaffold(
      title: 'JUMP BACK IN',
      actions: <Widget>[
        TextButton.icon(
          onPressed: songs.isEmpty
              ? null
              : () async {
                  final bool confirmed =
                      await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: _kSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: const BorderSide(color: _kSurfaceEdge),
                            ),
                            title: Text(
                              'Clear history?',
                              style: GoogleFonts.splineSans(
                                color: _kTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            content: Text(
                              'This clears Jump Back In history and removes its playback traces.',
                              style: GoogleFonts.splineSans(
                                color: _kTextSecondary,
                                height: 1.45,
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFDE6B48),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Clear'),
                              ),
                            ],
                          );
                        },
                      ) ??
                      false;
                  if (!confirmed || !context.mounted) {
                    return;
                  }
                  await liveController.clearPlaybackHistory();
                  if (context.mounted) {
                    _showMusixSnackBar(context, 'Playback history cleared');
                  }
                },
          icon: const Icon(Icons.history_toggle_off_rounded),
          label: const Text('Clear History'),
          style: TextButton.styleFrom(
            foregroundColor: _kAccent,
            backgroundColor: const Color(0x221C0904),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _kSurfaceEdge),
            ),
          ),
        ),
      ],
      child: songs.isEmpty
          ? Builder(
              builder: (BuildContext context) {
                return Text(
                  'Play songs and they will appear here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFFC8A9),
                  ),
                );
              },
            )
          : _ProgressiveListReveal(
              itemCount: songs.length,
              itemBuilder: (BuildContext context, int index) {
                final LibrarySong song = songs[index];
                return _SimplePlaybackTile(
                  song: song,
                  onTap: () {
                    if (song.isRemote) {
                      liveController.playOnlineSong(song);
                    } else {
                      liveController.playSong(song, label: 'Jump back in');
                    }
                  },
                );
              },
            ),
    );
  }
}

class _MusixSubscreenScaffold extends StatelessWidget {
  const _MusixSubscreenScaffold({
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final MusixController controller = context.watch<MusixController>();
    final bool desktop = _isDesktopPlatform();
    final Widget content = ListView(
      padding: EdgeInsets.fromLTRB(
        _kScreenHorizontalPadding,
        _kScreenTopPadding,
        _kScreenHorizontalPadding,
        _kScreenBottomPadding +
            (!desktop && controller.miniPlayerSong != null
                ? _kMiniPlayerReservedHeight
                : 0),
      ),
      children: <Widget>[
        _MusixSubscreenHeader(title: title, actions: actions),
        const SizedBox(height: 10),
        child,
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF120503),
      body: DecoratedBox(
        decoration: _musixPageDecoration(),
        child: SafeArea(
          child: desktop
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: content),
                      if (controller.miniPlayerSong != null) ...<Widget>[
                        const SizedBox(width: 18),
                        SizedBox(
                          width: MediaQuery.sizeOf(context).width >= 1400
                              ? 360
                              : 320,
                          child: _DesktopNowPlayingRail(
                            controller: controller,
                            onOpenPlayer: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      _PlayerScreen(controller: controller),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : content,
        ),
      ),
      bottomNavigationBar: desktop || controller.miniPlayerSong == null
          ? null
          : SafeArea(
              top: false,
              child: _MiniPlayer(
                controller: controller,
                onOpenPlayer: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          _PlayerScreen(controller: controller),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _MusixSubscreenHeader extends StatelessWidget {
  const _MusixSubscreenHeader({
    required this.title,
    this.actions = const <Widget>[],
  });

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return _HomeStyleHeader(
      title: title,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
      trailing: actions.isEmpty
          ? const SizedBox.shrink()
          : Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }
}

class _MayYouLikeScreen extends StatefulWidget {
  const _MayYouLikeScreen({required this.controller});

  final MusixController controller;

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
    final MusixController controller = widget.controller;
    final List<SongRecommendation> items = _allItems;

    return _MusixSubscreenScaffold(
      title: 'MAY YOU LIKE',
      child: Column(
        children: <Widget>[
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
                return _MusixPopularTrackTile(
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
          child: _MusixPopularTrackTileSkeleton(index: index + 1),
        );
      },
    );
  }
}

class _MusixListSkeleton extends StatelessWidget {
  const _MusixListSkeleton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(count, (int index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _MusixPopularTrackTileSkeleton(index: index + 1),
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

class _MusixHeroSkeleton extends StatelessWidget {
  const _MusixHeroSkeleton();

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
