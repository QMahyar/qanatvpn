import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../modules/health/diagnostics_screen.dart' as diag;
import '../modules/logs/logs_screen.dart' as logs;
import '../modules/onboarding/wizard.dart';
import '../modules/routing/groups_screen.dart' as groups;
import '../modules/routing/rules_screen.dart' as rules;
import '../modules/updates/updates_screen.dart';
import '../modules/vpn/repositories/endpoints_screen.dart';
import '../modules/vpn/screens/home.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Accessibility floor/ceiling: below 0.9 text becomes unreadably dense,
/// above 1.35 bento tiles overflow. WireGuard-grade UI stays legible at both.
const double minTextScale = 0.9;
const double maxTextScale = 1.35;

TextScaler clampTextScaler(TextScaler scaler) {
  final double scale = scaler.scale(10) / 10;
  return TextScaler.linear(scale.clamp(minTextScale, maxTextScale));
}

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
              const groups.GroupsScreen(),
        ),
        GoRoute(
          path: '/endpoints',
          builder: (BuildContext context, GoRouterState state) =>
              const EndpointsScreen(),
        ),
        GoRoute(
          path: '/rules',
          builder: (BuildContext context, GoRouterState state) =>
              const rules.RulesScreen(),
        ),
        GoRoute(
          path: '/logs',
          builder: (BuildContext context, GoRouterState state) =>
              const logs.LogsScreen(),
        ),
        GoRoute(
          path: '/diagnostics',
          builder: (BuildContext context, GoRouterState state) =>
              const diag.DiagnosticsScreen(),
        ),
        GoRoute(
          path: '/updates',
          builder: (BuildContext context, GoRouterState state) =>
              const UpdatesScreen(),
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
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: clampTextScaler(mq.textScaler)),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
        (
          path: '/diagnostics',
          icon: Icons.monitor_heart,
          labelKey: 'diagnostics',
        ),
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
      'groups' => l10n.groups,
      'rules' => l10n.rules,
      'logs' => l10n.logs,
      'diagnostics' => l10n.diagnostics,
      _ => l10n.connect,
    };
  }
}
