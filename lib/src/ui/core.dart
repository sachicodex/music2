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
        if (controller.scanning)
          const LinearProgressIndicator(
            minHeight: 3,
            color: _kAccent,
            backgroundColor: Color(0xFF3A170C),
          ),
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

const Color _kPageTop = Color(0xFF140804);
const Color _kPageMiddle = Color(0xFF211008);
const Color _kPageBottom = Color(0xFF0D0503);
const Color _kSurface = Color(0xFF2A1007);
const Color _kSurfaceEdge = Color(0xFF3A170C);
const Color _kAccent = Color(0xFFFF8A2A);
const Color _kTextPrimary = Color(0xFFFFE8DA);
const Color _kTextSecondary = Color(0xFFFFC8A9);
const double _kScreenHorizontalPadding = 24;
const double _kScreenTopPadding = 18;
const double _kScreenBottomPadding = 28;
const EdgeInsets _kScreenContentPadding = EdgeInsets.fromLTRB(
  _kScreenHorizontalPadding,
  _kScreenTopPadding,
  _kScreenHorizontalPadding,
  _kScreenBottomPadding,
);

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
