import 'package:go_router/go_router.dart';
import 'package:cliq/presentation/screens/splash_screen.dart';
import 'package:cliq/presentation/screens/login_screen.dart';
import 'package:cliq/presentation/screens/home_screen.dart';
import 'package:cliq/presentation/screens/register_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);