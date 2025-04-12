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
      final user = supabase.auth.currentUser;
      print('Current user: $user');
      print('Current session: ${supabase.auth.currentSession}');
      await Future.delayed(const Duration(seconds: 2));

      if (user != null) {
        final response = await supabase
            .from('users')
            .select()
            .eq('id', user.id)
            .maybeSingle();

<<<<<<< HEAD
        print('Profile query response: $response');
        if (response != null &&
            response['display_name'] != null &&
            (response['display_name'] as String).trim().isNotEmpty) {
          print('User has a valid profile (display_name: ${response['display_name']}), navigating to Home Screen');
          context.go('/home');
        } else {
          print('User has no valid profile, navigating to Profile Setup Screen');
=======
        if (response != null && response['display_name'] != null) {
          print('User has profile, navigating to Home Screen');
          context.go('/home');
        } else {
          print('User has no profile, navigating to Profile Setup Screen');
>>>>>>> 1890767f40856d2826418181c2c7406e7fe5fca7
          context.go('/profile');
        }
      } else {
        print('No user logged in, navigating to Login Screen');
        context.go('/login');
      }
    } catch (e) {
      print('Error in _checkAuthStatus: $e');
      context.go('/login');
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