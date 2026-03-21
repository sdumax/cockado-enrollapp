import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Feature screens — imported as they are built
import '../../features/init/splash_screen.dart';
import '../../features/init/initialisation_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/enrolment/enrolment_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/standby/standby_screen.dart';
import '../../core/services/auth_service.dart';

abstract class AppRoutes {
  static const splash    = '/';
  static const init      = '/init';
  static const login     = '/login';
  static const scan      = '/scan';
  static const enrolment = '/enrolment';
  static const settings  = '/settings';
  static const standby   = '/standby';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) async {
      final authService = ref.read(authServiceProvider);
      final loggedIn = await authService.isLoggedIn();
      final isLoginRoute = state.matchedLocation == AppRoutes.login;
      if (!loggedIn && !isLoginRoute) return AppRoutes.login;
      if (loggedIn && isLoginRoute) return AppRoutes.splash;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.init,
        builder: (_, __) => const InitialisationScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (_, __) => const ScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.enrolment,
        builder: (_, __) => const EnrolmentScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.standby,
        builder: (_, __) => const StandbyScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
});
