import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/auth/login_screen.dart';
import 'package:yuvomigo/features/calendar/calendar_screen.dart';
import 'package:yuvomigo/features/dashboard/dashboard_screen.dart';
import 'package:yuvomigo/features/home/home_screen.dart';
import 'package:yuvomigo/features/notes/notes_screen.dart';
import 'package:yuvomigo/features/shopping/shopping_list_detail_screen.dart';
import 'package:yuvomigo/features/shopping/shopping_screen.dart';
import 'package:yuvomigo/features/tasks/tasks_screen.dart';

final class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      // Leggo lo stato auth al momento del redirect (non lo watcho):
      // il GoRouter resta lo stesso, e mi ri-navigo con ref.listen sotto.
      final authState = ref.read(authControllerProvider);
      final path = state.uri.path;
      final onLoginOrSplash = path == '/login' || path == '/splash';
      switch (authState) {
        case AuthLoading():
          return path == '/splash' ? null : '/splash';
        case Authenticated():
          // Se è autenticato: niente login/splash; al resto lascia stare.
          return onLoginOrSplash ? '/dashboard' : null;
        case AuthUnauthenticated():
          return path == '/login' ? null : '/login';
        case AuthPending2FA():
          return path == '/login' ? null : '/login';
      }
    },
    routes: [
      // Shell con bottom nav: le 5 tab MVP vivono sotto '/'.
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/tasks',
            name: 'tasks',
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: '/shopping',
            name: 'shopping',
            builder: (context, state) => const ShoppingScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'shopping-detail',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ShoppingListDetailScreen(listId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/notes',
            name: 'notes',
            builder: (context, state) => const NotesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
    ],
  );

  // Quando lo stato auth cambia, ri-navigo a '/' così il redirect
  // viene riesaminato con lo stato nuovo (login → dashboard, logout → login).
  // Lo stato intermedio AuthLoading non naviga: il login resta sullo screen
  // corrente (che mostra il suo spinner locale) invece di passare per /splash
  // smontando il form e perdendo l'eventuale messaggio di errore.
  ref.listen(authControllerProvider, (_, next) {
    if (next is AuthLoading) return;
    router.go('/dashboard');
  });

  ref.onDispose(router.dispose);
  return router;
});
