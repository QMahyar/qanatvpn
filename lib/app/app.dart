import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../modules/onboarding/wizard.dart';
import '../modules/vpn/screens/home.dart';
import 'tabs.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/home',
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) =>
          AppShell(child: child),
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/groups',
          builder: (BuildContext context, GoRouterState state) =>
              const GroupsScreen(),
        ),
        GoRoute(
          path: '/rules',
          builder: (BuildContext context, GoRouterState state) =>
              const RulesScreen(),
        ),
        GoRoute(
          path: '/logs',
          builder: (BuildContext context, GoRouterState state) =>
              const LogsScreen(),
        ),
        GoRoute(
          path: '/diagnostics',
          builder: (BuildContext context, GoRouterState state) =>
              const DiagnosticsScreen(),
        ),
      ],
    ),
  ],
);

class YourVpnApp extends ConsumerWidget {
  const YourVpnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'YOURVPN',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF245C4F)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF245C4F),
          brightness: Brightness.dark,
        ),
      ),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const List<({String path, IconData icon, String labelKey})> tabs =
      <({String path, IconData icon, String labelKey})>[
    (path: '/home', icon: Icons.power_settings_new, labelKey: 'connect'),
    (path: '/groups', icon: Icons.hub, labelKey: 'groups'),
    (path: '/rules', icon: Icons.rule, labelKey: 'rules'),
    (path: '/logs', icon: Icons.article, labelKey: 'logs'),
    (path: '/diagnostics', icon: Icons.monitor_heart, labelKey: 'diagnostics'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String location = GoRouterState.of(context).uri.path;
    final WizardState wizard = ref.watch(wizardProvider);
    return Scaffold(
      body: wizard.step == WizardStep.done
          ? child
          : Center(
              child: SingleChildScrollView(
                child: Wizard(
                  onDone: () {}, // state change rebuilds and shows child
                ),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabs.indexWhere((t) => t.path == location).clamp(0, 4),
        onDestinationSelected: (int index) => context.go(tabs[index].path),
        destinations: <Widget>[
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              label: _label(context, tab.labelKey),
            ),
        ],
      ),
    );
  }

  String _label(BuildContext context, String key) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return switch (key) {
      'groups' => 'Groups',
      'rules' => 'Rules',
      'logs' => 'Logs',
      'diagnostics' => 'Diagnostics',
      _ => l10n.connect,
    };
  }
}

