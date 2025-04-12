import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      final user = supabase.auth.currentUser;
      print('Splash Screen - Current session: $session');
      print('Splash Screen - Current user: $user');

      await Future.delayed(const Duration(seconds: 2));

      if (user == null) {
        print('No user logged in, navigating to Login Screen');
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      print('Querying users table for user ID: ${user.id}');
      final response = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      print('Profile query response: $response');
      if (response == null) {
        print('No profile found for user, navigating to Profile Setup Screen');
        if (mounted) {
          context.go('/profile');
        }
        return;
      }

      final displayName = response['display_name'] as String?;
      print('Display name: $displayName');

      if (displayName != null && displayName.trim().isNotEmpty) {
        print('User has a display name set (display_name: $displayName), navigating to Home Screen');
        if (mounted) {
          context.go('/home');
        }
      } else {
        print('User does not have a display name set, navigating to Profile Setup Screen');
        if (mounted) {
          context.go('/profile');
        }
      }
    } catch (e) {
      print('Error in _checkAuthStatus: $e');
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: const Center(
        child: Text(
          'CLIQ',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}