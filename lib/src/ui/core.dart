part of '../ui.dart';

class MusixApp extends StatelessWidget {
  const MusixApp({super.key});

  @override
  Widget build(BuildContext context) {
    final MusixController controller = context.watch<MusixController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Musix',
      themeMode: controller.settings.themeMode,
      builder: (BuildContext context, Widget? child) {
        return Focus(
          canRequestFocus: false,
          onKeyEvent: (FocusNode node, KeyEvent event) {
            if (event.logicalKey != LogicalKeyboardKey.space ||
                event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            if (_focusedWidgetAcceptsTextInput()) {
              return KeyEventResult.ignored;
            }
            unawaited(context.read<MusixController>().togglePlayback());
            return KeyEventResult.handled;
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: _MusixStartupGate(controller: controller),
    );
  }
}

class _MusixStartupGate extends StatefulWidget {
  const _MusixStartupGate({required this.controller});

  final MusixController controller;

  @override
  State<_MusixStartupGate> createState() => _MusixStartupGateState();
}

class _MusixStartupGateState extends State<_MusixStartupGate> {
  static const Duration _targetStartupDuration = Duration(seconds: 5);
  static const Duration _splashFadeOutDuration = Duration(milliseconds: 650);
  static const bool _debugInfiniteStartup = false;

  int _bootAttempt = 0;
  Object? _bootError;
  bool _ready = false;
  bool _splashVisible = true;
  Duration _measuredBootDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _beginBoot();
  }

  @override
  void didUpdateWidget(covariant _MusixStartupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _beginBoot();
    }
  }

  Future<void> _beginBoot() async {
    final int attempt = ++_bootAttempt;
    setState(() {
      _bootError = null;
      _ready = false;
      _splashVisible = true;
      _measuredBootDuration = Duration.zero;
    });

    try {
      final Stopwatch stopwatch = Stopwatch()..start();
      await widget.controller.initialize();
      stopwatch.stop();
      final Duration bootDuration = stopwatch.elapsed;
      final Duration holdDuration = _remainingStartupHold(bootDuration);
      if (holdDuration > Duration.zero) {
        await Future<void>.delayed(holdDuration);
      }
      if (!mounted || attempt != _bootAttempt) {
        return;
      }
      setState(() {
        _measuredBootDuration = bootDuration;
        _ready = !_debugInfiniteStartup;
      });
      if (!_debugInfiniteStartup) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || attempt != _bootAttempt) {
            return;
          }
          setState(() => _splashVisible = false);
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Boot failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || attempt != _bootAttempt) {
        return;
      }
      setState(() {
        _bootError = error;
        _measuredBootDuration = Duration.zero;
      });
    }
  }

  Duration _remainingStartupHold(Duration bootDuration) {
    if (bootDuration >= _targetStartupDuration) {
      return Duration.zero;
    }
    return _targetStartupDuration - bootDuration;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_ready) const MusixShell(key: ValueKey<String>('shell')),
        IgnorePointer(
          ignoring: !_splashVisible,
          child: AnimatedOpacity(
            opacity: _splashVisible ? 1.0 : 0.0,
            duration: _splashFadeOutDuration,
            curve: Curves.easeInOutCubic,
            child: _MusixStartupScreen(
              key: ValueKey<String>('startup-$_bootAttempt'),
              bootAttempt: _bootAttempt,
              controller: widget.controller,
              error: _bootError,
              measuredBootDuration: _measuredBootDuration,
              targetStartupDuration: _targetStartupDuration,
              onRetry: _beginBoot,
            ),
          ),
        ),
      ],
    );
  }
}

class _MusixStartupScreen extends StatefulWidget {
  const _MusixStartupScreen({
    super.key,
    required this.bootAttempt,
    required this.controller,
    required this.onRetry,
    required this.measuredBootDuration,
    required this.targetStartupDuration,
    this.error,
  });

  final int bootAttempt;
  final MusixController controller;
  final Object? error;
  final Duration measuredBootDuration;
  final Duration targetStartupDuration;
  final VoidCallback onRetry;

  @override
  State<_MusixStartupScreen> createState() => _MusixStartupScreenState();
}

class _MusixStartupScreenState extends State<_MusixStartupScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: widget.targetStartupDuration,
  );
  late final Animation<double> _progressValue = CurvedAnimation(
    parent: _timeline,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _timeline.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionPreference();
  }

  @override
  void didUpdateWidget(covariant _MusixStartupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetStartupDuration != widget.targetStartupDuration) {
      _timeline.duration = widget.targetStartupDuration;
    }
    if (oldWidget.bootAttempt != widget.bootAttempt) {
      _timeline
        ..stop()
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _timeline.dispose();
    super.dispose();
  }

  void _syncMotionPreference() {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
    if (reduceMotion) {
      _intro
        ..stop()
        ..value = 1.0;
      return;
    }
    if (!_intro.isCompleted && !_intro.isAnimating) {
      _intro.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Listenable animation = Listenable.merge(<Listenable>[
      _intro,
      _timeline,
    ]);
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          final double wordOpacity = Curves.easeOutCubic.transform(
            (_displayedProgress * 1.1).clamp(0.0, 1.0),
          );
          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.2),
                radius: 1.05,
                colors: <Color>[Color(0xFF161616), Color(0xFF080808)],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFF121212), Color(0xFF050505)],
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Transform.scale(
                        scale: Tween<double>(begin: 0.98, end: 1.0).transform(
                          Curves.easeOutCubic.transform(_intro.value),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const _MusixSplashLogoBadge(),
                            const SizedBox(height: 16),
                            Opacity(
                              opacity: wordOpacity,
                              child: Text(
                                'MUSIX',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _MusixSplashProgressBar(
                              width: 128,
                              height: 3,
                              progress: _progressValue,
                              baseColor: const Color(0xFF1E1E1E),
                              fillColor: _kAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.error != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      minimum: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: FilledButton.icon(
                        onPressed: widget.onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E0D07),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(color: Color(0xFF6D3928)),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          'Try again',
                          style: GoogleFonts.ibmPlexSans(
                            fontWeight: FontWeight.w700,
                          ),
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
  }

  double get _displayedProgress {
    if (widget.error != null) {
      return _timeline.value.clamp(0.0, 1.0);
    }
    if (!widget.controller.initialized && _timeline.isCompleted) {
      return 0.94;
    }
    return _timeline.value.clamp(0.0, 1.0);
  }
}

class _MusixSplashLogoBadge extends StatelessWidget {
  const _MusixSplashLogoBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Center(
        child: Image.asset(
          'assets/icons/Musix - Full.png',
          width: 100,
          height: 100,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _MusixSplashProgressBar extends StatelessWidget {
  const _MusixSplashProgressBar({
    required this.width,
    required this.height,
    required this.progress,
    required this.baseColor,
    required this.fillColor,
  });

  final double width;
  final double height;
  final Animation<double> progress;
  final Color baseColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: AnimatedBuilder(
          animation: progress,
          builder: (BuildContext context, _) {
            final double value = (0.08 + (0.92 * progress.value)).clamp(
              0.0,
              1.0,
            );
            return LinearProgressIndicator(
              value: value,
              minHeight: height,
              color: fillColor,
              backgroundColor: baseColor,
            );
          },
        ),
      ),
    );
  }
}

bool _focusedWidgetAcceptsTextInput() {
  for (
    FocusNode? node = FocusManager.instance.primaryFocus;
    node != null;
    node = node.parent
  ) {
    final BuildContext? focusedContext = node.context;
    if (focusedContext == null) {
      continue;
    }
    if (focusedContext.widget is EditableText ||
        focusedContext.findAncestorStateOfType<EditableTextState>() != null) {
      return true;
    }
  }
  return false;
}

class _ShortcutBinding {
  const _ShortcutBinding(this.activator, this.onInvoke);

  final ShortcutActivator activator;
  final VoidCallback onInvoke;
}

bool _handleShortcutBindings(
  KeyEvent event,
  Iterable<_ShortcutBinding> bindings, {
  bool disableWhenTextFieldFocused = true,
}) {
  if (disableWhenTextFieldFocused && _focusedWidgetAcceptsTextInput()) {
    return false;
  }
  final HardwareKeyboard keyboard = HardwareKeyboard.instance;
  for (final _ShortcutBinding binding in bindings) {
    if (binding.activator.accepts(event, keyboard)) {
      binding.onInvoke();
      return true;
    }
  }
  return false;
}

bool _routeIsCurrent(BuildContext context) {
  final ModalRoute<dynamic>? route = ModalRoute.of(context);
  return route == null || route.isCurrent;
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
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: _kAccent,
      selectionColor: Color(0x66FF8A2A),
      selectionHandleColor: _kAccent,
    ),
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

class MusixShell extends StatefulWidget {
  const MusixShell({super.key});

  @override
  State<MusixShell> createState() => _MusixShellState();
}

class _MusixShellState extends State<MusixShell> {
  static const List<AppDestination> _mainDestinations = <AppDestination>[
    AppDestination.home,
    AppDestination.search,
    AppDestination.library,
    AppDestination.settings,
  ];

  AppDestination _destination = AppDestination.home;
  LibraryFilter _libraryFilter = LibraryFilter.all;
  late final PageController _pageController;
  late final KeyEventCallback _shortcutHandler;
  int _searchFocusRequestSerial = 0;
  int get _destinationPageIndex => _mainDestinations.indexOf(_destination);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _destinationPageIndex);
    _shortcutHandler = _handleShortcutKeyEvent;
    HardwareKeyboard.instance.addHandler(_shortcutHandler);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        context.read<MusixController>().ensureNotificationPermissionIfNeeded(),
      );
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_shortcutHandler);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MusixController controller = context.watch<MusixController>();
    final bool desktop = _isDesktopPlatform();
    final bool wide = MediaQuery.sizeOf(context).width >= 960;
    final List<Widget> pages = _mainDestinations
        .map(
          (AppDestination destination) => KeyedSubtree(
            key: ValueKey<AppDestination>(destination),
            child: _buildPageForDestination(context, controller, destination),
          ),
        )
        .toList(growable: false);

    if (desktop) {
      return _DesktopShellScaffold(
        controller: controller,
        destination: _destination,
        destinations: _mainDestinations,
        pageIndex: _destinationPageIndex,
        onDestinationChanged: _setDestination,
        onOpenPlayer: () {
          if (controller.nowPlayingState.value.song == null) {
            return;
          }
          unawaited(_openPlayer(context, controller));
        },
        children: pages,
      );
    }

    final Widget content = Column(
      children: <Widget>[
        if (controller.scanning)
          const LinearProgressIndicator(
            minHeight: 3,
            color: _kAccent,
            backgroundColor: Color(0xFF3A170C),
          ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (int index) {
              final AppDestination destination = _mainDestinations[index];
              _clearSearchIfNeeded(destination);
              if (_destination != destination && mounted) {
                setState(() => _destination = destination);
              }
            },
            children: pages,
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
              selectedIndex: _destinationPageIndex,
              extended: MediaQuery.sizeOf(context).width >= 1240,
              onDestinationSelected: (int index) {
                _setDestination(_mainDestinations[index]);
              },
              destinations: _mainDestinations
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
              child: _MusixBottomNav(
                destination: _destination,
                onDestinationChanged: (AppDestination value) {
                  _setDestination(value);
                },
              ),
            ),
    );
  }

  void _setDestination(AppDestination destination) {
    if (_destination == destination) {
      return;
    }
    _clearSearchIfNeeded(destination);
    final int pageIndex = _mainDestinations.indexOf(destination);
    if (pageIndex < 0) {
      return;
    }
    setState(() => _destination = destination);
    if (_pageController.hasClients) {
      unawaited(
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _clearSearchIfNeeded(AppDestination nextDestination) {
    if (_destination == AppDestination.search &&
        nextDestination != AppDestination.search) {
      context.read<MusixController>().clearSearchState();
    }
  }

  Widget _buildPageForDestination(
    BuildContext context,
    MusixController controller,
    AppDestination destination,
  ) {
    return switch (destination) {
      AppDestination.home => _HomeScreen(
        key: const ValueKey<String>('home'),
        controller: controller,
        onOpenSearch: () => _setDestination(AppDestination.search),
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
        focusRequestSerial: _searchFocusRequestSerial,
      ),
      AppDestination.settings => _SettingsScreen(
        key: const ValueKey<String>('settings'),
        controller: controller,
      ),
      AppDestination.history => const SizedBox.shrink(),
    };
  }

  Future<void> _openPlayer(
    BuildContext context,
    MusixController controller,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            _PlayerScreen(controller: controller),
      ),
    );
  }

  bool _handleShortcutKeyEvent(KeyEvent event) {
    if (!_isDesktopPlatform() || !mounted || !_routeIsCurrent(context)) {
      return false;
    }
    final MusixController controller = context.read<MusixController>();
    return _handleShortcutBindings(event, <_ShortcutBinding>[
      _ShortcutBinding(
        const SingleActivator(
          LogicalKeyboardKey.digit1,
          control: true,
          includeRepeats: false,
        ),
        () => _setDestination(_mainDestinations[0]),
      ),
      _ShortcutBinding(
        const SingleActivator(
          LogicalKeyboardKey.digit2,
          control: true,
          includeRepeats: false,
        ),
        () => _setDestination(_mainDestinations[1]),
      ),
      _ShortcutBinding(
        const SingleActivator(
          LogicalKeyboardKey.digit3,
          control: true,
          includeRepeats: false,
        ),
        () => _setDestination(_mainDestinations[2]),
      ),
      _ShortcutBinding(
        const SingleActivator(
          LogicalKeyboardKey.digit4,
          control: true,
          includeRepeats: false,
        ),
        () => _setDestination(_mainDestinations[3]),
      ),
      _ShortcutBinding(
        const SingleActivator(
          LogicalKeyboardKey.digit1,
          meta: true,
          includeRepeats: false,
        ),
        () => _setDestination(_mainDestinations[0]),
      ),
      _ShortcutBinding(
        const SingleActivator(
          LogicalKeyboardKey.digit2,
          meta: true,
          includeRepeats: false,
        ),
        () => _setDestination(_mainDestinations[1]),
      ),
      _ShortcutBinding(
        const SingleActivator(
          LogicalKeyboardKey.digit3,
          meta: true,
          includeRepeats: false,
        ),
        () => _setDestination(_mainDestinations[2]),
      ),
      _ShortcutBinding(
        const SingleActivator(
          LogicalKeyboardKey.digit4,
          meta: true,
          includeRepeats: false,
        ),
        () => _setDestination(_mainDestinations[3]),
      ),
      _ShortcutBinding(
        const SingleActivator(
          LogicalKeyboardKey.arrowUp,
          includeRepeats: false,
        ),
        () {
          if (controller.nowPlayingState.value.song == null) {
            return;
          }
          unawaited(_openPlayer(context, controller));
        },
      ),
      _ShortcutBinding(
        const SingleActivator(LogicalKeyboardKey.keyS, includeRepeats: false),
        _openSearchReady,
      ),
      _ShortcutBinding(
        const SingleActivator(LogicalKeyboardKey.keyL, includeRepeats: false),
        () => unawaited(_likeCurrentSong(controller)),
      ),
      _ShortcutBinding(
        const SingleActivator(LogicalKeyboardKey.keyD, includeRepeats: false),
        () => unawaited(_dislikeCurrentSong(controller)),
      ),
      _ShortcutBinding(
        const SingleActivator(
          LogicalKeyboardKey.backspace,
          includeRepeats: false,
        ),
        () => unawaited(Navigator.of(context).maybePop()),
      ),
    ]);
  }

  void _openSearchReady() {
    setState(() {
      _searchFocusRequestSerial += 1;
    });
    _setDestination(AppDestination.search);
  }

  Future<void> _likeCurrentSong(MusixController controller) async {
    final String? songId = controller.nowPlayingState.value.song?.id;
    if (songId == null) {
      return;
    }
    await controller.likeSong(songId);
  }

  Future<void> _dislikeCurrentSong(MusixController controller) async {
    final String? songId = controller.nowPlayingState.value.song?.id;
    if (songId == null) {
      return;
    }
    await controller.dislikeSong(songId);
  }
}

const Color _kPageTop = Color(0xFF140804);
const Color _kPageMiddle = Color(0xFF211008);
const Color _kPageBottom = Color(0xFF0D0503);
const Color _kSurface = Color(0xFF2A1007);
const Color _kSurfaceEdge = Color(0xFF3A170C);
const Color _kAccent = Color(0xFFFF8A2A);
const Color _kTextPrimary = Color(0xFFFFE8DA);
const Color _kTextSecondary = Color(0xFFFFC8A9);
const double _kScreenHorizontalPadding = 24;
const double _kScreenTopPadding = 10;
const double _kScreenBottomPadding = 28;
const double _kMobileBottomNavHeight = 85;
const double _kMiniPlayerReservedHeight = 96;
const EdgeInsets _kScreenContentPadding = EdgeInsets.fromLTRB(
  _kScreenHorizontalPadding,
  _kScreenTopPadding,
  _kScreenHorizontalPadding,
  _kScreenBottomPadding,
);

EdgeInsets _rootScreenContentPadding(
  BuildContext context, {
  required bool hasMiniPlayer,
}) {
  final bool wide = MediaQuery.sizeOf(context).width >= 960;
  final double bottomInset = wide
      ? _kScreenBottomPadding
      : _kScreenBottomPadding +
            _kMobileBottomNavHeight +
            (hasMiniPlayer ? _kMiniPlayerReservedHeight : 0);
  return EdgeInsets.fromLTRB(
    _kScreenHorizontalPadding,
    _kScreenTopPadding,
    _kScreenHorizontalPadding,
    bottomInset,
  );
}

BoxDecoration _musixPageDecoration() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: <Color>[_kPageTop, _kPageMiddle, _kPageBottom],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}

void _showMusixSnackBar(BuildContext context, String message) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: _kSurface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _kSurfaceEdge),
      ),
      content: Text(
        message,
        style: GoogleFonts.splineSans(
          color: _kTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

PopupMenuItem<String> _musixPopupMenuItem(String value, String label) {
  return PopupMenuItem<String>(
    value: value,
    child: Text(
      label,
      style: GoogleFonts.splineSans(
        color: _kTextPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _NetworkUnavailablePanel extends StatelessWidget {
  const _NetworkUnavailablePanel({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.wifi_off_rounded,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF35130A), Color(0xFF160806)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x55FF9E63)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -18,
            top: -16,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF8A2A).withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            left: -12,
            bottom: -20,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF8A2A).withValues(alpha: 0.18),
                  border: Border.all(color: const Color(0x55FFC39B)),
                ),
                child: Icon(icon, color: const Color(0xFFFFB784), size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: GoogleFonts.splineSans(
                  color: _kTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: GoogleFonts.splineSans(
                  color: _kTextSecondary.withValues(alpha: 0.92),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  if (actionLabel != null && onAction != null)
                    FilledButton.icon(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8A2A),
                        foregroundColor: const Color(0xFF2D1308),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.wifi_find_rounded),
                      label: Text(
                        actionLabel!,
                        style: GoogleFonts.splineSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
