import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/identify/history/detail_screen.dart';
import '../features/identify/history/history_screen.dart';
import '../features/identify/identifier.dart';
import '../features/identify/ui/identify_screen.dart';
import '../features/identify/ui/result_screen.dart';
import '../features/journal/ui/journal_screen.dart';
import '../features/journal/ui/outing_detail_screen.dart';
import '../features/journal/ui/outing_form_screen.dart';
import '../features/map/ui/map_screen.dart';
import '../features/map/ui/spot_form_screen.dart';
import '../features/safety/consent_screen.dart';
import '../features/safety/safety_screen.dart';
import '../features/settings/data/data_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/species/ui/add_species_screen.dart';
import '../features/species/ui/species_detail_screen.dart';
import '../features/species/ui/species_list_screen.dart';
import '../features/splash/splash_screen.dart';

/// Fondu + léger glissement entre les onglets, en gardant chaque onglet vivant.
class _FadingBranches extends StatelessWidget {
  const _FadingBranches({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < children.length; i++)
            AnimatedOpacity(
              opacity: i == index ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: AnimatedSlide(
                offset: i == index ? Offset.zero : const Offset(0, .015),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: i != index,
                  child: TickerMode(enabled: i == index, child: children[i]),
                ),
              ),
            ),
        ],
      );
}

GoRouter buildRouter({String initialLocation = '/splash'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const SettingsScreen(),
      routes: [
        GoRoute(path: 'data', builder: (_, _) => const DataScreen()),
        GoRoute(path: 'safety', builder: (_, _) => const SafetyScreen()),
      ],
    ),
    StatefulShellRoute(
      navigatorContainerBuilder: (context, shell, children) =>
          _FadingBranches(index: shell.currentIndex, children: children),
      builder: (context, state, shell) => Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Carte'),
            NavigationDestination(icon: Icon(Icons.photo_camera_outlined), selectedIcon: Icon(Icons.photo_camera), label: 'Identifier'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Espèces'),
            NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: 'Carnet'),
          ],
        ),
      ),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/map',
            builder: (_, _) => const MapScreen(),
            routes: [
              GoRoute(
                path: 'spot',
                builder: (_, state) => SpotFormScreen(
                  spotId: state.uri.queryParameters['id'],
                  latitude: double.tryParse(state.uri.queryParameters['lat'] ?? ''),
                  longitude: double.tryParse(state.uri.queryParameters['lon'] ?? ''),
                ),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/identify',
            builder: (_, _) => const IdentifyScreen(),
            routes: [
              GoRoute(
                path: 'result',
                builder: (_, state) =>
                    ResultScreen(outcome: state.extra! as IdentificationOutcome),
              ),
              GoRoute(
                path: 'history',
                builder: (_, _) => const IdentificationHistoryScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => IdentificationDetailScreen(
                      identificationId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/species',
            builder: (_, _) => const SpeciesListScreen(),
            routes: [
              GoRoute(path: 'add', builder: (_, _) => const AddSpeciesScreen()),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    SpeciesDetailScreen(speciesId: state.pathParameters['id']!),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/journal',
            builder: (_, _) => const JournalScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const OutingFormScreen()),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    OutingDetailScreen(outingId: state.pathParameters['id']!),
              ),
            ],
          ),
        ]),
      ],
    ),
  ],
);
