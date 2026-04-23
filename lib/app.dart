import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/sr_service.dart';
import 'screens/decks_tab.dart';
import 'screens/review_tab.dart';
import 'screens/settings_tab.dart';
import 'providers/theme_provider.dart';

class MyApp extends StatelessWidget {
  final StorageService storage;
  final ThemeProvider themeProvider;
  final GlobalKey<NavigatorState> navigatorKey;
  final SRService srService;

  const MyApp({
    required this.storage,
    required this.themeProvider,
    required this.navigatorKey,
    required this.srService,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return AnimatedBuilder(
          animation: themeProvider,
          builder: (context, child) {
            final seed = themeProvider.seedColor;
            final lightScheme = seed == null
                ? (lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.indigo))
                : ColorScheme.fromSeed(seedColor: seed);
            final darkScheme = seed == null
                ? (darkDynamic ??
                    ColorScheme.fromSeed(
                        seedColor: Colors.indigo, brightness: Brightness.dark))
                : ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

            final effectiveDarkScheme = themeProvider.isAmoled
                ? darkScheme.copyWith(
                    surface: Colors.black,
                    surfaceContainerLowest: Colors.black,
                    surfaceContainerLow: const Color(0xFF0D0D0D),
                    surfaceContainer: const Color(0xFF111111),
                    surfaceContainerHigh: const Color(0xFF161616),
                    surfaceContainerHighest: const Color(0xFF1A1A1A),
                  )
                : darkScheme;

            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'Deck It',
              themeMode: themeProvider.themeMode,
              theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
              darkTheme: ThemeData(
                colorScheme: effectiveDarkScheme,
                scaffoldBackgroundColor:
                    themeProvider.isAmoled ? Colors.black : null,
                useMaterial3: true,
              ),
              home: MyHomePage(
                storage: storage,
                themeProvider: themeProvider,
                srService: srService,
              ),
            );
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  final StorageService storage;
  final ThemeProvider themeProvider;
  final SRService srService;

  const MyHomePage({
    required this.storage,
    required this.themeProvider,
    required this.srService,
    super.key,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
  };

  int _currentIndex = 0;

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      _navigatorKeys[index]!.currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _currentIndex = index);
    }
  }

  Widget _buildOffstageNavigator(int index) {
    return Offstage(
      offstage: _currentIndex != index,
      child: TabNavigator(
        navigatorKey: _navigatorKeys[index]!,
        storage: widget.storage,
        themeProvider: widget.themeProvider,
        srService: widget.srService,
        tabIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final isFirstRouteInCurrentTab =
            !await _navigatorKeys[_currentIndex]!.currentState!.maybePop();
        if (isFirstRouteInCurrentTab && _currentIndex != 0) {
          _onTabTapped(0);
          return false;
        }
        return isFirstRouteInCurrentTab;
      },
      child: Scaffold(
        body: Stack(
          children: [
            _buildOffstageNavigator(0),
            _buildOffstageNavigator(1),
            _buildOffstageNavigator(2),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabTapped,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.library_books), label: 'Decks'),
            NavigationDestination(icon: Icon(Icons.refresh), label: 'Review'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final StorageService storage;
  final ThemeProvider themeProvider;
  final SRService srService;
  final int tabIndex;

  const TabNavigator({
    required this.navigatorKey,
    required this.storage,
    required this.themeProvider,
    required this.srService,
    required this.tabIndex,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) {
            switch (tabIndex) {
              case 0:
                return DecksTab(storage: storage);
              case 1:
                return ReviewTab(storage: storage, srService: srService);
              case 2:
                return SettingsTab(
                  storage: storage,
                  themeProvider: themeProvider,
                  srService: srService,
                );
              default:
                return DecksTab(storage: storage);
            }
          },
        );
      },
    );
  }
}
