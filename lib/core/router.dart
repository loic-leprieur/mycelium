import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/identify/identifier.dart';
import '../features/identify/ui/identify_screen.dart';
import '../features/identify/ui/result_screen.dart';
import '../features/journal/ui/journal_screen.dart';
import '../features/journal/ui/outing_detail_screen.dart';
import '../features/journal/ui/outing_form_screen.dart';
import '../features/map/ui/map_screen.dart';
import '../features/map/ui/spot_form_screen.dart';
import '../features/species/ui/add_species_screen.dart';
import '../features/species/ui/species_detail_screen.dart';
import '../features/species/ui/species_list_screen.dart';

final router = GoRouter(
  initialLocation: '/map',
  routes: [
    StatefulShellRoute.indexedStack(
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
