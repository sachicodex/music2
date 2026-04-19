part of '../ui.dart';

class OuterTuneApp extends StatelessWidget {
  const OuterTuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    final OuterTuneController controller = context.watch<OuterTuneController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OuterTune Flutter',
      themeMode: controller.settings.themeMode,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
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

class OuterTuneShell extends StatefulWidget {
  const OuterTuneShell({super.key});

  @override
  State<OuterTuneShell> createState() => _OuterTuneShellState();
}

class _OuterTuneShellState extends State<OuterTuneShell> {
  static const List<AppDestination> _mainDestinations = <AppDestination>[
    AppDestination.home,
    AppDestination.search,
    AppDestination.library,
    AppDestination.settings,
  ];

  AppDestination _destination = AppDestination.home;
  LibraryFilter _libraryFilter = LibraryFilter.all;
  int get _destinationPageIndex => _mainDestinations.indexOf(_destination);

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
        if (controller.scanning)
          const LinearProgressIndicator(
            minHeight: 3,
            color: _kAccent,
            backgroundColor: Color(0xFF3A170C),
          ),
        Expanded(
          child: IndexedStack(
            index: _destinationPageIndex,
            children: _mainDestinations
                .map((AppDestination destination) {
                  return KeyedSubtree(
                    key: ValueKey<AppDestination>(destination),
                    child: _buildPageForDestination(
                      context,
                      controller,
                      destination,
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
        if (wide && controller.miniPlayerSong != null)
          _MiniPlayer(
            controller: controller,
            onOpenPlayer: () => _openPlayer(context, controller),
          ),
      ],
    );

    final Widget swipeableContent = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (DragEndDetails details) {
        final double velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 350) {
          return;
        }
        if (velocity < 0) {
          _moveToAdjacentDestination(1);
        } else {
          _moveToAdjacentDestination(-1);
        }
      },
      child: content,
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
          Expanded(child: swipeableContent),
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
    setState(() => _destination = destination);
  }

  void _moveToAdjacentDestination(int step) {
    final int currentIndex = _destinationPageIndex;
    if (currentIndex < 0) {
      return;
    }
    final int targetIndex = (currentIndex + step).clamp(
      0,
      _mainDestinations.length - 1,
    );
    if (targetIndex == currentIndex) {
      return;
    }
    _setDestination(_mainDestinations[targetIndex]);
  }

  Widget _buildPageForDestination(
    BuildContext context,
    OuterTuneController controller,
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

BoxDecoration _kineticPageDecoration() {
  return const BoxDecoration(
    gradient: LinearGradient(
      colors: <Color>[_kPageTop, _kPageMiddle, _kPageBottom],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}

void _showKineticSnackBar(BuildContext context, String message) {
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

Future<void> _goToOfflineMusic(
  BuildContext context,
  OuterTuneController controller,
) async {
  if (!controller.isOffline) {
    await controller.setOfflineMusicMode(true);
  }
  if (!context.mounted) {
    return;
  }
  context.findAncestorStateOfType<_OuterTuneShellState>()?._setDestination(
    AppDestination.library,
  );
}

PopupMenuItem<String> _kineticPopupMenuItem(String value, String label) {
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
    required this.actionLabel,
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.icon = Icons.wifi_off_rounded,
    this.compact = false,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;
  final String? secondaryActionLabel;
  final Future<void> Function()? onSecondaryAction;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 24,
        compact ? 18 : 22,
        compact ? 18 : 24,
        compact ? 18 : 22,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 24 : 30),
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
              width: compact ? 94 : 118,
              height: compact ? 94 : 118,
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
              width: compact ? 76 : 92,
              height: compact ? 76 : 92,
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
                width: compact ? 50 : 58,
                height: compact ? 50 : 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF8A2A).withValues(alpha: 0.18),
                  border: Border.all(color: const Color(0x55FFC39B)),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFFFB784),
                  size: compact ? 24 : 28,
                ),
              ),
              SizedBox(height: compact ? 14 : 18),
              Text(
                title,
                style: GoogleFonts.splineSans(
                  color: _kTextPrimary,
                  fontSize: compact ? 20 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                message,
                style: GoogleFonts.splineSans(
                  color: _kTextSecondary.withValues(alpha: 0.92),
                  fontSize: compact ? 14 : 15,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              SizedBox(height: compact ? 16 : 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8A2A),
                      foregroundColor: const Color(0xFF2D1308),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 16 : 18,
                        vertical: compact ? 12 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    icon: const Icon(Icons.wifi_find_rounded),
                    label: Text(
                      actionLabel,
                      style: GoogleFonts.splineSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (secondaryActionLabel != null && onSecondaryAction != null)
                    OutlinedButton.icon(
                      onPressed: onSecondaryAction,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kTextPrimary,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 16 : 18,
                          vertical: compact ? 12 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.offline_bolt_rounded),
                      label: Text(
                        secondaryActionLabel!,
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

class _NetworkUnavailableOverlay extends StatelessWidget {
  const _NetworkUnavailableOverlay({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.icon = Icons.wifi_off_rounded,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;
  final String? secondaryActionLabel;
  final Future<void> Function()? onSecondaryAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(color: Colors.black.withValues(alpha: 0.50)),
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const SizedBox.expand(),
          ),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double value, Widget? child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.scale(scale: value, child: child),
                );
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _NetworkUnavailablePanel(
                    title: title,
                    message: message,
                    actionLabel: actionLabel,
                    onAction: onAction,
                    secondaryActionLabel: secondaryActionLabel,
                    onSecondaryAction: onSecondaryAction,
                    icon: icon,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
