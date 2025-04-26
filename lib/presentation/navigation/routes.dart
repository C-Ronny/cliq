import 'package:go_router/go_router.dart';
import 'package:cliq/presentation/screens/splash_screen.dart';
import 'package:cliq/presentation/screens/login_screen.dart';
import 'package:cliq/presentation/screens/register_screen.dart';
import 'package:cliq/presentation/screens/profile_screen.dart';
import 'package:cliq/presentation/screens/home_screen.dart';
import 'package:cliq/presentation/screens/friends_screen.dart';
import 'package:cliq/presentation/screens/chats_screen.dart';
import 'package:cliq/presentation/screens/chat_screen.dart';
import 'package:cliq/presentation/screens/profile_view_screen.dart';
import 'package:cliq/presentation/screens/call_screen.dart';
import 'package:cliq/presentation/screens/add_friends_screen.dart';


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
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileSetupScreen(),
      ),
    GoRoute(
      path: '/friends',
      builder: (context, state) => const FriendsScreen(),
    ),
    GoRoute(
      path: '/chats',
      builder: (context, state) => const ChatsScreen(),
    ),
    GoRoute(
      path: '/profile-view',
      builder: (context, state) => const ProfileViewScreen(),
    ),
    GoRoute(
      path: '/call/:callId',
      builder: (context, state) {
        final callId = state.pathParameters['callId']!;
        return CallScreen(callId: callId);
      },
    ),
    GoRoute(
      path: '/add-friends/:callId',
      builder: (context, state) {
        final callId = state.pathParameters['callId']!;
        return AddFriendsScreen(callId: callId);
      },
    ),
    GoRoute(
      path: '/chats',
      builder: (context, state) => const ChatsScreen(),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) {
        final conversationId = state.pathParameters['id']!;
        return ChatScreen(conversationId: conversationId);
      },
    ),
  ],
);