part of '../ui.dart';

class _SearchPulseHeader extends StatelessWidget {
  const _SearchPulseHeader();

  @override
  Widget build(BuildContext context) {
    return const _HomeStyleHeader(
      title: 'SEARCH',
      leading: _HomeStyleProfileBadge(),
      trailing: _HomeStyleNotificationIcon(),
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
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
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
      clipBehavior: Clip.antiAlias,
      child: _ArtworkFallbackSurface(colors: shelf.colors),
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
  final MusixController controller;

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
                color: _kSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: _kSurfaceEdge),
                ),
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
                  _musixPopupMenuItem('play', 'Play now'),
                  _musixPopupMenuItem('queue', 'Add to queue'),
                  _musixPopupMenuItem(
                    'favorite',
                    song.isFavorite ? 'Remove favorite' : 'Add favorite',
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

class _SearchScreen extends StatefulWidget {
  const _SearchScreen({super.key, required this.controller});

  final MusixController controller;

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 250);
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _recentSearches = <String>[];
  Timer? _searchDebounce;
  bool _requestedTrending = false;

  @override
  void initState() {
    super.initState();
    final String initialDraft = widget.controller.searchDraft;
    if (initialDraft.isNotEmpty) {
      _searchController.value = TextEditingValue(
        text: initialDraft,
        selection: TextSelection.collapsed(offset: initialDraft.length),
      );
    }
    _recentSearches.addAll(widget.controller.recentSearchTerms);
    widget.controller.addListener(_syncSearchStateFromController);
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
    widget.controller.removeListener(_syncSearchStateFromController);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _syncSearchStateFromController() {
    final String draft = widget.controller.searchDraft;
    if (_searchController.text != draft) {
      _searchDebounce?.cancel();
      _searchController.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
    final List<String> nextRecentSearches = widget.controller.recentSearchTerms;
    if (!listEquals(_recentSearches, nextRecentSearches) && mounted) {
      setState(() {
        _recentSearches
          ..clear()
          ..addAll(nextRecentSearches);
      });
    }
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
    widget.controller.cacheSearchDraft(value);
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
    widget.controller.rememberRecentSearch(trimmed);
    setState(() {
      _recentSearches
        ..clear()
        ..addAll(widget.controller.recentSearchTerms);
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

  @override
  Widget build(BuildContext context) {
    if (_isDesktopPlatform()) {
      return _DesktopSearchScreen(
        controller: widget.controller,
        searchController: _searchController,
        scrollController: _scrollController,
        recentSearches: _recentSearches,
        onRunSearch: _runSearch,
        onRememberSearch: _rememberSearch,
        onApplySearch: _applySearch,
        onRemoveSearch: (String term) {
          widget.controller.removeRecentSearch(term);
          setState(() {
            _recentSearches
              ..clear()
              ..addAll(widget.controller.recentSearchTerms);
          });
        },
      );
    }
    final bool searchOffline =
        widget.controller.isOffline || widget.controller.offlineMusicMode;
    if (searchOffline) {
      return _SearchOfflineState(controller: widget.controller);
    }

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
      child: Stack(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: ListView(
              controller: _scrollController,
              padding: _rootScreenContentPadding(
                context,
                hasMiniPlayer: widget.controller.miniPlayerSong != null,
              ),
              children: <Widget>[
                const _SearchPulseHeader(),
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
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFFD8A68C),
                      ),
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
                const SizedBox(height: 15),
                if (_recentSearches.isNotEmpty) ...<Widget>[
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
                              widget.controller.removeRecentSearch(term);
                              setState(() {
                                _recentSearches
                                  ..clear()
                                  ..addAll(widget.controller.recentSearchTerms);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
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
                    '${_lastMonthLabel()} chart - ${widget.controller.trendingNowRegionLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFD1A793),
                      fontWeight: FontWeight.w600,
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFFD1A793)),
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
          ),
        ],
      ),
    );
  }
}

class _SearchOfflineState extends StatelessWidget {
  const _SearchOfflineState({required this.controller});

  final MusixController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF2B0D02), Color(0xFF170602)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: _rootScreenContentPadding(
            context,
            hasMiniPlayer: controller.miniPlayerSong != null,
          ),
          child: Column(
            children: <Widget>[
              const _SearchPulseHeader(),
              const Spacer(),
              _NetworkUnavailablePanel(
                title: controller.offlineMusicMode
                    ? 'Offline Music Only'
                    : 'Search Is Offline',
                message: controller.offlineMusicMode
                    ? 'Search is limited to your local music right now. Reconnect to search online songs again.'
                    : 'Internet is required for online search. Your local music is still available in Home and Library.',
                actionLabel: 'Retry',
                onAction: () => controller.refreshConnectivityStatus(),
                icon: controller.offlineMusicMode
                    ? Icons.offline_bolt_rounded
                    : Icons.wifi_off_rounded,
              ),
              const Spacer(),
            ],
          ),
        ),
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

class _MusixSectionHeaderSkeleton extends StatelessWidget {
  const _MusixSectionHeaderSkeleton();

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

class _MusixPopularTrackTileSkeleton extends StatelessWidget {
  const _MusixPopularTrackTileSkeleton({required this.index});

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
