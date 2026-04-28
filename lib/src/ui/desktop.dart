part of '../ui.dart';

bool _isDesktopPlatform() {
  if (kIsWeb) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
  };
}

class _DesktopShellScaffold extends StatelessWidget {
  const _DesktopShellScaffold({
    required this.controller,
    required this.destination,
    required this.destinations,
    required this.pageIndex,
    required this.children,
    required this.onDestinationChanged,
    required this.onOpenPlayer,
  });

  final MusixController controller;
  final AppDestination destination;
  final List<AppDestination> destinations;
  final int pageIndex;
  final List<Widget> children;
  final ValueChanged<AppDestination> onDestinationChanged;
  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool showPlayerRail =
            controller.nowPlayingState.value.song != null;
        final bool compactSidebar = constraints.maxWidth < 1100;
        final bool windowsDesktop =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
        final double playerRailWidth = constraints.maxWidth >= 1500 ? 360 : 320;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0403),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[_kPageTop, _kPageMiddle, _kPageBottom],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                child: Column(
                  children: <Widget>[
                    if (windowsDesktop) ...<Widget>[
                      const _DesktopWindowTitleBar(),
                      const SizedBox(height: 12),
                    ],
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _DesktopSidebar(
                            controller: controller,
                            destination: destination,
                            destinations: destinations,
                            compact: compactSidebar,
                            onDestinationChanged: onDestinationChanged,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF140805,
                                ).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: const Color(
                                    0xFF3A1C11,
                                  ).withValues(alpha: 0.9),
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.14),
                                    blurRadius: 24,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: IndexedStack(
                                  index: pageIndex,
                                  children: children,
                                ),
                              ),
                            ),
                          ),
                          if (showPlayerRail) ...<Widget>[
                            const SizedBox(width: 18),
                            SizedBox(
                              width: playerRailWidth,
                              child: _DesktopNowPlayingRail(
                                controller: controller,
                                onOpenPlayer: onOpenPlayer,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopWindowTitleBar extends StatefulWidget {
  const _DesktopWindowTitleBar();

  @override
  State<_DesktopWindowTitleBar> createState() => _DesktopWindowTitleBarState();
}

class _DesktopWindowTitleBarState extends State<_DesktopWindowTitleBar>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_syncMaximizedState());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximizedState() async {
    final bool maximized = await windowManager.isMaximized();
    if (!mounted) {
      return;
    }
    setState(() => _isMaximized = maximized);
  }

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _syncMaximizedState();
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _isMaximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _isMaximized = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onDoubleTap: _toggleMaximize,
              child: DragToMoveArea(
                child: Container(
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF130806).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3A1C11)),
                  ),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.asset(
                          'assets/icons/Musix - Windows.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Musix',
                        style: GoogleFonts.spaceGrotesk(
                          color: _kTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _DesktopTitleBarActionButton(
            icon: Icons.minimize_rounded,
            onTap: () => unawaited(windowManager.minimize()),
            iconOffset: const Offset(0, -5),
          ),
          const SizedBox(width: 10),
          _DesktopTitleBarActionButton(
            icon: _isMaximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            onTap: _toggleMaximize,
          ),
          const SizedBox(width: 10),
          _DesktopTitleBarActionButton(
            icon: Icons.close_rounded,
            onTap: () => windowManager.close(),
            hoverColor: const Color.fromARGB(255, 121, 27, 0),
          ),
        ],
      ),
    );
  }
}

class _DesktopTitleBarActionButton extends StatefulWidget {
  const _DesktopTitleBarActionButton({
    required this.icon,
    required this.onTap,
    this.hoverColor = const Color(0xFF3A1B10),
    this.iconOffset = Offset.zero,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color hoverColor;
  final Offset iconOffset;

  @override
  State<_DesktopTitleBarActionButton> createState() =>
      _DesktopTitleBarActionButtonState();
}

class _DesktopTitleBarActionButtonState
    extends State<_DesktopTitleBarActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 52,
          height: 44,
          decoration: BoxDecoration(
            color: _hovering ? widget.hoverColor : const Color(0xFF2B130C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering
                  ? const Color(0xFF6A341D)
                  : const Color(0xFF4A2416),
            ),
          ),
          child: Center(
            child: Transform.translate(
              offset: widget.iconOffset,
              child: Icon(
                widget.icon,
                color: _hovering
                    ? const Color(0xFFD7D0CA)
                    : const Color(0xFFAAA39D),
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.controller,
    required this.destination,
    required this.destinations,
    required this.compact,
    required this.onDestinationChanged,
  });

  final MusixController controller;
  final AppDestination destination;
  final List<AppDestination> destinations;
  final bool compact;
  final ValueChanged<AppDestination> onDestinationChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: compact ? 92 : 232,
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 18,
        18,
        compact ? 14 : 18,
        18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF130806).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color(0xFF3A1C11).withValues(alpha: 0.92),
        ),
      ),
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: compact ? 54 : double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 0 : 16,
              vertical: compact ? 14 : 16,
            ),

            child: compact
                ? const Icon(
                    Icons.graphic_eq_rounded,
                    color: Color(0xFFFF9A46),
                    size: 24,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[],
                  ),
          ),
          for (int index = 0; index < destinations.length; index++) ...<Widget>[
            _DesktopSidebarButton(
              item: destinations[index],
              selected: destination == destinations[index],
              compact: compact,
              onTap: () => onDestinationChanged(destinations[index]),
            ),
            const SizedBox(height: 10),
          ],
          const Spacer(),
          if (!compact) _DesktopSidebarStatus(controller: controller),
        ],
      ),
    );
  }
}

class _DesktopSidebarButton extends StatefulWidget {
  const _DesktopSidebarButton({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final AppDestination item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_DesktopSidebarButton> createState() => _DesktopSidebarButtonState();
}

class _DesktopSidebarButtonState extends State<_DesktopSidebarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bool highlighted = widget.selected || _hovering;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: widget.selected
              ? const Color(0xFF3A1B0F)
              : highlighted
              ? const Color(0xFF1D0D09)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: widget.selected
                ? const Color(0xFF8A4A22)
                : const Color(0xFF2B140D),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: widget.onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 0 : 14,
              vertical: 12,
            ),
            child: widget.compact
                ? Icon(
                    widget.selected
                        ? widget.item.selectedIcon
                        : widget.item.unselectedIcon,
                    color: widget.selected
                        ? const Color(0xFFFF9A46)
                        : _kTextSecondary,
                  )
                : Row(
                    children: <Widget>[
                      Icon(
                        widget.selected
                            ? widget.item.selectedIcon
                            : widget.item.unselectedIcon,
                        color: widget.selected
                            ? const Color(0xFFFF9A46)
                            : _kTextSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.item.label,
                          style: GoogleFonts.splineSans(
                            color: widget.selected
                                ? _kTextPrimary
                                : _kTextSecondary.withValues(alpha: 0.92),
                            fontWeight: widget.selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
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

class _DesktopSidebarStatus extends StatelessWidget {
  const _DesktopSidebarStatus({required this.controller});

  final MusixController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C0E0A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF342018)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            controller.isOfflineViewActive
                ? Icons.cloud_off_rounded
                : controller.scanning
                ? Icons.sync_rounded
                : Icons.library_music_rounded,
            size: 18,
            color: const Color(0xFFFF9A46),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              controller.isOfflineViewActive
                  ? 'Offline mode'
                  : controller.scanning
                  ? 'Scanning library'
                  : 'Library ready',
              style: GoogleFonts.ibmPlexSans(
                color: _kTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopPageScrollView extends StatelessWidget {
  const _DesktopPageScrollView({required this.child, this.controller});

  final Widget child;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: <Widget>[child],
      ),
    );
  }
}

class _DesktopPanel extends StatelessWidget {
  const _DesktopPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1C0E0A).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF342018)),
      ),
      child: child,
    );
  }
}

class _DesktopPanelTitle extends StatelessWidget {
  const _DesktopPanelTitle({
    required this.eyebrow,
    required this.title,
    this.action,
  });

  final String eyebrow;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                eyebrow,
                style: GoogleFonts.ibmPlexSans(
                  color: _kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  color: _kTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...<Widget>[const SizedBox(width: 12), action!],
      ],
    );
  }
}

class _DesktopNowPlayingRail extends StatelessWidget {
  const _DesktopNowPlayingRail({
    required this.controller,
    required this.onOpenPlayer,
  });

  final MusixController controller;
  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NowPlayingState>(
      valueListenable: controller.nowPlayingState,
      builder: (BuildContext context, NowPlayingState nowPlaying, Widget? _) {
        final LibrarySong? song = nowPlaying.song;
        if (song == null) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compactHeight = constraints.maxHeight < 760;
            final double artworkExtent = math.max(
              0,
              constraints.maxWidth - (compactHeight ? 44 : 52),
            );

            return _DesktopPanel(
              padding: EdgeInsets.fromLTRB(
                compactHeight ? 22 : 26,
                compactHeight ? 22 : 28,
                compactHeight ? 22 : 26,
                compactHeight ? 22 : 26,
              ),
              child: ValueListenableBuilder<PlaybackProgressState>(
                valueListenable: controller.playbackProgressState,
                builder:
                    (
                      BuildContext context,
                      PlaybackProgressState progress,
                      Widget? child,
                    ) {
                      final Duration duration =
                          progress.duration == Duration.zero
                          ? song.duration
                          : progress.duration;
                      final Duration position = nowPlaying.isLoading
                          ? Duration.zero
                          : progress.position;
                      final double progressValue = duration.inMilliseconds <= 0
                          ? 0
                          : position.inMilliseconds / duration.inMilliseconds;
                      final double safeProgress = progressValue.isFinite
                          ? progressValue.clamp(0.0, 1.0)
                          : 0.0;
                      final bool showPauseIcon =
                          progress.isPlaying && !nowPlaying.isLoading;

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const _DesktopPanelTitle(
                              eyebrow: 'NOW PLAYING',
                              title: 'Session controls',
                            ),
                            SizedBox(height: compactHeight ? 18 : 22),
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(34),
                                child: SizedBox(
                                  width: artworkExtent,
                                  height: artworkExtent,
                                  child:
                                      song.artworkUrl != null &&
                                          song.artworkUrl!.trim().isNotEmpty
                                      ? _CachedArtworkImage(
                                          imageUrl: song.artworkUrl!,
                                          dimension: artworkExtent,
                                          placeholder:
                                              const _PlayerArtFallback(),
                                          errorWidget:
                                              const _PlayerArtFallback(),
                                        )
                                      : const _PlayerArtFallback(),
                                ),
                              ),
                            ),
                            SizedBox(height: compactHeight ? 18 : 22),
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                color: _kTextPrimary,
                                fontSize: compactHeight ? 24 : 28,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _songArtistLabel(song),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.ibmPlexSans(
                                color: _kTextSecondary,
                                fontSize: compactHeight ? 15 : 16,
                                height: 1.35,
                              ),
                            ),
                            SizedBox(height: compactHeight ? 18 : 22),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: SizedBox(
                                height: 6,
                                child: ColoredBox(
                                  color: const Color(0xFF73432C),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: safeProgress,
                                      alignment: Alignment.centerLeft,
                                      child: const SizedBox.expand(
                                        child: ColoredBox(color: _kAccent),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                Text(
                                  _formatClock(position),
                                  style: GoogleFonts.ibmPlexSans(
                                    color: _kTextPrimary.withValues(
                                      alpha: 0.92,
                                    ),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatClock(duration),
                                  style: GoogleFonts.ibmPlexSans(
                                    color: _kTextPrimary.withValues(
                                      alpha: 0.92,
                                    ),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compactHeight ? 18 : 22),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                _MiniPlayerIcon(
                                  icon: Icons.shuffle_rounded,
                                  onPressed: controller.toggleShuffle,
                                  color: nowPlaying.isShuffleEnabled
                                      ? _kAccent
                                      : _kTextSecondary.withValues(alpha: 0.7),
                                ),
                                _MiniPlayerIcon(
                                  icon: Icons.skip_previous_rounded,
                                  onPressed: controller.previousTrack,
                                  color: _kTextPrimary,
                                ),
                                InkWell(
                                  onTap: controller.togglePlayback,
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    width: compactHeight ? 72 : 80,
                                    height: compactHeight ? 72 : 80,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _kAccent,
                                    ),
                                    child: Center(
                                      child: nowPlaying.isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.6,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.black),
                                              ),
                                            )
                                          : Icon(
                                              showPauseIcon
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: Colors.black,
                                              size: showPauseIcon ? 34 : 38,
                                            ),
                                    ),
                                  ),
                                ),
                                _MiniPlayerIcon(
                                  icon: Icons.skip_next_rounded,
                                  onPressed: controller.nextTrack,
                                  color: _kTextPrimary,
                                ),
                                _MiniPlayerIcon(
                                  icon: _repeatIcon(nowPlaying.repeatMode),
                                  onPressed: controller.cycleRepeatMode,
                                  color: _kTextSecondary.withValues(alpha: 0.7),
                                ),
                              ],
                            ),
                            SizedBox(height: compactHeight ? 22 : 26),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: onOpenPlayer,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF572812),
                                  foregroundColor: _kTextPrimary,
                                  padding: EdgeInsets.symmetric(
                                    vertical: compactHeight ? 16 : 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    side: const BorderSide(
                                      color: Color(0xFF8C4C27),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.open_in_full_rounded),
                                label: Text(
                                  'Open Full Player',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.splineSans(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
              ),
            );
          },
        );
      },
    );
  }
}

class _DesktopHomeScreen extends StatelessWidget {
  const _DesktopHomeScreen({
    required this.controller,
    required this.onOpenSearch,
  });

  final MusixController controller;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    if (controller.isOfflineViewActive) {
      final List<LibrarySong> localSongs = controller.browsableSongs
          .where((LibrarySong song) => !song.isRemote)
          .take(6)
          .toList(growable: false);
      return _DesktopPageScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _DesktopPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _DesktopPanelTitle(
                    eyebrow: 'OFFLINE',
                    title: 'Desktop home is in offline mode',
                  ),
                  const SizedBox(height: 16),
                  _NetworkUnavailablePanel(
                    title: controller.offlineMusicMode
                        ? 'Offline Music Mode'
                        : 'No Internet Connection',
                    message: controller.offlineMusicMode
                        ? 'Only your local music is active right now. Online recommendations stay paused until connectivity returns.'
                        : 'Desktop recommendations need internet. Your local and downloaded music are still available.',
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
                ],
              ),
            ),
            const SizedBox(height: 20),
            _DesktopPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _DesktopPanelTitle(
                    eyebrow: 'READY OFFLINE',
                    title: 'Local picks',
                  ),
                  const SizedBox(height: 16),
                  if (localSongs.isEmpty)
                    const _PersonalizationHintCard(
                      message:
                          'Import a folder or add local songs to build your offline library.',
                    )
                  else
                    ...localSongs.asMap().entries.map(
                      (MapEntry<int, LibrarySong> entry) =>
                          _MusixPopularTrackTile(
                            index: entry.key + 1,
                            song: entry.value,
                            onTap: () => controller.playSongs(
                              localSongs,
                              startIndex: entry.key,
                              label: 'Offline',
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
    final bool showRecommendationLoadingState =
        !hasRevealableContent &&
        (controller.homeLoading || !controller.homeRefreshResolvedOnce);
    final List<LibrarySong> jumpBackIn = controller.recentlyPlayedSongs
        .take(4)
        .toList(growable: false);
    final _FeaturedHeroData? featured = _pickFeaturedHero(
      context: context,
      controller: controller,
      feed: feed,
      mayYouLike: mayYouLikeFull,
    );

    return _DesktopPageScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DesktopPanel(
            child: showRecommendationLoadingState
                ? const _MusixHeroSkeleton()
                : featured != null
                ? _MusixHeroCard(
                    badge: featured.badge,
                    title: featured.title,
                    subtitle: featured.subtitle,
                    imageUrl: featured.imageUrl,
                    onListenNow: featured.onListenNow,
                  )
                : const _PersonalizationHintCard(
                    message:
                        'Play local songs, like tracks, or reconnect to load personalized recommendations here.',
                  ),
          ),
          const SizedBox(height: 20),
          _DesktopPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MusixSectionHeader(
                  title: 'MAY YOU LIKE',
                  onViewAll: () {
                    if (mayYouLikeFull.isEmpty) {
                      onOpenSearch();
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
                if (showRecommendationLoadingState)
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
              ],
            ),
          ),
          ..._buildMoreShelves(
            context: context,
            controller: controller,
            skipCount: 1,
          ),
          if (controller.homeLoading && !hasRevealableContent) ...<Widget>[
            const SizedBox(height: 20),
            const _DesktopPanel(
              child: Opacity(opacity: 0.8, child: _HomeFeedSkeleton()),
            ),
          ],
          if (!controller.homeLoading && jumpBackIn.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            _DesktopPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _DesktopPanelTitle(
                    eyebrow: 'RECENT',
                    title: 'Jump back in',
                    action: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                _RecentPlaysScreen(controller: controller),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: _kAccent,
                        backgroundColor: const Color(0x221C0904),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: _kSurfaceEdge),
                        ),
                        textStyle: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Open history'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final double width = (constraints.maxWidth - 20) / 2;
                          return Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            children: jumpBackIn.map((LibrarySong song) {
                              return _MusixJumpBackCard(
                                width: width.clamp(220.0, 420.0),
                                title: song.title,
                                subtitle: _songArtistLabel(song),
                                seed: song.id,
                                imageUrl: song.artworkUrl,
                                onTap: () {
                                  if (song.isRemote) {
                                    controller.playOnlineSong(song);
                                  } else {
                                    controller.playSong(
                                      song,
                                      label: 'Jump back in',
                                    );
                                  }
                                },
                              );
                            }).toList(),
                          );
                        },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopSearchScreen extends StatelessWidget {
  const _DesktopSearchScreen({
    required this.controller,
    required this.searchController,
    required this.searchFocusNode,
    required this.scrollController,
    required this.recentSearches,
    required this.onRunSearch,
    required this.onRememberSearch,
    required this.onApplySearch,
    required this.onRemoveSearch,
  });

  final MusixController controller;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ScrollController scrollController;
  final List<String> recentSearches;
  final ValueChanged<String> onRunSearch;
  final ValueChanged<String> onRememberSearch;
  final ValueChanged<String> onApplySearch;
  final ValueChanged<String> onRemoveSearch;

  @override
  Widget build(BuildContext context) {
    final bool offline = controller.isOfflineViewActive;
    if (offline) {
      return _DesktopPageScrollView(
        child: _DesktopPanel(
          child: _NetworkUnavailablePanel(
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
        ),
      );
    }

    final String query = searchController.text.trim().toLowerCase();
    final List<LibrarySong> songs = controller.songs
        .where(
          (LibrarySong song) =>
              query.isEmpty ||
              song.title.toLowerCase().contains(query) ||
              song.artist.toLowerCase().contains(query) ||
              song.album.toLowerCase().contains(query),
        )
        .toList(growable: false);
    final List<_SearchGenreShelf> browseShelves = _buildSearchGenreShelves(
      controller,
    );
    final List<LibrarySong> monthlyTrendingSongs = _buildMonthlyTrendingNow(
      controller: controller,
    ).take(7).toList(growable: false);
    final List<LibrarySong> topResults = _mergeSearchResults(
      songs,
      controller.onlineResults,
      query: searchController.text,
    );

    return _DesktopPageScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DesktopPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _DesktopPanelTitle(
                  eyebrow: 'SEARCH',
                  title: 'Find artists, songs, and playlists',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  onChanged: onRunSearch,
                  onSubmitted: onRememberSearch,
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
                    hintText: 'Artists, songs, albums, or playlists',
                    hintStyle: const TextStyle(color: Color(0xFFC99173)),
                    filled: true,
                    fillColor: const Color(0xFF5A2904),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
                if (recentSearches.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: recentSearches.map((String term) {
                      return _SearchHistoryChip(
                        label: term,
                        onTap: () => onApplySearch(term),
                        onRemove: () => onRemoveSearch(term),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (query.isEmpty)
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stacked = constraints.maxWidth < 1160;
                final Widget browse = _DesktopPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final double totalWidth = constraints.maxWidth;
                              final int columns = totalWidth >= 1180
                                  ? 3
                                  : totalWidth >= 520
                                  ? 2
                                  : 1;
                              final double itemWidth = math.max(
                                0,
                                (totalWidth - ((columns - 1) * 16)) / columns,
                              );
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: browseShelves.asMap().entries.map((
                                  MapEntry<int, _SearchGenreShelf> entry,
                                ) {
                                  final int index = entry.key;
                                  final _SearchGenreShelf shelf = entry.value;
                                  final bool isLast =
                                      index == browseShelves.length - 1;
                                  final bool shouldSpanFullWidth =
                                      isLast &&
                                      browseShelves.length % columns == 1;
                                  return SizedBox(
                                    width: shouldSpanFullWidth
                                        ? totalWidth
                                        : itemWidth,
                                    child: _SearchGenreCard(
                                      shelf: shelf,
                                      height: shouldSpanFullWidth || isLast
                                          ? 210
                                          : 176,
                                      wide: shouldSpanFullWidth || isLast,
                                      onTap: () => onApplySearch(shelf.query),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                      ),
                    ],
                  ),
                );

                final Widget trending = _DesktopPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _DesktopPanelTitle(
                        eyebrow: 'TRENDING',
                        title: 'Regional chart pulse',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_lastMonthLabel()} chart - ${controller.trendingNowRegionLabel}',
                        style: GoogleFonts.ibmPlexSans(
                          color: _kTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (monthlyTrendingSongs.isEmpty &&
                          !controller.trendingNowLoading)
                        Text(
                          'Regional chart songs are loading for ${controller.preferredRegionLabel}.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFFD1A793)),
                        )
                      else
                        ...monthlyTrendingSongs.asMap().entries.map(
                          (MapEntry<int, LibrarySong> entry) =>
                              _SearchTrendingTile(
                                rank: entry.key + 1,
                                song: entry.value,
                                controller: controller,
                              ),
                        ),
                      if (controller.trendingNowLoading)
                        const _OnlineSongResultsSkeleton(),
                    ],
                  ),
                );

                if (stacked) {
                  return Column(
                    children: <Widget>[
                      browse,
                      const SizedBox(height: 20),
                      trending,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 7, child: browse),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: trending),
                  ],
                );
              },
            )
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget results = _DesktopPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _DesktopPanelTitle(
                        eyebrow: 'RESULTS',
                        title: 'Top matches',
                      ),
                      const SizedBox(height: 16),
                      if (topResults.isEmpty && !controller.onlineLoading)
                        Text(
                          'No matches found for "${searchController.text.trim()}".',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFFD1A793)),
                        )
                      else ...<Widget>[
                        ...topResults.asMap().entries.map(
                          (MapEntry<int, LibrarySong> entry) =>
                              _SearchTrendingTile(
                                rank: entry.key + 1,
                                song: entry.value,
                                controller: controller,
                              ),
                        ),
                        if (controller.onlineLoading)
                          const _OnlineSongResultsSkeleton()
                        else if (controller.onlineHasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Scroll for more',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFD1A793)),
                            ),
                          ),
                      ],
                      if (controller.onlineError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            controller.onlineError!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFFFFA27C)),
                          ),
                        ),
                    ],
                  ),
                );

                return results;
              },
            ),
        ],
      ),
    );
  }
}

class _DesktopLibraryScreen extends StatelessWidget {
  const _DesktopLibraryScreen({required this.controller});

  final MusixController controller;

  @override
  Widget build(BuildContext context) {
    final bool offline = controller.isOfflineViewActive;
    final List<UserPlaylist> playlists = controller.playlists;
    final List<LibrarySong> cachedSongs = controller.cachedSongs;
    final List<LibrarySong> likedSongs = controller.likedSongs;
    final List<LibrarySong> dislikedSongs = controller.dislikedSongs;
    final bool hasCachedPlaylist = cachedSongs.isNotEmpty;
    final bool hasDislikedPlaylist = dislikedSongs.isNotEmpty;
    final List<_DesktopLibraryPlaylistEntry> playlistEntries =
        <_DesktopLibraryPlaylistEntry>[
          if (hasCachedPlaylist)
            _DesktopLibraryPlaylistEntry(
              title: 'Cached Songs',
              seed: 'cached_songs',
              songs: cachedSongs,
              subtitle: '${cachedSongs.length} cached tracks',
            ),
          if (hasDislikedPlaylist)
            _DesktopLibraryPlaylistEntry(
              title: 'Disliked Songs',
              seed: 'disliked_songs',
              songs: dislikedSongs,
              subtitle: '${dislikedSongs.length} disliked tracks',
            ),
          ...playlists.map((UserPlaylist playlist) {
            final List<LibrarySong> playlistSongs = controller.songsForPlaylist(
              playlist,
            );
            return _DesktopLibraryPlaylistEntry(
              title: playlist.name,
              seed: playlist.id,
              songs: playlistSongs,
              playlist: playlist,
            );
          }),
        ].toList(growable: false);
    final bool hasAnyPlaylistEntries = playlistEntries.isNotEmpty;

    return _DesktopPageScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: <Widget>[
              SizedBox(
                width: 300,
                child: _LibraryFeatureCard(
                  title: 'Liked\nSongs',
                  subtitle: '${likedSongs.length} tracks',
                  icon: Icons.favorite_rounded,
                  accent: const Color(0xFFFF8A3D),
                  secondary: const Color(0xFFFF7D2F),
                  watermark: Icons.favorite_rounded,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => _MusixPlaylistScreen(
                          controller: controller,
                          title: 'Liked Songs',
                          songs: likedSongs,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: 300,
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
                        builder: (BuildContext context) => _MusixPlaylistScreen(
                          controller: controller,
                          title: 'Offline',
                          songs: controller.browsableSongs,
                          localPlaybackOnly: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _DesktopPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Playlists',
                        style: GoogleFonts.splineSans(
                          color: const Color(0xFFFFE2D2),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 0.95,
                        ),
                      ),
                    ),
                    if (!offline)
                      TextButton(
                        onPressed: () =>
                            _showCreatePlaylistDialog(context, controller),
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (!offline && !hasAnyPlaylistEntries)
                  _LibraryEmptyPlaylistCard(
                    onCreate: () =>
                        _showCreatePlaylistDialog(context, controller),
                  )
                else if (playlistEntries.isNotEmpty)
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final int columns = constraints.maxWidth >= 1380
                              ? 3
                              : constraints.maxWidth >= 760
                              ? 2
                              : 1;
                          final double rawItemWidth =
                              (constraints.maxWidth - ((columns - 1) * 18)) /
                              columns;
                          final double itemWidth = rawItemWidth.clamp(
                            260.0,
                            420.0,
                          );
                          return Wrap(
                            spacing: 18,
                            runSpacing: 18,
                            children: playlistEntries.map((
                              _DesktopLibraryPlaylistEntry entry,
                            ) {
                              return SizedBox(
                                width: itemWidth,
                                child: _DesktopPlaylistBox(
                                  controller: controller,
                                  title: entry.title,
                                  seed: entry.seed,
                                  songs: entry.songs,
                                  playlist: entry.playlist,
                                  subtitle: entry.subtitle,
                                ),
                              );
                            }).toList(),
                          );
                        },
                  )
                else if (!hasCachedPlaylist && !hasDislikedPlaylist)
                  const _LibraryBlockedCard(
                    title: 'Cloud Playlists',
                    subtitle: 'Reconnect to open playlists from the cloud.',
                    icon: Icons.cloud_off_rounded,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopPlaylistBox extends StatelessWidget {
  const _DesktopPlaylistBox({
    required this.controller,
    required this.title,
    required this.seed,
    required this.songs,
    this.playlist,
    this.subtitle,
  });

  final MusixController controller;
  final String title;
  final String seed;
  final List<LibrarySong> songs;
  final UserPlaylist? playlist;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final LibrarySong? leadSong = songs.isEmpty ? null : songs.first;
    final Widget artwork = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 104,
        height: 104,
        child: leadSong != null
            ? _Artwork(
                seed: seed,
                title: title,
                size: 104,
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
                  size: 38,
                ),
              ),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () {
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
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF23100C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF342018)),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 300;

            if (wide) {
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 150),
                child: Row(
                  children: <Widget>[
                    artwork,
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.splineSans(
                              color: const Color(0xFFFFE2D2),
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 0.98,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle ?? '${songs.length} tracks',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.splineSans(
                              color: const Color(0xFFD3A689),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF8C5835),
                      size: 26,
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                artwork,
                const SizedBox(height: 16),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.splineSans(
                    color: const Color(0xFFFFE2D2),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 0.98,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle ?? '${songs.length} tracks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.splineSans(
                    color: const Color(0xFFD3A689),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DesktopLibraryPlaylistEntry {
  const _DesktopLibraryPlaylistEntry({
    required this.title,
    required this.seed,
    required this.songs,
    this.playlist,
    this.subtitle,
  });

  final String title;
  final String seed;
  final List<LibrarySong> songs;
  final UserPlaylist? playlist;
  final String? subtitle;
}

class _DesktopSettingsActionRow extends StatelessWidget {
  const _DesktopSettingsActionRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFFFFE6D5),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFC89373)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Align(alignment: Alignment.centerRight, child: trailing),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }
}

class _DesktopSettingsScreen extends StatelessWidget {
  const _DesktopSettingsScreen({
    required this.controller,
    required this.onPickNextChanceSongCount,
    required this.onPickRegion,
  });

  final MusixController controller;
  final Future<void> Function() onPickNextChanceSongCount;
  final Future<void> Function() onPickRegion;

  @override
  Widget build(BuildContext context) {
    const Color card = Color(0xFF2A1007);
    const Color cardEdge = Color(0xFF3A170C);
    const Color titleColor = Color(0xFFFFE6D5);
    const Color subtitleColor = Color(0xFFC89373);
    const Color accent = Color(0xFFFF8A2A);

    final AuthService authService = context.read<AuthService>();
    final bool gapless = controller.settings.gaplessPlayback;
    final int nextChanceSongCount = controller.settings.nextChanceSongCount;
    final String userName = authService.currentUserDisplayName;
    final String userEmail = authService.currentUserEmail;
    final String userInitials = authService.currentUserInitials;
    final String userId = authService.currentUserShortUid;
    final bool emailVerified = authService.isCurrentUserEmailVerified;

    Future<void> signOutUser() async {
      try {
        await authService.signOut();
        await controller.clearUserDataFromCloud();
        if (!context.mounted) {
          return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      } on AuthException catch (error) {
        if (context.mounted) {
          _showMusixSnackBar(context, error.message);
        }
      }
    }

    return _DesktopPageScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DesktopPanel(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: <Widget>[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A1D0E),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Text(
                      userInitials,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: const Color(0xFFFFC8A1),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        userName.toUpperCase(),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        userEmail,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: subtitleColor),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = constraints.maxWidth < 1160;
              final Widget leftColumn = Column(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardEdge),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
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
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: titleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ProfileRow(
                          title: 'Email Verification',
                          subtitle: emailVerified
                              ? 'Your Firebase account email is verified.'
                              : 'Email verification is currently not completed.',
                          trailing: emailVerified ? 'Verified' : 'Pending',
                        ),
                        const Divider(color: cardEdge, height: 24),
                        _ProfileRow(
                          title: 'Firebase User ID',
                          subtitle:
                              'Short reference for your signed-in account.',
                          trailing: userId,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardEdge),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
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
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: titleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DesktopSettingsActionRow(
                          title: 'Gapless Playback',
                          subtitle: 'Remove silence between album tracks',
                          trailing: Switch(
                            value: gapless,
                            activeThumbColor: accent,
                            activeTrackColor: const Color(0xFF9D4D18),
                            inactiveThumbColor: const Color(0xFFD8A98A),
                            inactiveTrackColor: const Color(0xFF5C2A17),
                            onChanged: controller.setGaplessPlayback,
                          ),
                        ),
                        const Divider(color: cardEdge, height: 24),
                        _DesktopSettingsActionRow(
                          title: 'Upcoming Offline Songs',
                          subtitle: nextChanceSongCount == 0
                              ? 'Off'
                              : 'Keep the next $nextChanceSongCount song${nextChanceSongCount == 1 ? '' : 's'} ready offline',
                          onTap: onPickNextChanceSongCount,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  nextChanceSongCount == 0
                                      ? 'Off'
                                      : '$nextChanceSongCount',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: subtitleColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final Widget rightColumn = Column(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardEdge),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.public_rounded,
                              color: subtitleColor,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Discovery Region',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: titleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DesktopSettingsActionRow(
                          title: 'Region',
                          subtitle:
                              'Controls Trending Now and regional chart shelves',
                          onTap: onPickRegion,
                          trailing: Text(
                            controller.preferredRegionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ProfileDataUsageCard(
                    controller: controller,
                    card: card,
                    cardEdge: cardEdge,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    accent: accent,
                  ),
                  const SizedBox(height: 20),
                  _ProfileCurrentStreamCard(
                    controller: controller,
                    card: card,
                    cardEdge: cardEdge,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    accent: accent,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardEdge),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Pulse Audio v4.2.1-stable',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: subtitleColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Proudly built for music enthusiasts.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: subtitleColor.withValues(alpha: 0.8),
                              ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'PRIVACY      TERMS      CREDITS',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: subtitleColor,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: signOutUser,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              side: const BorderSide(color: cardEdge),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              foregroundColor: accent,
                            ),
                            child: const Text('LOG OUT'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (stacked) {
                return Column(
                  children: <Widget>[
                    leftColumn,
                    const SizedBox(height: 20),
                    rightColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: leftColumn),
                  const SizedBox(width: 20),
                  Expanded(child: rightColumn),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
