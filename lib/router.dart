import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/auth/login_screen.dart';
import 'package:yuvomigo/features/home/home_screen.dart';

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
    initialLocation: '/',
    redirect: (context, state) {
      // Leggo lo stato auth al momento del redirect (non lo watcho):
      // il GoRouter resta lo stesso, e mi ri-navigo con ref.listen sotto.
      final authState = ref.read(authControllerProvider);
      final path = state.uri.path;
      switch (authState) {
        case AuthLoading():
          return path == '/splash' ? null : '/splash';
        case Authenticated():
          // Se è autenticato, non mostrare il login.
          return path == '/login' || path == '/splash' ? '/' : null;
        case AuthUnauthenticated():
          // Se non autenticato, mandare al login (tranne se già lì).
          return path == '/login' ? null : '/login';
        case AuthPending2FA():
          // Il login è in corso (2FA): restare sul login.
          return path == '/login' ? null : '/login';
      }
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
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
  // viene riesaminato con lo stato nuovo (login → home, logout → login).
  ref.listen(authControllerProvider, (_, next) {
    router.go('/');
  });

  ref.onDispose(router.dispose);
  return router;
});
