part of '../ui.dart';

class _PlayerScreen extends StatefulWidget {
  const _PlayerScreen({required this.controller});

  final MusixController controller;

  @override
  State<_PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<_PlayerScreen>
    with TickerProviderStateMixin {
  static const double _kPlayerGestureVelocity = 420;

  late final AnimationController _tapFeedbackController;
  late final AnimationController _likeFeedbackController;
  bool _showPauseGlyph = false;

  @override
  void initState() {
    super.initState();
    _tapFeedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _likeFeedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _tapFeedbackController.dispose();
    _likeFeedbackController.dispose();
    super.dispose();
  }

  Future<void> _showQueueSheet() async {
    final MusixController controller = widget.controller;
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
    final MusixController controller = widget.controller;
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

  Future<void> _handleAlbumArtDoubleTap(LibrarySong song) async {
    await _triggerLikeFeedback();
    if (!song.isLiked) {
      await widget.controller.likeSong(song.id);
    }
  }

  Future<void> _handleAlbumArtTap() async {
    await _triggerPlaybackFeedback();
    unawaited(widget.controller.togglePlayback());
  }

  Future<void> _handleDislikeAction(LibrarySong song) async {
    await HapticFeedback.mediumImpact();
    await widget.controller.dislikeSong(song.id);
  }

  Future<void> _triggerPlaybackFeedback() async {
    final PlaybackProgressState progress =
        widget.controller.playbackProgressState.value;
    final bool isPlayerLoading =
        widget.controller.nowPlayingState.value.isLoading;
    _showPauseGlyph = !progress.isPlaying || isPlayerLoading;
    _tapFeedbackController
      ..stop()
      ..reset()
      ..forward();
    unawaited(HapticFeedback.lightImpact());
  }

  Future<void> _triggerLikeFeedback() async {
    _likeFeedbackController
      ..stop()
      ..reset()
      ..forward();
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _handlePlayerPanEnd(DragEndDetails details) async {
    final Velocity velocity = details.velocity;
    final double dx = velocity.pixelsPerSecond.dx;
    final double dy = velocity.pixelsPerSecond.dy;

    if (dx.abs() < _kPlayerGestureVelocity &&
        dy.abs() < _kPlayerGestureVelocity) {
      return;
    }

    if (dx.abs() > dy.abs()) {
      unawaited(HapticFeedback.selectionClick());
      if (dx < 0) {
        await widget.controller.nextTrack();
      } else {
        await widget.controller.previousTrack();
      }
      return;
    }

    if (dy < 0) {
      await HapticFeedback.selectionClick();
      await _showQueueSheet();
      return;
    }

    await HapticFeedback.selectionClick();
    if (mounted) {
      await Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MusixController controller = widget.controller;
    return ValueListenableBuilder<NowPlayingState>(
      valueListenable: controller.nowPlayingState,
      builder: (BuildContext context, NowPlayingState nowPlaying, Widget? child) {
        final LibrarySong? song = nowPlaying.song;
        if (song == null) {
          return const Scaffold(
            body: Center(child: Text('Nothing is playing.')),
          );
        }

        final bool isPlayerLoading = nowPlaying.isLoading;
        const Color backgroundTop = Color(0xFF774120);
        const Color backgroundBottom = Color(0xFF200901);
        const Color surface = Color(0xFF120606);
        const Color accent = Color(0xFFFF7F2A);
        const Color textPrimary = Color(0xFFFFDFC9);
        const Color textSecondary = Color(0xFFE9A56F);
        const Color trackInactive = Color(0xFF5A2508);

        if (_isDesktopPlatform()) {
          return _DesktopPlayerScreen(
            controller: controller,
            song: song,
            nowPlaying: nowPlaying,
            tapFeedbackController: _tapFeedbackController,
            likeFeedbackController: _likeFeedbackController,
            showPauseGlyph: _showPauseGlyph,
            onHandlePlayerMenuSelection: _handlePlayerMenuSelection,
            onAlbumArtDoubleTap: _handleAlbumArtDoubleTap,
            onAlbumArtTap: _handleAlbumArtTap,
            onDislikeAction: _handleDislikeAction,
            onTriggerPlaybackFeedback: _triggerPlaybackFeedback,
            onTriggerLikeFeedback: _triggerLikeFeedback,
            onShowQueueSheet: _showQueueSheet,
            backgroundTop: backgroundTop,
            backgroundBottom: backgroundBottom,
            surface: surface,
            accent: accent,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            trackInactive: trackInactive,
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanEnd: _handlePlayerPanEnd,
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
                    final double layoutScale = (constraints.maxHeight / 780)
                        .clamp(0.68, 1.0);
                    double scale(double value, {double? min, double? max}) {
                      final double scaled = value * layoutScale;
                      return scaled.clamp(
                        min ?? double.negativeInfinity,
                        max ?? double.infinity,
                      );
                    }

                    final double horizontalPadding = constraints.maxWidth < 360
                        ? 12
                        : 16;
                    final double artSize = math.min(
                      constraints.maxWidth - (horizontalPadding * 2),
                      math.min(
                        scale(328, min: 220, max: 328),
                        constraints.maxHeight * 0.38,
                      ),
                    );

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        scale(8, min: 6, max: 8),
                        horizontalPadding,
                        scale(20, min: 16, max: 28),
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
                                iconSize: scale(28, min: 24, max: 28),
                              ),
                              Expanded(
                                child: Text(
                                  'NOW PLAYING',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.splineSans(
                                    color: accent,
                                    fontSize: scale(17, min: 14, max: 17),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: scale(1.6, min: 1.1),
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                color: _kSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: _kSurfaceEdge),
                                ),
                                icon: const Icon(Icons.more_vert_rounded),
                                iconColor: accent,
                                onSelected: (String value) async {
                                  await _handlePlayerMenuSelection(value, song);
                                },
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                      _musixPopupMenuItem('save', 'Save'),
                                      _musixPopupMenuItem(
                                        'like',
                                        song.isLiked
                                            ? 'Unlike song'
                                            : 'Like song',
                                      ),
                                      _musixPopupMenuItem(
                                        'dislike',
                                        song.isDisliked
                                            ? 'Remove dislike'
                                            : 'Dislike song',
                                      ),
                                      _musixPopupMenuItem(
                                        'queue',
                                        'Add to queue',
                                      ),
                                    ],
                              ),
                            ],
                          ),
                          Spacer(flex: layoutScale < 0.8 ? 1 : 2),
                          Center(
                            child: RepaintBoundary(
                              child: SizedBox(
                                width: artSize,
                                height: artSize,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _handleAlbumArtTap,
                                  onDoubleTap: () =>
                                      _handleAlbumArtDoubleTap(song),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: surface,
                                      borderRadius: BorderRadius.circular(
                                        scale(34, min: 24, max: 34),
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.42,
                                          ),
                                          blurRadius: scale(
                                            32,
                                            min: 18,
                                            max: 32,
                                          ),
                                          offset: Offset(
                                            scale(14, min: 8, max: 14),
                                            scale(18, min: 10, max: 18),
                                          ),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        scale(34, min: 24, max: 34),
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 260,
                                        ),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        layoutBuilder:
                                            (
                                              Widget? currentChild,
                                              List<Widget> previousChildren,
                                            ) {
                                              return currentChild ??
                                                  const SizedBox.expand(
                                                    child: _PlayerArtFallback(),
                                                  );
                                            },
                                        transitionBuilder:
                                            (
                                              Widget child,
                                              Animation<double> animation,
                                            ) {
                                              return FadeTransition(
                                                opacity: animation,
                                                child: ScaleTransition(
                                                  scale: Tween<double>(
                                                    begin: 0.985,
                                                    end: 1,
                                                  ).animate(animation),
                                                  child: child,
                                                ),
                                              );
                                            },
                                        child: Stack(
                                          key: ValueKey<String>(
                                            '${song.id}|${song.artworkUrl ?? ''}',
                                          ),
                                          fit: StackFit.expand,
                                          children: <Widget>[
                                            if (song.artworkUrl != null &&
                                                song.artworkUrl!
                                                    .trim()
                                                    .isNotEmpty)
                                              _CachedArtworkImage(
                                                imageUrl: song.artworkUrl!,
                                                dimension: artSize,
                                                placeholder:
                                                    const _PlayerArtFallback(),
                                                errorWidget:
                                                    const _PlayerArtFallback(),
                                              )
                                            else
                                              const _PlayerArtFallback(),
                                            IgnorePointer(
                                              child:
                                                  _PlayerArtInteractionOverlay(
                                                    tapController:
                                                        _tapFeedbackController,
                                                    likeController:
                                                        _likeFeedbackController,
                                                    showPauseGlyph:
                                                        _showPauseGlyph,
                                                    isLiked: song.isLiked,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Spacer(flex: layoutScale < 0.8 ? 1 : 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      song.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.splineSans(
                                        color: textPrimary,
                                        fontSize: scale(33, min: 24, max: 33),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -scale(
                                          1.6,
                                          min: 1.0,
                                          max: 1.6,
                                        ),
                                        height: 0.96,
                                      ),
                                    ),
                                    SizedBox(height: scale(8, min: 4, max: 8)),
                                    Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.splineSans(
                                        color: textSecondary,
                                        fontSize: scale(16, min: 13, max: 16),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: scale(16, min: 8, max: 16)),
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: scale(6, min: 2, max: 6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    IconButton(
                                      onPressed: () async {
                                        if (!song.isLiked) {
                                          await _triggerLikeFeedback();
                                        }
                                        await controller.likeSong(song.id);
                                      },
                                      icon: Icon(
                                        song.isLiked
                                            ? Icons.thumb_up_rounded
                                            : Icons.thumb_up_outlined,
                                        color: accent,
                                        size: scale(28, min: 22, max: 28),
                                      ),
                                    ),
                                    SizedBox(width: scale(4, min: 0, max: 4)),
                                    IconButton(
                                      onPressed: () =>
                                          _handleDislikeAction(song),
                                      icon: Icon(
                                        song.isDisliked
                                            ? Icons.thumb_down_rounded
                                            : Icons.thumb_down_outlined,
                                        color: song.isDisliked
                                            ? Colors.redAccent
                                            : accent,
                                        size: scale(28, min: 22, max: 28),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: scale(14, min: 10, max: 20)),
                          ValueListenableBuilder<PlaybackProgressState>(
                            valueListenable: controller.playbackProgressState,
                            builder:
                                (
                                  BuildContext context,
                                  PlaybackProgressState progress,
                                  Widget? child,
                                ) {
                                  final Duration position = isPlayerLoading
                                      ? Duration.zero
                                      : progress.position;
                                  final Duration duration =
                                      progress.duration == Duration.zero
                                      ? song.duration
                                      : progress.duration;
                                  final double sliderMax = math.max(
                                    duration.inMilliseconds.toDouble(),
                                    1,
                                  );
                                  final double sliderValue = position
                                      .inMilliseconds
                                      .clamp(0, sliderMax.toInt())
                                      .toDouble();
                                  final bool showPauseIcon =
                                      progress.isPlaying && !isPlayerLoading;

                                  return _PlayerProgressAndControls(
                                    layoutScale: layoutScale,
                                    accent: accent,
                                    textPrimary: textPrimary,
                                    trackInactive: trackInactive,
                                    sliderValue: sliderValue,
                                    sliderMax: sliderMax,
                                    position: position,
                                    duration: duration,
                                    isPlayerLoading: isPlayerLoading,
                                    isShuffleEnabled:
                                        nowPlaying.isShuffleEnabled,
                                    repeatMode: nowPlaying.repeatMode,
                                    onSeek: controller.seek,
                                    onToggleShuffle: controller.toggleShuffle,
                                    onPrevious: controller.previousTrack,
                                    onNext: controller.nextTrack,
                                    onCycleRepeatMode:
                                        controller.cycleRepeatMode,
                                    onTogglePlayback: () async {
                                      await _triggerPlaybackFeedback();
                                      unawaited(controller.togglePlayback());
                                    },
                                    onShowQueue: _showQueueSheet,
                                    showPauseIcon: showPauseIcon,
                                  );
                                },
                          ),
                        ],
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

class _DesktopPlayerScreen extends StatelessWidget {
  const _DesktopPlayerScreen({
    required this.controller,
    required this.song,
    required this.nowPlaying,
    required this.tapFeedbackController,
    required this.likeFeedbackController,
    required this.showPauseGlyph,
    required this.onHandlePlayerMenuSelection,
    required this.onAlbumArtDoubleTap,
    required this.onAlbumArtTap,
    required this.onDislikeAction,
    required this.onTriggerPlaybackFeedback,
    required this.onTriggerLikeFeedback,
    required this.onShowQueueSheet,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.surface,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.trackInactive,
  });

  final MusixController controller;
  final LibrarySong song;
  final NowPlayingState nowPlaying;
  final AnimationController tapFeedbackController;
  final AnimationController likeFeedbackController;
  final bool showPauseGlyph;
  final Future<void> Function(String value, LibrarySong song)
  onHandlePlayerMenuSelection;
  final Future<void> Function(LibrarySong song) onAlbumArtDoubleTap;
  final Future<void> Function() onAlbumArtTap;
  final Future<void> Function(LibrarySong song) onDislikeAction;
  final Future<void> Function() onTriggerPlaybackFeedback;
  final Future<void> Function() onTriggerLikeFeedback;
  final Future<void> Function() onShowQueueSheet;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color surface;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color trackInactive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            unawaited(controller.previousTrack());
          },
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            unawaited(controller.nextTrack());
          },
          const SingleActivator(LogicalKeyboardKey.keyQ): () {
            unawaited(onShowQueueSheet());
          },
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[backgroundTop, backgroundBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool stacked = constraints.maxWidth < 1320;
                  final Widget mainPanel = _DesktopPlayerArtworkPanel(
                    controller: controller,
                    song: song,
                    nowPlaying: nowPlaying,
                    tapFeedbackController: tapFeedbackController,
                    likeFeedbackController: likeFeedbackController,
                    showPauseGlyph: showPauseGlyph,
                    accent: accent,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    surface: surface,
                    onAlbumArtTap: onAlbumArtTap,
                    onAlbumArtDoubleTap: onAlbumArtDoubleTap,
                    onHandlePlayerMenuSelection: onHandlePlayerMenuSelection,
                    onDislikeAction: onDislikeAction,
                    onTriggerLikeFeedback: onTriggerLikeFeedback,
                    onShowQueueSheet: onShowQueueSheet,
                    onTriggerPlaybackFeedback: onTriggerPlaybackFeedback,
                    trackInactive: trackInactive,
                  );

                  final Widget queuePanel = _DesktopPlayerQueuePanel(
                    controller: controller,
                    accent: accent,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onShowQueueSheet: onShowQueueSheet,
                  );

                  if (stacked) {
                    return ListView(
                      children: <Widget>[
                        mainPanel,
                        const SizedBox(height: 18),
                        SizedBox(height: 440, child: queuePanel),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(flex: 7, child: mainPanel),
                      const SizedBox(width: 18),
                      Expanded(flex: 4, child: queuePanel),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopPlayerArtworkPanel extends StatelessWidget {
  const _DesktopPlayerArtworkPanel({
    required this.controller,
    required this.song,
    required this.nowPlaying,
    required this.tapFeedbackController,
    required this.likeFeedbackController,
    required this.showPauseGlyph,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
    required this.onAlbumArtTap,
    required this.onAlbumArtDoubleTap,
    required this.onHandlePlayerMenuSelection,
    required this.onDislikeAction,
    required this.onTriggerLikeFeedback,
    required this.onShowQueueSheet,
    required this.onTriggerPlaybackFeedback,
    required this.trackInactive,
  });

  final MusixController controller;
  final LibrarySong song;
  final NowPlayingState nowPlaying;
  final AnimationController tapFeedbackController;
  final AnimationController likeFeedbackController;
  final bool showPauseGlyph;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color surface;
  final Future<void> Function() onAlbumArtTap;
  final Future<void> Function(LibrarySong song) onAlbumArtDoubleTap;
  final Future<void> Function(String value, LibrarySong song)
  onHandlePlayerMenuSelection;
  final Future<void> Function(LibrarySong song) onDislikeAction;
  final Future<void> Function() onTriggerLikeFeedback;
  final Future<void> Function() onShowQueueSheet;
  final Future<void> Function() onTriggerPlaybackFeedback;
  final Color trackInactive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0D09).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF342018)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NOW PLAYING',
                  style: GoogleFonts.ibmPlexSans(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                color: _kSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: _kSurfaceEdge),
                ),
                icon: const Icon(Icons.more_horiz_rounded),
                iconColor: accent,
                onSelected: (String value) async {
                  await onHandlePlayerMenuSelection(value, song);
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  _musixPopupMenuItem('save', 'Save'),
                  _musixPopupMenuItem(
                    'like',
                    song.isLiked ? 'Unlike song' : 'Like song',
                  ),
                  _musixPopupMenuItem(
                    'dislike',
                    song.isDisliked ? 'Remove dislike' : 'Dislike song',
                  ),
                  _musixPopupMenuItem('queue', 'Add to queue'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 520,
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onAlbumArtTap,
                    onDoubleTap: () => onAlbumArtDoubleTap(song),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(38),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.38),
                            blurRadius: 34,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(38),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Stack(
                            key: ValueKey<String>(
                              '${song.id}|${song.artworkUrl ?? ''}',
                            ),
                            fit: StackFit.expand,
                            children: <Widget>[
                              if (song.artworkUrl != null &&
                                  song.artworkUrl!.trim().isNotEmpty)
                                _CachedArtworkImage(
                                  imageUrl: song.artworkUrl!,
                                  dimension: 520,
                                  placeholder: const _PlayerArtFallback(),
                                  errorWidget: const _PlayerArtFallback(),
                                )
                              else
                                const _PlayerArtFallback(),
                              IgnorePointer(
                                child: _PlayerArtInteractionOverlay(
                                  tapController: tapFeedbackController,
                                  likeController: likeFeedbackController,
                                  showPauseGlyph: showPauseGlyph,
                                  isLiked: song.isLiked,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      song.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: textPrimary,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        height: 0.94,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSans(
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
                      onPressed: () async {
                        if (!song.isLiked) {
                          await onTriggerLikeFeedback();
                        }
                        await controller.likeSong(song.id);
                      },
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
                      onPressed: () => onDislikeAction(song),
                      icon: Icon(
                        song.isDisliked
                            ? Icons.thumb_down_rounded
                            : Icons.thumb_down_outlined,
                        color: song.isDisliked ? Colors.redAccent : accent,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ValueListenableBuilder<PlaybackProgressState>(
            valueListenable: controller.playbackProgressState,
            builder:
                (
                  BuildContext context,
                  PlaybackProgressState progress,
                  Widget? child,
                ) {
                  final Duration position = nowPlaying.isLoading
                      ? Duration.zero
                      : progress.position;
                  final Duration duration = progress.duration == Duration.zero
                      ? song.duration
                      : progress.duration;
                  final double sliderMax = math.max(
                    duration.inMilliseconds.toDouble(),
                    1,
                  );
                  final double sliderValue = position.inMilliseconds
                      .clamp(0, sliderMax.toInt())
                      .toDouble();
                  final bool showPauseIcon =
                      progress.isPlaying && !nowPlaying.isLoading;

                  return _PlayerProgressAndControls(
                    layoutScale: 1.0,
                    accent: accent,
                    textPrimary: textPrimary,
                    trackInactive: trackInactive,
                    sliderValue: sliderValue,
                    sliderMax: sliderMax,
                    position: position,
                    duration: duration,
                    isPlayerLoading: nowPlaying.isLoading,
                    isShuffleEnabled: nowPlaying.isShuffleEnabled,
                    repeatMode: nowPlaying.repeatMode,
                    onSeek: controller.seek,
                    onToggleShuffle: controller.toggleShuffle,
                    onPrevious: controller.previousTrack,
                    onTogglePlayback: () async {
                      await onTriggerPlaybackFeedback();
                      unawaited(controller.togglePlayback());
                    },
                    onNext: controller.nextTrack,
                    onCycleRepeatMode: controller.cycleRepeatMode,
                    showQueueHandle: false,
                    showPauseIcon: showPauseIcon,
                  );
                },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DesktopPlayerQueuePanel extends StatelessWidget {
  const _DesktopPlayerQueuePanel({
    required this.controller,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onShowQueueSheet,
  });

  final MusixController controller;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Future<void> Function() onShowQueueSheet;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final List<LibrarySong> songs = controller.queueSongs;
        final bool loading = controller.smartQueueLoading;
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0D09).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFF342018)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DesktopPanelTitle(eyebrow: 'QUEUE', title: 'Up next'),
              const SizedBox(height: 14),
              if (loading)
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Loading related songs...',
                      style: GoogleFonts.ibmPlexSans(
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              if (songs.isEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'Queue is empty. Start playback to generate smart suggestions.',
                  style: GoogleFonts.ibmPlexSans(
                    color: textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ] else
                Expanded(
                  child: ListView.separated(
                    itemCount: songs.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final LibrarySong queuedSong = songs[index];
                      final bool active = controller.queueIndex == index;
                      return Material(
                        color: active
                            ? accent.withValues(alpha: 0.14)
                            : const Color(0xFF23100C),
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => controller.jumpToQueue(index),
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
                                        queuedSong.artworkUrl != null &&
                                            queuedSong.artworkUrl!
                                                .trim()
                                                .isNotEmpty
                                        ? _CachedArtworkImage(
                                            imageUrl: queuedSong.artworkUrl!,
                                            dimension: 56,
                                            placeholder:
                                                const _PlayerArtFallback(),
                                            errorWidget:
                                                const _PlayerArtFallback(),
                                          )
                                        : const _PlayerArtFallback(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        queuedSong.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.splineSans(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _songArtistLabel(queuedSong),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.ibmPlexSans(
                                          color: active
                                              ? accent
                                              : textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      controller.removeFromQueue(index),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  color: textSecondary.withValues(alpha: 0.82),
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
      },
    );
  }
}

class _PlayerProgressAndControls extends StatelessWidget {
  const _PlayerProgressAndControls({
    required this.layoutScale,
    required this.accent,
    required this.textPrimary,
    required this.trackInactive,
    required this.sliderValue,
    required this.sliderMax,
    required this.position,
    required this.duration,
    required this.isPlayerLoading,
    required this.isShuffleEnabled,
    required this.repeatMode,
    required this.onSeek,
    required this.onToggleShuffle,
    required this.onPrevious,
    required this.onTogglePlayback,
    required this.onNext,
    required this.onCycleRepeatMode,
    this.onShowQueue,
    this.showQueueHandle = true,
    required this.showPauseIcon,
  });

  final double layoutScale;
  final Color accent;
  final Color textPrimary;
  final Color trackInactive;
  final double sliderValue;
  final double sliderMax;
  final Duration position;
  final Duration duration;
  final bool isPlayerLoading;
  final bool isShuffleEnabled;
  final PlaylistMode repeatMode;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onToggleShuffle;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePlayback;
  final VoidCallback onNext;
  final VoidCallback onCycleRepeatMode;
  final VoidCallback? onShowQueue;
  final bool showQueueHandle;
  final bool showPauseIcon;

  double _scale(double value, {double? min, double? max}) {
    final double scaled = value * layoutScale;
    return scaled.clamp(min ?? double.negativeInfinity, max ?? double.infinity);
  }

  Widget _buildTransportIcon() {
    if (isPlayerLoading) {
      return SizedBox(
        width: _scale(25, min: 20, max: 25),
        height: _scale(25, min: 20, max: 25),
        child: const CircularProgressIndicator(
          strokeWidth: 3.2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Icon(
        showPauseIcon ? Icons.pause_rounded : Icons.play_arrow_rounded,
        key: ValueKey<bool>(showPauseIcon),
        size: showPauseIcon
            ? _scale(36, min: 30, max: 36)
            : _scale(42, min: 34, max: 42),
        color: Colors.black,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isPlayerLoading)
          _PlaybackLoadingBar(
            accent: accent,
            trackColor: trackInactive,
            height: _scale(6, min: 4, max: 6),
          )
        else
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: _scale(6, min: 4, max: 6),
              activeTrackColor: accent,
              inactiveTrackColor: trackInactive,
              thumbColor: accent,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
            ),
            child: Slider(
              value: sliderValue,
              min: 0,
              max: sliderMax,
              onChanged: (double value) {
                onSeek(Duration(milliseconds: value.round()));
              },
            ),
          ),
        SizedBox(height: _scale(10, min: 6, max: 15)),
        Row(
          children: <Widget>[
            Text(
              _formatClock(position),
              style: GoogleFonts.splineSans(
                color: textPrimary.withValues(alpha: 0.86),
                fontSize: _scale(14, min: 12, max: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              _formatClock(duration),
              style: GoogleFonts.splineSans(
                color: textPrimary.withValues(alpha: 0.86),
                fontSize: _scale(14, min: 12, max: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: _scale(22, min: 14, max: 22)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _PlayerIconButton(
              icon: Icons.shuffle_rounded,
              onPressed: onToggleShuffle,
              color: isShuffleEnabled
                  ? accent
                  : textPrimary.withValues(alpha: 0.6),
              size: _scale(28, min: 24, max: 28),
            ),
            _PlayerIconButton(
              icon: Icons.skip_previous_rounded,
              onPressed: onPrevious,
              color: textPrimary,
              size: _scale(34, min: 28, max: 34),
            ),
            GestureDetector(
              onTap: onTogglePlayback,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: _scale(70, min: 58, max: 70),
                height: _scale(70, min: 58, max: 70),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    _scale(24, min: 18, max: 24),
                  ),
                  color: accent,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.38),
                      blurRadius: _scale(28, min: 18, max: 28),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(child: _buildTransportIcon()),
              ),
            ),
            _PlayerIconButton(
              icon: Icons.skip_next_rounded,
              onPressed: onNext,
              color: textPrimary,
              size: _scale(34, min: 28, max: 34),
            ),
            _PlayerIconButton(
              icon: _repeatIcon(repeatMode),
              onPressed: onCycleRepeatMode,
              color: textPrimary.withValues(alpha: 0.6),
              size: _scale(28, min: 24, max: 28),
            ),
          ],
        ),
        if (showQueueHandle && onShowQueue != null) ...<Widget>[
          SizedBox(height: _scale(10, min: 6, max: 20)),
          Center(
            child: IconButton(
              onPressed: onShowQueue,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              color: textPrimary.withValues(alpha: 0.3),
              iconSize: _scale(34, min: 28, max: 34),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlaybackLoadingBar extends StatelessWidget {
  const _PlaybackLoadingBar({
    required this.accent,
    required this.trackColor,
    this.height = 6,
  });

  final Color accent;
  final Color trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LinearProgressIndicator(
          minHeight: height,
          backgroundColor: trackColor,
          valueColor: AlwaysStoppedAnimation<Color>(accent),
        ),
      ),
    );
  }
}

class _PlayerArtFallback extends StatelessWidget {
  const _PlayerArtFallback();

  @override
  Widget build(BuildContext context) {
    return const _ArtworkFallbackSurface(
      colors: <Color>[Color(0xFF43100B), Color(0xFF120607), Color(0xFF070508)],
    );
  }
}

class _PlayerArtInteractionOverlay extends StatelessWidget {
  const _PlayerArtInteractionOverlay({
    required this.tapController,
    required this.likeController,
    required this.showPauseGlyph,
    required this.isLiked,
  });

  final AnimationController tapController;
  final AnimationController likeController;
  final bool showPauseGlyph;
  final bool isLiked;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[tapController, likeController]),
      builder: (BuildContext context, _) {
        final double tapValue = tapController.value;
        final double likeValue = likeController.value;
        final double tapIn = Curves.easeOutCubic.transform(
          (tapValue / 0.55).clamp(0.0, 1.0),
        );
        final double tapOut =
            1 -
            Curves.easeInCubic.transform(
              ((tapValue - 0.45) / 0.55).clamp(0.0, 1.0),
            );
        final double tapOpacity = tapIn * tapOut;
        final double badgeScale =
            0.94 + (0.06 * Curves.easeOutCubic.transform(tapValue));
        final double likeFade =
            1 - Curves.easeInCubic.transform(likeValue.clamp(0.0, 1.0));
        final double veilOpacity = tapValue > 0
            ? 0.14 * tapOpacity.clamp(0.0, 1.0)
            : likeValue > 0
            ? 0.12 * likeFade.clamp(0.0, 1.0)
            : 0;
        final double heartScale =
            TweenSequence<double>(<TweenSequenceItem<double>>[
              TweenSequenceItem<double>(
                tween: Tween<double>(
                  begin: 0.72,
                  end: 1.12,
                ).chain(CurveTween(curve: Curves.easeOutBack)),
                weight: 58,
              ),
              TweenSequenceItem<double>(
                tween: Tween<double>(
                  begin: 1.12,
                  end: 1.0,
                ).chain(CurveTween(curve: Curves.easeOutCubic)),
                weight: 42,
              ),
            ]).transform(likeValue.clamp(0.0, 1.0));

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (veilOpacity > 0)
              Opacity(
                opacity: veilOpacity,
                child: const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFF120907)),
                ),
              ),
            if (tapValue > 0)
              Center(
                child: Opacity(
                  opacity: 0.94 * tapOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: badgeScale,
                    child: Icon(
                      showPauseGlyph
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: const Color(0xFFFFF2E8),
                      size: showPauseGlyph ? 58 : 68,
                      shadows: const <Shadow>[
                        Shadow(
                          color: Color(0xAA000000),
                          blurRadius: 18,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (likeValue > 0)
              Center(
                child: Opacity(
                  opacity: likeFade.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: heartScale,
                    child: Icon(
                      isLiked || likeValue >= 0.16
                          ? Icons.favorite_rounded
                          : Icons.favorite_border,
                      color: Color.lerp(
                        const Color(0xFFFFF4F1),
                        const Color(0xFFFF786A),
                        Curves.easeOutCubic.transform(
                          (likeValue / 0.35).clamp(0.0, 1.0),
                        ),
                      ),
                      size: 70,
                      shadows: const <Shadow>[
                        Shadow(
                          color: Color(0xAA000000),
                          blurRadius: 18,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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

  final MusixController controller;

  @override
  State<_PlayerQueueSheet> createState() => _PlayerQueueSheetState();
}

class _PlayerQueueSheetState extends State<_PlayerQueueSheet> {
  static const int _queueBatchSize = 10;
  static const double _queueItemExtentEstimate = 88;

  final ScrollController _scroll = ScrollController();
  bool _loadingMore = false;
  bool _initialPositioned = false;

  MusixController get controller => widget.controller;

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

  void _centerCurrentQueueSong({bool animated = true}) {
    if (!mounted || !_scroll.hasClients || controller.queueSongs.isEmpty) {
      return;
    }
    final int activeIndex = controller.queueIndex.clamp(
      0,
      controller.queueSongs.length - 1,
    );
    final ScrollPosition position = _scroll.position;
    final double viewport = position.viewportDimension;
    final double rawOffset =
        (activeIndex * _queueItemExtentEstimate) -
        ((viewport - _queueItemExtentEstimate) / 2);
    final double targetOffset = rawOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (animated) {
      unawaited(
        _scroll.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }
    _scroll.jumpTo(targetOffset);
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
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialPositioned) {
        return;
      }
      _centerCurrentQueueSong(animated: false);
      _initialPositioned = true;
    });
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
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
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
          if (loading) ...<Widget>[
            const SizedBox(height: 6),
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
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ReorderableListView.builder(
                    scrollController: _scroll,
                    buildDefaultDragHandles: false,
                    proxyDecorator:
                        (Widget child, int index, Animation<double> animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (BuildContext context, Widget? _) {
                              final double t = Curves.easeOutCubic.transform(
                                animation.value,
                              );
                              return Transform.scale(
                                scale: 1 + (t * 0.02),
                                child: Material(
                                  color: Colors.transparent,
                                  elevation: 12 * t,
                                  borderRadius: BorderRadius.circular(22),
                                  child: child,
                                ),
                              );
                            },
                          );
                        },
                    onReorderStart: (int index) {
                      HapticFeedback.selectionClick();
                    },
                    onReorderEnd: (int index) {
                      HapticFeedback.selectionClick();
                    },
                    onReorder: (int oldIndex, int newIndex) async {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      await HapticFeedback.selectionClick();
                      await controller.reorderQueue(oldIndex, newIndex);
                    },
                    itemCount: songs.length,
                    itemBuilder: (BuildContext context, int index) {
                      final LibrarySong song = songs[index];
                      final bool active = controller.queueIndex == index;

                      return Padding(
                        key: ValueKey<String>('queue-${song.id}-$index'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Dismissible(
                          key: ValueKey<String>('queue-dismiss-${song.id}'),
                          direction: DismissDirection.endToStart,
                          background: _SwipeActionBackground(
                            alignment: Alignment.centerRight,
                            color: const Color(0xFF5A1613),
                            icon: Icons.delete_outline_rounded,
                            label: 'Remove',
                          ),
                          confirmDismiss: (DismissDirection direction) async {
                            await HapticFeedback.mediumImpact();
                            return true;
                          },
                          onDismissed: (DismissDirection direction) async {
                            final int queueIndex = controller.queueSongs
                                .indexWhere((LibrarySong item) {
                                  return item.id == song.id;
                                });
                            if (queueIndex < 0) {
                              return;
                            }
                            await controller.removeFromQueue(queueIndex);
                            if (context.mounted) {
                              _showMusixSnackBar(
                                context,
                                'Removed from queue',
                              );
                            }
                          },
                          child: Material(
                            color: active
                                ? accent.withValues(alpha: 0.14)
                                : tile,
                            borderRadius: BorderRadius.circular(22),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () async {
                                unawaited(HapticFeedback.selectionClick());
                                await controller.jumpToQueue(index);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SizedBox(
                                        width: 56,
                                        height: 56,
                                        child:
                                            song.artworkUrl != null &&
                                                song.artworkUrl!
                                                    .trim()
                                                    .isNotEmpty
                                            ? _CachedArtworkImage(
                                                imageUrl: song.artworkUrl!,
                                                dimension: 56,
                                                errorWidget:
                                                    const _PlayerArtFallback(),
                                                placeholder:
                                                    const _PlayerArtFallback(),
                                              )
                                            : const _PlayerArtFallback(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                              color: active
                                                  ? accent
                                                  : textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ReorderableDelayedDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 10,
                                        ),
                                        child: Icon(
                                          Icons.drag_handle_rounded,
                                          color: textSecondary.withValues(
                                            alpha: 0.84,
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _AlbumScreen extends StatelessWidget {
  const _AlbumScreen({required this.controller, required this.album});

  final MusixController controller;
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
      body: ListView.builder(
        padding: _kScreenContentPadding,
        itemCount: album.songs.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
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
                        Text('${album.artist} Ã¢â‚¬Â¢ ${album.songCount} tracks'),
                        const SizedBox(height: 8),
                        Text(_formatDuration(album.totalDuration)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final int songIndex = index - 1;
          return _SongTile(
            song: album.songs[songIndex],
            controller: controller,
            onTap: () => controller.playAlbum(album, startIndex: songIndex),
          );
        },
      ),
    );
  }
}

// ignore: unused_element
class _ArtistScreen extends StatelessWidget {
  const _ArtistScreen({required this.controller, required this.artist});

  final MusixController controller;
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
      body: ListView.builder(
        padding: _kScreenContentPadding,
        itemCount: artist.songs.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
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
                      '${artist.songs.length} tracks Ã¢â‚¬Â¢ ${artist.albumCount} albums',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            );
          }

          return _SongTile(
            song: artist.songs[index - 1],
            controller: controller,
          );
        },
      ),
    );
  }
}

// ignore: unused_element
class _FolderScreen extends StatelessWidget {
  const _FolderScreen({required this.controller, required this.folder});

  final MusixController controller;
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
      body: ListView.builder(
        padding: _kScreenContentPadding,
        itemCount: folder.songs.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                folder.path,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          return _SongTile(
            song: folder.songs[index - 1],
            controller: controller,
          );
        },
      ),
    );
  }
}

// ignore: unused_element
class _PlaylistScreen extends StatelessWidget {
  const _PlaylistScreen({
    required this.controller,
    required this.title,
    required this.songs,
    required this.playlist,
  });

  final MusixController controller;
  final String title;
  final List<LibrarySong> songs;
  final UserPlaylist? playlist;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
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
      body: ListView.builder(
        padding: _kScreenContentPadding,
        itemCount: songs.length,
        itemBuilder: (BuildContext context, int index) {
          return _SongTile(
            song: songs[index],
            controller: controller,
            extraPlaylistId: playlist?.id,
          );
        },
      ),
    );
  }
}

class _MusixCollectionSummary extends StatelessWidget {
  const _MusixCollectionSummary({
    required this.leading,
    required this.title,
    required this.lines,
  });

  final Widget leading;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final List<String> visibleLines = lines
        .where((String line) => line.trim().isNotEmpty)
        .toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _kSurfaceEdge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          leading,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.splineSans(
                    color: _kTextPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 0.96,
                  ),
                ),
                const SizedBox(height: 10),
                ...visibleLines.map(
                  (String line) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.splineSans(
                        color: _kTextSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MusixAlbumScreen extends StatelessWidget {
  const _MusixAlbumScreen({required this.controller, required this.album});

  final MusixController controller;
  final AlbumCollection album;

  @override
  Widget build(BuildContext context) {
    return _MusixSubscreenScaffold(
      title: album.title,
      actions: <Widget>[
        IconButton(
          onPressed: () => controller.playAlbum(album),
          icon: const Icon(Icons.play_arrow_rounded, color: _kAccent),
        ),
      ],
      child: Column(
        children: <Widget>[
          _MusixCollectionSummary(
            leading: _Artwork(seed: album.id, title: album.title, size: 120),
            title: album.title,
            lines: <String>[
              '${album.artist} Ã¢â‚¬Â¢ ${album.songCount} tracks',
              _formatDuration(album.totalDuration),
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

class _MusixArtistScreen extends StatelessWidget {
  const _MusixArtistScreen({required this.controller, required this.artist});

  final MusixController controller;
  final ArtistCollection artist;

  @override
  Widget build(BuildContext context) {
    return _MusixSubscreenScaffold(
      title: artist.name,
      actions: <Widget>[
        IconButton(
          onPressed: () => controller.playArtist(artist),
          icon: const Icon(Icons.play_arrow_rounded, color: _kAccent),
        ),
      ],
      child: Column(
        children: <Widget>[
          _MusixCollectionSummary(
            leading: _ResolvedArtistAvatar(
              controller: controller,
              artistName: artist.name,
              seed: artist.id,
              size: 120,
            ),
            title: artist.name,
            lines: <String>[
              '${artist.songs.length} tracks Ã¢â‚¬Â¢ ${artist.albumCount} albums',
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

class _MusixFolderScreen extends StatelessWidget {
  const _MusixFolderScreen({required this.controller, required this.folder});

  final MusixController controller;
  final FolderCollection folder;

  @override
  Widget build(BuildContext context) {
    return _MusixSubscreenScaffold(
      title: folder.name,
      actions: <Widget>[
        IconButton(
          onPressed: () => controller.playFolder(folder),
          icon: const Icon(Icons.play_arrow_rounded, color: _kAccent),
        ),
      ],
      child: Column(
        children: <Widget>[
          _MusixCollectionSummary(
            leading: _Artwork(
              seed: folder.id,
              title: folder.name,
              size: 120,
              icon: Icons.folder_rounded,
            ),
            title: folder.name,
            lines: <String>[folder.path, '${folder.songs.length} tracks'],
          ),
          const SizedBox(height: 20),
          ...folder.songs.map(
            (LibrarySong song) => _SongTile(song: song, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _MusixPlaylistScreen extends StatefulWidget {
  const _MusixPlaylistScreen({
    required this.controller,
    required this.title,
    required this.songs,
    this.playlist,
    this.localPlaybackOnly = false,
  });

  final MusixController controller;
  final String title;
  final List<LibrarySong> songs;
  final UserPlaylist? playlist;
  final bool localPlaybackOnly;

  @override
  State<_MusixPlaylistScreen> createState() => _MusixPlaylistScreenState();
}

class _MusixPlaylistScreenState extends State<_MusixPlaylistScreen> {
  final Set<String> _selectedSongIds = <String>{};

  bool get _selectionMode => _selectedSongIds.isNotEmpty;

  Future<void> _playSongFromList(
    List<LibrarySong> songs,
    LibrarySong tappedSong,
    String label,
  ) async {
    if (widget.localPlaybackOnly) {
      if (tappedSong.isRemote) {
        return;
      }
      final List<LibrarySong> localSongs = songs
          .where((LibrarySong item) => !item.isRemote)
          .toList(growable: false);
      final int startIndex = localSongs.indexWhere(
        (LibrarySong item) => item.id == tappedSong.id,
      );
      if (startIndex >= 0) {
        await widget.controller.playSongs(
          localSongs,
          startIndex: startIndex,
          label: label,
        );
      }
      return;
    }

    final int startIndex = songs.indexWhere(
      (LibrarySong item) => item.id == tappedSong.id,
    );
    if (startIndex >= 0) {
      await widget.controller.playSongs(
        songs,
        startIndex: startIndex,
        label: label,
      );
    }
  }

  void _toggleSongSelection(String songId) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      if (!_selectedSongIds.add(songId)) {
        _selectedSongIds.remove(songId);
      }
    });
  }

  Future<void> _enqueueSelected() async {
    final List<LibrarySong> selectedSongs =
        (widget.playlist != null
                ? widget.controller.songsForPlaylist(widget.playlist!)
                : widget.songs)
            .where((LibrarySong song) => _selectedSongIds.contains(song.id))
            .toList(growable: false);
    if (selectedSongs.isEmpty) {
      return;
    }
    await HapticFeedback.mediumImpact();
    for (final LibrarySong song in selectedSongs) {
      await widget.controller.enqueueSong(song);
    }
    if (!mounted) {
      return;
    }
    _showMusixSnackBar(
      context,
      '${selectedSongs.length} song${selectedSongs.length == 1 ? '' : 's'} added to queue',
    );
    setState(_selectedSongIds.clear);
  }

  Future<void> _removeSelectedFromPlaylist() async {
    final UserPlaylist? playlist = widget.playlist;
    if (playlist == null || _selectedSongIds.isEmpty) {
      return;
    }
    final List<String> songIds = _selectedSongIds.toList(growable: false);
    await HapticFeedback.mediumImpact();
    for (final String songId in songIds) {
      await widget.controller.removeSongFromPlaylist(playlist.id, songId);
    }
    if (!mounted) {
      return;
    }
    _showMusixSnackBar(
      context,
      '${songIds.length} song${songIds.length == 1 ? '' : 's'} removed from playlist',
    );
    setState(_selectedSongIds.clear);
  }

  @override
  Widget build(BuildContext context) {
    final UserPlaylist? playlist = widget.playlist;
    final String title = widget.title;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final List<LibrarySong> songs = playlist != null
            ? widget.controller.songsForPlaylist(playlist)
            : widget.songs;
        _selectedSongIds.removeWhere((String id) {
          return songs.every((LibrarySong song) => song.id != id);
        });

        return _MusixSubscreenScaffold(
          title: _selectionMode ? '${_selectedSongIds.length} Selected' : title,
          actions: <Widget>[
            if (_selectionMode) ...<Widget>[
              IconButton(
                onPressed: _enqueueSelected,
                icon: const Icon(Icons.queue_music_rounded, color: _kAccent),
              ),
              if (playlist != null)
                IconButton(
                  onPressed: _removeSelectedFromPlaylist,
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    color: _kTextSecondary,
                  ),
                ),
              IconButton(
                onPressed: () => setState(_selectedSongIds.clear),
                icon: const Icon(Icons.close_rounded, color: _kTextSecondary),
              ),
            ] else ...<Widget>[
              if (playlist != null)
                IconButton(
                  onPressed: () async {
                    await widget.controller.deletePlaylist(playlist.id);
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: _kTextSecondary,
                  ),
                ),
            ],
          ],
          child: Column(
            children: <Widget>[
              _MusixCollectionSummary(
                leading: songs.isNotEmpty
                    ? _Artwork(
                        seed: playlist?.id ?? title,
                        title: title,
                        size: 120,
                        imageUrl: songs.first.artworkUrl,
                      )
                    : _Artwork(
                        seed: playlist?.id ?? title,
                        title: title,
                        size: 120,
                        icon: Icons.queue_music_rounded,
                      ),
                title: title,
                lines: <String>[
                  '${songs.length} tracks',
                  if (playlist != null) 'Saved playlist',
                ],
              ),
              const SizedBox(height: 20),
              ...songs.map(
                (LibrarySong song) => _SongTile(
                  song: song,
                  controller: widget.controller,
                  extraPlaylistId: playlist?.id,
                  selectionMode: _selectionMode,
                  selected: _selectedSongIds.contains(song.id),
                  onLongPress: () => _toggleSongSelection(song.id),
                  onTap: _selectionMode
                      ? () => _toggleSongSelection(song.id)
                      : () => _playSongFromList(songs, song, title),
                  enableQueueSwipe: !_selectionMode,
                  enablePlaylistRemovalSwipe: !_selectionMode,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeFeedSkeleton extends StatelessWidget {
  const _HomeFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const <Widget>[
        _MusixSectionHeaderSkeleton(),
        SizedBox(height: 8),
        _MusixListSkeleton(count: 4),
        SizedBox(height: 22),
        _MusixSectionHeaderSkeleton(),
        SizedBox(height: 8),
        _MusixListSkeleton(count: 4),
      ],
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
  const _LibraryHeader();

  @override
  Widget build(BuildContext context) {
    return const _HomeStyleHeader(
      title: 'LIBRARY',
      leading: _HomeStyleProfileBadge(),
      trailing: _HomeStyleNotificationIcon(),
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

class _LibraryBlockedCard extends StatelessWidget {
  const _LibraryBlockedCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 164,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: <Color>[const Color(0xFF29120D), const Color(0xFF1A0A08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                color: const Color(0xFFFF8A2A).withValues(alpha: 0.16),
              ),
              child: Icon(icon, color: const Color(0xFFFFC79F), size: 24),
            ),
          ),
          Positioned(
            right: -18,
            top: -10,
            child: Icon(
              Icons.lock_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.05),
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
                    color: const Color(0xFFF6E3D2),
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    height: 0.98,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.splineSans(
                    color: const Color(0xFFD6B099),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          TextButton(
            onPressed: onCreate,
            style: TextButton.styleFrom(foregroundColor: _kAccent),
            child: Text(
              'Create',
              style: GoogleFonts.splineSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryPlaylistRow extends StatelessWidget {
  const _LibraryPlaylistRow({
    required this.controller,
    required this.title,
    required this.seed,
    required this.songs,
    this.playlist,
    this.subtitle,
    this.forceEnabled = false,
  });

  final MusixController controller;
  final String title;
  final String seed;
  final List<LibrarySong> songs;
  final UserPlaylist? playlist;
  final String? subtitle;
  final bool forceEnabled;

  @override
  Widget build(BuildContext context) {
    final LibrarySong? leadSong = songs.isEmpty ? null : songs.first;
    final bool blocked = controller.isOffline && !forceEnabled;

    return InkWell(
      onTap: blocked
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => _MusixPlaylistScreen(
                    controller: controller,
                    title: title,
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
                      seed: seed,
                      title: title,
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
                  title,
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
                  subtitle ?? 'Playlist - ${songs.length} Tracks',
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
            blocked ? Icons.cloud_off_rounded : Icons.chevron_right_rounded,
            color: blocked ? const Color(0xFFFF9B54) : const Color(0xFF7E4B2B),
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.splineSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
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
    this.selectionMode = false,
    this.selected = false,
    this.onLongPress,
    this.enableQueueSwipe = true,
    this.enablePlaylistRemovalSwipe = true,
  });

  final LibrarySong song;
  final MusixController controller;
  final VoidCallback? onTap;
  final String? extraPlaylistId;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onLongPress;
  final bool enableQueueSwipe;
  final bool enablePlaylistRemovalSwipe;

  @override
  Widget build(BuildContext context) {
    final bool active = controller.currentSong?.id == song.id;
    final List<PopupMenuEntry<String>> menuItems = <PopupMenuEntry<String>>[
      if (!song.isRemote)
        _musixPopupMenuItem(
          'favorite',
          song.isFavorite ? 'Unfavorite' : 'Favorite',
        ),
      _musixPopupMenuItem('enqueue', 'Add to queue'),
      if (!song.isRemote) _musixPopupMenuItem('playlist', 'Add to playlist'),
      if (extraPlaylistId != null)
        _musixPopupMenuItem('remove_playlist', 'Remove from playlist'),
    ];
    final VoidCallback resolvedTap =
        onTap ??
        () {
          if (song.isRemote) {
            controller.playOnlineSong(song);
          } else {
            controller.playSong(song, label: song.sourceLabel);
          }
        };

    final Widget tile = RepaintBoundary(
      child: Material(
        color: selected
            ? _kAccent.withValues(alpha: 0.22)
            : active
            ? _kAccent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          dense: controller.settings.denseLibrary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              _Artwork(
                seed: song.id,
                title: song.title,
                size: 52,
                imageUrl: song.artworkUrl,
              ),
              if (selectionMode)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: selected ? 0.16 : 0.28,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? _kAccent : Colors.white70,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _kTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            _songArtistLabel(song),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _kTextSecondary.withValues(alpha: 0.88),
            ),
          ),
          selected: active || selected,
          onTap: resolvedTap,
          onLongPress: onLongPress,
          trailing: selectionMode
              ? Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? _kAccent : _kTextSecondary,
                )
              : PopupMenuButton<String>(
                  color: _kSurface,
                  iconColor: _kTextSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: _kSurfaceEdge),
                  ),
                  onSelected: (String value) {
                    switch (value) {
                      case 'favorite':
                        controller.toggleFavorite(song.id);
                      case 'enqueue':
                        controller.enqueueSong(song);
                      case 'playlist':
                        _showAddToPlaylistDialog(context, controller, song);
                      case 'remove_playlist':
                        if (extraPlaylistId != null) {
                          controller.removeSongFromPlaylist(
                            extraPlaylistId!,
                            song.id,
                          );
                        }
                    }
                  },
                  itemBuilder: (BuildContext context) => menuItems,
                ),
        ),
      ),
    );

    final bool canRemoveFromPlaylist =
        !selectionMode &&
        enablePlaylistRemovalSwipe &&
        extraPlaylistId != null &&
        extraPlaylistId!.trim().isNotEmpty;
    final bool canAddToQueue = !selectionMode && enableQueueSwipe;
    if (!canRemoveFromPlaylist && !canAddToQueue) {
      return tile;
    }

    final DismissDirection direction = canRemoveFromPlaylist
        ? DismissDirection.horizontal
        : DismissDirection.startToEnd;

    return Dismissible(
      key: ValueKey<String>(
        'song-tile-${extraPlaylistId ?? song.sourceLabel}-${song.id}',
      ),
      direction: direction,
      background: canAddToQueue
          ? const _SwipeActionBackground(
              alignment: Alignment.centerLeft,
              color: Color(0xFF18432B),
              icon: Icons.queue_music_rounded,
              label: 'Queue',
            )
          : null,
      secondaryBackground: canRemoveFromPlaylist
          ? const _SwipeActionBackground(
              alignment: Alignment.centerRight,
              color: Color(0xFF5A1613),
              icon: Icons.remove_circle_outline_rounded,
              label: 'Remove',
            )
          : null,
      confirmDismiss: (DismissDirection dismissedDirection) async {
        final bool swipedRight =
            dismissedDirection == DismissDirection.startToEnd;
        if (swipedRight && canAddToQueue) {
          await HapticFeedback.selectionClick();
          await controller.enqueueSong(song);
          if (context.mounted) {
            _showMusixSnackBar(context, 'Added to queue');
          }
          return false;
        }
        if (!swipedRight && canRemoveFromPlaylist && extraPlaylistId != null) {
          await HapticFeedback.mediumImpact();
          return true;
        }
        return false;
      },
      onDismissed: (DismissDirection dismissedDirection) async {
        if (dismissedDirection == DismissDirection.endToStart &&
            canRemoveFromPlaylist &&
            extraPlaylistId != null) {
          await controller.removeSongFromPlaylist(extraPlaylistId!, song.id);
          if (context.mounted) {
            _showMusixSnackBar(context, 'Removed from playlist');
          }
        }
      },
      child: tile,
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

  final MusixController controller;
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
            subtitle: '${album.artist} Ã¢â‚¬Â¢ ${album.songCount} tracks',
            seed: album.id,
            icon: Icons.album_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      _MusixAlbumScreen(controller: controller, album: album),
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

  final MusixController controller;
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
                '${artist.songs.length} tracks Ã¢â‚¬Â¢ ${artist.albumCount} albums',
            seed: artist.id,
            icon: Icons.person_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => _MusixArtistScreen(
                    controller: controller,
                    artist: artist,
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
class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder, required this.controller});

  final FolderCollection folder;
  final MusixController controller;

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
                _MusixFolderScreen(controller: controller, folder: folder),
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _PlaylistGrid extends StatelessWidget {
  const _PlaylistGrid({required this.controller});

  final MusixController controller;

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
        title: 'Disliked Songs',
        subtitle: '${controller.dislikedSongs.length} disliked tracks',
        seed: 'disliked_songs',
        songs: controller.dislikedSongs,
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
                  builder: (BuildContext context) => _MusixPlaylistScreen(
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

  static const double _kMiniPlayerExpandVelocity = 360;

  final MusixController controller;
  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NowPlayingState>(
      valueListenable: controller.nowPlayingState,
      builder: (BuildContext context, NowPlayingState nowPlaying, Widget? child) {
        final LibrarySong? song = nowPlaying.song;
        if (song == null) {
          return const SizedBox.shrink();
        }

        const Color shell = Color(0xFF100502);
        const Color card = Color(0xFF2A1209);
        const Color cardEdge = Color(0xFF402016);
        const Color accent = Color(0xFFFF7F17);
        const Color inactive = Color(0xFFEEDDCF);
        const Color track = Color(0xFF4D2A1D);

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await HapticFeedback.selectionClick();
                onOpenPlayer();
              },
              onVerticalDragEnd: (DragEndDetails details) async {
                if (details.velocity.pixelsPerSecond.dy <
                    -_kMiniPlayerExpandVelocity) {
                  await HapticFeedback.selectionClick();
                  onOpenPlayer();
                }
              },
              child: Material(
                color: Colors.transparent,
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
                              ? _CachedArtworkImage(
                                  imageUrl: song.artworkUrl!,
                                  dimension: 50,
                                  placeholder: const _MiniArtworkFallback(),
                                  errorWidget: const _MiniArtworkFallback(),
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

                            return ValueListenableBuilder<
                              PlaybackProgressState
                            >(
                              valueListenable: controller.playbackProgressState,
                              builder:
                                  (
                                    BuildContext context,
                                    PlaybackProgressState progressState,
                                    Widget? child,
                                  ) {
                                    final bool isMiniLoading =
                                        nowPlaying.isLoading;
                                    final Duration position = isMiniLoading
                                        ? Duration.zero
                                        : progressState.position;
                                    final Duration duration =
                                        progressState.duration == Duration.zero
                                        ? song.duration
                                        : progressState.duration;
                                    final double progress =
                                        duration.inMilliseconds <= 0
                                        ? 0
                                        : position.inMilliseconds /
                                              duration.inMilliseconds;
                                    final double safeProgress =
                                        progress.isFinite
                                        ? progress.clamp(0.0, 1.0)
                                        : 0.0;
                                    final bool showPauseIcon =
                                        progressState.isPlaying &&
                                        !isMiniLoading;

                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: <Widget>[
                                                  _MiniPlayerIcon(
                                                    icon: Icons.shuffle_rounded,
                                                    color:
                                                        nowPlaying
                                                            .isShuffleEnabled
                                                        ? accent
                                                        : inactive.withValues(
                                                            alpha: 0.6,
                                                          ),
                                                    onPressed: controller
                                                        .toggleShuffle,
                                                    compact: compact,
                                                  ),
                                                  _MiniPlayerIcon(
                                                    icon: Icons
                                                        .skip_previous_rounded,
                                                    color: inactive,
                                                    onPressed: controller
                                                        .previousTrack,
                                                    compact: compact,
                                                  ),
                                                  GestureDetector(
                                                    onTap: controller
                                                        .togglePlayback,
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 180,
                                                      ),
                                                      curve:
                                                          Curves.easeOutCubic,
                                                      width: playButtonSize,
                                                      height: playButtonSize,
                                                      decoration:
                                                          const BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            color: accent,
                                                          ),
                                                      child: Center(
                                                        child: isMiniLoading
                                                            ? SizedBox(
                                                                width: compact
                                                                    ? 18
                                                                    : 20,
                                                                height: compact
                                                                    ? 18
                                                                    : 20,
                                                                child: const CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2.5,
                                                                  valueColor:
                                                                      AlwaysStoppedAnimation<
                                                                        Color
                                                                      >(
                                                                        Colors
                                                                            .black,
                                                                      ),
                                                                ),
                                                              )
                                                            : AnimatedSwitcher(
                                                                duration:
                                                                    const Duration(
                                                                      milliseconds:
                                                                          180,
                                                                    ),
                                                                switchInCurve:
                                                                    Curves
                                                                        .easeOutCubic,
                                                                switchOutCurve:
                                                                    Curves
                                                                        .easeInCubic,
                                                                transitionBuilder:
                                                                    (
                                                                      Widget
                                                                      child,
                                                                      Animation<
                                                                        double
                                                                      >
                                                                      animation,
                                                                    ) {
                                                                      return FadeTransition(
                                                                        opacity:
                                                                            animation,
                                                                        child: ScaleTransition(
                                                                          scale:
                                                                              animation,
                                                                          child:
                                                                              child,
                                                                        ),
                                                                      );
                                                                    },
                                                                child: Icon(
                                                                  showPauseIcon
                                                                      ? Icons
                                                                            .pause_rounded
                                                                      : Icons
                                                                            .play_arrow_rounded,
                                                                  key:
                                                                      ValueKey<
                                                                        bool
                                                                      >(
                                                                        showPauseIcon,
                                                                      ),
                                                                  color: Colors
                                                                      .black,
                                                                  size: compact
                                                                      ? 22
                                                                      : showPauseIcon
                                                                      ? 24
                                                                      : 28,
                                                                ),
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                  _MiniPlayerIcon(
                                                    icon:
                                                        Icons.skip_next_rounded,
                                                    color: inactive,
                                                    onPressed:
                                                        controller.nextTrack,
                                                    compact: compact,
                                                  ),
                                                  _MiniPlayerIcon(
                                                    icon: _repeatIcon(
                                                      nowPlaying.repeatMode,
                                                    ),
                                                    color: inactive.withValues(
                                                      alpha: 0.6,
                                                    ),
                                                    onPressed: controller
                                                        .cycleRepeatMode,
                                                    compact: compact,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (isMiniLoading)
                                          const _PlaybackLoadingBar(
                                            accent: accent,
                                            trackColor: track,
                                            height: 5,
                                          )
                                        else
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            child: SizedBox(
                                              height: 5,
                                              width: double.infinity,
                                              child: ColoredBox(
                                                color: track,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: FractionallySizedBox(
                                                    widthFactor: safeProgress,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: const SizedBox.expand(
                                                      child: ColoredBox(
                                                        color: accent,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    return const _ArtworkFallbackSurface(
      colors: <Color>[Color(0xFF1F8E96), Color(0xFF23516E)],
    );
  }
}

class _ArtworkFallbackSurface extends StatelessWidget {
  const _ArtworkFallbackSurface({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            right: -12,
            top: -10,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            left: -10,
            bottom: -12,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.12),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CachedArtworkImage extends StatelessWidget {
  const _CachedArtworkImage({
    required this.imageUrl,
    this.dimension,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final double? dimension;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final int? cacheDimension = dimension == null
        ? null
        : (dimension! * devicePixelRatio).round();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      memCacheWidth: cacheDimension,
      memCacheHeight: cacheDimension,
      filterQuality: FilterQuality.medium,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (BuildContext context, String url) =>
          placeholder ?? const SizedBox.shrink(),
      errorWidget: (BuildContext context, String url, Object error) =>
          errorWidget ?? placeholder ?? const SizedBox.shrink(),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.seed,
    required this.title,
    required this.size,
    this.icon,
    this.imageUrl,
  });

  final String seed;
  final String title;
  final double size;
  final IconData? icon;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors = _gradientFor(seed, scheme);
    final bool hasArtwork = imageUrl != null && imageUrl!.trim().isNotEmpty;

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
          if (hasArtwork)
            Positioned.fill(
              child: _CachedArtworkImage(imageUrl: imageUrl!, dimension: size),
            ),
          if (!hasArtwork) _ArtworkFallbackSurface(colors: colors),
          if (!hasArtwork && icon != null)
            Align(
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: size * 0.34,
                color: Colors.white.withValues(alpha: 0.82),
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
            _CachedArtworkImage(imageUrl: imageUrl!, dimension: size),
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

  final MusixController controller;
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
