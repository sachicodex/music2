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
                  const _KineticTopBar(),
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
          ),
          if (controller.isOffline)
            Positioned.fill(
              child: AbsorbPointer(
                child: _NetworkUnavailableOverlay(
                  title: 'You Are Offline',
                  message:
                      'Reconnect to bring back recommendations, trending shelves, and fresh online picks.',
                  actionLabel: 'Try Again',
                  onAction: () async {
                    final bool online = await controller
                        .refreshConnectivityStatus();
                    if (online) {
                      await controller.refreshHomeFeed(force: true);
                    }
                  },
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
  const _KineticTopBar();

  @override
  Widget build(BuildContext context) {
    return const _HomeStyleHeader(
      title: 'KINETIC',
      leading: _HomeStyleProfileBadge(),
      trailing: _HomeStyleNotificationIcon(),
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
                            const Icon(Icons.play_circle, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
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
    final double cardWidth =
        (width - (_kScreenHorizontalPadding * 2) - gap) / 2;

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
    return _KineticSubscreenScaffold(
      title: title,
      child: _ProgressiveListReveal(
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
    );
  }
}

class _RecentPlaysScreen extends StatelessWidget {
  const _RecentPlaysScreen({required this.controller});

  final OuterTuneController controller;

  @override
  Widget build(BuildContext context) {
    final List<LibrarySong> songs = controller.recentlyPlayedSongs;

    return _KineticSubscreenScaffold(
      title: 'JUMP BACK IN',
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
    );
  }
}

class _KineticSubscreenScaffold extends StatelessWidget {
  const _KineticSubscreenScaffold({
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120503),
      body: DecoratedBox(
        decoration: _kineticPageDecoration(),
        child: SafeArea(
          child: ListView(
            padding: _kScreenContentPadding,
            children: <Widget>[
              _KineticSubscreenHeader(title: title, actions: actions),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _KineticSubscreenHeader extends StatelessWidget {
  const _KineticSubscreenHeader({
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

    return _KineticSubscreenScaffold(
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
