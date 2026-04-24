part of '../ui.dart';

class SonixApp extends StatelessWidget {
  const SonixApp({super.key});

  @override
  Widget build(BuildContext context) {
    final SonixController controller = context.watch<SonixController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SONIX',
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
            unawaited(context.read<SonixController>().togglePlayback());
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
      home: const SonixShell(),
    );
  }
}

bool _focusedWidgetAcceptsTextInput() {
  final BuildContext? focusedContext =
      FocusManager.instance.primaryFocus?.context;
  if (focusedContext == null) {
    return false;
  }
  if (focusedContext.widget is EditableText) {
    return true;
  }

  bool foundEditableText = false;
  focusedContext.visitAncestorElements((Element element) {
    if (element.widget is EditableText) {
      foundEditableText = true;
      return false;
    }
    return true;
  });
  return foundEditableText;
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

class SonixShell extends StatefulWidget {
  const SonixShell({super.key});

  @override
  State<SonixShell> createState() => _SonixShellState();
}

class _SonixShellState extends State<SonixShell> {
  static const List<AppDestination> _mainDestinations = <AppDestination>[
    AppDestination.home,
    AppDestination.search,
    AppDestination.library,
    AppDestination.settings,
  ];

  AppDestination _destination = AppDestination.home;
  LibraryFilter _libraryFilter = LibraryFilter.all;
  late final PageController _pageController;
  int get _destinationPageIndex => _mainDestinations.indexOf(_destination);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _destinationPageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        context
            .read<SonixController>()
            .ensureNotificationPermissionIfNeeded(),
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SonixController controller = context.watch<SonixController>();
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
        onOpenPlayer: () => _openPlayer(context, controller),
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
              child: _SonixBottomNav(
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
      context.read<SonixController>().clearSearchState();
    }
  }

  Widget _buildPageForDestination(
    BuildContext context,
    SonixController controller,
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
    SonixController controller,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            _PlayerScreen(controller: controller),
      ),
    );
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

BoxDecoration _sonixPageDecoration() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: <Color>[_kPageTop, _kPageMiddle, _kPageBottom],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}

void _showSonixSnackBar(BuildContext context, String message) {
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

PopupMenuItem<String> _sonixPopupMenuItem(String value, String label) {
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
